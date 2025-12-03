mod prerequisites
mod e2e-with-product-id-time
mod dist-s1-polarization-switch-for-a-track
mod dist-s1-single-polarization
mod e2e-hist

# Run all DIST-S1 tests
all:
    #!/usr/bin/env bash
    set -e
    echo "Running all DIST-S1 tests..."
    echo ""
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time
    just dist-s1::dist-s1-single-polarization
    just dist-s1::dist-s1-polarization-switch-for-a-track
    just dist-s1::e2e-hist
    echo ""
    echo "All DIST-S1 tests completed."
