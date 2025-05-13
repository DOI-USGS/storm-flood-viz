reticulate::use_condaenv("hurricane-precip", required = TRUE)
reticulate::source_python("1_fetch/src/generate_hyswap_percentiles.py")

# source("1_fetch/src/fetch_utils.R")
source("1_fetch/src/get_precip_wrapper.R")
source("1_fetch/src/storm_shape_functions.R")
source("1_fetch/src/clip_flood_stage_gages.R")
source("1_fetch/src/fetch_uv_peaks_data.R")

# Input parameters (place in config file?)
pcodes <- c("00060", "00065")
storm_name <- 'Helene' # not currently used
shape_type <- "buffer_track"
buffer <- 250000
storm_code <- 'al092024'
date_start <- '2024-09-24'
date_end <- '2024-10-01'
proj <- "EPSG:3086"
bbox <- sf::st_bbox(c(xmin = -92, xmax = -80, ymin = 23, ymax = 45))

flood_stage_url <-"https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv"

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
             format = 'file'),
  # Convert projection if needed (from KVL's rmd)
  tar_target(
    p1_bbox_proj,
    {
      if (!(proj == "EPSG:4269")) {
        sf::st_as_sfc(bbox) |> 
          st_as_sf(crs = "EPSG:4269") |>
          sf::st_transform(crs = proj) |>
          sf::st_bbox()
      }else{
        bbox
      }
    }
  ),
  # Get storm shape file from NOAA, storm track or cone of uncertainty
  tar_target(
    p1_storm_shape_file,
    get_storm_shape(
      storm_code = storm_code,
      shape_type = shape_type,
      out_folder = "1_fetch/out"
    ),
    format = "file"
  ),
  # Read in storm shape to R and add a buffer if needed; clip to bbox
  tar_target(
    p1_storm_shape,
    read_in_shapefile(
      shape_name = p1_storm_shape_file,
      shape_type = shape_type,
      buffer = buffer,
      proj = proj, 
      bbox = p1_bbox_proj
    )
  ),
  # Download flood stage csv from NOAA
  tar_target(
    p1_flood_stage_file,
    {
      out_path <- "1_fetch/out/flood_stage_gages.csv"
      download.file(flood_stage_url, out_path)
      return(out_path)
      
    },
    format = "file"
  ),
  # Read in flood stage df and perform some tidying
  tar_target(
    p1_usgs_flood_stage_gages,
    clip_flood_stage_gages(
      flood_stage_file = p1_flood_stage_file,
      storm_shape = p1_storm_shape
    )
  ),
  # Get sites chunked up for uv data download
  tar_target(
    p1_site_id_chunks,
    chunk_up_sites(unique(p1_usgs_flood_stage_gages$site_no), n_sites_per_list = 200)
  ),
  # Download uv data to parquet
  tar_target(
    p1_uv_data_pqt,
    fetch_uv_data(
      outfile_path = "1_fetch/out/gage_uv_data.parquet",
      sites_list = p1_site_id_chunks,
      pcodes = c("00060", "00065"),
      startDate = "2024-09-24",
      endDate = "2024-10-01"
    ),
    format = "file"
  ),
  # Download peaks data to parquet
  tar_target(
    p1_peak_data_pqt,
    fetch_peak_data(
      outfile_path = "1_fetch/out/gage_peak_data.parquet",
      sites_list = p1_site_id_chunks
    ),
    format = "file"
  ),
  # Load in uv data df
  tar_target(
    p1_uv_data_df,
    arrow::read_parquet(p1_uv_data_pqt)
  ),
  # Make list of sites to run through the percentiles calculations
  tar_target(
    p1_uv_sites,
    unique(p1_uv_data_df$site_no)
  ),
  # Branch over site ids to generate percentiles and place in single df
  # of uv data
  tar_target(
    p1_uv_data_percentiles_df,
    calculate_uv_percentiles_from_dv(p1_uv_sites, p1_uv_data_df, pcode = "00060"),
    pattern = map(p1_uv_sites)
  ),
  # Read in peak data and grab max peak value per site, with ties
  # broken using the latest date in the dataset - makes more sense to compare
  # to the most recent peak than an earlier peak that was tied more recently.
  tar_target(
    p1_peak_data_max_df,
    arrow::read_parquet(p1_peak_data_pqt) |>
      group_by(site_no) |>
      slice_max(peak_va) |>
      filter(peak_dt == max(peak_dt)) |>
      ungroup()
  ),
  # Merge together uv percentiles with flood stages and peak data
  tar_target(
    p1_flow_height_complete_df,
    {
      out <- p1_uv_data_percentiles_df |>
        left_join(p1_usgs_flood_stage_gages, by = "site_no") |>
        left_join(p1_peak_data_max_df, by = "site_no")
    }
  )
)
