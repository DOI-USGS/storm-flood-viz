# source("1_fetch/src/fetch_utils.R")

use_condaenv("hurricane-precip", required = TRUE)
source_python("1_fetch/src/get_precip.py")

p1_targets <- list(
  tar_target(p1_precip_bbox,
             list(-82.0, 28.0, -79.0, 30.0)),
  tar_target(p1_precip_start,
             "2024-10-07T10"),
  tar_target(p1_precip_end,
             "2024-10-07T15"),
  tar_target(summed,
             TRUE),
  tar_target(p1_precip_tif, 
             download_precip(bBox=p1_precip_bbox,
                             start_time_str=p1_precip_start,
                             end_time_str=p1_precip_end,
                             summed=summed),
             format = 'file')
)