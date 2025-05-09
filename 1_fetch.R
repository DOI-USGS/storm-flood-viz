reticulate::use_condaenv("hurricane-precip", required = TRUE)
reticulate::source_python("1_fetch/src/generate_hyswap_percentiles.py")


source("1_fetch/src/storm_shape_functions.R")
source("1_fetch/src/clip_flood_stage_gages.R")
source("1_fetch/src/fetch_uv_peaks_data.R")

# Input parameters (place in config file?)
pcodes <- c("00060", "00065")
storm_name <- 'Helene'
shape_type <- "buffer_track"
buffer <- 250000
storm_code <- 'al092024'
date_start <- '2024-09-24'
date_end <- '2024-10-01'
proj <- "EPSG:3086"
bbox <- sf::st_bbox(c(xmin = -92, xmax = -80, ymin = 23, ymax = 45))

flood_stage_url <-"https://water.noaa.gov/resources/downloads/reports/nwps_all_gauges_report.csv"

p1_targets <- list(
  
  # Convert projection if needed (from KVL's rmd)
  tar_target(
    bbox_proj,
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
    storm_shape_file,
    get_storm_shape(
      storm_code = storm_code,
      shape_type = shape_type,
      out_folder = "1_fetch/out"
    ),
    format = "file"
  ),
  # Read in storm shape to R and add a buffer if needed; clip to bbox
  tar_target(
    storm_shape,
    read_in_shapefile(
      shape_name = storm_shape_file,
      shape_type = shape_type,
      buffer = buffer,
      bbox = bbox_proj
    )
  ),
  # Download flood stage csv from NOAA
  tar_target(
    flood_stage_file,
    {
      out_path <- "1_fetch/out/flood_stage_gages.csv"
      download.file(flood_stage_url, out_path)
      return(out_path)
      
    },
    format = "file"
  ),
  # Read in flood stage df and perform some tidying
  tar_target(
    usgs_flood_stage_gages,
    clip_flood_stage_gages(
      flood_stage_file = flood_stage_file,
      storm_shape = storm_shape
    )
  ),
  # Get sites chunked up for uv data download
  tar_target(
    site_id_chunks,
    chunk_up_sites(unique(usgs_flood_stage_gages$site_no), n_sites_per_list = 200)
  ),
  # Download uv data to parquet
  tar_target(
    uv_data_pqt,
    fetch_uv_data(
      outfile_path = "1_fetch/out/gage_uv_data.parquet",
      sites_list = site_id_chunks,
      pcodes = c("00060", "00065"),
      startDate = "2024-09-24",
      endDate = "2024-10-01"
    ),
    format = "file"
  ),
  # Download peaks data to parquet
  tar_target(
    peak_data_pqt,
    fetch_peak_data(
      outfile_path = "1_fetch/out/gage_peak_data.parquet",
      sites_list = site_id_chunks
    ),
    format = "file"
  ),
  # Load in uv data df
  tar_target(
    uv_data_df,
    arrow::read_parquet(uv_data_pqt)
  ),
  tar_target(
    uv_sites,
    unique(uv_data_df$site_no)[1:5]
  ),
  tar_target(
    uv_data_percentiles_df,
    calculate_uv_percentiles_from_dv(uv_sites, uv_data_df, pcode = "00060"),
    pattern = map(uv_sites)
  )
  
)