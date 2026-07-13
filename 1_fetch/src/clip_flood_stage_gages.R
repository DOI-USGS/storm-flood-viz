# Takes the entire file with all flood stage gages 

#' @param flood_stage_file A file path to a csv file containing flood stage
#' information for all USGS stream gages. Must have the following columns:
#' "latitude", "longitude", "usgs id", "action stage", "flood stage",
#' and "moderate flood stage", "major flood stage".
#' @param bbox, sf object that points to conus bounding box set up upstream 

#' @return An sf dataframe with all flood stage gages within the shape.

flood_stage_gages <- function(flood_stage_file, proj, bbox){
  
  # read in the file
  flood_stage_raw <- read_csv(flood_stage_file) 
  
  # process the data
  flood_stage_sf <- flood_stage_raw |> 
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |> 
    select(site_no = "usgs id", state, "action stage", "flood stage",
                  "moderate flood stage", "major flood stage",
                vert.datum = "nrldb vertical datum name",
                  geometry) |> 
    st_transform(proj)
  
  # filter to points inside the storm shape
  target_gages <- st_intersection(flood_stage_sf, bbox) |> 
    # filter out unusable site numbers
    filter(nchar(as.character(site_no)) >= 8) |> 
    filter(!grepl("[a-zA-Z]", site_no)) |>
    filter(
      !action.stage == -9999.0 &
        !flood.stage == -9999.0 &
        !moderate.flood.stage == -9999.0 &
        !major.flood.stage == -9999.0
    ) |>
    select(site_no, state, action.stage, flood.stage,
                  moderate.flood.stage, major.flood.stage,
                  vert.datum
                  ) |>
    distinct()
  
  # handle duplicates
  target_gages <- target_gages |>
    mutate(
      navd88_pref = coalesce(as.integer(vert.datum == "NAVD88"), 0L)
    ) |>
    arrange(site_no, desc(navd88_pref)) |>
    distinct(site_no, .keep_all = TRUE) |>
    select(-navd88_pref)
  
  return(target_gages)
  
}