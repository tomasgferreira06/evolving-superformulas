# Phase 14: Reference alignment

Phase 14 aligns automatic Superformula evaluation with the corresponding
evolving-harmonographs behavior without removing assignment requirements.

## Aligned behavior

- The default population is 30 and `eliteSize` is exactly 1.
- Automatic phenotypes use the default `createGraphics(width, height)` path.
- Automatic rendering uses a white background, black stroke, no fill, and
  `strokeWeight = canvas.height * 0.002` (0.512 at 256 px).
- Target preprocessing copies the source and stretches the copy with
  `resize(256, 256)`. The source image is not modified.
- Fitness reads each pixel as `pixel & 0xFF`, computes blue-channel RMSE over
  the pixel count, divides RMSE by 255, and returns `1 - normalizedRMSE`.
- Final fitness is not clamped; valid 8-bit images naturally produce [0, 1].
- One best genotype is deep-copied before offspring are created. It bypasses
  crossover and mutation. Automatic fitness is reevaluated after replacement.
- Interactive ties are deterministic: the lowest population index wins. The
  copied elite starts UNRATED, like every member of a new interactive generation.
- Populations are kept in stable descending fitness order after automatic
  evaluation and after interactive rating changes. Equal fitness values retain
  their previous order; interactive `UNRATED` individuals remain at the end.
- Experiment batches write Phase 14 metadata in a new timestamped directory.
  A numeric suffix prevents a timestamp collision from reusing a directory.

## Intentional differences retained

- The phenotype is a fixed number of Superformulas rather than a Harmonograph.
- Interactive fitness remains an integer rating from 1 through 10.
- Interactive evolution still requires every individual to be rated before
  reproduction. This all-rated policy is intentionally stricter than the
  reference workflow.
- Parent selection remains roulette-wheel selection. Automatic weights are
  target fitness; interactive weights are human ratings. Zero-total automatic
  weights retain uniform fallback selection.
- Crossover remains `PARAMETER_UNIFORM` or `WHOLE_FORMULA_UNIFORM`.
- Mutation remains `BOUNDED_UNIFORM_MUTATION` or
  `GAUSSIAN_PARAMETER_MUTATION`.
- Deterministic seeds, automatic controls, fitness tracking, startup validation,
  and experiment logging remain engineering extensions.
- Processing's `PImage.copy()` and `resize()` preserve the reference target
  preprocessing path, including its renderer-dependent alpha semantics; no
  additional alpha normalization is performed.
- No transform genes (`xOffset`, `yOffset`, `rotation`, or `scale`) exist.
