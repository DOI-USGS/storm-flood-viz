#' Build a progress bar ggplot for the animation frame.
#'
#' @param progress_fraction Numeric 0–1. How far through the event the current
#'   frame is.
#' @param config_vars Named list of styling options. Must contain
#'   `progress_bar_bg_col` and `progress_bar_col`.
#' @return A ggplot object suitable for use with [draw_plot()].
build_progress_bar <- function(progress_fraction, config_vars) {
  ggplot() +
    geom_rect(
      aes(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
      fill = config_vars$progress_bar_bg_col, color = NA
    ) +
    geom_rect(
      aes(xmin = 0, xmax = progress_fraction, ymin = 0, ymax = 1),
      fill = config_vars$progress_bar_col, color = NA
    ) +
    theme_void() +
    theme(
      plot.margin = margin(0, 0, 0, 0),
      panel.background = element_rect(fill = NA, color = NA)
    )
}
