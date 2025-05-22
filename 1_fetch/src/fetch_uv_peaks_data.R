
#' This function takes a vector of site ids and the desired number of sites
# per list and chunks them up into multiple vectors within a list
#' @param site_ids A vector of USGS site id's that include the leading zero, e.g. "01234567".
#' @param n_sites_per_vector The number of sites contained within each vector in the output list
#'
#' @return A list of vectors, each containing `n_sites_per_vector` site ID's for use
#' iterating over the `dataRetrieval::readNWISuv()` function.

chunk_up_sites <- function(site_ids, n_sites_per_vector){
  n_lists <- ceiling(length(site_ids)/n_sites_per_vector)
  # Split only works if n_lists is greater than 1, need to manually create
  # list if only 1 list needed!
  if(n_lists > 1){
    site_list <- split(site_ids, cut(seq_along(site_ids), n_lists, labels = FALSE))
  }else{
    site_list <- list()
    site_list[[1]] <- site_ids
  }
  
  return(site_list)
}

#' Batch pull instantaneous values for gage height
#'
#' @param outfile_path Character string pointing to the output file. Should have
#' file extension ".parquet".
#' @param sites_list List of site vectors created by `chunk_up_sites()` function.
#' @param pcodes A vector of strings representing desired USGS pcodes.
#' @param startDate A string in the format "YYYY-MM-DD" representing the start
#' date over which to pull data.
#' @param endDate A string in the format "YYYY-MM-DD" representing the end date
#' of the time period over which to pull uv data.
#'
#' @return The outfile path to a parquet file containing uv data.

fetch_uv_data <- function(outfile_path, sites_list, pcodes, startDate, endDate){
  
  out <- sites_list |>
    purrr::map(\(x) dataRetrieval::readNWISuv(x, parameterCd = pcodes, 
                               startDate = startDate, 
                               endDate = endDate)) |>
    dplyr::bind_rows()
  
  arrow::write_parquet(out, outfile_path)
  
  return(outfile_path)

}

#' Batch pull NWIS peaks data for a selected sites list and save the peaks
#' data to a file.
#' @param outfile_path Character string pointing to the output file. Should have
#' file extension ".parquet".
#' @param sites_list List of site vectors created by `chunk_up_sites()` function.
#' @param startDate A string in the format "YYYY-MM-DD" representing the start
#' date over which to pull peaks data. Should most likely be an early date like
#' "1900-01-01"
#'
#' @return The outfile path to a parquet file containing peaks data.

fetch_peak_data <- function(outfile_path, sites_list, startDate = "1900-01-01"){
  
  out <- sites_list |>
    purrr::map(\(x) dataRetrieval::readNWISpeak(x, 
                                              startDate = startDate)) |>
    dplyr::bind_rows()
  
  arrow::write_parquet(out, outfile_path)
  
  return(outfile_path)
  
}
