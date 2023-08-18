# Install COMPASS
git clone https://github.com/opera-adt/COMPASS.git
conda install -c conda-forge --file COMPASS/requirements.txt
yes | python -m pip install git+https://github.com/opera-adt/s1-reader.git
python -m pip install ./COMPASS

# Download and unzip gold files
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_cslc_s1_calval_0.3.1.zip
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_rtc_s1_calval_0.4.zip
unzip deployment_smoke_test_rtc_s1_calval_0.4.zip
unzip deployment_smoke_test_cslc_s1_calval_0.3.1.zip

# Download output files
# TODO: Fix exclude so that we don't download static files. Static files aren't part of the PGE smoke test
mkdir output_dir_rtc output_dir_cslc
cd output_dir_rtc
aws s3 cp s3://opera-int-rs-fwd/products/RTC_S1/ $(pwd) --recursive --exclude "OPERA*_static_layers" --include "OPERA_L2_RTC-S1_T064*"
cd ../output_dir_cslc
aws s3 cp s3://opera-int-rs-fwd/products/CSLC_S1/ $(pwd) --recursive --exclude "OPERA*_static_layers"  --include "OPERA_L2_CSLC-S1A_IW_*"
cd ..

# Run comparisons
rtc_compare_results_calval.sh | grep FAIL
cslc_compare_results_calval.sh | grep failed
