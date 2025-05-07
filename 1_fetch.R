source("1_fetch/src/storm_shape_functions.R")
source("1_fetch/src/clip_flood_stage_gages.R")

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
  tar_target(
    storm_shape_file,
    get_storm_shape(
      storm_code = storm_code,
      shape_type = shape_type,
      out_folder = "1_fetch/out"
    )
    
  ),
  tar_target(
    storm_shape,
    read_in_shapefile(
      shape_name = storm_shape_file,
      shape_type = shape_type,
      buffer = buffer,
      bbox = bbox_proj
    )
  ),
  tar_target(
    flood_stage_file,
    {
      out_path <- "1_fetch/out/flood_stage_gages.csv"
      download.file(flood_stage_url, out_path)
      return(out_path)
      
    }
  ),
  tar_target(
    usgs_flood_stage_gages,
    clip_flood_stage_gages(
      flood_stage_file = flood_stage_file,
      storm_shape = storm_shape
    )
  ),
  tar_target(
    uv_data_df,
    
  )
)