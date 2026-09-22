enum EvolutionMode {
  INTERACTIVE,
  AUTOMATIC
}

class AutomaticEvolution {
  final Config config;
  final TargetImageFitness targetFitness;
  final Crossover crossover;
  final Mutation mutation;

  EvolutionMode mode = EvolutionMode.INTERACTIVE;
  boolean automaticRunning;
  double[] currentFitness;
  double bestFitness;
  double meanFitness;
  int bestIndex = -1;
  int evaluatedGeneration = -1;
  long evaluatedTargetRevision = -1;

  RouletteWheelSelection selection;
  java.util.Random crossoverRandom;
  java.util.Random mutationRandom;

  AutomaticEvolution(Config config, TargetImageFitness targetFitness,
      Crossover crossover, Mutation mutation) {
    if (config == null || targetFitness == null || crossover == null || mutation == null) {
      throw new IllegalArgumentException("AutomaticEvolution dependencies must not be null");
    }
    this.config = config;
    this.targetFitness = targetFitness;
    this.crossover = crossover;
    this.mutation = mutation;
    resetController();
  }

  void resetController() {
    automaticRunning = false;
    mode = EvolutionMode.INTERACTIVE;
    invalidateEvaluation();
    selection = new RouletteWheelSelection(config.selectionSeed);
    crossoverRandom = new java.util.Random(config.crossoverSeed);
    mutationRandom = new java.util.Random(config.mutationSeed);
  }

  boolean enterAutomaticMode(Population population) {
    requirePopulation(population);
    automaticRunning = false;
    mode = EvolutionMode.AUTOMATIC;
    if (!targetFitness.hasTarget()) {
      invalidateEvaluation();
      println("Automatic mode unavailable: target image missing.");
      return false;
    }
    evaluatePopulation(population);
    return true;
  }

  void enterInteractiveMode() {
    automaticRunning = false;
    mode = EvolutionMode.INTERACTIVE;
  }

  boolean start(Population population) {
    if (!enterAutomaticMode(population)) return false;
    if (population.getGeneration() >= config.maxAutomaticGenerations) {
      println("Automatic generation limit reached.");
      return false;
    }
    automaticRunning = true;
    return true;
  }

  void stop() {
    automaticRunning = false;
  }

  boolean step(Population population) {
    requirePopulation(population);
    mode = EvolutionMode.AUTOMATIC;
    if (!targetFitness.hasTarget()) {
      automaticRunning = false;
      invalidateEvaluation();
      println("Automatic mode unavailable: target image missing.");
      return false;
    }
    if (population.getGeneration() >= config.maxAutomaticGenerations) {
      automaticRunning = false;
      return false;
    }

    // Always re-evaluate before selection so target/genotype fitness cannot be stale.
    evaluatePopulation(population);
    return stepFromCurrentEvaluation(population);
  }

  boolean stepFromCurrentEvaluation(Population population) {
    requirePopulation(population);
    mode = EvolutionMode.AUTOMATIC;
    if (!targetFitness.hasTarget()) {
      automaticRunning = false;
      invalidateEvaluation();
      println("Automatic mode unavailable: target image missing.");
      return false;
    }
    if (population.getGeneration() >= config.maxAutomaticGenerations) {
      automaticRunning = false;
      return false;
    }
    if (!hasCurrentEvaluation(population)) {
      throw new IllegalStateException("Automatic fitness must be current before reproduction");
    }

    double[] weights = copyFitness();
    int generationBefore = population.getGeneration();
    population.nextGenerationFromWeights(
      weights, selection, crossover, mutation, crossoverRandom, mutationRandom
    );
    if (population.getGeneration() != generationBefore + 1) {
      throw new IllegalStateException("Automatic generation did not advance exactly once");
    }
    invalidateEvaluation();
    evaluatePopulation(population);
    if (population.getGeneration() >= config.maxAutomaticGenerations) {
      automaticRunning = false;
    }
    return true;
  }

  void updateOneFrame(Population population) {
    if (automaticRunning) step(population);
  }

  void evaluatePopulation(Population population) {
    requirePopulation(population);
    if (!targetFitness.hasTarget()) {
      throw new IllegalStateException("Automatic population evaluation requires a target image");
    }
    double[] evaluated = new double[population.size()];
    double sum = 0.0;
    for (int i = 0; i < population.size(); i++) {
      double fitness = targetFitness.evaluate(population.getIndividual(i)).fitness;
      if (Double.isNaN(fitness) || Double.isInfinite(fitness)
          || fitness < 0.0 || fitness > 1.0) {
        throw new IllegalStateException("Automatic fitness must be finite and inside [0, 1]");
      }
      evaluated[i] = fitness;
      sum += fitness;
    }
    population.sortByFitnessDescending(evaluated);
    currentFitness = evaluated;
    bestFitness = evaluated[0];
    bestIndex = 0;
    meanFitness = sum / evaluated.length;
    evaluatedGeneration = population.getGeneration();
    evaluatedTargetRevision = targetFitness.getTargetRevision();
  }

  boolean hasCurrentEvaluation(Population population) {
    return population != null && targetFitness.hasTarget() && currentFitness != null
      && currentFitness.length == population.size()
      && evaluatedGeneration == population.getGeneration()
      && evaluatedTargetRevision == targetFitness.getTargetRevision();
  }

  double getFitness(int index, Population population) {
    if (!hasCurrentEvaluation(population)) {
      throw new IllegalStateException("Automatic fitness is not current");
    }
    if (index < 0 || index >= currentFitness.length) {
      throw new IndexOutOfBoundsException("Automatic fitness index out of range: " + index);
    }
    return currentFitness[index];
  }

  double[] copyFitness() {
    if (currentFitness == null) {
      throw new IllegalStateException("Automatic population has not been evaluated");
    }
    return java.util.Arrays.copyOf(currentFitness, currentFitness.length);
  }

  void invalidateEvaluation() {
    currentFitness = null;
    bestFitness = 0.0;
    meanFitness = 0.0;
    bestIndex = -1;
    evaluatedGeneration = -1;
    evaluatedTargetRevision = -1;
  }

  private void requirePopulation(Population population) {
    if (population == null || population.size() <= 0) {
      throw new IllegalArgumentException("Automatic evolution requires a non-empty Population");
    }
  }
}
