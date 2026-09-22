class ExperimentRunSummary {
  final String runId;
  final int runIndex;
  final String crossover;
  final String mutation;
  final double initialBestFitness;
  final double finalBestFitness;
  final double initialMeanFitness;
  final double finalMeanFitness;
  final double maxBestFitness;
  final int generationOfMaxBest;
  final int finalBestIndex;
  final long populationSeed;
  final long selectionSeed;
  final long crossoverSeed;
  final long mutationSeed;

  ExperimentRunSummary(
      String runId, int runIndex, String crossover, String mutation,
      double initialBestFitness, double finalBestFitness,
      double initialMeanFitness, double finalMeanFitness,
      double maxBestFitness, int generationOfMaxBest, int finalBestIndex,
      long populationSeed, long selectionSeed, long crossoverSeed, long mutationSeed) {
    this.runId = runId;
    this.runIndex = runIndex;
    this.crossover = crossover;
    this.mutation = mutation;
    this.initialBestFitness = initialBestFitness;
    this.finalBestFitness = finalBestFitness;
    this.initialMeanFitness = initialMeanFitness;
    this.finalMeanFitness = finalMeanFitness;
    this.maxBestFitness = maxBestFitness;
    this.generationOfMaxBest = generationOfMaxBest;
    this.finalBestIndex = finalBestIndex;
    this.populationSeed = populationSeed;
    this.selectionSeed = selectionSeed;
    this.crossoverSeed = crossoverSeed;
    this.mutationSeed = mutationSeed;
  }
}

class ExperimentCombinationSummary {
  final String crossover;
  final String mutation;
  final int runs;
  final double meanFinalBest;
  final double stdFinalBest;
  final double meanMaxBest;
  final double stdMaxBest;
  final double meanFinalMean;
  final double meanGenerationOfMaxBest;

  ExperimentCombinationSummary(
      String crossover, String mutation, int runs,
      double meanFinalBest, double stdFinalBest,
      double meanMaxBest, double stdMaxBest,
      double meanFinalMean, double meanGenerationOfMaxBest) {
    this.crossover = crossover;
    this.mutation = mutation;
    this.runs = runs;
    this.meanFinalBest = meanFinalBest;
    this.stdFinalBest = stdFinalBest;
    this.meanMaxBest = meanMaxBest;
    this.stdMaxBest = stdMaxBest;
    this.meanFinalMean = meanFinalMean;
    this.meanGenerationOfMaxBest = meanGenerationOfMaxBest;
  }
}

class ExperimentLogger {
  final java.io.File outputDirectory;
  final java.io.PrintWriter generationWriter;
  final java.io.PrintWriter runWriter;
  final java.io.PrintWriter combinationWriter;
  final java.io.PrintWriter metadataWriter;
  int generationRowCount;
  int runRowCount;
  int combinationRowCount;

  ExperimentLogger(java.io.File outputDirectory, Config config) {
    if (outputDirectory == null || config == null) {
      throw new IllegalArgumentException("Experiment logger requires an output directory and Config");
    }
    if (outputDirectory.exists()) {
      throw new IllegalStateException("Experiment output directory already exists");
    }
    if (!outputDirectory.mkdirs()) {
      throw new IllegalStateException("Could not create experiment output directory");
    }
    this.outputDirectory = outputDirectory;
    generationWriter = createWriter(new java.io.File(
      outputDirectory, "automatic_generation_log.csv"
    ).getAbsolutePath());
    runWriter = createWriter(new java.io.File(
      outputDirectory, "automatic_run_summary.csv"
    ).getAbsolutePath());
    combinationWriter = createWriter(new java.io.File(
      outputDirectory, "automatic_combination_summary.csv"
    ).getAbsolutePath());
    metadataWriter = createWriter(new java.io.File(
      outputDirectory, "phase_14_metadata.csv"
    ).getAbsolutePath());
    writeHeaders();
    writeMetadata(config);
  }

  void logGeneration(
      String runId, int runIndex, Config runConfig, int generation,
      double bestFitness, double meanFitness, int bestIndex) {
    generationWriter.println(
      runId + "," + runIndex
      + "," + runConfig.crossoverOperator
      + "," + runConfig.mutationOperator
      + "," + runConfig.targetImagePath
      + "," + runConfig.populationSize
      + "," + runConfig.formulasPerIndividual
      + "," + decimal(runConfig.mutationRate)
      + "," + decimal(runConfig.uniformMutationDelta)
      + "," + decimal(runConfig.gaussianMutationSigma)
      + "," + runConfig.evaluationWidth
      + "," + runConfig.evaluationHeight
      + "," + runConfig.experimentGenerations
      + "," + runConfig.randomSeed
      + "," + runConfig.selectionSeed
      + "," + runConfig.crossoverSeed
      + "," + runConfig.mutationSeed
      + "," + generation
      + "," + decimal(bestFitness)
      + "," + decimal(meanFitness)
      + "," + bestIndex
    );
    generationRowCount++;
  }

  void logRun(ExperimentRunSummary summary) {
    runWriter.println(
      summary.runId + "," + summary.runIndex
      + "," + summary.crossover + "," + summary.mutation
      + "," + decimal(summary.initialBestFitness)
      + "," + decimal(summary.finalBestFitness)
      + "," + decimal(summary.finalBestFitness - summary.initialBestFitness)
      + "," + decimal(summary.initialMeanFitness)
      + "," + decimal(summary.finalMeanFitness)
      + "," + decimal(summary.finalMeanFitness - summary.initialMeanFitness)
      + "," + decimal(summary.maxBestFitness)
      + "," + summary.generationOfMaxBest
      + "," + summary.finalBestIndex
      + "," + summary.populationSeed
      + "," + summary.selectionSeed
      + "," + summary.crossoverSeed
      + "," + summary.mutationSeed
    );
    runRowCount++;
  }

  void logCombination(ExperimentCombinationSummary summary) {
    combinationWriter.println(
      summary.crossover + "," + summary.mutation + "," + summary.runs
      + "," + decimal(summary.meanFinalBest)
      + "," + decimal(summary.stdFinalBest)
      + "," + decimal(summary.meanMaxBest)
      + "," + decimal(summary.stdMaxBest)
      + "," + decimal(summary.meanFinalMean)
      + "," + decimal(summary.meanGenerationOfMaxBest)
    );
    combinationRowCount++;
  }

  void close() {
    generationWriter.flush();
    runWriter.flush();
    combinationWriter.flush();
    metadataWriter.flush();
    generationWriter.close();
    runWriter.close();
    combinationWriter.close();
    metadataWriter.close();
  }

  private void writeMetadata(Config config) {
    metadataWriter.println("key,value");
    metadataWriter.println("populationSize," + config.populationSize);
    metadataWriter.println("eliteSize," + config.eliteSize);
    metadataWriter.println("fitnessMetric,blue-channel RMSE");
    metadataWriter.println("pixelRepresentation,pixel & 0xFF");
    metadataWriter.println("renderBackground," + config.automaticBackground);
    metadataWriter.println("renderStroke," + config.automaticStroke);
    metadataWriter.println("strokeWeight,height * " + config.automaticStrokeWeightFraction);
    metadataWriter.println(
      "evaluationResolution," + config.evaluationWidth + "x" + config.evaluationHeight
    );
    metadataWriter.println("targetResize,source.copy() then resize(width height)");
  }

  private void writeHeaders() {
    generationWriter.println(
      "run_id,run_index,crossover,mutation,target,population_size,formulas_per_individual,"
      + "mutation_rate,uniform_delta,gaussian_sigma,evaluation_width,evaluation_height,"
      + "experiment_generations,population_seed,selection_seed,crossover_seed,mutation_seed,"
      + "generation,best_fitness,mean_fitness,best_index"
    );
    runWriter.println(
      "run_id,run_index,crossover,mutation,initial_best_fitness,final_best_fitness,"
      + "best_fitness_change,initial_mean_fitness,final_mean_fitness,mean_fitness_change,"
      + "max_best_fitness,generation_of_max_best,final_best_index,population_seed,"
      + "selection_seed,crossover_seed,mutation_seed"
    );
    combinationWriter.println(
      "crossover,mutation,runs,mean_final_best,std_final_best,mean_max_best,std_max_best,"
      + "mean_final_mean,mean_generation_of_max_best"
    );
  }

  private String decimal(double value) {
    return String.format(java.util.Locale.US, "%.10f", value);
  }
}
