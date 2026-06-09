#' Build storm track layer list for the current animation frame.
#'
#' Filters storm points up to the current timestamp, then returns ggplot2
#' layers for the track path, individual time-step dots, and the hurricane
#' symbol at the latest position.
#'
#' @param storm_now sf/data.frame. Storm track points with columns `DTG`
#'   (POSIXct), `X`, `Y` (projected coordinates).
#' @param dtg POSIXct. Current frame timestamp; points after this are excluded.
#' @param hurricane_symbol_path Character. Path to the hurricane symbol PNG.
#' @param config_vars Named list of styling options. Must contain
#'   `storm_path_col`.
#' @return A list of ggplot2 layer objects suitable for use with `+`.
build_storm_track <- function(storm_now, dtg, hurricane_symbol_path,
                              config_vars) {
  # Track line width and dot size are visual calibration values tuned so the
  # path is legible at 1920x1080 without overpowering the gage symbols.
  lw_track <- 0.8
  size_dots  <- 2
  # Symbol size is in fraction of plot width 
  size_symbol <- 0.035

  past_storm_points <- dplyr::filter(storm_now, DTG <= dtg)
  latest_point <- dplyr::slice_tail(past_storm_points, n = 1)

  list(
    geom_path(
      data = past_storm_points,
      aes(x = X, y = Y),
      color = config_vars$storm_path_col,
      linewidth = lw_track
    ),
    geom_point(
      data = past_storm_points,
      aes(x = X, y = Y),
      color = "black",
      size = size_dots
    ),
    ggimage::geom_image(
      data = latest_point,
      aes(x = X, y = Y),
      image = hurricane_symbol_path,
      size = size_symbol
    )
  )
}
