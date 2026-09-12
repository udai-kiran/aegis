#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableEnvChanged" && exit 0

f=$(jq -r '.file // ""')
[ -z "$f" ] || [ "$f" = "null" ] && exit 0

fname=$(basename "$f")
printf '{"systemMessage":"Environment file changed: %s — verify no secrets were exposed and restart any dependent processes."}\n' "$fname"
