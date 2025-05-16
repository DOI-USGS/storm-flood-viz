#source('2_process/src/data_utils.R')

p2_targets <- list(
  # Load in uv data df
  tar_target(
    p2_uv_data_df,
    arrow::read_parquet(p1_uv_data_pqt)
  ),
  # Branch over site ids to generate percentiles and place in single df
  # of uv data
  tar_target(
    p2_uv_data_percentiles_df,
    {
      # Make this target dependent upon the hyswap python file
      p1_hyswap_py_file
      
      # Print message about time to run
      if(p1_uv_sites == unique(p2_uv_data_df$site_no)[1]){
        print("This branching step may take a while (~30 minutes)")
      }
      
      calculate_uv_percentiles_from_dv(p1_uv_sites, p2_uv_data_df, pcode = "00060")
    },
    pattern = map(p1_uv_sites)
  ),
  # Read in peak data and grab max peak value per site, with ties
  # broken using the latest date in the dataset - makes more sense to compare
  # to the most recent peak than an earlier peak that was tied more recently.
  tar_target(
    p2_peak_data_max_df,
    arrow::read_parquet(p1_peak_data_pqt) |>
      group_by(site_no) |>
      slice_max(peak_va) |>
      filter(peak_dt == max(peak_dt)) |>
      ungroup()
  ),
  # Merge together uv percentiles with flood stages and peak data
  tar_target(
    p1_flow_height_complete_df,
    {
      out <- p1_uv_data_percentiles_df |>
        left_join(p1_usgs_flood_stage_gages, by = "site_no") |>
        left_join(p1_peak_data_max_df, by = c("site_no", "agency_cd")) |>
        select(
          site_no, dateTime, X_00060_00000, X_00060_00000_cd, X_00065_00000, X_00065_00000_cd, tz_cd,
          percentile, action.stage, flood.stage, moderate.flood.stage, major.flood.stage, 
          peak_va, peak_cd, peak_dateTime
        ) |>
        distinct()
    }
  )
)