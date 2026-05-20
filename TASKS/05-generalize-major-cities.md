# Task 05 — Generalize `p1_major_cities_sf` beyond hard-coded SE US cities

Branch: `refactor/05-generalize-major-cities`

## Goal
Replace the hard-coded 12-city list in [1_fetch.R:120-143](1_fetch.R#L120-L143) with a generalizable approach that selects appropriate cities for any storm's bbox/region — driven by the per-storm config from Task 01.

## Why
- REFACTOR.md priority #5: the city lookup is hand-tuned for Helene (Miami, Atlanta, Raleigh, NYC, etc.) and won't work for a Gulf-only or West Coast storm without manual editing.
- Should pair naturally with Task 01's per-storm config so labeling cities becomes a config concern, not a code concern.

## Affected files
- [1_fetch.R:120-143](1_fetch.R#L120-L143) — `p1_major_cities_sf` target
- New: `1_fetch/src/get_major_cities.R` — pluggable city selector
- `config/<storm>.yml` (from Task 01) — optional `cities:` override list

## Stepwise plan
1. Decide selection strategy. Options to present in PR description:
   - **A. Population-threshold from `tigris::places()` + Census population** clipped to bbox. Fully automatic.
   - **B. Curated list from config** (user lists cities per storm).
   - **C. Hybrid:** auto-select top-N by population within bbox, allow config override/append.
   Recommend C — auto by default, override available.
2. Write `get_major_cities(bbox_sf, proj, n = 12, override = NULL)`:
   - Pull `tigris::places(cb = TRUE)` for states intersecting bbox.
   - Join Census population (e.g. `tidycensus::get_acs` total population) or use `tigris` LSAD/feature filtering for "incorporated place".
   - Rank by population, take top `n` within bbox.
   - If `override` provided (named list of city/state pairs), union with auto results, dedup.
3. Replace inline target body with one call: `get_major_cities(bbox_sf = p0_bbox_sf, proj = p0_proj, n = config$cities_n, override = config$cities)`.
4. Document the function with roxygen2.
5. Sanity-check that for Helene's bbox the auto-selected list reasonably overlaps the current curated list.

## Success criteria
- No hard-coded city/state strings remain in `1_fetch.R`.
- Function works for any bbox in CONUS without code edits.
- Helene viz output is materially equivalent (cities labeled in same general locations; minor differences acceptable).
- If `tidycensus` is added as a dep, it's flagged in PR per AGENTS.md hard rule on dependencies.

## Test
- Run `get_major_cities()` with Helene bbox → returns ~12 cities, sf with NAME + geometry, projected to `p0_proj`.
- Run with a Gulf-only bbox (xmin = -98, xmax = -82, ymin = 24, ymax = 32) → returns Gulf-region cities (Houston, New Orleans, Mobile, Tampa, etc.) with no NE cities.
- Confirm Helene gif still renders with cities on the map; visually compare label positions to pre-refactor.
