#source('3_visualize/src/plot_utils.R')
source('3_visualize/src/mapping_utils.R')
source('3_visualize/src/title_end_frame.R')

p3_targets <- list(
  # Subset hurricane track by timestep
  tar_target(
    p3_storm_by_time,
    {
      filter(p1_storm_track_pts_sf, DTG <= p2_all_precip_timestamps)
    },
    pattern = map(p2_all_precip_timestamps),
    iteration = "list"
  ),
  # Subset precipitation raster by timestep
  tar_target(
    p3_precip_by_time,
    filter(p2_process_precip_rast, dateTime <= p2_all_precip_timestamps),
    pattern = map(p2_all_precip_timestamps),
    iteration = "list"
  ),
  # Subset rapid deployment gage sf by timestep
  tar_target(
    p3_rdg_by_time,
    {
      filter(p1_rapid_dep_gages, dateTime <= p2_all_precip_timestamps)
    },
    pattern = map(p2_all_precip_timestamps),
    iteration = "list"
  ),
  # Global max precip to add to precip legend limit
  tar_target(
    p3_global_max_precip_in,
    round(max(p2_process_precip_rast$precip_in, na.rm = TRUE))
  ),
  # Build flood stage animation
  tar_target(
    p3_flood_stage_frames,
    hurricane_flood_stage_frames(
      dtg = p2_all_precip_timestamps,
      precip_now = p3_precip_by_time,
      global_max_precip = p3_global_max_precip_in,
      global_max_flood_stages = p2_global_max_flooded,
      flow_now = p2_flow_by_time,
      storm_now = p3_storm_by_time,
      rdg_now = p3_rdg_by_time,
      storm_info = p0_storm_info,
      progress_fraction = p2_progress_fract,
      bbox_coords = p1_bbox_coords,
      state_borders = p1_conus_bbox_crop_sf,
      state_inner_borders = p2_state_inner_lines,
      state_outer_lines = p2_bbox_outer_lines,
      major_cities = p1_major_cities_sf,
      flood_stage_cols_blue = p0_viz_fs_config_pal_blue,
      flood_stage_cols_red = p0_viz_fs_config_pal_red,
      precip_grayscale = p0_precip_grayscale_var,
      # points vs spikes viz 
      flood_spikes = p0_flood_spike_var,
      points_range = c(2, 10),
      timezone_long = p0_timezone,
      precip_cols = p0_viz_precip_config_pal_blue,
      precip_grayscale_cols = p0_viz_precip_config_pal_grayscale,
      config_vars = p0_viz_config_df,
      peak_height = 200000,
      y_baseheight = 10000,
      global_max_duration = p2_global_max_flood_duration,
      landfall_dtg = p0_landfall_time,
      target_rdg_icon = "3_visualize/in/bullseye.png",
      logo_path = '3_visualize/in/usgs_logo_black.png',
      hurricane_symbol_path = "3_visualize/in/hurricane_symbol.png",
      flood_stage_spike_leg_path = "3_visualize/in/custom_flood_stage_spike_leg_percentile.png",
      flood_stage_point_leg_path = "3_visualize/in/custom_flood_stage_point_leg_percentile.png",
      frame_spike_dir = sprintf("3_visualize/out/flood_stage_%s_spike_frames",
                          tolower(p0_storm_info$storm_name)),
      frame_point_dir = sprintf("3_visualize/out/flood_stage_%s_point_frames",
                                tolower(p0_storm_info$storm_name))
    ),
    pattern = map(p2_all_precip_timestamps, p3_precip_by_time, p2_flow_by_time,
                  p3_storm_by_time, p2_progress_fract, p3_rdg_by_time),
    format = "file"
  ),
  tar_target(
    p3_title_frame_png,
    title_frame(title_text_line1 = sprintf("Hurricane %s", stringr::str_to_sentence(tolower(p0_storm_info$storm_name))),
                title_text_line2 = "Flooding",
                start_date = p0_date_start,
                end_date = p0_date_end,
                logo_path = '3_visualize/in/usgs_logo_black.png',
                frame_bg_path = as.character(p3_flood_stage_frames)[
                  grepl("frame_20240928T0800.png$", p3_flood_stage_frames)
                ],
                config_vars = p0_viz_config_df,
                out_path = if (p0_flood_spike_var) {
                  sprintf("3_visualize/out/flood_stage_%s_spike_frames/frame_00000000000.png",
                          tolower(p0_storm_info$storm_name))
                } else {
                  sprintf("3_visualize/out/flood_stage_%s_point_frames/frame_00000000000.png",
                          tolower(p0_storm_info$storm_name))
                }
  ),
  format = "file"
  ),
  tar_target(
    p3_end_frame_png,
    end_frame(end_text_line1 = "STAY SAFE DURING FLOODS",
              end_text_line2 = sprintf("Learn more about the USGS response to %s at",
                                       stringr::str_to_sentence(tolower(p0_storm_info$storm_name))),
              end_text_line3 = sprintf("www.usgs.gov/%s",
                                       stringr::str_to_sentence(tolower(p0_storm_info$storm_name))),
              logo_path = '3_visualize/in/usgs_logo_black.png',
              config_vars = p0_viz_config_df,
              out_path = if (p0_flood_spike_var) {
                sprintf("3_visualize/out/flood_stage_%s_spike_frames/frame_99999999999.png",
                        tolower(p0_storm_info$storm_name))
                } else {
                  sprintf("3_visualize/out/flood_stage_%s_point_frames/frame_99999999999.png",
                          tolower(p0_storm_info$storm_name))
                  },
              bg_col = p0_viz_precip_config_pal_blue[1]
              ),
    format = "file"
    ),
  tar_target(
    p3_flood_stage_hourly_gif,
    {
      fade_frames     <- 10L  # how smooth/long the fade is
      end_hold_frames <- 4L   # how long to hold the end frame
      fps             <- 2    # frames per second

      title_img    <- magick::image_read(p3_title_frame_png)
      title_frames <- rep(title_img, times = 8L)
      
      valid_paths <- p3_flood_stage_frames[!is.na(p3_flood_stage_frames)]
      valid_paths <- valid_paths[valid_paths != p3_title_frame_png]

      flood_frames <- magick::image_read(valid_paths)
      flood_frames <- magick::image_coalesce(flood_frames)

      # end frame + fade
      end_img <- magick::image_read(p3_end_frame_png)

      last_flood <- flood_frames[length(flood_frames)]
      crossfade  <- magick::image_morph(c(last_flood, end_img), frames = fade_frames)
      end_hold   <- rep(end_img, end_hold_frames)  

      all_frames <- c(title_frames, flood_frames, crossfade, end_hold)
      # coalesce to be safe before animating
      all_frames <- magick::image_coalesce(all_frames)

      gif <- magick::image_animate(all_frames, fps = fps)

      gif_path <- if (p0_flood_spike_var) {
        sprintf("3_visualize/out/%s_flood_stage_spike_animation.gif",
                tolower(p0_storm_info$storm_name))
      } else {
        sprintf("3_visualize/out/%s_flood_stage_point_animation.gif",
                tolower(p0_storm_info$storm_name))
      }

      magick::image_write(gif, gif_path)
      gif_path
    },
    format = "file"
  )
)