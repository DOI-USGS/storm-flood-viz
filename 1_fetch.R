# source("1_fetch/src/fetch_utils.R")
library(reticulate)

use_condaenv("hurricane-precip", required = TRUE) 

tar_option_set(packages = c("reticulate"))
source("1_fetch/src/get_precip_wrapper.R")

p1_targets <- list(
  tar_target(p1_precip_py, 
             "1_fetch/src/get_precip.py",
             format = "file"),
  tar_target(p1_precip_bbox,
             list(-92.0, 23.0, -80.0, 45.0)),
  tar_target(p1_precip_start,
             "2024-09-26T00"),
  tar_target(p1_precip_end,
             "2024-09-26T23"),
  tar_target(p1_precip_tifs, 
             download_precip_r(py_script = p1_precip_py,
                               bBox = p1_precip_bbox,
                               start_time_str = p1_precip_start,
                               end_time_str = p1_precip_end,
                               summed = "cumulative",
                               output_path = "1_fetch/out/"),
             format = 'file')
)