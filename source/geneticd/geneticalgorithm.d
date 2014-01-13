module geneticd.geneticalgorithm;

import std.algorithm : map;
import std.array : array;
import std.random : uniform;

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
        assert(configuration.crossoverOperator !is null, "Crossover operator not set");

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
            _status.bestRealFitness = _population.best.realFitness;
            _status.averageFitness = _population.totalFitness / _population.chromosomes.length;
            _status.averageRealFitness = _population.totalRealFitness / _population.chromosomes.length;

            _configuration.callbacks.invoke!"onFitness"(this, _status);
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
            _configuration.callbacks.invoke!"onInitialPopulation"(this, _status);
        }
        else
        {
            //TODO: make pool of chromosomes to reuse chromosome instances(and use it where new Chromosome is called),
            //also reuse 2 populations instead of creating new ones
            auto newPopulation = new Population!T(_configuration, false);

            // handle special case of selection operator
            if(_configuration.eliteSelectionOperator !is null)
            {
                _configuration.eliteSelectionOperator.init(_status, _population);
                //select elite chromosomes
                auto tmp = _configuration.eliteSelectionOperator.select(_population).map!((a)
                {
                    auto elite = a.clone();
                    elite.age = elite.age + 1; //make older as it is not modified
                    return elite;
                }).array;
                _configuration.callbacks.invoke!"onElite"(tmp);
                newPopulation ~= tmp;
            }

            //parent selection
            _configuration.parentSelectionOperator.init(_status, _population);
            bool addAge;
            while(newPopulation.chromosomes.length < _configuration.populationSize)
            {
                // 1. select parent chromosomes
                auto tmp = _configuration.parentSelectionOperator.select(_population).map!(a=>a.clone()).array;
                _configuration.callbacks.invoke!"onSelected"(tmp);

                // 2. crossover parents
                addAge = true;
                if(uniform(0.0, 1.0) <= _configuration.crossoverProbability)
                {
                    _configuration.callbacks.invoke!"onBeforeCrossover"(tmp);
                    _configuration.crossoverOperator.cross(_status, tmp);
                    _configuration.callbacks.invoke!"onAfterCrossover"(tmp);
                    addAge = false; //ofspring has age = 0
                    _status.crossovers += tmp.length;
                 }

                // 3. mutate offspring (or parents if crossover is not applied)
                foreach(ch; tmp)
                {
                    _configuration.callbacks.invoke!"onBeforeMutate"(ch);
                    auto mutated = ch.mutate();

                    if(mutated) ch.age = 0; //new individual so age = 0
                    else if(addAge) ch.age = ch.age + 1; //no change, so individual is getting older

                    _configuration.callbacks.invoke!"onAfterMutate"(ch, mutated > 0);

                    _status.mutatedGenes += mutated;
                }

                // 4. add to new population
                newPopulation ~= tmp;
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

    /// Unaltered fitness of the best solution found
    double bestRealFitness;

    /// Average fitness of the current population
    double averageFitness;

    /// Unaltered average fitness of the current population
    double averageRealFitness;

    /// Total number of mutated genes
    size_t mutatedGenes;

    /// Total number of crossovers
    size_t crossovers;
}

/// Simple guessing of bool array content
unittest
{
    import std.algorithm;
    import std.random;
    import std.conv;
    import std.stdio;

    alias Chromosome!(ScalarGene!bool) chromoType;

    enum size = 20;
    bool[] target;

    foreach(i; 0..size)
    {
        target ~= to!bool(uniform!"[]"(0, 1));
    }

    writeln("GA - bool array guessing");

    //create GA configuration
    auto conf = new Configuration!chromoType(new chromoType(new ScalarGene!bool(), size));
    conf.populationSize = 20;

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
    conf.terminateFunction = compositeTerminate(
        maxGenerationsTerminate!(100),
        fitnessTerminate!size); //target fitness is size of genomes

    //add GA operations
    conf.eliteSelectionOperator = eliteSelection!chromoType; // best chromosome allways survives
    //conf.parentSelectionOperator = truncationSelection!chromoType(conf.populationSize / 3); // 1/3 of best chromosomes is used to breed the next generation
    //conf.parentSelectionOperator = weightedRouletteSelection!chromoType();
    //conf.parentSelectionOperator = tournamentSelection!chromoType(5, 0.9);
    //conf.parentSelectionOperator = stochasticSelection!chromoType(10);
    //conf.parentSelectionOperator = rankSelection!chromoType(1.8);
    conf.parentSelectionOperator = rankSelection!(chromoType, false)(3.0);

    //conf.crossoverOperator = singlePointCrossover!chromoType();
    //conf.crossoverOperator = twoPointCrossover!chromoType();
    conf.crossoverOperator = uniformCrossover!chromoType();

    //set callback functions
    conf.callbacks.onInitialPopulation = (const g, const ref s)
    {
        assert(isNaN(s.bestFitness));
        assert(isNaN(s.averageFitness));
        assert(s.mutatedGenes == 0);
        assert(s.generations == 1);
        assert(s.evaluations == 0);
    };
    conf.callbacks.onFitness = (const g, const ref s)
    {
        writeln();
        writeln("----------------------------------------------------------");
        writefln("Gen %s, Eval: %s, Best: %s, Avg: %s, Cross: %s, Mut: %s", 
                 s.generations, s.evaluations, s.bestFitness, s.averageFitness, s.crossovers, s.mutatedGenes);
        writeln(g.population);
    };
    conf.callbacks.onElite = (elite)
    {
        assert(elite.length > 0);
        foreach(el; elite)
        {
            writefln("> Elite: %s", el);
            writeln();
        }
    };
    conf.callbacks.onSelected = (parents)
    {
        assert(parents.length > 0);
        foreach(p; parents)
        {
            writefln("> Selected: %s", p);
        }
    };
    conf.callbacks.onAfterCrossover = (offspiring)
    {
        assert(offspiring.length > 0);
        foreach(off; offspiring)
        {
            writefln("> Crossover: %s", off);
        }
    };
    conf.callbacks.onAfterMutate = (offspiring, mutated)
    {
        assert(offspiring !is null);
        if(mutated) writefln("> Mutated: %s", offspiring);
    };

    //execute GA
    GA!chromoType ga = new GA!chromoType(conf);
    ga.run();

    writeln();
    writefln("Input: [%s]", target.map!(to!string).joiner(", "));
    writefln("Best: [%s]", ga.population.best);
}