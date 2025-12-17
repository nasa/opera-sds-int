# DIST-S1 Single Polarization Test
#
# This test validates DIST-S1 processing for single polarization scenarios
# using track 51QTA_1 with timestamp 20241029T100014Z
#
# Usage:
#   just dist-s1::dist-s1-single-polarization
#
# Note: All actual commands (curl, daac_data_subscriber.py, etc.) are logged
#       by the underlying e2e-with-product-id-time test with debug output
#

# Main test for single polarization scenario
dist-s1-single-polarization:
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
    echo "DIST-S1 Single Polarization Test"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Testing single polarization scenario for track 51QTA_1"
    echo "Timestamp: 20241029T100014Z"
    echo "==================================================================="
    echo ""

    timestamp "Starting single polarization test..."
    # Reuse the existing e2e-with-product-id-time test with specific parameters
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 51QTA_1 20241029T100014Z
    timestamp "Single polarization test completed"

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
