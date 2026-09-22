class Config {
  // Project baseline settings
  final int formulasPerIndividual;
  final int populationSize;
  final long randomSeed;
  final float mutationRate;
  final float uniformMutationDelta;
  final float gaussianMutationSigma;
  final String crossoverOperator;
  final String mutationOperator;
  final long selectionSeed;
  final long crossoverSeed;
  final long mutationSeed;
  final String targetImagePath = "target.png";
  final int evaluationWidth = 256;
  final int evaluationHeight = 256;
  final int maxAutomaticGenerations = 200;
  final int eliteSize = 1;
  final int automaticBackground = 255;
  final int automaticStroke = 0;
  final float automaticStrokeWeightFraction = 0.002;

  final float aMin = 0.5;
  final float aMax = 2.0;
  final float bMin = 0.5;
  final float bMax = 2.0;
  final int mMin = 1;
  final int mMax = 12;
  final float n1Min = 0.2;
  final float n1Max = 5.0;
  final float n2Min = 0.2;
  final float n2Max = 5.0;
  final float n3Min = 0.2;
  final float n3Max = 5.0;

  final float thetaMin = 0.0;
  final float thetaMax = TWO_PI;
  final float thetaStep = 0.01;

  final int canvasWidth = 500;
  final int canvasHeight = 500;
  final float renderScale = 50.0;

  final float divisorEpsilon = 0.000001;
  final float n1Epsilon = 0.0001;
  final float maximumSafeRadius = 4.0;
  final float maximumInvalidSampleFraction = 0.25;

  Config() {
    this(
      30, 12345L, 1, 0.20, 0.10, 0.10,
      "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
    );
  }

  Config(int populationSize, long randomSeed) {
    this(
      populationSize, randomSeed, 1, 0.20, 0.10, 0.10,
      "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
    );
  }

  Config(int populationSize, long randomSeed, int formulasPerIndividual) {
    this(
      populationSize, randomSeed, formulasPerIndividual, 0.20, 0.10, 0.10,
      "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
    );
  }

  Config(
      int populationSize,
      long randomSeed,
      int formulasPerIndividual,
      float mutationRate,
      float uniformMutationDelta,
      float gaussianMutationSigma) {
    this(
      populationSize,
      randomSeed,
      formulasPerIndividual,
      mutationRate,
      uniformMutationDelta,
      gaussianMutationSigma,
      "PARAMETER_UNIFORM",
      "BOUNDED_UNIFORM_MUTATION"
    );
  }

  Config(
      int populationSize,
      long randomSeed,
      int formulasPerIndividual,
      float mutationRate,
      float uniformMutationDelta,
      float gaussianMutationSigma,
      String crossoverOperator,
      String mutationOperator) {
    this.populationSize = populationSize;
    this.randomSeed = randomSeed;
    this.formulasPerIndividual = formulasPerIndividual;
    this.mutationRate = mutationRate;
    this.uniformMutationDelta = uniformMutationDelta;
    this.gaussianMutationSigma = gaussianMutationSigma;
    this.crossoverOperator = crossoverOperator;
    this.mutationOperator = mutationOperator;
    selectionSeed = randomSeed + 6000L;
    crossoverSeed = randomSeed + 7000L;
    mutationSeed = randomSeed + 8000L;
  }

  void validate() {
    if (formulasPerIndividual <= 0) {
      throw new IllegalArgumentException("formulasPerIndividual must be positive");
    }
    if (populationSize <= 0) {
      throw new IllegalArgumentException("populationSize must be positive");
    }
    if (eliteSize > populationSize) {
      throw new IllegalArgumentException("eliteSize must be exactly 1 and fit the population");
    }
    if (targetImagePath == null || targetImagePath.length() == 0) {
      throw new IllegalArgumentException("targetImagePath must not be empty");
    }
    if (!isFinite(mutationRate) || mutationRate < 0 || mutationRate > 1) {
      throw new IllegalArgumentException("mutationRate must be in [0, 1]");
    }
    if (!isFinite(uniformMutationDelta)
        || uniformMutationDelta < 0
        || uniformMutationDelta > 1) {
      throw new IllegalArgumentException("uniformMutationDelta must be in [0, 1]");
    }
    if (!isFinite(gaussianMutationSigma)
        || gaussianMutationSigma < 0
        || gaussianMutationSigma > 1) {
      throw new IllegalArgumentException("gaussianMutationSigma must be in [0, 1]");
    }
    if (!("PARAMETER_UNIFORM".equals(crossoverOperator)
        || "WHOLE_FORMULA_UNIFORM".equals(crossoverOperator))) {
      throw new IllegalArgumentException("Unsupported crossoverOperator: " + crossoverOperator);
    }
    if (!("BOUNDED_UNIFORM_MUTATION".equals(mutationOperator)
        || "GAUSSIAN_PARAMETER_MUTATION".equals(mutationOperator))) {
      throw new IllegalArgumentException("Unsupported mutationOperator: " + mutationOperator);
    }

    validateFloatRange("a", aMin, aMax);
    validateFloatRange("b", bMin, bMax);
    validateFloatRange("n1", n1Min, n1Max);
    validateFloatRange("n2", n2Min, n2Max);
    validateFloatRange("n3", n3Min, n3Max);

    if (!isFinite(thetaMin) || !isFinite(thetaMax) || thetaMax <= thetaMin) {
      throw new IllegalArgumentException("theta bounds must be finite and increasing");
    }
    if (!isFinite(thetaStep) || thetaStep <= 0) {
      throw new IllegalArgumentException("thetaStep must be finite and positive");
    }

    if (!isFinite(renderScale) || renderScale <= 0) {
      throw new IllegalArgumentException("renderScale must be finite and positive");
    }

    if (!isFinite(automaticStrokeWeightFraction) || automaticStrokeWeightFraction <= 0) {
      throw new IllegalArgumentException("Automatic stroke-weight fraction must be positive");
    }
    if (!isFinite(divisorEpsilon) || divisorEpsilon <= 0) {
      throw new IllegalArgumentException("divisorEpsilon must be finite and positive");
    }
    if (!isFinite(n1Epsilon) || n1Epsilon <= 0 || n1Min <= n1Epsilon) {
      throw new IllegalArgumentException("n1Min must be safely above n1Epsilon");
    }
    if (!isFinite(maximumSafeRadius) || maximumSafeRadius <= 0) {
      throw new IllegalArgumentException("maximumSafeRadius must be finite and positive");
    }
    if (!isFinite(maximumInvalidSampleFraction)
        || maximumInvalidSampleFraction < 0
        || maximumInvalidSampleFraction > 1) {
      throw new IllegalArgumentException("maximumInvalidSampleFraction must be in [0, 1]");
    }
  }

  float decodeA(float normalized) {
    return decodeLinear(normalized, aMin, aMax);
  }

  float decodeB(float normalized) {
    return decodeLinear(normalized, bMin, bMax);
  }

  int decodeM(float normalized) {
    int numberOfValues = mMax - mMin + 1;
    int offset = min((int) floor(clampNormalized(normalized) * numberOfValues), numberOfValues - 1);
    return mMin + offset;
  }

  float decodeN1(float normalized) {
    return decodeLinear(normalized, n1Min, n1Max);
  }

  float decodeN2(float normalized) {
    return decodeLinear(normalized, n2Min, n2Max);
  }

  float decodeN3(float normalized) {
    return decodeLinear(normalized, n3Min, n3Max);
  }

  float encodeA(float decoded) {
    return encodeLinear("a", decoded, aMin, aMax);
  }

  float encodeB(float decoded) {
    return encodeLinear("b", decoded, bMin, bMax);
  }

  float encodeM(int decoded) {
    if (decoded < mMin || decoded > mMax) {
      throw new IllegalArgumentException("m must be inside the configured integer range");
    }
    // Encode at the centre of the integer's decoding bucket.
    return (decoded - mMin + 0.5) / (float) (mMax - mMin + 1);
  }

  float encodeN1(float decoded) {
    return encodeLinear("n1", decoded, n1Min, n1Max);
  }

  float encodeN2(float decoded) {
    return encodeLinear("n2", decoded, n2Min, n2Max);
  }

  float encodeN3(float decoded) {
    return encodeLinear("n3", decoded, n3Min, n3Max);
  }

  SuperFormulaGene geneFromDecoded(float a, float b, int m, float n1, float n2, float n3) {
    return new SuperFormulaGene(
      this,
      encodeA(a), encodeB(b), encodeM(m),
      encodeN1(n1), encodeN2(n2), encodeN3(n3)
    );
  }

  int thetaSampleCount() {
    return (int) ceil((thetaMax - thetaMin) / thetaStep);
  }


  float automaticStrokeWeight(int renderHeight) {
    if (renderHeight <= 0) {
      throw new IllegalArgumentException("Render height must be positive");
    }
    return renderHeight * automaticStrokeWeightFraction;
  }
  float clampNormalized(float value) {
    if (!isFinite(value)) {
      throw new IllegalArgumentException("Normalized genes must be finite");
    }
    return constrain(value, 0.0, 1.0);
  }

  boolean isFinite(float value) {
    return !Float.isNaN(value) && !Float.isInfinite(value);
  }

  private float decodeLinear(float normalized, float minimum, float maximum) {
    return minimum + clampNormalized(normalized) * (maximum - minimum);
  }

  private float encodeLinear(String name, float decoded, float minimum, float maximum) {
    if (!isFinite(decoded) || decoded < minimum || decoded > maximum) {
      throw new IllegalArgumentException(name + " must be finite and inside its configured range");
    }
    return (decoded - minimum) / (maximum - minimum);
  }

  private void validateFloatRange(String name, float minimum, float maximum) {
    if (!isFinite(minimum) || !isFinite(maximum) || maximum <= minimum) {
      throw new IllegalArgumentException(name + " bounds must be finite and increasing");
    }
  }
}
