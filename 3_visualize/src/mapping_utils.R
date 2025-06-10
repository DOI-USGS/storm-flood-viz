#' Create a single map frame visualizing flood stage impacts at a timestep
#'
#' @param dtg POSIXct timestamp to label and filter data.
#' @param precip_now A dataframe of gridded precipitation at the current timestep.
#' @param flow_now A dataframe of streamgage data (one row per gage at current timestep),
#'   with flood thresholds and cumulative flood duration.
#' @param storm_now An sf object representing the storm path up to and including this timestep.
#' @param state_borders sf object of CONUS boundaries.
#' @param state_inner_borders sf object of internal CONUS state lines.
#' @param major_cities sf object with a NAME column.
#' @param flood_stage_cols Named color vector for flood status ("Flood", "Moderate", etc).
#' @param percip_cols viridisLite color scheme (e.g., "mako").
#' @param config_vars Named list of styling and theme options.
#' @param peak_height Maximum height of flood lines (numeric).
#' @param frame_dir Character path for saving PNGs.
#' @param logo_path Charcter path for USGS logo.
#' @return Character file path to PNG frame.
hurricane_flood_stage_frame <- function(dtg, precip_now, flow_now, storm_now,
                                        state_borders, state_inner_borders,
                                        major_cities, flood_stage_cols,
                                        percip_cols, config_vars, peak_height,
                                        frame_dir, logo_path) {
  
  font_legend <- config_vars$load_font
  font_add_google(font_legend)
  showtext_opts(dpi = config_vars$dpi, regular.wt = 200, bold.wt = 700)
  showtext_auto(enable = TRUE)
  
  # return NA if no streamgage data
  if (nrow(flow_now) == 0) {
    return(NA_character_)
  }
  
  global_max_duration <- max(flow_now$duration_above_flood_hr, na.rm = TRUE)

  p <- ggplot() +
    geom_raster(data = precip_now, aes(x = x, y = y, fill = precip_in), alpha = 0.4) +
    geom_sf(data = state_inner_borders, color = config_vars$state_outline_col,
            fill = NA, linewidth = 0.7) +
    scale_fill_stepsn(
      colors = scales::alpha(
        viridisLite::viridis(7, option = percip_cols, direction = -1), 0.6),
      breaks = c(1, 2, 4, 6, 8, 10, 12),   
      limits = c(1, 14),                   
      labels = c("1", "2", "4", "6", "8", "10", "12+"),
      name = "Total rainfall (in) \nData: NOAA",
      guide = guide_coloursteps(
        title.theme = element_text(family = font_legend, size = config_vars$font_size),
        title.position = "top", title.vjust = 2,
        direction = "vertical", barwidth = unit(0.6, "cm"),
        barheight = unit(8, "cm"), label.position = "right"
      )
    ) +
    theme(text = element_text(family = font_legend, size = config_vars$font_size))
  
  # Plot non-flooded gages
  p <- p +
    geom_sf(
      data = flow_now |> filter(!is_flooded),
      aes(geometry = geometry),
      shape = 21, fill = flood_stage_cols["Not flooded"], size = 1,
      stroke = 0.1, color = config_vars$streamgage_col, alpha = 0.8,
      show.legend = FALSE
    )
  
  # Peak style lines for flooded sites
  flow_now_coords <- flow_now |> 
    filter(is_flooded) |> 
    mutate(
      x = sf::st_coordinates(geometry)[, 1],
      y = sf::st_coordinates(geometry)[, 2],
      xend = x,
      yend = y + (duration_above_flood_hr / global_max_duration) * peak_height
    )
  
  p <- p +
    ggforce::geom_link(
      data = flow_now_coords,
      aes(x = x, xend = xend, y = y, yend = yend,
          color = flood_status,
          alpha = after_stat(I(index) + 0.2),
          linewidth = after_stat(I((1 - index) * 2))),
      show.legend = FALSE
    ) +
    # Dummy points for legend
    geom_point(
      data = data.frame(flood_status = factor(names(flood_stage_cols),
                                              levels = names(flood_stage_cols)),
                        x = NA_real_, y = NA_real_),
      aes(x = x, y = y, color = flood_status),
      shape = 22, size = 5, stroke = 0.2, fill = flood_stage_cols,
      show.legend = TRUE, na.rm = TRUE
    ) +
    scale_color_manual(
      name = "Peak flood stage",
      values = flood_stage_cols,
      limits = names(flood_stage_cols),
      drop = FALSE,
      na.value = config_vars$streamgage_col,
      guide = guide_legend(
        direction = "vertical",
        override.aes = list(
          shape = rep(22, length(flood_stage_cols)),
          size = rep(6, length(flood_stage_cols)),
          fill = unname(flood_stage_cols),
          color = NA,
          stroke = rep(0.1, length(flood_stage_cols))
        ),
        label.theme = element_text(size = config_vars$font_size, family = font_legend),
        title.theme = element_text(size = config_vars$font_size, family = font_legend),
        keyheight = unit(0.8, "cm")
      )
    ) +
    theme(
      text = element_text(family = font_legend)
    ) +
    geom_sf(data = major_cities, shape = 23, fill = NA,
            color = config_vars$major_cities_col, size = 2.5, stroke = 0.3) +
    geom_sf_text(data = major_cities, aes(label = NAME),
                 color = config_vars$major_cities_text_col,
                 size = 3, nudge_y = 50000, family = font_legend) 
  
  # Add storm path
  p <- p +
    geom_path(data = storm_now, aes(x = X, y = Y),
              color = config_vars$storm_path_col, linewidth = 1, alpha = 0.6) +
    geom_sf(data = storm_now, color = config_vars$storm_path_col,
            size = 1.5, alpha = 0.4) +
    geom_sf(data = storm_now |> filter(DTG == dtg),
            color = config_vars$storm_path_col, size = 1.5)
  
  
  # Final plot theme and save
  p <- p +
    coord_sf(xlim = range(precip_now$x, na.rm = TRUE),
             ylim = range(precip_now$y, na.rm = TRUE), expand = FALSE) +
    labs(title = paste0(
      "Hurricane ", stringr::str_to_sentence(unique(storm_now$STORMNAME)), "\n",
      format(dtg, "%Y-%m-%d %H:%M:%S")
    )) +
    theme_void() +
    theme(
      legend.position = "top",
      legend.title = element_text(size = config_vars$font_size),
      legend.text = element_text(size = config_vars$leg_font_size),
      plot.margin = margin(t = 10, r = 15, b = 20, l = 15, unit = "pt"),
      plot.title = element_text(hjust = 0.5, size = config_vars$font_size_title,
                                face = "bold", family = font_legend,
                                margin = margin(b = 10)),
      plot.title.position = "plot",
      legend.box = "vertical",
      legend.box.just = "center"
    )
  
  p_precip_legend <- p +
    theme(legend.position = "right",
          plot.title = element_blank()) +
    guides(color = "none")  # removes flood legend
  
  p_flood_legend <- p +
    theme(legend.position = "right",
          plot.title = element_blank()) +
    guides(fill = "none")  # removes precip legend
  
  
  legend_precip <- get_legend_non0(p_precip_legend)
  legend_flood <- get_legend_non0(p_flood_legend)

  logo <- magick::image_read(logo_path) |> 
    magick::image_resize('x100') |> 
    magick::image_colorize(100, "black")
  
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
    draw_plot(p + theme(legend.position = 'none',
                         plot.title = element_blank()),
               x = (1-config_vars$plot_margin)*-1.7,
               y = -0.01,
               height = 1.125,
               width = (1-config_vars$plot_margin)+3.3) + 
    draw_image(logo,
               x = 0.9 - config_vars$plot_margin*2,
               y = config_vars$plot_margin*1,
               width = 0.125,
               hjust = 0, vjust = 0, 
               halign = 0, valign = 0) +
    draw_label(paste0(
      "Hurricane Helene", "\n",
      format(dtg, "%Y-%m-%d %H:%M:%S")),
      x = config_vars$plot_margin, y = 1-config_vars$plot_margin*1.2,
               size = 24,
               hjust = 0,
               vjust = 1,
               fontfamily = font_legend,
               fontface = "bold",
               color = "black",
               lineheight = 1) +
    draw_plot(legend_precip,
              x = (1-config_vars$plot_margin)*-0.04,
              y = 0.17,
              height = 0.42,
              width = 0.42-config_vars$plot_margin) +
    draw_plot(legend_flood,
              x = (1-config_vars$plot_margin)*-0.07,
              y = 0.54,
              height = 0.42,
              width = 0.42-config_vars$plot_margin) + 
    draw_label("Atlantic Ocean",
               x = 0.83, y = config_vars$plot_margin + 0.32,
               fontfamily = font_legend,
               color = config_vars$major_cities_text_col,
               size = 10)
  
  
  fs::dir_create(frame_dir)
  timestamp_str <- format(dtg, "%Y%m%dT%H%M")
  frame_path <- file.path(frame_dir, paste0("frame_", timestamp_str, ".png"))
  
  ggsave(filename = frame_path, plot = p,
         width = config_vars$width, height = config_vars$height,
         dpi = config_vars$dpi, bg = config_vars$bg_col)
  
  return(frame_path)
}


#' Get legend (and avoid returning zeroGrob objects)
#'
#' @param plot a ggplot
#'
#' @return a grob with "guide-box" component name (i.e., a legend)
#'
get_legend_non0 <- function(plot) {
  legends <- cowplot::get_plot_component(plot, "guide-box", return_all = TRUE)
  non0_idx <- which(!purrr::map_lgl(legends, ~ inherits(., what = "zeroGrob")))
  
  if (length(non0_idx) == 0) {
    cli::cli_warn(c("!" = "No non-zeroGrob legends. Returning `NULL`."))
    return(NULL)
  }
  
  if (length(non0_idx) > 1) {
    cli::cli_warn(c("!" = "Multiple legends exist. Returning the first one."))
  }
  
  legends[non0_idx][[1]]
}
