# Task 02 — Speed up percentiles with variable POR threshold (≥20 yr)

Branch: `refactor/02-percentiles-speedup`

## Goal
Replace the slow per-site Python `calculate_uv_percentiles_from_dv()` branching step with a faster path that (a) only computes percentiles for gages with ≥20 years of period of record, and (b) leverages USGS-native tooling (`dataRetrieval::read_waterdata_stats()` and/or `hyswap`) instead of bespoke Python.

## Why
- [2_process.R:26-32](2_process.R#L26-L32) prints "This branching step may take a while (~30 minutes)" — currently the dominant runtime cost.
- Percentiles computed against short records are statistically weak; REFACTOR.md priority #2 calls for a "variable percentile that includes gages of at least a 20 year period of record."
- REFACTOR.md success criteria #2 explicitly directs use of `hyswap` (https://doi-usgs.github.io/hyswap/) and/or the USGS stats API via `dataRetrieval::read_waterdata_stats()`.

## Affected files
- [1_fetch/src/generate_hyswap_percentiles.py](1_fetch/src/generate_hyswap_percentiles.py) — likely deprecated/removed
- [2_process.R](2_process.R) — replace `p2_uv_data_percentiles_df` target
- New: `2_process/src/calc_percentiles.R` — R-native percentile calc using `dataRetrieval` / `hyswap`
- New: `1_fetch/src/fetch_site_por.R` — fetch period of record per site to filter by ≥20 yr
- [_targets.R](_targets.R) — drop reticulate/python target if percentile computation moves fully to R

## Stepwise plan
1. Pull period-of-record metadata for the candidate sites (`dataRetrieval::whatNWISdata()` or `read_waterdata_*`); flag sites with ≥20 yr discharge record.
2. For qualifying sites, fetch daily-value statistics via `dataRetrieval::read_waterdata_stats()` (server-side computed) rather than computing from raw uv locally.
3. Join those stats back to the uv records to derive instantaneous percentile per timestamp (matching the column shape currently expected by [2_process.R:46-54](2_process.R#L46-L54)).
4. Sites without ≥20 yr POR: keep `percentile = NA` (downstream viz already handles NA gracefully).
5. Benchmark vs. current Python branch; require ≥5× speedup to justify swap.
6. Remove the python file dependency target if no longer referenced.

## Success criteria
- Pipeline runtime for the percentile step drops from ~30 min to under 5 min on Helene's site list.
- Output column `percentile` exists and is non-NA only for sites with ≥20 yr POR.
- Downstream targets (`p2_flow_height_complete_df`, viz frames) render without code changes.
- Statistical method follows hyswap / USGS stats API conventions (cited in code comment).

## Test
- Snapshot `p2_uv_data_percentiles_df` for ~10 representative sites pre-refactor; confirm post-refactor percentiles match within ±1 percentile point for sites with ≥20 yr POR.
- Confirm short-POR sites have `percentile = NA` and don't appear in percentile-colored viz layers.
- Time the full `tar_make(p2_uv_data_percentiles_df)` before and after; record in PR description.
