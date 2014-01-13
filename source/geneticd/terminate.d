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
    bool terminate(in StatusInfo status) nothrow;
}

/**
 * Simple terminate function which just calls the provided delegate function
 */
private class DelegateTerminateFunction(termFun...) : ITerminateFunction 
    if(termFun.length)
{
    bool terminate(in StatusInfo status) nothrow
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
 *      op = with this we can select if bestFitness or averageFitness of population will be checked to grow
 */
private class NoImprovementTerminateFunction(uint maxGenerations, string op = "bestFitness") : ITerminateFunction
    if(maxGenerations > 0 && (op == "bestFitness" || op == "averageFitness"))
{
    private double _bestFitness;
    private uint _noImpGenerations;
    private size_t _lastGen;

    /**
     * Determines if further evaluations should be terminated
     */
    bool terminate(in StatusInfo status) nothrow
    {
        assert(!isNaN(mixin("status." ~ op)));
        assert(status.generations > 0);
        assert(_lastGen != status.generations);

        _lastGen = status.generations;

        if(isNaN(_bestFitness) || _bestFitness < mixin("status." ~ op))
        {
            _bestFitness = mixin("status." ~ op);
            _noImpGenerations = 0;
            return false;
        }

        return (++_noImpGenerations >= maxGenerations);
    }
}

/**
 * Composite terminate function which consists of more ITerminateFunctions.
 * Functions are evaluated in the same order as created.
 * 
 * Note:
 * First function with positive result breaks evaluation so not all terminate functions are guaranteed to be called at GA termination
 */
private class CompositeTerminateFunction : ITerminateFunction
{
    ITerminateFunction[] _funcList;

    this(ITerminateFunction[] funcList...)
    {
        this._funcList = funcList;
    }

    bool terminate(in StatusInfo status)
    {
        foreach(f; _funcList)
        {
            if(f.terminate(status)) return true;
        }
        return false;
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
auto noImprovementTerminate(uint maxGenerations, string op = "bestFitness")()
{
    return new NoImprovementTerminateFunction!(maxGenerations, op)();
}

/**
 * Create composite terminate function
 */
auto compositeTerminate(ITerminateFunction[] functionList...)
{
    return new CompositeTerminateFunction(functionList);
}

/// delegateTerminate tests
unittest
{
    import std.exception;

    StatusInfo status = StatusInfo(1, 0, 0);

    ITerminateFunction func = delegateTerminate!(s => s.generations == 10);
    assert(func.terminate(status) == false);

    status.generations = 10;
    assert(func.terminate(status) == true);

    //throwing delegate test
    func = delegateTerminate!((s){ if(s.generations >=0) throw new Exception(""); return true;});
    assert(func.terminate(status) == false);
}

//composite delegate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = delegateTerminate!(
        s => s.generations >= 10,
        s => s.evaluations >= 50,);
        //fitnessTerminate!(100)); //this is not possible as class instances are not the valid template arguments

    assert(func.terminate(status) == false);
    status.generations = 10;
    assert(func.terminate(status) == true);
    status.generations = 1;
    status.evaluations = 50;
    assert(func.terminate(status) == true);
}

//maxGenerationsTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = maxGenerationsTerminate!(10);
    while(!func.terminate(status)) status.generations++;

    assert(status.generations == 10);
}

/// maxEvaluationsTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = maxEvaluationsTerminate!(10);
    while(!func.terminate(status)) status.evaluations++;
    
    assert(status.evaluations == 10);
}

/// fitnessTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = fitnessTerminate!(100.0);
    while(!func.terminate(status)) status.bestFitness += 10;
    
    assert(status.bestFitness == 100.0);
}

/// noImprovementTerminate test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 50.0, 50.0, 0.0, 0.0);
    ITerminateFunction func = noImprovementTerminate!(10);

    while(!func.terminate(status))
    {
        status.averageFitness += 1;
        status.averageRealFitness += 1;
        status.generations++;
        assert(status.generations < 20); //to stop the loop if terminate does not work
    }
    
    assert(status.generations == 11); //first gen is ok, then +10

    status.generations = 1;
    func = noImprovementTerminate!(10, "averageFitness");
    while(!func.terminate(status))
    {
        status.bestFitness += 1;
        status.bestRealFitness += 1;
        status.generations++;
        assert(status.generations < 20); //to stop the loop if terminate does not work
    }
    assert(status.generations == 11); //first gen is ok, then +10
}

//composite test
unittest
{
    StatusInfo status = StatusInfo(1, 0, 0);
    ITerminateFunction func = compositeTerminate(
        maxGenerationsTerminate!10,
        maxEvaluationsTerminate!50,
        fitnessTerminate!100);
    
    assert(func.terminate(status) == false);
    status.generations = 10;
    assert(func.terminate(status) == true);
    status.generations = 1;
    status.evaluations = 50;
    assert(func.terminate(status) == true);
}
