Config config = new Config();
SuperFormulaRenderer formulaRenderer;
IndividualRenderer individualRenderer;
Population population;
InteractiveUI interactiveUI;
InteractiveFitness interactiveFitness;
RouletteWheelSelection rouletteSelection;
Crossover crossover;
Mutation mutation;
java.util.Random crossoverRandom;
java.util.Random mutationRandom;
TargetImageFitness targetFitness;
boolean configuredTargetLoaded;
AutomaticEvolution automaticEvolution;
int renderedIndividualCount;

void settings() {
  size(config.canvasWidth, config.canvasHeight, P2D);
}

void setup() {
  int startupStartedAt = millis();
  println("Startup mode: " + (config.runStartupValidation ? "FULL VALIDATION" : "NORMAL"));
  config.validate();
  formulaRenderer = new SuperFormulaRenderer(config);
  individualRenderer = new IndividualRenderer(config, formulaRenderer);
  population = new Population(config);
  interactiveFitness = new InteractiveFitness();
  interactiveUI = new InteractiveUI(config, individualRenderer, interactiveFitness);
  rouletteSelection = new RouletteWheelSelection(interactiveFitness, config.selectionSeed);
  crossover = new Crossover();
  mutation = new Mutation();
  targetFitness = new TargetImageFitness(config, individualRenderer);
  resetInteractiveRun();

  if (config.runStartupValidation) {
    int validationStartedAt = millis();
    runFullStartupValidation();
    println("Validation completed in " + (millis() - validationStartedAt) + " ms");
  }

  configuredTargetLoaded = targetFitness.loadConfiguredTarget();
  automaticEvolution = new AutomaticEvolution(config, targetFitness, crossover, mutation);
  interactiveUI.setAutomaticEvolution(automaticEvolution);
  if (configuredTargetLoaded) {
    TargetEvaluation evaluation = targetFitness.evaluate(population.getIndividual(0));
    println(
      "Phase 10 population[0] target fitness=" + evaluation.fitness
      + " normalizedRMSE=" + evaluation.normalizedRMSE
    );
  }
  println("Startup completed in " + (millis() - startupStartedAt) + " ms");
}

void runFullStartupValidation() {
  runPhaseOneAndTwoRegressionChecks();
  runPhaseThreeChecks(population);
  population.reset();
  runPhaseFourChecks(population);
  runPhaseFiveChecks(population);
  runPhaseSixChecks(population);
  runPhaseSevenChecks(population);
  runPhaseEightChecks(population);
  runPhaseNineChecks(population);
  resetInteractiveRun();
  runPhaseTenChecks(population);
  resetInteractiveRun();
  runPhaseElevenChecks();
  runPhaseFourteenChecks();
  resetInteractiveRun();
}

void draw() {
  if (automaticEvolution != null) automaticEvolution.updateOneFrame(population);
  background(255);
  renderedIndividualCount = interactiveUI.renderPopulation(
    population, width, height, mouseX, mouseY
  );
  require(renderedIndividualCount == population.size(),
    "Grid did not render every population member exactly once");
}

void mouseReleased() {
  interactiveUI.ensureLayout(width, height, population.size());
  interactiveUI.selectAt(mouseX, mouseY);
}

void keyReleased() {
  if (key == 'a' || key == 'A') {
    automaticEvolution.start(population);
    return;
  }
  if (key == 's' || key == 'S') {
    automaticEvolution.stop();
    return;
  }
  if (key == 'n' || key == 'N') {
    automaticEvolution.stop();
    automaticEvolution.step(population);
    return;
  }
  if (key == 'i' || key == 'I') {
    automaticEvolution.enterInteractiveMode();
    return;
  }
  if (key == 'r' || key == 'R') {
    resetInteractiveRun();
    return;
  }

  if (automaticEvolution != null && automaticEvolution.mode == EvolutionMode.AUTOMATIC) return;
  int rating = ratingForKey(key);
  if (rating != -1) interactiveUI.rateSelected(population, rating);
  else if (keyCode == BACKSPACE || keyCode == DELETE) interactiveUI.clearSelectedRating(population);
  else if (keyCode == ENTER || keyCode == RETURN || key == ' ') evolveCurrentPopulation();
}

boolean evolveCurrentPopulation() {
  boolean evolved = population.nextGeneration(
    interactiveFitness,
    rouletteSelection,
    crossover,
    mutation,
    crossoverRandom,
    mutationRandom
  );
  if (evolved) {
    interactiveUI.clearInteraction();
    interactiveUI.ensureLayout(width, height, population.size());
  }
  return evolved;
}

void resetInteractiveRun() {
  population.reset();
  rouletteSelection = new RouletteWheelSelection(interactiveFitness, config.selectionSeed);
  crossoverRandom = new java.util.Random(config.crossoverSeed);
  mutationRandom = new java.util.Random(config.mutationSeed);
  if (automaticEvolution != null) automaticEvolution.resetController();
  interactiveUI.clearInteraction();
  interactiveUI.ensureLayout(width, height, population.size());
}

int ratingForKey(char pressedKey) {
  if (pressedKey >= '1' && pressedKey <= '9') return pressedKey - '0';
  return pressedKey == '0' ? 10 : -1;
}

void runPhaseOneAndTwoRegressionChecks() {
  require(config.formulasPerIndividual > 0, "Fixed N must be positive");
  SuperFormulaGene formulaA = config.geneFromDecoded(2, 2, 6, 1, 1, 1);
  SuperFormulaGene formulaB = config.geneFromDecoded(1, 1, 5, 1, 2, 2);
  SuperFormulaGene[] constructorInput = new SuperFormulaGene[config.formulasPerIndividual];
  for (int i = 0; i < constructorInput.length; i++) {
    constructorInput[i] = i % 2 == 0 ? formulaA : formulaB;
  }
  Individual original = new Individual(config, constructorInput);

  DecodedSuperFormula decodedReference = formulaA.decode(config);
  require(nearlyEqual(decodedReference.a, 2), "Phase 1: a did not decode to 2");
  require(nearlyEqual(decodedReference.b, 2), "Phase 1: b did not decode to 2");
  require(decodedReference.m == 6, "Phase 1: m did not decode to 6");
  require(nearlyEqual(decodedReference.n1, 1), "Phase 1: n1 did not decode to 1");
  require(nearlyEqual(decodedReference.n2, 1), "Phase 1: n2 did not decode to 1");
  require(nearlyEqual(decodedReference.n3, 1), "Phase 1: n3 did not decode to 1");

  SuperFormulaGene boundaryGene = config.geneFromDecoded(
    config.aMax, config.bMax, config.mMax,
    config.n1Min, config.n2Max, config.n3Max
  );
  require(formulaRenderer.validateGene(formulaA).isBroadlyValid(config),
    "Phase 1 reference formula was not broadly valid");
  require(formulaRenderer.validateGene(formulaB).isBroadlyValid(config),
    "Phase 1 alternate formula was not broadly valid");
  RenderStats boundaryStats = formulaRenderer.validateGene(boundaryGene);
  require(boundaryStats.isBroadlyValid(config), "Phase 1 boundary formula was not broadly valid");
  require(boundaryStats.cappedSamples > 0, "Phase 1 radius cap regression");

  require(original.formulas != constructorInput, "Phase 2 constructor array ownership regression");
  expectInvalidIndividual(new SuperFormulaGene[config.formulasPerIndividual - 1], "N - 1");
  expectInvalidIndividual(new SuperFormulaGene[config.formulasPerIndividual + 1], "N + 1");
  expectNullFormulaArray();

  SuperFormulaGene[] withNullGene = new SuperFormulaGene[config.formulasPerIndividual];
  for (int i = 0; i < withNullGene.length; i++) {
    withNullGene[i] = original.getFormula(i).copy(config);
  }
  withNullGene[withNullGene.length - 1] = null;
  expectInvalidIndividual(withNullGene, "null formula entry");

  Individual copied = original.deepCopy();
  require(copied != original, "Phase 2 deepCopy Individual alias");
  require(copied.formulas != original.formulas, "Phase 2 deepCopy array alias");
  for (int i = 0; i < original.getFormulaCount(); i++) {
    require(copied.getFormula(i) != original.getFormula(i), "Phase 2 deepCopy gene alias");
    require(genesHaveSameValues(copied.getFormula(i), original.getFormula(i)),
      "Phase 2 deepCopy changed values");
  }

  IndividualRenderStats renderStats = individualRenderer.render(original);
  require(renderStats.getRenderedLayerCount() == config.formulasPerIndividual,
    "Phase 2 rendered layer count regression");
  println("Phase 1 and Phase 2 regression checks passed");
}

void runPhaseThreeChecks(Population baseline) {
  require(baseline.size() == config.populationSize, "Population size does not match Config");
  require(baseline.getGeneration() == 0, "Generation must start at zero");
  validatePopulationShapeAndOwnership(baseline);
  expectPopulationIndexFailure(baseline, -1);
  expectPopulationIndexFailure(baseline, baseline.size());

  Individual[] initialSnapshot = snapshotPopulation(baseline);
  baseline.reset();
  require(baseline.getGeneration() == 0, "Generation must return to zero after reset");
  require(populationsHaveSameGenomes(initialSnapshot, baseline),
    "Reset with the same seed did not reproduce the initial population");

  Population sameSeedPopulation = new Population(
    new Config(config.populationSize, config.randomSeed, config.formulasPerIndividual)
  );
  require(populationsHaveSameGenomes(initialSnapshot, sameSeedPopulation),
    "Separate population with the same seed was not reproducible");

  Population differentSeedPopulation = new Population(
    new Config(config.populationSize, config.randomSeed + 1, config.formulasPerIndividual)
  );
  require(populationsHaveDifferentGenomes(initialSnapshot, differentSeedPopulation),
    "Different seed did not change any normalized gene");

  Population evenPopulation = new Population(new Config(8, config.randomSeed, config.formulasPerIndividual));
  require(evenPopulation.size() == 8, "Even population size 8 failed");
  validatePopulationShapeAndOwnership(evenPopulation);

  Population singlePopulation = new Population(new Config(1, config.randomSeed, config.formulasPerIndividual));
  require(singlePopulation.size() == 1, "Single-member population failed");
  require(singlePopulation.getIndividual(0).getFormulaCount() == config.formulasPerIndividual,
    "Single-member population has invalid Individual shape");

  expectInvalidPopulationSize(0);
  expectInvalidPopulationSize(-1);
  println("Phase 3 validation passed: size, ownership, reproducibility, reset, and generation=0");
}

void runPhaseFourChecks(Population baseline) {
  Individual[] genomeSnapshot = snapshotPopulation(baseline);
  int[] layoutSizes = new int[] { 1, 5, 8, 9, 10 };
  for (int i = 0; i < layoutSizes.length; i++) {
    validateGridLayout(layoutSizes[i], width, height);
  }

  interactiveUI.recalculateLayout(width, height, baseline.size());
  require(interactiveUI.getSelectedIndex() == -1, "selectedIndex must start at -1");

  GridCell firstCell = interactiveUI.getCell(0);
  GridCell middleCell = interactiveUI.getCell(baseline.size() / 2);
  GridCell lastCell = interactiveUI.getCell(baseline.size() - 1);

  interactiveUI.updateHover(firstCell.centreX(), firstCell.centreY());
  require(interactiveUI.getHoveredIndex() == 0, "First-cell hover mapping failed");
  interactiveUI.updateHover(middleCell.centreX(), middleCell.centreY());
  require(interactiveUI.getHoveredIndex() == middleCell.populationIndex,
    "Middle-cell hover mapping failed");
  interactiveUI.updateHover(lastCell.centreX(), lastCell.centreY());
  require(interactiveUI.getHoveredIndex() == baseline.size() - 1,
    "Last-cell hover mapping failed");
  interactiveUI.updateHover(0, 0);
  require(interactiveUI.getHoveredIndex() == -1, "Status/empty-space hover must be none");

  interactiveUI.selectAt(firstCell.centreX(), firstCell.centreY());
  require(interactiveUI.getSelectedIndex() == 0, "Clicking a valid cell did not set UI focus");
  interactiveUI.updateHover(lastCell.centreX(), lastCell.centreY());
  require(interactiveUI.getHoveredIndex() == baseline.size() - 1,
    "Hover did not update independently of UI focus");
  require(interactiveUI.getSelectedIndex() == 0,
    "Hover incorrectly changed selectedIndex");
  interactiveUI.selectAt(0, 0);
  require(interactiveUI.getSelectedIndex() == -1,
    "Clicking empty space should clear UI focus");

  interactiveUI.recalculateLayout(width, height, baseline.size());
  interactiveUI.clearInteraction();
  int renderedCount = interactiveUI.renderPopulation(baseline, width, height, -1, -1);
  require(renderedCount == baseline.size(), "Grid did not render exactly populationSize Individuals");
  require(populationsHaveSameGenomes(genomeSnapshot, baseline),
    "Grid layout, interaction, or rendering changed a genome");
  require(baseline.getGeneration() == 0, "Phase 4 must not change generation");

  interactiveUI.clearInteraction();
  println("Phase 4 validation passed: layouts, mapping, hover, UI focus, and render count");
}

void runPhaseFiveChecks(Population baseline) {
  require(interactiveFitness.ratedCount(baseline) == 0, "New population must start with no ratings");
  require(interactiveFitness.unratedCount(baseline) == baseline.size(), "New population must start entirely UNRATED");
  require(!interactiveFitness.allRated(baseline), "New population must not report allRated");
  Individual tested = baseline.getIndividual(0);
  Individual genomeBeforeRating = tested.deepCopy();
  require(!interactiveFitness.isRated(tested), "New Individual must be UNRATED");
  expectInvalidRating(tested, 0);
  expectInvalidRating(tested, 11);
  expectInvalidRating(tested, -1);
  interactiveFitness.assignRating(tested, 1);
  require(interactiveFitness.getRating(tested) == 1, "Rating 1 failed");
  interactiveFitness.assignRating(tested, 10);
  require(interactiveFitness.getRating(tested) == 10, "Rating 10 failed");
  interactiveFitness.assignRating(tested, 5);
  require(interactiveFitness.getRating(tested) == 5, "Rating 5 failed");
  interactiveFitness.assignRating(tested, 3);
  interactiveFitness.assignRating(tested, 8);
  require(interactiveFitness.getRating(tested) == 8, "Rating change 3 -> 8 failed");
  interactiveFitness.clearRating(tested);
  require(!interactiveFitness.isRated(tested), "Clearing did not restore UNRATED");
  require(individualsHaveSameGenomes(genomeBeforeRating, tested), "Rating operations altered genotype");
  interactiveFitness.assignRating(tested, 7);
  Individual genomeCopy = tested.deepCopy();
  require(!interactiveFitness.isRated(genomeCopy), "Genome deepCopy must not copy evaluation state");
  require(individualsHaveSameGenomes(tested, genomeCopy), "Genome deepCopy changed values");
  interactiveFitness.clearRating(tested);
  require(ratingForKey('1') == 1 && ratingForKey('9') == 9, "Number-key mapping 1-9 failed");
  require(ratingForKey('0') == 10, "Number-key mapping 0 -> 10 failed");
  require(ratingForKey('x') == -1, "Non-rating key should be ignored");
  interactiveUI.clearInteraction();
  require(!interactiveUI.rateSelected(baseline, 4), "Rating without selection must do nothing");
  interactiveUI.recalculateLayout(width, height, baseline.size());
  GridCell firstCell = interactiveUI.getCell(0);
  GridCell lastCell = interactiveUI.getCell(baseline.size() - 1);
  interactiveUI.selectAt(firstCell.centreX(), firstCell.centreY());
  interactiveUI.updateHover(lastCell.centreX(), lastCell.centreY());
  require(interactiveUI.rateSelected(baseline, 7), "Selected-cell rating failed");
  require(interactiveFitness.getRating(baseline.getIndividual(0)) == 7, "Rating did not apply to selectedIndex");
  require(!interactiveFitness.isRated(baseline.getIndividual(baseline.size() - 1)), "Hover incorrectly received rating");
  for (int i = 0; i < baseline.size() - 1; i++) interactiveFitness.assignRating(baseline.getIndividual(i), (i % 10) + 1);
  require(!interactiveFitness.allRated(baseline), "allRated became true too early");
  require(interactiveFitness.unratedCount(baseline) == 1, "Expected one unrated Individual");
  interactiveFitness.assignRating(baseline.getIndividual(baseline.size() - 1), 10);
  require(interactiveFitness.allRated(baseline), "allRated did not become true");
  require(interactiveFitness.unratedCount(baseline) == 0, "Expected zero unrated Individuals");
  interactiveFitness.clearRating(baseline.getIndividual(0));
  require(!interactiveFitness.allRated(baseline), "Clearing one rating must make allRated false");
  require(interactiveFitness.unratedCount(baseline) == 1, "Clearing one rating must leave one unrated");
  baseline.reset();
  require(interactiveFitness.ratedCount(baseline) == 0, "Reset must make every Individual UNRATED");
  require(baseline.getGeneration() == 0, "Phase 5 must not change generation");
  interactiveUI.clearInteraction();
  println("Phase 5 validation passed: ratings, readiness, reset, and genotype isolation");
}

void expectInvalidRating(Individual individual, int rating) {
  boolean rejected = false;
  try { interactiveFitness.assignRating(individual, rating); }
  catch (IllegalArgumentException expected) { rejected = true; }
  require(rejected, "Interactive rating should reject " + rating);
}

boolean individualsHaveSameGenomes(Individual left, Individual right) {
  if (left.getFormulaCount() != right.getFormulaCount()) return false;
  for (int i = 0; i < left.getFormulaCount(); i++) if (!genesHaveSameValues(left.getFormula(i), right.getFormula(i))) return false;
  return true;
}

void runPhaseSixChecks(Population baseline) {
  long selectionSeed = config.randomSeed + 6000L;
  baseline.reset();
  expectInteractiveSelectionFailure(rouletteSelection, baseline);

  for (int i = 0; i < baseline.size(); i++) {
    interactiveFitness.assignRating(baseline.getIndividual(i), (i % 10) + 1);
  }
  require(interactiveFitness.allRated(baseline), "Phase 6 all-rated setup failed");

  Individual[] genomeSnapshot = snapshotPopulation(baseline);
  int[] ratingSnapshot = snapshotRatings(baseline);
  interactiveUI.recalculateLayout(width, height, baseline.size());
  GridCell selectedCell = interactiveUI.getCell(min(4, baseline.size() - 1));
  GridCell hoveredCell = interactiveUI.getCell(min(2, baseline.size() - 1));
  interactiveUI.selectAt(selectedCell.centreX(), selectedCell.centreY());
  interactiveUI.updateHover(hoveredCell.centreX(), hoveredCell.centreY());
  int selectedBefore = interactiveUI.getSelectedIndex();
  int hoveredBefore = interactiveUI.getHoveredIndex();

  int parentA = rouletteSelection.selectParentIndex(baseline);
  int parentB = rouletteSelection.selectParentIndex(baseline);
  require(isValidPopulationIndex(parentA, baseline), "First roulette parent index was invalid");
  require(isValidPopulationIndex(parentB, baseline), "Second roulette parent index was invalid");
  // Each draw uses the unchanged wheel, so parentA and parentB are allowed to match.
  for (int i = 0; i < 500; i++) {
    require(isValidPopulationIndex(rouletteSelection.selectParentIndex(baseline), baseline),
      "Roulette returned an invalid population index");
  }
  require(populationsHaveSameGenomes(genomeSnapshot, baseline), "Roulette modified genotype");
  require(ratingsMatch(ratingSnapshot, baseline), "Roulette modified ratings");
  require(interactiveUI.getSelectedIndex() == selectedBefore, "Roulette modified UI selection");
  require(interactiveUI.getHoveredIndex() == hoveredBefore, "Roulette modified hover state");
  require(baseline.getGeneration() == 0, "Roulette must not change generation");

  validateTheoreticalRoulette(selectionSeed);
  validateRouletteReproducibility(selectionSeed);
  validateRouletteStatistics(selectionSeed);
  validateZeroTotalFallback(selectionSeed);
  validateEqualWeights(selectionSeed);
  validateSingleMemberSelection(selectionSeed);
  validateInvalidWeights(selectionSeed);

  interactiveFitness.clearRating(baseline.getIndividual(0));
  expectInteractiveSelectionFailure(rouletteSelection, baseline);

  baseline.reset();
  require(populationsHaveSameGenomes(genomeSnapshot, baseline),
    "Selection RNG interfered with deterministic population reset");
  require(interactiveFitness.ratedCount(baseline) == 0, "Reset after roulette must be UNRATED");
  require(baseline.getGeneration() == 0, "Phase 6 generation must remain zero");
  interactiveUI.clearInteraction();
  println("Phase 6 validation passed: roulette proportionality, edge cases, and state isolation");
}

void validateTheoreticalRoulette(long seed) {
  RouletteWheelSelection selector = new RouletteWheelSelection(interactiveFitness, seed);
  double[] weights = new double[] { 10.0, 5.0, 1.0 };
  double total = selector.totalWeight(weights);
  require(abs((float) total - 16.0) < 0.00001, "[10,5,1] total weight must equal 16");
  require(abs((float) (weights[0] / total) - 10.0 / 16.0) < 0.00001, "10/16 probability mismatch");
  require(abs((float) (weights[1] / total) - 5.0 / 16.0) < 0.00001, "5/16 probability mismatch");
  require(abs((float) (weights[2] / total) - 1.0 / 16.0) < 0.00001, "1/16 probability mismatch");
}

void validateRouletteReproducibility(long seed) {
  double[] weights = new double[] { 10.0, 5.0, 1.0 };
  RouletteWheelSelection first = new RouletteWheelSelection(interactiveFitness, seed);
  RouletteWheelSelection second = new RouletteWheelSelection(interactiveFitness, seed);
  RouletteWheelSelection different = new RouletteWheelSelection(interactiveFitness, seed + 1L);
  boolean differentSequenceFound = false;
  for (int i = 0; i < 100; i++) {
    int expected = first.selectIndex(weights);
    require(expected == second.selectIndex(weights), "Same selection seed did not reproduce sequence");
    if (expected != different.selectIndex(weights)) differentSequenceFound = true;
  }
  require(differentSequenceFound, "Different selection seed did not change the sampled sequence");
}

void validateRouletteStatistics(long seed) {
  RouletteWheelSelection selector = new RouletteWheelSelection(interactiveFitness, seed);
  double[] weights = new double[] { 10.0, 5.0, 1.0 };
  int[] counts = sampleCounts(selector, weights, 20000);
  require(counts[0] > counts[1] && counts[1] > counts[2],
    "[10,5,1] statistical ordering was not preserved");
  require(abs(counts[0] / 20000.0 - 10.0 / 16.0) < 0.03, "Weight 10 frequency outside tolerance");
  require(abs(counts[1] / 20000.0 - 5.0 / 16.0) < 0.03, "Weight 5 frequency outside tolerance");
  require(abs(counts[2] / 20000.0 - 1.0 / 16.0) < 0.03, "Weight 1 frequency outside tolerance");
  println("Phase 6 [10,5,1] counts: " + counts[0] + ", " + counts[1] + ", " + counts[2]);
}

void validateZeroTotalFallback(long seed) {
  RouletteWheelSelection selector = new RouletteWheelSelection(interactiveFitness, seed);
  int[] counts = sampleCounts(selector, new double[] { 0.0, 0.0, 0.0 }, 3000);
  for (int i = 0; i < counts.length; i++) require(counts[i] > 0, "Zero-total fallback did not reach every index");
}

void validateEqualWeights(long seed) {
  validateApproximatelyUniform(new double[] { 1.0, 1.0, 1.0 }, seed);
  validateApproximatelyUniform(new double[] { 10.0, 10.0, 10.0 }, seed + 1L);
}

void validateApproximatelyUniform(double[] weights, long seed) {
  int draws = 12000;
  int[] counts = sampleCounts(new RouletteWheelSelection(interactiveFitness, seed), weights, draws);
  double expected = draws / (double) weights.length;
  for (int i = 0; i < counts.length; i++) {
    require(abs((float) (counts[i] - expected)) / expected < 0.10,
      "Equal roulette weights were not approximately uniform");
  }
}

void validateSingleMemberSelection(long seed) {
  RouletteWheelSelection positive = new RouletteWheelSelection(interactiveFitness, seed);
  RouletteWheelSelection zero = new RouletteWheelSelection(interactiveFitness, seed);
  for (int i = 0; i < 100; i++) {
    require(positive.selectIndex(new double[] { 10.0 }) == 0, "Single positive weight must select index 0");
    require(zero.selectIndex(new double[] { 0.0 }) == 0, "Single zero weight must select index 0");
  }
}

void validateInvalidWeights(long seed) {
  expectInvalidWeights(null, seed, "null");
  expectInvalidWeights(new double[0], seed, "empty");
  expectInvalidWeights(new double[] { 1.0, -1.0 }, seed, "negative");
  expectInvalidWeights(new double[] { 1.0, Double.NaN }, seed, "NaN");
  expectInvalidWeights(new double[] { 1.0, Double.POSITIVE_INFINITY }, seed, "Infinity");
  expectInvalidWeights(new double[] { Double.MAX_VALUE, Double.MAX_VALUE }, seed, "overflowing total");
}

void expectInvalidWeights(double[] weights, long seed, String caseName) {
  boolean rejected = false;
  try {
    new RouletteWheelSelection(interactiveFitness, seed).selectIndex(weights);
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Roulette should reject " + caseName + " weights");
}

void expectInteractiveSelectionFailure(RouletteWheelSelection selector, Population candidate) {
  boolean rejected = false;
  try {
    selector.selectParentIndex(candidate);
  }
  catch (IllegalStateException expected) {
    rejected = true;
  }
  require(rejected, "Interactive roulette must reject an UNRATED population");
}

int[] sampleCounts(RouletteWheelSelection selector, double[] weights, int draws) {
  int[] counts = new int[weights.length];
  for (int i = 0; i < draws; i++) {
    int selected = selector.selectIndex(weights);
    require(selected >= 0 && selected < weights.length, "Generic roulette returned invalid index");
    counts[selected]++;
  }
  return counts;
}

int[] snapshotRatings(Population source) {
  int[] ratings = new int[source.size()];
  for (int i = 0; i < source.size(); i++) ratings[i] = interactiveFitness.getRating(source.getIndividual(i));
  return ratings;
}

boolean ratingsMatch(int[] expected, Population actual) {
  if (expected.length != actual.size()) return false;
  for (int i = 0; i < expected.length; i++) {
    if (!interactiveFitness.isRated(actual.getIndividual(i))) return false;
    if (interactiveFitness.getRating(actual.getIndividual(i)) != expected[i]) return false;
  }
  return true;
}

boolean isValidPopulationIndex(int index, Population source) {
  return index >= 0 && index < source.size();
}

void runPhaseSevenChecks(Population baseline) {
  Individual[] populationSnapshot = snapshotPopulation(baseline);
  int generationBefore = baseline.getGeneration();
  validateCrossoverForFormulaCount(1);
  validateCrossoverForFormulaCount(2);
  validateCrossoverForFormulaCount(3);
  validateCrossoverCompatibilityFailures();
  validateOperatorDifference();
  require(populationsHaveSameGenomes(populationSnapshot, baseline),
    "Crossover validation modified the Population");
  require(baseline.getGeneration() == generationBefore && generationBefore == 0,
    "Phase 7 must not change generation");
  println("Phase 7 validation passed: both crossover operators, ownership, and fixed N");
}

void validateCrossoverForFormulaCount(int formulaCount) {
  Config testConfig = new Config(2, config.randomSeed, formulaCount);
  testConfig.validate();
  Individual parentA = createDistinctCrossoverParent(testConfig, true);
  Individual parentB = createDistinctCrossoverParent(testConfig, false);
  interactiveFitness.assignRating(parentA, 10);
  interactiveFitness.assignRating(parentB, 3);
  Individual parentABefore = parentA.deepCopy();
  Individual parentBBefore = parentB.deepCopy();
  long seed = config.randomSeed + 7000L + formulaCount;

  Individual parameterChild = crossover.parameterWiseUniform(
    parentA, parentB, new java.util.Random(seed)
  );
  Individual parameterRepeat = crossover.parameterWiseUniform(
    parentA, parentB, new java.util.Random(seed)
  );
  validateParameterChild(parameterChild, parentA, parentB);
  require(individualsHaveSameGenomes(parameterChild, parameterRepeat),
    "Same seed did not reproduce parameter-wise crossover");

  Individual formulaChild = crossover.wholeFormulaUniform(
    parentA, parentB, new java.util.Random(seed)
  );
  Individual formulaRepeat = crossover.wholeFormulaUniform(
    parentA, parentB, new java.util.Random(seed)
  );
  validateWholeFormulaChild(formulaChild, parentA, parentB);
  require(individualsHaveSameGenomes(formulaChild, formulaRepeat),
    "Same seed did not reproduce whole-formula crossover");

  validateChildOwnership(parameterChild, parentA, parentB);
  validateChildOwnership(formulaChild, parentA, parentB);
  require(!interactiveFitness.isRated(parameterChild), "Parameter-wise child must start UNRATED");
  require(!interactiveFitness.isRated(formulaChild), "Whole-formula child must start UNRATED");
  require(individualsHaveSameGenomes(parentABefore, parentA), "Parameter crossover modified Parent A");
  require(individualsHaveSameGenomes(parentBBefore, parentB), "Parameter crossover modified Parent B");
  require(interactiveFitness.getRating(parentA) == 10, "Crossover modified Parent A rating");
  require(interactiveFitness.getRating(parentB) == 3, "Crossover modified Parent B rating");
  require(parameterChild.getFormulaCount() == formulaCount, "Parameter child did not preserve fixed N");
  require(formulaChild.getFormulaCount() == formulaCount, "Formula child did not preserve fixed N");

  boolean differentParameterChildFound = false;
  boolean differentFormulaChildFound = false;
  for (long offset = 1; offset <= 64; offset++) {
    long differentSeed = seed + offset * 104729L;
    Individual differentParameter = crossover.parameterWiseUniform(
      parentA, parentB, new java.util.Random(differentSeed)
    );
    Individual differentFormula = crossover.wholeFormulaUniform(
      parentA, parentB, new java.util.Random(differentSeed)
    );
    if (!individualsHaveSameGenomes(parameterChild, differentParameter)) {
      differentParameterChildFound = true;
    }
    if (!individualsHaveSameGenomes(formulaChild, differentFormula)) {
      differentFormulaChildFound = true;
    }
  }
  require(differentParameterChildFound, "Different seed never changed parameter-wise child");
  require(differentFormulaChildFound, "Different seed never changed whole-formula child");
}

Individual createDistinctCrossoverParent(Config testConfig, boolean firstParent) {
  SuperFormulaGene[] formulas = new SuperFormulaGene[testConfig.formulasPerIndividual];
  for (int i = 0; i < formulas.length; i++) {
    float base = firstParent ? 0.05 + i * 0.08 : 0.95 - i * 0.08;
    formulas[i] = new SuperFormulaGene(
      testConfig,
      base,
      firstParent ? base + 0.01 : base - 0.01,
      firstParent ? base + 0.02 : base - 0.02,
      firstParent ? base + 0.03 : base - 0.03,
      firstParent ? base + 0.04 : base - 0.04,
      firstParent ? base + 0.05 : base - 0.05
    );
  }
  return new Individual(testConfig, formulas);
}

void validateParameterChild(Individual child, Individual parentA, Individual parentB) {
  require(child.getFormulaCount() == parentA.getFormulaCount(), "Parameter child formula count mismatch");
  for (int i = 0; i < child.getFormulaCount(); i++) {
    SuperFormulaGene result = child.getFormula(i);
    SuperFormulaGene sourceA = parentA.getFormula(i);
    SuperFormulaGene sourceB = parentB.getFormula(i);
    require(inherits(result.aGene, sourceA.aGene, sourceB.aGene), "Invalid inherited aGene");
    require(inherits(result.bGene, sourceA.bGene, sourceB.bGene), "Invalid inherited bGene");
    require(inherits(result.mGene, sourceA.mGene, sourceB.mGene), "Invalid inherited mGene");
    require(inherits(result.n1Gene, sourceA.n1Gene, sourceB.n1Gene), "Invalid inherited n1Gene");
    require(inherits(result.n2Gene, sourceA.n2Gene, sourceB.n2Gene), "Invalid inherited n2Gene");
    require(inherits(result.n3Gene, sourceA.n3Gene, sourceB.n3Gene), "Invalid inherited n3Gene");
    requireGeneIsNormalized(result);
  }
}

void validateWholeFormulaChild(Individual child, Individual parentA, Individual parentB) {
  require(child.getFormulaCount() == parentA.getFormulaCount(), "Formula child count mismatch");
  for (int i = 0; i < child.getFormulaCount(); i++) {
    SuperFormulaGene result = child.getFormula(i);
    boolean matchesA = genesHaveSameValues(result, parentA.getFormula(i));
    boolean matchesB = genesHaveSameValues(result, parentB.getFormula(i));
    require(matchesA || matchesB, "Whole-formula crossover mixed fields inside a formula");
    requireGeneIsNormalized(result);
  }
}

void validateChildOwnership(Individual child, Individual parentA, Individual parentB) {
  require(child != parentA && child != parentB, "Crossover returned a parent object");
  require(child.formulas != parentA.formulas && child.formulas != parentB.formulas,
    "Child formula array aliases a parent array");
  for (int i = 0; i < child.getFormulaCount(); i++) {
    require(child.getFormula(i) != parentA.getFormula(i), "Child gene aliases Parent A");
    require(child.getFormula(i) != parentB.getFormula(i), "Child gene aliases Parent B");
  }
}

void validateCrossoverCompatibilityFailures() {
  Config oneFormula = new Config(2, config.randomSeed, 1);
  Config twoFormulas = new Config(2, config.randomSeed, 2);
  Individual parentOne = createDistinctCrossoverParent(oneFormula, true);
  Individual parentTwo = createDistinctCrossoverParent(twoFormulas, false);
  expectInvalidCrossover(null, parentOne, new java.util.Random(1), "null Parent A");
  expectInvalidCrossover(parentOne, null, new java.util.Random(1), "null Parent B");
  expectInvalidCrossover(parentOne, parentTwo, new java.util.Random(1), "incompatible N");
  expectInvalidCrossover(parentOne, parentOne, null, "null RNG");
}

void expectInvalidCrossover(
    Individual parentA,
    Individual parentB,
    java.util.Random randomSource,
    String caseName) {
  boolean rejected = false;
  try {
    crossover.parameterWiseUniform(parentA, parentB, randomSource);
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Crossover should reject " + caseName);
}

void validateOperatorDifference() {
  Config testConfig = new Config(2, config.randomSeed, 2);
  Individual parentA = createDistinctCrossoverParent(testConfig, true);
  Individual parentB = createDistinctCrossoverParent(testConfig, false);
  boolean mixedFormulaFound = false;
  for (long seed = 1; seed <= 100 && !mixedFormulaFound; seed++) {
    Individual child = crossover.parameterWiseUniform(parentA, parentB, new java.util.Random(seed));
    for (int i = 0; i < child.getFormulaCount(); i++) {
      boolean completeA = genesHaveSameValues(child.getFormula(i), parentA.getFormula(i));
      boolean completeB = genesHaveSameValues(child.getFormula(i), parentB.getFormula(i));
      if (!completeA && !completeB) mixedFormulaFound = true;
    }
  }
  require(mixedFormulaFound, "Parameter-wise operator never mixed fields within a formula");
  Individual wholeChild = crossover.wholeFormulaUniform(parentA, parentB, new java.util.Random(1));
  validateWholeFormulaChild(wholeChild, parentA, parentB);
}

boolean inherits(float childValue, float valueA, float valueB) {
  return childValue == valueA || childValue == valueB;
}

void runPhaseEightChecks(Population baseline) {
  Individual[] populationSnapshot = snapshotPopulation(baseline);
  int generationBefore = baseline.getGeneration();
  validateMutationConfig();
  validateMutationForFormulaCount(1);
  validateMutationForFormulaCount(2);
  validateMutationForFormulaCount(3);
  validateMutationBoundaries();
  validateMutationInputFailures();
  validateMutationOperatorDifference();
  require(populationsHaveSameGenomes(populationSnapshot, baseline),
    "Mutation validation modified the Population");
  require(baseline.getGeneration() == generationBefore && generationBefore == 0,
    "Phase 8 must not change generation");
  println("Phase 8 validation passed: both mutation operators, discrete m, ownership, and fixed N");
}

void validateMutationConfig() {
  require(nearlyEqual(config.mutationRate, 0.20), "Default mutationRate must be 0.20");
  require(nearlyEqual(config.uniformMutationDelta, 0.10), "Default uniform delta must be 0.10");
  require(nearlyEqual(config.gaussianMutationSigma, 0.10), "Default Gaussian sigma must be 0.10");
  expectInvalidMutationConfig(-0.01, 0.10, 0.10, "negative mutationRate");
  expectInvalidMutationConfig(1.01, 0.10, 0.10, "mutationRate above one");
  expectInvalidMutationConfig(0.20, -0.01, 0.10, "negative uniform delta");
  expectInvalidMutationConfig(0.20, 1.01, 0.10, "uniform delta above one");
  expectInvalidMutationConfig(0.20, 0.10, -0.01, "negative Gaussian sigma");
  expectInvalidMutationConfig(0.20, 0.10, 1.01, "Gaussian sigma above one");
  expectInvalidMutationConfig(Float.NaN, 0.10, 0.10, "non-finite mutationRate");
}

void expectInvalidMutationConfig(float rate, float delta, float sigma, String caseName) {
  boolean rejected = false;
  try {
    new Config(2, config.randomSeed, 2, rate, delta, sigma).validate();
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Config should reject " + caseName);
}

void validateMutationForFormulaCount(int formulaCount) {
  long seed = config.randomSeed + 8000L + formulaCount;
  Config fullConfig = new Config(2, config.randomSeed, formulaCount, 1.0, 0.10, 0.10);
  Individual source = createDistinctCrossoverParent(fullConfig, true);
  interactiveFitness.assignRating(source, 9);
  Individual sourceBefore = source.deepCopy();

  MutationStats uniformStats = new MutationStats();
  Individual uniformResult = mutation.boundedUniform(source, new java.util.Random(seed), uniformStats);
  MutationStats gaussianStats = new MutationStats();
  Individual gaussianResult = mutation.gaussianParameters(source, new java.util.Random(seed), gaussianStats);
  int expectedOpportunities = formulaCount * 6;
  require(uniformStats.opportunities == expectedOpportunities
      && uniformStats.executedBranches == expectedOpportunities,
    "Full-rate uniform mutation did not execute all six branches per formula");
  require(gaussianStats.opportunities == expectedOpportunities
      && gaussianStats.executedBranches == expectedOpportunities,
    "Full-rate Gaussian mutation did not execute all six branches per formula");

  validateMutatedIndividual(uniformResult, source, formulaCount);
  validateMutatedIndividual(gaussianResult, source, formulaCount);
  validateUniformDeltas(source, uniformResult, fullConfig.uniformMutationDelta);
  validateDiscreteM(uniformResult, fullConfig);
  validateDiscreteM(gaussianResult, fullConfig);
  require(individualsHaveSameGenomes(sourceBefore, source), "Mutation changed source genotype");
  require(interactiveFitness.getRating(source) == 9, "Mutation changed source rating");

  Individual uniformRepeat = mutation.boundedUniform(source, new java.util.Random(seed));
  Individual gaussianRepeat = mutation.gaussianParameters(source, new java.util.Random(seed));
  require(individualsHaveSameGenomes(uniformResult, uniformRepeat),
    "Same seed did not reproduce bounded uniform mutation");
  require(individualsHaveSameGenomes(gaussianResult, gaussianRepeat),
    "Same seed did not reproduce Gaussian mutation");

  Config zeroConfig = new Config(2, config.randomSeed, formulaCount, 0.0, 0.10, 0.10);
  Individual zeroSource = createDistinctCrossoverParent(zeroConfig, true);
  MutationStats zeroUniformStats = new MutationStats();
  MutationStats zeroGaussianStats = new MutationStats();
  Individual zeroUniform = mutation.boundedUniform(zeroSource, new java.util.Random(seed), zeroUniformStats);
  Individual zeroGaussian = mutation.gaussianParameters(zeroSource, new java.util.Random(seed), zeroGaussianStats);
  require(individualsHaveSameGenomes(zeroSource, zeroUniform), "Zero-rate uniform mutation changed values");
  require(individualsHaveSameGenomes(zeroSource, zeroGaussian), "Zero-rate Gaussian mutation changed values");
  require(zeroUniformStats.executedBranches == 0 && zeroGaussianStats.executedBranches == 0,
    "Zero mutation rate executed a mutation branch");
  validateMutatedIndividual(zeroUniform, zeroSource, formulaCount);
  validateMutatedIndividual(zeroGaussian, zeroSource, formulaCount);

  boolean differentUniformFound = false;
  boolean differentGaussianFound = false;
  for (long offset = 1; offset <= 32; offset++) {
    long differentSeed = seed + offset * 104729L;
    if (!individualsHaveSameGenomes(
        uniformResult,
        mutation.boundedUniform(source, new java.util.Random(differentSeed)))) {
      differentUniformFound = true;
    }
    if (!individualsHaveSameGenomes(
        gaussianResult,
        mutation.gaussianParameters(source, new java.util.Random(differentSeed)))) {
      differentGaussianFound = true;
    }
  }
  require(differentUniformFound, "Different seeds never changed uniform mutation result");
  require(differentGaussianFound, "Different seeds never changed Gaussian mutation result");
}

void validateMutatedIndividual(Individual result, Individual source, int expectedFormulaCount) {
  require(result != source, "Mutation returned the source Individual");
  require(result.formulas != source.formulas, "Mutation result shares source formula array");
  require(result.getFormulaCount() == expectedFormulaCount, "Mutation changed fixed N");
  require(!interactiveFitness.isRated(result), "Mutation result must start UNRATED");
  for (int i = 0; i < result.getFormulaCount(); i++) {
    require(result.getFormula(i) != source.getFormula(i), "Mutation result shares a source gene");
    requireGeneIsNormalized(result.getFormula(i));
  }
}

void validateUniformDeltas(Individual source, Individual result, float maximumDelta) {
  for (int i = 0; i < source.getFormulaCount(); i++) {
    SuperFormulaGene before = source.getFormula(i);
    SuperFormulaGene after = result.getFormula(i);
    require(abs(after.aGene - before.aGene) <= maximumDelta + 0.00001, "Uniform a delta exceeded bound");
    require(abs(after.bGene - before.bGene) <= maximumDelta + 0.00001, "Uniform b delta exceeded bound");
    require(abs(after.n1Gene - before.n1Gene) <= maximumDelta + 0.00001, "Uniform n1 delta exceeded bound");
    require(abs(after.n2Gene - before.n2Gene) <= maximumDelta + 0.00001, "Uniform n2 delta exceeded bound");
    require(abs(after.n3Gene - before.n3Gene) <= maximumDelta + 0.00001, "Uniform n3 delta exceeded bound");
  }
}

void validateDiscreteM(Individual candidate, Config candidateConfig) {
  for (int i = 0; i < candidate.getFormulaCount(); i++) {
    int decodedM = candidateConfig.decodeM(candidate.getFormula(i).mGene);
    require(decodedM >= candidateConfig.mMin && decodedM <= candidateConfig.mMax,
      "Mutated m left configured integer range");
    float encodedM = candidateConfig.encodeM(decodedM);
    require(candidateConfig.decodeM(encodedM) == decodedM, "Mutated m failed encode/decode round trip");
  }
}

void validateMutationBoundaries() {
  Config boundaryConfig = new Config(2, config.randomSeed, 1, 1.0, 0.10, 0.10);
  Individual minimumM = createMutationBoundaryIndividual(boundaryConfig, boundaryConfig.mMin, 0.0);
  Individual maximumM = createMutationBoundaryIndividual(boundaryConfig, boundaryConfig.mMax, 1.0);
  Individual uniformMinimum = mutation.boundedUniform(
    minimumM, new FixedMutationRandom(false, -1.0, 0.0)
  );
  Individual uniformMaximum = mutation.boundedUniform(
    maximumM, new FixedMutationRandom(true, 1.0, 0.999999)
  );
  Individual gaussianMinimum = mutation.gaussianParameters(
    minimumM, new FixedMutationRandom(false, -1.0, 0.0)
  );
  Individual gaussianMaximum = mutation.gaussianParameters(
    maximumM, new FixedMutationRandom(true, 1.0, 0.0)
  );
  require(boundaryConfig.decodeM(uniformMinimum.getFormula(0).mGene) == boundaryConfig.mMin,
    "Uniform m crossed minimum boundary");
  require(boundaryConfig.decodeM(uniformMaximum.getFormula(0).mGene) == boundaryConfig.mMax,
    "Uniform m crossed maximum boundary");
  require(boundaryConfig.decodeM(gaussianMinimum.getFormula(0).mGene) == boundaryConfig.mMin,
    "Gaussian m crossed minimum boundary");
  require(boundaryConfig.decodeM(gaussianMaximum.getFormula(0).mGene) == boundaryConfig.mMax,
    "Gaussian m crossed maximum boundary");
  requireContinuousGenesEqual(uniformMinimum.getFormula(0), 0.0, "Uniform lower clamp");
  requireContinuousGenesEqual(uniformMaximum.getFormula(0), 1.0, "Uniform upper clamp");
  requireContinuousGenesEqual(gaussianMinimum.getFormula(0), 0.0, "Gaussian lower clamp");
  requireContinuousGenesEqual(gaussianMaximum.getFormula(0), 1.0, "Gaussian upper clamp");
}

Individual createMutationBoundaryIndividual(
    Config testConfig,
    int decodedM,
    float continuousValue) {
  SuperFormulaGene gene = new SuperFormulaGene(
    testConfig,
    continuousValue,
    continuousValue,
    testConfig.encodeM(decodedM),
    continuousValue,
    continuousValue,
    continuousValue
  );
  return new Individual(testConfig, new SuperFormulaGene[] { gene });
}

void requireContinuousGenesEqual(SuperFormulaGene gene, float expected, String caseName) {
  require(gene.aGene == expected, caseName + " failed for aGene");
  require(gene.bGene == expected, caseName + " failed for bGene");
  require(gene.n1Gene == expected, caseName + " failed for n1Gene");
  require(gene.n2Gene == expected, caseName + " failed for n2Gene");
  require(gene.n3Gene == expected, caseName + " failed for n3Gene");
}

void validateMutationInputFailures() {
  boolean nullSourceRejected = false;
  boolean nullRandomRejected = false;
  try { mutation.boundedUniform(null, new java.util.Random(1)); }
  catch (IllegalArgumentException expected) { nullSourceRejected = true; }
  try {
    Config testConfig = new Config(2, config.randomSeed, 1);
    mutation.gaussianParameters(createDistinctCrossoverParent(testConfig, true), null);
  }
  catch (IllegalArgumentException expected) { nullRandomRejected = true; }
  require(nullSourceRejected, "Mutation should reject null source");
  require(nullRandomRejected, "Mutation should reject null RNG");
}

void validateMutationOperatorDifference() {
  Config testConfig = new Config(2, config.randomSeed, 3, 1.0, 0.10, 0.10);
  Individual source = createDistinctCrossoverParent(testConfig, true);
  boolean differenceFound = false;
  for (long seed = 1; seed <= 32; seed++) {
    Individual uniformResult = mutation.boundedUniform(source, new java.util.Random(seed));
    Individual gaussianResult = mutation.gaussianParameters(source, new java.util.Random(seed));
    if (!individualsHaveSameGenomes(uniformResult, gaussianResult)) differenceFound = true;
  }
  require(differenceFound, "Uniform and Gaussian mutation behaved identically");
}

class FixedMutationRandom extends java.util.Random {
  final boolean fixedBoolean;
  final double fixedGaussian;
  final double fixedDouble;

  FixedMutationRandom(boolean fixedBoolean, double fixedGaussian, double fixedDouble) {
    this.fixedBoolean = fixedBoolean;
    this.fixedGaussian = fixedGaussian;
    this.fixedDouble = fixedDouble;
  }

  public double nextDouble() { return fixedDouble; }
  public boolean nextBoolean() { return fixedBoolean; }
  public double nextGaussian() { return fixedGaussian; }
}

void runPhaseNineChecks(Population baseline) {
  resetInteractiveRun();
  validateBlockedEvolution(baseline);

  rateAllPopulation(baseline);
  Individual[] generationZeroReferences = activePopulationReferences(baseline);
  Individual[] generationZeroGenomes = snapshotPopulation(baseline);
  int[] generationZeroRatings = snapshotRatings(baseline);
  interactiveUI.recalculateLayout(width, height, baseline.size());
  GridCell selectedCell = interactiveUI.getCell(min(4, baseline.size() - 1));
  interactiveUI.selectAt(selectedCell.centreX(), selectedCell.centreY());
  require(evolveCurrentPopulation(), "Fully rated generation should evolve");
  require(baseline.getGeneration() == 1, "First successful evolution must create generation 1");
  require(baseline.size() == config.populationSize, "Generation 1 changed population size");
  require(interactiveFitness.ratedCount(baseline) == 0, "Generation 1 children must be UNRATED");
  require(!interactiveFitness.allRated(baseline), "Generation 1 must require new ratings");
  require(interactiveUI.getSelectedIndex() == -1, "Successful evolution must clear selectedIndex");
  require(interactiveUI.getHoveredIndex() == -1, "Successful evolution must clear hoveredIndex");
  validatePopulationShapeAndOwnership(baseline);
  validatePopulationSemanticM(baseline);
  validateOldGenerationUnchanged(
    generationZeroReferences, generationZeroGenomes, generationZeroRatings
  );
  validateOldGenerationIsNoLongerActive(generationZeroReferences, baseline);
  int renderedAfterEvolution = interactiveUI.renderPopulation(baseline, width, height, -1, -1);
  require(renderedAfterEvolution == baseline.size(), "Grid did not render complete new generation");

  Individual[] expectedGenerationOne = snapshotPopulation(baseline);
  rateAllPopulation(baseline);
  require(evolveCurrentPopulation(), "Second fully rated generation should evolve");
  require(baseline.getGeneration() == 2, "Two successful evolutions must create generation 2");
  require(baseline.size() == config.populationSize, "Generation 2 changed population size");
  require(interactiveFitness.ratedCount(baseline) == 0, "Generation 2 children must be UNRATED");

  resetInteractiveRun();
  require(baseline.getGeneration() == 0, "Reset must restore generation 0");
  require(interactiveFitness.ratedCount(baseline) == 0, "Reset population must be UNRATED");
  rateAllPopulation(baseline);
  require(evolveCurrentPopulation(), "Reproducibility evolution failed");
  require(populationsHaveSameGenomes(expectedGenerationOne, baseline),
    "Reset plus identical ratings did not reproduce generation 1");

  validateAllOperatorCombinations();
  validateLifecyclePopulationSize(1);
  validateLifecyclePopulationSize(5);
  validateLifecyclePopulationSize(9);
  validateOperatorConfigFailures();

  resetInteractiveRun();
  require(baseline.getGeneration() == 0, "Final Phase 9 reset must restore generation 0");
  println("Phase 9 validation passed: atomic interactive lifecycle through generation 2");
}

void validateBlockedEvolution(Population candidate) {
  for (int i = 0; i < candidate.size() - 1; i++) {
    interactiveFitness.assignRating(candidate.getIndividual(i), (i % 10) + 1);
  }
  Individual[] genomeSnapshot = snapshotPopulation(candidate);
  int generationBefore = candidate.getGeneration();
  int ratedBefore = interactiveFitness.ratedCount(candidate);
  interactiveUI.recalculateLayout(width, height, candidate.size());
  GridCell firstCell = interactiveUI.getCell(0);
  interactiveUI.selectAt(firstCell.centreX(), firstCell.centreY());
  int selectedBefore = interactiveUI.getSelectedIndex();
  require(!evolveCurrentPopulation(), "Evolution must be blocked while one Individual is UNRATED");
  require(candidate.getGeneration() == generationBefore, "Blocked evolution changed generation");
  require(populationsHaveSameGenomes(genomeSnapshot, candidate), "Blocked evolution changed genomes");
  require(interactiveFitness.ratedCount(candidate) == ratedBefore, "Blocked evolution changed ratings");
  require(!interactiveFitness.isRated(candidate.getIndividual(candidate.size() - 1)),
    "Blocked evolution changed UNRATED state");
  require(interactiveUI.getSelectedIndex() == selectedBefore,
    "Blocked evolution changed UI selection");
  resetInteractiveRun();
}

void validateAllOperatorCombinations() {
  String[] crossoverOperators = new String[] {
    "PARAMETER_UNIFORM", "WHOLE_FORMULA_UNIFORM"
  };
  String[] mutationOperators = new String[] {
    "BOUNDED_UNIFORM_MUTATION", "GAUSSIAN_PARAMETER_MUTATION"
  };
  for (int crossoverIndex = 0; crossoverIndex < crossoverOperators.length; crossoverIndex++) {
    for (int mutationIndex = 0; mutationIndex < mutationOperators.length; mutationIndex++) {
      Config testConfig = new Config(
        5,
        config.randomSeed,
        2,
        config.mutationRate,
        config.uniformMutationDelta,
        config.gaussianMutationSigma,
        crossoverOperators[crossoverIndex],
        mutationOperators[mutationIndex]
      );
      Population testPopulation = new Population(testConfig);
      rateAllPopulation(testPopulation);
      boolean evolved = evolveTestPopulation(testPopulation, testConfig);
      require(evolved, "Operator combination failed to evolve");
      require(testPopulation.size() == 5 && testPopulation.getGeneration() == 1,
        "Operator combination did not preserve odd population size");
      require(interactiveFitness.ratedCount(testPopulation) == 0,
        "Operator combination produced rated children");
      validatePopulationShapeAndOwnership(testPopulation);
      validatePopulationSemanticM(testPopulation);
    }
  }
}

void validateLifecyclePopulationSize(int populationSize) {
  Config testConfig = new Config(
    populationSize,
    config.randomSeed,
    config.formulasPerIndividual,
    config.mutationRate,
    config.uniformMutationDelta,
    config.gaussianMutationSigma,
    config.crossoverOperator,
    config.mutationOperator
  );
  Population testPopulation = new Population(testConfig);
  rateAllPopulation(testPopulation);
  require(evolveTestPopulation(testPopulation, testConfig),
    "Lifecycle failed for populationSize=" + populationSize);
  require(testPopulation.size() == populationSize, "Lifecycle changed configured population size");
  require(testPopulation.getGeneration() == 1, "Lifecycle generation increment failed");
  require(interactiveFitness.ratedCount(testPopulation) == 0, "Lifecycle children must be UNRATED");
  validatePopulationShapeAndOwnership(testPopulation);
}

boolean evolveTestPopulation(Population candidate, Config candidateConfig) {
  return candidate.nextGeneration(
    interactiveFitness,
    new RouletteWheelSelection(interactiveFitness, candidateConfig.selectionSeed),
    crossover,
    mutation,
    new java.util.Random(candidateConfig.crossoverSeed),
    new java.util.Random(candidateConfig.mutationSeed)
  );
}

void rateAllPopulation(Population candidate) {
  for (int i = 0; i < candidate.size(); i++) {
    interactiveFitness.assignRating(candidate.getIndividual(i), (i % 10) + 1);
  }
}

Individual[] activePopulationReferences(Population source) {
  Individual[] references = new Individual[source.size()];
  for (int i = 0; i < source.size(); i++) references[i] = source.getIndividual(i);
  return references;
}

void validateOldGenerationUnchanged(
    Individual[] oldReferences,
    Individual[] oldGenomes,
    int[] oldRatings) {
  for (int i = 0; i < oldReferences.length; i++) {
    require(individualsHaveSameGenomes(oldReferences[i], oldGenomes[i]),
      "Reproduction modified an old-generation parent");
    require(interactiveFitness.isRated(oldReferences[i]),
      "Reproduction cleared an old-generation parent rating");
    require(interactiveFitness.getRating(oldReferences[i]) == oldRatings[i],
      "Reproduction changed an old-generation parent rating");
  }
}

void validateOldGenerationIsNoLongerActive(
    Individual[] oldReferences,
    Population activePopulation) {
  for (int activeIndex = 0; activeIndex < activePopulation.size(); activeIndex++) {
    for (int oldIndex = 0; oldIndex < oldReferences.length; oldIndex++) {
      require(activePopulation.getIndividual(activeIndex) != oldReferences[oldIndex],
        "Old-generation Individual remained in the active population");
    }
  }
}

void validatePopulationSemanticM(Population candidate) {
  for (int i = 0; i < candidate.size(); i++) {
    for (int formulaIndex = 0;
        formulaIndex < candidate.getIndividual(i).getFormulaCount();
        formulaIndex++) {
      int decodedM = candidate.config.decodeM(
        candidate.getIndividual(i).getFormula(formulaIndex).mGene
      );
      require(decodedM >= candidate.config.mMin && decodedM <= candidate.config.mMax,
        "Evolution child has invalid semantic m");
      require(candidate.config.decodeM(candidate.config.encodeM(decodedM)) == decodedM,
        "Evolution child m failed encode/decode round trip");
    }
  }
}

void validateOperatorConfigFailures() {
  expectInvalidOperatorConfig("UNKNOWN_CROSSOVER", "BOUNDED_UNIFORM_MUTATION");
  expectInvalidOperatorConfig("PARAMETER_UNIFORM", "UNKNOWN_MUTATION");
}

void expectInvalidOperatorConfig(String crossoverName, String mutationName) {
  boolean rejected = false;
  try {
    new Config(
      2, config.randomSeed, 2, 0.20, 0.10, 0.10, crossoverName, mutationName
    ).validate();
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Config should reject unsupported operator names");
}

void runPhaseTenChecks(Population baseline) {
  require(config.evaluationWidth == 256 && config.evaluationHeight == 256,
    "Phase 10 baseline evaluation resolution must be 256x256");
  int generationBefore = baseline.getGeneration();
  Individual[] populationBefore = snapshotPopulation(baseline);
  Individual candidate = baseline.getIndividual(0);
  Individual candidateGenomeBefore = candidate.deepCopy();

  PImage firstRender = targetFitness.renderCandidate(candidate);
  PImage secondRender = targetFitness.renderCandidate(candidate);
  TargetEvaluation deterministicComparison = targetFitness.compareImages(firstRender, secondRender);
  require(deterministicComparison.rmse == 0.0, "Repeated off-screen renders were not pixel-identical");

  TargetEvaluation identical = targetFitness.evaluateAgainst(candidate, firstRender);
  require(identical.rmse < 0.00001, "Identical render RMSE must be zero");
  require(identical.normalizedRMSE < 0.00001, "Identical normalized RMSE must be zero");
  require(abs((float) identical.fitness - 1.0) < 0.00001, "Identical fitness must be one");

  PImage white = createSolidImage(config.evaluationWidth, config.evaluationHeight, color(255));
  PImage black = createSolidImage(config.evaluationWidth, config.evaluationHeight, color(0));
  TargetEvaluation maximumDifference = targetFitness.compareImages(white, black);
  require(abs((float) maximumDifference.rmse - 255.0) < 0.00001,
    "White/black RMSE must be 255");
  require(abs((float) maximumDifference.normalizedRMSE - 1.0) < 0.00001,
    "White/black normalized RMSE must be one");
  require(maximumDifference.fitness < 0.00001, "White/black fitness must be zero");

  PImage halfDifferent = createHalfBlackHalfWhiteImage(
    config.evaluationWidth, config.evaluationHeight
  );
  TargetEvaluation intermediate = targetFitness.compareImages(white, halfDifferent);
  require(intermediate.fitness > 0.0 && intermediate.fitness < 1.0,
    "Partial difference must produce intermediate fitness");
  TargetEvaluation forward = targetFitness.compareImages(white, halfDifferent);
  TargetEvaluation reverse = targetFitness.compareImages(halfDifferent, white);
  require(abs((float) (forward.rmse - reverse.rmse)) < 0.00001,
    "RMSE must be symmetric");

  Individual changedIndividual = baseline.getIndividual(min(1, baseline.size() - 1));
  TargetEvaluation changedPhenotype = targetFitness.evaluateAgainst(changedIndividual, firstRender);
  require(changedPhenotype.fitness >= 0.0 && changedPhenotype.fitness <= 1.0,
    "Changed-Individual fitness left [0,1]");
  if (!individualsHaveSameGenomes(candidate, changedIndividual)) {
    require(changedPhenotype.rmse > 0.0 && changedPhenotype.fitness < 1.0,
      "Distinct deterministic Individuals unexpectedly rendered identical pixels");
  }

  expectInvalidImageComparison(null, white, "null candidate");
  expectInvalidImageComparison(white, null, "null target");
  expectInvalidImageComparison(white, createSolidImage(8, 8, color(255)), "dimension mismatch");
  expectNullIndividualEvaluation(firstRender);
  expectMissingTargetFailure();

  interactiveFitness.assignRating(candidate, 1);
  TargetEvaluation ratingOne = targetFitness.evaluateAgainst(candidate, firstRender);
  interactiveFitness.assignRating(candidate, 10);
  TargetEvaluation ratingTen = targetFitness.evaluateAgainst(candidate, firstRender);
  require(abs((float) (ratingOne.fitness - ratingTen.fitness)) < 0.00001,
    "Interactive rating changed automatic fitness");
  require(interactiveFitness.getRating(candidate) == 10,
    "Automatic evaluation modified interactive rating");

  interactiveUI.recalculateLayout(width, height, baseline.size());
  GridCell firstCell = interactiveUI.getCell(0);
  GridCell lastCell = interactiveUI.getCell(baseline.size() - 1);
  interactiveUI.selectAt(firstCell.centreX(), firstCell.centreY());
  interactiveUI.updateHover(lastCell.centreX(), lastCell.centreY());
  int selectedBefore = interactiveUI.getSelectedIndex();
  int hoveredBefore = interactiveUI.getHoveredIndex();
  TargetEvaluation uiChanged = targetFitness.evaluateAgainst(candidate, firstRender);
  require(abs((float) (ratingTen.fitness - uiChanged.fitness)) < 0.00001,
    "UI state changed automatic fitness");
  require(interactiveUI.getSelectedIndex() == selectedBefore,
    "Target evaluation modified selectedIndex");
  require(interactiveUI.getHoveredIndex() == hoveredBefore,
    "Target evaluation modified hoveredIndex");

  require(individualsHaveSameGenomes(candidateGenomeBefore, candidate),
    "Target evaluation modified genotype");
  require(populationsHaveSameGenomes(populationBefore, baseline),
    "Target evaluation modified Population genomes");
  require(baseline.size() == config.populationSize, "Target evaluation changed population size");
  require(baseline.getGeneration() == generationBefore,
    "Target evaluation changed generation");

  PImage smallTransparent = createImage(8, 4, ARGB);
  smallTransparent.loadPixels();
  for (int i = 0; i < smallTransparent.pixels.length; i++) {
    smallTransparent.pixels[i] = color(0, 0);
  }
  smallTransparent.updatePixels();
  targetFitness.setTarget(smallTransparent);
  require(targetFitness.normalizedTarget.width == config.evaluationWidth
      && targetFitness.normalizedTarget.height == config.evaluationHeight,
    "Target preprocessing did not normalize dimensions");

  validateTargetFitnessForFormulaCount(1);
  validateTargetFitnessForFormulaCount(3);
  interactiveFitness.clearRating(candidate);
  interactiveUI.clearInteraction();
  println(
    "Phase 10 metrics: identical=" + identical.fitness
    + " maximumDifference=" + maximumDifference.fitness
    + " intermediate=" + intermediate.fitness
  );
  println("Phase 10 validation passed: deterministic off-screen blue-channel RMSE evaluation");
}

void validateTargetFitnessForFormulaCount(int formulaCount) {
  Config testConfig = new Config(2, config.randomSeed, formulaCount);
  Individual testIndividual = createDistinctCrossoverParent(testConfig, true);
  SuperFormulaRenderer testFormulaRenderer = new SuperFormulaRenderer(testConfig);
  IndividualRenderer testIndividualRenderer = new IndividualRenderer(testConfig, testFormulaRenderer);
  TargetImageFitness evaluator = new TargetImageFitness(testConfig, testIndividualRenderer);
  PImage rendered = evaluator.renderCandidate(testIndividual);
  TargetEvaluation result = evaluator.evaluateAgainst(testIndividual, rendered);
  require(result.fitness > 0.99999,
    "Target fitness identical-render test failed for N=" + formulaCount);
}

PImage createSolidImage(int imageWidth, int imageHeight, int pixelColor) {
  PImage image = createImage(imageWidth, imageHeight, RGB);
  image.loadPixels();
  for (int i = 0; i < image.pixels.length; i++) image.pixels[i] = pixelColor;
  image.updatePixels();
  return image;
}

PImage createHalfBlackHalfWhiteImage(int imageWidth, int imageHeight) {
  PImage image = createImage(imageWidth, imageHeight, RGB);
  image.loadPixels();
  int halfway = image.pixels.length / 2;
  for (int i = 0; i < image.pixels.length; i++) {
    image.pixels[i] = i < halfway ? color(0) : color(255);
  }
  image.updatePixels();
  return image;
}

void expectInvalidImageComparison(PImage candidate, PImage target, String caseName) {
  boolean rejected = false;
  try {
    targetFitness.compareImages(candidate, target);
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Target comparator should reject " + caseName);
}

void expectNullIndividualEvaluation(PImage target) {
  boolean rejected = false;
  try {
    targetFitness.evaluateAgainst(null, target);
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Target evaluator should reject null Individual");
}

void expectMissingTargetFailure() {
  TargetImageFitness evaluator = new TargetImageFitness(config, individualRenderer);
  boolean rejected = false;
  try {
    evaluator.evaluate(population.getIndividual(0));
  }
  catch (IllegalStateException expected) {
    rejected = true;
  }
  require(rejected, "Evaluation without a loaded target should fail clearly");
}

void runPhaseElevenChecks() {
  require(config.maxAutomaticGenerations == 1000,
    "Configured maxAutomaticGenerations must be 1000");
  validateAutomaticPopulationSize(1);
  validateAutomaticPopulationSize(5);
  validateAutomaticPopulationSize(8);
  validateAutomaticPopulationSize(9);
  validateAutomaticPopulationSize(10);

  String[] crossovers = { "PARAMETER_UNIFORM", "WHOLE_FORMULA_UNIFORM" };
  String[] mutations = { "BOUNDED_UNIFORM_MUTATION", "GAUSSIAN_PARAMETER_MUTATION" };
  for (int c = 0; c < crossovers.length; c++) {
    for (int m = 0; m < mutations.length; m++) {
      Config operatorConfig = phaseElevenConfig(3, crossovers[c], mutations[m]);
      Population operatorPopulation = new Population(operatorConfig);
      AutomaticEvolution engine = createAutomaticEngine(operatorConfig, operatorPopulation);
      require(engine.step(operatorPopulation), "Automatic operator combination failed");
      require(operatorPopulation.getGeneration() == 1,
        "Automatic operator combination did not increment generation once");
      validateAutomaticChildren(operatorPopulation, engine);
    }
  }

  validateAutomaticReproducibility();
  validateAutomaticIgnoresRatingsAndUI();
  validateAutomaticFailureAndTargetRevision();
  validateZeroWeightAutomaticReplacement();
  println("Phase 11 validation passed: automatic target evolution generation 0 -> 5");
}

Config phaseElevenConfig(int populationSize, String crossoverName, String mutationName) {
  return new Config(
    populationSize, config.randomSeed, config.formulasPerIndividual,
    config.mutationRate, config.uniformMutationDelta, config.gaussianMutationSigma,
    crossoverName, mutationName
  );
}

AutomaticEvolution createAutomaticEngine(Config testConfig, Population testPopulation) {
  SuperFormulaRenderer formula = new SuperFormulaRenderer(testConfig);
  IndividualRenderer renderer = new IndividualRenderer(testConfig, formula);
  TargetImageFitness evaluator = new TargetImageFitness(testConfig, renderer);
  evaluator.setTarget(evaluator.renderCandidate(testPopulation.getIndividual(0)));
  AutomaticEvolution engine = new AutomaticEvolution(
    testConfig, evaluator, new Crossover(), new Mutation()
  );
  require(engine.enterAutomaticMode(testPopulation), "Valid target must enable automatic mode");
  require(engine.hasCurrentEvaluation(testPopulation), "Generation 0 was not evaluated");
  return engine;
}

void validateAutomaticPopulationSize(int populationSize) {
  Config testConfig = phaseElevenConfig(
    populationSize, "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
  );
  Population testPopulation = new Population(testConfig);
  AutomaticEvolution engine = createAutomaticEngine(testConfig, testPopulation);
  require(engine.start(testPopulation), "Automatic start failed for valid target");
  require(engine.automaticRunning, "Automatic start did not set running state");
  engine.stop();
  require(!engine.automaticRunning, "Automatic stop did not clear running state");
  require(engine.step(testPopulation), "Automatic step failed for populationSize=" + populationSize);
  require(testPopulation.size() == populationSize,
    "Automatic evolution changed populationSize=" + populationSize);
  validateAutomaticChildren(testPopulation, engine);
}

void validateAutomaticChildren(Population candidate, AutomaticEvolution engine) {
  require(engine.hasCurrentEvaluation(candidate), "New automatic population was not evaluated");
  require(engine.bestIndex >= 0 && engine.bestIndex < candidate.size(),
    "Automatic best index is invalid");
  require(engine.bestFitness >= 0.0 && engine.bestFitness <= 1.0,
    "Automatic best fitness is outside [0,1]");
  require(engine.meanFitness >= 0.0 && engine.meanFitness <= 1.0,
    "Automatic mean fitness is outside [0,1]");
  for (int i = 0; i < candidate.size(); i++) {
    Individual child = candidate.getIndividual(i);
    require(child.getFormulaCount() == candidate.config.formulasPerIndividual,
      "Automatic child changed fixed N");
    require(!child.hasInteractiveRating(), "Automatic child inherited a human rating");
    require(engine.getFitness(i, candidate) >= 0.0 && engine.getFitness(i, candidate) <= 1.0,
      "Automatic child fitness is outside [0,1]");
    for (int formulaIndex = 0; formulaIndex < child.getFormulaCount(); formulaIndex++) {
      requireGeneIsNormalized(child.getFormula(formulaIndex));
      int decodedM = candidate.config.decodeM(child.getFormula(formulaIndex).mGene);
      require(decodedM >= candidate.config.mMin && decodedM <= candidate.config.mMax,
        "Automatic child has invalid semantic m");
    }
  }
}

void validateAutomaticReproducibility() {
  Config testConfig = phaseElevenConfig(
    3, "WHOLE_FORMULA_UNIFORM", "GAUSSIAN_PARAMETER_MUTATION"
  );
  Population firstPopulation = new Population(testConfig);
  Population secondPopulation = new Population(testConfig);

  SuperFormulaRenderer firstFormula = new SuperFormulaRenderer(testConfig);
  IndividualRenderer firstRenderer = new IndividualRenderer(testConfig, firstFormula);
  TargetImageFitness firstTarget = new TargetImageFitness(testConfig, firstRenderer);
  PImage sharedTarget = firstTarget.renderCandidate(firstPopulation.getIndividual(0));
  firstTarget.setTarget(sharedTarget);

  SuperFormulaRenderer secondFormula = new SuperFormulaRenderer(testConfig);
  IndividualRenderer secondRenderer = new IndividualRenderer(testConfig, secondFormula);
  TargetImageFitness secondTarget = new TargetImageFitness(testConfig, secondRenderer);
  secondTarget.setTarget(sharedTarget);

  AutomaticEvolution first = new AutomaticEvolution(
    testConfig, firstTarget, new Crossover(), new Mutation()
  );
  AutomaticEvolution second = new AutomaticEvolution(
    testConfig, secondTarget, new Crossover(), new Mutation()
  );
  first.enterAutomaticMode(firstPopulation);
  second.enterAutomaticMode(secondPopulation);
  for (int generation = 1; generation <= 5; generation++) {
    first.step(firstPopulation);
    second.step(secondPopulation);
    require(firstPopulation.getGeneration() == generation
        && secondPopulation.getGeneration() == generation,
      "Reproducibility run has wrong generation");
    require(populationsHaveSameGenomes(snapshotPopulation(firstPopulation), secondPopulation),
      "Same automatic run diverged at generation " + generation);
    double[] firstFitness = first.copyFitness();
    double[] secondFitness = second.copyFitness();
    for (int i = 0; i < firstFitness.length; i++) {
      require(Math.abs(firstFitness[i] - secondFitness[i]) < 0.000000001,
        "Same automatic run produced different fitness values");
    }
  }
}

void validateAutomaticIgnoresRatingsAndUI() {
  Config testConfig = phaseElevenConfig(
    3, "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
  );
  Population lowRatings = new Population(testConfig);
  Population highRatings = new Population(testConfig);
  InteractiveFitness ratings = new InteractiveFitness();
  for (int i = 0; i < lowRatings.size(); i++) {
    ratings.assignRating(lowRatings.getIndividual(i), 1);
    ratings.assignRating(highRatings.getIndividual(i), 10);
  }
  AutomaticEvolution lowEngine = createAutomaticEngine(testConfig, lowRatings);
  AutomaticEvolution highEngine = createAutomaticEngine(testConfig, highRatings);
  interactiveUI.selectedIndex = 0;
  interactiveUI.hoveredIndex = 1;
  lowEngine.step(lowRatings);
  highEngine.step(highRatings);
  require(populationsHaveSameGenomes(snapshotPopulation(lowRatings), highRatings),
    "Human ratings affected automatic evolution");
  require(interactiveUI.selectedIndex == 0 && interactiveUI.hoveredIndex == 1,
    "Automatic evolution changed UI focus state");
  interactiveUI.clearInteraction();
}

void validateAutomaticFailureAndTargetRevision() {
  Config testConfig = phaseElevenConfig(
    3, "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
  );
  Population missingPopulation = new Population(testConfig);
  SuperFormulaRenderer formula = new SuperFormulaRenderer(testConfig);
  IndividualRenderer renderer = new IndividualRenderer(testConfig, formula);
  TargetImageFitness missingTarget = new TargetImageFitness(testConfig, renderer);
  AutomaticEvolution unavailable = new AutomaticEvolution(
    testConfig, missingTarget, new Crossover(), new Mutation()
  );
  require(!unavailable.start(missingPopulation), "Missing target started automatic run");
  require(missingPopulation.getGeneration() == 0,
    "Failed automatic start changed generation");

  Population revisionPopulation = new Population(testConfig);
  TargetImageFitness revisionTarget = new TargetImageFitness(testConfig, renderer);
  revisionTarget.setTarget(revisionTarget.renderCandidate(revisionPopulation.getIndividual(0)));
  AutomaticEvolution revisionEngine = new AutomaticEvolution(
    testConfig, revisionTarget, new Crossover(), new Mutation()
  );
  revisionEngine.enterAutomaticMode(revisionPopulation);
  require(revisionEngine.hasCurrentEvaluation(revisionPopulation), "Initial evaluation is missing");
  revisionTarget.setTarget(revisionTarget.renderCandidate(revisionPopulation.getIndividual(1)));
  require(!revisionEngine.hasCurrentEvaluation(revisionPopulation),
    "Target change did not invalidate automatic fitness");

  require(revisionEngine.start(revisionPopulation), "Valid target did not start automatic run");
  int generationBeforeMissingTarget = revisionPopulation.getGeneration();
  revisionTarget.normalizedTarget = null;
  require(!revisionEngine.step(revisionPopulation), "Missing target allowed an automatic step");
  require(!revisionEngine.automaticRunning,
    "Target loss did not stop the automatic run");
  require(revisionPopulation.getGeneration() == generationBeforeMissingTarget,
    "Target loss changed generation");
  revisionTarget.setTarget(revisionTarget.renderCandidate(revisionPopulation.getIndividual(0)));

  revisionPopulation.generation = testConfig.maxAutomaticGenerations;
  require(!revisionEngine.start(revisionPopulation), "Generation limit did not stop automatic start");
  require(!revisionEngine.automaticRunning, "Generation limit left automatic run active");
}

void validateZeroWeightAutomaticReplacement() {
  Config testConfig = phaseElevenConfig(
    3, "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
  );
  Population candidate = new Population(testConfig);
  boolean replaced = candidate.nextGenerationFromWeights(
    new double[] { 0.0, 0.0, 0.0 },
    new RouletteWheelSelection(testConfig.selectionSeed),
    new Crossover(),
    new Mutation(),
    new java.util.Random(testConfig.crossoverSeed),
    new java.util.Random(testConfig.mutationSeed)
  );
  require(replaced && candidate.getGeneration() == 1,
    "Zero-total automatic weights did not use uniform fallback");
}

void validateGridLayout(int populationSize, int canvasWidth, int canvasHeight) {
  interactiveUI.recalculateLayout(canvasWidth, canvasHeight, populationSize);
  require(interactiveUI.getCellCount() == populationSize,
    "Grid cell count mismatch for populationSize=" + populationSize);

  boolean[] seenIndices = new boolean[populationSize];
  for (int i = 0; i < interactiveUI.getCellCount(); i++) {
    GridCell cell = interactiveUI.getCell(i);
    require(cell.populationIndex >= 0 && cell.populationIndex < populationSize,
      "Grid contains an out-of-range population index");
    require(!seenIndices[cell.populationIndex], "Grid contains a duplicate population index");
    seenIndices[cell.populationIndex] = true;
    require(cell.size > 0, "Grid cell size must be positive");
    require(cell.x >= 0 && cell.y >= interactiveUI.statusHeight,
      "Grid cell starts outside the drawable area");
    require(cell.x + cell.size <= canvasWidth && cell.y + cell.size <= canvasHeight,
      "Grid cell extends outside the canvas");

    interactiveUI.updateHover(cell.centreX(), cell.centreY());
    require(interactiveUI.getHoveredIndex() == cell.populationIndex,
      "Cell centre does not map to its population index");
  }

  for (int i = 0; i < seenIndices.length; i++) {
    require(seenIndices[i], "Grid omitted population index " + i);
  }
  interactiveUI.updateHover(0, 0);
  require(interactiveUI.getHoveredIndex() == -1,
    "Empty/status space incorrectly maps to an Individual");
}

void validatePopulationShapeAndOwnership(Population candidate) {
  for (int i = 0; i < candidate.size(); i++) {
    Individual individual = candidate.getIndividual(i);
    require(individual != null, "Population contains a null Individual");
    require(individual.getFormulaCount() == candidate.config.formulasPerIndividual,
      "Individual formula count does not match Config");
    for (int formulaIndex = 0; formulaIndex < individual.getFormulaCount(); formulaIndex++) {
      require(individual.getFormula(formulaIndex) != null, "Individual contains a null gene");
      requireGeneIsNormalized(individual.getFormula(formulaIndex));
    }

    for (int otherIndex = i + 1; otherIndex < candidate.size(); otherIndex++) {
      Individual other = candidate.getIndividual(otherIndex);
      require(individual != other, "Population slots share an Individual object");
      require(individual.formulas != other.formulas, "Individuals share a formula array");
      for (int formulaIndex = 0; formulaIndex < individual.getFormulaCount(); formulaIndex++) {
        require(individual.getFormula(formulaIndex) != other.getFormula(formulaIndex),
          "Individuals share a SuperFormulaGene object");
      }
    }
  }
}

void requireGeneIsNormalized(SuperFormulaGene gene) {
  require(gene.aGene >= 0 && gene.aGene <= 1, "aGene outside [0,1]");
  require(gene.bGene >= 0 && gene.bGene <= 1, "bGene outside [0,1]");
  require(gene.mGene >= 0 && gene.mGene <= 1, "mGene outside [0,1]");
  require(gene.n1Gene >= 0 && gene.n1Gene <= 1, "n1Gene outside [0,1]");
  require(gene.n2Gene >= 0 && gene.n2Gene <= 1, "n2Gene outside [0,1]");
  require(gene.n3Gene >= 0 && gene.n3Gene <= 1, "n3Gene outside [0,1]");
}

Individual[] snapshotPopulation(Population source) {
  Individual[] snapshot = new Individual[source.size()];
  for (int i = 0; i < source.size(); i++) {
    snapshot[i] = source.getIndividual(i).deepCopy();
  }
  return snapshot;
}

boolean populationsHaveSameGenomes(Individual[] expected, Population actual) {
  if (expected.length != actual.size()) {
    return false;
  }
  for (int i = 0; i < expected.length; i++) {
    for (int j = 0; j < expected[i].getFormulaCount(); j++) {
      if (!genesHaveSameValues(expected[i].getFormula(j), actual.getIndividual(i).getFormula(j))) {
        return false;
      }
    }
  }
  return true;
}

boolean populationsHaveDifferentGenomes(Individual[] expected, Population actual) {
  return !populationsHaveSameGenomes(expected, actual);
}

void expectPopulationIndexFailure(Population candidate, int index) {
  boolean rejected = false;
  try {
    candidate.getIndividual(index);
  }
  catch (IndexOutOfBoundsException expected) {
    rejected = true;
  }
  require(rejected, "Population should reject index " + index);
}

void expectInvalidPopulationSize(int populationSize) {
  boolean rejected = false;
  try {
    Config invalidConfig = new Config(populationSize, config.randomSeed);
    invalidConfig.validate();
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Config should reject populationSize=" + populationSize);
}

void expectInvalidIndividual(SuperFormulaGene[] formulas, String caseName) {
  boolean rejected = false;
  try {
    new Individual(config, formulas);
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Individual should reject " + caseName);
}

void expectNullFormulaArray() {
  boolean rejected = false;
  try {
    new Individual(config, null);
  }
  catch (IllegalArgumentException expected) {
    rejected = true;
  }
  require(rejected, "Individual should reject a null formula array");
}

boolean genesHaveSameValues(SuperFormulaGene left, SuperFormulaGene right) {
  return left.aGene == right.aGene
    && left.bGene == right.bGene
    && left.mGene == right.mGene
    && left.n1Gene == right.n1Gene
    && left.n2Gene == right.n2Gene
    && left.n3Gene == right.n3Gene;
}


void runPhaseFourteenChecks() {
  require(config.populationSize == 30, "Phase 14 default populationSize must be 30");
  require(config.eliteSize == 1, "Phase 14 eliteSize must be 1");
  validatePhaseFourteenRendering();
  validateFitnessFormulaEquivalence();
  validateAutomaticElitePreservation();
  validateInteractiveElitePreservation();
  validateFitnessOrdering();
  validatePopulationThirty();
  println("Phase 14 validation passed: reference alignment and one-elite preservation");
}

void validatePhaseFourteenRendering() {
  require(config.automaticBackground == 255, "Automatic background must be white");
  require(config.automaticStroke == 0, "Automatic stroke must be black");
  require(abs(config.automaticStrokeWeight(256) - 0.512) < 0.000001,
    "Automatic strokeWeight at 256px must be 0.512");

  SuperFormulaGene circle = config.geneFromDecoded(1, 1, 4, 2, 2, 2);
  SuperFormulaGene[] formulas = new SuperFormulaGene[config.formulasPerIndividual];
  for (int i = 0; i < formulas.length; i++) formulas[i] = circle;
  PImage rendered = targetFitness.renderCandidate(new Individual(config, formulas));
  rendered.loadPixels();
  require((rendered.pixels[0] & 0xff) == 255, "Automatic render background is not white");
  int centre = (rendered.height / 2) * rendered.width + rendered.width / 2;
  require((rendered.pixels[centre] & 0xff) == 255, "Automatic Superformula render must use no fill");
  boolean foundVisibleStroke = false;
  for (int i = 0; i < rendered.pixels.length; i++) {
    if ((rendered.pixels[i] & 0xff) < 255) {
      foundVisibleStroke = true;
      break;
    }
  }
  require(foundVisibleStroke, "Automatic render did not contain a visible black stroke");
}

void validateFitnessFormulaEquivalence() {
  PImage white = createSolidImage(16, 16, color(255));
  PImage black = createSolidImage(16, 16, color(0));
  PImage shape = createSolidImage(16, 16, color(255));
  shape.loadPixels();
  for (int y = 4; y < 12; y++) {
    for (int x = 5; x < 11; x++) shape.pixels[y * shape.width + x] = color(0);
  }
  shape.updatePixels();

  PImage partial = createImage(16, 16, RGB);
  partial.loadPixels();
  int[] grayscale = { 0, 85, 170, 255 };
  for (int i = 0; i < partial.pixels.length; i++) partial.pixels[i] = color(grayscale[i % 4]);
  partial.updatePixels();

  assertReferenceFitnessEquivalent(white, white, "identical white images");
  assertReferenceFitnessEquivalent(black, white, "black versus white");
  assertReferenceFitnessEquivalent(shape, white, "simple black shape on white");
  assertReferenceFitnessEquivalent(partial, white, "partially different grayscale image");
}

void assertReferenceFitnessEquivalent(PImage candidate, PImage target, String caseName) {
  double actual = targetFitness.compareImages(candidate, target).fitness;
  double expected = referenceBlueChannelFitness(candidate, target);
  require(Math.abs(actual - expected) < 0.000000000001,
    "Blue-channel fitness diverged from reference for " + caseName);
}

double referenceBlueChannelFitness(PImage candidate, PImage target) {
  candidate.loadPixels();
  target.loadPixels();
  double squaredError = 0.0;
  for (int i = 0; i < candidate.pixels.length; i++) {
    int difference = (target.pixels[i] & 0xff) - (candidate.pixels[i] & 0xff);
    squaredError += (double) difference * difference;
  }
  double rmse = Math.sqrt(squaredError / candidate.pixels.length);
  return 1.0 - rmse / 255.0;
}

void validateAutomaticElitePreservation() {
  Config automaticConfig = new Config(
    8, config.randomSeed, config.formulasPerIndividual,
    config.mutationRate, config.uniformMutationDelta, config.gaussianMutationSigma,
    "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
  );
  Population automaticPopulation = new Population(automaticConfig);
  AutomaticEvolution engine = createAutomaticEngine(automaticConfig, automaticPopulation);
  Individual expectedElite = automaticPopulation.getIndividual(engine.bestIndex).deepCopy();
  require(engine.stepFromCurrentEvaluation(automaticPopulation), "Automatic elite test did not evolve");
  require(populationContainsGenome(expectedElite, automaticPopulation),
    "Automatic best genotype was not preserved");

  Config highMutationConfig = new Config(
    6, config.randomSeed, config.formulasPerIndividual,
    1.0, 0.5, config.gaussianMutationSigma,
    "PARAMETER_UNIFORM", "BOUNDED_UNIFORM_MUTATION"
  );
  Population highMutationPopulation = new Population(highMutationConfig);
  Individual commonGenome = highMutationPopulation.getIndividual(0).deepCopy();
  for (int i = 0; i < highMutationPopulation.size(); i++) {
    highMutationPopulation.individuals[i] = commonGenome.deepCopy();
  }
  double[] equalWeights = new double[highMutationPopulation.size()];
  java.util.Arrays.fill(equalWeights, 1.0);
  highMutationPopulation.nextGenerationFromWeights(
    equalWeights,
    new RouletteWheelSelection(highMutationConfig.selectionSeed),
    new Crossover(),
    new Mutation(),
    new java.util.Random(highMutationConfig.crossoverSeed),
    new java.util.Random(highMutationConfig.mutationSeed)
  );
  require(individualsHaveSameGenomes(commonGenome, highMutationPopulation.getIndividual(0)),
    "High mutation changed the automatic elite");
  for (int i = highMutationConfig.eliteSize; i < highMutationPopulation.size(); i++) {
    require(!individualsHaveSameGenomes(commonGenome, highMutationPopulation.getIndividual(i)),
      "High mutation did not change ordinary offspring at index " + i);
  }
}

void validateInteractiveElitePreservation() {
  Config interactiveConfig = new Config(6, config.randomSeed, config.formulasPerIndividual);
  Population interactivePopulation = new Population(interactiveConfig);
  for (int i = 0; i < interactivePopulation.size(); i++) {
    interactiveFitness.assignRating(interactivePopulation.getIndividual(i), 1);
  }
  interactiveFitness.assignRating(interactivePopulation.getIndividual(2), 10);
  interactiveFitness.assignRating(interactivePopulation.getIndividual(4), 10);
  Individual expectedElite = interactivePopulation.getIndividual(2).deepCopy();
  require(evolveTestPopulation(interactivePopulation, interactiveConfig),
    "Interactive elite test did not evolve");
  require(individualsHaveSameGenomes(expectedElite, interactivePopulation.getIndividual(0)),
    "Interactive tie policy did not preserve the lowest-index best genotype");
  require(interactiveFitness.ratedCount(interactivePopulation) == 0,
    "Interactive elite carried a stale rating into the new generation");
}

void validatePopulationThirty() {
  Population populationThirty = new Population(config);
  require(populationThirty.size() == 30, "Population 30 initialization failed");
  validateGridLayout(30, config.canvasWidth, config.canvasHeight);
  validateLifecyclePopulationSize(30);
  validateAutomaticPopulationSize(30);
}


void validateFitnessOrdering() {
  Config interactiveConfig = new Config(5, config.randomSeed, config.formulasPerIndividual);
  Population interactivePopulation = new Population(interactiveConfig);
  Individual firstTie = interactivePopulation.getIndividual(0);
  Individual secondTie = interactivePopulation.getIndividual(1);
  Individual highest = interactivePopulation.getIndividual(2);
  Individual lowest = interactivePopulation.getIndividual(3);
  Individual unrated = interactivePopulation.getIndividual(4);
  interactiveFitness.assignRating(firstTie, 7);
  interactiveFitness.assignRating(secondTie, 7);
  interactiveFitness.assignRating(highest, 10);
  interactiveFitness.assignRating(lowest, 2);

  interactivePopulation.sortByInteractiveFitness(interactiveFitness);
  require(interactivePopulation.getIndividual(0) == highest,
    "Highest interactive fitness was not sorted first");
  require(interactivePopulation.getIndividual(1) == firstTie
      && interactivePopulation.getIndividual(2) == secondTie,
    "Interactive fitness ties did not preserve their previous order");
  require(interactivePopulation.getIndividual(3) == lowest,
    "Lower interactive fitness is out of order");
  require(interactivePopulation.getIndividual(4) == unrated,
    "UNRATED Individual was not sorted last");

  Config automaticConfig = new Config(
    6, config.randomSeed, config.formulasPerIndividual,
    config.mutationRate, config.uniformMutationDelta, config.gaussianMutationSigma,
    config.crossoverOperator, config.mutationOperator
  );
  Population automaticPopulation = new Population(automaticConfig);
  AutomaticEvolution engine = createAutomaticEngine(automaticConfig, automaticPopulation);
  requireAutomaticFitnessDescending(engine, automaticPopulation);
  require(engine.stepFromCurrentEvaluation(automaticPopulation),
    "Automatic ordering test did not evolve");
  requireAutomaticFitnessDescending(engine, automaticPopulation);
}

void requireAutomaticFitnessDescending(
    AutomaticEvolution engine, Population population) {
  for (int i = 1; i < population.size(); i++) {
    require(engine.getFitness(i - 1, population) >= engine.getFitness(i, population),
      "Automatic population is not sorted by descending fitness at index " + i);
  }
  require(engine.bestIndex == 0, "Best automatic Individual must be at index 0");
}
boolean populationContainsGenome(Individual expected, Population actual) {
  for (int i = 0; i < actual.size(); i++) {
    if (individualsHaveSameGenomes(expected, actual.getIndividual(i))) return true;
  }
  return false;
}
void require(boolean condition, String message) {
  if (!condition) {
    throw new RuntimeException(message);
  }
}

boolean nearlyEqual(float left, float right) {
  return abs(left - right) < 0.00001;
}
