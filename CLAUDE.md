# CLAUDE.md — Protocolo de Orquestração

> Arquivo carregado automaticamente. Sub-arquivos: lidos **sob demanda** conforme tabela abaixo.
> **Hierarquia:** Instruções do usuário > Superpowers skills > `claude-sdd.md` > `claude-stacks.md` > `claude-debug.md` > `DESIGN.md` > `claude-stacks-refactor.md`
> Para decisões visuais: `docs/design-system/MASTER.md` prevalece sobre `DESIGN.md` (Parte 1).

---

## 🔀 TRIAGEM — Todo pedido segue este fluxo

Para qualquer pedido novo ou ambíguo, invocar **`/triage`**.
Para bugs e troubleshooting, invocar **`/bug`**.

> O routing completo de agentes e a decisão spec-vs-TDD estão em `.claude/commands/triage.md`.

---

## 🤖 ROUTING DE AGENTES — Referência rápida

> O orquestrador **nunca** escreve código de produção diretamente. Toda implementação é delegada.

| Arquivo / Domínio | Agente |
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

---

## ⚡ SKILLS — INVOCAÇÃO OBRIGATÓRIA

| Situação | Skill OBRIGATÓRIA |
|---|---|
| Qualquer feature nova ou criativa | `superpowers:brainstorming` |
| Spec aprovado → decompor em micro-tasks | `superpowers:writing-plans` |
| Executando plano na sessão atual | `superpowers:subagent-driven-development` |
| Implementar qualquer feature ou fix | `superpowers:test-driven-development` |
| **Erro em rota Hono** | `hono-api-debugging` |
| **Erro em query Drizzle** | `drizzle-database-debugging` |
| **Erro em React/TanStack** | `react-tanstack-debugging` |
| 2-3 tentativas de fix falhadas | `escalation-and-bug-journal` |
| Prestes a declarar "pronto" | `superpowers:verification-before-completion` |
| Após concluir feature | `superpowers:requesting-code-review` |
| Implementação completa → merge/PR | `superpowers:finishing-a-development-branch` |
| 2+ tasks independentes | `superpowers:dispatching-parallel-agents` |
| Isolamento de feature em branch | `superpowers:using-git-worktrees` |

---

## 🚀 SCRIPTS — EXECUÇÃO OBRIGATÓRIA

| Gatilho | Script |
|---|---|
| `docs/backlog.md` atualizado | `./sync-github-issues.sh` |
| Primeiro uso em projeto novo | `./setup-github-project.sh` |
| `claude-stacks-refactor.md` com `⏳ Pendente` | Perguntar: rodar `./promote-learning.sh`? |
| Verificar saúde do projeto | `./check-health.sh` |
| Após `bun test` (automático via hook) | `./check-quality.sh` |
| Receber atualização do template | `./sync-globals.sh` |

---

## 📂 SUB-ARQUIVOS — Ler sob demanda

| Arquivo | Ler quando... |
|---|---|
| `claude-sdd.md` | Triage → spec necessária |
| `claude-subagents.md` | Montar contexto para subagente |
| `claude-stacks.md` | Regras de stack, padrões técnicos |
| `claude-stacks-refactor.md` | Aprendizados, bug journal |
| `claude-debug.md` | Bug fix, troubleshooting, CI quebrando |
| `DESIGN.md` | Task frontend OU gerar/regenerar design system |
| `docs/design-system/design-brief.md` | Montar contexto de componente para subagente |
| `docs/design-system/pages/*.md` | Componente com override de página |
| `docs/user-stories.md` | Referenciar story ou criar feature |
| `docs/backlog.md` | Continuar, executar task, verificar progresso |
| `docs/specs/US-XX.spec.md` | Story com spec já gerado |
| `start_project.md` | "Iniciar projeto novo" |
| `.claude/agents/*.md` | Verificar capabilities antes de invocar agente |
| `.claude/agent-memory/[agent]/MEMORY.md` | Consultar memória de agente especializado |

---

## 🏗️ SEQUÊNCIA DE AGENTES — Projeto Novo

Execute nesta ordem com handoff explícito:

1. `requirements-roadmap-builder` → gera `docs/user-stories.md` + `docs/backlog.md` — **aguardar aprovação**
2. `software-architect` → lê backlog → gera `docs/adr/ADR-001-stack-selection.md`
3. `ux-ui-designer` → lê `DESIGN.md` (Parte 2) + user-stories → gera `docs/design-system/MASTER.md` — **aguardar aprovação**
4. `ux-ui-designer` → regenera `docs/design-system/design-brief.md` a partir do MASTER.md aprovado
5. `data-engineer-dba` → lê user-stories + ADRs → schema inicial em `packages/shared/src/schemas/`
6. `devops-sre-engineer` → CI/CD + docker-compose + `.github/workflows/`
7. Rodar `./setup-github-project.sh`

---

## 🚫 PROIBIÇÕES

- ❌ Escrever código de produção sem lançar o agente especializado
- ❌ Código de produção sem teste (Superpowers TDD enforce)
- ❌ Feature com contrato novo sem spec aprovado
- ❌ Funcionalidade não mapeada no backlog
- ❌ `any` TypeScript sem justificativa
- ❌ Commit com testes falhando ou cobertura < 80%
- ❌ Misturar refactor com novas funcionalidades
- ❌ Test runner diferente de `bun test`
- ❌ Ignorar lint (Biome) ou typecheck
- ❌ `[skip ci]`, `--no-verify`, `--force`
- ❌ Tecnologias fora do `claude-stacks.md` sem aprovação
- ❌ Modificar spec sem amendment aprovado
- ❌ Componente frontend sem `DESIGN.md`
- ❌ Cores/fontes/espaçamentos hardcoded
- ❌ Componente sem 4 estados obrigatórios (Loading, Empty, Error, Success)
- ❌ Cortar design brief do contexto de componente
- ❌ Tasks P2/P3 enquanto houver P1 pendentes
- ❌ Declarar pronto sem `superpowers:verification-before-completion`
- ❌ Merge sem `superpowers:requesting-code-review`

---

## 📱 Notificação ntfy (ao aguardar input do usuário)

```bash
bash -c 'printf "%s" "Finalizei X e fiz Y. Posso continuar com Z?" > ~/.claude/ntfy-msg-$WT_SESSION.txt'
```
