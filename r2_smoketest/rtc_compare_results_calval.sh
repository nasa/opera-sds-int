#!/bin/bash

declare -a burst_ids=(  "t064_135518_iw1"
                        "t064_135518_iw2"
                        "t064_135518_iw3"
                        "t064_135519_iw1"
                        "t064_135519_iw2"
                        "t064_135519_iw3"
                        "t064_135520_iw1"
                        "t064_135520_iw2"
                        "t064_135520_iw3"
                        "t064_135521_iw1"
                        "t064_135521_iw2"
                        "t064_135521_iw3"
                        "t064_135522_iw1"
                        "t064_135522_iw2"
                        "t064_135522_iw3"
                        "t064_135523_iw1"
                        "t064_135523_iw2"
                        "t064_135523_iw3"
                        "t064_135524_iw1"
                        "t064_135524_iw2"
                        "t064_135524_iw3"
                        "t064_135525_iw1"
                        "t064_135525_iw2"
                        "t064_135525_iw3"
                        "t064_135526_iw1"
                        "t064_135526_iw2"
                        "t064_135526_iw3"
                        "t064_135527_iw1")

for burst_id in "${burst_ids[@]}"; do
  echo "-------------------------------------"
  echo "Comparing results for ${burst_id}"
  
  burst_id_uppercase=${burst_id^^}
  burst_id_replace_underscores=${burst_id_uppercase//_/-}
  burst_id_pattern="*_${burst_id_replace_underscores}_*"
  
  output_file=$(ls ./output_dir_rtc/${burst_id_pattern}/*.h5)
  expected_file=$(ls ./deployment_smoke_test_rtc_s1_calval_0.4/expected_output_data/${burst_id_pattern}/*.h5)

  echo "expected_file: ${expected_file}"
  echo "output_file: ${output_file}"
  python3 rtc_compare_calval.py ${expected_file} ${output_file}
done
