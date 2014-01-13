import std.stdio;
import std.random : uniform;
import std.math;
import geneticd;

/**
 * Traveling salesman problem is a common problem to show how it can be solved with GA, so here is an implementation using geneticd library.
 * 
 * More about the problem itself is for example here: http://en.wikipedia.org/wiki/Travelling_salesman_problem
 */

/// Simple struct to define our cities
struct City
{
    /// City name - char is enough for an example
    char name;

    /// X coordinate
    double x;

    /// Y coordinate
    double y;

    /// Computes distance between cities
    double dist(City other)
    {
        return sqrt(pow(x-other.x, 2) + pow(y-other.y, 2));
    }
}

void main()
{
    enum citiesNumber = 20;

    alias ScalarGene!char GeneType;
    alias Chromosome!GeneType ChromosomeType;

    City[] cities;
    GeneType[] genes;

    //find city by name
    ref City getCity(char name)
    {
        return cities[name-'a'];
    }

	//Lets make it simple and place random 20 cities in a square of size 100x100
    //As this is an ordering problem we will represent the salesman path as an CharGene chromosome 
    //with permutation encoding (each gene has different value)
    //So we have to create sample Chromosome alone (random chromosome is no usable here)
    foreach(i; 0..citiesNumber)
    {
        cities ~= City(cast(char)('a'+i), uniform(0, 101), uniform(0, 101));
        genes ~= new ScalarGene!char(cities[i].name, 'a', cast(char)('a'+citiesNumber-1));
    }

    //Create sample Chromosome
    auto chromosome = new ChromosomeType(genes);
    chromosome.isPermutation = true; //make sure that only order of genes is changed not genes itself

    //Now we can create configuration for GA
    auto conf = new Configuration!ChromosomeType();
    conf.sampleChromosome = chromosome; //set sample chromosome from which population is initialized
    conf.populationSize = 20;   //set size of population to work with
    conf.terminateFunction = compositeTerminate(
        maxGenerationsTerminate!(100),  //terminate after 100 generations
        noImprovementTerminate!(10));   //terminate if no better chromosome is found within 10 generations
    conf.eliteSelectionOperator = eliteSelection!ChromosomeType(1); //keep the best chromosome unchanged for next population
    conf.parentSelectionOperator = tournamentSelection!ChromosomeType(5, 0.9); //parents are selected from tournament pools of size 5 with probability 0.9 that the best of the pool will will be selected
    conf.crossoverOperator = orderedCrossover!ChromosomeType(); //we have to use some crossover operator which keeps genes ordered - OX in this case
    conf.mutationOperator = swapMutation!ChromosomeType(); //again we have to use mutation operator that will not invalidate chromosome

    //set fitness function - we should precompute the distance between all cities, but for simplicity..
    conf.fitnessFunction = simpleFitness!ChromosomeType(delegate (ch)
    {
        //sum distances
        double dist = 0.0;
        foreach(i, g; ch.genes[0..$-1])
        {
            dist += getCity(g.value).dist(getCity(ch.genes[i+1].value));
        }
        return dist;
    });

    //as we want to search shortest possible path we need to invert fitness function
    conf.alterFitnessFunction = alterFitnessMinimize!(ChromosomeType, 150*citiesNumber); //as we have 100x100 square, maximal distance between 2 cities is sqrt(2x100x100)

    //set some callbacks
    conf.callbacks.onFitness = (const g, const ref s)
    {
        writeln();
        writeln("----------------------------------------------------------");
        writefln("Gen %s, Best: %s, Avg: %s, Cross: %s, Mut: %s", 
                 s.generations, s.bestRealFitness, s.averageRealFitness, s.crossovers, s.mutatedGenes);
        writeln(g.population);
    };

    //execute GA
    auto ga = new GA!ChromosomeType(conf);
    ga.run();
    
    writeln();
    writefln("Best: [%s], distance travelled: %s", ga.population.best, ga.population.best.realFitness);
}
