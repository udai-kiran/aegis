#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableTestWatcher" && exit 0

input=$(cat)

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
exit_code=$(printf '%s' "$input" | jq -r '.tool_response.exitCode // .tool_response.exit_code // "0"')

[ -z "$cmd" ] && exit 0
[ "$exit_code" = "0" ] && exit 0
[ "$exit_code" = "null" ] && exit 0

is_test=false
case "$cmd" in
  *"pytest"* | *"python -m pytest"* | *"python -m unittest"*) is_test=true ;;
  *"npm test"* | *"npm run test"* | *"npx jest"* | *"npx vitest"* | *"npx mocha"*) is_test=true ;;
  *"yarn test"* | *"pnpm test"*) is_test=true ;;
  *"go test"* | *"cargo test"* | *"mvn test"* | *"gradle test"*) is_test=true ;;
  *"make test"* | *"make check"*) is_test=true ;;
  *"rspec"* | *"bundle exec rspec"*) is_test=true ;;
esac

if [ "$is_test" = true ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"⚠ Tests failed (exit code %s). Fix the failures before moving on."}}\n' "$exit_code"
fi
