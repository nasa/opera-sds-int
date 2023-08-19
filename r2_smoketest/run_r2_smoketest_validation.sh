# Arguments: CSLC version, RTC version, S3 R3 location
# for example: 0.4.0, 0.4.1, opera-int-rs-fwd

cslc_v=$1
rtc_v=$2
s3_rs=$3
release=$4

# TODO: Add query job here and then a s3 rs poll later on
#2.0.0-rc.10.0
# python3 daac_data_subscriber.py query -c SENTINEL-1A_SLC --release-version=${release} --processing-mode=reprocessing --job-queue=opera-job_worker-slc_data_download --chunk-size=1 --native-id=S1A_IW_SLC__1SDH_20230628T122652_20230628T122722_049186_05EA20_0BC9*

# Install COMPASS
git clone https://github.com/opera-adt/COMPASS.git
yes | conda install -c conda-forge --file COMPASS/requirements.txt
yes | python -m pip install git+https://github.com/opera-adt/s1-reader.git
python -m pip install ./COMPASS

# Download comparison scripts.
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/cslc_compare_results_calval_${cslc_v}.sh
chmod +x cslc_compare_results_calval_${cslc_v}.sh
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/validate_cslc_product_calval_${cslc_v}.py
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/rtc_compare_results_calval_${rtc_v}.sh
chmod +x rtc_compare_results_calval_${rtc_v}.sh
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/rtc_compare_calval_${rtc_v}.py

# Download and unzip gold files.
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_cslc_s1_calval_${cslc_v}.zip
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_rtc_s1_calval_${rtc_v}.zip
unzip deployment_smoke_test_rtc_s1_calval_${rtc_v}.zip
unzip deployment_smoke_test_cslc_s1_calval_${cslc_v}.zip

# Download output files
mkdir output_dir_rtc output_dir_cslc

# TODO: poll for all rtc products here
# aws s3 ls s3://${s3_rs}/products/RTC_S1/ --recursive | grep OPERA_L2_RTC-S1_T064.*h5$ | wc -l
# loop and poll every minute for ALL files to exist

cd output_dir_rtc
aws s3 cp s3://${s3_rs}/products/RTC_S1/ $(pwd) --recursive --exclude "OPERA*_static_layers" --include "OPERA_L2_RTC-S1_T064*"

# TODO: poll for all cslc products here
# aws s3 ls s3://${s3_rs}/products/CSLC_S1/ --recursive | grep OPERA_L2_CSLC-S1A_IW_.*h5$ | wc -l
# loop and poll every minute for ALL files to exist

cd ../output_dir_cslc
aws s3 cp s3://${s3_rs}/products/CSLC_S1/ $(pwd) --recursive --exclude "OPERA*_static_layers"  --include "OPERA_L2_CSLC-S1A_IW_*"
cd ..

# Run comparisons
./rtc_compare_results_calval_${rtc_v}.sh | grep FAIL
./cslc_compare_results_calval_${cslc_v}.sh | grep failed

