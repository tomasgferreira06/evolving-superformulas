# Superformula Mapping Plan

## 1. Purpose

This document is the implementation blueprint for mapping the evolutionary ideas in `evolving-harmonographs` into `evolving-superformulas`. Its primary source is `docs/HARMONOGRAPHS_REPO_AUDIT.md`; the reference source was checked only where the audit identified details of the step 10 evaluator. No source code is specified here.

The document uses three labels throughout:

- **Requirement** — explicitly required by the assignment.
- **Inherited behaviour** — demonstrated by the reference repository but not necessarily required.
- **Recommendation** — a proposed decision for this project, subject to the open questions in section 22.

The central mapping is to preserve the understandable evolutionary lifecycle while replacing the harmonograph genome and curve generator. Unlike the reference `Harmonograph` class, genotype, rendering, variation, and evaluation should not be owned by one object.

## 2. Target Architecture

### 2.1 Architectural shape

```text
                         App / Interactive UI
                       (mode and user controls)
                                  |
                                  v
       +-------------------- Population --------------------+
       | individuals, generation; generation replacement    |
       +-----------+--------------------+--------------------+
                   |                    |
                   v                    v
             EvolutionPolicy       FitnessEvaluator
          Selection / Crossover    /              \
               / Mutation      Interactive       TargetImage
                   |             ratings          similarity
                   v                    ^              ^
               Individual              |              |
          formulas[N] + fitness         +------ IndividualRenderer
                   |                                  |
                   v                                  v
          SuperFormulaGene  -------> SuperFormulaRenderer

 Config supplies run-wide N, domains, rates, render settings, and seed.
```

Dependencies point inward toward semantic data. Renderers read genes but do not mutate them. Operators create new individuals but do not draw them. Evaluators obtain phenotypes through `IndividualRenderer`; the population engine does not need to know whether scores came from a person or an image.

### 2.2 Components and contracts

| Component | Responsibility | Owned data | Conceptual operations | Dependencies | Origin |
|---|---|---|---|---|---|
| `Config` | Hold validated run and experiment settings | population size, fixed `N`, domains, rates, render/evaluation settings, elite size, optional seed | validate; expose settings; describe run | none | NEW; replaces globals/magic numbers |
| `ParameterDomain` (or simple config records) | Define decode, bounds, type, repair, and mutation scale per parameter | lower/upper bounds, integer flag, epsilon policy | decode; clamp/repair; sample | `Config` | NEW |
| `SuperFormulaGene` | Represent one formula's six heritable parameters | `a`, `b`, `m`, `n1`, `n2`, `n3` in normalized form | deep copy; decode; validate invariant | parameter domains | SPLIT/REPLACE from `Harmonograph.genes` |
| `Individual` | Represent one candidate made of exactly `N` formulas | fixed-length gene array; evaluation state; phenotype cache or cache version if kept here | deep copy genome; get formula; set/clear evaluation; invalidate cache | `SuperFormulaGene`, run `N` | SPLIT from `Harmonograph` |
| `SuperFormulaRenderer` | Turn one decoded formula into a safe sequence of Cartesian points and/or draw it | no evolutionary state | sample theta; calculate safe radius; transform; draw | render config, gene decoding | REPLACE `calculatePoints()` and formula portion of `render()` |
| `IndividualRenderer` | Compose `N` formula layers into one off-screen phenotype | cache keyed by genome version and complete render specification | render phenotype; compose layers; return cached image | formula renderer, Processing `PGraphics` | ADAPT `getPhenotype()` and composition portion of `render()` |
| `Population` | Own current generation and perform lifecycle orchestration | individuals; generation count | initialize; replace generation; get members; preserve elites; clear/evaluate scores | config, operators, evaluator | ADAPT reference `Population` |
| `Selection` | Select parents from an eligible evaluated population | no candidate state | roulette select; apply fallback policy | random source, fitness values | REPLACE tournament selection |
| `Crossover` | Produce child genomes from parent genomes | operator configuration only | whole-formula; formula-boundary; per-parameter; blend | genes, domains, random source | ADAPT/NEW from uniform crossover |
| `Mutation` | Apply bounded, parameter-aware variation to child genomes | per-parameter probabilities/scales | perturb; reset; replace formula; repair | domains, random source | ADAPT/NEW from generic additive mutation |
| `FitnessEvaluator` | Common strategy contract for obtaining a comparable, maximized score | evaluator-specific state | evaluate one/all; report mode | renderer as needed | NEW abstraction informed by steps 7–11 |
| `InteractiveFitness` | Store/validate user ratings and expose them as selection weights | rating policy; no UI geometry | rate 1–10; clear; test generation readiness | `Individual` evaluation state | ADAPT step 11 interaction |
| `TargetImageFitness` | Score rendered candidates against a preprocessed target | target image/brightness array; evaluation resolution; normalization | load/preprocess target; evaluate; compare | `IndividualRenderer` | ADAPT step 7–10 `Evaluator` |
| `InteractiveUI` / main sketch | Draw grid and status, manage hover/selection, collect ratings, trigger evolution | cells, hovered/selected index, display state, mode | setup/draw; rate; evolve; reset; switch or initialize mode | population, renderer, evaluators | ADAPT step 11 sketch |
| `ExperimentLogger` | Record reproducible settings and generation results | output policy, current run metadata | log config/seed/operator; record best/mean; export summary | population, config | NEW, added late |

This is a responsibility split, not a mandate for interfaces and one-class-per-policy everywhere. Processing-friendly classes with small methods are sufficient.

## 3. Original-to-New Mapping

| Original component | Original responsibility | New component | Action | Mapping notes |
|---|---|---|---|---|
| Step 11 main sketch | Lifecycle, globals, grid, drawing, input | main sketch + `Config` + `InteractiveUI` | SPLIT/ADAPT | Keep Processing callbacks thin; move run settings out of globals where practical. |
| `Harmonograph` | Genome, curve generation, phenotype cache, fitness, crossover, mutation, export | `SuperFormulaGene[]` in `Individual`; renderers; operators; optional export helper | SPLIT/REPLACE | Do not carry its tight coupling forward. |
| `float[20] genes` | Normalized harmonograph genotype | `SuperFormulaGene formulas[N]`, six normalized values each | REPLACE | Similar normalized storage idea, different semantics and size. |
| gene constructor | Copy 20 values | validated gene/individual constructors | ADAPT | Require exact six fields per gene and exactly configured `N` formulas. |
| `randomize()` | Uniform `[0,1]` initialization | gene factory/domain sampling | ADAPT | Sample normalized genes, then decode through documented domains. |
| `getCopy()` | Copy genes and fitness, clear render cache indirectly | explicit deep-copy operations | ADAPT | Offspring copies must not alias genes or cache; copying evaluation is an explicit option. |
| `calculatePoints()` | Decode genes and calculate harmonograph points | `SuperFormulaRenderer.samplePoints()` | REPLACE | Evaluate the Superformula over theta and convert polar to Cartesian. |
| `render()` | Calculate and draw one harmonograph | formula renderer + individual composer | SPLIT/REPLACE | Formula geometry and multi-layer composition are separate. |
| `getPhenotype()` | Off-screen rendering and height-only cache | `IndividualRenderer.render()` and complete cache key | ADAPT | Cache must include width, height, genome revision, sampling, and style/composition settings. |
| `points` field | Mutable rendering scratch state | local point sequence or direct vertex emission | REMOVE/ADAPT | Prefer renderer-local transient data; it is not individual state. |
| `fitness` field | Runtime `[0,1]` score | explicit `EvaluationState` on `Individual` | ADAPT | Distinguish unrated from a valid 1; automatic scores may be floats. |
| `setFitness/getFitness` | Fitness access | validated evaluation methods | ADAPT | Do not allow arbitrary invalid interactive values. |
| `onePointCrossover()` in earlier steps | Flat-array recombination | boundary-preserving formula crossover | ADAPT | A formula boundary is the meaningful cut unit. |
| `uniformCrossover()` | Swap each of 20 positions independently | per-parameter uniform crossover | ADAPT | Useful baseline candidate, but semantic fields replace anonymous indices. |
| `mutate()` | Same rate and additive delta for every normalized gene | parameter-aware mutation policy | ADAPT | Retain bounded mutation concept; use field-specific policies. |
| `export()` | PNG/PDF/gene text from individual | optional export/serialization helper | SPLIT/ADAPT | Not needed for core assignment; add only after evolution works. |
| `Population.individuals` | Fixed array of harmonographs | fixed array/list of `Individual` | ADAPT | Preserve stable population size. |
| `Population.initialize()` | Randomize, and in automatic steps evaluate/sort | mode-neutral initialization plus evaluator call | SPLIT/ADAPT | Interactive starts unrated; automatic evaluates immediately. |
| `Population.evolve()` | Elite copy, parent selection, crossover, mutation, replacement | generation engine using injected policies | ADAPT | Same high-level lifecycle; replace selection and operators. |
| `Population.generations` | Count replacements | generation counter | REUSE | Starts at zero; increment once per successful replacement. |
| sorting by fitness | Place fittest first, support elite | ranked view or sort before elite extraction | ADAPT | Roulette itself does not require sorting; avoid making sorted order an implicit invariant. |
| `elite_size = 1` | Preserve best genome | configurable optional elitism | ADAPT | Inherited, not an assignment requirement. |
| `tournamentSelection()` | Fitness-biased parent choice | roulette selection | REPLACE | Roulette wheel is an explicit requirement. |
| `tournamentSelectionV2()` | Prefer positive-rated subset | eligibility/rating-completeness policy | REMOVE/REPLACE | No separate preferred-parent algorithm is needed when all members are rated 1–10. |
| step 11 click/arrows | Toggle or adjust `[0,1]` fitness | direct integer 1–10 rating controls | ADAPT | Preserve hover/keyboard convenience but display explicit rating state. |
| `calculateGrid()` | Dynamic thumbnail layout | grid layout helper | REUSE/ADAPT | Recalculate if canvas dimensions change; validate cell geometry. |
| hover state | Choose active thumbnail | hovered/selected index in UI | ADAPT | A selected state may make numeric rating less error-prone. |
| Enter/Space evolve | Trigger next generation | evolve action after readiness validation | REUSE/ADAPT | Reject or clearly resolve incomplete ratings. |
| `r` reset | Reinitialize population | reset action | REUSE | Reset generation count and evaluation states. |
| step 7–10 `Evaluator` | Target loading, brightness extraction, normalized RMSE similarity | `TargetImageFitness` | ADAPT | Render composite at common resolution; preserve maximize convention. |
| evaluator blue-channel brightness | Fast grayscale proxy | documented luminance/brightness extraction | ADAPT | Blue channel is inherited implementation detail, not a requirement; choose and keep preprocessing identical for both images. |
| step 10 automatic loop | Evaluate, sort, evolve repeatedly | automatic controller using shared population engine | ADAPT | Automatic mode evaluates every new candidate without user input. |
| no tests/version pin | None | lightweight validation sketches/checks and recorded environment | NEW | Add deterministic seeds and numerical/operator checks. |
| PDF dependency | Export | optional later export | REMOVE from core | Avoid adding a dependency before it is needed. |

## 4. Genotype Representation

### 4.1 Conceptual model

```text
Individual
  formulas: SuperFormulaGene[N]
  evaluation: UNRATED | SCORE(value, source)
  genomeRevision

SuperFormulaGene
  aGene
  bGene
  mGene
  n1Gene
  n2Gene
  n3Gene
```

**Requirement:** every individual visualizes a fixed number of Superformulas. The assignment does not prescribe `N`.

**Recommendation:** make `N` a run-wide `Config` value. Every individual in one population must have exactly that number. Do not store an independently mutable `N` in each individual; the array length records it and constructors validate it. This makes crossover compatibility and phenotype composition unambiguous. A different `N` means a different run/experiment.

### 4.2 Initialization

For each initial individual, create exactly `N` independently sampled genes. With normalized storage, sample each normalized field from its allowed initialization interval and decode only for rendering. Initialization distributions may later be narrowed or biased, but the first version should be uniform and reproducible under an optional random seed.

Initialization must validate the decoded parameter invariants. It should not silently accept invalid array lengths or non-finite fields.

### 4.3 Copy and runtime state

- A deep genome copy creates a new individual, a new formula array, and new gene objects/values. No child may share mutable formula objects with a parent or sibling.
- Render caches and transient point data are never shared.
- Crossover and mutation operate on child copies, never on selected parents.
- `genomeRevision` (or simple explicit cache invalidation) changes after any gene mutation.
- Fitness is phenotype/evaluation state, not genotype. It must never participate in crossover or mutation.
- `UNRATED` should be an explicit state, not encoded as rating `0`, because interactive score 1 is valid and the assignment's range is 1–10.
- A convenience selection weight may map `UNRATED` to zero only inside a documented incomplete-rating policy; it must not erase the distinction in UI/state.
- Deep copy should specify whether evaluation is copied. Elite preservation may copy the previous score for ranking/audit, but a new interactive generation must be reset to `UNRATED` before display. Offspring always start unrated. In automatic mode, scores are recomputed after rendering.

## 5. Parameter Policy

### 5.1 Direct values versus normalized genes

| Strategy | Benefits | Costs/risks in this project |
|---|---|---|
| A. Store decoded real values | Easy to inspect; equation reads directly; natural Gaussian deltas in physical units | Each parameter needs different mutation scales and repair logic everywhere; blending/integer `m` need special handling; domain experiments change stored meaning less cleanly |
| B. Store normalized `[0,1]` genes and decode | Inherits a useful idea from the reference; uniform initialization, clamping, generic crossover, and mutation magnitudes are comparable; ranges are centralized | Requires explicit domain metadata; linear decoding may be poor for highly nonlinear exponents; `m` needs discrete decoding; normalized equality is not equal visual sensitivity |

**Recommendation:** use normalized `[0,1]` storage with semantic named fields, not a flat anonymous array. Decode through centralized per-parameter policies. This retains the reference's convenient bounded genotype while fixing its lack of semantic types and parameter-specific mutation. If experiments show that `n` parameters need logarithmic spacing, the decoder can change without changing operators or stored gene bounds.

The normalized strategy does not mean every parameter receives identical mutation. Probabilities and normalized step sizes remain field-specific.

### 5.2 Equation contract

The renderer should use the standard assignment-provided structure conceptually:

```text
r(theta) = [ |cos(m*theta/4)/a|^n2
           + |sin(m*theta/4)/b|^n3 ]^(-1/n1)
x = r * cos(theta)
y = r * sin(theta)
```

The precise equation spelling should be confirmed against the course's provided Superformula example before implementation. This plan does not turn a remembered convention into an assignment requirement.

### 5.3 Domain decision table

No destination source or assignment material inspected for this plan defines final numeric ranges. All ranges therefore remain experiment decisions.

| Parameter | Representation and decisions required | Zero policy / safeguard | Mutation policy | Rendering risk |
|---|---|---|---|---|
| `a` | decoded positive float; decide lower/upper bounds and whether linear or log decode | zero must not be allowed because it is a divisor; decoded magnitude at least `epsilonA` | small Gaussian perturbation in normalized space; rare reset | zero/near-zero can create division overflow; extremes alter scale |
| `b` | decoded positive float; same decisions as `a` | zero must not be allowed; at least `epsilonB` | same category as `a`, independently configurable | same as `a`; unequal `a/b` stretches axes |
| `m` | decide integer versus float. **Recommendation:** integer for v1 if course example treats it as symmetry count; float may be a later experiment | zero can be mathematically evaluable but may collapse variation; whether allowed is an explicit experiment decision | discrete step (`±1`) or random reset, with lower/upper clamp; stronger/rarer mutations can cause useful topology jumps | large values need finer theta sampling and can alias; rounding policy must be deterministic |
| `n1` | decoded float; decide whether only positive values are allowed and whether log decoding is useful | never allow zero or near zero because `-1/n1` is singular; enforce `abs(n1) >= epsilonN1`; **recommend positive-only v1** | smaller Gaussian step than topology-changing `m`; rare reset | near zero causes enormous exponents, overflow, NaN, or huge radii |
| `n2` | decoded float; decide sign policy and range from course example/experiments | zero may be mathematically permitted but changes shape strongly; decide explicitly; avoid invalid `pow` inputs by retaining absolute bases | parameter-specific Gaussian step and rare reset | large magnitude may overflow/underflow; negative values magnify near-zero bases |
| `n3` | same decision class as `n2` | same as `n2` | same category as `n2`, independently sampled | same as `n2` |

Candidate starting policy, explicitly a **recommendation rather than a requirement**:

- keep `a` and `b` positive and bounded away from zero; consider fixing both initially if varying them only duplicates renderer scaling;
- use integer `m` over a modest experimentally chosen symmetry interval;
- use positive `n1`, `n2`, and `n3` for the first valid renderer;
- determine actual bounds by rendering a small parameter sweep from the course example, then record the chosen values in `Config` and the report;
- only introduce negative exponent domains after the safe renderer and tests can demonstrate their value.

Upper bounds must jointly respect theta sampling. Increasing `m` without increasing sample density produces undersampling; extreme exponent bounds may create effectively discontinuous or clipped curves. The domain table and renderer settings must therefore be validated together.

## 6. Rendering

### 6.1 Mapping and data flow

```text
SuperFormulaGene (normalized)
       |
       v
decode a,b,m,n1,n2,n3
       |
       v
sample theta over configured angular interval
       |
       v
calculate guarded radius r(theta)
       |
       v
polar -> Cartesian (x,y)
       |
       v
normalize/scale to formula drawing box
       |
       v
draw one formula layer
       |
       v
compose exactly N layers in PGraphics
       |
       v
Individual phenotype PImage (cacheable)
```

This replaces the reference mapping as follows:

- `Harmonograph.calculatePoints()` becomes a stateless formula sampling operation.
- `Harmonograph.render()` splits into formula-level drawing and individual-level composition.
- `Harmonograph.getPhenotype()` becomes individual off-screen rendering with a complete cache policy.

### 6.2 Formula-level renderer

The formula renderer decodes one gene, samples theta, calculates only finite points, applies a documented scale/transform, and emits a closed curve or connected vertices. It owns no fitness and does not change the gene. Sampling interval, step/count, coordinate normalization, and invalid-point policy come from render config.

Prefer sampling a fixed point count over relying on floating-point `theta += step` termination. If `thetaStep` remains the exposed setting, derive and document the sample count. The angular interval (normally one full turn for the standard equation, subject to the provided course example) must be explicit.

### 6.3 Individual renderer and off-screen graphics

The individual renderer creates a `PGraphics` at the requested width and height, draws a deterministic background, translates to the canvas centre, applies the common scale, and asks the formula renderer to draw each of the `N` genes in fixed order. It returns a `PImage` suitable for thumbnails and evaluation.

Target evaluation and UI must use the same geometry and base composition rules. Display thumbnails may be scaled after rendering, but target candidates must be rendered at the evaluator's common resolution rather than compared after arbitrary UI scaling.

### 6.4 Cache policy

Caching is an optimization, not genotype state. A cached phenotype is valid only for a key containing at least:

- genome revision or stable hash;
- width and height;
- theta sampling settings;
- scale/normalization policy;
- composition/style settings that affect pixels.

Mutation, crossover construction, random reset, or config changes invalidate the relevant cache. A simple v1 alternative is one cached thumbnail and one evaluation image per immutable genome revision. Correctness is more important than a sophisticated cache.

### 6.5 Numerical safeguards

For every theta sample:

1. Reject or repair decoded non-finite parameters before evaluation.
2. Clamp divisor magnitudes for `a` and `b` to their positive epsilon floors.
3. Enforce the configured `n1` exclusion zone around zero.
4. Compute absolute trigonometric bases before non-integer powers.
5. Guard negative-exponent cases against a zero base if those domains are ever enabled.
6. Check each intermediate term, sum, exponent, radius, and coordinate with `isFinite` logic.
7. Bound `abs(r)` to a configured maximum before the canvas transform. Do not let one singular sample dominate the scale.
8. For an invalid isolated sample, break/skip that vertex rather than connect across infinity. If invalid samples exceed a threshold, mark the phenotype invalid and render a deterministic fallback/penalty image.
9. Clip drawing to the off-screen canvas. Coordinates outside the canvas must not cause array access or allocation failures.
10. Give invalid phenotypes the evaluator's worst score in automatic mode and expose a visible diagnostic during development.

Two scaling policies are possible: fixed run-wide scale (pixel differences retain size information) or per-formula/per-individual fit-to-bounds (shapes remain visible but size differences disappear). **Recommendation:** use one run-wide fixed transform after choosing safe parameter domains; do not auto-fit each target-evaluation candidate independently unless the intended target metric should ignore scale.

## 7. Multi-Superformula Composition

### 7.1 Required versus optional genes

**Equation parameters required per formula:** `a`, `b`, `m`, `n1`, `n2`, `n3`.

**Optional visual/evolvable parameters:** rotation, translation, layer scale, stroke weight, stroke colour/alpha, fill, blend mode, drawing order. None is stated as an assignment requirement. Adding them expands the search space and complicates crossover, mutation, and target comparison.

### 7.2 Candidate composition strategies

| Strategy | Description | Benefit | Cost |
|---|---|---|---|
| Centered overlay | Draw every formula at one centre and common scale | Minimal genotype; clear mapping to assignment; stable target comparison | Layers may overlap heavily |
| Styled layering | Common centre with deterministic per-index stroke/alpha | Makes layers distinguishable without adding genes | Colour can dominate pixel fitness; ordering matters |
| Independent transform | Evolve rotation/scale/offset per formula | Rich images and spatial arrangements | Much larger search space; not required for v1 |
| Compound contour | Combine or connect formula outputs | Highly structural visuals | Changes the phenotype interpretation and needs a new composition specification |

**Recommendation for v1:** draw exactly `N` closed, unfilled formula outlines, all centred, with one common scale and deterministic drawing order. Use a white background and one consistent dark stroke. If layers need differentiation for interactive viewing, use a fixed per-index style palette only after confirming that automatic target evaluation uses the same palette. Do not evolve rotation, scale, offsets, colour, alpha, or style in v1.

This minimal design makes the only heritable values the six required equation parameters and keeps the academic comparison of operators interpretable.

## 8. Population

### 8.1 Lifecycle mapping

The useful reference lifecycle remains:

1. Allocate a configured population size.
2. Initialize independent fixed-`N` individuals.
3. Obtain fitness through the active evaluator.
4. Build a separate next-generation container.
5. Optionally copy elites.
6. Fill remaining slots through roulette selection, crossover/copy, and mutation.
7. Replace the old generation atomically.
8. reset or recalculate evaluation state according to mode.
9. Increment the generation counter.

### 8.2 Policies

- `populationSize` is configurable in code and must be positive.
- Replacement is generational: all non-elites are replaced each generation. This matches the reference and is simple to explain.
- Offspring creation must fill exactly the configured size for even or odd remaining slot counts. If an operator returns two children and only one slot remains, use one child deterministically or randomly and discard the other without changing the population size.
- Selection returns parent references for reading; reproduction deep-copies before any mutation.
- No population history is required in memory. Logging may keep generation summaries.
- Automatic initialization evaluates all members and may maintain a ranked view. Interactive initialization leaves all members `UNRATED`.

### 8.3 Elitism

Elitism is an **inherited/reference behaviour**, not an assignment requirement. It is useful because interactive preferences or automatic progress are not lost entirely, but it reduces diversity and complicates rating semantics.

**Recommendation:** support `eliteSize` in configuration and use a small value (possibly one) for the baseline experiment, while explicitly comparing it with zero. Elite genomes are copied without mutation. In interactive mode, their old rating should not remain displayed as if the new generation had already been rated: set every new generation member, including elites, to `UNRATED`. If selection requires ratings before the next evolution, the elite must be rated again. In automatic mode, an unchanged elite's cached automatic score may be safely retained only when evaluator and render configuration are identical; recomputing is simpler and less error-prone for v1.

## 9. Interactive Fitness

### 9.1 Rating model

**Requirement:** interactive fitness is from 1 to 10.

**Recommended policy:** integer ratings only: `{1,2,...,10}` plus a separate `UNRATED` state. `0` is not a user-visible or stored rating. Internally, selection may assign zero weight to `UNRATED` only for an explicitly chosen fallback, but the preferred baseline is to require all individuals to be rated before evolution.

Requiring complete ratings has three advantages: roulette probabilities reflect deliberate comparisons, no phenotype receives a hidden disadvantage from missing input, and total fitness is guaranteed positive. The evolve action should show a concise message such as `Rate all individuals (7 remaining)` rather than partially evolve.

If later usability testing finds full rating too burdensome, an optional experiment may allow partial ratings and give unrated members zero weight. That is a policy change, not the baseline, and must keep unrated distinct from the minimum rating 1.

### 9.2 Visual and interaction design

- Display `—` or `unrated` until a score is assigned; display the integer prominently afterward.
- Use a clear border/fill indicator for hover and a distinct rated indicator. Do not rely on two-decimal text inherited from the reference.
- Preserve hover-based interaction if convenient: number keys `1`–`9` rate directly; `0` can mean 10 only if labeled clearly. A selected thumbnail plus number keys is safer if hover timing is unreliable.
- Arrow keys may increment/decrement within 1–10; an increment from `UNRATED` should choose a documented starting value rather than silently use zero.
- Click may select/focus an individual, but binary toggle behaviour does not satisfy the 1–10 requirement and should be removed.
- Enter/Space requests evolution only after rating readiness passes.
- A reset/clear-rating action should be explicit and visually confirmed.
- On successful generation replacement, every interactive rating resets to `UNRATED`, including copied elites.

Interactive ratings can be stored as integer values while the common evaluation API exposes a float selection weight. Automatic similarity remains a float; the source/mode tag prevents confusing a 0.83 similarity with an interactive rating.

## 10. Roulette Wheel Selection

### 10.1 Definition

For eligible individuals with non-negative weights `w_i`, roulette selection gives:

```text
P(select individual i) = w_i / sum(w_j)
```

For the baseline interactive mode, `w_i` is the integer rating 1–10. For automatic mode, it is the non-negative maximized similarity score. If later automatic metrics can be negative, transform or clamp them through a documented selection-weight policy before roulette selection.

### 10.2 Policy and edge cases

- Selection is with replacement. The same individual may be selected twice; self-crossover is valid but produces less novelty. This matches standard roulette behaviour and avoids hidden resampling bias.
- Interactive baseline requires all candidates to be rated, so `UNRATED` is not eligible at evolution time.
- If partial-rating mode is later enabled, unrated candidates receive zero selection weight, remain visible, and cannot be selected unless the entire eligible total is zero.
- Equal positive fitness naturally becomes uniform selection; no special case is needed.
- A total of zero can arise in automatic mode if all candidates receive worst fitness, or in optional partial-rating mode. Fall back to uniform random selection across the full valid population. Log/display that fallback because it indicates no selection signal.
- Reject NaN, Infinity, and negative selection weights before summing. An invalid automatic phenotype receives zero weight.
- Accumulate in `double` if convenient, and return the final individual as a defensive fallback for floating-point boundary error.

### 10.3 Pseudocode

```text
function rouletteSelect(individuals, weightPolicy, random):
    eligible = individuals allowed by current mode/readiness policy
    if eligible is empty:
        fail with configuration/evaluation error

    weights = []
    total = 0
    for individual in eligible:
        weight = weightPolicy(individual.evaluation)
        if weight is NaN, infinite, or negative:
            weight = 0
        weights.append(weight)
        total += weight

    if total <= 0:
        return uniformRandom(eligible)

    draw = random(0, total)       // half-open [0, total)
    cumulative = 0
    for i from 0 to eligible.length - 1:
        cumulative += weights[i]
        if draw < cumulative:
            return eligible[i]

    return eligible[last]        // floating-point defensive fallback
```

For each child or pair of children, invoke this independently for parent 1 and parent 2. Do not remove selected parents from the wheel.

## 11. Crossover Operators

All operators take two compatible parents with the same `N`, produce new deep-copied child genomes, preserve exactly `N` formulas and six fields per formula, clear evaluation/cache state, and validate decoded constraints afterward.

| Operator | Parents/output | Unit and boundary policy | Advantages | Disadvantages | Search behaviour | Repair |
|---|---|---|---|---|---|---|
| Per-parameter uniform | 2 parents → 1 or 2 children | For each formula index and named field, choose value from either parent; formula boundaries exist but may be internally mixed | Direct adaptation of reference; simple; high combinatorial variety | Can destroy useful parameter combinations within one formula; ignores formula as a semantic building block | Broad exploration through recombination | Normalized inherited values remain bounded; validate discrete `m` decode |
| Whole-formula uniform | 2 → 1 or 2 | At each formula index, inherit all six fields from one parent | Superformula-aware; preserves coherent formula building blocks; easy to explain | Cannot create a new formula parameter combination without mutation; index alignment may be arbitrary | Structural exploration while preserving local traits | Usually none beyond compatibility validation |
| One-point at formula boundary | 2 → 2 | Choose cut between formula indices; exchange suffixes; never split a formula | Preserves blocks and relative runs; closest safe analogue of earlier one-point crossover | With small `N`, few possible cuts; position/order has meaning only by convention | Medium exploration, strong inheritance | Ensure cut in `1..N-1`; for `N=1`, fall back to copy or another operator |
| Blend/interpolation | 2 → 1 or 2 | For corresponding named fields, interpolate normalized values using alpha; handle `m` discretely | Produces smooth intermediate shapes; useful exploitation near good parents | Children may be visually bland; integer `m` rounding bias; extrapolation can leave bounds | Primarily exploitation for alpha in `[0,1]` | Clamp normalized fields; round/decode `m` deterministically; validate singularity exclusions |
| Formula exchange by selected subset | 2 → 2 | Swap one or more whole formula indices | Explicitly structural and works even when useful layers are sparse | Similar to whole-formula uniform; requires a subset policy | Tunable structural exploration | Compatibility validation |

**Recommended simple baseline:** per-parameter uniform crossover, because it maps transparently from the reference and provides a comparison point.

**Recommended Superformula-specific operator:** whole-formula uniform crossover, because it treats the six parameters as one coherent visual building block.

**Recommended optional exploitation operator:** blend corresponding continuous fields while inheriting or discretely choosing `m`. Keep alpha in `[0,1]` initially; do not extrapolate until bounds tests exist.

`crossoverRate` determines whether selected parents are crossed. If crossover is skipped, the child is a deep copy of a roulette-selected parent, then subject to mutation. Experiments should compare operators one at a time with the same rate and seed set.

## 12. Mutation Operators

Mutation is applied to non-elite child copies. Each operator uses domain policies rather than hardcoded equation values.

| Operator | Affected parameters / probability | Magnitude and bounds | Expected visual effect | Risks |
|---|---|---|---|---|
| Parameter-wise Gaussian perturbation | Independently test each named field using a global base probability multiplied by optional field weights | Add zero-mean Gaussian noise in normalized space using per-field sigma; clamp/reflect to `[0,1]`; repair decoded exclusions | Mostly small shape changes; `m` changes can alter symmetry abruptly | Boundary pile-up with clamping; same sigma does not mean same visual change |
| Uniform bounded perturbation | Same field-wise probability | Add uniform delta within parameter-specific normalized magnitude, then repair | Direct reference analogue and easy baseline comparison | Artificial sharp step limit; still needs semantic scales |
| Random reset | Low independent probability for a field | Resample normalized field from its initialization domain | Escapes local convergence; can introduce new symmetry/exponent regime | Disruptive; too frequent resets turn search into random sampling |
| Discrete `m` mutation | Separate probability for `m` | Step decoded `m` by `±1` (or reset rarely), clamp to configured domain, re-encode | Clear changes in lobe/symmetry count | Strong phenotype jumps and sampling aliasing at high `m` |
| Whole-formula reset/replacement | Low probability per formula | Replace all six fields with a newly valid random gene | Restores diversity at layer level; structurally meaningful | Destroys a useful layer; should be rare |
| Coordinated formula mutation | Low probability per formula | Perturb related fields (`n1,n2,n3`, or `a,b`) together with correlated/independent deltas | Can move between coherent shape families | Harder to interpret and tune; defer until baseline evidence exists |

**Recommended v1 baseline:** parameter-wise Gaussian mutation in normalized space, with:

- one documented base probability per parameter visit;
- a smaller sigma for sensitive exponent fields;
- separate discrete `m` step mutation rather than adding a float and silently rounding;
- positive epsilon safeguards supplied by decoding;
- clamp or reflection at normalized bounds (choose one and record it; clamp is simpler);
- a rare random reset as an optional second-stage escape operator, disabled in the first baseline if simplicity is preferred.

Mutation rate and magnitude are separate settings. A rate answers “which fields change?”; sigma/magnitude answers “by how much?”. The reference's `0.4` and `±0.1` are inherited harmonograph settings, not justified defaults for this project.

After mutation, validate all normalized fields, decode once to validate equation constraints, increment the genome revision, clear phenotype cache, and clear evaluation state.

## 13. Evolution Pipeline

### 13.1 Shared generation construction

```text
precondition: current population has valid fitness for the active mode

ranked = stable descending view of current population
next = empty container of populationSize

for each configured elite:
    next.add(deepGenomeCopy(ranked[i]))

while next has empty slots:
    parent1 = rouletteSelect(current)
    if random < crossoverRate:
        parent2 = rouletteSelect(current)       // may equal parent1
        children = crossover(parent1, parent2)  // new deep genomes
    else:
        children = [deepGenomeCopy(parent1)]

    for child in children while a slot remains:
        mutate(child)                           // never mutate parents/elites
        validate(child)
        clear child evaluation and caches
        next.add(child)

replace current population atomically with next
generation += 1
obtain new fitness according to mode
```

### 13.2 Interactive flow

```text
initialize random population -> render grid -> all UNRATED
-> user assigns integer ratings 1..10
-> UI verifies every individual is rated
-> shared generation construction
-> reset every new member, including elites, to UNRATED
-> render next generation -> repeat
```

### 13.3 Automatic flow

```text
initialize random population
-> render/evaluate every candidate against target
-> shared generation construction
-> render/evaluate every new candidate (or safely reuse unchanged elite score)
-> record best/mean -> repeat until stop condition/user stop
```

The automatic controller should support one generation per frame, a controlled interval, or a bounded batch. Avoid a blocking infinite loop that prevents the Processing UI from responding.

## 14. Target-Driven Evolution

### 14.1 Evaluator hierarchy

```text
FitnessEvaluator
  evaluate(Individual) -> EvaluationResult

InteractiveFitness
  receives validated human ratings; does not infer pixels

TargetImageFitness
  renders at evaluation resolution and computes image similarity
```

This hierarchy is conceptual; Processing may use an interface or a small strategy class. The population engine consumes `EvaluationResult`/selection weights and remains mode-neutral.

### 14.2 Target preparation

1. Load the target once from a configured path and fail visibly if it is absent.
2. Convert/crop/pad it to the same square aspect and exact evaluation resolution as candidates. The choice between stretch, fit-with-padding, and centre-crop is an open policy and must be applied deterministically.
3. Use the same background convention and grayscale/brightness extraction for target and candidates.
4. Cache the preprocessed target pixel values.
5. Record path/identifier, preprocessing, and resolution in experiment logs.

### 14.3 Baseline RMSE strategy

RMSE is the recommended baseline because reference steps 7–10 already demonstrate it:

```text
MSE  = sum((targetPixel[i] - candidatePixel[i])^2) / pixelCount
RMSE = sqrt(MSE)
normalizedError = RMSE / maxChannelDifference
fitness = clamp(1 - normalizedError, 0, 1)
```

For 8-bit grayscale values, the reference uses `255` as maximum RMSE. This yields a maximized similarity, where identical images score `1` and maximum difference approaches `0`. The new evaluator must verify identical array lengths and use a sufficiently wide accumulator to avoid overflow. The reference's blue-channel shortcut may be retained for black/white images or replaced with documented luminance; whichever is chosen must be common to candidate and target.

Use one convention throughout: evolution maximizes fitness. Error metrics are inverted/normalized inside `TargetImageFitness`, not handled specially by selection.

Invalid rendered candidates receive fitness zero and a diagnostic count. A total population fitness of zero invokes the roulette uniform fallback.

### 14.4 Differences from interactive mode

- No ratings/readiness gate; evaluation follows initialization and every replacement.
- Fitness is a continuous normalized similarity, not an integer 1–10.
- The controller may evolve repeatedly and apply an experiment stop condition such as generation limit or stagnation limit; neither is an assignment-specified value.
- UI may show target, current best, generation, best/mean fitness, and pause/reset controls.
- Target preprocessing and evaluator settings form part of the experiment definition.

Optional future metrics—MSE without square root, thresholded silhouette overlap/IoU, edge distance, structural similarity, or feature-based similarity—are experiments, not baseline requirements. Pixel RMSE is sensitive to small translation, scale, stroke width, and background imbalance; document that limitation rather than obscuring it.

## 15. Interactive vs Automatic Mode

| Concern | Shared | Interactive-specific | Automatic-specific |
|---|---|---|---|
| Genotype | fixed-`N` individuals and domains | none | none |
| Rendering | formula calculation, composition, safeguards, cache | thumbnail grid | exact evaluation-resolution phenotype |
| Evolution | population replacement, elitism option, roulette, crossover, mutation, copies, generation count | readiness gate and rating reset | evaluate after replacement and loop controller |
| Fitness contract | validated maximized non-negative selection weight | explicit integer 1–10 from user | float similarity from target pixels |
| UI | current population, generation, reset | rating controls and completeness | target/best display, run/pause/step, metrics |
| Logging | config, seed, operators, generation summaries | rating distribution/qualitative notes | best/mean similarity and convergence |

Mode selection should choose a fitness provider/controller, not construct a second evolutionary engine. `Population.nextGeneration(...)` should receive or own the same selection/crossover/mutation policies in both modes. `IndividualRenderer` is also shared; mode-specific code decides requested resolution and when rendering occurs.

Avoid storing a global mode check inside every operator. The only intentional mode distinctions are fitness acquisition, readiness/reset semantics, and loop/UI control.

## 16. Configuration

### 16.1 Classification

| Setting | Initial classification | Rationale |
|---|---|---|
| population size | configurable in code; experiment setting | Affects UI burden and evolutionary diversity; not changed mid-generation |
| `N` formulas per individual | configurable in code; experiment setting | Fixed for a run; assignment gives no exact value |
| elite size | configurable in code; experiment setting | Inherited option; compare enabled/disabled |
| crossover operator | configurable in code; experiment setting | Required comparison/design dimension |
| crossover rate | configurable in code; experiment setting | Keep fixed per run; no v1 UI control |
| mutation operator | configurable in code; experiment setting | Required design dimension |
| base mutation rate | configurable in code; experiment setting | Keep fixed per run |
| per-parameter mutation magnitude/sigma | configurable in code; experiment setting | Domains have different sensitivity |
| random-reset rate | fixed initially at disabled/low; later experiment setting | Avoid early complexity |
| theta sampling step/count | configurable in code | Coupled to `m` upper bound and render speed; no routine UI control |
| angular interval | fixed initially from confirmed equation example | Core renderer contract |
| display render resolution | derived from grid / configurable in code | UI concern |
| target evaluation resolution | configurable in code; experiment setting | Accuracy/performance tradeoff; fixed within a run |
| parameter ranges/decoders | configurable in code; experiment setting | Must be documented, not hidden constants |
| numerical epsilons/radius cap | fixed initially in validated config | Safety settings; expose only for diagnostics/experiments |
| composition style | fixed initially | Keep v1 search space small |
| fitness mode | interactive UI/startup setting | User chooses interactive or target-driven run |
| target image/path and preprocessing | startup/UI or code setting; experiment setting | Automatic-mode input |
| random seed | configurable in code; experiment setting | Enables repeatable comparisons |
| maximum generations/stagnation rule | automatic experiment setting | Provides bounded runs; not needed for interactive baseline |

### 16.2 Simplicity policy

For v1, keep a single `Config.pde` with named fields and validation. Do not build a general settings framework. Only mode choice, target choice, and essential run controls need UI; operator/range experiments can be changed in code and logged. Values should be centralized even when initially fixed.

Validate at startup: positive population size, `N > 0`, `0 <= eliteSize < populationSize`, rates in `[0,1]`, valid ordered domains, positive resolution/sample count, safe epsilons, and crossover compatibility for `N`.

## 17. Planned Project Structure

```text
evolving-superformulas/
  docs/
    HARMONOGRAPHS_REPO_AUDIT.md
    SUPERFORMULA_MAPPING_PLAN.md
  evolving_superformulas/
    evolving_superformulas.pde
    Config.pde
    SuperFormulaGene.pde
    Individual.pde
    Rendering.pde
    Population.pde
    Selection.pde
    Crossover.pde
    Mutation.pde
    FitnessEvaluator.pde
    InteractiveUI.pde
    ExperimentLogger.pde          # add in final experiment phase
    data/
      target.png                  # placeholder/name decided later
```

| Planned file | Responsibility |
|---|---|
| `evolving_superformulas.pde` | Processing `settings/setup/draw` and event delegation; construct config, mode, population, renderer, and evaluator |
| `Config.pde` | Named settings, parameter domain metadata/decoders, startup validation, optional seed |
| `SuperFormulaGene.pde` | Six semantic normalized fields, initialization, deep copy, decode/validity helpers |
| `Individual.pde` | Exact `N`-gene candidate, evaluation state, genome revision/cache invalidation contract |
| `Rendering.pde` | `SuperFormulaRenderer` and `IndividualRenderer`; numerical safeguards, composition, off-screen rendering, cache |
| `Population.pde` | Initialization, current members, generation count, elites, next-generation orchestration |
| `Selection.pde` | Roulette wheel selection and selection-weight validation/fallback |
| `Crossover.pde` | Small set of named crossover functions/operators |
| `Mutation.pde` | Parameter-aware mutation and repair |
| `FitnessEvaluator.pde` | Evaluator contract, interactive evaluation state/policy, and target RMSE evaluator |
| `InteractiveUI.pde` | Grid calculation/drawing, hover/selection, ratings, readiness feedback, mode-specific controls |
| `ExperimentLogger.pde` | Reproducible run metadata and small CSV/text summaries; added only after core modes work |

This grouping avoids excessive abstraction: both renderers can share one file, fitness strategies can share one file, and operator variants can be functions/classes in their respective single files. Export can be added later to `Rendering.pde` or a small `Export.pde` only if the assignment workflow needs it.

## 18. Implementation Roadmap

No phase should begin by copying the reference `Harmonograph` wholesale. Each phase ends with a runnable or inspectable result.

### Phase 1 — Standalone Superformula renderer

**Goal:** render one formula safely and deterministically, independent of evolution.

**Files:** main sketch prototype, `Config.pde`, `SuperFormulaGene.pde`, `Rendering.pde`.

**Acceptance criteria:**

- Course-provided known parameters produce a stable closed shape at two resolutions.
- Parameter decoding is visible/documented and contains no hidden ranges.
- No NaN/Infinity reaches Processing vertices; singular inputs produce a controlled diagnostic/fallback.
- Same parameters, render config, and seed produce identical pixels.

### Phase 2 — Fixed-`N` individual and composition

**Goal:** model and render one candidate containing exactly configured `N` formulas.

**Files:** `Individual.pde`, existing renderer/config files.

**Acceptance criteria:**

- Constructors reject a formula count different from `N`.
- Exactly `N` layers are rendered using the minimal centred composition.
- A deep copy has equal values but no mutable aliases or shared cache.
- Changing one child gene invalidates only that child's phenotype.

### Phase 3 — Population foundation

**Goal:** initialize and display a stable-size population without evolution.

**Files:** `Population.pde`, main sketch.

**Acceptance criteria:**

- Population contains the configured number of independent valid individuals.
- Generation is zero after initialization/reset.
- Odd and even population sizes can be represented.
- A fixed seed reproduces initial genomes.

### Phase 4 — Interactive grid

**Goal:** show all composite phenotypes with reliable hover/selection and status.

**Files:** `InteractiveUI.pde`, main sketch, renderer.

**Acceptance criteria:**

- Every member appears once in a responsive valid grid.
- Hover/selection refers to the intended member.
- Generation and rating state are visible.
- Resizing/reinitialization does not leave stale cells or images.

### Phase 5 — Interactive fitness 1–10

**Goal:** collect explicit integer ratings and enforce generation readiness.

**Files:** `FitnessEvaluator.pde`, `InteractiveUI.pde`, `Individual.pde`.

**Acceptance criteria:**

- Only integer 1–10 or `UNRATED` can be stored interactively.
- Minimum score 1 is distinguishable from unrated.
- Evolve is blocked with a remaining-count message until all are rated.
- Direct rating, correction, and reset controls are unambiguous.

### Phase 6 — Roulette wheel selection

**Goal:** implement fitness-proportional parent selection with defined edge cases.

**Files:** `Selection.pde` plus a lightweight validation sketch/method.

**Acceptance criteria:**

- Known weights yield approximately proportional frequencies over many seeded draws.
- Equal weights are approximately uniform.
- zero-total weights use uniform fallback without failure.
- NaN, Infinity, negative, or missing values cannot corrupt cumulative selection.

### Phase 7 — Crossover operators

**Goal:** add baseline per-parameter uniform and structural whole-formula crossover.

**Files:** `Crossover.pde`.

**Acceptance criteria:**

- Children contain exactly `N` valid formulas.
- Every inherited baseline value can be traced to a parent.
- Whole-formula crossover never splits the six-field unit.
- Parents do not change when children are edited.
- `N=1` and final odd population slots have explicit behaviour.

### Phase 8 — Mutation operators

**Goal:** add parameter-aware Gaussian mutation and discrete `m` mutation.

**Files:** `Mutation.pde`, domain policies in `Config.pde`.

**Acceptance criteria:**

- All normalized genes remain in bounds and decode validly.
- A zero mutation rate changes nothing; controlled high-rate checks affect expected fields.
- `m` follows the declared integer/step policy.
- Mutation invalidates caches/evaluation only on the child.
- Safety sweeps render mutated genomes without non-finite output.

### Phase 9 — Full interactive evolution

**Goal:** connect rating, roulette selection, crossover, mutation, replacement, and optional elitism.

**Files:** main sketch, `Population.pde`, UI and operator files.

**Acceptance criteria:**

- One evolve action replaces exactly one generation and preserves population size.
- Parents remain unchanged during breeding.
- Configured elite genomes survive exactly when elitism is enabled.
- Every new interactive member is `UNRATED`.
- Generation count increments once; repeated rated generations remain stable and responsive.

### Phase 10 — Target image evaluator

**Goal:** evaluate one composite candidate against a preprocessed target using normalized RMSE similarity.

**Files:** `FitnessEvaluator.pde`, renderer/config, target asset.

**Acceptance criteria:**

- Candidate and target are compared at exactly the same dimensions/preprocessing.
- Identical image data scores 1 (within tolerance); deliberately different data scores lower.
- Scores are finite and clamped to `[0,1]`.
- Invalid phenotypes score zero and report a diagnostic.

### Phase 11 — Automatic evolution

**Goal:** reuse the population engine in target-driven mode.

**Files:** main sketch/controller, `Population.pde`, evaluator/UI.

**Acceptance criteria:**

- Initial and every new population are automatically evaluated.
- Roulette consumes the maximized similarity without mode-specific selection code.
- Run/step/pause/reset stays responsive.
- Best and mean fitness plus generation are visible/recordable.
- A bounded seeded run completes without NaN/Infinity or population-size drift.

### Phase 12 — Experiment and logging support

**Goal:** make operator/rate comparisons repeatable and reportable.

**Files:** `ExperimentLogger.pde`, config, optional export additions.

**Acceptance criteria:**

- Each run records seed, `N`, population size, domains, renderer/evaluator settings, operators, rates, and elitism.
- Automatic runs record generation, best, and mean fitness in a simple CSV/text form.
- Interactive runs can record selected final genome/image and short qualitative notes without logging personal data.
- The required report comparisons can be reconstructed from saved settings/results.

## 19. Validation Plan

Use lightweight Processing assertions/helper sketches and deterministic seeds; a heavy testing framework is unnecessary. Keep a few known parameter fixtures and expected invariants. Pixel snapshots are useful only after renderer conventions stabilize.

| Area | Programmatic validation | Manual/visual validation |
|---|---|---|
| Equation/numerics | sweep domain boundaries and random samples; assert finite decoded values/radii/coordinates; count skipped samples | inspect known course examples and boundary shapes |
| Deterministic rendering | hash/compare pixels for fixed genome/config/seed | compare saved reference thumbnails at multiple resolutions |
| Fixed `N` | reject wrong array lengths; assert all generations use same count | verify layer count with diagnostic per-layer colours during development only |
| Deep copies | mutate child and assert parent/sibling genes and caches unchanged | none required |
| Population | assert size before/after many odd/even replacements; generation increments once | watch grid for missing/duplicate slots |
| Crossover | tag parent fields and verify legal ancestry; assert boundaries for structural operator | inspect whether offspring combine recognizable traits |
| Mutation | property checks for `[0,1]`, decoded domains, integer `m`, zero-rate identity | compare low/high sigma visual effects |
| Roulette | seeded high-volume frequency counts within reasonable tolerance; equal/zero-total cases | optional histogram/debug display |
| Elitism | capture best genome, evolve, test exact genome present when enabled and absent guarantee removed when disabled | observe diversity/convergence |
| Fitness reset | after interactive replacement assert all `UNRATED`, including elites | verify UI shows no stale scores |
| Target fitness | identical pixel fixture ≈ 1; inverted/blank/different fixtures lower; sizes checked | compare candidate, target, difference image during development |
| NaN/Infinity protection | inject near-zero `a/b/n1`, extreme decoded settings, invalid values; assert fallback/penalty | ensure UI remains responsive and diagnostic phenotype is recognizable |
| Cache | same key reuses result; any pixel-affecting key change rerenders | toggle resolution/style during development and check no stale images |

Roulette statistical checks should not demand exact counts. For example, with weights `1:2:7`, many draws should preserve the ordering and fall within a predeclared tolerance around 10%, 20%, and 70%. Fix the seed so failures are reproducible.

Before claiming the automatic evaluator works, test the metric independently on small hand-constructed pixel arrays; this separates image preprocessing errors from evolutionary behaviour.

## 20. Experiment Plan

Keep experiments small enough for a short academic report. Change one primary variable, reuse several recorded seeds for automatic runs, and keep target, domains, renderer, `N`, population size, and generation budget fixed unless they are the variable under study.

| Experiment | Variable changed | Keep fixed | Metrics/observations | Informative result |
|---|---|---|---|---|
| Crossover comparison | per-parameter uniform vs whole-formula | seeds, mutation, rates, target/rating protocol, elitism | automatic best/mean fitness curves; interactive perceived coherence/diversity | Shows whether preserving formula blocks improves useful offspring or slows mixing |
| Optional blend crossover | blend vs baseline uniform | same as above | convergence speed, final similarity, phenotype diversity | Shows whether arithmetic exploitation helps near good solutions |
| Mutation rate | low/medium/high candidate rates | mutation sigma/operator and all other settings | convergence, diversity, invalid phenotype count, interactive novelty | Identifies premature convergence versus excessive disruption |
| Mutation magnitude | small vs larger per-field sigma | rate and other settings | generation-to-generation fitness change; visible shape jump; best final score | Establishes useful local-search scale |
| `m` mutation | discrete step enabled vs reset/disabled | continuous field mutation | symmetry diversity, convergence, subjective novelty | Tests value of topology-changing mutation |
| Elitism | `eliteSize=0` vs small enabled value | operators/rates/seeds | best-so-far retention, mean diversity, interactive frustration | Demonstrates benefit/cost of inherited reference behaviour |
| Target convergence | generation number | fixed run config and target | best/mean RMSE similarity at intervals; best images | Demonstrates automatic target-driven progress rather than only final output |
| Target variation | two or three simple targets | full algorithm config | final fitness and visual resemblance | Reveals metric/representation limitations across image types |
| Interactive outcome | operator choice or mutation setting | same participant protocol and starting seeds where practical | ratings over generations, chosen final image, short qualitative notes | Supports “visually appealing” claims without pretending ratings are objective |

For stochastic comparisons, report multiple seeds or clearly state when a result is a single illustrative run. Do not compare two algorithms while also changing population size, domains, sampling, and generation count.

## 21. Assignment Traceability

| Assignment requirement | Planned component(s) | Roadmap phase(s) | Evidence/output |
|---|---|---|---|
| Familiarize with interactive reference, especially step 11 | audit and mapping matrix | planning prerequisite | `HARMONOGRAPHS_REPO_AUDIT.md`; sections 2–3 |
| Implement Superformula in Processing | `SuperFormulaGene`, `SuperFormulaRenderer` | 1 | deterministic single-formula render |
| Fixed number of formulas per individual | `Individual.formulas[N]`, `Config.N`, `IndividualRenderer` | 2 | validated fixed-length composite |
| Interactive fitness 1–10 | `InteractiveFitness`, `InteractiveUI` | 5 | integer ratings and explicit unrated state |
| Roulette wheel selection | `Selection` | 6 | proportional-selection implementation and sanity check |
| Design new crossover operators | `Crossover` | 7 | baseline uniform plus whole-formula structural operator |
| Design new mutation operators | `Mutation` | 8 | parameter-aware Gaussian/discrete mutation; candidate reset operators |
| Interactive evolution for appealing images | shared population engine + interactive controller/UI | 9, 12 | rated generation loop, saved final examples/notes |
| Automatic target resemblance | `TargetImageFitness`, automatic controller | 10–11 | RMSE fitness and convergence record |
| Experimentation | `Config`, `ExperimentLogger`, experiment protocol | 12 | seeds, settings, plots/tables/images for report |

## 22. Decisions and Open Questions

### Decisions already supported by the assignment/audit

- **Requirement:** use the Superformula parameters `a`, `b`, `m`, `n1`, `n2`, `n3`.
- **Requirement:** an individual contains a fixed number `N` of Superformulas.
- **Requirement:** interactive fitness is 1–10.
- **Requirement:** parent selection uses roulette wheel selection, replacing reference tournament selection.
- **Requirement:** design Superformula-appropriate crossover and mutation operators.
- **Requirement:** support both interactive evolution and automatic target-driven evolution.
- **Audit-supported mapping:** reference step 11 provides the population/grid/manual-evaluation lifecycle but uses `[0,1]` fitness, tournament selection, a single 20-gene harmonograph, uniform crossover, and generic bounded mutation.
- **Audit-supported mapping:** off-screen `PGraphics` rendering, generation counting, deep-copy-before-variation, generational replacement, and grid layout are useful patterns to adapt.
- **Audit-supported mapping:** reference steps 7–10 use brightness-pixel RMSE normalized and inverted to a maximized similarity; this is the justified automatic baseline.
- **Inherited, not required:** elitism, a population size of 30, a crossover rate of 0.5, mutation rate 0.4, mutation magnitude `±0.1`, white/black rendering, and particular keyboard controls.
- **Recommended architecture:** separate semantic genotype, rendering, selection, crossover, mutation, evaluation, population, and UI responsibilities while keeping them in a small Processing sketch.
- **Recommended genotype representation:** named normalized genes decoded through centralized parameter policies; fitness remains separate runtime state.
- **Recommended interactive policy:** all members must receive an integer 1–10 rating before evolving; every new generation resets to explicit `UNRATED`.
- **Recommended v1 composition:** exactly `N` centred, unfilled, consistently styled formula outlines; no extra evolvable visual genes.
- **Recommended baseline operators:** per-parameter uniform crossover for reference comparison; whole-formula uniform as the structural operator; parameter-wise Gaussian mutation plus discrete `m` steps.

### Open design decisions before implementation

1. Exact fixed `N` for the first run and whether the report compares more than one `N`.
2. The authoritative equation spelling/angular interval from the course-provided Superformula example.
3. Final decoded ranges for all six parameters; no inspected source defines them.
4. Whether `a` and `b` evolve in v1 or remain fixed while renderer scale handles size.
5. Whether `m=0` is permitted and the initial integer symmetry range.
6. Whether `n2/n3` may be zero or negative; positive-only is the safer v1 recommendation.
7. Linear versus logarithmic decoding for sensitive exponent parameters.
8. Numerical epsilon values, radius cap, invalid-sample threshold, and whether normalized mutation bounds clamp or reflect.
9. Fixed run-wide scale versus fit-to-bounds rendering; fixed scale is recommended for target comparability.
10. Exact population size and UI grid size that make rating every member practical.
11. Whether elitism is enabled in the baseline and the chosen elite size; it is not an assignment requirement.
12. Crossover rate, mutation rate, and per-parameter mutation sigmas/magnitudes.
13. Whether rare random-reset and whole-formula mutation are enabled initially or only in experiments.
14. Whether each crossover call produces one child or two; both are valid if population filling is exact.
15. Target image choice, aspect preprocessing (stretch/pad/crop), evaluation resolution, and grayscale extraction.
16. Automatic stopping condition/generation budget and target-fitness reporting precision.
17. Exact UI bindings for rating 10 and whether click selects or rates.
18. Processing version and renderer (`P2D` or default) to record for reproducibility.
19. Which experiments fit within the report/time budget and how many stochastic seeds are feasible.

These questions must be resolved in `Config` and the experimental protocol before their associated implementation phase. They must not be presented later as if the assignment prescribed them.
