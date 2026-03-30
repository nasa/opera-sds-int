# DIST-S1 Forward Processing E2E Test
# Enables the EventBridge forward processing trigger, waits for jobs to complete,
# then verifies no jobs failed and new products were created on SDS and CMR.

# Environment variable defaults (overridable)
EVENTBRIDGE_RULE := env("EVENTBRIDGE_RULE", "opera-int-fwd-rtc_for_dist-query-timer-Trigger")
REGION := env("REGION", "us-west-2")
FWD_WAIT_SECONDS := env("FWD_WAIT_SECONDS", "10800")

# Main forward processing E2E test
e2e-fwd:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    echo "💻 Running test: DIST-S1 Forward Processing E2E Test"
    echo "💻 EventBridge rule: {{EVENTBRIDGE_RULE}}"
    echo "💻 Region: {{REGION}}"
    echo "💻 Wait time: {{FWD_WAIT_SECONDS}} seconds ($(({{FWD_WAIT_SECONDS}} / 60)) minutes)"
    echo ""

    # ── Step 1: Collect baseline counts and start time ──
    echo "=== Step 1: Collect baseline product counts and start time ==="

    sds_output_before=$(just dist-s1::helpers::sds-get-product-count 2>&1)
    echo "$sds_output_before"
    sds_count_before=$(echo "$sds_output_before" | awk '{print $1}')

    daac_output_before=$(just dist-s1::helpers::daac-get-product-count 2>&1)
    echo "$daac_output_before"
    daac_count_before=$(echo "$daac_output_before" | awk '{print $1}')

    test_start_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "💻 Test start time: $test_start_time"
    echo "💻 Baseline SDS count: $sds_count_before"
    echo "💻 Baseline CMR count: $daac_count_before"
    echo ""

    # ── Step 2: Enable forward processing trigger ──
    echo "=== Step 2: Enable forward processing trigger ==="

    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: aws events enable-rule --name {{EVENTBRIDGE_RULE}} --region {{REGION}}"
        echo "💻 Dry run: aws events describe-rule --name {{EVENTBRIDGE_RULE}} --region {{REGION}} --query '[Name,State]' --output table"
    else
        aws events enable-rule \
          --name "{{EVENTBRIDGE_RULE}}" \
          --region "{{REGION}}"
        echo "✅ EventBridge rule enabled"
        aws events describe-rule \
          --name "{{EVENTBRIDGE_RULE}}" \
          --region "{{REGION}}" \
          --query '[Name,State]' \
          --output table
    fi
    echo ""

    # ── Step 3: Wait, then disable trigger ──
    echo "=== Step 3: Wait {{FWD_WAIT_SECONDS}} seconds, then disable trigger ==="

    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: sleep {{FWD_WAIT_SECONDS}}"
    else
        echo "💻 Sleeping {{FWD_WAIT_SECONDS}} seconds ($(({{FWD_WAIT_SECONDS}} / 60)) minutes)..."
        sleep {{FWD_WAIT_SECONDS}}
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: aws events disable-rule --name {{EVENTBRIDGE_RULE}} --region {{REGION}}"
        echo "💻 Dry run: aws events describe-rule --name {{EVENTBRIDGE_RULE}} --region {{REGION}} --query '[Name,State]' --output table"
    else
        aws events disable-rule \
          --name "{{EVENTBRIDGE_RULE}}" \
          --region "{{REGION}}"
        echo "✅ EventBridge rule disabled"
        aws events describe-rule \
          --name "{{EVENTBRIDGE_RULE}}" \
          --region "{{REGION}}" \
          --query '[Name,State]' \
          --output table
    fi
    echo ""

    # ── Step 4: Check job statuses since test start ──
    echo "=== Step 4: Check job statuses since $test_start_time ==="

    job_output=$(just dist-s1::dist-job-status-check::check-job-status-since "$test_start_time" 2>&1)
    echo "$job_output"

    failed_count=$(echo "$job_output" | grep -oE 'Failed: [0-9]+' | head -1 | grep -oE '[0-9]+' || echo 0)
    echo ""

    # ── Step 5: Collect post-test counts ──
    echo "=== Step 5: Collect post-test product counts ==="

    sds_output_after=$(just dist-s1::helpers::sds-get-product-count 2>&1)
    echo "$sds_output_after"
    sds_count_after=$(echo "$sds_output_after" | awk '{print $1}')

    daac_output_after=$(just dist-s1::helpers::daac-get-product-count 2>&1)
    echo "$daac_output_after"
    daac_count_after=$(echo "$daac_output_after" | awk '{print $1}')

    echo "💻 Post-test SDS count: $sds_count_after"
    echo "💻 Post-test CMR count: $daac_count_after"
    echo ""

    # ── Step 6: Determine pass/fail ──
    echo "=== Step 6: Test Results ==="
    echo "================================================================="
    echo " FORWARD PROCESSING E2E TEST RESULTS"
    echo "================================================================="
    echo ""
    echo "SDS Products:  $sds_count_before -> $sds_count_after"
    echo "CMR Products:  $daac_count_before -> $daac_count_after"
    echo "Failed Jobs:   $failed_count"
    echo ""

    if [ "$DRY_RUN" = "true" ]; then
        echo "💻 Dry run: skipping pass/fail verification"
        echo "================================================================="
        exit 0
    fi

    test_passed=true

    if [ "$failed_count" -gt 0 ]; then
        echo "❌ FAIL: $failed_count job(s) failed during forward processing"
        test_passed=false
    fi

    if [ "$sds_count_after" -le "$sds_count_before" ]; then
        echo "❌ FAIL: No new DIST-S1 products on SDS (count unchanged: $sds_count_before)"
        test_passed=false
    else
        echo "✅ SDS products increased by $((sds_count_after - sds_count_before))"
    fi

    if [ "$daac_count_after" -le "$daac_count_before" ]; then
        echo "❌ FAIL: No new DIST-S1 products on CMR (count unchanged: $daac_count_before)"
        test_passed=false
    else
        echo "✅ CMR products increased by $((daac_count_after - daac_count_before))"
    fi

    echo ""
    if [ "$test_passed" = "true" ]; then
        echo "✅ TEST PASSED - Forward processing completed successfully"
        echo "================================================================="
        exit 0
    else
        echo "❌ TEST FAILED - See failures above"
        echo "================================================================="
        exit 1
    fi
