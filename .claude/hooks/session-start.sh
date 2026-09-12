#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableSessionStart" && exit 0

msg=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "?")
  behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo "?")
  msg="Branch: ${branch} | Dirty: ${dirty} | Ahead: ${ahead} | Behind: ${behind}"
fi

if [ -n "$msg" ]; then
  printf '{"systemMessage":"%s"}\n' "$msg"
fi
