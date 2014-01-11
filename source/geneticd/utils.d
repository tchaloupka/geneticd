module geneticd.utils;

import std.traits : isNumeric, isFloatingPoint;
import std.random : uniform;
import std.complex;

/**
 * Simple implementation of stack using dynamic array.
 * 
 * Note:
 * It does not change the length of an array so if reused with the same size, no other allocation is needed.
 */
struct Stack(T) if (isNumeric!T)
{
    private T[] _stack;
    private size_t _idx = 0;
    private bool _empty = true;

    /// Is stack empty?
    @property pure nothrow bool empty() const @safe
    {
        return _empty;
    }

    /// Add value on top of stack
    pure nothrow void push(T value) @safe
    {
        if(_empty)
        {
            if(_stack.length == 0) _stack ~= value;
            else _stack[0] = value;
            _empty = false;
        }
        else
        {
            _idx++;
            if(_stack.length == _idx) _stack ~= value;
            else _stack[_idx] = value;
        }
    }

    /// Remove value from top of the stack
    pure nothrow T pop() @safe
    {
        assert(!empty);

        auto tmp = _stack[_idx];
        if(_idx == 0) _empty = true;
        else _idx--;

        return tmp;
    }

    /// Clear the stack
    pure nothrow void clear() @safe
    {
        _empty = true;
        _idx = 0;
    }

    unittest
    {
        Stack!int stack;
        assert(stack.empty);
        stack.push(99);
        foreach(n; 1..10)
        {
            stack.push(n);
        }
        
        foreach(n; 1..10)
        {
            auto x = stack.pop();
            assert(x == 10-n);
        }
        assert(!stack.empty);
        assert(stack.pop() == 99);
        assert(stack.empty);
        
        foreach(x; 1..10)
        {
            stack.push(x);
            auto y = stack.pop();
            assert(stack.empty);
            assert(x == y);
        }
    }
}

/** 
 * Selection with alias Vose's algorithm
 * 
 * See_Also:
 * http://www.keithschwarz.com/darts-dice-coins/
 */
struct AliasMethodSelection(T) if(isNumeric!T)
{
    import std.algorithm : reduce;

    private Stack!uint _small;
    private Stack!uint _large;

    private size_t[] _alias;
    private double[] _prob;
    private double[] _tmpProb;

    pure nothrow void init(in T[] probabilities, in T sum = 0)
    {
        assert(probabilities.length > 0);
        assert(_small.empty && _large.empty);
        if(sum) assert(reduce!"a+b"(0.0, probabilities) == sum);

        immutable double probSum = sum ? sum : reduce!"a+b"(0.0, probabilities);

        //init arrays
        _alias.length = _prob.length = _tmpProb.length = probabilities.length;

        //init stacks with input probabilities
        foreach(uint i, p; probabilities)
        {
            //normalize probabilities
            _tmpProb[i] = (probSum == 1.0 ? cast(double)probabilities[i] : (cast(double)probabilities[i]/probSum)) * probabilities.length;

            if(_tmpProb[i] >= 1.0) _large.push(i);
            else _small.push(i);
        }

        while(!_small.empty && !_large.empty)
        {
            //get index of small and large probabilities
            uint less = _small.pop();
            uint more = _large.pop();

            _prob[less] = _tmpProb[less];
            _alias[less] = more;

            //decrease the probability of larger one
            _tmpProb[more] = (_tmpProb[more] + _tmpProb[less]) - 1.0;

            if(_tmpProb[more] >= 1.0) _large.push(more);
            else _small.push(more);
        }

        //at this point all whats left should be = 1.0
        //due to numerical issues, we can't be sure which stack will hold the entries, so we empty both
        while(!_small.empty) _prob[_small.pop()] = 1.0;
        while(!_large.empty) _prob[_large.pop()] = 1.0;
    }

    /**
     * Select the next item
     * 
     * Returns:
     * index to the original array of selected items
     */
    size_t next()
    {
        auto column = uniform(0, _prob.length);
        return uniform(0.0, 1.0) < _prob[column] ? column : _alias[column];
    }

    unittest
    {
        import std.math : approxEqual;

        AliasMethodSelection!double aliasMethod;
        double[] input = [1.0/8, 1.0/5, 1.0/10, 1.0/4, 1.0/10, 1.0/10, 1.0/8];
        aliasMethod.init(input, 1.0);

        assert(approxEqual(aliasMethod._prob, [0.875, 1, 0.7, 0.725, 0.7, 0.7, 0.875]));
        assert(aliasMethod._alias == [1, 0, 3, 1, 3, 3, 3]);
    }
}

/**
 * Struct representing polynomial with some usable methods
 */
struct Polynomial
{
    import std.conv : to;
    private double[] _coef;

    /**
     * Constructor
     * 
     * Params:
     *      coefficients = polynomial coefficients, highest order coefficient has to be first
     */
    pure nothrow this(T)(in T[] coefficients...) @safe
    in
    {
        assert(coefficients.length > 0);
        assert(coefficients[0] != 0);
    }
    body
    {
        _coef = to!(double[])(coefficients);
    }

    /// Evaluate polynomial function using Horner's method
    pure nothrow auto evaluate(U)(in U x) const @safe
        if(isNumeric!U || is(U == Complex!double))
    {
        static if(isNumeric!U)
        {
            double bi = _coef[0];
        }
        else 
        {
            Complex!double bi = _coef[0];
        }

        foreach(c; _coef[1..$])
        {
            bi = bi*x + c;
        }
        
        return bi;
    }

    /// Return derivative polynomial from current
    pure nothrow Polynomial derivative() const @safe
    {
        assert(_coef.length > 1);

        double[] tmp;

        size_t pow = _coef.length - 1;
        foreach(c; _coef[0..$-1])
        {
            tmp ~= c*(pow--);
        }

        return Polynomial(tmp);
    }

    /// Degree of polynomial
    @property pure nothrow size_t degree() const @safe
    {
        return _coef.length-1;
    }

    /// Is polynomial monic?
    @property pure nothrow bool isMonic() const @safe
    {
        return _coef[0] == 1.0;
    }

    /// Creates monic polynomial from current
    pure nothrow Polynomial toMonic() const @safe
    {
        if(isMonic) return Polynomial(_coef);

        double[] tmp;
        tmp ~= 1.0;
        foreach(c; _coef[1..$])
        {
            tmp ~= c/_coef[0];
        }

        return Polynomial(tmp);
    }

    /**
     * Find all roots using Durand-Kerner-Weierstrass method 
     */
    pure Complex!double[] findRoots(in uint maxIterations = 999, in double epsilon = 1e-15)
    {
        // Check if is monic polynomial
        if(!isMonic)
        {
            return toMonic().findRoots(maxIterations, epsilon);
        }

        import std.math : abs;

        //roots array
        Complex!double[] r = new Complex!double[degree];

        auto num = complex(0.4, 0.9);
        r[0] = complex(1.0);
        foreach(i; 1..degree) r[i] = r[i-1] * num;

        // Iterate
        int count = 0;
        bool changed;
        do
        {
            changed = false;
            foreach(i; 0..r.length)
            {
                auto tmp = complex(1.0);
                foreach(j; 0..r.length) if (i != j) tmp *= r[i] - r[j];

                tmp = r[i] - evaluate(r[i])/tmp;

                //check if new root is unchanged
                if(abs(r[i].re - tmp.re) > epsilon) changed = true;
                else if(abs(r[i].im - tmp.im) > epsilon) changed = true;
                r[i] = tmp;
            }
        } while(count++ < maxIterations && changed);

        return r;
    }

    string toString() const
    {
        import std.string : format;

        string tmp;
        size_t pow = _coef.length - 1;
        foreach(c; _coef)
        {
            if(pow == 0 && c != 0.0) tmp ~= format("%s + ", c);
            if(pow == 1 && c != 0.0) tmp ~= c!=1 ? format("%sx + ", c) : format("x + ");
            if(pow > 1 && c!= 0.0) tmp ~= c!=1 ? format("%sx^%s + ", c, pow) : format("x^%s + ", pow);
            pow--;
        }

        if(tmp.length>0) return tmp[0..$-3];
        else return "ZERO POLY";
    }

    pure nothrow double opCall(double x) const
    {
        return evaluate(x);
    }

    unittest
    {
        import std.conv : to;
        import std.math : approxEqual;
        import std.algorithm : filter;
        import std.array;

        auto poly = Polynomial(2, 1, 0, 1); //2x^3 + x^2 + 1
        assert(to!string(poly) == "2x^3 + x^2 + 1");

        auto dpoly = poly.derivative();
        assert(dpoly == Polynomial(6, 2, 0)); //6x^2 + 2x

        assert(dpoly.toMonic() == Polynomial(1.0, 2.0/6, 0.0));

        assert(dpoly.evaluate(1) == 2 + 6);
        assert(dpoly.evaluate(2) == 4 + 6*4);
        assert(dpoly(3) == 6 + 6*9);

        assert(poly == Polynomial(2.0, 1.0, 0.0, 1.0));

        auto roots = dpoly.findRoots();
        assert(approxEqual(roots[0].re, 0));
        assert(approxEqual(roots[0].im, 0));
        assert(approxEqual(roots[1].re, -1.0/3));
        assert(approxEqual(roots[1].im, 0));

        poly = Polynomial(-8, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3); //-8x^10+3x^9+3x^8+3x^7+3x^6+3x^5+3x^4+3x^3+3x^2+3x+3
        roots = poly.findRoots();
        assert(roots.length == 10);
        auto realRoots = roots.filter!(a=>approxEqual(a.im,0)).array;
        assert(realRoots.length == 2);
        assert(approxEqual(realRoots.filter!(a=>a.re > 0).front.re, 1.357));
    }
}


