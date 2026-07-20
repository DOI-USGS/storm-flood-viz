#' Select major cities to label within a storm's bounding box.
#'
#' Auto-selects the most populous incorporated places intersecting `bbox_sf`,
#' using ACS total population from the Census API (via tidycensus), with an
#' optional per-storm override to force-include specific cities.
#'
#' Requires a Census API key in the `CENSUS_API_KEY` env var (see
#' `census_api_key()`or README.md).
#'
#' @param bbox_sf An `st_bbox` (or object coercible via `st_as_sfc`) in
#'   EPSG:4269 (NAD83) decimal degrees — the storm bbox from `p0_bbox_sf`.
#' @param proj Target CRS (PROJ string or EPSG) for the returned geometry,
#'   i.e. `p0_proj`.
#' @param n Integer. Number of top-population cities to auto-select within the
#'   bbox. Default 12.
#' @param override Optional data.frame/tibble of cities to force-include even
#'   if outside the top `n` or the bbox, with character columns `name` and
#'   `state` (two-letter abbreviation), e.g. `tibble(name = "Miami",
#'   state = "FL")`. `NULL` (default) means auto-selection only.
#' @param year ACS 5-year end year to pull population for. Defaults to the most
#'   recent 5-year ACS release (2020-2024).
#' @return An `sf` of city label points in `proj` with a single `NAME` column.
get_major_cities <- function(bbox_sf, proj, n = 12, override = NULL,
                             year = 2024) {
  bbox_4269 <- bbox_sf |>
    st_as_sfc() |>
    st_as_sf(crs = "EPSG:4269")

  # States intersecting the bbox, plus any states named in the override, so
  # the ACS pull covers every place we might return.
  bbox_states <- states(cb = TRUE) |>
    st_filter(bbox_4269) |>
    pull(STUSPS)
  states <- union(bbox_states, override$state)

  # Total population (B01003_001) for every place in those states.
  places <- get_acs(
    geography = "place",
    variables = "B01003_001",
    state = states,
    year = year,
    survey = "acs5",
    geometry = TRUE
  ) |>
    rename(pop = estimate) |>
    mutate(
      # ACS NAME is e.g. "Miami city, Florida"; keep the bare city name.
      # Consolidated city-counties read e.g. "Indianapolis city (balance),
      # Indiana", "Louisville/Jefferson County metro government (balance),
      # Kentucky", or "Athens-Clarke County unified government (balance),
      # Georgia". Drop the state, the "(balance)" tag, the place-type /
      # government designator, then the county tail (slash- or "County"-form).
      city = sub(",.*$", "", NAME),
      city = sub(" \\(balance\\)$", "", city),
      city = sub(paste0(" (city|town|village|borough|municipality|CDP|",
                        "((urban |metropolitan |metro )?county |consolidated |",
                        "unified |metropolitan |metro )?government)$"),
                 "", city),
      city = sub("/.*$", "", city),
      city = sub("-[A-Za-z]+ County$", "", city),
      state = sub("^.*, ", "", NAME)
    ) |>
    st_transform(proj) |>
    st_centroid()

  # Auto pick: most populous places whose centroid falls in the bbox.
  bbox_proj <- st_transform(bbox_4269, proj)
  auto <- places |>
    st_filter(bbox_proj) |>
    slice_max(pop, n = n)

  # Forced picks: rows matching the override name/state, regardless of bbox.
  forced <- if (is.null(override)) {
    places[0, ]
  } else {
    state_names <- setNames(fips_codes$state_name,
                            fips_codes$state)
    wanted <- tibble(
      city = override$name,
      state = unname(state_names[override$state])
    )
    inner_join(places, wanted, by = c("city", "state"))
  }

  # Friendlier labels for hyphen-merger city-counties whose county tail has no
  # "County" word for the rules above to catch (and which we can't strip
  # generically without breaking real hyphenated names like "Winston-Salem").
  # Anything not listed passes through unchanged.
  display_aliases <- c(
    "Nashville-Davidson" = "Nashville",
    "Lexington-Fayette" = "Lexington"
  )

  bind_rows(auto, forced) |>
    distinct(GEOID, .keep_all = TRUE) |>
    transmute(NAME = coalesce(display_aliases[city], city))
}
