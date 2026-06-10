#' Build the precipitation colorbar panel for one animation frame.
#'
#' Positions the precip colorbar and its min/max tick labels relative to the
#' `precip_legend` anchor. Returns a list of cowplot draw_* layers to add onto
#' the assembled `ggdraw()` canvas with `+`.
#'
#' @param legends List from [build_legends()]; uses `$precip`.
#' @param global_max_precip Numeric. Upper precip limit, shown as the max tick.
#' @param lbl Function. The anchored label helper built in [compose_frame()].
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list of ggplot2 layer objects.
build_precip_legend_panel <- function(legends, global_max_precip, lbl,
                                       anchors, config_vars) {
  a <- anchors$precip_legend
  list(
    lbl("Total rainfall (in)", "precip_legend"),
    draw_plot(legends$precip,
      x = a[1] + 0.050, y = 0.238,
      height = 0.05, width = 0.42 - config_vars$plot_margin),
    lbl("1", "precip_legend", dx = 0.156, dy = 0.001),
    lbl(paste(global_max_precip), "precip_legend", dx = 0.331, dy = 0.001)
  )
}
