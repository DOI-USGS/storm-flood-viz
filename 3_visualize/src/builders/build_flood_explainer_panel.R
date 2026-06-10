#' Build the flood-stage explainer panel for one animation frame.
#'
#' The spike vs point design difference lives here — the one block that is
#' genuinely different between modes — instead of branching inside
#' [compose_frame()]. Each branch returns the explainer sentences (with bold
#' keywords overprinted), the flood-stage swatch image, and the flood-status
#' barplot, positioned relative to the `flood_explain` / `flood_bar` anchors.
#'
#' @param legends List from [build_legends()]; uses `$peak`, `$flood_stage`.
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param flood_status_bar ggplot. The flood-status barplot from
#'   [build_flood_status_bar()].
#' @param lbl Function. The anchored label helper built in [compose_frame()].
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list of ggplot2 layer objects.
build_flood_explainer_panel <- function(legends, flood_spikes, flood_status_bar,
                                         lbl, anchors, config_vars) {
  lh <- config_vars$canvas_line_height
  fx <- anchors$flood_explain[1]
  fb <- anchors$flood_bar
  if (flood_spikes) {
    list(
      lbl("A               appears at the 75th+ percentile", "flood_explain"),
      lbl("spike", "flood_explain", dx = 0.021, bold = TRUE),
      draw_plot(legends$peak, x = fx + 0.318, y = 0.147,
        height = 0.03, width = 0.1 - config_vars$plot_margin),
      lbl("The                 is correlated to flow percentiles",
        "flood_explain", dy = lh),
      lbl("height", "flood_explain", dx = 0.0395, dy = lh, bold = TRUE),
      draw_image(legends$flood_stage, x = fx + 0.358, y = 0.114,
        width = 0.12, height = 0.12),
      lbl("The              is the severity of the flood",
        "flood_explain", dy = 2 * lh),
      lbl("color", "flood_explain", dx = 0.040, dy = 2 * lh, bold = TRUE),
      draw_plot(flood_status_bar, x = fb[1], y = fb[2],
        width = 0.2, height = 0.055)
    )
  } else {
    list(
      lbl("If it floods:", "flood_explain", dx = 0.002),
      lbl("     The              is the severity of the flood",
        "flood_explain", dy = 0.024),
      lbl("color", "flood_explain", dx = 0.060, dy = 0.024, bold = TRUE),
      draw_plot(flood_status_bar, x = 0.189, y = 0.054,
        width = 0.2, height = 0.055),
      lbl("      The           is correlated to flow percentiles",
        "flood_explain", dx = -0.022, dy = 0.122),
      lbl("       size", "flood_explain", dx = 0.012, dy = 0.122, bold = TRUE),
      draw_image(legends$flood_stage, x = fx + 0.353, y = 0.011,
        width = 0.08, height = 0.14, scale = 1.0)
    )
  }
}
