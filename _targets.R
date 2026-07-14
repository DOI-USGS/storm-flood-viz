library(targets)
library(tarchetypes)
library(reticulate)
library(crew)

# Fail fast if required setup is missing: a resolvable Python 
# plus both API keys. See README for setup.
stopifnot(
  (Sys.getenv("RETICULATE_PYTHON") != "" ||
     condaenv_exists("storm-precip")) &&
    Sys.getenv("CENSUS_API_KEY") != "" &&
    Sys.getenv("API_USGS_PAT") != ""
)

# Set Python environment and load the precipitation data processing script.
py <- Sys.getenv("RETICULATE_PYTHON", unset = "")
if (nzchar(py)) {
  use_python(py, required = TRUE)
} else {
  use_condaenv("storm-precip", required = TRUE)
}
source_python("1_fetch/src/get_precip.py")

# tigris_use_cache: cache downloaded Census/TIGER layers (states, places) to
# disk so they are not re-downloaded on every pipeline run.
options(tidyverse.quiet = TRUE, timeout = 800, tigris_use_cache = TRUE)

# Crew controller: run independent targets in parallel across local worker
# processes; workers shut down after seconds_idle. Adjust workers to your
# machine's core count. Run the pipeline as usual with tar_make().
tar_option_set(controller = crew_controller_local(
                              workers = 4,
                              seconds_idle = 30),
               packages = c('tidyverse',
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
                            'ggforce',
                            'magick',
                            'arrow',
                            'grid',
                            'scales',
                            'jsonlite',
                            'ggnewscale',
                            'tools'))

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
