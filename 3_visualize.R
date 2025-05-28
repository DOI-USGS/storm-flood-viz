#source('3_visualize/src/plot_utils.R')
source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  tar_target(p3_percentile_hourly_gif,
             hurricane_viz(
               precip_data = p2_process_precip_rast,
               flow_data = p2_flow_height_complete_df,
               storm_path = p1_storm_track_pts_sf,
               state_borders = p1_conus_bbox_crop_sf,
               major_cities = p1_major_cities_sf, 
               path_out = "3_visualize/out/hurricane_percentile_animation.gif",
               metric = "percentile"),
             format = "file"
             ) ,
  tar_target(p3_flood_stage_hourly_gif,
             hurricane_viz(
               precip_data = p2_process_precip_rast,
               flow_data = p2_flow_height_complete_df,
               storm_path = p1_storm_track_pts_sf,
               state_borders = p1_conus_bbox_crop_sf,
               major_cities = p1_major_cities_sf,
               path_out = "3_visualize/out/hurricane_flood_stage_animation.gif",
               metric = "flood_stage"),
             format = "file"
             )
)
