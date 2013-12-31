module geneticd.gene;

import std.conv;
import std.random;
import std.traits;

import geneticd.chromosome;

/**
 * Gene basic interface 
 */
interface IGene(T)
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
     * Gets the constraint checker of the gene
     */
    @property pure nothrow IConstraintChecker!T constraintChecker();
    
    /**
     * Sets the constraint checker of the gene
     */
    @property pure nothrow void constraintChecker(IConstraintChecker!T checker);

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
     * 
     * Params:
     *      percentage = probability of gene value change from -1 to 1
     *      idx = index of atom gene value if it consists of more than one
     */
    pure nothrow void mutate(double percentage, uint idx = 0)
    in
    {
        assert(percentage >= -1.0 && percentage <= 1.0, "Percentage of mutation must be between -1.0 and 1.0");
    }

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

    /**
     * Create new gene using current instance as a template
     * It should use the same ranges, constraints, etc.
     */
    pure nothrow IGene!T clone()
        out(result)
    {
        assert(result !is null);
    }
}

/**
 * Interface for checking if given gene value is valid to be set.
 * Called from value setter property of the gene.
 */
interface IConstraintChecker(T)
{
    pure nothrow bool isValid(IGene!T gene, T value);
}

/**
 * Basic abstract class for all genes
 */
abstract class BasicGene(T) : IGene!T
{
    protected T _value;
    protected IConstraintChecker!T _constraintChecker;

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
        if(_constraintChecker !is null && !_constraintChecker.isValid(this, val))
            assert(false, "Constraint check failed");

        _value = val;
    }

    /**
     * Gets the constraint checker of the gene
     */
    @property pure nothrow IConstraintChecker!T constraintChecker()
    {
        return _constraintChecker;
    }
    
    /**
     * Sets the constraint checker of the gene
     */
    @property pure nothrow void constraintChecker(IConstraintChecker!T checker)
    {
        _constraintChecker = checker;
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
     * 
     * Params:
     *      percentage = probability of gene value change from -1 to 1
     *      idx = index of atom gene value if it consists of more than one
     */
    pure nothrow abstract void mutate(double percentage, uint idx = 0)
    in
    {
        //TODO: Repeated due to http://d.puremagic.com/issues/show_bug.cgi?id=6856
        assert(percentage >= -1.0 && percentage <= 1.0, "Percentage of mutation must be between -1.0 and 1.0");
    }
    body{}

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
        body
    {
        auto gene = cloneInternal();
        //copy rest of the non value properties
        gene._constraintChecker = _constraintChecker;
        
        return gene;
    }
    
    pure nothrow protected abstract BasicGene!T cloneInternal()
        out(result)
    {
        assert(result !is null);
    }
    body
    {
        return null;
    }

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
        _value = to!bool(uniform!"[]"(0, 1));
    }

    /**
     * Apply mutation operation to gene
     * 
     * Params:
     *      percentage = probability of gene value change from -1 to 1
     *      idx = index of atom gene value if it consists of more than one
     */
    pure nothrow override void mutate(double percentage, uint idx = 0)
    in
    {
        //TODO: Repeated due to http://d.puremagic.com/issues/show_bug.cgi?id=6856 and because no AssertError is thrown without this..
        assert(percentage >= -1.0 && percentage <= 1.0, "Percentage of mutation must be between -1.0 and 1.0");
    }
    body
    {
        if(percentage > 0) value = true;
        if(percentage < 0) value = false;
    }

    /// BoolGene tests
    unittest
    {
        import core.exception;
        import std.exception;

        IGene!bool gene = new BoolGene();
        gene = gene.clone();
        gene.value = true;

        assertThrown!AssertError(gene.mutate(2));

        gene.mutate(0);
        assert(gene.value == true);
        gene.mutate(-0.5);
        assert(gene.value == false);
        gene.mutate(0.5);
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
