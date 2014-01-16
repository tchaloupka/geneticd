module geneticd.chromosome;

import std.conv;
import std.string;
import std.math : isNaN;

import geneticd.gene;
import geneticd.configuration;

interface IChromosome : ICloneable!IChromosome
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
     * The real fitness of this chromosome. It means not altered via AlterFitness function.
     */
    @property pure nothrow double realFitness() const;
    
    /**
     * Set the fitness of this chromosome. It means not altered via AlterFitness function.
     */
    @property pure nothrow void realFitness(double fitness);

    /**
     * Has chromosome already been evaluated?
     */
    @property pure nothrow bool isEvaluated() const;

    /**
     * Used by GA engine to clean up any resources
     */
    pure nothrow void clean();
}

/**
 * Represents an individual solution which consost of fixed number of genes
 */
class Chromosome(T:IGene!G, G) : IChromosome
{
    alias Configuration!(Chromosome!T) configType;

    protected double _fitness;
    protected double _realFitness;
    protected uint _age;
    protected T[] _genes;
    protected configType _configuration;
    protected bool _isPermutation;
    protected bool _isFixedLength = true;

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
    this(ref configType configuration)
    {
        assert(configuration !is null);
        assert(configuration.sampleChromosome !is null);

        auto sample = cast(Chromosome!T)configuration.sampleChromosome;
        if(!sample) assert(false);
        assert(sample._genes.length > 0);

        if(sample.isPermutation)
        {
            assert(sample.isFixedLength, "Only fixed length permutation chromosomes supported");
            this(configuration, sample);
        }
        else
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
     * Special constructor to make sample chromosome
     */
    this(T[] sampleGenes)
    {
        assert(sampleGenes.length > 0);
        
        this._genes = sampleGenes;
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
    this(ref configType configuration, T sampleGene, size_t size)
    in
    {
        assert(configuration !is null);
        assert(sampleGene !is null);
        assert(size > 0);
    }
    out
    {
        assert(!_isFixedLength || this._genes.length == size);
    }
    body
    {
        import std.random : uniform;

        this._configuration = configuration;
        this._isFixedLength = configuration.sampleChromosome.isFixedLength;
        this._isPermutation = configuration.sampleChromosome.isPermutation;
        foreach(i; 0..(_isFixedLength ? size : uniform(0, size)))
        {
            this._genes ~= cast(T)sampleGene.clone();
        }
        randomize();
    }

    /**
     * Chromosome constructor.
     * Random chromosome is initialized according to sample.
     * 
     * Params:
     *      configuration = GA configuration
     *      sampleChromosome = sample chromosome to help create new one
     */
    this(ref configType configuration, Chromosome!T sampleChromosome)
    in
    {
        assert(configuration !is null);
        assert(sampleChromosome !is null);
        assert(sampleChromosome.isSample);
    }
    out
    {
        assert(this._genes.length == sampleChromosome.genes.length);
    }
    body
    {
        this._configuration = configuration;
        this._isPermutation = sampleChromosome._isPermutation;
        this._isFixedLength = sampleChromosome._isFixedLength;

        foreach(g; sampleChromosome.genes)
        {
            assert(g !is null, "Sample chromosome has null sample genes!");
            this._genes ~= cast(T)g.clone();
        }
        randomize();
    }

    /**
     * Chromosome constructor to set exact genes of chromosome.
     * 
     * Params:
     *      configuration = GA configuration
     *      initialGenes = initial set of genes
     */
    this(ref configType configuration, T[] initialGenes)
    {
        assert(configuration !is null);
        assert(!configuration.sampleChromosome.isFixedLength || initialGenes.length > 0);

        scope(exit)
        {
            assert(_genes.length == initialGenes.length);
        }
        
        this._configuration = configuration;
        this._genes = initialGenes;
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
     * The real fitness of this chromosome. It means not altered via AlterFitness function.
     */
    @property pure nothrow double realFitness() const
    {
        assert(!isSample);
        
        return this._realFitness;
    }
    
    /**
     * Set the fitness of this chromosome. It means not altered via AlterFitness function.
     */
    @property pure nothrow void realFitness(double fitness)
    {
        assert(!isSample);
        
        this._realFitness = fitness;
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
     * True if chromosome consists of unique set of genes which can't be randomized
     */
    @property pure nothrow bool isPermutation() const
    {
        return _isPermutation;
    }

    /**
     * True if chromosome consists of unique set of genes which can't be randomized
     */
    @property pure nothrow void isPermutation(bool value)
    {
        _isPermutation = value;
    }

    /**
     * True if chromosome can't change number of genes. Default is true.
     */
    @property pure nothrow bool isFixedLength() const
    {
        return _isFixedLength;
    }
    
    /**
     * True if chromosome can't change number of genes. Default is true.
     */
    @property pure nothrow void isFixedLength(bool value)
    {
        _isFixedLength = value;
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
    private void randomize()
    {
        assert(!isSample);

        if(_isPermutation)
        {
            import std.random : randomShuffle;
            randomShuffle(_genes);
        }
        else
        {
            foreach(gene; _genes)
            {
                gene.setRandomValue();
            }
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
        
        foreach(i; 0.._genes.length)
        {
            //mutate each gene of chromosome with a given probability
            if(uniform(0.0, 1.0) <= _configuration.mutationProbability) 
            {
                _configuration.callbacks.invoke!"onBeforeGeneMutate"(this, i);

                assert(_configuration.mutationOperator !is null);
                _configuration.mutationOperator.mutate(this, i);
                numMutated++;

                _configuration.callbacks.invoke!"onAfterGeneMutate"(this, i);
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

    /**
     * Genes of chromosome
     */
    @property pure nothrow T[] genes()
    {
        return _genes;
    }

    /**
     * Genes of chromosome
     */
    @property pure nothrow const(T[]) genes() const
    {
        return _genes;
    }

    /**
     * Genes of chromosome
     */
    @property pure nothrow genes(T[] genes)
    {
        assert(!_isFixedLength || _genes.length == genes.length);

        this._genes = genes;
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
        if(_genes.length > 0)
        {
            foreach(g; _genes[0..$-1])
            {
                tmp ~= to!string(g);
                tmp ~= ", ";
            }
            tmp ~= to!string(_genes[$-1]);
        }
        tmp ~= "])";

        return tmp;
    }

    /**
     * Clone current instance of chromosome
     */
    typeof(this) clone()
    out(result)
    {
        assert(result !is null);
        assert(result !is this);
        assert(result.isEvaluated == this.isEvaluated);
    }
    body
    {
        T[] tmpGenes;
        foreach(g; _genes)
        {
            tmpGenes ~= cast(T)g.clone();
        }

        auto tmp = new Chromosome!T(_configuration, tmpGenes);
        tmp._fitness = this._fitness;
        tmp._realFitness = this._realFitness;
        tmp._age = this._age;
        tmp._isPermutation = this._isPermutation;
        tmp._isFixedLength = this._isFixedLength;
        return tmp;
    }

    unittest
    {
        import std.math : isNaN;
        
        alias Chromosome!(ScalarGene!bool) chromoType;
        
        auto conf = new Configuration!chromoType(new chromoType(new ScalarGene!bool(), 10));
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
