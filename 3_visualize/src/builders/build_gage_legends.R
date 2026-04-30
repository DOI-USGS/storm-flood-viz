#' Build small icon ggplots for rapid-deployment and decommissioned gage legends.
#'
#' @param target_rdg_icon Character. Path to the bullseye PNG used for RDG gages.
#' @param config_vars Named list of styling options. Must contain `x_mark`.
#' @return A named list with two ggplot elements:
#'   \describe{
#'     \item{rdg}{Bullseye icon representing a rapid-deployment gage.}
#'     \item{decom}{X mark representing an out-of-service streamgage.}
#'   }
build_gage_legends <- function(target_rdg_icon, config_vars) {
  rdg <- ggplot(
    data.frame(X = 0.5, Y = 0.5),
    aes(x = X, y = Y)
  ) +
    ggimage::geom_image(
      image = target_rdg_icon,
      size = 0.6
    ) +
    theme_void()

  decom <- ggplot(
    data.frame(x = 0, y = 0),
    aes(x = x, y = y)
  ) +
    geom_point(
      shape = 4,
      color = config_vars$x_mark,
      size = 2,
      alpha = 0.75,
      stroke = 1
    ) +
    theme_void()

  list(rdg = rdg, decom = decom)
}
