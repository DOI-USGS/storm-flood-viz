#' Assemble all visual elements onto the cowplot canvas for one animation frame.
#'
#' @param p ggplot. The themed base map (coord_sf applied, no legend).
#' @param logo magick-image. USGS logo, already resized and colorized.
#' @param flood_stage_leg magick-image. Flood stage legend graphic, resized.
#' @param legend_precip grob. Precipitation color-bar legend from
#'   [build_precip_legend()].
#' @param progress_bar ggplot. Progress bar from [build_progress_bar()].
#' @param flood_status_bar ggplot. Flood status barplot from
#'   [build_flood_bar()].
#' @param p_dot_legend ggplot. Gray dot icon from [build_icon_legends()].
#' @param p_peak_legend ggplot. Spike triangle icon from [build_icon_legends()].
#' @param p_rdg_leg ggplot. RDG bullseye icon from [build_gage_legends()].
#' @param p_decom_leg ggplot. Decommissioned gage X from [build_gage_legends()].
#' @param storm_info tibble. Must contain `storm_name`.
#' @param dtg POSIXct. Current frame timestamp.
#' @param timezone_long Character. Long timezone name for the timestamp label.
#' @param landfall_label Character or NULL. Countdown label shown until landfall.
#' @param classification_label Character or NULL. Storm classification label.
#' @param global_max_precip Numeric. Max precipitation value for the scale label.
#' @param flood_spikes Logical. Controls which legend panel is drawn.
#' @param font_legend Character. Font family for all text elements.
#' @param config_vars Named list. Must contain `bg_col`, `plot_margin`,
#'   `plot_shift_x/y`, `plot_height/width`, `major_cities_text_col`.
#' @return A ggdraw object representing the fully composed frame.
compose_frame <- function(p, logo, flood_stage_leg, legend_precip,
                          progress_bar, flood_status_bar,
                          p_dot_legend, p_peak_legend, p_rdg_leg, p_decom_leg,
                          storm_info, dtg, timezone_long, landfall_label,
                          classification_label, global_max_precip,
                          flood_spikes, font_legend, config_vars) {
  canvas <- grid::rectGrob(
    x = 0, y = 0,
    width = 16, height = 9,
    gp = grid::gpar(
      fill = config_vars$bg_col, alpha = 1,
      col = config_vars$bg_col
    )
  )

  out <- ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
    draw_grob(canvas,
      x = 0, y = 1,
      height = 1, width = 1,
      hjust = 0, vjust = 1
    ) +
    draw_plot(
      p + theme(legend.position = "none", plot.title = element_blank()),
      x = config_vars$plot_shift_x,
      y = config_vars$plot_shift_y,
      height = config_vars$plot_height,
      width = config_vars$plot_width
    ) +
    draw_image(logo,
      x = 0.9 - config_vars$plot_margin * 2,
      y = config_vars$plot_margin * 1,
      width = 0.125,
      hjust = 0, vjust = 0,
      halign = 0, valign = 0
    ) +
    draw_label("Atlantic Ocean",
      x = 0.83, y = config_vars$plot_margin + 0.32,
      fontfamily = font_legend,
      color = config_vars$major_cities_text_col,
      size = 10
    ) +
    draw_label(
      paste("Hurricane", stringr::str_to_sentence(storm_info$storm_name)),
      x = config_vars$plot_margin, y = 1 - config_vars$plot_margin * 1.2,
      size = 31, hjust = 0, vjust = 1,
      fontfamily = font_legend, fontface = "bold",
      color = "black", lineheight = 1
    ) +
    draw_label(
      paste0(format(lubridate::with_tz(dtg, timezone_long), "%b. %d, %Y %H:%M %Z")),
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.055,
      size = 14, hjust = 0, vjust = 1,
      fontfamily = font_legend, fontface = "bold",
      color = "black", lineheight = 1
    ) +
    draw_label(landfall_label,
      x = config_vars$plot_margin + 0.26,
      y = 1 - config_vars$plot_margin - 0.055,
      size = 14, hjust = 0, vjust = 1,
      fontfamily = font_legend,
      color = "black", lineheight = 1
    ) +
    draw_plot(progress_bar,
      x = -0.05, y = -0.001,
      width = 1.1, height = 0.015
    ) +
    draw_plot(legend_precip,
      x = config_vars$plot_margin + 0.052,
      y = 0.227 + 0.01,
      height = 0.05,
      width = 0.42 - config_vars$plot_margin
    ) +
    draw_label("Total rainfall (in)",
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.715 + 0.015,
      size = 12, hjust = 0, vjust = 1,
      fontfamily = font_legend, color = "black", lineheight = 1
    ) +
    draw_label("1",
      x = config_vars$plot_margin + 0.158,
      y = 1 - config_vars$plot_margin - 0.716 + 0.015,
      size = 12, hjust = 0, vjust = 1,
      fontfamily = font_legend, color = "black", lineheight = 1
    ) +
    draw_label(paste(global_max_precip),
      x = config_vars$plot_margin + 0.333,
      y = 1 - config_vars$plot_margin - 0.716 + 0.015,
      size = 12, hjust = 0, vjust = 1,
      fontfamily = font_legend, color = "black", lineheight = 1
    ) +
    draw_label("USGS streamgage",
      x = config_vars$plot_margin + 0.028,
      y = 1 - config_vars$plot_margin - 0.746 + 0.017,
      size = 12, hjust = 0, vjust = 1,
      fontfamily = font_legend, color = "black", lineheight = 1
    ) +
    draw_plot(p_dot_legend,
      x = config_vars$plot_margin - 0.025,
      y = 0.208 + 0.017,
      height = 0.03,
      width = 0.1 - config_vars$plot_margin
    )

  if (flood_spikes) {
    out <- out +
      draw_label("Rapid-Deployment gage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 + 0.019,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_plot(p_rdg_leg,
        x = config_vars$plot_margin - 0.025,
        y = 0.177 + 0.019,
        height = 0.03,
        width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("Out-of-service streamgage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 - 0.008,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_plot(p_decom_leg,
        x = config_vars$plot_margin - 0.025,
        y = 0.144,
        height = 0.08,
        width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("A               appears at the 75th+ percentile",
        x = config_vars$plot_margin + 0.004,
        y = 1 - config_vars$plot_margin - 0.812,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_label("spike",
        x = config_vars$plot_margin + 0.023,
        y = 1 - config_vars$plot_margin - 0.812,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, fontface = "bold",
        color = "black", lineheight = 1
      ) +
      draw_plot(p_peak_legend,
        x = config_vars$plot_margin + 0.32,
        y = 0.147,
        height = 0.03,
        width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("The                 is correlated to flow percentiles",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.84,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_label("height",
        x = config_vars$plot_margin + 0.0415,
        y = 1 - config_vars$plot_margin - 0.84,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, fontface = "bold",
        color = "black", lineheight = 1
      ) +
      draw_image(flood_stage_leg,
        x = config_vars$plot_margin + 0.36,
        y = 0.11,
        width = 0.12, height = 0.12
      ) +
      draw_label("The              is the severity of the flood",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.867,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_label("color",
        x = config_vars$plot_margin + 0.042,
        y = 1 - config_vars$plot_margin - 0.867,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, fontface = "bold",
        color = "black", lineheight = 1
      ) +
      draw_plot(flood_status_bar,
        x = 0.17, y = 0.026,
        width = 0.2, height = 0.055
      )
  } else {
    out <- out +
      draw_label("Rapid-Deployment gage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 + 0.019,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_plot(p_rdg_leg,
        x = config_vars$plot_margin - 0.025,
        y = 0.177 + 0.019,
        height = 0.03,
        width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("Out-of-service streamgage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 - 0.008,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_plot(p_decom_leg,
        x = config_vars$plot_margin - 0.025,
        y = 0.144,
        height = 0.08,
        width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("If it floods:",
        x = config_vars$plot_margin + 0.004,
        y = 1 - config_vars$plot_margin - 0.810,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_label("     The              is the severity of the flood",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.836,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_label("color",
        x = config_vars$plot_margin + 0.062,
        y = 1 - config_vars$plot_margin - 0.836,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, fontface = "bold",
        color = "black", lineheight = 1
      ) +
      draw_plot(flood_status_bar,
        x = 0.189, y = 0.054,
        width = 0.2, height = 0.055
      ) +
      draw_label("      The           is how long it's been flooded",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.934,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, color = "black", lineheight = 1
      ) +
      draw_label("       size",
        x = config_vars$plot_margin + 0.036,
        y = 1 - config_vars$plot_margin - 0.934,
        size = 12, hjust = 0, vjust = 1,
        fontfamily = font_legend, fontface = "bold",
        color = "black", lineheight = 1
      )
  }

  if (!is.null(classification_label)) {
    out <- out + draw_label(
      classification_label,
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.08,
      size = 14, hjust = 0, vjust = 1,
      fontfamily = font_legend, color = "black", lineheight = 1
    )
  }

  out
}
