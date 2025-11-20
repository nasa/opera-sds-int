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
    echo "==================================================================="
    echo "DIST-S1 Single Polarization Test"
    echo "==================================================================="
    echo "Testing single polarization scenario for track 51QTA_1"
    echo "Timestamp: 20241029T100014Z"
    echo "==================================================================="
    echo ""

    # Reuse the existing e2e-with-product-id-time test with specific parameters
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 51QTA_1 20241029T100014Z
