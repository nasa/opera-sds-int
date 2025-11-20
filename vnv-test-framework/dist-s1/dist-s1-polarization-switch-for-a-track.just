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
    echo "==================================================================="
    echo "DIST-S1 Polarization Switch for a Track Test"
    echo "==================================================================="
    echo "Testing polarization switch scenario for track 20TLP_3"
    echo "Timestamp: 20250919T102312Z"
    echo "==================================================================="
    echo ""

    # Reuse the existing e2e-with-product-id-time test with specific parameters
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 20TLP_3 20250919T102312Z