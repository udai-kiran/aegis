#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableStopCheck" && exit 0

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirty" -gt 0 ]; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    printf '{"systemMessage":"You have %s uncommitted change(s) on branch [%s]"}\n' "$dirty" "$branch"
  fi
fi
