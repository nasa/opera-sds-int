#!/usr/bin/env python3

import os
import sys
import time
import boto3
import subprocess

'''Example of how to run this program:
python3 opera_pcm_granule_test.py DSWx-S1 3.0.0-er.3.0 opera-int-rs-fwd'''

product_type = sys.argv[1]
release_version = sys.argv[2]
s3_bucket = sys.argv[3]

_product_to_params = {
    "DSWx-S1": {
        "collection": "OPERA_L2_RTC-S1_V1",
        "queue": "opera-job_worker-rtc_data_download",
        "s3_folder": "DSWx_S1",
        "granule": "OPERA_L2_RTC-S1_T148-316855-IW2_20231004T204706Z_20231005T232451Z_S1A_30_v1.0",
        "product_count": 17
    }
}

params = _product_to_params[product_type]

# Run data subscriber
cmd = f'python3 ~/mozart/ops/opera-pcm/data_subscriber/daac_data_subscriber.py query \
-c {params["collection"]} \
--release-version={release_version} \
--job-queue={params["queue"]} --chunk-size 1 --native-id={params["granule"]}'
subprocess.run(cmd, shell=True, check=True)

# Sleep for 30 mins because it will at least take that long for processing to complete
print("Sleeping for 30 mins...")
time.sleep(1800)

client = boto3.client('s3')
while True:
    response = client.list_objects_v2(
        Bucket=s3_bucket,
        Prefix=f'products/{params["s3_folder"]}/')

    # print the numer of files in the bucket
    print(len(response.get('Contents', [])))

    for content in response.get('Contents', []):
        print(content['Key'])

    #TODO: If we have the correct number of products, we are done

    time.sleep(300)