module geneticd.terminate;

import std.exception : enforce;
import std.math : isNaN;
import std.typetuple;
import std.traits;
import geneticd.geneticalgorithm;

//alias bool function(StatusInfo) termFuncDelegate;

/**
 * Interface for a GA terminate conditions
 */
interface ITerminateFunction
{
    /**
     * Determines if further evaluations should be terminated
     */
    bool opCall(in StatusInfo status) nothrow;
}

/**
 * Simple terminate function which just calls the provided delegate function
 */
class DelegateTerminateFunction(termFun...) : ITerminateFunction 
    if(termFun.length)
{
    bool opCall(in StatusInfo status) nothrow
    {
        assert(!isNaN(status.bestFitness));
        assert(status.generations > 0);

        try
        {
            static if(termFun.length == 1)
            {
                return termFun[0](status);
            }
            else
            {
                foreach(fun; termFun)
                {
                    if(fun(status)) return true;
                }

                return false;
            }
        }
        catch
        {
            return false;
        }
    }
}

/**
 * Terminate function which terminates GA evaluation when better fitness is not achieved within specified number of generations.
 * 
 * Params:
 *      maxGenerations = maximum number of generations we wait for better fitness before GA is terminated
 */
private class NoImprovementTerminateFunction(uint maxGenerations) : ITerminateFunction
    if(maxGenerations > 0)
{
    private double _bestFitness;
    private uint _noImpGenerations;
    private size_t _lastGen;

    /**
     * Determines if further evaluations should be terminated
     */
    bool opCall(in StatusInfo status) nothrow
    {
        assert(!isNaN(status.bestFitness));
        assert(status.generations > 0);
        assert(_lastGen != status.generations);

        _lastGen = status.generations;

        if(isNaN(_bestFitness) || _bestFitness < status.bestFitness)
        {
            _bestFitness = status.bestFitness;
            _noImpGenerations = 0;
            return false;
        }

        return (++_noImpGenerations >= maxGenerations);
    }
}

/**
 * Helper function to create terminate function which calls provided delegates or functions
 * 
 * Can be used to create composite terminate function which consists of more than one terminate function
 */
auto delegateTerminate(T...)()
{
    return new DelegateTerminateFunction!T();
}

/**
 * Helper function to create simple terminate function which terminates evaluation after specified number of generations
 */
auto maxGenerationsTerminate(size_t maxGenerations)()
{
    return new DelegateTerminateFunction!((status) => status.generations >= maxGenerations);
}

/**
 * Helper function to create simple terminate function which terminates evaluation after specified number of generations
 */
auto maxEvaluationsTerminate(size_t maxEvaluations)()
{
    return new DelegateTerminateFunction!((status) => status.evaluations >= maxEvaluations)();
}

/**
 * Helper function to create simple terminate function which terminates evaluation after required fitness is achieved
 */
auto fitnessTerminate(double targetFitness)()
{
    assert(!isNaN(targetFitness));
    return new DelegateTerminateFunction!((status) => status.bestFitness >= targetFitness)();
}

/**
 * Terminate function which terminates GA evaluation when better fitness is not achieved within specified number of generations.
 * 
 * Params:
 *      maxGenerations = maximum number of generations we wait for better fitness before GA is terminated
 */
auto noImprovementTerminate(uint maxGenerations)()
{
    return new NoImprovementTerminateFunction!(maxGenerations)();
}

/// delegateTerminate tests
unittest
{
    import std.exception;

    StatusInfo status = StatusInfo(1, 0, 0);

    ITerminateFunction func = delegateTerminate!(s => s.generations == 10);
    assert(func(status) == false);

    status.generations = 10;
    assert(func(status) == true);

    //throwing delegate test
    func = delegateTerminate!((s){ if(s.generations >=0) throw new Exception(""); return true;});
    assert(func(status) == false);
}

//composite test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = delegateTerminate!(
        s => s.generations >= 10,
        s => s.evaluations >= 50,);
        //fitnessTerminate!(100)); //TODO: make this possible

    assert(func(status) == false);
    status.generations = 10;
    assert(func(status) == true);
    status.generations = 1;
    status.evaluations = 50;
    assert(func(status) == true);
}

//maxGenerationsTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = maxGenerationsTerminate!(10);
    while(!func(status)) status.generations++;

    assert(status.generations == 10);
}

/// maxEvaluationsTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = maxEvaluationsTerminate!(10);
    while(!func(status)) status.evaluations++;
    
    assert(status.evaluations == 10);
}

/// fitnessTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = fitnessTerminate!(100.0);
    while(!func(status)) status.bestFitness += 10;
    
    assert(status.bestFitness == 100.0);
}

/// noImprovementTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 50.0);
    ITerminateFunction func = noImprovementTerminate!(10);

    import std.stdio;

    while(!func(status)) status.generations++;
    
    assert(status.generations == 11); //first gen is ok, then +10
}
