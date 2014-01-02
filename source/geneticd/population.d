module geneticd.population;

import std.algorithm;

import geneticd.chromosome;
import geneticd.configuration;

class Population(T:IChromosome)
{
    private Configuration!T _configuration;
    private T[] _chromosomes;
    private T _best;
    private double _totalFitness;
    private bool _changed;
    private bool _evaluated;
    private bool _sorted;
    
    /**
     * Create a population
     * 
     * Params:
     *      configuration = configuration of GA
     *      init = if true, the population is initialized with random chromosomes
     */
    public this(Configuration!T configuration, bool init = true)
    {
        assert(configuration !is null);

        this._configuration = configuration;
        if(init) initRandom();
    }
    
    /// The best genome of the population
    @property pure nothrow T best()
    {
        return this._best;
    }

    /**
     * Indicates wheather at leas one of the chromosomes has been changed with any of the genetic operations
     */
    @property pure nothrow bool changed() const
    {
        return this._changed;
    }

    private void initRandom()
    {
        assert(_configuration.sampleChromosome !is null);

        _chromosomes.length = _configuration.populationSize;
        foreach(i; 0.._configuration.populationSize)
        {
            _chromosomes[i] = new T(_configuration);
        }
    }

    /// evaluate fitness of all not evaluated chromosomes in population
    /// 
    /// Returns:
    ///     number of evaluated chromosomes
    size_t fitness()
    {
        scope(exit)
        {
            assert(this._best !is null);
        }

        size_t evaluated;
        _totalFitness = 0;
        foreach(ch; _chromosomes.filter!(a=>!a.isEvaluated))
        {
            ch.fitness = _configuration.fitnessFunction.evaluate(ch);
            _totalFitness += ch.fitness;
            if((this._best is null) || this._best.fitness < ch.fitness) this._best = ch;
            evaluated++;
        }

        _changed = false;
        _evaluated = true;

        return evaluated;
    }

    /**
     * List of chromosomes
     * 
     * Returns:
     *      list of chromosomes
     */
    @property pure nothrow T[] chromosomes()
    {
        return _chromosomes;
    }

    /**
     * Returns the summed fitness of all chromosomes
     */
    @property pure nothrow double totalFitness() const
    {
        return _totalFitness;
    }

    /**
     * Are population chromosomes evaluated?
     */
    @property pure nothrow bool evaluated() const
    {
        return _evaluated;
    }

    /**
     * Are population chromosomes sorted?
     */
    @property pure nothrow bool sorted() const
    {
        return _sorted;
    }

    override string toString() const
    {
        import std.conv : to;

        string tmp = "Population(\n";

        foreach(ch; _chromosomes)
        {
            tmp ~= to!string(ch) ~ "\n";
        }

        tmp ~= ")";

        return tmp;
    }

    /// Assign operator so we can manually extend chromosomes in population
    Population!T opOpAssign(string op)(T[] chromosome...) if(op == "~")
    {
        assert(chromosome !is null);

        _chromosomes ~= chromosome;
        _changed = true;
        _sorted = false;
        _evaluated = false;
        return this;
    }

    void sortChromosomes()
    {
        assert(_evaluated);

        if(!_sorted) // sort only if not sorted yet
        {
            sort!"a.fitness > b.fitness"(_chromosomes);
            _sorted = true;
        }
    }
}
