# Check DIST job statuses for jobs in last X hours or since timestamp

DEFAULT_HOURS := "24"

_query-and-display SINCE_TIME DESCRIPTION:
    #!/usr/bin/env bash
    set -e
    SINCE_TIME="{{SINCE_TIME}}"
    DESCRIPTION="{{DESCRIPTION}}"
    just dist-s1::helpers::validate-opera-sds-url
    query_file=$(mktemp)
    sed "s/SINCE_TIME_PLACEHOLDER/$SINCE_TIME/g" job-status-query-template.json > "$query_file"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "💻 Dry run: curl -sk \"\${OPERA_SDS_BASE_URL}/grq_es/job_status-*/_search\" -X POST -H 'Content-Type: application/json' --data-binary @$query_file"
        echo "💻 Query content:"
        cat "$query_file"
        rm -f "$query_file"
    else
        response=$(curl -sk "$OPERA_SDS_BASE_URL/grq_es/job_status-*/_search" -X POST -H 'Content-Type: application/json' --data-binary @"$query_file")
        rm -f "$query_file"
        total=$(echo "$response" | jq -r '.hits.total.value // .hits.total // 0')
        completed=$(echo "$response" | jq -r '[.hits.hits[] | select(._source.status == "job-completed")] | length')
        failed=$(echo "$response" | jq -r '[.hits.hits[] | select(._source.status == "job-failed")] | length')
        echo "💻 $DESCRIPTION"
        echo "✅ Completed: $completed jobs"
        echo "❌ Failed: $failed jobs"
        echo "📊 Total: $total jobs"
        if [ "$completed" -gt 0 ]; then
            echo ""
            echo "Completed Job IDs:"
            echo "$response" | jq -r '.hits.hits[] | select(._source.status == "job-completed") | "  ✅ " + ._source.job_id'
        fi
        if [ "$failed" -gt 0 ]; then
            echo ""
            echo "Failed Job IDs:"
            echo "$response" | jq -r '.hits.hits[] | select(._source.status == "job-failed") | "  ❌ " + ._source.job_id'
        fi
    fi

check-job-status HOURS=DEFAULT_HOURS:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    since_time=$(date -u -v-{{HOURS}}H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "{{HOURS}} hours ago" '+%Y-%m-%dT%H:%M:%SZ')
    just dist-s1::dist-job-status-check::_query-and-display "$since_time" "DIST job status check for last {{HOURS}} hours (since $since_time)"

check-job-status-since TIMESTAMP:
    #!/usr/bin/env bash
    set -e
    export DRY_RUN="${DRY_RUN:-false}"
    just dist-s1::dist-job-status-check::_query-and-display "{{TIMESTAMP}}" "DIST job status check since {{TIMESTAMP}}"
