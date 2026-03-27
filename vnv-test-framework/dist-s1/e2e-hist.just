# DIST-S1 E2E Historical Processing Test - validates historical processing using date range queries

# Expected number of products for this test
EXPECTED_PRODUCT_COUNT := "582"

# Main test for historical processing
e2e-hist:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 E2E Historical Processing Test"
    echo "💻 Date Range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z (Expected: {{EXPECTED_PRODUCT_COUNT}} products)"
    sds_output_before=$(just dist-s1::helpers::sds-get-product-count 2>&1)
    echo "$sds_output_before"
    sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')
    daac_output_before=$(just dist-s1::helpers::daac-get-product-count 2>&1)
    echo "$daac_output_before"
    daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')
    just dist-s1::e2e-hist::sds-submit-hist-job
    sleep_seconds=43200
    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: sleep $sleep_seconds seconds"
    else
        sleep $sleep_seconds
    fi
    just dist-s1::helpers::sds-get-latest-product-rtc-input-products
    just dist-s1::helpers::sds-get-latest-product-s3-product-urls
    sds_output_after=$(just dist-s1::helpers::sds-get-product-count 2>&1)
    echo "$sds_output_after"
    sds_count_after=$(echo "$sds_output_after" | awk '{print $1}')
    daac_output_after=$(just dist-s1::helpers::daac-get-product-count 2>&1)
    echo "$daac_output_after"
    daac_count_after=$(echo "$daac_output_after" | awk '{print $1}')
    if [ "$DRY_RUN" = "false" ]; then
        sds_delta=$((sds_count_after - sds_count_before))
        daac_delta=$((daac_count_after - daac_count_before))
        if [ "$sds_count_before" = "$sds_count_after" ]; then
            echo "❌ No products were generated on SDS (count unchanged: $sds_count_before)"
            exit 1
        fi
        if [ "$daac_count_before" = "$daac_count_after" ]; then
            echo "❌ No new products were delivered to DAAC (count unchanged: $daac_count_before)"
            exit 1
        fi
        if [ "$sds_delta" != "{{EXPECTED_PRODUCT_COUNT}}" ]; then
            echo "⚠️  WARNING: SDS product count delta ($sds_delta) does not match expected ({{EXPECTED_PRODUCT_COUNT}})"
        fi
        echo "✅ Products generated and delivered - SDS: $sds_count_before -> $sds_count_after (+$sds_delta), DAAC: $daac_count_before -> $daac_count_after (+$daac_delta)"
    fi

# Submit DIST S1 historical processing job with date range
sds-submit-hist-job:
    #!/usr/bin/env bash
    echo "💻 Submitting historical processing job for date range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z"
    cmd="daac_data_subscriber.py query \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --product=DIST_S1 \
        --endpoint=OPS \
        --start-date=2025-07-10T02:00:00Z \
        --end-date=2025-07-10T07:00:00Z \
        --job-queue=opera-job_worker-rtc_for_dist_data_download \
        --chunk-size=1 \
        --use-temporal \
        --transfer-protocol=auto"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        if eval "$cmd"; then
            echo "✅ Successfully submitted historical processing job"
        else
            echo "❌ Failed to submit historical processing job"
            exit 1
        fi
    fi
