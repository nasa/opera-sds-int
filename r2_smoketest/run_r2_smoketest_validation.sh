mkdir -p smoketest/product/cslc smoketest/product/rtc
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_cslc_s1_calval_0.3.1.zip
wget https://artifactory-fn.jpl.nasa.gov:443/artifactory/general-stage/gov/nasa/jpl/opera/sds/pcm/testdata_R2.0.0/deployment_smoke_test_rtc_s1_calval_0.4.zip
unzip deployment_smoke_test_rtc_s1_calval_0.4.zip
unzip deployment_smoke_test_cslc_s1_calval_0.3.1.zip

cd product/rtc
aws s3 cp s3://opera-int-rs-fwd/products/RTC_S1/ $(pwd) --recursive --exclude "*" --include "OPERA_L2_RTC-S1_T064*"

cd ../cslc
aws s3 cp s3://opera-int-rs-fwd/products/CSLC_S1/ $(pwd) --recursive --exclude "*"  --include "OPERA_L2_CSLC-S1A_IW_*"

