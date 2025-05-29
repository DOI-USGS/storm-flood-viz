hurricane_viz <- function(precip_data, flow_data, storm_path, state_borders,
                          path_out, metric, major_cities) {
  
  font_legend <- "Source Sans Pro"
  font_add_google(font_legend)
  showtext_opts(dpi = 300, regular.wt = 200, bold.wt = 700)
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
          !is.na(major.flood.stage) & X_00065_00000 >= major.flood.stage ~ "Major",
          !is.na(moderate.flood.stage) & X_00065_00000 >= moderate.flood.stage ~ "Moderate",
          !is.na(flood.stage) & X_00065_00000 >= flood.stage ~ "Flood",
          !is.na(action.stage) & X_00065_00000 >= action.stage ~ "Action",
          TRUE ~ "Normal"
        ),
        flood_status = factor(flood_status,
                              levels = c("Normal", "Action", "Flood", "Moderate", "Major"))
      )

    p <- ggplot() +
      geom_raster(
        data = precip_now,
        aes(x = x, y = y, fill = precip_in),
        alpha = 0.7
      ) +
      geom_sf(data = state_borders, color = "white", fill = NA, linewidth = 0.6) +
      scale_fill_stepsn(
        colors = viridisLite::viridis(7, option = "mako", direction = -1),
        breaks = c(1.5, 3, 5, 7, 9, 11, 13),
        limits = c(1, 14),
        labels = c("1–2", "2–4", "4–6", "6–8", "8–10", "10–12", "12+"),
        name = "Total precipitation (in)",
        guide = guide_coloursteps(
          title.theme = element_text(family = font_legend, size = 14),
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
      theme(text = element_text(family = font_legend, size = 14)) +
      ggnewscale::new_scale_fill()

    if (metric == "percentile") {
      p <- p +
        geom_sf(
          data = streamgage_now,
          aes(geometry = geometry, fill = percentile),
          pch = 21,
          color = "gray30",
          stroke = 0.2,
          alpha = 0.7,
          size = 2
        ) +
        geom_sf(data = major_cities, shape = 23, fill = NA,
                color = "gray60", size = 2.5, stroke = 0.3) +
        geom_sf_text(data = major_cities, aes(label = NAME),
                     color = "gray30", size = 3, nudge_y = 50000) +
        scale_fill_stepsn(
          colors = c("#8c2d04", "#cc9e02", "#fee391", 
                     "#C0C0C0", "#80cdc1", "#35978f", "#045a8d"),
          values = scales::rescale(c(0, 5, 10, 25, 75, 90, 100)),
          breaks = c(0, 5, 10, 25, 75, 90, 95, 100),
          labels = c("0", "5", "10", "25", "75", "90", "95", "100"),
          limits = c(0, 100),
          name = "Percentile",
          guide = guide_coloursteps(
            title.position = "top", title.hjust = 0.5,
            direction = "horizontal",
            title.theme = element_text(family = font_legend, size = 14),
            barwidth = unit(10, "cm"), barheight = unit(0.4, "cm"),
            label.position = "bottom", even.steps = TRUE
          )
        ) +
        theme(text = element_text(family = font_legend, size = 14))
    } else if (metric == "flood_stage") {
      p <- p +
        geom_sf(
          data = streamgage_now,
          aes(geometry = geometry, fill = flood_status),
          shape = 21,
          size = 2,
          stroke = 0.5,
          color = "gray30",
          alpha = 0.9
        ) +
        scale_fill_manual(
          name = "Flood stage status",
          values = c(
            "Normal" = "#D5D5D5",
            "Action" = "#FEFF66",
            "Flood" = "#FFC76C",
            "Moderate" = "#FF726F",
            "Major" = "#E38AFF"
          ),
          drop = FALSE,
          na.value = "gray80"
        ) +
        geom_sf(data = major_cities, shape = 23, fill = NA,
                color = "gray60", size = 2.5, stroke = 0.3) +
        geom_sf_text(
          data = major_cities, aes(label = NAME), color = "gray50",
          size = 3, nudge_y = 50000, family = font_legend
        ) +
        theme(text = element_text(family = font_legend, size = 14))
    }

    p <- p +
      geom_path(
        data = hurr_subset, aes(x = X, y = Y),
        color = "red", linewidth = 1, alpha = 0.6
      ) +
      geom_sf(data = hurr_subset, color = "red", size = 1.5, alpha = 0.4) +
      geom_sf(
        data = hurr_subset |> filter(DTG == dtg_now),
        color = "red", size = 3
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
        legend.title = element_text(size = 14),
        legend.text = element_text(size = 12),
        plot.margin = margin(t = 10, r = 15, b = 20, l = 15, unit = "pt"),
        plot.title = element_text(
          hjust = 0.5, size = 16, face = "bold",
          family = font_legend,
          margin = margin(b = 10)
        ),
        plot.title.position = "plot",
        legend.box = "vertical",
        legend.box.just = "center",
        text = element_text(family = font_legend, size = 14)
      )

    timestamp_str <- format(dtg_now, "%Y%m%dT%H%M")
    file_out <- file.path(frame_dir, paste0("frame_", timestamp_str, ".png"))
    message("Creating image for: ", timestamp_str)
    ggsave(filename = file_out, plot = p,
           width = 8, height = 8, dpi = 300, bg = "white")
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
