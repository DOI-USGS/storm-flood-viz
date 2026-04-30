# Task 05 — Generalize `p1_major_cities_sf` beyond hard-coded SE US cities

Branch: `refactor/05-generalize-major-cities`

## Goal
Replace the hard-coded 12-city list in `1_fetch.R` with a generalizable approach
that selects appropriate cities for any storm's bbox/region — driven by the
per-storm config from Task 01.

## Why
- REFACTOR.md priority #5: the city lookup is hand-tuned for Helene (Miami,
  Atlanta, Raleigh, NYC, etc.) and won't work for a Gulf-only or West Coast
  storm without manual editing.
- Should pair naturally with Task 01's per-storm config so labeling cities
  becomes a config concern, not a code concern.

## Affected files
- `1_fetch.R` — `p1_major_cities_sf` target (inline body replaced)
- `1_fetch/src/get_major_cities.R` — pluggable city selector (new)
- `config/helene.yml` and `config/_template.yml` — `cities_n`, `cities_track_buffer`, `cities_min_dist`, `cities_storm_types`, `cities_override` keys (new)
- `0_config.R` — `p0_cities_n`, `p0_cities_track_buffer`, `p0_cities_min_dist`, `p0_cities_storm_types`, `p0_cities_override` targets (new)

## Approach considered and rejected: `tigris::places()`

The original plan called for pulling `tigris::places(cb = TRUE)` for states
intersecting the bbox and ranking by Census population via `tidycensus::get_acs`.

**Why we didn't use it:**
- `tigris::places()` downloads one file per state over HTTP/FTP. Helene's bbox
  spans 37 states, making this slow and fragile (FTP fallbacks failed in
  testing).
- Adding `tidycensus` as a dependency requires a Census API key, adding friction
  for new users and CI environments.
- Using ALAND (land area) as a population proxy — to avoid the `tidycensus` dep
  — produced poor results: Texas cities (San Antonio, Fort Worth, Austin) have
  enormous land areas and dominated the ranking even for an Atlantic hurricane,
  while smaller but storm-relevant cities (Atlanta, Raleigh) were excluded.

## Implemented approach: `maps::us.cities`

The built-in `maps::us.cities` dataset (part of the `maps` package, already a
transitive dependency) provides city name, state abbreviation, lat/lon, and
population for ~1,000 US cities. No API calls or extra downloads at runtime.

**How `get_major_cities()` works:**

1. **State filter** — extracts state abbreviations from `bbox_sf$STUSPS` and
   subsets `maps::us.cities` to those states.
2. **Storm type filter** — filters the storm track to only the STORMTYPE codes
   in `storm_types` (default `c("HU", "TS")`) before building the buffer.
   This excludes the extratropical LO phase, which can extend the track far
   inland (e.g. Helene's LO track reaches ~38°N near Indianapolis, pulling in
   Midwest cities irrelevant to hurricane impact visualization). HU/TS-only
   track caps at ~34.4°N for Helene.
3. **Storm track buffer** — builds a LINESTRING from the filtered track points
   and buffers it by `track_buffer_dist` metres. Cities outside this buffer are
   excluded, so large metros far from the storm path (Chicago, Detroit) don't
   outrank storm-corridor cities simply because they fall within a wide bbox.
4. **Population ranking** — remaining candidates are sorted descending by `pop`.
5. **Greedy min-distance filter** — iterates cities in population order and
   keeps each one only if it is at least `min_dist` metres from all
   already-selected cities. Because iteration is in descending population order,
   the larger city in any nearby pair is always kept (e.g. Tampa beats
   St. Petersburg). This prevents label crowding on the map.
6. **Override** — cities named in `cities_override` are appended after
   auto-selection and deduped, so storm-specific cities that fall outside the
   buffer or lose out in ranking can still be forced onto the map.

**Config keys (per-storm, in `config/<storm>.yml`):**

| Key | Default | Description |
|---|---|---|
| `cities_n` | 12 | Max auto-selected cities |
| `cities_track_buffer` | 500000 | Search radius (m) from storm track |
| `cities_min_dist` | 100000 | Min distance (m) between any two selected cities |
| `cities_storm_types` | `[HU, TS]` | STORMTYPE codes used to build the track buffer |
| `cities_override` | null | City names to force-include regardless of rank |

For Helene, `cities_track_buffer` is set to 700000 m and `cities_min_dist` to
30000 m in `helene.yml` to better capture the storm's broad inland reach while
allowing denser labeling in the impact corridor.

## Success criteria
- No hard-coded city/state strings remain in `1_fetch.R`. ✅
- Function works for any CONUS bbox without code edits. ✅
- Nearby cities (Tampa + St. Petersburg) are deduplicated with the larger kept. ✅
- LO-phase track points excluded by default so inland cities (Indianapolis, Nashville) don't appear. ✅
- Per-storm tuning is config-only. ✅

## Test
- Run `get_major_cities()` with Helene track (HU/TS only) → cities limited to
  SE US corridor, not Midwest metros.
- Set `cities_storm_types: [HU, TS, LO]` → Indianapolis appears, confirming
  the filter is doing its job.
- Adjust `cities_track_buffer` (e.g. 300000 vs 700000) → narrower/wider city
  selection corridor around the track.
- Adjust `cities_min_dist` (e.g. 30000 vs 200000) → denser or sparser labels.
- Confirm Helene gif still renders with cities on the map; visually compare
  label positions to pre-refactor.
