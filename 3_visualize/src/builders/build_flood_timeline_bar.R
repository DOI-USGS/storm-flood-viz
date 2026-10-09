#' Build the growing flood-stage timeline barplot for one animation frame.
#'
#' One stacked vertical bar per hour (Flood/Moderate/Major gage counts), left
#' to right across the full animation. Only hours up to and including `dtg`
#' are drawn; later hours stay blank until the animation reaches them. The
#' x-axis spans the full timeline (not just hours seen so far) so bars don't
#' shift position as more are added.
#'
#' @param flood_counts_all data.frame from [p2_flood_counts_by_hour]: one row
#'   per `dateTime`/`flood_status` with gage count `n`, Flood/Moderate/Major
#'   only (no "Not flooded" -- stacking the full gage count buries the
#'   flood signal under it).
#' @param dtg POSIXct. Current frame timestamp; hours after this are omitted.
#' @param global_max_flood_stages Numeric. Max *stacked* Flood+Moderate+Major
#'   total across all hours (already computed this way by
#'   [p2_global_flow_maxes]'s `max_flooded`) -- sets the y-axis limit.
#' @param flood_stage_cols_red Named character vector. Flood/Moderate/Major colors.
#' @param config_vars Named list of styling options from storm YAML viz_config.
#' @return A ggplot object.
build_flood_timeline_bar <- function(flood_counts_all, dtg,
                                      global_max_flood_stages,
                                      flood_stage_cols_red, config_vars) {
  all_dtg <- sort(unique(flood_counts_all$dateTime))
  n_frames <- length(all_dtg)

  df <- flood_counts_all |>
    filter(dateTime <= dtg) |>
    mutate(hour = match(dateTime, all_dtg))

  ggplot(df, aes(x = hour, y = n, fill = flood_status)) +
    geom_col(width = 1, show.legend = FALSE) +
    scale_fill_manual(values = flood_stage_cols_red, drop = FALSE) +
    scale_x_continuous(limits = c(0.5, n_frames + 0.5), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, global_max_flood_stages * 1.05),
      expand = c(0, 0)) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = config_vars$bg_col, color = NA),
      plot.margin = margin(0, 0, 0, 0)
    )
}
