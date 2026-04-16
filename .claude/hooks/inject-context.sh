#!/usr/bin/env bash
# .claude/hooks/inject-context.sh — UserPromptSubmit hook
# Injeta contexto relevante baseado em palavras-chave do prompt.
# Reduz gasto de tokens: só injeta o que é relevante para o pedido atual.
#
# Contexto injetado:
#   - session-state.md  → SEMPRE (pequeno, crítico para continuidade)
#   - quality.md        → APENAS se prompt menciona testes/qualidade/bugs
#   - backlog.md        → APENAS se prompt menciona tasks/stories/progresso

# Claude Code passa dados do hook via stdin como JSON — CLAUDE_USER_PROMPT pode não ser setado
PROMPT="${CLAUDE_USER_PROMPT:-}"
if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
  _STDIN=$(cat 2>/dev/null)
  # Extrai o campo "prompt" do JSON — usa jq se disponível, regex como fallback
  if command -v jq &>/dev/null; then
    PROMPT=$(echo "$_STDIN" | jq -r '.prompt // empty' 2>/dev/null || true)
  fi
  if [ -z "$PROMPT" ]; then
    PROMPT=$(echo "$_STDIN" | grep -o '"prompt" *: *"[^"]*"' | head -1 | sed 's/"prompt" *: *"//;s/"$//')
  fi
fi
out=""

# ── Session state — sempre ────────────────────────────────────────
[ -f docs/session-state.md ] && out="$(cat docs/session-state.md)"

# ── Quality dashboard — condicional ──────────────────────────────
# Palavras-chave: testes, qualidade, bugs, lint, cobertura
if echo "$PROMPT" | grep -qiE 'test|qualidade|cobertura|coverage|bug|erro|error|quality|falha|quebr|lint|typecheck|spec'; then
  [ -f docs/quality.md ] && out="$out
---
$(cat docs/quality.md)"
fi

# ── Backlog — condicional ─────────────────────────────────────────
# Palavras-chave: continuar, executar, story, task, backlog, implementar
if echo "$PROMPT" | grep -qiE 'continu|execut|task|story|backlog|US-[0-9]|sprint|próxim|implement|feature|pendente|próxima'; then
  [ -f docs/backlog.md ] && out="$out
---
### BACKLOG ATUAL
$(head -50 docs/backlog.md)"
fi

# Se CLAUDE_USER_PROMPT não está disponível, injetar tudo (fallback seguro)
if [ -z "$PROMPT" ]; then
  [ -f docs/quality.md ] && out="$out
---
$(cat docs/quality.md)"
  [ -f docs/backlog.md ] && out="$out
---
### BACKLOG ATUAL
$(head -50 docs/backlog.md)"
fi

[ -n "$out" ] && echo "$out" || true
