# claude-sdd.md — Spec Driven Development

> **Este arquivo define o fluxo de Spec Driven Development (SDD).**
> SDD é uma camada de planejamento técnico entre as User Stories e a implementação TDD.
> Gera specs compactas e autocontidas que servem como contrato para subagentes com contexto mínimo.
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
| Refactors cascateiam por falta de contrato | Interfaces congeladas no spec — mudança exige novo spec |
| Alto gasto de tokens por contexto desnecessário | Spec é o contexto mínimo suficiente — subagente não precisa de mais |

---

## 📐 O que é um Spec

Um **spec** é um documento Markdown compacto que descreve **o quê** será implementado e **como** será validado — sem código de produção.

Cada spec contém apenas o necessário para que um subagente implemente com TDD sem precisar ler mais nada além do spec + regras de stack.

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
├── user-stories.md       ← histórias de usuário (já existe)
├── backlog.md            ← backlog XP (já existe)
└── specs/                ← specs SDD (novo)
    ├── US-01-nome.spec.md
    ├── US-02-nome.spec.md
    └── ...
```

Convenção de nome: `US-{número}-{slug-kebab-case}.spec.md`

---

## 🔄 Fluxo SDD → TDD (automático, inline)

O usuário pede para implementar uma story com um único comando (ex: `Implementar a US-03`).
O agente principal decide automaticamente se precisa de spec, gera, apresenta, e segue implementando após aprovação — tudo na mesma conversa.

```
Usuário: "Implementar a US-XX"
  │
  ▼
┌─────────────────────────────────────────┐
│  0. TRIAGE — Precisa de spec?           │  ← Agente principal
│     Avaliar via tabela de decisão       │
│     (novo schema/endpoint/componente?)  │
│     SIM → continuar │  NÃO → TDD direto│
└──────────┬──────────────────────────────┘
           │ SIM
           ▼
┌─────────────────────────────────────────┐
│  1. SPEC — Gerar spec automaticamente   │  ← Agente principal
│     Salvar em docs/specs/US-XX.spec.md  │
│     Apresentar ao usuário inline        │
│     ⏸️  AGUARDAR APROVAÇÃO              │
└──────────┬──────────────────────────────┘
           │ Aprovado
           ▼
┌─────────────────────────────────────────┐
│  2. DECOMPOSE — Quebrar em tasks        │  ← Agente principal
│     Ordem: schema → api → componente    │
│     Cada task = 1 subagente             │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  3. IMPLEMENT — Subagentes executam     │  ← Subagentes (contexto mínimo)
│     Cada um recebe: spec section +      │
│     regras de stack aplicáveis          │
│     Cada um executa: Red→Green→Refactor │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  4. VALIDATE — Verificação global       │  ← Agente principal
│     spec✓ testes✓ lint✓ typecheck✓      │
│     Commit + atualizar backlog          │
└─────────────────────────────────────────┘
```

### Tabela de decisão (step 0 — TRIAGE)

O agente principal avalia automaticamente:

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

> Na dúvida, **gerar spec**. O custo de um spec desnecessário (~2 min) é menor que o retrabalho por falta de contrato.

### Regras do fluxo

1. **A decisão spec vs TDD direto é automática** — o agente principal avalia sem perguntar ao usuário.
2. **Se spec é necessário, o agente gera e apresenta antes de escrever qualquer código.**
3. **O único ponto de pausa é a aprovação do spec** — o agente pergunta "Spec gerado. Aprovo para implementar?" e só continua após OK.
4. **Se o usuário pedir ajustes no spec**, o agente ajusta e re-apresenta. Não implementa com spec não aprovado.
5. **Spec é imutável durante a implementação.** Se algo precisa mudar, gerar amendment e aprovar.
6. **Cada task de subagente mapeia para exatamente uma seção do spec** (um endpoint, um schema, um componente).
7. **Subagente não lê código fora do que está listado em "Dependências" do spec.**
8. **Validação é feita pelo agente principal**, não pelo subagente.

### Como o agente apresenta o spec para aprovação

Após gerar o spec, o agente principal deve:

1. Salvar o arquivo em `docs/specs/US-XX-nome.spec.md`
2. Exibir o spec completo no terminal
3. Perguntar explicitamente:

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

4. **Só prosseguir após "sim" explícito.** Qualquer outro input = ajustar e re-apresentar.

---

## 📝 Como o agente gera um Spec (automático)

### Input (coletado automaticamente pelo agente)

1. A User Story com critérios de aceite (de `docs/user-stories.md`)
2. O estado atual dos schemas em `packages/shared/src/schemas/` (leitura dos arquivos existentes)
3. Os endpoints existentes em `apps/api/src/routes/` (leitura dos arquivos existentes)
4. Componentes existentes em `apps/web/src/` (se a story envolve frontend)

> O agente coleta esses inputs silenciosamente — não pergunta ao usuário. Se algum arquivo não existir (projeto novo), o agente prossegue com o que tem.

### Processo de geração

1. **Ler** a User Story e seus critérios de aceite
2. **Analisar** o estado atual do código (schemas, rotas, componentes existentes)
3. **Derivar contratos**: types → API → componentes (nessa ordem, respeitando dependências)
4. **Derivar cenários de teste** dos critérios de aceite (cada critério gera ≥1 cenário)
5. **Listar dependências** — paths exatos de arquivos que serão lidos ou modificados
6. **Gerar checklist de conclusão** — cada item verificável por `bun test`, `bun run lint`, `bun run typecheck` ou inspeção visual
7. **Salvar** em `docs/specs/US-XX-nome.spec.md`
8. **Apresentar** ao usuário e aguardar aprovação

### Regras de qualidade do spec

- **Compacto**: um spec não deve ultrapassar 150 linhas. Se ultrapassar, a story é grande demais — quebre-a.
- **Sem código de produção**: specs contêm apenas types, interfaces e assinaturas. Nunca implementação.
- **Sem ambiguidade**: cada campo de contrato tem tipo explícito. Cada cenário de teste tem resultado esperado concreto.
- **Autocontido**: um subagente deve conseguir implementar lendo apenas o spec + `claude-stacks.md`. Se precisar de mais contexto, o spec está incompleto.

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
1. DADO body válido, QUANDO POST /recursos, ENTÃO 201 + recurso criado no banco
2. DADO body sem campo obrigatório, QUANDO POST /recursos, ENTÃO 400 + VALIDATION_ERROR
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
1. DADO form renderizado, QUANDO preencher campos válidos e submeter, ENTÃO mutation é chamada com dados corretos
2. DADO form renderizado, QUANDO submeter vazio, ENTÃO erros Zod aparecem nos campos
3. DADO mutation com erro 400, QUANDO resposta chegar, ENTÃO toast exibe mensagem do backend
```

---

## 🏗️ Decomposição em Tasks para Subagentes

Após o spec aprovado, o agente principal decompõe em tasks. Cada task gera um bloco de contexto para o subagente.

### Ordem obrigatória de decomposição

1. **Schema/Types** (packages/shared) — sempre primeiro
2. **API Endpoints** (apps/api) — depende dos schemas
3. **Componentes** (apps/web) — depende da API estar implementada e testável

### Formato de task para subagente

Cada task é descrita como um bloco que o agente principal monta ao invocar o subagente:

```
TASK: [identificador]
SPEC_SECTION: [seção relevante do spec — copiar literalmente]
FILES_TO_READ: [paths de dependências do spec]
FILES_TO_CREATE_OR_MODIFY: [paths de output]
STACK_RULES: [regras relevantes do claude-stacks.md — copiar as aplicáveis]
TDD_FLOW: Red → Green → Refactor (sem exceção)
```

### Regras de task

- **Uma task = um ciclo TDD completo** (Red → Green → Refactor)
- **Uma task ≤ 1 arquivo de produção + 1 arquivo de teste** — se precisar de mais, quebrar
- Task de schema não depende de task de API. Task de API depende de schema. Task de componente depende de API.
- O subagente **nunca** modifica arquivos fora do escopo da task.

---

## ✅ Validação pós-implementação

Após todos os subagentes completarem suas tasks, o agente principal executa:

```bash
# 1. Testes passam
bun test

# 2. Cobertura ≥ 80%
bun test --coverage

# 3. Lint limpo
bun run lint

# 4. Types limpos
bun run typecheck

# 5. Cenários do spec cobertos
# (verificação manual: cada cenário do spec tem teste correspondente)
```

Se qualquer check falhar, o agente principal identifica o problema e delega correção ao subagente responsável — passando apenas o erro e o spec section, não o codebase inteiro.

---

## 🔀 Spec Amendment (mudanças durante implementação)

Se durante a implementação o subagente encontrar algo que exige mudança no spec:

1. **Subagente para** e reporta o conflito ao agente principal
2. **Agente principal** gera um `amendment` no spec:
   ```markdown
   ## Amendment #1 — [data]
   **Motivo**: [o que foi encontrado]
   **Mudança**: [o que muda no contrato]
   **Impacto**: [quais tasks são afetadas]
   ```
3. **Usuário aprova** o amendment (ou rejeita)
4. **Tasks afetadas** são re-executadas com o spec atualizado

---

## 📊 Métricas de eficiência

Para avaliar se o SDD está funcionando, rastrear:

| Métrica | Alvo |
|---|---|
| Specs rejeitados pelo usuário | < 20% |
| Amendments por spec | ≤ 1 |
| Tasks de subagente que falharam na validação | < 10% |
| Retrabalho (task refeita) | < 5% |
| Linhas de spec vs linhas de código | ratio ≤ 1:10 |

---

## 🚫 Anti-patterns SDD

- ❌ Escrever código antes do spec existir
- ❌ Spec com mais de 150 linhas (story grande demais — quebrar)
- ❌ Spec com código de produção (apenas types, interfaces, assinaturas)
- ❌ Subagente lendo arquivos fora do escopo da task
- ❌ Modificar spec sem amendment aprovado
- ❌ Pular a fase de validação pelo agente principal
- ❌ Fazer spec para tasks triviais (< 10 linhas de código, sem contrato novo)
- ❌ Spec que repete o que já está em `claude-stacks.md` — referenciar, não copiar
