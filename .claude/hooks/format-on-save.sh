#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config/hook-utils.sh"
is_hook_disabled "disableFormatOnSave" && exit 0

f=$(jq -r '.tool_response.filePath // .tool_input.file_path')
[ -z "$f" ] || [ "$f" = "null" ] && exit 0
[ -f "$f" ] || exit 0

find_config_up() {
  local dir="$1"
  shift
  while true; do
    for name in "$@"; do
      if [ -f "$dir/$name" ]; then
        printf '%s\n' "$dir/$name"
        return 0
      fi
    done
    [ "$dir" = "/" ] && return 1
    dir=$(dirname "$dir")
  done
}

filedir=$(dirname "$f")

case "$f" in
  *.py)
    ruff format --quiet "$f"
    ruff check --fix --quiet "$f"
    ;;
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.mts)
    npx --yes prettier --write "$f" >/dev/null
    npx --yes eslint --fix "$f" 2>/dev/null || true
    ;;
  *.go)
    GOIMPORTS=$(command -v goimports 2>/dev/null || echo "$HOME/go/bin/goimports")
    if [ -x "$GOIMPORTS" ]; then
      "$GOIMPORTS" -w "$f"
    else
      GOFMT=$(command -v gofmt 2>/dev/null || echo /usr/local/go/bin/gofmt)
      [ -x "$GOFMT" ] && "$GOFMT" -w "$f" || true
    fi
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt --edition 2021 "$f" || true
    ;;
  *.sh | *.bash | *.zsh)
    SHFMT=$(command -v shfmt 2>/dev/null || echo "$HOME/go/bin/shfmt")
    [ -x "$SHFMT" ] && "$SHFMT" -w -i 2 -ci "$f" || true
    ;;
  *.java)
    GJF="$HOME/.local/bin/google-java-format.jar"
    JAVA17=/usr/lib/jvm/java-17-amazon-corretto/bin/java
    [ -f "$GJF" ] && [ -x "$JAVA17" ] && "$JAVA17" -jar "$GJF" -i "$f" || true
    ;;
  *.c | *.h | *.cpp | *.hpp | *.cc | *.cxx)
    command -v clang-format >/dev/null 2>&1 && clang-format -i --style=file --fallback-style=none "$f" 2>/dev/null || true
    ;;
  *.yaml | *.yml)
    if cfg=$(find_config_up "$filedir" .yamlfmt .yamlfmt.yml .yamlfmt.yaml yamlfmt.yml yamlfmt.yaml); then
      YAMLFMT=$(command -v yamlfmt 2>/dev/null || echo "$HOME/go/bin/yamlfmt")
      [ -x "$YAMLFMT" ] && "$YAMLFMT" -conf "$cfg" "$f" 2>/dev/null || true
    fi
    ;;
  *.toml)
    if cfg=$(find_config_up "$filedir" .taplo.toml taplo.toml); then
      command -v taplo >/dev/null 2>&1 && taplo fmt -c "$cfg" "$f" 2>/dev/null || true
    fi
    ;;
  *.md | *.mdx)
    if find_config_up "$filedir" .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.yaml .prettierrc.js .prettierrc.cjs prettier.config.js prettier.config.cjs >/dev/null 2>&1; then
      npx --yes prettier --write --prose-wrap preserve "$f" >/dev/null 2>&1 || true
    fi
    ;;
  *.json)
    if command -v jq >/dev/null 2>&1; then
      tmp=$(mktemp)
      if jq . "$f" >"$tmp" 2>/dev/null; then
        mv "$tmp" "$f"
      else
        rm -f "$tmp"
      fi
    fi
    ;;
  *.sql)
    command -v sqlfluff >/dev/null 2>&1 && sqlfluff fix "$f" 2>/dev/null || true
    ;;
  *.tf | *.tfvars)
    command -v terraform >/dev/null 2>&1 && terraform fmt "$f" 2>/dev/null || true
    ;;
esac
