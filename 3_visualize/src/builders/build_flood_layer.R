#' Build flood gage and city layers for one animation frame.
#'
#' Handles the full flood visualization: non-flooded gage points, major-city
#' markers and labels, decommissioned gage markers, and either height-tapered
#' spikes (flood_spikes = TRUE) or sized circle points (flood_spikes = FALSE)
#' for flooded and near-flood gages.
#'
#' Flooded gages are ordered by sev_rank / above_amt so the most severe ones
#' render last (on top).
#'
#' @param flow_now data.frame. One row per gage at the current timestep; must
#'   contain columns `above_flood`, `percentile`, `flood_status`, `sev_rank`,
#'   `above_amt`, `dateTime`, `is_decommissioned`, and an sf `geometry` column.
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param flood_stage_cols_red Named character vector mapping flood-status
#'   labels to hex colors. Used for fill/color scales and factor levels.
#' @param peak_height Numeric. Maximum spike height in projected units.
#' @param y_baseheight Numeric. Offset added to a gage's y position to form the
#'   spike base, so even the shortest spike is immediately visible.
#' @param points_range Numeric vector length 2. Min/max point sizes passed to
#'   `scale_size_continuous()` in point mode, e.g. `c(2, 6)`.
#' @param font_legend Character. Font family for city labels.
#' @param config_vars Named list of styling options. Must contain `bg_col`,
#'   `major_cities_col`, `major_cities_text_col`, `x_mark`, `streamgage_col`,
#'   `font_size`, and `leg_font_size` (set in storm YAML viz_config).
#' @return A list of ggplot2 layer and scale objects suitable for use with `+`.
build_flood_layer <- function(flow_now, flood_spikes,
                               flood_stage_cols_red, peak_height, y_baseheight,
                               points_range, font_legend, config_vars) {
  base_layers <- list(
    ggnewscale::new_scale_fill(),
    ggplot2::geom_sf(
      data = flow_now |>
        dplyr::filter(above_flood == "FALSE") |>
        dplyr::filter(
          isTRUE(flood_spikes) |
            !(percentile %in% c("75-90", "90-95", "high"))
        ) |>
        dplyr::mutate(flood_status = factor(
          flood_status, levels = names(flood_stage_cols_red))) |>
        dplyr::filter(!is.na(flood_status)),
      ggplot2::aes(geometry = geometry, fill = flood_status),
      shape = 21, size = config_vars$non_flooded_point_size, stroke = 0.3,
      color = config_vars$bg_col, show.legend = FALSE
    ),
    ggplot2::theme(
      text = ggplot2::element_text(family = font_legend)
    ),
    ggplot2::geom_sf(
      data = dplyr::filter(flow_now, is_decommissioned),
      ggplot2::aes(geometry = geometry),
      shape = 4, color = config_vars$x_mark,
      size = 1.25, alpha = 0.75, stroke = 1
    )
  )

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
          pct_rescaled = ifelse(
            is.na(pct) | pct < 75, 0, (pct - 75) / 25),
          xy = sf::st_coordinates(geometry),
          x = xy[, 1],
          y = xy[, 2],
          y_base = y + y_baseheight,
          xend = x,
          yend = y_base + pct_rescaled * peak_height
        )
    }

    flow_spikes_gray <- flow_now |>
      dplyr::filter(
        !above_flood,
        !is.na(percentile),
        percentile %in% c("75-90", "90-95", "high")
      ) |>
      pct_spike_transform()

    flow_spikes_col <- flow_now |>
      dplyr::filter(
        above_flood,
        !is.na(percentile),
        percentile %in% c("75-90", "90-95", "high"),
        !is.na(flood.stage) | !is.na(moderate.flood.stage) |
          !is.na(major.flood.stage)
      ) |>
      dplyr::arrange(sev_rank, dplyr::desc(above_amt),
                     dplyr::desc(dateTime)) |>
      pct_spike_transform()

    gray_spike_layers <- if (nrow(flow_spikes_gray) > 0) {
      list(
        ggforce::geom_link(
          data = flow_spikes_gray,
          ggplot2::aes(
            x = .data$x, xend = .data$xend,
            y = .data$y + 10000, yend = .data$yend,
            alpha = ggplot2::after_stat(I(0.6 + index)),
            linewidth = ggplot2::after_stat(I((1 - index) * 1.4))
          ),
          colour = flood_stage_cols_red[["Not flooded"]],
          show.legend = FALSE
        ),
        ggplot2::geom_point(
          data = flow_spikes_gray,
          ggplot2::aes(x = .data$x, y = .data$y_base),
          shape = 21, fill = flood_stage_cols_red[["Not flooded"]],
          color = "white",
          size = config_vars$non_flooded_point_size,
          stroke = 0.3, show.legend = FALSE
        )
      )
    } else {
      list()
    }

    spike_layers <- list(
      ggforce::geom_link(
        data = flow_spikes_col,
        ggplot2::aes(
          x = .data$x, xend = .data$xend,
          y = .data$y, yend = .data$yend,
          color = flood_status,
          alpha = ggplot2::after_stat(I(0.6 + index)),
          linewidth = ggplot2::after_stat(I((1 - index) * 2.3))
        ),
        show.legend = FALSE
      ),
      ggplot2::scale_color_manual(
        name = "Peak flood stage",
        values = flood_stage_cols_red,
        limits = names(flood_stage_cols_red),
        drop = FALSE,
        na.value = config_vars$streamgage_col,
        guide = ggplot2::guide_legend(
          direction = "vertical",
          override.aes = list(
            shape = rep(22, length(flood_stage_cols_red)),
            size = rep(6, length(flood_stage_cols_red)),
            fill = unname(flood_stage_cols_red),
            alpha = 0.8, color = NA,
            stroke = rep(0.1, length(flood_stage_cols_red))
          ),
          label.theme = ggplot2::element_text(
            size = config_vars$font_size, family = font_legend),
          title.theme = ggplot2::element_text(
            size = config_vars$font_size, family = font_legend),
          keyheight = grid::unit(config_vars$flood_legend_key_height_cm, "cm")
        )
      ),
      ggplot2::geom_sf(
        data = flow_now |>
          dplyr::filter(above_flood) |>
          dplyr::mutate(flood_status = factor(
            flood_status, levels = names(flood_stage_cols_red))) |>
          dplyr::filter(!is.na(flood_status)),
        ggplot2::aes(geometry = geometry, fill = flood_status),
        shape = 21, size = config_vars$flooded_point_size, stroke = 0.3,
        color = config_vars$bg_col, show.legend = FALSE
      ),
      ggplot2::scale_fill_manual(
        values = flood_stage_cols_red,
        drop = FALSE,
        name = "Flood status"
      )
    )

    c(base_layers, gray_spike_layers, spike_layers)
  } else {
    pct_rank <- c(
      "low" = 0, "5-10" = 1/6,
      "10-25" = 2/6, "25-75" = 3/6,
      "75-90" = 4/6, "90-95" = 5/6,
      "high" = 1
    )

    flow_points_gray <- flow_now |>
      dplyr::filter(
        !above_flood,
        !is.na(percentile),
        percentile %in% c("75-90", "90-95", "high")
      ) |>
      dplyr::mutate(index = pct_rank[as.character(percentile)])

    flow_points_col <- flow_now |>
      dplyr::filter(above_flood) |>
      dplyr::arrange(sev_rank, dplyr::desc(above_amt),
                     dplyr::desc(dateTime)) |>
      dplyr::mutate(
        index = dplyr::coalesce(pct_rank[as.character(percentile)], 0))

    gray_point_layers <- if (nrow(flow_points_gray) > 0) {
      list(
        ggplot2::geom_sf(
          data = flow_points_gray,
          ggplot2::aes(size = .data$index, geometry = geometry),
          shape = 21, fill = flood_stage_cols_red[["Not flooded"]],
          color = "white",
          stroke = 0.3, alpha = config_vars$flood_point_alpha,
          show.legend = FALSE
        )
      )
    } else {
      list()
    }

    point_layers <- list(
      ggplot2::geom_sf(
        data = flow_points_col,
        ggplot2::aes(
          fill = flood_status, size = .data$index, geometry = geometry),
        shape = 21, stroke = 0.4,
        color = config_vars$bg_col,
        alpha = config_vars$flood_point_alpha, show.legend = FALSE
      ),
      ggplot2::scale_size_continuous(range = points_range, limits = c(0, 1)),
      ggplot2::scale_fill_manual(
        name = "Peak flood stage",
        values = flood_stage_cols_red,
        limits = names(flood_stage_cols_red),
        drop = FALSE,
        na.value = config_vars$streamgage_col,
        guide = ggplot2::guide_legend(
          direction = "vertical",
          override.aes = list(
            shape = rep(21, length(flood_stage_cols_red)),
            size = rep(6, length(flood_stage_cols_red)),
            fill = unname(flood_stage_cols_red),
            alpha = 0.8, color = "black",
            stroke = 0.2
          ),
          label.theme = ggplot2::element_text(
            size = config_vars$font_size, family = font_legend),
          title.theme = ggplot2::element_text(
            size = config_vars$font_size, family = font_legend),
          keyheight = grid::unit(config_vars$flood_legend_key_height_cm, "cm")
        )
      )
    )

    c(base_layers, gray_point_layers, point_layers)
  }
}
