#' Build major-city marker and label layers.
#'
#' Renders diamond symbols at city locations and nudged text labels above them.
#' Intended to be added after the basemap and precip layers so cities render
#' on top of the raster.
#'
#' @param major_cities sf. City points; must contain a `NAME` column.
#' @param font_legend Character. Font family for city labels.
#' @param config_vars Named list of styling options. Must contain
#'   `major_cities_col`, `major_cities_text_col`, `city_symbol_size`,
#'   `city_text_size`, and `city_label_nudge_y` (set in storm YAML viz_config).
#' @return A list of ggplot2 layer objects suitable for use with `+`.
build_cities_layer <- function(major_cities, font_legend, config_vars) {
  list(
    geom_sf(
      data = major_cities, shape = 23, fill = NA,
      color = config_vars$major_cities_col,
      size = config_vars$city_symbol_size, stroke = 0.3
    ),
    geom_sf_text(
      data = major_cities, aes(label = NAME),
      color = config_vars$major_cities_text_col,
      size = config_vars$city_text_size,
      nudge_y = config_vars$city_label_nudge_y,
      family = font_legend
    )
  )
}
