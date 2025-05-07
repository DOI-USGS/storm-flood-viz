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