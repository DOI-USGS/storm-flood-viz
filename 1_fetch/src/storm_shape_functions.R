

get_storm_shape <- function(storm_code, shape_type = c("cone_of_uncertainty", "buffer_track"), out_folder){
  
  unzip_dir <- sprintf("%s/storm_shape_%s", out_folder, storm_code)
  file_name <- paste0(unzip_dir, ".zip")
  
  if (!dir.exists(unzip_dir)) dir.create(unzip_dir)
  
  if(shape_type == "cone_of_uncertainty"){
    file_url <- sprintf(
      "https://www.nhc.noaa.gov/gis/forecast/archive/%s_5day_001.zip",
      storm_code
      )
    shp_name <- sprintf("%s/%s-001_5day_pgn.shp", unzip_dir, storm_code)
  }else{
    # download url
    file_url <- sprintf(
      "http://www.nhc.noaa.gov/gis/best_track/%s_best_track.zip",
      storm_code
      )
    shp_name <- sprintf("%s/%s_lin.shp", unzip_dir, stringr::str_to_upper(storm_code))
    
  }
  
  # download the file
  download.file(file_url, file_name)
  
  # unzip the file
  unzip(file_name, exdir = unzip_dir)
  
  file.remove(file_name)
  
  return(shp_name)

}

read_in_shapefile <- function(
    shape_name,
    shape_type = c("cone_of_uncertainty", "buffer_track"),
    buffer = 250000,
    bbox
    ){
  
  # read in and project storm track
  shape_proj_sf <- sf::read_sf(shape_name) |> 
    sf::st_transform(crs = proj)   |> 
    sf::st_crop(bbox)
  
  if(shape_type == "buffer_track"){
    shape_proj_sf <- sf::st_buffer(shape_proj_sf, dist = buffer)
  }
  
  return(shape_proj_sf)
}
