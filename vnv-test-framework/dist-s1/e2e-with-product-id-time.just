# Test Generation of products with the given --product-id-time in the command line

# Default values for backward compatibility
DEFAULT_TILE := "11SLT_0"
DEFAULT_TIMESTAMP := "20250614T015042Z"

# Main test with variable tile and timestamp
e2e-with-product-id-time TILE=DEFAULT_TILE TIMESTAMP=DEFAULT_TIMESTAMP:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 E2E Test with --product-id-time"
    echo "💻 Product ID: {{TILE}}, Timestamp: {{TIMESTAMP}}"
    just dist-s1::helpers::daac-get-product-count
    just dist-s1::helpers::sds-get-product-count
    just dist-s1::e2e-with-product-id-time::sds-submit-job {{TILE}} {{TIMESTAMP}}
    sleep_seconds=1800
    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: sleep $sleep_seconds seconds"
    else
        sleep $sleep_seconds
    fi
    just dist-s1::helpers::sds-get-latest-product-rtc-input-products
    just dist-s1::helpers::sds-get-latest-product-s3-product-urls
    just dist-s1::helpers::sds-get-product-count
    just dist-s1::helpers::daac-get-product-count
    if [ "$DRY_RUN" = "false" ]; then
        daac_output_before=$(just dist-s1::helpers::daac-get-product-count 2>&1)
        daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')
        sds_output_before=$(just dist-s1::helpers::sds-get-product-count 2>&1)
        sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')
        sds_output_after=$(just dist-s1::helpers::sds-get-product-count 2>&1)
        sds_count_after=$(echo "$sds_output_after" | awk '{print $1}')
        daac_output_after=$(just dist-s1::helpers::daac-get-product-count 2>&1)
        daac_count_after=$(echo "$daac_output_after" | awk '{print $1}')
        if [ "$sds_count_before" = "$sds_count_after" ]; then
            echo "❌ No products were generated on SDS (count unchanged: $sds_count_before)"
            exit 1
        fi
        if [ "$daac_count_before" = "$daac_count_after" ]; then
            echo "❌ No new products were delivered to DAAC (count unchanged: $daac_count_before)"
            exit 1
        fi
        echo "✅ Products generated and delivered - SDS: $sds_count_before -> $sds_count_after (+" $((sds_count_after - sds_count_before)) "), DAAC: $daac_count_before -> $daac_count_after (+" $((daac_count_after - daac_count_before)) ")"
    fi

# Submit DIST S1 job with product id time (now with variable parameters)
sds-submit-job TILE=DEFAULT_TILE TIMESTAMP=DEFAULT_TIMESTAMP:
    #!/usr/bin/env bash
    echo "💻 Submitting job for product-id-time: {{TILE}},{{TIMESTAMP}}"
    cmd="daac_data_subscriber.py query \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --product=DIST_S1 \
        --endpoint=OPS \
        --job-queue=opera-job_worker-rtc_for_dist_data_download \
        --chunk-size=1 \
        --use-temporal \
        --transfer-protocol=auto \
        --processing-mode=reprocessing \
        --product-id-time={{TILE}},{{TIMESTAMP}}"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        if eval "$cmd"; then
            echo "✅ Successfully submitted job"
        else
            echo "❌ Failed to submit job"
            exit 1
        fi
    fi
