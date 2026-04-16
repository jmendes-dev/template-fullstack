# template-fullstack

> Template de projeto fullstack com workflow SDD/TDD + Superpowers para Claude Code.
> Versão atual: **v1.2.0** — [CHANGELOG](CHANGELOG.md)

**Stack**: Monorepo TypeScript · Bun · Hono · React 19 · Drizzle ORM · PostgreSQL · Tailwind CSS v4 · shadcn/ui

**Plugins**: [Superpowers](https://github.com/obra/superpowers) (execução + TDD + code review) · [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (design system)

---

## Arquitetura

O sistema funciona em **5 camadas**:

```
┌─────────────────────────────────────────────────────────┐
│              REQUISITOS (PRD + fases)                     │
│  novo-prd · prd-planejamento · plans/<feature>.md        │
└───────────────────────┬─────────────────────────────────┘
                        │ alimenta o spec
                        ▼
┌─────────────────────────────────────────────────────────┐
│              SEU WORKFLOW (conhecimento)                  │
│  Specs SDD · Design Brief · Stack Rules · Backlog P1/P2/P3  │
└───────────────────────┬─────────────────────────────────┘
                        │ injeta contexto
                        ▼
┌─────────────────────────────────────────────────────────┐
│            SUPERPOWERS (execução + enforcement)           │
│  Plans · Subagentes · TDD Gates · Code Review · Verify   │
└───────────────────────┬─────────────────────────────────┘
                        │ diagnóstico por stack
                        ▼
┌─────────────────────────────────────────────────────────┐
│            PERSONAL SKILLS (debugging da stack)           │
│  Hono · Drizzle · React/TanStack · Escalação             │
└───────────────────────┬─────────────────────────────────┘
                        │ guardrails mecânicos
                        ▼
┌─────────────────────────────────────────────────────────┐
│            HARNESS ENGINEERING (enforcement automático)   │
│  PreToolUse hooks · Structured agent output · Hooks CI   │
└─────────────────────────────────────────────────────────┘
```

---

## Estrutura do template

```
template-fullstack/
│
│  ── Orquestração ──
├── CLAUDE.md                     ← Protocolo executável. Routing mandatório de agentes.
├── claude-sdd.md                 ← Specs: define O QUÊ implementar (contratos, cenários)
├── claude-subagents.md           ← Templates de contexto para subagentes (conhecimento injetado)
├── claude-stacks.md              ← Stack técnica: regras, padrões, anti-patterns
├── claude-stacks-refactor.md     ← Aprendizados e extensões (começa vazio, cresce com o projeto)
├── claude-design.md              ← Regras estruturais de UI/UX + pipeline design brief
├── claude-debug.md               ← Orquestração de debugging (Superpowers + personal skills)
│
│  ── Pipelines de geração ──
├── REQUIREMENTS.md               ← Entrevista → user-stories + backlog (Kanban P1/P2/P3)
├── DESIGN_SYSTEM.md              ← ui-ux-pro-max → entrevista → MASTER.md + design-brief.md
│
│  ── Bootstrap ──
├── start_project.md              ← Bootstrap: 9 fases de inicialização de projeto novo
│
│  ── Referência de stack ──
├── package.json.example          ← Deps e scripts de referência: raiz + apps/api, apps/web, packages/shared
│
│  ── Superpowers ──
├── .superpowers/
│   └── agent-memory-bootstrap.md ← Guia para pré-popular memórias dos agentes em projeto novo
│
│  ── Artefatos por feature ──
├── plans/                        ← PRDs e planos faseados gerados pelo Claude
│   ├── <feature>.md              ← PRD (problema, stories, API, MVP, escopo)
│   └── <feature>-plano.md        ← Plano faseado com tracer bullets
│
│  ── Docs vivos (por projeto) ──
├── docs/
│   ├── user-stories.md           ← Stories com critérios de aceite
│   ├── backlog.md                ← Kanban P1/P2/P3 com tasks
│   ├── quality.md                ← Quality Dashboard (atualizado automaticamente)
│   ├── session-state.md          ← Estado da sessão para continuidade entre sessões
│   ├── contracts/                ← Contratos versionados API ↔ Frontend
│   │   └── README.md             ← Schema e instruções do Contract Registry
│   ├── specs/                    ← Specs SDD por story
│   └── design-system/
│       ├── MASTER.md             ← Fonte de verdade visual do projeto
│       ├── design-brief.md       ← Resumo ~800 tokens para subagentes de frontend
│       └── pages/                ← Overrides por página
│
│  ── Agentes especializados ──
├── .claude/
│   ├── agents/                   ← 10 agentes por papel técnico (global — sincronizado)
│   │   ├── backend-developer.md
│   │   ├── frontend-developer.md
│   │   ├── data-engineer-dba.md
│   │   ├── qa-engineer.md
│   │   ├── devops-sre-engineer.md
│   │   ├── security-engineer.md
│   │   ├── software-architect.md
│   │   ├── ux-ui-designer.md
│   │   ├── project-manager.md
│   │   └── requirements-roadmap-builder.md
│   ├── agent-memory/             ← Memória persistente por agente (instanciado — versionado)
│   │   ├── backend-developer/MEMORY.md
│   │   ├── frontend-developer/MEMORY.md
│   │   └── ...                   ← um diretório por agente
│   ├── hooks/                    ← Hook scripts (PreToolUse, UserPromptSubmit)
│   │   ├── pre-tool-use.sh       ← Bloqueia .github/workflows/, avisa sobre globais
│   │   └── inject-context.sh     ← Injeção condicional de contexto por palavras-chave
│   ├── settings.example.json     ← Template de settings com plugins + hooks (copiar para settings.json)
│   ├── settings.json             ← Configuração pessoal ativa — gitignored, não versionado
│   ├── settings.local.example.json ← Template de permissões (copiar para settings.local.json)
│   └── settings.local.json       ← Permissões pessoais ativas — gitignored, não versionado
│
│  ── GitHub ──
├── .github/
│   ├── pull_request_template.md  ← Checklist DoD em todo PR
│   └── CODEOWNERS                ← Proteção de arquivos de arquitetura
│
│  ── Scripts ──
├── adopt-workflow.sh             ← Adotar workflow em projeto existente
├── sync-globals.sh               ← Template → projetos (globais + agentes + hooks)
├── promote-learning.sh           ← Projetos → template (coletar aprendizados)
├── setup-github-project.sh       ← Criar GitHub Project board, labels, milestones, branch protection
├── sync-github-issues.sh         ← Sincronizar backlog.md com GitHub Issues
├── check-health.sh               ← Diagnóstico do estado do template no projeto
├── check-quality.sh              ← Atualiza docs/quality.md com resultados de bun test
│
│  ── Versionamento ──
├── TEMPLATE_VERSION              ← Versão semver atual (ex: 1.1.0)
├── CHANGELOG.md                  ← Histórico de mudanças por versão
│
│  ── Git ──
├── .gitattributes                ← Força LF nos .sh (evita falhas no Windows)
├── .githooks/post-commit         ← Avisa sobre candidatos, backlog atualizado, MASTER.md mudado
├── .gitignore
└── README.md
```

---

## Globais vs Instanciados

| Tipo | Arquivos | Comportamento |
|---|---|---|
| **Global** | `claude-stacks.md`, `claude-sdd.md`, `claude-design.md`, `claude-subagents.md`, `claude-debug.md`, `start_project.md`, `REQUIREMENTS.md`, `DESIGN_SYSTEM.md`, `package.json.example`, `.gitattributes`, todos os scripts `.sh`, `.claude/agents/*.md`, `.claude/hooks/*.sh`, `.claude/settings.example.json`, `.claude/settings.local.example.json`, `.superpowers/agent-memory-bootstrap.md` | Reutilizáveis. Atualizados no template, propagados via `sync-globals.sh` |
| **Instanciado** | `CLAUDE.md`, `claude-stacks-refactor.md`, tudo em `docs/`, `.claude/agent-memory/` | Específicos por projeto. Nunca sobrescritos pelo sync |
| **Gitignored** | `.claude/settings.json`, `.claude/settings.local.json` | Configuração pessoal ativa — nunca commitado |

### Scripts disponíveis por contexto

| Script | Template | Projetos | O que faz |
|---|---|---|---|
| `adopt-workflow.sh` | ✅ | ❌ | Adoção inicial — copia tudo para o projeto |
| `sync-globals.sh` | ✅ | ✅ | Puxar atualizações do template |
| `promote-learning.sh` | ✅ | ✅ | Enviar aprendizados para o template |
| `setup-github-project.sh` | ✅ | ✅ | Criar Project board + labels + branch protection |
| `sync-github-issues.sh` | ✅ | ✅ | Sincronizar backlog.md → GitHub Issues (rastreamento de conclusão de tasks) |
| `check-health.sh` | ✅ | ✅ | Diagnóstico do template + modo `--assert` para CI |
| `check-quality.sh` | ✅ | ✅ | Atualizar quality.md após bun test |

### Harness Engineering — guardrails automáticos

| Mecanismo | Onde | O que faz |
|---|---|---|
| `PreToolUse` hook | `.claude/hooks/pre-tool-use.sh` | Bloqueia writes em `.github/workflows/`; avisa sobre arquivos globais (Write\|Edit unificado) |
| `UserPromptSubmit` hook | `.claude/hooks/inject-context.sh` | Injeta session-state sempre; quality.md e backlog só quando relevante |
| `PostToolUse` hook | `settings.json` (inline) | Aciona `check-quality.sh` automaticamente após `bun test` |
| `Stop` hook | `settings.json` | Cria `docs/session-state.md` se não existe |
| Structured agent output | Todos os 10 agentes | Protocolo STATUS/ARTEFATOS/PRÓXIMO/CONCERNS ao fim de cada task |

### Personal skills (globais, em ~/.claude/skills/)

| Skill | Descrição |
|---|---|
| `hono-api-debugging` | Debugging de rotas, middleware, auth, response format |
| `drizzle-database-debugging` | Debugging de queries, migrations, schemas, Zod |
| `react-tanstack-debugging` | Debugging de React 19, TanStack Query, Hono RPC, shadcn/ui |
| `escalation-and-bug-journal` | Protocolo de escalação 4 níveis + Bug Journal |

---

## Guia 1 — Projeto novo (do zero)

**1. Criar repositório** — clique "Use this template" no GitHub, clone localmente.

**2. Configurar:**
```bash
git config core.hooksPath .githooks
cp .claude/settings.example.json .claude/settings.json
cp .claude/settings.local.example.json .claude/settings.local.json
```

Edite `.claude/settings.json` para ajustar os plugins instalados na sua conta Claude Code.

Configurar a URL do template para sincronização (substitua pelo seu repositório):
```bash
# Opção A — variável de ambiente (sem editar o script)
export TEMPLATE_REPO_URL="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main"

# Opção B — editar o fallback no script (linha ~29 de sync-globals.sh)
# GITHUB_RAW_BASE="${TEMPLATE_REPO_URL:-https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main}"
```

**3. (Opcional) Configurar GitHub Project board:**
```bash
./setup-github-project.sh
```
Cria labels, milestones, Project board kanban e branch protection no repositório.

**4. Levantar requisitos** — no Claude Code:
```
Iniciar projeto novo
```
Claude segue a sequência obrigatória de 7 agentes: requirements-roadmap-builder → software-architect → ux-ui-designer → data-engineer-dba → devops-sre-engineer → setup-github-project.sh.

**5. Implementar fase por fase** — no Claude Code:
```
Implementar a US-01
Implementar a US-02
```
Cada story passa pelo ciclo completo: triage → spec → plan → execute → verify → finish.

---

## Guia 2 — Projeto existente (retrofit)

**1. Rodar script de adoção** (do diretório do template):
```bash
./adopt-workflow.sh /path/to/seu-projeto
```

O script copia automaticamente:
- Arquivos globais (`claude-stacks.md`, `claude-design.md`, scripts `.sh`, etc.)
- `.claude/agents/` — todos os 10 agentes especializados
- `.claude/hooks/` — hook scripts (pre-tool-use, inject-context)
- `.claude/agent-memory/` — estrutura de memória criada vazia para cada agente
- `.claude/settings.example.json` → copiar para `.claude/settings.json` (ajustar plugins)
- `docs/` — estrutura com templates para user-stories, backlog, quality, session-state, contracts
- `.githooks/post-commit` — hook com `core.hooksPath` configurado automaticamente
- `.template-version` — versão instalada para rastreamento de updates

**2. (Opcional) Configurar GitHub:**
```bash
cd /path/to/seu-projeto
./setup-github-project.sh
```

**3. Ajustar CLAUDE.md** ao projeto ou no Claude Code: `Adotar workflow SDD/TDD neste projeto`.

**4. Gerar docs** — REQUIREMENTS.md (stories + backlog) e DESIGN_SYSTEM.md (design system).

**5. Commitar:**
```bash
git add . && git commit -m "docs: adopt SDD/TDD workflow"
```

---

## Guia 3 — Sincronização: Template → Projetos

> Quando: você atualizou um arquivo global ou um agente no template e quer propagar para projetos.

**1. Atualize e pushe o template:**
```bash
cd /path/to/template-fullstack
git add . && git commit -m "docs: update" && git push
```

**2. Em cada projeto, rode o sync:**
```bash
cd /path/to/seu-projeto

# Do GitHub (padrão)
./sync-globals.sh

# Com URL customizada via env var
TEMPLATE_REPO_URL="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main" ./sync-globals.sh

# De cópia local (sem internet)
./sync-globals.sh /path/to/template-fullstack
```

O sync exibe a versão atual vs template antes de mostrar o diff:
```
⚠  Atualização disponível: v1.0.0 → v1.1.0
~~~ ALTERADO: claude-design.md           (+12 -3 linhas)
    sem alteração: claude-stacks.md
+++ NOVO: .claude/hooks/inject-context.sh
  Aplicar alterações? (s/N)
```

**3. Confirme e commite:**
```bash
git add . && git commit -m "docs: sync from template v1.1.0"
```

> O sync **nunca** toca em: `CLAUDE.md`, `claude-sdd.md`, `claude-stacks-refactor.md`, `docs/`, `.claude/agent-memory/`, `.claude/settings.json`, `.claude/settings.local.json`.

---

## Guia 4 — Sincronização: Projetos → Template

> Quando: o Claude descobriu algo útil e marcou como candidato no `claude-stacks-refactor.md`.

**Como candidatos aparecem:** o Claude auto-atualiza `claude-stacks-refactor.md` durante o dev. Se o aprendizado é reutilizável, marca como `Pendente` na tabela de candidatos.

**Como você sabe:** o git hook avisa após cada commit:
```
>>> 2 candidato(s) pendente(s) de promocao no claude-stacks-refactor.md
    Rode: ./promote-learning.sh /path/to/template-fullstack
```

**1. Rode o promote no projeto:**
```bash
./promote-learning.sh /path/to/template-fullstack
```

**2. Para cada candidato, escolha:** `p` (promover) / `s` (pular) / `r` (rejeitar).

**3. Commite em ambos:**
```bash
# Projeto
git add claude-stacks-refactor.md && git commit -m "docs: review candidates"

# Template
cd /path/to/template-fullstack
git add . && git commit -m "docs: promote learnings from projeto-x" && git push
```

**4. Propague** para outros projetos via `sync-globals.sh`.

### O ciclo completo

```
Claude descobre algo → auto-atualiza refactor.md → marca Pendente
  → hook avisa → promote-learning.sh → template atualizado
    → sync-globals.sh → todos os projetos atualizados
```

---

## Guia 5 — Qualidade e saúde do projeto

### Quality Dashboard

O `docs/quality.md` é atualizado automaticamente via hook toda vez que `bun test` roda:

```bash
# Verificar manualmente
./check-quality.sh

# Saída: docs/quality.md atualizado com:
# - Cobertura geral e por módulo
# - Gates do DoD (≥80% cobertura, lint, typecheck)
# - Spec Coverage (cenários do spec vs testes existentes)
```

### Health Check

```bash
# Diagnóstico visual
./check-health.sh

# Modo CI — exit 1 se falhas críticas
./check-health.sh --assert
```

Verifica: versão instalada, agentes (10/10), arquivos críticos, scripts executáveis, GitHub integration, candidatos pendentes, git hooks.

---

## Fluxos de desenvolvimento

> Diga ao Claude Code exatamente os comandos indicados. Ele orquestra o resto automaticamente.

### Projeto novo

```
1. Iniciar projeto novo
   → Claude segue a sequência de 7 agentes + bootstrap de memória dos agentes (Fase 9)

2. Implementar a US-01
   Implementar a US-02
   → Cada story: spec → plan → execute → verify → finish
```

### Nova feature (projeto existente)

```
1. Implementar a US-XX
   → triage → spec (se contrato novo) → plan → execute → verify → finish

2. Ou: /novo-prd → /prd-planejamento → Implementar a Fase 0
```

### Correção de bug

```
1. Corrigir [descrição do bug]
   → Claude investiga, reproduz, isola causa

2. Red: teste que falha (reproduz o bug)
3. Green: fix mínimo
4. Verify: testes, lint, typecheck, cobertura
```

### Refatoração

```
1. Refatorar [módulo/camada]
   → triage: sem contrato novo → TDD direto

2. Para cada task:
   Red → Green → Refactor
   → Comportamento externo não muda
```

### Aprendizado contínuo

```
Claude descobre algo → auto-atualiza claude-stacks-refactor.md → marca Pendente
  → hook avisa → promote-learning.sh → template atualizado
    → sync-globals.sh → todos os projetos atualizados
```

---

## Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | — | Orquestração do workflow |
| [Bun](https://bun.sh) | ≥ 1.3 | Runtime, PM, test runner |
| [Docker](https://docker.com) + Compose | — | Dev environment |
| [Node](https://nodejs.org) | ≥ 20.19 ou ≥ 22.12 | Tooling (Vite 8, TypeScript) |
| [Python](https://python.org) | 3.x | ui-ux-pro-max scripts |
| [gh CLI](https://cli.github.com) | — | GitHub Issues sync + Project board |
| Git | — | Versionamento + hooks |

### Plugins (instalar no Claude Code)

**Superpowers** — execução, TDD, code review, debugging:
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

**ui-ux-pro-max** — geração de design system:
```
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

### Personal skills de debugging

Instalar em `~/.claude/skills/`:
```bash
mkdir -p ~/.claude/skills/{hono-api-debugging,drizzle-database-debugging,react-tanstack-debugging,escalation-and-bug-journal}
# Copiar SKILL.md de cada skill para a pasta correspondente
```

---

## Referência rápida

### Claude Code

| Comando | O que faz |
|---|---|
| `Iniciar projeto novo` | Sequência de 7 agentes com handoff explícito |
| `Adotar workflow SDD/TDD neste projeto` | Retrofit em projeto existente |
| `Implementar a US-03` | Story completa: triage → spec → plan → execute → verify → finish |
| `Continuar o backlog` | Próxima task P1 pendente |
| `Continuar o backlog da US-03` | Próxima task da story |
| `Executar a task 3.2 do backlog` | Task específica |
| `Corrigir o erro 500 ao criar evento` | Bug fix com debugging protocol |
| `/novo-prd` | Entrevista guiada → PRD em `plans/<feature>.md` |
| `/prd-planejamento` | PRD → plano faseado em `plans/<feature>-plano.md` |

### Terminal

| Comando | Onde | O que faz |
|---|---|---|
| `./adopt-workflow.sh /path/projeto` | Template | Adotar workflow: copia tudo, cria estrutura completa |
| `./sync-globals.sh` | Projeto | Puxar globais + agentes + hooks do GitHub |
| `./sync-globals.sh /path/template` | Projeto | Puxar de cópia local |
| `TEMPLATE_REPO_URL="..." ./sync-globals.sh` | Projeto | Puxar com URL customizada |
| `./promote-learning.sh /path/template` | Projeto | Enviar aprendizados para o template |
| `./setup-github-project.sh` | Projeto | Criar Project board, labels, milestones, branch protection |
| `./sync-github-issues.sh` | Projeto | Sincronizar backlog.md → GitHub Issues |
| `./check-health.sh` | Projeto | Diagnóstico visual do template |
| `./check-health.sh --assert` | Projeto/CI | Diagnóstico + exit 1 se falhas críticas |
| `./check-quality.sh` | Projeto | Atualizar docs/quality.md manualmente |

---

## Licença

Uso interno.
