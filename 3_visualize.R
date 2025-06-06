#source('3_visualize/src/plot_utils.R')
source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  tar_target(p3_percentile_hourly_gif,
             hurricane_viz(
               metric = "percentile",
               precip_data = p2_process_precip_rast,
               flow_data = p2_flow_height_complete_df,
               storm_path = p1_storm_track_pts_sf,
               state_borders = p1_conus_bbox_crop_sf,
               state_inner_borders = p2_state_inner_lines,
               major_cities = p1_major_cities_sf, 
               percentile_cols = p0_viz_percentile_config_pal,
               flood_stage_cols = p0_viz_fs_config_pal,
               percip_cols = p0_viz_precip_config_pal,
               config_vars = p0_viz_config_df,
               peak_height = 250000,
               path_out = "3_visualize/out/hurricane_percentile_animation.gif"
               ),
             format = "file"
             ) ,
  tar_target(p3_flood_stage_hourly_gif,
             hurricane_viz(
               metric = "flood_stage",
               precip_data = p2_process_precip_rast,
               flow_data = p2_flow_height_complete_df,
               storm_path = p1_storm_track_pts_sf,
               state_borders = p1_conus_bbox_crop_sf,
               state_inner_borders = p2_state_inner_lines, 
               major_cities = p1_major_cities_sf,
               percentile_cols = p0_viz_percentile_config_pal,
               flood_stage_cols = p0_viz_fs_config_pal,
               percip_cols = p0_viz_precip_config_pal,
               config_vars = p0_viz_config_df,
               peak_height = 250000,
               path_out = "3_visualize/out/hurricane_flood_stage_animation.gif"
               ),
             format = "file"
             )
)
