# DIST-S1 EC2 Worker Node Destruction Test - validates job recovery after worker node termination

# Default working directory for test artifacts
DEFAULT_WORK_DIR := "/tmp/ec2-destruction-test"

# Main test for EC2 worker node destruction scenario
ec2-destruction-test WORK_DIR=DEFAULT_WORK_DIR:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 EC2 Worker Node Destruction Test"
    echo "💻 Work directory: {{WORK_DIR}}"
    VNV_FRAMEWORK_DIR="$(cd "$(dirname "{{justfile()}}")" && pwd)"
    SCRIPT_DIR="$(cd "$(dirname "{{source_file()}}")" && pwd)"
    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: ${SCRIPT_DIR}/ec2-destruction-test.sh {{WORK_DIR}} ${VNV_FRAMEWORK_DIR}"
    else
        "${SCRIPT_DIR}/ec2-destruction-test.sh" "{{WORK_DIR}}" "${VNV_FRAMEWORK_DIR}"
    fi
