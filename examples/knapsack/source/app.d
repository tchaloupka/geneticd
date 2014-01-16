import std.stdio;
import std.algorithm : reduce, map;
import std.math : abs;
import std.typecons;

import geneticd;

/**
 * 
 * This example demonstrates solution to problem described here: http://en.wikipedia.org/wiki/Knapsack_problem
 *
 * I choosed to implement sample inspired by http://xkcd.com/287/
 * described here http://kataklinger.com/index.php/genetic-algorithm-knapsack/ using C++
 * 
 * So we can compare how different is C++ and D implementation ;-)
 */

/// Definition of appetizer
struct Appetizer
{
    string name;
    double price; //appetizer price 
    uint time; //time to prepare
}

void main()
{
    //init list of appetizers to play with
    enum Appetizer[] appetizers = 
    [
        Appetizer("mixed fruit", 2.15, 3),
        Appetizer("french fries", 2.75, 2),
        Appetizer("side salad", 3.35, 5),
        Appetizer("hot wings", 3.55, 3),
        Appetizer("mozzarella sticks", 4.20, 4),
        Appetizer("sampler plate", 5.80, 7)
    ];

    //as encoding, we choose a simple ScalarGene with index of appetizer as its value
    alias ScalarGene!byte GeneType;
    alias Chromosome!GeneType ChromosomeType;

    //maxinam number of genes in chromosome
    enum maxGenes = 10;

    //we want the price to be more important criterion
    enum weightOfPrice = 2.0;
    enum weightOfTime = 1.0;

    //target price we want
    enum targetPrice = 15.05;

    //as genes can repeat in chromosome and their value is bounded by appetizers array size, we create sample chromosome like this
    auto sampleGene = new GeneType(cast(byte)0, cast(byte)0, cast(byte)(appetizers.length-1)); //sample value, lowest index, highest index
    auto sampleChromosome = new ChromosomeType(sampleGene, maxGenes);
    sampleChromosome.isFixedLength = false; //number of genes in chromosome can change during population initialization and evolution

    //Now we can create configuration for GA
    auto conf = new Configuration!ChromosomeType();
    conf.sampleChromosome = sampleChromosome; //set sample chromosome from which population is initialized
    conf.populationSize = 20;   //set size of population to work with
    conf.terminateFunction = compositeTerminate(
        maxGenerationsTerminate!(100),  //terminate after 100 generations
        noImprovementTerminate!(10)     //terminate if no better chromosome is found within 10 generations
    );
    conf.eliteSelectionOperator = eliteSelection!ChromosomeType(1); //keep the best chromosome unchanged for next population
    conf.parentSelectionOperator = tournamentSelection!ChromosomeType(5, 0.9); //parents are selected from tournament pools of size 5 with probability 0.9 that the best of the pool will will be selected
    conf.crossoverOperator = cutAndSpliceCrossover!ChromosomeType(); //simple crossover which can change number of genes in chromosome

    //set fitness function
    conf.fitnessFunction = simpleFitness!ChromosomeType(delegate (ch)
    {
        if(!ch.genes.length) return 0.0;

        auto r = reduce!("a+b.price", "a+b.time")(tuple(0.0, 0), ch.genes.map!(a=>appetizers[a.value]));
        return weightOfPrice/(1 + abs(targetPrice - r[0])) + cast(double)weightOfTime/r[1];
    });
    
    //set some callbacks
    conf.callbacks.onFitness = (const g, const ref s)
    {
        writeln();
        writeln("----------------------------------------------------------");
        writefln("Gen %s, Best: %s, Avg: %s, Cross: %s, Mut: %s", 
                 s.generations, s.bestFitness, s.averageFitness, s.crossovers, s.mutatedGenes);
        writeln(g.population);
    };
    
    //execute GA
    auto ga = new GA!ChromosomeType(conf);
    ga.run();
    
    writeln();
    auto r = reduce!("a+b.price", "a+b.time")(tuple(0.0, 0), ga.population.best.genes.map!(a => appetizers[a.value]));

    writefln("Total price: $%s, Total time: %s min", r[0], r[1]);
    foreach(g; ga.population.best.genes)
    {
        writeln(appetizers[g.value]);
    }
}
