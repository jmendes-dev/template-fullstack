#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# promote-learning.sh
# Coleta aprendizados ("candidatos a promoção") de um projeto
# e os promove para os arquivos globais no template-fullstack.
# Direção: projeto → template.
#
# Uso:
#   ./promote-learning.sh /path/to/template-fullstack
#
# Pré-requisito: rodar dentro do diretório do projeto.
# ──────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; exit 1; }

TEMPLATE_DIR="${1:-}"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

if [ -z "$TEMPLATE_DIR" ]; then
  echo ""
  echo "Uso: ./promote-learning.sh /path/to/template-fullstack"
  echo ""
  echo "Rodar dentro do diretório do projeto."
  echo "Coleta candidatos de claude-stacks-refactor.md e promove para o template."
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  error "Template não encontrado: $TEMPLATE_DIR"
fi

REFACTOR_FILE="$PROJECT_DIR/claude-stacks-refactor.md"

if [ ! -f "$REFACTOR_FILE" ]; then
  error "claude-stacks-refactor.md não encontrado em $PROJECT_DIR"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  promote-learning.sh — Projeto → Template"
echo "  Projeto:  $PROJECT_NAME"
echo "  Template: $TEMPLATE_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Extrair candidatos pendentes ───────────────

# Busca linhas da tabela de candidatos que têm ⏳ Pendente
CANDIDATES=$(grep -n "⏳" "$REFACTOR_FILE" 2>/dev/null || true)

if [ -z "$CANDIDATES" ]; then
  ok "Nenhum candidato pendente encontrado em claude-stacks-refactor.md"
  echo ""

  # Verificar se há regras no corpo do arquivo que poderiam ser candidatas
  RULES_COUNT=$(grep -c "^- " "$REFACTOR_FILE" 2>/dev/null || true)
  if [ "$RULES_COUNT" -gt 0 ]; then
    info "Encontradas $RULES_COUNT regras no arquivo."
    info "Se alguma deveria ser promovida, marque-a na tabela 'Candidatos a promoção'"
    info "com status ⏳ Pendente e rode este script novamente."
  fi
  exit 0
fi

# Contar candidatos
CANDIDATE_COUNT=$(echo "$CANDIDATES" | wc -l)
info "Encontrado(s) $CANDIDATE_COUNT candidato(s) pendente(s):"
echo ""

# ── Processar cada candidato ───────────────────

INDEX=0
while IFS= read -r line; do
  INDEX=$((INDEX + 1))
  LINE_NUM=$(echo "$line" | cut -d: -f1)
  CONTENT=$(echo "$line" | cut -d: -f2-)

  # Extrair campos da tabela markdown: | Regra | Origem | Destino | Status |
  RULE=$(echo "$CONTENT" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
  ORIGIN=$(echo "$CONTENT" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
  DEST=$(echo "$CONTENT" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4}')

  echo -e "${BOLD}[$INDEX/$CANDIDATE_COUNT]${NC} $RULE"
  echo -e "  Origem:  $ORIGIN"
  echo -e "  Destino: $DEST"
  echo ""

  # Perguntar ação
  echo "  Ações:"
  echo "    p = Promover (adicionar ao template e marcar como ✅)"
  echo "    s = Pular (manter como ⏳ Pendente)"
  echo "    r = Rejeitar (marcar como ❌ Rejeitado)"
  echo ""
  read -p "  Ação? (p/s/r) " -n 1 -r ACTION
  echo ""
  echo ""

  case $ACTION in
    [Pp])
      # Determinar arquivo destino no template
      TARGET_FILE=""
      if echo "$DEST" | grep -qi "stacks"; then
        TARGET_FILE="$TEMPLATE_DIR/claude-stacks.md"
      elif echo "$DEST" | grep -qi "design"; then
        TARGET_FILE="$TEMPLATE_DIR/claude-design.md"
      elif echo "$DEST" | grep -qi "subagent"; then
        TARGET_FILE="$TEMPLATE_DIR/claude-subagents.md"
      else
        warn "Destino não reconhecido: $DEST"
        read -p "  Caminho completo do arquivo destino no template: " TARGET_FILE
      fi

      if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
        # Adicionar a regra ao final do arquivo destino (antes do último ---)
        echo "" >> "$TARGET_FILE"
        echo "<!-- Promovido de $PROJECT_NAME em $(date +%Y-%m-%d) -->" >> "$TARGET_FILE"
        echo "- $RULE" >> "$TARGET_FILE"
        ok "Adicionado a $TARGET_FILE"

        # Marcar como promovido no projeto
        sed -i "${LINE_NUM}s/⏳ Pendente/✅ Promovido $(date +%Y-%m-%d)/" "$REFACTOR_FILE"
        ok "Marcado como ✅ Promovido em claude-stacks-refactor.md"
      else
        warn "Arquivo destino não encontrado: $TARGET_FILE — pulando"
      fi
      ;;

    [Rr])
      # Marcar como rejeitado
      sed -i "${LINE_NUM}s/⏳ Pendente/❌ Rejeitado/" "$REFACTOR_FILE"
      ok "Marcado como ❌ Rejeitado"
      ;;

    *)
      info "Pulando..."
      ;;
  esac
done <<< "$CANDIDATES"

# ── Resumo ─────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Revisão concluída"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Próximos passos:"
echo ""
echo "  1. No PROJETO ($PROJECT_NAME):"
echo "     git add claude-stacks-refactor.md"
echo "     git commit -m 'docs: review promotion candidates'"
echo ""
echo "  2. No TEMPLATE ($TEMPLATE_DIR):"
echo "     cd $TEMPLATE_DIR"
echo "     git diff  # revisar as adições"
echo "     git add . && git commit -m 'docs: promote learnings from $PROJECT_NAME'"
echo "     git push"
echo ""
echo "  3. Nos OUTROS PROJETOS:"
echo "     ./sync-globals.sh  # puxar as atualizações do template"
echo ""
