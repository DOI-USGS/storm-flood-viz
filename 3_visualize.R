#source('3_visualize/src/plot_utils.R')
source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  # Define the precip timestemps
  tar_target(
    p3_all_precip_timestamps,
    sort(unique(p2_process_precip_rast$dateTime))
  ),
  # Subset hurricane track by timestep
  tar_target(
    p3_storm_by_time,
    {
      filter(p1_storm_track_pts_sf, DTG <= p3_all_precip_timestamps)
    },
    pattern = map(p3_all_precip_timestamps),
    iteration = "list"
  ),
  # Subset precipitation raster by timestep
  tar_target(
    p3_precip_by_time,
    filter(p2_process_precip_rast, dateTime <= p3_all_precip_timestamps),
    pattern = map(p3_all_precip_timestamps),
    iteration = "list"
  ),
  # Subset flow data and calculate cumulative flood duration
  tar_target(
    p3_flow_by_time,
    {
      p2_flow_height_complete_df |>
        filter(dateTime <= p3_all_precip_timestamps) |>
        group_by(site_no) |>
        arrange(site_no, dateTime) |>
        mutate(
          above_flood = !is.na(flood.stage) & X_00065_00000 >= flood.stage,
          duration_above_flood_hr = cumsum(above_flood)
        ) |>
        ungroup() |>
        filter(dateTime == p3_all_precip_timestamps) |>
        mutate(
          flood_status = case_when(
            !is.na(major.flood.stage) & X_00065_00000 >= major.flood.stage ~ "Major",
            !is.na(moderate.flood.stage) & X_00065_00000 >= moderate.flood.stage ~ "Moderate",
            !is.na(flood.stage) & X_00065_00000 >= flood.stage ~ "Flood",
            TRUE ~ "Not flooded"
          ),
          flood_status = factor(flood_status, levels = c("Not flooded", "Flood", "Moderate", "Major")),
          is_flooded = flood_status != "Not flooded"
        )
    },
    pattern = map(p3_all_precip_timestamps),
    iteration = "list"
  ),
  # Build flood stage animation
  tar_target(
    p3_flood_stage_frames,
    hurricane_flood_stage_frame(
      dtg = p3_all_precip_timestamps,
      precip_now = p3_precip_by_time,
      flow_now = p3_flow_by_time,
      storm_now = p3_storm_by_time,
      state_borders = p1_conus_bbox_crop_sf,
      state_inner_borders = p2_state_inner_lines,
      state_outer_lines = p2_bbox_outer_lines,
      major_cities = p1_major_cities_sf,
      flood_stage_cols = p0_viz_fs_config_pal,
      percip_cols = p0_viz_precip_config_pal,
      config_vars = p0_viz_config_df,
      peak_height = 250000,
      logo_path = '3_visualize/in/usgs_logo_black.png',
      frame_dir = "3_visualize/out/flood_stage_frames" 
    ),
    pattern = map(p3_all_precip_timestamps, p3_precip_by_time, p3_flow_by_time, p3_storm_by_time)
  ),
  tar_target(
    p3_flood_stage_hourly_gif,
    {
      valid_paths <- p3_flood_stage_frames[!is.na(p3_flood_stage_frames)]
      img_list <- magick::image_read(valid_paths)
      gif <- magick::image_animate(magick::image_join(img_list), fps = 2)
      gif_path <- "3_visualize/out/hurricane_flood_stage_animation.gif"
      magick::image_write(gif, gif_path)
      gif_path
    },
    format = "file"
  )
)
