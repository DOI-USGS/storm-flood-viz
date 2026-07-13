#' Build flood gage layers for one animation frame.
#'
#' Draws the pre-split render groups from [split_flood_groups()]: non-flooded
#' gage points, decommissioned gage markers, and either height-tapered spikes
#' (flood_spikes = TRUE) or sized circle points (flood_spikes = FALSE) for
#' flooded and near-flood gages. Row filtering and draw-order sorting now live
#' in phase 2; this builder only applies geometry and the percentile-to-
#' height/size mappings, which are presentation tied to viz params.
#'
#' @param flood_groups Named list from [split_flood_groups()] with `non_flooded`,
#'   `decom`, `gray`, `flooded`, and `flooded_high` sf data.frames.
#' @param flood_spikes Logical. TRUE for spike mode; FALSE for sized-point mode.
#' @param flood_stage_cols_red Named character vector mapping flood-status
#'   labels to hex colors. Used for fill/color scales and factor levels.
#' @param points_range Numeric vector length 2. Min/max point sizes passed to
#'   `scale_size_continuous()` in point mode, e.g. `c(2, 6)`.
#' @param font_legend Character. Font family.
#' @param config_vars Named list of styling options. Must contain `bg_col`,
#'   `x_mark`, `streamgage_col`, `non_flooded_point_size`, `flooded_point_size`,
#'   `flood_point_alpha`, `flood_legend_key_height_cm`, `font_size`, and the
#'   projected-unit spike geometry `peak_height` (max spike height) and
#'   `y_baseheight` (spike base offset, so the shortest spike stays visible).
#' @return A list of ggplot2 layer and scale objects suitable for use with `+`.
build_flood_layer <- function(flood_groups, flood_spikes,
                              flood_stage_cols_red,
                              points_range, font_legend, config_vars) {
  peak_height <- config_vars$peak_height
  y_baseheight <- config_vars$y_baseheight
  base_layers <- list(
    new_scale_fill(),
    geom_sf(
      data = flood_groups$non_flooded,
      aes(geometry = geometry, fill = flood_status),
      shape = 21, size = config_vars$non_flooded_point_size, stroke = 0.3,
      color = config_vars$bg_col, show.legend = FALSE
    ),
    theme(
      text = element_text(family = font_legend)
    ),
    geom_sf(
      data = flood_groups$decom,
      aes(geometry = geometry),
      shape = 4, color = config_vars$x_mark,
      size = 1.25, alpha = 0.75, stroke = 1
    )
  )

  if (flood_spikes) {
    pct_spike_height <- c("75-90" = 0.20, "90-95" = 0.55, "high" = 0.85)

    pct_spike_transform <- function(df) {
      df |>
        mutate(
          pct_rescaled = coalesce(
            pct_spike_height[as.character(percentile)], 0),
          xy = st_coordinates(geometry),
          x = xy[, 1],
          y = xy[, 2],
          y_base = y + y_baseheight,
          xend = x,
          yend = y_base + pct_rescaled * peak_height
        )
    }

    flow_spikes_gray <- pct_spike_transform(flood_groups$gray)

    flow_spikes_col <- pct_spike_transform(flood_groups$flooded_high)

    gray_spike_layers <- if (nrow(flow_spikes_gray) > 0) {
      list(
        geom_link(
          data = flow_spikes_gray,
          aes(
            x = .data$x, xend = .data$xend,
            y = .data$y + y_baseheight, yend = .data$yend,
            alpha = after_stat(I(0.6 + index)),
            linewidth = after_stat(I((1 - index) * 1.4))
          ),
          colour = flood_stage_cols_red[["Not flooded"]],
          show.legend = FALSE
        ),
        geom_point(
          data = flow_spikes_gray,
          aes(x = .data$x, y = .data$y_base),
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
      geom_link(
        data = flow_spikes_col,
        aes(
          x = .data$x, xend = .data$xend,
          y = .data$y, yend = .data$yend,
          color = flood_status,
          alpha = after_stat(I(0.6 + index)),
          linewidth = after_stat(I((1 - index) * 2.3))
        ),
        show.legend = FALSE
      ),
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
            alpha = 0.8, color = NA,
            stroke = rep(0.1, length(flood_stage_cols_red))
          ),
          label.theme = element_text(
            size = config_vars$font_size, family = font_legend),
          title.theme = element_text(
            size = config_vars$font_size, family = font_legend),
          keyheight = unit(config_vars$flood_legend_key_height_cm, "cm")
        )
      ),
      geom_sf(
        data = flood_groups$flooded,
        aes(geometry = geometry, fill = flood_status),
        shape = 21, size = config_vars$flooded_point_size, stroke = 0.3,
        color = config_vars$bg_col, show.legend = FALSE
      ),
      scale_fill_manual(
        values = flood_stage_cols_red,
        drop = FALSE,
        name = "Flood status"
      )
    )

    c(base_layers, gray_spike_layers, spike_layers)
  } else {
    pct_rank <- c(
      "low" = 0, "5-10" = 0.05,
      "10-25" = 0.10, "25-75" = 0.18,
      "75-90" = 0.30, "90-95" = 0.65, "high" = 1.0
    )

    flow_points_gray <- flood_groups$gray |>
      mutate(index = pct_rank[as.character(percentile)])

    flow_points_col <- flood_groups$flooded |>
      mutate(
        index = coalesce(pct_rank[as.character(percentile)], 0))

    gray_point_layers <- if (nrow(flow_points_gray) > 0) {
      list(
        geom_sf(
          data = flow_points_gray,
          aes(size = .data$index, geometry = geometry),
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
      geom_sf(
        data = flow_points_col,
        aes(
          fill = flood_status, size = .data$index, geometry = geometry),
        shape = 21, stroke = 0.4,
        color = config_vars$bg_col,
        alpha = config_vars$flood_point_alpha, show.legend = FALSE
      ),
      scale_size_continuous(range = points_range, limits = c(0, 1)),
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
            alpha = 0.8, color = "black",
            stroke = 0.2
          ),
          label.theme = element_text(
            size = config_vars$font_size, family = font_legend),
          title.theme = element_text(
            size = config_vars$font_size, family = font_legend),
          keyheight = unit(config_vars$flood_legend_key_height_cm, "cm")
        )
      )
    )

    c(base_layers, gray_point_layers, point_layers)
  }
}
