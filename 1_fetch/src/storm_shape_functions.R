#' Get storm shape from NOAA's website
#'
#' @param storm_code An alphanumeric code from NOAA's website used to identify
#' particular storms.
#' @param shape_type Must be either "cone_of_uncertainty", "buffered_storm_track" or "storm_track_files".
#' @param out_folder Folder to output shape folder containing shape files.
#'
#' @return Returns the file path of the downloaded shape file.
get_storm_shape <- function(
    storm_code,
    shape_type = c("cone_of_uncertainty", "buffered_storm_track", "storm_track_files"),
    out_folder){
  
  shape_type <- match.arg(shape_type)
  
  unzip_dir <- sprintf("%s/storm_shape_%s", out_folder, storm_code)
  file_name <- paste0(unzip_dir, ".zip")
  
  if (!dir.exists(unzip_dir)) dir.create(unzip_dir, recursive = TRUE)
  
  if (shape_type == "cone_of_uncertainty") {
    
    file_url <- sprintf(
      "https://www.nhc.noaa.gov/gis/forecast/archive/%s_5day_001.zip",
      storm_code
    )
    shp_name <- sprintf("%s/%s-001_5day_pgn.shp", unzip_dir, storm_code)
  } else {
    
    file_url <- sprintf(
      "http://www.nhc.noaa.gov/gis/best_track/%s_best_track.zip",
      storm_code
    )
    
    if (shape_type == "storm_track_files") {
      
      # Download and return all unzipped file paths
      download.file(file_url, file_name)
      unzipped_files <- unzip(file_name, exdir = unzip_dir)
      file.remove(file_name)
      return(unzipped_files)
      
    } else {
      # buffered_storm_track (default to _lin shapefile)
      shp_name <- sprintf("%s/%s_lin.shp", unzip_dir, stringr::str_to_upper(storm_code))
    }
  }
  
  # Download and unzip a single .shp
  download.file(file_url, file_name)
  unzip(file_name, exdir = unzip_dir)
  file.remove(file_name)
  
  return(shp_name)
}

#' Read in the shape file, and if it's a "buffered_storm_track", apply a buffer to the
#' storm track.
#'
#' @param shape_name String representing file path to storm .shp file.
#' @param shape_type Must be either "cone_of_uncertainty" or "buffered_storm_track".
#' @param buffer Numeric. The buffer around the storm track to be applied, in
#' meters. The buffer previously applied was 250,000 m (250 km). Note that this
#' value is not used with "cone_of_uncertainty" shapes.
#' @param proj String describing projection to be applied to the shape
#' @param bbox An sf::st_bbox() object containing the xmin, xmax, ymin, and ymax
#' values describing the box over which the shape should be clipped.
#'
#' @return An sf object of the clipped, projected, and (if applicable) buffered
#' storm shape.

read_in_shapefile <- function(
    shape_name,
    shape_type = c("cone_of_uncertainty", "buffered_storm_track"),
    buffer = 250000,
    proj,
    bbox
    ){
  
  # read in and project storm track
  shape_proj_sf <- sf::read_sf(shape_name) |> 
    sf::st_transform(crs = proj)   |> 
    sf::st_crop(bbox)
  
  # Apply buffer around storm track
  if(shape_type == "buffered_storm_track"){
    shape_proj_sf <- sf::st_buffer(shape_proj_sf, dist = buffer)
  }
  
  return(shape_proj_sf)
}