#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableToolFailure" && exit 0

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // "unknown"')
error=$(printf '%s' "$input" | jq -r '.tool_response.error // .tool_response.stderr // ""' | head -c 200)

LOG="$HOME/.claude/hook-logs/tool-failures.jsonl"
mkdir -p "$(dirname "$LOG")"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')

printf '{"ts":"%s","session":"%s","tool":"%s","error":"%s"}\n' \
  "$timestamp" "$session_id" "$tool" "$(printf '%s' "$error" | sed 's/"/\\"/g')" >>"$LOG"
