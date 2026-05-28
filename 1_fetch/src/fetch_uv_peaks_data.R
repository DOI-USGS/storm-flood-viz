#' Find active USGS stream gages in a bbox with UV time series during the event.
#'
#' Queries the time-series-metadata endpoint (one compact row per time series)
#' filtered by bbox, parameter code, and statistic_id "00011" (instantaneous/UV).
#' Sites whose most recent observation predates the storm start are dropped, so
#' only gages with active UV data during the event window are returned.
#'
#' @param bbox Numeric vector of length 4: c(xmin, ymin, xmax, ymax).
#' @param pcodes Character vector of USGS parameter codes (e.g. c("00060","00065")).
#' @param time_range ISO 8601 interval "startZ/endZ" spanning the event window.
#' @param page_size Rows per API page; default 10000.
#' @return data.frame with columns site_no (character), lon, lat (numeric).
fetch_bbox_stream_sites <- function(bbox, pcodes, time_range, page_size = 10000L) {
  storm_start <- as.POSIXct(sub("/.*", "", time_range),
                            format = "%Y-%m-%dT%H:%MZ", tz = "UTC"
  )
  
  base_req <- httr2::request(
    "https://api.waterdata.usgs.gov/ogcapi/v0/collections/time-series-metadata/items"
  ) |>
    httr2::req_url_query(
      f = "json",
      bbox = paste(bbox, collapse = ","),
      parameter_code = paste(pcodes, collapse = ","),
      statistic_id = "00011",
      limit = page_size
    )
  
  api_key <- Sys.getenv("API_USGS_PAT")
  next_url <- base_req$url
  rows <- list()
  
  repeat {
    req <- httr2::request(next_url) |>
      httr2::req_throttle(rate = 0.5) |>
      httr2::req_retry(
        max_tries    = 4L,
        is_transient = \(r) httr2::resp_status(r) %in% c(429L, 500L, 503L),
        after        = NULL
      )
    if (nzchar(api_key)) req <- httr2::req_headers(req, `X-Api-Token` = api_key)
    resp <- req |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    
    features <- resp$features
    if (length(features) > 0L) {
      rows[[length(rows) + 1L]] <- data.frame(
        monitoring_location_id = vapply(
          features,
          \(f) f$properties$monitoring_location_id %||% NA_character_, character(1L)
        ),
        end_utc = vapply(
          features,
          \(f) f$properties$end_utc %||% NA_character_, character(1L)
        ),
        lon = vapply(
          features,
          \(f) tryCatch(f$geometry$coordinates[[1L]], error = \(e) NA_real_), numeric(1L)
        ),
        lat = vapply(
          features,
          \(f) tryCatch(f$geometry$coordinates[[2L]], error = \(e) NA_real_), numeric(1L)
        ),
        stringsAsFactors = FALSE
      )
    }
    
    next_link <- Filter(\(lk) identical(lk$rel, "next"), resp$links)
    if (length(next_link) == 0L) break
    next_url <- next_link[[1L]]$href
  }
  
  if (length(rows) == 0L) {
    return(data.frame(
      site_no = character(0),
      lon = numeric(0), lat = numeric(0)
    ))
  }
  
  ts_meta <- do.call(rbind, rows)
  ts_meta$end_utc <- as.POSIXct(ts_meta$end_utc,
                                format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"
  )
  active <- ts_meta[!is.na(ts_meta$end_utc) & ts_meta$end_utc >= storm_start, ]
  active$site_no <- sub("^USGS-", "", active$monitoring_location_id)
  
  unique(active[, c("site_no", "lon", "lat")])
}

#' Fetch continuous UV data for a batch of sites directly from the OGC API.
#'
#' Bypasses `dataRetrieval::read_waterdata_continuous()` to avoid an internal
#' type-coercion bug: `qualifier` arrives as NULL in some JSON features and a
#' string in others, causing `bind_rows()` failures during internal pagination.
#' This function extracts only the four needed properties from raw JSON and
#' handles cursor-based pagination itself.
#'
#' @param ids Character vector of "USGS-XXXXXXXX" site IDs.
#' @param pcodes Character vector of USGS parameter codes.
#' @param time_range ISO 8601 interval string "startZ/endZ".
#' @param page_size Rows per API page; default 50000.
#' @return data.frame with columns monitoring_location_id, parameter_code,
#'   time (character ISO 8601), value (numeric).
fetch_continuous_direct <- function(ids, pcodes, time_range, page_size = 50000L) {
  base_req <- httr2::request(
    "https://api.waterdata.usgs.gov/ogcapi/v0/collections/continuous/items"
  ) |>
    httr2::req_url_query(
      f = "json",
      skipGeometry = "TRUE",
      monitoring_location_id = paste(ids, collapse = ","),
      parameter_code = paste(pcodes, collapse = ","),
      time = time_range,
      limit = page_size
    )
  
  api_key <- Sys.getenv("API_USGS_PAT")
  next_url <- base_req$url
  pages <- list()
  
  repeat {
    req <- httr2::request(next_url) |>
      httr2::req_throttle(rate = 0.5) |>
      httr2::req_retry(
        max_tries = 4L,
        is_transient = \(r) httr2::resp_status(r) %in% c(429L, 500L, 503L),
        after = NULL
      )
    if (nzchar(api_key)) req <- httr2::req_headers(req, `X-Api-Token` = api_key)
    resp <- req |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    
    features <- resp$features
    if (length(features) > 0L) {
      p <- resp$features
      pages[[length(pages) + 1L]] <- data.frame(
        monitoring_location_id = vapply(p, \(f) f$properties$monitoring_location_id %||% NA_character_, character(1L)),
        parameter_code = vapply(p, \(f) f$properties$parameter_code %||% NA_character_, character(1L)),
        time = vapply(p, \(f) f$properties$time %||% NA_character_, character(1L)),
        value = vapply(p, \(f) {
          v <- f$properties$value
          if (is.null(v)) NA_real_ else as.numeric(v)
        }, numeric(1L)),
        stringsAsFactors = FALSE
      )
    }
    
    next_link <- Filter(\(lk) identical(lk$rel, "next"), resp$links)
    if (length(next_link) == 0L) break
    next_url <- next_link[[1L]]$href
  }
  
  if (length(pages) == 0L) {
    return(data.frame(
      monitoring_location_id = character(0),
      parameter_code = character(0),
      time = character(0),
      value = numeric(0),
      stringsAsFactors = FALSE
    ))
  }
  
  do.call(rbind, pages)
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
      result <- fetch_continuous_direct(
        ids = paste0("USGS-", chunk),
        pcodes = pcodes,
        time_range = time_range
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
      dateTime = as.POSIXct(time, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
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
