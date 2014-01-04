module geneticd.gene;

import std.conv : to;
import std.traits : isScalarType;

import geneticd.chromosome;

interface ICloneable
{
    /**
     * Create new object using current instance as a template.
     */
    pure nothrow ICloneable clone()
    out(result)
    {
        assert(result !is null);
    }
}

/**
 * Gene basic interface 
 */
interface IGene(T) : ICloneable
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
    pure nothrow void mutate();

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
    pure nothrow abstract void mutate();

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
    pure nothrow BasicGene!T clone()
    out(result)
    {
        assert(result !is null);
    }
    body
    {
        auto gene = cloneInternal();
        //copy rest of the non value properties

        return gene;
    }
    
    pure nothrow protected abstract BasicGene!T cloneInternal();

    override string toString() const
    {
        return to!string(_value);
    }
}

/**
 * Simple gene whith two possible values: true and false
 */
class BoolGene : BasicGene!bool
{
    pure nothrow this()
    { }

    pure nothrow this(bool value)
    {
        this.value = value;
    }

    pure nothrow protected override BoolGene cloneInternal()
    {
        return new BoolGene(_value);
    }

    /**
     * Set random value to gene.
     * Used by mutate operator.
     */
    override void setRandomValue()
    {
        import std.random : dice;
        _value = dice(0.5,0.5) == 1;
    }

    /**
     * Apply mutation operation to gene.
     * For BoolGene the flip bit mutation is used.
     */
    pure nothrow override void mutate()
    {
        _value = !_value;
    }

    /// BoolGene tests
    unittest
    {
        import core.exception;
        import std.exception;

        IGene!bool gene = new BoolGene();
        gene = cast(BoolGene)gene.clone();
        gene.value = true;

        gene.mutate();
        assert(gene.value == false);
        gene.mutate();
        assert(gene.value == true);

        assert((gene is null) == false);

        auto gene2 = new BoolGene(true);
        assert(gene == gene2);
        assert(gene.toHash == gene2.toHash);

        assert(gene2 == true);

        gene2.value = false;
        assert(gene != gene2);
        assert(gene.toHash != gene2.toHash);

        assert(gene2 == false);
    }
}

//TODO: Add scalar type Gene with min max params
//TODO: Add bitarray Gene for bitwise representation instead of BoolGene
//TODO: Add string Gene
//TODO: Add composite Gene
