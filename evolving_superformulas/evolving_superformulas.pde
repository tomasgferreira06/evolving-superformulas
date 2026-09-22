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
AutomaticEvolutionController automaticEvolution;

void settings() {
  size(config.canvasWidth, config.canvasHeight, P2D);
}

void setup() {
  int startupStartedAt = millis();
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

  targetFitness.loadConfiguredTarget();
  automaticEvolution = new AutomaticEvolutionController(config, targetFitness, crossover, mutation);
  interactiveUI.setAutomaticEvolution(automaticEvolution);
  println("Startup completed in " + (millis() - startupStartedAt) + " ms");
}

void draw() {
  if (automaticEvolution != null) automaticEvolution.updateOneFrame(population);
  background(255);
  interactiveUI.renderPopulation(
    population, width, height, mouseX, mouseY
  );
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
