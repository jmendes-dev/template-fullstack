#!/usr/bin/env bash
# .claude/hooks/post-tool-use.sh — PostToolUse hook
# Dispara check-quality.sh automaticamente após bun test.
# Chamado pelo settings.json após cada execução do tool Bash.

# Claude Code envia dados do hook via stdin como JSON — CLAUDE_TOOL_INPUT pode não ser setado
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$TOOL_INPUT" ] && [ ! -t 0 ]; then
  TOOL_INPUT=$(cat 2>/dev/null)
fi

# Só dispara se o comando continha "bun test"
echo "$TOOL_INPUT" | grep -q "bun test" || exit 0

# Resolver raiz do repo (funciona em worktrees)
GCD=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ "$GCD" != /* ]] && [[ ! "$GCD" =~ ^[A-Za-z]:/ ]]; then
  GCD="$PWD/$GCD"
fi
ROOT=$(dirname "$GCD")

[ -f "$ROOT/check-quality.sh" ] && bash "$ROOT/check-quality.sh" 2>/dev/null || true
