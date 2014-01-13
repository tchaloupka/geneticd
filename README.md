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

Library can be used to solve basic problems already.
Currently encoding with scalar value gene chromosomes is supported.
Common selection and crossover operators are implemented.

Note
----
I'm not an genetic or evolution algorithms expert nor experienced D programmer (still learning). So any advice is welcome :)

Sample
------

For advanced samples look to the examples directory in the library.

```D
    // Guessing of the array content

    alias Chromosome!(ScalarGene!bool) chromoType;   // define chromosome type

    //init target array
    enum size = 20;
    bool[] target;

    foreach(i; 0..size)
    {
        target ~= dice(0.5, 0.5) == 1;
    }

    //create GA configuration
    auto conf = new Configuration!chromoType(new chromoType(new ScalarGene!bool(), size)); //config with sample chromosome to init population with
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
```

TODO
----
- [x] Scalar gene with boundaries
- [x] Traveling salesman problem example
- [ ] Knapsack problem example
- [ ] Target number game example
- [ ] Saving/loading population to/from file
- [ ] Parallel processing (probably chunk the population and fitness chunks in own tasks)
- [ ] ??? (fill the bug or pull request)
