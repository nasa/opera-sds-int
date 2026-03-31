# DIST-S1 E2E Historical Processing Test - parameterized by date range

# Default values (2026-01-01 full-day test)
DEFAULT_START_DATE := "2026-01-01T00:00:00Z"
DEFAULT_END_DATE := "2026-01-01T23:59:59Z"
DEFAULT_EXPECTED_PRODUCT_COUNT := "10"
DEFAULT_SLEEP_SECONDS := "43200"

# Main test for historical processing with configurable date range
e2e-hist-date-range START_DATE=DEFAULT_START_DATE END_DATE=DEFAULT_END_DATE EXPECTED_PRODUCT_COUNT=DEFAULT_EXPECTED_PRODUCT_COUNT SLEEP_SECONDS=DEFAULT_SLEEP_SECONDS:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 E2E Historical Processing Test"
    echo "💻 Date Range: {{START_DATE}} to {{END_DATE}} (Expected: {{EXPECTED_PRODUCT_COUNT}} products)"
    sds_output_before=$(just dist-s1::helpers::sds-get-product-count 2>&1)
    echo "$sds_output_before"
    sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')
    daac_output_before=$(just dist-s1::helpers::daac-get-product-count 2>&1)
    echo "$daac_output_before"
    daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')
    just dist-s1::e2e-hist-date-range::sds-submit-hist-job {{START_DATE}} {{END_DATE}}
    sleep_seconds={{SLEEP_SECONDS}}
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
sds-submit-hist-job START_DATE=DEFAULT_START_DATE END_DATE=DEFAULT_END_DATE:
    #!/usr/bin/env bash
    echo "💻 Submitting historical processing job for date range: {{START_DATE}} to {{END_DATE}}"
    cmd="daac_data_subscriber.py query \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --product=DIST_S1 \
        --endpoint=OPS \
        --start-date={{START_DATE}} \
        --end-date={{END_DATE}} \
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
