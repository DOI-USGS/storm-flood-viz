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
    """returns gdal data source raster object"""
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
    file_path_base="1_fetch/out/",
    summed=False,
    cells_x=500,
    zarr_url="s3://mdmf/gdp/stageiv_combined.zarr/",
    GEOTIFF_DRIVER_NAME=r"GTiff",
    NO_DATA=-9999.0,
    SPATIAL_REFERENCE_SYSTEM_WKID=4269,
):
    if os.path.exists(file_path_base) == False:
        os.makedirs(file_path_base)

    # time in Coordinated Universal Time (UTC) (I believe)
    start_time = pd.to_datetime(start_time_str)
    end_time = pd.to_datetime(end_time_str)

    # access the s3 bucket?
    fs = fsspec.filesystem("s3", anon=True, endpoint_url="https://usgs.osn.mghpcc.org")

    # open the dataset
    ds = xr.open_dataset(
        fs.get_mapper(zarr_url),
        engine="zarr",
        backend_kwargs={"consolidated": True},
        chunks={},
    )

    # get data from Wednesday 10/9/24 4 PM Eastern to Thursday 10/10/24 12 AM Eastern
    time_filtered_ds = ds.sel(time=slice(start_time, end_time))

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

    output_paths = []
    # save array from each time
    for i in range(0, precip.shape[0]):

        # interpolate - needs to be nearest, griddata crashes with reticulate and targets for some reason 5/2/25. It's all good with reticulate or python by itself.
        interp_precip = griddata(
            (precip.longitude.values.flatten(), precip.latitude.values.flatten()),
            precip[i].values.flatten(),
            (grid_xx, grid_yy),
            method="nearest",
        )

        if summed == False:
            # specify file path
            output_path = file_path_base + str(precip.time.values[i])[:-16] + ".tif"
            # convert to gdal tiff
            print("saving tif: " + output_path)
            numpy_array_to_raster(
                output_path,
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
            output_paths += [output_path]
        else:
            if i == 0:
                interp_precip_sum = interp_precip
            else:
                interp_precip_sum += interp_precip

    if summed == True:
        output_path = (
            file_path_base
            + str(precip.time.values[0])[:-16]
            + "_to_"
            + str(precip.time.values[-1])[:-16]
            + ".tif"
        )
        # convert to gdal tiff
        print(
            "saving summer tif: "
            + file_path_base
            + str(precip.time.values[0])[:-16]
            + "_to_"
            + str(precip.time.values[-1])[:-16]
            + ".tif"
        )
        numpy_array_to_raster(
            output_path,
            np.flipud(interp_precip_sum),
            (bBox[0] - dx * 0.5, bBox[3] + dx * 0.5),
            dx,
            nband=1,
            no_data=NO_DATA,
            gdal_data_type=gdal.GDT_Float32,
            spatial_reference_system_wkid=SPATIAL_REFERENCE_SYSTEM_WKID,
            driver=GEOTIFF_DRIVER_NAME,
        )
        return output_path
    else:
        return output_paths
