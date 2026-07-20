# This python code access precip data in an xarray and converts it to a geotiff.

import xarray as xr
import fsspec
import pandas as pd
import numpy as np
from scipy.interpolate import griddata
import os
from osgeo import gdal
from osgeo import osr


def create_raster(
    output_path,
    columns,
    rows,
    nband,
    gdal_data_type,
    driver,
):
    """Create an empty GDAL raster dataset to write bands into.

    Args:
        output_path (str): Path where the raster file will be written.
        columns (int): Number of columns (pixels in the x direction).
        rows (int): Number of rows (pixels in the y direction).
        nband (int): Number of bands to allocate.
        gdal_data_type (int): GDAL pixel data type 
        driver (str): GDAL driver short name

    Returns:
        osgeo.gdal.Dataset: The newly created, empty raster dataset.
    """
    # create driver
    driver = gdal.GetDriverByName(driver)

    output_raster = driver.Create(
        output_path, int(columns), int(rows), nband, eType=gdal_data_type
    )
    return output_raster


def numpy_array_to_raster(
    output_path,
    numpy_array,
    upper_left_tuple,
    cell_resolution,
    nband,
    no_data,
    gdal_data_type,
    spatial_reference_system_wkid,
    driver,
):
    """Write a 2D NumPy array to a single-band, georeferenced raster.

    Builds the geotransform from the upper-left corner and cell resolution,
    assigns the given projection, writes the array to band 1, sets the
    no-data value, and computes band statistics.

    Args:
        output_path (str): Path where the raster file will be written.
        numpy_array (numpy.ndarray): 2D array of pixel values, shaped
            ``(rows, columns)``.
        upper_left_tuple (tuple): ``(x, y)`` map coordinates of the upper-left
            corner of the raster.
        cell_resolution (float): Pixel size in map units; applied as positive
            in x and negative in y.
        nband (int): Number of bands to allocate (values are written to band 1).
        no_data (float): Value used to flag missing pixels.
        gdal_data_type (int): GDAL pixel data type .
        spatial_reference_system_wkid (int): EPSG code of the raster's
            coordinate reference system.
        driver (str): GDAL driver short name.

    Returns:
        osgeo.gdal.Dataset: The written raster dataset.

    Raises:
        Exception: If the output file was not created on disk.
    """
    # get raster shape
    rows, columns = numpy_array.shape

    # create output raster
    output_raster = create_raster(
        output_path, int(columns), int(rows), nband, gdal_data_type, driver
    )

    geotransform = (
        upper_left_tuple[0],
        cell_resolution,
        0,
        upper_left_tuple[1],
        0,
        -1 * (cell_resolution),
    )

    spatial_reference = osr.SpatialReference()
    spatial_reference.ImportFromEPSG(spatial_reference_system_wkid)
    output_raster.SetProjection(spatial_reference.ExportToWkt())
    output_raster.SetGeoTransform(geotransform)
    output_band = output_raster.GetRasterBand(1)
    output_band.SetNoDataValue(no_data)
    output_band.WriteArray(numpy_array)
    output_band.FlushCache()
    output_band.ComputeStatistics(False)

    if os.path.exists(output_path) == False:
        raise Exception("Failed to create raster: %s" % output_path)

    return output_raster


def download_precip(
    bBox=[-82.0, 28.0, -79.0, 30.0],
    start_time_str="2024-10-07T10",
    end_time_str="2024-10-07T12",
    output_path="1_fetch/out/",
    summed="cumulative",
    cells_x=500,
    zarr_url="s3://mdmf/gdp/stageiv_combined.zarr/",
    GEOTIFF_DRIVER_NAME=r"GTiff",
    NO_DATA=-9999.0,
    SPATIAL_REFERENCE_SYSTEM_WKID=4269,
):
    """Download Stage IV hourly precip and write it as GeoTIFFs.

    Reads the Stage IV Zarr store on S3 for the requested UTC window,
    interpolates each hourly field onto a regular grid over ``bBox``, and
    writes GeoTIFFs. Existing files are skipped.

    Args:
        bBox (list): Bounding box ``[xmin, ymin, xmax, ymax]`` in the output CRS.
        start_time_str (str): Inclusive window start (UTC), parsed by
            ``pandas.to_datetime``.
        end_time_str (str): Inclusive window end (UTC), same format.
        output_path (str): Output directory; created if missing.
        summed (str): ``"none"`` (one file per hour), ``"cumulative"``
            (running sum per hour), or ``"total"`` (one summed file).
        cells_x (int): Grid cells along x; cell size and y cells derive from it.
        zarr_url (str): S3 URL of the Stage IV Zarr store.
        GEOTIFF_DRIVER_NAME (str): GDAL driver short name.
        NO_DATA (float): No-data value for each raster.
        SPATIAL_REFERENCE_SYSTEM_WKID (int): EPSG code for the output rasters.

    Returns:
        list[str]: Paths of the GeoTIFFs, including any that already existed.
    """
    if os.path.exists(output_path) == False:
        os.makedirs(output_path)

    # time in Coordinated Universal Time (UTC) (I believe)
    start_time = pd.to_datetime(start_time_str)
    end_time   = pd.to_datetime(end_time_str)
    hours      = pd.date_range(start=start_time, end=end_time, freq="h")
    start_str  = start_time.strftime("%Y-%m-%dT%H")

    # Check expected files before opening zarr.
    # Cumulative files: start_to_hourN.tif; none files: hourN.tif.
    if summed == "cumulative":
        expected_paths = [
            output_path + start_str + "_to_" + h.strftime("%Y-%m-%dT%H") + ".tif"
            for h in hours
        ]
    else:
        expected_paths = [
            output_path + h.strftime("%Y-%m-%dT%H") + ".tif"
            for h in hours
        ]

    missing = [p for p in expected_paths if not os.path.exists(p)]
    if not missing:
        print("All precip files already exist, skipping download.")
        return expected_paths

    # Index of the first missing file
    first_missing_idx = next(i for i, p in enumerate(expected_paths) if not os.path.exists(p))

    # For cumulative: load the last existing file from disk as the base sum
    # so zarr only needs to fetch the missing hours, not the full range.
    if summed == "cumulative" and first_missing_idx > 0:
        prev_raster = gdal.Open(expected_paths[first_missing_idx - 1])
        # files were written with np.flipud, so flip back to restore orientation
        interp_precip_sum = np.flipud(prev_raster.GetRasterBand(1).ReadAsArray().astype(np.float32))
        prev_raster = None
        zarr_start = hours[first_missing_idx]
    else:
        interp_precip_sum = None
        zarr_start = start_time

    # access the s3 bucket?
    fs = fsspec.filesystem("s3", anon=True, endpoint_url="https://usgs.osn.mghpcc.org")

    # open the dataset
    ds = xr.open_dataset(
        fs.get_mapper(zarr_url),
        engine="zarr",
        backend_kwargs={"consolidated": True},
        chunks={},
    )

    # fetch only the hours we actually need
    time_filtered_ds = ds.sel(time=slice(zarr_start, end_time))

    # isolate the 1-hr precip data
    precip = time_filtered_ds["Total_precipitation_surface_1_Hour_Accumulation"]
    precip = precip.transpose("time", "y", "x")

    # interpolated grid
    dx = (bBox[2] - bBox[0]) / float(cells_x)
    cell_height = int((bBox[3] - bBox[1]) / dx) + 1
    grid_x = np.linspace(
        bBox[0], bBox[0] + cells_x * dx, cells_x + 1
    )  # X-coordinates of your regular grid
    grid_y = np.linspace(
        bBox[1], bBox[1] + cell_height * dx, cell_height + 1
    )  # Y-coordinates of your regular grid

    # Create a meshgrid for regular grid coordinates
    grid_xx, grid_yy = np.meshgrid(grid_x, grid_y)

    # precip coordinates
    precip_coor = np.column_stack(
        (precip.longitude.values.flatten(), precip.latitude.values.flatten())
    )

    # seed file_paths with already-existing cumulative files
    file_paths = list(expected_paths[:first_missing_idx]) if summed == "cumulative" else []

    # save array from each time
    for i in range(0, precip.shape[0]):

        # interpolate - needs to be nearest, griddata crashes with reticulate and targets for some reason 5/2/25. It's all good with reticulate or python by itself.
        interp_precip = griddata(
            (precip.longitude.values.flatten(), precip.latitude.values.flatten()),
            precip[i].values.flatten(),
            (grid_xx, grid_yy),
            method="nearest",
        )

        if summed == "none":
            # specify file path
            file_path = output_path + str(precip.time.values[i])[:-16] + ".tif"
            if not os.path.exists(file_path):
                print("saving tif: " + file_path)
                numpy_array_to_raster(
                    file_path,
                    np.flipud(interp_precip),
                    (bBox[0] - dx * 0.5, bBox[3] + dx * 0.5),
                    dx,
                    nband=1,
                    no_data=NO_DATA,
                    gdal_data_type=gdal.GDT_Float32,
                    spatial_reference_system_wkid=SPATIAL_REFERENCE_SYSTEM_WKID,
                    driver=GEOTIFF_DRIVER_NAME,
                )
            # make a list of output paths
            file_paths += [file_path]
        else:
            if interp_precip_sum is None:
                interp_precip_sum = interp_precip
            else:
                interp_precip_sum += interp_precip

            if summed == "cumulative" or (
                summed == "total" and i == precip.shape[0] - 1
            ):  # Save a sum is cumulative or the sum at the end of the loop if summed mode == total
                file_path = expected_paths[first_missing_idx + i]
                if not os.path.exists(file_path):
                    print("saving tif: " + file_path)
                    numpy_array_to_raster(
                        file_path,
                        np.flipud(interp_precip_sum),
                        (bBox[0] - dx * 0.5, bBox[3] + dx * 0.5),
                        dx,
                        nband=1,
                        no_data=NO_DATA,
                        gdal_data_type=gdal.GDT_Float32,
                        spatial_reference_system_wkid=SPATIAL_REFERENCE_SYSTEM_WKID,
                        driver=GEOTIFF_DRIVER_NAME,
                    )
                file_paths += [file_path]

    return file_paths
