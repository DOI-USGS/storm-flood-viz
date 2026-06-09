#' Compute title block text strings for one animation frame.
#'
#' Centralises all per-frame text computation: storm name, formatted
#' timestamp, landfall countdown, and storm classification. Returns plain
#' strings so the caller (`compose_frame`) can place them with draw_label
#' at the appropriate canvas coordinates.
#'
#' @param storm_info Named list or tibble with a `storm_name` field.
#' @param dtg POSIXct. Current frame timestamp (UTC).
#' @param timezone_long Character. Olson timezone name for display
#'   (e.g. "America/New_York").
#' @param landfall_dtg POSIXct. Expected landfall time (UTC). Used to
#'   compute the countdown label; shown until 2 hours after landfall.
#' @param storm_now sf. Storm track points up to and including `dtg`;
#'   must contain columns `DTG` and `storm_type_full`.
#' @return A named list:
#'   \describe{
#'     \item{storm_name}{Character. "Hurricane <Name>" title string.}
#'     \item{timestamp}{Character. Formatted local date-time string.}
#'     \item{landfall}{Character or NULL. Countdown label, or NULL when
#'       more than 2 hours past landfall or landfall has not yet occurred
#'       but countdown should not be shown.}
#'     \item{classification}{Character or NULL. Latest known storm
#'       classification, or NULL if none available.}
#'   }
build_title_block <- function(storm_info, dtg, timezone_long,
                               landfall_dtg, storm_now) {
  storm_name <- paste(
    storm_info$storm_type_label,
    stringr::str_to_sentence(storm_info$storm_name))

  timestamp <- format(
    lubridate::with_tz(dtg, timezone_long), "%b. %d, %Y %H:%M %Z")

  time_to_landfall <- difftime(landfall_dtg, dtg, units = "hours")
  landfall <- if (time_to_landfall > -2 && time_to_landfall > 0) {
    paste0(round(as.numeric(time_to_landfall), 1), " hours to landfall")
  } else {
    NULL
  }

  storm_match <- storm_now |>
    filter(.data$DTG <= dtg, !is.na(.data$storm_type_full)) |>
    slice_tail(n = 1)
  classification <- if (nrow(storm_match) > 0) {
    storm_match$storm_type_full[1]
  } else {
    NULL
  }

  list(
    storm_name = storm_name,
    timestamp = timestamp,
    landfall = landfall,
    classification = classification
  )
}
