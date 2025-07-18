#source('3_visualize/src/plot_utils.R')
source('3_visualize/src/mapping_utils.R')
source('3_visualize/src/title_frame.R')

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
  # Global max precip to add to precip legend limit
  tar_target(
    p3_global_max_precip_in,
    round(max(p2_process_precip_rast$precip_in, na.rm = TRUE))
  ),
  # Global max flood stages to flood stage dynamic barplot x-limit
  tar_target(
    p3_global_max_flooded,
    max(vapply(p3_flow_by_time,
               function(tbl) {
                 sum(tbl$flood_status %in% c("Flood","Moderate", "Major"), na.rm = TRUE)
               },
               FUN.VALUE = integer(1)
               )
        )
    ), 
  tar_target(
    p3_flow_by_time,
    {
      p2_flow_height_complete_df |>
        filter(dateTime <= p3_all_precip_timestamps) |>
        group_by(site_no) |>
        arrange(site_no, dateTime) |>
        mutate(
          above_flood = !is.na(flood.stage) & X_00065_00000 >= flood.stage,
          duration_above_flood_hr = ifelse(above_flood, cumsum(above_flood), NA)
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
          is_flooded = above_flood
        )
    },
    pattern = map(p3_all_precip_timestamps),
    iteration = "list"
  ),
  # Caclulate global max duration above flood stage across all timesteps
  # to apply to map flood peaks 
  tar_target(
    p3_global_max_flood_duration,
    {
      p3_flow_by_time |>
        purrr::map_dbl(~ max(.x$duration_above_flood_hr, na.rm = TRUE)) |>
        max(na.rm = TRUE)
    }
  ),
  # progress bar targets
  tar_target(
    p3_min_timestamp,
    p3_all_precip_timestamps[[1]]
  ),
  tar_target(
    p3_precip_duration,
    as.double(p3_all_precip_timestamps[[length(p3_all_precip_timestamps)]] -
                p3_min_timestamp, 
              units = "hours")
  ),
  tar_target(
    p3_progress_fract,
    {
      hours_since_start <- as.double(p3_all_precip_timestamps - 
                                       p3_min_timestamp, 
                                     units = "hours")
      progress_fraction <- hours_since_start / p3_precip_duration
      progress_fraction
    },
    pattern = map(p3_all_precip_timestamps),
    iteration = "list"
  ),
  # Build flood stage animation
  tar_target(
    p3_flood_stage_spike_frames,
    hurricane_flood_stage_spike_frames(
      dtg = p3_all_precip_timestamps,
      precip_now = p3_precip_by_time,
      global_max_precip = p3_global_max_precip_in,
      global_max_flood_stages = p3_global_max_flooded, 
      flow_now = p3_flow_by_time,
      storm_now = p3_storm_by_time,
      storm_info = p0_storm_info,
      progress_fraction = p3_progress_fract,
      state_borders = p1_conus_bbox_crop_sf,
      state_inner_borders = p2_state_inner_lines,
      state_outer_lines = p2_bbox_outer_lines,
      major_cities = p1_major_cities_sf,
      flood_stage_cols_blue = p0_viz_fs_config_pal_blue,
      flood_stage_cols_red = p0_viz_fs_config_pal_red,
      precip_grayscale = FALSE,
      timezone_abv = p0_timezone_abv,
      precip_cols = p0_viz_precip_config_pal,
      precip_grayscale_cols = p0_viz_grayscale_precip, 
      config_vars = p0_viz_config_df,
      peak_height = 200000,
      global_max_duration = p3_global_max_flood_duration,
      landfall_dtg = p0_landfall_time, 
      logo_path = '3_visualize/in/usgs_logo_black.png',
      hurricane_symbol_path = "3_visualize/in/hurricane_symbol.png",
      flood_stage_leg_path = "3_visualize/in/custom_flood_stage_leg.png", 
      frame_dir = "3_visualize/out/flood_stage_heline_spike_frames" 
    ),
    pattern = map(p3_all_precip_timestamps, p3_precip_by_time, p3_flow_by_time,
                  p3_storm_by_time, p3_progress_fract),
    format = "file"
  ),
  tar_target(
    p3_title_spike_frame_png,
    title_frame(title_text_line1 = "Hurricane Helene",
                title_text_line2 = "Flooding",
                start_date = p0_date_start,
                end_date = p0_date_end,
                logo_path = '3_visualize/in/usgs_logo_black.png',
                frame_bg_path = as.character(p3_flood_stage_spike_frames)[
                  grepl("frame_20240928T0800.png$", p3_flood_stage_spike_frames)
                ],
                config_vars = p0_viz_config_df,
                out_path = "3_visualize/out/flood_stage_heline_spike_frames/frame_00000000000.png")
  )
  # tar_target(
  #   p3_flood_stage_hourly_spike_gif,
  #   {
  #     title_img <- magick::image_read(p3_title_spike_frame_png)
  #     title_frames <- rep(list(title_img), times = 5)
  #     valid_paths <- p3_flood_stage_spike_frames[!is.na(p3_flood_stage_spike_frames)]
  #     valid_paths <- valid_paths[valid_paths != p3_title_spike_frame_png]
  #     flood_frames <- magick::image_read(valid_paths)
  #     all_frames <- magick::image_join(c(title_frames, flood_frames))
  #     gif <- magick::image_animate(all_frames, fps = 2)
  #     gif_path <- "3_visualize/out/helene_flood_stage_spike_animation.gif"
  #     magick::image_write(gif, gif_path)
  #     gif_path
  #   },
  #   format = "file"
  # )
)
