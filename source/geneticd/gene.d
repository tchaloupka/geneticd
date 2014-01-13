module geneticd.gene;

import std.conv : to;
import std.traits : isScalarType, isBoolean;

import geneticd.chromosome;

interface ICloneable(T)
{
    /**
     * Create new object using current instance as a template.
     */
    T clone()
    out(result)
    {
        assert(result !is null);
    }
}

/**
 * Gene basic interface 
 */
interface IGene(T) : ICloneable!(IGene!T)
{
    /**
     * Gets the value of the gene
     */
    @property pure nothrow T value() const;

    /**
     * Sets the value of the gene
     */
    @property pure nothrow void value(T val);

    /**
     * Number of atomic elements of the gene.
     * For example number genes has allways size = 1
     */
    @property pure nothrow uint size() const;

    /**
     * Set random value to gene.
     * Used by mutate operator.
     */
    void setRandomValue();

    /**
     * Used by GA engine to clean up any resources
     */
    pure nothrow void clean();

    /**
     * Apply mutation operation to gene
     */
    void mutate();

    /**
     * Equality operator
     */
    pure nothrow bool opEquals(Object o) const;

    /**
     * Equality operator for internal values
     */
    pure nothrow bool opEquals(T)(const auto ref T val) const;

    /**
     * Returns a hash of the object
     */
    nothrow size_t toHash() const;
}

/**
 * Basic abstract class for all genes
 */
abstract class BasicGene(T) : IGene!T
{
    protected T _value;

    /**
     * Gets the value of the gene
     */
    @property pure nothrow T value() const
    {
        return _value;
    }
    
    /**
     * Sets the value of the gene
     */
    @property pure nothrow void value(T val)
    {
        _value = val;
    }
    
    /**
     * Number of atomic elements of the gene.
     * For example number genes has allways size = 1
     */
static if(isScalarType!T)
    @property pure nothrow uint size() const
    {
        return 1;
    }
else
    @property pure nothrow abstract uint size() const;
    
    /**
     * Set random value to gene.
     * Used by mutate operator.
     */
    abstract void setRandomValue();
    
    /**
     * Used by GA engine to clean up any resources
     */
    pure nothrow void clean() {}
    
    /**
     * Apply mutation operation to gene
     */
    abstract void mutate();

    /**
     * Equality operator
     */
    pure nothrow override bool opEquals(Object rhs) const
    {
        auto that = cast(BasicGene!T)rhs;
        if(!that)
        {
            return false;
        }
        return this._value == that._value;
    }

    /**
     * Equality operator
     */
    pure nothrow bool opEquals(T)(const auto ref T rhs) const
    {
        return this._value == rhs;
    }

    /**
     * Returns a hash of the object
     */
static if(isScalarType!T)
    nothrow override size_t toHash() const
    {
        return typeid(_value).getHash(&_value);
    }
else 
    nothrow abstract size_t toHash() const;

    /**
     * Create new gene using current instance as a template
     * It should use the same ranges, constraints, etc.
     */
    final typeof(this) clone() const
    out(result)
    {
        assert(result !is null);
    }
    body
    {
        import std.traits : Unqual;
        auto gene = cloneInternal();
        //copy rest of the non value properties

        return cast(Unqual!(typeof(this)))gene;
    }
    
    protected abstract Object cloneInternal() const;

    override string toString() const
    {
        return to!string(_value);
    }

    /// Boundaries for scalar values
    static if(isScalarType!T)
    {
        protected T _min;
        protected T _max;

        /// Minimal gene boundary
        @property pure nothrow @safe T min() const
        {
            return _min;
        }

        /// Maximal gene boundary
        @property pure nothrow @safe T max() const
        {
            return _max;
        }

        /// Set minimal gene boundary
        @property pure nothrow @safe void min(T val)
        {
            _min = val;
        }

        /// Set minimal gene boundary
        @property pure nothrow @safe void max(T val)
        {
            _max = val;
        }

        /// Scalar construcor
        pure nothrow @safe this(in T value)
        {
            this(value, T.min, T.max);
        }

        /// Scalar constructor with boundaries
        pure nothrow @safe this(in T value, in T min, in T max)
        {
            _value = value;
            _min = min;
            _max = max;
        }
    }
}

/// Gene represented as a scalar value
class ScalarGene(T) : BasicGene!T if(isScalarType!T)
{
    pure nothrow this()
    {
        super(T.init);
    }

    pure nothrow this(T value)
    {
        super(value);
    }

    pure nothrow this(T value, T min, T max)
    {
        super(value, min, max);
    }

    protected final override Object cloneInternal() const
    {
        import std.traits : Unqual;
        auto newObj = cast(Unqual!(typeof(this)))this.classinfo.create();
        newObj._value = _value;
        newObj._min = _min;
        newObj._max = _max;

        return newObj;
    }

    /**
     * Set random value to gene.
     * Used by mutate operator.
     */
    override void setRandomValue()
    {
        static if(isBoolean!T)
        {
            import std.random : dice;
            _value = dice(0.5,0.5) == 1;
        }
        else
        {
            import std.random : uniform;
            _value = uniform!"[]"(_min, _max);
        }
    }
    
    /**
     * Apply mutation operation to gene.
     * For BoolGene the flip bit mutation is used.
     */
    override void mutate()
    {
        static if(isBoolean!T)
        {
            //For BoolGene the flip bit mutation is used.
            _value = !_value;
        }
        else
            setRandomValue();
    }
}

/// BoolGene tests
unittest
{
    import core.exception;
    import std.exception;
    
    auto gene = new ScalarGene!bool();
    gene = cast(ScalarGene!bool)gene.clone();
    gene.value = true;
    
    gene.mutate();
    assert(gene.value == false);
    gene.mutate();
    assert(gene.value == true);
    
    assert((gene is null) == false);
    
    auto gene2 = new ScalarGene!bool(true);
    assert(gene == gene2);
    assert(gene.toHash == gene2.toHash);
    
    assert(gene2 == true);
    
    gene2.value = false;
    assert(gene != gene2);
    assert(gene.toHash != gene2.toHash);
    
    assert(gene2 == false);
}

/// CharGene tests
unittest
{
    auto gene = new ScalarGene!char('a');
    assert(gene == new ScalarGene!char('a'));
    assert(gene != new ScalarGene!char('b'));
}

//TODO: Add bitarray Gene for bitwise representation instead of BoolGene?
//TODO: Add string Gene
//TODO: Add composite Gene
