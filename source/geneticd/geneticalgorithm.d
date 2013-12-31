module geneticd.geneticalgorithm;

import geneticd.configuration;
import geneticd.chromosome;
import geneticd.gene;
import geneticd.population;
import geneticd.fitness;
import geneticd.terminate;

/**
 * Driving class for genetic algorithm evaluation
 */
class GA(T:IChromosome)
{
    private Configuration!T _configuration;
    private Population!T _population;
    private size_t _generations;
    private size_t _evaluations;
    private StatusInfo _status;

    /// Constructor
    this(Configuration!T configuration)
    {
        assert(configuration !is null, "Configuration not set");
        assert(configuration.terminateFunction !is null, "Terminate function not set");

        this._configuration = configuration;
    }

    /// Executes the GA algorithm
    void run()
    {
        do
        {
            evolvePopulation(); //create next gen
            _status.evaluations += _population.fitness(); //determine fitness of chromosomes
            _status.bestFitness = _population.best.fitness;
            _configuration.callBacks.invoke!"onFitness"(_status);
        }
        while(!_configuration.terminateFunction.terminate(_status));
    }

    /// prepare next generation
    private void evolvePopulation()
    {
        if(_population is null) //first
        {
            initRandomPopulation();
            assert(_population !is null);
            _status.generations = 1;
        }
        else
        {
            //TODO: select, mutate, cross, ...
            _status.generations++;
        }
    }

    /**
     * Initializes random population.
     * Can be overriden so it can be used to customize population generation
     */
    protected void initRandomPopulation()
    {
        _population = new Population!T(_configuration);
    }

    /**
     * Current population of GA
     */
    @property nothrow const(Population!T) population() const
    {
        assert(_population !is null);

        return cast(const(Population!T))(_population);
    }
}

/**
 * GA status information holder to describe current status of running algorithm
 */
struct StatusInfo
{
    /// Total number of evolved generations (1 means the first generation);
    size_t generations;

    /// Total number of evaluations (chromosome.evaluate calls)
    size_t evaluations;

    /// Fitness of the best solution found
    double bestFitness;
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
    auto conf = new Configuration!chromoType(new chromoType(new BoolGene(), size));
    conf.populationSize = 10;

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
    //conf.terminateFunction = fitnessTerminate!(size); //size of the input is also maximum fitness (all bool values are equal)
    conf.terminateFunction = maxGenerationsTerminate!(10);

    //add GA operations
    //TODO

    //set callback functions
    GA!chromoType ga;
    conf.callBacks.onFitness = (s)
    {
        writefln("Gen %s, Eval: %s, Best: %s", s.generations, s.evaluations, s.bestFitness);
        writeln(ga.population);
    };

    //execute GA
    ga = new GA!chromoType(conf);
    ga.run();

    writeln();
}