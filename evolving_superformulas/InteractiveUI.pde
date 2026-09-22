class GridCell {
  final float x;
  final float y;
  final float size;
  final int populationIndex;

  GridCell(float x, float y, float size, int populationIndex) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.populationIndex = populationIndex;
  }

  float centreX() {
    return x + size * 0.5;
  }

  float centreY() {
    return y + size * 0.5;
  }

  boolean contains(float pointX, float pointY) {
    return pointX >= x && pointX < x + size
      && pointY >= y && pointY < y + size;
  }
}

class InteractiveUI {
  final Config config;
  final IndividualRenderer individualRenderer;
  final InteractiveFitness interactiveFitness;
  final float statusHeight = 182;
  final float margin = 10;
  final float gutter = 8;
  final float cellPadding = 6;

  GridCell[] cells = new GridCell[0];
  int hoveredIndex = -1;
  int selectedIndex = -1;
  int layoutWidth = -1;
  int layoutHeight = -1;
  int layoutPopulationSize = -1;
  AutomaticEvolution automaticEvolution;

  InteractiveUI(Config config, IndividualRenderer individualRenderer, InteractiveFitness interactiveFitness) {
    if (config == null || individualRenderer == null || interactiveFitness == null) {
      throw new IllegalArgumentException("InteractiveUI requires Config, IndividualRenderer, and InteractiveFitness");
    }
    this.config = config;
    this.individualRenderer = individualRenderer;
    this.interactiveFitness = interactiveFitness;
  }

  void setAutomaticEvolution(AutomaticEvolution automaticEvolution) {
    this.automaticEvolution = automaticEvolution;
  }

  void recalculateLayout(int canvasWidth, int canvasHeight, int populationSize) {
    if (canvasWidth <= 0 || canvasHeight <= 0) {
      throw new IllegalArgumentException("Canvas dimensions must be positive");
    }
    if (populationSize <= 0) {
      throw new IllegalArgumentException("Grid population size must be positive");
    }

    float drawableWidth = canvasWidth - margin * 2;
    float drawableHeight = canvasHeight - statusHeight - margin * 2;
    if (drawableWidth <= 0 || drawableHeight <= 0) {
      throw new IllegalArgumentException("Canvas is too small for the grid and status area");
    }

    // Try every column count and keep the arrangement with the largest square cell.
    int bestColumns = 1;
    int bestRows = populationSize;
    float bestCellSize = -1;
    for (int columns = 1; columns <= populationSize; columns++) {
      int rows = (int) ceil(populationSize / (float) columns);
      float availableWidth = drawableWidth - (columns - 1) * gutter;
      float availableHeight = drawableHeight - (rows - 1) * gutter;
      if (availableWidth <= 0 || availableHeight <= 0) {
        continue;
      }
      float candidateSize = min(availableWidth / columns, availableHeight / rows);
      if (candidateSize > bestCellSize) {
        bestCellSize = candidateSize;
        bestColumns = columns;
        bestRows = rows;
      }
    }
    if (bestCellSize <= 0) {
      throw new IllegalArgumentException("No positive grid cell size fits the canvas");
    }

    float gridWidth = bestColumns * bestCellSize + (bestColumns - 1) * gutter;
    float gridHeight = bestRows * bestCellSize + (bestRows - 1) * gutter;
    float startX = margin + (drawableWidth - gridWidth) * 0.5;
    float startY = statusHeight + margin + (drawableHeight - gridHeight) * 0.5;

    cells = new GridCell[populationSize];
    for (int index = 0; index < populationSize; index++) {
      int column = index % bestColumns;
      int row = index / bestColumns;
      cells[index] = new GridCell(
        startX + column * (bestCellSize + gutter),
        startY + row * (bestCellSize + gutter),
        bestCellSize,
        index
      );
    }

    layoutWidth = canvasWidth;
    layoutHeight = canvasHeight;
    layoutPopulationSize = populationSize;
    hoveredIndex = -1;
    if (selectedIndex >= populationSize) {
      selectedIndex = -1;
    }
  }

  void ensureLayout(int canvasWidth, int canvasHeight, int populationSize) {
    if (canvasWidth != layoutWidth
        || canvasHeight != layoutHeight
        || populationSize != layoutPopulationSize) {
      recalculateLayout(canvasWidth, canvasHeight, populationSize);
    }
  }

  int renderPopulation(
      Population population,
      int canvasWidth,
      int canvasHeight,
      float pointerX,
      float pointerY) {
    if (population == null) {
      throw new IllegalArgumentException("Population must not be null");
    }
    ensureLayout(canvasWidth, canvasHeight, population.size());
    updateHover(pointerX, pointerY);

    int renderedCount = 0;
    for (int i = 0; i < cells.length; i++) {
      GridCell cell = cells[i];
      drawCellBackground(cell);

      float maximumFormulaRadiusPixels = config.maximumSafeRadius * config.renderScale;
      float displayScale = (cell.size - cellPadding * 2) / (maximumFormulaRadiusPixels * 2);
      displayScale = max(displayScale, 0.0001);

      pushMatrix();
      translate(cell.centreX(), cell.centreY());
      scale(displayScale);
      individualRenderer.render(population.getIndividual(cell.populationIndex));
      popMatrix();

      drawCellFeedback(cell);
      drawEvaluation(population, cell);
      renderedCount++;
    }

    drawStatus(population);
    return renderedCount;
  }

  void updateHover(float pointerX, float pointerY) {
    hoveredIndex = findIndexAt(pointerX, pointerY);
  }

  void selectAt(float pointerX, float pointerY) {
    hoveredIndex = findIndexAt(pointerX, pointerY);
    // Clicking empty space clears UI focus; it has no genetic meaning.
    selectedIndex = hoveredIndex;
  }

  void clearInteraction() {
    hoveredIndex = -1;
    selectedIndex = -1;
  }

  boolean rateSelected(Population population, int rating) {
    if (!hasValidSelectedIndex(population)) return false;
    Individual selected = population.getIndividual(selectedIndex);
    interactiveFitness.assignRating(selected, rating);
    return true;
  }

  boolean clearSelectedRating(Population population) {
    if (!hasValidSelectedIndex(population)) return false;
    Individual selected = population.getIndividual(selectedIndex);
    interactiveFitness.clearRating(selected);
    return true;
  }

  int getHoveredIndex() {
    return hoveredIndex;
  }

  int getSelectedIndex() {
    return selectedIndex;
  }

  int getCellCount() {
    return cells.length;
  }

  GridCell getCell(int index) {
    if (index < 0 || index >= cells.length) {
      throw new IndexOutOfBoundsException("Grid cell index out of range: " + index);
    }
    return cells[index];
  }

  private int findIndexAt(float pointerX, float pointerY) {
    for (int i = 0; i < cells.length; i++) {
      if (cells[i].contains(pointerX, pointerY)) {
        return cells[i].populationIndex;
      }
    }
    return -1;
  }

  private boolean hasValidSelectedIndex(Population population) {
    if (population == null) throw new IllegalArgumentException("Population must not be null");
    return selectedIndex >= 0 && selectedIndex < population.size();
  }

  private void drawCellBackground(GridCell cell) {
    noStroke();
    fill(250);
    rect(cell.x, cell.y, cell.size, cell.size);
  }

  private void drawCellFeedback(GridCell cell) {
    noFill();
    if (cell.populationIndex == selectedIndex) {
      stroke(40, 105, 190);
      strokeWeight(3);
      rect(cell.x, cell.y, cell.size, cell.size);
    } else {
      stroke(175);
      strokeWeight(1);
      rect(cell.x, cell.y, cell.size, cell.size);
    }

    if (cell.populationIndex == hoveredIndex) {
      stroke(230, 135, 35);
      strokeWeight(2);
      rect(cell.x + 3, cell.y + 3, cell.size - 6, cell.size - 6);
    }
  }

  private void drawEvaluation(Population population, GridCell cell) {
    noStroke();
    fill(24);
    textSize(12);
    Individual individual = population.getIndividual(cell.populationIndex);
    String label;
    if (isAutomaticMode()) {
      label = automaticEvolution.hasCurrentEvaluation(population)
        ? "Fitness: " + nf((float) automaticEvolution.getFitness(cell.populationIndex, population), 1, 3)
        : "Fitness: unavailable";
    } else {
      label = interactiveFitness.isRated(individual)
        ? "Rating: " + interactiveFitness.getRating(individual)
        : "Rating: UNRATED";
    }
    text(label, cell.x + 7, cell.y + cell.size - 8);
  }

  private void drawStatus(Population population) {
    fill(24);
    noStroke();
    textSize(13);
    if (isAutomaticMode()) {
      drawAutomaticStatus(population);
      return;
    }
    int rated = interactiveFitness.ratedCount(population);
    int unrated = population.size() - rated;
    text("Interactive Evolution", margin, 18);
    text(
      "Generation: " + population.getGeneration()
      + "  Population: " + population.size()
      + "  Formulas per Individual: " + config.formulasPerIndividual,
      margin,
      38
    );
    text(
      "hovered=" + indexLabel(hoveredIndex)
      + "  selected=" + indexLabel(selectedIndex),
      margin,
      56
    );
    text("Rated: " + rated + "/" + population.size(), margin, 74);
    text("Crossover: " + config.crossoverOperator, margin, 92);
    text("Mutation: " + config.mutationOperator, margin, 110);
    String readiness;
    if (unrated == 0) {
      readiness = "Ready to evolve";
    } else if (population.getGeneration() > 0) {
      readiness = "Generation " + population.getGeneration()
        + " created - rate all individuals (" + unrated + " remaining)";
    } else {
      readiness = "Rate all individuals - " + unrated + " remaining";
    }
    text(readiness, margin, 128);
    text("Click select | 1-9 rate | 0 rate 10 | Backspace/Delete clear", margin, 146);
    text("Enter/Space = next generation | R = reset", margin, 164);
  }

  private void drawAutomaticStatus(Population population) {
    boolean current = automaticEvolution.hasCurrentEvaluation(population);
    text("Automatic Target Evolution", margin, 18);
    text(
      "Generation: " + population.getGeneration()
      + " / " + config.maxAutomaticGenerations
      + "  Population: " + population.size()
      + "  Target: " + (automaticEvolution.targetFitness.hasTarget() ? "loaded" : "missing"),
      margin,
      38
    );
    text(
      "Running: " + (automaticEvolution.automaticRunning ? "yes" : "no")
      + "  Best index: " + (current ? str(automaticEvolution.bestIndex) : "none"),
      margin,
      56
    );
    text(
      "Best fitness: " + (current ? nf((float) automaticEvolution.bestFitness, 1, 4) : "unavailable")
      + "  Mean fitness: " + (current ? nf((float) automaticEvolution.meanFitness, 1, 4) : "unavailable"),
      margin,
      74
    );
    text("Crossover: " + config.crossoverOperator, margin, 92);
    text("Mutation: " + config.mutationOperator, margin, 110);
    text("A = start | S = stop | N = one automatic step", margin, 128);
    text("I = interactive mode | R = deterministic reset", margin, 146);
    text("hovered=" + indexLabel(hoveredIndex) + "  selected=" + indexLabel(selectedIndex), margin, 164);
  }

  private boolean isAutomaticMode() {
    return automaticEvolution != null && automaticEvolution.mode == EvolutionMode.AUTOMATIC;
  }

  private String indexLabel(int index) {
    return index < 0 ? "none" : str(index);
  }
}
