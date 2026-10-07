#' @param title_text_line1 Character. First line of title text (e.g., region or theme).
#' @param title_text_line2 Character. Second line of title text (e.g., event type).
#' @param start_date Date or character. Start date for the event range (e.g., "2025-07-04").
#' @param end_date Date or character. End date for the event range (e.g., "2025-07-07").
#' @param logo_path Character. File path to the logo image (e.g., a USGS logo PNG).
#' @param frame_bg_path Character. File path to the background image (typically the first frame).
#' @param config_vars Named list or dataframe. Configuration variables (e.g., fonts, dpi, plot margins, bg color).
#' @param out_path Character. Output file path to save the generated frame (as PNG).
#'
#' @param layout "hold" (default, 1:1 title-hold frame) or "cover" (IG
#'   3-line cover card: pretitle / title_text_line1 / month-year).
#' @param pretitle Character. Small line above title_text_line1; cover only.
#' @return Character. The output file path (`out_path`) where the image was saved.
title_frame <- function(title_text_line1, title_text_line2, start_date,
                        end_date, logo_path, frame_bg_path, config_vars,
                        out_path, layout = "hold", pretitle = NULL){

  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  font_legend <- config_vars$load_font

  logo <- image_read(logo_path) |>
    image_resize('x100') |>
    image_colorize(100, "black")

  canvas <- rectGrob(
    x = 0, y = 0,
    width = 16, height = 9,
    gp = gpar(fill = config_vars$bg_col, alpha = 1, col = config_vars$bg_col)
  )

  if (layout == "cover") {
    # crop-to-fill so a square source frame isn't stretched on the 4:5 canvas.
    # cover_pan_y pans the crop window within the zoomed source (0 = centered,
    # 1 = as far down as possible) instead of moving the placed image, which
    # would leave a gap since it already exactly fills the canvas. Both are
    # storm-specific (depend on the chosen background frame), so they come
    # from config_vars, not hardcoded here.
    cover_zoom <- config_vars$cover_zoom
    if (is.null(cover_zoom)) cover_zoom <- 1.58
    cover_pan_y <- config_vars$cover_pan_y
    if (is.null(cover_pan_y)) cover_pan_y <- 0
    target_px <- round(c(config_vars$width, config_vars$height) * config_vars$dpi * cover_zoom)
    crop_px <- round(c(config_vars$width, config_vars$height) * config_vars$dpi)
    offset_y <- round((target_px[2] - crop_px[2]) / 2 * cover_pan_y)
    bg_frame <- image_read(frame_bg_path) |>
      image_resize(sprintf("%dx%d^", target_px[1], target_px[2])) |>
      image_crop(sprintf("%dx%d+0+%d", crop_px[1], crop_px[2], offset_y),
                 gravity = "center") |>
    image_colorize(opacity = 15, color = config_vars$bg_col)

    p <- ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
      draw_grob(canvas, x = 0, y = 1, height = 1, width = 1, hjust = 0, vjust = 1) +
      draw_image(bg_frame, x = 0, y = 1, height = 1, width = 1, hjust = 0, vjust = 1) +
      draw_image(logo,
                 x = 0.9 - config_vars$plot_margin * 2, y = config_vars$plot_margin,
                 width = config_vars$logo_width, hjust = 0, vjust = 0,
                 halign = 0, valign = 0) +
      draw_label(pretitle, x = 0.032 + config_vars$plot_margin, y = 0.92, size = 28,
                 hjust = 0, vjust = 1, fontfamily = font_legend,
                 fontface = "bold", color = "black") +
      draw_label(title_text_line1, x = 0.03 + config_vars$plot_margin, y = 0.87, size = 48,
                 hjust = 0, vjust = 1, fontfamily = font_legend, fontface = "bold",
                 color = "black", lineheight = 0.95) +
      draw_label(format(as.Date(start_date), "%B %Y"),
                 x = 0.03 + config_vars$plot_margin, y = 0.80, size = 24,
                 hjust = 0, vjust = 1, fontfamily = font_legend, color = "black")
  } else {
    bg_frame <- image_read(frame_bg_path) |>
      image_colorize(opacity = 40, color = config_vars$bg_col)

    p <- ggdraw(xlim = c(0, 1), ylim = c(0,1)) +
      draw_grob(canvas,
                x = 0, y = 1,
                height = 1, width = 1,
                hjust = 0, vjust = 1) +
      draw_image(bg_frame,
                 x = -0.40, y = 3.6,
                 height = 6.4, width = 1.95,
                 hjust = 0, vjust = 1) +
      draw_image(logo,
                 x = 0.9 - config_vars$plot_margin * 2,
                 y = config_vars$plot_margin * 1,
                 width = 0.125,
                 hjust = 0, vjust = 0,
                 halign = 0, valign = 0) +
      draw_label(title_text_line1,
                 x = config_vars$plot_margin, y = 0.25,
                 size = 48,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 fontface = "bold",
                 color = "black",
                 lineheight = 1) +
      draw_label(title_text_line2,
                 x = config_vars$plot_margin + 0.01, y = 0.17,
                 size = 48,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 fontface = "bold",
                 color = "black",
                 lineheight = 1) +
      draw_label(paste0(format(as.Date(start_date), "%b. "),
                        as.integer(format(as.Date(start_date), "%d")), " – ",
                        format(as.Date(end_date), "%b. "),
                        as.integer(format(as.Date(end_date), "%d")), " ",
                        format(as.Date(end_date), "%Y")),
                 x = config_vars$plot_margin + 0.01, y = 0.08,
                 size = 28,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 color = "black",
                 lineheight = 1)
  }

  ggsave(filename = out_path, plot = p,
         width = config_vars$width, height = config_vars$height,
         dpi = config_vars$dpi, bg = config_vars$bg_col,
         device = agg_png)

  return(out_path)

}

#' @param end_text_line1 Character. First line of title text
#' @param end_text_line2 Character. Second line of title text
#' @param end_text_line3 Character. Third line of title text
#' @param logo_path Character. File path to the logo image (e.g., a USGS logo PNG).
#' @param config_vars Named list or dataframe. Configuration variables (e.g., fonts, dpi, plot margins, bg color).
#' @param out_path Character. Output file path to save the generated frame (as PNG).
#' @param bg_col Character. hex code for background color.
#'
#' @return Character. The output file path (`out_path`) where the image was saved.
end_frame <- function(end_text_line1, end_text_line2, end_text_line3,
                      logo_path, config_vars, bg_col, out_path) {

  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  font_legend <- config_vars$load_font

  logo <- image_read(logo_path) |>
    image_resize('x100') |>
    image_colorize(100, "black")

  canvas <- rectGrob(
    x = 0, y = 0,
    width = 16, height = 9,
    gp = gpar(fill = bg_col, alpha = 1, col = bg_col)
  )

  p <- ggdraw(xlim = c(0, 1), ylim = c(0,1)) +
    draw_grob(canvas,
              x = 0, y = 1,
              height = 1, width = 1,
              hjust = 0, vjust = 1) +
    draw_image(logo,
               x = 0.9 - config_vars$plot_margin * 2,
               y = config_vars$plot_margin * 1,
               width = 0.125,
               hjust = 0, vjust = 0,
               halign = 0, valign = 0) +
    draw_label(end_text_line1,
               x = config_vars$plot_margin + 0.48,
               y = 0.6,
               size = 38,
               hjust = 0.5,
               fontfamily = font_legend,
               fontface = "bold",
               color = "black",
               lineheight = 1) +
    draw_label(end_text_line2,
               x = config_vars$plot_margin + 0.48,
               y = 0.52,
               size = 25.5,
               hjust = 0.5,
               fontfamily = font_legend,
               color = "black",
               lineheight = 1) +
    draw_label(end_text_line3,
               x = config_vars$plot_margin + 0.48,
               y = 0.47,
               size = 25.5,
               hjust = 0.5,
               fontfamily = font_legend,
               color = "black",
               lineheight = 1)

  ggsave(filename = out_path, plot = p,
         width = config_vars$width, height = config_vars$height,
         dpi = config_vars$dpi, bg = bg_col,
         device = agg_png)

  return(out_path)

}