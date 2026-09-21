class RouletteWheelSelection {
  final InteractiveFitness interactiveFitness;
  final java.util.Random randomSource;

  RouletteWheelSelection(long seed) {
    interactiveFitness = null;
    randomSource = new java.util.Random(seed);
  }

  RouletteWheelSelection(InteractiveFitness interactiveFitness, long seed) {
    if (interactiveFitness == null) {
      throw new IllegalArgumentException("Roulette selection requires InteractiveFitness");
    }
    this.interactiveFitness = interactiveFitness;
    randomSource = new java.util.Random(seed);
  }

  int selectParentIndex(Population population) {
    if (population == null || population.size() <= 0) {
      throw new IllegalArgumentException("Roulette selection requires a non-empty Population");
    }
    if (interactiveFitness == null) {
      throw new IllegalStateException("This roulette selector has no interactive fitness policy");
    }
    if (!interactiveFitness.allRated(population)) {
      throw new IllegalStateException(
        "Every Individual must be rated before interactive roulette selection"
      );
    }

    double[] weights = new double[population.size()];
    for (int i = 0; i < population.size(); i++) {
      weights[i] = interactiveFitness.getInteractiveWeight(population.getIndividual(i));
    }
    return selectIndex(weights);
  }

  int selectIndex(double[] weights) {
    double total = totalWeight(weights);
    if (total == 0.0) {
      return randomSource.nextInt(weights.length);
    }

    double threshold = randomSource.nextDouble() * total;
    double cumulative = 0.0;
    int finalPositiveIndex = -1;
    for (int i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (weights[i] > 0.0) {
        finalPositiveIndex = i;
      }
      if (threshold < cumulative) {
        return i;
      }
    }

    // Defensive fallback for an unexpected floating-point edge at the upper bound.
    return finalPositiveIndex;
  }

  double totalWeight(double[] weights) {
    validateWeights(weights);
    double total = 0.0;
    for (int i = 0; i < weights.length; i++) {
      total += weights[i];
      if (Double.isInfinite(total)) {
        throw new IllegalArgumentException("Total roulette weight must be finite");
      }
    }
    return total;
  }

  private void validateWeights(double[] weights) {
    if (weights == null || weights.length == 0) {
      throw new IllegalArgumentException("Roulette weights must not be null or empty");
    }
    for (int i = 0; i < weights.length; i++) {
      if (Double.isNaN(weights[i]) || Double.isInfinite(weights[i]) || weights[i] < 0.0) {
        throw new IllegalArgumentException(
          "Roulette weight at index " + i + " must be finite and nonnegative"
        );
      }
    }
  }
}
