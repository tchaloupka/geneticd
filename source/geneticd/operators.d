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
    in
    {
    }
    body
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
 * Parents are selected randomly according to their rank, which is equal to their position in sorted list of chromosomes by their fitness.
 * Chromosomes with greater fitness have greater probability to be choosen as parents.
 * 
 * Note:
 * Linear ranking is used so all chromosomes have chance to be selected. But this can slower the convergence, because best chromosomes do not differ so much from the others.
 * Non linear solves this problem as it gives better chromosomes higher rank and worse chromosomes lower than with linear ranking.
 * 
 * Note:
 * Alias method is used to select parents.
 * 
 * See_Also:
 * http://www.geatbx.com/docu/algindex-02.html
 */
class RankSelection(T:IChromosome, bool linear = true) : SelectionBase!T
{
    import geneticd.utils : AliasMethodSelection;
    import std.algorithm : map;
    import std.array : array;
    
    private AliasMethodSelection!double _alias;
    private double _sp;

    static if(!linear)
    {
        import geneticd.utils : Polynom;
        private double _lastRoot;
        private size_t _lastSize;
        private double _lastSumRootPower;
    }

    /**
     * Calculation function for linear ranking
     * 
     * Params:
     *      pos = zero based index of item to rank. Note that 0 means the least fitted, length-1 means the fittest.
     *      length = number of individuals to rank
     *      selectivePressure = controls flattnes of rank function. 
     *                          It has to be in [1.0..2.0] range. 1 means flat (all individuals rank=1), 
     *                          2 means least flat (best has rank=2, worst has rank=0)
     */
    private static double getLinearRank(in size_t pos, in size_t length, in double selectivePressure)
    in
    {
        assert(pos<length);
        assert(length > 1);
        assert(selectivePressure >= 1.0 && selectivePressure <= 2.0);
    }
    out(result)
    {
        assert(result >= 0.0);
    }
    body
    {
        alias selectivePressure SP;
        return 2-SP+2*(SP-1)*pos/(length-1);
    }

    /**
     * Calculates the root for function: 0 = (SP-N).X^(N-1) + SP.X^(N-2) + ... + SP.X + SP
     * 
     * Params:
     *      length = number of individuals
     *      selectivePressure = must be in [1..N-2]
     *      sumRootPower = output of sumarized powers of root^(i) where i=[0..N-1]
     */
    private static double getNonLinearRoot(in size_t length, in double selectivePressure, out double sumRootPower)
    in
    {
        assert(length > 2);
        assert(selectivePressure >= 1.0 && selectivePressure <= length - 2);
    }
    out(result)
    {
        assert(result > 0.0);
        assert(sumRootPower > 0.0);
    }
    body
    {
        import std.math : pow;

        alias selectivePressure SP;

        double[] coeficients;
        coeficients.length = length;
        foreach(ref c; coeficients) c = SP;
        coeficients[$-1] = SP - length;

        auto poly = Polynom(coeficients);

//            if(SP == 3.0) root = 1.3573328;
//            else assert(false, "Not implemented");

        double root = poly.findRoot(2); //TODO: it is not guaranteed yet that it finds root > 0

        sumRootPower = 0;
        foreach(i; 0..length)
        {
            sumRootPower += pow(root, i);
        }

        return root;
    }

    /**
     * Calculation function for non linear ranking
     * 
     * Params:
     *      pos = zero based index of item to rank. Note that 0 means the least fitted, length-1 means the fittest.
     *      length = number of individuals to rank
     *      root = poly function root which is calculated with getNonLinearRoot function
     *      sumRootPower = precomputed sum of root powers in 0..N-1 interval
     */
    private static double getNonLinearRank(in size_t pos, in size_t length, in double root, in double sumRootPower)
    in
    {
        import std.math : isNaN;
        assert(!isNaN(root));
        assert(!isNaN(sumRootPower));
        assert(root > 0.0 && sumRootPower > 0.0);
    }
    out(result)
    {
        assert(result > 0.0);
    }
    body
    {
        import std.math : pow;
        return length * pow(root, pos) / sumRootPower;
    }

    this(in double selectivePressure)
    in
    {
        static if(linear) assert(selectivePressure >= 1.0 && selectivePressure <= 2.0);
    }
    body
    {
        _sp = selectivePressure;
    }

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
    in
    {
        static if(!linear) assert(_sp >= 1.0 && _sp <= population.chromosomes.length - 2);
    }
    body
    {
        immutable size_t N = population.chromosomes.length;

        size_t pos = N-1; //we start with N-1 because first chromosome is fittest and linear rank for 0 is the lowest

        //we need to create array of ranks for ordered chromosomes
        static if(linear)
        {
            _alias.init(
                population.chromosomes.map!(ch=>getLinearRank(pos--, N, _sp)).array, 
                );
        }
        else
        {
            if(_lastSize != N)
            {
                _lastSize = N;
                _lastRoot = getNonLinearRoot(N, _sp, _lastSumRootPower);
            }

            _alias.init(
                population.chromosomes.map!(ch=>getNonLinearRank(pos--, N, _lastRoot, _lastSumRootPower)).array, 
                );
        }
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

    unittest
    {
        import std.math : approxEqual;

        double[11] test;
        foreach(i; 0..11)
        {
            test[i] = getLinearRank(i, 11, 2.0);
        }

        assert(test == [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0]);

        double sum;
        auto root = getNonLinearRoot(11, 3.0, sum);
        assert(approxEqual(root, 1.357333));
        foreach(i; 0..11)
        {
            test[i] = getNonLinearRank(i, 11, root, sum);
        }

        assert(approxEqual(test[],[0.14, 0.19, 0.26, 0.35, 0.48, 0.65, 0.88, 1.20, 1.63, 2.21, 3.00]));

        root = getNonLinearRoot(11, 2.0, sum);
        assert(approxEqual(root, 1.1796301));
        foreach(i; 0..11)
        {
            test[i] = getNonLinearRank(i, 11, root, sum);
        }

        import std.stdio;
        writeln(test);

        assert(approxEqual(test[],[0.38, 0.45, 0.53, 0.63, 0.74, 0.88, 1.03, 1.22, 1.44, 1.70, 2.00]));
    }
}

/**
 * Tournament selection involves running several "tournaments" among a few individuals chosen at random from the population.
 * The winner of each tournament (the one with the best fitness) is selected for crossover.
 * Selection pressure is easily adjusted by changing the tournament size. If the tournament size is larger, 
 * weak individuals have a smaller chance to be selected.
 */
class TournamentSelection(T) : SelectionBase!T
{
    import std.random : uniform;
    import std.algorithm : sort;

    private T[] _tournament;
    private double _prob;

    this(in size_t tournamentSize, in double probability)
    in
    {
        assert(probability > 0.0 && probability <= 1.0);
        assert(tournamentSize > 0);
    }
    body
    {
        _tournament.length = tournamentSize;
        _prob = probability;
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
        tmp ~= getOne(population);
        tmp ~= getOne(population);
        
        return tmp;
    }

    private T getOne(Population!T population)
    {
        //choose random individuals to tournament
        foreach(i; 0.._tournament.length)
        {
            _tournament[i] = population.chromosomes[uniform(0, population.chromosomes.length)];
        }

        if(_tournament.length == 1) return _tournament[0]; //its just random select

        //sort tournament
        sort!"a.fitness > b.fitness"(_tournament);

        auto prob = uniform(0.0, 1.0);
        auto probAcc = _prob;

        // select by prob
        size_t idx;
        do
        {
            if(prob <= probAcc) break;
            else
            {
                probAcc += probAcc * (1 - _prob);
                idx++;
            }
        } while(idx < _tournament.length - 1);

        return _tournament[idx];
    }
}

/**
 * The individuals are mapped to contiguous segments of a line, such that each individual's segment is equal in size to its fitness exactly 
 * as in roulette-wheel selection. Here equally spaced pointers are placed over the line as many as there are individuals to be selected.
 * Consider N the number of individuals to be selected, then the distance between the pointers are 1/N and the position of the first pointer 
 * is given by a randomly generated number in the range [0, 1/N].
 * 
 * These pointers are prepared before actual selection, so when init is called, selection array of indexes to actual chromosomes is initialized.
 * When selecting, the random 2 parents are choosen from the selection array.
 * 
 * More fitted chromosomes can be more than once in selection array so it has a better chance to be selected as a parent.
 */
class StochasticUniversalSamplingSelection(T:IChromosome) : SelectionBase!T
{
    import std.random : uniform;

    private size_t[] _selection; //contains indexes of selected chromosomes from population to select from

    this(in size_t selectionSize)
    {
        _selection.length = selectionSize;
    }

    /**
     * Initialize the selection operator befor its usage.
     * It's used to prepare some calculations which are then used to select parent chromosomes.
     */
    protected override void initInternal(StatusInfo status, Population!T population)
    {
        auto dist = population.totalFitness/_selection.length;
        auto prob = uniform(0.0, dist); //initial probability
        auto sum = 0.0;
        size_t popIdx = 0;

        foreach(i; 0.._selection.length)
        {
            //add next chromosome from population
            while(sum < prob) sum += population[popIdx++].fitness;

            //add index of current chromosome to selection
            _selection[i] = popIdx-1; //as we are pointing on the next one
        }
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
        //just random select from selection list
        T[] tmp;
        tmp ~= population[uniform(0, _selection.length)];
        tmp ~= population[uniform(0, _selection.length)];

        return tmp;
    }
}

//TODO: NonLinearRankSelection

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
 * Crossover operator which randomly swaps each parent genes with the probability of 0.5.
 * So about 50% of genes are swapped between parents to make new offspring.
 */
class UniformCrossover(T:IChromosome) : ICrossoverOperator!T if(MemberFunctionsTuple!(T, "genes").length > 0)
{
    import std.random : uniform;
    import std.algorithm : swap;
    
    /// Execute crossover operator
    void cross(StatusInfo status, T[] chromosomes...)
        in
    {
        assert(chromosomes.length == 2);
        assert(chromosomes[0].genes.length == chromosomes[1].genes.length);
    }
    body
    {
        foreach(i; 0..chromosomes[0].genes.length)
        {
            if(uniform(0.0, 1.0) > 0.5) swap(chromosomes[0].genes[i], chromosomes[1].genes[i]);
        }

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
auto rankSelection(T:IChromosome, bool linear = true)(in double selectivePressure)
in
{
    static if(linear) assert(selectivePressure >= 1.0 && selectivePressure <= 2.0);
    else assert(selectivePressure >= 1.0);
}
body
{
    return new RankSelection!(T, linear)(selectivePressure);
}

/**
 * Helper function to create instance of TournamentSelection operator
 * 
 * Params:
 *      tournamentSize = size of tournament to select from
 *      probability = probability to select best chromosome of tournament
 */
auto tournamentSelection(T:IChromosome)(in size_t tournamentSize, in double probability)
{
    return new TournamentSelection!T(tournamentSize, probability);
}

/**
 * Helper function to create instance of StochasticUniversalSamplingSelection operator
 * 
 * Params:
 *      selectionSize = number of pointers to create to selection
 */
auto stochasticSelection(T:IChromosome)(in size_t selectionSize)
{
    return new StochasticUniversalSamplingSelection!T(selectionSize);
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

/**
 * Helper function to create instance of SinglePointCrossover operator
 */
auto uniformCrossover(T:IChromosome)()
{
    return new UniformCrossover!T();
}

//TODO: unittests
