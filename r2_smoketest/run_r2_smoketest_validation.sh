# Arguments: CSLC version, RTC version, S3 R3 location, release
# for example: 0.4.0, 0.4.1, opera-int-rs-fwd, 2.0.0-rc.10.0
cslc_v=$1
rtc_v=$2
s3_rs=$3
release=$4

# Submit query job
python3 ~/mozart/ops/opera-pcm/data_subscriber/daac_data_subscriber.py query -c SENTINEL-1A_SLC --release-version=${release} --processing-mode=reprocessing --job-queue=opera-job_worker-slc_data_download --chunk-size=1 --native-id=S1A_IW_SLC__1SDV_20220501T015035_20220501T015102_043011_0522A4_42CC*

# Download and unzip gold files.
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_cslc_s1_calval_${cslc_v}.zip
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_rtc_s1_calval_${rtc_v}.zip
unzip deployment_smoke_test_rtc_s1_calval_${rtc_v}.zip
unzip deployment_smoke_test_cslc_s1_calval_${cslc_v}.zip

echo "Sleeping 1 hr initially for the SCIFLO PGE jobs to complete..."
sleep 3600

# Download output files
mkdir output_dir_rtc output_dir_cslc

# Poll for 28 rtc products. RTC PGE runs faster than CSLC so we poll and copy these first.
while [ 28 -ne `aws s3 ls s3://${s3_rs}/products/RTC_S1/ --recursive | grep "OPERA_L2_RTC-S1_T064.*h5$" | wc -l` ]
do
        echo "Sleeping 5 mins waiting for RTC products..."
        sleep 300
done
echo "Sleeping 2 mins to make sure all files have transferred to S3"
sleep 120

echo "Copying down RTC products from S3"
cd output_dir_rtc
aws s3 cp s3://${s3_rs}/products/RTC_S1/ $(pwd) --recursive --exclude "OPERA_L2_RTC-S1-STATIC*" --include "OPERA_L2_RTC-S1_T064*"

# Poll for 28 cslc products
while [ 28 -ne `aws s3 ls s3://${s3_rs}/products/CSLC_S1/ --recursive | grep "OPERA_L2_CSLC-S1_T064.*h5$" | wc -l` ]
do
        echo "Sleeping 5 mins waiting for CSLC products..."
        sleep 300
done
echo "Sleeping another 2 mins to make sure all files have transferred to S3"
sleep 120

echo "Copying down CSLC products from S3"
cd ../output_dir_cslc
aws s3 cp s3://${s3_rs}/products/CSLC_S1/ $(pwd) --recursive --exclude "OPERA_L2_CSLC-S1-STATIC*" --include "OPERA_L2_CSLC-S1_T064*"

cd ..

# Run comparisons
echo "Comparing RTC products against gold files"
./rtc_compare.sh ./output_dir_rtc ./deployment_smoke_test_rtc_s1_calval_${rtc_v} | grep "file: OPERA_L2_RTC-S1_T064"

echo "Comparing CSLC products against gold files"
./cslc_compare.sh ./output_dir_cslc ./deployment_smoke_test_cslc_s1_calval_${cslc_v}