#' Build the precipitation raster layer and fill scale.
#'
#' Constructs the stepped fill scale (colorized or grayscale) and the
#' geom_raster layer. Returns both so the scale can be reused by
#' [build_legends()] to extract the color-bar legend grob without
#' re-rendering the raster.
#'
#' @param precip_now data.frame. Gridded precipitation at the current
#'   timestep; must contain columns `x`, `y`, and `precip_in`.
#' @param precip_cols Character vector. Colorized precipitation palette.
#' @param precip_grayscale_cols Character vector. Grayscale precipitation
#'   palette.
#' @param global_max_precip Numeric. Upper limit of the precipitation scale
#'   (inches).
#' @param precip_grayscale Logical. If TRUE use grayscale palette; if FALSE
#'   use colorized palette.
#' @param font_legend Character. Font family for the legend title.
#' @param config_vars Named list of styling options. Must contain
#'   `precip_raster_alpha` and `precip_col_alpha` (set in storm YAML
#'   viz_config).
#' @return A named list:
#'   \describe{
#'     \item{layers}{List of ggplot2 layers/scales to add to the base plot.}
#'     \item{scale}{The precip fill scale object, for passing to
#'       [build_legends()].}
#'   }
build_precip_layer <- function(precip_now, precip_cols, precip_grayscale_cols,
                               global_max_precip, precip_grayscale,
                               font_legend, config_vars) {
  # ggplot2 3.5+ guide API: appearance goes inside theme() within the guide
  precip_guide <- ggplot2::guide_coloursteps(
    theme = ggplot2::theme(
      legend.direction = "horizontal",
      legend.title.position = "left",
      legend.key.width = grid::unit(
        config_vars$precip_legend_key_width_cm, "cm"),
      legend.key.height = grid::unit(
        config_vars$precip_legend_key_height_cm, "cm"),
      legend.text.position = "bottom",
      legend.text = ggplot2::element_text(size = 0, color = "transparent"),
      legend.title = ggplot2::element_text(
        family = font_legend, hjust = 0, vjust = 0.5)
    )
  )

  cols <- if (precip_grayscale) {
    precip_grayscale_cols
  } else {
    scales::alpha(precip_cols, config_vars$precip_col_alpha)
  }

  scale <- ggplot2::scale_fill_stepsn(
    colors = cols,
    breaks = get_precip_breaks(global_max_precip),
    limits = c(1, global_max_precip),
    name = NULL,
    na.value = scales::alpha("white", 0),
    guide = precip_guide
  )

  layers <- list(
    ggplot2::geom_raster(
      data = precip_now,
      ggplot2::aes(x = .data$x, y = .data$y, fill = .data$precip_in),
      alpha = config_vars$precip_raster_alpha
    ),
    scale
  )

  list(layers = layers, scale = scale)
}
