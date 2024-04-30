#!/bin/bash

# Arguments: DSWx-S1 version, DISP-S1 version, S3 R3 location, release
# for example: gamma_0.3 DISP_S1_Version opera-int-rs-fwd 3.0.0-rc.4.0

set -e
umask 002

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

dswx_s1_v=$1
disp_s1_v=$2
s3_rs=$3
release=$4

# Submit query job
python3 ~/mozart/ops/opera-pcm/data_subscriber/daac_data_subscriber.py query -c OPERA_L2_RTC-S1_V1 --endpoint=OPS --release-version=${release} --job-queue=opera-job_worker-rtc_data_download --chunk-size=1 --transfer-protocol=auto --native-id=OPERA_L2_RTC-S1_T114-243001-IW3_20231213T121156Z_20231213T190239Z_S1A_30_v1.0*
# TODO submit DISP-S1 job

# Download and unzip gold files.
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R3.0.0/deployment_smoke_test_dswx_s1_${dswx_s1_v}.zip
unzip deployment_smoke_test_dswx_s1_${dswx_s1_v}.zip
# TODO Download and unzip expected DISP-S1 products

echo "Sleeping 60 min initially for the SCIFLO PGE jobs to complete..."
sleep 3600

# Download output files
mkdir output_dir_dswx output_dir_disp

# Poll for 17 DSWx-S1 products. DSWx-S1 PGE runs faster than DISP-S1 so we poll and copy these first.
while [ 17 -ne `aws s3 ls s3://${s3_rs}/products/DSWx_S1/ | grep "OPERA_L3_DSWx-S1_T4.*$" | wc -l` ]
do
  echo "Sleeping 5 mins waiting for DSWx products..."
  sleep 300
done
echo "Sleeping 2 mins to make sure all files have transferred to S3"
sleep 120

echo "Copying down DSWx-S1 products from S3"
cd output_dir_dswx
aws s3 cp s3://${s3_rs}/products/DSWx_S1/ $(pwd) --recursive --exclude "*" --include "OPERA_L3_DSWx-S1_T4*"

# TODO Poll and download DISP-S1 products

cd ..

# Run comparisons
echo "Comparing DSWx-S1 products against gold files"
expected=($(find ./deployment_smoke_test_dswx_s1_${dswx_s1_v} -maxdepth 1 -mindepth 1 -type d -printf "%f\n"))
output=($(find ./output_dir_dswx -maxdepth 1 -mindepth 1 -type d -printf "%f\n"))

# Point GDAL to the proj.db file it wants to load, this path assumes the script is being run on mozart
export PROJ_LIB=/export/home/hysdsops/conda/share/proj

for (( i=0; i<${#expected[@]}; i++ )); do
  python3 ${SCRIPT_DIR}/diff_dswx_files.py ./deployment_smoke_test_dswx_s1_${dswx_s1_v}/${expected[$i]} ./output_dir_dswx/${output[$i]} 2>&1 | tee -a ./deployment_smoke_test_dswx_s1_${dswx_s1_v}.log
done

# TODO compare output and expected DISP-S1 products
