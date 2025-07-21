source('2_process/src/process_precip.R')
source('2_process/src/process_states.R')

p2_targets <- list(

# process flood data -----------------------------------------------------
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
      if(p2_uv_sites == unique(p2_uv_data_df$site_no)[1]){
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
    {
      inst_data <- p2_uv_data_percentiles_df
      
      # Identify all value and code columns
      value_columns <- names(inst_data)[grepl("^X_", names(inst_data)) & !grepl("_cd$", names(inst_data))]
      code_columns <- names(inst_data)[grepl("^X_", names(inst_data)) & grepl("_cd$", names(inst_data))]
      
      if (nrow(inst_data) > 0) {
        inst_data_long <- inst_data |>
          mutate(across(all_of(value_columns), as.numeric),
                 across(all_of(code_columns), as.character)) |>
          pivot_longer(
            cols = all_of(value_columns),
            names_to = "pcode_col",
            values_to = "value",
            values_drop_na = TRUE
          ) |>
          mutate(
            parameter = ifelse(grepl("00060", pcode_col), "discharge", "gage_height"),
            utc_hour = lubridate::floor_date(dateTime, unit = "hour")
          ) |>
          select(site_no, agency_cd, dateTime, utc_hour, parameter, value)
        
        # max gage height per site & hour
        max_gage_dt <- inst_data_long |>
          filter(parameter == "gage_height") |>
          group_by(site_no, utc_hour) |>
          slice_max(value, with_ties = TRUE) |>
          slice_max(dateTime, with_ties = FALSE) |>
          ungroup() |>
          select(site_no, dateTime)
        
        # join back to get both gage height and discharge
        inst_data_max <- max_gage_dt |>
          left_join(inst_data_long, by = c("site_no", "dateTime")) |>
          group_by(site_no, dateTime, parameter) |>
          slice_max(value, with_ties = FALSE) |>
          ungroup()
        
        # wide and join percentile
        inst_data_wide <- inst_data_max |>
          pivot_wider(
            id_cols = c(site_no, dateTime),
            names_from = parameter,
            values_from = value,
            values_fill = list(value = NA)
          ) |>
          left_join(
            inst_data |> select(site_no, agency_cd, dateTime, percentile),
            by = c("site_no", "dateTime")
          ) |>
          mutate(
            utc_hour = lubridate::floor_date(dateTime, unit = "hour")
          ) |>
          select(site_no, agency_cd, dateTime, utc_hour,
                 X_00065_00000 = gage_height,
                 X_00060_00000 = discharge,
                 percentile)
      } else {
        # fallback if input is empty
        tibble()
      }
    }
  ),
  # Merge together uv percentiles with flood stages and peak data
  tar_target(
    p2_flow_height_complete_df,
    {
      out <- p2_uv_data_percentiles_df |>
        left_join(p1_usgs_flood_stage_gages, by = "site_no") |>
        left_join(p2_peak_data_max_df, by = c("site_no", "agency_cd")) |>
        filter(lubridate::minute(dateTime) == 0, lubridate::second(dateTime) == 0) |>  # Keep full hours only, since animation timestep is 1 hour
        mutate(dateTime = lubridate::floor_date(dateTime, unit = "hour"),
               dateTime = lubridate::with_tz(dateTime, tzone = p0_timezone)
               ) |> 
        select(
          site_no, dateTime, X_00060_00000, X_00065_00000,
          percentile, action.stage, flood.stage, moderate.flood.stage, major.flood.stage, 
          peak_va, peak_cd, peak_dateTime, geometry
        ) |>
        distinct()
    }
  ),
  
# process precipitation data ----------------------------------------------
  tar_target(p2_process_precip_rast,
             get_precip_df(
               tif_files = p1_precip_tifs,
               proj = p0_proj,
               precip_summ = "cumulative",
               states = p1_conus_bbox_crop_sf,
               desired_timezone = p0_timezone)
             
  ),
  tar_target(p2_state_inner_lines,
             get_inner_lines(
               in_sf = p1_conus_bbox_crop_sf
             )
             ),
tar_target(p2_bbox_outer_lines,
           get_outer_lines(
             in_sf = p1_conus_bbox_crop_sf
           )
)
)