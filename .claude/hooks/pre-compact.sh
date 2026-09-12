#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disablePreCompact" && exit 0
parts=()

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  recent=$(git log --oneline -3 2>/dev/null | sed 's/"/\\"/g' | tr '\n' '; ')
  parts+=("Branch: ${branch} | Dirty: ${dirty} | Staged: ${staged}")
  [ -n "$recent" ] && parts+=("Recent commits: ${recent}")

  stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  [ "$stash_count" -gt 0 ] && parts+=("Stashes: ${stash_count}")
fi

if [ -n "${VIRTUAL_ENV:-}" ]; then
  parts+=("Python venv: $(basename "$VIRTUAL_ENV")")
fi

if [ -n "${CONDA_DEFAULT_ENV:-}" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
  parts+=("Conda env: ${CONDA_DEFAULT_ENV}")
fi

if [ ${#parts[@]} -gt 0 ]; then
  msg=$(printf '%s' "${parts[*]}" | sed 's/"/\\"/g')
  printf '{"systemMessage":"[Pre-compact snapshot] %s"}\n' "$msg"
fi
