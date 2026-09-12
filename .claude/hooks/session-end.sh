#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableSessionEnd" && exit 0

LOG="$HOME/.claude/hook-logs/sessions.jsonl"
mkdir -p "$(dirname "$LOG")"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
session_id=$(jq -r '.session_id // "unknown"')

entry="{\"ts\":\"${timestamp}\",\"session\":\"${session_id}\",\"event\":\"end\""

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  entry="${entry},\"branch\":\"${branch}\",\"dirty\":${dirty}"
fi

entry="${entry}}"
printf '%s\n' "$entry" >>"$LOG"
