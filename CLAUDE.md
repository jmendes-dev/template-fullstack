# CLAUDE.md — Protocolo de Orquestração

> Arquivo carregado automaticamente. Sub-arquivos: lidos **sob demanda** conforme tabela abaixo.
> **Hierarquia:** Instruções do usuário > Superpowers skills > `claude-sdd.md` > `claude-stacks.md` > `claude-debug.md` > `claude-design.md` > `claude-stacks-refactor.md`
> Para decisões visuais: `docs/design-system/MASTER.md` prevalece sobre `claude-design.md`.

---

## 🔀 ÁRVORE DE DECISÃO — Todo pedido segue este fluxo

```
Pedido recebido
├── "Iniciar projeto novo"        → ler start_project.md → SEQUÊNCIA DE AGENTES (ver abaixo)
├── "Adotar workflow / retrofit"  → rodar ./adopt-workflow.sh → ajustar CLAUDE.md
├── Feature / Story (nova)        → TRIAGE → spec se novo contrato → PLAN → EXECUTE → VERIFY → FINISH
├── Feature / Story (existente)   → localizar no backlog → spec se ausente → EXECUTE → VERIFY → FINISH
├── Bug / erro                    → ler claude-debug.md → checkpoint git → skill de debugging
├── Refatoração                   → TRIAGE (sem contrato novo) → TDD direto
├── "Continuar backlog"           → ler docs/backlog.md → próxima P1 → confirmar → executar
└── Pedido ambíguo                → fazer UMA pergunta antes de qualquer ação
```

**TRIAGE:** Story introduz schemas/endpoints/componentes novos? → **SIM**: gerar spec (ler `claude-sdd.md`). **NÃO**: TDD direto.

---

## 🤖 ROUTING MANDATÓRIO DE AGENTES — Sem exceções

> **O orquestrador NUNCA escreve código de produção diretamente. Toda implementação é delegada.**

| Arquivo / Domínio | Agente OBRIGATÓRIO |
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

---

## 📂 SUB-ARQUIVOS — Ler sob demanda

| Arquivo | Ler quando... |
|---|---|
| `claude-sdd.md` | Triage → spec necessária |
| `claude-subagents.md` | Montar contexto para subagente |
| `claude-stacks.md` | Regras de stack, padrões técnicos |
| `claude-stacks-refactor.md` | Aprendizados, bug journal |
| `claude-debug.md` | Bug fix, troubleshooting, CI quebrando |
| `claude-design.md` | Task frontend (criar/modificar componente) |
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
3. `ux-ui-designer` → lê user-stories → gera `docs/design-system/MASTER.md` — **aguardar aprovação**
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
- ❌ Componente frontend sem `claude-design.md`
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
