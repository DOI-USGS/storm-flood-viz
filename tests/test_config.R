# Smoke test for the config refactor.
#
# Verifies that load_storm_config("config/helene.yml") returns values
# identical to the pre-refactor literals from 0_config.R.
#
# Run from project root:
#   Rscript tests/test_config.R

suppressPackageStartupMessages(library(targets))  # 0_config.R uses tar_target()
source("0_config.R")  # defines load_storm_config()

cfg <- load_storm_config("config/helene.yml")

# Storm metadata
stopifnot(cfg$date_start == "2024-09-24")
stopifnot(cfg$date_end == "2024-09-29")
stopifnot(cfg$landfall_time == as.POSIXct("2024-09-27 03:00:00", tz = "UTC"))
stopifnot(attr(cfg$landfall_time, "tzone") == "UTC")

# Storm info tibble
stopifnot(inherits(cfg$storm_info, "tbl_df"))
stopifnot(cfg$storm_info$storm_name == "HELENE")
stopifnot(cfg$storm_info$storm_code == "al092024")
stopifnot(cfg$storm_info$storm_buffer == 250000)
stopifnot(cfg$storm_info$stn_event == 346)

# Spatial
stopifnot(inherits(cfg$bbox, "bbox"))
stopifnot(identical(unname(cfg$bbox), c(-98.21, 23, -69.97, 44.6)))
stopifnot(grepl("^\\+proj=aea", cfg$proj))

# Display tz + viz toggles (kept as strings to match existing pipeline code)
stopifnot(cfg$timezone == "America/New_York")
stopifnot(cfg$timezone_abv == "ET")
stopifnot(cfg$precip_grayscale == "FALSE")
stopifnot(cfg$flood_spike == "TRUE")

# Named-map palettes round-trip with names preserved
stopifnot(identical(cfg$pal_fs_blue, c("Not flooded" = "#dcdcdc", "Flood" = "#4ecad7", "Moderate" = "#17718E", "Major" = "#003e6a")))
stopifnot(identical(cfg$pal_fs_red, c("Not flooded" = "#dcdcdc", "Flood" = "#e5a000", "Moderate" = "#F7513B", "Major" = "#C917E8")))

# Sequence palettes are unnamed character vectors of length 7
stopifnot(is.character(cfg$pal_percentile), length(cfg$pal_percentile) == 7, is.null(names(cfg$pal_percentile)))
stopifnot(is.character(cfg$pal_precip_blue), length(cfg$pal_precip_blue) == 7)
stopifnot(is.character(cfg$pal_precip_grayscale), length(cfg$pal_precip_grayscale) == 7)
stopifnot(cfg$pal_percentile[1] == "#8c2d04")
stopifnot(cfg$pal_precip_blue[1] == "#c7f0f6")

# viz_config tibble: spot-check numeric and string fields
stopifnot(inherits(cfg$viz_config, "tbl_df"))
stopifnot(cfg$viz_config$width == 8, cfg$viz_config$height == 8, cfg$viz_config$dpi == 300)
stopifnot(cfg$viz_config$load_font == "Source Sans Pro")
stopifnot(cfg$viz_config$plot_shift_x == -0.18)
stopifnot(cfg$viz_config$plot_height == 1.6)

# Template loads and has the same top-level shape
tpl <- load_storm_config("config/_template.yml")
stopifnot(setequal(names(cfg), names(tpl)))

cat("OK — config refactor produces expected values\n")
