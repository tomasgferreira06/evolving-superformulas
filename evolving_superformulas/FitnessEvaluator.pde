class InteractiveEvaluation {
  private boolean rated;
  private int rating;
  InteractiveEvaluation() { clear(); }
  boolean isRated() { return rated; }
  int getRating() {
    if (!rated) throw new IllegalStateException("Interactive rating is UNRATED");
    return rating;
  }
  void setRating(int value) {
    if (value < InteractiveFitness.MIN_RATING || value > InteractiveFitness.MAX_RATING) {
      throw new IllegalArgumentException("Interactive rating must be an integer from 1 to 10");
    }
    rating = value;
    rated = true;
  }
  void clear() {
    rated = false;
    rating = Integer.MIN_VALUE;
  }
}

class InteractiveFitness {
  static final int MIN_RATING = 1;
  static final int MAX_RATING = 10;
  void assignRating(Individual individual, int rating) { requireIndividual(individual); individual.setInteractiveRating(rating); }
  void clearRating(Individual individual) { requireIndividual(individual); individual.clearInteractiveRating(); }
  boolean isRated(Individual individual) { requireIndividual(individual); return individual.hasInteractiveRating(); }
  int getRating(Individual individual) { requireIndividual(individual); return individual.getInteractiveRating(); }
  double getInteractiveWeight(Individual individual) {
    return (double) getRating(individual);
  }
  int ratedCount(Population population) {
    requirePopulation(population);
    int count = 0;
    for (int i = 0; i < population.size(); i++) if (isRated(population.getIndividual(i))) count++;
    return count;
  }
  int unratedCount(Population population) { requirePopulation(population); return population.size() - ratedCount(population); }
  boolean allRated(Population population) { requirePopulation(population); return ratedCount(population) == population.size(); }
  private void requireIndividual(Individual individual) {
    if (individual == null) throw new IllegalArgumentException("Interactive fitness requires an Individual");
  }
  private void requirePopulation(Population population) {
    if (population == null) throw new IllegalArgumentException("Interactive fitness requires a Population");
  }
}
