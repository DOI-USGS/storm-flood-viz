# Takes the entire file with all flood stage gages and filters to gages
# contained within the storm shape.
#'
#' @param flood_stage_file A file path to a csv file containing flood stage
#' information for all USGS stream gages. Must have the following columns:
#' "latitude", "longitude", "usgs id", "action stage", "flood stage",
#' and "moderate flood stage", "major flood stage".
#' @param storm_shape An sf object over which to intersect the latitude and
#' longitude from the stream gages with flood stage information.
#'
#' @return An sf dataframe with all flood stage gages within the shape.

clip_flood_stage_gages <- function(flood_stage_file, storm_shape, proj){
  
  # read in the file
  flood_stage_raw <- readr::read_csv(flood_stage_file) 
  
  # process the data
  flood_stage_sf <- flood_stage_raw |> 
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> 
    dplyr::select(site_no = "usgs id", state, "action stage", "flood stage", "moderate flood stage", "major flood stage", geometry) |> 
    sf::st_transform(proj)
  
  # filter to points inside the storm shape
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
                    ) |>
    dplyr::select(site_no, state, action.stage, flood.stage, moderate.flood.stage, major.flood.stage) |>
    dplyr::distinct()
  
  return(target_gages)
}