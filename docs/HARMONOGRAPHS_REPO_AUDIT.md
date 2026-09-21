# Evolving Harmonographs Repository Audit

## 1. Purpose and scope

This audit is based on the source in `tiagofmartins/evolving-harmonographs`, with emphasis on `step_11_interactive_evolution`. The reference repository was inspected read-only. No implementation was added to `evolving-superformulas`; this document is the only intended change there.

Observed behaviour is distinguished from recommendations. File paths below are relative to the reference repository.

## 2. Repository structure

Relevant tree:

```text
README.md
images/                         Tutorial screenshots/GIFs
step_01_parametric_harmonograph/  Basic deterministic parametrised drawing
step_02_random_harmonograph/     Random parameter generation
step_03_individual/              Harmonograph as an individual/genome
step_04_population/              Array-backed population
step_05_recombination/           One-point and uniform crossover
step_06_mutation/                Mutation and copying
step_07_evaluation/              Target-image fitness
step_08_tournament/              Tournament selection
step_09_elite/                  Elitism
step_10_automatic_evolution/    Automatic target-driven evolution
step_11_interactive_evolution/  Manual fitness and interactive evolution
step_12_external_evaluation/    External evaluator variant
```

Each step is a separate Processing sketch. Processing combines the `.pde` files in a sketch directory into one program; there is no conventional build system, package manifest, or application framework. Step 11 contains exactly three relevant source files:

| File | Responsibility |
|---|---|
| `step_11_interactive_evolution.pde` | Global parameters, Processing lifecycle, grid layout, drawing loop, keyboard/mouse interaction |
| `Population.pde` | Population storage, initialization, generation replacement, elitism, tournament selection, sorting |
| `Harmonograph.pde` | 20-gene individual, phenotype generation/cache, crossover, mutation, export |
| `README.md` | Human-facing description and controls; some labels differ from the code |

Step 11 has no `Evaluator.pde`: fitness is assigned by the user. It retains the phenotype/rendering code from the earlier automatic-evolution steps.

## 3. Step 11 overview

The entry sketch is `step_11_interactive_evolution/step_11_interactive_evolution.pde`. At startup it creates a `Population`, computes a grid for all individuals, and renders 30 cached/generated phenotype images. The user hovers an individual, changes its fitness, and presses Enter or Space to invoke `Population.evolve()`.

The actual interactive model is not a 1–10 rating system. Fitness is a `float` initially `0`; mouse click toggles between `0` and `1`; arrow keys adjust by `0.1` or set the endpoints. Thus the implemented range is effectively `[0,1]`.

## 4. Runtime and execution flow

1. Processing calls `settings()`, which sets a P2D canvas to 90% of display width and 80% of display height and enables `smooth(8)`.
2. `setup()` constructs `pop = new Population()`. The constructor allocates `Harmonograph[population_size]` and calls `initialize()`, which creates 30 random individuals and resets `generations` to zero.
3. `setup()` calls `calculateGrid(...)` for the drawable area (`height - 30`) and sets text size from cell size.
4. Every `draw()` clears the background, clears `hovered_indiv`, walks the population, detects whether the mouse lies in each grid cell, draws hover/fitness borders, calls `getPhenotype(resolution)`, displays the image and its numeric fitness, then draws the controls string.
5. `mouseReleased()` toggles the hovered individual's fitness: values below 1 become 1; otherwise they become 0.
6. `keyReleased()` evolves on Enter/Return or Space, resets on `r`, exports the hovered individual on `e`, and otherwise applies arrow-key fitness changes to the hovered individual.
7. `Population.evolve()` sorts by fitness, copies up to one elite, breeds the remainder, mutates non-elites, replaces the array, resets all fitness values to zero, and increments `generations`.

Generation pseudocode:

```text
sort individuals descending by fitness
new[0] = copy(best)                         // elite_size = 1
for remaining slots in pairs:
    if random < crossover_rate:
        p1 = tournamentSelectionV2()
        p2 = tournamentSelectionV2()
        children = uniformCrossover(p1, p2)  // two children
    else:
        children = copies from tournamentSelection()
    place children
mutate every non-elite child
replace old array
set every individual's fitness to 0
generations++
```

Important consequence: the elite genome is copied, but its fitness is also reset to zero. “Elite” means genome preservation only, not preservation of its displayed score.

## 5. Individual and genotype representation

One `Harmonograph` object is one individual and one rendered harmonograph. It is not a collection of harmonographs or layers.

`Harmonograph.genes` is a fixed `float[20]`. Every gene is initialized by `random(0, 1)`. The array stores normalized values; physical drawing parameters are derived in `calculatePoints(w,h)`.

| Gene(s) | Type/range | Derived parameter | Purpose | Evolvable | Source |
|---|---|---|---|---|---|
| `0..3` | float `[0,1)` | `a1..a4 = dimension * (0.15 + 0.1*g)` | x/y amplitudes | Yes | `Harmonograph.calculatePoints` |
| `4..7` | float `[0,1)` | `v = -0.02 + 0.04*g` | small frequency offsets | Yes | same |
| `8..11` | float `[0,1)` | `f = v + 1 + int(5*g)` | integer-banded frequencies plus offset | Yes | same |
| `12..15` | float `[0,1)` | `p = TWO_PI*g` | phases | Yes | same |
| `16..19` | float `[0,1)` | `d = 0.01*g` | damping coefficients | Yes | same |

The point equation is:

```text
x(t) = a1*sin(t*f1+p1)*exp(-d1*t) + a2*sin(t*f2+p2)*exp(-d2*t)
y(t) = a3*sin(t*f3+p3)*exp(-d3*t) + a4*sin(t*f4+p4)*exp(-d4*t)
```

`time_max = 150` and `time_step = 0.025` are fixed, non-evolvable rendering/sampling settings. `points`, `phenotype`, and `fitness` are runtime state, not genes. The constructor taking `float[]` copies into its fixed 20-slot array; it assumes compatible input length and does not validate it.

## 6. Population

`Population.individuals` is a `Harmonograph[]` of length `population_size`, configured globally as 30 in the entry sketch. `generations` is explicitly tracked and starts at zero. Initialization replaces every slot with `new Harmonograph()`.

There is one elite (`elite_size = 1`). The old population is not mutated in place during breeding: `evolve()` builds a new array, then assigns it back slot by slot. No population history is retained. The array is sorted descending by fitness before reproduction using `Arrays.sort` and a Java `Comparator`.

## 7. Fitness and interaction

Fitness is a field on each `Harmonograph`, with default `0`, accessed only through `setFitness()` and `getFitness()`. There is no automatic evaluator in step 11 and no target image.

The UI applies changes only to `hovered_indiv`, which is determined during the current `draw()` pass from the mouse coordinates. Fitness is displayed with two decimals below each image. A positive fitness adds a black border; hover adds another border.

The implementation supports continuous values in `[0,1]` through arrow keys:

```text
UP:    min(fitness + 0.1, 1)
DOWN:  max(fitness - 0.1, 0)
RIGHT: 1
LEFT:  0
click: 0 -> 1, otherwise -> 0
```

Unselected individuals remain at zero. `getPreferredIndivsShuffled()` defines preferred individuals as those with `fitness > 0`, but this list is only used by `tournamentSelectionV2()` for crossover parents. The non-crossover branch uses the whole population through `tournamentSelection()`.

The README says “click,” arrow controls, Space, `i`, and export. The code instead resets on `r`, evolves on Enter as well as Space, and has no `i` branch. The on-screen controls string says Enter and `r`. The source code is authoritative for runtime behaviour.

## 8. Selection

Selection is tournament selection, not roulette wheel selection.

`Population.tournamentSelection()` samples `tournament_size` individuals uniformly with replacement from the full population (`tournament_size = 2`) and returns the one with greatest fitness. Ties retain the first sampled individual.

`tournamentSelectionV2()` is used only when crossover occurs. If more than one positive-fitness individual exists, it shuffles a list of positive-fitness individuals and samples the tournament from that list. If exactly one exists it returns that individual directly. If none exists it falls back to the full population. It still chooses the highest fitness within a tournament.

There is no roulette wheel, rank selection, explicit random selection, or fitness-proportional probability. With all fitnesses zero, the fallback tournament still returns a random tournament winner, but all candidates tie and the first sampled candidate wins. With exactly one preferred individual, both crossover parents can be the same object.

## 9. Crossover

Step 11 uses `Harmonograph.uniformCrossover(Harmonograph partner)`. It copies both parents, then for each of the 20 positions independently swaps the corresponding gene between the two child copies with probability `0.5`. It returns two children. The population applies this operator to parent pairs with probability `crossover_rate = 0.5`; otherwise it creates two independent copies selected by ordinary tournament selection.

Pseudocode:

```text
child1 = copy(parent1)
child2 = copy(parent2)
for gene i in 0..19:
    if random() < 0.5:
        swap(child1[i], child2[i])
return child1, child2
```

The per-gene operator is generic infrastructure, but its fixed loop and copy type are tied to `Harmonograph` and its fixed 20-gene representation. `onePointCrossover()` exists in earlier steps but is not called by step 11.

## 10. Mutation

`Harmonograph.mutate()` visits every gene. Independently, with probability `mutation_rate = 0.4`, it adds a uniform random perturbation in `[-0.1, 0.1)` and clamps the result to `[0,1]` using `constrain`. This is additive bounded mutation, not random reset.

```text
for every gene:
    if random() <= 0.4:
        gene = clamp(gene + uniform(-0.1, 0.1), 0, 1)
invalidate cached phenotype
```

All genes share the same mutation probability and step size despite representing different physical quantities. The normalized gene domain and the `0.1` perturbation are harmonograph encoding assumptions. The phenotype cache is invalidated after randomization and mutation; crossover copies start with a null cache.

## 11. Rendering

`getPhenotype(resolution)` creates a `PGraphics` off-screen canvas, draws a white background, disables fill, sets black stroke and stroke weight `height * 0.002`, calls `render(...)`, copies the result to `phenotype`, and returns it. A cached image is reused when its height matches the requested resolution.

`render()` calls `calculatePoints(w,h)`, translates to the canvas centre, opens a `beginShape()`, emits every generated `PVector` with `vertex`, and closes the shape. The points are generated for `t` from `0` up to `150` with step `0.025` (approximately 6,000 points). The canvas itself is white; drawings are black, unfilled, and opaque. There is no animation: the time variable is a curve parameter, not frame time. Each thumbnail is drawn with `image(...)` into the main canvas. No persistent trails are used.

`export()` is coupled to the harmonograph: it writes a 2,000-pixel PNG, a 500×500 PDF using `processing.pdf.*`, and one text line per gene. It is triggered for the currently hovered individual.

## 12. UI and events

The UI is a dynamically calculated grid of square cells from `calculateGrid(...)`, with margins/gutters and optional top alignment. The grid is computed once in `setup()`, so it is not recomputed on window resize.

State coupling is direct: the sketch owns `pop`, `cells`, and `hovered_indiv`; `Population` owns evolutionary operations; `Harmonograph` owns both genome and rendering/export. There is no separate view, controller, fitness model, or event abstraction. Keyboard actions depend on hover state established in the prior draw frame.

There is no visible generation counter, no dedicated evolve/reset button, no selection panel, and no selected-state object beyond the fitness border and hover variable.

## 13. Data flow

```text
Harmonograph.genes[20]
    -> calculatePoints(w,h)
    -> ArrayList<PVector> points
    -> render(PGraphics,...)
    -> cached PImage phenotype
    -> draw() thumbnail
    -> mouse/keyboard changes Harmonograph.fitness
    -> Population.sort/tournamentSelection[V2]
    -> copy + uniformCrossover
    -> mutate()
    -> new Harmonograph[]
    -> fitness reset to 0
    -> next draw() generation
```

For step 11, fitness is not calculated from the phenotype. It is a user-controlled reproductive signal.

## 14. Dependencies and Processing assumptions

The project is standard Processing source, not a Java/Maven/Gradle project. Step 11 imports only `processing.pdf.*` and otherwise relies on Processing core APIs: `PVector`, `PImage`, `PGraphics`, `random`, `constrain`, `createGraphics`, `image`, lifecycle callbacks, and constants such as `P2D`, `TWO_PI`, `ENTER`, and arrow key codes. It also uses `java.util.*` for sorting and shuffling.

The PDF export requires the Processing PDF library bundled with Processing. No third-party runtime dependency is evident. The code assumes a Processing version supporting `settings()`, P2D, `PGraphics.copy()`, and the PDF renderer. Exact Processing version is not pinned in the repository; this is an uncertainty to verify locally.

## 15. Evolution across tutorial steps

The sequence is cumulative conceptually, but each directory is a copy/variant rather than a shared library.

| Step | Main addition | Most useful lesson |
|---|---|---|
| 1–2 | Parametric and random harmonographs | Phenotype equation and normalized random parameters |
| 3 | `Harmonograph` class and 20-gene encoding | Individual/genotype boundary |
| 4 | `Population` array and initialization | Population storage |
| 5 | One-point/uniform recombination | Parent-to-child gene exchange |
| 6 | Mutation and copying | Variation and cache-independent copies |
| 7 | `Evaluator` and target RMSE similarity | Automatic fitness architecture |
| 8 | Tournament selection | Selection mechanics |
| 9 | Elitism | Sorted best-copy preservation |
| 10 | Full automatic loop | Selection, crossover, mutation, evaluation, sorting |
| 11 | Manual fitness and preferred-parent logic | Interactive genetic algorithm variant |
| 12 | External image evaluation | Alternative evaluation boundary |

Step 11 reuses the step-10-style `Population.evolve()` and `Harmonograph`, but replaces `Evaluator` calls with UI assignment and adds `getPreferredIndivsShuffled()` / `tournamentSelectionV2()` for preferred individuals. It also changes several global rates and the population size. Because files are duplicated between steps, fixes in one step do not propagate automatically.

## 16. Architectural and code-quality observations

- Global mutable configuration in the entry sketch is read directly by `Population` and `Harmonograph`.
- `Harmonograph` combines genotype, fitness state, curve generation, raster caching, PDF/PNG export, and file serialization.
- Evolutionary operators are methods on the concrete phenotype class, so they are not representation-independent.
- The normalized gene array hides semantic parameter types; frequency uses integer quantization while all genes are floats.
- Constructor input length is not validated; `getCopy()` aliases no array because the constructor copies values, but it copies the current fitness too.
- The cache depends only on requested image height, not width or all rendering settings.
- `calculatePoints()` mutates the individual's `points` list during rendering, which makes rendering stateful.
- Population size, elite size, tournament size, rates, and resolution are magic/global values rather than constructor configuration.
- `evolve()` resets elite fitness as well as offspring fitness, which is appropriate for a new interactive evaluation cycle but easy to misread as losing elite quality.
- `tournamentSelectionV2()` shuffles a list even though only random indexing is needed; it can select duplicates.
- UI text and README controls disagree with the implementation (`i` versus `r`, and README wording around evolution).
- There is no validation for odd population sizes, invalid tournament sizes, or impossible grid dimensions.

These observations are recommendations for the future architecture, not changes made to the reference repository.

## 17. Reuse / adapt / replace matrix

| Component | Existing implementation | Action | Reason |
|---|---|---|---|
| Population container/replacement | `Harmonograph[]`, `initialize`, `evolve` | ADAPT | Lifecycle is reusable, type and policy should be generalized |
| Generation counter | `Population.generations` | REUSE | Independent of harmonograph phenotype |
| Individual representation | fixed `float[20]` in `Harmonograph` | REPLACE | Must represent N Superformulas × 6 parameters |
| Normalized gene encoding | `[0,1]` values mapped in `calculatePoints` | ADAPT | Useful, but Superformula ranges and typed parameters differ |
| Rendering | `calculatePoints`, `render`, `getPhenotype` | REPLACE | Must implement Superformula geometry and composition |
| PGraphics/image cache | `getPhenotype` cache | ADAPT | Useful off-screen rendering pattern; key/cache policy should improve |
| Interactive fitness UI | hover, click, arrows, `setFitness` | ADAPT | Required 1–10 scale and clearer selection feedback |
| Fitness storage | `float fitness` | ADAPT | Could become numeric 1–10, with an explicit unassigned state if needed |
| Tournament selection | `tournamentSelection`, `tournamentSelectionV2` | ADAPT/optional | Existing mechanism works, but assignment asks roulette wheel |
| Roulette wheel selection | Absent | NEW | Must implement fitness-proportional parent selection and zero-sum fallback |
| Uniform crossover | fixed 20-gene swap | ADAPT | Gene-wise crossover can work across flattened formula genes, but structural operators may be preferable |
| Superformula-aware crossover | Absent | NEW | Decide whether exchange whole formulas, parameters, or both |
| Mutation | uniform additive perturbation and `[0,1]` clamp | ADAPT | Parameter-specific mutation/ranges are required |
| Automatic target fitness | `Evaluator` exists only in steps 7–10 | NEW/ADAPT | Reuse RMSE concept, adapt to Superformula phenotype and target workflow |
| Export | PNG/PDF/genes in `Harmonograph.export` | ADAPT | Useful feature, but serialize Superformula arrays |
| Grid layout | `calculateGrid` | REUSE/ADAPT | General UI utility; recompute on resize |

## 18. Mapping to evolving Superformulas

The clean conceptual mapping is:

```text
Individual
  formulas[N]
    formula[i].a
    formula[i].b
    formula[i].m
    formula[i].n1
    formula[i].n2
    formula[i].n3
```

The current `Harmonograph` class should be split conceptually into a Superformula gene/data type, an Individual containing a fixed-length array/list of N formula genes, and a renderer that composites the N curves into one phenotype image. The current `Population` lifecycle maps well to an array of these Individuals, but its breeding code should operate on the new representation. `getPhenotype()` becomes an Individual-level composition renderer; a formula renderer evaluates the polar Superformula and converts radius/angle samples to canvas coordinates.

The current 20 flat genes are analogous to `N * 6` formula parameters only at the storage level. They should not be copied as a semantic mapping: current genes encode four amplitudes, four frequency offsets, four quantized frequencies, four phases, and four damping values, whereas the Superformula parameters have different mathematical meanings and likely different domains.

## 19. Missing assignment requirements

The reference step 11 does not provide:

- interactive integer fitness from 1 to 10;
- roulette wheel selection;
- Superformula implementation;
- fixed N-formula composite individuals;
- Superformula-specific crossover operators;
- Superformula-specific mutation operators;
- automatic target-driven evolution in the interactive sketch;
- a separation between interactive fitness and automatic target fitness;
- explicit controls for choosing/configuring N;
- tests or reproducible random seeds.

Steps 7–10 demonstrate automatic target-image evaluation, but that evaluator is not part of step 11 and uses a harmonograph phenotype.

## 20. Risks for future adaptation

1. Flattening all formula parameters into one array can make crossover split a formula in the middle and create invalid combinations; structural crossover should be an explicit design choice.
2. A single global mutation rate and perturbation size are unsuitable for parameters with different scales and constraints.
3. The existing `[0,1]` encoding can be retained as an internal normalized representation, but every Superformula parameter needs a documented decode range and validity policy.
4. Interactive fitness must distinguish “not rated” from a legitimate minimum score if the assignment uses 1–10.
5. Roulette wheel selection needs a zero-total-fitness policy and careful handling of integer ratings.
6. Rendering and genotype are tightly coupled in the reference, so copying `Harmonograph` wholesale would carry harmonograph assumptions into the new system.
7. Superformula singularities, negative/near-zero exponents, large radii, and sampling resolution can produce numerical or visual failures; the reference has no analogous validation layer.
8. The current cache key is incomplete for richer rendering settings and multiple formula layers.
9. The reference UI assumes fixed grid geometry and hover-driven actions; a more explicit interaction state will reduce accidental ratings.
10. The reference has no tests, version pin, or documented reproducibility strategy, so visual regressions need to be introduced deliberately in the future project.

## 21. Recommended implementation order

1. **Define the Superformula contract.** Document parameter domains, numerical safeguards, angular sampling, coordinate normalization, and rendering conventions.
2. **Implement and validate one Superformula renderer.** Test known parameter sets and bounds independently of evolution.
3. **Create a formula gene type and an Individual with fixed N.** Keep fitness and genome state separate from rendering where practical.
4. **Implement Individual composition rendering and caching.** Render all N formulas into one off-screen image with explicit layering/style rules.
5. **Integrate population initialization and generation replacement.** Preserve the useful lifecycle from `Population`, but remove direct `Harmonograph` dependencies.
6. **Implement parameter-aware mutation.** Add per-parameter bounds, perturbation scales, and invalid-value handling.
7. **Implement and compare crossover operators.** Start with safe whole-formula and per-parameter variants; add assignment-specific operators after invariants are clear.
8. **Implement interactive 1–10 fitness.** Decide whether zero means unrated or use a separate rated flag; provide visible feedback and generation controls.
9. **Implement roulette wheel selection.** Define normalization and zero-total fallback, then test statistical behaviour.
10. **Add interactive evolution loop.** Add elitism policy, offspring rating reset, generation counter, and reproducible logging.
11. **Add automatic target-driven evaluation as a separate strategy.** Adapt the step-10 RMSE idea to the composite Superformula image rather than coupling it to the interactive evaluator.
12. **Add tests and visual regression fixtures.** Cover parameter decoding, mutation bounds, crossover validity, roulette edge cases, rendering dimensions, and target scoring.

## 22. Source-grounded summary

The step 11 entry point is `step_11_interactive_evolution/step_11_interactive_evolution.pde`; `setup()` creates a 30-member `Population`, and `draw()` renders its grid. An individual is one `Harmonograph` with a fixed `float[20]` normalized genome. Fitness is manually assigned in `[0,1]` through hover-based mouse/keyboard interaction. Parent selection is tournament selection, with a preferred-positive subset used only for crossover. Crossover is two-child uniform per-gene recombination at a 0.5 generation-level crossover probability. Mutation independently perturbs each gene at rate 0.4 by up to ±0.1 and clamps to `[0,1]`. Reusable foundations are population replacement, generation tracking, copying, off-screen image caching, grid layout, and the general evolutionary lifecycle. Harmonograph encoding, curve equation, rendering, export, and fixed-gene operators must be replaced or substantially adapted. The assignment-specific missing pieces are 1–10 ratings, roulette wheel selection, Superformula/N-formula representation and rendering, new operators, and target-driven evaluation.
