mod helpers
mod prerequisites
mod e2e-with-product-id-time
mod dist-s1-polarization-switch-for-a-track
mod dist-s1-single-polarization
mod dist-s1-anti-meridian
mod e2e-hist-small
mod e2e-hist
mod dist-job-status-check
mod e2e-fwd
mod dist-s1-ec2-destruction

# Run all DIST-S1 tests
all:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running all DIST-S1 tests..."
    just dist-s1::e2e-with-product-id-time::e2e-with-product-id-time
    just dist-s1::dist-s1-single-polarization
    just dist-s1::dist-s1-polarization-switch-for-a-track
    just dist-s1::dist-s1-anti-meridian
    just dist-s1::e2e-hist-small
    just dist-s1::e2e-hist
    just dist-s1::e2e-fwd
    just dist-s1::dist-s1-ec2-destruction::ec2-destruction-test
    echo "💻 All DIST-S1 tests completed."
