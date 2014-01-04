module geneticd.utils;

import std.traits : isNumeric;
import std.random : uniform;

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

/// Stack unittest
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
