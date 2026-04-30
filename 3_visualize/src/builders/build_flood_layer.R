#' Add flood gage layers to the base map plot.
#'
#' Renders either percentile-height spikes (flooded = colored, non-flooded =
#' gray) or sized points depending on [flood_spikes]. Returns the modified plot.
#'
#' @param p ggplot object. The base map to add layers to.
#' @param flow_now sf/data.frame. Gage data at the current timestep.
#' @param flood_spikes Logical. If TRUE render tapered spikes; if FALSE render
#'   sized points.
#' @param flood_stage_cols_red Named character vector mapping flood status
#'   levels to colors (used for both colored spikes and points).
#' @param config_vars Named list of styling options. Must contain
#'   `streamgage_col`, `bg_col`, and `font_size`.
#' @param font_legend Character. Font family for legend text.
#' @param peak_height Numeric. Maximum spike height in map units.
#' @param y_baseheight Numeric. Vertical offset added to each gage's y
#'   coordinate before the spike starts.
#' @param points_range Numeric vector of length 2. Passed to
#'   [ggplot2::scale_size_continuous()] when rendering sized points.
#' @return The input ggplot [p] with flood layers appended.
build_flood_layer <- function(p, flow_now, flood_spikes, flood_stage_cols_red,
                              config_vars, font_legend, peak_height,
                              y_baseheight, points_range) {
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

  if (flood_spikes) {
    flow_spikes_gray <- flow_now |>
      dplyr::filter(
        !is_flooded,
        !is.na(percentile),
        percentile %in% c("75-90", "90-95", "high")
      ) |>
      pct_spike_transform()

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
          label.theme = element_text(size = config_vars$font_size,
                                     family = font_legend),
          title.theme = element_text(size = config_vars$font_size,
                                     family = font_legend),
          keyheight = unit(0.7, "cm")
        )
      )

    p <- p +
      geom_sf(
        data = flow_now |>
          filter(is_flooded) |>
          mutate(flood_status = factor(flood_status,
                                       levels = names(flood_stage_cols_red))) |>
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

  } else {
    pct_rank <- c(
      "low" = 0, "5-10" = 1/6,
      "10-25" = 2/6, "25-75" = 3/6,
      "75-90" = 4/6, "90-95" = 5/6,
      "high" = 1
    )

    flow_now_points <- flow_now |>
      filter(is_flooded) |>
      arrange(sev_rank, desc(above_amt), desc(dateTime)) |>
      mutate(index = pct_rank[as.character(percentile)])

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
          label.theme = element_text(size = config_vars$font_size,
                                     family = font_legend),
          title.theme = element_text(size = config_vars$font_size,
                                     family = font_legend),
          keyheight = unit(0.7, "cm")
        )
      )
  }

  p
}
