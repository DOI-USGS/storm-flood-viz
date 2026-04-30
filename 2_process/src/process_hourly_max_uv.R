#' Extract Hourly Maximum Gage Height and Discharge from Instantaneous Data
#'
#' This function processes instantaneous USGS unit value (UV) data to extract the
#' hourly maximum gage height and associated discharge value per site.
#' It returns a wide-format dataframe with `gage_height`, `discharge`, and optional percentiles.
#'
#' @param inst_data A data frame of instantaneous values (UV data) with timestamped readings per site.
#' @param value_cols_regex A regular expression to identify value columns (e.g., "^X_").
#' @param hour_unit A character string specifying the time unit for aggregation (e.g., "hour", "30 minutes").
#' @param pcode_param_map A named character vector mapping PCODE substrings (e.g., "00060") to parameter names (e.g., "discharge").
#'
#' @return A tibble in wide format with one row per site and datetime
get_hourly_max_uv <- function(inst_data, value_cols_regex, hour_unit,
                              pcode_param_map){

  # Lengthen dataset by pcode columns (won't need to do this with new uv service)
  # Note that some gages have multiple columns for one pcode in the old service, e.g. "X_00065_left.sensor_0000" and "X00065_right.sensor_0000". We are not discerning between these, just picking the max value.

  if (nrow(inst_data) == 0) return(tibble())

  # Identify value/code columns
  value_columns <- names(inst_data)[grepl(value_cols_regex, names(inst_data)) & !grepl("_cd$", names(inst_data))]
  code_columns  <- names(inst_data)[grepl(value_cols_regex, names(inst_data)) &  grepl("_cd$", names(inst_data))]

  inst_data_long <- inst_data |>
    mutate(
      across(all_of(value_columns), as.numeric),
      across(all_of(code_columns), as.character)
    ) |>
    tidyr::pivot_longer(
      cols = all_of(value_columns),
      names_to = "pcode_col",
      values_to = "value",
      values_drop_na = TRUE
    ) |>
    mutate(
      parameter = dplyr::case_when(
        grepl("00060", pcode_col) ~ pcode_param_map[["00060"]],
        grepl("00065", pcode_col) ~ pcode_param_map[["00065"]],
        TRUE ~ NA_character_
      ),
      utc_hour = lubridate::floor_date(dateTime, unit = hour_unit)
    ) |>
    select(site_no, agency_cd, dateTime, utc_hour, parameter, value)

  # Pick the max value and (if there are ties) datetime for each site given the gage heights.
  # Grab gage height and discharge value for that site and dateTime
  # Widen dataset to have discharge and gage_height columns

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
    tidyr::pivot_wider(
      id_cols = c(site_no, dateTime),
      names_from = parameter,
      values_from = value,
      values_fill = list(value = NA)
    ) |>
    left_join(
      inst_data |> dplyr::select(site_no, agency_cd, dateTime, percentile),
      by = c("site_no", "dateTime")
    ) |>
    mutate(
      utc_hour = lubridate::floor_date(dateTime, unit = hour_unit)
    ) |>
    select(
      site_no, agency_cd, dateTime, utc_hour,
      X_00065_00000 = gage_height,
      X_00060_00000 = discharge,
      percentile
    )

  return(inst_data_wide)
}