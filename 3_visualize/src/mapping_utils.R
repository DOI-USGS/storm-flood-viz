#' Create a single map frame visualizing flood stage impacts at a timestep
#'
#' @param dtg POSIXct timestamp to label and filter data.
#' @param precip_now A dataframe of gridded precipitation at the current timestep.
#' @param flow_now A dataframe of streamgage data (one row per gage at current timestep),
#'   with flood thresholds and cumulative flood duration.
#' @param storm_now An sf object representing the storm path up to and including this timestep.
#' @param rdg_now, An sf object representing rapid deployment gage points and including this timestep
#' @param state_borders sf object of CONUS boundaries.
#' @param state_inner_borders sf object of internal CONUS state lines.
#' @param state_outer_lines sf object of outer CONUS state lines.
#' @param major_cities sf object with a NAME column.
#' @param precip_cols colorized precip scheme
#' @param config_vars Named list of styling and theme options.
#' @param peak_height Maximum height of flood lines (numeric).
#' @param global_max_duration Numeric. The maximum `duration_above_flood_hr` across all time steps.
#' @param frame_dir Character path for saving flood stage frame PNGs.
#' @param logo_path Character path for USGS logo.
#' @param hurricane_symbol_path Character path for hurricane symbology.
#' @param landfall_dtg POSIXct. The expected date-time of hurricane landfall, used to calculate and display a countdown label.
#' @param progress_fraction Numeric value between 0 and 1 indicating progress through the animation.
#' @param flood_stage_spike_leg_path Character path for custom flood stage spikes height explainer legend.
#' @param flood_stage_point_leg_path Character path for custom flood stage points size explainer legend.
#' @param precip_grayscale Logical. If TRUE, use a grayscale color palette for precipitation; if FALSE, use the associated colorized palette.
#' @param flood_spikes Logical. If TRUE, use spikes for visualizing durations above flood stage for flooded gages; if FALSE, use sized flood points instead.
#' @param global_max_precip Numeric value indicating the global max precipitation (in) value to set as precip legend limit.
#' @param global_max_flood_stages Numeric value indicating the single highest count of flooded gages across all timesteps to set as x-limit on flooding barplot
#' @param storm_info tibble of storm information including storm_name, storm_code, and storm_best_track_url from NOAA.
#' @param precip_grayscale_cols vector of precipitation grayscale colors (7)
#' @param y_baseheight numeric value to add to base height of yend for spikes, so that peaks are immediately visible as peaks when a gage floods
#' @param points_range, numeric values for sizing points in `scale_size_continuous()`
#' @param target_rdg_icon, Character path for target icon for rapid deployment gages points.
#' @param timezone_long, Character long name for timezone to be added to map
#' @param bbox_coords A list with named numeric vectors `xlim` and `ylim`,
#' representing the projected bounding box coordinates (xmin/xmax and ymin/ymax)
#'  to be used in `coord_sf()` for consistent map extent across frames

#' @return Character file path to PNG frame.
hurricane_flood_stage_frames <- function(dtg, precip_now, flow_now, storm_now,
                                         state_borders, state_inner_borders,
                                         major_cities, flood_stage_cols_blue,
                                         flood_stage_cols_red, precip_cols,
                                         config_vars, peak_height, frame_dir,
                                         logo_path, bbox_coords,
                                         state_outer_lines,
                                         hurricane_symbol_path,
                                         global_max_duration,
                                         landfall_dtg, progress_fraction,
                                         flood_stage_point_leg_path,
                                         flood_stage_spike_leg_path,
                                         precip_grayscale,
                                         global_max_precip, flood_spikes,
                                         storm_info, global_max_flood_stages,
                                         precip_grayscale_cols, points_range,
                                         timezone_long, y_baseheight,
                                         target_rdg_icon,
                                         rdg_now) {
  # Font configuration — resolved by systemfonts from system-installed fonts;
  # no showtext registration needed when using ragg as the graphics device.
  font_legend <- config_vars$load_font

  # Landfall label
  time_to_landfall <- difftime(landfall_dtg, dtg, units = "hours")

  # only show label until 2 hours after landfall
  show_landfall_label <- time_to_landfall > -2 
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

  # flood stats for dynamic barplot
  flood_status_summary <- flow_now |>
    filter(flood_status %in% c("Flood", "Moderate", "Major")) |>
    count(flood_status) |>
    mutate(flood_status = factor(flood_status,
      levels = c("Flood", "Moderate", "Major")
    )) |>
    complete(flood_status, fill = list(n = 0)) |> # fill missing flood_status with 0 so the bars don't shift vertically
    mutate(
      label_right = paste(n, "gages"),
      label_left = case_when(
        flood_status %in% c("Moderate", "Major") ~ paste(flood_status, "flood"),
        TRUE ~ as.character(flood_status)
      )
    )

  x_buffer <- global_max_flood_stages * 0.03

  # Set conditional parmaters
  flood_alpha <- if (precip_grayscale) 0.7 else 0.85
  flood_cols <- if (precip_grayscale) flood_stage_cols_blue else flood_stage_cols_red

  # Shared base plot
  flood_status_bar <- ggplot(
    flood_status_summary,
    aes(
      y = flood_status,
      x = n,
      fill = flood_status
    )
  ) +
    geom_col(width = 0.35, show.legend = FALSE, color = NA, alpha = flood_alpha) +
    # number of gages to the right of bar
    geom_text(
      aes(label = label_right),
      hjust = 0,
      x = flood_status_summary$n + x_buffer,
      family = font_legend, size = 4,
      color = flood_cols[as.character(flood_status_summary$flood_status)]
    ) +
    # flood status to the left of bar
    geom_text(
      aes(label = label_left),
      hjust = 1,
      x = -x_buffer,
      family = font_legend, fontface = "bold", size = 4,
      color = flood_cols[as.character(flood_status_summary$flood_status)]
    ) +
    scale_fill_manual(values = flood_cols, drop = FALSE) +
    scale_x_continuous(
      limits = c(0, global_max_flood_stages * 1.15),
      expand = c(0, 0)
    ) +
    scale_y_discrete(expand = expansion(add = 0.2)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = font_legend) +
    theme(text = element_text(size = config_vars$font_size))

  # ggplot2 3.5+ guide API: appearance goes inside theme() within the guide
  precip_guide <- guide_coloursteps(
    theme = theme(
      legend.direction = "horizontal",
      legend.title.position = "left",
      legend.key.width = unit(3, "cm"),
      legend.key.height = unit(0.4, "cm"),
      legend.text.position = "bottom",
      legend.text = element_text(size = 0, color = "transparent"),
      legend.title = element_text(family = font_legend, hjust = 0, vjust = 0.5)
    )
  )

  if (precip_grayscale) {
    precip_fill_scale <- scale_fill_stepsn(
      colors = precip_grayscale_cols,
      breaks = get_precip_breaks(global_max_precip),
      limits = c(1, global_max_precip),
      name = NULL,
      na.value = scales::alpha("white", 0),
      guide = precip_guide
    )
  } else {
    precip_fill_scale <- scale_fill_stepsn(
      colors = scales::alpha(precip_cols, 0.7),
      breaks = get_precip_breaks(global_max_precip),
      limits = c(1, global_max_precip),
      name = NULL,
      na.value = scales::alpha("white", 0),
      guide = precip_guide
    )
  }

  p <- ggplot() +
    geom_raster(
      data = precip_now, aes(x = x, y = y, fill = precip_in),
      alpha = 0.6
    ) +
    geom_sf(
      data = state_inner_borders, color = config_vars$state_inner_borders_col,
      fill = NA, linewidth = 0.27
    ) +
    geom_sf(
      data = state_outer_lines, color = config_vars$state_outer_lines_col,
      fill = NA, linewidth = 0.3
    ) +
    theme(
      text = element_text(family = font_legend),
      legend.spacing.x = unit(0, "cm")
    ) +
    precip_fill_scale

  # plot non flooded points + city labels
  p <- p + ggnewscale::new_scale_fill() +
    geom_sf(
      data = flow_now |>
        filter(is_flooded == "FALSE") |> 
        mutate(flood_status = factor(flood_status, levels = names(flood_stage_cols_red))) |> 
        filter(!is.na(flood_status)),
      aes(geometry = geometry, fill = flood_status),
      shape = 21, size = 1.25,
      stroke = 0.3,
      color = config_vars$bg_col,
      show.legend = FALSE
    ) +
    theme(
      text = element_text(family = font_legend)
    ) +
    geom_sf(
      data = major_cities, shape = 23, fill = NA,
      color = config_vars$major_cities_col, size = 1.75, stroke = 0.3
    ) +
    geom_sf_text(
      data = major_cities, aes(label = NAME),
      color = config_vars$major_cities_text_col,
      size = 3, nudge_y = 50000, family = font_legend
    ) + 
  # decomissioned gages
    geom_sf(data = flow_now |> filter(is_decommissioned), 
            aes(geometry = geometry), 
            shape = 4,     
            color = config_vars$x_mark, 
            size = 1.25, 
            alpha = 0.75,
            stroke = 1) 
  
  # If flood_spikes TRUE, make spikes
  if (flood_spikes) {
    pct_midpoint <- c(
      "low" = 2.5, "5-10" = 7.5,
      "10-25" = 17.5, "25-75" = 50,
      "75-90" = 82.5, "90-95" = 92.5,
      "high" = 97.5
    )

    pct_spike_transform <- function(df) {
      df |>
        dplyr::mutate(
          pct = pct_midpoint[as.character(percentile)],
          pct_rescaled = ifelse(is.na(pct) | pct < 75, 0, (pct - 75) / 25),
          xy = sf::st_coordinates(geometry),
          x = xy[, 1],
          y = xy[, 2],
          y_base = y + y_baseheight,
          xend = x,
          yend = y_base + pct_rescaled * peak_height
        )
    }

    # Gray spikes: non-flooded gages at >=75th percentile
    flow_spikes_gray <- flow_now |>
      dplyr::filter(
        !is_flooded,
        !is.na(percentile),
        percentile %in% c("75-90", "90-95", "high")
      ) |>
      pct_spike_transform()

    # Colored spikes: flooded gages at >=75th percentile
    flow_spikes_col <- flow_now |>
      dplyr::filter(
        is_flooded,
        !is.na(percentile),
        percentile %in% c("75-90", "90-95", "high"),
        !is.na(flood.stage) | !is.na(moderate.flood.stage) | !is.na(major.flood.stage)
      ) |>
      dplyr::arrange(sev_rank, desc(above_amt), desc(dateTime)) |>
      pct_spike_transform()

    if (nrow(flow_spikes_gray) > 0) {
      p <- p +
        ggforce::geom_link(
          data = flow_spikes_gray,
          aes(
            x = x, xend = xend, y = y + 10000, yend = yend,
            alpha = after_stat(I(0.6 + index)),
            linewidth = after_stat(I((1 - index) * 1.4))
          ),
          colour = "#dcdcdc",
          show.legend = FALSE
        ) +
        geom_point(
          data = flow_spikes_gray,
          aes(x = x, y = y_base),
          shape = 21, fill = "#dcdcdc", color = "white", size = 1.25,
          stroke = 0.3,
          show.legend = FALSE
        )
    }

    p <- p +
      ggforce::geom_link(
        data = flow_spikes_col,
        aes(
          x = x, xend = xend, y = y, yend = yend,
          color = flood_status,
          alpha = after_stat(I(0.6 + index)),
          linewidth = after_stat(I((1 - index) * 2.3))
        ),
        show.legend = FALSE
      ) +
      scale_color_manual(
        name = "Peak flood stage",
        values = flood_stage_cols_red,
        limits = names(flood_stage_cols_red),
        drop = FALSE,
        na.value = config_vars$streamgage_col,
        guide = guide_legend(
          direction = "vertical",
          override.aes = list(
            shape = rep(22, length(flood_stage_cols_red)),
            size = rep(6, length(flood_stage_cols_red)),
            fill = unname(flood_stage_cols_red),
            alpha = 0.8,
            color = NA,
            stroke = rep(0.1, length(flood_stage_cols_red))
          ),
          label.theme = element_text(
            size = config_vars$font_size,
            family = font_legend
          ),
          title.theme = element_text(
            size = config_vars$font_size,
            family = font_legend
          ),
          keyheight = unit(0.7, "cm")
        )
      )

    # Plot all flooded gages on top of spikes
    p <- p +
      geom_sf(
        data = flow_now |>
          filter(is_flooded) |>
          mutate(flood_status = factor(flood_status,
            levels = names(flood_stage_cols_red)
          )) |>
          filter(!is.na(flood_status)),
        aes(geometry = geometry, fill = flood_status),
        shape = 21, size = 2,
        stroke = 0.3,
        color = config_vars$bg_col,
        show.legend = FALSE
      ) +
      scale_fill_manual(
        values = flood_stage_cols_red,
        drop = FALSE,
        name = "Flood status"
      )

    # otherwise, do sized points
  } else {
    # Prepare point data
    flow_now_points <- flow_now |> 
      filter(is_flooded) |> 
      arrange(
        sev_rank,
        desc(above_amt),
        desc(duration_above_flood_hr),
        desc(dateTime)
      ) |> 
      mutate(index = (duration_above_flood_hr / global_max_duration)^3)
    

    p <- p +
      geom_sf(
        data = flow_now_points,
        aes(fill = flood_status, size = index, geometry = geometry),
        shape = 21,
        stroke = 0.4,
        color = config_vars$bg_col,
        alpha = 0.75,
        show.legend = FALSE
      ) +
      scale_size_continuous(range = points_range, limits = c(0, 1)) +
      scale_fill_manual(
        name = "Peak flood stage",
        values = flood_stage_cols_red,
        limits = names(flood_stage_cols_red),
        drop = FALSE,
        na.value = config_vars$streamgage_col,
        guide = guide_legend(
          direction = "vertical",
          override.aes = list(
            shape = rep(21, length(flood_stage_cols_red)),
            size = rep(6, length(flood_stage_cols_red)),
            fill = unname(flood_stage_cols_red),
            alpha = 0.8,
            color = "black",
            stroke = 0.2
          ),
          label.theme = element_text(size = config_vars$font_size, family = font_legend),
          title.theme = element_text(size = config_vars$font_size, family = font_legend),
          keyheight = unit(0.7, "cm")
        )
      )
  }

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
    geom_point(
      data = past_storm_points,
      aes(x = X, y = Y),
      color = "black",
      size = 2
    ) +
    ggimage::geom_image(
      data = latest_point,
      aes(x = X, y = Y),
      image = hurricane_symbol_path,
      size = 0.035
    )

  # Final plot theme and save
  p <- p +
    coord_sf(
      xlim = bbox_coords$xlim,
      ylim = bbox_coords$ylim,
      expand = FALSE
    ) +
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
      plot.title = element_text(
        hjust = 0.5, size = config_vars$font_size_title,
        face = "bold", family = font_legend,
        margin = margin(b = 10)
      ),
      plot.title.position = "plot",
      legend.box = "vertical",
      legend.box.just = "center"
    )

  # Build precip legend from a minimal 2-row dummy dataset using the same
  # fill scale — avoids re-rendering the full raster just to get the color bar.
  legend_precip <- cowplot::get_legend(
    ggplot(
      data.frame(x = c(1, global_max_precip), y = 1,
                 fill = c(1, global_max_precip)),
      aes(x, y, fill = fill)
    ) +
      geom_tile() +
      precip_fill_scale +
      theme(legend.position = "right")
  )

  p_dot_legend <- ggplot() +
    geom_point(
      data = data.frame(x = 1, y = 1),
      aes(x = x, y = y),
      shape = 21,
      fill = "#aaaaaa",
      size = 5,
      stroke = 0.1,
      color = config_vars$bg_col,
      alpha = 0.8
    ) +
    theme_void()

  p_peak_legend <- ggplot(
    data.frame(
      x = c(0, -0.25, 0.25),
      y = c(1.5, 0, 0)
    ),
    aes(x, y)
  ) +
    geom_polygon(
      fill =  "#aaaaaa",
      color = NA,
      alpha = 0.8
    ) +
    coord_fixed() +
    theme_void()

  logo <- magick::image_read(logo_path) |>
    magick::image_resize("x100") |>
    magick::image_colorize(100, "black")

  if (flood_spikes) {
    flood_stage_leg <- magick::image_read(flood_stage_spike_leg_path)
  } else {
    flood_stage_leg <- magick::image_read(flood_stage_point_leg_path)
  }

  flood_stage_leg <- flood_stage_leg |> magick::image_resize("x200")

  # Rapid deployement gages icon (target)
  if (nrow(rdg_now) > 0) {
    rdg_now_coords <- rdg_now |>
      mutate(
        X = sf::st_coordinates(geometry)[, 1],
        Y = sf::st_coordinates(geometry)[, 2]
      )

    p <- p + ggimage::geom_image(
      data = rdg_now_coords,
      aes(x = X, y = Y),
      image = target_rdg_icon,
      size = 0.014
    )
  }

  # rdg icon for legend
  p_rdg_leg <- ggplot(
    data.frame(X = 0.5, Y = 0.5),
    aes(x = X, y = Y)
  ) +
    ggimage::geom_image(
      image = target_rdg_icon,
      size = 0.6
    ) +
    theme_void()
  
  # decomissioned/ out of service gage legend icon
  p_decom_leg <- ggplot(
    data.frame(x = 0, y = 0),
    aes(x = x, y = y)
    ) +
    geom_point(
      shape = 4, 
      color = config_vars$x_mark, 
      size = 2, 
      alpha = 0.75, 
      stroke = 1
    ) +
    theme_void()
  
  # Progress bar plot
  progress_bar <- ggplot() +
    geom_rect(aes(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
      fill = config_vars$progress_bar_bg_col, color = NA
    ) +
    geom_rect(aes(xmin = 0, xmax = progress_fraction, ymin = 0, ymax = 1),
      fill = config_vars$progress_bar_col, color = NA
    ) +
    theme_void() +
    theme(
      plot.margin = margin(0, 0, 0, 0),
      panel.background = element_rect(fill = NA, color = NA)
    )

  canvas <- grid::rectGrob(
    x = 0, y = 0,
    width = 16, height = 9,
    gp = grid::gpar(
      fill = config_vars$bg_col, alpha = 1,
      col = config_vars$bg_col
    )
  )

  p <- ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
    draw_grob(canvas,
      x = 0, y = 1,
      height = 1, width = 1,
      hjust = 0, vjust = 1
    ) +
    draw_plot(
      p + theme(
        legend.position = "none",
        plot.title = element_blank()
      ),
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
      paste(
        "Hurricane",
        stringr::str_to_sentence(storm_info$storm_name)
      ),
      x = config_vars$plot_margin, y = 1 - config_vars$plot_margin * 1.2,
      size = 31,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      fontface = "bold",
      color = "black",
      lineheight = 1
    ) +
    draw_label(paste0(format(lubridate::with_tz(dtg, timezone_long), "%b. %d, %Y %H:%M %Z")),
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.055,
      size = 14,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      fontface = "bold",
      color = "black",
      lineheight = 1
    ) +
    draw_label(landfall_label,
      x = config_vars$plot_margin + 0.26,
      y = 1 - config_vars$plot_margin - 0.055,
      size = 14,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    ) +
    draw_plot(progress_bar,
      x = -0.05,
      y = -0.001,
      width = 1.1,
      height = 0.015
    ) +
    draw_plot(legend_precip,
      x = config_vars$plot_margin + 0.052,
      y = 0.227 + 0.011,
      height = 0.05,
      width = 0.42 - config_vars$plot_margin
    ) +
    draw_label("Total rainfall (in)",
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.715 + 0.015,
      size = 12,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    ) +
    draw_label("1",
      x = config_vars$plot_margin + 0.158,
      y = 1 - config_vars$plot_margin - 0.716 + 0.015,
      size = 12,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    ) +
    draw_label(paste(global_max_precip),
      x = config_vars$plot_margin + 0.333,
      y = 1 - config_vars$plot_margin - 0.716 + 0.015,
      size = 12,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    ) +
    draw_label("USGS streamgage",
      x = config_vars$plot_margin + 0.028,
      y = 1 - config_vars$plot_margin - 0.746 + 0.017,
      size = 12,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    ) +
    draw_plot(p_dot_legend,
      x = config_vars$plot_margin - 0.025,
      y = 0.208 + 0.017,
      height = 0.03,
      width = 0.1 - config_vars$plot_margin
    )

  if (flood_spikes) {
    p <- p +
      draw_label("Rapid-Deployment gage",
        x = config_vars$plot_margin + 0.028,
        y = 1 - config_vars$plot_margin - 0.775 + 0.019,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1
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
                 size = 12,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 color = "black",
                 lineheight = 1
      ) +
      draw_plot(p_decom_leg,
                x = config_vars$plot_margin - 0.025,
                y = 0.144,
                height = 0.08,
                width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("If it floods, a               appears",
                 x = config_vars$plot_margin + 0.004,
                 y = 1 - config_vars$plot_margin - 0.812,
                 size = 12,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 color = "black",
                 lineheight = 1
      ) +
      draw_label("spike",
                 x = config_vars$plot_margin + 0.118,
                 y = 1 - config_vars$plot_margin - 0.812,
                 size = 12,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 fontface = "bold",
                 color = "black",
                 lineheight = 1
      ) +
      draw_plot(p_peak_legend,
        x = config_vars$plot_margin + 0.22,
        y = 0.145,
        height = 0.03,
        width = 0.1 - config_vars$plot_margin
      ) +
      draw_label("The                 is how long it's been flooded",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.84,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1
      ) +
      draw_label("height",
        x = config_vars$plot_margin + 0.0415,
        y = 1 - config_vars$plot_margin - 0.84,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        fontface = "bold",
        color = "black",
        lineheight = 1
      ) +
      draw_image(flood_stage_leg,
        x = config_vars$plot_margin + 0.335,
        y = 0.113,
        width = 0.13,
        height = 0.135
      ) +
      draw_label("The              is the severity of the flood",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.867,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1
      ) +
      draw_label("color",
        x = config_vars$plot_margin + 0.042,
        y = 1 - config_vars$plot_margin - 0.867,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        fontface = "bold",
        color = "black",
        lineheight = 1
      ) +
      draw_plot(flood_status_bar,
        x = 0.17,
        y = 0.026,
        width = 0.2,
        height = 0.055
      )
  } else {
    p <- p +
      draw_label("Rapid-Deployment gage",
                 x = config_vars$plot_margin + 0.028,
                 y = 1 - config_vars$plot_margin - 0.775 + 0.019,
                 size = 12,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 color = "black",
                 lineheight = 1
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
                 size = 12,
                 hjust = 0,
                 vjust = 1,
                 fontfamily = font_legend,
                 color = "black",
                 lineheight = 1
      ) +
      draw_plot(p_decom_leg,
                x = config_vars$plot_margin - 0.025,
                y = 0.144,
                height = 0.08,
                width = 0.1 - config_vars$plot_margin
      )  +
      draw_label("If it floods:",
        x = config_vars$plot_margin + 0.004,
        y = 1 - config_vars$plot_margin - 0.810,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1
      ) +
      draw_label("     The              is the severity of the flood",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.836,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1
      ) +
      draw_label("color",
        x = config_vars$plot_margin + 0.062,
        y = 1 - config_vars$plot_margin - 0.836,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        fontface = "bold",
        color = "black",
        lineheight = 1
      ) +
      draw_plot(flood_status_bar,
        x = 0.189,
        y = 0.054,
        width = 0.2,
        height = 0.055
      )  +
      draw_label("      The           is how long it's been flooded",
        x = config_vars$plot_margin + 0.002,
        y = 1 - config_vars$plot_margin - 0.934,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        color = "black",
        lineheight = 1
      ) +
      draw_label("       size",
        x = config_vars$plot_margin + 0.036,
        y = 1 - config_vars$plot_margin - 0.934,
        size = 12,
        hjust = 0,
        vjust = 1,
        fontfamily = font_legend,
        fontface = "bold",
        color = "black",
        lineheight = 1
      )
    # Dropping custom flood stage for now, since placement is a bit awkward
    #  +
    # draw_image(flood_stage_leg,
    #            x = config_vars$plot_margin + 0.28,
    #            y = 0.0465,
    #            width = 0.145,
    #            height = 0.125)
  }

  if (!is.null(classification_label)) {
    p <- p + draw_label(
      classification_label,
      x = config_vars$plot_margin + 0.002,
      y = 1 - config_vars$plot_margin - 0.08,
      size = 14,
      hjust = 0,
      vjust = 1,
      fontfamily = font_legend,
      color = "black",
      lineheight = 1
    )
  }

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

#' Get legend (and avoid returning zeroGrob objects)
#'
#' @param plot a ggplot
#'
#' @return a grob with "guide-box" component name (i.e., a legend)
#'
get_legend_non0 <- function(plot) {
  # ggplot2 3.5+ stores guide boxes as "guide-box-right", "guide-box-bottom",
  # etc. rather than "guide-box", so use a regex pattern to catch all variants.
  legends <- cowplot::get_plot_component(plot, "guide-box", return_all = TRUE)
  if (length(legends) == 0) {
    legends <- cowplot::get_plot_component(plot, "^guide-box", return_all = TRUE)
  }
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

#' Generate clean breakpoints for a precipitation scale.
#' Ensures the scale always includes 1 as the minimum visible value and avoids
#' exceeding a specified maximum number of breaks.
#'
#' @param global_max_precip Numeric. The maximum precipitation value (in inches)
#'   across all timesteps, used to anchor the upper limit of the scale.
#' @param max_breaks Integer. The maximum number of breaks to allow in the scale.
#'
#' @return A numeric vector of breakpoints for use in a stepped color scale.
get_precip_breaks <- function(global_max_precip, max_breaks = 8) {
  if (global_max_precip <= 1) {
    return(c(1, global_max_precip))
  }

  # Create evenly spaced breaks between 1 and global_max_precip
  breaks <- seq(1, global_max_precip, length.out = max_breaks)

  # Round to reasonable values for cleaner labels
  breaks <- signif(breaks, digits = 2)

  return(breaks)
}
