#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disablePostCompact" && exit 0

parts=()

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  parts+=("Branch: ${branch} | Dirty: ${dirty}")
fi

if [ -n "${VIRTUAL_ENV:-}" ]; then
  parts+=("Python venv: $(basename "$VIRTUAL_ENV")")
fi

if [ ${#parts[@]} -gt 0 ]; then
  msg=$(printf '%s' "${parts[*]}" | sed 's/"/\\"/g')
  printf '{"systemMessage":"[Post-compact state] %s"}\n' "$msg"
fi
