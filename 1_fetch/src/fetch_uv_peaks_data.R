#' Find active USGS stream gages in a bbox with UV time series during the event.
#'
#' Thin wrapper around `dataRetrieval::read_waterdata_ts_meta()`, filtered by
#' bbox, parameter code, and statistic_id "00011" (instantaneous/UV). Sites
#' whose most recent observation predates the storm start are dropped, so only
#' gages with active UV data during the event window are returned. The
#' `API_USGS_PAT` env var is picked up automatically by dataRetrieval.
#'
#' @param bbox Numeric vector of length 4: c(xmin, ymin, xmax, ymax).
#' @param pcodes Character vector of USGS parameter codes (e.g. c("00060","00065")).
#' @param time_range ISO 8601 interval "startZ/endZ"; the start side is used to
#'   drop series whose most recent observation predates the event.
#' @return `sf` object with one row per active site, columns `site_no` and
#'   `geometry` (POINT, WGS 84).
fetch_bbox_stream_sites <- function(bbox, pcodes, time_range) {
  storm_start <- as.POSIXct(sub("/.*", "", time_range),
                            format = "%Y-%m-%dT%H:%MZ", tz = "UTC")

  dataRetrieval::read_waterdata_ts_meta(
    bbox = bbox,
    parameter_code = pcodes,
    statistic_id = "00011"
  ) |>
    dplyr::filter(!is.na(end_utc), end_utc >= storm_start) |>
    dplyr::mutate(site_no = sub("^USGS-", "", monitoring_location_id)) |>
    dplyr::distinct(site_no, .keep_all = TRUE) |>
    dplyr::select(site_no, geometry)
}

#' This function takes a vector of site ids and the desired number of sites
# per list and chunks them up into multiple vectors within a list
#' @param site_ids A vector of USGS site id's that include the leading zero, e.g. "01234567".
#' @param n_sites_per_vector The number of sites contained within each vector in the output list
#'
#' @return A list of vectors, each containing `n_sites_per_vector` site ID's for use
#' iterating over the `dataRetrieval::readNWISuv()` function.

chunk_up_sites <- function(site_ids, n_sites_per_vector) {
  n_lists <- ceiling(length(site_ids) / n_sites_per_vector)
  # Split only works if n_lists is greater than 1, need to manually create
  # list if only 1 list needed!
  if (n_lists > 1) {
    site_list <- split(site_ids, cut(seq_along(site_ids), n_lists, labels = FALSE))
  } else {
    site_list <- list()
    site_list[[1]] <- site_ids
  }
  
  return(site_list)
}

#' Batch pull instantaneous values for gage height
#'
#' @param outfile_path Character string pointing to the output file. Should have
#' file extension ".parquet".
#' @param sites_list List of site vectors created by `chunk_up_sites()` function.
#' @param pcodes A vector of strings representing desired USGS pcodes.
#' @param startDate A string in the format "YYYY-MM-DDTHH:MMZ" representing the
#' start datetime in UTC (e.g. "2024-09-24T00:00Z").
#' @param endDate A string in the format "YYYY-MM-DDTHH:MMZ" representing the
#' end datetime in UTC (e.g. "2024-09-29T23:00Z").
#'
#' @return The outfile path to a parquet file containing uv data.

fetch_uv_data <- function(outfile_path, sites_list, pcodes, startDate, endDate) {
  time_range <- paste0(startDate, "/", endDate)
  
  cache_dir <- paste0(tools::file_path_sans_ext(outfile_path), "_cache")
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  
  fetch_chunk <- purrr::insistently(
    function(chunk, chunk_name) {
      cache_file <- file.path(cache_dir, paste0("chunk_", chunk_name, ".parquet"))
      if (file.exists(cache_file)) {
        message("Chunk ", chunk_name, ": loading from cache")
        return(arrow::read_parquet(cache_file))
      }
      result <- dataRetrieval::read_waterdata_continuous(
        monitoring_location_id = paste0("USGS-", chunk),
        parameter_code = pcodes,
        time = time_range
      )
      arrow::write_parquet(result, cache_file)
      result
    },
    rate = purrr::rate_backoff(pause_base = 5, pause_cap = 120, max_times = 6),
    quiet = FALSE
  )

  out <- purrr::imap(sites_list, fetch_chunk) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      site_no = sub("^USGS-", "", monitoring_location_id),
      agency_cd = "USGS",
      dateTime = lubridate::with_tz(time, tzone = "UTC"),
      col_name = paste0("X_", parameter_code, "_00000")
    ) |>
    dplyr::distinct(site_no, dateTime, col_name, .keep_all = TRUE) |>
    dplyr::select(site_no, agency_cd, dateTime, col_name, value) |>
    tidyr::pivot_wider(names_from = col_name, values_from = value)
  
  unlink(cache_dir, recursive = TRUE)
  
  arrow::write_parquet(out, outfile_path)
  return(outfile_path)
}

#' Batch pull NWIS peaks data for a selected sites list and save the peaks
#' data to a file.
#' @param outfile_path Character string pointing to the output file. Should have
#' file extension ".parquet".
#' @param sites_list List of site vectors created by `chunk_up_sites()` function.
#' @param startDate A string in the format "YYYY-MM-DD" representing the start
#' date over which to pull peaks data. Should most likely be an early date like
#' "1900-01-01"
#'
#' @return The outfile path to a parquet file containing peaks data.

fetch_peak_data <- function(outfile_path, sites_list, startDate = "1900-01-01",
                            batch_size = 10) {
  all_sites <- unlist(sites_list, use.names = FALSE)
  all_sites <- all_sites[grepl("^[0-9]{8,15}$", all_sites)]
  batches <- split(all_sites, ceiling(seq_along(all_sites) / batch_size))
  
  cache_dir <- paste0(tools::file_path_sans_ext(outfile_path), "_cache")
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  
  fetch_batch <- purrr::insistently(
    function(batch, batch_name) {
      cache_file <- file.path(cache_dir, paste0("batch_", batch_name, ".parquet"))
      if (file.exists(cache_file)) {
        message("Batch ", batch_name, ": loading from cache")
        return(arrow::read_parquet(cache_file))
      }
      result <- dataRetrieval::readNWISpeak(batch, startDate = startDate)
      arrow::write_parquet(result, cache_file)
      result
    },
    rate = purrr::rate_backoff(pause_base = 2, pause_cap = 60, max_times = 5),
    quiet = FALSE
  )
  
  out <- purrr::imap(batches, fetch_batch) |>
    dplyr::bind_rows()
  
  unlink(cache_dir, recursive = TRUE)
  
  arrow::write_parquet(out, outfile_path)
  return(outfile_path)
}
