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
GITHUB_RAW_BASE="${TEMPLATE_REPO_URL:-https://raw.githubusercontent.com/jmendes-dev/template-fullstack/main}"

# Arquivos globais — APENAS estes são sincronizados.
# Arquivos instanciados (CLAUDE.md, claude-stacks-refactor.md, docs/*) NUNCA são sobrescritos.
GLOBAL_FILES=(
  "claude-stacks.md"
  "claude-sdd.md"
  "DESIGN.md"
  "claude-debug.md"
  "start_project.md"
  "setup-github-project.sh"
  "sync-github-issues.sh"
  "sync-globals.sh"
  "promote-learning.sh"
  "check-health.sh"
  "check-quality.sh"
  "TEMPLATE_VERSION"
  ".claude/settings.local.example.json"
  ".claude/settings.example.json"
  ".claude/hooks/pre-tool-use.sh"
  ".claude/hooks/inject-context.sh"
  ".claude/hooks/post-tool-use.sh"
  "package.json.example"
  ".superpowers/agent-memory-bootstrap.md"
)

# Slash commands — sincronizados junto com os globais
COMMAND_FILES=(
  "bug.md"
  "triage.md"
  "feature.md"
  "finish.md"
  "continue.md"
  "new-project.md"
  "refactor.md"
)

# Agentes — sincronizados junto com os globais
AGENT_FILES=(
  "backend-developer.md"
  "data-engineer-dba.md"
  "devops-sre-engineer.md"
  "frontend-developer.md"
  "project-manager.md"
  "qa-engineer.md"
  "requirements-roadmap-builder.md"
  "security-engineer.md"
  "software-architect.md"
  "ux-ui-designer.md"
)

SOURCE="${1:-remote}"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sync-globals.sh — Template → Projeto"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Comparação de versões ──────────────────────────────────────
LOCAL_VER="desconhecida"
REMOTE_VER="desconhecida"

if [ -f ".template-version" ]; then
  LOCAL_VER=$(cat .template-version | tr -d '[:space:]')
fi

if [ "$SOURCE" != "remote" ] && [ -f "$SOURCE/TEMPLATE_VERSION" ]; then
  REMOTE_VER=$(cat "$SOURCE/TEMPLATE_VERSION" | tr -d '[:space:]')
elif [ "$SOURCE" = "remote" ]; then
  REMOTE_VER=$(curl -sfL "$GITHUB_RAW_BASE/TEMPLATE_VERSION" 2>/dev/null | tr -d '[:space:]' || echo "desconhecida")
fi

if [ "$LOCAL_VER" != "desconhecida" ] && [ "$REMOTE_VER" != "desconhecida" ]; then
  if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
    info "Versão: v$LOCAL_VER (atualizado)"
  else
    warn "Atualização disponível: v$LOCAL_VER → v$REMOTE_VER"
  fi
else
  info "Versão local: ${LOCAL_VER} | Template: ${REMOTE_VER}"
fi
echo ""

# ── Baixar/Copiar arquivos globais ─────────────

mkdir -p "$TEMP_DIR/.claude/agents"
mkdir -p "$TEMP_DIR/.claude/commands"
mkdir -p "$TEMP_DIR/.claude/hooks"
mkdir -p "$TEMP_DIR/.superpowers"

if [ "$SOURCE" = "remote" ]; then
  info "Fonte: GitHub ($GITHUB_RAW_BASE)"
  echo ""

  for file in "${GLOBAL_FILES[@]}"; do
    mkdir -p "$(dirname "$TEMP_DIR/$file")"
    if curl -sfL "$GITHUB_RAW_BASE/$file" -o "$TEMP_DIR/$file"; then
      ok "Baixado: $file"
    else
      warn "Falha ao baixar: $file — pulando"
    fi
  done

  for agent in "${AGENT_FILES[@]}"; do
    if curl -sfL "$GITHUB_RAW_BASE/.claude/agents/$agent" -o "$TEMP_DIR/.claude/agents/$agent"; then
      ok "Baixado: .claude/agents/$agent"
    else
      warn "Falha ao baixar: .claude/agents/$agent — pulando"
    fi
  done

  for cmd in "${COMMAND_FILES[@]}"; do
    if curl -sfL "$GITHUB_RAW_BASE/.claude/commands/$cmd" -o "$TEMP_DIR/.claude/commands/$cmd"; then
      ok "Baixado: .claude/commands/$cmd"
    else
      warn "Falha ao baixar: .claude/commands/$cmd — pulando"
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
      mkdir -p "$(dirname "$TEMP_DIR/$file")"
      cp "$SOURCE/$file" "$TEMP_DIR/$file"
      ok "Copiado: $file"
    else
      warn "Não encontrado: $SOURCE/$file — pulando"
    fi
  done

  for agent in "${AGENT_FILES[@]}"; do
    if [ -f "$SOURCE/.claude/agents/$agent" ]; then
      cp "$SOURCE/.claude/agents/$agent" "$TEMP_DIR/.claude/agents/$agent"
      ok "Copiado: .claude/agents/$agent"
    else
      warn "Não encontrado: $SOURCE/.claude/agents/$agent — pulando"
    fi
  done

  # Sync slash commands via glob
  for f in "$SOURCE/.claude/commands/"*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$TEMP_DIR/.claude/commands/$(basename "$f")"
    ok "Copiado: .claude/commands/$(basename "$f")"
  done
fi

# ── Comparar arquivos globais ─────────────────

echo ""
info "Comparando com arquivos locais..."
echo ""

CHANGES=0
CHANGED_FILES=()
CHANGED_AGENTS=()
CHANGED_COMMANDS=()

for file in "${GLOBAL_FILES[@]}"; do
  if [ ! -f "$TEMP_DIR/$file" ]; then
    continue
  fi

  if [ ! -f "./$file" ]; then
    echo -e "${GREEN}+++ NOVO${NC}: $file"
    CHANGES=$((CHANGES + 1))
    CHANGED_FILES+=("$file")
  elif ! diff -q "./$file" "$TEMP_DIR/$file" > /dev/null 2>&1; then
    ADDED=$(diff "./$file" "$TEMP_DIR/$file" | grep -c "^>" || true)
    REMOVED=$(diff "./$file" "$TEMP_DIR/$file" | grep -c "^<" || true)
    echo -e "${YELLOW}~~~ ALTERADO${NC}: $file  (+${ADDED} -${REMOVED} linhas)"
    CHANGES=$((CHANGES + 1))
    CHANGED_FILES+=("$file")
  else
    echo -e "    sem alteração: $file"
  fi
done

mkdir -p "./.claude/agents"
mkdir -p "./.claude/commands"
mkdir -p "./.superpowers"
for agent in "${AGENT_FILES[@]}"; do
  if [ ! -f "$TEMP_DIR/.claude/agents/$agent" ]; then
    continue
  fi

  if [ ! -f "./.claude/agents/$agent" ]; then
    echo -e "${GREEN}+++ NOVO${NC}: .claude/agents/$agent"
    CHANGES=$((CHANGES + 1))
    CHANGED_AGENTS+=("$agent")
  elif ! diff -q "./.claude/agents/$agent" "$TEMP_DIR/.claude/agents/$agent" > /dev/null 2>&1; then
    ADDED=$(diff "./.claude/agents/$agent" "$TEMP_DIR/.claude/agents/$agent" | grep -c "^>" || true)
    REMOVED=$(diff "./.claude/agents/$agent" "$TEMP_DIR/.claude/agents/$agent" | grep -c "^<" || true)
    echo -e "${YELLOW}~~~ ALTERADO${NC}: .claude/agents/$agent  (+${ADDED} -${REMOVED} linhas)"
    CHANGES=$((CHANGES + 1))
    CHANGED_AGENTS+=("$agent")
  else
    echo -e "    sem alteração: .claude/agents/$agent"
  fi
done

for cmd in "${COMMAND_FILES[@]}"; do
  if [ ! -f "$TEMP_DIR/.claude/commands/$cmd" ]; then
    continue
  fi

  if [ ! -f "./.claude/commands/$cmd" ]; then
    echo -e "${GREEN}+++ NOVO${NC}: .claude/commands/$cmd"
    CHANGES=$((CHANGES + 1))
    CHANGED_COMMANDS+=("$cmd")
  elif ! diff -q "./.claude/commands/$cmd" "$TEMP_DIR/.claude/commands/$cmd" > /dev/null 2>&1; then
    ADDED=$(diff "./.claude/commands/$cmd" "$TEMP_DIR/.claude/commands/$cmd" | grep -c "^>" || true)
    REMOVED=$(diff "./.claude/commands/$cmd" "$TEMP_DIR/.claude/commands/$cmd" | grep -c "^<" || true)
    echo -e "${YELLOW}~~~ ALTERADO${NC}: .claude/commands/$cmd  (+${ADDED} -${REMOVED} linhas)"
    CHANGES=$((CHANGES + 1))
    CHANGED_COMMANDS+=("$cmd")
  else
    echo -e "    sem alteração: .claude/commands/$cmd"
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
for a in "${CHANGED_AGENTS[@]}"; do
  echo "    • .claude/agents/$a"
done
for c in "${CHANGED_COMMANDS[@]}"; do
  echo "    • .claude/commands/$c"
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
  mkdir -p "$(dirname "./$file")"
  cp "$TEMP_DIR/$file" "./$file"
  ok "Atualizado: $file"
done
for agent in "${CHANGED_AGENTS[@]}"; do
  cp "$TEMP_DIR/.claude/agents/$agent" "./.claude/agents/$agent"
  ok "Atualizado: .claude/agents/$agent"
done

# Sync slash commands
mkdir -p "./.claude/commands"
for cmd in "${CHANGED_COMMANDS[@]}"; do
  cp "$TEMP_DIR/.claude/commands/$cmd" "./.claude/commands/$cmd"
  ok "Atualizado: .claude/commands/$cmd"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ $CHANGES arquivo(s) sincronizado(s)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Para commitar:"
FILES_TO_COMMIT=("${CHANGED_FILES[@]}")
for a in "${CHANGED_AGENTS[@]}"; do FILES_TO_COMMIT+=(".claude/agents/$a"); done
for c in "${CHANGED_COMMANDS[@]}"; do FILES_TO_COMMIT+=(".claude/commands/$c"); done
echo "  git add ${FILES_TO_COMMIT[*]}"
echo "  git commit -m 'docs: sync global configs from template'"
echo ""

# ── Verificar se CLAUDE.md precisa de atenção ──

if [ -f "./CLAUDE.md" ]; then
  info "Nota: CLAUDE.md é instanciado — NÃO foi alterado."
  info "Se os globais mudaram estrutura, revise o CLAUDE.md manualmente."
fi

echo ""
warn "Arquivos obsoletos — podem ser removidos dos projetos adotados:"
echo "    claude-subagents.md, DESIGN_SYSTEM.md, REQUIREMENTS.md"
echo "    (versões antigas de claude-debug.md e start_project.md foram substituídas)"
