#' Build the rapid-deployment gage layer for the current animation frame.
#'
#' Returns an empty list if no RDG gages are active at the current timestep,
#' so the caller can unconditionally do `p <- p + build_rdg_layer(...)`.
#'
#' Layer stacking note: add after flood layers and storm track so RDG icons
#' render on top.
#'
#' @param rdg_now sf. Rapid-deployment gage points active at the current
#'   timestep. May have zero rows.
#' @param target_rdg_icon Character. Path to the bullseye PNG icon.
#' @param config_vars Named list of styling options. Must contain
#'   `rdg_icon_size` (fraction of plot width; set in storm YAML viz_config).
#' @return A list of ggplot2 layer objects suitable for use with `+`, or an
#'   empty list if `rdg_now` has no rows.
build_rdg_layer <- function(rdg_now, target_rdg_icon, config_vars) {
  if (nrow(rdg_now) == 0) return(list())

  rdg_coords <- rdg_now |>
    dplyr::mutate(
      X = sf::st_coordinates(geometry)[, 1],
      Y = sf::st_coordinates(geometry)[, 2]
    )

  list(
    ggimage::geom_image(
      data = rdg_coords,
      aes(x = X, y = Y),
      image = target_rdg_icon,
      size = config_vars$rdg_icon_size
    )
  )
}
