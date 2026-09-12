#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableSecurityScan" && exit 0

f=$(jq -r '.tool_response.filePath // .tool_input.file_path')
[ -z "$f" ] || [ "$f" = "null" ] && exit 0
[ -f "$f" ] || exit 0

findings=""

case "$f" in
  *.py)
    if command -v bandit >/dev/null 2>&1; then
      out=$(bandit -q -ll "$f" 2>/dev/null) || true
      if [ -n "$out" ]; then
        count=$(echo "$out" | grep -c ">> Issue:" 2>/dev/null || echo "?")
        findings="bandit found ${count} medium/high severity issue(s)"
      fi
    fi
    ;;
  *.js | *.jsx | *.ts | *.tsx | *.go | *.java | *.c | *.cpp | *.h | *.rs | *.rb | *.php)
    if command -v semgrep >/dev/null 2>&1; then
      out=$(semgrep --config auto --quiet --json "$f" 2>/dev/null) || true
      if [ -n "$out" ]; then
        count=$(printf '%s' "$out" | jq '.results | length' 2>/dev/null || echo "0")
        [ "$count" -gt 0 ] && findings="semgrep found ${count} issue(s)"
      fi
    fi
    ;;
esac

if [ -n "$findings" ]; then
  findings=$(printf '%s' "$findings" | sed 's/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"🔒 Security: %s in %s. Review before committing."}}\n' "$findings" "$f"
fi
