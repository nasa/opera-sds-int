# DIST-S1 Polarization Switch for a Track Test
#
# This test validates DIST-S1 processing for polarization switching scenarios
# using track 20TLP_3 with timestamp 20250919T102312Z
#
# Usage:
#   just dist-s1::dist-s1-polarization-switch-for-a-track::polarization-switch-test
#
# Note: All actual commands (curl, daac_data_subscriber.py, etc.) are logged
#       by the underlying e2e-with-product-id-time test with debug output
#

# Main test for polarization switch scenario
polarization-switch-test:
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
    echo "DIST-S1 Polarization Switch for a Track Test"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "Testing polarization switch scenario for track 20TLP_3"
    echo "Timestamp: 20250919T102312Z"
    echo "==================================================================="
    echo ""

    timestamp "Starting polarization switch test..."
    # Reuse the existing e2e-with-product-id-time test with specific parameters
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 20TLP_3 20250919T102312Z
    timestamp "Polarization switch test completed"

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