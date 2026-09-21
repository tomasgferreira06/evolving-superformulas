class Crossover {
  final String PARAMETER_UNIFORM = "PARAMETER_UNIFORM";
  final String WHOLE_FORMULA_UNIFORM = "WHOLE_FORMULA_UNIFORM";

  Individual parameterWiseUniform(
      Individual parentA,
      Individual parentB,
      java.util.Random randomSource) {
    validateParents(parentA, parentB, randomSource);
    SuperFormulaGene[] childFormulas = new SuperFormulaGene[parentA.getFormulaCount()];

    for (int i = 0; i < childFormulas.length; i++) {
      SuperFormulaGene formulaA = parentA.getFormula(i);
      SuperFormulaGene formulaB = parentB.getFormula(i);
      childFormulas[i] = new SuperFormulaGene(
        parentA.config,
        choose(formulaA.aGene, formulaB.aGene, randomSource),
        choose(formulaA.bGene, formulaB.bGene, randomSource),
        choose(formulaA.mGene, formulaB.mGene, randomSource),
        choose(formulaA.n1Gene, formulaB.n1Gene, randomSource),
        choose(formulaA.n2Gene, formulaB.n2Gene, randomSource),
        choose(formulaA.n3Gene, formulaB.n3Gene, randomSource)
      );
    }

    return new Individual(parentA.config, childFormulas);
  }

  Individual wholeFormulaUniform(
      Individual parentA,
      Individual parentB,
      java.util.Random randomSource) {
    validateParents(parentA, parentB, randomSource);
    SuperFormulaGene[] childFormulas = new SuperFormulaGene[parentA.getFormulaCount()];

    for (int i = 0; i < childFormulas.length; i++) {
      SuperFormulaGene source = randomSource.nextBoolean()
        ? parentA.getFormula(i)
        : parentB.getFormula(i);
      childFormulas[i] = source.copy(parentA.config);
    }

    return new Individual(parentA.config, childFormulas);
  }

  private float choose(float valueA, float valueB, java.util.Random randomSource) {
    return randomSource.nextBoolean() ? valueA : valueB;
  }

  private void validateParents(
      Individual parentA,
      Individual parentB,
      java.util.Random randomSource) {
    if (parentA == null || parentB == null) {
      throw new IllegalArgumentException("Crossover requires two non-null parents");
    }
    if (randomSource == null) {
      throw new IllegalArgumentException("Crossover requires a random source");
    }
    if (parentA.config.formulasPerIndividual != parentB.config.formulasPerIndividual
        || parentA.getFormulaCount() != parentB.getFormulaCount()) {
      throw new IllegalArgumentException("Crossover parents must use the same fixed formula count");
    }
    if (parentA.getFormulaCount() != parentA.config.formulasPerIndividual
        || parentB.getFormulaCount() != parentB.config.formulasPerIndividual) {
      throw new IllegalArgumentException("Crossover parent formula counts must match their Config");
    }

    for (int i = 0; i < parentA.getFormulaCount(); i++) {
      validateGene(parentA.getFormula(i), "parentA", i);
      validateGene(parentB.getFormula(i), "parentB", i);
    }
  }

  private void validateGene(SuperFormulaGene gene, String parentName, int formulaIndex) {
    if (gene == null
        || !isNormalized(gene.aGene)
        || !isNormalized(gene.bGene)
        || !isNormalized(gene.mGene)
        || !isNormalized(gene.n1Gene)
        || !isNormalized(gene.n2Gene)
        || !isNormalized(gene.n3Gene)) {
      throw new IllegalArgumentException(
        parentName + " formula " + formulaIndex + " contains invalid normalized genes"
      );
    }
  }

  private boolean isNormalized(float value) {
    return !Float.isNaN(value) && !Float.isInfinite(value) && value >= 0.0 && value <= 1.0;
  }
}
