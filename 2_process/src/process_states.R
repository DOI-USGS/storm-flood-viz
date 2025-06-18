#' Extract inner shared borders between adjacent polygons
#'
#' This function identifies and extracts the shared boundary lines between adjacent features 
#' in an `sf` object, such as internal state borders. It avoids duplicated lines by checking 
#' only the upper triangle of the adjacency matrix.
#'
#' @param in_sf An `sf` object of polygon features (e.g., U.S. state boundaries). 
#'              Must be in a projected CRS.
#'
#' @return An `sf` object with `MULTILINESTRING` geometries representing the inner shared borders.
get_inner_lines <- function(in_sf) {
  
  # Ensure geometries are valid
  state_borders <- st_make_valid(in_sf)
  
  # Get all unique combinations of bordering states
  adjacent_pairs <- st_touches(state_borders, sparse = FALSE)
  
  # Create a data frame of touching pairs (upper triangle only to avoid duplicates)
  touching_pairs <- which(adjacent_pairs, arr.ind = TRUE)
  touching_pairs <- touching_pairs[touching_pairs[,1] < touching_pairs[,2], ]
  
  # Get shared boundaries
  inner_borders <- purrr::map_dfr(1:nrow(touching_pairs), function(i) {
    i1 <- touching_pairs[i, 1]
    i2 <- touching_pairs[i, 2]
    
    g1 <- state_borders[i1, ]
    g2 <- state_borders[i2, ]
    
    shared <- st_intersection(st_geometry(g1), st_geometry(g2))
    
    tibble::tibble(geometry = shared)
  }) |> 
    st_as_sf()
  
}

#' Extract Outer Boundary Lines from an sf Object
#'
#' This function takes a sf object with polygon or multipolygon geometries
#' and returns a single geometry representing the outer boundary (outline) of the union of all features.
#'
#' @param in_sf An sf object with polygon or multipolygon geometries.
#'
#' @return An `sfc` object containing LINESTRING or MULTILINESTRING geometries representing the outer boundary.
#' 
#' @examples
#' library(sf)
#' data <- p1_conus_bbox_crop_sf
#' outer_lines <- get_outer_lines(data)
#' plot(outer_lines)
#'
#' @importFrom sf st_union st_boundary
#' @export
get_outer_lines <- function(in_sf) {
  # Union all geometries together into one
  unified_geom <- st_union(in_sf)
  
  # Get the outer boundary of the unioned geometry
  outer_lines <- st_boundary(unified_geom)
  
  return(outer_lines)
}