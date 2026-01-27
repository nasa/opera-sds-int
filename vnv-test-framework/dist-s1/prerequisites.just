# Prerequisites helper commands for DIST-S1 testing

# Survey RTC-S1 granules from CMR for a date range
survey-rtc-granules START_DATE END_DATE OUTPUT_FILE:
    #!/usr/bin/env bash
    set -e
    echo "💻 Surveying RTC-S1 granules: {{START_DATE}} to {{END_DATE}}"
    cmd="daac_data_subscriber.py survey \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --endpoint=OPS \
        --start-date={{START_DATE}} \
        --end-date={{END_DATE}} \
        --out-csv={{OUTPUT_FILE}}"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        if eval "$cmd"; then
            echo "✅ Survey completed - Output: {{OUTPUT_FILE}} and {{OUTPUT_FILE}}.raw.csv"
        else
            echo "❌ Survey failed"
            exit 1
        fi
    fi

# Trigger granules for a specific tile from survey results (use .raw.csv file)
trigger-granules TILE_ID RAW_CSV_FILE:
    #!/usr/bin/env bash
    set -e
    echo "💻 Triggering granules for tile {{TILE_ID}} from {{RAW_CSV_FILE}}"
    if [ ! -f "{{RAW_CSV_FILE}}" ]; then
        echo "❌ File not found: {{RAW_CSV_FILE}}"
        exit 1
    fi
    cmd="dist_s1_burst_db_tool.py trigger_granules {{RAW_CSV_FILE}} --tile-to-trigger={{TILE_ID}}"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        if eval "$cmd"; then
            echo "✅ Trigger analysis completed - Use product_id and timestamp from output above"
        else
            echo "❌ Trigger analysis failed"
            exit 1
        fi
    fi

# Check what acquisition groups exist for a tile
check-tile TILE_ID:
    #!/usr/bin/env bash
    echo "💻 Checking tile {{TILE_ID}}"
    cmd="dist_s1_burst_db_tool.py tile_id {{TILE_ID}}"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        if eval "$cmd"; then
            echo "✅ Tile information retrieved"
        else
            echo "❌ Failed to get tile information - tile may not exist in DIST-S1 burst database"
            exit 1
        fi
    fi

# Get product-id-time from a specific RTC granule ID
get-product-id-from-granule GRANULE_ID:
    #!/usr/bin/env bash
    echo "💻 Getting product ID from granule {{GRANULE_ID}}"
    cmd="dist_s1_burst_db_tool.py native_id {{GRANULE_ID}}"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: $cmd"
    else
        if eval "$cmd"; then
            echo "✅ Product ID information retrieved - Look for '--product-id-time:' lines above"
        else
            echo "❌ Failed to get product ID"
            exit 1
        fi
    fi

# Complete workflow: Survey → Find tile products → Show test commands
workflow TILE_ID START_DATE END_DATE OUTPUT_FILE:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 DIST-S1 Prerequisites Workflow - Tile: {{TILE_ID}}, Date Range: {{START_DATE}} to {{END_DATE}}"
    just dist-s1::prerequisites::check-tile {{TILE_ID}}
    just dist-s1::prerequisites::survey-rtc-granules {{START_DATE}} {{END_DATE}} {{OUTPUT_FILE}}
    just dist-s1::prerequisites::trigger-granules {{TILE_ID}} {{OUTPUT_FILE}}.raw.csv
    echo "✅ Workflow completed - Review trigger_granules output above and pick a product_id and timestamp"
