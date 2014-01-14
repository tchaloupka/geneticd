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

/**
 * Interface for mutation operators
 */
interface IMutationOperator(T:IChromosome)
{
    /// Execute mutate operator
    void mutate(T chromosome, size_t idx)
    in
    {
        assert(chromosome !is null);
        assert(chromosome.genes.length > idx);
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

    this(in double selectivePressure)
    in
    {
        static if(linear) assert(selectivePressure >= 1.0 && selectivePressure <= 2.0);
    }
    body
    {
        _sp = selectivePressure;
    }

    static if(!linear)
    {
        import geneticd.utils : Polynomial;
        private double _lastRoot;
        private size_t _lastSize;
        private double _lastSumRootPower;

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
            import std.math : pow, approxEqual;
            import std.algorithm : filter;

            alias selectivePressure SP;

            double[] coeficients;
            coeficients.length = length;
            foreach(ref c; coeficients) c = SP;
            coeficients[0] = SP - length;

            auto poly = Polynomial(coeficients);
            auto roots = poly.findRoots().filter!(a=>approxEqual(a.im, 0) && a.re > 0); //we want real root > 0
            if(roots.empty) assert(false, "No real root found!");
            double root = roots.front.re;

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
    }
    else
    {
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
        import geneticd.gene;

        alias RankSelection!(Chromosome!(ScalarGene!bool), true) linearRank;
        alias RankSelection!(Chromosome!(ScalarGene!bool), false) nonLinearRank;

        double[11] test;
        foreach(i; 0..11)
        {
            test[i] = linearRank.getLinearRank(i, 11, 2.0);
        }

        assert(test == [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0]);

        double sum;
        auto root = nonLinearRank.getNonLinearRoot(11, 3.0, sum);
        assert(approxEqual(root, 1.357333));
        foreach(i; 0..11)
        {
            test[i] = nonLinearRank.getNonLinearRank(i, 11, root, sum);
        }

        assert(approxEqual(test[],[0.14, 0.19, 0.26, 0.35, 0.48, 0.65, 0.88, 1.20, 1.63, 2.21, 3.00]));

        root = nonLinearRank.getNonLinearRoot(11, 2.0, sum);
        assert(approxEqual(root, 1.1796301));
        foreach(i; 0..11)
        {
            test[i] = nonLinearRank.getNonLinearRank(i, 11, root, sum);
        }

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

/**
 * Base class for crossover operators which can work with chromosomes with a fixed number of genes
 */
abstract class FixedLengthCrossoverBase(T:IChromosome) : ICrossoverOperator!T if(MemberFunctionsTuple!(T, "genes").length > 0)
{
    import std.algorithm : all;

    /// Execute crossover operator
    abstract void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(chromosomes.length == 2);
        assert(all!"a.isFixedLength"(chromosomes), "Only fixed length chromosomes can be changed with this operator");
        assert(all!"!a.isPermutation"(chromosomes), "This crossover will break ordered chromosome. Use some ordered crossover instead.");
        assert(chromosomes[0].genes.length == chromosomes[1].genes.length);
    }
    body{}
}

/**
 * Base class for crossover operators which can work with chromosomes with a fixed number of genes with permutation
 */
abstract class PermutationCrossoverBase(T:IChromosome) : ICrossoverOperator!T if(MemberFunctionsTuple!(T, "genes").length > 0)
{
    import std.algorithm : all;
    
    /// Execute crossover operator
    abstract void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(chromosomes.length == 2);
        assert(all!"a.isFixedLength"(chromosomes), "Only fixed length chromosomes can be changed with this operator");
        assert(chromosomes[0].genes.length == chromosomes[1].genes.length);
    }
    body{}
}

/**
 * Simple crossover operator which randomly select index of gene and swap genes of parents after that index
 */
class SinglePointCrossover(T:IChromosome) : FixedLengthCrossoverBase!T
{
    import std.random : uniform;
    import std.algorithm : swapRanges;

    /// Execute crossover operator
    override void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(false);
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
class TwoPointCrossover(T:IChromosome) : FixedLengthCrossoverBase!T
{
    import std.random : uniform;
    import std.algorithm : swapRanges, swap;
    
    /// Execute crossover operator
    override void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(false);
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
 * UX Crossover operator which randomly swaps each parent genes with the probability of 0.5.
 * So about 50% of genes are swapped between parents to make new offspring.
 */
class UniformCrossover(T:IChromosome) : FixedLengthCrossoverBase!T
{
    import std.random : uniform;
    import std.algorithm : swap;
    
    /// Execute crossover operator
    override void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(false);
    }
    body
    {
        foreach(i; 0..chromosomes[0].genes.length)
        {
            if(chromosomes[0].genes[i] != chromosomes[1].genes[i] && uniform(0.0, 1.0) > 0.5) //uniform swap if genes differ
                swap(chromosomes[0].genes[i], chromosomes[1].genes[i]);
        }

        foreach(ch; chromosomes)
        {
            ch.age = 0;
            ch.fitness = double.init;
        }
    }
}

/**
 * In HUX crossover, only half of the bits that are different will be exchanged.
 * For this purpose, first it is calculated the number of different bits (Hamming distance) between the parents.
 * The half of this number is the number of bits exchanged between parents to form the childs.
 */
class HalfUniformCrossover(T:IChromosome) : FixedLengthCrossoverBase!T
{
    import std.random : randomShuffle;
    import std.algorithm : swap;
    
    /// Execute crossover operator
    override void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(false);
    }
    body
    {
        size_t[] toChange;

        //find what genes can be changed
        foreach(i; 0..chromosomes[0].genes.length)
        {
            if(chromosomes[0].genes[i] != chromosomes[1].genes[i]) toChange ~= i;
        }

        //random shuffle the indexes list
        randomShuffle(toChange);

        //and swap half of them
        foreach(idx; toChange[0..$/2])
        {
            swap(chromosomes[0].genes[idx], chromosomes[1].genes[idx]);
        }
        
        foreach(ch; chromosomes)
        {
            ch.age = 0;
            ch.fitness = double.init;
        }
    }
}

/**
 * Perform ordered crossover (OX) on the specified tours.
 * 
 * Ordered crossover works in two stages. First, a random slice is swapped between the two tours, as in a two-point crossover.
 * Second, repeated genes not in the swapped area are removed, and the remaining integers are added
 * from the other tour, in the order that they appear starting from the end index of the swapped section.
 * 
 * Example:
 *  Parent 1: 8 4 7 | 3 6 2 5 1 | 9 0
 *  Parent 2: 0 1 2 | 3 4 5 6 7 | 8 9
 *  Child  1: 0 4 7   3 6 2 5 1   8 9
 *  Child  2: 8 2 1   3 4 5 6 7   9 0
 */
class OrderedCrossover(T:Chromosome!U, U) : PermutationCrossoverBase!T
{
    import std.random : uniform;
    import std.algorithm : filter, canFind, swap;
    import std.array : array, insertInPlace;
    
    /// Execute crossover operator
    override void cross(StatusInfo status, T[] chromosomes...)
    in
    {
        assert(false);
    }
    body
    {
        size_t size = chromosomes[0].genes.length;
        auto start = uniform(0, size);
        auto end = uniform(0, size);
        if(start > end) swap(start, end);
        
        U[] o1 = ox(start, end, chromosomes[0].genes, chromosomes[1].genes);
        U[] o2 = ox(start, end, chromosomes[1].genes, chromosomes[0].genes);
        
        assert(o1.length == o2.length);
        assert(o1.length == size);
        
        //set age, fitness and new genes
        foreach(i, ch; chromosomes)
        {
            ch.age = 0;
            ch.fitness = double.init;
            ch.genes = i==0? o1 : o2;
        }
    }

    private static V[] ox(V)(in size_t start, in size_t end, V[] p1, V[] p2)
    {
        assert(start <= end);
        assert(p1.length == p2.length);

        import std.algorithm : canFind, copy;

        V[] tmp;
        tmp.length = p1.length;

        //copy subrange
        copy(p1[start..end+1], tmp[start..end+1]);

        size_t pIdx = end+1; //we begin to fill from the right side of subrange
        size_t idx = end+1;

        while(idx < p1.length) //fill end
        {
            if(!canFind(tmp[start..end+1], p2[pIdx]))
                tmp[idx++] = p2[pIdx];

            if(++pIdx == p1.length)
                pIdx = 0; //start from the beginning of parent
        }

        idx = 0;
        if(pIdx == p1.length) pIdx = 0; //if end is last index of parent

        while(idx < start) //fill the rest
        {
            if(!canFind(tmp[start..end+1], p2[pIdx]))
                tmp[idx++] = p2[pIdx];
            pIdx++;
        }

        return tmp;
    }

    unittest
    {
        //Test 1:
        auto p1 = [8, 4, 7, 3, 6, 2, 5, 1, 9, 0];
        auto p2 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

        auto o1 = ox(3, 7, p1, p2);
        auto o2 = ox(3, 7, p2, p1);

        assert(o1 == [0, 4, 7, 3, 6, 2, 5, 1, 8, 9]);
        assert(o2 == [8, 2, 1, 3, 4, 5, 6, 7, 9, 0]);

        //Test2
        p1 = [8, 4, 7, 3, 6, 2, 5, 1];
        p2 = [0, 1, 2, 3, 4, 5, 6, 7];

        o1 = ox(3, 7, p1, p2);
        o2 = ox(3, 7, p2, p1);

        assert(o1 == [0, 4, 7, 3, 6, 2, 5, 1]);
        assert(o2 == [8, 2, 1, 3, 4, 5, 6, 7]);

        //Test 3:
        p1 = [1, 4, 2, 8, 5, 7, 3, 6, 9];
        p2 = [7, 5, 3, 1, 9, 8, 6, 4, 2];

        o1 = ox(3, 6, p1, p2);
        o2 = ox(3, 6, p2, p1);

        assert(o1 == [1, 9, 6, 8, 5, 7, 3, 4, 2]);
        assert(o2 == [5, 7, 3, 1, 9, 8, 6, 4, 2]);
    }
}

/**
 * Partialy mapped crossover (PMX).
 * 
 * The PMX builds an offspring by choosing a subsequence of a tour from one parent preserving the order and position of as many positions as possible 
 * from the other parent.
 * 
 * Example:
 *  Parent 1: 1 4 2 | 8 5 7 3 | 6 9
 *  Parent 2: 7 5 3 | 1 9 8 6 | 4 2
 *  Child  1: 7 4 2   1 9 8 6   3 5
 *  Child  2: 1 9 6   8 5 7 3   4 2
 */
class PMXCrossover(T:Chromosome!U, U) : PermutationCrossoverBase!T
{
    import std.random : uniform;
    import std.algorithm : filter, canFind, swap;
    import std.array : array, insertInPlace;
    
    /// Execute crossover operator
    override void cross(StatusInfo status, T[] chromosomes...)
        in
    {
        assert(false);
    }
    body
    {
        size_t size = chromosomes[0].genes.length;
        auto start = uniform(0, size);
        auto end = uniform(0, size);
        if(start > end) swap(start, end);
        
        U[] o1 = ox(start, end, chromosomes[0].genes, chromosomes[1].genes);
        U[] o2 = ox(start, end, chromosomes[1].genes, chromosomes[0].genes);
        
        assert(o1.length == o2.length);
        assert(o1.length == size);
        
        //set age, fitness and new genes
        foreach(i, ch; chromosomes)
        {
            ch.age = 0;
            ch.fitness = double.init;
            ch.genes = i==0? o1 : o2;
        }
    }
    
    private static V[] ox(V)(in size_t start, in size_t end, V[] p1, V[] p2)
    {
        assert(start <= end);
        assert(p1.length == p2.length);

        bool canFind(V[] slice, V item, ref size_t idx)
        {
            idx = 0;
            while(idx != slice.length && slice[idx] != item) idx++;
            return idx < slice.length;
        }
        
        V[] tmp;
        tmp.length = p1.length;
        size_t idx, tmpIdx;

        foreach(i; 0..p1.length)
        {
            if(i >= start && i <= end) //just copy from p2
            {
                tmp[i] = p2[i];
            }
            else if(!canFind(p2[start..end+1], p1[i], idx)) //add original gene from p1
            {
                tmp[i] = p1[i];
            }
            else
            {
                //find mapped
                tmpIdx = idx;
                while(canFind(p2[start..end+1], p1[start+idx], idx))
                {
                    tmpIdx = idx;
                }
                tmp[i] = p1[start+tmpIdx];
            }
        }

        return tmp;
    }
    
    unittest
    {
        import std.stdio;

        auto p1 = [1, 4, 2, 8, 5, 7, 3, 6, 9];
        auto p2 = [7, 5, 3, 1, 9, 8, 6, 4, 2];
        
        auto o1 = ox(3, 6, p1, p2);
        auto o2 = ox(3, 6, p2, p1);

        writeln(o1);
        writeln(o2);
        
        assert(o1 == [7, 4, 2, 1, 9, 8, 6, 3, 5]);
        assert(o2 == [1, 9, 6, 8, 5, 7, 3, 4, 2]);
    }
}

//TODO: Cycle crossover
//TODO: Cut and splice crossover for variable length chromosomes

/**
 * Simple mutate operator to create mutate operators with delegate functions
 */
class SimpleMutationOperator(T:IChromosome) : IMutationOperator!T
{
    void delegate(T, size_t) _mutateFunc;
    
    this(void delegate(T, size_t) func)
    {
        _mutateFunc = func;
    }

    /// Execute mutate operator
    void mutate(T chromosome, size_t idx)
    {
        _mutateFunc(chromosome, idx);
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
 * Helper function to create instance of TwoPointCrossover operator
 */
auto twoPointCrossover(T:IChromosome)()
{
    return new TwoPointCrossover!T();
}

/**
 * Helper function to create instance of UniformCrossover operator
 */
auto uniformCrossover(T:IChromosome)()
{
    return new UniformCrossover!T();
}

/**
 * Helper function to create instance of HalfUniformCrossover operator
 */
auto halfUniformCrossover(T:IChromosome)()
{
    return new HalfUniformCrossover!T();
}

/**
 * Helper function to create instance of OrderedCrossover operator
 */
auto orderedCrossover(T:IChromosome)()
{
    return new OrderedCrossover!T();
}

/**
 * Helper function to create instance of PMXCrossover operator
 */
auto pmxCrossover(T:IChromosome)()
{
    return new PMXCrossover!T();
}

/**
 * Uniform mutation operator. Simply set gene value with random value from defined range.
 */
auto uniformMutation(T:IChromosome)()
{
    return new SimpleMutationOperator!T((ch, idx)
    {
        assert(!ch.isPermutation, "This mutation will break ordered chromosome. Use some mutation that takes care of this (for example swapMutation).");

        ch[idx].mutate();
    });
}

/**
 * Mutation operator that swaps two randomly selected genes.
 */
auto swapMutation(T:IChromosome)()
{
    return new SimpleMutationOperator!T((ch, idx)
    {
        import std.random : uniform;

        auto idx2 = uniform(0, ch.genes.length);
        auto tmp = ch.genes[idx];
        ch.genes[idx] = ch.genes[idx2];
        ch.genes[idx2] = tmp;
    });
}

//TODO: unittests
