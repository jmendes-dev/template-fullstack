#!/usr/bin/env bash
# check-health.sh — Diagnóstico rápido do estado do template no projeto
# Uso: ./check-health.sh           # diagnóstico visual
#      ./check-health.sh --assert  # exit 1 se falhas críticas (para CI)

set -euo pipefail

ASSERT_MODE=false
[[ "${1:-}" == "--assert" ]] && ASSERT_MODE=true

FAILURES=0  # contador de falhas críticas (apenas no modo --assert)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅${NC}  $1"; }
warn() { echo -e "${YELLOW}⚠️ ${NC}  $1"; }
err()  { echo -e "${RED}❌${NC}  $1"; [ "$ASSERT_MODE" = true ] && FAILURES=$((FAILURES + 1)); }
info() { echo -e "${CYAN}ℹ${NC}  $1"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SAÚDE DO TEMPLATE — $(date '+%Y-%m-%d %H:%M')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. Versão do template ──────────────────────────────────────
echo "📦 Versão do Template"
if [ -f ".template-version" ]; then
  LOCAL_VER=$(cat .template-version | tr -d '[:space:]')
  ok "Versão instalada: v$LOCAL_VER"
elif [ -f "TEMPLATE_VERSION" ]; then
  LOCAL_VER=$(cat TEMPLATE_VERSION | tr -d '[:space:]')
  ok "Versão do template: v$LOCAL_VER (este é o template)"
else
  warn "TEMPLATE_VERSION não encontrado — rodar adopt-workflow.sh para instalar"
fi
echo ""

# ── 2. Agentes instalados ──────────────────────────────────────
echo "🤖 Agentes Especializados"
AGENT_COUNT=0
if [ -d ".claude/agents" ]; then
  AGENT_COUNT=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d '[:space:]')
fi
if [ "$AGENT_COUNT" -ge 10 ]; then
  ok "Agentes instalados: $AGENT_COUNT/10"
elif [ "$AGENT_COUNT" -gt 0 ]; then
  warn "Agentes instalados: $AGENT_COUNT/10 (incompleto)"
else
  err "Agentes não instalados — rodar adopt-workflow.sh"
fi
echo ""

# ── 3. Memória dos agentes ─────────────────────────────────────
echo "🧠 Memória dos Agentes"
EMPTY_COUNT=0
TOTAL_COUNT=0
if [ -d ".claude/agent-memory" ]; then
  for mem_file in .claude/agent-memory/*/MEMORY.md; do
    if [ -f "$mem_file" ]; then
      TOTAL_COUNT=$((TOTAL_COUNT + 1))
      LINE_COUNT=$(wc -l < "$mem_file" | tr -d '[:space:]')
      if [ "$LINE_COUNT" -lt 10 ]; then
        EMPTY_COUNT=$((EMPTY_COUNT + 1))
      fi
    fi
  done
fi
FILLED=$((TOTAL_COUNT - EMPTY_COUNT))
if [ "$EMPTY_COUNT" -eq 0 ] && [ "$TOTAL_COUNT" -gt 0 ]; then
  ok "Memória: todos os $TOTAL_COUNT agentes com conteúdo"
elif [ "$EMPTY_COUNT" -gt 0 ]; then
  warn "Memória: $FILLED/$TOTAL_COUNT agentes com conteúdo ($EMPTY_COUNT vazios — acumular via uso)"
else
  err "Nenhum agent-memory/ encontrado"
fi
echo ""

# ── 4. Arquivos críticos ──────────────────────────────────────
echo "📄 Arquivos Críticos"
CRITICAL_FILES=(
  "docs/quality.md:Quality Dashboard"
  "docs/session-state.md:Session State"
  "docs/backlog.md:Backlog"
  "docs/user-stories.md:User Stories"
"docs/design-system/MASTER.md:Design System MASTER"
  "docs/design-system/design-brief.md:Design Brief"
  ".claude/settings.json:Settings com hooks"
)
for entry in "${CRITICAL_FILES[@]}"; do
  path="${entry%%:*}"
  label="${entry##*:}"
  if [ -f "$path" ]; then
    ok "$label ($path)"
  elif [ "$path" = "docs/session-state.md" ]; then
    err "$label não existe ($path) — hook inject-context.sh vai falhar"
  else
    warn "$label não existe ($path)"
  fi
done
echo ""

# ── 4b. Config template files ────────────────────────────────
echo "📋 Config Templates (arquivos .example)"
TEMPLATE_FILES=(
  ".env.example:.env com todas as variáveis"
  "biome.json.example:Lint config (Biome 2.x)"
  "tsconfig.json.example:TypeScript config base"
  "sonar-project.properties.example:SonarQube config"
  ".github/workflows/ci.yml:CI pipeline"
)
for entry in "${TEMPLATE_FILES[@]}"; do
  path="${entry%%:*}"
  label="${entry##*:}"
  if [ -f "$path" ]; then
    ok "$label ($path)"
  else
    warn "$label ausente ($path) — sync-globals.sh para restaurar"
  fi
done
echo ""

# ── 5. GitHub Project ──────────────────────────────────────────
echo "🐙 GitHub Integration"
if [ -f ".github/project-id" ]; then
  PROJECT_ID=$(cat .github/project-id)
  ok "GitHub Project configurado: $PROJECT_ID"
else
  warn ".github/project-id não existe — rodar ./setup-github-project.sh"
fi
if [ -f ".github/pull_request_template.md" ]; then
  ok "PR Template configurado"
else
  warn "PR Template ausente (.github/pull_request_template.md)"
fi
echo ""

# ── 6. Scripts disponíveis ────────────────────────────────────
echo "🚀 Scripts"
SCRIPTS=("sync-github-issues.sh" "setup-github-project.sh" "sync-globals.sh" "promote-learning.sh" "check-quality.sh" "check-health.sh" "check-spec-coverage.sh")
for script in "${SCRIPTS[@]}"; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    ok "$script"
  elif [ -f "$script" ]; then
    warn "$script existe mas não é executável (rodar: chmod +x $script)"
  else
    err "$script não encontrado"
  fi
done
echo ""

# ── 7. Candidatos pendentes ──────────────────────────────────
echo "📝 Candidatos a Promoção"
if [ -f "claude-stacks-refactor.md" ] && grep -q "Pendente" "claude-stacks-refactor.md" 2>/dev/null; then
  PENDING=$(grep -c "Pendente" "claude-stacks-refactor.md" 2>/dev/null | tr -d '[:space:]')
  warn "$PENDING candidato(s) pendente(s) em claude-stacks-refactor.md"
  info "Rode: ./promote-learning.sh /path/to/template-fullstack"
else
  ok "Nenhum candidato pendente"
fi
echo ""

# ── 8. Git hooks ─────────────────────────────────────────────
echo "🪝 Git Hooks"
if [ -f ".githooks/post-commit" ] && [ -x ".githooks/post-commit" ]; then
  HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "não configurado")
  if [ "$HOOKS_PATH" = ".githooks" ]; then
    ok "post-commit ativo (core.hooksPath=.githooks)"
  else
    warn "post-commit existe mas core.hooksPath=$HOOKS_PATH (rodar: git config core.hooksPath .githooks)"
  fi
else
  err ".githooks/post-commit não encontrado — rodar adopt-workflow.sh"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Para corrigir problemas: ./adopt-workflow.sh ."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Assert mode: exit 1 se há falhas críticas ─────────────────
if [ "$ASSERT_MODE" = true ]; then
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}❌ Assert mode: $FAILURES verificação(ões) crítica(s) falharam${NC}"
    echo "   Corrija os problemas acima antes de prosseguir."
    echo ""
    exit 1
  else
    echo -e "${GREEN}✅ Assert mode: todas as verificações críticas passaram${NC}"
    echo ""
    exit 0
  fi
fi
