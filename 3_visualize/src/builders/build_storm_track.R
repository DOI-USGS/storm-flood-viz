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
#'   `storm_path_col`, `storm_track_lw`, `storm_track_dot_size`, and
#'   `hurricane_symbol_size` (all set in storm YAML viz_config).
#' @return A list of ggplot2 layer objects suitable for use with `+`.
build_storm_track <- function(storm_now, dtg, hurricane_symbol_path,
                              config_vars) {
  past_storm_points <- dplyr::filter(storm_now, DTG <= dtg)
  latest_point <- dplyr::slice_tail(past_storm_points, n = 1)

  list(
    geom_path(
      data = past_storm_points,
      aes(x = X, y = Y),
      color = config_vars$storm_path_col,
      linewidth = config_vars$storm_track_lw
    ),
    geom_point(
      data = past_storm_points,
      aes(x = X, y = Y),
      color = "black",
      size = config_vars$storm_track_dot_size
    ),
    ggimage::geom_image(
      data = latest_point,
      aes(x = X, y = Y),
      image = hurricane_symbol_path,
      size = config_vars$hurricane_symbol_size
    )
  )
}
