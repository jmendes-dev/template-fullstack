# claude-sdd.md — Spec Driven Development

> **Este arquivo define o fluxo de Spec Driven Development (SDD).**
> SDD é uma camada de planejamento técnico entre as User Stories e a implementação.
> Gera specs compactas e autocontidas que definem O QUÊ implementar.
> O Superpowers (`writing-plans` + `subagent-driven-development`) define COMO executar.
>
> **Hierarquia**: `CLAUDE.md` > `claude-sdd.md` > `claude-stacks.md` > `claude-stacks-refactor.md`
> SDD não substitui o TDD — ele alimenta o TDD com contratos precisos, reduzindo retrabalho e consumo de tokens.

---

## 🎯 Por que SDD

| Problema sem SDD | Solução com SDD |
|---|---|
| Agente lê codebase inteiro para cada task | Subagente recebe apenas o spec + regras relevantes |
| Testes são "descobertos" durante implementação | Cenários de teste já estão no spec antes do Red |
| Contratos API ↔ Frontend surgem ad-hoc | Contratos definidos no spec, implementados em paralelo |
| Refactors cascateiam por falta de contrato | Interfaces congeladas no spec — mudança exige amendment |
| Alto gasto de tokens por contexto desnecessário | Spec é o contexto mínimo suficiente |

---

## 📐 O que é um Spec

Um **spec** é um documento Markdown compacto que descreve **o quê** será implementado e **como** será validado — sem código de produção.

### Estrutura obrigatória de um spec

```markdown
# Spec: US-XX — [Nome da feature]

## Contexto
[Uma frase sobre o que essa feature resolve e onde ela se encaixa]

## Contratos

### Types/Schemas (packages/shared)
[Tipos TypeScript e schemas Zod que serão criados ou modificados]

### API Endpoints (apps/api)
[Método, path, request body, response body, status codes]

### Componentes (apps/web)
[Nome, props, estados (loading/empty/error/success), eventos]

## Dependências
[Arquivos existentes que serão lidos ou modificados — paths exatos]

## Cenários de teste
[Lista numerada de cenários no formato: DADO x, QUANDO y, ENTÃO z]

## Critério de conclusão
[Checklist binário — cada item é verificável por automação ou inspeção]
```

---

## 📁 Onde ficam os specs

```
docs/
├── user-stories.md
├── backlog.md
└── specs/
    ├── US-01-nome.spec.md
    ├── US-02-nome.spec.md
    └── ...
```

Convenção de nome: `US-{número}-{slug-kebab-case}.spec.md`

---

## 🔄 Fluxo SDD → Superpowers (automático, inline)

O usuário pede para implementar uma story com um único comando (ex: `Implementar a US-03`).
O agente principal decide se precisa de spec, gera, apresenta, e segue para o Superpowers — tudo na mesma conversa.

```
Usuário: "Implementar a US-XX"
  │
  ▼
┌─────────────────────────────────────────┐
│  0. TRIAGE — Precisa de spec?           │  ← Agente principal
│     SIM → continuar │  NÃO → TDD direto│
└──────────┬──────────────────────────────┘
           │ SIM
           ▼
┌─────────────────────────────────────────┐
│  1. SPEC — Gerar spec automaticamente   │  ← Agente principal
│     Salvar em docs/specs/US-XX.spec.md  │
│     ⏸️  AGUARDAR APROVAÇÃO              │
└──────────┬──────────────────────────────┘
           │ Aprovado
           ▼
┌─────────────────────────────────────────┐
│  2. PLAN — Superpowers writing-plans    │  ← Superpowers
│     Lê o spec aprovado                  │
│     Decompõe em micro-tasks (2-5 min)   │
│     Injeta contexto do workflow          │
│     Atualiza docs/backlog.md            │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  3. EXECUTE — Superpowers subagents     │  ← Superpowers
│     subagent-driven-development ou      │
│     dispatching-parallel-agents         │
│     TDD enforced com hard gates         │
│     Code review entre tasks             │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  4. VERIFY — Superpowers verification   │  ← Superpowers
│     spec✓ testes✓ lint✓ typecheck✓      │
│     Visual checklist (se frontend)      │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  5. FINISH — Superpowers branch finish  │  ← Superpowers
│     Merge/PR + backlog atualizado       │
└─────────────────────────────────────────┘
```

### Tabela de decisão (Step 0 — TRIAGE)

| A story introduz...? | Decisão |
|---|---|
| Novo schema ou tabela | → Gerar spec |
| Novo endpoint de API | → Gerar spec |
| Novo componente com estado (fetch, form, mutation) | → Gerar spec |
| Novo campo em schema existente | → Gerar spec amendment |
| Apenas fix de bug | → TDD direto |
| Apenas refactor (sem mudança de contrato) | → TDD direto |
| Apenas config (Docker, CI, Biome) | → TDD direto |
| Componente estático (sem fetch, sem state) | → TDD direto |
| Task < 10 linhas de código | → TDD direto |

> Na dúvida, **gerar spec**. O custo de um spec desnecessário (~2 min) é menor que o retrabalho.

### Regras do fluxo

1. **A decisão spec vs TDD direto é automática** — sem perguntar ao usuário.
2. **Se spec necessário, o agente gera e apresenta antes de qualquer código.**
3. **O único ponto de pausa é a aprovação do spec.**
4. **Após aprovação, o Superpowers assume a execução** (Steps 2-5).
5. **Spec é imutável durante a implementação.** Mudança exige amendment aprovado.
6. **Cada seção do spec mapeia para tasks no plan do Superpowers.**

### Como o agente apresenta o spec para aprovação

```
📐 SPEC GERADO — docs/specs/US-XX-nome.spec.md
─────────────────────────────────────────────
[conteúdo do spec]
─────────────────────────────────────────────
Contratos: X schemas, Y endpoints, Z componentes
Cenários de teste: N
─────────────────────────────────────────────
Aprova este spec para iniciar a implementação?
(Responda "sim" para prosseguir, ou indique os ajustes desejados)
```

S� prosseguir após "sim" explícito.

---

## 📝 Como o agente gera um Spec

### Input (coletado automaticamente)

1. User Story com critérios de aceite (de `docs/user-stories.md`)
2. Estado atual dos schemas em `packages/shared/src/schemas/`
3. Endpoints existentes em `apps/api/src/routes/`
4. Componentes existentes em `apps/web/src/` (se envolve frontend)

### Processo de geração

1. **Ler** a User Story e critérios de aceite
2. **Analisar** estado atual do código
3. **Derivar contratos**: types → API → componentes (ordem de dependência)
4. **Derivar cenários de teste** dos critérios de aceite (cada critério gera ≥1 cenário)
5. **Listar dependências** — paths exatos
6. **Gerar checklist de conclusão** — cada item verificável
7. **Salvar** em `docs/specs/US-XX-nome.spec.md`
8. **Apresentar** ao usuário e aguardar aprovação

### Regras de qualidade

- **Compacto**: ≤ 150 linhas. Se ultrapassar, a story é grande demais — quebrá-la.
- **Sem código de produção**: apenas types, interfaces e assinaturas.
- **Sem ambiguidade**: cada campo com tipo explícito, cada cenário com resultado concreto.
- **Autocontido**: subagente implementa lendo apenas o spec + regras de stack.

---

## 🧩 Templates de Spec por tipo

### Spec de Schema/Types (packages/shared)

```markdown
## Contratos — Schema

### Tabela: `nome_tabela`
| Coluna | Tipo Drizzle | Nullable | Default | Nota |
|---|---|---|---|---|
| id | uuid | não | defaultRandom() | PK |
| ... | ... | ... | ... | ... |
| createdAt | timestamp | não | now() | |
| updatedAt | timestamp | não | now() | |

### Zod Schemas
- `insertNomeSchema` — campos: [listar], omit: [id, createdAt, updatedAt]
- `selectNomeSchema` — todos os campos
- `updateNomeSchema` — partial de insert, com id obrigatório

### Tipos exportados
- `type InsertNome = z.input<typeof insertNomeSchema>`
- `type SelectNome = z.infer<typeof selectNomeSchema>`
```

### Spec de API Endpoint (apps/api)

```markdown
## Contratos — API

### `POST /api/v1/recursos`
- **Auth**: requer userId
- **Request body**: `insertRecursoSchema`
- **Response 201**: `{ data: SelectRecurso }`
- **Response 400**: `{ error: string, code: "VALIDATION_ERROR", details: ZodIssue[] }`
- **Response 401**: `{ error: "Unauthorized", code: 401 }`

### Cenários de teste — API
1. DADO body válido, QUANDO POST /recursos, ENTÃO 201 + recurso criado
2. DADO body sem campo obrigatório, QUANDO POST /recursos, ENTÃO 400
3. DADO sem auth header, QUANDO POST /recursos, ENTÃO 401
```

### Spec de Componente (apps/web)

```markdown
## Contratos — Componente

### `RecursoForm`
- **Props**: `{ onSuccess: () => void }`
- **Estado interno**: React Hook Form com `insertRecursoSchema`
- **Submissão**: mutation via TanStack Query → POST /api/v1/recursos
- **Estados**:
  - idle: form visível, botão habilitado
  - submitting: botão disabled + spinner
  - error: toast Sonner com mensagem do backend
  - success: chama `onSuccess()` + toast de confirmação

### Cenários de teste — Componente
1. DADO form renderizado, QUANDO preencher e submeter, ENTÃO mutation chamada
2. DADO form vazio, QUANDO submeter, ENTÃO erros Zod nos campos
3. DADO mutation erro 400, QUANDO resposta chegar, ENTÃO toast com mensagem
```

---

## 🏗️ Do Spec ao Plan (Superpowers)

Após spec aprovado, o agente principal invoca `superpowers:writing-plans` passando:

### Input para o Superpowers

1. **O spec aprovado** (`docs/specs/US-XX-nome.spec.md`) — como documento principal
2. **Contexto de conhecimento** (injetado do workflow — ver `claude-subagents.md`):
   - Stack rules relevantes (de `claude-stacks.md`)
   - Design brief (`docs/design-system/design-brief.md`) — se tem componentes frontend
   - Page override (`docs/design-system/pages/*.md`) — se página tem override

### O que o Superpowers faz com o spec

1. **Decompõe** o spec em micro-tasks granulares (2-5 min cada)
2. **Respeita ordem de dependência**: schema → api → componente
3. **Distribui cenários de teste** do spec nas tasks correspondentes
4. **Orienta cada task para TDD** (teste antes de código)
5. **Inclui checkpoints de code review** entre tasks
6. **Para tasks de frontend**: inclui design brief + visual checklist no contexto

### O que o workflow controla (não o Superpowers)

- O **spec** é a fonte de verdade dos contratos — Superpowers não modifica contratos
- Os **cenários de teste** vêm do spec — Superpowers distribui mas não inventa
- O **design brief** é injetado pelo workflow — Superpowers não conhece o design system
- O **backlog.md** é atualizado pelo workflow com as tasks do plan

### Regras

- Uma task = um ciclo TDD completo
- Uma task ≤ 1 arquivo de produção + 1 arquivo de teste
- Se task precisa de mais → o spec está muito granular ou pouco granular
- Task de schema não depende de API. API depende de schema. Componente depende de API.

---

## ✅ Validação pós-implementação

Executada via `superpowers:verification-before-completion`:

```bash
bun test                    # testes passam
bun test --coverage         # cobertura ≥ 80%
bun run lint                # lint limpo
bun run typecheck           # types limpos
```

Mais: verificação de que cada cenário do spec tem teste correspondente. Se frontend, visual checklist completo.

Se qualquer check falhar: `superpowers:systematic-debugging` + personal skills da stack.

---

## 🔀 Spec Amendment (mudanças durante implementação)

Se durante a implementação algo exige mudança no spec:

1. **Superpowers/subagente para** e reporta o conflito
2. **Agente principal** gera amendment:
   ```markdown
   ## Amendment #1 — [data]
   **Motivo**: [o que foi encontrado]
   **Mudança**: [o que muda no contrato]
   **Impacto**: [quais tasks são afetadas]
   ```
3. **Usuário aprova** o amendment
4. **Tasks afetadas** são re-executadas com spec atualizado

---

## 📊 Métricas de eficiência

| Métrica | Alvo |
|---|---|
| Specs rejeitados pelo usuário | < 20% |
| Amendments por spec | ≤ 1 |
| Tasks que falharam na validação | < 10% |
| Retrabalho (task refeita) | < 5% |
| Linhas de spec vs linhas de código | ratio ≤ 1:10 |

---

## 🚫 Anti-patterns SDD

- ❌ Escrever código antes do spec existir
- ❌ Spec com mais de 150 linhas (story grande demais — quebrar)
- ❌ Spec com código de produção (apenas types, interfaces, assinaturas)
- ❌ Subagente lendo arquivos fora do escopo da task
- ❌ Modificar spec sem amendment aprovado
- ❌ Pular a fase de verificação
- ❌ Fazer spec para tasks triviais (< 10 linhas, sem contrato novo)
- ❌ Spec que repete o que já está em `claude-stacks.md` — referenciar, não copiar
- ❌ Implementar sem passar pelo Superpowers plan (pular Step 2)
