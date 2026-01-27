# DIST-S1 Polarization Switch for a Track Test - validates polarization switching scenarios

# Main test for polarization switch scenario
polarization-switch-test:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 Polarization Switch for a Track Test"
    echo "💻 Testing polarization switch scenario for track 20TLP_3 at 20250919T102312Z"
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time 20TLP_3 20250919T102312Z