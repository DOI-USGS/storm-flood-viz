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
#' @param track_start_dtg POSIXct or NULL. If set, no track is drawn until
#'   `dtg` reaches this time, and the drawn path itself starts at this time
#'   too (earlier track points are excluded, not just hidden pre-reveal)
#'   (storm YAML `storm_track_start_time`).
#' @return A list of ggplot2 layer objects suitable for use with `+`.
build_storm_track <- function(storm_now, dtg, hurricane_symbol_path,
                              config_vars, track_start_dtg = NULL) {
  if (!is.null(track_start_dtg) && dtg < track_start_dtg) return(list())

  past_storm_points <- filter(storm_now, DTG <= dtg)
  if (!is.null(track_start_dtg)) {
    past_storm_points <- filter(past_storm_points, DTG >= track_start_dtg)
  }
  latest_point <- slice_tail(past_storm_points, n = 1)

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
    geom_image(
      data = latest_point,
      aes(x = X, y = Y),
      image = hurricane_symbol_path,
      size = config_vars$hurricane_symbol_size
    )
  )
}
