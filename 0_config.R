# Phase 0: pipeline plumbing.
#
# Per-storm and viz parameters live in config/<storm>.yml.
# To swap storms, change the path in `p0_storm_cfg_file` below.
#
# Each per-storm/viz value is exposed as its own leaf target so downstream
# targets only re-run when their specific input changes.

#' Load and type-coerce a per-storm YAML config.
#'
#' YAML scalars/maps don't preserve R types like POSIXct, sf bbox, or tibble,
#' so this loader reconstructs them. Returns a named list with the same shape
#' the per-storm/viz tar_targets below expect.
#'
#' @param path Path to the storm YAML file.
#' @return A named list ready for downstream `p0_storm_cfg$<field>` access.
load_storm_config <- function(path) {
  cfg <- yaml::read_yaml(path)

  cfg$landfall_time <- as.POSIXct(cfg$landfall_time, tz = "UTC")

  cfg$bbox <- sf::st_bbox(c(xmin = cfg$bbox$xmin, xmax = cfg$bbox$xmax, ymin = cfg$bbox$ymin, ymax = cfg$bbox$ymax))

  cfg$storm_info <- tibble::as_tibble(cfg$storm_info)
  cfg$viz_config <- tibble::as_tibble(cfg$viz_config)

  # Named-map palettes -> named character vector
  cfg$pal_fs_blue <- unlist(cfg$pal_fs_blue)
  cfg$pal_fs_red <- unlist(cfg$pal_fs_red)
  # Sequence palettes -> unnamed character vector
  cfg$pal_percentile <- unlist(cfg$pal_percentile)
  cfg$pal_precip_blue <- unlist(cfg$pal_precip_blue)
  cfg$pal_precip_grayscale <- unlist(cfg$pal_precip_grayscale)

  cfg$cities_n <- cfg$cities_n %||% 12L
  cfg$cities_track_buffer <- cfg$cities_track_buffer %||% 500000
  cfg$cities_min_dist <- cfg$cities_min_dist %||% 100000
  cfg$cities_storm_types <- if (!is.null(cfg$cities_storm_types)) unlist(cfg$cities_storm_types) else c("HU", "TS")
  cfg$cities_override <- if (!is.null(cfg$cities_override)) unlist(cfg$cities_override) else NULL

  cfg
}

p0_targets <- list(

  # Storm config dispatch
  tar_target(p0_storm_cfg_file, "config/helene.yml", format = "file"),
  tar_target(p0_storm_cfg, load_storm_config(p0_storm_cfg_file)),

  # Pipeline-constant data sources
  tar_target(p0_flood_stage_url, "https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv"),
  tar_target(p0_pcodes, c("00060", "00065")),

  # Per-storm leaves
  tar_target(p0_bbox_sf, p0_storm_cfg$bbox),
  tar_target(p0_proj, p0_storm_cfg$proj),
  tar_target(p0_date_start, p0_storm_cfg$date_start),
  tar_target(p0_date_end, p0_storm_cfg$date_end),
  tar_target(p0_storm_info, p0_storm_cfg$storm_info),
  tar_target(p0_landfall_time, p0_storm_cfg$landfall_time),
  tar_target(p0_timezone, p0_storm_cfg$timezone),
  tar_target(p0_timezone_abv, p0_storm_cfg$timezone_abv),

  # Viz leaves
  tar_target(p0_viz_fs_config_pal_blue, p0_storm_cfg$pal_fs_blue),
  tar_target(p0_viz_fs_config_pal_red, p0_storm_cfg$pal_fs_red),
  tar_target(p0_viz_percentile_config_pal, p0_storm_cfg$pal_percentile),
  tar_target(p0_viz_precip_config_pal_blue, p0_storm_cfg$pal_precip_blue),
  tar_target(p0_viz_precip_config_pal_grayscale, p0_storm_cfg$pal_precip_grayscale),
  tar_target(p0_precip_grayscale_var, p0_storm_cfg$precip_grayscale),
  tar_target(p0_flood_spike_var, p0_storm_cfg$flood_spike),
  tar_target(p0_viz_config_df, p0_storm_cfg$viz_config),
  tar_target(p0_cities_n, p0_storm_cfg$cities_n),
  tar_target(p0_cities_track_buffer, p0_storm_cfg$cities_track_buffer),
  tar_target(p0_cities_min_dist, p0_storm_cfg$cities_min_dist),
  tar_target(p0_cities_storm_types, p0_storm_cfg$cities_storm_types),
  tar_target(p0_cities_override, p0_storm_cfg$cities_override),

  # Derived from per-storm values (precip/NWIS times in UTC to match precip)
  tar_target(p0_precip_bbox, unname(as.list(p0_bbox_sf))),
  tar_target(p0_precip_start, paste0(p0_date_start, "T00")),
  tar_target(p0_precip_end, paste0(p0_date_end, "T23")),
  tar_target(p0_nwis_start, paste0(p0_date_start, "T00:00Z")),
  tar_target(p0_nwis_end, paste0(p0_date_end, "T23:00Z"))
)
