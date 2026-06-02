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
  # Join USGS day-of-year percentile thresholds to uv data and derive a
  # category string. Sites absent from p1_site_stats_pqt (< 20 yr POR)
  # receive percentile = NA and are excluded from percentile viz layers.
  tar_target(
    p2_uv_data_percentiles_df,
    {
      thresholds <- arrow::read_parquet(p1_site_stats_pqt)
      p2_uv_data_df |>
        mutate(time_of_year = format(dateTime, "%m-%d")) |>
        left_join(thresholds, by = c("site_no", "time_of_year")) |>
        mutate(percentile = case_when(
          is.na(X_00060_00000) | is.na(p05) ~ NA_character_,
          X_00060_00000 >= p95 ~ "high",
          X_00060_00000 >= p90 ~ "90-95",
          X_00060_00000 >= p75 ~ "75-90",
          X_00060_00000 >= p25 ~ "25-75",
          X_00060_00000 >= p10 ~ "10-25",
          X_00060_00000 >= p05 ~ "5-10",
          TRUE ~ "low"
        )) |>
        select(-time_of_year, -any_of(c("p05","p10","p25","p50","p75","p90","p95")))
    }
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
        # Add flood stage thresholds (drop geometry — we attach it from all-gage sf below)
        left_join(sf::st_drop_geometry(p1_usgs_flood_stage_gages), by = "site_no") |>
        # Add peaks data
        left_join(p2_peak_data_max_df, by = c("site_no", "agency_cd")) |>
        # Attach geometry for all bbox stream gages (not just flood-stage sites)
        left_join(
          tibble::tibble(
            site_no = p1_bbox_stream_sites_sf$site_no,
            geometry = sf::st_geometry(p1_bbox_stream_sites_sf)
          ),
          by = "site_no"
        ) |>
        sf::st_as_sf(sf_column_name = "geometry") |>
        select(
          site_no, dateTime, X_00060_00000, X_00065_00000,
          percentile, action.stage, flood.stage, moderate.flood.stage, major.flood.stage,
          peak_va, peak_cd, peak_dt, geometry
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
  ),
  # Unique precipitation timestamps that drive all per-frame targets
  tar_target(
    p2_all_precip_timestamps,
    sort(unique(p2_process_precip_rast$dateTime))
  ),
  # Compute above_flood flag and cumulative flood duration once over the full
  # time series. 
  tar_target(
    p2_flow_with_duration_df,
    p2_flow_height_complete_df |>
      arrange(site_no, dateTime) |>
      group_by(site_no) |>
      mutate(
        above_flood = ifelse(is.na(X_00065_00000), FALSE, X_00065_00000 >= flood.stage),
        duration_above_flood_hr = ifelse(above_flood, cumsum(above_flood), NA)
      ) |>
      ungroup()
  ),
  # Classify flood status for each gage at each timestep — branches only slice
  # the single timestamp row
  tar_target(
    p2_flow_by_time,
    p2_flow_with_duration_df |>
      filter(dateTime == p2_all_precip_timestamps) |>
      mutate(
        flood_status = case_when(
          !is.na(major.flood.stage) & X_00065_00000 >= major.flood.stage ~ "Major",
          !is.na(moderate.flood.stage) & X_00065_00000 >= moderate.flood.stage ~ "Moderate",
          !is.na(flood.stage) & X_00065_00000 >= flood.stage ~ "Flood",
          TRUE ~ "Not flooded"
        ),
        flood_status = factor(flood_status, levels = c("Not flooded", "Flood", "Moderate", "Major")),
        is_flooded = above_flood,
        sev_rank = c("Not flooded" = 0L, "Flood" = 1L, "Moderate" = 2L, "Major" = 3L)[as.character(flood_status)],
        above_amt = dplyr::case_when(
          flood_status == "Major" ~ X_00065_00000 - major.flood.stage,
          flood_status == "Moderate" ~ X_00065_00000 - moderate.flood.stage,
          flood_status == "Flood" ~ X_00065_00000 - flood.stage,
          TRUE ~ NA_real_
        )
      ),
    pattern = map(p2_all_precip_timestamps),
    iteration = "list"
  ),
  # Global max flooded gage count and max flood duration.
  tar_target(
    p2_global_flow_maxes,
    p2_flow_by_time |>
      map(~ list(
        max_flooded = sum(.x$flood_status %in% c("Flood", "Moderate", "Major"), na.rm = TRUE),
        max_duration = max(.x$duration_above_flood_hr, na.rm = TRUE)
      )) |>
      transpose() |>
      map(~ max(unlist(.x), na.rm = TRUE))
  ),
  # Progress bar math
  tar_target(
    p2_min_timestamp,
    p2_all_precip_timestamps[[1]]
  ),
  tar_target(
    p2_precip_duration,
    as.double(
      p2_all_precip_timestamps[[length(p2_all_precip_timestamps)]] - p2_min_timestamp,
      units = "hours"
    )
  ),
  tar_target(
    p2_progress_fract,
    {
      hours_since_start <- as.double(p2_all_precip_timestamps - p2_min_timestamp, units = "hours")
      hours_since_start / p2_precip_duration
    },
    pattern = map(p2_all_precip_timestamps),
    iteration = "list"
  )
)
