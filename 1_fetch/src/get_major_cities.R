#' Select major cities likely impacted by a storm for map labeling.
#'
#' Filters [maps::us.cities] to states in `bbox_sf`, computes distance from
#' each city to the storm track, keeps cities within `track_buffer_dist`
#' metres of the track, ranks by population, then applies a greedy
#' minimum-distance filter to prevent label crowding.
#'
#' @param bbox_sf sf object. States covering the region; must have a `STUSPS`
#'   column. Typically `p1_conus_bbox_crop_sf`.
#' @param storm_track_sf sf object. Storm track points. Typically
#'   `p1_storm_track_pts_sf`. Must have `STORMTYPE` and geometry columns.
#' @param proj Character. CRS string passed to [sf::st_transform()].
#' @param n Integer. Maximum number of cities to return (default 12).
#' @param track_buffer_dist Numeric. Maximum distance in metres from the storm
#'   track for a city to be considered (default 500000 = 500 km).
#' @param min_dist Numeric. Minimum distance in metres between any two selected
#'   cities (default 100000 = 100 km). The larger city in any nearby pair is
#'   always kept because candidates are ranked by population before filtering.
#' @param storm_types Character vector. STORMTYPE values to include when
#'   building the track buffer (default `c("HU", "TS")`). Use this to exclude
#'   the extratropical/LO phase that can extend the track far inland.
#' @param override Character vector or NULL. City names to force-include
#'   regardless of rank. Plain names (e.g. `"Miami"`) match any city with that
#'   name; use `"City ST"` format (e.g. `"Columbia SC"`) to disambiguate
#'   cities that share a name across states. Override cities are appended after
#'   auto-selection and are not subject to `min_dist`.
#' @return An sf object with columns NAME and geometry (point locations)
#'   projected to `proj`.
get_major_cities <- function(bbox_sf, storm_track_sf, proj,
                             n = 12, track_buffer_dist = 500000,
                             min_dist = 100000, storm_types = c("HU", "TS"),
                             override = NULL) {
  state_abbrs <- unique(bbox_sf$STUSPS)

  cities_sf <- maps::us.cities |>
    dplyr::mutate(city_name = sub(" [A-Z]{2}$", "", name)) |>
    dplyr::filter(country.etc %in% state_abbrs) |>
    sf::st_as_sf(coords = c("long", "lat"), crs = "EPSG:4269") |>
    sf::st_transform(proj)

  # Build a single LINESTRING from tropical-phase track points only, then buffer.
  # Filtering to HU/TS prevents the extratropical LO phase from dragging the
  # buffer far inland (e.g. Helene's LO track reaches ~38°N near Indianapolis).
  track_line <- storm_track_sf |>
    dplyr::filter(STORMTYPE %in% storm_types) |>
    sf::st_geometry() |>
    sf::st_union() |>
    sf::st_cast("LINESTRING")
  track_buffer <- sf::st_buffer(track_line, dist = track_buffer_dist)

  candidates <- cities_sf |>
    dplyr::filter(sf::st_within(geometry, track_buffer, sparse = FALSE)[, 1]) |>
    dplyr::arrange(dplyr::desc(pop))

  # Greedy min-distance selection: iterate in population order so the larger
  # city in any nearby cluster is always kept over a smaller neighbour.
  # n = 0 skips auto-selection entirely (result driven solely by override).
  selected <- list()
  for (i in seq_len(nrow(candidates))) {
    if (length(selected) >= n) break
    candidate <- candidates[i, ]
    if (length(selected) == 0) {
      selected <- c(selected, list(candidate))
      next
    }
    kept <- do.call(rbind, selected)
    dists <- as.numeric(sf::st_distance(candidate, kept))
    if (all(dists >= min_dist)) {
      selected <- c(selected, list(candidate))
    }
  }

  top_cities <- if (length(selected) > 0) {
    do.call(rbind, selected) |> dplyr::select(NAME = city_name, geometry)
  } else {
    cities_sf[0, ] |> dplyr::select(NAME = city_name, geometry)
  }

  if (!is.null(override)) {
    # "City ST" entries match on raw maps name field to disambiguate same-named
    # cities across states. Plain names match on city_name.
    qualified <- grepl("^.+ [A-Z]{2}$", override)
    override_cities <- cities_sf |>
      dplyr::filter(
        sf::st_within(
          geometry, sf::st_union(bbox_sf), sparse = FALSE
        )[, 1],
        name %in% override[qualified] | city_name %in% override[!qualified]
      ) |>
      dplyr::select(NAME = city_name, geometry)
    top_cities <- dplyr::bind_rows(top_cities, override_cities) |>
      dplyr::distinct(NAME, .keep_all = TRUE)
  }

  top_cities
}
