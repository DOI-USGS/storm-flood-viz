# Task 02 — Speed up percentiles with USGS stats API (≥20 yr POR)

Branch: `refactor/02-percentiles-speedup`

## Goal

Replace the slow per-site Python `calculate_uv_percentiles_from_dv()` step with
an R-native fetch from the USGS waterdata statistics API
(`dataRetrieval::read_waterdata_stats_por()`). Percentile thresholds are
computed server-side by USGS and fetched once per event for all sites in the
event bbox, eliminating the ~30-minute branching bottleneck.

## Why

- [2_process.R](2_process.R) branched over every site, fetching all historical
  daily values back to 1900 and computing thresholds locally via Python/hyswap
  (~30 min runtime).
- REFACTOR.md priority #2 calls for a variable percentile including only gages
  with ≥20 yr period of record, using USGS-native tooling
  (cited in REFACTOR.md success criteria #2).
- The new approach fetches pre-computed USGS statistics for only the sites in
  the event bbox — no Python, no per-site branching, no raw DV downloads.

## Affected files

- [1_fetch/src/fetch_site_stats.R](1_fetch/src/fetch_site_stats.R) — new; fetches
  day-of-year percentile thresholds from USGS stats API, filters to ≥20 yr POR,
  pivots to wide format (p05–p95 per site × MM-DD), writes parquet
- [1_fetch.R](1_fetch.R) — adds `p1_site_stats_pqt` target; removes
  `p1_hyswap_py_file` target and `generate_hyswap_percentiles.py` source
- [2_process.R](2_process.R) — replaces `p2_uv_sites` + Python branching target
  with a single join + category-assignment target
- [1_fetch/src/generate_hyswap_percentiles.py](1_fetch/src/generate_hyswap_percentiles.py) — deprecated (no longer sourced)

## How it works

### Fetch (`p1_site_stats_pqt`)

`fetch_site_stats()` calls `read_waterdata_stats_por()` in batches for all sites
in `p1_bbox_stream_sites` (all active UV gages in the event bbox, not just
flood-stage sites). It:

1. Filters to `time_of_year_type == "day_of_year"` rows.
2. Selects the preferred time series per site: the one with the highest
   `min(sample_count)` across all 366 day-of-year rows, requiring that minimum
   to be ≥ `min_por_years` (default 30). Sites below this threshold are excluded.
3. Pivots to wide format: one row per `site_no × MM-DD` with columns
   `p05, p10, p25, p50, p75, p90, p95`.

Note: the stats API returns threshold *values* at fixed percentile levels, not a
numeric percentile for each observation. Categories are assigned by comparing
the observed discharge to these thresholds.

**API key warning**: batches larger than ~30 sites trigger HTTP 403 from the
statistics API unless `API_USGS_PAT` is set in the environment. Keep
`batch_size ≤ 30` without an API key. The function signature default and the
docstring have drifted — verify they agree before running. If `batch_size = 50`
is set, expect 403s.

**Batch checkpointing**: completed batches are written to
`1_fetch/out/site_stats_cache/batch_N.parquet` immediately. On a failed run,
restarting resumes from the last successful batch. The cache folder is deleted
automatically on success.

### Process (`p2_uv_data_percentiles_df`)

Joins the wide threshold table to UV data on `site_no + format(dateTime, "%m-%d")`,
then assigns a **category string** by comparing `X_00060_00000` to the thresholds:

| Category | Condition |
|---|---|
| `"low"` | value < p05 |
| `"5-10"` | p05 ≤ value < p10 |
| `"10-25"` | p10 ≤ value < p25 |
| `"25-75"` | p25 ≤ value < p75 |
| `"75-90"` | p75 ≤ value < p90 |
| `"90-95"` | p90 ≤ value < p95 |
| `"high"` | value ≥ p95 |
| `NA` | discharge NA or site has < 20 yr POR |

These 7 categories match the 7-color `pal_percentile` palette in the storm config.

## Success criteria

- Pipeline runtime for the percentile step drops from ~30 min to under 5 min.
- `percentile` is a character category string, NA only for sites with < 20 yr POR.
- Downstream targets (`p2_flow_height_complete_df`, viz frames) render without
  code changes.
- No Python dependency for percentile calculation; `generate_hyswap_percentiles.py`
  is no longer sourced.

## Test

```r
targets::tar_make(p1_site_stats_pqt)
targets::tar_make(p2_uv_data_percentiles_df)

df <- targets::tar_read(p2_uv_data_percentiles_df)
table(df$percentile, useNA = "always")  # 7 categories + NAs for short-POR sites
mean(is.na(df$percentile))              # fraction excluded by POR filter
```

Time `tar_make(p2_uv_data_percentiles_df)` before and after; record delta in PR
description.
