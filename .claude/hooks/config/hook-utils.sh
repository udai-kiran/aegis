#!/usr/bin/env bash
# hook-utils.sh — shared helpers for Claude Code hooks
#
# Sourced by every hook script via:
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config/hook-utils.sh"
# (or similar self-locating pattern so symlinks and moves both work)

# is_hook_disabled <key>
# Returns 0 (true = disabled, caller should `exit 0`) if the named hook is
# disabled; returns 1 (false = enabled) otherwise.
#
# A hook is disabled when either of these is true:
#   1. The env var CLAUDE_HOOK_DISABLE_<UPPER_KEY>=1 is set, e.g.
#      CLAUDE_HOOK_DISABLE_DISABLEBASHGUARD=1
#   2. ~/.claude/hook-config.json contains { "<key>": true }, e.g.
#      { "disableBashGuard": true }
is_hook_disabled() {
  local key="${1:-}"
  [ -z "$key" ] && return 1

  # Env-var check: CLAUDE_HOOK_DISABLE_<UPPERCASE_KEY>=1
  local env_key
  env_key="CLAUDE_HOOK_DISABLE_$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
  if [ "${!env_key:-0}" = "1" ]; then
    return 0
  fi

  # JSON config check: ~/.claude/hook-config.json
  local cfg="$HOME/.claude/hook-config.json"
  if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
    local val
    val=$(jq -r --arg k "$key" '.[$k] // false' "$cfg" 2>/dev/null || echo "false")
    [ "$val" = "true" ] && return 0
  fi

  return 1
}
