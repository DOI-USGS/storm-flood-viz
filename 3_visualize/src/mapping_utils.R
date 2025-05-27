hurricane_viz <- function(precip_summ, precip_data, flow_data, storm_path, state_borders,
                          path_out, metric) {
  
  metric <- match.arg(metric, c("percentile", "flood_stage"))
  
  dtg_list <- sort(unique(precip_data$dateTime))
  
  if (precip_summ == "none") {
    purrr::imap(dtg_list, function(dtg_now, i) {
      hurr_subset <- storm_path |> dplyr::filter(DTG <= dtg_now)
      precip_now <- precip_data |> dplyr::filter(dateTime <= dtg_now)
      streamgage_now <- flow_data |> 
        dplyr::filter(as.Date(dateTime) == as.Date(dtg_now)) |>
        dplyr::mutate(flood_exceeded = X_00065_00000 >= flood.stage)
      
      p <- ggplot() +
        geom_sf(data = state_borders, color = "gray60", fill = NA) +
        geom_raster(
          data = precip_now,
          aes(x = x, y = y, fill = precip_mm),
          alpha = 0.7
        ) +
        scale_fill_viridis_c(
          option = "mako",
          name = "Precipitation (mm)",
          direction = -1,
          limits = c(0, ceiling(max(precip_data$precip_mm, na.rm = TRUE))),
          guide = guide_colorbar(title.position = "top", title.hjust = 0.5,
                                 barwidth = unit(8, "cm"), barheight = unit(0.4, "cm"),
                                 label.position = "bottom")
        ) +
        ggnewscale::new_scale_fill()
      
      if (metric == "percentile") {
        p <- p +
          geom_sf(
            data = streamgage_now,
            aes(geometry = geometry, fill = percentile),
            pch = 21, color = "gray30", stroke = 0.2, alpha = 0.7, size = 2.5
          ) +
          scale_fill_stepsn(
            colors = c("#8c2d04", "#cc9e02", "#fee391", "#C0C0C0", "#80cdc1", "#35978f", "#045a8d"),
            values = scales::rescale(c(0, 5, 10, 25, 75, 90, 100)),
            breaks = c(0, 5, 10, 25, 75, 90, 95, 100),
            labels = c("0", "5", "10", "25", "75", "90", "95", "100"),
            limits = c(0, 100),
            name = "Percentile",
            guide = guide_coloursteps(title.position = "top", title.hjust = 0.5,
                                      direction = "horizontal",
                                      barwidth = unit(8, "cm"), barheight = unit(0.4, "cm"),
                                      label.position = "bottom", even.steps = TRUE)
          )
      } else if (metric == "flood_stage") {
        p <- p +
          geom_sf(
            data = streamgage_now,
            aes(geometry = geometry, fill = X_00065_00000),
            shape = 21,
            size = 2.5,
            stroke = 0.5,
            color = dplyr::if_else(streamgage_now$flood_exceeded, "purple", "gray30"),
            alpha = 0.8
          ) +
          scale_fill_viridis_c(
            name = "Gage height (ft)",
            option = "viridis",
            limits = c(min(flow_data$X_00065_00000, na.rm = TRUE),
                       max(flow_data$X_00065_00000, na.rm = TRUE)),
            guide = guide_colorbar(title.position = "top", title.hjust = 0.5,
                                   barwidth = unit(8, "cm"), barheight = unit(0.4, "cm"),
                                   label.position = "bottom")
          )
      }
      
      # Hurricane path
      p <- p +
        geom_path(data = hurr_subset, aes(x = X, y = Y),
                  color = "red", linewidth = 1, alpha = 0.6) +
        geom_sf(data = hurr_subset, color = "red", size = 1.5, alpha = 0.4) +
        geom_sf(data = hurr_subset |> filter(DTG == dtg_now),
                color = "red", size = 3) +
        coord_sf(
          xlim = range(precip_now$x, na.rm = TRUE),
          ylim = range(precip_now$y, na.rm = TRUE),
          expand = FALSE,
          clip = "on"
        ) +
        labs(title = paste("Hurricane", unique(storm_path$STORMNAME),
                           format(dtg_now, "%Y-%m-%d %H:%M:%S"), sep = "\n")) +
        theme_void() +
        theme(
          legend.position = "top",
          legend.title = element_text(size = 14),
          legend.text = element_text(size = 12),
          plot.margin = margin(t = 60, r = 15, b = 15, l = 15, unit = "pt"),
          plot.title = element_text(hjust = 0.5, size = 14),
          legend.box = "vertical",
          legend.box.just = "center"
        )
      
      # Save image
      timestamp_str <- format(dtg_now, "%Y%m%dT%H%M")
      frame_dir <- dirname(path_out)
      file_out <- file.path(frame_dir, paste0("frame_", timestamp_str, ".png"))
      message("Creating image for: ", timestamp_str)
      ggsave(filename = file_out, plot = p, width = 8, height = 8, dpi = 300, bg = "white")
    })
    
    # Combine to GIF
    img_files <- list.files(frame_dir, pattern = "^frame_\\d{8}T\\d{4}\\.png$", full.names = TRUE) |> sort()
    img_list <- magick::image_read(img_files)
    hurr_gif <- magick::image_animate(magick::image_join(img_list), fps = 4)
    
    magick::image_write(hurr_gif, path_out)
    return(path_out)
  }
}

