#' Extract a standalone precipitation color-bar legend grob.
#'
#' Renders a 2-row dummy dataset with the supplied fill scale and pulls the
#' legend grob via [cowplot::get_legend()]. This avoids re-rendering the full
#' precipitation raster just to obtain the color bar.
#'
#' @param precip_fill_scale A ggplot2 scale object (e.g. [ggplot2::scale_fill_stepsn()])
#'   built with the appropriate colors, breaks, and limits.
#' @param global_max_precip Numeric. Upper limit of the precipitation scale (inches).
#' @return A gtable/grob suitable for use with [cowplot::draw_plot()].
build_precip_legend <- function(precip_fill_scale, global_max_precip) {
  cowplot::get_legend(
    ggplot(
      data.frame(x = c(1, global_max_precip), y = 1,
                 fill = c(1, global_max_precip)),
      aes(x, y, fill = fill)
    ) +
      geom_tile() +
      precip_fill_scale +
      theme(legend.position = "right")
  )
}
