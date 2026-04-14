#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# adopt-workflow.sh
# Adota o workflow SDD/TDD em um projeto existente.
# Copia arquivos estruturais e cria a estrutura docs/.
# ──────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; exit 1; }

# ── Validação ──────────────────────────────────

if [ ! -d "$TARGET_DIR" ]; then
  error "Diretório alvo não encontrado: $TARGET_DIR"
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  adopt-workflow.sh — SDD/TDD Workflow"
echo "  Template: $SCRIPT_DIR"
echo "  Target:   $TARGET_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Detecção de estrutura existente ────────────

HAS_APPS=false
HAS_CLAUDE=false
HAS_DOCS=false

[ -d "$TARGET_DIR/apps" ] && HAS_APPS=true
[ -f "$TARGET_DIR/CLAUDE.md" ] && HAS_CLAUDE=true
[ -d "$TARGET_DIR/docs" ] && HAS_DOCS=true

if [ "$HAS_APPS" = true ]; then
  info "Detectado: projeto com estrutura apps/ (monorepo)"
else
  warn "Sem estrutura apps/ — o CLAUDE.md será copiado mas o bootstrap pode ser necessário"
fi

if [ "$HAS_CLAUDE" = true ]; then
  warn "CLAUDE.md já existe no projeto. Será renomeado para CLAUDE.md.bak"
  cp "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.bak"
fi

# ── Arquivos globais (sempre copiar) ──────────

GLOBAL_FILES=(
  "claude-stacks.md"
  "claude-design.md"
  "claude-subagents.md"
  "claude-debug.md"
  "start_project.md"
  "REQUIREMENTS.md"
  "DESIGN_SYSTEM.md"
  ".gitattributes"
  "setup-github-project.sh"
  "sync-github-issues.sh"
)

info "Copiando arquivos globais..."
for file in "${GLOBAL_FILES[@]}"; do
  if [ -f "$SCRIPT_DIR/$file" ]; then
    cp "$SCRIPT_DIR/$file" "$TARGET_DIR/$file"
    ok "$file"
  else
    warn "$file não encontrado no template — pulando"
  fi
done

# ── Agentes especializados ─────────────────────

info "Copiando .claude/agents/..."
mkdir -p "$TARGET_DIR/.claude/agents"
if [ -d "$SCRIPT_DIR/.claude/agents" ]; then
  cp "$SCRIPT_DIR/.claude/agents/"*.md "$TARGET_DIR/.claude/agents/" 2>/dev/null || true
  AGENT_COUNT=$(ls "$TARGET_DIR/.claude/agents/"*.md 2>/dev/null | wc -l)
  ok "$AGENT_COUNT agente(s) copiado(s)"
else
  warn ".claude/agents/ não encontrado no template — pulando"
fi

# ── Estrutura agent-memory ─────────────────────

info "Criando .claude/agent-memory/..."
AGENTS=(
  "backend-developer"
  "data-engineer-dba"
  "devops-sre-engineer"
  "frontend-developer"
  "project-manager"
  "qa-engineer"
  "requirements-roadmap-builder"
  "security-engineer"
  "software-architect"
  "ux-ui-designer"
)
for agent in "${AGENTS[@]}"; do
  mkdir -p "$TARGET_DIR/.claude/agent-memory/$agent"
  if [ ! -f "$TARGET_DIR/.claude/agent-memory/$agent/MEMORY.md" ]; then
    cat > "$TARGET_DIR/.claude/agent-memory/$agent/MEMORY.md" << MEMEOF
# MEMORY.md — $agent

> Memória persistente do agente. Atualizada automaticamente durante o desenvolvimento.

## Índice

<!-- Entradas adicionadas pelo agente durante sessões -->
MEMEOF
    ok "agent-memory/$agent/MEMORY.md"
  fi
done

# ── Arquivos instanciados (copiar se não existem) ──

INSTANCE_FILES=(
  "CLAUDE.md"
  "claude-sdd.md"
)

info "Copiando arquivos instanciados (sem sobrescrever existentes)..."
for file in "${INSTANCE_FILES[@]}"; do
  if [ -f "$SCRIPT_DIR/$file" ]; then
    if [ ! -f "$TARGET_DIR/$file" ] || [ "$file" = "CLAUDE.md" ]; then
      cp "$SCRIPT_DIR/$file" "$TARGET_DIR/$file"
      ok "$file"
    else
      warn "$file já existe — mantendo versão do projeto"
    fi
  fi
done

# ── claude-stacks-refactor.md (criar vazio se não existe) ──

if [ ! -f "$TARGET_DIR/claude-stacks-refactor.md" ]; then
  cat > "$TARGET_DIR/claude-stacks-refactor.md" << 'REFACTOR_EOF'
# claude-stacks-refactor.md — Aprendizados e Extensões

> **Este arquivo é um documento vivo.**
> Contém regras, padrões e configurações descobertos durante o desenvolvimento
> que complementam o `claude-stacks.md`.
>
> **Auto-atualizado pelo Claude** quando um erro evitável é encontrado (ver CLAUDE.md → Auto-atualização do Stacks).
>
> **Hierarquia**: `CLAUDE.md` > `claude-sdd.md` > `claude-stacks.md` > `claude-design.md` > `claude-stacks-refactor.md`

---

## Regras descobertas

<!-- Adicionadas automaticamente pelo Claude durante o desenvolvimento -->

---

## Candidatos a promoção

> Regras que podem beneficiar todos os projetos. Revisar periodicamente e promover para os arquivos globais.

| Regra | Origem | Destino | Status |
|---|---|---|---|

REFACTOR_EOF
  ok "claude-stacks-refactor.md (criado vazio)"
else
  warn "claude-stacks-refactor.md já existe — mantendo"
fi

# ── Estrutura docs/ ────────────────────────────

info "Criando estrutura docs/..."

mkdir -p "$TARGET_DIR/docs/specs"
mkdir -p "$TARGET_DIR/docs/design-system/pages"

# user-stories.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/user-stories.md" ]; then
  cat > "$TARGET_DIR/docs/user-stories.md" << 'STORIES_EOF'
# User Stories

> Gerado via REQUIREMENTS.md. Fonte de verdade para requisitos do projeto.
> Cada story segue o formato XP: Como [ator], quero [ação], para que [benefício].

---

<!-- Rodar o prompt do REQUIREMENTS.md para gerar as stories -->
STORIES_EOF
  ok "docs/user-stories.md (template)"
fi

# backlog.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/backlog.md" ]; then
  cat > "$TARGET_DIR/docs/backlog.md" << 'BACKLOG_EOF'
# Backlog

> Gerado via REQUIREMENTS.md. Modelo Kanban com priorização (P1/P2/P3).
> Ordenado por prioridade: P1 primeiro, depois P2, depois P3.

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** — Crítico | Bloqueia outras stories ou é requisito de lançamento |
| **P2** — Importante | Agrega valor significativo, fazer após P1 |
| **P3** — Desejável | Nice-to-have, fazer se sobrar capacidade |

---

<!-- Rodar o prompt do REQUIREMENTS.md para gerar o backlog -->
BACKLOG_EOF
  ok "docs/backlog.md (template)"
fi

# MASTER.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/design-system/MASTER.md" ]; then
  cat > "$TARGET_DIR/docs/design-system/MASTER.md" << 'MASTER_EOF'
# Design System

> Fonte de verdade visual do projeto.
> Gerado via DESIGN_SYSTEM.md (pipeline de 3 passos: ui-ux-pro-max → entrevista → brief).
> Para regras estruturais: ver `claude-design.md`.

---

<!-- Rodar o pipeline do DESIGN_SYSTEM.md para gerar o design system -->
MASTER_EOF
  ok "docs/design-system/MASTER.md (template)"
fi

# design-brief.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/design-system/design-brief.md" ]; then
  cat > "$TARGET_DIR/docs/design-system/design-brief.md" << 'BRIEF_EOF'
# Design Brief

> Resumo compacto (~800 tokens) do MASTER.md para injeção em subagentes de componente.
> Gerado automaticamente a partir do MASTER.md. Fonte de verdade: MASTER.md.

---

<!-- Gerado automaticamente após o MASTER.md estar completo -->
BRIEF_EOF
  ok "docs/design-system/design-brief.md (template)"
fi

# .gitkeep em pastas vazias
touch "$TARGET_DIR/docs/specs/.gitkeep" 2>/dev/null || true
touch "$TARGET_DIR/docs/design-system/pages/.gitkeep" 2>/dev/null || true

ok "Estrutura docs/ completa"

# ── Git hook (post-commit) ─────────────────────

info "Instalando git hook..."

mkdir -p "$TARGET_DIR/.githooks"

cat > "$TARGET_DIR/.githooks/post-commit" << 'HOOK_EOF'
#!/usr/bin/env bash
REFACTOR_FILE="claude-stacks-refactor.md"
[ ! -f "$REFACTOR_FILE" ] && exit 0
COUNT=$(grep -c "Pendente" "$REFACTOR_FILE" 2>/dev/null || true)
if [ "$COUNT" -gt 0 ]; then
  echo ""
  echo ">>> $COUNT candidato(s) pendente(s) de promocao no claude-stacks-refactor.md"
  echo "    Rode: ./promote-learning.sh /path/to/template-fullstack"
  echo ""
fi
HOOK_EOF

chmod +x "$TARGET_DIR/.githooks/post-commit"

# Configurar git para usar a pasta de hooks (só funciona se for um repo git)
if [ -d "$TARGET_DIR/.git" ]; then
  git -C "$TARGET_DIR" config core.hooksPath .githooks
  ok ".githooks/post-commit instalado + core.hooksPath configurado"
else
  ok ".githooks/post-commit criado (configurar core.hooksPath após git init)"
fi

# ── Resumo ─────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Workflow adotado com sucesso!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "Arquivos copiados para: $TARGET_DIR"
echo ""
echo "  Próximos passos:"
echo ""
echo "  1. Revisar o CLAUDE.md e ajustar ao seu projeto"
if [ "$HAS_CLAUDE" = true ]; then
  echo "     (backup do anterior em CLAUDE.md.bak)"
fi
echo "  2. (opcional) Ativar rastreamento GitHub Issues (requer gh autenticado):"
echo "     ./setup-github-project.sh"
echo "  3. Rodar REQUIREMENTS.md para gerar stories e backlog"
echo "  4. Rodar DESIGN_SYSTEM.md para gerar o design system"
echo "  5. Commitar:"
echo "     git add . && git commit -m 'docs: adopt SDD/TDD workflow'"
echo ""

if [ "$HAS_APPS" = false ]; then
  warn "Projeto sem apps/ detectado."
  echo "     Se for projeto novo, diga ao Claude Code: 'Iniciar projeto novo'"
  echo "     Se for projeto existente com outra estrutura, adapte o CLAUDE.md"
fi
