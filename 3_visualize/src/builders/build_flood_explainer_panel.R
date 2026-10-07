#' Build the flood-stage explainer panel for one animation frame.
#'
#' The spike vs point design difference lives here — the one block that is
#' genuinely different between modes — instead of branching inside
#' [compose_frame()]. Each branch returns the explainer sentences (with bold
#' keywords overprinted) and the flood-stage swatch image, positioned relative
#' to the `flood_explain` anchor. The barplot is placed separately by
#' [build_flood_status_bar_panel()].
#'
#' @param legends List from [build_legends()]; uses `$peak`, `$flood_stage`.
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param lbl Function. The anchored label helper built in [compose_frame()].
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list of ggplot2 layer objects.
build_flood_explainer_panel <- function(legends, flood_spikes,
                                         lbl, anchors, config_vars) {
  lh <- config_vars$canvas_line_height
  fx <- anchors$flood_explain[1]
  fy <- anchors$flood_explain[2]
  # Nudges the spike-mode flood-stage legend image right, independent of the
  # 1:1 layout, when it sits too close to the preceding line's text (e.g. on
  # the taller 4:5 social canvas). Defaults to 0 (no change) when unset.
  flood_stage_leg_x_nudge <- config_vars$flood_stage_leg_x_nudge
  if (is.null(flood_stage_leg_x_nudge)) flood_stage_leg_x_nudge <- 0
  if (flood_spikes) {
    list(
      lbl("A               appears at the 75th+ percentile", "flood_explain"),
      lbl("spike", "flood_explain", dx = 0.021, bold = TRUE),
      draw_plot(legends$peak, x = fx + 0.318, y = fy - 0.016,
        height = 0.03, width = 0.1 - config_vars$plot_margin),
      lbl("The                 is correlated to flow percentiles",
        "flood_explain", dy = lh),
      lbl("height", "flood_explain", dx = 0.0395, dy = lh, bold = TRUE),
      draw_image(legends$flood_stage,
        x = fx + 0.358 + flood_stage_leg_x_nudge, y = fy - 0.049,
        width = 0.12, height = 0.12),
      lbl("The              is the severity of the flood",
        "flood_explain", dy = 2 * lh),
      lbl("color", "flood_explain", dx = 0.040, dy = 2 * lh, bold = TRUE)
    )
  } else {
    list(
      lbl("If it floods:", "flood_explain", dx = 0.002),
      lbl("     The              is the severity of the flood",
        "flood_explain", dy = 0.024),
      lbl("color", "flood_explain", dx = 0.060, dy = 0.024, bold = TRUE),
      lbl("      The           is correlated to flow percentiles",
        "flood_explain", dx = -0.022, dy = 0.122),
      lbl("       size", "flood_explain", dx = 0.012, dy = 0.122, bold = TRUE),
      draw_image(legends$flood_stage, x = fx + 0.353, y = fy - 0.152,
        width = 0.08, height = 0.14, scale = 1.0)
    )
  }
}
