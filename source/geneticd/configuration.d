module geneticd.configuration;

import geneticd.chromosome;
import geneticd.fitness;
import geneticd.terminate;
import geneticd.geneticalgorithm;
import geneticd.operators;

/**
 * Configuration parameters for GA evaluation
 */
class Configuration(T:IChromosome)
{
    struct Callbacks
    {
        import std.traits : isDelegate;
        import std.string : format;

        /// Called when initial population is initialized
        void delegate(StatusInfo) onInitialPopulation;

        /// Called when fitness is determined for all chromosomes in current population
        void delegate(StatusInfo) onFitness;

        /// Called when elite chromosomes are selected
        void delegate(T[] elite) onElite;

        /// Called when chromosome is going to be mutated
        void delegate(T chromosome, size_t geneIdx) onBeforeMutate;

        /// Called when chromosome has been mutated
        void delegate(T chromosome, size_t geneIdx) onAfterMutate;

        void invoke(alias Callback,U...)(U params)
        {
            mixin(format("if(%s !is null) try{ %s(params);} catch{}", Callback, Callback));
        }
    }

    private uint _populationSize = 100;
    private T _sampleChromosome;
    private IFitnessFunction!T _fitnessFunc;
    private ITerminateFunction _terminateFunc;
    private ISelectionOperator!T _eliteSelectionOperator;
    private ISelectionOperator!T _parentSelectionOperator;
    private double _crossoverProbability = 0.8;
    private double _mutationProbability = 0.01;

    /// Simple struct to hold callback delegates
    Callbacks callbacks;

    /// Default constructor
    this()
    {

    }

    /**
     * Constructor
     * 
     * Params:
     *      sampleChromosome = chromosome used to specify how each chromosome of the population should look alike, its used for population generation
     *      populationSize = defines the population size
     */
    this(T sampleChromosome, uint populationSize = 100)
    {
        this._sampleChromosome = sampleChromosome;
        this._populationSize = populationSize;
        this._terminateFunc = maxGenerationsTerminate!100;
    }

    /**
     * Constructor
     * 
     * Params:
     *      sampleChromosome = chromosome which is used to specify how each chromosome of the population should look alike, its used for population generation
     *      fitnessFunc = function used to evaluate fitness of each chromosome of the population before each evolution
     *      populationSize = defines the population size
     */
    this(T sampleChromosome, IFitnessFunction!T fitnessFunc, uint populationSize = 100)
    {
        this._sampleChromosome = sampleChromosome;
        this._fitnessFunc = fitnessFunc;
        this._populationSize = populationSize;
        this._terminateFunc = maxGenerationsTerminate!100;
    }

    /**
     * Constructor
     * 
     * Params:
     *      sampleChromosome = chromosome which is used to specify how each chromosome of the population should look alike, its used for population generation
     *      fitnessFunc = function used to evaluate fitness of each chromosome of the population before each evolution
     *      populationSize = defines the population size
     */
    this(T sampleChromosome, IFitnessFunction!T fitnessFunc, ITerminateFunction terminateFunc, uint populationSize = 100)
    {
        this._sampleChromosome = sampleChromosome;
        this._fitnessFunc = fitnessFunc;
        this._populationSize = populationSize;
        this._terminateFunc = terminateFunc;
    }

    /**
     * Desired size of each population
     */
    @property pure nothrow uint populationSize() const
    {
        return _populationSize;
    }

    /**
     * Set desired size of each population
     */
    @property pure nothrow void populationSize(uint size)
    {
        _populationSize = size;
    }

    /**
     * Sample chromosome which is used to specify how each chromosome of the population should look alike, its used to generate all chromosomes in population
     */
    @property pure nothrow T sampleChromosome()
    {
        return _sampleChromosome;
    }

    /**
     * Set sample chromosome which is used to specify how each chromosome of the population should look alike, its used to generate all chromosomes in population
     */
    @property pure nothrow void sampleChromosome(T sample)
    {
        _sampleChromosome = sample;
    }

    /**
     * Fitness function used to evaluate fitness of each chromosome of the population before each evolution
     */
    @property pure nothrow IFitnessFunction!T fitnessFunction()
    {
        return _fitnessFunc;
    }
    
    /**
     * Fitness function used to evaluate fitness of each chromosome of the population before each evolution
     */
    @property pure nothrow void fitnessFunction(IFitnessFunction!T func)
    {
        _fitnessFunc = func;
    }

    /**
     * Terminate function is used to determine if GA should continue with next generation or not
     */
    @property pure nothrow ITerminateFunction terminateFunction()
    {
        return _terminateFunc;
    }
    
    /**
     * Terminate function is used to determine if GA should continue with next generation or not
     */
    @property pure nothrow void terminateFunction(ITerminateFunction func)
    {
        _terminateFunc = func;
    }

    /**
     * Selection operator used to select elite chromosomes from the current population which are used in the new population without any change.
     * This allows to survive the best chromosomes found yet.
     */
    @property pure nothrow ISelectionOperator!T eliteSelectionOperator()
    {
        return _eliteSelectionOperator;
    }
    
    /**
     * Selection operator used to select elite chromosomes from the current population which are used in the new population without any change.
     * This allows to survive the best chromosomes found yet.
     */
    @property pure nothrow void eliteSelectionOperator(ISelectionOperator!T eliteSel)
    {
        _eliteSelectionOperator = eliteSel;
    }

    /**
     * Operator to select parent chromosomes for crossover opertor.
     */
    @property pure nothrow ISelectionOperator!T parentSelectionOperator()
    {
        return _parentSelectionOperator;
    }
    
    /**
     * Operator to select parent chromosomes for crossover opertor.
     */
    @property pure nothrow void parentSelectionOperator(ISelectionOperator!T eliteSel)
    {
        _parentSelectionOperator = eliteSel;
    }

    /**
     * Probability of crossover operator. The higher the number is, the higher rate of crossover.
     * Expected value range is [0..1]
     * Note:
     *      This should be relatively high number - about 80%
     *      0 means no crossover will be performed so all parents will be taken as they are before mutation operator.
     *      1 means that all parents initiate new offspring.
     */
    @property pure nothrow double crossoverProbability() const
    {
        return _crossoverProbability;
    }
    
    /**
     * Probability of crossover operator. The higher the number is, the higher rate of crossover.
     * Expected value range is [0..1]
     * Note:
     *      This should be relatively high number - about 80%
     *      0 means no crossover will be performed so all parents will be taken as they are before mutation operator.
     *      1 means that all parents initiate new offspring.
     */
    @property pure nothrow void crossoverProbability(double probability)
    {
        assert(probability > 0.0 && probability < 1.0);

        _crossoverProbability = probability;
    }

    /**
     * Probability of mutation operator. The higher the number is, the higher rate of mutation.
     * Expected value range is [0..1]
     * Note:
     *      This should be relatively low number - about 0.5% - 1%
     *      0 means no mutation will be performed.
     *      1 means that all genes of each chromosome will be mutated - which makes random search from GA.
     */
    @property pure nothrow double mutationProbability() const
    {
        return _mutationProbability;
    }
    
    /**
     * Probability of mutation operator. The higher the number is, the higher rate of mutation.
     * Expected value range is [0..1]
     * Note:
     *      This should be relatively low number - about 0.5% - 1%
     *      0 means no mutation will be performed.
     *      1 means that all genes of each chromosome will be mutated - which makes random search from GA.
     */
    @property pure nothrow void mutationProbability(double probability)
    {
        assert(probability > 0.0 && probability < 1.0);
        
        _mutationProbability = probability;
    }
}

