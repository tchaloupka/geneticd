module geneticd.chromosome;

import std.conv;
import std.string;

import geneticd.gene;
import geneticd.configuration;

interface IChromosome
{
    /**
     * Age of the chromosome - number of generation since chromosome was born
     * Can be used for altering chromosome fitness by age (to prefer new ones over the old ones)
     */
    @property pure nothrow uint age() const;

    /**
     * Age of the chromosome - number of generation since chromosome was born
     * Can be used for altering chromosome fitness by age (to prefer new ones over the old ones)
     */
    @property pure nothrow void age(uint age);

    /**
     * The fitness of this chromosome.
     */
    @property pure nothrow double fitness() const;

    /**
     * Set the fitness of this chromosome.
     */
    @property pure nothrow void fitness(double fitness);

    /**
     * Should this chromosome survive for the next generation?
     */
    @property pure nothrow bool survive() const;

    /**
     * Set if this chromosome should survive for the next generation unchanged
     */
    @property pure nothrow void survive(bool survive);

    /**
     * Used by GA engine to clean up any resources
     */
    pure nothrow void clean();

    /**
     * Randomizes chromosome genes
     */
    void randomize();
}

/**
 * Represents an individual solution which consost of fixed number of genes
 */
class Chromosome(T:IGene!G, G) : IChromosome
{
    alias Configuration!(Chromosome!T) configType;

    protected double _fitness;
    protected uint _age;
    protected bool _survive;
    protected T[] _genes;
    protected configType _configuration;

    protected @property pure nothrow isSample() const
    {
        return _configuration is null;
    }

    /**
     * Chromosome constructor which uses a configuration sampleChromosome to initialization
     * 
     * Params:
     *      configuration = GA configuration
     */
    this(configType configuration)
    {
        assert(configuration !is null);

        auto sample = cast(Chromosome!T)configuration.sampleChromosome;
        if(!sample) assert(false);

        assert(sample._genes.length > 0);

        this(configuration, sample._genes[0], sample._genes.length);
    }

    /**
     * Special constructor to make sample chromosome
     */
    this(T sampleGene, size_t size)
    {
        assert(sampleGene !is null);

        this._genes.length = size;
        this._genes[0] = sampleGene;
    }

    /**
     * Chromosome constructor
     * 
     * Params:
     *      configuration = GA configuration
     *      sampleGene = sample gene to help create chromosome
     *      size = desired number of stored genes in chromosome
     */
    this(configType configuration, T sampleGene, size_t size)
    in
    {
        assert(configuration !is null);
        assert(sampleGene !is null);
        assert(size > 0);
    }
    body
    {
        scope(exit)
        {
            assert(this._genes.length == size);
        }
    
        this._configuration = configuration;
        foreach(i; 0..size)
        {
            this._genes ~= cast(T)sampleGene.clone();
        }
        randomize();
    }

    /**
     * Chromosome constructor which uses a configuration sampleChromosome to initialization
     * 
     * Params:
     *      configuration = GA configuration
     *      initialGenes = initial set of genes
     */
    pure nothrow this(configType configuration, T[] initialGenes)
    {
        assert(configuration !is null);
        assert(initialGenes.length > 0);

        scope(exit)
        {
            assert(_genes.length == initialGenes.length);
        }
        
        this._configuration = configuration;
        foreach(gene; initialGenes)
        {
            _genes ~= cast(T)gene.clone();
        }
    }

    /**
     * Fitnes of the chromosome
     */
    @property pure nothrow double fitness() const
    {
        assert(!isSample);

        return this._fitness;
    }

    /**
     * Set fitnes of the chromosome
     */
    @property pure nothrow void fitness(double fitness)
    {
        assert(!isSample);

        this._fitness = fitness;
    }

    /**
     * Age of the chromosome - number of generation since chromosome was born
     * Can be used for altering chromosome fitness by age (to prefer new ones over the old ones)
     */
    @property pure nothrow uint age() const
    {
        assert(!isSample);

        return this._age;
    }
    
    /**
     * Age of the chromosome - number of generation since chromosome was born
     * Can be used for altering chromosome fitness by age (to prefer new ones over the old ones)
     */
    @property pure nothrow void age(uint age)
    {
        assert(!isSample);

        this._age = age;
    }

    /**
     * Should this chromosome survive for the next generation?
     */
    @property pure nothrow bool survive() const
    {
        assert(!isSample);

        return this._survive;
    }
    
    /**
     * Set if this chromosome should survive for the next generation unchanged
     */
    @property pure nothrow void survive(bool survive)
    {
        assert(!isSample);

        this._survive = survive;
    }
    
    /**
     * Used by GA engine to clean up any resources
     */
    pure nothrow void clean()
    {
        assert(!isSample);

        scope(exit)
        {
            assert(_genes.length == 0);
        }

        foreach(gene; _genes)
        {
            gene.clean();
        }
        _genes.length = 0;
    }

    /**
     * Randomize chromosome genes
     */
    void randomize()
    {
        assert(!isSample);

        foreach(gene; _genes)
        {
            gene.setRandomValue();
        }
    }

    /**
     * Enable accessing individual genes with array index
     */
    pure nothrow T opIndex(size_t i)
    {
        return this._genes[i];
    }

    override string toString()
    {
        string tmp = to!string(typeid(this));
        tmp ~= "(";
        if(isSample) tmp ~= "SAMPLE, ";
        tmp ~= format("age: %s, ", _age);
        tmp ~= format("survive: %s, ", _survive);
        tmp ~= format("fitness: %s, ", _fitness);
        tmp ~= "[";
        foreach(g; _genes[0..$-1])
        {
            tmp ~= to!string(g);
            tmp ~= ", ";
        }
        tmp ~= to!string(_genes[$-1]);
        tmp ~= "])";

        return tmp;
    }
}

unittest
{
    import std.stdio;

    alias Chromosome!BoolGene chromoType;

    auto conf = new Configuration!chromoType(new chromoType(new BoolGene(), 10));
    auto chromo = new chromoType(conf);

    writefln("Chromosome: %s", chromo);
}