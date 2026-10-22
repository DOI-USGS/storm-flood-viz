#' Build the flood-severity color key panel (Major/Moderate/Flood swatches)
#' for one animation frame.
#'
#' @param flood_stage_cols_red Named character vector. Flood/Moderate/Major colors.
#' @param lbl Function. The anchored label helper built in [compose_frame()].
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list of grid/ggplot2 layer objects.
build_flood_severity_panel <- function(flood_stage_cols_red, lbl, anchors,
                                        config_vars) {
  fx <- anchors$flood_severity[1]
  fy <- anchors$flood_severity[2]
  font_legend <- config_vars$load_font
  size <- config_vars$canvas_legend_size
  sw <- 0.018
  sh <- 0.022
  gap_after_swatch <- 0.010
  gap_between_items <- 0.008

  cats <- c("Major", "Moderate", "Flood")
  labels <- c("Major flood", "Moderate flood", "Flood")

  x <- fx
  layers <- list()
  for (i in seq_along(cats)) {
    swatch <- rectGrob(
      x = x, y = fy, width = sw, height = sh,
      hjust = 0, vjust = 1,
      gp = gpar(fill = flood_stage_cols_red[[cats[i]]], col = NA)
    )
    layers <- c(layers, list(draw_grob(swatch)))
    x <- x + sw + gap_after_swatch
    layers <- c(layers, list(
      draw_label(labels[i], x = x, y = fy - 0.002, size = size,
                 fontfamily = font_legend, fontface = "bold",
                 hjust = 0, vjust = 1, color = flood_stage_cols_red[[cats[i]]])
    ))
    label_w <- systemfonts::string_width(labels[i], family = font_legend, weight = "bold",
                                          size = size, res = 72) / (config_vars$width * 72)
    x <- x + label_w + gap_between_items
  }
  layers
}
