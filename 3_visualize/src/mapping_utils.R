source("3_visualize/src/builders/build_progress_bar.R")
source("3_visualize/src/builders/build_flood_bar.R")
source("3_visualize/src/builders/build_precip_legend.R")
source("3_visualize/src/builders/build_icon_legends.R")
source("3_visualize/src/builders/build_gage_legends.R")
source("3_visualize/src/builders/build_flood_layer.R")
source("3_visualize/src/builders/compose_frame.R")

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
#' @param frame_spike_dir Character path for saving flood stage spike viz PNGs.
#' @param frame_point_dir Character path for saving flood stage points viz PNGs.
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
                                         flood_stage_cols_red,
                                         precip_cols, config_vars, peak_height,
                                         frame_spike_dir, frame_point_dir,
                                         logo_path, bbox_coords, state_outer_lines,
                                         hurricane_symbol_path, global_max_duration,
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

  # Set conditional parameters
  flood_cols <- if (precip_grayscale) flood_stage_cols_blue else flood_stage_cols_red

  # Dynamic flood status barplot
  flood_status_bar <- build_flood_bar(
    flow_now = flow_now,
    global_max_flood_stages = global_max_flood_stages,
    flood_cols = flood_cols,
    precip_grayscale = precip_grayscale,
    font_legend = font_legend,
    config_vars = config_vars
  )

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

  p <- build_flood_layer(
    p = p,
    flow_now = flow_now,
    flood_spikes = flood_spikes,
    flood_stage_cols_red = flood_stage_cols_red,
    config_vars = config_vars,
    font_legend = font_legend,
    peak_height = peak_height,
    y_baseheight = y_baseheight,
    points_range = points_range
  )

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

  p_precip_legend <- p +
    theme(
      legend.position = "right",
      plot.title = element_blank()
    ) +
    guides(color = "none") # removes flood legend

  icon_legends <- build_icon_legends(config_vars)
  p_dot_legend <- icon_legends$dot
  p_peak_legend <- icon_legends$peak

  legend_precip <- build_precip_legend(precip_fill_scale, global_max_precip)

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

  gage_legends <- build_gage_legends(target_rdg_icon, config_vars)
  p_rdg_leg <- gage_legends$rdg
  p_decom_leg <- gage_legends$decom

  # Progress bar plot
  progress_bar <- build_progress_bar(progress_fraction, config_vars)

  p <- compose_frame(
    p = p,
    logo = logo,
    flood_stage_leg = flood_stage_leg,
    legend_precip = legend_precip,
    progress_bar = progress_bar,
    flood_status_bar = flood_status_bar,
    p_dot_legend = p_dot_legend,
    p_peak_legend = p_peak_legend,
    p_rdg_leg = p_rdg_leg,
    p_decom_leg = p_decom_leg,
    storm_info = storm_info,
    dtg = dtg,
    timezone_long = timezone_long,
    landfall_label = landfall_label,
    classification_label = classification_label,
    global_max_precip = global_max_precip,
    flood_spikes = flood_spikes,
    font_legend = font_legend,
    config_vars = config_vars
  )

  timestamp_str <- format(dtg, "%Y%m%dT%H%M")

  if (flood_spikes) {
    fs::dir_create(frame_spike_dir)
    frame_path <- file.path(frame_spike_dir, paste0("frame_", timestamp_str, ".png"))
  } else {
    fs::dir_create(frame_point_dir)
    frame_path <- file.path(frame_point_dir, paste0("frame_", timestamp_str, ".png"))
  }

  ggsave(
    filename = frame_path, plot = p,
    width = config_vars$width, height = config_vars$height,
    dpi = config_vars$dpi, bg = config_vars$bg_col,
    device = ragg::agg_png
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
