#' @param title_text_line1 Character. First line of title text (e.g., region or theme).
#' @param title_text_line2 Character. Second line of title text (e.g., event type).
#' @param start_date Date or character. Start date for the event range (e.g., "2025-07-04").
#' @param end_date Date or character. End date for the event range (e.g., "2025-07-07").
#' @param logo_path Character. File path to the logo image (e.g., a USGS logo PNG).
#' @param frame_bg_path Character. File path to the background image (typically the first frame).
#' @param config_vars Named list or dataframe. Configuration variables (e.g., fonts, dpi, plot margins, bg color).
#' @param out_path Character. Output file path to save the generated frame (as PNG).
#'
#' @return Character. The output file path (`out_path`) where the image was saved.
title_frame <- function(title_text_line1, title_text_line2, start_date,
                        end_date, logo_path, frame_bg_path, config_vars,
                        out_path){

  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

  # Font configuration
  font_legend <- config_vars$load_font
  # systemfonts resolves the font from system-installed files via ragg device

  logo <- magick::image_read(logo_path) |>
    magick::image_resize('x100') |>
    magick::image_colorize(100, "black")

  bg_frame <- magick::image_read(frame_bg_path) |>
    magick::image_colorize(opacity = 40, color = config_vars$bg_col)

  canvas <- grid::rectGrob(
    x = 0, y = 0,
    width = 16, height = 9,
    gp = grid::gpar(fill = config_vars$bg_col, alpha = 1, col = config_vars$bg_col)
  )

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
  
  
  ggsave(filename = out_path, plot = p,
         width = config_vars$width, height = config_vars$height,
         dpi = config_vars$dpi, bg = config_vars$bg_col,
         device = ragg::agg_png)

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

  # Font configuration
  font_legend <- config_vars$load_font
  # systemfonts resolves the font from system-installed files via ragg device

  logo <- magick::image_read(logo_path) |>
    magick::image_resize('x100') |>
    magick::image_colorize(100, "black")

  canvas <- grid::rectGrob(
    x = 0, y = 0,
    width = 16, height = 9,
    gp = grid::gpar(fill = bg_col, alpha = 1, col = bg_col)
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
         device = ragg::agg_png)

  return(out_path)

}