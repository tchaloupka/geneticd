geneticd
========

Simple Genetic Algorithm Library for D.

Instalation
-----------
It is recommended to use [DUB](https://github.com/rejectedsoftware/dub) for including the library to other projects.
Add the following dependency to the `package.json` file in your project's directory:

    {
        "name": "your-project-identifier",
        "dependencies": {
            "geneticd": "~master"
        }
    }

Status
------

First target is single threaded evaluation of GA with possibility to use custom genes, fitness functions, terminate functions, selection functions, mutation operators, etc.

Currently simple BoolGene chromosomes can be evaluated with some variations of selection and crossover operators.

Note
----
I'm not an genetic or evolution algorithms expert nor experienced D programmer (still learning). So any advice is welcome :)

Sample
------

    // Guessing of the array content

    alias Chromosome!BoolGene chromoType;   // define chromosome type

    //init target array
    enum size = 20;
    bool[] target;

    foreach(i; 0..size)
    {
        target ~= to!bool(uniform!"[]"(0, 1));
    }

    //create GA configuration
    auto conf = new Configuration!chromoType(new chromoType(new BoolGene(), size)); //config with sample chromosome to init population with
    conf.populationSize = 10;   //size of the population

    //set fitness function
    conf.fitnessFunction = simpleFitness!chromoType(delegate (ch)
    {
        //add to tmp if chromosome and target are same so max fitness = 20
        uint tmp;
        foreach(i; 0..size)
        {
            if(target[i] == ch[i]) ++tmp;
        }

        return cast(double)tmp;
    });

    //set terminate function
    conf.terminateFunction = compositeTerminate( //GA is terminated if one of conditions is met
        maxGenerationsTerminate!(100),  //limit to max 100 generations
        fitnessTerminate!size); //target fitness is size of genomes

    //add GA operations
    conf.eliteSelectionOperator = eliteSelection!chromoType; // best chromosome allways survives
    conf.parentSelectionOperator = weightedRouletteSelection!chromoType(); //select parent chromosomes to crossover and mutate
    conf.crossoverOperator = singlePointCrossover!chromoType(); //type of crossover operator

    //execute GA
    auto ga = new GA!chromoType(conf);
    ga.run(); //does return after one of terminate condition is met

    writefln("Input: [%s]", target.map!(to!string).joiner(", "));
    writefln("Best: [%s]", ga.population.best);

TODO
----
    - add numeric genes with boundaries
    - create some samples to solve known problems and to show how to use the lib
    - saving/loading population to/from file
    - parallel processing (probably chunk the population and fitness chunks in own tasks)
    - ??? (fill the bug or pull request)