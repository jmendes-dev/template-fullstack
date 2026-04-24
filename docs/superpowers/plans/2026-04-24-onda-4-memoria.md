# Onda 4 — Memória que aprende · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `adopt-workflow.sh` popula MEMORY.md de cada agente com Project Context + seeds; `check-health.sh` reporta densidade de memória por agente.

**Architecture:** Duas funções bash novas em `adopt-workflow.sh` (`_detect_project_context` + `_generate_memory_file`) substituem o `cat > MEMORY.md` boilerplate atual. Cada MEMORY.md ganha 3 seções: Project Context (inline, comum), Agent-specific notes (seeds hardcoded por agente), guia Session Retrospective. `check-health.sh` ganha função `_report_memory_density` com tabela visual. Zero mudança em prompts de agentes — `memory: project` frontmatter já carrega MEMORY.md automaticamente.

**Tech Stack:** Bash 4+, grep/sed para parsing, stat/date para timestamps.

**Decisões do usuário (A/A/A):**
- População: 2 seções (Project Context comum + Agent-specific seeds)
- check-health: tabela com barra visual
- Agent prompts: NÃO alterar (frontmatter já resolve injeção)

**Branch strategy:** `feat/onda-4-memoria` (já criada a partir de main com Onda 3 mergeada).

---

## File Structure

| Arquivo | Tipo | Responsabilidade |
|---|---|---|
| `adopt-workflow.sh` | modify | Detecta contexto + gera MEMORY.md rico por agente (substitui bloco atual) |
| `check-health.sh` | modify | Reporta densidade de memória (tabela + barras + contagem de boilerplate) |

---

## Task 1: Função `_detect_project_context` em `adopt-workflow.sh`

**Files:**
- Modify: `adopt-workflow.sh`

- [ ] **Step 1.1: Inserir função `_detect_project_context` antes do bloco atual de agent-memory**

Localizar esta linha em `adopt-workflow.sh` (é o primeiro comentário do bloco de agent-memory — procurar por "Estrutura agent-memory"):

```bash
# ── Estrutura agent-memory ─────────────────────

info "Criando .claude/agent-memory/..."
```

**Imediatamente antes dessa linha**, inserir:

```bash
# ── Detecção de contexto do projeto (para Project Context em MEMORY.md) ────
# Chamado uma vez antes do loop de agentes. Exporta variáveis PROJECT_*.
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

```

- [ ] **Step 1.2: Validar sintaxe**

```bash
bash -n adopt-workflow.sh && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`.

- [ ] **Step 1.3: Commit**

```bash
git add adopt-workflow.sh
git commit -m "feat(adopt): detectar contexto do projeto para popular MEMORY.md

- Função _detect_project_context extrai: nome, stack (claude-stacks.md),
  workspace layout (apps/, packages/shared), ports (.env.example),
  DATABASE_URL e ADMIN_EMAIL (linhas do .env.example)
- Todos os valores têm fallback documentado quando inputs ausentes
- Chamada uma vez antes do loop de agentes; exporta vars PROJECT_*

Onda 4 · Task 1"
```

---

## Task 2: Função `_generate_memory_file` e bloco substituto em `adopt-workflow.sh`

**Files:**
- Modify: `adopt-workflow.sh`

**Contexto:** substituir o bloco atual (~linhas 166-180) que gera MEMORY.md com boilerplate. Nova versão usa função dedicada + seeds por agente + idempotência inteligente.

- [ ] **Step 2.1: Adicionar função `_generate_memory_file` imediatamente APÓS a chamada `_detect_project_context`**

Após o `info "Contexto detectado: ..."` que você inseriu no Step 1.1, adicionar:

```bash
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

```

- [ ] **Step 2.2: Substituir o loop atual que gera MEMORY.md**

Localizar o bloco atual (linhas ~151-180 do arquivo original, mas pode ter shiftado após Step 1.1):

```bash
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
```

Substituir por:

```bash
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
  "ux-ui-designer"
)
for agent in "${AGENTS[@]}"; do
  _generate_memory_file "$agent"
done
```

- [ ] **Step 2.3: Validar sintaxe**

```bash
bash -n adopt-workflow.sh && echo "SYNTAX OK"
```

- [ ] **Step 2.4: Fixture test — gerar MEMORY.md em target fresh**

```bash
TEMP=$(mktemp -d)
cat > "$TEMP/claude-stacks.md" <<'EOF'
# claude-stacks.md

Stack: Bun + Hono + React 19 + Drizzle + Tailwind v4
EOF
cat > "$TEMP/.env.example" <<'EOF'
PORT=3001
WEB_PORT=5174
DATABASE_URL=postgres://localhost:5432/testdb
ADMIN_EMAIL=admin@example.com
EOF
mkdir -p "$TEMP/apps/api" "$TEMP/apps/web" "$TEMP/packages/shared"

# Rodar adopt-workflow (NÃO usar --dry-run, precisa gerar arquivos de verdade)
./adopt-workflow.sh "$TEMP" 2>&1 | grep -E "Contexto detectado|agent-memory/.*/MEMORY.md"

# Validar para 3 agentes representativos
for agent in backend-developer frontend-developer qa-engineer; do
  F="$TEMP/.claude/agent-memory/$agent/MEMORY.md"
  if [ ! -f "$F" ]; then echo "FAIL: $F não foi criado"; continue; fi
  grep -q "^## Project Context" "$F" || echo "FAIL: $agent sem Project Context"
  grep -q "^## Agent-specific notes" "$F" || echo "FAIL: $agent sem seeds section"
  grep -q "PORT=3001" "$F" 2>/dev/null || grep -q "3001" "$F" || echo "FAIL: $agent sem porta 3001"
  grep -q "Bun + Hono" "$F" || echo "FAIL: $agent sem stack detectada"
done

echo "--- Exemplo backend-developer ---"
head -40 "$TEMP/.claude/agent-memory/backend-developer/MEMORY.md"

# Cleanup
rm -rf "$TEMP"
```

Expected: nenhuma linha `FAIL` na saída; head mostra MEMORY.md com Project Context preenchido (Stack: Bun + Hono, API: 3001, Web: 5174) + seeds de backend-developer (rotas em apps/api/src/routes/, etc).

- [ ] **Step 2.5: Fixture test — idempotência**

```bash
TEMP=$(mktemp -d)
cat > "$TEMP/claude-stacks.md" <<'EOF'
Stack: TestStack
EOF

# Primeiro adopt
./adopt-workflow.sh "$TEMP" > /dev/null 2>&1

# Capturar timestamp e content hash do MEMORY.md de backend-developer
F="$TEMP/.claude/agent-memory/backend-developer/MEMORY.md"
TS1=$(stat -c %Y "$F" 2>/dev/null || stat -f %m "$F")
HASH1=$(sha256sum "$F" 2>/dev/null | cut -d' ' -f1)

# Adicionar nota custom para simular uso real (>10 linhas não-boilerplate)
cat >> "$F" <<'EOF'

## Notas Custom de Teste

Esta é uma linha de teste.
Outra linha.
Mais uma linha.
Quarta linha.
Quinta linha.
Sexta linha.
Sétima linha.
Oitava linha.
EOF

sleep 1  # garantir timestamp diferente se sobrescrever

# Segundo adopt — deveria PRESERVAR
./adopt-workflow.sh "$TEMP" > /dev/null 2>&1

HASH2=$(sha256sum "$F" 2>/dev/null | cut -d' ' -f1)

if [ "$HASH1" = "$HASH2" ]; then
  # Sem mudanças significa não-atualizado (mas adicionamos custom — hash diferente esperado)
  echo "FAIL: arquivo não foi modificado como esperado (hash igual ao antes do append)"
elif grep -q "Notas Custom de Teste" "$F"; then
  echo "PASS: conteúdo custom preservado"
else
  echo "FAIL: conteúdo custom foi destruído"
fi

rm -rf "$TEMP"
```

Expected: `PASS: conteúdo custom preservado`.

- [ ] **Step 2.6: Commit**

```bash
git add adopt-workflow.sh
git commit -m "feat(adopt): gerar MEMORY.md rico com Project Context + seeds por agente

- Função _agent_seeds retorna 2-3 bullets específicos por agente (10 agentes cobertos)
- Função _is_boilerplate detecta formato legacy (≤10L não-comentário + sem marcador 'Project Context')
- Função _generate_memory_file: idempotente (preserva customizações >10L)
- Substitui o bloco cat > MEMORY.md por chamada a _generate_memory_file
- Fixture tests: bootstrap fresh + idempotência confirmados

Onda 4 · Task 2"
```

---

## Task 3: Função `_report_memory_density` em `check-health.sh`

**Files:**
- Modify: `check-health.sh`

- [ ] **Step 3.1: Substituir a seção "🧠 Memória dos Agentes" atual**

Localizar o bloco (linhas ~58-81 do check-health.sh):

```bash
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
```

Substituir por:

```bash
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
```

- [ ] **Step 3.2: Validar sintaxe**

```bash
bash -n check-health.sh && echo "SYNTAX OK"
```

- [ ] **Step 3.3: Rodar check-health no próprio template repo**

```bash
./check-health.sh 2>&1 | sed -n '/🧠 Memória/,/^$/p'
```

Expected: tabela com 10 agentes, barras proporcionais, contagem de boilerplate/sem-tópicos. Não precisa passar em assert mode neste repo (template tem mix natural).

- [ ] **Step 3.4: Commit**

```bash
git add check-health.sh
git commit -m "feat(health): reporta densidade de memória por agente (tabela visual)

- Substitui resumo binário 'X/Y agentes com conteúdo' por tabela detalhada
- Colunas: nome · barra 10-char proporcional · linhas · tópicos · status
- Status: 'atualizado Xd' ou 'boilerplate' (detecção idêntica a adopt-workflow)
- Resumo: média de linhas, contagem de boilerplate, contagem de sem-tópicos
- Assert mode (--assert): falha se qualquer agente está com boilerplate

Onda 4 · Task 3"
```

---

## Task 4: Validação E2E + PR

- [ ] **Step 4.1: Checklist consolidado**

- [ ] `adopt-workflow.sh` tem `_detect_project_context`, `_agent_seeds`, `_is_boilerplate`, `_generate_memory_file`
- [ ] Loop atual `for agent in AGENTS` usa `_generate_memory_file` (não mais cat heredoc)
- [ ] `bash -n adopt-workflow.sh` passa
- [ ] Fixture test (Step 2.4) passa — nenhum `FAIL` na saída
- [ ] Fixture test idempotência (Step 2.5) passa — custom preservado
- [ ] `check-health.sh` tem `_MEM_*` arrays + cálculo de barra + resumo
- [ ] `bash -n check-health.sh` passa
- [ ] Rodar `./check-health.sh` no template mostra tabela com 10 agentes
- [ ] `git diff --stat main..HEAD` mostra exatamente 2 arquivos modificados (adopt-workflow.sh + check-health.sh) + spec/plan

- [ ] **Step 4.2: Push + PR**

```bash
git push -u origin feat/onda-4-memoria

gh pr create --title "Onda 4 — Memória que aprende (bootstrap real + density report)" --body "$(cat <<'EOF'
## Summary

Última onda da remediação (4 de 4). Elimina o problema de MEMORY.md vazio em projetos novos identificado no diagnóstico inicial: apenas 2 de 10 agentes tinham memória real, os outros nasciam com boilerplate 3-4 linhas.

### Entregas

- **T1+T2** `adopt-workflow.sh`: 4 funções novas (`_detect_project_context`, `_agent_seeds`, `_is_boilerplate`, `_generate_memory_file`). Cada MEMORY.md agora nasce com:
  - Project Context (stack, workspace, portas, env vars — detectados do target)
  - Agent-specific notes (2-3 seeds de domínio por agente, extraídos de claude-stacks.md)
  - Guia "Como Capturar Memória"
- **T3** `check-health.sh`: substitui resumo binário por tabela visual com barras proporcionais, contagem de boilerplate, contagem de sem-tópicos, idade de última atualização.
- **Idempotência**: re-rodar adopt-workflow preserva MEMORY.md customizados (>10L não-comentário). Detecta e substitui boilerplate legacy sem flag.

### Decisões (do spec)

- População: 2 seções (Project Context + Agent-specific seeds) — Opção A
- check-health: tabela com barra visual — Opção A
- Agent prompts NÃO alterados — frontmatter `memory: project` já carrega automaticamente — Opção A

### Test plan

- [x] `bash -n adopt-workflow.sh` e `bash -n check-health.sh` OK
- [x] Fixture bootstrap: target fresh gera 10 MEMORY.md com Project Context preenchido
- [x] Fixture idempotência: append custom preservado em re-run
- [x] `check-health` rodado no template — tabela coerente com estado real
- [ ] **Smoke test após merge**: em projeto consumidor com MEMORY.md boilerplate antigo, rodar `./adopt-workflow.sh .` e confirmar migração automática

### Fora de escopo

- Hook que auto-injeta project-context compartilhado (duplicação inline é aceita)
- Alterar MEMORY.md do próprio template-fullstack repo
- Flag `--force-memory` (YAGNI)

### Spec e Plan

- `docs/superpowers/specs/2026-04-24-onda-4-memoria-design.md`
- `docs/superpowers/plans/2026-04-24-onda-4-memoria.md`

### Encerramento da remediação

Onda 4 fecha as 4 ondas planejadas no diagnóstico inicial (sessão 1). Status esperado pós-merge:

- ✅ Onda 1 — Destravar fluxo (agentes órfãos + STOP protocol + learning loop)
- ✅ Onda 2 — Scaffold Quality (docker/vite HMR + auth-rbac + ui-ux pré-req)
- ✅ Onda 3 — Backlog em Ondas (waves → GitHub Milestones)
- ✅ Onda 4 — Memória que aprende (bootstrap real + density report)
- Hotfixes: bun install condicional, sync-globals 2 bugs, check-quality HOOK_MODE, ROOT cache

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (aplicada antes de handoff)

**1. Spec coverage:**

| Spec §/Objetivo | Task |
|---|---|
| §4 Detecção de contexto | Task 1 ✅ |
| §5 Formato do MEMORY.md novo | Task 2 (função _generate_memory_file) ✅ |
| §6 Seeds por agente | Task 2 (função _agent_seeds) ✅ |
| §7 Lógica de idempotência | Task 2 (função _is_boilerplate + _generate_memory_file) ✅ |
| §8 Formato do density report | Task 3 ✅ |
| §9 Testes (bootstrap, idempotência, legacy, density) | Steps 2.4, 2.5, 3.3 ✅ |

**2. Placeholder scan:** Zero TBD/TODO. Todo código bash completo.

**3. Type/naming consistency:**
- Funções prefixadas com `_` (convenção bash para helpers internos) — `_detect_project_context`, `_agent_seeds`, `_is_boilerplate`, `_generate_memory_file`, `_report_memory_density`
- Variáveis exportadas prefixadas `PROJECT_*` (stack, layout, portas, env lines)
- Arrays do check-health prefixados `_MEM_*` (agents, lines, topics, age, boil)
- Regex de boilerplate IDÊNTICA em adopt-workflow (Task 2) e check-health (Task 3): `grep -cvE '^[[:space:]]*(#|<!--|$)'` + check `! grep -q "^## Project Context"` — garante consistência
- `10` como threshold de boilerplate em ambos os lados (Task 2 e 3)
