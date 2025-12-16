# Prerequisites helper commands for DIST-S1 testing
#
# These commands help gather the information needed to run other tests

# Survey RTC-S1 granules from CMR for a date range
#
# Usage:
#   just dist-s1::prerequisites::survey-rtc-granules <START_DATE> <END_DATE> <OUTPUT_FILE>
#
# Example:
#   just dist-s1::prerequisites::survey-rtc-granules 2024-10-01T00:00:00Z 2024-10-31T23:59:59Z /tmp/rtc_oct.csv
#   just dist-s1::prerequisites::survey-rtc-granules 2022-01-01T00:00:00Z 2022-01-31T23:59:59Z /tmp/rtc_jan_2022.csv
#
survey-rtc-granules START_DATE END_DATE OUTPUT_FILE:
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
    echo "Surveying RTC-S1 Granules from CMR"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Start Date: {{START_DATE}}"
    echo "End Date: {{END_DATE}}"
    echo "Output File: {{OUTPUT_FILE}}"
    echo "==================================================================="
    echo ""

    timestamp "Starting CMR survey..."
    if daac_data_subscriber.py survey \
        --collection-shortname=OPERA_L2_RTC-S1_V1 \
        --endpoint=OPS \
        --start-date={{START_DATE}} \
        --end-date={{END_DATE}} \
        --out-csv={{OUTPUT_FILE}}; then
        timestamp "Survey completed successfully"
        echo ""
        echo "✅ Survey completed successfully"
        echo ""
        echo "Output files created:"
        echo "  Summary: {{OUTPUT_FILE}}"
        echo "  Raw granule list: {{OUTPUT_FILE}}.raw.csv"
        echo ""
        echo "To view granule count:"
        echo "  wc -l {{OUTPUT_FILE}}.raw.csv"
    else
        timestamp "Survey failed"
        echo "❌ Survey failed"
        exit 1
    fi

    # Calculate duration
    END_TIME=$(date +%s)
    END_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    DURATION_HUMAN=$(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)

    echo ""
    echo "==================================================================="
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="

# Trigger granules for a specific tile from survey results
#
# Usage:
#   just dist-s1::prerequisites::trigger-granules <TILE_ID> <RAW_CSV_FILE>
#
# Example:
#   just dist-s1::prerequisites::trigger-granules 11SLT /tmp/rtc_oct.csv.raw.csv
#   just dist-s1::prerequisites::trigger-granules 01WDU /tmp/rtc_jan_2022.csv.raw.csv
#
# Note: Use the .raw.csv file from the survey command!
#
trigger-granules TILE_ID RAW_CSV_FILE:
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
    echo "Triggering Granules for Tile {{TILE_ID}}"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Input File: {{RAW_CSV_FILE}}"
    echo "==================================================================="
    echo ""

    timestamp "Checking input file..."
    if [ ! -f "{{RAW_CSV_FILE}}" ]; then
        echo "❌ ERROR: File not found: {{RAW_CSV_FILE}}"
        echo ""
        echo "Make sure you run survey-rtc-granules first and use the .raw.csv file"
        exit 1
    fi

    timestamp "Running dist_s1_burst_db_tool.py..."
    echo ""

    if dist_s1_burst_db_tool.py trigger_granules {{RAW_CSV_FILE}} --tile-to-trigger={{TILE_ID}}; then
        timestamp "Trigger analysis completed"
        echo ""
        echo "✅ Trigger analysis completed"
        echo ""
        echo "Look for output lines like:"
        echo "  product_id='{{TILE_ID}}_X_YYY' YYYY-MM-DD HH:MM:SS ..."
        echo ""
        echo "Use the product_id and timestamp for your test:"
        echo "  just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time <PRODUCT_ID> <TIMESTAMP>"
    else
        timestamp "Trigger analysis failed"
        echo "❌ Trigger analysis failed"
        exit 1
    fi

    # Calculate duration
    END_TIME=$(date +%s)
    END_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    DURATION_HUMAN=$(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)

    echo ""
    echo "==================================================================="
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="

# Check what acquisition groups exist for a tile
#
# Usage:
#   just dist-s1::prerequisites::check-tile <TILE_ID>
#
# Example:
#   just dist-s1::prerequisites::check-tile 11SLT
#   just dist-s1::prerequisites::check-tile 01WDU
#
check-tile TILE_ID:
    #!/usr/bin/env bash

    # Capture start time
    START_TIME=$(date +%s)
    START_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')

    # Helper function to print timestamp
    timestamp() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    }

    echo "==================================================================="
    echo "Checking Tile: {{TILE_ID}}"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "==================================================================="
    echo ""

    timestamp "Querying tile information..."
    if dist_s1_burst_db_tool.py tile_id {{TILE_ID}}; then
        timestamp "Tile information retrieved successfully"
        echo ""
        echo "✅ Tile information retrieved"
    else
        timestamp "Failed to get tile information"
        echo "❌ Failed to get tile information"
        echo ""
        echo "Possible reasons:"
        echo "  - Tile ID doesn't exist in DIST-S1 burst database"
        echo "  - Typo in tile ID"
        exit 1
    fi

    # Calculate duration
    END_TIME=$(date +%s)
    END_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    DURATION_HUMAN=$(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)

    echo ""
    echo "==================================================================="
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="

# Get product-id-time from a specific RTC granule ID
#
# Usage:
#   just dist-s1::prerequisites::get-product-id-from-granule <GRANULE_ID>
#
# Example:
#   just dist-s1::prerequisites::get-product-id-from-granule OPERA_L2_RTC-S1_T066-140035-IW2_20220101T051815Z_20241216T224934Z_S1A_30_v1.0
#
get-product-id-from-granule GRANULE_ID:
    #!/usr/bin/env bash

    # Capture start time
    START_TIME=$(date +%s)
    START_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')

    # Helper function to print timestamp
    timestamp() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    }

    echo "==================================================================="
    echo "Getting Product ID from Granule"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Granule ID: {{GRANULE_ID}}"
    echo "==================================================================="
    echo ""

    timestamp "Querying granule information..."
    if dist_s1_burst_db_tool.py native_id {{GRANULE_ID}}; then
        timestamp "Product ID information retrieved successfully"
        echo ""
        echo "✅ Product ID information retrieved"
        echo ""
        echo "Look for lines starting with '--product-id-time:' above"
        echo "Use those values for your test"
    else
        timestamp "Failed to get product ID"
        echo "❌ Failed to get product ID"
        exit 1
    fi

    # Calculate duration
    END_TIME=$(date +%s)
    END_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    DURATION_HUMAN=$(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)

    echo ""
    echo "==================================================================="
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="

# Complete workflow: Survey → Find tile products → Show test commands
#
# Usage:
#   just dist-s1::prerequisites::workflow <TILE_ID> <START_DATE> <END_DATE> <OUTPUT_FILE>
#
# Example:
#   just dist-s1::prerequisites::workflow 11SLT 2024-06-01T00:00:00Z 2024-06-30T23:59:59Z /tmp/rtc_test.csv
#   just dist-s1::prerequisites::workflow 01WDU 2022-01-01T00:00:00Z 2022-01-31T23:59:59Z /tmp/rtc_arctic.csv
#
workflow TILE_ID START_DATE END_DATE OUTPUT_FILE:
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
    echo "DIST-S1 Test Prerequisites Workflow"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Tile: {{TILE_ID}}"
    echo "Date Range: {{START_DATE}} to {{END_DATE}}"
    echo "==================================================================="
    echo ""

    timestamp "Step 1: Checking tile information..."
    just dist-s1::prerequisites::check-tile {{TILE_ID}}
    timestamp "Step 1 completed"
    echo ""

    timestamp "Step 2: Surveying RTC granules..."
    just dist-s1::prerequisites::survey-rtc-granules {{START_DATE}} {{END_DATE}} {{OUTPUT_FILE}}
    timestamp "Step 2 completed"
    echo ""

    timestamp "Step 3: Triggering granules for tile {{TILE_ID}}..."
    just dist-s1::prerequisites::trigger-granules {{TILE_ID}} {{OUTPUT_FILE}}.raw.csv
    timestamp "Step 3 completed"
    echo ""

    # Calculate duration
    END_TIME=$(date +%s)
    END_TIME_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    SECONDS=$((DURATION % 60))
    DURATION_HUMAN=$(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)

    echo "==================================================================="
    echo "✅ Workflow completed!"
    echo "==================================================================="
    echo ""
    echo "Next steps:"
    echo "  1. Review the trigger_granules output above"
    echo "  2. Pick a product_id and timestamp from the output"
    echo "  3. Run your test:"
    echo "     just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time <PRODUCT_ID> <TIMESTAMP>"
    echo ""
    echo "==================================================================="
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="
