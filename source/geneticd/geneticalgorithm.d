module geneticd.geneticalgorithm;

import std.algorithm : map;
import std.array : array;
import std.random : dice;

import geneticd.configuration;
import geneticd.chromosome;
import geneticd.gene;
import geneticd.population;
import geneticd.fitness;
import geneticd.terminate;
import geneticd.operators;

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
        assert(configuration.parentSelectionOperator !is null, "Parent selection operator not set");

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
            _status.averageFitness = _population.totalFitness / _population.chromosomes.length;

            _configuration.callBacks.invoke!"onFitness"(_status);
        }
        while(!_configuration.terminateFunction.terminate(_status));
    }

    private T cloneChromosome(T chromosome)
    {
        auto tmp = chromosome.clone();
        tmp.age = tmp.age + 1;  // tmp.age++ not working yet -> @property is not lvalue
        return tmp;
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
            auto newPopulation = new Population!T(_configuration, false);
            newPopulation ~= new T(_configuration);

            // handle special case of selection operator
            if(_configuration.eliteSelectionOperator !is null)
            {
                //select elite chromosomes
                newPopulation ~= _configuration.eliteSelectionOperator.select(_population).map!(a=>cloneChromosome(a)).array;
            }

            while(newPopulation.chromosomes.length < _configuration.populationSize)
            {
                // 1. select parent chromosomes
                auto tmp = _configuration.parentSelectionOperator.select(_population).map!(a=>cloneChromosome(a)).array;

                // 2. crossover parents
                if(dice(_configuration.crossoverProbability, 1.0 - _configuration.crossoverProbability) == 0)
                {
                    //TODO: crossover
                    newPopulation ~= tmp;
                }
                else
                {
                    //use as they are
                    newPopulation ~= tmp;
                }

                // 3. mutate offspring

                // 4. add to new population

            }

            _population = newPopulation;
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

    /// Average fitness of the current population
    double averageFitness;
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
    conf.eliteSelectionOperator = eliteSelection!chromoType; // best chromosome allways survives
    conf.parentSelectionOperator = randomTruncationSelection!chromoType(conf.populationSize / 3); // 1/3 of best chromosomes is used to breed the next generation
    //TODO

    //set callback functions
    GA!chromoType ga;
    conf.callBacks.onFitness = (s)
    {
        writefln("Gen %s, Eval: %s, Best: %s, Avg: %s", s.generations, s.evaluations, s.bestFitness, s.averageFitness);
        writeln(ga.population);
    };

    //execute GA
    ga = new GA!chromoType(conf);
    ga.run();

    writeln();
}