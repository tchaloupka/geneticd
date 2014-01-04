module geneticd.operators;

import geneticd.chromosome;
import geneticd.population;
import geneticd.geneticalgorithm : StatusInfo;
import std.traits : MemberFunctionsTuple;

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
     * Initialize the selection operator befor its usage.
     * It's used to prepare some calculations which are then used to select parent chromosomes.
     */
    void init(StatusInfo status, Population!T population);

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

/**
 * Interface for crossover operators
 */
interface ICrossoverOperator(T:IChromosome)
{
    /// Execute crossover operator
    void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(chromosomes !is null && chromosomes.length > 0);
    }
    out
    {
        import std.algorithm : all;
        assert(chromosomes.all!(ch => ch.age == 0));
        assert(chromosomes.all!(ch => !ch.isEvaluated));
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
     * Initialize the selection operator befor its usage.
     * It's used to prepare some calculations which are then used to select parent chromosomes.
     */
    void init(StatusInfo status, Population!T population)
    {
        if(needSorted) population.sortChromosomes();
        initInternal(status, population);
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
        return selectInternal(population);
    }

    protected void initInternal(StatusInfo status, Population!T population)
    {
        //do nothing here
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
    protected override T[] selectInternal(Population!T population)
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
        tmp ~= population[uniform(0, _subSize)];
        tmp ~= population[uniform(0, _subSize)];

        return tmp;
    }
}

/**
 * Parents are selected randomly according to their weighted fitness probability.
 * Chromosomes with greater fitness have greater probability to be choosen as parents.
 * 
 * Note:
 * If some chromosome dominates with its fitness, than other solutions has little chance to be choosen.
 * 
 * Note:
 * Alias method is used to select parents.
 */
class WeightedRouletteSelection(T:IChromosome) : SelectionBase!T
{
    import geneticd.utils : AliasMethodSelection;
    import std.algorithm : map;
    import std.array : array;

    private AliasMethodSelection!double _alias;

    /**
     * Initialize the selection operator befor its usage.
     * It's used to prepare some calculations which are then used to select parent chromosomes.
     */
    protected override void initInternal(StatusInfo status, Population!T population)
    {
        _alias.init(population.chromosomes.map!(ch=>ch.fitness).array, population.totalFitness);
    }

    /**
     * Select some chromosomes from population
     */
    protected override T[] selectInternal(Population!T population)
    out(result)
    {
        assert(result.length == 2);
    }
    body
    {
        T[] tmp;
        tmp ~= population[_alias.next()];
        tmp ~= population[_alias.next()];
        
        return tmp;
    }
}

/**
 * Modification of WeightedRouletteSelection.
 * 
 * Parents are selected randomly according to their rank, which is determined from their fitness probability.
 * Chromosomes with greater fitness have greater probability to be choosen as parents.
 * 
 * Note:
 * All chromosomes have chance to be selected. But this can slower the convergence, because best chromosomes do not differ
 * so much from the others.
 * 
 * Note:
 * Alias method is used to select parents.
 */
class RankSelection(T:IChromosome) : SelectionBase!T
{
    import geneticd.utils : AliasMethodSelection;
    
    private AliasMethodSelection!double _alias;

    /**
     * Population chromosomes need to be sorted
     */
    @property pure nothrow override bool needSorted() const
    {
        return true; //we need them sorted so we can make ranks easily
    }

    /**
     * Initialize the selection operator befor its usage.
     * It's used to prepare some calculations which are then used to select parent chromosomes.
     */
    protected override void initInternal(StatusInfo status, Population!T population)
    {
        alias population.chromosomes.length N;

        //we need to create array of ranks for ordered chromosomes
        size_t rank = N; //rank of best chromosome = number of chromosomes
        _alias.init(
            population.chromosomes.map!(ch=>rank--).array, //best chromosome has rank N, next N-1, etc.
             (N*(N+1))/2); //sum of ranks
    }
    
    /**
     * Select some chromosomes from population
     */
    protected override T[] selectInternal(Population!T population)
    out(result)
    {
        assert(result.length == 2);
    }
    body
    {
        T[] tmp;
        tmp ~= population[_alias.next()];
        tmp ~= population[_alias.next()];
        
        return tmp;
    }
}

//TODO: TournamentSelection

/**
 * Simple crossover operator which randomly select index of gene and swap genes of parents after that index
 */
class SinglePointCrossover(T:IChromosome) : ICrossoverOperator!T if(MemberFunctionsTuple!(T, "genes").length > 0)
{
    import std.random : uniform;
    import std.algorithm : swapRanges;

    /// Execute crossover operator
    void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(chromosomes.length == 2);
        assert(chromosomes[0].genes.length == chromosomes[1].genes.length);
    }
    body
    {
        auto idx = uniform(0, chromosomes[0].genes.length);

        swapRanges(chromosomes[0].genes[idx..$], chromosomes[1].genes[idx..$]);
        foreach(ch; chromosomes)
        {
            ch.age = 0;
            ch.fitness = double.init;
        }
    }
}

/**
 * Simple crossover operator which randomly select 2 indexes of gene and swap middle genes of parents
 */
class TwoPointCrossover(T:IChromosome) : ICrossoverOperator!T if(MemberFunctionsTuple!(T, "genes").length > 0)
{
    import std.random : uniform;
    import std.algorithm : swapRanges, swap;
    
    /// Execute crossover operator
    void cross(StatusInfo status, T[] chromosomes...)
        in
    {
        assert(chromosomes.length == 2);
        assert(chromosomes[0].genes.length == chromosomes[1].genes.length);
    }
    body
    {
        auto idx1 = uniform(0, chromosomes[0].genes.length);
        auto idx2 = uniform(0, chromosomes[0].genes.length);
        if(idx1 > idx2) swap(idx1, idx2);
        
        swapRanges(chromosomes[0].genes[idx1..idx2+1], chromosomes[1].genes[idx1..idx2+1]);
        foreach(ch; chromosomes)
        {
            ch.age = 0;
            ch.fitness = double.init;
        }
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

/**
 * Helper function to create instance of WeightedRouletteSelection operator
 */
auto weightedRouletteSelection(T:IChromosome)()
{
    return new WeightedRouletteSelection!T();
}

/**
 * Helper function to create instance of RankSelection operator
 */
auto rankSelection(T:IChromosome)()
{
    return new RankSelection!T();
}

/**
 * Helper function to create instance of SinglePointCrossover operator
 */
auto singlePointCrossover(T:IChromosome)()
{
    return new SinglePointCrossover!T();
}

/**
 * Helper function to create instance of SinglePointCrossover operator
 */
auto twoPointCrossover(T:IChromosome)()
{
    return new TwoPointCrossover!T();
}

//TODO: unittests
