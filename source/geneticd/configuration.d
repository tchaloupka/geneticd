module geneticd.configuration;

import geneticd.chromosome;
import geneticd.fitness;

/**
 * Configuration parameters for GA evaluation
 */
class Configuration(T:IChromosome)
{
    private uint _populationSize = 100;
    private T _sampleChromosome;
    private IFitnessFunction!T _fitnessFunc;

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
}

