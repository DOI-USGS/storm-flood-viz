from dataretrieval import nwis
import hyswap
import pandas as pd
import numpy as np
import datetime

def calculate_uv_percentiles_from_dv(site_id, sites_uv_df, pcode):
    """
    Calculate percentiles on instantaneous data using daily values fixed percentile thresholds
    Keyword arguments
    -----------------
    site_id: A single string corresponding to a monitoring location gage
    sites_uv_df: A pandas dataframe with a 'dateTime' column and a column
                containing instantaneous data for the pcode input
    pcode: A 5-digit string representing a particular parameter code.
    """

    # Check that pcode column is not all NA:
    pcode_column = "X_" + pcode + "_00000"
    
    # Define percentile levels
    percentile_levels = [1,5,10,25,50,75,90,95,99]

    # subset to site
    site_uv_df = sites_uv_df[sites_uv_df['site_no'] == site_id].copy()

    if not site_uv_df[pcode_column].isnull().all():
        # get minimum date
        max_date_percentiles = (site_uv_df['dateTime'].min() - datetime.timedelta(days=1)).strftime('%Y-%m-%d')

        # grab site data
        dv_data = nwis.get_record(sites='07029500', start="1900-01-01", end=max_date_percentiles, service="dv")
        
        # get correct column name
        data_column = pcode + "_Mean"

        # if column exists in data, calculate percentiles
        if data_column in dv_data.columns:
            fixed_percentiles = hyswap.calculate_fixed_percentile_thresholds(
                dv_data,
                data_column_name=data_column,
                percentiles=percentile_levels
                )
            
            # Then, use percentile thresholds to estimate percentiles for uv data
            site_uv_df.loc[:, 'percentile'] = site_uv_df.apply(lambda row: hyswap.percentiles.calculate_fixed_percentile_from_value(  # noqa: E501
                row[pcode_column], fixed_percentiles), axis = 1)
        
        else:
            print(f"No {data_column} column present in returned dv data for {site_id}. Returning input dataset with NA percentiles.")
            site_uv_df['percentile'] = np.nan
    else:
        print(f"All {pcode_column} column values in input data are NA. Returning input dataset with NA percentiles")
        site_uv_df['percentile'] = np.nan
    
    return site_uv_df

# if __name__ == "__main__":
#     in_data_file = "1_fetch/out/gage_uv_data.parquet"
#     sites_uv_df = pd.read_parquet(in_data_file, engine="pyarrow")
#     site_id = sites_uv_df['site_no'].to_list()[5]
# 
#     out = calculate_uv_percentiles_from_dv(site_id=site_id, sites_uv_df=sites_uv_df, pcode='00060')



