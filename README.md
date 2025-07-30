# Hurricane Revamp Animation

This repository creates a series of hurricane/storm track related maps using NOAA flood data from [water.noaa.gov](https://water.noaa.gov/resources/downloads/reports/) and hurricane track data is from NOAA National Hurricane Center [nhc.noaa.gov](https://www.nhc.noaa.gov/gis/best_track/)

# Running the pipeline

This repository uses a pipeline with the [`targets` library](https://github.com/ropensci/targets) for R. To run the pipeline, install `targets` and run `targets::tar_make()` in the console. You may find that you get errors at first if you do not have all of the necessary packages, e.g. `Error : could not find packages terra, ggimage in library paths`. Install the packages that are needed (using `install.packages("[packageName]")` and try`targets::tar_make()`again. Repeat as needed. You will need the following packages installed:`tidyverse`, `sf`, `reticulate`, `janitor`, `sbtools`, `tigris`, `sysfonts`, `showtext`, `readr`, `cowplot`, `rmapshaper`, `terra`, `raster`, `tidyterra`, `rvest`, `httr`, `fs`, `glue`, `dataRetrieval`, `ggimage`.

The pipeline will fetch and visualize flood stage and storm track data for provided dates and bounding box. All animation frames will then be loaded in `3_visualize/out/food_stage_frames` and the frames will be compiled to build the final animation in `3_visualize/out`

# Manually adjust components

This pipeline is intentionally structured to be manually adjusted for new storms/hurricanes that occur. Much of the components needed to be adjusted will be done in `0_config.R`. Namely, these targets:

-   `p0_bbox_sf`

```         
-   Define the geographic bounding box of interest using NAD83 (`"EPSG:4269"`) coordinates in decimal degrees. This area sets the spatial extent for precipitation, streamgage, and storm track data.

-   Example: `sf::st_bbox(c(xmin = -98.21, xmax = -69.97, ymin = 23, ymax = 44.6))`
```

-   `p0_proj`

    -   Set the projection string (e.g. EPSG code) appropriate for mapping the region. For large areas across the southeastern U.S., `EPSG:3086` (NAD83 / Conus Albers) is a good choice.

-   `p0_date_start`

    -   Start date of the animation period, in `"YYYY-MM-DD"` format. Choose a date a day or two before the storm's arrival to capture early rainfall and streamflow conditions.

-   `p0_date_end`

    -   End date of the animation period. Should extend past landfall to show ongoing impacts such as flooding or continued precipitation.

-   `p0_storm_info`

    -   A `tibble()` describing the storm being visualized. Must include:

        -   `storm_name`: name of the storm (all caps, e.g., `"HELENE"`)

        -   `storm_code`: storm identifier used by NOAA (e.g., `"al092024"`)

        -   `storm_buffer`: distance (in meters) to buffer around the storm track for spatial filtering

        -   `shape_type`: method for spatial filtering (e.g., `"buffered_storm_track"`)

        -   `storm_best_track_url`: source of storm track shapefiles (e.g., from [NHC GIS archive](https://www.nhc.noaa.gov/gis/best_track/))

        -   `stn_event`: code number associated with short-term network (STN) rapid deployment gage (e.g. 346 code for Hurricane Helene - values available at [STN Data Portal](https://stn.wim.usgs.gov/STNDataPortal/#))

-   **`p0_pcodes`**

    -   Vector of USGS parameter codes (e.g., `00060` for discharge and `00065` for gage height) used to filter streamgage data.

-   **`p0_precip_bbox`**

    -   A list version of the bounding box (same as `p0_bbox_sf`), used to subset gridded precipitation data. Automatically derived using `unname(as.list(p0_bbox_sf))`.

-   `p0_precip_start / p0_precip_end`

    -   Start and end timestamps (in `"YYYY-MM-DDTHH"` format) for retrieving gridded precipitation data. Must align with the desired animation timeframe.

-   `p0_timezone`

    -   Sets the local timezone for labeling times in final visualizations -- All processing is done in UTC, but this value (e.g., `"America/New_York"`) ensures that labels, countdowns, and annotations reflect the expected local time.

-   `p0_timezone_abv`

    -   Abbreviation used for the local timezone, for display in map title (e.g., `"ET"` for Eastern Time).

-   `p0_landfall_time`

    -   A `POSIXct` timestamp in UTC indicating the expected time of landfall. This is used to trigger a countdown label on frames leading up to landfall. Can be determined from NHC forecasts or storm summary pages.

-   `p0_viz_fs_config_pal_blue`

    -   Color palette (blue theme) for flood stage categories used in the map and legend. A named vector mapping categorical flood severity (e.g., `"Moderate"`) to color codes (e.g., `"#17718E"`).

-   `p0_viz_fs_config_pal_red`

    -   Alternative flood stage color palette (red theme) for use in more attention-grabbing contexts, following NOAA National Water Prediction Service (NWPS) colors. Also a named vector with categories like `"Flood"` and `"Major"` tied to color hex codes.

```{=html}
<!-- -->
```
-   `p0_viz_percentile_config_pal`

    -   Color scale for streamflow percentiles, typically used in non-storm visualizations or background context. Ordered from very dry to very wet, including a neutral color (`"#C0C0C0"`) for normal conditions.

-   `p0_viz_precip_config_pal_blue`

    -   Blue-toned color palette for representing total precipitation in maps.

-   `p0_viz_precip_config_pal_grayscale`

    -   Grayscale palette for precipitation, used when visual context or accessibility requires less saturation.

-    `p0_precip_grayscale_var`

    -   Toggle to use grayscale precipitation styling. Accepts `"TRUE"` or `"FALSE"` as a string. When `"TRUE"`, grayscale colors are applied to precip layers.

-   `p0_flood_spike_var`

    -   Toggle for how flood points are drawn:

        -   `"FALSE"`: Use sized circles scaled by duration above flood stage.

        -   `"TRUE"`: Use triangular "spike" scaled by time above flood stage.

-   `p0_viz_config_df`

    -   A `tibble()` containing all styling and layout variables for the plot, including:

        -   Output figure dimensions (`width`, `height`, `dpi`)

        -   Color for state outlines, background, ocean, streamgages, and storm paths

        -   Font family and text sizes for titles, legends, and margins (`load_font`, `font_size_title`, etc.)

        -   Plot margins as a proportion of the frame (e.g., `plot_margin = 0.025`)

# Data Citation

National Oceanic and Atmospheric Administration. NWPS all gauges report [Data set]. NOAA National Water Prediction Service. Retrieved June 23, 2025, from <https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv>

National Hurricane Center. Best track data (HURDAT2) [Data set]. National Oceanic and Atmospheric Administration. Retrieved June 23, 2025, from <https://www.nhc.noaa.gov/gis/best_track/>

USGS Short-Term Network Portal. U.S. Geological Survey. *Short-Term Network Data Portal*. Accessed via: <https://stn.wim.usgs.gov/STNDataPortal/>

DeCicco L, Hirsch R, Lorenz D, Read J, Walker J, Platt L, Watkins D, Blodgett D, Johnson M, Krall A, Stanish L, Zemmels J, Hinman E, Mahoney M (2025). *dataRetrieval: R packages for discovering and retrieving water data available from U.S. federal hydrologic web services*. [doi:10.5066/P9X4L3GE](https://doi.org/10.5066/P9X4L3GE).
