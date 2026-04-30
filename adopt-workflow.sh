#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# adopt-workflow.sh
# Adota o workflow SDD/TDD em um projeto existente.
# Copia arquivos estruturais e cria a estrutura docs/.
# ──────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Argument parsing — suporta --dry-run
DRY_RUN=false
_ARGS=()
for _arg in "$@"; do
  case "$_arg" in
    --dry-run) DRY_RUN=true ;;
    *) _ARGS+=("$_arg") ;;
  esac
done
TARGET_DIR="${_ARGS[0]:-.}"

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

# ── Dry-run: mostrar o que seria feito e sair ────────────────
if [ "$DRY_RUN" = true ]; then
  source "$SCRIPT_DIR/.claude/lib/global-files.sh"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  DRY RUN — Nenhum arquivo será modificado"
  echo "  Destino: $TARGET_DIR"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📄 Arquivos globais (${#GLOBAL_FILES[@]}):"
  for _f in "${GLOBAL_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$_f" ]; then
      echo "  + $_f"
    else
      echo "  ⚠ $_f (ausente no template)"
    fi
  done
  echo ""
  echo "🤖 Agentes (${#AGENT_FILES[@]}):"
  for _f in "${AGENT_FILES[@]}"; do echo "  + .claude/agents/$_f"; done
  echo ""
  echo "📋 Commands (${#COMMAND_FILES[@]}):"
  for _f in "${COMMAND_FILES[@]}"; do echo "  + .claude/commands/$_f"; done
  echo ""
  echo "📁 Estrutura docs/ criada (backlog.md, user-stories.md, session-state.md, etc.)"
  echo "🪝 Git hook instalado em .githooks/post-commit"
  [ "$HAS_CLAUDE" = true ] && warn "CLAUDE.md existente seria renomeado para CLAUDE.md.bak"
  echo ""
  echo "Execute sem --dry-run para aplicar."
  echo ""
  exit 0
fi

if [ "$HAS_CLAUDE" = true ]; then
  warn "CLAUDE.md já existe no projeto. Será renomeado para CLAUDE.md.bak"
  cp "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.bak"
fi

# ── Detecção de contexto do projeto (para Project Context em MEMORY.md) ────
# Chamado antes do loop de agentes. Exporta variáveis PROJECT_*.
# Deve rodar ANTES de copiar arquivos globais para ler o .env.example original do target.
_detect_project_context() {
  # Project name: package.json → .name ou basename do target
  if [ -f "$TARGET_DIR/package.json" ] && command -v jq &>/dev/null; then
    PROJECT_NAME=$(jq -r '.name // empty' "$TARGET_DIR/package.json" 2>/dev/null || echo "")
  fi
  [ -z "${PROJECT_NAME:-}" ] && PROJECT_NAME=$(basename "$TARGET_DIR")

  # Stack summary: primeira linha "Stack" de claude-stacks.md
  if [ -f "$TARGET_DIR/claude-stacks.md" ]; then
    PROJECT_STACK=$(grep -m1 -E '^[[:space:]]*(Monorepo|Stack)' "$TARGET_DIR/claude-stacks.md" 2>/dev/null \
                   | head -c 200 | sed 's/^[[:space:]]*//' || echo "")
  fi
  [ -z "${PROJECT_STACK:-}" ] && PROJECT_STACK="Stack não detectada — ver claude-stacks.md"

  # Workspace layout
  local _layout=""
  [ -d "$TARGET_DIR/apps/api" ] && _layout="${_layout}apps/api "
  [ -d "$TARGET_DIR/apps/web" ] && _layout="${_layout}apps/web "
  [ -d "$TARGET_DIR/packages/shared" ] && _layout="${_layout}packages/shared"
  if [ -z "$_layout" ]; then
    PROJECT_LAYOUT="monorepo não inicializado (rode /new-project)"
  else
    PROJECT_LAYOUT="$_layout"
  fi

  # Ports do .env.example
  PROJECT_API_PORT="3000"
  PROJECT_WEB_PORT="5173"
  if [ -f "$TARGET_DIR/.env.example" ]; then
    local _p
    _p=$(grep -m1 -E '^(API_)?PORT=' "$TARGET_DIR/.env.example" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    [ -n "$_p" ] && PROJECT_API_PORT="$_p"
    _p=$(grep -m1 -E '^WEB_PORT=' "$TARGET_DIR/.env.example" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    [ -n "$_p" ] && PROJECT_WEB_PORT="$_p"
  fi

  # Env vars chave (só echo das linhas inteiras — preserva comentários)
  PROJECT_DB_URL_LINE="DATABASE_URL=... (não configurada)"
  PROJECT_ADMIN_EMAIL_LINE="ADMIN_EMAIL=... (ver docs/auth-rbac.md)"
  if [ -f "$TARGET_DIR/.env.example" ]; then
    local _l
    _l=$(grep -m1 -E '^DATABASE_URL=' "$TARGET_DIR/.env.example" 2>/dev/null || echo "")
    [ -n "$_l" ] && PROJECT_DB_URL_LINE="$_l"
    _l=$(grep -m1 -E '^ADMIN_EMAIL=' "$TARGET_DIR/.env.example" 2>/dev/null || echo "")
    [ -n "$_l" ] && PROJECT_ADMIN_EMAIL_LINE="$_l"
  fi

  export PROJECT_NAME PROJECT_STACK PROJECT_LAYOUT PROJECT_API_PORT PROJECT_WEB_PORT
  export PROJECT_DB_URL_LINE PROJECT_ADMIN_EMAIL_LINE
}

_detect_project_context
info "Contexto detectado: $PROJECT_NAME · $PROJECT_STACK"

# ── Arquivos globais (sempre copiar) ──────────

# Fonte de verdade: .claude/lib/global-files.sh
# shellcheck source=.claude/lib/global-files.sh
source "$SCRIPT_DIR/.claude/lib/global-files.sh"

info "Copiando arquivos globais..."
mkdir -p "$TARGET_DIR/.claude/lib"
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.superpowers"
for file in "${GLOBAL_FILES[@]}"; do
  if [ -f "$SCRIPT_DIR/$file" ]; then
    mkdir -p "$TARGET_DIR/$(dirname "$file")"
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

# ── Slash commands ─────────────────────────────

info "Copiando .claude/commands/..."
mkdir -p "$TARGET_DIR/.claude/commands"
if [ -d "$SCRIPT_DIR/.claude/commands" ]; then
  for f in "$SCRIPT_DIR/.claude/commands/"*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$TARGET_DIR/.claude/commands/$(basename "$f")"
    echo "  ✓ $(basename "$f")"
  done
  ok "Slash commands copiados"
else
  warn ".claude/commands/ não encontrado no template — pulando"
fi

# Seeds específicos por agente — hardcoded (extraídos de claude-stacks.md e agent prompts)
_agent_seeds() {
  case "$1" in
    backend-developer) cat <<'S'
- Rotas em `apps/api/src/routes/<kebab-case>.ts` — registrar no `apps/api/src/index.ts`
- Schemas vivem em `packages/shared/src/schemas/` (nunca redefinir localmente)
- `getAuth(c)` é síncrono no Hono — nunca reimplementar JWT ou sessões
S
      ;;
    frontend-developer) cat <<'S'
- Ler `docs/design-system/design-brief.md` ANTES de implementar qualquer componente
- 4 estados obrigatórios em todo componente com dados: loading/empty/error/success
- Data fetching em custom hooks (TanStack Query) — nunca em componentes
S
      ;;
    data-engineer-dba) cat <<'S'
- Schemas Drizzle + Zod em `packages/shared/src/schemas/` — fonte única de verdade
- Migrations: `bun run db:generate && bun run db:migrate`
- Cascade FK documentada no schema (ON DELETE CASCADE / SET NULL / RESTRICT)
S
      ;;
    devops-sre-engineer) cat <<'S'
- Dockerfile sempre multi-stage + non-root user; base `oven/bun:1.3` (nunca `:latest`)
- Baseline dev: copiar `templates/docker-compose.yml` + `templates/vite.config.ts` do template
- CI fail-fast: lint → typecheck → test → sonar → build
S
      ;;
    qa-engineer) cat <<'S'
- Cobertura mínima 95% em business domain code (validators, routes, auth, edge cases)
- Cenários de spec mapeados via `it('Cenário X.Y: ...')` — checado por `check-spec-coverage.sh`
- Test runner único: `bun test` (nunca outro)
S
      ;;
    project-manager) cat <<'S'
- Backlog em `docs/backlog.md` usa waves (`## Wave: <Nome>`) mapeadas a GitHub Milestones
- P1/P2/P3 é ordem INTERNA da wave ativa (não global)
- `/finish` Passo 4: marcar US concluída + rodar sync-github-issues.sh (fecha issue)
S
      ;;
    requirements-roadmap-builder) cat <<'S'
- PRDs em `plans/<feature>.md` · planos de implementação em `plans/<feature>-plano.md`
- Cada Fase do plano vira uma Wave no backlog (via PM agent — Passo 5.5 do prd-planejamento)
- Fase 0 (fundação) → Wave: Backlog (não é entrega visível ao cliente)
S
      ;;
    security-engineer) cat <<'S'
- OWASP Top 10 + validação Zod em toda rota que aceita input
- RBAC: Clerk provê identidade; papel (admin/user) em tabela custom — ver `docs/auth-rbac.md`
- `ADMIN_EMAIL` bootstrap: email === `process.env.ADMIN_EMAIL` → role=admin (determinístico)
S
      ;;
    software-architect) cat <<'S'
- ADRs em `docs/adr/` numeradas (ADR-0001, ADR-0002, ...)
- Monorepo: `apps/api`, `apps/web`, `packages/shared` — nunca import runtime cross-app
- Decisões estruturais antes de código; updates em claude-stacks.md requerem justificativa
S
      ;;
    tech-lead) cat <<'S'
- Nunca escreve código — apenas ANALYZE → BRIEF → DELEGATE → VALIDATE
- Brief em `docs/tasks/brief-YYYY-MM-DD-<slug>.md` com critérios de aceite explícitos
- Invocar para bugs não-óbvios (após diagnóstico) e para tasks de feature antes de delegar ao especialista
S
      ;;
    ux-ui-designer) cat <<'S'
- `docs/design-system/MASTER.md` é fonte de verdade visual (gerada via pipeline da Parte 2 do DESIGN.md)
- `design-brief.md` é resumo compacto (~800 tokens) injetado em subagentes de componente
- Regras estruturais em `DESIGN.md` Parte 1 · personalidade visual em MASTER.md
S
      ;;
    *) cat <<'S'
- (Sem seeds específicos — agente não-padrão. Adicionar notas manualmente.)
S
      ;;
  esac
}

# Detecta se MEMORY.md existente é boilerplate legacy (ok sobrescrever)
# Regra: ≤10 linhas não-comentário E sem marcador "## Project Context"
_is_boilerplate() {
  local f="$1"
  [ ! -f "$f" ] && return 1  # não existe → não é boilerplate, é criação fresh
  if grep -q "^## Project Context" "$f" 2>/dev/null; then
    return 1  # já está no formato novo — preservar
  fi
  local _non_comment_lines
  _non_comment_lines=$(grep -cvE '^[[:space:]]*(#|<!--|$)' "$f" 2>/dev/null || echo "0")
  [ "$_non_comment_lines" -le 10 ]
}

# Gera MEMORY.md para um agente específico
_generate_memory_file() {
  local agent="$1"
  local dir="$TARGET_DIR/.claude/agent-memory/$agent"
  local file="$dir/MEMORY.md"

  mkdir -p "$dir"

  # Idempotência: se existe E tem conteúdo real, preservar
  if [ -f "$file" ] && ! _is_boilerplate "$file"; then
    ok "agent-memory/$agent/MEMORY.md (preservado — conteúdo custom)"
    return 0
  fi

  # Gerar/substituir
  local _today
  _today=$(date '+%Y-%m-%d')
  local _seeds
  _seeds=$(_agent_seeds "$agent")

  cat > "$file" <<MEMEOF
# MEMORY.md — $agent

> Memória persistente do agente. Carregada automaticamente via frontmatter \`memory: project\`.
> Gerada inicialmente por \`./adopt-workflow.sh\` em $_today. Atualizada pelo próprio agente durante sessões.

---

## Project Context (comum)

**Projeto:** $PROJECT_NAME
**Stack:** $PROJECT_STACK
**Workspace:** $PROJECT_LAYOUT

**Portas:**
- API: $PROJECT_API_PORT
- Web: $PROJECT_WEB_PORT

**Env vars chave:**
- \`$PROJECT_DB_URL_LINE\`
- \`$PROJECT_ADMIN_EMAIL_LINE\`

> ℹ️ Se a stack ou estrutura mudou substancialmente, rodar \`./adopt-workflow.sh\` novamente para regenerar esta seção (seeds custom em "Agent-specific notes" são preservados se MEMORY.md tiver >10 linhas não-boilerplate).

---

## Agent-specific notes (seeds)

$_seeds

<!-- Abaixo deste comentário, o agente adiciona suas próprias notas durante o trabalho.
     Criar arquivos \`feedback_<topico>.md\` no mesmo diretório e linkar aqui. -->

---

## Como Capturar Memória (Session Retrospective)

**Quando:**
- Padrão novo descoberto (configuração, workaround, decisão de design)
- Bug resolvido após > 15 min de investigação
- Decisão arquitetural tomada (e o motivo)
- Anti-pattern encontrado que deve ser evitado

**Como:**
1. Criar arquivo \`feedback_<topico>.md\` neste diretório com frontmatter:
   \`\`\`markdown
   ---
   name: [nome curto]
   description: [1 linha — usado para decidir relevância em futuras sessões]
   type: feedback
   ---
   \`\`\`
2. Adicionar bullet em "Agent-specific notes" acima linkando para o arquivo

**Promover entre projetos:** se o aprendizado é reutilizável, marcar em \`claude-stacks-refactor.md\` como \`⏳ Pendente\` e rodar \`./promote-learning.sh\` no fim do ciclo.
MEMEOF

  ok "agent-memory/$agent/MEMORY.md"
}

# ── Estrutura agent-memory ─────────────────────

info "Criando .claude/agent-memory/ com Project Context + seeds por agente..."
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
  "tech-lead"
  "ux-ui-designer"
)
for agent in "${AGENTS[@]}"; do
  _generate_memory_file "$agent"
done

# ── Arquivos instanciados (copiar se não existem) ──

INSTANCE_FILES=(
  "CLAUDE.md"
)

info "Copiando arquivos instanciados (sem sobrescrever existentes)..."
for file in "${INSTANCE_FILES[@]}"; do
  if [ -f "$SCRIPT_DIR/$file" ]; then
    if [ ! -f "$TARGET_DIR/$file" ]; then
      cp "$SCRIPT_DIR/$file" "$TARGET_DIR/$file"
      ok "$file"
    else
      warn "$file já existe — mantendo versão do projeto (use --force-claude-md para reinstalar)"
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
> **Hierarquia**: `CLAUDE.md` > `claude-sdd.md` > `claude-stacks.md` > `DESIGN.md` > `claude-stacks-refactor.md`

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

> Fonte de verdade para requisitos do projeto.
> Cada story segue o formato XP: Como [ator], quero [ação], para que [benefício].
> **Para gerar:** usar o comando `/new-project` e seguir a entrevista de levantamento de requisitos.

---

<!-- Exemplo de story (remover após gerar o conteúdo real):

### US-01 — Autenticação de usuário
**Como** visitante, **quero** criar conta e fazer login, **para que** eu possa acessar funcionalidades protegidas.

**Critérios de aceite:**
- [ ] Posso me registrar com e-mail e senha
- [ ] Posso fazer login com credenciais válidas
- [ ] Recebo mensagem de erro clara em credenciais inválidas
- [ ] Sessão persiste ao recarregar a página

**Estimativa:** M (3-5 dias)
**Prioridade:** P1

-->
STORIES_EOF
  ok "docs/user-stories.md (template)"
fi

# backlog.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/backlog.md" ]; then
  cat > "$TARGET_DIR/docs/backlog.md" << 'BACKLOG_EOF'
# Backlog

> Modelo Kanban com priorização (P1/P2/P3).
> Ordenado por prioridade: P1 primeiro, depois P2, depois P3.
> **Para gerar:** usar o comando `/new-project` e seguir a entrevista de levantamento de requisitos.

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** — Crítico | Bloqueia outras stories ou é requisito de lançamento |
| **P2** — Importante | Agrega valor significativo, fazer após P1 |
| **P3** — Desejável | Nice-to-have, fazer se sobrar capacidade |

---

<!-- Exemplo de formato (remover após gerar o conteúdo real):

### US-01 — Autenticação de usuário · **P1**

**Status:** 🔴 Não iniciado

| Task | Agente | Status |
|------|--------|--------|
| 1.1 Criar schema de usuário (Drizzle) | data-engineer-dba | ⏳ |
| 1.2 Implementar endpoints POST /auth/register e POST /auth/login | backend-developer | ⏳ |
| 1.3 Implementar tela de login e registro | frontend-developer | ⏳ |

-->
BACKLOG_EOF
  ok "docs/backlog.md (template)"
fi

# MASTER.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/design-system/MASTER.md" ]; then
  cat > "$TARGET_DIR/docs/design-system/MASTER.md" << 'MASTER_EOF'
# Design System

> Fonte de verdade visual do projeto.
> Gerado via DESIGN.md (Parte 2 — pipeline de 3 passos: ui-ux-pro-max → entrevista → brief).
> Para regras estruturais: ver `DESIGN.md` (Parte 1).

---

<!-- Rodar o pipeline da Parte 2 do DESIGN.md para gerar o design system -->
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

# session-state.md (criar template se não existe)
if [ ! -f "$TARGET_DIR/docs/session-state.md" ]; then
  cat > "$TARGET_DIR/docs/session-state.md" << 'SESSION_EOF'
# Session State

> Atualizado pelo Claude antes de cada notificação ntfy (ao aguardar input do usuário).
> Injetado automaticamente no contexto via hook `UserPromptSubmit`.
> **OBRIGATÓRIO:** Preencher todas as seções antes de enviar a notificação ntfy.

---

## Contexto Ativo

- **Story:** --
- **Task:** --
- **Fase TDD:** Red | Green | Refactor

---

## Último Passo Executado

--

---

## Próximo Passo Esperado

--

---

## Questões Abertas

--

---

## Agentes Envolvidos nesta Sessão

--

---

_Última atualização: --_
SESSION_EOF
  ok "docs/session-state.md (template)"
fi

# quality.md (criar placeholder — gerado por check-quality.sh)
if [ ! -f "$TARGET_DIR/docs/quality.md" ]; then
  cat > "$TARGET_DIR/docs/quality.md" << 'QUALITY_EOF'
# Quality Dashboard

> Atualizado automaticamente após cada `bun test` via hook PostToolUse.
> Fonte de verdade para o estado de qualidade do projeto.

---

## Status Geral

| Métrica | Valor | Status |
|---------|-------|--------|
| Cobertura geral | --% | ⏳ |
| Lint (Biome) | -- | ⏳ |
| Typecheck | -- | ⏳ |
| Última execução | -- | -- |

---

## Cobertura por Módulo

| Módulo | Stmts | Branch | Funcs | Lines | Status |
|--------|-------|--------|-------|-------|--------|
| -- | --% | --% | --% | --% | ⏳ |

---

## Gates do DoD

- [ ] `bun test` passa com cobertura ≥ 95%
- [ ] `bunx biome check` zero erros
- [ ] `tsc --noEmit` zero erros
- [ ] Cenários do spec ativos cobertos (ver Spec Coverage abaixo)
- [ ] Code review aprovado (`superpowers:requesting-code-review`)

---

## Spec Coverage

| Spec | Cenário | Teste | Status |
|------|---------|-------|--------|
| -- | -- | -- | ⏳ |

---

## Bugs Abertos

| ID | Descrição | Severidade | Status |
|----|-----------|------------|--------|
| -- | -- | -- | -- |

---

_Gerado por `check-quality.sh` · Última atualização: --_
QUALITY_EOF
  ok "docs/quality.md (placeholder)"
fi

# .gitkeep em pastas vazias
touch "$TARGET_DIR/docs/specs/.gitkeep" 2>/dev/null || true
touch "$TARGET_DIR/docs/design-system/pages/.gitkeep" 2>/dev/null || true

# docs/adr/ — necessário para software-architect criar ADR-001
mkdir -p "$TARGET_DIR/docs/adr"
touch "$TARGET_DIR/docs/adr/.gitkeep" 2>/dev/null || true
ok "docs/adr/ (criado)"

ok "Estrutura docs/ completa"

# ── GitHub templates ──────────────────────────

info "Configurando .github/..."
mkdir -p "$TARGET_DIR/.github"
mkdir -p "$TARGET_DIR/.github/workflows"
touch "$TARGET_DIR/.github/workflows/.gitkeep" 2>/dev/null || true
ok ".github/workflows/ (criado — populate via devops-sre-engineer)"

if [ ! -f "$TARGET_DIR/.github/pull_request_template.md" ]; then
  cp "$SCRIPT_DIR/.github/pull_request_template.md" "$TARGET_DIR/.github/pull_request_template.md" 2>/dev/null || \
  cat > "$TARGET_DIR/.github/pull_request_template.md" << 'PR_EOF'
## O que essa PR faz?

<!-- Descreva em 1-3 frases o que foi implementado -->

---

## Story / Task

<!-- US-XX — Task X.Y — Título da task -->

---

## Definition of Done

- [ ] `bun test` passa (zero falhas)
- [ ] Cobertura de testes ≥ 95% (`docs/quality.md` atualizado)
- [ ] `bunx biome check` zero erros
- [ ] `tsc --noEmit` zero erros
- [ ] Todos os cenários do spec cobertos
- [ ] Code review aprovado (`superpowers:requesting-code-review`)
- [ ] `docs/backlog.md` atualizado com status da task
- [ ] Sem código hardcoded (cores, fontes, URLs de API, credenciais)

---

## Tipo de mudança

- [ ] Bug fix
- [ ] Nova feature
- [ ] Refatoração
- [ ] Docs / configuração
PR_EOF
  ok ".github/pull_request_template.md"
fi

# ── Configuração .claude/ ─────────────────────

info "Configurando .claude/settings.json..."
mkdir -p "$TARGET_DIR/.claude"

if [ ! -f "$TARGET_DIR/.claude/settings.json" ]; then
  if [ -f "$SCRIPT_DIR/.claude/settings.example.json" ]; then
    cp "$SCRIPT_DIR/.claude/settings.example.json" "$TARGET_DIR/.claude/settings.json"
    ok ".claude/settings.json criado a partir de settings.example.json"
    warn "Edite .claude/settings.json para ajustar os plugins instalados na sua conta"
  else
    warn ".claude/settings.example.json não encontrado — settings.json não criado"
    warn "Copie manualmente: cp .claude/settings.example.json .claude/settings.json"
  fi
else
  warn ".claude/settings.json já existe — mantendo (verifique se tem os hooks de enforcement)"
fi

if [ ! -f "$TARGET_DIR/.claude/settings.local.json" ] && [ -f "$TARGET_DIR/.claude/settings.local.example.json" ]; then
  cp "$TARGET_DIR/.claude/settings.local.example.json" "$TARGET_DIR/.claude/settings.local.json"
  ok ".claude/settings.local.json criado a partir do exemplo"
fi

# Criar .template-version no projeto alvo
if [ -f "$SCRIPT_DIR/TEMPLATE_VERSION" ]; then
  cp "$SCRIPT_DIR/TEMPLATE_VERSION" "$TARGET_DIR/.template-version"
  ok ".template-version ($(cat "$SCRIPT_DIR/TEMPLATE_VERSION" | tr -d '[:space:]'))"
fi

# ── Git hook (post-commit) ─────────────────────

info "Instalando git hook..."

mkdir -p "$TARGET_DIR/.githooks"

cat > "$TARGET_DIR/.githooks/post-commit" << 'HOOK_EOF'
#!/usr/bin/env bash
# post-commit — Avisos automáticos após commit

# ── 1. Candidatos de promoção pendentes ───────────────────────
REFACTOR_FILE="claude-stacks-refactor.md"
if [ -f "$REFACTOR_FILE" ] && grep -q "Pendente" "$REFACTOR_FILE" 2>/dev/null; then
  COUNT=$(grep -c "Pendente" "$REFACTOR_FILE" 2>/dev/null | tr -d '[:space:]')
  echo ""
  echo ">>> ${COUNT} candidato(s) pendente(s) de promoção em claude-stacks-refactor.md"
  echo "    Rode: ./promote-learning.sh /path/to/template-fullstack"
  echo ""
fi

# ── 2. Backlog atualizado → sugerir sync GitHub Issues ────────
if git diff-tree --no-commit-id -r --name-only HEAD 2>/dev/null | grep -q "docs/backlog.md"; then
  echo ""
  echo ">>> docs/backlog.md foi atualizado neste commit."
  echo "    Sincronize com GitHub Issues: ./sync-github-issues.sh"
  echo ""
fi

# ── 3. MASTER.md atualizado → design brief desatualizado ──────
if git diff-tree --no-commit-id -r --name-only HEAD 2>/dev/null | grep -q "docs/design-system/MASTER.md"; then
  echo ""
  echo ">>> docs/design-system/MASTER.md foi atualizado neste commit."
  echo "    Regenere o design brief (via ux-ui-designer):"
  echo "    'Regenerar design-brief.md a partir do MASTER.md atualizado'"
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
echo "  3. Usar o comando /new-project para gerar stories e backlog"
echo "  4. Rodar DESIGN.md (Parte 2) para gerar o design system"
echo "  5. Commitar:"
echo "     git add . && git commit -m 'docs: adopt SDD/TDD workflow'"
echo ""

if [ "$HAS_APPS" = false ]; then
  warn "Projeto sem apps/ detectado."
  echo "     Se for projeto novo, diga ao Claude Code: 'Iniciar projeto novo'"
  echo "     Se for projeto existente com outra estrutura, adapte o CLAUDE.md"
fi
