#!/usr/bin/env bash
# .claude/hooks/pre-tool-use.sh — PreToolUse hook
# Protege arquivos sensíveis de modificações não intencionais.
# Chamado pelo settings.json antes de Write e Edit.
#
# Comportamento:
#   exit 0  → permite o tool call prosseguir (com ou sem aviso)
#   exit 2  → BLOQUEIA o tool call e mostra a mensagem ao Claude

FILE=$(echo "${CLAUDE_TOOL_INPUT:-}" | grep -o '"file_path" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' | head -1)

# Se CLAUDE_TOOL_INPUT não estava disponível, tentar stdin (Claude Code envia JSON via stdin)
if [ -z "$FILE" ] && [ ! -t 0 ]; then
  STDIN=$(cat 2>/dev/null)
  FILE=$(echo "${STDIN}" | grep -o '"file_path" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' | head -1)
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
if echo "$FILE" | grep -qE '(^|/)claude-(stacks|subagents|debug|design)\.md$'; then
  echo "⚠️  AVISO: $FILE é um arquivo global do template."
  echo "Modificações manuais serão sobrescritas em ./sync-globals.sh"
  echo "Prefira registrar aprendizados em claude-stacks-refactor.md"
  echo "(Prosseguindo — apenas um aviso)"
fi

exit 0
