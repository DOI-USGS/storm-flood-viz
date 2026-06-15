#' Place the flood-status barplot on the canvas for one animation frame.
#'
#' Positions the barplot grob from [build_flood_status_bar()] relative to the
#' `flood_bar` anchor. Point mode sits slightly lower-right of spike mode; that
#' offset is a design constant. Returns a list for `+` onto the cowplot canvas.
#'
#' @param flood_status_bar ggplot. The barplot from [build_flood_status_bar()].
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list with one ggplot2 layer object.
build_flood_status_bar_panel <- function(flood_status_bar, flood_spikes,
                                          anchors, config_vars) {
  fb <- anchors$flood_bar
  pos <- if (flood_spikes) fb else fb + c(0.019, 0.028)
  list(
    draw_plot(flood_status_bar, x = pos[1], y = pos[2],
      width = 0.2, height = 0.055)
  )
}
