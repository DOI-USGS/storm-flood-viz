# Task 04 — Decompose `mapping_utils.R` into focused builders

Branch: `refactor/04-decompose-mapping-utils`

## Goal
Break the 956-line single-function file [3_visualize/src/mapping_utils.R](3_visualize/src/mapping_utils.R) into small, focused builder functions, each responsible for one map layer or panel. Improve readability, testability, and ease of customization for future storms.

## Why
- REFACTOR.md priority #4 calls this out by name: "Decompose 3_visualize/src/mapping_utils.R (956 lines, single function) into focused builders."
- A 956-line function is hard to review, test, and tweak per storm; small builders compose into the same final frame but can be edited or swapped individually.

## In scope
- File decomposition: split `mapping_utils.R` into per-layer/per-panel builders.
- Simplification of `hurricane_flood_stage_frames()`'s 30+ parameter signature
  via grouped argument bundles or pre-resolved config.
- Documenting each builder with a roxygen2 header.
- Performance tuning of the ggplot calls or render time.

## Out of scope (file as separate tasks if you want these)
- Changing what gets rendered, where it's placed on the frame, what palettes
  are used, font sizes, legend layouts, or any other visual-design decision.
- Switching the spike-vs-point selector mechanism.
- Replacing cowplot with patchwork (or vice versa) — pick the one the existing
  code uses and stay consistent.
- Adding new viz layers (annotations, scale bars, additional gage symbology).

If the refactor surfaces a clear bug (e.g., a layer that's hidden by another),
note it in the PR description and either fix it as a one-line follow-up commit
*or* file a separate task — do not silently bundle.


## Affected files
- [3_visualize/src/mapping_utils.R](3_visualize/src/mapping_utils.R) — split
- New: `3_visualize/src/builders/` directory with one file per builder, e.g.:
  - `build_basemap.R` (states, ocean, bbox)
  - `build_precip_layer.R` (raster, palette)
  - `build_flood_layer.R` (points vs spikes, sev_rank ordering)
  - `build_storm_track.R` (track buffer, points, hurricane symbol)
  - `build_rdg_layer.R` (rapid deployment gages, bullseye icon)
  - `build_cities_layer.R`
  - `build_progress_bar.R`
  - `build_legends.R` (flood stage, precip)
  - `build_title_block.R` (storm name, timestamp, countdown)
  - `compose_frame.R` — top-level orchestrator that assembles a frame
- [3_visualize.R](3_visualize.R) — `source()` updates only

## Stepwise plan
1. Read `mapping_utils.R` end-to-end; map sections to candidate builders (≤80 lines each).
2. Identify the shared inputs (config_vars, palettes, bbox_coords) and pass them as explicit args — no globals.
3. Extract builders one at a time, smallest first (legends, progress bar) to validate the pattern.
4. Each builder returns a `ggplot` layer list, `grob`, or `patchwork` element — pick one convention and stick to it.
5. Write `compose_frame()` last; it should read like a table of contents.
6. Add roxygen2 headers to each new function (per REFACTOR.md code style).
7. Delete dead code revealed during extraction.

## Builder conventions
Two builder types, each with one canonical return type:

**Layer builders** (`build_*_layer.R`) — add things to the main map.
  Return: a `list` of ggplot2 Layer objects (the kind `+` accepts).
  Caller does: `ggplot() + state_layer + precip_layer + flood_layer + ...`
  Example: `build_precip_layer(precip_now, palette, ...)`.

**Panel builders** (`build_*_panel.R`) — produce free-standing visual elements
  that go on the page outside the main map (legends, title block, progress
  bar, attribution, peak callout).
  Return: a `grob` (use `cowplot::ggdraw() + ... |> as_grob()` if needed).
  Caller does: `cowplot::ggdraw() |> draw_grob(progress_grob, x=...)`.

`compose_frame()` builds the main map from layer builders, then arranges
panels around it via `cowplot::ggdraw + draw_*` calls — the same pattern
the existing code uses for title/end frames.

## Commit cadence
Commit each builder extraction separately, in this order:
1. Smallest/lowest-risk first: legend grobs, progress bar.
2. Pure-data layers next: precip, states, cities, RDG.
3. Domain-specific last: flood layer (spike vs point logic), storm track.
4. `compose_frame()` last — once all builders exist, the composer collapses
   what's left of `hurricane_flood_stage_frames()`.
Each commit should leave the pipeline runnable. After each, re-render one
frame and confirm equivalence. Don't pile 11 builder extractions into one
commit — `git bisect` becomes useless.

## Design legibility (preserve, don't change)
- Every magic number (`peak_height = 200000`, `y_baseheight = 10000`,
  `points_range = c(2, 10)`, `alpha = 0.6` on precip raster, etc.) must
  either:
  (a) be defined as a named local constant at the top of its builder with
      a comment explaining the choice, OR
  (b) move to `viz_config_df` in the storm YAML so it's per-storm tunable.
  Do not leave them as bare positional args.
- Layer stacking order is design — record it. Add a comment in
  `compose_frame()` listing the layer order from bottom to top.
- Theme application is design — apply themes in one place inside
  `compose_frame()`, not sprinkled across builders.

## Success criteria
- `compose_frame()` body is essentially a sequence of builder calls.
- Final rendered frames match pre-refactor pixel-for-pixel.
- Each builder has a roxygen2 header documenting inputs/outputs.

## Test
- Pre-refactor: render frame for one timestamp and save PNG hash.
- Post-refactor: render same timestamp; PNG hashes match (or visual diff < 1% pixel delta to allow for trivial AA differences).
- Source each new builder file standalone in a fresh R session — no missing-symbol errors.
