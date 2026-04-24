# template-fullstack

> Workflow SDD/TDD com Claude Code para projetos fullstack TypeScript.
> Versão: **v2.0.0** · [Changelog](CHANGELOG.md)

**Stack**: Monorepo TypeScript · Bun ≥1.3 · Hono · React 19 · Drizzle ORM · PostgreSQL · Tailwind CSS v4 · shadcn/ui · Clerk

**Plugins**: [Superpowers](https://github.com/obra/superpowers) · [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)

---

## O que é

Um template que transforma o Claude Code em um orquestrador de desenvolvimento disciplinado:

- **SDD** (Spec-Driven Development): contratos aprovados antes de qualquer código
- **TDD enforced**: testes antes da implementação, cobertura ≥ 95% por módulo
- **10 agentes especializados** não-órfãos: cada camada tem seu agente (API, frontend, banco, DevOps, QA, Security, PM…) com caminho de invocação explícito
- **STOP protocol** para bugs pré-existentes: agentes nunca contornam — corrigem ≤30min ou viram P1 no backlog
- **QA + Security gates obrigatórios**: `qa-engineer` em todo `/feature`, `security-engineer` quando há gatilhos (auth/input/segredos)
- **Backlog em Ondas** (Waves): entregas visíveis ao cliente final mapeadas 1:1 com GitHub Milestones
- **RBAC pattern documentado**: Clerk (identidade) + tabela custom (papéis) + bootstrap determinístico via `ADMIN_EMAIL`
- **Scaffolds prontos**: samples de `docker-compose.yml` e `vite.config.ts` com HMR configurado para Docker+Windows (polling correto)
- **Memória persistente que aprende**: cada agente recebe Project Context + seeds de domínio no bootstrap; `check-health.sh` reporta densidade
- **Quality gates automáticos**: lint, typecheck, coverage e spec-coverage no CI
- **Hooks otimizados**: injeção de contexto, `bun install` condicional por hash, quality dashboard em background

---

## Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | — | Orquestração |
| [Bun](https://bun.sh) | ≥ 1.3 | Runtime, PM, test runner |
| [Docker](https://docker.com) + Compose | — | Dev environment |
| [Node](https://nodejs.org) | ≥ 20.19 ou ≥ 22.12 | Tooling |
| [gh CLI](https://cli.github.com) | — | GitHub Issues + Milestones sync |
| Git | — | Versionamento + hooks |

### Plugins do Claude Code (obrigatório)

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

> ⚠️ `ui-ux-pro-max` é **pré-requisito explícito** de `/new-project`. Sem ela, o pipeline de design system não gera `MASTER.md` e projetos nascem com UI genérica shadcn.

### Skills pessoais (instalar em `~/.claude/skills/`)

| Skill | Para quê |
|---|---|
| `hono-api-debugging` | Debug de rotas e middleware Hono |
| `drizzle-database-debugging` | Debug de queries, migrations e schemas Drizzle |
| `react-tanstack-debugging` | Debug de componentes React/TanStack Query |
| `escalation-and-bug-journal` | Journaling de bugs persistentes após 3 tentativas |

---

## Quickstart — Projeto novo

### 1. Clonar e configurar

```bash
git clone <este-repo> meu-projeto
cd meu-projeto
git config core.hooksPath .githooks
cp .claude/settings.example.json .claude/settings.json
cp .claude/settings.local.example.json .claude/settings.local.json

# Opcional: criar GitHub Project board + labels
./setup-github-project.sh
```

### 2. No Claude Code, iniciar o bootstrap

```
Iniciar projeto novo
```

Claude conduz uma entrevista de requisitos e executa a sequência de agentes. Cada Fase do plano gerado vira uma **Wave** (entrega ao cliente final) no backlog:

| Passo | Agente | Output | Gate |
|---|---|---|---|
| 1 | `requirements-roadmap-builder` | `plans/<feature>.md` (PRD) | Aprovação explícita |
| 2 | `prd-planejamento` skill | `plans/<feature>-plano.md` + `docs/backlog.md` com waves | Aprovação explícita |
| 3 | `software-architect` | `docs/adr/ADR-001-stack-selection.md` | Review antes de avançar |
| 4 | `ux-ui-designer` | `docs/design-system/MASTER.md` (via `ui-ux-pro-max` + entrevista) | Aprovação explícita |
| 5 | `ux-ui-designer` | `docs/design-system/design-brief.md` (~800 tokens) | Auto |
| 6 | `data-engineer-dba` | Schemas Drizzle em `packages/shared/src/schemas/` | `bun run db:generate` sem erros |
| 7 | `devops-sre-engineer` | Copia `templates/docker-compose.yml` + `vite.config.ts` · Dockerfiles · CI/CD | `docker compose up` → todos healthy + checklist HMR |
| 8 | `./setup-github-project.sh` | GitHub Project board + **Milestones de cada Wave** | — |
| 9 | `./sync-github-issues.sh` | Issues criadas e associadas à milestone correta | — |

### 3. Implementar story por story

```
Implementar a US-01
```

Ou continuar o backlog de onde parou:

```
Continuar o backlog
```

`/continue` aciona o `project-manager` que identifica a **wave ativa** (primeira wave com USs pendentes) e retorna a próxima P1 dentro dela.

---

## Quickstart — Projeto existente (retrofit)

### 1. Preview — ver o que seria instalado antes de aplicar

```bash
# Do diretório do template
./adopt-workflow.sh --dry-run /path/to/seu-projeto
```

### 2. Aplicar o workflow

```bash
./adopt-workflow.sh /path/to/seu-projeto
cd /path/to/seu-projeto
git add . && git commit -m "docs: adopt SDD/TDD workflow"
```

> `adopt-workflow.sh` detecta contexto do projeto (stack, workspace, portas, env vars) e **popula cada `MEMORY.md` com Project Context + seeds específicos do agente**. Copia: `CLAUDE.md`, agentes, commands, hooks, scripts, estrutura `docs/`, `agent-memory/`. **Nunca** sobrescreve código de aplicação nem `MEMORY.md` com conteúdo customizado (>10 linhas não-boilerplate).

### 3. Ajustar CLAUDE.md ao projeto

No Claude Code:

```
Adotar workflow SDD/TDD neste projeto
```

Claude revisa o `CLAUDE.md` copiado e o ajusta ao contexto do projeto existente.

### 4. Opcional: GitHub Integration

```bash
./setup-github-project.sh        # cria labels + milestones (a partir das waves do backlog)
./sync-github-issues.sh          # sincroniza docs/backlog.md → Issues (com milestones)
```

---

## Ciclo de desenvolvimento

```
Pedido recebido
      │
      ▼
  /triage ──────── Bug? ──────────────────► /bug
      │                                     (debug → fix → test → finish)
      │
      ├── Refatoração ──────────────────► /refactor
      │                                     (branch isolada, sem novas features)
      │
      └── Feature (nova ou existente)
               │
          Contrato novo?
               │
         SIM ──┤ SPEC (gerar spec → aguardar aprovação)
               │
         NÃO ──┤
               │
               ▼
             PLAN (superpowers:writing-plans)
             Decompõe em micro-tasks independentes
               │
               ▼
           EXECUTE (superpowers:subagent-driven-development)
           TDD por task: Red → Green → Refactor
           Agente correto por camada
           Bugs pré-existentes: STOP protocol (≤30min corrige, >30min vira P1)
               │
               ▼
            VERIFY (superpowers:verification-before-completion)
            bun test ≥95% · lint · typecheck · spec coverage
               │
               ▼
            5.1 QA Review (qa-engineer — sempre obrigatório)
               │
               ▼
            5.2 Security Review (security-engineer — condicional)
            Gatilhos: auth, input, segredos, CORS/CSP, middleware
               │
               ▼
            FINISH (code review → PR → merge)
               │
               ▼
            Passo 4 — PM fecha backlog + issue GitHub
            (marca **Status:** concluída, tasks [x], roda sync-github-issues.sh)
```

---

## Slash commands

| Comando | Passos | Quando usar |
|---|---|---|
| `/triage` | Classifica | **Qualquer pedido novo ou ambíguo** — roteia para /bug, /feature, /refactor, /continue |
| `/feature [descrição]` | 1-6 (SPEC→PLAN→EXECUTE→VERIFY→FINISH) | Feature nova ou existente. 5.1 QA sempre; 5.2 Security condicional |
| `/continue` | PM refresh → feature → PM close | Retoma o backlog — PM identifica wave ativa e executa próxima P1 |
| `/bug [descrição]` | Diagnóstico estruturado | Qualquer erro, falha de teste, CI quebrado |
| `/refactor` | Branch isolada | Refatoração sem mudança de contrato |
| `/finish` | Verify → review → merge → backlog update | Encerra o ciclo |
| `/new-project` | Entrevista + 9 passos | Bootstrap completo de projeto novo |

---

## Agentes especializados

Todos os 10 agentes têm caminho de invocação explícito — zero órfãos.

| Domínio / Gatilho | Agente | Invocação |
|---|---|---|
| `apps/api/**` (rotas, serviços, middleware) | `backend-developer` | Automática por arquivo |
| `apps/web/**` (componentes, pages, hooks) | `frontend-developer` | Automática por arquivo |
| `packages/shared/src/schemas/**` | `data-engineer-dba` | Automática por arquivo |
| CI/CD, Dockerfile, GitHub Actions, docker-compose | `devops-sre-engineer` | Automática por arquivo |
| `docs/design-system/**`, componentes visuais novos | `ux-ui-designer` | Via `/feature` quando há UI nova |
| Arquitetura, ADRs, revisão estrutural | `software-architect` | Via `/new-project` ou review explícito |
| Backlog, sprint, DoD, issues/PRs | `project-manager` | `/continue` Passos 0 e 2 · `/finish` Passo 4 |
| Levantamento de requisitos, roadmap | `requirements-roadmap-builder` | `/new-project` Fase 1/2 |
| Test plans, coverage, bug reports | `qa-engineer` | `/feature` Passo 5.1 (sempre) |
| OWASP, dependency audit, security review | `security-engineer` | `/feature` Passo 5.2 (gatilhos: auth, input, segredos, CORS) |

> **O orquestrador nunca escreve código de produção diretamente.** Toda implementação é delegada ao agente correto.

---

## Backlog em Ondas (Waves)

`docs/backlog.md` usa dois eixos complementares:

- **Wave** (`## Wave: <Nome>`) — entregas visíveis ao cliente final (ex: MVP, Release 1, Beta). Cada wave mapeia 1:1 a um **GitHub Milestone homônimo**.
- **P1/P2/P3** — ordem **INTERNA** da wave ativa (não prioridade global).

Exemplo de formato:

```markdown
## Wave: MVP
> Milestone GitHub: `MVP` · Meta: primeira entrega viável ao cliente

### US-1 — Autenticação de usuário
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente

Tasks:
- [ ] TASK-1.1: Schema users (Drizzle)
- [ ] TASK-1.2: Middleware requireRole

## Wave: Release 1
> Milestone GitHub: `Release 1` · Meta: funcionalidades complementares

### US-5 — Relatórios exportáveis
**Prioridade:** P2  ·  **Estimativa:** 5  ·  **Status:** pendente

## Wave: Backlog
> Sem milestone atribuída. Mover para wave concreta ao priorizar.
```

**Fluxo end-to-end:**

- `setup-github-project.sh` → cria GitHub Milestones de cada wave do backlog (ignora `Backlog` catch-all)
- `sync-github-issues.sh` → cria issues associadas à milestone correspondente
- `/finish` Passo 4 → marca US concluída + fecha issue (via sync) → barra de progresso da milestone avança visivelmente ao cliente

Ver spec completo: `docs/superpowers/specs/2026-04-23-onda-3-backlog-ondas-design.md`.

---

## Auth + RBAC

Padrão híbrido documentado em **`docs/auth-rbac.md`**:

- **Clerk** provê identidade (userId, JWT)
- **Tabela `users` custom** (Drizzle) guarda o papel: `admin | user`
- **Bootstrap determinístico**: `email === process.env.ADMIN_EMAIL` → `role=admin` (não depende de ordem de cadastro)
- **Middleware `requireRole(...allowed: UserRole[])`** consulta a tabela e injeta `currentUser` no context Hono
- **JWT Clerk** deve incluir claim `email` (template configurável em clerk.com)

6 casos de teste obrigatórios (401 sem JWT, 403 sem permissão, 200 com role correto, bootstrap admin/user, etc.).

---

## Templates prontos para scaffold

O diretório `templates/` contém samples testados copiados por `/new-project`:

| Arquivo | Onde copiar | Contém |
|---|---|---|
| `docker-compose.yml` | raiz do projeto consumidor | Stack completa (api, web, postgres, minio, backup) + polling env vars para Docker+Windows |
| `vite.config.ts` | `apps/web/vite.config.ts` | `server.host: true` + `server.hmr.host` + `server.watch.usePolling: true` — HMR funciona em WSL2 |

Checklist HMR obrigatório em `templates/README.md` (gate para avançar à Fase 5 em `/new-project`).

---

## Memória dos agentes

Cada agente tem memória persistente em `.claude/agent-memory/<agente>/`. O `adopt-workflow.sh` popula **MEMORY.md rico** com 3 seções:

- **Project Context** (comum) — detectado do target: nome, stack, workspace, portas, env vars chave
- **Agent-specific notes (seeds)** — 2-3 padrões mandatórios do domínio (rotas em `apps/api/src/routes/` para backend, 4 estados obrigatórios para frontend, etc.)
- **Como Capturar Memória** — guia de Session Retrospective

Detecção idempotente: re-rodar `adopt-workflow.sh` **preserva** conteúdo customizado (>10 linhas não-boilerplate) e **substitui** boilerplate legacy automaticamente.

Ver densidade de memória em qualquer momento:

```bash
./check-health.sh
```

Saída (trecho):

```
🧠 Memória dos Agentes (densidade)

  backend-developer            : ██████████  45L · 3 tópicos · atualizado 2d
  frontend-developer           : ██████░░░░  28L · 1 tópico  · atualizado 7d
  qa-engineer                  : ██░░░░░░░░  12L · 0 tópicos · boilerplate
  ────────────────────────────────────────────────────────────────────
  Média: 25L/agente · 1 agente(s) com boilerplate · 3 agente(s) sem tópicos
```

---

## Gates de qualidade (Definition of Done)

Uma task só está concluída quando todos os itens passam:

- [ ] `bun test` com cobertura ≥ 95% por módulo
- [ ] `bunx biome check` sem erros (lint + format)
- [ ] `tsc --noEmit` sem erros (typecheck)
- [ ] Todos os cenários do spec têm teste `it('Cenário X.Y: ...')`
- [ ] **QA review** via `qa-engineer` (em `/feature` Passo 5.1)
- [ ] **Security review** via `security-engineer` quando há gatilhos (em `/feature` Passo 5.2)
- [ ] Code review via `superpowers:requesting-code-review`
- [ ] **Zero bugs pré-existentes** — STOP protocol de `claude-debug.md`
- [ ] CI verde antes do merge (bloqueia CD automaticamente se vermelho)
- [ ] Backlog atualizado (`/finish` Passo 4 — PM marca US concluída + fecha issue)

```bash
# Verificação completa (manual — antes de declarar pronto)
./check-quality.sh        # roda testes + lint + typecheck + spec coverage + quality.md
./check-spec-coverage.sh  # verifica cenários de spec → testes
./check-health.sh         # diagnóstico geral do workflow + densidade de memória
```

> 💡 `check-quality.sh` invocado via hook (após `bun test`) usa **HOOK_MODE**: pula biome+typecheck full-project (economia de 10-40s CPU em background por ciclo TDD). Para validação completa antes de VERIFY/FINISH/CI, rodar sem args.

---

## CI/CD

### Pipeline CI (`ci.yml`)

Dispara em push e PRs para `main` e `uat`.

```
Security audit (bun audit)
→ Lint (bunx biome check)
→ Typecheck (tsc --noEmit)
→ Tests + coverage (bun test, ≥95%)
→ Spec coverage check (./check-spec-coverage.sh)
→ SonarQube (se SONAR_TOKEN configurado)
```

### Deploy (Portainer on-premises)

- CD **nunca** roda direto em push — sempre via `workflow_run` após CI verde
- `uat` branch → `cd-portainer-uat.yml` → deploy com tag `uat-latest`
- `main` branch → `cd-portainer-prd.yml` → deploy com tag `latest`
- Ordem obrigatória: API primeiro (build+push), depois Web (aciona webhook)

### Rollback (Portainer)

Se um deploy quebrar produção:
1. Identificar SHA anterior no histórico do GitHub Actions
2. Editar a stack PRD no Portainer: trocar tag `latest` → `{sha}`
3. Portainer faz pull e reinicia
4. Após estabilizar: criar `hotfix/` branch → corrigir → `uat` → `main`

> Tags SHA ficam disponíveis por 168h (PRD) e 72h (UAT). Ver `claude-stacks.md` → "Rollback".

### Deploy Railway

Configure via `cd-railway.yml.example`. Migrations como pre-deploy command. Ver `claude-stacks.md` → "Deploy: dois targets".

---

## Sincronização com o template

| Ação | Script | Onde rodar |
|---|---|---|
| Puxar atualizações do template (via GitHub) | `./sync-globals.sh` | No projeto |
| Puxar de cópia local do template | `./sync-globals.sh /path/template` | No projeto |
| Enviar aprendizados para o template | `./promote-learning.sh /path/template` | No projeto |
| Preview antes de adotar | `./adopt-workflow.sh --dry-run /path` | No template |

O sync **nunca** toca: `CLAUDE.md`, `claude-stacks-refactor.md`, `docs/`, `.claude/agent-memory/`, `.claude/settings*.json`.

### Aprendizados e extensões

O Claude registra padrões novos e bugs evitáveis em `claude-stacks-refactor.md`. Após edit, o hook `post-tool-use` detecta entries `⏳ Pendente` e lembra de promover:

```bash
./promote-learning.sh /path/to/template-fullstack
```

---

## Scripts de referência

| Script | O que faz |
|---|---|
| `./check-health.sh [--assert]` | Diagnóstico do workflow + densidade de memória por agente (`--assert` falha se há boilerplate) |
| `./check-quality.sh [--from-output FILE]` | Roda testes + lint + typecheck + spec coverage. Com `--from-output`: HOOK_MODE (pula lint/tc) |
| `./check-spec-coverage.sh [specs-dir]` | Verifica cenários de spec → testes correspondentes |
| `./adopt-workflow.sh [--dry-run] /path` | Adota workflow em projeto existente (+ Project Context em MEMORY.md) |
| `./sync-globals.sh [/path/template]` | Atualiza arquivos globais (self-update deferido para evitar bash race) |
| `./promote-learning.sh /path/template` | Promove aprendizados de volta ao template |
| `./setup-github-project.sh` | Cria GitHub Project board + labels + **Milestones das waves do backlog** |
| `./sync-github-issues.sh` | Sincroniza `docs/backlog.md` → GitHub Issues com milestone correta |

---

## Hooks automáticos

| Hook | Quando | O que faz |
|---|---|---|
| `UserPromptSubmit` (inject-context.sh) | Antes de cada prompt | Injeta `session-state.md` + condicionalmente `quality.md`/`backlog.md` (por keyword). Força TRIAGEM se prompt não é slash command |
| `PreToolUse` (pre-tool-use.sh) | Antes de Write/Edit | Bloqueia edição de `.github/workflows/` sem aprovação; avisa sobre arquivos globais e código de produção |
| `PreToolUse` (Bash) | Antes de `bun test` | **`bun install` condicional** (hash SHA-256 de `package.json`+`bun.lock`) + async — só roda quando deps mudaram |
| `PostToolUse` (Bash) | Após cada Bash | Roda `check-quality.sh` em HOOK_MODE após `bun test`; alerta sobre entries `⏳ Pendente` em `claude-stacks-refactor.md` |
| `post-commit` (.githooks) | Após cada commit | Avisa sobre candidatos de promoção + sync do backlog + regeneração de design brief |

> 📦 Hooks compartilham `CLAUDE_TEMPLATE_ROOT` via env var exportado — elimina `git rev-parse` redundante (economia de ~100-200ms/hook no Windows).

---

## Estrutura de arquivos

```
CLAUDE.md                    ← Protocolo de orquestração (ponto de entrada do Claude)
claude-sdd.md                ← Metodologia Spec-Driven Development
claude-stacks.md             ← Regras, padrões técnicos e stack completa
claude-stacks-versions.md    ← Versões pinadas e notas de compatibilidade
claude-stacks-refactor.md    ← Aprendizados e extensões (por projeto, não commitado no template)
DESIGN.md                    ← Regras UI/UX + pipeline de design system (ui-ux-pro-max pré-requisito)
claude-debug.md              ← Política de bugs pré-existentes (STOP protocol) + escalação
start_project.md             ← Gates de fase para projeto novo
README.md                    ← este arquivo
CHANGELOG.md                 ← histórico de versões
TEMPLATE_VERSION             ← versão atual (v2.0.0)

templates/                   ← Samples prontos para scaffold em /new-project
  README.md                  ← regras de uso + checklist HMR
  docker-compose.yml         ← stack completa com polling Windows/Docker
  vite.config.ts             ← HMR config para Docker+Windows

.claude/
  commands/                  ← /bug /triage /feature /finish /continue /new-project /refactor
  agents/                    ← 10 agentes especializados (*.md)
  hooks/
    inject-context.sh        ← UserPromptSubmit: contexto relevante por keyword + enforço de TRIAGEM
    pre-tool-use.sh          ← Proteção de CI/CD e arquivos globais
    post-tool-use.sh         ← Quality dashboard após bun test + alerta learning loop
  lib/global-files.sh        ← Fonte de verdade para GLOBAL_FILES (sync + adopt)
  agent-memory/              ← MEMORY.md por agente (Project Context + seeds + session retro)
  settings.example.json      ← Settings com hooks (copiar para settings.json)
  settings.local.example.json
  skills/                    ← Skills locais (novo-prd, prd-planejamento)
    novo-prd/SKILL.md
    prd-planejamento/SKILL.md

.github/
  pull_request_template.md   ← Template de PR com DoD checklist
  workflows/
    ci.yml                   ← CI pipeline completo
    cd-portainer-uat.yml.example
    cd-portainer-prd.yml.example
    cd-railway.yml.example

docs/
  user-stories.md            ← Stories com critérios de aceite
  backlog.md                 ← Kanban com waves (## Wave: <Nome>) + P1/P2/P3 interno
  auth-rbac.md               ← Padrão RBAC: Clerk + tabela custom + ADMIN_EMAIL
  specs/                     ← US-XX-nome.spec.md por story
  adr/                       ← Architecture Decision Records
  design-system/
    MASTER.md                ← Design system (personalizado por projeto via entrevista)
    design-brief.md          ← Resumo ~800 tokens para subagentes
    pages/                   ← Overrides por página
  superpowers/
    specs/                   ← Specs de design das ondas de evolução do template
    plans/                   ← Planos de implementação das ondas
  quality.md                 ← Quality Dashboard (auto-atualizado via hook)
  session-state.md           ← Estado da sessão atual (injetado automaticamente)

setup-github-project.sh      ← Cria labels + milestones das waves
sync-github-issues.sh        ← backlog.md → GitHub Issues (com milestones)
adopt-workflow.sh            ← Adota template + gera MEMORY.md ricos
sync-globals.sh              ← Puxa atualizações do template (self-update deferido)
promote-learning.sh          ← Promove aprendizados de projeto → template
check-health.sh              ← Diagnóstico + densidade de memória
check-quality.sh             ← Quality gates (HOOK_MODE disponível)
check-spec-coverage.sh       ← Valida cenários de spec → testes
```

---

## Changelog resumido

- **v2.0.0** (2026-04-24) — 4 ondas de remediação: agentes não-órfãos com QA+Security integrados, scaffolds Docker/Vite/RBAC, backlog em waves → milestones, memória persistente com bootstrap rico. Ver `CHANGELOG.md`.
- **v1.7.0** (2026-04-20) — DESIGN.md 60% menor, global-files.sh como fonte única
- **v1.6.0** (2026-04-19) — README condensado, versões pinadas extraídas

---

## Licença

MIT
