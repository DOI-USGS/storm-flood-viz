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

This repository uses a pipeline with the [`targets` library](https://github.com/ropensci/targets) for R. To run the pipeline, install `targets` and run `targets::tar_make()` in the console. You may find that you get errors at first if you do not have all of the necessary packages, e.g. `Error : could not find packages terra, ggimage in library paths`. Install the packages that are needed (using `install.packages("[packageName]")`) and try `targets::tar_make()` again. Repeat as needed. You will need the following packages installed: `tidyverse`, `sf`, `reticulate`, `janitor`, `sbtools`, `tigris`, `ragg`, `systemfonts`, `textshaping`, `readr`, `cowplot`, `rmapshaper`, `terra`, `raster`, `tidyterra`, `rvest`, `httr`, `fs`, `glue`, `dataRetrieval`, `ggimage`, `ggtext`, `arrow`, `ggforce`, `httr2`, `maps`, `av`.

This code has been organized into a data pipeline using the [targets](https://books.ropensci.org/targets/) package. Targets is a pipeline building tool that automatically tracks the status (i.e., up-to-date vs. out-of-date) and builds intermediate objects only as needed. To run the entire pipeline, you can run the command [`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html). For more information on targets, the package author has written [a walkthrough to get started](https://books.ropensci.org/targets/walkthrough.html) and there is an [Introduction to targets](https://carpentries-incubator.github.io/targets-workshop/) training that may also be useful.

The pipeline will fetch and visualize flood stage and storm track data for the provided dates and bounding box. All animation frames are written to `3_visualize/out/flood_stage_[storm]_spike_frames/` or `flood_stage_[storm]_point_frames/` and compiled into a final MP4 in `3_visualize/out/`.

## Code runtime

The entire pipeline run-time varies based on `p0_date_start` and `p0_date_end`, as well as the size of `p0_bbox_sf`. For the default Hurricane Helene configuration, the total run-time is \~5 hours on a high-end laptop (e.g. Apple M1 Max).

## USGS Water Data API key

The pipeline uses the [USGS Water Data API](https://api.waterdata.usgs.gov) to fetch streamgage UV data, peak flows, and site statistics. Requests work without a key but are rate-limited. An API token raises the limit and is recommended for full pipeline runs.

1. Request a free token at <https://api.waterdata.usgs.gov/signup>.
2. Add it to your `.Renviron` file (create it in your home directory if it does not exist):

```
API_USGS_PAT=your_token_here
```

3. Restart R so the variable is available via `Sys.getenv("API_USGS_PAT")`.

Your `.Renviron` file is listed in `.gitignore` — the key will never be committed to the repository.

### Font setup

Map frames are rendered using [`ragg`](https://ragg.r-lib.org/) as the graphics device, which resolves fonts through [`systemfonts`](https://systemfonts.r-lib.org/) from your system's installed font files.The pipeline uses **Source Sans 3** (configured via `load_font` in `config/helene.yml`). To set it up:

1.  Download the Source Sans 3 static `.ttf` files from [Google Fonts](https://fonts.google.com/specimen/Source+Sans+3) (click "Download family", then use the files in the `static/` folder).
2.  Install the fonts on your system (double-click each `.ttf` on macOS/Windows, or place them in `~/.local/share/fonts/` on Linux and run `fc-cache -f`).
3.  In RStudio ≥ 1.4, go to **Tools \> Global Options \> General \> Graphics** and set the **Backend** to **AGG** so the IDE preview also uses ragg.

If you change `load_font` to a different font family, install that font on your system using the same steps above.

## Configuring a new storm

Storm-specific settings are defined in per-storm YAML files under `config/`. To add a new storm, copy `config/_template.yml`, fill in the values, and update `p0_storm_cfg_file` in `0_config.R` to point at the new file. The template documents all available fields.

## Manually adjust components

This pipeline is intentionally structured to be manually adjusted for new storms/hurricanes. Key fields in the storm config YAML (and corresponding targets in `0_config.R`) include:

-   `bbox` / `p0_bbox_sf`

    -   Define the geographic bounding box of interest using NAD83 (`"EPSG:4269"`) coordinates in decimal degrees. This area sets the spatial extent for precipitation, streamgage, and storm track data. Example: `sf::st_bbox(c(xmin = -98.21, xmax = -69.97, ymin = 23, ymax = 44.6))`

-   `proj` / `p0_proj`

    -   Set the projection string appropriate for mapping the region. For large areas across the southeastern U.S., an Albers Equal Area projection centered on the region of interest is a good choice.

-   `date_start` / `date_end` — `p0_date_start`, `p0_date_end`

    -   Start and end dates of the animation period, in `"YYYY-MM-DD"` format. Choose a start date a day or two before the storm's arrival to capture early conditions; extend the end date past landfall to show ongoing flood impacts.

-   `storm_info` / `p0_storm_info`

    -   A named block describing the storm. Must include:

        -   `storm_name`: name of the storm (all caps, e.g., `"HELENE"`)

        -   `storm_code`: storm identifier used by NOAA (e.g., `"al092024"`).

            -   The code follows the pattern `[basin][number][year]`, matching the best track zip filename (e.g., `al092024_best_track.zip`):

                | Part   | Meaning                                         | Example         |
                |--------|-------------------------------------------------|-----------------|
                | `al`   | Basin (`al` = Atlantic, `ep` = Eastern Pacific) | `al`            |
                | `09`   | Storm number that season                        | 9th named storm |
                | `2024` | Year                                            | 2024            |

                To find or validate a storm code, go to the [NHC data archive](https://www.nhc.noaa.gov/data/) → **Tropical Cyclone Reports** → **Atlantic, Caribbean, and Gulf** → select the year. The PDF report and SHP download links both use this same code.

        -   `storm_buffer`: distance (in meters) to buffer around the storm track for spatial filtering

        -   `shape_type`: method for spatial filtering (e.g., `"buffered_storm_track"`)

        -   `storm_best_track_url`: source of storm track shapefiles (e.g., from [NHC GIS archive](https://www.nhc.noaa.gov/gis/best_track/))

        -   `stn_event`: STN event ID for the rapid deployment gage network (browse all event IDs at the [STN Events API](https://stn.wim.usgs.gov/STNServices/Events.json))

-   **`p0_pcodes`**

    -   Vector of USGS parameter codes (e.g., `00060` for discharge and `00065` for gage height) used to filter streamgage data.

-   `p0_precip_start` / `p0_precip_end`

    -   Start and end timestamps (in `"YYYY-MM-DDTHH"` format) for retrieving gridded NOAA Stage 4 precipitation data. Must align with the desired animation timeframe.

-   `p0_nwis_start` / `p0_nwis_end`

    -   Start and end timestamps (in `"YYYY-MM-DDTHH:MMZ"` format, UTC) for pulling instantaneous streamgage values from the USGS Water Data API.

-   `timezone` / `p0_timezone`

    -   Display timezone for map labels (e.g., `"America/New_York"`). All pipeline processing is done in UTC; this value is applied only in the final visualization step.

-   `landfall_time` / `p0_landfall_time`

    -   A UTC timestamp indicating the expected time of landfall. Used to display a countdown label on frames leading up to landfall.

-   `pal_fs_blue` / `pal_fs_red` — `p0_viz_fs_config_pal_blue`, `p0_viz_fs_config_pal_red`

    -   Named color palettes for flood stage categories (`"Not flooded"`, `"Flood"`, `"Moderate"`, `"Major"`). The red palette follows NOAA National Water Prediction Service (NWPS) colors; the blue palette is used when `precip_grayscale` is `TRUE`.

-   `pal_percentile` / `p0_viz_percentile_config_pal`

    -   Seven-color scale for streamflow percentile categories, ordered from very low (`< 5th`) to very high (`≥ 95th`), with a neutral color for the normal range (`25th–75th`). Used to color-encode historical flow context for all gages in the bounding box.

-   `pal_precip_blue` / `pal_precip_grayscale` — `p0_viz_precip_config_pal_blue`, `p0_viz_precip_config_pal_grayscale`

    -   Color palettes for representing cumulative precipitation on the map, in blue (default) or grayscale (when `precip_grayscale` is `TRUE`).

-   `precip_grayscale` / `p0_precip_grayscale_var`

    -   Toggle to use grayscale precipitation styling. Set to `"TRUE"` or `"FALSE"`.

-   `flood_spike` / `p0_flood_spike_var`

    -   Toggle for how streamgage flow is visualized on the map:

        -   `"TRUE"`: Vertical spikes whose height encodes streamflow percentile (≥ 75th percentile triggers a spike). Gray spikes are shown for gages without NOAA flood stage thresholds; colored spikes for currently-flooded gages. Flooded gage points are drawn on top.

        -   `"FALSE"`: Sized circles for flooded gages, where point size encodes streamflow percentile rank.

-   `viz_config` / `p0_viz_config_df`

    -   A block of styling and layout variables for the plot, including:

        -   Output figure dimensions (`width`, `height`, `dpi`)

        -   Colors for state outlines, background, ocean, streamgages, and storm path

        -   Font family and text sizes (`load_font`, `font_size_title`, `font_size`, `leg_font_size`)

        -   Plot margins and canvas offsets (`plot_margin`, `plot_shift_x`, `plot_shift_y`, `plot_width`, `plot_height`)

-   In cases where the storm occurs in regions such as Puerto Rico, Alaska, or Hawaii, users will need to adjust `p1_conus_bbox_crop_sf`, which downloads [tigris](https://github.com/walkerke/tigris) state borders and crops to the bbox. City label selection is config-driven via the `cities_*` keys in the storm YAML — adjust `cities_n`, `cities_track_buffer`, `cities_storm_types`, and `cities_override` as needed for the region.

## Repository organization

-   `config/` directory containing per-storm configuration YAML files.
    -   `_template.yml` template for configuring a new storm — copy and fill in values.
    -   `helene.yml` configuration for Hurricane Helene (2024).
-   `1_fetch/` directory containing files related to fetching data.
    -   `src/` directory containing source code to define functions.
        -   `clip_flood_stage_gages.R` R script that filters NOAA flood stage gages to the event bbox.
        -   `fetch_rapid_deployment_data.R` R script that fetches Rapid-Deployment Gage sites from STN as an `sf` object.
        -   `fetch_site_stats.R` R script that fetches day-of-year streamflow percentile thresholds from the USGS statistics API for all active gages in the bbox; filters to sites with ≥ 10 years of record; writes parquet.
        -   `get_major_cities.R` R script that selects major cities for map labeling from `maps::us.cities`, filtered to a buffer around the storm track (HU/TS phase only) and ranked by population with greedy min-distance deduplication.
        -   `fetch_uv_peaks_data.R` R script defining downloads of USGS instantaneous (UV) data and historical peak flows via the USGS OGC Water Data API; writes parquet.
        -   `get_precip.py` Python script to pull NOAA Stage 4 precipitation and export GeoTIFF rasters.
        -   `storm_shape_functions.R` R script defining functions to download and process NOAA NHC storm track shapefiles.
    -   `out/` directory containing output files (once code is run).
        -   `gage_peak_data.parquet` parquet file of NWIS historical peak flows.
        -   `gage_uv_data.parquet` parquet file of instantaneous USGS streamgage data.
        -   `site_stats.parquet` parquet file of day-of-year percentile thresholds (p05–p95) for all bbox gages with ≥ 30 years of record.
        -   `flood_stage_gages.csv` NOAA flood stage threshold data downloaded for the event bbox.
        -   `[storm_code]/` shapefiles associated with hurricane path, points, radii, and wind swath.
        -   `[p0_precip_start]_to_[p0_precip_end].tif` precipitation raster files for given date and hours.
-   `2_process/` directory containing files related to processing data.
    -   `src/` directory containing source code to define functions.
        -   `process_hourly_max_uv.R` R script to extract hourly maximum gage height and discharge from instantaneous values.
        -   `process_precip.R` R script to read Stage 4 precipitation rasters, reproject/crop to the bounding box, reshape to long format, and compute cumulative precipitation.
        -   `process_states.R` R script to build state boundary layers; derive inner shared borders and the outer outline as `sf` geometries.
-   `3_visualize/` directory containing files related to visualizing data.
    -   `src/` directory containing source code to define functions.
        -   `mapping_utils.R` R script containing the main frame-rendering function (`hurricane_flood_stage_frames()`), which produces one PNG per timestep in either spike or point mode.
        -   `title_end_frame.R` R script that defines the `title_frame()` and `end_frame()` functions for the opening and closing animation frames.
        -   `video_utils.R` R script that defines `encode_flood_mp4()`, which assembles title, flood, crossfade, and end frames into a final MP4 using `av::av_encode_video()`.
        -   `builders/` directory containing focused builder functions called by `mapping_utils.R`:
            -   `build_flood_bar.R` builds the flood stage bar chart inset.
            -   `build_flood_layer.R` builds the spike or point gage layer on the map.
            -   `build_icon_legends.R` builds the dot and spike icon legends.
            -   `build_gage_legends.R` builds the rapid deployment and decommissioned gage icon legends.
            -   `build_precip_legend.R` builds the precipitation color scale legend.
            -   `build_progress_bar.R` builds the time progress bar.
            -   `compose_frame.R` assembles all layers into the final cowplot canvas for each frame.
    -   `out/` directory containing animation frames and MP4s (once code is run).
        -   `[storm_name]_flood_stage_spike_animation.mp4` compiled spike animation.
        -   `[storm_name]_flood_stage_point_animation.mp4` compiled point animation.
        -   `flood_stage_[storm_name]_spike_frames/`
            -   `frame_[datehour].png` PNG frames of the spike map over time.
            -   `frame_00000000000.png` title frame.
            -   `frame_99999999999.png` end frame.
        -   `flood_stage_[storm_name]_point_frames/`
            -   `frame_[datehour].png` PNG frames of the point map over time.
            -   `frame_00000000000.png` title frame.
            -   `frame_99999999999.png` end frame.
    -   `in/`
        -   `usgs_logo_black.png` PNG of black USGS logo.
        -   `hurricane_symbol.png` PNG of hurricane icon used on the storm track.
        -   `custom_flood_stage_spike_leg.png` custom legend image for the spike animation describing spike height encoding.
        -   `custom_flood_stage_point_leg.png` custom legend image for the point animation describing point size encoding.
        -   `bullseye.png` target/bullseye icon for rapid deployment gages on the map.
-   `.gitignore` file specifying which files should not be tracked in git.
-   `_targets.R` a [target script file](https://books.ropensci.org/targets/walkthrough.html#target-script-file) used to define the [targets pipeline](https://docs.ropensci.org/targets/index.html).
-   `0_config.R` R script that reads the active storm YAML and defines all `p0_` configuration targets.
-   `1_fetch.R` R script defining the fetch phase of the data pipeline.
-   `2_process.R` R script defining the process phase of the pipeline.
-   `3_visualize.R` R script defining the visualize phase of the pipeline.
-   `code.json` metadata file compliant with the [USGS software template](https://www.usgs.gov/products/software/software-management/distribution-usgs-code).
-   `CODE_OF_CONDUCT.md` information on the contribution code of conduct.
-   `CONTRIBUTING.md` information on how to contribute to this repository.
-   `DISCLAIMER.md` Provisional USGS disclaimer; should be removed upon approval.
-   `LICENSE.md` license information for code.
-   `README.md` general information about the project.
-   `USGS_ID_black.png` USGS logo used at the top of this README.
-   `hurricane-revamp.Rproj` an R project file.

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

USGS Short-Term Network. U.S. Geological Survey. *STN Events API*. Accessed via: <https://stn.wim.usgs.gov/STNServices/Events.json>

DeCicco L, Hirsch R, Lorenz D, Read J, Walker J, Platt L, Watkins D, Blodgett D, Johnson M, Krall A, Stanish L, Zemmels J, Hinman E, Mahoney M (2025). *dataRetrieval: R packages for discovering and retrieving water data available from U.S. federal hydrologic web services*. [doi:10.5066/P9X4L3GE](https://doi.org/10.5066/P9X4L3GE).
