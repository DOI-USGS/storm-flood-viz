#' Fetch day-of-year percentile thresholds for USGS streamflow sites.
#'
#' Calls the USGS waterdata statistics API for each site and returns a wide
#' table of threshold values (p05–p95) per site × MM-DD day-of-year. Sites
#' with fewer than `min_por_years` years of record on any day are excluded
#' (their rows will be absent from the output, producing NA percentile
#' categories downstream).
#'
#' @param site_nos Character vector of USGS site numbers (no "USGS-" prefix).
#' @param parameter_code USGS parameter code; default "00060" (discharge).
#' @param out_path File path for the output parquet.
#' @param min_por_years Minimum years of record required; default 30.
#' @param batch_size Sites per API request; default 50 (keep ≤30 without API key; higher ok with API_USGS_PAT).
#' @return `out_path` (invisibly), written as a parquet file.
fetch_site_stats <- function(site_nos, parameter_code = "00060", out_path,
                             min_por_years = 30, batch_size = 50) {
  monitoring_ids <- paste0("USGS-", site_nos)
  batches <- split(monitoring_ids, ceiling(seq_along(monitoring_ids) / batch_size))
  
  cache_dir <- paste0(file_path_sans_ext(out_path), "_cache")
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  
  fetch_batch <- insistently(
    function(batch, batch_name) {
      cache_file <- file.path(cache_dir, paste0("batch_", batch_name, ".parquet"))
      if (file.exists(cache_file)) {
        message("Batch ", batch_name, ": loading from cache")
        return(read_parquet(cache_file))
      }
      result <- read_waterdata_stats_por(
        monitoring_location_id = batch,
        parameter_code = parameter_code,
        computation_type = "percentile",
        normal_type = "DOY"
      ) |>
        st_drop_geometry()
      write_parquet(result, cache_file)
      result
    },
    rate  = rate_backoff(pause_base = 5, pause_cap = 120, max_times = 6),
    quiet = FALSE
  )
  
  raw <- imap(batches, fetch_batch) |>
    bind_rows()
  
  unlink(cache_dir, recursive = TRUE)
  
  # read_waterdata_stats_por(normal_type = "DOY") already returns only
  # day-of-year rows, so no client-side time_of_year_type filter is needed.
  doy <- raw |>
    mutate(site_no = sub("^USGS-", "", monitoring_location_id))
  
  # Per time series, the minimum sample_count across all days is the
  # most conservative POR estimate. Pick the ts with the longest such
  # record that still meets the threshold.
  preferred <- doy |>
    group_by(monitoring_location_id, parent_time_series_id) |>
    summarise(min_sc = min(sample_count, na.rm = TRUE), .groups = "drop") |>
    filter(min_sc >= min_por_years) |>
    group_by(monitoring_location_id) |>
    slice_max(min_sc, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(monitoring_location_id, parent_time_series_id)
  
  stats_wide <- doy |>
    inner_join(preferred, by = c("monitoring_location_id", "parent_time_series_id")) |>
    filter(percentile %in% c(5L, 10L, 25L, 50L, 75L, 90L, 95L)) |>
    mutate(percentile = sprintf("%02d", percentile)) |>
    select(site_no, time_of_year, percentile, value) |>
    pivot_wider(
      names_from = percentile,
      names_prefix = "p",
      values_from = value
    )
  
  write_parquet(stats_wide, out_path)
  invisible(out_path)
}
