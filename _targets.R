library(targets)
library(tarchetypes)
library(reticulate)

# tigris_use_cache: cache downloaded Census/TIGER layers (states, places) to
# disk so they are not re-downloaded on every pipeline run.
options(tidyverse.quiet = TRUE, timeout = 800, tigris_use_cache = TRUE)
tar_option_set(packages = c('tidyverse',
                            'sf',
                            'reticulate',
                            'janitor',
                            'sbtools',
                            'tigris',
                            'tidycensus',
                            'readr',
                            'cowplot',
                            'rmapshaper',
                            'terra',
                            'raster',
                            'tidyterra',
                            'rvest',
                            'httr',
                            'fs',
                            'glue',
                            'dataRetrieval',
                            'ggimage',
                            'ggtext',
                            'yaml',
                            'ragg',
                            'av',
                            'ggforce'))

# Phase target makefiles
source("0_config.R")
source("1_fetch.R")
source("2_process.R")
source("3_visualize.R")

# Combined list of target outputs
c(
  p0_targets,
  p1_targets,
  p2_targets,
  p3_targets
)
