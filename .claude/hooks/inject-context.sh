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

# ── Session state — sempre, mas compacto quando não há contexto ──
if [ -f docs/session-state.md ]; then
  # Se Story ainda é "--", não há sessão ativa — injeta placeholder mínimo
  if grep -q "^\- \*\*Story:\*\* --$" docs/session-state.md 2>/dev/null; then
    out="# Session State
_Sem contexto ativo._"
  else
    out="$(cat docs/session-state.md)"
  fi
fi

# ── Enforçamento de triagem — prompts sem slash command ──────────
# Dispara apenas para prompts de ação (não para perguntas informacionais).
# Heurística: prompts que começam com verbos de ação ou palavras-chave de implementação.
_IS_QUESTION=false
if echo "$PROMPT" | grep -qiE '^(o que|como|por que|qual|quais|explique|mostre|me diga|what|how|why|which|explain|show|tell|analise|analisa|verifique|verifica|revise|avalie|avalia|descreva|descreve|explore|explora|resume|sumarize|mapeie|olhe|veja|busque)'; then
  _IS_QUESTION=true
fi
if [ -n "$PROMPT" ] && [ "${PROMPT#/}" = "$PROMPT" ] && [ "$_IS_QUESTION" = "false" ]; then
  out="$out
---
### ⚠️ TRIAGEM OBRIGATÓRIA
Este prompt não é invocação de slash command. Antes de qualquer ação:
1. Se é bug/erro → invocar \`/bug\`
2. Se é feature/refactor/ambíguo → invocar \`/triage\`
3. Se é continuação explícita da tarefa atual → prosseguir
Não pular para implementação direta."
fi

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

# Se CLAUDE_USER_PROMPT não está disponível, não injetar contexto adicional
# Impossível determinar relevância sem o prompt — session-state é suficiente para continuidade

[ -n "$out" ] && echo "$out" || true
