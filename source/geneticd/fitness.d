module geneticd.fitness;

import geneticd.chromosome;
import geneticd.gene;

/**
 * Interface for fitness functions
 */
interface IFitnessFunction(T:IChromosome)
{
    double evaluate(T chromosome);
}

/**
 * Interface for alter fitness functions
 */
interface IAlterFitnessFunction(T:IChromosome)
{
    double evaluate(T chromosome, double realFitness);
}

/**
 * Helper function to create simple fitness function
 */
SimpleFitnessFunction!T simpleFitness(T:IChromosome)(double delegate(T chromosome) evaluator)
{
    return new SimpleFitnessFunction!T(evaluator);
}

/**
 * Simple fitness function which just calls the provided delegate function
 */
class SimpleFitnessFunction(T) : IFitnessFunction!T
{
    double delegate(T chromosome) _evalFunc;
    
    this(double delegate(T chromosome) func)
    {
        assert(func !is null);
        this._evalFunc = func;
    }
    
    double evaluate(T chromosome)
    {
        return _evalFunc(chromosome);
    }
}

/**
 * Helper function to create simple alter fitness function using given delegate function
 */
AlterFitnessFunction!T alterFitnessDelegate(T:IChromosome)(double delegate(T chromosome, double realFitness) evaluator)
{
    return new AlterFitnessFunction!T(evaluator);
}

/**
 * Helper function to create alter fitness function which reverts the search direction (instead of maximize we try to minimize the resulted fitness)
 * 
 * Params:
 *      maxFitness = maximal fitnes which can real fitness function return so we can use "maxFitness - fitness" correction
 * 
 * Note that if maxFitness - fitness < 0 than 0 is returned as GA require to work with fitness values >=0
 */
AlterFitnessFunction!T alterFitnessMinimize(T:IChromosome, double maxFitness)()
{
    return new AlterFitnessFunction!T((ch, realFitness)
    {
        auto tmp = maxFitness - realFitness;
        return tmp < 0? 0.0 : tmp;
    });
}

/**
 * Function that can adjust evaluated fitness of the chromosome for example by age, normalize, invert (to minimize fitness instead of maximize), etc.
 */
class AlterFitnessFunction(T) : IAlterFitnessFunction!T
{
    double delegate(T chromosome, double realFitness) _evalFunc;
    
    this(double delegate(T chromosome, double realFitness) func)
    {
        assert(func !is null);
        this._evalFunc = func;
    }
    
    double evaluate(T chromosome, double realFitness)
    {
        return _evalFunc(chromosome, realFitness);
    }
}

/// Simple fitness function tests
unittest
{
    import std.stdio;
    import std.conv;
    import geneticd.configuration;

    alias Chromosome!(ScalarGene!bool) chromoType;

    auto conf = new Configuration!chromoType(new chromoType(new ScalarGene!bool(), 10));
    auto chrom = new chromoType(conf, new ScalarGene!bool(), 10);

    auto fitness = simpleFitness!chromoType((ch) => 5.0);
    assert(fitness.evaluate(chrom) == 5.0);

    auto alterFitness = alterFitnessMinimize!(chromoType, 100)();
    assert(alterFitness.evaluate(chrom, 5.0) == 95);
}
