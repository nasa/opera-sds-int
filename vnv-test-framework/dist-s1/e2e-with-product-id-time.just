# Test Generation of products with the given --product-id-time in the command line
#
# Usage:
#   just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time <TILE_ID> <TIMESTAMP>
#
# Example:
#   just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 11SLT_0 20250614T015042Z
#   just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 01WDU_5 20220101T051815Z
#
# Note: All commands are logged with dimmed gray output showing the exact command being executed
#
# Default values for backward compatibility
DEFAULT_TILE := "11SLT_0"
DEFAULT_TIMESTAMP := "20250614T015042Z"

# Debug output styling - change these to adjust command logging appearance
DEBUG_COLOR := "\\033[2m\\033[90m"  # Dim dark gray color
RESET_COLOR := "\\033[0m"           # Reset color
DEBUG_PREFIX := "🔧 Running:"

# Main test with variable tile and timestamp
e2e-with-product-id-time TILE=DEFAULT_TILE TIMESTAMP=DEFAULT_TIMESTAMP:
    #!/usr/bin/env bash
    set -e
    echo "==================================================================="
    echo "DIST-S1 E2E Test with --product-id-time"
    echo "==================================================================="
    echo "Product ID: {{TILE}}"
    echo "Timestamp: {{TIMESTAMP}}"
    echo "==================================================================="
    echo ""
    echo "=== Initial DAAC Product Count ==="
    daac_output_before=$(just dist-s1::e2e-with-product-id-time::daac-get-product-count 2>&1)
    echo "$daac_output_before"
    daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')
    echo ""
    echo "=== Initial SDS Product Count ==="
    sds_output_before=$(just dist-s1::e2e-with-product-id-time::sds-get-product-count 2>&1)
    echo "$sds_output_before"
    sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')
    echo ""
    echo "=== Submitting Job ==="
    just dist-s1::e2e-with-product-id-time::sds-submit-job {{TILE}} {{TIMESTAMP}}
    echo ""
    echo "=== Waiting 20 minutes for job completion ==="
    sleep 1200
    echo ""
    echo "=== Latest Product RTC Inputs ==="
    just dist-s1::e2e-with-product-id-time::sds-get-latest-product-rtc-input-products
    echo ""
    echo "=== Latest Product S3 URLs ==="
    just dist-s1::e2e-with-product-id-time::sds-get-latest-product-s3-product-urls
    echo ""
    echo "=== Final SDS Product Count ==="
    sds_output_after=$(just dist-s1::e2e-with-product-id-time::sds-get-product-count 2>&1)
    echo "$sds_output_after"
    sds_count_after=$(echo "$sds_output_after" | awk '{print $1}')
    echo ""
    echo "=== Final DAAC Product Count ==="
    daac_output_after=$(just dist-s1::e2e-with-product-id-time::daac-get-product-count 2>&1)
    echo "$daac_output_after"
    daac_count_after=$(echo "$daac_output_after" | awk '{print $1}')
    echo ""
    echo "==================================================================="
    echo "RESULTS"
    echo "==================================================================="
    if [ "$sds_count_before" = "$sds_count_after" ]; then
        echo "❌ ERROR: No products were generated on SDS (count unchanged: $sds_count_before)"
        exit 1
    fi
    if [ "$daac_count_before" = "$daac_count_after" ]; then
        echo "❌ ERROR: No new products were delivered to DAAC (count unchanged: $daac_count_before)"
        exit 1
    fi
    echo "✅ SUCCESS: Products generated and delivered"
    echo "   Product ID: {{TILE}}"
    echo "   Timestamp: {{TIMESTAMP}}"
    echo "   SDS: $sds_count_before -> $sds_count_after (+" $((sds_count_after - sds_count_before)) ")"
    echo "   DAAC: $daac_count_before -> $daac_count_after (+" $((daac_count_after - daac_count_before)) ")"
    echo "==================================================================="

# Submit DIST S1 job with product id time (now with variable parameters)
sds-submit-job TILE=DEFAULT_TILE TIMESTAMP=DEFAULT_TIMESTAMP:
    #!/usr/bin/env bash

    # Function to run command with debug output
    run_cmd() {
        echo -e "  {{DEBUG_COLOR}}{{DEBUG_PREFIX}} $*{{RESET_COLOR}}" >&2
        "$@"
    }

    echo "Submitting job for product-id-time: {{TILE}},{{TIMESTAMP}}"
    if run_cmd daac_data_subscriber.py query \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --product=DIST_S1 \
        --endpoint=OPS \
        --job-queue=opera-job_worker-rtc_for_dist_data_download \
        --chunk-size=1 \
        --use-temporal \
        --transfer-protocol=auto \
        --processing-mode=reprocessing \
        --product-id-time={{TILE}},{{TIMESTAMP}}; then
        echo "✅ Successfully submitted job"
    else
        echo "❌ Failed to submit job"
        exit 1
    fi

# Get latest DIST S1 product's RTC list from OPERA SDS mozart
sds-get-latest-product-rtc-input-products:
    #!/usr/bin/env bash

    # Function to run command with debug output
    run_cmd() {
        echo -e "  {{DEBUG_COLOR}}{{DEBUG_PREFIX}} $*{{RESET_COLOR}}" >&2
        "$@"
    }

    if [ -z "$OPERA_SDS_BASE_URL" ]; then
        echo "❌ ERROR: OPERA_SDS_BASE_URL environment variable is not set"
        echo "Please set it to your OPERA SDS instance URL (e.g., https://your-opera-sds.example.com)"
        exit 1
    fi
    if [[ ! "$OPERA_SDS_BASE_URL" =~ ^https?:// ]]; then
        echo "❌ ERROR: OPERA_SDS_BASE_URL must include protocol (http:// or https://)"
        echo "Current value: $OPERA_SDS_BASE_URL"
        echo "Example: https://opera-int-mozart-fwd.jpl.nasa.gov"
        exit 1
    fi
    response=$(run_cmd curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq_v0.1_l3_dist_s1-*/_search" -X POST -H 'Content-Type: application/json' --data-binary @grq-latest-dist-s1.json)
    hit_count=$(echo "$response" | jq -r '.hits.total.value // .hits.total // 0')
    if [ "$hit_count" -eq 0 ]; then  # lol the variable name
        echo "No DIST S1 products found - job may still be processing"
    else
        rtc_inputs=$(echo "$response" | jq -r '.hits.hits[0]._source.metadata.Files[0].runconfig.input_file_group.pre_rtc_copol | to_entries[] | .value')
        rtc_count=$(echo "$rtc_inputs" | wc -l)
        echo -e "{{DEBUG_COLOR}}$rtc_inputs{{RESET_COLOR}}"
        echo "Total RTC input products: $rtc_count"
    fi

# Get latest DIST S1 product's S3 URL list from OPERA SDS mozart
sds-get-latest-product-s3-product-urls:
    #!/usr/bin/env bash

    # Function to run command with debug output
    run_cmd() {
        echo -e "  {{DEBUG_COLOR}}{{DEBUG_PREFIX}} $*{{RESET_COLOR}}" >&2
        "$@"
    }

    if [ -z "$OPERA_SDS_BASE_URL" ]; then
        echo "❌ ERROR: OPERA_SDS_BASE_URL environment variable is not set"
        echo "Please set it to your OPERA SDS instance URL (e.g., https://your-opera-sds.example.com)"
        exit 1
    fi
    if [[ ! "$OPERA_SDS_BASE_URL" =~ ^https?:// ]]; then
        echo "❌ ERROR: OPERA_SDS_BASE_URL must include protocol (http:// or https://)"
        echo "Current value: $OPERA_SDS_BASE_URL"
        echo "Example: https://opera-int-mozart-fwd.jpl.nasa.gov"
        exit 1
    fi
    response=$(run_cmd curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq_v0.1_l3_dist_s1-*/_search" -X POST -H 'Content-Type: application/json' --data-binary @grq-latest-dist-s1.json)
    hit_count=$(echo "$response" | jq -r '.hits.total.value // .hits.total // 0')
    if [ "$hit_count" -eq 0 ]; then
        echo "No DIST S1 products found - job may still be processing"
    else
        product_urls=$(echo "$response" | jq -r '.hits.hits[0]._source.metadata.product_urls[]')
        url_count=$(echo "$product_urls" | wc -l)
        echo -e "{{DEBUG_COLOR}}$product_urls{{RESET_COLOR}}"
        echo "Total product URLs: $url_count"
    fi

# Get the count of DIST S1 products on OPERA SDS mozart
sds-get-product-count:
    #!/usr/bin/env bash

    # Function to run command with debug output
    run_cmd() {
        echo -e "  {{DEBUG_COLOR}}{{DEBUG_PREFIX}} $*{{RESET_COLOR}}" >&2
        "$@"
    }

    if [ -z "$OPERA_SDS_BASE_URL" ]; then
        echo "❌ ERROR: OPERA_SDS_BASE_URL environment variable is not set"
        echo "Please set it to your OPERA SDS instance URL (e.g., https://your-opera-sds.example.com)"
        exit 1
    fi
    if [[ ! "$OPERA_SDS_BASE_URL" =~ ^https?:// ]]; then
        echo "❌ ERROR: OPERA_SDS_BASE_URL must include protocol (http:// or https://)"
        echo "Current value: $OPERA_SDS_BASE_URL"
        echo "Example: https://opera-int-mozart-fwd.jpl.nasa.gov"
        exit 1
    fi
    response=$(run_cmd curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq/_msearch?" -X POST -H 'Content-Type: application/x-ndjson' -H 'Accept: application/json' --data-binary @sds-product-count.json)
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "❌ ERROR: Invalid response from OPERA SDS (not valid JSON)"
        echo "URL: $OPERA_SDS_BASE_URL/grq_es/grq/_msearch?"
        echo "Response: $response"
        exit 1
    fi
    count=$(echo "$response" | jq -r '.responses[0].hits.total.value // .responses[0].hits.total')
    echo "$count DIST S1 products currently exist on the system"

# Query NASA CMR for OPERA_L3 DIST S1 product count
daac-get-product-count:
    #!/usr/bin/env bash

    # Function to run command with debug output
    run_cmd() {
        echo -e "  {{DEBUG_COLOR}}{{DEBUG_PREFIX}} $*{{RESET_COLOR}}" >&2
        "$@"
    }

    # Set defaults for public NASA CMR information (can be overridden via environment variables)
    NASA_CMR_BASE_URL="${NASA_CMR_BASE_URL:-https://cmr.uat.earthdata.nasa.gov}"
    OPERA_COLLECTION_ID="${OPERA_COLLECTION_ID:-C1275699124-ASF}"

    if [[ ! "$NASA_CMR_BASE_URL" =~ ^https?:// ]]; then
        echo "❌ ERROR: NASA_CMR_BASE_URL must include protocol (http:// or https://)"
        echo "Current value: $NASA_CMR_BASE_URL"
        echo "Example: https://cmr.earthdata.nasa.gov"
        exit 1
    fi
    count=$(run_cmd curl -si "$NASA_CMR_BASE_URL/search/granules.json?collection_concept_id=$OPERA_COLLECTION_ID&page_size=0" | grep -i 'CMR-Hits:' | awk '{print $2}' | tr -d '\r')
    echo "$count OPERA_L3 DIST S1 products found in CMR"
