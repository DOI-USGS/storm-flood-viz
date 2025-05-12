
# This function takes a vector of site ids and the desired number of sites
# per list and chunks them up into multiple vectors within a list
chunk_up_sites <- function(site_ids, n_sites_per_list){
  n_lists <- ceiling(length(site_ids)/n_sites_per_list)
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

## batch pull instantaneous values for gage height 
# function to fetch gage height data 
fetch_uv_data <- function(outfile_path, sites_list, pcodes, startDate, endDate){
  
  out <- sites_list |>
    purrr::map(\(x) dataRetrieval::readNWISuv(x, parameterCd = pcodes, 
                               startDate = startDate, 
                               endDate = endDate)) |>
    dplyr::bind_rows()
  
  arrow::write_parquet(out, outfile_path)
  
  return(outfile_path)

}

# Batch pull NWIS peaks data for a selected sites list and save the peaks
# data to a file.
fetch_peak_data <- function(outfile_path, sites_list, startDate = "1900-01-01"){
  
  out <- sites_list |>
    purrr::map(\(x) dataRetrieval::readNWISpeak(x, 
                                              startDate = startDate)) |>
    dplyr::bind_rows()
  
  arrow::write_parquet(out, outfile_path)
  
  return(outfile_path)
  
}
