clip_flood_stage_gages <- function(flood_stage_file, storm_shape){
  
  # read in the file
  flood_stage_raw <- readr::read_csv(flood_stage_file) 
  
  # process the data
  flood_stage_sf <- flood_stage_raw |> 
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> 
    dplyr::select(site_no = "usgs id", state, "action stage", "flood stage", "moderate flood stage", "major flood stage", geometry) |> 
    sf::st_transform(proj)
  
  # filter to points inside the cone of uncertainty
  target_gages <- sf::st_intersection(flood_stage_sf, storm_shape) |> 
    tidyr::drop_na() |> 
    # filter out unusable site numbers
    dplyr::filter(nchar(as.character(site_no)) >= 8) |> 
    dplyr::filter(!grepl("[a-zA-Z]", site_no)) |>
    dplyr::filter(
      !action.stage == -9999.0 &
        !flood.stage == -9999.0 &
        !moderate.flood.stage == -9999.0 &
        !major.flood.stage == -9999.0
                    )
  
  return(target_gages)
  
}