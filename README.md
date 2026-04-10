# template-fullstack

> Template de projeto fullstack com workflow SDD/TDD + Superpowers para Claude Code.

**Stack**: Monorepo TypeScript · Bun · Hono · React 19 · Drizzle ORM · PostgreSQL · Tailwind CSS v4 · shadcn/ui

**Plugins**: [Superpowers](https://github.com/obra/superpowers) (execução + TDD + code review) · [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (design system)

---

## Arquitetura

O sistema funciona em **3 camadas**:

```
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
└─────────────────────────────────────────────────────────┘
```

---

## Estrutura do template

```
template-fullstack/
│
│  ── Orquestração ──
├── CLAUDE.md                     ← Ponto de entrada. 9 prompts reconhecidos
├── claude-sdd.md                 ← Specs: define O QUÊ implementar (contratos, cenários)
├── claude-subagents.md           ← Templates de contexto para subagentes (conhecimento injetado)
├── claude-stacks.md              ← Stack técnica: regras, padrões, anti-patterns
├── claude-stacks-refactor.md     ← Aprendizados (começa vazio, cresce com o projeto)
├── claude-design.md              ← Regras estruturais de UI/UX reutilizáveis
├── claude-debug.md               ← Orquestração de debugging (Superpowers + personal skills)
│
│  ── Pipelines de geração ──
├── REQUIREMENTS.md               ← Entrevista → user-stories + backlog (Kanban P1/P2/P3)
├── DESIGN_SYSTEM.md              ← ui-ux-pro-max → entrevista → MASTER.md + design-brief.md
│
│  ── Bootstrap ──
├── start_project.md              ← 5 fases: planejamento → scaffold → deps/banco → app → CI/CD
│
│  ── Docs vivos (por projeto) ──
├── docs/
│   ├── user-stories.md           ← Stories com critérios de aceite
│   ├── backlog.md                ← Kanban P1/P2/P3 com tasks
│   ├── specs/                    ← Specs SDD por story
│   └── design-system/
│       ├── MASTER.md             ← Fonte de verdade visual do projeto
│       ├── design-brief.md       ← Resumo ~800 tokens para subagentes de frontend
│       └── pages/                ← Overrides por página
│
│  ── Ferramentas ──
├── adopt-workflow.sh             ← Adotar workflow em projeto existente
├── sync-globals.sh               ← Template → projetos (distribuir atualizações)
├── promote-learning.sh           ← Projetos → template (coletar aprendizados)
│
│  ── Git ──
├── .githooks/post-commit         ← Avisa sobre candidatos pendentes de promoção
├── .gitignore
└── README.md
```

---

## Globais vs Instanciados

| Tipo | Arquivos | Comportamento |
|---|---|---|
| **Global** | `claude-stacks.md`, `claude-design.md`, `claude-subagents.md`, `claude-debug.md`, `start_project.md`, `REQUIREMENTS.md`, `DESIGN_SYSTEM.md` | Reutilizáveis. Atualizados no template, propagados via `sync-globals.sh` |
| **Instanciado** | `CLAUDE.md`, `claude-sdd.md`, `claude-stacks-refactor.md`, tudo em `docs/` | Específicos por projeto. Nunca sobrescritos pelo sync |

### Onde cada ferramenta vive

| Arquivo | Template | Projetos |
|---|---|---|
| `adopt-workflow.sh` | ✅ | ❌ (roda uma vez, do template para o projeto) |
| `sync-globals.sh` | ✅ | ✅ (roda nos projetos para puxar atualizações) |
| `promote-learning.sh` | ✅ | ✅ (roda nos projetos para enviar aprendizados) |
| `.githooks/post-commit` | ✅ | ✅ (avisa sobre candidatos pendentes) |

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
# Editar sync-globals.sh linha 24: trocar SEU_USUARIO pelo seu username
```

**3. Levantar requisitos** — colar o conteúdo de `REQUIREMENTS.md` no Claude (chat ou Code). Gera `docs/user-stories.md` + `docs/backlog.md`.

**4. Gerar design system** (requer [ui-ux-pro-max](#pré-requisitos)):
```bash
# Passo 1: engine gera a base
python3 .claude/skills/ui-ux-pro-max/scripts/search.py \
  "[indústria]" --design-system --persist -p "[NomeProjeto]"

# Passo 2: colar prompt do DESIGN_SYSTEM.md no Claude para refinar

# Passo 3: design-brief.md gerado automaticamente
```

**5. Bootstrap** — no Claude Code: `Iniciar projeto novo` (5 fases automáticas).

**6. Implementar** — no Claude Code: `Continuar o backlog` (pega próxima task P1).

---

## Guia 2 — Projeto existente (retrofit)

**1. Rodar script de adoção** (do diretório do template):
```bash
./adopt-workflow.sh /path/to/seu-projeto
```

**2. Copiar scripts de sync para o projeto:**
```bash
cp sync-globals.sh promote-learning.sh /path/to/seu-projeto/
```

**3. Ajustar CLAUDE.md** ao projeto ou no Claude Code: `Adotar workflow SDD/TDD neste projeto`.

**4. Gerar docs** — REQUIREMENTS.md (stories + backlog) e DESIGN_SYSTEM.md (design system).

**5. Commitar:**
```bash
git add . && git commit -m "docs: adopt SDD/TDD workflow"
```

---

## Guia 3 — Sincronização: Template → Projetos

> Quando: você atualizou um arquivo global no template e quer propagar para projetos.

**1. Atualize e pushe o template:**
```bash
cd /path/to/template-fullstack
git add claude-design.md && git commit -m "docs: update" && git push
```

**2. Em cada projeto, rode o sync:**
```bash
cd /path/to/cotamar
./sync-globals.sh                           # do GitHub
./sync-globals.sh /path/to/template         # de cópia local
```

**3. O script mostra diff e pede confirmação:**
```
~~~ ALTERADO: claude-design.md  (+12 -3 linhas)
    sem alteração: claude-stacks.md
    ...
  Aplicar alterações? (s/N)
```

**4. Confirme e commite:**
```bash
git add . && git commit -m "docs: sync from template"
```

> O sync **nunca** toca em: CLAUDE.md, claude-sdd.md, claude-stacks-refactor.md, docs/*.

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
git add . && git commit -m "docs: promote learnings from cotamar" && git push
```

**4. Propague** para outros projetos via `sync-globals.sh`.

### O ciclo completo

```
Claude descobre algo → auto-atualiza refactor.md → marca Pendente
  → hook avisa → promote-learning.sh → template atualizado
    → sync-globals.sh → todos os projetos atualizados
```

---

## Fluxo completo de uma feature

```
1. REQUISITOS        REQUIREMENTS.md → entrevista → user-stories + backlog (P1/P2/P3)

2. DESIGN            DESIGN_SYSTEM.md → ui-ux-pro-max → MASTER.md + design-brief.md

3. BOOTSTRAP         start_project.md → 5 fases → projeto rodando com CI verde

4. IMPLEMENTAÇÃO
   │
   ├── Spec (SDD)           define O QUÊ (contratos, cenários)
   │     └── claude-sdd.md
   │
   ├── Plan (Superpowers)   define COMO (micro-tasks, ordem, TDD)
   │     └── superpowers:writing-plans
   │
   ├── Execute (Superpowers) subagentes + TDD hard gates + code review
   │     ├── superpowers:subagent-driven-development
   │     ├── superpowers:test-driven-development
   │     └── Contexto injetado: stack rules + design-brief + cenários do spec
   │
   ├── Verify (Superpowers)  testes + lint + typecheck + visual checklist
   │     └── superpowers:verification-before-completion
   │
   └── Finish (Superpowers)  merge/PR + backlog atualizado
         └── superpowers:finishing-a-development-branch

5. DEBUGGING         claude-debug.md orquestra:
   │                 ├── superpowers:systematic-debugging (metodologia)
   │                 └── Personal skills (Hono, Drizzle, React, escalação)
   │
6. APRENDIZADO       Auto-atualização contínua:
                     ├── claude-stacks-refactor.md (erros técnicos)
                     ├── claude-design.md / MASTER.md (padrões visuais)
                     └── candidatos → hook → promote → sync
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

Ou via CLI: `npm install -g uipro-cli && uipro init --ai claude`

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
| `Iniciar projeto novo` | Bootstrap completo (5 fases) |
| `Adotar workflow SDD/TDD neste projeto` | Retrofit em projeto existente |
| `Continuar o backlog` | Próxima task P1 pendente |
| `Continuar o backlog da US-03` | Próxima task da story |
| `Implementar a US-03` | Story completa: spec → plan → execute |
| `Executar a task 3.2 do backlog` | Task específica |
| `Corrigir o erro 500 ao criar evento` | Bug fix com debugging protocol |

### Terminal

| Comando | Onde | O que faz |
|---|---|---|
| `./adopt-workflow.sh /path/projeto` | Template | Adotar workflow em projeto |
| `./sync-globals.sh` | Projeto | Puxar atualizações do template |
| `./sync-globals.sh /path/template` | Projeto | Puxar atualizações (local) |
| `./promote-learning.sh /path/template` | Projeto | Enviar aprendizados para o template |

---

## Licença

Uso interno.
