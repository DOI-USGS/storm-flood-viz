# Refactor guidance
Goals: 
- Improve pipeline runtime
- Easy per-storm configuration
- Leverage USGS tools - dataretrieval and hyswap for working with USGS water data 
- 

Do not:
- change the overall phase structure of the repository
- change the design of the visual output without being told
- 

## code style
- use tidyverse where it's useful
- use |> pipe over %>%
- use sf for spatial data
- use terra for raster data
- document functions using roxygen2 format 
- chunk up refactor steps into small, tangible PRs for review 
- provide small tests to check code changesd with and ensure consistent outputs 
- use R primarily, with Python as needed 
- Each refactor priority gets its own branch off main and its own task file in TASKS/.
- Use compact formatting, do not use extra spacing. 

## refactor priorities
1. consolidate viz and storm configs into config files for each change
1. Speed up the percentiles calculation. We want a variable percentile that includes gages of at least a 20 year period of record available.
1. Separate fetch, process, and visualize phases in a clear strcuture, so that when the visual is regenerated for new storms it is easy to update and customize to the event.
1. Decompose 3_visualize/src/mapping_utils.R (956 lines, single function) into focused builders.
1. Generalize p1_major_cities_sf (1_fetch.R:120-143) so it isn't hard-coded to SE US cities

## success
Refactor efforts are successful if:
1. the pipeline runs faster without error
1. statistical calculations are robust and adhere to USGS procedures outlined in the hyswap documentation: https://doi-usgs.github.io/hyswap/ and/or leverages statstical computations provided by the USGS stats API, accessed through dataretrieval: https://doi-usgs.github.io/dataRetrieval/reference/read_waterdata_stats.html 
1. visuals are easy to generate and modify during future events, with important variables set in a global config
1. it produces a high quality animation that is optimized for web viewing
1. it incoporates both NWS flood stages and USGS stramflow percentiles