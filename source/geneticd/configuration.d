module geneticd.configuration;

import geneticd.chromosome;
import geneticd.fitness;
import geneticd.terminate;
import geneticd.geneticalgorithm;

/**
 * Configuration parameters for GA evaluation
 */
class Configuration(T:IChromosome)
{
    struct CallBacks
    {
        import std.traits : isDelegate;
        import std.string : format;

        /// Called when fitness is determined for all chromosomes in current population
        void delegate(StatusInfo) onFitness;

        void invoke(alias CallBack,U...)(U params)
        {
            mixin(format("if(%s !is null) try{ %s(params);} catch{}", CallBack, CallBack));
        }
    }

    private uint _populationSize = 100;
    private T _sampleChromosome;
    private IFitnessFunction!T _fitnessFunc;
    private ITerminateFunction _terminateFunc;

    /// Simple struct to hold callback delegates
    CallBacks callBacks;

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
}

