p0_targets <- list(
  tar_target(
    p0_flood_stage_url,
    "https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv"
    ),
  # Must be defined using NAD83 ("EPSG:4269") coordinates in decimal degrees
  tar_target(
    p0_bbox_sf,
    sf::st_bbox(c(xmin = -98.21, xmax = -69.97, ymin = 23, ymax = 44.6))
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
    "2024-09-28"
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
    ),
  # Set time for storm landfall to add countdown to landfall
  # For Helene, this was noted from https://en.wikipedia.org/wiki/Hurricane_Helene 
  tar_target(
    p0_landfall_time,
    as.POSIXct("2024-09-27 03:00:00", tz = "UTC")
  ),
  tar_target(
    # Create a tibble to define color palette for flood stage
    p0_viz_fs_config_pal,
    c(
      "Not flooded" = "#d3d3d3",
      "Flood" = "#f4b183",
      "Moderate" = "#d55a60",
      "Major" = "#934141"
      )
    ), 
  tar_target(
    # Create a tibble to define color palette for percentile
    p0_viz_percentile_config_pal,
    c("#8c2d04", "#cc9e02", "#fee391", 
      "#C0C0C0", "#80cdc1", "#35978f", "#045a8d")
    ),
  tar_target(
    p0_viz_precip_config_pal,
    "mako"
    ),
  tar_target(
    # Create a tibble to define fig width and height, conus outline colors,
    # background color, font name, and font size 
    p0_viz_config_df,
    tibble(
      width = 8,
      height = 8,
      dpi = 300, 
      state_outline_col = "white",
      major_cities_col = 'gray60',
      major_cities_text_col = 'gray50',
      streamgage_col = "gray30",
      storm_path_col = "black",
      state_inner_borders_col = "gray85",
      state_outer_lines_col = "gray80",
      bg_col = "white",
      ocean_col = "#f8fcfc",
      progress_bar_bg_col = 'gray80',
      progress_bar_col = "#345EC4",
      load_font = 'Source Sans Pro',
      font_size_title = 16,
      font_size = 14,
      leg_font_size = 12,
      plot_margin = 0.025
    )
  )
)