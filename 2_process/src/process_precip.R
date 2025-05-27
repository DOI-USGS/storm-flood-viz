#' Process precipitation raster data into a long-format data frame
#'
#' This fxn reads one or more precipitation `.tif` raster files, reprojects,
#' crops, and masks them to a given spatial boundary box, then converts them into a
#' tidy data frame with precipitation values. It supports hourly ("none"),
#' total-period ("total"), or cumulative multi-file ("cumulative") precipitation inputs.
#'
#' @param tif_files Character vector of paths to `.tif` files containing precipitation data.
#'        File names must follow a standard format: either `YYYY-MM-DDTHH.tif` (for hourly)
#'        or `YYYY-MM-DDTHH_to_YYYY-MM-DDTHH.tif` (for total/cumulative).
#' @param proj Character string specifying the target CRS for reprojection.
#' @param precip_summ Character; one of `"none"`, `"total"`, or `"cumulative"`, specifying
#'        how to treat the precipitation data:
#'        - `"none"`: each file is a single-hour raster layer;
#'        - `"total"`: one file represents total precip over a period;
#'        - `"cumulative"`: multiple files, each representing totals over partial periods.
#' @param states An `sf` object defining the spatial extent to crop/mask the rasters.
#'
#' @return A `data.frame` with precipitation values:
#'   - `"none"` mode: columns `x`, `y`, `dateTime`, `date`, and `precip_mm`
#'   - `"total"` and `"cumulative"` modes: columns `x`, `y`, `start_dateTime`, `end_dateTime`, and `precip_mm`
get_precip_df <- function(tif_files, proj, precip_summ, states) {
  # Convert sf to terra SpatVector
  state_vect <- terra::vect(states)
  
  # extract datetimes from filename
  extract_datetimes <- function(file) {
    fname <- basename(file)
    parts <- stringr::str_match(fname, "(\\d{4}-\\d{2}-\\d{2}T\\d{2})_to_(\\d{4}-\\d{2}-\\d{2}T\\d{2})")
    list(
      start = as.POSIXct(parts[2], format = "%Y-%m-%dT%H", tz = "UTC"),
      end   = as.POSIXct(parts[3], format = "%Y-%m-%dT%H", tz = "UTC")
    )
  }
  
  # project, crop, and mask a raster
  process_raster <- function(file) {
    r <- terra::rast(file)
    r_proj <- terra::project(r, proj)
    terra::mask(terra::crop(r_proj, state_vect), state_vect)
  }
  
  # none --------------------------------------------------------------------
  if (precip_summ == "none") {
    # Extract datetime labels for layer names
    names_vec <- str_extract(tif_files, "\\d{4}-\\d{2}-\\d{2}T\\d{2}")
    times <- as.POSIXct(names_vec, format = "%Y-%m-%dT%H", tz = "UTC")

    # Read, project, crop, and mask each file
    precip_rasters <- tif_files |>
      set_names(names_vec) |>
      purrr::map(~ process_raster(.x))
    
    stacked_rasters <- terra::rast(precip_rasters)
    names(stacked_rasters) <- format(times, "%Y-%m-%dT%H")
    
    precip_df <- as.data.frame(stacked_rasters, xy = TRUE) |>
      tidyr::pivot_longer(
        cols = -c(x, y),
        names_to = "dateTime",
        values_to = "precip_mm"
      ) |>
      mutate(
        dateTime = as.POSIXct(dateTime, format = "%Y-%m-%dT%H", tz = "UTC"),
        date = as.Date(dateTime)
      )
    
# total or cumulative -----------------------------------------------------
  } else if (precip_summ %in% c("total", "cumulative")) {
    precip_df <- tif_files |>
      purrr::map_dfr(function(file) {
        times <- extract_datetimes(file)
        r_crop <- process_raster(file)
        
        as.data.frame(r_crop, xy = TRUE, na.rm = TRUE) |>
          dplyr::rename(precip_mm = 3) |>
          dplyr::mutate(
            start_dateTime = times$start,
            end_dateTime = times$end
          )
      })
    
  } else {
    stop("Invalid value for precip_summ. Must be one of 'none', 'total', or 'cumulative'.")
  }
  
  return(precip_df)
}
