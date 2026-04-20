#!/usr/bin/env bash
# .claude/hooks/post-tool-use.sh — PostToolUse hook
# Dispara check-quality.sh automaticamente após bun test.
# Chamado pelo settings.json após cada execução do tool Bash.

# PostToolUse stdin JSON: { "tool_name": "...", "tool_input": {...}, "tool_result": "..." }
_STDIN=""
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$TOOL_INPUT" ] && [ ! -t 0 ]; then
  _STDIN=$(cat 2>/dev/null)
  TOOL_INPUT="$_STDIN"
fi

# Só dispara se o comando continha "bun test"
echo "$TOOL_INPUT" | grep -q "bun test" || exit 0

# Resolver raiz do repo (funciona em worktrees)
GCD=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ "$GCD" != /* ]] && [[ ! "$GCD" =~ ^[A-Za-z]:/ ]]; then
  GCD="$PWD/$GCD"
fi
ROOT=$(dirname "$GCD")
mkdir -p "$ROOT/.claude/logs"

# Extrair saída do bun test do payload do hook (campo tool_result) para evitar dupla execução
OUTPUT_CACHE="$ROOT/.claude/logs/last-test-output.txt"
_RAW="${_STDIN:-$TOOL_INPUT}"
if command -v jq &>/dev/null && [ -n "$_RAW" ]; then
  TOOL_RESULT=$(echo "$_RAW" | jq -r '.tool_result // empty' 2>/dev/null || true)
  [ -n "$TOOL_RESULT" ] && echo "$TOOL_RESULT" > "$OUTPUT_CACHE"
fi

if [ -f "$ROOT/check-quality.sh" ]; then
  if [ -f "$OUTPUT_CACHE" ] && [ -s "$OUTPUT_CACHE" ]; then
    bash "$ROOT/check-quality.sh" --from-output "$OUTPUT_CACHE" >> "$ROOT/.claude/logs/quality.log" 2>&1 || true
  else
    bash "$ROOT/check-quality.sh" >> "$ROOT/.claude/logs/quality.log" 2>&1 || true
  fi
fi
