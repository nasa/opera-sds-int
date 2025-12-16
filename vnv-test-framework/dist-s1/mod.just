mod prerequisites
mod e2e-with-product-id-time
mod dist-s1-polarization-switch-for-a-track
mod dist-s1-single-polarization
mod e2e-hist

# Run all DIST-S1 tests
all:
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
    echo "DIST-S1 Test Suite"
    echo "==================================================================="
    echo "Started: $START_TIME_HUMAN"
    echo "==================================================================="
    echo ""

    timestamp "Running all DIST-S1 tests..."
    echo ""

    timestamp "Starting e2e-with-product-id-time test"
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time
    timestamp "Completed e2e-with-product-id-time test"
    echo ""

    timestamp "Starting dist-s1-single-polarization test"
    just dist-s1::dist-s1-single-polarization
    timestamp "Completed dist-s1-single-polarization test"
    echo ""

    timestamp "Starting dist-s1-polarization-switch-for-a-track test"
    just dist-s1::dist-s1-polarization-switch-for-a-track
    timestamp "Completed dist-s1-polarization-switch-for-a-track test"
    echo ""

    timestamp "Starting e2e-hist test"
    just dist-s1::e2e-hist
    timestamp "Completed e2e-hist test"
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
    echo "EXECUTION SUMMARY"
    echo "==================================================================="
    echo "All DIST-S1 tests completed successfully"
    echo ""
    echo "Started:  $START_TIME_HUMAN"
    echo "Ended:    $END_TIME_HUMAN"
    echo "Duration: $DURATION_HUMAN (${DURATION}s)"
    echo "==================================================================="
