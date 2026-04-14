# CLAUDE.md — Orquestrador do Projeto

> **Este é o ponto de entrada.** O Claude lê este arquivo automaticamente ao iniciar.
> Os demais arquivos são lidos **sob demanda** — nunca todos de uma vez.
>
> ### Quando ler cada arquivo
>
> | Arquivo | Ler quando... |
> |---|---|
> | `claude-sdd.md` | O fluxo exigir geração de spec (triage resultou em "gerar spec") |
> | `claude-subagents.md` | Precisar de templates de contexto para injetar em subagentes |
> | `claude-stacks.md` | Precisar de regras de stack, estrutura do monorepo ou padrões técnicos |
> | `claude-stacks-refactor.md` | Precisar de padrões de implementação, aprendizados ou regras complementares |
> | `claude-debug.md` | Bug fix, troubleshooting, teste falhando após 2 tentativas, CI quebrando |
> | `claude-design.md` | Task envolver criação ou modificação de componentes frontend |
> | `docs/design-system/design-brief.md` | Montar contexto de componente frontend para subagente |
> | `docs/design-system/pages/*.md` | Montar contexto de componente para página com override |
> | `docs/user-stories.md` | O usuário referenciar uma story ou pedir para criar feature |
> | `docs/backlog.md` | O usuário pedir para continuar, executar task ou verificar progresso |
> | `docs/specs/US-XX-nome.spec.md` | Implementar uma story que já tem spec gerado |
> | `.claude/agents/*.md` | Verificar capabilities de agente antes de invocá-lo |
> | `.claude/agent-memory/[agent]/MEMORY.md` | Consultar memória de agente especializado |
>
> **Nunca abrir todos os arquivos preventivamente.** Ler apenas o necessário para a ação atual.
>
> Em caso de conflito, a hierarquia é:
> Instruções do usuário (CLAUDE.md, pedidos diretos) > Superpowers skills > `claude-sdd.md` > `claude-stacks.md` > `claude-debug.md` > `claude-design.md` > `claude-stacks-refactor.md` > `docs/*`
>
> Para decisões visuais de projeto, `docs/design-system/MASTER.md` prevalece sobre `claude-design.md`.
> Para decisões estruturais (acessibilidade, responsividade, estados obrigatórios), `claude-design.md` prevalece.

---

## 🧭 Metodologia

Este projeto segue **XP (Extreme Programming)** com:
- **SDD (Spec Driven Development)** — define O QUÊ implementar (contratos, cenários)
- **Superpowers** — dirige COMO executar (planning, subagentes, TDD enforcement, code review)
- **Documentação viva** — fornece CONHECIMENTO de stack, design e aprendizados

### Princípios inegociáveis

- **Spec antes de código**: toda feature com contrato novo exige spec aprovado antes da implementação.
- **Red → Green → Refactor**: enforced via `superpowers:test-driven-development` com hard gates.
- **Baby steps**: cada ciclo TDD deve ser o menor possível. Sem antecipar funcionalidades.
- **YAGNI** (You Ain't Gonna Need It): não implementar o que não está na story atual.
- **KISS**: soluções simples e legíveis antes de soluções "elegantes".
- **DRY**: eliminar duplicação, mas somente após o Green — nunca durante o Red.
- **Evidence over claims**: verificar que tudo funciona antes de declarar pronto (`superpowers:verification-before-completion`).
- **Baseline sempre verde**: bugs pré-existentes encontrados durante qualquer ciclo TDD ou verificação **devem ser corrigidos antes de continuar** — nunca ignorar com "é pré-existente". Ver política completa em `claude-debug.md → Bugs pré-existentes`.

### Superpowers — skills disponíveis

O plugin Superpowers está instalado e fornece enforcement automático:

| Skill | Quando usar |
|---|---|
| `superpowers:brainstorming` | Antes de features complexas — explorar antes de planejar |
| `superpowers:writing-plans` | Após spec aprovado — gerar plano granular de micro-tasks |
| `superpowers:subagent-driven-development` | Executar plano com subagentes + code review entre tasks |
| `superpowers:executing-plans` | Alternativa ao subagent-driven para execução na sessão atual |
| `superpowers:test-driven-development` | Implementar qualquer feature ou fix — hard gates TDD |
| `superpowers:systematic-debugging` | Bugs e falhas — antes de propor fix |
| `superpowers:requesting-code-review` | Após concluir feature — review antes de merge |
| `superpowers:verification-before-completion` | Antes de declarar trabalho concluído |
| `superpowers:finishing-a-development-branch` | Implementação completa — merge/PR/cleanup |
| `superpowers:dispatching-parallel-agents` | 2+ tasks independentes em paralelo |
| `superpowers:using-git-worktrees` | Isolamento de feature em worktree git |

---

## 🤖 Agentes Especializados (.claude/agents/)

Agentes especializados por papel técnico, com memória persistente em `.claude/agent-memory/`.
Eles **complementam** o Superpowers: o Superpowers dirige execução (TDD, code review, verification), os agentes executam com conhecimento de domínio específico.

| Agente | Quando usar |
|---|---|
| `requirements-roadmap-builder` | Iniciar projeto novo ou planejar feature maior → gera user-stories.md + backlog.md |
| `project-manager` | Gestão de backlog, sprint tracking, templates de issues/PRs, DoD |
| `software-architect` | Decisões de arquitetura, ADRs, C4 diagrams, review estrutural, biome.json |
| `backend-developer` | API Hono, rotas, serviços, repositórios Drizzle, auth Clerk |
| `frontend-developer` | Componentes React 19, pages, hooks TanStack Query, forms, design system |
| `ux-ui-designer` | Design system (MASTER.md + design-brief.md), specs de componentes |
| `data-engineer-dba` | Schemas Drizzle, migrations, seeds, otimização de queries |
| `qa-engineer` | Test plans, coverage analysis, bug reports, relatórios de qualidade |
| `devops-sre-engineer` | CI/CD GitHub Actions, Dockerfiles, docker-compose, runbooks |
| `security-engineer` | Security review, OWASP checklist, dependency audit |

### Mapeamento ao fluxo SDD → Superpowers

| Step | Agente(s) complementares |
|---|---|
| **Iniciar projeto** | `requirements-roadmap-builder` → user-stories + backlog |
| **Step 0 (TRIAGE)** | `project-manager` informa contexto do backlog |
| **Step 1 (SPEC)** | `software-architect` valida contratos; `data-engineer-dba` valida schema |
| **Step 2 (PLAN)** | `superpowers:writing-plans` decompõe — agentes fornecem contexto técnico |
| **Step 3 (EXECUTE)** | `backend-developer`, `frontend-developer`, `data-engineer-dba` como subagentes |
| **Step 4 (VERIFY)** | `qa-engineer` + `security-engineer` como gates de qualidade |
| **Step 5 (FINISH)** | `devops-sre-engineer` valida CI antes do merge |

### Memória dos agentes

- Cada agente tem memória em `.claude/agent-memory/[agent-name]/MEMORY.md`
- **Memória usa paths relativos** — portável ao copiar o template para novos projetos
- Memória é **versionada no repositório** — compartilhada entre sessões e contribuidores

---

## 📁 Estrutura de orquestração

```
/
├── CLAUDE.md                 ← este arquivo (auto-carregado)
├── claude-sdd.md             ← Spec Driven Development (triage → spec)
├── claude-subagents.md       ← Templates de contexto para subagentes (conhecimento injetado)
├── claude-stacks.md          ← stack base e padrões técnicos
├── claude-stacks-refactor.md ← extensões e aprendizados
├── claude-design.md          ← regras estruturais de UI/UX
├── claude-debug.md           ← orquestração de debugging
├── .claude/
│   ├── agents/               ← agentes especializados por papel (10 agentes)
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
│   └── agent-memory/         ← memória persistente por agente (versionada no repo)
│       ├── backend-developer/MEMORY.md
│       ├── frontend-developer/MEMORY.md
│       └── ...               ← um diretório por agente
├── docs/
│   ├── user-stories.md       ← histórias de usuário + critérios de aceite
│   ├── backlog.md            ← backlog XP Kanban P1/P2/P3
│   ├── specs/                ← specs SDD por story
│   └── design-system/
│       ├── MASTER.md         ← fonte de verdade visual
│       ├── design-brief.md   ← resumo compacto (~800 tokens) para subagentes
│       └── pages/            ← overrides por página
```

---

## 🎯 Prompts de entrada

### Iniciar projeto novo
`Iniciar projeto novo` → ler `start_project.md` → 5 fases → perguntar se quer REQUIREMENTS.md.

### Adotar workflow em projeto existente
`Adotar workflow SDD/TDD neste projeto` → verificar estrutura → adaptar → criar docs/.

### Criar PRD de feature
`/novo-prd` → entrevista guiada → PRD em `plans/<feature>.md` → aprovação → `/prd-planejamento`.

### Transformar PRD em plano faseado
`/prd-planejamento` → lê PRD em `plans/` → plano faseado com tracer bullets em `plans/<feature>-plano.md` → executar fase por fase.

### Implementar feature (story existe)
`Implementar a US-03` → triage → spec (se necessário) → plan (Superpowers) → execute → review → verify → finish.

### Implementar feature (story não existe)
`Criar story e implementar importação CSV` → criar story → **aprovação** → triage → spec → **aprovação** → plan → execute → finish.

### Refatoração
`Refatorar o módulo de autenticação` → triage sem contrato novo → `superpowers:test-driven-development` direto.

### Continuar backlog (com story)
`Continuar o backlog da US-03` → próxima task pendente → spec → executar com TDD → done → próxima.

### Continuar backlog (sem story)
`Continuar o backlog` → seleção por prioridade P1 → P2 → P3 → confirmar antes de executar.

### Executar task específica
`Executar a task 3.2 do backlog` → localizar → spec → TDD → done.

### Corrigir bug
`Corrigir o erro 500 ao criar evento` → `claude-debug.md` → checkpoint → `superpowers:systematic-debugging` + personal skills.

### Prompt ambíguo
Perguntar **uma vez**: "Encontrei US-03 com 3 tasks pendentes. Continuo a partir da 3.4?"

---

## 📐 Fluxo SDD → Superpowers

### Step 0: TRIAGE (automático)

- Story introduz schemas/endpoints/componentes novos? → **SIM**: gerar spec. **NÃO**: TDD direto.

### Step 1: SPEC (claude-sdd.md)

1. Ler User Story + código atual
2. Gerar `docs/specs/US-XX.spec.md` (contratos, cenários, checklist)
3. **Apresentar e aguardar aprovação**
4. Gerar plan Superpowers a partir do spec (Step 2)

### Step 2: PLAN (superpowers:writing-plans)

1. Superpowers lê o spec e decompõe em micro-tasks
2. Cada task orientada a TDD com cenários do spec
3. Ordem: schema → api → componente
4. Contexto injetado do workflow (ver `claude-subagents.md` → Templates):
   - Stack rules (de `claude-stacks.md`)
   - Design brief (de `design-brief.md`) — se frontend
   - Page override — se aplicável
5. Atualizar `docs/backlog.md`

### Step 3: EXECUTE (superpowers:subagent-driven-development)

1. Superpowers dirige execução task por task
2. TDD enforced com hard gates (`superpowers:test-driven-development`)
3. **Code review automático** entre tasks (`superpowers:requesting-code-review`)
4. Se bug: `superpowers:systematic-debugging` + personal skills
5. Frontend: design-brief.md injetado no contexto do component-agent

### Step 4: VERIFY (superpowers:verification-before-completion)

1. `bun test` + coverage ≥ 80% + lint + typecheck
2. Cenários do spec cobertos
3. **Se frontend**: visual checklist completo
4. Nada hardcoded

### Step 5: FINISH (superpowers:finishing-a-development-branch)

1. Verificação final de testes
2. Opções: merge / PR / keep / discard
3. Commit (Conventional Commits)
4. Atualizar `docs/backlog.md`
5. Cleanup

> Sem SDD (trivial): `superpowers:test-driven-development` direto.

---

## 🔴🟢♻️ TDD — Enforced via Superpowers

Hard gates via `superpowers:test-driven-development`. O workflow adiciona:

- **Runner**: `bun test` — único permitido
- **Cobertura**: ≥ 80%
- **Nomenclatura**: `*.test.ts` / `*.test.tsx`
- **Cenários do spec**: cada cenário → ≥ 1 teste
- **Mocking**: Clerk, Resend, S3 — nunca APIs reais no CI
- **Estrutura**: `describe` → `it('deve [X] quando [Y]')` → Arrange/Act/Assert

---

## 🃏 User Stories, Specs & Backlog

- **Stories** = PORQUÊ (valor, critérios de aceite) → `docs/user-stories.md`
- **Specs** = O QUÊ (contratos, schemas, cenários) → `docs/specs/` via `claude-sdd.md`
- **Plans** = COMO (micro-tasks, ordem, TDD) → via `superpowers:writing-plans`
- **Backlog** = Kanban P1/P2/P3 → `docs/backlog.md`

---

## 📱 Notificação ntfy (obrigatório ao aguardar input)

```bash
bash -c 'printf "%s" "Finalizei X e fiz Y. Posso continuar com Z?" > ~/.claude/ntfy-msg-$WT_SESSION.txt'
```

---

## 💬 Comunicação

1. Indicar task do backlog/plano
2. Se spec: indicar seção
3. Teste primeiro (Red), depois código (Green)
4. Sinalizar Refactor
5. Apontar dívidas técnicas fora do escopo
6. Se delegando: indicar contexto injetado

### ✅ Definição de Pronto

Verificado via `superpowers:verification-before-completion`:

1. Testes ≥ 80% cobertura
2. Lint zero erros
3. Typecheck zero erros
4. Commitado e pushado
5. CI verde
6. Cenários do spec cobertos
7. **Frontend**: cores/tipografia/radius do brief, 4 estados, responsivo, animações, hover/focus
8. **Code review** aprovado (`superpowers:requesting-code-review`)

---

## 🤖 Contexto para Subagentes

Superpowers dirige execução. Workflow injeta conhecimento:

| Contexto | Fonte | Quando |
|---|---|---|
| Stack rules | `claude-stacks.md` (extraídas) | Toda task |
| Design brief | `design-brief.md` (~800 tokens) | Frontend |
| Page override | `pages/*.md` | Frontend com override |
| Cenários de teste | `specs/US-XX.spec.md` | Task com spec |
| Regras UI | `claude-design.md` (seções relevantes) | Frontend |

Templates por tipo em `claude-subagents.md` (budgets: schema/api 1500, component 3500, fix 1500).

---

## 🔄 Auto-atualização do Stacks

Erros evitáveis → atualizar `claude-stacks-refactor.md` → commitar com `docs(stacks):`.

```
📝 STACKS ATUALIZADO — claude-stacks-refactor.md
───────────────────────────────────────────────
📍 Seção: [nome] · ✏️ Alteração: [descrição] · 💡 Motivo: [erro e regra]
───────────────────────────────────────────────
```

---

## 🔄 Auto-atualização do Design

Padrões visuais melhores → atualizar `claude-design.md` (reutilizável) ou `MASTER.md` + brief (projeto-específico) → commitar com `docs(design):`.

### Candidatos a promoção (cross-projeto)

Marcar em `claude-stacks-refactor.md` → "Candidatos a promoção". Hook `post-commit` avisa.

---

## 🚫 Proibições

- ❌ Código de produção sem teste (Superpowers TDD enforce)
- ❌ Feature com contrato novo sem spec aprovado
- ❌ Funcionalidade não mapeada no backlog
- ❌ `any` no TypeScript sem justificativa
- ❌ Commit com testes falhando ou cobertura < 80%
- ❌ Misturar refactor com novas funcionalidades
- ❌ Test runner diferente de `bun test`
- ❌ Ignorar lint (Biome) ou typecheck
- ❌ `[skip ci]`, `--no-verify`, `--force`
- ❌ Serviços opcionais sem necessidade explícita
- ❌ Tecnologias fora do `claude-stacks.md` sem aprovação
- ❌ Modificar spec sem amendment aprovado
- ❌ Componente frontend sem `claude-design.md`
- ❌ Cores/fontes/espaçamentos hardcoded
- ❌ Componente sem 4 estados obrigatórios
- ❌ Cortar design brief do contexto de componente
- ❌ Tasks P2/P3 enquanto houver P1 pendentes
- ❌ Declarar pronto sem `superpowers:verification-before-completion`
- ❌ Merge sem `superpowers:requesting-code-review`
