class TargetEvaluation {
  final double rmse;
  final double normalizedRMSE;
  final double fitness;

  TargetEvaluation(double rmse, double normalizedRMSE, double fitness) {
    this.rmse = rmse;
    this.normalizedRMSE = normalizedRMSE;
    this.fitness = fitness;
  }
}

class TargetImageFitness {
  final Config config;
  final IndividualRenderer individualRenderer;
  PImage normalizedTarget;
  long targetRevision;

  TargetImageFitness(Config config, IndividualRenderer individualRenderer) {
    if (config == null || individualRenderer == null) {
      throw new IllegalArgumentException("TargetImageFitness requires Config and IndividualRenderer");
    }
    this.config = config;
    this.individualRenderer = individualRenderer;
  }

  boolean loadConfiguredTarget() {
    java.io.File configuredFile = new java.io.File(dataPath(config.targetImagePath));
    if (!configuredFile.isFile()) {
      normalizedTarget = null;
      printMissingTargetMessage();
      return false;
    }
    PImage loaded = loadImage(config.targetImagePath);
    if (loaded == null) {
      normalizedTarget = null;
      printMissingTargetMessage();
      return false;
    }
    println("Target source dimensions: " + loaded.width + "x" + loaded.height);
    setTarget(loaded);
    println(
      "Phase 10 target loaded: " + config.targetImagePath
      + " -> normalized " + normalizedTarget.width + "x" + normalizedTarget.height
    );
    return true;
  }

  void setTarget(PImage target) {
    normalizedTarget = normalizeTarget(target);
    targetRevision++;
  }

  boolean hasTarget() {
    return normalizedTarget != null;
  }

  long getTargetRevision() {
    return targetRevision;
  }

  TargetEvaluation evaluate(Individual individual) {
    if (normalizedTarget == null) {
      throw new IllegalStateException("No target image is loaded");
    }
    return evaluateAgainst(individual, normalizedTarget);
  }

  TargetEvaluation evaluateAgainst(Individual individual, PImage target) {
    if (individual == null) {
      throw new IllegalArgumentException("Target evaluation requires an Individual");
    }
    PImage candidate = renderCandidate(individual);
    PImage normalizedComparisonTarget = normalizeTarget(target);
    return compareImages(candidate, normalizedComparisonTarget);
  }

  PImage renderCandidate(Individual individual) {
    if (individual == null) {
      throw new IllegalArgumentException("Off-screen rendering requires an Individual");
    }
    PGraphics buffer = createGraphics(config.evaluationWidth, config.evaluationHeight, P2D);
    buffer.noSmooth();
    buffer.beginDraw();
    buffer.background(255);
    buffer.pushMatrix();
    buffer.translate(config.evaluationWidth * 0.5, config.evaluationHeight * 0.5);
    individualRenderer.render(individual, buffer);
    buffer.popMatrix();
    buffer.endDraw();
    return buffer.get();
  }

  TargetEvaluation compareImages(PImage candidate, PImage target) {
    validateComparableImages(candidate, target);
    candidate.loadPixels();
    target.loadPixels();
    int expectedLength = candidate.width * candidate.height;
    if (candidate.pixels.length != expectedLength || target.pixels.length != expectedLength) {
      throw new IllegalArgumentException("Image pixel arrays do not match their dimensions");
    }

    double squaredError = 0.0;
    for (int i = 0; i < expectedLength; i++) {
      int candidatePixel = candidate.pixels[i];
      int targetPixel = target.pixels[i];
      int redDifference = ((candidatePixel >> 16) & 0xff) - ((targetPixel >> 16) & 0xff);
      int greenDifference = ((candidatePixel >> 8) & 0xff) - ((targetPixel >> 8) & 0xff);
      int blueDifference = (candidatePixel & 0xff) - (targetPixel & 0xff);
      squaredError += (double) redDifference * redDifference;
      squaredError += (double) greenDifference * greenDifference;
      squaredError += (double) blueDifference * blueDifference;
    }

    double rmse = Math.sqrt(squaredError / (expectedLength * 3.0));
    double normalized = clampUnit(rmse / 255.0);
    double fitness = clampUnit(1.0 - normalized);
    if (Double.isNaN(rmse) || Double.isInfinite(rmse)) {
      throw new IllegalStateException("RMSE calculation produced a non-finite result");
    }
    return new TargetEvaluation(rmse, normalized, fitness);
  }

  private PImage normalizeTarget(PImage source) {
    if (source == null) {
      throw new IllegalArgumentException("Target image must not be null");
    }
    if (source.width <= 0 || source.height <= 0) {
      throw new IllegalArgumentException("Target image must have positive dimensions");
    }
    PGraphics normalized = createGraphics(config.evaluationWidth, config.evaluationHeight, P2D);
    normalized.noSmooth();
    normalized.beginDraw();
    normalized.background(255);
    normalized.imageMode(CORNER);
    // Fixed stretch-to-size policy; transparency is flattened against white.
    normalized.image(source, 0, 0, config.evaluationWidth, config.evaluationHeight);
    normalized.endDraw();
    return normalized.get();
  }

  private void validateComparableImages(PImage candidate, PImage target) {
    if (candidate == null || target == null) {
      throw new IllegalArgumentException("Candidate and target images must not be null");
    }
    if (candidate.width != target.width || candidate.height != target.height) {
      throw new IllegalArgumentException("Candidate and target dimensions must match");
    }
    if (candidate.width <= 0 || candidate.height <= 0) {
      throw new IllegalArgumentException("Comparable images must have positive dimensions");
    }
  }

  private double clampUnit(double value) {
    return Math.max(0.0, Math.min(1.0, value));
  }

  private void printMissingTargetMessage() {
    println(
      "Phase 10 target missing: place " + config.targetImagePath
      + " in the sketch data folder to enable manual target evaluation"
    );
  }
}
