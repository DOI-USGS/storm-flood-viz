#' Create a single map frame visualizing flood stage impacts at a timestep
#'
#' @param dtg POSIXct timestamp to label and filter data.
#' @param precip_now A dataframe of gridded precipitation at the current timestep.
#' @param flow_now A dataframe of streamgage data (one row per gage at current timestep),
#'   with flood thresholds and cumulative flood duration.
#' @param storm_now An sf object representing the storm path up to and including this timestep.
#' @param state_borders sf object of CONUS boundaries.
#' @param state_inner_borders sf object of internal CONUS state lines.
#' @param state_outer_lines sf object of outer CONUS state lines.
#' @param major_cities sf object with a NAME column.
#' @param flood_stage_cols Named color vector for flood status ("Flood", "Moderate", etc).
#' @param precip_cols viridisLite color scheme (e.g., "mako").
#' @param config_vars Named list of styling and theme options.
#' @param peak_height Maximum height of flood lines (numeric).
#' @param global_max_duration Numeric. The maximum `duration_above_flood_hr` across all time steps.
#' @param frame_dir Character path for saving PNGs.
#' @param logo_path Charcter path for USGS logo.
#' @param hurricane_symbol_path Charcter path for hurricane symbology.
#' @param landfall_dtg POSIXct. The expected date-time of hurricane landfall, used to calculate and display a countdown label.
#' @param progress_fraction Numeric value between 0 and 1 indicating progress through the animation.
#' @return Character file path to PNG frame.
hurricane_flood_stage_frame <- function(dtg, precip_now, flow_now, storm_now,
                                        state_borders, state_inner_borders,
                                        major_cities, flood_stage_cols,
                                        precip_cols, config_vars, peak_height,
                                        frame_dir, logo_path, state_outer_lines,
                                        hurricane_symbol_path, global_max_duration,
                                        landfall_dtg, progress_fraction) {
  
  # Font configuration
  font_legend <- config_vars$load_font
  font_add_google(font_legend)
  showtext_opts(dpi = config_vars$dpi, regular.wt = 200, bold.wt = 700)
  showtext_auto(enable = TRUE)
  
  # Landfall label
  time_to_landfall <- difftime(landfall_dtg, dtg, units = "hours")
  
  # only show label until 2 hours after landfall
  show_landfall_label <- time_to_landfall > -2 & time_to_landfall <= 72  
  landfall_label <- if (show_landfall_label && time_to_landfall > 0) {
    paste0(round(as.numeric(time_to_landfall), 1), " hours to landfall")
  } else {
    NULL
  }
  
  # return NA if no streamgage data
  if (nrow(flow_now) == 0) {
    return(NULL)
  }
  
  # Storm classification label 
  # latest known classification (up to the current frame's dtg) is shown.
  storm_match <- storm_now |>
    filter(DTG <= dtg, !is.na(storm_type_full)) |>
    slice_tail(n = 1)
  
  # Only proceed if a valid match exists
  classification_label <- NULL
  if (nrow(storm_match) > 0) {
    classification_label <- paste0(storm_match$storm_type_full[1])
  }
  
  # Flood staus dynamic barplot 
  flood_status_summary <- flow_now |>
    filter(flood_status %in% c("Flood", "Moderate", "Major")) |>
    count(flood_status) |>
    mutate(
      flood_status = factor(flood_status, levels = c("Flood", "Moderate", "Major"))) |>
    arrange(flood_status)

  flood_status_bar <- ggplot(flood_status_summary, aes(x = 1, y = n, fill = flood_status)) +
    geom_col(width = 0.2, color = config_vars$bg_col, linewidth = 0.2, alpha = 0.8) +
    geom_text(
      aes(label = n),
      position = position_stack(vjust = 0.5),
      size = 3, family = font_legend,
      color = config_vars$bg_col
    ) +
    scale_fill_manual(values = flood_stage_cols, drop = FALSE) +
    scale_color_manual(values = flood_stage_cols, guide = "none") +
    coord_cartesian(clip = "off") +
    labs(title = "Gages in \nflood status", x = NULL, y = NULL) +
    theme_void(base_family = font_legend) +
    theme(
      plot.title = element_text(hjust = 0, size = config_vars$font_size, margin = margin(b = 6)),
      legend.position = "none"
    )
  
  p <- ggplot() +
    geom_raster(data = precip_now, aes(x = x, y = y, fill = precip_in), alpha = 0.4) +
    geom_sf(data = state_inner_borders, color = config_vars$state_inner_borders_col,
            fill = NA, linewidth = 0.25) +
    geom_sf(data = state_outer_lines, color = config_vars$state_outer_lines_col,
            fill = NA, linewidth = 0.3) + 
    scale_fill_stepsn(
      colors = scales::alpha(
        viridisLite::viridis(7, option = precip_cols, direction = -1), 0.6),
      breaks = c(1, 2, 4, 6, 8, 10, 12),   
      limits = c(1, 14),                   
      labels = c("1", "2", "4", "6", "8", "10", "12+"),
      name = "Total rainfall (in) \nData: NOAA",
      na.value = scales::alpha("white", 0),
      guide = guide_coloursteps(
        title.theme = element_text(family = font_legend, size = config_vars$font_size),
        title.position = "top", title.vjust = 2,
        direction = "vertical", barwidth = unit(0.6, "cm"),
        barheight = unit(5.5, "cm"), label.position = "right"
      )
    ) +
    theme(text = element_text(family = font_legend, size = config_vars$font_size))
  
  # Plot all non and  flooded gages
  p <- p + ggnewscale::new_scale_fill() +
    geom_sf(
      data = flow_now |> mutate(flood_status = factor(flood_status, levels = names(flood_stage_cols))) |>
        filter(!is.na(flood_status)),  # Ensure fill values are valid
      aes(geometry = geometry, fill = flood_status),
      shape = 21, size = 0.8,
      stroke = 0.1,
      color = config_vars$bg_col,
      alpha = 0.8,
      show.legend = TRUE  # set to FALSE if you don’t want legend
    ) +
    scale_fill_manual(
      values = flood_stage_cols,
      drop = FALSE,
      name = "Flood status"
    )
  
  # Peak style lines for flooded sites
  flow_now_coords <- flow_now |> 
    filter(is_flooded) |> 
    arrange(desc(duration_above_flood_hr)) |> 
    mutate(
      x = sf::st_coordinates(geometry)[, 1],
      y = sf::st_coordinates(geometry)[, 2],
      xend = x,
      yend = y + (duration_above_flood_hr / global_max_duration) * peak_height
    )
  
  p <-  p + 
    # add white layer behind peaks to have them pop more
    ggforce::geom_link(
      data = flow_now_coords,
      aes(x = x, xend = xend, y = y, yend = yend,
          linewidth = after_stat(I((1 - index) * 2))),
      color = config_vars$bg_col,
      alpha = 0.9,
      show.legend = FALSE
    ) +
    # Colored peak lines on top
    ggforce::geom_link(
      data = flow_now_coords,
      aes(x = x, xend = xend, y = y, yend = yend,
          color = flood_status,
          alpha = after_stat(I(index)),
          linewidth = after_stat(I((1 - index) * 2))),
      show.legend = FALSE
    ) +
    # # Dummy points for legend
    # geom_point(
    #   data = data.frame(flood_status = factor(names(flood_stage_cols),
    #                                           levels = names(flood_stage_cols)),
    #                     x = NA_real_, y = NA_real_),
    #   aes(x = x, y = y, color = flood_status),
    #   shape = 22, size = 5, stroke = 0.2, fill = flood_stage_cols,
    #   show.legend = TRUE, na.rm = TRUE
    # ) +
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
          alpha = 0.8,
          color = NA,
          stroke = rep(0.1, length(flood_stage_cols))
        ),
        label.theme = element_text(size = config_vars$font_size, family = font_legend),
        title.theme = element_text(size = config_vars$font_size, family = font_legend),
        keyheight = unit(0.7, "cm")
      )
    ) +
    theme(
      text = element_text(family = font_legend)
    ) +
    geom_sf(data = major_cities, shape = 23, fill = NA,
            color = config_vars$major_cities_col, size = 1.75, stroke = 0.3) +
    geom_sf_text(data = major_cities, aes(label = NAME),
                 color = config_vars$major_cities_text_col,
                 size = 3, nudge_y = 50000, family = font_legend) 
  
  # Filter storm points up to current DTG
  past_storm_points <- dplyr::filter(storm_now, DTG <= dtg)
  
  # Get the latest point (this will be the only one with the icon)
  latest_point <- dplyr::slice_tail(past_storm_points, n = 1)
  
  # Plot path and only the latest symbol
  p <- p +
    geom_path(
      data = past_storm_points,
      aes(x = X, y = Y),
      color = config_vars$storm_path_col,
      linewidth = 0.8
    ) +
    ggimage::geom_image(
      data = latest_point,
      aes(x = X, y = Y),
      image = hurricane_symbol_path,
      size = 0.035
    )
  
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
  
  # Progress bar plot
  progress_bar <- ggplot() +
    geom_rect(aes(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
              fill = config_vars$progress_bar_bg_col, color = NA ) +
    geom_rect(aes(xmin = 0, xmax = progress_fraction, ymin = 0, ymax = 1),
              fill = config_vars$progress_bar_col, color = NA) +
    theme_void() +
    theme(
      plot.margin = margin(0, 0, 0, 0),
      panel.background = element_rect(fill = NA, color = NA)
    )
  
  canvas <- grid::rectGrob(
    x = 0, y = 0, 
    width = 16, height = 9,
    gp = grid::gpar(fill = config_vars$bg_col, alpha = 1, col =  config_vars$bg_col)
  )
  
  p <- ggdraw(xlim = c(0, 1), ylim = c(0,1)) +
    draw_grob(canvas,
              x = 0, y = 1,
              height = 1, width = 1,
              hjust = 0, vjust = 1) +
    draw_plot(p + theme(legend.position = 'none',
                         plot.title = element_blank()),
              # shifting plot for focus on florida/south atlantic region
              # will need to be adjusted if storm is focused elsewhere
               x = (1-config_vars$plot_margin)*-1.75,
               y = -0.01,
               height = 1.125,
               width = (1-config_vars$plot_margin)+3.3) + 
    draw_image(logo,
               x = 0.9 - config_vars$plot_margin*2,
               y = config_vars$plot_margin*1,
               width = 0.125,
               hjust = 0, vjust = 0, 
               halign = 0, valign = 0) +
    draw_label("Atlantic Ocean",
               x = 0.83, y = config_vars$plot_margin + 0.32,
               fontfamily = font_legend,
               color = config_vars$major_cities_text_col,
               size = 10) + 
    draw_label("Hurricane Helene",
      x = config_vars$plot_margin, y = 1-config_vars$plot_margin*1.2,
               size = 24,
               hjust = 0,
               vjust = 1,
               fontfamily = font_legend,
               fontface = "bold",
               color = "black",
               lineheight = 1) +
      draw_label(paste0(format(dtg, "%b. %d, %Y %H:%M")),
        x = config_vars$plot_margin + 0.002, y = 1-config_vars$plot_margin-0.05,
        size = 14,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        fontface = "bold",
        color = "black",
        lineheight = 1) + 
      draw_label(
        landfall_label,
        x = config_vars$plot_margin + 0.215, 
        y = 1-config_vars$plot_margin-0.05,
        size = 14,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1) + 
    # draw_plot(legend_precip,
    #           x = (1-config_vars$plot_margin)*-0.04,
    #           y = 0.44,
    #           height = 0.05,
    #           width = 0.42-config_vars$plot_margin) +
    # draw_plot(legend_flood,
    #           x = (1-config_vars$plot_margin)*-0.07,
    #           y = 0.522,
    #           height = 0.42,
    #           width = 0.42-config_vars$plot_margin) + 
    # draw_plot(flood_status_bar,
    #           x = 0.036,
    #           y = 0.02,
    #           width = 0.036,
    #           height = 0.26) +
    draw_plot(progress_bar,
              x = -0.05,
              y = -0.001,
              width = 1.1,
              height = 0.015)
  
  if (!is.null(classification_label)) {
    p <- p + draw_label(
      classification_label,
      x = config_vars$plot_margin + 0.002,
      y = 1-config_vars$plot_margin - 0.08,
      size = 14,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    )
  }
  
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