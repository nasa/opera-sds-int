# Common helper functions for VNV test framework

# Validate OPERA_SDS_BASE_URL
# Assumes the environment variable is already exported by the user
# Only runs validation when DRY_RUN is false
validate-opera-sds-url:
    #!/usr/bin/env bash
    set -e
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

# Validate NASA_CMR_BASE_URL
# Assumes the environment variable is already exported by the user
# Only runs validation when DRY_RUN is false
validate-cmr-url:
    #!/usr/bin/env bash
    set -e
    if [ "${DRY_RUN:-false}" = "false" ]; then
        if [[ ! "$NASA_CMR_BASE_URL" =~ ^https?:// ]]; then
            echo "❌ NASA_CMR_BASE_URL must include protocol (http:// or https://)"
            exit 1
        fi
    fi

# Get the count of DIST S1 products on OPERA SDS mozart
sds-get-product-count:
    #!/usr/bin/env bash
    just dist-s1::helpers::validate-opera-sds-url
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
    just dist-s1::helpers::validate-cmr-url
    cmd="curl -si \"\${NASA_CMR_BASE_URL}/search/granules.json?collection_concept_id=\${OPERA_COLLECTION_ID}&page_size=0\""
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        count=$(curl -si "$NASA_CMR_BASE_URL/search/granules.json?collection_concept_id=$OPERA_COLLECTION_ID&page_size=0" | grep -i 'CMR-Hits:' | awk '{print $2}' | tr -d '\r')
        echo "$count OPERA_L3 DIST S1 products found in CMR"
    fi

# Get latest DIST S1 product's RTC list from OPERA SDS mozart
sds-get-latest-product-rtc-input-products:
    #!/usr/bin/env bash
    just dist-s1::helpers::validate-opera-sds-url
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
    just dist-s1::helpers::validate-opera-sds-url
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
