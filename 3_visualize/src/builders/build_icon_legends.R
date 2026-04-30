#' Build small icon ggplots used as inline legend symbols.
#'
#' @param config_vars Named list of styling options. Must contain `bg_col`.
#' @return A named list with two ggplot elements:
#'   \describe{
#'     \item{dot}{Gray circle representing a non-flooded streamgage.}
#'     \item{peak}{Gray triangle representing a percentile spike.}
#'   }
build_icon_legends <- function(config_vars) {
  dot <- ggplot() +
    geom_point(
      data = data.frame(x = 1, y = 1),
      aes(x = x, y = y),
      shape = 21,
      fill = "#aaaaaa",
      size = 5,
      stroke = 0.1,
      color = config_vars$bg_col,
      alpha = 0.8
    ) +
    theme_void()

  peak <- ggplot(
    data.frame(
      x = c(0, -0.25, 0.25),
      y = c(1.5, 0, 0)
    ),
    aes(x, y)
  ) +
    geom_polygon(
      fill  = "#aaaaaa",
      color = NA,
      alpha = 0.8
    ) +
    coord_fixed() +
    theme_void()

  list(dot = dot, peak = peak)
}
