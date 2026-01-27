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
    just dist-s1::e2e-with-product-id-time::daac-get-product-count
    just dist-s1::e2e-with-product-id-time::sds-get-product-count
    just dist-s1::e2e-with-product-id-time::sds-submit-job {{TILE}} {{TIMESTAMP}}
    sleep_seconds=1800
    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: sleep $sleep_seconds seconds"
    else
        sleep $sleep_seconds
    fi
    just dist-s1::e2e-with-product-id-time::sds-get-latest-product-rtc-input-products
    just dist-s1::e2e-with-product-id-time::sds-get-latest-product-s3-product-urls
    just dist-s1::e2e-with-product-id-time::sds-get-product-count
    just dist-s1::e2e-with-product-id-time::daac-get-product-count
    if [ "$DRY_RUN" = "false" ]; then
        daac_output_before=$(just dist-s1::e2e-with-product-id-time::daac-get-product-count 2>&1)
        daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')
        sds_output_before=$(just dist-s1::e2e-with-product-id-time::sds-get-product-count 2>&1)
        sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')
        sds_output_after=$(just dist-s1::e2e-with-product-id-time::sds-get-product-count 2>&1)
        sds_count_after=$(echo "$sds_output_after" | awk '{print $1}')
        daac_output_after=$(just dist-s1::e2e-with-product-id-time::daac-get-product-count 2>&1)
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

# Get latest DIST S1 product's RTC list from OPERA SDS mozart
sds-get-latest-product-rtc-input-products:
    #!/usr/bin/env bash
    if [ "${DRY_RUN:-false}" = "false" ]; then
        if [ -z "$OPERA_SDS_BASE_URL" ]; then
            echo "❌ OPERA_SDS_BASE_URL environment variable is not set"
            exit 1
        fi
        if [[ ! "$OPERA_SDS_BASE_URL" =~ ^https?:// ]]; then
            echo "❌ OPERA_SDS_BASE_URL must include protocol (http:// or https://)"
            exit 1
        fi
    fi
    cmd="curl -sk \"\${OPERA_SDS_BASE_URL}/grq_es/grq_v0.1_l3_dist_s1-*/_search\" -X POST -H 'Content-Type: application/json' --data-binary @grq-latest-dist-s1.json"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        response=$(curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq_v0.1_l3_dist_s1-*/_search" -X POST -H 'Content-Type: application/json' --data-binary @grq-latest-dist-s1.json)
        hit_count=$(echo "$response" | jq -r '.hits.total.value // .hits.total // 0')
        if [ "$hit_count" -eq 0 ]; then
            echo "No DIST S1 products found - job may still be processing"
        else
            rtc_inputs=$(echo "$response" | jq -r '.hits.hits[0]._source.metadata.Files[0].runconfig.input_file_group.pre_rtc_copol | to_entries[] | .value')
            rtc_count=$(echo "$rtc_inputs" | wc -l)
            echo "$rtc_inputs"
            echo "💻 Total RTC input products: $rtc_count"
        fi
    fi

# Get latest DIST S1 product's S3 URL list from OPERA SDS mozart
sds-get-latest-product-s3-product-urls:
    #!/usr/bin/env bash
    if [ "${DRY_RUN:-false}" = "false" ]; then
        if [ -z "$OPERA_SDS_BASE_URL" ]; then
            echo "❌ OPERA_SDS_BASE_URL environment variable is not set"
            exit 1
        fi
        if [[ ! "$OPERA_SDS_BASE_URL" =~ ^https?:// ]]; then
            echo "❌ OPERA_SDS_BASE_URL must include protocol (http:// or https://)"
            exit 1
        fi
    fi
    cmd="curl -sk \"\${OPERA_SDS_BASE_URL}/grq_es/grq_v0.1_l3_dist_s1-*/_search\" -X POST -H 'Content-Type: application/json' --data-binary @grq-latest-dist-s1.json"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        response=$(curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq_v0.1_l3_dist_s1-*/_search" -X POST -H 'Content-Type: application/json' --data-binary @grq-latest-dist-s1.json)
        hit_count=$(echo "$response" | jq -r '.hits.total.value // .hits.total // 0')
        if [ "$hit_count" -eq 0 ]; then
            echo "No DIST S1 products found - job may still be processing"
        else
            product_urls=$(echo "$response" | jq -r '.hits.hits[0]._source.metadata.product_urls[]')
            url_count=$(echo "$product_urls" | wc -l)
            echo "$product_urls"
            echo "💻 Total product URLs: $url_count"
        fi
    fi

# Get the count of DIST S1 products on OPERA SDS mozart
sds-get-product-count:
    #!/usr/bin/env bash
    if [ "${DRY_RUN:-false}" = "false" ]; then
        if [ -z "$OPERA_SDS_BASE_URL" ]; then
            echo "❌ OPERA_SDS_BASE_URL environment variable is not set"
            exit 1
        fi
        if [[ ! "$OPERA_SDS_BASE_URL" =~ ^https?:// ]]; then
            echo "❌ OPERA_SDS_BASE_URL must include protocol (http:// or https://)"
            exit 1
        fi
    fi
    cmd="curl -sk \"\${OPERA_SDS_BASE_URL}/grq_es/grq/_msearch?\" -X POST -H 'Content-Type: application/x-ndjson' -H 'Accept: application/json' --data-binary @sds-product-count.json"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        response=$(curl -sk "$OPERA_SDS_BASE_URL/grq_es/grq/_msearch?" -X POST -H 'Content-Type: application/x-ndjson' -H 'Accept: application/json' --data-binary @sds-product-count.json)
        if ! echo "$response" | jq . >/dev/null 2>&1; then
            echo "❌ Invalid response from OPERA SDS (not valid JSON)"
            exit 1
        fi
        count=$(echo "$response" | jq -r '.responses[0].hits.total.value // .responses[0].hits.total')
        echo "$count DIST S1 products currently exist on the system"
    fi

# Query NASA CMR for OPERA_L3 DIST S1 product count
daac-get-product-count:
    #!/usr/bin/env bash
    NASA_CMR_BASE_URL="${NASA_CMR_BASE_URL:-https://cmr.uat.earthdata.nasa.gov}"
    OPERA_COLLECTION_ID="${OPERA_COLLECTION_ID:-C1275699124-ASF}"
    if [ "${DRY_RUN:-false}" = "false" ]; then
        if [[ ! "$NASA_CMR_BASE_URL" =~ ^https?:// ]]; then
            echo "❌ NASA_CMR_BASE_URL must include protocol (http:// or https://)"
            exit 1
        fi
    fi
    cmd="curl -si \"\${NASA_CMR_BASE_URL:-https://cmr.uat.earthdata.nasa.gov}/search/granules.json?collection_concept_id=\${OPERA_COLLECTION_ID:-C1275699124-ASF}&page_size=0\""
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        count=$(curl -si "$NASA_CMR_BASE_URL/search/granules.json?collection_concept_id=$OPERA_COLLECTION_ID&page_size=0" | grep -i 'CMR-Hits:' | awk '{print $2}' | tr -d '\r')
        echo "$count OPERA_L3 DIST S1 products found in CMR"
    fi
