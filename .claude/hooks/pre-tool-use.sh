#!/usr/bin/env bash
# .claude/hooks/pre-tool-use.sh — PreToolUse hook
# Protege arquivos sensíveis de modificações não intencionais.
# Chamado pelo settings.json antes de Write e Edit.
#
# Comportamento:
#   exit 0  → permite o tool call prosseguir (com ou sem aviso)
#   exit 2  → BLOQUEIA o tool call e mostra a mensagem ao Claude

_extract_file_path() {
  local json="$1"
  if command -v jq &>/dev/null; then
    jq -r '.file_path // empty' 2>/dev/null <<< "$json" | head -1
  else
    echo "$json" | grep -o '"file_path" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' | head -1
  fi
}

FILE=$(_extract_file_path "${CLAUDE_TOOL_INPUT:-}")

# Se CLAUDE_TOOL_INPUT não estava disponível, tentar stdin (Claude Code envia JSON via stdin)
if [ -z "$FILE" ] && [ ! -t 0 ]; then
  STDIN=$(cat 2>/dev/null)
  FILE=$(_extract_file_path "$STDIN")
fi

# Sem file_path → não é Write/Edit ou não há path — deixar passar
[ -z "$FILE" ] && exit 0

# Normalizar backslashes para forward slashes (paths Windows absolutos)
FILE=$(echo "$FILE" | tr '\\' '/')

# ── Hard block: .github/workflows/ ───────────────────────────────
# Mudanças de CI/CD têm alto impacto e devem passar pelo devops-sre-engineer
if echo "$FILE" | grep -qE '\.github/workflows/'; then
  echo "⛔ BLOQUEADO: $FILE"
  echo ""
  echo "Arquivos .github/workflows/ são protegidos — mudanças de CI/CD"
  echo "têm alto impacto e requerem revisão especializada."
  echo ""
  echo "Para prosseguir:"
  echo "  1. Lance o agente devops-sre-engineer"
  echo "  2. Obtenha confirmação explícita do usuário"
  echo "  3. Então prossiga com a modificação"
  exit 2
fi

# ── Soft warning: arquivos globais gerenciados por sync-globals.sh ─
# Estes arquivos são sobrescritos em cada sync — edições manuais se perdem
if echo "$FILE" | grep -qE '(^|/)(claude-stacks(-versions)?|claude-sdd|DESIGN|claude-debug|start_project)\.md$'; then
  echo "⚠️  AVISO: $FILE é um arquivo global do template."
  echo "Modificações manuais serão sobrescritas em ./sync-globals.sh"
  echo "Prefira registrar aprendizados em claude-stacks-refactor.md"
  echo "(Prosseguindo — apenas um aviso)"
fi

# ── Soft reminder: docs/backlog.md → sugerir sync com GitHub Issues ─
if echo "$FILE" | grep -qE '(^|/)docs/backlog\.md$'; then
  echo "📋 LEMBRETE: Após salvar docs/backlog.md, execute:"
  echo "  ./sync-github-issues.sh"
  echo "para manter os GitHub Issues sincronizados."
  echo "(Prosseguindo — apenas um aviso)"
fi

# ── Soft warning: paths de código de produção ─────────────────────
# CLAUDE.md proíbe escrever código de produção sem agente especializado.
# Este aviso lembra o orquestrador de delegar antes de editar diretamente.
if echo "$FILE" | grep -qE '(^|/)(apps|packages)/(api|web|shared)/src/'; then
  echo "⚠️  AVISO: $FILE é código de produção."
  echo "CLAUDE.md exige delegação ao agente especializado:"
  echo "  apps/api/**  → backend-developer"
  echo "  apps/web/**  → frontend-developer"
  echo "  packages/shared/src/schemas/** → data-engineer-dba"
  echo "Se este arquivo está sendo editado por um subagente, ignore este aviso."
  echo "(Prosseguindo — apenas um aviso)"
fi

exit 0
