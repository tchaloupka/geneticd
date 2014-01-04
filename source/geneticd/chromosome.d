module geneticd.chromosome;

import std.conv;
import std.string;
import std.math : isNaN;

import geneticd.gene;
import geneticd.configuration;

interface IChromosome : ICloneable
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
     * Has chromosome already been evaluated?
     */
    @property pure nothrow bool isEvaluated() const;

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
    protected T[] _genes;
    protected configType _configuration;

    protected @property pure nothrow isSample() const
    {
        return _configuration is null;
    }

    /**
     * Chromosome constructor which uses a configuration sampleChromosome to initialization.
     * Random chromosome is initialized.
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
     * Chromosome constructor.
     * Random chromosome is initialized.
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
     * Age of the chromosome - number of generation since chromosome was born (0 means the chromosome was born in current generation)
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
     * Has chromosome already been evaluated?
     */
    @property pure nothrow bool isEvaluated() const
    {
        return !isNaN(_fitness);
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
        _fitness = double.init;
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

        _fitness = double.init;
    }

    /**
     * Mutate some of chromosome genes
     * 
     * Returns:
     *      number of mutated genes
     */
    uint mutate()
    out(result)
    {
        assert(result <= _genes.length);
        assert(isNaN(_fitness));
    }
    body
    {
        assert(!isSample);

        import std.random : uniform;

        uint numMutated = 0;
        
        foreach(i, gene; _genes)
        {
            //mutate each gene of chromosome with a given probability
            if(uniform(0.0, 1.0) <= _configuration.mutationProbability) 
            {
                _configuration.callbacks.invoke!"onBeforeMutate"(this, i);

                gene.mutate();
                numMutated++;

                _configuration.callbacks.invoke!"onAfterMutate"(this, i);
            }
        }

        _fitness = double.init;

        return numMutated;
    }

    /**
     * Enable accessing individual genes with array index
     */
    pure nothrow T opIndex(size_t i)
    {
        assert(i<this._genes.length);

        return this._genes[i];
    }

    override string toString() const
    {
        import std.string : lastIndexOf;

        string tmp = to!string(typeid(this));
        tmp = tmp[(tmp.lastIndexOf('.')+1)..$];
        tmp ~= "(";
        if(isSample) tmp ~= "SAMPLE, ";
        tmp ~= format("age: %s, ", _age);
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

    /**
     * Clone current instance of chromosome
     */
    Chromosome!T clone()
    out(result)
    {
        assert(result !is null);
        assert(result !is this);
    }
    body
    {
        auto tmp = new Chromosome!T(_configuration, this._genes);
        tmp._fitness = this._fitness;
        tmp._age = this._age;
        return tmp;
    }

    unittest
    {
        import std.math : isNaN;
        
        alias Chromosome!BoolGene chromoType;
        
        auto conf = new Configuration!chromoType(new chromoType(new BoolGene(), 10));
        auto chromo = new chromoType(conf);
        
        assert(!chromo.isEvaluated);
        assert(chromo.age == 0);
        assert(isNaN(chromo.fitness));
        assert(chromo._genes.length == 10);

        auto clone = chromo.clone();

        assert(chromo !is clone);
        assert(clone._genes.length == 10);
        foreach(i, g; chromo._genes)
        {
            assert(clone[i] == g);
            assert(clone[i] !is g);
        }
    }
}
