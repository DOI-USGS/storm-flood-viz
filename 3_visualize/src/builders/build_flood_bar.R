#' Build the dynamic flood status barplot for the animation frame.
#'
#' @param flow_now sf/data.frame. Gage data at the current timestep; must
#'   contain a `flood_status` column with levels "Not flooded", "Flood",
#'   "Moderate", "Major".
#' @param global_max_flood_stages Numeric. Highest flooded gage count across
#'   all timesteps; sets the fixed x-axis limit so bars don't shift between
#'   frames.
#' @param flood_cols Named character vector mapping flood status levels to
#'   colors.
#' @param precip_grayscale Logical. Drives bar alpha (0.7 if TRUE, 0.85 if
#'   FALSE).
#' @param font_legend Character. Font family for bar labels.
#' @param config_vars Named list of styling options. Must contain `load_font`
#'   and `font_size`.
#' @return A ggplot object.
build_flood_bar <- function(flow_now, global_max_flood_stages, flood_cols,
                            precip_grayscale, font_legend, config_vars) {
  flood_alpha <- if (precip_grayscale) 0.7 else 0.85
  x_buffer <- global_max_flood_stages * 0.03

  flood_status_summary <- flow_now |>
    dplyr::filter(flood_status %in% c("Flood", "Moderate", "Major")) |>
    dplyr::count(flood_status) |>
    dplyr::mutate(flood_status = factor(flood_status,
      levels = c("Flood", "Moderate", "Major")
    )) |>
    tidyr::complete(flood_status, fill = list(n = 0)) |>
    dplyr::mutate(
      label_right = paste(n, "gages"),
      label_left = dplyr::case_when(
        flood_status %in% c("Moderate", "Major") ~ paste(flood_status, "flood"),
        TRUE ~ as.character(flood_status)
      )
    )

  ggplot(
    flood_status_summary,
    aes(y = flood_status, x = n, fill = flood_status)
  ) +
    geom_col(width = 0.35, show.legend = FALSE, color = NA, alpha = flood_alpha) +
    geom_text(
      aes(label = label_right),
      hjust = 0,
      x = flood_status_summary$n + x_buffer,
      family = font_legend, size = 4,
      color = flood_cols[as.character(flood_status_summary$flood_status)]
    ) +
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
    theme_void(base_family = config_vars$load_font) +
    theme(text = element_text(size = config_vars$font_size))
}
