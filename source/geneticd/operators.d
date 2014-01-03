module geneticd.operators;

import geneticd.chromosome;
import geneticd.population;

/**
 * Interface of genetic selection operators.
 * They are used to select parent chromosomes for crossover to the next population generation.
 */
interface ISelectionOperator(T:IChromosome)
{
    /**
     * Population chromosomes need to be sorted
     */
    @property pure nothrow bool needSorted() const;

    /**
     * Select some chromosomes from population
     */
    T[] select(Population!T population)
    in
    {
        assert(population !is null);
        assert(population.chromosomes !is null);
        assert(!needSorted || population.sorted);
    }
}

abstract class SelectionBase(T:IChromosome) : ISelectionOperator!T
{
    /**
     * Population chromosomes need to be sorted
     */
    @property pure nothrow bool needSorted() const
    {
        return false;
    }

    /**
     * Select some chromosomes from population
     */
    T[] select(Population!T population)
    in
    {
        assert(false); //because currently this is the only way to use contract from interface
    }
    body
    {
        if(needSorted) population.sortChromosomes();
        return selectInternal(population);
    }

    protected abstract T[] selectInternal(Population!T population);
}

/**
 * Selection operator used to select elite chromosomes from the current population which are used in the new population without any change.
 * This allows to survive the best chromosomes found yet.
 */
class EliteSelection(T:IChromosome) : SelectionBase!T
{
    private uint _numElite;

    /**
     * Population chromosomes need to be sorted
     */
    @property pure nothrow override bool needSorted() const
    {
        return true;
    }

    /**
     * Constructor
     * 
     * Params:
     *      numElite = number of elite chromosomes to select
     */
    this(uint numElite)
    {
        assert(numElite > 0);

        this._numElite = numElite;
    }

    /**
     * Select some chromosomes from population
     */
    pure nothrow protected override T[] selectInternal(Population!T population)
    {
        return population.chromosomes[0.._numElite];
    }
}


/**
 * Simple selection operator which repeatedly selects parents from the better some slice of original chromosomes
 */
class TruncationSelection(T:IChromosome) : SelectionBase!T
{
    import std.random : uniform;

    private uint _subSize;

    /**
     * Population chromosomes need to be sorted
     */
    @property pure nothrow override bool needSorted() const
    {
        return true;
    }
    
    /**
     * Constructor
     * 
     * Params:
     *      subSize = number of chromosomes to select from. It needs to be < size of the population
     */
    this(uint subSize)
    {
        assert(subSize > 1);
        
        this._subSize = subSize;
    }
    
    /**
     * Select some chromosomes from population
     */
    protected override T[] selectInternal(Population!T population)
    in
    {
        assert(population.chromosomes.length >= _subSize);
    }
    out(result)
    {
        assert(result.length == 2);
    }
    body
    {
        T[] tmp;
        tmp ~= population.chromosomes[uniform(0, _subSize)];
        tmp ~= population.chromosomes[uniform(0, _subSize)];

        return tmp;
    }
}

/**
 * Helper function to create instance of EliteSelection operator
 */
auto eliteSelection(T:IChromosome)(uint numElite = 1)
{
    return new EliteSelection!T(numElite);
}

/**
 * Helper function to create instance of TruncationSelection operator
 */
auto truncationSelection(T:IChromosome)(uint subSize)
{
    return new TruncationSelection!T(subSize);
}

//TODO: unittests