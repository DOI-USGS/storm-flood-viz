#' Build the "<N> gages in flood stage" stat callout for one animation frame.
#'
#' Big number + label showing the current total Flood+Moderate+Major gage
#' count -- the same total the flood-timeline barplot's rightmost bar stacks
#' to at `dtg`.
#'
#' @param flood_counts_all data.frame from [p2_flood_counts_by_hour]: one row
#'   per `dateTime`/`flood_status` with gage count `n`.
#' @param dtg POSIXct. Current frame timestamp.
#' @param lbl Function. The anchored label helper built in [compose_frame()].
#' @param anchors Named list of canvas anchor points (x, y in 0-1 coords).
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A list of grid/ggplot2 layer objects.
build_flood_stat_callout <- function(flood_counts_all, dtg, lbl, anchors,
                                      config_vars) {
  total <- sum(flood_counts_all$n[flood_counts_all$dateTime == dtg])
  number_size <- config_vars$flood_stat_number_size
  if (is.null(number_size)) number_size <- 20
  label_size <- config_vars$flood_stat_label_size
  if (is.null(label_size)) label_size <- 13

  number_lineheight_pt <- systemfonts::font_info(
    family = config_vars$load_font, weight = "bold",
    size = number_size, res = 72
  )$lineheight
  label_dy <- (number_lineheight_pt * 0.8) / (config_vars$height * 72)

  list(
    lbl(format(total, big.mark = ","), "flood_stat", bold = TRUE, size = number_size),
    lbl("gages in flood stage", "flood_stat", dy = label_dy, size = label_size)
  )
}
