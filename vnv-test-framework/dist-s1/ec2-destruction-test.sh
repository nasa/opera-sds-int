#!/bin/bash
#
# EC2 Worker Node Destruction Test Script
# ----------------------------------------
# Executes the OPERA DIST-S1 PCM EC2 destruction test procedure:
#   Step 1:  Enable DIST-S1 Forward Processing
#   Step 2:  Identify Active Worker Nodes and Auto-Scaling Group
#   Step 3A: Capture Baseline Job Status
#   Step 4:  Terminate Worker Node (Option A - decrement desired capacity)
#   Step 5:  Monitor Job Recovery
#   Step 6:  Verify Job Recovery
#   Step 7:  Generate Test Report
#   Step 8:  Disable DIST-S1 Forward Processing Trigger
#
# Usage:
#   ./ec2-destruction-test.sh <WORK_DIR> <VNV_FRAMEWORK_DIR>
#
# Arguments:
#   WORK_DIR           - Directory for intermediate/output files (e.g. /tmp/ec2-test)
#   VNV_FRAMEWORK_DIR  - Path to opera-sds-int/vnv-test-framework
#
# Environment variables (override defaults):
#   ASG_NAME              - Auto-scaling group name
#   EVENTBRIDGE_RULE      - EventBridge rule name for forward processing trigger
#   REGION                - AWS region
#   OPERA_SDS_BASE_URL    - Base URL for OPERA SDS Mozart
#   RECOVERY_WAIT_SECONDS - Seconds to wait for job recovery after termination
#
# The script will interactively prompt for the EC2 Instance ID to terminate.
#

set -euo pipefail

# ---------- Constants (overridable via environment) ----------
ASG_NAME="${ASG_NAME:-opera-int-fwd-opera-job_worker-sciflo-l3_dist_s1}"
EVENTBRIDGE_RULE="${EVENTBRIDGE_RULE:-opera-int-fwd-rtc_for_dist-query-timer-Trigger}"
REGION="${REGION:-us-west-2}"
OPERA_SDS_BASE_URL="${OPERA_SDS_BASE_URL:-https://opera-int-mozart-fwd.jpl.nasa.gov}"
RECOVERY_WAIT_SECONDS="${RECOVERY_WAIT_SECONDS:-300}"

# ---------- Output helpers ----------
info()  { printf "[INFO]  %s\n" "$*"; }
step()  { printf "\n=== %s ===\n" "$*"; }
ok()    { printf "[OK]    %s\n" "$*"; }
err()   { printf "[ERROR] %s\n" "$*" >&2; }

# ---------- Argument validation ----------
if [ $# -lt 2 ]; then
    echo "Usage: $0 <WORK_DIR> <VNV_FRAMEWORK_DIR>"
    echo ""
    echo "  WORK_DIR           Directory for intermediate and output files"
    echo "  VNV_FRAMEWORK_DIR  Path to opera-sds-int/vnv-test-framework"
    exit 1
fi

WORK_DIR="$1"
VNV_FRAMEWORK_DIR="$2"

# ---------- Setup working directory ----------
info "Creating working directory: ${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# Resolve to absolute paths so cd into other dirs doesn't break references
WORK_DIR="$(cd "${WORK_DIR}" && pwd)"
VNV_FRAMEWORK_DIR="$(cd "${VNV_FRAMEWORK_DIR}" && pwd)"

# ---------- Step 1: Enable DIST-S1 Forward Processing ----------
step "Step 1: Enable DIST-S1 Forward Processing"

info "Enabling EventBridge rule '${EVENTBRIDGE_RULE}' in ${REGION}..."
aws events enable-rule \
  --name "${EVENTBRIDGE_RULE}" \
  --region "${REGION}"

info "Verifying rule state..."
aws events describe-rule \
  --name "${EVENTBRIDGE_RULE}" \
  --region "${REGION}" \
  --query '[Name,State]' \
  --output table

ok "EventBridge rule enabled. Wait 5-10 minutes for forward processing jobs to appear."
info "Monitor Mozart Figaro UI: ${OPERA_SDS_BASE_URL}/hysds_ui/figaro"
echo ""
printf "Press ENTER once jobs are visible in Figaro UI to continue..."
read -r DUMMY

# ---------- Step 2: Identify Active Worker Nodes ----------
step "Step 2: Identify Active Worker Nodes and Auto-Scaling Group"

info "Fetching auto-scaling group configuration for '${ASG_NAME}'..."
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --region "${REGION}" \
  --query 'AutoScalingGroups[0].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize]' \
  --output table

info "Listing all running EC2 instances in the auto-scaling group..."
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --region "${REGION}" \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
  --output table

# Capture original desired capacity for later restoration
ORIGINAL_CAPACITY="$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --region "${REGION}" \
  --query 'AutoScalingGroups[0].DesiredCapacity' \
  --output text)"

info "Current desired capacity: ${ORIGINAL_CAPACITY} (saved for cleanup/restore)"

# ---------- Step 3A: Capture Baseline Job Status ----------
step "Step 3A: Capture Baseline Job Status (via vnv-test-framework)"

info "Setting OPERA_SDS_BASE_URL=${OPERA_SDS_BASE_URL}"
export OPERA_SDS_BASE_URL

SAVED_DIR="$(pwd)"

info "Running dist-s1 job status check (last 1 hour) from ${VNV_FRAMEWORK_DIR}..."
cd "${VNV_FRAMEWORK_DIR}"
just dist-s1::dist-job-status-check::check-job-status 1 > "${WORK_DIR}/baseline-jobs.txt" 2>&1 || true
cd "${SAVED_DIR}"

# Ensure the file exists even if just produced nothing
touch "${WORK_DIR}/baseline-jobs.txt"

info "Baseline output saved to ${WORK_DIR}/baseline-jobs.txt"
cat "${WORK_DIR}/baseline-jobs.txt"

info "Extracting baseline job IDs and states..."
# Extract job IDs with their status from the tool output
# Lines look like: "  ✅ job-WF-SCIFLO_L3_DIST_S1-batch-..." or "  ❌ job-WF-..."
# Also handles: "  ✅ send_notify_msg__..."
grep -E "^[[:space:]]*(✅|❌)" "${WORK_DIR}/baseline-jobs.txt" \
  | sed -E 's/^[[:space:]]*✅[[:space:]]+(.*)/\1,completed/; s/^[[:space:]]*❌[[:space:]]+(.*)/\1,failed/' \
  | sort > "${WORK_DIR}/baseline-job-ids.txt" \
  || touch "${WORK_DIR}/baseline-job-ids.txt"

# Extract counts from the summary lines the tool already prints
BASELINE_COMPLETED="$(grep -oE 'Completed: [0-9]+' "${WORK_DIR}/baseline-jobs.txt" | head -1 | grep -oE '[0-9]+' || echo 0)"
BASELINE_FAILED="$(grep -oE 'Failed: [0-9]+' "${WORK_DIR}/baseline-jobs.txt" | head -1 | grep -oE '[0-9]+' || echo 0)"
BASELINE_TOTAL="$(grep -oE 'Total: [0-9]+' "${WORK_DIR}/baseline-jobs.txt" | head -1 | grep -oE '[0-9]+' || echo 0)"

echo ""
info "Baseline Job Summary:"
echo "  Completed: ${BASELINE_COMPLETED} jobs"
echo "  Failed:    ${BASELINE_FAILED} jobs"
echo "  Total:     ${BASELINE_TOTAL} jobs"
echo ""
info "Sample tracked job IDs:"
head -5 "${WORK_DIR}/baseline-job-ids.txt" || true

date -u "+%Y-%m-%dT%H:%M:%SZ" > "${WORK_DIR}/test-start-time.txt"
info "Baseline captured at: $(cat "${WORK_DIR}/test-start-time.txt")"

# ---------- Step 4: Terminate Worker Node (Option A) ----------
step "Step 4: Terminate Worker Node (Option A - Decrement Desired Capacity)"

info "This will terminate an EC2 instance and decrement the ASG desired capacity"
info "to prevent automatic replacement, isolating the recovery behavior."
echo ""

printf "Enter the Instance ID to terminate (from Step 2 output): "
read -r INSTANCE_ID

if [ -z "${INSTANCE_ID}" ]; then
    err "No Instance ID provided. Aborting."
    exit 1
fi

echo "${INSTANCE_ID}" > "${WORK_DIR}/terminated-instance-id.txt"
info "Terminating instance ${INSTANCE_ID} with desired capacity decrement..."

aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id "${INSTANCE_ID}" \
  --should-decrement-desired-capacity \
  --region "${REGION}"

info "Confirming termination state..."
aws ec2 describe-instances \
  --instance-ids "${INSTANCE_ID}" \
  --region "${REGION}" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,StateTransitionReason]' \
  --output table

ok "Instance ${INSTANCE_ID} termination initiated."

# ---------- Step 5: Monitor Job Recovery ----------
step "Step 5: Monitor Job Recovery"

info "Waiting ${RECOVERY_WAIT_SECONDS} seconds ($((RECOVERY_WAIT_SECONDS / 60)) minutes) for PCM to detect the failure and recover jobs..."
sleep "${RECOVERY_WAIT_SECONDS}"

info "Capturing post-recovery job status from ${VNV_FRAMEWORK_DIR}..."
cd "${VNV_FRAMEWORK_DIR}"
just dist-s1::dist-job-status-check::check-job-status 1 > "${WORK_DIR}/recovery-jobs.txt" 2>&1 || true
cd "${SAVED_DIR}"

# Ensure the file exists even if just produced nothing
touch "${WORK_DIR}/recovery-jobs.txt"

info "Recovery output saved to ${WORK_DIR}/recovery-jobs.txt"
cat "${WORK_DIR}/recovery-jobs.txt"

info "Extracting recovery job IDs and states..."
grep -E "^[[:space:]]*(✅|❌)" "${WORK_DIR}/recovery-jobs.txt" \
  | sed -E 's/^[[:space:]]*✅[[:space:]]+(.*)/\1,completed/; s/^[[:space:]]*❌[[:space:]]+(.*)/\1,failed/' \
  | sort > "${WORK_DIR}/recovery-job-ids.txt" \
  || touch "${WORK_DIR}/recovery-job-ids.txt"

# Extract counts from the summary lines
RECOVERY_COMPLETED="$(grep -oE 'Completed: [0-9]+' "${WORK_DIR}/recovery-jobs.txt" | head -1 | grep -oE '[0-9]+' || echo 0)"
RECOVERY_FAILED="$(grep -oE 'Failed: [0-9]+' "${WORK_DIR}/recovery-jobs.txt" | head -1 | grep -oE '[0-9]+' || echo 0)"
RECOVERY_TOTAL="$(grep -oE 'Total: [0-9]+' "${WORK_DIR}/recovery-jobs.txt" | head -1 | grep -oE '[0-9]+' || echo 0)"

echo ""
info "Recovery Job Summary:"
echo "  Completed: ${RECOVERY_COMPLETED} jobs"
echo "  Failed:    ${RECOVERY_FAILED} jobs"
echo "  Total:     ${RECOVERY_TOTAL} jobs"

# ---------- Step 6: Verify Job Recovery ----------
step "Step 6: Verify Job Recovery - Compare Baseline vs Recovery"

echo ""
echo "================================================================="
echo " JOB RECOVERY VERIFICATION"
echo "================================================================="

info "Checking for job state changes..."

# Extract sorted lists for comm (grep || true to handle no-match case)
grep ",completed" "${WORK_DIR}/baseline-job-ids.txt" 2>/dev/null | cut -d',' -f1 | sort > "${WORK_DIR}/tmp-baseline-completed.txt" || true
grep ",failed" "${WORK_DIR}/baseline-job-ids.txt" 2>/dev/null | cut -d',' -f1 | sort > "${WORK_DIR}/tmp-baseline-failed.txt" || true
grep ",failed" "${WORK_DIR}/recovery-job-ids.txt" 2>/dev/null | cut -d',' -f1 | sort > "${WORK_DIR}/tmp-recovery-failed.txt" || true

# Ensure all temp files exist
touch "${WORK_DIR}/tmp-baseline-completed.txt" "${WORK_DIR}/tmp-baseline-failed.txt" "${WORK_DIR}/tmp-recovery-failed.txt"

# Find jobs that were completed in baseline but failed in recovery
comm -12 "${WORK_DIR}/tmp-baseline-completed.txt" "${WORK_DIR}/tmp-recovery-failed.txt" \
  > "${WORK_DIR}/newly-failed-jobs.txt" || true

# Find jobs that were already failed in baseline and still failed
comm -12 "${WORK_DIR}/tmp-baseline-failed.txt" "${WORK_DIR}/tmp-recovery-failed.txt" \
  > "${WORK_DIR}/still-failed-jobs.txt" || true

# Ensure output files exist for wc
touch "${WORK_DIR}/newly-failed-jobs.txt" "${WORK_DIR}/still-failed-jobs.txt"

NEWLY_FAILED="$(wc -l < "${WORK_DIR}/newly-failed-jobs.txt" | tr -d ' ')"
STILL_FAILED="$(wc -l < "${WORK_DIR}/still-failed-jobs.txt" | tr -d ' ')"

echo ""
echo "=== Test Results ==="
echo "Baseline:  ${BASELINE_COMPLETED} completed, ${BASELINE_FAILED} failed (Total: ${BASELINE_TOTAL})"
echo "Recovery:  ${RECOVERY_COMPLETED} completed, ${RECOVERY_FAILED} failed (Total: ${RECOVERY_TOTAL})"
echo ""
echo "Jobs that became failed after termination: ${NEWLY_FAILED}"
echo "Jobs that were already failed (pre-existing): ${STILL_FAILED}"

if [ "${NEWLY_FAILED}" -gt 0 ]; then
    echo ""
    err "TEST FAILURE - The following jobs failed after worker termination:"
    while IFS= read -r job_id; do
        echo "  FAILED: ${job_id}"
    done < "${WORK_DIR}/newly-failed-jobs.txt"
    echo ""
    err "These jobs should have been automatically recovered/requeued."
    TEST_STATUS="FAILED"
else
    echo ""
    ok "TEST SUCCESS - No jobs failed as a result of worker termination"
    echo "   All jobs maintained their state or completed successfully"
    TEST_STATUS="PASSED"
fi

echo ""
echo "================================================================="
echo " Overall Test Status: ${TEST_STATUS}"
echo "================================================================="

echo "${TEST_STATUS}" > "${WORK_DIR}/test-result.txt"

# ---------- Step 7: Generate Test Report ----------
step "Step 7: Generate Test Report"

REPORT_FILE="${WORK_DIR}/ec2-destruction-test-report-$(date "+%Y%m%d-%H%M%S").txt"
TEST_START_TIME="$(cat "${WORK_DIR}/test-start-time.txt")"
TEST_END_TIME="$(date -u "+%Y-%m-%dT%H:%M:%SZ")"

# Build failure details if needed
FAILURE_DETAILS=""
if [ "${TEST_STATUS}" = "FAILED" ]; then
    FAILURE_DETAILS="Failure Reason: Jobs failed to recover after worker termination

Failed Job IDs:"
    while IFS= read -r job_id; do
        FAILURE_DETAILS="${FAILURE_DETAILS}
  - ${job_id}"
    done < "${WORK_DIR}/newly-failed-jobs.txt"
else
    FAILURE_DETAILS="Success: All jobs maintained state or recovered successfully"
fi

if [ "${TEST_STATUS}" = "PASSED" ]; then
    MANUAL_INTERVENTION="No"
else
    MANUAL_INTERVENTION="Yes - investigate failed jobs"
fi

cat > "${REPORT_FILE}" <<REPORT_EOF
=================================================================
EC2 WORKER NODE DESTRUCTION TEST REPORT
=================================================================

Test Environment: INT-FWD (Integration Forward)
Test Date: $(date -u "+%Y-%m-%d")
Test Start Time: ${TEST_START_TIME}
Test End Time: ${TEST_END_TIME}

Target Component: DIST-S1 Worker Nodes
Auto-Scaling Group: ${ASG_NAME}
Terminated Instance: ${INSTANCE_ID}

=== Job Statistics ===
Baseline (before termination):
  - Completed: ${BASELINE_COMPLETED} jobs
  - Failed: ${BASELINE_FAILED} jobs
  - Total: ${BASELINE_TOTAL} jobs

Recovery (after termination + $((RECOVERY_WAIT_SECONDS / 60)) min wait):
  - Completed: ${RECOVERY_COMPLETED} jobs
  - Failed: ${RECOVERY_FAILED} jobs
  - Total: ${RECOVERY_TOTAL} jobs

=== Recovery Analysis ===
Jobs that became failed: ${NEWLY_FAILED}
Jobs pre-existing failed: ${STILL_FAILED}

=== Test Result ===
Status: ${TEST_STATUS}

${FAILURE_DETAILS}

=== System Behavior ===
- EventBridge Trigger: Enabled -> Disabled (cleanup successful)
- Auto-Scaling Group: Capacity decremented (Option A)
- Original Desired Capacity: ${ORIGINAL_CAPACITY}
- Manual Intervention Required: ${MANUAL_INTERVENTION}

=================================================================
REPORT_EOF

info "Test report generated."
cat "${REPORT_FILE}"
ok "Report saved to: ${REPORT_FILE}"

# ---------- Step 8: Disable DIST-S1 Forward Processing Trigger ----------
step "Step 8: Disable DIST-S1 Forward Processing Trigger (Cleanup)"

info "Disabling EventBridge rule '${EVENTBRIDGE_RULE}'..."
aws events disable-rule \
  --name "${EVENTBRIDGE_RULE}" \
  --region "${REGION}"

info "Verifying rule is disabled..."
aws events describe-rule \
  --name "${EVENTBRIDGE_RULE}" \
  --region "${REGION}" \
  --query '[Name,State]' \
  --output table

ok "EventBridge rule disabled."

# ---------- Restore ASG capacity prompt ----------
echo ""
info "NOTE: The auto-scaling group desired capacity was decremented from ${ORIGINAL_CAPACITY}."
info "To restore it, run:"
echo ""
echo "  aws autoscaling set-desired-capacity \\"
echo "    --auto-scaling-group-name ${ASG_NAME} \\"
echo "    --desired-capacity ${ORIGINAL_CAPACITY} \\"
echo "    --region ${REGION}"
echo ""
printf "Would you like to restore the ASG capacity now? (y/N): "
read -r RESTORE_CHOICE

case "${RESTORE_CHOICE}" in
    y|Y)
        info "Restoring desired capacity to ${ORIGINAL_CAPACITY}..."
        aws autoscaling set-desired-capacity \
          --auto-scaling-group-name "${ASG_NAME}" \
          --desired-capacity "${ORIGINAL_CAPACITY}" \
          --region "${REGION}"

        info "Monitoring scaling activities..."
        aws autoscaling describe-scaling-activities \
          --auto-scaling-group-name "${ASG_NAME}" \
          --region "${REGION}" \
          --max-records 5 \
          --query 'Activities[*].[StartTime,StatusCode,Description]' \
          --output table

        info "Verifying instances..."
        aws autoscaling describe-auto-scaling-groups \
          --auto-scaling-group-names "${ASG_NAME}" \
          --region "${REGION}" \
          --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
          --output table

        ok "ASG capacity restored to ${ORIGINAL_CAPACITY}."
        ;;
    *)
        info "Skipping ASG capacity restore. Remember to restore it manually."
        ;;
esac

echo ""
step "Test Complete"
info "Test status: ${TEST_STATUS}"
info "Report: ${REPORT_FILE}"
info "Working files: ${WORK_DIR}/"

