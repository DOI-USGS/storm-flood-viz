source('3_visualize/src/builders/build_progress_bar.R')
source('3_visualize/src/builders/build_basemap.R')
source('3_visualize/src/builders/build_storm_track.R')
source('3_visualize/src/builders/build_rdg_layer.R')
source('3_visualize/src/builders/build_precip_layer.R')
source('3_visualize/src/builders/build_flood_layer.R')
source('3_visualize/src/builders/build_cities_layer.R')
source('3_visualize/src/builders/build_legends.R')
source('3_visualize/src/mapping_utils.R')
source('3_visualize/src/title_end_frame.R')
source('3_visualize/src/video_utils.R')

p3_targets <- list(
  # One symbolic name for the layer style ("spike" or "point")
  tar_target(p3_layer, if (p0_flood_spike_var) "spike" else "point"),
  # Storm slug used across many file paths
  tar_target(p3_storm_slug, tolower(p0_storm_info$storm_name)),
  # Per-frame PNG directory — single source of truth
  tar_target(
    p3_frame_dir,
    sprintf("3_visualize/out/flood_stage_%s_%s_frames", p3_storm_slug, p3_layer)
  ),
  # Final mp4 output path
  tar_target(
    p3_mp4_path,
    sprintf("3_visualize/out/%s_flood_stage_%s_animation.mp4", p3_storm_slug, p3_layer)
  ),
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
    filter(p2_process_precip_rast, dateTime == p2_all_precip_timestamps),
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
  # Build flood stage animation frames
  tar_target(
    p3_flood_stage_frames,
    hurricane_flood_stage_frames(
      dtg = p2_all_precip_timestamps,
      precip_now = p3_precip_by_time,
      global_max_precip = p3_global_max_precip_in,
      global_max_flood_stages = p2_global_flow_maxes$max_flooded,
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
      points_range = c(2, 6),
      timezone_long = p0_timezone,
      precip_cols = p0_viz_precip_config_pal_blue,
      precip_grayscale_cols = p0_viz_precip_config_pal_grayscale,
      config_vars = p0_viz_config_df,
      peak_height = 200000,
      y_baseheight = 10000,
      global_max_duration = p2_global_flow_maxes$max_duration,
      landfall_dtg = p0_landfall_time,
      target_rdg_icon = "3_visualize/in/bullseye.png",
      logo_path = '3_visualize/in/usgs_logo_black.png',
      hurricane_symbol_path = "3_visualize/in/hurricane_symbol.png",
      flood_stage_spike_leg_path = "3_visualize/in/custom_flood_stage_spike_leg_percentile.png",
      flood_stage_point_leg_path = "3_visualize/in/custom_flood_stage_point_leg_percentile.png",
      frame_dir = p3_frame_dir
    ),
    pattern = map(p2_all_precip_timestamps, p3_precip_by_time, p2_flow_by_time,
                  p3_storm_by_time, p2_progress_fract, p3_rdg_by_time),
    format = "file"
  ),
  tar_target(
    p3_title_frame_png,
    title_frame(
      title_text_line1 = sprintf("Hurricane %s", stringr::str_to_sentence(p3_storm_slug)),
      title_text_line2 = "Flooding",
      start_date = p0_date_start,
      end_date = p0_date_end,
      logo_path = '3_visualize/in/usgs_logo_black.png',
      frame_bg_path = as.character(p3_flood_stage_frames)[
        grepl("frame_20240928T0800.png$", p3_flood_stage_frames)
      ],
      config_vars = p0_viz_config_df,
      out_path = file.path(p3_frame_dir, "frame_00000000000.png")
    ),
    format = "file"
  ),
  tar_target(
    p3_end_frame_png,
    end_frame(
      end_text_line1 = "STAY SAFE DURING FLOODS",
      end_text_line2 = sprintf("Learn more about the USGS response to %s at",
                               stringr::str_to_sentence(p3_storm_slug)),
      end_text_line3 = sprintf("www.usgs.gov/%s", stringr::str_to_sentence(p3_storm_slug)),
      logo_path = '3_visualize/in/usgs_logo_black.png',
      config_vars = p0_viz_config_df,
      out_path = file.path(p3_frame_dir, "frame_99999999999.png"),
      bg_col = p0_viz_precip_config_pal_blue[1]
    ),
    format = "file"
  ),
  tar_target(
    p3_flood_stage_hourly_mp4,
    encode_flood_mp4(
      title_frame_path = p3_title_frame_png,
      flood_frame_paths = p3_flood_stage_frames[!is.na(p3_flood_stage_frames) &
                                                  p3_flood_stage_frames != p3_title_frame_png &
                                                  p3_flood_stage_frames != p3_end_frame_png],
      end_frame_path = p3_end_frame_png,
      output_path = p3_mp4_path,
      fps = 2,
      title_hold = 10L,
      fade_frames = 8L,
      end_hold = 4L
    ),
    format = "file"
  )
)
