#!/usr/bin/env bash
# .claude/hooks/inject-context.sh — UserPromptSubmit hook
# Injeta contexto relevante baseado em palavras-chave do prompt.
# Reduz gasto de tokens: só injeta o que é relevante para o pedido atual.
#
# Contexto injetado:
#   - session-state.md  → SEMPRE (pequeno, crítico para continuidade)
#   - quality.md        → APENAS se prompt menciona testes/qualidade/bugs
#   - backlog.md        → APENAS se prompt menciona tasks/stories/progresso

PROMPT="${CLAUDE_USER_PROMPT:-}"
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
