#' Create an animated GIF visualizing hurricane impacts
#'
#' This fxn generates time series maps of a hurricane's track, precipitation,
#' and streamgage response (either in percentiles or flood stage categories), 
#' saves each frame as a PNG, and then compiles them into an animated GIF.
#'
#' @param precip_data A data frame of gridded precipitation data with columns 
#' `x`, `y`, `precip_in`, and `dateTime`.
#' @param flow_data A data frame of streamgage data with columns `dateTime`,
#'  `X_00065_00000`, 
#'        flood stage thresholds (`flood.stage`, `action.stage`, etc.), and 
#'        geometry for plotting.
#' @param storm_path A `sf` object representing the hurricane path, with `DTG`,
#'  `X`, `Y`, and `STORMNAME` columns.
#' @param state_borders A `sf` object representing the state 
#' boundaries for plotting.
#' @param path_out The output file path (ending in `.gif`) for the
#'  final animated visualization.
#' @param metric A string, either `"percentile"` or `"flood_stage"`,
#'  indicating which streamgage metric to visualize.
#' @param major_cities A `sf` object of city points with a `NAME` 
#' column for labeling.
#' @param percentile_cols A named character vector of colors to use for the 
#'   streamgage percentile scale.
#' @param flood_stage_cols A named character vector of colors to use for the 
#'   flood stage categories (e.g., "Normal", "Action", etc.).
#' @param percip_cols A character string specifying the `viridisLite::viridis()` 
#'   color option to use for precipitation shading (e.g., `"mako"`, `"inferno"`).
#' @param config_vars A named list of plot and theme configuration values 
#'   (e.g., font size, colors, DPI, background color). Includes
#'   `load_font`, `dpi`, `font_size`, `leg_font_size`, `font_size_title`, 
#'   `streamgage_col`, `state_outline_col`, `major_cities_col`, 
#'   `major_cities_text_col`, `storm_path_col`, `width`, `height`, and `bg_col`.
#'
#' @return The path to the generated GIF file (same as `path_out`).
hurricane_viz <- function(precip_data, flow_data, storm_path, state_borders,
                          path_out, metric, major_cities, percentile_cols,
                          flood_stage_cols, percip_cols, config_vars) {
  
  font_legend <- config_vars$load_font
  font_add_google(font_legend)
  showtext_opts(dpi = config_vars$dpi, regular.wt = 200, bold.wt = 700)
  showtext_auto(enable = TRUE)

  metric <- match.arg(metric, c("percentile", "flood_stage"))
  dtg_list <- sort(unique(precip_data$dateTime))
  frame_dir <- file.path(dirname(path_out), 
                         ifelse(metric == "percentile", 
                                "percentile_frames", "flood_stage_frames"))
  fs::dir_create(frame_dir)  
  
  purrr::imap(dtg_list, function(dtg_now, i) {
    hurr_subset <- storm_path |> dplyr::filter(DTG <= dtg_now)
    precip_now <- precip_data |> dplyr::filter(dateTime <= dtg_now)

    streamgage_now <- flow_data |>
      dplyr::filter(as.Date(dateTime) == as.Date(dtg_now)) |>
      dplyr::mutate(
        flood_status = dplyr::case_when(
          !is.na(major.flood.stage) & X_00065_00000 >=
            major.flood.stage ~ "Major",
          !is.na(moderate.flood.stage) & X_00065_00000 >= 
            moderate.flood.stage ~ "Moderate",
          !is.na(flood.stage) & X_00065_00000 >= 
            flood.stage ~ "Flood",
          !is.na(action.stage) & X_00065_00000 >=
            action.stage ~ "Action",
          TRUE ~ "Normal"
        ),
        flood_status = factor(flood_status,
                              levels = c("Normal", "Action",
                                         "Flood", "Moderate", "Major"))
      )

    p <- ggplot() +
      geom_raster(
        data = precip_now,
        aes(x = x, y = y, fill = precip_in),
        alpha = 0.7
      ) +
      geom_sf(data = state_borders, color = config_vars$state_outline_col,
              fill = NA, linewidth = 0.6) +
      scale_fill_stepsn(
        colors = viridisLite::viridis(7, option = percip_cols, direction = -1),
        breaks = c(1.5, 3, 5, 7, 9, 11, 13),
        limits = c(1, 14),
        labels = c("1–2", "2–4", "4–6", "6–8", "8–10", "10–12", "12+"),
        name = "Total precipitation (in)",
        guide = guide_coloursteps(
          title.theme = element_text(family = font_legend, 
                                     size = config_vars$font_size),
          title.position = "top",
          title.hjust = 0.5,
          direction = "horizontal",
          barwidth = unit(10, "cm"),
          barheight = unit(0.4, "cm"),
          label.position = "bottom",
          label.hjust = 0.5,
          even.steps = TRUE
        )
      ) +
      theme(text = element_text(family = font_legend,
                                size = config_vars$font_size)) +
      ggnewscale::new_scale_fill()

    if (metric == "percentile") {
      p <- p +
        geom_sf(
          data = streamgage_now,
          aes(geometry = geometry, fill = percentile),
          pch = 21,
          color = config_vars$streamgage_col,
          stroke = 0.2,
          alpha = 0.7,
          size = 2
        ) +
        geom_sf(data = major_cities, shape = 23, fill = NA,
                color = config_vars$major_cities_col, 
                size = 2.5, stroke = 0.3) +
        geom_sf_text(data = major_cities, aes(label = NAME),
                     color = config_vars$major_cities_text_col,
                     size = 3, nudge_y = 50000) +
        scale_fill_stepsn(
          colors = percentile_cols,
          values = scales::rescale(c(0, 5, 10, 25, 75, 90, 100)),
          breaks = c(0, 5, 10, 25, 75, 90, 95, 100),
          labels = c("0", "5", "10", "25", "75", "90", "95", "100"),
          limits = c(0, 100),
          name = "Percentile",
          guide = guide_coloursteps(
            title.position = "top", title.hjust = 0.5,
            direction = "horizontal",
            title.theme = element_text(family = font_legend,
                                       size = config_vars$font_size),
            barwidth = unit(10, "cm"), barheight = unit(0.4, "cm"),
            label.position = "bottom", even.steps = TRUE
          )
        ) +
        theme(text = element_text(family = font_legend,
                                  size = config_vars$font_size))
    } else if (metric == "flood_stage") {
      p <- p +
        geom_sf(
          data = streamgage_now,
          aes(geometry = geometry, fill = flood_status),
          shape = 21,
          size = 2,
          stroke = 0.5,
          color = config_vars$streamgage_col,
          alpha = 0.9
        ) +
        scale_fill_manual(
          name = "Flood stage status",
          values = flood_stage_cols,
          drop = FALSE,
          na.value = config_vars$streamgage_col
        ) +
        geom_sf(data = major_cities, shape = 23, fill = NA,
                color = config_vars$major_cities_col, 
                size = 2.5, stroke = 0.3) +
        geom_sf_text(
          data = major_cities, aes(label = NAME), 
          color = config_vars$major_cities_text_col,
          size = 3, nudge_y = 50000, family = font_legend
        ) +
        theme(text = element_text(family = font_legend,
                                  size = config_vars$font_size))
    }

    p <- p +
      geom_path(
        data = hurr_subset, aes(x = X, y = Y),
        color = config_vars$storm_path_col, linewidth = 1, alpha = 0.6
      ) +
      geom_sf(data = hurr_subset, color = config_vars$storm_path_col,
              size = 1.5, alpha = 0.4) +
      geom_sf(
        data = hurr_subset |> filter(DTG == dtg_now),
        color = config_vars$storm_path_col, size = 3
      ) +
      coord_sf(
        xlim = range(precip_now$x, na.rm = TRUE),
        ylim = range(precip_now$y, na.rm = TRUE),
        expand = FALSE,
        clip = "on"
      ) +
      labs(
        title = paste0(
          "Hurricane ", 
          stringr::str_to_sentence(unique(storm_path$STORMNAME)), "\n",
          format(dtg_now, "%Y-%m-%d %H:%M:%S")
        )
      ) +
      theme_void() +
      theme(
        legend.position = "top",
        legend.title = element_text(size = config_vars$font_size),
        legend.text = element_text(size = config_vars$leg_font_size),
        plot.margin = margin(t = 10, r = 15, b = 20, l = 15, unit = "pt"),
        plot.title = element_text(
          hjust = 0.5, size = config_vars$font_size_title, face = "bold",
          family = font_legend,
          margin = margin(b = 10)
        ),
        plot.title.position = "plot",
        legend.box = "vertical",
        legend.box.just = "center",
        text = element_text(family = font_legend, size = config_vars$font_size)
      )

    timestamp_str <- format(dtg_now, "%Y%m%dT%H%M")
    file_out <- file.path(frame_dir, paste0("frame_", timestamp_str, ".png"))
    message("Creating image for: ", timestamp_str)
    ggsave(filename = file_out, plot = p,
           width = config_vars$width, height = config_vars$height,
           dpi = config_vars$dpi, bg = config_vars$bg_col)
  })

  img_files <- list.files(frame_dir, 
                          pattern = "^frame_\\d{8}T\\d{4}\\.png$",
                          full.names = TRUE) |> 
    sort()
  img_list <- magick::image_read(img_files)
  hurr_gif <- magick::image_animate(magick::image_join(img_list), fps = 4)

  magick::image_write(hurr_gif, path_out)
  return(path_out)
}
