module geneticd.geneticalgorithm;

import geneticd.configuration;
import geneticd.chromosome;
import geneticd.gene;
import geneticd.population;
import geneticd.fitness;

/**
 * Driving class for genetic algorithm evaluation
 */
class GA(T:IChromosome)
{
    private Configuration!T _configuration;
    private Population!T _population;
    private size_t _generations;
    private size_t _evaluations;

    /// Constructor
    this(Configuration!T configuration)
    {
        this._configuration = configuration;
    }
}

/// Simple guessing of bool array content
unittest
{
    import std.algorithm;
    import std.random;
    import std.conv;
    import std.stdio;

    alias Chromosome!BoolGene chromoType;

    enum size = 20;
    bool[] target;

    foreach(i; 0..size)
    {
        target ~= to!bool(uniform!"[]"(0, 1));
    }

    writeln("GA - bool array guessing");
    writeln("------------------------");
    writefln("Input: [%s]", target.map!(to!string).joiner(", "));

    //create GA configuration
    auto conf = new Configuration!chromoType(new chromoType(new BoolGene(), 10));

    //set fitness function
    conf.fitnessFunction = simpleFitness!chromoType(delegate (ch)
    {
        //add to tmp if chromosome and target are same
        uint tmp;
        foreach(i; 0..size)
        {
            if(target[i] == ch[i]) ++tmp;
        }

        return cast(double)tmp;
    });

    //set terminate function
    //TODO

    //add GA operations
    //TODO

    //set callback functions
    //TODO

    //execute GA
    //TODO

    writeln();
}