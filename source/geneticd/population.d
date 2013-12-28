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
}
