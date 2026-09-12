#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableSubagentStop" && exit 0

LOG="$HOME/.claude/hook-logs/subagents.jsonl"
mkdir -p "$(dirname "$LOG")"

input=$(cat)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
agent_name=$(printf '%s' "$input" | jq -r '.agent_name // .subagent_name // "unknown"')

printf '{"ts":"%s","session":"%s","agent":"%s","event":"stop"}\n' \
  "$timestamp" "$session_id" "$agent_name" >>"$LOG"
