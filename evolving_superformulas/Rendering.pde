class SuperFormulaRenderer {
  final Config config;

  SuperFormulaRenderer(Config config) {
    this.config = config;
  }

  RenderStats render(SuperFormulaGene gene) {
    return render(gene, g);
  }

  RenderStats render(SuperFormulaGene gene, PGraphics target) {
    SuperFormulaSamples samples = sample(gene);

    if (samples.broadlyInvalid) {
      drawDiagnostic(target);
      return samples.stats;
    }

    applyStyle(target);

    boolean shapeOpen = false;
    for (int i = 0; i < samples.valid.length; i++) {
      if (!samples.valid[i]) {
        if (shapeOpen) {
          endShape(target);
          shapeOpen = false;
        }
        continue;
      }

      if (!shapeOpen) {
        beginShape(target);
        shapeOpen = true;
      }
      vertex(target, samples.x[i], samples.y[i]);
    }

    if (shapeOpen) {
      // Match the course example: the sampled revolution approaches closure naturally.
      endShape(target);
    }

    return samples.stats;
  }

  RenderStats validateGene(SuperFormulaGene gene) {
    return sample(gene).stats;
  }

  private SuperFormulaSamples sample(SuperFormulaGene gene) {
    DecodedSuperFormula parameters = gene.decode(config);
    int sampleCount = config.thetaSampleCount();
    SuperFormulaSamples samples = new SuperFormulaSamples(sampleCount);

    if (!parametersAreSafe(parameters)) {
      samples.markAllInvalid();
      return samples;
    }

    for (int i = 0; i < sampleCount; i++) {
      float theta = config.thetaMin + i * config.thetaStep;
      if (theta >= config.thetaMax) {
        break;
      }

      RadiusResult radius = calculateSafeRadius(theta, parameters);
      if (!radius.valid) {
        samples.recordInvalid(i);
        continue;
      }

      float x = radius.value * cos(theta) * config.renderScale;
      float y = radius.value * sin(theta) * config.renderScale;
      if (!config.isFinite(x) || !config.isFinite(y)) {
        samples.recordInvalid(i);
        continue;
      }

      samples.recordValid(i, x, y, radius.wasCapped);
    }

    samples.finish(config.maximumInvalidSampleFraction);
    return samples;
  }

  private RadiusResult calculateSafeRadius(float theta, DecodedSuperFormula p) {
    if (!config.isFinite(theta)) {
      return invalidRadius();
    }

    float cosineBase = abs(cos(p.m * theta / 4.0) / p.a);
    float sineBase = abs(sin(p.m * theta / 4.0) / p.b);
    if (!config.isFinite(cosineBase) || !config.isFinite(sineBase)) {
      return invalidRadius();
    }

    float cosineTerm = pow(cosineBase, p.n2);
    float sineTerm = pow(sineBase, p.n3);
    float sum = cosineTerm + sineTerm;
    float exponent = -1.0 / p.n1;
    if (!config.isFinite(cosineTerm)
        || !config.isFinite(sineTerm)
        || !config.isFinite(sum)
        || !config.isFinite(exponent)
        || sum <= 0) {
      return invalidRadius();
    }

    // This is the exact course equation, evaluated only after divisor safeguards.
    float radius = pow(
      pow(abs(cos(p.m * theta / 4.0) / p.a), p.n2)
      + pow(abs(sin(p.m * theta / 4.0) / p.b), p.n3),
      -1.0 / p.n1
    );
    if (!config.isFinite(radius)) {
      return invalidRadius();
    }

    boolean wasCapped = abs(radius) > config.maximumSafeRadius;
    float safeRadius = constrain(radius, -config.maximumSafeRadius, config.maximumSafeRadius);
    return new RadiusResult(true, safeRadius, wasCapped);
  }

  private RadiusResult invalidRadius() {
    return new RadiusResult(false, 0, false);
  }

  private boolean parametersAreSafe(DecodedSuperFormula p) {
    return config.isFinite(p.a)
      && config.isFinite(p.b)
      && config.isFinite(p.n1)
      && config.isFinite(p.n2)
      && config.isFinite(p.n3)
      && abs(p.a) > config.divisorEpsilon
      && abs(p.b) > config.divisorEpsilon
      && abs(p.n1) > config.n1Epsilon
      && p.m >= config.mMin
      && p.m <= config.mMax;
  }

  private void applyStyle(PGraphics target) {
    target.noFill();
    target.stroke(24);
    target.strokeWeight(config.strokeWeight);
  }

  private void beginShape(PGraphics target) {
    target.beginShape();
  }

  private void vertex(PGraphics target, float x, float y) {
    target.vertex(x, y);
  }

  private void endShape(PGraphics target) {
    target.endShape();
  }

  private void drawDiagnostic(PGraphics target) {
    float size = min(target.width, target.height) * 0.12;
    target.stroke(180, 30, 30);
    target.strokeWeight(config.strokeWeight);
    target.noFill();
    target.line(-size, -size, size, size);
    target.line(-size, size, size, -size);
  }
}

class IndividualRenderer {
  final Config config;
  final SuperFormulaRenderer formulaRenderer;

  IndividualRenderer(Config config, SuperFormulaRenderer formulaRenderer) {
    if (config == null || formulaRenderer == null) {
      throw new IllegalArgumentException("IndividualRenderer requires Config and SuperFormulaRenderer");
    }
    this.config = config;
    this.formulaRenderer = formulaRenderer;
  }

  IndividualRenderStats render(Individual individual) {
    return render(individual, g);
  }

  IndividualRenderStats render(Individual individual, PGraphics target) {
    if (individual == null) {
      throw new IllegalArgumentException("Individual must not be null");
    }
    if (individual.getFormulaCount() != config.formulasPerIndividual) {
      throw new IllegalArgumentException("Individual formula count does not match Config");
    }

    RenderStats[] layerStats = new RenderStats[individual.getFormulaCount()];
    for (int i = 0; i < individual.getFormulaCount(); i++) {
      // Every layer shares the caller's current centre, scale, and coordinate system.
      layerStats[i] = formulaRenderer.render(individual.getFormula(i), target);
    }
    return new IndividualRenderStats(layerStats);
  }
}

class IndividualRenderStats {
  final RenderStats[] layers;

  IndividualRenderStats(RenderStats[] layers) {
    this.layers = layers;
  }

  int getRenderedLayerCount() {
    return layers.length;
  }

  RenderStats getLayerStats(int index) {
    if (index < 0 || index >= layers.length) {
      throw new IndexOutOfBoundsException("Layer index out of range: " + index);
    }
    return layers[index];
  }
}

class SuperFormulaSamples {
  final float[] x;
  final float[] y;
  final boolean[] valid;
  final RenderStats stats;
  boolean broadlyInvalid;

  SuperFormulaSamples(int sampleCount) {
    x = new float[sampleCount];
    y = new float[sampleCount];
    valid = new boolean[sampleCount];
    stats = new RenderStats(sampleCount);
  }

  void recordValid(int index, float xValue, float yValue, boolean wasCapped) {
    x[index] = xValue;
    y[index] = yValue;
    valid[index] = true;
    stats.validSamples++;
    if (wasCapped) {
      stats.cappedSamples++;
    }
  }

  void recordInvalid(int index) {
    valid[index] = false;
    stats.invalidSamples++;
  }

  void markAllInvalid() {
    stats.invalidSamples = stats.totalSamples;
    broadlyInvalid = true;
  }

  void finish(float maximumInvalidFraction) {
    float invalidFraction = stats.invalidSamples / (float) stats.totalSamples;
    broadlyInvalid = stats.validSamples < 2 || invalidFraction > maximumInvalidFraction;
  }
}

class RenderStats {
  final int totalSamples;
  int validSamples;
  int invalidSamples;
  int cappedSamples;

  RenderStats(int totalSamples) {
    this.totalSamples = totalSamples;
  }

  boolean isBroadlyValid(Config config) {
    return validSamples >= 2
      && invalidSamples / (float) totalSamples <= config.maximumInvalidSampleFraction;
  }
}

class RadiusResult {
  final boolean valid;
  final float value;
  final boolean wasCapped;

  RadiusResult(boolean valid, float value, boolean wasCapped) {
    this.valid = valid;
    this.value = value;
    this.wasCapped = wasCapped;
  }

}
