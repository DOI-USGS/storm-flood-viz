p0_targets <- list(
  tar_target(
    p0_flood_stage_url,
    "https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv"
    ),
  # Must be defined using NAD83 ("EPSG:4269") coordinates in decimal degrees
  # Note: when bbox area changes, downstread `plot_shift_x`, `plot_shift_y`,
  # `plot_width`, `plot_height` will likely need to be adjusted in 
  # `p0_viz_config_df` below
  tar_target(
    p0_bbox_sf,
    sf::st_bbox(c(xmin = -98.21, xmax = -69.97, ymin = 23, ymax = 44.6))
    ),
  # Select appropriate projection for the area of interest within the bounding box
  tar_target(
    # Southeastern U.S. focus projection 
    p0_proj,
    "+proj=aea +lat_0=23 +lon_0=-84 +lat_1=30 +lat_2=37 +x_0=0 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs"
    ),
  tar_target(
    p0_date_start,
    "2024-09-24"
  ),
  tar_target(
    p0_date_end,
    "2024-09-29"
  ),
  tar_target(
    p0_storm_info,
    tibble(storm_name = "HELENE",
           storm_code = "al092024",
           storm_buffer = 250000,
           shape_type = "buffered_storm_track",
           storm_best_track_url = "https://www.nhc.noaa.gov/gis/best_track/",
           # Can find code by looking at REST URLs here: https://stn.wim.usgs.gov/STNDataPortal/#
           stn_event = 346)
    ),
  tar_target(
    p0_pcodes,
    c("00060", "00065")
  ),
  # Set precipitation bbox and dates
  tar_target(p0_precip_bbox,
             unname(as.list(p0_bbox_sf))),
  # Set precipitation start and end time
  # Note: these must be defined in UTC time
  tar_target(
    p0_precip_start,
    paste0(p0_date_start, "T00")
    ),
  tar_target(
    p0_precip_end,
    paste0(p0_date_end, "T23")
    ),
  # Desired timezone for map display
  # For refernce: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  # Note: all data processing/fetching is done in UTC timezone, timezone edits for  
  # local desired timezone are only done in final mapping step `mapping_utils.R`
  tar_target(p0_timezone,
             "America/New_York"
             ),
  tar_target(p0_timezone_abv,
             "ET"),
  # Set time for storm landfall to add countdown to landfall
  # For Helene, this was noted from https://en.wikipedia.org/wiki/Hurricane_Helene 
  tar_target(
    p0_landfall_time,
    as.POSIXct("2024-09-27 03:00:00", tz = "UTC")
  ),
  tar_target(
    # Create a tibble to define color palette for flood stage
    p0_viz_fs_config_pal_blue,
    c(
      "Not flooded" = "#dcdcdc",
      "Flood" = "#4ecad7",
      "Moderate" = "#17718E",
      "Major" = "#003e6a"
    )
  ),
  tar_target(
    # Create a tibble to define color palette for flood stage
    p0_viz_fs_config_pal_red,
    c(
      "Not flooded" = "#dcdcdc",
      "Flood" = "#e5a000",
      "Moderate" = "#F7513B",
      "Major" = "#C917E8"
    )
  ), 
  tar_target(
    # Create a tibble to define color palette for percentile
    p0_viz_percentile_config_pal,
    c("#8c2d04", "#cc9e02", "#fee391", 
      "#C0C0C0", "#80cdc1", "#35978f", "#045a8d")
    ),
  tar_target(
    p0_viz_precip_config_pal_blue,
    c("#c7f0f6", "#92dce5", "#5fc8d1", "#38b1bc", "#259db0", "#1b88a1", "#16738c")
    ),
  tar_target(
    p0_viz_precip_config_pal_grayscale,
    c("#E6E6E6", "#CBCBCB", "#B6B6B6", "#A6A6A6", "#979797", "#858585", "#6D6D6D")
    ),
  # Set up TRUE/FALSE statement for variables wanted on on or off for viz
  # FALSE = colorized precipitation
  # TRUE = grayscale precipitation
  tar_target(
    p0_precip_grayscale_var,
    "FALSE"
  ),
  # FALSE = sized flooded points
  # TRUE = sized flooded spike
  tar_target(
    p0_flood_spike_var,
    "TRUE"
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
      progress_bar_col = "gray45",
      x_mark = "black",
      load_font = 'Source Sans Pro',
      font_size_title = 16,
      font_size = 14,
      leg_font_size = 12,
      # Note: these vals are relative to the 0-1 canvas limits & 
      # adjust these parameters when bbox area is adjusted
      plot_margin = 0.025,
      plot_shift_x = -0.18,
      plot_shift_y = -0.212,
      plot_width = 1.39,
      plot_height = 1.6
    )
  )
)