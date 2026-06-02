# Set Python environment and run precipitation data processing script
py <- Sys.getenv("RETICULATE_PYTHON", unset = "")
if (nzchar(py)) {
  reticulate::use_python(py, required = TRUE)
} else {
  reticulate::use_condaenv("hurricane-precip", required = TRUE)
}
reticulate::source_python("1_fetch/src/get_precip.py")

# Source functions
source("1_fetch/src/storm_shape_functions.R")
source("1_fetch/src/clip_flood_stage_gages.R")
source("1_fetch/src/fetch_uv_peaks_data.R")
source("1_fetch/src/fetch_rapid_deployment_data.R")
source("1_fetch/src/fetch_site_stats.R")

p1_targets <- list(
# Fetch precipitation data  -----------------------------------------------
  tar_target(p1_precip_py_file, 
             "1_fetch/src/get_precip.py",
             format = "file"),
  tar_target(p1_precip_tifs,
             {
               # Make this target dependent upon the precip python file
               p1_precip_py_file

               download_precip(bBox = p0_precip_bbox,
                               start_time_str = p0_precip_start,
                               end_time_str = p0_precip_end,
                               summed = "cumulative",
                               output_path = "1_fetch/out/")
             },
             format = 'file'),
  # Convert projection
  tar_target(
    p1_bbox_proj,
    {
      if (!identical(sf::st_crs(p0_proj), sf::st_crs("EPSG:4269"))) {
        sf::st_as_sfc(p0_bbox_sf) |> 
          sf::st_as_sf(crs = "EPSG:4269") |>
          sf::st_transform(crs = p0_proj) |>
          sf::st_bbox()
      }else{
        p0_bbox_sf
      }
    }
  ),

# Storm shape -------------------------------------------------------------
  # Get storm shape file from NOAA, storm track or cone of uncertainty
  tar_target(
    p1_storm_track_files,
    get_storm_shape(
      storm_code = p0_storm_info |> pull(storm_code),
      shape_type = "storm_track_files",
      out_folder = "1_fetch/out"
    ),
    format = "file"
  ),
  tar_target(
    p1_storm_path_buffered_sf,
    {
      lin_file <- p1_storm_track_files[grepl("_lin\\.shp$", p1_storm_track_files)]
      sf::read_sf(lin_file) |>
        sf::st_transform(crs = p0_proj) |>
        sf::st_crop(p1_bbox_proj) |>
        sf::st_buffer(dist = p0_storm_info |> pull(storm_buffer))
    }
  ),
  tar_target(
    p1_storm_track_pts_sf,
    {
      pts_file <- p1_storm_track_files[grepl("_pts\\.shp$", p1_storm_track_files)]
      
      sf_data <- sf::read_sf(pts_file) |>
        sf::st_transform(crs = p0_proj) |>
        filter(STORMNAME %in% dplyr::pull(p0_storm_info, storm_name)) |>
        mutate(
          DTG = as.POSIXct(as.character(DTG), format = "%Y%m%d%H", tz = "UTC"),
          storm_type_full = dplyr::case_when(
            STORMTYPE == "TS" ~ "Tropical storm",
            STORMTYPE == "HU" ~ "Hurricane",
            STORMTYPE == "LO" ~ "Low pressure system",
            TRUE ~ NA_character_  # Keep unknowns explicit
          )
        ) |> 
        tidyr::fill(storm_type_full, .direction = "down")
  
      # now bind coordinates
      bind_cols(
        sf_data,
        sf::st_coordinates(sf_data) |> tibble::as_tibble() |> 
          rename(X = X, Y = Y)
      )
    }
  ),

# State data --------------------------------------------------------------
  # Download state borders and crop to bbox
  tar_target(
    p1_conus_bbox_crop_sf, 
    tigris::states(cb = TRUE) |>
      filter(!STUSPS %in% c("AK", "HI", "MP", "VI", "AS", "GU")) |>
      st_transform(p0_proj) |>
      rmapshaper::ms_simplify(keep = 0.2) |> 
      st_crop(
        p0_bbox_sf |>
          st_as_sfc() |>
          sf::st_as_sf(crs = "EPSG:4269") |>
          st_transform(p0_proj)
      )
  ),
  # Convert bbox to a list with xlim and ylim vector
  tar_target(
    p1_bbox_coords,
    {
      bbox <- sf::st_bbox(p1_conus_bbox_crop_sf)
      list(
        xlim = c(bbox["xmin"], bbox["xmax"]),
        ylim = c(bbox["ymin"], bbox["ymax"])
      )
      }
    ),
  # Download major cities
  tar_target(
    p1_major_cities_sf,
    {
      city_lookup <- tibble::tibble(
        name = c("Miami", "Atlanta", "Raleigh", "Philadelphia", "New York", 
                 "New Orleans", "Memphis", "Jackson", "Houston",
                 "Richmond", "Mobile", "Columbia"),
        state_abbr = c("FL", "GA", "NC", "PA", "NY", "LA", "TN", "MS", "TX", 
                       "VA", "AL", "SC")
      )
      
      state_fips <- tigris::fips_codes |>
        dplyr::distinct(state_code, state) |>
        dplyr::rename(state_abbr = state)
      
      city_join <- dplyr::left_join(city_lookup, state_fips, by = "state_abbr")
      
      tigris::places(cb = TRUE) |>
        dplyr::inner_join(city_join, by = c("NAME" = "name", "STATEFP" = "state_code")) |>
        dplyr::select(NAME, geometry) |>
        sf::st_transform(p0_proj) |>
        sf::st_centroid()
    }
  ),

# Fetch rapid deployment gages  -------------------------------------------
  tar_target(
    # Note that some rapid deployment gages are placed a weeks or so after
    # hurricane landfall 
    p1_rapid_dep_gages,
    fetch_rapid_dep_sites(event = p0_storm_info$stn_event,
                          proj = p0_proj,
                          start_day = p0_precip_start,
                          end_day = p0_precip_end)
  ),

# Fetch flood data --------------------------------------------------------
  # Download flood stage csv from NOAA
  tar_target(
    p1_flood_stage_file,
    {
      out_path <- "1_fetch/out/flood_stage_gages.csv"
      download.file(p0_flood_stage_url, out_path)
      return(out_path)
      
    },
    format = "file"
  ),
  # Read in flood stage df and perform some tidying
  tar_target(
    p1_usgs_flood_stage_gages,
    flood_stage_gages(
      flood_stage_file = p1_flood_stage_file,
      proj = p0_proj,
      bbox = p1_conus_bbox_crop_sf
    )
  ),
  # Get all stream gages in the event bbox (not just flood-stage sites).
  # Queries time-series-metadata/items by bbox + pcode + statistic_id "00011"
  # (instantaneous/UV) via dataRetrieval, then drops series whose end_utc
  # predates storm start. Returns sf (WGS 84); we reproject to p0_proj for
  # downstream mapping.
  tar_target(
    p1_bbox_stream_sites_sf,
    fetch_bbox_stream_sites(
      bbox = as.numeric(p0_bbox_sf),
      pcodes = p0_pcodes,
      time_range = paste0(p0_nwis_start, "/", p0_nwis_end)
    ) |>
      sf::st_transform(p0_proj)
  ),
  # Character vector of site numbers for UV/stats fetching
  tar_target(
    p1_bbox_stream_sites,
    p1_bbox_stream_sites_sf$site_no
  ),
  # Get sites chunked up for uv data download
  tar_target(
    p1_site_id_chunks,
    chunk_up_sites(p1_bbox_stream_sites, n_sites_per_vector = 300)
  ),
  # Download uv data to parquet
  tar_target(
    p1_uv_data_pqt,
    fetch_uv_data(
      outfile_path = "1_fetch/out/gage_uv_data.parquet",
      sites_list = p1_site_id_chunks,
      pcodes = p0_pcodes,
      startDate = p0_nwis_start,
      endDate = p0_nwis_end
    ),
    format = "file"
  ),
  # Download peaks data to parquet
  tar_target(
    p1_peak_data_pqt,
    fetch_peak_data(
      outfile_path = "1_fetch/out/gage_peak_data.parquet",
      sites_list = p1_site_id_chunks
    ),
    format = "file"
  ),
  tar_target(
    p1_site_stats_pqt,
    fetch_site_stats(site_nos = p1_bbox_stream_sites,
                     out_path = "1_fetch/out/site_stats.parquet",
                     min_por_years = 10),
    format = "file"
  )
)
