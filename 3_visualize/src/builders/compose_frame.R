#' Assemble one flood-stage animation frame from pre-built layers and panels.
#'
#' Calls every layer/panel builder in stacking order, assembles the cowplot
#' canvas, and saves the result as a PNG. Returns the output file path so
#' targets can track it as a file artifact.
#'
#' Layer stacking order (bottom to top):
#'   1. Precipitation raster
#'   2. Basemap (state borders)
#'   3. Flood gages — non-flooded points, spikes or sized points, decom markers
#'   4. City markers and labels
#'   5. Storm track path, dots, and hurricane symbol
#'   6. Rapid-deployment gage icons
#'
#' @param dtg POSIXct. Current frame timestamp (UTC).
#' @param precip_now data.frame. Gridded precipitation at current timestep.
#' @param flow_now data.frame. Streamgage data at current timestep.
#' @param storm_now sf. Storm track points up to `dtg`.
#' @param rdg_now sf. Rapid-deployment gages active at `dtg`.
#' @param state_inner_borders sf. Internal CONUS state lines.
#' @param state_outer_lines sf. Outer CONUS boundary lines.
#' @param major_cities sf. Major city points with a `NAME` column.
#' @param flood_stage_cols_blue Named character vector. Blue flood palette.
#' @param flood_stage_cols_red Named character vector. Red flood palette.
#' @param precip_cols Character vector. Colorized precip palette.
#' @param precip_grayscale_cols Character vector. Grayscale precip palette.
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param global_max_precip Numeric. Global max precip (inches) for scale limit.
#' @param global_max_flood_stages Numeric. Max flooded gage count across all
#'   timesteps; sets the flood-status barplot x-axis limit.
#' @param points_range Numeric length-2. Min/max point sizes for point mode.
#' @param logo_path Character. Path to USGS logo PNG.
#' @param hurricane_symbol_path Character. Path to hurricane symbol PNG.
#' @param target_rdg_icon Character. Path to RDG bullseye PNG.
#' @param flood_stage_spike_leg_path Character. Path to spike-mode legend PNG.
#' @param flood_stage_point_leg_path Character. Path to point-mode legend PNG.
#' @param bbox_coords List with `xlim` and `ylim` projected bounding box coords.
#' @param progress_fraction Numeric in [0, 1]. Animation progress.
#' @param storm_info Named list/tibble with `storm_name` and `storm_type_label`.
#' @param timezone_long Character. Olson timezone name for display.
#' @param landfall_dtg POSIXct. Expected landfall time (UTC).
#' @param frame_dir Character. Directory for output PNGs.
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @param precip_grayscale Logical. TRUE for grayscale precip palette.
#' @param flood_groups_now Named list from [split_flood_groups()]. Pre-split,
#'   pre-sorted gage render groups for the current timestep.
#' @param anchors Named list of canvas anchor points from the storm YAML
#'   `anchors:` block. Each is a length-2 numeric c(x, y) in 0-1 canvas coords.
#'   Missing anchors fall back to the hardcoded `default_anchors` below. These
#'   are the few layout knobs worth tuning per storm; in-block offsets are
#'   design constants and stay in the panel builders.
#' @param include_legend Logical. TRUE (default) draws the legend stack
#'   (precip legend, gage icons, flood explainer, flood status bar). FALSE
#'   omits it, e.g. for a social-media crop with a separate static legend.
#' @return Character file path to the saved PNG, or NULL if `flow_now` is empty.
compose_frame <- function(dtg, precip_now, flow_now, storm_now, rdg_now,
                           state_inner_borders, state_outer_lines,
                           major_cities, flood_stage_cols_blue,
                           flood_stage_cols_red, precip_cols,
                           precip_grayscale_cols, flood_spikes,
                           global_max_precip, global_max_flood_stages,
                           points_range,
                           logo_path, hurricane_symbol_path, target_rdg_icon,
                           flood_stage_spike_leg_path,
                           flood_stage_point_leg_path,
                           bbox_coords, progress_fraction,
                           storm_info, timezone_long, landfall_dtg,
                           frame_dir, config_vars, precip_grayscale,
                           flood_groups_now, anchors = list(),
                           include_legend = TRUE, frame_prefix = "frame") {
  font_legend <- config_vars$load_font
  pm <- config_vars$plot_margin

  # Named anchor points on the 0-1 canvas. `legend_box` is the single knob for
  # the whole legend stack — move it to reposition the entire panel for a new
  # storm. title/ocean/progress derive from existing config keys. YAML can
  # override any of these.
  default_anchors <- list(
    title = c(pm, 1 - pm * 1.2),
    legend_box = c(0, 0.275),
    ocean_label = c(config_vars$ocean_label_x,
                    pm + config_vars$ocean_label_y_offset),
    progress = c(config_vars$progress_x, config_vars$progress_y)
  )
  anchors <- modifyList(default_anchors, anchors)

  # Legend blocks position relative to the legend_box origin (top-left of the
  # stack). These offsets are design constants — they describe the legend's
  # internal layout, not the storm — so they stay in R, not YAML.
  lb <- anchors$legend_box
  anchors$precip_legend <- lb + c(0.027, 0)
  anchors$gage_icons <- lb + c(0, -0.029)
  anchors$flood_explain <- lb + c(0.027, -0.112)
  anchors$flood_bar <- lb + c(0.17, -0.249)

  # Anchored label helper: dx/dy are offsets from `anchor`, with dy reading
  # "down from the anchor". Captures font and config so call sites stay terse.
  lbl <- function(text, anchor = "flood_explain", dx = 0, dy = 0,
                  bold = FALSE, italic = FALSE, size = NULL, color = "black") {
    base <- anchors[[anchor]]
    face <- if (bold && italic) "bold.italic"
      else if (bold) "bold"
      else if (italic) "italic"
      else "plain"
    draw_label(text, x = base[1] + dx, y = base[2] - dy,
      size = if (is.null(size)) config_vars$canvas_legend_size else size,
      fontfamily = font_legend, fontface = face,
      hjust = 0, vjust = 1, color = color, lineheight = 1)
  }

  title_block <- build_title_block(
    storm_info, dtg, timezone_long, landfall_dtg, storm_now)

  # Landfall countdown sits right after the timestamp label
  landfall_gap <- 0.01
  timestamp_width_pt <- systemfonts::string_width(
    title_block$timestamp, family = font_legend, weight = "bold",
    size = config_vars$canvas_subtitle_size, res = 72
  )
  landfall_dx <- 0.002 + timestamp_width_pt / (config_vars$width * 72) +
    landfall_gap

  # Classification sits below the timestamp/landfall row
  line_tighten <- 0.8
  timestamp_lineheight_pt <- systemfonts::font_info(
    family = font_legend, weight = "bold",
    size = config_vars$canvas_subtitle_size, res = 72
  )$lineheight
  classification_dy <- 0.050 +
    (timestamp_lineheight_pt * line_tighten) / (config_vars$height * 72)

  if (nrow(flow_now) == 0) return(NULL)

  # --- Flood status barplot ---
  if (include_legend) {
    flood_status_bar <- build_flood_status_bar(
      flow_now, flood_stage_cols_blue, flood_stage_cols_red,
      global_max_flood_stages, precip_grayscale, font_legend, config_vars
    )
  }

  # --- Main map ---
  precip <- build_precip_layer(
    precip_now, precip_cols, precip_grayscale_cols,
    global_max_precip, precip_grayscale, font_legend, config_vars
  )

  p <- ggplot() +
    precip$layers +
    build_basemap(state_inner_borders, state_outer_lines, config_vars) +
    theme(
      text = element_text(family = font_legend),
      legend.spacing.x = unit(0, "cm")
    ) +
    build_flood_layer(
      flood_groups_now, flood_spikes,
      flood_stage_cols_red,
      points_range, font_legend, config_vars
    ) +
    build_cities_layer(major_cities, font_legend, config_vars) +
    build_storm_track(storm_now, dtg, hurricane_symbol_path, config_vars) +
    build_rdg_layer(rdg_now, target_rdg_icon, config_vars) +
    coord_sf(
      xlim = bbox_coords$xlim,
      ylim = bbox_coords$ylim,
      expand = FALSE
    ) +
    theme_void() +
    theme(
      legend.position = "top",
      legend.title = element_text(size = config_vars$font_size),
      legend.text = element_text(size = config_vars$leg_font_size),
      plot.margin = margin(
        t = 10, r = 15, b = 20, l = 15, unit = "pt"),
      plot.title.position = "plot",
      legend.box = "vertical",
      legend.box.just = "center"
    )

  # --- Panels ---
  if (include_legend) {
    legends <- build_legends(
      precip$scale, global_max_precip,
      flood_spikes, flood_stage_spike_leg_path,
      flood_stage_point_leg_path, target_rdg_icon, config_vars
    )
  }

  logo <- image_read(logo_path) |>
    image_resize("x100") |>
    image_colorize(100, "black")

  progress_bar <- build_progress_bar(progress_fraction, config_vars)

  canvas <- rectGrob(
    x = 0, y = 0, width = config_vars$canvas_width,
    height = config_vars$canvas_height,
    gp = gpar(
      fill = config_vars$bg_col, alpha = 1, col = config_vars$bg_col)
  )

  # --- Canvas assembly ---
  # Reads as a table of contents: a base canvas + main map, the title block,
  # then one call per legend panel. Each panel builder returns a list of
  # draw_* layers positioned relative to its anchor.
  p <- ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
    draw_grob(canvas,
      x = 0, y = 1, height = 1, width = 1, hjust = 0, vjust = 1) +
    draw_plot(
      p + theme(
        legend.position = "none",
        plot.title = element_blank()
      ),
      x = config_vars$plot_shift_x, y = config_vars$plot_shift_y,
      height = config_vars$plot_height, width = config_vars$plot_width
    ) +
    draw_image(logo,
      x = 0.9 - pm * 2, y = pm, width = config_vars$logo_width,
      hjust = 0, vjust = 0, halign = 0, valign = 0
    ) +
    lbl(config_vars$ocean_label_text, "ocean_label",
      size = config_vars$ocean_label_size, italic = TRUE,
      color = config_vars$major_cities_text_col) +
    lbl(title_block$storm_name, "title",
      size = config_vars$storm_title_size, bold = TRUE) +
    lbl(title_block$timestamp, "title", dx = 0.002, dy = 0.050,
      size = config_vars$canvas_subtitle_size, bold = TRUE) +
    lbl(title_block$landfall, "title", dx = landfall_dx, dy = 0.050,
      size = config_vars$canvas_subtitle_size) +
    draw_plot(progress_bar,
      x = anchors$progress[1], y = anchors$progress[2],
      width = config_vars$progress_w, height = config_vars$progress_h)

  if (include_legend) {
    p <- p +
      build_precip_legend_panel(legends, global_max_precip, lbl, anchors,
        config_vars) +
      build_gage_icons_panel(legends, lbl, anchors, config_vars) +
      build_flood_status_bar_panel(flood_status_bar, flood_spikes, anchors,
        config_vars) +
      build_flood_explainer_panel(legends, flood_spikes, lbl, anchors,
        config_vars)
  }

  if (!is.null(title_block$classification)) {
    p <- p + lbl(
      title_block$classification, "title", dx = 0.002, dy = classification_dy,
      size = config_vars$canvas_subtitle_size
    )
  }

  # --- Save ---
  timestamp_str <- format(dtg, "%Y%m%dT%H%M")
  dir_create(frame_dir)
  frame_path <- file.path(frame_dir, paste0(frame_prefix, "_", timestamp_str, ".png"))
  ggsave(
    filename = frame_path, plot = p,
    width = config_vars$width, height = config_vars$height,
    dpi = config_vars$dpi, bg = config_vars$bg_col
  )
  return(frame_path)
}
