#' Build the basemap layer list (state borders).
#'
#' Returns a list of ggplot2 layers that a caller can add to an existing
#' ggplot with `+`. Includes inner state lines and outer state boundary.
#'
#' @param state_inner_borders sf. Internal CONUS state lines.
#' @param state_outer_lines sf. Outer CONUS state boundary.
#' @param config_vars Named list of styling options. Must contain
#'   `state_inner_borders_col`, `state_outer_lines_col`,
#'   `state_inner_border_lw`, and `state_outer_border_lw`
#'   (linewidths set in storm YAML viz_config).
#' @return A list of ggplot2 layer objects suitable for use with `+`.
build_basemap <- function(state_inner_borders, state_outer_lines, config_vars) {
  list(
    geom_sf(
      data = state_inner_borders,
      color = config_vars$state_inner_borders_col,
      fill = NA, linewidth = config_vars$state_inner_border_lw
    ),
    geom_sf(
      data = state_outer_lines,
      color = config_vars$state_outer_lines_col,
      fill = NA, linewidth = config_vars$state_outer_border_lw
    )
  )
}
