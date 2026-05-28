![](USGS_ID_black.png)

# Visualizing Hurricane Impacts Using Flood Stage and Streamgage Data

> *A newer version of the software may be available. See <https://code.usgs.gov/wma/vizlab/hurricane-revamp/-/releases> to view all releases.*

**Authors**: Elmera Azadpour, Elise Hinman, Jeffrey Kwang, Kaysa Vaarre-Lamoureux, Cee Nell, Hayley Corson-Dosch

**Point of contact**: Elmera Azadpour ([eazadpour\@usgs.gov](mailto:eazadpour@usgs.gov){.email})

**Repository Type**: *R* script supporting publication

**Year of Origin**: 2025 (original publication)

**Year of Version**: 2025

**Digital Object Identifier (DOI)**: <https://doi.org/10.5066/P1CGKFTD>

**USGS Information Product Data System (IPDS) no.**: IP-182360 (internal agency tracking)

------------------------------------------------------------------------

This repository creates a series of hurricane/storm track related maps using NOAA flood data from [water.noaa.gov](https://water.noaa.gov/resources/downloads/reports/) and hurricane track data is from NOAA National Hurricane Center [nhc.noaa.gov](https://www.nhc.noaa.gov/gis/best_track/)

# Running the pipeline

This repository uses a pipeline with the [`targets` library](https://github.com/ropensci/targets) for R. To run the pipeline, install `targets` and run `targets::tar_make()` in the console. You may find that you get errors at first if you do not have all of the necessary packages, e.g. `Error : could not find packages terra, ggimage in library paths`. Install the packages that are needed (using `install.packages("[packageName]")` and try `targets::tar_make()` again. Repeat as needed. You will need the following packages installed: `tidyverse`, `sf`, `reticulate`, `janitor`, `sbtools`, `tigris`, `sysfonts`, `showtext`, `readr`, `cowplot`, `rmapshaper`, `terra`, `raster`, `tidyterra`, `rvest`, `httr`, `httr2`, `fs`, `glue`, `dataRetrieval`, `arrow`, `purrr`, `ggimage`, `ggtext`.

## Python environment setup

The pipeline uses Python only for precipitation data retrieval (`get_precip.py`). The following Python packages are required: `xarray`, `fsspec`, `numpy`, `pandas`, `scipy`, `gdal`.

The pipeline resolves the Python environment in the following order:

1. If the environment variable `RETICULATE_PYTHON` is set, it will use that Python executable. Set this in your `.Renviron` file:
```
RETICULATE_PYTHON=/path/to/your/python
```
You can find the correct path by activating your Python environment in the terminal and running `which python`.

2. If `RETICULATE_PYTHON` is not set, the pipeline falls back to a conda environment named `hurricane-precip`. Ensure this environment exists and has the required dependencies installed.

The pipeline will fetch and visualize flood stage and storm track data for provided dates and bounding box. All animation frames will then be loaded in `3_visualize/out/food_stage_frames` and the frames will be compiled to build the final animation in `3_visualize/out`

## Running the code

This code has been organized into a data pipeline using the [targets](https://books.ropensci.org/targets/) package. Targets is a pipeline building tool that automatically tracks the status (i.e., up-to-date vs. out-of-date) and builds intermediate objects only as needed. To run the entire pipeline, you can run the command [`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html), after the steps (above) have been completed. For more information on targets, the package author has written [a walkthrough to get started](https://books.ropensci.org/targets/walkthrough.html) and there is an [Introduction to targets](https://carpentries-incubator.github.io/targets-workshop/) training that is currently in development but still may be useful in its current state.

## Code runtime

The entire pipeline run-time varies based on `p0_date_start` and `p0_date_end`, as well as size of `p0_bbox_sf`. For the default loaded Hurricane Helene, the total run-time is \~5 hours on a high-end laptop (e.g. Apple M1 Max)

## Manually adjust components

This pipeline is intentionally structured to be manually adjusted for new storms/hurricanes that occur. Much of the components needed to be adjusted will be done in `0_config.R`. Namely, these targets:

-   `p0_bbox_sf`

    -   Define the geographic bounding box of interest using NAD83 (`"EPSG:4269"`) coordinates in decimal degrees. This area sets the spatial extent for precipitation, streamgage, and storm track data. Example: `sf::st_bbox(c(xmin = -98.21, xmax = -69.97, ymin = 23, ymax = 44.6))`

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

-   `p0_nwis_start / p0_nwis_end`

    -   Start and end timestamps (in `"YYYY-MM-DDTHH:MMZ"` format) for pulling instantaneous values for gage height from `dataRetrieval::readNWISuv()`. We define these in UTC time to match the precip data pull.

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

-   `p0_viz_percentile_config_pal`

    -   Color scale for streamflow percentiles, typically used in non-storm visualizations or background context. Ordered from very dry to very wet, including a neutral color (`"#C0C0C0"`) for normal conditions.

-   `p0_viz_precip_config_pal_blue`

    -   Blue-toned color palette for representing total precipitation in maps.

-   `p0_viz_precip_config_pal_grayscale`

    -   Grayscale palette for precipitation, used when visual context or accessibility requires less saturation.

-   `p0_precip_grayscale_var`

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

        -   Plot x and y movement, as well as plot height and width values (e.g., `plot_shift_x`, `plot_shift_y`, `plot_width`, `plot_height`)

-   In cases where the storm occurs in regions such as Puerto Rico, Alaska, Hawaii, etc, users will need to adjust `p1_conus_bbox_crop_sf` which downloads [tigris](https://github.com/walkerke/tigris) state borders and crops to bbox. Additionally, based on storm region and bbox, users will likely need to edit `p1_major_cities_sf` to manually assign city/state labels in the tibble to help orient viewers.

## Repository organization

-   `0_config/` directory containing files related to configuration.
-   `1_fetch/` directory containing files related to fetching data.
    -   `src/` directory containing source code to define functions.
        -   `clip_flood_stage_gages.R` R script that filters flood-stage gages to bbox
        -   `fetch_rapid_deployment_data.R` R script that fetches Rapid-Deployment Gage sites from STN as `sf`
        -   `fetch_uv_peaks_data.R` R script defining downloads of NWIS instantaneous data and peaks; write parquet.
        -   `get_precip.py` Python script to pull NOAA Stage 4 precipitation and export GeoTIFF rasters.
        -   `fetch_site_stats.R` R script that fetches day-of-year streamflow percentile thresholds (p05–p95) from the USGS waterdata statistics API for all active gages in the bbox, filtered to sites with a minimum period of record. Replaces the former `generate_hyswap_percentiles.py` approach.
        -   `storm_shape_functions.R` R script defining percentiles from historical daily data; tag instantaneous data.
    -   **Percentile threshold note:** Sites are filtered to a minimum of **10 years** of discharge record (parameter `min_por_years` in `fetch_site_stats()`). The original spec called for 20 years. Testing against the Helene site list showed ≥20 yr qualifies 4,158 sites while ≥10 yr qualifies 4,937 — a gain of 779 sites (+19%), with the added sites having PORs clustered between 10–20 years. Sites below the threshold receive `percentile = NA` and appear as gray dots without a percentile spike. The threshold is configurable if 20 years is preferred for future events.
    -   `out/` directory containing output files (once code is run).
        -   `gage_peak_data.parquet` parquet file of NWIS peaks
        -   `gage_uv_data.parquet` parquet file of instantaneous NWIS data
        -   `site_stats.parquet` parquet file of USGS day-of-year percentile thresholds (p05–p95) per site
        -   `[p0_precip_start]_to_[p0_precip_end].tif` precipitation raster files for given date and hours.
        -   `storm_shape_[p0_storm_info$storm_code]` shapefiles associated with hurricane path/points/radii/windswath.
-   `2_process/` directory containing files related to processing data.
    -   `src/` directory containing source code to define functions.
        -   `process_hourly_max_uv.R` R script to extract hourly maximum gage height and discharge from instantaneous values; join parameters; add optional percentiles.
        -   `process_precip.R` R script to read Stage 4 precipitation rasters, reproject/crop to the bounding box area, reshape to long format, and compute hourly/total/cumulative precipitation.
        -   `process_states.R` R script to build state boundary layers; derive inner shared borders and the outer outline as `sf` geometries.
-   `3_visualize/` directory containing files related to visualizing data.
    -   `src/` directory containing source code to define functions.
        -   `mapping_utils.R` R script that contains mapping function to create frames of hurricane animation in either spike or point format
        -   `title_end_frame.R` R script that defines title frame and end frame of the animation
    -   `out/` directory containing output files of pie and bar charts (once code is run).
        -   `[p0_storm_info$storm_name]_flood_stage_spike_animation.gif` animation of flood stage spikes
        -   `[p0_storm_info$storm_name]_flood_stage_point_animation.gif` animation of flood stage points
        -   `flood_stage_[p0_storm_info$storm_name]_spike_frames`
            -   `frame_[datehour].png` PNG files of hurricane spike map over time
            -   `frame_00000000000.png` PNG of spike title frame
            -   `frame_99999999999.png` PNG of spike final frame
        -   `flood_stage_[p0_storm_info$storm_name]_point_frames`
        -   `frame_[datehour].png` PNG files of hurricane point map over time
        -   `frame_00000000000.png` PNG of point title frame
        -   `frame_99999999999.png` PNG of point final frame
    -   `in/`
        -   `usgs_logo_black.png` PNG of black USGS logo
        -   `hurricane_symbol.png` PNG of black hurricane icon to add to final viz
        -   `custom_flood_stage_spike_leg.png` PNG of custom made legend for spike animation to describe height component of spike (duration above flood stage).
        -   `custom_flood_stage_point_leg.png` PNG of custom made legend for point animation to describe size component of point (duration above flood stage).
        -   `billeye.png` PNG of target/bullseye to serve as icon for rapid deployment gage on visualization.
-   `.gitignore` file specifying which files should not be tracked in git repository
-   `_targets.R` a [target script file](https://books.ropensci.org/targets/walkthrough.html#target-script-file) used to define a [targets pipeline](https://docs.ropensci.org/targets/index.html). See the [targets documentation](https://books.ropensci.org/targets/walkthrough.html) for how to run a targets pipeline.
-   `1_fetch.R` R script defining the "fetch" phase of the data pipeline.
-   `2_process.R` R script defining the "process" phase of the pipeline
-   `3_visualize.R` R script defining the "visualizing" phase of the pipeline
-   `code.json` metadata file containing information for code contained in this repository. Compliant with [USGS template](https://www.usgs.gov/products/software/software-management/distribution-usgs-code).
-   `CODE_OF_CONDUCT.md` information on the contribution code of conduct.
-   `CONTRIBUTING.md` information on how to contribute to this repository
-   `DISCLAIMER.md` Provisional USGS disclaimer of code in repository. Should be removed when approved.
-   `LICENSE.md` license information for code
-   `README.md` general information about the project
-   `USGS_ID_black.png` USGS logo used at the top of README.md.
-   `hurricane-revamp.Rproj` an R project file. See [6.2 Projects \| R for data science](https://r4ds.hadley.nz/workflow-scripts#projects) for more information on RStudio projects

## Expertise required

This code assumes the user is familiar with R and familiar with the [targets](https://books.ropensci.org/targets/) package (or willing to become acquainted with it). No subject matter expertise is required to run the code.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on the process for submitting pull requests to us. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details on adhering by the [USGS Code of Scientific Conduct](https://www2.usgs.gov/fsp/fsp_code_of_scientific_conduct.asp).

## Built With

-   [R](https://www.r-project.org/about.html) - data formatting and processing

## Authors

-   [**Elmera Azadpour**](https://www.usgs.gov/staff-profiles/elmera-azadpour) - *Data scientist/visualization specialist* - [USGS Water Mission Area](https://www.usgs.gov/mission-areas/water-resources)
-   [**Elise Hinman**](https://www.usgs.gov/staff-profiles/elise-hinman) - *Data scientist* - [USGS Water Mission Area](https://www.usgs.gov/mission-areas/water-resources)
-   [**Jeffrey Kwang**](https://www.usgs.gov/staff-profiles/jeffrey-kwang) - *Data scientist* - [USGS Water Mission Area](https://www.usgs.gov/mission-areas/water-resources)
-   [**Kaysa Vaarre-Lamoureux**](https://www.usgs.gov/mission-areas/water-resources) - *Data scientist (former employee)* - [USGS Water Mission Area](https://www.usgs.gov/mission-areas/water-resources)
-   [**Cee Nell**](https://www.usgs.gov/staff-profiles/cee-nell) - *Lead of the Open Data Science Team* - [USGS Water Mission Area](https://www.usgs.gov/mission-areas/water-resources)
-   [**Hayley Corson-Dosch**](https://www.usgs.gov/staff-profiles/hayley-corson-dosch)- *Data scientist* - [USGS Water Mission Area](https://www.usgs.gov/mission-areas/water-resources)

## License

This project is licensed under the Creative Commons CC0 1.0 Universal License - see the [LICENSE.md](LICENSE.md) file for details.

## Suggested Citation

In the spirit of open source, please cite any re-use of the source code stored in this repository. Below is the suggested citation:

> Azadpour E, Hinman ED, Kwang JS, Vaarre-Lamoureux K, Nell C, Corson-Dosch HR. 2025. Visualizing Hurricane Impacts Using Flood Stage and Streamgage Data. U.S. Geological Survey software release. Reston, Va. <https://doi.org/10.5066/P1CGKFTD>.

## Acknowledgments

-   Thank you to [Karl Winters](https://www.usgs.gov/staff-profiles/karl-e-winters) and [Athena Clark](https://www.usgs.gov/staff-profiles/athena-p-clark) for their subject matter expert review and guidance.

# References

National Oceanic and Atmospheric Administration. NWPS all gauges report [Data set]. NOAA National Water Prediction Service. Retrieved June 23, 2025, from <https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv>

National Hurricane Center. Best track data (HURDAT2) [Data set]. National Oceanic and Atmospheric Administration. Retrieved June 23, 2025, from <https://www.nhc.noaa.gov/gis/best_track/>

USGS Short-Term Network Portal. U.S. Geological Survey. *Short-Term Network Data Portal*. Accessed via: <https://stn.wim.usgs.gov/STNDataPortal/>

DeCicco L, Hirsch R, Lorenz D, Read J, Walker J, Platt L, Watkins D, Blodgett D, Johnson M, Krall A, Stanish L, Zemmels J, Hinman E, Mahoney M (2025). *dataRetrieval: R packages for discovering and retrieving water data available from U.S. federal hydrologic web services*. [doi:10.5066/P9X4L3GE](https://doi.org/10.5066/P9X4L3GE).
