import subprocess
import pandas as pd
import boto3
import os
from google.cloud import storage
import shutil
import h5py
import time
import numpy as np
import fsspec
import s3fs
#import shapely.wkt as wkt
import rasterio
from rasterio.crs import CRS
from rasterio.transform import from_origin
import rioxarray
from botocore import UNSIGNED
from botocore.client import Config
from osgeo import gdal, osr, ogr 
import multiprocessing as mp
from cslc_utils import read_cslc, cslc_info, rasterWrite, custom_merge, moving_window_mean


def upload_blob(bucket_name, source_file_name, destination_blob_name):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name,timeout=None)
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(source_file_name,timeout=None)

def getGeoTransform(extent, nlines, ncols):
    resx = (extent[2] - extent[0]) / ncols
    resy = (extent[3] - extent[1]) / nlines
    return [extent[0], resx, 0, extent[3] , 0, -resy]


def makeInterferogram(s3key1,s3key2,gcskeyP,gcskeyC):
    filename = gcskeyP.split('/')[-1]
    fpath = f'./temp/{filename}/'
    if os.path.exists(fpath):
        shutil.rmtree(fpath)
    os.makedirs(fpath,exist_ok=True)

    try: 
        bucket = 'opera-pst-rs-pop1'
        s3uri1 = f's3://{bucket}/{s3key1}'
        s3uri2 = f's3://{bucket}/{s3key2}'
        dat1 = read_cslc(s3uri1)
        dat2 = read_cslc(s3uri2)

        xcoor, ycoor, dx, dy, epsg, bounding_polygon, orbit_direction = cslc_info(s3uri1)
        pass_direction = {'Ascending':'A','Descending':'D'}
        pass_d = pass_direction[orbit_direction]

        #print('Making interferogram')
        ifg = dat2 * np.conj(dat1)
        transform = from_origin(xcoor[0],ycoor[0],dx,np.abs(dy))
        tempfile = f'{fpath}temp_ifg.tif'
        outfile_ifg = f'{fpath}ifg.tif'
        rasterWrite(tempfile,np.angle(ifg),transform,epsg,dtype=rasterio.float32)
        gdal_cmd = f'gdal_translate -of COG -co COMPRESS=DEFLATE -co RESAMPLING=NEAREST {tempfile} {outfile_ifg}'
        subprocess.run(gdal_cmd,shell=True,stdout=subprocess.DEVNULL)

        #print('reading interferogram')
        ifg = rioxarray.open_rasterio(outfile_ifg)
        ifg = ifg.rio.reproject("EPSG:4326")[0]  
        minlon,minlat,maxlon,maxlat = ifg.rio.bounds()
        extent = [minlon,minlat,maxlon,maxlat]

        #print('computing complex')
        ifg_cpx = np.exp(1j * np.nan_to_num(ifg))

        #print('computing coherence')
        coh = np.clip(np.abs(moving_window_mean(ifg_cpx, 10)), 0, 1)

        #print('masking 0s and nans')
        nan_mask = np.isnan(ifg)
        zero_mask = ifg == 0
        coh[nan_mask] = np.nan
        coh[zero_mask] = 0

        tempfile = f'{fpath}tem_coh.tif'
        outfile_coh = f'{fpath}coh.tif'

        driver = gdal.GetDriverByName('GTiff')
        nlines = coh.shape[0]
        ncols = coh.shape[1]
        nbands = len(coh.shape)
        data_type = gdal.GDT_Float32
        grid_data = driver.Create(f'{fpath}grid_data', ncols, nlines, 1, data_type)#, options)
        grid_data.GetRasterBand(1).WriteArray(coh)
        srs = osr.SpatialReference()
        srs.ImportFromEPSG(4326)
        driver.CreateCopy(tempfile, grid_data, 0)

        # Setup projection and geo-transform
        grid_data.SetProjection(srs.ExportToWkt())
        grid_data.SetGeoTransform(getGeoTransform(extent, nlines, ncols))
        driver.CreateCopy(tempfile, grid_data, 0)
        driver = None
        grid_data = None

        gdal_cmd = f'gdal_translate -of COG -co COMPRESS=DEFLATE -co RESAMPLING=AVERAGE {tempfile} {outfile_coh}'
        subprocess.run(gdal_cmd,shell=True,stdout=subprocess.DEVNULL)

        #Upload to GCS bucket
        #print('Uploading to GCS Bucket')
        gcsbucket = "opera-bucket-cslc"
        gcskeyP= gcskeyP + f'_{pass_d}.tif'
        gcskeyC = gcskeyC + f'_{pass_d}.tif'
        upload_blob(gcsbucket,outfile_ifg,gcskeyP)
        upload_blob(gcsbucket,outfile_coh,gcskeyC)
    except Exception as e:
        print(f'failed at {s3key1}')
        print(f'error: {e}')
    shutil.rmtree(fpath)

def run_cslc_ifg(keydict):
    try:
        start_time = time.time()
        s3key1 = keydict['s3Key1']
        s3key2 = keydict['s3Key2']
        gcskeyP = keydict['gcsKey_phase']
        gcskeyC = keydict['gcsKey_coh']
        makeInterferogram(s3key1,s3key2,gcskeyP,gcskeyC)
        print(f'[{time.time() - start_time}] Uploaded to: {gcskeyP}')
    except Exception as e: 
        print(f'Failed on {s3key1}, error: {e}')

if __name__ == '__main__':
    os.environ["GCLOUD_PROJECT"] = "opera-one"
    s3_prefix = 'products/cslc_historical_20190701_to_20190718/'
    gcs_prefix = 'products/cslc_historical_20190701_to_20190718_v2/'
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket='opera-pst-rs-pop1', Prefix=s3_prefix, Delimiter='/')

    #burstList = ['T071-151217','T071-151218','T071-151219','T071-151220']
    with open('burstIDList.txt') as f:
        burstList = f.read().splitlines() 
    
    keyList = []
    for page in pages:
        for obj in page['CommonPrefixes']:
            path = obj.get('Prefix')
            fname = path.split('/')[-2]+'.h5'
            keyList.append(path+fname)
    print(f'{len(keyList)} s3 keys found')

    storage_client = storage.Client()
    blobs = storage_client.list_blobs("opera-bucket-cslc", prefix=gcs_prefix)
    gcsKeys = []
    for blob in blobs:
        gcsKeys.append(blob.name.split('.tif')[0][:-2]+'.tif')
    print(f'{len(gcsKeys)} existing gcs keys found')
    keyMatches = []
    burstMatches = []
    Dates = []
    fileData = []
    for key in keyList:
        burst = key.split('/')[2].split('_')[4]#.split('-IW')[0]
        sub_burst = key.split('/')[2].split('_')[4]
        date = int(key.split('/')[2].split('_')[6].split('T')[0])
        if burst in burstList:
            fileData.append([key,sub_burst,date])
        else:
            fileData.append([key,sub_burst,date])
    df = pd.DataFrame(fileData,
    columns =['Key', 'Burst','Date'])
    uniqueBursts = df.Burst.unique()
    print(len(uniqueBursts))
    keyPairs = []
    for b in uniqueBursts:
        if len(df[df.Burst==b]) >= 2:
            pairDict = {}
            pairs = df[df.Burst==b].sort_values(by='Date')
            row1 = pairs.iloc[[0]]
            row2 = pairs.iloc[[1]]
            
            s1 = row1['Key'].values[0].split('/')[-1].split('_')
            date1 = s1[6]
            burst = s1[4]
            
            s2 = row2['Key'].values[0].split('/')[-1].split('_')
            date2 = s2[6]
            
            gcsKey_phase = f'{gcs_prefix}ifg/{burst}_{date1}_{date2}_ifg'
            gcsKey_coh = f'{gcs_prefix}coh/{burst}_{date1}_{date2}_coh'

            if gcsKey_phase+'.tif' not in gcsKeys:
                pairDict['s3Key1'] = row1['Key'].values[0]
                pairDict['s3Key2'] = row2['Key'].values[0]
                pairDict['gcsKey_phase'] = gcsKey_phase
                pairDict['gcsKey_coh'] = gcsKey_coh

                keyPairs.append(pairDict)
            
    print(f'{len(keyPairs)} key pairs identified')
    pool = mp.Pool(12)
    pool.map(run_cslc_ifg,keyPairs)
    pool.close()
