# DIST-S1 Anti-Meridian Test Template

# Main test for anti-meridian scenario
dist-s1-anti-meridian:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 Anti-Meridian Test"

    # Get initial product counts
    just dist-s1::e2e-with-product-id-time::sds-get-product-count
    just dist-s1::e2e-with-product-id-time::daac-get-product-count

    # Function to run a batch of commands
    run_batch() {
        local batch_name=$1
        shift
        echo "💻 Executing $batch_name"
        for cmd in "$@"; do
            if [ "${DRY_RUN:-false}" = "true" ]; then
                echo "💻 Dry run: $cmd"
            else
                eval "$cmd"
            fi
        done
    }

    # Batch 1: TODO - Add daac_data_subscriber.py commands here
    run_batch "batch1" \
        # "daac_data_subscriber.py query --collection-shortname=OPERA_L2_RTC-S1_V1 --product=DIST_S1 --endpoint=OPS ..." \
        # "daac_data_subscriber.py query --collection-shortname=OPERA_L2_RTC-S1_V1 --product=DIST_S1 --endpoint=OPS ..." \
        # "daac_data_subscriber.py query --collection-shortname=OPERA_L2_RTC-S1_V1 --product=DIST_S1 --endpoint=OPS ..."

    # Wait for user input
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: Skipping user input prompt"
    else
        echo "Press Enter to continue with the next batch..."
        read -r
    fi

    # Batch 2: TODO - Add daac_data_subscriber.py commands here
    run_batch "batch2" \
        # "daac_data_subscriber.py query --collection-shortname=OPERA_L2_RTC-S1_V1 --product=DIST_S1 --endpoint=OPS ..." \
        # "daac_data_subscriber.py query --collection-shortname=OPERA_L2_RTC-S1_V1 --product=DIST_S1 --endpoint=OPS ..." \
        # "daac_data_subscriber.py query --collection-shortname=OPERA_L2_RTC-S1_V1 --product=DIST_S1 --endpoint=OPS ..."

    # Get final product counts
    just dist-s1::e2e-with-product-id-time::sds-get-product-count
    just dist-s1::e2e-with-product-id-time::daac-get-product-count
