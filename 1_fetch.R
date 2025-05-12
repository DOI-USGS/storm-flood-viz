# source("1_fetch/src/fetch_utils.R")

use_condaenv("hurricane-precip", required = TRUE)
source_python("1_fetch/src/get_precip.py")

p1_targets <- list(
  tar_target(p1_precip_bbox,
             list(-92.0, 23.0, -80.0, 45.0)),
  tar_target(p1_precip_start,
             "2024-09-26T00"),
  tar_target(p1_precip_end,
             "2024-09-26T23"),
  tar_target(p1_precip_tifs, 
             download_precip(bBox = p1_precip_bbox,
                             start_time_str = p1_precip_start,
                             end_time_str = p1_precip_end,
                             summed = "cumulative",
                             output_path = "1_fetch/out/"),
             format = 'file')
)