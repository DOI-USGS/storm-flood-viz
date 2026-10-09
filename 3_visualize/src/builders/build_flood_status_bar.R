#' Build the flood-severity key for the Instagram legend card.
#'
#' A single vertical stacked bar (Flood bottom, Moderate middle, Major top --
#' the same stacking order as the flood-timeline barplot) with each
#' category's label to its right, instead of three separate swatch rows.
#'
#' @param flood_stage_cols_blue Named character vector. Blue flood palette.
#' @param flood_stage_cols_red Named character vector. Red flood palette.
#' @param precip_grayscale Logical. If TRUE use blue palette; else red.
#' @param font_legend Character. Font family.
#' @param config_vars Named list of styling options. Must contain
#'   `bar_text_size` and `font_size`.
#' @return A ggplot object.
build_flood_status_bar <- function(flood_stage_cols_blue, flood_stage_cols_red,
                                    precip_grayscale, font_legend,
                                    config_vars) {
  flood_alpha <- if (precip_grayscale) 0.7 else 0.85
  flood_cols  <- if (precip_grayscale) flood_stage_cols_blue else flood_stage_cols_red

  key <- tibble(
    flood_status = factor(c("Flood", "Moderate", "Major"),
                          levels = c("Major", "Moderate", "Flood")),
    label = c("Flood", "Moderate flood", "Major flood"),
    y_center = c(0.5, 1.5, 2.5)
  )

  ggplot(key, aes(x = 0, y = 1, fill = flood_status)) +
    geom_col(width = 0.5, color = NA, alpha = flood_alpha,
             show.legend = FALSE) +
    geom_text(aes(x = 0.4, y = y_center, label = label),
              hjust = 0, vjust = 0.5, family = font_legend, fontface = "bold",
              size = config_vars$bar_text_size,
              color = flood_cols[as.character(key$flood_status)]) +
    scale_fill_manual(values = flood_cols, drop = FALSE) +
    scale_x_continuous(limits = c(-0.5, 4), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 3), expand = c(0, 0)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = font_legend) +
    theme(text = element_text(size = config_vars$font_size))
}
