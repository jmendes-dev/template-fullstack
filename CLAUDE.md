# CLAUDE.md — Protocolo de Orquestração

> Arquivo carregado automaticamente. Sub-arquivos: lidos **sob demanda** conforme tabela abaixo.
> **Hierarquia:** Instruções do usuário > **Kit Empresa** (`claude-stacks.md`, `start_project.md`, `master-*` skills, `docs/<empresa>`) > Superpowers skills > `.claude/commands/` > `claude-sdd.md` > `DESIGN.md` > `claude-stacks-refactor.md`
> Para decisões visuais: `docs/design-system/MASTER.md` prevalece sobre `DESIGN.md` (Parte 1).

---

## 🧭 PRINCÍPIOS GERAIS — Tom de toda resposta e implementação

- **Simplicity First** — toda mudança o mais simples possível. Impacto mínimo no código.
- **No Laziness** — encontrar causas raiz. Sem fix temporário. Padrão de senior engineer.
- **Minimal Impact** — tocar apenas o necessário. Não introduzir bugs nem regressões.

---

## 🎯 PROTOCOLO DE RESPOSTA — OBRIGATÓRIO PARA TODA RESPOSTA

Antes de entregar **qualquer** resposta substantiva ao usuário:
1. Invocar skill `five-response-selector`
2. Gerar internamente 5 candidatos de resposta
3. Pontuar cada candidato com a fórmula de probabilidade do skill
4. Retornar **apenas** o candidato de maior probabilidade
5. Append ao final: `[Candidato X selecionado | P = 0.XX | 5 avaliados]`

**Exceções** (não aplicar): confirmações de uma palavra ("ok", "sim"), etapas internas de workflow de skills.

---

## 📦 KIT EMPRESA — Camada imutável (sincronizada via Action)

A organização mantém um kit oficial obrigatório em todos os projetos. Esses arquivos são **sincronizados pela GitHub Action corporativa** (allowlist) e **não devem ser editados localmente** — em conflito, a versão da empresa prevalece.

| Caminho | Conteúdo |
|---|---|
| `claude-stacks.md` | Stack pinada + regras técnicas (fonte de verdade) |
| `start_project.md` | Fases com gates para projeto novo |
| `.claude/skills/master-*/` | 7 skills operacionais oficiais (PRD, plan, fase, schema, deploy, security review, CI fix) |
| `docs/auth-clerk.md`, `docs/deploy-*.md`, `docs/observability.md`, etc. | ~33 guias técnicos por domínio |

**Conteúdo local** (template) costura sobre o kit via `CLAUDE.md`, `.claude/commands/`, `.claude/agents/` — preservado integralmente.

> ⚠️ **Fallback (projeto novo)**: se uma skill `master-*` referenciada por commands ainda não existe localmente, é porque a Action corporativa não rodou neste projeto ainda. Nesse caso, seguir o fluxo equivalente do template (`superpowers:writing-plans` no lugar de `master-plan`, agente especialista no lugar de `master-fase`, etc.) até a próxima sincronização.

---

## 🔀 TRIAGEM — Todo pedido segue este fluxo

Para qualquer pedido novo ou ambíguo, invocar **`/triage`**.
Para bugs e troubleshooting, invocar **`/bug`**.
Para refatoração, invocar **`/refactor`**.

> O routing completo de agentes e a decisão spec-vs-TDD estão em `.claude/commands/triage.md`.

---

## 🤖 ROUTING DE AGENTES — Referência rápida

> O orquestrador **nunca** escreve código de produção diretamente. Toda implementação é delegada.

| Arquivo / Domínio / Gatilho | Agente | Invocação |
|---|---|---|
| `apps/api/**` (rotas, serviços, middleware) | `backend-developer` | Automática por arquivo |
| `apps/web/**` (componentes, pages, hooks) | `frontend-developer` | Automática por arquivo |
| `packages/shared/src/schemas/**` | `data-engineer-dba` | Automática por arquivo |
| CI/CD, Dockerfile, GitHub Actions, docker-compose | `devops-sre-engineer` | Automática por arquivo |
| `docs/design-system/**`, componentes visuais novos | `ux-ui-designer` | Via `/feature` quando há UI nova |
| Arquitetura, ADRs, revisão estrutural | `software-architect` | Via `/new-project` ou review explícito |
| Backlog, sprint, DoD, issues/PRs | `project-manager` | `/continue` Passo 0 e Passo 2 |
| Levantamento de requisitos, roadmap | `requirements-roadmap-builder` | `/new-project` Fase 1/2 |
| Test plans, coverage, bug reports | `qa-engineer` | `/feature` Passo 5.1 (sempre) |
| OWASP, dependency audit, security review | `security-engineer` | `/feature` Passo 5.2 (gatilhos: auth, input, segredos, CORS) |
| Bug não-óbvio após diagnóstico ou task de feature antes de delegar | `tech-lead` | `/bug` Passo 4.5 e `/feature` Passo 4 |

---

## 🔁 OWNERSHIP DE ETAPAS — Commands vs Skills

> Commands são **orquestradores pt-BR** que invocam skills. Não competem — cada um tem dono.

| Etapa do fluxo | Dono | Mecanismo |
|---|---|---|
| Classificar pedido | `/triage` | command (wrapper) |
| Brainstorm pré-spec | `superpowers:brainstorming` | skill |
| Redigir spec | `claude-sdd.md` + `/feature` | template + command |
| Decompor em micro-tasks | `superpowers:writing-plans` | skill |
| Executar tasks em paralelo | `superpowers:subagent-driven-development` | skill |
| Analisar causa raiz + criar brief + delegar + validar | `tech-lead` | agente (intermediário entre orquestrador e especialista) |
| QA review de cada feature | `qa-engineer` + `/feature` Passo 5.1 | agente |
| Security review condicional | `security-engineer` + `/feature` Passo 5.2 | agente |
| Manter backlog vivo | `project-manager` + `/continue` Passos 0/2 | agente |
| Implementar (TDD) | `superpowers:test-driven-development` | skill |
| Verificar antes de declarar pronto | `superpowers:verification-before-completion` | skill |
| Code review | `superpowers:requesting-code-review` | skill |
| Merge / PR | `superpowers:finishing-a-development-branch` | skill |
| Encerrar ciclo | `/finish` | command (wrapper) |

> Skills `master-*` (kit empresa) complementam etapas específicas: `master-prd`/`master-plan` para PRD/plano, `master-fase` para execução por fase, `master-schema` para mudanças de schema, `master-deploy` para deploy, `master-security-review` para revisão por endpoint, `master-ci-fix` para CI vermelho. Ver tabela completa em "⚡ SKILLS" abaixo.

---

## ⚡ SKILLS — INVOCAÇÃO OBRIGATÓRIA

| Situação | Skill OBRIGATÓRIA |
|---|---|
| **Antes de qualquer resposta substantiva** | `five-response-selector` |
| **Criar PRD / novo produto** | `master-prd` (kit empresa) — substitui `novo-prd` |
| **Transformar PRD em plano de fases** | `master-plan` (kit empresa) — substitui `prd-planejamento` |
| **Executar fase pendente do plano** | `master-fase` (kit empresa) |
| **Mudança de schema (Drizzle/Zod) ou migration** | `master-schema` (kit empresa) |
| **Configurar deploy de produção** | `master-deploy` (kit empresa) — pergunta target obrigatoriamente (regra 32) |
| **CI quebrou após push** | `master-ci-fix` (kit empresa) — loop ≤7 tentativas |
| **Security review por endpoint Hono** | `master-security-review` (kit empresa) — gatilho do Passo 5.2 do `/feature` |
| Qualquer feature nova ou criativa | `superpowers:brainstorming` |
| Spec aprovado → decompor em micro-tasks | `superpowers:writing-plans` |
| Executando plano na sessão atual | `superpowers:subagent-driven-development` |
| Implementar qualquer feature ou fix | `superpowers:test-driven-development` |
| **Erro em rota Hono** | `hono-api-debugging` |
| **Erro em query Drizzle** | `drizzle-database-debugging` |
| **Erro em React/TanStack** | `react-tanstack-debugging` |
| 3 tentativas falhadas (ver nível 2 em `claude-debug.md`) | `escalation-and-bug-journal` |
| Prestes a declarar "pronto" | `superpowers:verification-before-completion` — pergunta-gatilho obrigatória: *"Would a staff engineer approve this?"* |
| Após concluir feature | `superpowers:requesting-code-review` |
| Implementação completa → merge/PR | `superpowers:finishing-a-development-branch` |
| 2+ tasks independentes | `superpowers:dispatching-parallel-agents` |
| Isolamento de feature em branch | `superpowers:using-git-worktrees` |

---

## 🚀 SCRIPTS — EXECUÇÃO OBRIGATÓRIA

| Gatilho | Script |
|---|---|
| `docs/backlog.md` atualizado | `./sync-github-issues.sh` (detecta `## Wave:` e mapeia para GitHub Milestone) |
| Primeiro uso em projeto novo | `./setup-github-project.sh` (cria milestones a partir das waves do backlog) |
| `claude-stacks-refactor.md` com `⏳ Pendente` | Perguntar: rodar `./promote-learning.sh`? |
| Verificar saúde do projeto | `./check-health.sh` |
| Após `bun test` (automático via hook) | `./check-quality.sh` |
| Receber atualização do template | `./sync-globals.sh` |

---

## 📂 SUB-ARQUIVOS — Ler sob demanda

| Arquivo | Ler quando... |
|---|---|
| `claude-sdd.md` | Triage → spec necessária + contextos de subagente |
| `claude-stacks.md` | Regras de stack, padrões técnicos (kit empresa — fonte de verdade) |
| `docs/auth-clerk.md`, `docs/deploy-*.md`, `docs/observability.md`, etc. | Guias técnicos por domínio (kit empresa) |
| `claude-stacks-versions.md` | Versões pinadas e notas de compatibilidade (atualizar ao trocar versão) |
| `claude-stacks-refactor.md` | Aprendizados, bug journal |
| `claude-debug.md` | Política de bugs pré-existentes + tabela de escalação (referência para `/bug`) |
| `DESIGN.md` | Task frontend OU gerar/regenerar design system |
| `docs/design-system/design-brief.md` | Montar contexto de componente para subagente |
| `docs/design-system/pages/*.md` | Componente com override de página |
| `docs/user-stories.md` | Referenciar story ou criar feature |
| `docs/backlog.md` | Continuar, executar task, verificar progresso |
| `docs/specs/US-XX.spec.md` | Story com spec já gerado |
| `start_project.md` | Gates de fase (referência para `/new-project`) |
| `.claude/agents/*.md` | Verificar capabilities antes de invocar agente |
| `.claude/agent-memory/[agent]/MEMORY.md` | Consultar memória de agente especializado |

---

## 🚫 PROIBIÇÕES

- ❌ Escrever código de produção sem lançar o agente especializado
- ❌ Código de produção sem teste (Superpowers TDD enforce)
- ❌ Feature com contrato novo sem spec aprovado
- ❌ Funcionalidade não mapeada no backlog
- ❌ `any` TypeScript sem justificativa
- ❌ Commit com testes falhando ou cobertura < 95%
- ❌ Misturar refactor com novas funcionalidades
- ❌ Test runner diferente de `bun test`
- ❌ Ignorar lint (Biome) ou typecheck
- ❌ `[skip ci]`, `--no-verify`, `--force`
- ❌ Tecnologias fora do `claude-stacks.md` (kit empresa) sem aprovação
- ❌ Modificar spec sem amendment aprovado
- ❌ Componente frontend sem `DESIGN.md`
- ❌ Cores/fontes/espaçamentos hardcoded
- ❌ Componente sem 4 estados obrigatórios (Loading, Empty, Error, Success)
- ❌ Cortar design brief do contexto de componente
- ❌ Tasks P2/P3 enquanto houver P1 pendentes
- ❌ Declarar pronto sem `superpowers:verification-before-completion`
- ❌ Pular QA review (`qa-engineer` em `/feature` 5.1) antes de merge
- ❌ Pular Security review (`security-engineer` em `/feature` 5.2) quando feature toca auth/input/segredos
- ❌ Contornar bug pré-existente — aplicar STOP protocol do `claude-debug.md`
- ❌ Merge sem `superpowers:requesting-code-review`

---

## 📱 Notificação ntfy (ao aguardar input do usuário)

```bash
bash -c 'printf "%s" "Finalizei X e fiz Y. Posso continuar com Z?" > ~/.claude/ntfy-msg-$WT_SESSION.txt'
```
