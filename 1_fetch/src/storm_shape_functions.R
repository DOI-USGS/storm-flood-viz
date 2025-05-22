#' Get storm shape from NOAA's website
#'
#' @param storm_code An alphanumeric code from NOAA's website used to identify
#' particular storms.
#' @param shape_type Must be either "cone_of_uncertainty" or "storm_track_files".
#' @param out_folder Folder to output shape folder containing shape files.
#'
#' @return For "cone_of_uncertainty", returns the full path to a .shp file.
#' For "storm_track_files", returns a character vector of all files unzipped from the archive.
get_storm_shape <- function(
    storm_code,
    shape_type = c("cone_of_uncertainty", "storm_track_files"),
    out_folder
) {
  
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
    
    # Download and unzip a single .shp
    download.file(file_url, file_name)
    unzip(file_name, exdir = unzip_dir)
    file.remove(file_name)
    
    return(shp_name)
    
  } else if (shape_type == "storm_track_files") {
    
    file_url <- sprintf(
      "http://www.nhc.noaa.gov/gis/best_track/%s_best_track.zip",
      storm_code
    )
    
    # Download and return all unzipped file paths
    download.file(file_url, file_name)
    unzipped_files <- unzip(file_name, exdir = unzip_dir)
    file.remove(file_name)
    
    return(unzipped_files)
  }
}