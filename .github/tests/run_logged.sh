#!/usr/bin/env bash
# Runs a command and, if it fails, repeats the end of its output as a GitHub
# Actions annotation, so the reason is visible on the run summary page
# without opening the full log.
#
# Usage: run_logged.sh <command> [arguments...]
set -uo pipefail

log_file=$(mktemp)
trap 'rm -f "$log_file"' EXIT

"$@" 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}

if [[ $status -ne 0 ]]; then
  # Annotations are single line; %0A stands for a line break.
  tail_text=$(tail -n 40 "$log_file" | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/%/%25/g' | sed ':a;N;$!ba;s/\n/%0A/g')
  echo "::error title=Command failed ($1)::${tail_text}"
fi
exit "$status"
