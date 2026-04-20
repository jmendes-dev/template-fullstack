# template-fullstack

> Template de projeto fullstack com workflow SDD/TDD + Superpowers para Claude Code.
> Versão atual: **v1.5.1** — [CHANGELOG](CHANGELOG.md)

**Stack**: Monorepo TypeScript · Bun · Hono · React 19 · Drizzle ORM · PostgreSQL · Tailwind CSS v4 · shadcn/ui

**Plugins**: [Superpowers](https://github.com/obra/superpowers) · [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)

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

**Plugins (instalar no Claude Code):**

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

**Personal skills** — instalar em `~/.claude/skills/`: `hono-api-debugging`, `drizzle-database-debugging`, `react-tanstack-debugging`, `escalation-and-bug-journal`.

---

## Quickstart — Projeto novo

```bash
# 1. Clonar e configurar
git config core.hooksPath .githooks
cp .claude/settings.example.json .claude/settings.json
cp .claude/settings.local.example.json .claude/settings.local.json

# 2. (Opcional) GitHub Project board
./setup-github-project.sh

# 3. Configurar URL do template para sync futuro
export TEMPLATE_REPO_URL="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main"
```

```
# 4. No Claude Code — levantar requisitos e iniciar
Iniciar projeto novo
```

Claude segue a sequência de 7 agentes: requirements-roadmap-builder → software-architect → ux-ui-designer → data-engineer-dba → devops-sre-engineer → setup-github-project.sh.

```
# 5. Implementar story por story
Implementar a US-01
```

---

## Quickstart — Projeto existente (retrofit)

```bash
# Do diretório do template
./adopt-workflow.sh /path/to/seu-projeto

# No projeto
cd /path/to/seu-projeto
cp .claude/settings.example.json .claude/settings.json
./setup-github-project.sh  # opcional
git add . && git commit -m "docs: adopt SDD/TDD workflow"
```

No Claude Code: `Adotar workflow SDD/TDD neste projeto` para ajustar o CLAUDE.md.

---

## Sincronização

| Direção | Como | O que faz |
|---|---|---|
| Template → Projeto | `./sync-globals.sh` | Puxar globais, agentes e hooks do GitHub |
| Template → Projeto (local) | `./sync-globals.sh /path/template` | Sem internet |
| Projeto → Template | `./promote-learning.sh /path/template` | Enviar aprendizados marcados como Pendente |

O sync **nunca** toca: `CLAUDE.md`, `claude-stacks-refactor.md`, `docs/`, `.claude/agent-memory/`, `.claude/settings*.json`.

---

## Estrutura

```
CLAUDE.md                    ← Protocolo de orquestração (ponto de entrada)
claude-sdd.md                ← Metodologia Spec-Driven Development
claude-stacks.md             ← Regras e padrões técnicos da stack
DESIGN.md                    ← Regras estruturais de UI/UX
claude-debug.md              ← Referência de debugging e escalação
start_project.md             ← Gates de fase para projeto novo
.claude/
  commands/                  ← Slash commands: /bug /triage /feature /finish /continue /new-project /refactor
  agents/                    ← 10 agentes especializados
  hooks/                     ← PreToolUse, UserPromptSubmit, PostToolUse
  agent-memory/              ← Memória persistente por agente
docs/
  user-stories.md            ← Stories com critérios de aceite
  backlog.md                 ← Kanban P1/P2/P3
  specs/                     ← Specs SDD por story
  design-system/             ← MASTER.md + design-brief.md
  contracts/                 ← Contratos API ↔ Frontend
  quality.md                 ← Quality Dashboard (auto-atualizado)
```

---

## Referência rápida

### Claude Code

| O que dizer | O que acontece |
|---|---|
| `Iniciar projeto novo` | Sequência de 7 agentes com handoff |
| `Implementar a US-03` | triage → spec → plan → execute → verify → finish |
| `Continuar o backlog` | Próxima task P1 pendente |
| `Corrigir o erro [descrição]` | Bug fix com protocolo de debugging |

### Terminal

| Script | Onde | O que faz |
|---|---|---|
| `./adopt-workflow.sh /path` | Template | Adotar workflow em projeto existente |
| `./sync-globals.sh` | Projeto | Puxar atualizações do template |
| `./promote-learning.sh /path` | Projeto | Enviar aprendizados para o template |
| `./setup-github-project.sh` | Projeto | Criar Project board + labels |
| `./sync-github-issues.sh` | Projeto | Sincronizar backlog.md → GitHub Issues |
| `./check-health.sh [--assert]` | Projeto | Diagnóstico (--assert para CI) |
| `./check-quality.sh` | Projeto | Atualizar quality.md manualmente |

---

## Licença

MIT
