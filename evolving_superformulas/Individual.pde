class Individual {
  final Config config;
  final SuperFormulaGene[] formulas;
  final InteractiveEvaluation interactiveEvaluation;

  Individual(Config config, SuperFormulaGene[] sourceFormulas) {
    if (config == null) {
      throw new IllegalArgumentException("Individual requires a Config");
    }
    if (sourceFormulas == null) {
      throw new IllegalArgumentException("Formula array must not be null");
    }
    if (sourceFormulas.length != config.formulasPerIndividual) {
      throw new IllegalArgumentException(
        "Individual requires exactly " + config.formulasPerIndividual
        + " formulas, but received " + sourceFormulas.length
      );
    }

    this.config = config;
    interactiveEvaluation = new InteractiveEvaluation();
    formulas = new SuperFormulaGene[sourceFormulas.length];
    for (int i = 0; i < sourceFormulas.length; i++) {
      if (sourceFormulas[i] == null) {
        throw new IllegalArgumentException("Formula at index " + i + " must not be null");
      }
      formulas[i] = sourceFormulas[i].copy(config);
    }
  }

  int getFormulaCount() {
    return formulas.length;
  }

  SuperFormulaGene getFormula(int index) {
    if (index < 0 || index >= formulas.length) {
      throw new IndexOutOfBoundsException("Formula index out of range: " + index);
    }
    return formulas[index];
  }

  Individual deepCopy() {
    // Genome copies intentionally start with fresh, UNRATED evaluation state.
    return new Individual(config, formulas);
  }

  boolean hasInteractiveRating() { return interactiveEvaluation.isRated(); }
  int getInteractiveRating() { return interactiveEvaluation.getRating(); }
  void setInteractiveRating(int rating) { interactiveEvaluation.setRating(rating); }
  void clearInteractiveRating() { interactiveEvaluation.clear(); }
}
