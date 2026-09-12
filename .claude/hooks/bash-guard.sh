#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableBashGuard" && exit 0

cmd=$(jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

block() {
  printf '{"decision":"block","reason":"%s"}\n' "$1"
  exit 0
}

case "$cmd" in
  *"rm -rf /"*) block "Blocked: rm -rf / is catastrophic" ;;
  *"rm -rf /*"*) block "Blocked: rm -rf /* is catastrophic" ;;
  *"rm -rf ~"* | *"rm -rf \$HOME"* | *'rm -rf $HOME'*) block "Blocked: rm -rf home directory" ;;
  *"--force"*"main"* | *"--force"*"master"*) block "Blocked: force-push to main/master" ;;
  *"push -f"*"main"* | *"push -f"*"master"*) block "Blocked: force-push to main/master" ;;
  *"git push"*"--force"*) block "Blocked: force-push -- use --force-with-lease if needed" ;;
  *"reset --hard"*"origin/main"*) block "Blocked: hard reset to origin/main -- stash first" ;;
  *"DROP DATABASE"* | *"drop database"*) block "Blocked: DROP DATABASE" ;;
  *"DROP TABLE"* | *"drop table"*) block "Blocked: DROP TABLE" ;;
  *"curl"*"|"*"bash"* | *"curl"*"|"*"sh"*) block "Blocked: curl pipe to shell -- download and inspect first" ;;
  *"wget"*"|"*"bash"* | *"wget"*"|"*"sh"*) block "Blocked: wget pipe to shell -- download and inspect first" ;;
  *"chmod 777"*) block "Blocked: chmod 777 is world-writable -- use specific perms" ;;
  *"chmod -R 777"*) block "Blocked: recursive chmod 777 is dangerous" ;;
  *"> /dev/sd"* | *">/dev/sd"*) block "Blocked: writing to raw block device" ;;
  *"mkfs."*) block "Blocked: mkfs will destroy filesystem -- confirm manually" ;;
  *":(){ :|:&"* | *":(){:|:&"*) block "Blocked: fork bomb detected" ;;
  *"dd if="*"of=/dev/"*) block "Blocked: dd to raw device -- confirm manually" ;;
  *"shutdown"* | *"reboot"* | *"init 0"* | *"init 6"*) block "Blocked: system shutdown/reboot" ;;
  *"TRUNCATE TABLE"* | *"truncate table"*) block "Blocked: TRUNCATE TABLE" ;;
  *"DELETE FROM"*"WHERE 1"* | *"delete from"*"where 1"*) block "Blocked: DELETE all rows" ;;
esac
