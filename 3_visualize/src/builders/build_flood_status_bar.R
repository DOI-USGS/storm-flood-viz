#' Build the flood-status count barplot for one animation frame.
#'
#' @param flow_now data.frame. Streamgage data at the current timestep; must
#'   contain a `flood_status` column.
#' @param flood_stage_cols_blue Named character vector. Blue flood palette.
#' @param flood_stage_cols_red Named character vector. Red flood palette.
#' @param global_max_flood_stages Numeric. Max flooded gage count across all
#'   timesteps; sets the x-axis limit.
#' @param precip_grayscale Logical. If TRUE use blue palette; else red.
#' @param font_legend Character. Font family.
#' @param config_vars Named list of styling options. Must contain `bar_width`,
#'   `bar_text_size`, `x_axis_buffer`, and `font_size`.
#' @param static Logical. TRUE draws a non-updating severity key (colored
#'   square + label, no counts) instead of the live chart; ignores flow_now.
#' @return A ggplot object.
build_flood_status_bar <- function(flow_now, flood_stage_cols_blue,
                                    flood_stage_cols_red,
                                    global_max_flood_stages,
                                    precip_grayscale, font_legend,
                                    config_vars, static = FALSE) {
  flood_alpha <- if (precip_grayscale) 0.7 else 0.85
  flood_cols  <- if (precip_grayscale) flood_stage_cols_blue else flood_stage_cols_red

  if (static) {
    key <- tibble(
      flood_status = factor(c("Flood", "Moderate", "Major"),
                            levels = c("Flood", "Moderate", "Major")),
      label = c("Flood", "Moderate flood", "Major flood")
    )
    return(
      ggplot(key, aes(y = flood_status)) +
        geom_tile(aes(x = 0, fill = flood_status), width = 0.5, height = 0.5,
                  show.legend = FALSE, alpha = flood_alpha) +
        geom_text(aes(x = 0.5, label = label),
                  hjust = 0, family = font_legend, fontface = "bold",
                  size = config_vars$bar_text_size,
                  color = flood_cols[as.character(key$flood_status)]) +
        scale_fill_manual(values = flood_cols, drop = FALSE) +
        scale_x_continuous(limits = c(-0.5, 3), expand = c(0, 0)) +
        scale_y_discrete(expand = expansion(add = 0.6)) +
        coord_cartesian(clip = "off") +
        theme_void(base_family = font_legend) +
        theme(text = element_text(size = config_vars$font_size))
    )
  }

  flood_status_summary <- flow_now |>
    filter(flood_status %in% c("Flood", "Moderate", "Major")) |>
    count(flood_status) |>
    mutate(flood_status = factor(
      flood_status, levels = c("Flood", "Moderate", "Major"))) |>
    complete(flood_status, fill = list(n = 0)) |>
    mutate(
      label_right = paste(n, "gages"),
      label_left = case_when(
        flood_status %in% c("Moderate", "Major") ~ paste(flood_status, "flood"),
        TRUE ~ as.character(flood_status)
      )
    )

  x_buffer <- global_max_flood_stages * 0.03
  bar_y_expand <- config_vars$bar_y_expand
  if (is.null(bar_y_expand)) bar_y_expand <- 0.2

  ggplot(
    flood_status_summary,
    aes(y = flood_status, x = n, fill = flood_status)
  ) +
    geom_col(
      width = config_vars$bar_width, show.legend = FALSE,
      color = NA, alpha = flood_alpha
    ) +
    geom_text(
      aes(label = label_right),
      hjust = 0, x = flood_status_summary$n + x_buffer,
      family = font_legend, size = config_vars$bar_text_size,
      color = flood_cols[as.character(flood_status_summary$flood_status)]
    ) +
    geom_text(
      aes(label = label_left),
      hjust = 1, x = -x_buffer,
      family = font_legend, fontface = "bold", size = config_vars$bar_text_size,
      color = flood_cols[as.character(flood_status_summary$flood_status)]
    ) +
    scale_fill_manual(values = flood_cols, drop = FALSE) +
    scale_x_continuous(
      limits = c(0, global_max_flood_stages * config_vars$x_axis_buffer),
      expand = c(0, 0)
    ) +
    scale_y_discrete(expand = expansion(add = bar_y_expand)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = font_legend) +
    theme(text = element_text(size = config_vars$font_size))
}
