# Task 04 — Decompose `mapping_utils.R` into focused builders

Branch: `refactor/04-decompose-mapping-utils`

## Goal
Break the 956-line single-function file [3_visualize/src/mapping_utils.R](3_visualize/src/mapping_utils.R) into small, focused builder functions, each responsible for one map layer or panel. Improve readability, testability, and ease of customization for future storms.

## Why
- REFACTOR.md priority #4 calls this out by name: "Decompose 3_visualize/src/mapping_utils.R (956 lines, single function) into focused builders."
- A 956-line function is hard to review, test, and tweak per storm; small builders compose into the same final frame but can be edited or swapped individually.

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

## Success criteria
- No file in `3_visualize/src/builders/` exceeds ~150 lines.
- `compose_frame()` body is essentially a sequence of builder calls.
- Final rendered frames match pre-refactor pixel-for-pixel.
- Each builder has a roxygen2 header documenting inputs/outputs.

## Test
- Pre-refactor: render frame for one timestamp and save PNG hash.
- Post-refactor: render same timestamp; PNG hashes match (or visual diff < 1% pixel delta to allow for trivial AA differences).
- Source each new builder file standalone in a fresh R session — no missing-symbol errors.
