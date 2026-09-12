#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disablePromptLog" && exit 0

LOG="$HOME/.claude/prompt-log.jsonl"

session_id=$(jq -r '.session_id // "unknown"')
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

printf '{"ts":"%s","session":"%s"}\n' "$timestamp" "$session_id" >>"$LOG"
