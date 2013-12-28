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

//TODO: Add AlterFitnessFunction, which can adjust evaluated fitness of the chromosome for example by age, normalize, invert (to minimize fitness instead of maximize)

/// Simple fitness function tests
unittest
{
    import std.stdio;
    import std.conv;
    import geneticd.configuration;

    alias Chromosome!BoolGene chromoType;

    auto conf = new Configuration!chromoType(new chromoType(new BoolGene(), 10));
    auto chrom = new chromoType(conf, new BoolGene(), 10);

    auto fitness = simpleFitness!chromoType((ch) => 5.0);
    assert(fitness.evaluate(chrom) == 5.0);
}