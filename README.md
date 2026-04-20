# template-fullstack

> Workflow SDD/TDD com Claude Code para projetos fullstack TypeScript.
> Versão: **v1.7.0** · [Changelog](CHANGELOG.md)

**Stack**: Monorepo TypeScript · Bun ≥1.3 · Hono · React 19 · Drizzle ORM · PostgreSQL · Tailwind CSS v4 · shadcn/ui

**Plugins**: [Superpowers](https://github.com/obra/superpowers) · [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)

---

## O que é

Um template que transforma o Claude Code em um orquestrador de desenvolvimento disciplinado:

- **SDD** (Spec-Driven Development): contratos aprovados antes de qualquer código
- **TDD enforced**: testes antes da implementação, cobertura ≥ 95%
- **10 agentes especializados**: cada camada tem seu agente (API, frontend, banco, DevOps…)
- **Quality gates automáticos**: lint, typecheck, coverage e spec-coverage no CI
- **Memória persistente**: cada agente acumula contexto do projeto entre sessões
- **Hooks automáticos**: injeção de contexto, proteção de arquivos críticos, quality dashboard

---

## Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | — | Orquestração |
| [Bun](https://bun.sh) | ≥ 1.3 | Runtime, PM, test runner |
| [Docker](https://docker.com) + Compose | — | Dev environment |
| [Node](https://nodejs.org) | ≥ 20.19 ou ≥ 22.12 | Tooling |
| [gh CLI](https://cli.github.com) | — | GitHub Issues sync |
| Git | — | Versionamento + hooks |

### Plugins do Claude Code (obrigatório)

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

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

Claude conduz uma entrevista de requisitos e executa a sequência de agentes:

| Passo | Agente | Output | Gate |
|---|---|---|---|
| 1 | requirements-roadmap-builder | `docs/user-stories.md` + `docs/backlog.md` | Aprovação explícita |
| 2 | software-architect | `docs/adr/ADR-001-stack-selection.md` | Review antes de avançar |
| 3 | ux-ui-designer | `docs/design-system/MASTER.md` | Aprovação explícita |
| 4 | ux-ui-designer | `docs/design-system/design-brief.md` | Auto (após MASTER aprovado) |
| 5 | data-engineer-dba | Schemas Drizzle em `packages/shared/src/schemas/` | `bun run db:generate` sem erros |
| 6 | devops-sre-engineer | Dockerfiles + compose + workflows CI/CD | `docker compose up` → todos healthy |
| 7 | `./setup-github-project.sh` | GitHub Project board sincronizado | — |

### 3. Implementar story por story

```
Implementar a US-01
```

Ou continuar o backlog de onde parou:

```
Continuar o backlog
```

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
cp .claude/settings.example.json .claude/settings.json
git config core.hooksPath .githooks
git add . && git commit -m "docs: adopt SDD/TDD workflow"
```

> `adopt-workflow.sh` copia: `CLAUDE.md`, agentes, commands, hooks, scripts, estrutura `docs/`, `agent-memory/`. **Nunca** sobrescreve código de aplicação.

### 3. Ajustar CLAUDE.md ao projeto

No Claude Code:

```
Adotar workflow SDD/TDD neste projeto
```

Claude revisa o `CLAUDE.md` copiado e o ajusta ao contexto do projeto existente (stack, estrutura de pastas, convenções).

### 4. Opcional: GitHub Integration

```bash
./setup-github-project.sh
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
               │
               ▼
            VERIFY (superpowers:verification-before-completion)
            bun test ≥95% · lint · typecheck · spec coverage
               │
               ▼
            FINISH (code review → PR → merge)
```

---

## Slash commands

| Comando | Quando usar |
|---|---|
| `/triage` | **Qualquer pedido novo ou ambíguo** — classifica e roteia |
| `/feature [descrição]` | Feature nova ou existente — fluxo SPEC→PLAN→EXECUTE→VERIFY→FINISH |
| `/continue` | Retoma o backlog — executa a próxima P1 pendente |
| `/bug [descrição]` | Qualquer erro, falha de teste, CI quebrado |
| `/refactor` | Refatoração sem mudança de contrato (branch isolada) |
| `/finish` | Encerra o ciclo — verificação → code review → merge |
| `/new-project` | Bootstrap completo de projeto novo (entrevista + 7 agentes) |

---

## Agentes especializados

| Domínio / Arquivo | Agente |
|---|---|
| `apps/api/**` (rotas, serviços, middleware) | `backend-developer` |
| `apps/web/**` (componentes, pages, hooks) | `frontend-developer` |
| `packages/shared/src/schemas/**` | `data-engineer-dba` |
| CI/CD, Dockerfile, GitHub Actions | `devops-sre-engineer` |
| `docs/design-system/**`, componentes visuais | `ux-ui-designer` |
| Arquitetura, ADRs, revisão estrutural | `software-architect` |
| Backlog, sprint, DoD, issues/PRs | `project-manager` |
| Levantamento de requisitos, roadmap | `requirements-roadmap-builder` |
| Test plans, coverage, bug reports | `qa-engineer` |
| OWASP, dependency audit, security review | `security-engineer` |

> **O orquestrador nunca escreve código de produção diretamente.** Toda implementação é delegada ao agente correto.

---

## Gates de qualidade (Definition of Done)

Uma task só está concluída quando todos os itens passam:

- [ ] `bun test` com cobertura ≥ 95% por módulo
- [ ] `bunx biome check` sem erros (lint + format)
- [ ] `tsc --noEmit` sem erros (typecheck)
- [ ] Todos os cenários do spec têm teste `it('Cenário X.Y: ...')`
- [ ] Code review via `superpowers:requesting-code-review`
- [ ] CI verde antes do merge (bloqueia CD automaticamente se vermelho)

```bash
# Verificar localmente antes de declarar pronto
./check-quality.sh        # roda testes + atualiza docs/quality.md
./check-spec-coverage.sh  # verifica cenários de spec → testes
./check-health.sh         # diagnóstico geral do workflow
```

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

> Tags SHA ficam disponíveis por 168h (PRD) e 72h (UAT). Ver seção "Rollback" em `claude-stacks.md`.

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

O Claude registra padrões novos e bugs evitáveis em `claude-stacks-refactor.md`. O hook post-commit avisa quando há candidatos a promover:

```bash
./promote-learning.sh /path/to/template-fullstack
```

---

## Scripts de referência

| Script | O que faz |
|---|---|
| `./check-health.sh [--assert]` | Diagnóstico do estado do workflow (`--assert` para CI) |
| `./check-quality.sh` | Roda testes e atualiza `docs/quality.md` |
| `./check-spec-coverage.sh [specs-dir]` | Verifica cenários de spec → testes correspondentes |
| `./adopt-workflow.sh [--dry-run] /path` | Adota workflow em projeto existente |
| `./sync-globals.sh [/path/template]` | Atualiza arquivos globais a partir do template |
| `./promote-learning.sh /path/template` | Promove aprendizados de volta ao template |
| `./setup-github-project.sh` | Cria GitHub Project board + labels |
| `./sync-github-issues.sh` | Sincroniza `docs/backlog.md` → GitHub Issues |

---

## Hooks automáticos

| Hook | Quando | O que faz |
|---|---|---|
| `UserPromptSubmit` (inject-context.sh) | Antes de cada prompt | Injeta `session-state.md` + `quality.md`/`backlog.md` se relevante |
| `PreToolUse` (pre-tool-use.sh) | Antes de Write/Edit | Bloqueia edição de CI/CD sem aprovação; avisa sobre arquivos globais |
| `PostToolUse` (post-tool-use.sh) | Após `bun test` | Atualiza `docs/quality.md` automaticamente (sem re-executar os testes) |
| `post-commit` (.githooks) | Após cada commit | Avisa sobre candidatos de promoção e sync do backlog |

---

## Estrutura de arquivos

```
CLAUDE.md                    ← Protocolo de orquestração (ponto de entrada do Claude)
claude-sdd.md                ← Metodologia Spec-Driven Development
claude-stacks.md             ← Regras, padrões técnicos e stack completa
claude-stacks-versions.md    ← Versões pinadas e notas de compatibilidade
claude-stacks-refactor.md    ← Aprendizados e extensões (por projeto, não commitado no template)
DESIGN.md                    ← Regras UI/UX e pipeline de design system
claude-debug.md              ← Política de bugs e tabela de escalação
start_project.md             ← Gates de fase para projeto novo
.claude/
  commands/                  ← /bug /triage /feature /finish /continue /new-project /refactor
  agents/                    ← 10 agentes especializados (*.md)
  hooks/
    inject-context.sh        ← UserPromptSubmit: contexto relevante por keyword
    pre-tool-use.sh          ← Proteção de CI/CD e arquivos globais
    post-tool-use.sh         ← Quality dashboard após bun test
  lib/global-files.sh        ← Fonte de verdade para GLOBAL_FILES (sync + adopt)
  agent-memory/              ← MEMORY.md por agente — acumulado via uso
.github/
  pull_request_template.md   ← Template de PR com DoD checklist
  workflows/
    ci.yml                   ← CI pipeline completo
    cd-portainer-uat.yml.example  ← CD template UAT (Portainer)
    cd-portainer-prd.yml.example  ← CD template PRD (Portainer)
    cd-railway.yml.example        ← CD template Railway
docs/
  user-stories.md            ← Stories com critérios de aceite
  backlog.md                 ← Kanban P1/P2/P3
  specs/                     ← US-XX-nome.spec.md por story
  adr/                       ← Architecture Decision Records
  design-system/
    MASTER.md                ← Design system completo
    design-brief.md          ← Resumo ~800 tokens para subagentes
    pages/                   ← Overrides por página
  quality.md                 ← Quality Dashboard (auto-atualizado)
  session-state.md           ← Estado da sessão atual (injetado automaticamente)
```

---

## Licença

MIT
