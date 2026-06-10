#' Partition one timestep's gages into the render groups the flood layer draws.
#'
#' Lifts all row filtering and draw-order sorting out of
#' [build_flood_layer()] so the visualize step only does geometry, not data
#' selection. The grouping is identical for spike and point modes; the
#' percentile-to-height/size mappings stay in the layer builder since those are
#' presentation tied to viz params (peak_height, points_range).
#'
#' @param flow_now sf data.frame. One timestep from `p2_flow_by_time`; must
#'   contain `above_flood`, `percentile`, `flood_status`, `sev_rank`,
#'   `above_amt`, `dateTime`, `is_decommissioned`, the flood-stage columns, and
#'   an sf `geometry` column.
#' @param perc_filter Character vector of `percentile` tiers treated as
#'   "elevated" — the gray (not-yet-flooded) and spike groups are limited to
#'   these tiers.
#' @return Named list of sf data.frames:
#'   \describe{
#'     \item{non_flooded}{Base non-flooded points.}
#'     \item{decom}{Decommissioned (out-of-service) gages.}
#'     \item{gray}{Elevated-percentile, not-yet-flooded gages.}
#'     \item{flooded}{All flooded gages, in draw order (point mode + spike dots).}
#'     \item{flooded_high}{Elevated-percentile flooded gages with a stage
#'       threshold, in draw order (spike links).}
#'   }
process_flood_groups <- function(flow_now,
                                 perc_filter) {
  flooded_order <- function(df) arrange(df, sev_rank, desc(above_amt),
    desc(dateTime))
  list(
    non_flooded = flow_now |>
      filter(above_flood == "FALSE") |>
      filter(!(percentile %in% perc_filter)) |>
      filter(!is.na(flood_status)),
    decom = filter(flow_now, is_decommissioned),
    gray = flow_now |>
      filter(!above_flood, !is.na(percentile), percentile %in% perc_filter),
    flooded = flooded_order(filter(flow_now, above_flood)),
    flooded_high = flow_now |>
      filter(above_flood, !is.na(percentile), percentile %in% perc_filter,
        !is.na(flood.stage) | !is.na(moderate.flood.stage) |
          !is.na(major.flood.stage)) |>
      flooded_order()
  )
}
