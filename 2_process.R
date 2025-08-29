source("2_process/src/process_precip.R")
source("2_process/src/process_states.R")
source("2_process/src/process_hourly_max_uv.R")
p2_targets <- list(

  # Process flood data -----------------------------------------------------
  # Load in uv data df
  tar_target(
    p2_uv_data_df,
    arrow::read_parquet(p1_uv_data_pqt)
  ),
  # Make list of sites to run through the percentiles calculations
  tar_target(
    p2_uv_sites,
    unique(p2_uv_data_df$site_no)
  ),
  # Branch over site ids to generate percentiles and place in single df
  # of uv data
  tar_target(
    p2_uv_data_percentiles_df,
    {
      # Make this target dependent upon the hyswap python file
      p1_hyswap_py_file

      # Print message about time to run
      if (p2_uv_sites == unique(p2_uv_data_df$site_no)[1]) {
        print("This branching step may take a while (~30 minutes)")
      }

      calculate_uv_percentiles_from_dv(p2_uv_sites, p2_uv_data_df, pcode = "00060")
    },
    pattern = map(p2_uv_sites)
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
  # Get hourly max uv values
  tar_target(
    p2_uv_hourly_max_df,
    get_hourly_max_uv(
      inst_data = p2_uv_data_percentiles_df,
      value_cols_regex = "^X_",
      hour_unit = "hour",
      pcode_param_map = c("00060" = "discharge", "00065" = "gage_height")
    )
  ),
  # Merge together uv percentiles with flood stages and peak data
  tar_target(
    p2_flow_height_complete_df,
    {
      # Keep geometry per site
      site_geom <- p1_usgs_flood_stage_gages |> 
        select(site_no, geometry) |> 
        distinct(site_no, .keep_all = TRUE)

      min_datetime <- min(p2_uv_data_percentiles_df[["dateTime"]])
      max_datetime <- max(p2_uv_data_percentiles_df[["dateTime"]])
      
      out <- p2_uv_data_percentiles_df |> 
        mutate(
          date = lubridate::date(dateTime),
          hour = lubridate::hour(dateTime),
          dateTime = lubridate::floor_date(dateTime, "hour"),
          .after = "dateTime"
        ) |> 
        group_by(site_no, date, hour) |> 
        slice_max(X_00065_00000, n = 1, with_ties = FALSE) |> 
        group_by(site_no) |> 
        complete(
          dateTime = seq(
            floor_date(min_datetime, "hour"),
            floor_date(max_datetime, "hour"),
            by = "1 hour"
          )
        ) |> 
        fill(agency_cd, .direction = "downup") |>
        ungroup() |> 
        # Add in stage data
        left_join(p1_usgs_flood_stage_gages, by = "site_no") |>  
        # Add in peaks data
        left_join(p2_peak_data_max_df, by = c("site_no", "agency_cd")) |> 
        select(
          site_no, dateTime, X_00060_00000, X_00065_00000,
          percentile, action.stage, flood.stage, moderate.flood.stage, major.flood.stage,
          peak_va, peak_cd, peak_dateTime, geometry
        )
      
      # Flag only rows that are part of 4+ consecutive NA runs for X_00065_00000
      out <- out |> 
        arrange(site_no, dateTime) |> 
        group_by(site_no) |> 
        mutate(
          na_flag = is.na(X_00065_00000),
          has_data_elsewhere = any(!na_flag),
          # unique identifier that increments every time a variable changes
          run_id  = dplyr::consecutive_id(na_flag)      
        ) |> 
        group_by(site_no, run_id) |> 
        mutate(run_length = dplyr::n()) |> 
        ungroup() |> 
        mutate(is_decommissioned = has_data_elsewhere & na_flag & run_length >= 4) |> 
        select(-na_flag, -run_id, -run_length, -has_data_elsewhere)
    }
  ),
  # Process precipitation data ----------------------------------------------
  tar_target(
    p2_process_precip_rast,
    get_precip_df(
      tif_files = p1_precip_tifs,
      proj = p0_proj,
      precip_summ = "cumulative",
      states = p1_conus_bbox_crop_sf
    )
  ),
  tar_target(
    p2_state_inner_lines,
    get_inner_lines(
      in_sf = p1_conus_bbox_crop_sf
    )
  ),
  tar_target(
    p2_bbox_outer_lines,
    get_outer_lines(
      in_sf = p1_conus_bbox_crop_sf
    )
  )
)
