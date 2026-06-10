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
#' @param peak_height Numeric. Max spike height in projected units.
#' @param y_baseheight Numeric. Spike base offset in projected units.
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
#' @return Character file path to the saved PNG, or NULL if `flow_now` is empty.
compose_frame <- function(dtg, precip_now, flow_now, storm_now, rdg_now,
                           state_inner_borders, state_outer_lines,
                           major_cities, flood_stage_cols_blue,
                           flood_stage_cols_red, precip_cols,
                           precip_grayscale_cols, flood_spikes,
                           global_max_precip, global_max_flood_stages,
                           peak_height, y_baseheight, points_range,
                           logo_path, hurricane_symbol_path, target_rdg_icon,
                           flood_stage_spike_leg_path,
                           flood_stage_point_leg_path,
                           bbox_coords, progress_fraction,
                           storm_info, timezone_long, landfall_dtg,
                           frame_dir, config_vars, precip_grayscale) {
  font_legend <- config_vars$load_font

  # Convenience wrapper — captures font/defaults so call sites only vary in
  # text, position, and the occasional bold or size override.
  lbl <- function(text, x, y, bold = FALSE,
                  size = config_vars$canvas_legend_size, color = "black") {
    draw_label(text, x = x, y = y, size = size,
      fontfamily = font_legend, fontface = if (bold) "bold" else "plain",
      hjust = 0, vjust = 1, color = color, lineheight = 1)
  }

  title_block <- build_title_block(
    storm_info, dtg, timezone_long, landfall_dtg, storm_now)

  if (nrow(flow_now) == 0) return(NULL)

  # --- Flood status barplot ---
  flood_status_bar <- build_flood_status_bar(
    flow_now, flood_stage_cols_blue, flood_stage_cols_red,
    global_max_flood_stages, precip_grayscale, font_legend, config_vars
  )

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
      legend.spacing.x = grid::unit(0, "cm")
    ) +
    build_flood_layer(
      flow_now, flood_spikes,
      flood_stage_cols_red, peak_height, y_baseheight,
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
  legends <- build_legends(
    precip$scale, global_max_precip,
    flood_spikes, flood_stage_spike_leg_path,
    flood_stage_point_leg_path, target_rdg_icon, config_vars
  )

  logo <- magick::image_read(logo_path) |>
    magick::image_resize("x100") |>
    magick::image_colorize(100, "black")

  progress_bar <- build_progress_bar(progress_fraction, config_vars)

  canvas <- grid::rectGrob(
    x = 0, y = 0, width = config_vars$canvas_width,
    height = config_vars$canvas_height,
    gp = grid::gpar(
      fill = config_vars$bg_col, alpha = 1, col = config_vars$bg_col)
  )

  # --- Canvas assembly ---
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
      x = 0.9 - config_vars$plot_margin * 2,
      y = config_vars$plot_margin,
      width = config_vars$logo_width,
      hjust = 0, vjust = 0, halign = 0, valign = 0
    ) +
    lbl(config_vars$ocean_label_text,
      x = config_vars$ocean_label_x,
      y = config_vars$plot_margin + config_vars$ocean_label_y_offset,
      size = config_vars$ocean_label_size,
      color = config_vars$major_cities_text_col
    ) +
    lbl(title_block$storm_name,
      x = config_vars$plot_margin,
      y = 1 - config_vars$plot_margin * 1.2,
      size = config_vars$storm_title_size, bold = TRUE
    ) +
    lbl(title_block$timestamp,
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.055,
      size = config_vars$canvas_subtitle_size, bold = TRUE
    ) +
    lbl(title_block$landfall,
      x = config_vars$plot_margin + 0.26,
      y = 1 - config_vars$plot_margin - 0.055,
      size = config_vars$canvas_subtitle_size
    ) +
    draw_plot(progress_bar,
      x = config_vars$progress_x, y = config_vars$progress_y,
      width = config_vars$progress_w, height = config_vars$progress_h
    ) +
    draw_plot(legends$precip,
      x = config_vars$plot_margin + 0.052,
      y = 0.227 + 0.011,
      height = 0.05, width = 0.42 - config_vars$plot_margin
    ) +
    lbl("Total rainfall (in)",
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.715 + 0.015
    ) +
    lbl("1",
      x = config_vars$plot_margin + 0.158,
      y = 1 - config_vars$plot_margin - 0.716 + 0.015
    ) +
    lbl(paste(global_max_precip),
      x = config_vars$plot_margin + 0.333,
      y = 1 - config_vars$plot_margin - 0.716 + 0.015
    ) +
    lbl("USGS streamgage",
      x = config_vars$plot_margin + 0.028,
      y = 1 - config_vars$plot_margin - 0.746 + 0.017
    ) +
    draw_plot(legends$dot,
      x = config_vars$plot_margin - 0.025,
      y = 0.208 + 0.017,
      height = 0.03, width = 0.1 - config_vars$plot_margin
    )

  if (flood_spikes) {
    p <- p +
      lbl("Rapid-Deployment gage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 + 0.019
      ) +
      draw_plot(legends$rdg,
        x = config_vars$plot_margin - 0.025,
        y = 0.177 + 0.019,
        height = 0.03, width = 0.1 - config_vars$plot_margin
      ) +
      lbl("Out-of-service streamgage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 - 0.008
      ) +
      draw_plot(legends$decom,
        x = config_vars$plot_margin - 0.025,
        y = 0.144,
        height = 0.08, width = 0.1 - config_vars$plot_margin
      ) +
      lbl("A               appears at the 75th+ percentile",
        x = config_vars$plot_margin + 0.004,
        y = 1 - config_vars$plot_margin - 0.812
      ) +
      lbl("spike",
        x = config_vars$plot_margin + 0.023,
        y = 1 - config_vars$plot_margin - 0.812, bold = TRUE
      ) +
      draw_plot(legends$peak,
        x = config_vars$plot_margin + 0.32,
        y = 0.147,
        height = 0.03, width = 0.1 - config_vars$plot_margin
      ) +
      lbl("The                 is correlated to flow percentiles",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.84
      ) +
      lbl("height",
        x = config_vars$plot_margin + 0.0415,
        y = 1 - config_vars$plot_margin - 0.84, bold = TRUE
      ) +
      draw_image(legends$flood_stage,
        x = config_vars$plot_margin + 0.36,
        y = 0.114, width = 0.12, height = 0.12
      ) +
      lbl("The              is the severity of the flood",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.867
      ) +
      lbl("color",
        x = config_vars$plot_margin + 0.042,
        y = 1 - config_vars$plot_margin - 0.867, bold = TRUE
      ) +
      draw_plot(flood_status_bar,
        x = 0.17, y = 0.026, width = 0.2, height = 0.055)
  } else {
    p <- p +
      lbl("Rapid-Deployment gage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 + 0.019
      ) +
      draw_plot(legends$rdg,
        x = config_vars$plot_margin - 0.025,
        y = 0.177 + 0.019,
        height = 0.03, width = 0.1 - config_vars$plot_margin
      ) +
      lbl("Out-of-service streamgage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 - 0.008
      ) +
      draw_plot(legends$decom,
        x = config_vars$plot_margin - 0.025,
        y = 0.144,
        height = 0.08, width = 0.1 - config_vars$plot_margin
      ) +
      lbl("If it floods:",
        x = config_vars$plot_margin + 0.004,
        y = 1 - config_vars$plot_margin - 0.810
      ) +
      lbl("     The              is the severity of the flood",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.836
      ) +
      lbl("color",
        x = config_vars$plot_margin + 0.062,
        y = 1 - config_vars$plot_margin - 0.836, bold = TRUE
      ) +
      draw_plot(flood_status_bar,
        x = 0.189, y = 0.054, width = 0.2, height = 0.055) +
      lbl("      The           is correlated to flow percentiles",
        x = config_vars$plot_margin - 0.02,
        y = 1 - config_vars$plot_margin - 0.934
      ) +
      lbl("       size",
        x = config_vars$plot_margin + 0.014,
        y = 1 - config_vars$plot_margin - 0.934, bold = TRUE
      ) +
      draw_image(legends$flood_stage,
        x = config_vars$plot_margin + 0.355,
        y = 0.011, width = 0.08, height = 0.14,
        scale = 1.0
      )
  }

  if (!is.null(title_block$classification)) {
    p <- p + lbl(
      title_block$classification,
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.08,
      size = config_vars$canvas_subtitle_size
    )
  }

  # --- Save ---
  timestamp_str <- format(dtg, "%Y%m%dT%H%M")
  fs::dir_create(frame_dir)
  frame_path <- file.path(frame_dir, paste0("frame_", timestamp_str, ".png"))
  ggsave(
    filename = frame_path, plot = p,
    width = config_vars$width, height = config_vars$height,
    dpi = config_vars$dpi, bg = config_vars$bg_col
  )
  return(frame_path)
}
