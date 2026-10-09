#' Build the Instagram carousel static legend card (slide 3): a full-canvas,
#' single-column legend, rendered once (not per timestep). Reuses
#' build_legends() for the icon/colorbar assets and build_flood_status_bar()
#' for the static severity key, but uses its own row-by-row layout — the
#' small map-corner panel builders' internal offsets don't fit a full-canvas
#' single column. Icon/text sizes inside those reused builders are fixed
#' absolute points, not scaled by the draw_plot() box they're placed into, so
#' a scaled copy of config_vars is passed to them just for icon construction.
#'
#' @param global_max_precip Numeric. Upper precip limit (inches).
#' @param precip_cols,precip_grayscale_cols,precip_grayscale See
#'   [build_precip_layer()]; scale-only, no real raster.
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param flood_stage_spike_leg_path,flood_stage_point_leg_path Character.
#' @param flood_stage_cols_blue,flood_stage_cols_red Named character vectors.
#' @param target_rdg_icon Character. Path to RDG bullseye PNG.
#' @param config_vars Named list of styling options (viz_config_social).
#' @param card_cfg Named list from the storm YAML `legend_card:` block — row
#'   x/y positions, text size, per-icon scale (dot/rdg/decom), indent,
#'   bottom-block sizing. Missing keys fall back to `default_card_cfg` below.
#' @param out_path Character. Output PNG path.
#' @return Character. out_path.
build_legend_card <- function(global_max_precip, precip_cols,
                               precip_grayscale_cols, precip_grayscale,
                               flood_spikes, flood_stage_spike_leg_path,
                               flood_stage_point_leg_path,
                               flood_stage_cols_blue, flood_stage_cols_red,
                               target_rdg_icon, config_vars,
                               card_cfg = list(), out_path) {
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  font_legend <- config_vars$load_font

  default_card_cfg <- list(
    text_size = 24,
    # per-icon scale: fixed absolute sizes in build_legends(), so each needs
    # its own multiplier rather than one shared value
    dot_scale = 3,
    rdg_scale = 0.9,
    decom_scale = 3,
    decom_stroke_scale = 3,
    colorbar_scale = 2.5,
    indent = 0.04,

    # row y-positions, top to bottom (0 = canvas bottom, 1 = canvas top)
    rainfall_y = 0.94,
    usgs_y = 0.84,
    rdg_y = 0.75,
    oos_y = 0.66,
    spike_y = 0.58,
    height_y = 0.50,
    percentiles_y = 0.44,
    color_y = 0.35,
    flood_y = 0.29,
    bottom_y = 0.25,

    # row x-positions
    rainfall_label_x = 0.07,
    rainfall_tick1_x = 0.425,
    rainfall_colorbar_x = 0.46,
    rainfall_tick2_x = 0.855,
    icon_x = 0.10,
    icon_label_x = 0.17,
    explainer_x = 0.075,

    # bottom_image sized to the source PNG's true 1200x1800 (2:3) aspect at
    # this height, on an 8x10in canvas, so it isn't stretched/squeezed
    bottom_image_x = 0.15,
    bottom_image_width = 0.18,
    bottom_image_height = 0.22,
    bottom_key_x = 0.42,
    bottom_key_y = 0.03,
    bottom_key_width = 0.55,
    bottom_key_height = 0.18
  )
  if (is.null(card_cfg)) card_cfg <- list()
  cc <- modifyList(default_card_cfg, card_cfg)
  text_size <- cc$text_size

  # Icon/colorbar/severity-key sizes are fixed absolute points or physical cm
  # inside build_legends()/build_flood_status_bar() — scale them up here for
  # this full-canvas card rather than relying on a bigger draw_plot() box
  # (which only adds whitespace, since the geoms themselves don't stretch).
  config_vars_card <- config_vars
  config_vars_card$dot_legend_size <- config_vars$dot_legend_size * cc$dot_scale
  config_vars_card$decom_legend_size <- config_vars$decom_legend_size * cc$decom_scale
  config_vars_card$decom_stroke <- cc$decom_stroke_scale
  config_vars_card$rdg_legend_icon_size <- cc$rdg_scale
  # geom_text() size is in mm; .pt converts our point-based text_size to it.
  config_vars_card$bar_text_size <- text_size / .pt
  config_vars_card$precip_legend_key_width_cm <-
    config_vars$precip_legend_key_width_cm * cc$colorbar_scale
  config_vars_card$precip_legend_key_height_cm <-
    config_vars$precip_legend_key_height_cm * cc$colorbar_scale

  # One text row, with an optional inline bold word positioned by measured
  # text width (not a hardcoded offset) so it lines up at any font size.
  row_text <- function(y, prefix, bold_word = NULL, suffix = "",
                        x0 = cc$explainer_x) {
    out <- list(draw_label(prefix, x = x0, y = y, size = text_size, hjust = 0,
      vjust = 1, fontfamily = font_legend, color = "black"))
    if (is.null(bold_word)) return(out)
    prefix_w <- systemfonts::string_width(prefix, family = font_legend,
      size = text_size, res = 72) / (config_vars$width * 72)
    out <- c(out, list(draw_label(bold_word, x = x0 + prefix_w, y = y,
      size = text_size, hjust = 0, vjust = 1, fontfamily = font_legend,
      fontface = "bold", color = "black")))
    bold_w <- systemfonts::string_width(bold_word, family = font_legend,
      weight = "bold", size = text_size, res = 72) / (config_vars$width * 72)
    c(out, list(draw_label(suffix, x = x0 + prefix_w + bold_w, y = y,
      size = text_size, hjust = 0, vjust = 1, fontfamily = font_legend,
      color = "black")))
  }

  precip <- build_precip_layer(
    data.frame(x = numeric(0), y = numeric(0), precip_in = numeric(0)),
    precip_cols, precip_grayscale_cols, global_max_precip, precip_grayscale,
    font_legend, config_vars_card
  )
  legends <- build_legends(
    precip$scale, global_max_precip, flood_spikes,
    flood_stage_spike_leg_path, flood_stage_point_leg_path,
    target_rdg_icon, config_vars_card
  )
  severity_key <- build_flood_status_bar(
    flood_stage_cols_blue = flood_stage_cols_blue,
    flood_stage_cols_red = flood_stage_cols_red,
    precip_grayscale = precip_grayscale,
    font_legend = font_legend, config_vars = config_vars_card
  )

  canvas <- rectGrob(
    x = 0, y = 0, width = 16, height = 9,
    gp = gpar(fill = config_vars$bg_col, alpha = 1, col = config_vars$bg_col)
  )

  p <- ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
    draw_grob(canvas,
      x = 0, y = 1, height = 1, width = 1, hjust = 0, vjust = 1) +
    # 1: rainfall legend — all inline, vertically centered on one row
    draw_label("Total rainfall (in)", x = cc$rainfall_label_x, y = cc$rainfall_y,
      size = text_size, hjust = 0, vjust = 0.5, fontfamily = font_legend,
      color = "black") +
    draw_label("1", x = cc$rainfall_tick1_x, y = cc$rainfall_y,
      size = text_size, hjust = 0, vjust = 0.5, fontfamily = font_legend,
      color = "black") +
    draw_plot(legends$precip, x = cc$rainfall_colorbar_x, y = cc$rainfall_y,
      width = 0.45, height = 0.05, hjust = 0, vjust = 0.5) +
    draw_label(paste(global_max_precip), x = cc$rainfall_tick2_x, y = cc$rainfall_y,
      size = text_size, hjust = 0, vjust = 0.5, fontfamily = font_legend,
      color = "black") +
    # 2: USGS streamgage
    draw_plot(legends$dot, x = cc$icon_x, y = cc$usgs_y,
      width = 0.09, height = 0.09, hjust = 0.5, vjust = 0.5) +
    draw_label("USGS streamgage", x = cc$icon_label_x, y = cc$usgs_y,
      size = text_size, hjust = 0, vjust = 0.5, fontfamily = font_legend,
      color = "black") +
    # 3: Rapid-Deployment gage
    draw_plot(legends$rdg, x = cc$icon_x, y = cc$rdg_y,
      width = 0.09, height = 0.09, hjust = 0.5, vjust = 0.5) +
    draw_label("Rapid-Deployment gage", x = cc$icon_label_x, y = cc$rdg_y,
      size = text_size, hjust = 0, vjust = 0.5, fontfamily = font_legend,
      color = "black") +
    # 4: Out-of-service streamgage
    draw_plot(legends$decom, x = cc$icon_x, y = cc$oos_y,
      width = 0.09, height = 0.09, hjust = 0.5, vjust = 0.5) +
    draw_label("Out-of-service streamgage", x = cc$icon_label_x, y = cc$oos_y,
      size = text_size, hjust = 0, vjust = 0.5, fontfamily = font_legend,
      color = "black") +
    # 5-9: spike/height/color explainer; wrapped lines indented under it
    row_text(cc$spike_y, "A ", "spike", " appears at the 75th+ percentile") +
    row_text(cc$height_y, "The ", "height", " is correlated to") +
    row_text(cc$percentiles_y, "flow percentiles", x0 = cc$explainer_x + cc$indent) +
    row_text(cc$color_y, "The ", "color", " is the severity") +
    row_text(cc$flood_y, "of the flood", x0 = cc$explainer_x + cc$indent) +
    # 10: spike-percentile scale image + severity key
    draw_image(legends$flood_stage,
      x = cc$bottom_image_x, y = cc$bottom_y,
      width = cc$bottom_image_width, height = cc$bottom_image_height,
      hjust = 0, vjust = 1) +
    draw_plot(severity_key,
      x = cc$bottom_key_x, y = cc$bottom_key_y,
      width = cc$bottom_key_width, height = cc$bottom_key_height)

  ggsave(filename = out_path, plot = p, width = config_vars$width,
         height = config_vars$height, dpi = config_vars$dpi,
         bg = config_vars$bg_col, device = agg_png)

  out_path
}
