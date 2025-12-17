# DIST-S1 E2E Historical Processing Test
#
# This test validates DIST-S1 historical processing using date range queries
# Date Range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z
# Expected Products: 582
#
# Usage:
#   just dist-s1::e2e-hist
#
# Note: All actual commands (curl, daac_data_subscriber.py, etc.) are logged
#       with debug output showing the exact command being executed
#

# Expected number of products for this test
EXPECTED_PRODUCT_COUNT := "582"

# Debug output styling - consistent with other tests
DEBUG_COLOR := "\\033[2m\\033[90m"  # Dim dark gray color
RESET_COLOR := "\\033[0m"           # Reset color
DEBUG_PREFIX := "🔧 Running:"

# Main test for historical processing
e2e-hist:
    #!/usr/bin/env bash
    set -e

    # Capture start time
    START_TIME=$(date +%s)
    START_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')

    # Helper function to print timestamp
    timestamp() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    }

    echo "==================================================================="
    echo "DIST-S1 E2E Historical Processing Test"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Date Range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z"
    echo "Expected Products: {{EXPECTED_PRODUCT_COUNT}}"
    echo "==================================================================="
    echo ""

    timestamp "Getting initial DAAC product count..."
    echo "=== Initial DAAC Product Count ==="
    daac_output_before=$(just dist-s1::e2e-with-product-id-time::daac-get-product-count 2>&1)
    echo "$daac_output_before"
    daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')
    echo ""

    timestamp "Getting initial SDS product count..."
    echo "=== Initial SDS Product Count ==="
    sds_output_before=$(just dist-s1::e2e-with-product-id-time::sds-get-product-count 2>&1)
    echo "$sds_output_before"
    sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')
    echo ""

    timestamp "Submitting historical processing job..."
    echo "=== Submitting Historical Processing Job ==="
    just dist-s1::e2e-hist::sds-submit-hist-job
    echo ""

    timestamp "Waiting 12 hours for job completion..."
    echo "=== Waiting 12 hours for job completion ==="
    sleep 43200
    timestamp "Wait completed"
    echo ""

    timestamp "Getting latest product RTC inputs..."
    echo "=== Latest Product RTC Inputs ==="
    just dist-s1::e2e-with-product-id-time::sds-get-latest-product-rtc-input-products
    echo ""

    timestamp "Getting latest product S3 URLs..."
    echo "=== Latest Product S3 URLs ==="
    just dist-s1::e2e-with-product-id-time::sds-get-latest-product-s3-product-urls
    echo ""

    timestamp "Getting final SDS product count..."
    echo "=== Final SDS Product Count ==="
    sds_output_after=$(just dist-s1::e2e-with-product-id-time::sds-get-product-count 2>&1)
    echo "$sds_output_after"
    sds_count_after=$(echo "$sds_output_after" | awk '{print $1}')
    echo ""

    timestamp "Getting final DAAC product count..."
    echo "=== Final DAAC Product Count ==="
    daac_output_after=$(just dist-s1::e2e-with-product-id-time::daac-get-product-count 2>&1)
    echo "$daac_output_after"
    daac_count_after=$(echo "$daac_output_after" | awk '{print $1}')
    echo ""

    # Calculate duration
    END_TIME=$(date +%s)
    END_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    DURATION_HUMAN=$(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)

    timestamp "Validating results..."
    echo "==================================================================="
    echo "RESULTS"
    echo "==================================================================="

    # Calculate deltas
    sds_delta=$((sds_count_after - sds_count_before))
    daac_delta=$((daac_count_after - daac_count_before))

    # Check if products were generated
    if [ "$sds_count_before" = "$sds_count_after" ]; then
        echo "❌ ERROR: No products were generated on SDS (count unchanged: $sds_count_before)"
        exit 1
    fi

    # Check if products were delivered
    if [ "$daac_count_before" = "$daac_count_after" ]; then
        echo "❌ ERROR: No new products were delivered to DAAC (count unchanged: $daac_count_before)"
        exit 1
    fi

    # Check if the delta matches expected count
    if [ "$sds_delta" != "{{EXPECTED_PRODUCT_COUNT}}" ]; then
        echo "⚠️  WARNING: SDS product count delta ($sds_delta) does not match expected ({{EXPECTED_PRODUCT_COUNT}})"
    fi

    echo "✅ SUCCESS: Products generated and delivered"
    echo "   Date Range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z"
    echo "   SDS: $sds_count_before -> $sds_count_after (+$sds_delta)"
    echo "   DAAC: $daac_count_before -> $daac_count_after (+$daac_delta)"
    echo "   Expected: {{EXPECTED_PRODUCT_COUNT}} products"
    echo "==================================================================="
    echo ""
    echo "==================================================================="
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="

# Submit DIST S1 historical processing job with date range
sds-submit-hist-job:
    #!/usr/bin/env bash

    # Function to run command with debug output
    run_cmd() {
        echo -e "  {{DEBUG_COLOR}}{{DEBUG_PREFIX}} $*{{RESET_COLOR}}" >&2
        "$@"
    }

    echo "Submitting historical processing job for date range: 2025-07-10T02:00:00Z to 2025-07-10T07:00:00Z"
    if run_cmd daac_data_subscriber.py query \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --product=DIST_S1 \
        --endpoint=OPS \
        --start-date=2025-07-10T02:00:00Z \
        --end-date=2025-07-10T07:00:00Z \
        --job-queue=opera-job_worker-rtc_for_dist_data_download \
        --chunk-size=1 \
        --use-temporal \
        --transfer-protocol=auto; then
        echo "✅ Successfully submitted historical processing job"
    else
        echo "❌ Failed to submit historical processing job"
        exit 1
    fi
