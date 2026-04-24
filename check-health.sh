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

# ── 3. Memória dos agentes (densidade com barra visual) ─────────
echo "🧠 Memória dos Agentes (densidade)"
echo ""

if [ ! -d ".claude/agent-memory" ]; then
  err "Nenhum agent-memory/ encontrado"
  echo ""
else
  # Coletar dados de cada agente em arrays paralelos
  _MEM_AGENTS=()
  _MEM_LINES=()
  _MEM_TOPICS=()
  _MEM_AGE_DAYS=()
  _MEM_IS_BOIL=()
  _MAX_LINES=1  # evita divisão por zero
  _BOIL_COUNT=0
  _NO_TOPIC_COUNT=0
  _TOTAL_LINES=0
  _AGENT_COUNT=0

  for dir in .claude/agent-memory/*/; do
    agent=$(basename "$dir")
    [ "$agent" = "*" ] && continue  # diretório vazio
    memfile="$dir/MEMORY.md"
    [ ! -f "$memfile" ] && continue

    _AGENT_COUNT=$((_AGENT_COUNT + 1))
    lines=$(wc -l < "$memfile" 2>/dev/null | tr -d '[:space:]')
    lines=${lines:-0}
    _TOTAL_LINES=$((_TOTAL_LINES + lines))
    [ "$lines" -gt "$_MAX_LINES" ] && _MAX_LINES=$lines

    # Contar arquivos .md no diretório EXCLUINDO MEMORY.md
    topics=$(find "$dir" -maxdepth 1 -type f -name "*.md" ! -name "MEMORY.md" 2>/dev/null | wc -l | tr -d '[:space:]')
    topics=${topics:-0}
    [ "$topics" -eq 0 ] && _NO_TOPIC_COUNT=$((_NO_TOPIC_COUNT + 1))

    # Idade em dias
    now_sec=$(date +%s)
    # stat funciona diferente em Linux (-c) vs Mac (-f); tentar ambos
    mod_sec=$(stat -c %Y "$memfile" 2>/dev/null || stat -f %m "$memfile" 2>/dev/null || echo "$now_sec")
    age_days=$(( (now_sec - mod_sec) / 86400 ))

    # Detectar boilerplate (mesma regra de adopt-workflow)
    non_comment=$(grep -cvE '^[[:space:]]*(#|<!--|$)' "$memfile" 2>/dev/null || echo "0")
    is_boil=0
    if [ "$non_comment" -le 10 ] && ! grep -q "^## Project Context" "$memfile" 2>/dev/null; then
      is_boil=1
      _BOIL_COUNT=$((_BOIL_COUNT + 1))
    fi

    _MEM_AGENTS+=("$agent")
    _MEM_LINES+=("$lines")
    _MEM_TOPICS+=("$topics")
    _MEM_AGE_DAYS+=("$age_days")
    _MEM_IS_BOIL+=("$is_boil")
  done

  # Imprimir tabela
  _i=0
  while [ "$_i" -lt "${#_MEM_AGENTS[@]}" ]; do
    agent="${_MEM_AGENTS[$_i]}"
    lines="${_MEM_LINES[$_i]}"
    topics="${_MEM_TOPICS[$_i]}"
    age="${_MEM_AGE_DAYS[$_i]}"
    boil="${_MEM_IS_BOIL[$_i]}"

    # Barra: proporção de linhas / max × 10
    filled=$(( lines * 10 / _MAX_LINES ))
    [ "$filled" -gt 10 ] && filled=10
    [ "$filled" -lt 0 ] && filled=0
    bar=""
    j=0
    while [ "$j" -lt "$filled" ]; do bar="${bar}█"; j=$((j+1)); done
    while [ "$j" -lt 10 ]; do bar="${bar}░"; j=$((j+1)); done

    # Age label
    if [ "$age" -gt 30 ]; then
      age_label="30d+"
    else
      age_label="${age}d"
    fi

    # Status extra
    if [ "$boil" -eq 1 ]; then
      status_label="boilerplate"
    else
      status_label="atualizado $age_label"
    fi

    # Formato: nome padded a 28 chars
    printf '  %-28s : %s %3dL · %d tópicos · %s\n' "$agent" "$bar" "$lines" "$topics" "$status_label"
    _i=$((_i + 1))
  done

  # Resumo
  echo "  ────────────────────────────────────────────────────────────────────"
  if [ "$_AGENT_COUNT" -gt 0 ]; then
    avg=$(( _TOTAL_LINES / _AGENT_COUNT ))
    summary="Média: ${avg}L/agente"
    [ "$_BOIL_COUNT" -gt 0 ] && summary="$summary · $_BOIL_COUNT agente(s) com boilerplate"
    [ "$_NO_TOPIC_COUNT" -gt 0 ] && summary="$summary · $_NO_TOPIC_COUNT agente(s) sem tópicos"
    info "$summary"
  else
    warn "Nenhum MEMORY.md encontrado em agent-memory/"
  fi

  # Assert mode: falha se há boilerplate
  if [ "$ASSERT_MODE" = true ] && [ "$_BOIL_COUNT" -gt 0 ]; then
    FAILURES=$((FAILURES + 1))
  fi
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
