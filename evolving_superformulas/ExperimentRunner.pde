class ExperimentRunner {
  final Config config;
  final TargetImageFitness applicationTargetFitness;
  final String[] crossoverOperators = {
    "PARAMETER_UNIFORM", "WHOLE_FORMULA_UNIFORM"
  };
  final String[] mutationOperators = {
    "BOUNDED_UNIFORM_MUTATION", "GAUSSIAN_PARAMETER_MUTATION"
  };

  boolean running;
  java.io.File lastOutputDirectory;
  java.util.ArrayList<ExperimentCombinationSummary> lastCombinationSummaries =
    new java.util.ArrayList<ExperimentCombinationSummary>();
  long lastElapsedMs;

  ExperimentRunner(Config config, TargetImageFitness applicationTargetFitness) {
    if (config == null || applicationTargetFitness == null) {
      throw new IllegalArgumentException("ExperimentRunner requires Config and TargetImageFitness");
    }
    this.config = config;
    this.applicationTargetFitness = applicationTargetFitness;
  }

  boolean runAutomaticExperiments() {
    if (running) {
      println("[Experiment] A batch is already running.");
      return false;
    }
    if (!applicationTargetFitness.hasTarget()) {
      println("[Experiment] Aborted: configured target image is unavailable.");
      return false;
    }

    running = true;
    long startedAt = System.currentTimeMillis();
    ExperimentLogger logger = null;
    try {
      java.io.File outputDirectory = createIsolatedOutputDirectory();
      logger = new ExperimentLogger(outputDirectory, config);
      lastOutputDirectory = outputDirectory;
      lastCombinationSummaries.clear();

      int combinationIndex = 0;
      int totalRuns = crossoverOperators.length
        * mutationOperators.length * config.experimentRunsPerCombination;
      int completedRuns = 0;

      for (int crossoverIndex = 0;
          crossoverIndex < crossoverOperators.length; crossoverIndex++) {
        for (int mutationIndex = 0;
            mutationIndex < mutationOperators.length; mutationIndex++) {
          String crossoverName = crossoverOperators[crossoverIndex];
          String mutationName = mutationOperators[mutationIndex];
          java.util.ArrayList<ExperimentRunSummary> combinationRuns =
            new java.util.ArrayList<ExperimentRunSummary>();

          for (int runIndex = 0;
              runIndex < config.experimentRunsPerCombination; runIndex++) {
            completedRuns++;
            println(
              "[Experiment] " + completedRuns + "/" + totalRuns
              + " " + crossoverName + " + " + mutationName
              + " run " + (runIndex + 1) + "/" + config.experimentRunsPerCombination
            );
            ExperimentRunSummary summary = runSingleExperiment(
              logger, combinationIndex, runIndex, crossoverName, mutationName
            );
            combinationRuns.add(summary);
            logger.logRun(summary);
          }

          ExperimentCombinationSummary combinationSummary = summarizeCombination(
            crossoverName, mutationName, combinationRuns
          );
          lastCombinationSummaries.add(combinationSummary);
          logger.logCombination(combinationSummary);
          printCombinationSummary(combinationSummary);
          combinationIndex++;
        }
      }

      validateRowCounts(logger);
      lastElapsedMs = System.currentTimeMillis() - startedAt;
      println("[Experiment] Complete");
      println("[Experiment] Runs: " + totalRuns);
      println("[Experiment] Generation rows: " + logger.generationRowCount);
      println("[Experiment] Output: " + outputDirectory.getAbsolutePath());
      println("[Experiment] Elapsed: " + lastElapsedMs + " ms");
      return true;
    }
    finally {
      if (logger != null) logger.close();
      running = false;
    }
  }

  private ExperimentRunSummary runSingleExperiment(
      ExperimentLogger logger,
      int combinationIndex,
      int runIndex,
      String crossoverName,
      String mutationName) {
    long populationSeed = config.randomSeed + runIndex * config.experimentSeedStride;
    Config runConfig = new Config(
      config.populationSize,
      populationSeed,
      config.formulasPerIndividual,
      config.mutationRate,
      config.uniformMutationDelta,
      config.gaussianMutationSigma,
      crossoverName,
      mutationName
    );
    runConfig.validate();

    Population runPopulation = new Population(runConfig);
    SuperFormulaRenderer formulaRenderer = new SuperFormulaRenderer(runConfig);
    IndividualRenderer individualRenderer = new IndividualRenderer(runConfig, formulaRenderer);
    TargetImageFitness targetFitness = new TargetImageFitness(runConfig, individualRenderer);
    targetFitness.setPreprocessedTarget(applicationTargetFitness.normalizedTarget);
    AutomaticEvolution evolution = new AutomaticEvolution(
      runConfig, targetFitness, new Crossover(), new Mutation()
    );
    if (!evolution.enterAutomaticMode(runPopulation)) {
      throw new IllegalStateException("Experiment target unexpectedly became unavailable");
    }

    String runId = "combination_" + combinationIndex + "_run_" + runIndex;
    validateMetrics(evolution, runPopulation);
    double initialBest = evolution.bestFitness;
    double initialMean = evolution.meanFitness;
    double maxBest = initialBest;
    int generationOfMaxBest = 0;
    logger.logGeneration(
      runId, runIndex, runConfig, 0,
      evolution.bestFitness, evolution.meanFitness, evolution.bestIndex
    );

    for (int generation = 1; generation <= config.experimentGenerations; generation++) {
      if (!evolution.stepFromCurrentEvaluation(runPopulation)) {
        throw new IllegalStateException("Experiment stopped before generation " + generation);
      }
      if (runPopulation.getGeneration() != generation) {
        throw new IllegalStateException("Experiment generation counter is inconsistent");
      }
      validateMetrics(evolution, runPopulation);
      logger.logGeneration(
        runId, runIndex, runConfig, generation,
        evolution.bestFitness, evolution.meanFitness, evolution.bestIndex
      );
      if (evolution.bestFitness > maxBest) {
        maxBest = evolution.bestFitness;
        generationOfMaxBest = generation;
      }
      if (generation % 20 == 0 || generation == config.experimentGenerations) {
        println(
          "[Experiment] run " + (runIndex + 1)
          + " generation " + generation + "/" + config.experimentGenerations
        );
      }
    }

    ExperimentRunSummary summary = new ExperimentRunSummary(
      runId,
      runIndex,
      crossoverName,
      mutationName,
      initialBest,
      evolution.bestFitness,
      initialMean,
      evolution.meanFitness,
      maxBest,
      generationOfMaxBest,
      evolution.bestIndex,
      runConfig.randomSeed,
      runConfig.selectionSeed,
      runConfig.crossoverSeed,
      runConfig.mutationSeed
    );
    return summary;
  }

  private ExperimentCombinationSummary summarizeCombination(
      String crossoverName,
      String mutationName,
      java.util.ArrayList<ExperimentRunSummary> runs) {
    int count = runs.size();
    double[] finalBest = new double[count];
    double[] maxBest = new double[count];
    double finalMeanSum = 0.0;
    double maxGenerationSum = 0.0;
    for (int i = 0; i < count; i++) {
      ExperimentRunSummary run = runs.get(i);
      finalBest[i] = run.finalBestFitness;
      maxBest[i] = run.maxBestFitness;
      finalMeanSum += run.finalMeanFitness;
      maxGenerationSum += run.generationOfMaxBest;
    }
    return new ExperimentCombinationSummary(
      crossoverName,
      mutationName,
      count,
      mean(finalBest),
      sampleStandardDeviation(finalBest),
      mean(maxBest),
      sampleStandardDeviation(maxBest),
      finalMeanSum / count,
      maxGenerationSum / count
    );
  }

  private void validateMetrics(AutomaticEvolution evolution, Population population) {
    if (!evolution.hasCurrentEvaluation(population)) {
      throw new IllegalStateException("Experiment fitness is stale or missing");
    }
    if (!isValidFitness(evolution.bestFitness)
        || !isValidFitness(evolution.meanFitness)
        || evolution.bestFitness + 0.000000000001 < evolution.meanFitness
        || evolution.bestIndex < 0
        || evolution.bestIndex >= population.size()) {
      throw new IllegalStateException("Experiment produced invalid aggregate fitness metrics");
    }
    for (int i = 0; i < population.size(); i++) {
      if (!isValidFitness(evolution.getFitness(i, population))) {
        throw new IllegalStateException("Experiment produced invalid Individual fitness");
      }
    }
  }

  private boolean isValidFitness(double value) {
    return !Double.isNaN(value) && !Double.isInfinite(value)
      && value >= 0.0 && value <= 1.0;
  }

  private double mean(double[] values) {
    double sum = 0.0;
    for (int i = 0; i < values.length; i++) sum += values[i];
    return sum / values.length;
  }

  private double sampleStandardDeviation(double[] values) {
    if (values.length <= 1) return 0.0;
    double average = mean(values);
    double squaredDifferenceSum = 0.0;
    for (int i = 0; i < values.length; i++) {
      double difference = values[i] - average;
      squaredDifferenceSum += difference * difference;
    }
    // Sample standard deviation uses n - 1 for multiple experimental runs.
    return Math.sqrt(squaredDifferenceSum / (values.length - 1));
  }

  private void validateRowCounts(ExperimentLogger logger) {
    int combinationCount = crossoverOperators.length * mutationOperators.length;
    int expectedRuns = combinationCount * config.experimentRunsPerCombination;
    int expectedGenerationRows = expectedRuns * (config.experimentGenerations + 1);
    if (logger.generationRowCount != expectedGenerationRows
        || logger.runRowCount != expectedRuns
        || logger.combinationRowCount != combinationCount) {
      throw new IllegalStateException(
        "Experiment CSV row counts are incorrect: "
        + logger.generationRowCount + "/" + logger.runRowCount
        + "/" + logger.combinationRowCount
      );
    }
  }

  private java.io.File createIsolatedOutputDirectory() {
    java.text.SimpleDateFormat format = new java.text.SimpleDateFormat(
      "yyyyMMdd_HHmmss_SSS", java.util.Locale.US
    );
    String executionId = "exp_" + format.format(new java.util.Date());
    java.io.File experimentsDirectory = new java.io.File(sketchPath("experiments"));
    java.io.File candidate = new java.io.File(experimentsDirectory, executionId);
    int suffix = 1;
    while (candidate.exists()) {
      candidate = new java.io.File(experimentsDirectory, executionId + "_" + suffix);
      suffix++;
    }
    return candidate;
  }

  private void printCombinationSummary(ExperimentCombinationSummary summary) {
    println(
      "[Experiment Summary] " + summary.crossover + " + " + summary.mutation
      + " meanFinalBest=" + summary.meanFinalBest
      + " stdFinalBest=" + summary.stdFinalBest
      + " meanMaxBest=" + summary.meanMaxBest
      + " stdMaxBest=" + summary.stdMaxBest
      + " meanFinalMean=" + summary.meanFinalMean
      + " meanGenerationOfMaxBest=" + summary.meanGenerationOfMaxBest
    );
  }
}
