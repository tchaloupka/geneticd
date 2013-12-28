module geneticd.terminate;

import geneticd.chromosome;
import geneticd.population;

//TODO: Define simple non generic Population interface tu use with these functions or define for example GAStatusInfo that store used parameters

/**
 * Interface for a GA terminate conditions
 */
interface ITerminateFunction(T:IChromosome)
{
    /**
     * Determines if further evaluations should be terminated
     */
    bool terminate(Population!T population, size_t generations, size_t evaluations);
}

/**
 * Simple terminate function which just calls the provided delegate function
 */
class SimpleTerminateFunction(T) : ITerminateFunction!T
{
    bool delegate(Population!T population, size_t generations, size_t evaluations) _termFunc;
    
    this(bool delegate(Population!T population, size_t generations, size_t evaluations) func)
    {
        assert(func !is null);
        this._termFunc = func;
    }
    
    bool terminate(Population!T population, size_t generations, size_t evaluations)
    {
        return _termFunc(population, generations, evaluations);
    }
}

/**
 * Helper function to create simple terminate function
 */
SimpleTerminate!T simpleTerminate(T:IChromosome)(double delegate(Population!T population, size_t generations, size_t evaluations) terminator)
{
    return new SimpleTerminateFunction!T(terminator);
}

/**
 * Helper function to create simple terminate function which terminates evaluation after specified number of generations
 */
SimpleTerminate!T maxGenerationsTerminate(T:IChromosome)(size_t maxGenerations)
{
    return new SimpleTerminateFunction!T((population, generations, evaluations) => generations >= maxGenerations);
}

/**
 * Helper function to create simple terminate function which terminates evaluation after specified number of generations
 */
SimpleTerminate!T maxEvaluationsTerminate(T:IChromosome)(size_t maxEvaluations)
{
    return new SimpleTerminateFunction!T((population, generations, evaluations) => evaluations >= maxEvaluations);
}

/**
 * Helper function to create simple terminate function which terminates evaluation after required fitness is achieved
 */
SimpleTerminate!T targetFitnessTerminate(T:IChromosome)(double targetFitness)
{
    return new SimpleTerminateFunction!T((population, generations, evaluations) => population.best.fitness >= targetFitness);
}

//TODO: Terminate when defined count of generations does not achieve further improvement

unittest
{
    //TODO: add some unittests for terminate functions
}