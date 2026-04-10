# claude-subagents.md — Orquestração de Subagentes

> **Este arquivo define como o agente principal delega trabalho a subagentes no Claude Code.**
> Subagentes são invocados via `Task` tool do Claude Code. Cada subagente recebe contexto mínimo
> derivado do spec, executa uma task isolada com TDD e retorna o resultado.
>
> **Pré-requisito**: o spec da feature deve existir em `docs/specs/` e estar aprovado pelo usuário.
> Sem spec, não há delegação. Ver `claude-sdd.md` para o fluxo completo.

---

## 🧠 Princípio: Contexto Mínimo Suficiente

O maior gasto de tokens no Claude Code vem de:
1. Ler arquivos desnecessários para entender o contexto
2. Re-ler os mesmos arquivos em cada iteração
3. Subagente "explorando" o codebase para descobrir o que fazer

**SDD resolve isso**: o spec já contém tudo que o subagente precisa saber. O agente principal monta o prompt do subagente com:

- **O quê fazer** → seção do spec (copiada literalmente)
- **Onde fazer** → paths exatos (FILES_TO_CREATE, FILES_TO_READ)
- **Como fazer** → regras de stack aplicáveis (só as relevantes, não o arquivo inteiro)
- **Como validar** → cenários de teste do spec
- **Como parecer** → design brief + page override (apenas para component-agent)

O subagente **nunca** precisa ler `CLAUDE.md`, `claude-stacks.md` ou `claude-stacks-refactor.md` inteiros. O agente principal extrai e injeta apenas as regras aplicáveis.

---

## 🏷️ Tipos de Subagente

### 1. `schema-agent` — Schema & Types

**Escopo**: criar/modificar schemas Drizzle + Zod em `packages/shared`

**Contexto injetado**:
- Seção "Contratos — Schema" do spec
- Regras: Drizzle config, Zod v4, barrel exports, naming conventions
- Arquivo atual de `packages/shared/src/schemas/` (se existir)
- `packages/shared/src/index.ts` (para adicionar re-export)

**Output esperado**:
- Arquivo de schema criado/modificado
- Arquivo de teste `*.test.ts` com cenários do spec
- `index.ts` atualizado com re-export
- Migration gerada (`bun run db:generate`)

**Validação**: `bun test [arquivo]` + `bun run typecheck` + `bun run db:generate` sem diff

---

### 2. `api-agent` — API Endpoints

**Escopo**: criar/modificar rotas Hono em `apps/api`

**Contexto injetado**:
- Seção "Contratos — API" do spec
- Schemas Zod importáveis (output do schema-agent — nomes e paths)
- Regras: response format `{ data }`, error handling, sValidator, auth middleware
- Rotas existentes (se integrar com endpoint existente)

**Output esperado**:
- Arquivo de rota criado/modificado
- Arquivo de teste `*.test.ts` com cenários do spec
- Rota registrada no app principal (`index.ts`)
- AppType atualizado (se nova rota)

**Validação**: `bun test [arquivo]` + `bun run lint` + `bun run typecheck` + `curl` nos endpoints

---

### 3. `component-agent` — React Components

**Escopo**: criar/modificar componentes React em `apps/web`

**Contexto injetado**:
- Seção "Contratos — Componente" do spec
- Types importáveis (output do schema-agent — nomes e paths)
- API contract (endpoints que o componente consome — do spec, não da implementação)
- Regras de stack: TanStack Query, React Hook Form, shadcn/ui, UI states, Sonner
- **Design brief** (`docs/design-system/design-brief.md`) — resumo visual compacto (~800 tokens)
- **Page override** (`docs/design-system/pages/*.md`) — se a página tiver override

**Output esperado**:
- Arquivo de componente criado/modificado com tokens visuais do design brief aplicados
- Arquivo de teste `*.test.tsx` com cenários do spec
- Integração na árvore de rotas (se for page component)

**Validação**: `bun test [arquivo]` + `bun run lint` + `bun run typecheck` + visual checklist

---

### 4. `fix-agent` — Correção de falhas

**Escopo**: corrigir uma falha específica identificada na validação

**Protocolo**: segue `claude-debug.md` — Fases 1-5 obrigatórias (reproduzir → isolar → diagnosticar → formular → corrigir). Nunca aplica fix sem diagnóstico completo.

**Contexto injetado**:
- Mensagem de erro exata + stack trace (output do test/lint/typecheck)
- Contexto de reprodução (comando ou ação que causou o erro)
- Seção do spec que a task deveria implementar
- Arquivo(s) com o problema (paths exatos)
- Regra de stack violada (se aplicável)
- Tentativas anteriores de fix (se houver — para não repetir)

**Output esperado**:
- Diagnóstico com causa raiz em uma frase
- Correção no(s) arquivo(s) identificado(s)
- Testes passando + regressão verificada

**Validação**: re-executar o check que falhou + `bun test` completo

**Escalação**: se não resolver após 3 tentativas, retorna diagnóstico parcial ao agente principal (não continua tentando)

---

## 📋 Prompt Templates para Subagentes

### Template base (comum a todos)

```
Você é um subagente de implementação. Siga estas regras:

1. ESCOPO: implemente APENAS o que está descrito abaixo. Não leia nem modifique outros arquivos.
2. TDD: escreva o teste PRIMEIRO (Red), depois o código mínimo (Green), depois refatore (Refactor).
3. TESTES: use `bun test`. Nomenclatura: `*.test.ts`. Um assert por teste quando possível.
4. LINT: o código deve passar em `bunx biome check .`.
5. TYPES: o código deve passar em `bun run typecheck` (strict: true).

---
TASK: {task_id}
STORY: {story_id} — {story_title}

{spec_section}

FILES_TO_READ:
{lista de paths}

FILES_TO_CREATE_OR_MODIFY:
{lista de paths}

STACK_RULES:
{regras extraídas do claude-stacks.md, apenas as aplicáveis}

TEST_SCENARIOS:
{cenários do spec}

DONE_WHEN:
- [ ] Todos os testes passam
- [ ] `bun run lint` sem erros
- [ ] `bun run typecheck` sem erros
- [ ] Apenas os arquivos listados foram modificados
```

### Template: schema-agent

```
STACK_RULES:
- Schemas vivem em packages/shared/src/schemas/ — kebab-case.ts
- Exportar via barrel file: packages/shared/src/index.ts
- Todo schema tem createdAt e updatedAt com defaults
- IDs: uuid com defaultRandom() (padrão do projeto)
- Zod schemas via drizzle-zod: createInsertSchema, createSelectSchema
- Tipos: z.input<typeof insertSchema> para forms, z.infer<typeof selectSchema> para reads
- Rodar `bun run db:generate` após criar o schema
- Testar: validação Zod (campos obrigatórios, tipos, defaults)
```

### Template: api-agent

```
STACK_RULES:
- Framework: Hono. Validação: sValidator de @hono/standard-validator
- Response sucesso: c.json({ data: ... })
- Response lista: c.json({ data: [...], pagination: { page, limit, total, totalPages } })
- Response erro: c.json({ error, code, details }, status)
- Auth: getAuth(c) — síncrono. userId = auth?.userId ?? "dev-user"
- Importar schemas de @projeto/shared
- Importar db de ../db (nunca criar nova instância)
- Arquivo de rota: apps/api/src/routes/kebab-case.ts
- Registrar rota no apps/api/src/index.ts
- Exportar tipo da rota para AppType
- Testar: happy path, validação, auth, edge cases
```

### Template: component-agent

```
STACK_RULES:
- React 19 + TypeScript strict
- Data fetching: TanStack Query + Hono RPC client tipado
- Forms: React Hook Form + standardSchemaResolver (Zod v4)
- UI: shadcn/ui + Tailwind CSS v4 classes. Nunca CSS inline
- States obrigatórios: loading (Skeleton), empty (ícone+mensagem+CTA), error (Alert+retry), success
- Toasts: Sonner (nunca alert())
- Estado: TanStack Query para server state, Zustand para client state
- Um componente por arquivo, PascalCase.tsx
- Container components gerenciam data fetching; presentational recebem props
- Testar: renderização, interações, estados de loading/error/empty

DESIGN_RULES:
{conteúdo de docs/design-system/design-brief.md — colado literalmente pelo agente principal}

PAGE_OVERRIDE:
{conteúdo de docs/design-system/pages/<nome>.md se existir, senão "Sem override. Seguir o brief."}

VISUAL_CHECKLIST:
- [ ] Cores usam tokens do design brief (sem hex hardcoded, sem cores default do shadcn)
- [ ] Tipografia segue escala do brief (font family, weight, size por elemento)
- [ ] Border-radius conforme brief (não usar defaults do shadcn)
- [ ] Density e spacing conforme brief (padding, gap entre elementos)
- [ ] Animações de entrada aplicadas conforme brief (ex: animate-fade-slide-up)
- [ ] 4 estados implementados: loading (Skeleton), empty (icon+msg+CTA), error (Alert+retry), success
- [ ] Responsivo: mobile stack → desktop grid (mínimo 2 breakpoints)
- [ ] Hover e focus states com transição (transition-colors duration-150)
```

### Template: fix-agent

```
PROTOCOLO: Seguir claude-debug.md — Fases 1-5. Sem atalhos.

ERRO ENCONTRADO:
{mensagem de erro exata — copiar literalmente, não resumir}

STACK TRACE (se houver):
{stack trace completo}

CONTEXTO DE REPRODUÇÃO:
{como o erro foi produzido: comando, ação do usuário, teste que falhou}

ARQUIVO COM PROBLEMA:
{path — baseado na stack trace ou no bisect do agente principal}

SPEC SECTION:
{seção do spec que define o comportamento esperado}

REGRA VIOLADA:
{regra do claude-stacks.md que se aplica, se houver}

TENTATIVAS ANTERIORES (se houver):
{lista de fixes já tentados e por que falharam — para não repetir}

INSTRUÇÕES:
1. REPRODUZIR: confirmar o erro executando o teste ou comando indicado
2. ISOLAR: ler o arquivo na linha do erro, rastrear a cadeia de execução
3. DIAGNOSTICAR: identificar causa raiz em uma frase
4. FORMULAR: propor fix com máximo 3 ações + teste de validação
5. CORRIGIR: aplicar fix + verificar regressão (bun test completo)

Se não conseguir completar a Fase 3 (diagnosticar), PARAR e retornar:
- O que sabe até agora
- O que não sabe
- Sugestão de próximo passo de investigação
NÃO aplicar fix sem diagnóstico completo.
```

---

## 🔀 Fluxo de Orquestração do Agente Principal

### Fase 1: Preparação (agente principal)

```
1. Ler spec de docs/specs/US-XX.spec.md
2. Verificar que o spec está aprovado
3. Decompor em tasks na ordem: schema → api → component
4. Para cada task, montar o prompt com:
   a. Seção do spec (copiar literalmente)
   b. Paths de input/output
   c. Regras de stack aplicáveis (extrair, não copiar o arquivo inteiro)
   d. Cenários de teste
   e. (component-agent) Design brief + page override
```

### Fase 2: Execução (subagentes)

```
Para cada task, na ordem de dependência:

1. Invocar subagente com o prompt montado
2. Aguardar conclusão
3. Executar validação:
   - bun test [arquivo do teste]
   - bun run lint
   - bun run typecheck
   - (component-agent) Verificar visual checklist
4. Se falhou:
   - Se é problema no código do subagente → invocar fix-agent
   - Se é problema no spec → parar e gerar amendment
   - Máximo 3 tentativas por task
5. Se passou:
   - Marcar task como concluída
   - Prosseguir para a próxima task
```

### Fase 3: Integração (agente principal)

```
Após todas as tasks concluídas:

1. Executar suite completa: bun test
2. Verificar cobertura: bun test --coverage (≥ 80%)
3. Lint global: bun run lint
4. Typecheck global: bun run typecheck
5. Se tudo verde:
   - Commit com mensagem Conventional Commits
   - Atualizar backlog.md (marcar tasks como done)
6. Se algo falhou:
   - Identificar task responsável
   - Invocar fix-agent com contexto mínimo
   - Repetir validação
```

---

## 💡 Otimizações de Token

### O que o agente principal NÃO envia para subagentes

- ❌ `CLAUDE.md` inteiro — subagente não precisa da metodologia, apenas das regras técnicas
- ❌ `claude-stacks.md` inteiro — apenas regras da camada relevante (API, frontend, shared)
- ❌ `claude-stacks-refactor.md` inteiro — apenas seções aplicáveis
- ❌ `claude-design.md` inteiro — agente principal extrai regras estruturais aplicáveis
- ❌ `docs/design-system/MASTER.md` inteiro — subagente recebe o `design-brief.md` (resumo compacto)
- ❌ Código de outros módulos/features — apenas dependências listadas no spec
- ❌ Histórico de conversa anterior — cada subagente é stateless

### O que o agente principal SEMPRE envia

- ✅ Seção exata do spec (copiada, não referenciada)
- ✅ Paths de arquivos (input e output)
- ✅ Regras de stack aplicáveis (extraídas e coladas)
- ✅ Cenários de teste do spec
- ✅ Checklist de conclusão
- ✅ **Design brief** (`docs/design-system/design-brief.md`) — apenas para `component-agent`
- ✅ **Page override** (`docs/design-system/pages/*.md`) — quando existir, apenas para `component-agent`

### Budget de contexto por tipo de subagente

> Cada tipo de subagente tem um budget proporcional à complexidade do contexto que precisa.
> O component-agent tem budget maior porque inclui contexto visual (design brief + page override)
> que os outros tipos não precisam.

| Subagente | Budget máx | Composição |
|---|---|---|
| `schema-agent` | ≤ 1500 tokens | spec (~600) + paths (~100) + stack rules (~400) + cenários (~400) |
| `api-agent` | ≤ 1500 tokens | spec (~600) + paths (~100) + stack rules (~400) + cenários (~400) |
| `component-agent` | ≤ 3500 tokens | spec (~600) + paths (~100) + stack rules (~500) + design brief (~800) + page override (~300) + cenários (~400) + visual checklist (~200) |
| `fix-agent` | ≤ 1500 tokens | erro (~300) + stack trace (~200) + arquivo (~300) + spec section (~300) + tentativas anteriores (~200) + regra (~200) |

> Se o prompt ultrapassar o budget do tipo, **revisar e reduzir**.
> Para `component-agent`: **nunca cortar a seção DESIGN_RULES para caber** — cortar stack rules genéricas primeiro.
> O design é o que diferencia UI profissional de UI genérica.

---

## 📊 Tabela de decisão: delegar ou fazer direto?

| Situação | Decisão |
|---|---|
| Task com contrato claro no spec + ≥1 teste | **Delegar** para subagente |
| Fix trivial (1-3 linhas, causa óbvia) | **Fazer direto** — overhead de delegar é maior |
| Refactor que afeta múltiplos arquivos | **Fazer direto** — subagente tem escopo limitado |
| Configuração (Docker, CI, biome) | **Fazer direto** — sem spec necessário |
| Story inteira sem spec | **Parar** — gerar spec primeiro |
| Exploração/protótipo (spike) | **Fazer direto** — spec vem depois |

---

## 🚫 Proibições

- ❌ Subagente nunca executa `git commit` ou `git push` — apenas o agente principal
- ❌ Subagente nunca modifica specs, backlog ou user stories
- ❌ Subagente nunca instala dependências (`bun add`) — apenas o agente principal
- ❌ Subagente nunca modifica `CLAUDE.md`, `claude-stacks.md` ou `claude-stacks-refactor.md`
- ❌ Subagente nunca lê mais arquivos do que os listados na task
- ❌ Agente principal nunca delega sem spec aprovado
- ❌ Nunca mais que 3 retries no mesmo subagente — escalar para o agente principal
- ❌ Nunca cortar design brief do prompt do component-agent para economizar tokens — cortar stack rules genéricas primeiro
