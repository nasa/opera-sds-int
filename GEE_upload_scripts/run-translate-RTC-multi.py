import subprocess
import boto3
import os
from google.cloud import storage
import shutil
import time
from botocore import UNSIGNED
from botocore.client import Config
import multiprocessing as mp


def upload_blob(bucket_name, source_file_name, destination_blob_name):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name,timeout=None)
    blob = bucket.blob(destination_blob_name)
    blob.upload_from_filename(source_file_name,timeout=None)

def processRTC(s3key,gcskey):
    filename = s3key.split('/')[-1]
    if os.path.exists(f'./temp_{filename}/'):
        shutil.rmtree(f'./temp_{filename}/')
    os.mkdir(f'./temp_{filename}/')

    #Download RTC file
    #print('Downloading RTC File')
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    bucket = 'opera-pst-rs-pop1'
    filename = s3key.split('/')[-1]
    filepath = f'./temp_{filename}/'+filename
    s3.download_file(bucket, s3key, filepath)

    #Change compression to DEFLATE and NBITS to 32
    #print('Translating compression')
    tempfile = f'./temp_{filename}/gtiff32.tif'
    outfile = f'./temp_{filename}/cog32deflate.tif'
    gdal_cmd1 = f'gdal_translate -of GTiff -co NBITS=32 {filepath} {tempfile}'
    gdal_cmd2 = f'gdal_translate -of COG -co COMPRESS=DEFLATE -co RESAMPLING=AVERAGE {tempfile} {outfile}'
    subprocess.run(gdal_cmd1,shell=True,stdout=subprocess.DEVNULL)
    subprocess.run(gdal_cmd2,shell=True,stdout=subprocess.DEVNULL)
    metadata = os.popen(f'gdalinfo {filepath}').read()
    if metadata.split('ORBIT_PASS_DIRECTION=')[1].split('\n')[0] == 'ASCENDING':
        pass_d = 'A'
    elif metadata.split('ORBIT_PASS_DIRECTION=')[1].split('\n')[0] == 'DESCENDING':
        pass_d = 'D'
    else:
        pass_d = 'N'

    #Upload to GCS bucket
    #print('Uploading to GCS Bucket')
    gcskey = gcskey.split('.tif')[0] + f'_{pass_d}.tif'
    gcsbucket = "opera-bucket-rtc"
    upload_blob(gcsbucket,outfile,gcskey)

    shutil.rmtree(f'./temp_{filename}/')

def run_rtc_transfer(keydict):
    try:
        start_time = time.time()
        s3key = keydict['s3key']
        gcskey = keydict['gcsKey']
        processRTC(s3key,gcskey)
        #print(f'[{time.time() - start_time}] Uploaded to: {gcskey}')
    except: 
        print(f'Failed on {s3key}')

if __name__ == '__main__':
    os.environ["GCLOUD_PROJECT"] = "opera-one"
    s3_prefix = 'products/int_fwd_r2/2023-05-04_globalrun_2021-04-11_to_2021-04-22/RTC_S1/'
    gcs_prefix = 'products/2023-05-04_globalrun_2021-04-11_to_2021-04-22/'
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket='opera-pst-rs-pop1', Prefix=s3_prefix, Delimiter='/')
    keyList = []
    for page in pages:
        #pprint(page)
        for obj in page['CommonPrefixes']:
            path = obj.get('Prefix')
            if path[-2] != 's':  #checks if end is not "static_layers"
                fname = path.split('/')[-2]+'_VH.tif'
                keyList.append(path+fname)
    print(f'{len(keyList)} s3 keys found')


    storage_client = storage.Client()
    blobs = storage_client.list_blobs("opera-bucket-rtc", prefix=gcs_prefix)
    gcsKeys = []
    for blob in blobs:
        gcsKeys.append(blob.name.split('.tif')[0][:-2]+'.tif')
    print(f'{len(gcsKeys)} existing gcs keys found')

    keyPairs = []
    for key in keyList:
        fname = key.split('/')[-1]
        gcsKey = gcs_prefix+fname
        if gcsKey not in gcsKeys:
            keydict = {'s3key':key,'gcsKey':gcsKey}
            keyPairs.append(keydict)
    print(f'{len(keyPairs)} key pairs identified')
    pool = mp.Pool(mp.cpu_count())
    run_rtc_transfer(keyPairs[0])
    pool.map(run_rtc_transfer,keyPairs)
    pool.close()
