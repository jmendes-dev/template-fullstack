#!/usr/bin/env bash
# .claude/hooks/post-tool-use.sh — PostToolUse hook
# Dispara check-quality.sh automaticamente após bun test.
# Também alerta quando claude-stacks-refactor.md ou claude-stacks.md tem entries pendentes.
# Chamado pelo settings.json após cada execução do tool Bash.

# PostToolUse stdin JSON: { "tool_name": "...", "tool_input": {...}, "tool_result": "..." }
_STDIN=""
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
if [ -z "$TOOL_INPUT" ] && [ ! -t 0 ]; then
  _STDIN=$(cat 2>/dev/null)
  TOOL_INPUT="$_STDIN"
fi

# Variável de controle: só rodar quality-check quando o comando continha "bun test"
_RUN_QUALITY=false
if echo "$TOOL_INPUT" | grep -q "bun test"; then
  _RUN_QUALITY=true
fi

# _RAW disponível para todos os blocos abaixo
_RAW="${_STDIN:-$TOOL_INPUT}"

# Resolver raiz do repo (funciona em worktrees) — necessário para quality-check e learning-loop
GCD=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ "$GCD" != /* ]] && [[ ! "$GCD" =~ ^[A-Za-z]:/ ]]; then
  GCD="$PWD/$GCD"
fi
ROOT=$(dirname "$GCD")

# ── Quality-check: apenas quando o tool executou "bun test" ──────────────────
if [ "$_RUN_QUALITY" = "true" ]; then
  mkdir -p "$ROOT/.claude/logs"

  # Extrair saída do bun test do payload do hook (campo tool_result) para evitar dupla execução
  OUTPUT_CACHE="$ROOT/.claude/logs/last-test-output.txt"
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
fi

# ── Alerta promote-learning: roda somente quando o hook disparou por
#    Edit/Write em claude-stacks-refactor.md ou claude-stacks.md ───────────
_TOUCHED_LEARNING=false
_TOOL_NAME=""
_FILE_PATH=""
if command -v jq &>/dev/null && [ -n "$_RAW" ]; then
  _TOOL_NAME=$(echo "$_RAW" | jq -r '.tool_name // empty' 2>/dev/null || true)
  _FILE_PATH=$(echo "$_RAW" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi

case "$_FILE_PATH" in
  *claude-stacks-refactor.md|*claude-stacks.md)
    _TOUCHED_LEARNING=true ;;
esac

if [ "$_TOUCHED_LEARNING" = "true" ] && [ -f "$ROOT/claude-stacks-refactor.md" ]; then
  # Procurar marcador de entries pendentes na tabela "Candidatos a promoção"
  if grep -qE '⏳ *Pendente' "$ROOT/claude-stacks-refactor.md"; then
    printf '\n[learning-loop] claude-stacks-refactor.md contém entries "⏳ Pendente". Rode: ./promote-learning.sh\n' >&2
  fi
fi
