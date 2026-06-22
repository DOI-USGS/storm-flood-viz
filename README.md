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

This repository is organized as a data pipeline built with the [`targets`](https://github.com/ropensci/targets) package, which tracks each step's status (up-to-date vs. out-of-date) and rebuilds only what is needed. After completing the setup steps below (R packages, Python environment, fonts, and API keys), run [`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html) in the console to build the entire pipeline.

If packages are missing you will see an error like `Error : could not find packages terra, ggimage in library paths`. Install everything the pipeline needs up front, then re-run `tar_make()`:

```r
install.packages(c(
  "tidyverse", "sf", "reticulate", "janitor", "sbtools", "tigris",
  "tidycensus", "cowplot", "rmapshaper", "terra", "raster", "tidyterra",
  "rvest", "httr", "fs", "glue", "dataRetrieval", "arrow", "ggimage",
  "ggtext", "ggforce", "ragg", "av", "yaml"
))
```

For more information on `targets`, see the [getting-started walkthrough](https://books.ropensci.org/targets/walkthrough.html) and the [Introduction to targets](https://carpentries-incubator.github.io/targets-workshop/) training.

## Python environment setup

The pipeline uses Python only for precipitation data retrieval (`get_precip.py`). The following Python packages are required: `xarray`, `fsspec`, `numpy`, `pandas`, `scipy`, `gdal`.

The pipeline resolves the Python environment in the following order:

1.  If the environment variable `RETICULATE_PYTHON` is set, it will use that Python executable. Set this in your `.Renviron` file:

```         
RETICULATE_PYTHON=/path/to/your/python
```

You can find the correct path by activating your Python environment in the terminal and running `which python`.

2.  If `RETICULATE_PYTHON` is not set, the pipeline falls back to a conda environment named `hurricane-precip`. Ensure this environment exists and has the required dependencies installed.

## Font setup

Map frames are rendered using `ragg` as the graphics device, which resolves fonts through `systemfonts` from your system's installed font files. The pipeline uses **Source Sans 3** (configured via `load_font` in `config/helene.yml`). To set it up:

1.  Download the Source Sans 3 static `.ttf` files from [Google Fonts](https://fonts.google.com/specimen/Source+Sans+3) (click "Download family", then use the files in the `static/` folder).
2.  Install the fonts on your system (double-click each `.ttf` on macOS/Windows, or place them in `~/.local/share/fonts/` on Linux and run `fc-cache -f`).
3.  In RStudio ≥ 1.4, go to **Tools \> Global Options \> General \> Graphics** and set the Backend to **AGG** so the IDE preview also uses `ragg`.

If you change `load_font` to a different font family, install that font on your system using the same steps above.

## API keys

The pipeline requires two API keys. Set both in your `.Renviron` file (run `usethis::edit_r_environ()` to open it, add the lines below, then restart R). The pipeline will fail at the fetch step without them.

-   **Census API key** — required by `tidycensus`, which `fetch_major_cities()` uses to pull American Community Survey population for city labeling. Request a free key at <https://api.census.gov/data/key_signup.html>, then add:

    ```         
    CENSUS_API_KEY=your_key_here
    ```

-   **USGS Water Data API key** — required by the USGS Water Data APIs queried through `dataRetrieval` (in `fetch_uv_peaks_data()` and `fetch_site_stats()`). Request a token at <https://api.waterdata.usgs.gov/signup/>, then add:

    ```         
    API_USGS_PAT=your_token_here
    ```

    See the [dataRetrieval API tokens guide](https://doi-usgs.github.io/dataRetrieval/articles/read_waterdata_functions.html#api-tokens) for more information.

## Code runtime

The full pipeline run-time varies with the configured date range (`date_start` / `date_end`) and the size of the `bbox`, i.e. a larger area and longer window mean more precipitation rasters and gage queries. A first run, which downloads all source data, can take a few hours on a high-end laptop (e.g. Apple M1 Max); after that, `tar_make()` only rebuilds the targets affected by your changes.

## Configuring a new storm

Per-storm and visualization settings live in `config/<storm>.yml`, **not** in R code — `0_config.R` reads that file and exposes each value as a `p0_*` target. To set up a new storm: copy `config/_template.yml` to `config/<storm>.yml`, fill in the keys described below, then point `p0_storm_cfg_file` in `0_config.R` at your new file. Many downstream values (precipitation/NWIS request timestamps, the precip bounding box) are **derived automatically** from these keys and do not need to be set.

**Storm metadata**

-   `date_start` / `date_end` — animation period in `"YYYY-MM-DD"`. Start a day or two before arrival to capture early rainfall and streamflow; end past landfall to show ongoing impacts.
-   `landfall_time` — UTC `"YYYY-MM-DD HH:MM:SS"` timestamp of landfall, used to drive the countdown label. From NHC forecasts/summaries.
-   `storm_info`:
    -   `storm_name` — name in all caps (e.g. `"HELENE"`).
    -   `storm_type_label` — label shown in the title (e.g. `"Hurricane"`, `"Typhoon"`).
    -   `storm_code` — NOAA storm identifier (e.g. `"al092024"`).
    -   `storm_buffer` — distance (meters) to buffer around the storm track for spatial filtering.
    -   `shape_type` — spatial-filter method (e.g. `"buffered_storm_track"`).
    -   `storm_best_track_url` — source of storm track shapefiles ([NHC GIS archive](https://www.nhc.noaa.gov/gis/best_track/)).
    -   `stn_event` — STN rapid-deployment event id (e.g. `346` for Helene; look up at the [STN Data Portal](https://stn.wim.usgs.gov/STNDataPortal/#)).

**Spatial**

-   `bbox` — area of interest as `xmin` / `xmax` / `ymin` / `ymax` in NAD83 (`EPSG:4269`) decimal degrees. Sets the extent for precipitation, streamgage, and storm track data.
-   `proj` — projection (PROJ string or EPSG code) appropriate for the region. Helene uses an Albers Equal Area string centered on the southeastern U.S.

**Display**

-   `timezone` — local timezone for time labels, given as an [IANA tz database name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) (e.g. `"America/New_York"`, `"America/Chicago"`, `"America/Puerto_Rico"`). All processing is done in UTC; this only affects display.
-   `timezone_abv` — abbreviation shown in the title (e.g. `"ET"`).

**City labels**

-   `cities_n` — number of most-populous cities to auto-label within the bbox (`fetch_major_cities()`).
-   `cities` *(optional)* — list of `name` / `state` pairs to force-include regardless of population or bbox.

**Viz toggles**

-   `precip_grayscale` — `"TRUE"` for grayscale precip, `"FALSE"` for colorized.
-   `flood_spike` — `"TRUE"` for height-scaled spikes, `"FALSE"` for size-scaled circles.

**Color palettes** — `pal_fs_blue` / `pal_fs_red` (flood-stage categories, blue and NWPS-red themes), `pal_percentile` (streamflow percentile scale), and `pal_precip_blue` / `pal_precip_grayscale` (precipitation).

**`viz_config`** — styling and layout constants for the composited frame. These drive the visual composition and will likely need re-tuning when the bbox area changes, so each is listed below, grouped by purpose:

-   *Output & canvas:*
    -   `width` / `height` — frame size, inches.
    -   `dpi` — resolution.
    -   `canvas_width` / `canvas_height` — full 16:9 canvas size.
    -   `plot_margin` — map margin as a fraction of the canvas.
    -   `plot_shift_x` / `plot_shift_y` — map position within the canvas.
    -   `plot_width` / `plot_height` — map scale within the canvas.
    -   `logo_width` — USGS logo width.
    -   `x_axis_buffer` — horizontal padding for the flood-status barplot.
-   *Fonts & text sizes:*
    -   `load_font` — font family.
    -   `font_size_title` / `font_size` / `leg_font_size` — base title / body / legend sizes.
    -   `storm_title_size` / `canvas_subtitle_size` / `canvas_legend_size` — canvas-level title / subtitle / legend sizes.
    -   `canvas_line_height` — line spacing.
    -   `bar_text_size` — flood-status barplot labels.
-   *Colors:*
    -   `bg_col` / `ocean_col` — background and ocean fill.
    -   `state_outline_col` / `state_inner_borders_col` / `state_outer_lines_col` — state borders.
    -   `storm_path_col` — storm track.
    -   `streamgage_col` — gages.
    -   `major_cities_col` / `major_cities_text_col` — city markers and labels.
    -   `x_mark` — decommissioned-gage X.
    -   `legend_icon_col` — legend icons.
    -   `progress_bar_bg_col` / `progress_bar_col` — progress-bar track and fill.
-   *Line weights:*
    -   `state_inner_border_lw` / `state_outer_border_lw` — state borders.
    -   `storm_track_lw` — storm track line.
-   *Markers & symbols:*
    -   `non_flooded_point_size` / `flooded_point_size` — gage point sizes.
    -   `flood_point_alpha` — gage point opacity.
    -   `storm_track_dot_size` — storm track dots.
    -   `hurricane_symbol_size` — hurricane icon.
    -   `rdg_icon_size` — rapid-deployment gage icon on the map.
    -   `city_symbol_size` — city diamond size.
    -   `city_text_size` — city label text size.
    -   `city_label_nudge_y` — city label vertical offset (projected units).
-   *Precipitation:*
    -   `precip_raster_alpha` / `precip_col_alpha` — raster and legend opacity.
    -   `precip_legend_key_width_cm` / `precip_legend_key_height_cm` — colorbar key size.
-   *Legend keys & icons:*
    -   `flood_legend_key_height_cm` — flood legend key height.
    -   `dot_legend_size` — flood dot legend marker.
    -   `rdg_legend_icon_size` — RDG legend icon.
    -   `decom_legend_size` — decommissioned-gage legend marker.
-   *Ocean label:*
    -   `ocean_label_text` — label text.
    -   `ocean_label_x` — x position.
    -   `ocean_label_y_offset` — y offset.
    -   `ocean_label_size` — font size.
-   *Progress & status bar:*
    -   `progress_x` / `progress_y` — position.
    -   `progress_w` / `progress_h` — size.
    -   `bar_width` — flood-status bar thickness.
-   *Flood-spike geometry (projected units):*
    -   `peak_height` — max spike height.
    -   `y_baseheight` — spike base offset above the gage.

**`anchors`** — `legend_box` sets the position of the entire legend stack on the canvas; move it to reposition the legend panel for a new storm.

> **Regional note:** For storms outside the contiguous U.S. (Puerto Rico, Alaska, Hawaii, etc.), you may also need to adjust `p1_conus_bbox_crop_sf`, which downloads [tigris](https://github.com/walkerke/tigris) state borders and crops to the bbox.

## Repository organization

The pipeline runs in four phases. Each phase has a top-level script (`N_*.R`) that defines its `targets`, and a `N_*/src/` directory holding the functions those targets call.

**Top-level pipeline scripts**

-   `_targets.R` defines the [targets pipeline](https://docs.ropensci.org/targets/index.html) and the global package/options setup.
-   `0_config.R` phase 0 ("config") — loads the per-storm YAML and exposes each setting as a `p0_*` target.
-   `1_fetch.R` phase 1 ("fetch") — data-download targets.
-   `2_process.R` phase 2 ("process") — data-processing targets.
-   `3_visualize.R` phase 3 ("visualize") — frame-rendering and animation targets.

**`config/`** — per-storm and visualization configuration.

-   `helene.yml` configuration for Hurricane Helene (the default storm): storm metadata, bbox, projection, palettes, city labels, and all `viz_config` styling constants.
-   `_template.yml` annotated template to copy when configuring a new storm.

**`1_fetch/src/`** — data-fetch functions.

-   `get_precip.py` pulls NOAA Stage 4 precipitation and exports GeoTIFF rasters.
-   `storm_shape_functions.R` downloads storm track / cone shapefiles from NOAA NHC.
-   `clip_flood_stage_gages.R` reads the NOAA flood-stage gage CSV and filters it to the bbox.
-   `fetch_rapid_deployment_data.R` fetches STN Rapid-Deployment Gage (RDG) sites for the event as `sf`.
-   `fetch_uv_peaks_data.R` finds active NWIS gages in the bbox and downloads instantaneous (UV) and peak data to parquet.
-   `fetch_site_stats.R` fetches day-of-year streamflow percentile thresholds (p05–p95) from the USGS waterdata statistics API.
-   `fetch_major_cities.R` selects major cities to label by ACS population within the bbox (via `tidycensus`), with optional per-storm overrides.

> **Percentile threshold note:** Sites are filtered to a minimum of **10 years** of discharge record (parameter `min_por_years` in `fetch_site_stats()`). The original spec called for 20 years. Testing against the Helene site list showed ≥20 yr qualifies 4,158 sites while ≥10 yr qualifies 4,937 — a gain of 779 sites (+19%), with the added sites having PORs clustered between 10–20 years. Sites below the threshold receive `percentile = NA` and appear as gray dots without a percentile spike. The threshold is configurable if 20 years is preferred for future events.

**`2_process/src/`** — data-processing functions.

-   `process_precip.R` reprojects/crops Stage 4 rasters to the bbox and reshapes to long format with hourly/cumulative precipitation.
-   `process_hourly_max_uv.R` extracts hourly maximum gage height and discharge, joins parameters, and adds percentiles.
-   `process_states.R` builds state boundary layers and derives the inner shared borders and outer outline as `sf`.
-   `process_flood_groups.R` partitions each timestep's gages into the render groups the flood layer draws (non-flooded, decommissioned, flooded, etc.).

**`3_visualize/src/builders/`** — modular frame builders. `compose_frame.R` orchestrates the rest to assemble a single animation frame; each `build_*` file returns one layer or panel.

-   `compose_frame.R` assembles one flood-stage frame from the layers and panels below.
-   `build_basemap.R` state-border basemap.
-   `build_precip_layer.R` / `build_precip_legend_panel.R` precipitation raster and its colorbar legend.
-   `build_flood_layer.R` flood gage spikes/points.
-   `build_flood_status_bar.R` / `build_flood_status_bar_panel.R` flood-status count barplot and its canvas placement.
-   `build_flood_explainer_panel.R` flood-stage explainer text panel.
-   `build_cities_layer.R` city markers and labels.
-   `build_storm_track.R` storm track line and hurricane symbol.
-   `build_rdg_layer.R` / `build_gage_icons_panel.R` rapid-deployment gage markers and their legend panel.
-   `build_legends.R` assembles legend grobs and icon plots.
-   `build_title_block.R` title text (storm name, datetime, landfall countdown).
-   `build_progress_bar.R` timeline progress bar.
-   `build_title_end_frame.R` builds the title and end frames.
-   `build_video_mp4.R` encodes the rendered frames to MP4.

**`3_visualize/in/`** — static image assets.

-   `usgs_logo_black.png` USGS logo.
-   `hurricane_symbol.png` hurricane icon for the storm center.
-   `bullseye.png` target icon for rapid-deployment gages.
-   `custom_flood_stage_spike_leg_percentile.png` custom spike-legend image (height = duration above flood stage).
-   `custom_flood_stage_point_leg_percentile.png` custom point-legend image (size = duration above flood stage).

**Outputs** (created when the pipeline runs)

-   `1_fetch/out/` downloaded data: precipitation rasters (`*.tif`), `storm_shape_[storm_code]` shapefiles, and `gage_uv_data.parquet`, `gage_peak_data.parquet`, `site_stats.parquet`.
-   `3_visualize/out/` per-frame PNGs in `flood_stage_[storm]_[spike|point]_frames/` (including title frame `frame_00000000000.png` and end frame `frame_99999999999.png`) and the final `[storm]_flood_stage_[spike|point]_animation.mp4`.

**Project files**

-   `.gitignore`, `code.json` ([USGS metadata template](https://www.usgs.gov/products/software/software-management/distribution-usgs-code)), `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `DISCLAIMER.md`, `LICENSE.md`, `README.md`, `USGS_ID_black.png`, and the `hurricane-revamp.Rproj` [RStudio project file](https://r4ds.hadley.nz/workflow-scripts#projects).

## Expertise required

This code assumes the user is familiar with R and familiar with the [targets](https://books.ropensci.org/targets/) package (or willing to become acquainted with it). No subject matter expertise is required to run the code.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on the process for submitting pull requests to us. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details on adhering by the [USGS Code of Scientific Conduct](https://www2.usgs.gov/fsp/fsp_code_of_scientific_conduct.asp).

## Built With

-   [R](https://www.r-project.org/about.html) - data retrieval, processing, and visualization
-   [Python](https://www.python.org/) - precipitation data retrieval (`get_precip.py`), called from R via [reticulate](https://rstudio.github.io/reticulate/)

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
-   Portions of this software were developed with the assistance of [Claude Code](https://www.claude.com/product/claude-code), Anthropic's AI coding tool. All AI-assisted contributions were author-reviewed, and additional merge peer review was conducted to ensure accuracy.

# References

National Oceanic and Atmospheric Administration. NWPS all gauges report [Data set]. NOAA National Water Prediction Service. Retrieved June 23, 2025, from <https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv>

National Hurricane Center. Best track data (HURDAT2) [Data set]. National Oceanic and Atmospheric Administration. Retrieved June 23, 2025, from <https://www.nhc.noaa.gov/gis/best_track/>

USGS Short-Term Network Portal. U.S. Geological Survey. *Short-Term Network Data Portal*. Accessed via: <https://stn.wim.usgs.gov/STNDataPortal/>

U.S. Census Bureau. American Community Survey 5-year estimates [Data set]. Accessed via the `tidycensus` R package and the U.S. Census Bureau Data API: <https://www.census.gov/data/developers/data-sets/acs-5year.html>

DeCicco L, Hirsch R, Lorenz D, Read J, Walker J, Platt L, Watkins D, Blodgett D, Johnson M, Krall A, Stanish L, Zemmels J, Hinman E, Mahoney M (2025). *dataRetrieval: R packages for discovering and retrieving water data available from U.S. federal hydrologic web services*. [doi:10.5066/P9X4L3GE](https://doi.org/10.5066/P9X4L3GE).
