class Population {
  final Config config;
  Individual[] individuals;
  int generation;

  Population(Config config) {
    if (config == null) {
      throw new IllegalArgumentException("Population requires a Config");
    }
    config.validate();
    this.config = config;
    individuals = new Individual[config.populationSize];
    reset();
  }

  void reset() {
    randomSeed(config.randomSeed);
    for (int i = 0; i < individuals.length; i++) {
      individuals[i] = createRandomIndividual();
    }
    generation = 0;
  }

  int size() {
    return individuals.length;
  }

  int getGeneration() {
    return generation;
  }

  Individual getIndividual(int index) {
    if (index < 0 || index >= individuals.length) {
      throw new IndexOutOfBoundsException("Population index out of range: " + index);
    }
    return individuals[index];
  }

  boolean nextGeneration(
      InteractiveFitness interactiveFitness,
      RouletteWheelSelection selection,
      Crossover crossover,
      Mutation mutation,
      java.util.Random crossoverRandom,
      java.util.Random mutationRandom) {
    validateEvolutionDependencies(
      interactiveFitness, selection, crossover, mutation, crossoverRandom, mutationRandom
    );
    if (!interactiveFitness.allRated(this)) {
      return false;
    }

    Individual[] nextIndividuals = new Individual[individuals.length];
    nextIndividuals[0] = getIndividual(bestRatedIndex(interactiveFitness)).deepCopy();
    validateChild(nextIndividuals[0]);
    for (int i = config.eliteSize; i < nextIndividuals.length; i++) {
      Individual parentA = getIndividual(selection.selectParentIndex(this));
      Individual parentB = getIndividual(selection.selectParentIndex(this));
      Individual crossed = applyCrossover(parentA, parentB, crossover, crossoverRandom);
      Individual child = applyMutation(crossed, mutation, mutationRandom);
      validateChild(child);
      nextIndividuals[i] = child;
    }

    validateNextPopulation(nextIndividuals);
    individuals = nextIndividuals;
    generation++;
    return true;
  }

  boolean nextGenerationFromWeights(
      double[] weights,
      RouletteWheelSelection selection,
      Crossover crossover,
      Mutation mutation,
      java.util.Random crossoverRandom,
      java.util.Random mutationRandom) {
    if (weights == null || weights.length != individuals.length) {
      throw new IllegalArgumentException("Automatic weights must match populationSize");
    }
    if (selection == null || crossover == null || mutation == null
        || crossoverRandom == null || mutationRandom == null) {
      throw new IllegalArgumentException("Automatic evolution dependencies must not be null");
    }
    selection.totalWeight(weights);

    Individual[] nextIndividuals = new Individual[individuals.length];
    nextIndividuals[0] = getIndividual(bestWeightIndex(weights)).deepCopy();
    validateChild(nextIndividuals[0]);
    for (int i = config.eliteSize; i < nextIndividuals.length; i++) {
      Individual parentA = getIndividual(selection.selectIndex(weights));
      Individual parentB = getIndividual(selection.selectIndex(weights));
      Individual crossed = applyCrossover(parentA, parentB, crossover, crossoverRandom);
      Individual child = applyMutation(crossed, mutation, mutationRandom);
      validateChild(child);
      nextIndividuals[i] = child;
    }

    validateNextPopulation(nextIndividuals);
    individuals = nextIndividuals;
    generation++;
    return true;
  }


  void sortByFitnessDescending(double[] fitnessValues) {
    if (fitnessValues == null || fitnessValues.length != individuals.length) {
      throw new IllegalArgumentException("Fitness values must match populationSize");
    }
    for (int i = 0; i < fitnessValues.length; i++) {
      if (Double.isNaN(fitnessValues[i]) || Double.isInfinite(fitnessValues[i])) {
        throw new IllegalArgumentException("Fitness values must be finite");
      }
    }

    // Stable insertion sort keeps the previous order when fitness values tie.
    for (int i = 1; i < individuals.length; i++) {
      Individual individual = individuals[i];
      double fitness = fitnessValues[i];
      int insertionIndex = i - 1;
      while (insertionIndex >= 0 && fitnessValues[insertionIndex] < fitness) {
        individuals[insertionIndex + 1] = individuals[insertionIndex];
        fitnessValues[insertionIndex + 1] = fitnessValues[insertionIndex];
        insertionIndex--;
      }
      individuals[insertionIndex + 1] = individual;
      fitnessValues[insertionIndex + 1] = fitness;
    }
  }



  private int bestRatedIndex(InteractiveFitness interactiveFitness) {
    int bestIndex = 0;
    int bestRating = interactiveFitness.getRating(getIndividual(0));
    for (int i = 1; i < individuals.length; i++) {
      int rating = interactiveFitness.getRating(getIndividual(i));
      if (rating > bestRating) {
        bestRating = rating;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  private int bestWeightIndex(double[] weights) {
    int bestIndex = 0;
    double bestWeight = weights[0];
    for (int i = 1; i < weights.length; i++) {
      if (weights[i] > bestWeight) {
        bestWeight = weights[i];
        bestIndex = i;
      }
    }
    return bestIndex;
  }
  private Individual createRandomIndividual() {
    SuperFormulaGene[] formulas = new SuperFormulaGene[config.formulasPerIndividual];
    for (int i = 0; i < formulas.length; i++) {
      formulas[i] = createRandomGene();
    }
    return new Individual(config, formulas);
  }

  private SuperFormulaGene createRandomGene() {
    return new SuperFormulaGene(
      config,
      random(1), random(1), random(1),
      random(1), random(1), random(1)
    );
  }

  private Individual applyCrossover(
      Individual parentA,
      Individual parentB,
      Crossover crossover,
      java.util.Random randomSource) {
    if ("PARAMETER_UNIFORM".equals(config.crossoverOperator)) {
      return crossover.parameterWiseUniform(parentA, parentB, randomSource);
    }
    if ("WHOLE_FORMULA_UNIFORM".equals(config.crossoverOperator)) {
      return crossover.wholeFormulaUniform(parentA, parentB, randomSource);
    }
    throw new IllegalStateException("Unsupported crossover operator: " + config.crossoverOperator);
  }

  private Individual applyMutation(
      Individual source,
      Mutation mutation,
      java.util.Random randomSource) {
    if ("BOUNDED_UNIFORM_MUTATION".equals(config.mutationOperator)) {
      return mutation.boundedUniform(source, randomSource);
    }
    if ("GAUSSIAN_PARAMETER_MUTATION".equals(config.mutationOperator)) {
      return mutation.gaussianParameters(source, randomSource);
    }
    throw new IllegalStateException("Unsupported mutation operator: " + config.mutationOperator);
  }

  private void validateEvolutionDependencies(
      InteractiveFitness interactiveFitness,
      RouletteWheelSelection selection,
      Crossover crossover,
      Mutation mutation,
      java.util.Random crossoverRandom,
      java.util.Random mutationRandom) {
    if (interactiveFitness == null
        || selection == null
        || crossover == null
        || mutation == null
        || crossoverRandom == null
        || mutationRandom == null) {
      throw new IllegalArgumentException("Interactive evolution dependencies must not be null");
    }
  }

  private void validateNextPopulation(Individual[] nextIndividuals) {
    if (nextIndividuals == null || nextIndividuals.length != config.populationSize) {
      throw new IllegalStateException("Next population must preserve configured populationSize");
    }
    for (int i = 0; i < nextIndividuals.length; i++) {
      validateChild(nextIndividuals[i]);
      for (int j = i + 1; j < nextIndividuals.length; j++) {
        if (nextIndividuals[i] == nextIndividuals[j]
            || nextIndividuals[i].formulas == nextIndividuals[j].formulas) {
          throw new IllegalStateException("Next population contains shared child storage");
        }
      }
    }
  }

  private void validateChild(Individual child) {
    if (child == null || child.getFormulaCount() != config.formulasPerIndividual) {
      throw new IllegalStateException("Evolution produced an invalid fixed-N child");
    }
    if (child.hasInteractiveRating()) {
      throw new IllegalStateException("Evolution child must start UNRATED");
    }
    for (int i = 0; i < child.getFormulaCount(); i++) {
      SuperFormulaGene gene = child.getFormula(i);
      if (!isNormalized(gene.aGene)
          || !isNormalized(gene.bGene)
          || !isNormalized(gene.mGene)
          || !isNormalized(gene.n1Gene)
          || !isNormalized(gene.n2Gene)
          || !isNormalized(gene.n3Gene)) {
        throw new IllegalStateException("Evolution child contains invalid normalized genes");
      }
      int decodedM = config.decodeM(gene.mGene);
      if (decodedM < config.mMin || decodedM > config.mMax) {
        throw new IllegalStateException("Evolution child contains invalid semantic m");
      }
    }
  }

  private boolean isNormalized(float value) {
    return !Float.isNaN(value) && !Float.isInfinite(value) && value >= 0.0 && value <= 1.0;
  }
}
