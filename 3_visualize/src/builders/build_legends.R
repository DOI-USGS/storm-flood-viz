#' Build all legend grobs and icon plots for one animation frame.
#'
#' Centralises every small legend element so `compose_frame()` can place
#' them without constructing ggplot objects inline. The precip colorbar is
#' extracted from the same fill scale used to render the raster, avoiding
#' any re-rendering of the full precip data.
#'
#' @param precip_fill_scale The ggplot2 scale object returned by the `$scale`
#'   element of [build_precip_layer()]. Reused here to extract the colorbar
#'   via a minimal dummy dataset.
#' @param global_max_precip Numeric. Upper precip limit (inches); sets the
#'   dummy dataset range for the colorbar extraction.
#' @param flood_spikes Logical. Selects which custom flood-stage explainer PNG
#'   to load: spike version (TRUE) or sized-point version (FALSE).
#' @param flood_stage_spike_leg_path Character. Path to the spike-mode
#'   flood-stage explainer PNG.
#' @param flood_stage_point_leg_path Character. Path to the point-mode
#'   flood-stage explainer PNG.
#' @param target_rdg_icon Character. Path to the rapid-deployment gage
#'   bullseye PNG.
#' @param config_vars Named list of styling options. Must contain `bg_col`
#'   and `x_mark` (set in storm YAML viz_config).
#' @return A named list:
#'   \describe{
#'     \item{precip}{grob. Precip colorbar extracted via get_legend.}
#'     \item{dot}{ggplot. Gray circle icon (USGS streamgage; both modes).}
#'     \item{peak}{ggplot. Gray triangle icon (spike-mode flood indicator).}
#'     \item{flood_stage}{magick-image. Resized flood-stage explainer PNG.}
#'     \item{rdg}{ggplot. Rapid-deployment gage bullseye icon.}
#'     \item{decom}{ggplot. Out-of-service streamgage X-mark icon.}
#'   }
build_legends <- function(precip_fill_scale, global_max_precip,
                           flood_spikes, flood_stage_spike_leg_path,
                           flood_stage_point_leg_path, target_rdg_icon,
                           config_vars) {
  legend_precip <- get_legend(
    ggplot(
      data.frame(
        x = c(1, global_max_precip),
        y = 1,
        fill = c(1, global_max_precip)
      ),
      aes(x, y, fill = fill)
    ) +
      geom_tile() +
      precip_fill_scale +
      theme(legend.position = "right")
  )

  p_dot <- ggplot() +
    geom_point(
      data = data.frame(x = 1, y = 1),
      aes(x = x, y = y),
      shape = 21, fill = config_vars$legend_icon_col, size = config_vars$dot_legend_size,
      stroke = 0.1, color = config_vars$bg_col, alpha = 0.8
    ) +
    theme_void()

  p_peak <- ggplot(
    data.frame(x = c(0, -0.25, 0.25), y = c(1.5, 0, 0)),
    aes(x = x, y = y)
  ) +
    geom_polygon(fill = config_vars$legend_icon_col, color = NA, alpha = 0.8) +
    coord_fixed() +
    theme_void()

  flood_stage_img <- if (flood_spikes) {
    image_read(flood_stage_spike_leg_path)
  } else {
    image_read(flood_stage_point_leg_path)
  }
  flood_stage_img <- image_resize(flood_stage_img, "x200")

  p_rdg <- ggplot(
    data.frame(X = 0.5, Y = 0.5),
    aes(x = X, y = Y)
  ) +
    geom_image(image = target_rdg_icon,
                        size = config_vars$rdg_legend_icon_size) +
    theme_void()

  p_decom <- ggplot(
    data.frame(x = 0, y = 0),
    aes(x = x, y = y)
  ) +
    geom_point(
      shape = 4, color = config_vars$x_mark,
      size = config_vars$decom_legend_size,
      alpha = config_vars$flood_point_alpha, stroke = 1
    ) +
    theme_void()

  list(
    precip = legend_precip,
    dot = p_dot,
    peak = p_peak,
    flood_stage = flood_stage_img,
    rdg = p_rdg,
    decom = p_decom
  )
}
