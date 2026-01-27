# DIST-S1 Single Polarization Test - validates single polarization scenarios

# Main test for single polarization scenario
dist-s1-single-polarization:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 Single Polarization Test"
    echo "💻 Testing single polarization scenario for track 51QTA_1 at 20241029T100014Z"
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 51QTA_1 20241029T100014Z
