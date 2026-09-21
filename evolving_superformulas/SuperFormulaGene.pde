class SuperFormulaGene {
  final float aGene;
  final float bGene;
  final float mGene;
  final float n1Gene;
  final float n2Gene;
  final float n3Gene;

  SuperFormulaGene(
      Config config,
      float aGene,
      float bGene,
      float mGene,
      float n1Gene,
      float n2Gene,
      float n3Gene) {
    this.aGene = config.clampNormalized(aGene);
    this.bGene = config.clampNormalized(bGene);
    this.mGene = config.clampNormalized(mGene);
    this.n1Gene = config.clampNormalized(n1Gene);
    this.n2Gene = config.clampNormalized(n2Gene);
    this.n3Gene = config.clampNormalized(n3Gene);
  }

  DecodedSuperFormula decode(Config config) {
    return new DecodedSuperFormula(
      config.decodeA(aGene),
      config.decodeB(bGene),
      config.decodeM(mGene),
      config.decodeN1(n1Gene),
      config.decodeN2(n2Gene),
      config.decodeN3(n3Gene)
    );
  }

  SuperFormulaGene copy(Config config) {
    return new SuperFormulaGene(config, aGene, bGene, mGene, n1Gene, n2Gene, n3Gene);
  }
}

class DecodedSuperFormula {
  final float a;
  final float b;
  final int m;
  final float n1;
  final float n2;
  final float n3;

  DecodedSuperFormula(float a, float b, int m, float n1, float n2, float n3) {
    this.a = a;
    this.b = b;
    this.m = m;
    this.n1 = n1;
    this.n2 = n2;
    this.n3 = n3;
  }
}
