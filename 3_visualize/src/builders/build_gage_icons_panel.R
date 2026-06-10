#' Build the gage-icon legend panel for one animation frame.
#'
#' Three labelled icon rows shared by both spike and point modes: USGS
#' streamgage, rapid-deployment gage, and out-of-service streamgage. Text rows
#' are evenly spaced by `canvas_line_height` below the `gage_icons` anchor; the
#' icon art keeps per-icon vertical offsets since the glyphs differ in height.
#'
#' @param legends List from [build_legends()]; uses `$dot`, `$rdg`, `$decom`.
#' @param lbl Function. The anchored label helper built in [compose_frame()].
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list of ggplot2 layer objects.
build_gage_icons_panel <- function(legends, lbl, anchors, config_vars) {
  lh <- config_vars$canvas_line_height
  ix <- anchors$gage_icons[1]
  iw <- 0.1 - config_vars$plot_margin
  list(
    lbl("USGS streamgage", "gage_icons", dx = 0.053),
    draw_plot(legends$dot, x = ix, y = 0.225, height = 0.03, width = iw),
    lbl("Rapid-Deployment gage", "gage_icons", dx = 0.053, dy = lh),
    draw_plot(legends$rdg, x = ix, y = 0.196, height = 0.03, width = iw),
    lbl("Out-of-service streamgage", "gage_icons", dx = 0.053, dy = 2 * lh),
    draw_plot(legends$decom, x = ix, y = 0.144, height = 0.08, width = iw)
  )
}
