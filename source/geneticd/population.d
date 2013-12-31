module geneticd.population;

import std.algorithm;

import geneticd.chromosome;
import geneticd.configuration;

class Population(T:IChromosome)
{
    private Configuration!T _configuration;
    private T[] _chromosomes;
    private T _best;
    private bool _changed;
    
    /// Create a population
    public this(Configuration!T configuration)
    {
        assert(configuration !is null);

        this._configuration = configuration;
        initRandom();
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
        foreach(ch; _chromosomes.filter!(a=>!a.isEvaluated))
        {
            ch.fitness = _configuration.fitnessFunction.evaluate(ch);
            if((this._best is null) || this._best.fitness < ch.fitness) this._best = ch;
            evaluated++;
        }

        return evaluated;
    }

    /// List of chromosomes
    /// 
    /// Returns:
    ///     list of chromosomes
    @property T[] chromosomes()
    {
        return _chromosomes;
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
}
