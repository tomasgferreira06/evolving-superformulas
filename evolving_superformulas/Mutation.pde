class MutationStats {
  int opportunities;
  int executedBranches;

  void record(boolean executed) {
    opportunities++;
    if (executed) executedBranches++;
  }
}

class Mutation {
  final String BOUNDED_UNIFORM_MUTATION = "BOUNDED_UNIFORM_MUTATION";
  final String GAUSSIAN_PARAMETER_MUTATION = "GAUSSIAN_PARAMETER_MUTATION";

  Individual boundedUniform(Individual source, java.util.Random randomSource) {
    return boundedUniform(source, randomSource, null);
  }

  Individual boundedUniform(
      Individual source,
      java.util.Random randomSource,
      MutationStats stats) {
    validateInputs(source, randomSource);
    Config config = source.config;
    SuperFormulaGene[] result = new SuperFormulaGene[source.getFormulaCount()];
    for (int i = 0; i < result.length; i++) {
      SuperFormulaGene gene = source.getFormula(i);
      result[i] = new SuperFormulaGene(
        config,
        mutateUniformContinuous(gene.aGene, config, randomSource, stats),
        mutateUniformContinuous(gene.bGene, config, randomSource, stats),
        mutateUniformM(gene.mGene, config, randomSource, stats),
        mutateUniformContinuous(gene.n1Gene, config, randomSource, stats),
        mutateUniformContinuous(gene.n2Gene, config, randomSource, stats),
        mutateUniformContinuous(gene.n3Gene, config, randomSource, stats)
      );
    }
    return new Individual(config, result);
  }

  Individual gaussianParameters(Individual source, java.util.Random randomSource) {
    return gaussianParameters(source, randomSource, null);
  }

  Individual gaussianParameters(
      Individual source,
      java.util.Random randomSource,
      MutationStats stats) {
    validateInputs(source, randomSource);
    Config config = source.config;
    SuperFormulaGene[] result = new SuperFormulaGene[source.getFormulaCount()];
    for (int i = 0; i < result.length; i++) {
      SuperFormulaGene gene = source.getFormula(i);
      result[i] = new SuperFormulaGene(
        config,
        mutateGaussianContinuous(gene.aGene, config, randomSource, stats),
        mutateGaussianContinuous(gene.bGene, config, randomSource, stats),
        mutateGaussianM(gene.mGene, config, randomSource, stats),
        mutateGaussianContinuous(gene.n1Gene, config, randomSource, stats),
        mutateGaussianContinuous(gene.n2Gene, config, randomSource, stats),
        mutateGaussianContinuous(gene.n3Gene, config, randomSource, stats)
      );
    }
    return new Individual(config, result);
  }

  private float mutateUniformContinuous(
      float value,
      Config config,
      java.util.Random randomSource,
      MutationStats stats) {
    if (!shouldMutate(config, randomSource, stats)) return value;
    float delta = (float) ((randomSource.nextDouble() * 2.0 - 1.0) * config.uniformMutationDelta);
    return config.clampNormalized(value + delta);
  }

  private float mutateGaussianContinuous(
      float value,
      Config config,
      java.util.Random randomSource,
      MutationStats stats) {
    if (!shouldMutate(config, randomSource, stats)) return value;
    float delta = (float) (randomSource.nextGaussian() * config.gaussianMutationSigma);
    return config.clampNormalized(value + delta);
  }

  private float mutateUniformM(
      float value,
      Config config,
      java.util.Random randomSource,
      MutationStats stats) {
    if (!shouldMutate(config, randomSource, stats)) return value;
    int step = randomSource.nextBoolean() ? 1 : -1;
    int mutatedM = clampDiscreteM((long) config.decodeM(value) + step, config);
    return config.encodeM(mutatedM);
  }

  private float mutateGaussianM(
      float value,
      Config config,
      java.util.Random randomSource,
      MutationStats stats) {
    if (!shouldMutate(config, randomSource, stats)) return value;
    long step = Math.round(randomSource.nextGaussian());
    if (step == 0) step = randomSource.nextBoolean() ? 1 : -1;
    int mutatedM = clampDiscreteM((long) config.decodeM(value) + step, config);
    return config.encodeM(mutatedM);
  }

  private boolean shouldMutate(
      Config config,
      java.util.Random randomSource,
      MutationStats stats) {
    boolean mutate = randomSource.nextDouble() < config.mutationRate;
    if (stats != null) stats.record(mutate);
    return mutate;
  }

  private int clampDiscreteM(long value, Config config) {
    if (value < config.mMin) return config.mMin;
    if (value > config.mMax) return config.mMax;
    return (int) value;
  }

  private void validateInputs(Individual source, java.util.Random randomSource) {
    if (source == null) throw new IllegalArgumentException("Mutation requires a source Individual");
    if (randomSource == null) throw new IllegalArgumentException("Mutation requires a random source");
    source.config.validate();
    if (source.getFormulaCount() != source.config.formulasPerIndividual) {
      throw new IllegalArgumentException("Mutation source formula count must match Config");
    }
    for (int i = 0; i < source.getFormulaCount(); i++) validateGene(source.getFormula(i), i);
  }

  private void validateGene(SuperFormulaGene gene, int formulaIndex) {
    if (gene == null
        || !isNormalized(gene.aGene)
        || !isNormalized(gene.bGene)
        || !isNormalized(gene.mGene)
        || !isNormalized(gene.n1Gene)
        || !isNormalized(gene.n2Gene)
        || !isNormalized(gene.n3Gene)) {
      throw new IllegalArgumentException(
        "Mutation source formula " + formulaIndex + " contains invalid normalized genes"
      );
    }
  }

  private boolean isNormalized(float value) {
    return !Float.isNaN(value) && !Float.isInfinite(value) && value >= 0.0 && value <= 1.0;
  }
}
