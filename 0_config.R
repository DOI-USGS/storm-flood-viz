p0_targets <- list(
  tar_target(
    p0_flood_stage_url,
    "https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv"
    ),
  # Must be defined using NAD83 ("EPSG:4269") coordinates in decimal degrees
  tar_target(
    p0_bbox_sf,
    sf::st_bbox(c(xmin = -92, xmax = -80, ymin = 23, ymax = 45))
    ),
  # Select appropriate projection for the area of interest within the bounding box
  tar_target(
    p0_proj,
    'EPSG:3086'
    ),
  tar_target(
    p0_date_start,
    "2024-09-24"
  ),
  tar_target(
    p0_date_end,
    "2024-10-01"
  ),
  tar_target(
    p0_storm_info,
    tibble(storm_name = "HELENE",
           storm_code = "al092024",
           storm_buffer = 250000,
           shape_type = "buffered_storm_track",
           storm_best_track_url = "https://www.nhc.noaa.gov/gis/best_track/")
    ),
  tar_target(
    p0_pcodes,
    c("00060", "00065")
  ),
  # Set precipitation bbox and dates
  tar_target(p0_precip_bbox,
             unname(as.list(p0_bbox_sf))),
  tar_target(
    p0_precip_start,
    paste0(p0_date_start, "T00")
    ),
  tar_target(
    p0_precip_end,
    paste0(p0_date_end, "T23")
    )
)