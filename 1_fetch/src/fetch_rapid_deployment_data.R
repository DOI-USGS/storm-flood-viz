#' Fetch Rapid Deployment Gage (RDG) Sites for a Specified Event
#'
#' This function retrieves rapid deployment gage (RDG) sites from the USGS STN web services
#' for a specified flood or storm event. It filters for pressure transducer sensors
#' (SensorType = 5).
#' @param event Integer. A valid USGS stn evebt ID, found at https://stn.wim.usgs.gov/STNDataPortal/#
#' @param proj projection to reproject by
#' @param start_day start date, to filter final df by to gather rapid deployment gages
#' @param end_day end date, to filter final df by to gather rapid deployment gages
#' @return A data frame of RDG site information, including sensor type, event name, 
#' timestamp, site number, latitude, longitude, and site description.
fetch_rapid_dep_sites <- function(event, proj, start_day, end_day) {
  
  if(is.null(event)) {
    
    rdgs <- data.frame()
    } else {    # fetch the rapid deployment gages (RDGs) from the STN web services
      
      url <- sprintf('https://stn.wim.usgs.gov/STNServices/Instruments/FilteredInstruments.json?Event=%d&EventType=&EventStatus=&States=&County=&CurrentStatus=&CollectionCondition=&SensorType=5&DeploymentType=', event) 
      
    rdgs <- jsonlite::fromJSON(url)
    
    if(length(rdgs) > 0) {
      rdgs <- rdgs %>%
        select(sensorType, eventName, timeStamp, site_no, latitude, longitude, siteDescription)
    }
    }    
  
  # reproject
  rdgs_proj <- st_as_sf(
    rdgs,
    coords = c("longitude", "latitude"),
    #decimal degrees
    crs = 4326  # EPSG:4326 is WGS84
  )
  
  rdgs_proj <- st_transform(rdgs_proj, crs = proj)
  
  start_day <- as.POSIXct(start_day, format = "%Y-%m-%dT%H", tz = "UTC")
  end_day   <- as.POSIXct(end_day,   format = "%Y-%m-%dT%H",tz = "UTC")
  
  rdgs_time <- rdgs_proj |>
    mutate(
      dateTime = as.POSIXct(timeStamp, format = "%Y-%m-%dT%H:%M:%S",  tz = "UTC"),
      dateTime = round_date(dateTime, unit = "hour")
    ) |>
    filter(dateTime >= start_day, dateTime <= end_day) 
  
  # if we wanted to look up data for these sites, we could go to NWIS by using  # this sites table to map the RDG ID (site_no) to an NWIS id (usgs_sid):  # https://stn.wim.usgs.gov/STNServices/Events/283/sites
  
  return(rdgs_time)
}
