# Phase 0: pipeline plumbing.
#
# Per-storm and viz parameters live in config/<storm>.yml.
# To swap storms, change the path in `p0_storm_cfg_file` below.
#
# Each per-storm/viz value is exposed as its own leaf target so downstream
# targets only re-run when their specific input changes.

#' Parse a config field that must be TRUE or FALSE.
#'
#' Accepts an actual logical or the strings "TRUE"/"FALSE" (any case) and
#' errors on anything else (e.g. a typo like "FASLE"), so the mistake surfaces
#' at config load rather than as a cryptic `if (NA)` error downstream.
parse_config_logical <- function(x, field) {
  if (is.logical(x) && length(x) == 1 && !is.na(x)) return(x)
  if (is.character(x) && length(x) == 1) {
    v <- toupper(trimws(x))
    if (v == "TRUE") return(TRUE)
    if (v == "FALSE") return(FALSE)
  }
  stop(sprintf("Config field '%s' must be TRUE or FALSE, got: %s",
               field, dQuote(x)), call. = FALSE)
}

#' Validate required storm-config fields before the pipeline uses them.
#'
#' Checks required keys are present and applies basic sanity rules so typos
#' fail fast with a clear message.
validate_storm_config <- function(cfg) {
  required <- c("date_start", "date_end", "landfall_time", "proj",
                "storm_info", "cities_n", "flood_spike", "precip_grayscale")
  missing <- setdiff(required, names(cfg))
  if (length(missing) > 0) {
    stop("Config is missing required field(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  for (f in c("date_start", "date_end")) {
    if (is.na(as.Date(cfg[[f]], format = "%Y-%m-%d"))) {
      stop(sprintf("Config '%s' must be a date 'YYYY-MM-DD', got: %s",
                   f, dQuote(cfg[[f]])), call. = FALSE)
    }
  }
  if (as.Date(cfg$date_end) < as.Date(cfg$date_start)) {
    stop("Config 'date_end' must not be before 'date_start'.", call. = FALSE)
  }
  if (is.na(as.POSIXct(cfg$landfall_time, tz = "UTC"))) {
    stop("Config 'landfall_time' must parse as 'YYYY-MM-DD HH:MM:SS'.",
         call. = FALSE)
  }
  if (!is.numeric(cfg$cities_n)) {
    stop("Config 'cities_n' must be numeric.", call. = FALSE)
  }

  invisible(TRUE)
}

#' Load and type-coerce a per-storm YAML config.
#'
#' YAML scalars/maps don't preserve R types like POSIXct, sf bbox, or tibble,
#' so this loader reconstructs them. Returns a named list with the same shape
#' the per-storm/viz tar_targets below expect.
#'
#' @param path Path to the storm YAML file.
#' @return A named list ready for downstream `p0_storm_cfg$<field>` access.
load_storm_config <- function(path) {
  cfg <- read_yaml(path)
  validate_storm_config(cfg)

  # Coerce logical fields strictly so a typo errors here, not in the viz phase.
  cfg$flood_spike <- parse_config_logical(cfg$flood_spike, "flood_spike")
  cfg$precip_grayscale <- parse_config_logical(cfg$precip_grayscale,
                                               "precip_grayscale")

  cfg$landfall_time <- as.POSIXct(cfg$landfall_time, tz = "UTC")

  # Optional: hides the storm track/hurricane symbol until this time
  if (!is.null(cfg[["storm_track_start_time"]])) {
    cfg$storm_track_start_time <- as.POSIXct(cfg$storm_track_start_time, tz = "UTC")
  }

  cfg$bbox <- st_bbox(c(xmin = cfg$bbox$xmin, xmax = cfg$bbox$xmax, ymin = cfg$bbox$ymin, ymax = cfg$bbox$ymax))

  # as_tibble() rejects NULL columns, but the template allows e.g.
  # stn_event: ~ for storms with no STN rapid-deployment gage data.
  cfg$storm_info <- as_tibble(lapply(cfg$storm_info,
                                     function(x) if (is.null(x)) NA else x))
  cfg$viz_config <- as_tibble(cfg$viz_config)
  cfg$viz_config_social <- as_tibble(cfg$viz_config_social)

  cfg$anchors <- lapply(cfg$anchors, function(a) as.numeric(unlist(a)))
  cfg$anchors_social <- lapply(cfg$anchors_social, function(a) as.numeric(unlist(a)))

  # Optional city override: list of name/state maps -> tibble (NULL if absent).
  # Use [["cities"]] not $cities: $ partial-matches the `cities_n` key.
  if (!is.null(cfg[["cities"]])) {
    cfg$cities <- bind_rows(lapply(cfg[["cities"]], as_tibble))
  }

  # Named-map palettes -> named character vector
  cfg$pal_fs_blue <- unlist(cfg$pal_fs_blue)
  cfg$pal_fs_red <- unlist(cfg$pal_fs_red)
  # Sequence palettes -> unnamed character vector
  cfg$pal_percentile <- unlist(cfg$pal_percentile)
  cfg$pal_precip_blue <- unlist(cfg$pal_precip_blue)
  cfg$pal_precip_grayscale <- unlist(cfg$pal_precip_grayscale)

  cfg
}

p0_targets <- list(

  # Storm config dispatch
  tar_target(p0_storm_cfg_file, "config/isaias.yml", format = "file"),
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
  tar_target(p0_cities_n, p0_storm_cfg$cities_n),
  tar_target(p0_cities_override, p0_storm_cfg[["cities"]]),
  # Optional: overrides the auto-picked Instagram cover image.
  tar_target(p0_cover_image_path, p0_storm_cfg[["cover_image_path"]]),
  # Optional: Instagram legend card row positions/sizing.
  tar_target(p0_legend_card_cfg, p0_storm_cfg[["legend_card"]]),
  # Optional: hides the storm track until this time (see load_storm_config()).
  tar_target(p0_storm_track_start_time, p0_storm_cfg[["storm_track_start_time"]]),

  # Viz leaves
  tar_target(p0_viz_fs_config_pal_blue, p0_storm_cfg$pal_fs_blue),
  tar_target(p0_viz_fs_config_pal_red, p0_storm_cfg$pal_fs_red),
  tar_target(p0_viz_percentile_config_pal, p0_storm_cfg$pal_percentile),
  tar_target(p0_viz_precip_config_pal_blue, p0_storm_cfg$pal_precip_blue),
  tar_target(p0_viz_precip_config_pal_grayscale, p0_storm_cfg$pal_precip_grayscale),
  tar_target(p0_precip_grayscale_var, p0_storm_cfg$precip_grayscale),
  tar_target(p0_flood_spike_var, p0_storm_cfg$flood_spike),
  tar_target(p0_viz_config_df, p0_storm_cfg$viz_config),
  tar_target(p0_viz_anchors, p0_storm_cfg$anchors),
  tar_target(p0_viz_config_social_df, p0_storm_cfg$viz_config_social),
  tar_target(p0_viz_anchors_social, p0_storm_cfg$anchors_social),

  # Derived from per-storm values (precip/NWIS times in UTC to match precip)
  tar_target(p0_precip_bbox, unname(as.list(p0_bbox_sf))),
  tar_target(p0_precip_start, paste0(p0_date_start, "T00")),
  tar_target(p0_precip_end, paste0(p0_date_end, "T23")),
  tar_target(p0_nwis_start, paste0(p0_date_start, "T00:00Z")),
  tar_target(p0_nwis_end, paste0(p0_date_end, "T23:00Z"))
)
