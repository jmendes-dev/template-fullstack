#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# sync-globals.sh
# Sincroniza arquivos globais do template-fullstack
# para o projeto atual. Direção: template → projeto.
#
# Uso:
#   ./sync-globals.sh                        # usa repo remoto (GitHub)
#   ./sync-globals.sh /path/to/template      # usa cópia local
# ──────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; exit 1; }

# ── Configuração ───────────────────────────────

# IMPORTANTE: ajuste esta URL para o seu repo
GITHUB_RAW_BASE="https://raw.githubusercontent.com/jmendes-dev/template-fullstack/main"

# Arquivos globais — APENAS estes são sincronizados.
# Arquivos instanciados (CLAUDE.md, claude-stacks-refactor.md, docs/*) NUNCA são sobrescritos.
GLOBAL_FILES=(
  "claude-stacks.md"
  "claude-design.md"
  "claude-subagents.md"
  "start_project.md"
  "REQUIREMENTS.md"
  "DESIGN_SYSTEM.md"
)

SOURCE="${1:-remote}"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sync-globals.sh — Template → Projeto"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Baixar/Copiar arquivos globais ─────────────

if [ "$SOURCE" = "remote" ]; then
  info "Fonte: GitHub ($GITHUB_RAW_BASE)"
  echo ""

  for file in "${GLOBAL_FILES[@]}"; do
    if curl -sfL "$GITHUB_RAW_BASE/$file" -o "$TEMP_DIR/$file"; then
      ok "Baixado: $file"
    else
      warn "Falha ao baixar: $file — pulando"
    fi
  done
else
  # Fonte local
  if [ ! -d "$SOURCE" ]; then
    error "Diretório não encontrado: $SOURCE"
  fi
  info "Fonte: local ($SOURCE)"
  echo ""

  for file in "${GLOBAL_FILES[@]}"; do
    if [ -f "$SOURCE/$file" ]; then
      cp "$SOURCE/$file" "$TEMP_DIR/$file"
      ok "Copiado: $file"
    else
      warn "Não encontrado: $SOURCE/$file — pulando"
    fi
  done
fi

# ── Comparar e aplicar ────────────────────────

echo ""
info "Comparando com arquivos locais..."
echo ""

CHANGES=0
CHANGED_FILES=()

for file in "${GLOBAL_FILES[@]}"; do
  if [ ! -f "$TEMP_DIR/$file" ]; then
    continue
  fi

  if [ ! -f "./$file" ]; then
    # Arquivo não existe localmente — criar
    echo -e "${GREEN}+++ NOVO${NC}: $file"
    CHANGES=$((CHANGES + 1))
    CHANGED_FILES+=("$file")
  elif ! diff -q "./$file" "$TEMP_DIR/$file" > /dev/null 2>&1; then
    # Arquivo existe e é diferente — mostrar diff resumido
    ADDED=$(diff "./$file" "$TEMP_DIR/$file" | grep -c "^>" || true)
    REMOVED=$(diff "./$file" "$TEMP_DIR/$file" | grep -c "^<" || true)
    echo -e "${YELLOW}~~~ ALTERADO${NC}: $file  (+${ADDED} -${REMOVED} linhas)"
    CHANGES=$((CHANGES + 1))
    CHANGED_FILES+=("$file")
  else
    echo -e "    sem alteração: $file"
  fi
done

echo ""

if [ "$CHANGES" -eq 0 ]; then
  ok "Tudo sincronizado — nenhuma alteração necessária."
  exit 0
fi

# ── Confirmação ────────────────────────────────

info "$CHANGES arquivo(s) com alterações."
echo ""
echo "  Arquivos que serão atualizados:"
for f in "${CHANGED_FILES[@]}"; do
  echo "    • $f"
done
echo ""

read -p "  Aplicar alterações? (s/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  warn "Cancelado pelo usuário."
  exit 0
fi

# ── Aplicar ────────────────────────────────────

echo ""
for file in "${CHANGED_FILES[@]}"; do
  cp "$TEMP_DIR/$file" "./$file"
  ok "Atualizado: $file"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ $CHANGES arquivo(s) sincronizado(s)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Para commitar:"
echo "  git add ${CHANGED_FILES[*]}"
echo "  git commit -m 'docs: sync global configs from template'"
echo ""

# ── Verificar se CLAUDE.md precisa de atenção ──

if [ -f "./CLAUDE.md" ]; then
  info "Nota: CLAUDE.md é instanciado — NÃO foi alterado."
  info "Se os globais mudaram estrutura, revise o CLAUDE.md manualmente."
fi
