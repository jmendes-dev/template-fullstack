#!/usr/bin/env pwsh
# ──────────────────────────────────────────────
# adopt-workflow.ps1
# Adota o workflow SDD/TDD em um projeto existente.
# Versao nativa Windows do adopt-workflow.sh — usa cmdlets PowerShell
# para evitar processos externos (cp, grep, mkdir, date, jq).
# ──────────────────────────────────────────────
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SCRIPT_DIR = $PSScriptRoot

# ── Argument parsing ───────────────────────────
$DRY_RUN = $false
$PositionalArgs = @()
foreach ($arg in $args) {
    if ($arg -eq '--dry-run') { $DRY_RUN = $true }
    else { $PositionalArgs += $arg }
}
$TARGET_DIR = if ($PositionalArgs.Count -gt 0) { $PositionalArgs[0] } else { '.' }

# ── Output helpers ─────────────────────────────
function Write-Info  { param($msg) Write-Host "i  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "v  $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "!  $msg" -ForegroundColor Yellow }
function Write-Error-Exit { param($msg) Write-Host "x  $msg" -ForegroundColor Red; exit 1 }

# ── Validacao ──────────────────────────────────
if (-not (Test-Path $TARGET_DIR -PathType Container)) {
    Write-Error-Exit "Diretorio alvo nao encontrado: $TARGET_DIR"
}

$TARGET_DIR = (Resolve-Path $TARGET_DIR).Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  adopt-workflow.ps1 — SDD/TDD Workflow"
Write-Host "  Template: $SCRIPT_DIR"
Write-Host "  Target:   $TARGET_DIR"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# ── Deteccao de estrutura existente ────────────
$HAS_APPS   = Test-Path (Join-Path $TARGET_DIR 'apps') -PathType Container
$HAS_CLAUDE = Test-Path (Join-Path $TARGET_DIR 'CLAUDE.md') -PathType Leaf
$HAS_DOCS   = Test-Path (Join-Path $TARGET_DIR 'docs') -PathType Container

if ($HAS_APPS) {
    Write-Info "Detectado: projeto com estrutura apps/ (monorepo)"
} else {
    Write-Warn "Sem estrutura apps/ — o CLAUDE.md sera copiado mas o bootstrap pode ser necessario"
}

# ── Arrays equivalentes ao global-files.sh ─────
# Fonte de verdade original: .claude/lib/global-files.sh
$GLOBAL_FILES = @(
    'claude-stacks.md'
    'claude-stacks-versions.md'
    'claude-sdd.md'
    'DESIGN.md'
    'claude-debug.md'
    'start_project.md'
    '.gitattributes'
    'setup-github-project.sh'
    'sync-github-issues.sh'
    'sync-globals.sh'
    'promote-learning.sh'
    'check-health.sh'
    'check-quality.sh'
    'check-spec-coverage.sh'
    '.claude/lib/global-files.sh'
    '.claude/settings.local.example.json'
    '.claude/settings.example.json'
    '.claude/hooks/pre-tool-use.sh'
    '.claude/hooks/inject-context.sh'
    '.claude/hooks/post-tool-use.sh'
    'package.json.example'
    '.env.example'
    'biome.json.example'
    'tsconfig.json.example'
    'sonar-project.properties.example'
    '.github/pull_request_template.md'
    '.github/workflows/ci.yml'
    '.github/workflows/cd-portainer-uat.yml.example'
    '.github/workflows/cd-portainer-prd.yml.example'
    '.github/workflows/cd-railway.yml.example'
    '.superpowers/agent-memory-bootstrap.md'
)

$AGENT_FILES = @(
    'backend-developer.md'
    'data-engineer-dba.md'
    'devops-sre-engineer.md'
    'frontend-developer.md'
    'project-manager.md'
    'qa-engineer.md'
    'requirements-roadmap-builder.md'
    'security-engineer.md'
    'software-architect.md'
    'tech-lead.md'
    'ux-ui-designer.md'
)

$COMMAND_FILES = @(
    'bug.md'
    'triage.md'
    'feature.md'
    'finish.md'
    'continue.md'
    'new-project.md'
    'refactor.md'
)

# ── Dry-run ────────────────────────────────────
if ($DRY_RUN) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "  DRY RUN — Nenhum arquivo sera modificado"
    Write-Host "  Destino: $TARGET_DIR"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host ""
    Write-Host "Arquivos globais ($($GLOBAL_FILES.Count)):"
    foreach ($f in $GLOBAL_FILES) {
        $src = Join-Path $SCRIPT_DIR $f
        if (Test-Path $src -PathType Leaf) { Write-Host "  + $f" }
        else { Write-Host "  ! $f (ausente no template)" -ForegroundColor Yellow }
    }
    Write-Host ""
    Write-Host "Agentes ($($AGENT_FILES.Count)):"
    foreach ($f in $AGENT_FILES) { Write-Host "  + .claude/agents/$f" }
    Write-Host ""
    Write-Host "Commands ($($COMMAND_FILES.Count)):"
    foreach ($f in $COMMAND_FILES) { Write-Host "  + .claude/commands/$f" }
    Write-Host ""
    Write-Host "Estrutura docs/ criada (backlog.md, user-stories.md, session-state.md, etc.)"
    Write-Host "Git hook instalado em .githooks/post-commit"
    if ($HAS_CLAUDE) { Write-Warn "CLAUDE.md existente seria renomeado para CLAUDE.md.bak" }
    Write-Host ""
    Write-Host "Execute sem --dry-run para aplicar."
    Write-Host ""
    exit 0
}

# ── Backup CLAUDE.md ───────────────────────────
if ($HAS_CLAUDE) {
    Write-Warn "CLAUDE.md ja existe no projeto. Sera renomeado para CLAUDE.md.bak"
    Copy-Item (Join-Path $TARGET_DIR 'CLAUDE.md') (Join-Path $TARGET_DIR 'CLAUDE.md.bak') -Force
}

# ── Deteccao de contexto do projeto ────────────
# Exporta variaveis de projeto para uso no MEMORY.md por agente.
# Roda ANTES de copiar arquivos globais para ler .env.example original do target.

function Get-ProjectContext {
    # Nome: package.json → .name ou basename
    $script:PROJECT_NAME = ''
    $pkgJson = Join-Path $TARGET_DIR 'package.json'
    if (Test-Path $pkgJson -PathType Leaf) {
        try {
            $pkg = Get-Content $pkgJson -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($pkg.name) { $script:PROJECT_NAME = $pkg.name }
        } catch {}
    }
    if (-not $script:PROJECT_NAME) {
        $script:PROJECT_NAME = Split-Path $TARGET_DIR -Leaf
    }

    # Stack: primeira linha com "Monorepo" ou "Stack" em claude-stacks.md
    $script:PROJECT_STACK = 'Stack nao detectada — ver claude-stacks.md'
    $stackFile = Join-Path $TARGET_DIR 'claude-stacks.md'
    if (Test-Path $stackFile -PathType Leaf) {
        $match = Select-String -Path $stackFile -Pattern '^\s*(Monorepo|Stack)' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            $line = $match.Line.TrimStart()
            $script:PROJECT_STACK = if ($line.Length -gt 200) { $line.Substring(0, 200) } else { $line }
        }
    }

    # Workspace layout
    $layout = ''
    if (Test-Path (Join-Path $TARGET_DIR 'apps/api') -PathType Container) { $layout += 'apps/api ' }
    if (Test-Path (Join-Path $TARGET_DIR 'apps/web') -PathType Container) { $layout += 'apps/web ' }
    if (Test-Path (Join-Path $TARGET_DIR 'packages/shared') -PathType Container) { $layout += 'packages/shared' }
    $script:PROJECT_LAYOUT = if ($layout) { $layout.TrimEnd() } else { 'monorepo nao inicializado (rode /new-project)' }

    # Portas do .env.example
    $script:PROJECT_API_PORT = '3000'
    $script:PROJECT_WEB_PORT = '5173'
    $envExample = Join-Path $TARGET_DIR '.env.example'
    if (Test-Path $envExample -PathType Leaf) {
        $envLines = Get-Content $envExample -ErrorAction SilentlyContinue
        foreach ($line in $envLines) {
            if ($line -match '^(API_)?PORT=(.+)$' -and $script:PROJECT_API_PORT -eq '3000') {
                $script:PROJECT_API_PORT = $Matches[2].Trim()
            }
            if ($line -match '^WEB_PORT=(.+)$' -and $script:PROJECT_WEB_PORT -eq '5173') {
                $script:PROJECT_WEB_PORT = $Matches[1].Trim()
            }
        }
    }

    # Env vars chave
    $script:PROJECT_DB_URL_LINE     = 'DATABASE_URL=... (nao configurada)'
    $script:PROJECT_ADMIN_EMAIL_LINE = 'ADMIN_EMAIL=... (ver docs/auth-rbac.md)'
    if (Test-Path $envExample -PathType Leaf) {
        $envLines = Get-Content $envExample -ErrorAction SilentlyContinue
        foreach ($line in $envLines) {
            if ($line -match '^DATABASE_URL=') { $script:PROJECT_DB_URL_LINE = $line; break }
        }
        foreach ($line in $envLines) {
            if ($line -match '^ADMIN_EMAIL=') { $script:PROJECT_ADMIN_EMAIL_LINE = $line; break }
        }
    }
}

Get-ProjectContext
Write-Info "Contexto detectado: $PROJECT_NAME · $PROJECT_STACK"

# ── Copiar arquivos globais ─────────────────────
Write-Info "Copiando arquivos globais..."
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.claude/lib')   -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.claude/hooks') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.superpowers')  -Force | Out-Null

foreach ($file in $GLOBAL_FILES) {
    # Normaliza separadores: o array usa '/' mas Windows usa '\'
    $srcPath  = Join-Path $SCRIPT_DIR  ($file -replace '/', [IO.Path]::DirectorySeparatorChar)
    $destPath = Join-Path $TARGET_DIR  ($file -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (Test-Path $srcPath -PathType Leaf) {
        $destDir = Split-Path $destPath -Parent
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item $srcPath $destPath -Force
        Write-Ok $file
    } else {
        Write-Warn "$file nao encontrado no template — pulando"
    }
}

# ── Agentes especializados ──────────────────────
Write-Info "Copiando .claude/agents/..."
$agentsDir = Join-Path $TARGET_DIR '.claude/agents'
New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
$agentsSrc = Join-Path $SCRIPT_DIR '.claude/agents'
if (Test-Path $agentsSrc -PathType Container) {
    $count = 0
    foreach ($f in $AGENT_FILES) {
        $src = Join-Path $agentsSrc $f
        if (Test-Path $src -PathType Leaf) {
            Copy-Item $src (Join-Path $agentsDir $f) -Force
            $count++
        }
    }
    Write-Ok "$count agente(s) copiado(s)"
} else {
    Write-Warn ".claude/agents/ nao encontrado no template — pulando"
}

# ── Slash commands ──────────────────────────────
Write-Info "Copiando .claude/commands/..."
$commandsDir = Join-Path $TARGET_DIR '.claude/commands'
New-Item -ItemType Directory -Path $commandsDir -Force | Out-Null
$commandsSrc = Join-Path $SCRIPT_DIR '.claude/commands'
if (Test-Path $commandsSrc -PathType Container) {
    foreach ($f in $COMMAND_FILES) {
        $src = Join-Path $commandsSrc $f
        if (Test-Path $src -PathType Leaf) {
            Copy-Item $src (Join-Path $commandsDir $f) -Force
            Write-Host "  v $f" -ForegroundColor Green
        }
    }
    Write-Ok "Slash commands copiados"
} else {
    Write-Warn ".claude/commands/ nao encontrado no template — pulando"
}

# ── Seeds por agente ────────────────────────────
function Get-AgentSeeds {
    param([string]$Agent)
    switch ($Agent) {
        'backend-developer' { @'
- Rotas em `apps/api/src/routes/<kebab-case>.ts` — registrar no `apps/api/src/index.ts`
- Schemas vivem em `packages/shared/src/schemas/` (nunca redefinir localmente)
- `getAuth(c)` e sincrono no Hono — nunca reimplementar JWT ou sessoes
'@ }
        'frontend-developer' { @'
- Ler `docs/design-system/design-brief.md` ANTES de implementar qualquer componente
- 4 estados obrigatorios em todo componente com dados: loading/empty/error/success
- Data fetching em custom hooks (TanStack Query) — nunca em componentes
'@ }
        'data-engineer-dba' { @'
- Schemas Drizzle + Zod em `packages/shared/src/schemas/` — fonte unica de verdade
- Migrations: `bun run db:generate && bun run db:migrate`
- Cascade FK documentada no schema (ON DELETE CASCADE / SET NULL / RESTRICT)
'@ }
        'devops-sre-engineer' { @'
- Dockerfile sempre multi-stage + non-root user; base `oven/bun:1.3` (nunca `:latest`)
- Baseline dev: copiar `templates/docker-compose.yml` + `templates/vite.config.ts` do template
- CI fail-fast: lint → typecheck → test → sonar → build
'@ }
        'qa-engineer' { @'
- Cobertura minima 95% em business domain code (validators, routes, auth, edge cases)
- Cenarios de spec mapeados via `it('Cenario X.Y: ...')` — checado por `check-spec-coverage.sh`
- Test runner unico: `bun test` (nunca outro)
'@ }
        'project-manager' { @'
- Backlog em `docs/backlog.md` usa waves (`## Wave: <Nome>`) mapeadas a GitHub Milestones
- P1/P2/P3 e ordem INTERNA da wave ativa (nao global)
- `/finish` Passo 4: marcar US concluida + rodar sync-github-issues.sh (fecha issue)
'@ }
        'requirements-roadmap-builder' { @'
- PRDs em `plans/<feature>.md` · planos de implementacao em `plans/<feature>-plano.md`
- Cada Fase do plano vira uma Wave no backlog (via PM agent — Passo 5.5 do prd-planejamento)
- Fase 0 (fundacao) → Wave: Backlog (nao e entrega visivel ao cliente)
'@ }
        'security-engineer' { @'
- OWASP Top 10 + validacao Zod em toda rota que aceita input
- RBAC: Clerk provê identidade; papel (admin/user) em tabela custom — ver `docs/auth-rbac.md`
- `ADMIN_EMAIL` bootstrap: email === `process.env.ADMIN_EMAIL` → role=admin (deterministico)
'@ }
        'software-architect' { @'
- ADRs em `docs/adr/` numeradas (ADR-0001, ADR-0002, ...)
- Monorepo: `apps/api`, `apps/web`, `packages/shared` — nunca import runtime cross-app
- Decisoes estruturais antes de codigo; updates em claude-stacks.md requerem justificativa
'@ }
        'ux-ui-designer' { @'
- `docs/design-system/MASTER.md` e fonte de verdade visual (gerada via pipeline da Parte 2 do DESIGN.md)
- `design-brief.md` e resumo compacto (~800 tokens) injetado em subagentes de componente
- Regras estruturais em `DESIGN.md` Parte 1 · personalidade visual em MASTER.md
'@ }
        default { @'
- (Sem seeds especificos — agente nao-padrao. Adicionar notas manualmente.)
'@ }
    }
}

# Detecta se MEMORY.md existente e boilerplate (<=10 linhas nao-comentario E sem "## Project Context")
function Test-IsBoilerplate {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath -PathType Leaf)) { return $false }  # nao existe → criacao fresh
    $content = Get-Content $FilePath -ErrorAction SilentlyContinue
    if ($content -match '## Project Context') { return $false }  # formato novo — preservar
    $nonCommentLines = ($content | Where-Object { $_ -notmatch '^\s*(#|<!--|$)' }).Count
    return $nonCommentLines -le 10
}

# Gera MEMORY.md para um agente
function New-AgentMemoryFile {
    param([string]$Agent)
    $dir  = Join-Path $TARGET_DIR ".claude/agent-memory/$Agent"
    $file = Join-Path $dir 'MEMORY.md'

    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    # Idempotencia: preservar se tem conteudo real
    if ((Test-Path $file -PathType Leaf) -and -not (Test-IsBoilerplate $file)) {
        Write-Ok "agent-memory/$Agent/MEMORY.md (preservado — conteudo custom)"
        return
    }

    $today  = (Get-Date).ToString('yyyy-MM-dd')
    $seeds  = Get-AgentSeeds $Agent

    # Conteudo do MEMORY.md — equivalente ao heredoc do .sh
    $memContent = @"
# MEMORY.md — $Agent

> Memoria persistente do agente. Carregada automaticamente via frontmatter ``memory: project``.
> Gerada inicialmente por ``./adopt-workflow.ps1`` em $today. Atualizada pelo proprio agente durante sessoes.

---

## Project Context (comum)

**Projeto:** $PROJECT_NAME
**Stack:** $PROJECT_STACK
**Workspace:** $PROJECT_LAYOUT

**Portas:**
- API: $PROJECT_API_PORT
- Web: $PROJECT_WEB_PORT

**Env vars chave:**
- ``$PROJECT_DB_URL_LINE``
- ``$PROJECT_ADMIN_EMAIL_LINE``

> Se a stack ou estrutura mudou substancialmente, rodar ``./adopt-workflow.ps1`` novamente para regenerar esta secao (seeds custom em "Agent-specific notes" sao preservados se MEMORY.md tiver >10 linhas nao-boilerplate).

---

## Agent-specific notes (seeds)

$seeds

<!-- Abaixo deste comentario, o agente adiciona suas proprias notas durante o trabalho.
     Criar arquivos ``feedback_<topico>.md`` no mesmo diretorio e linkar aqui. -->

---

## Como Capturar Memoria (Session Retrospective)

**Quando:**
- Padrao novo descoberto (configuracao, workaround, decisao de design)
- Bug resolvido apos > 15 min de investigacao
- Decisao arquitetural tomada (e o motivo)
- Anti-pattern encontrado que deve ser evitado

**Como:**
1. Criar arquivo ``feedback_<topico>.md`` neste diretorio com frontmatter:
   ``````markdown
   ---
   name: [nome curto]
   description: [1 linha — usado para decidir relevancia em futuras sessoes]
   type: feedback
   ---
   ``````
2. Adicionar bullet em "Agent-specific notes" acima linkando para o arquivo

**Promover entre projetos:** se o aprendizado e reutilizavel, marcar em ``claude-stacks-refactor.md`` como ``Pendente`` e rodar ``./promote-learning.sh`` no fim do ciclo.
"@

    Set-Content -Path $file -Value $memContent -Encoding UTF8
    Write-Ok "agent-memory/$Agent/MEMORY.md"
}

# ── Estrutura agent-memory ──────────────────────
Write-Info "Criando .claude/agent-memory/ com Project Context + seeds por agente..."
$AGENTS = @(
    'backend-developer'
    'data-engineer-dba'
    'devops-sre-engineer'
    'frontend-developer'
    'project-manager'
    'qa-engineer'
    'requirements-roadmap-builder'
    'security-engineer'
    'software-architect'
    'ux-ui-designer'
)
foreach ($agent in $AGENTS) {
    New-AgentMemoryFile $agent
}

# ── Arquivos instanciados (sem sobrescrever) ────
Write-Info "Copiando arquivos instanciados (sem sobrescrever existentes)..."
$INSTANCE_FILES = @('CLAUDE.md')
foreach ($file in $INSTANCE_FILES) {
    $src  = Join-Path $SCRIPT_DIR $file
    $dest = Join-Path $TARGET_DIR $file
    if (Test-Path $src -PathType Leaf) {
        if (-not (Test-Path $dest -PathType Leaf)) {
            Copy-Item $src $dest -Force
            Write-Ok $file
        } else {
            Write-Warn "$file ja existe — mantendo versao do projeto (use --force-claude-md para reinstalar)"
        }
    }
}

# ── claude-stacks-refactor.md ──────────────────
$refactorFile = Join-Path $TARGET_DIR 'claude-stacks-refactor.md'
if (-not (Test-Path $refactorFile -PathType Leaf)) {
    Set-Content -Path $refactorFile -Encoding UTF8 -Value @'
# claude-stacks-refactor.md — Aprendizados e Extensoes

> **Este arquivo e um documento vivo.**
> Contem regras, padroes e configuracoes descobertos durante o desenvolvimento
> que complementam o `claude-stacks.md`.
>
> **Auto-atualizado pelo Claude** quando um erro evitavel e encontrado (ver CLAUDE.md -> Auto-atualizacao do Stacks).
>
> **Hierarquia**: `CLAUDE.md` > `claude-sdd.md` > `claude-stacks.md` > `DESIGN.md` > `claude-stacks-refactor.md`

---

## Regras descobertas

<!-- Adicionadas automaticamente pelo Claude durante o desenvolvimento -->

---

## Candidatos a promocao

> Regras que podem beneficiar todos os projetos. Revisar periodicamente e promover para os arquivos globais.

| Regra | Origem | Destino | Status |
|---|---|---|---|

'@
    Write-Ok "claude-stacks-refactor.md (criado vazio)"
} else {
    Write-Warn "claude-stacks-refactor.md ja existe — mantendo"
}

# ── Estrutura docs/ ─────────────────────────────
Write-Info "Criando estrutura docs/..."

New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR 'docs/specs')                 -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR 'docs/design-system/pages')   -Force | Out-Null

# user-stories.md
$storiesFile = Join-Path $TARGET_DIR 'docs/user-stories.md'
if (-not (Test-Path $storiesFile -PathType Leaf)) {
    Set-Content -Path $storiesFile -Encoding UTF8 -Value @'
# User Stories

> Fonte de verdade para requisitos do projeto.
> Cada story segue o formato XP: Como [ator], quero [acao], para que [beneficio].
> **Para gerar:** usar o comando `/new-project` e seguir a entrevista de levantamento de requisitos.

---

<!-- Exemplo de story (remover apos gerar o conteudo real):

### US-01 — Autenticacao de usuario
**Como** visitante, **quero** criar conta e fazer login, **para que** eu possa acessar funcionalidades protegidas.

**Criterios de aceite:**
- [ ] Posso me registrar com e-mail e senha
- [ ] Posso fazer login com credenciais validas
- [ ] Recebo mensagem de erro clara em credenciais invalidas
- [ ] Sessao persiste ao recarregar a pagina

**Estimativa:** M (3-5 dias)
**Prioridade:** P1

-->
'@
    Write-Ok "docs/user-stories.md (template)"
}

# backlog.md
$backlogFile = Join-Path $TARGET_DIR 'docs/backlog.md'
if (-not (Test-Path $backlogFile -PathType Leaf)) {
    Set-Content -Path $backlogFile -Encoding UTF8 -Value @'
# Backlog

> Modelo Kanban com priorizacao (P1/P2/P3).
> Ordenado por prioridade: P1 primeiro, depois P2, depois P3.
> **Para gerar:** usar o comando `/new-project` e seguir a entrevista de levantamento de requisitos.

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** — Critico | Bloqueia outras stories ou e requisito de lancamento |
| **P2** — Importante | Agrega valor significativo, fazer apos P1 |
| **P3** — Desejavel | Nice-to-have, fazer se sobrar capacidade |

---

<!-- Exemplo de formato (remover apos gerar o conteudo real):

### US-01 — Autenticacao de usuario · **P1**

**Status:** Nao iniciado

| Task | Agente | Status |
|------|--------|--------|
| 1.1 Criar schema de usuario (Drizzle) | data-engineer-dba | pendente |
| 1.2 Implementar endpoints POST /auth/register e POST /auth/login | backend-developer | pendente |
| 1.3 Implementar tela de login e registro | frontend-developer | pendente |

-->
'@
    Write-Ok "docs/backlog.md (template)"
}

# docs/design-system/MASTER.md
$masterFile = Join-Path $TARGET_DIR 'docs/design-system/MASTER.md'
if (-not (Test-Path $masterFile -PathType Leaf)) {
    Set-Content -Path $masterFile -Encoding UTF8 -Value @'
# Design System

> Fonte de verdade visual do projeto.
> Gerado via DESIGN.md (Parte 2 — pipeline de 3 passos: ui-ux-pro-max → entrevista → brief).
> Para regras estruturais: ver `DESIGN.md` (Parte 1).

---

<!-- Rodar o pipeline da Parte 2 do DESIGN.md para gerar o design system -->
'@
    Write-Ok "docs/design-system/MASTER.md (template)"
}

# docs/design-system/design-brief.md
$briefFile = Join-Path $TARGET_DIR 'docs/design-system/design-brief.md'
if (-not (Test-Path $briefFile -PathType Leaf)) {
    Set-Content -Path $briefFile -Encoding UTF8 -Value @'
# Design Brief

> Resumo compacto (~800 tokens) do MASTER.md para injecao em subagentes de componente.
> Gerado automaticamente a partir do MASTER.md. Fonte de verdade: MASTER.md.

---

<!-- Gerado automaticamente apos o MASTER.md estar completo -->
'@
    Write-Ok "docs/design-system/design-brief.md (template)"
}

# docs/session-state.md
$sessionFile = Join-Path $TARGET_DIR 'docs/session-state.md'
if (-not (Test-Path $sessionFile -PathType Leaf)) {
    Set-Content -Path $sessionFile -Encoding UTF8 -Value @'
# Session State

> Atualizado pelo Claude antes de cada notificacao ntfy (ao aguardar input do usuario).
> Injetado automaticamente no contexto via hook `UserPromptSubmit`.
> **OBRIGATORIO:** Preencher todas as secoes antes de enviar a notificacao ntfy.

---

## Contexto Ativo

- **Story:** --
- **Task:** --
- **Fase TDD:** Red | Green | Refactor

---

## Ultimo Passo Executado

--

---

## Proximo Passo Esperado

--

---

## Questoes Abertas

--

---

## Agentes Envolvidos nesta Sessao

--

---

_Ultima atualizacao: --_
'@
    Write-Ok "docs/session-state.md (template)"
}

# docs/quality.md
$qualityFile = Join-Path $TARGET_DIR 'docs/quality.md'
if (-not (Test-Path $qualityFile -PathType Leaf)) {
    Set-Content -Path $qualityFile -Encoding UTF8 -Value @'
# Quality Dashboard

> Atualizado automaticamente apos cada `bun test` via hook PostToolUse.
> Fonte de verdade para o estado de qualidade do projeto.

---

## Status Geral

| Metrica | Valor | Status |
|---------|-------|--------|
| Cobertura geral | --% | pendente |
| Lint (Biome) | -- | pendente |
| Typecheck | -- | pendente |
| Ultima execucao | -- | -- |

---

## Cobertura por Modulo

| Modulo | Stmts | Branch | Funcs | Lines | Status |
|--------|-------|--------|-------|-------|--------|
| -- | --% | --% | --% | --% | pendente |

---

## Gates do DoD

- [ ] `bun test` passa com cobertura >= 95%
- [ ] `bunx biome check` zero erros
- [ ] `tsc --noEmit` zero erros
- [ ] Cenarios do spec ativos cobertos (ver Spec Coverage abaixo)
- [ ] Code review aprovado (`superpowers:requesting-code-review`)

---

## Spec Coverage

| Spec | Cenario | Teste | Status |
|------|---------|-------|--------|
| -- | -- | -- | pendente |

---

## Bugs Abertos

| ID | Descricao | Severidade | Status |
|----|-----------|------------|--------|
| -- | -- | -- | -- |

---

_Gerado por `check-quality.sh` · Ultima atualizacao: --_
'@
    Write-Ok "docs/quality.md (placeholder)"
}

# .gitkeep em pastas vazias
$null = New-Item -ItemType File -Path (Join-Path $TARGET_DIR 'docs/specs/.gitkeep')                -Force
$null = New-Item -ItemType File -Path (Join-Path $TARGET_DIR 'docs/design-system/pages/.gitkeep') -Force

# docs/adr/
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR 'docs/adr') -Force | Out-Null
$null = New-Item -ItemType File -Path (Join-Path $TARGET_DIR 'docs/adr/.gitkeep') -Force
Write-Ok "docs/adr/ (criado)"

Write-Ok "Estrutura docs/ completa"

# ── GitHub templates ────────────────────────────
Write-Info "Configurando .github/..."
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.github')           -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.github/workflows') -Force | Out-Null
$null = New-Item -ItemType File -Path (Join-Path $TARGET_DIR '.github/workflows/.gitkeep') -Force
Write-Ok ".github/workflows/ (criado — populate via devops-sre-engineer)"

$prTemplate = Join-Path $TARGET_DIR '.github/pull_request_template.md'
if (-not (Test-Path $prTemplate -PathType Leaf)) {
    # Tentar copiar do template; fallback para conteudo inline
    $prSrc = Join-Path $SCRIPT_DIR '.github/pull_request_template.md'
    if (Test-Path $prSrc -PathType Leaf) {
        Copy-Item $prSrc $prTemplate -Force
    } else {
        Set-Content -Path $prTemplate -Encoding UTF8 -Value @'
## O que essa PR faz?

<!-- Descreva em 1-3 frases o que foi implementado -->

---

## Story / Task

<!-- US-XX — Task X.Y — Titulo da task -->

---

## Definition of Done

- [ ] `bun test` passa (zero falhas)
- [ ] Cobertura de testes >= 95% (`docs/quality.md` atualizado)
- [ ] `bunx biome check` zero erros
- [ ] `tsc --noEmit` zero erros
- [ ] Todos os cenarios do spec cobertos
- [ ] Code review aprovado (`superpowers:requesting-code-review`)
- [ ] `docs/backlog.md` atualizado com status da task
- [ ] Sem codigo hardcoded (cores, fontes, URLs de API, credenciais)

---

## Tipo de mudanca

- [ ] Bug fix
- [ ] Nova feature
- [ ] Refatoracao
- [ ] Docs / configuracao
'@
    }
    Write-Ok ".github/pull_request_template.md"
}

# ── Configuracao .claude/ ───────────────────────
Write-Info "Configurando .claude/settings.json..."
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.claude') -Force | Out-Null

$settingsFile = Join-Path $TARGET_DIR '.claude/settings.json'
if (-not (Test-Path $settingsFile -PathType Leaf)) {
    $settingsExample = Join-Path $SCRIPT_DIR '.claude/settings.example.json'
    if (Test-Path $settingsExample -PathType Leaf) {
        Copy-Item $settingsExample $settingsFile -Force
        Write-Ok ".claude/settings.json criado a partir de settings.example.json"
        Write-Warn "Edite .claude/settings.json para ajustar os plugins instalados na sua conta"
    } else {
        Write-Warn ".claude/settings.example.json nao encontrado — settings.json nao criado"
        Write-Warn "Copie manualmente: cp .claude/settings.example.json .claude/settings.json"
    }
} else {
    Write-Warn ".claude/settings.json ja existe — mantendo (verifique se tem os hooks de enforcement)"
}

$settingsLocal        = Join-Path $TARGET_DIR '.claude/settings.local.json'
$settingsLocalExample = Join-Path $TARGET_DIR '.claude/settings.local.example.json'
if ((-not (Test-Path $settingsLocal -PathType Leaf)) -and (Test-Path $settingsLocalExample -PathType Leaf)) {
    Copy-Item $settingsLocalExample $settingsLocal -Force
    Write-Ok ".claude/settings.local.json criado a partir do exemplo"
}

# ── .template-version ──────────────────────────
$templateVersionSrc  = Join-Path $SCRIPT_DIR 'TEMPLATE_VERSION'
$templateVersionDest = Join-Path $TARGET_DIR '.template-version'
if (Test-Path $templateVersionSrc -PathType Leaf) {
    Copy-Item $templateVersionSrc $templateVersionDest -Force
    $ver = (Get-Content $templateVersionSrc -Raw).Trim()
    Write-Ok ".template-version ($ver)"
}

# ── Git hook (post-commit) ──────────────────────
Write-Info "Instalando git hook..."
New-Item -ItemType Directory -Path (Join-Path $TARGET_DIR '.githooks') -Force | Out-Null

# O hook usa bash (cross-platform no Windows via Git Bash / WSL)
$hookContent = @'
#!/usr/bin/env bash
# post-commit — Avisos automaticos apos commit

# ── 1. Candidatos de promocao pendentes ───────────────────────
REFACTOR_FILE="claude-stacks-refactor.md"
if [ -f "$REFACTOR_FILE" ] && grep -q "Pendente" "$REFACTOR_FILE" 2>/dev/null; then
  COUNT=$(grep -c "Pendente" "$REFACTOR_FILE" 2>/dev/null | tr -d '[:space:]')
  echo ""
  echo ">>> ${COUNT} candidato(s) pendente(s) de promocao em claude-stacks-refactor.md"
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
'@

$hookFile = Join-Path $TARGET_DIR '.githooks/post-commit'
Set-Content -Path $hookFile -Value $hookContent -Encoding UTF8 -NoNewline:$false

# Configurar git hooksPath se for repo git
$gitDir = Join-Path $TARGET_DIR '.git'
if (Test-Path $gitDir -PathType Container) {
    & git -C $TARGET_DIR config core.hooksPath .githooks
    Write-Ok ".githooks/post-commit instalado + core.hooksPath configurado"
} else {
    Write-Ok ".githooks/post-commit criado (configurar core.hooksPath apos git init)"
}

# ── Resumo ──────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  Workflow adotado com sucesso!"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Info "Arquivos copiados para: $TARGET_DIR"
Write-Host ""
Write-Host "  Proximos passos:"
Write-Host ""
Write-Host "  1. Revisar o CLAUDE.md e ajustar ao seu projeto"
if ($HAS_CLAUDE) {
    Write-Host "     (backup do anterior em CLAUDE.md.bak)"
}
Write-Host "  2. (opcional) Ativar rastreamento GitHub Issues (requer gh autenticado):"
Write-Host "     ./setup-github-project.sh"
Write-Host "  3. Usar o comando /new-project para gerar stories e backlog"
Write-Host "  4. Rodar DESIGN.md (Parte 2) para gerar o design system"
Write-Host "  5. Commitar:"
Write-Host "     git add . && git commit -m 'docs: adopt SDD/TDD workflow'"
Write-Host ""

if (-not $HAS_APPS) {
    Write-Warn "Projeto sem apps/ detectado."
    Write-Host "     Se for projeto novo, diga ao Claude Code: 'Iniciar projeto novo'"
    Write-Host "     Se for projeto existente com outra estrutura, adapte o CLAUDE.md"
}
