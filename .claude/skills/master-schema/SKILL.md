---
name: master-schema
description: Cria ou altera schema Drizzle em packages/shared, gera schemas Zod via drizzle-zod, gera migration SQL e valida nullability/imports antes de aplicar. Usar quando o usuário disser "criar tabela", "adicionar coluna", "alterar schema", "nova entidade", "gerar migration" ou pedir mudança de modelo de dados.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

Esta skill formaliza a regra 24 do `CLAUDE.md` (schemas compartilhados em `packages/shared`, drizzle-zod stable como padrão) e a regra 16 (nullable explícito). O objetivo é evitar os erros mais comuns em mudanças de schema: import faltando, nullable implícito que vaza no frontend, migration aplicada sem revisão, Zod schema desatualizado.

Toda comunicação em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de qualquer pergunta:

1. Ler `CLAUDE.md` regras 1, 16, 24, 26 (Drizzle/Zod/nullable)
2. Ler `docs/version-matrix.md` — confirmar Drizzle stable (≥0.45.2) ou beta, e versão correspondente de `drizzle-zod`
3. Ler `packages/shared/src/schema/` — listar schemas existentes para entender convenções (naming, exports do barrel file). Padrão do template é `schema/` singular
4. Ler `drizzle.config.ts` — confirmar paths (`schema`, `out`, dialect) **e validar uso de `defineConfig` de `drizzle-kit`** (regra 26 do CLAUDE.md). Se o arquivo usa `export default { ... }` solto, sinalizar e propor migração para `defineConfig({ ... })` antes de seguir
5. Ler `packages/shared/package.json` para descobrir o **nome real do workspace** (`name` field) — evitar hardcode de `@projeto/shared` (cada projeto derivado tem outro nome)
6. `git status` — confirmar working tree limpo (mudança de schema sem outras alterações pendentes)

Se o repo não tem `packages/shared/` ou `drizzle.config.ts`, parar e avisar:
> "Não achei a estrutura de schema esperada (`packages/shared/src/schema/` + `drizzle.config.ts`). Esta skill assume o template padrão do CLAUDE.md. Quer que eu inicialize via `START_PROJECT.md`?"

---

## Passo 1 — Entender a mudança

Confirmar com o usuário:

> "Vou trabalhar no schema. Antes de mexer:
>
> 1. **Tipo de mudança**: tabela nova / nova coluna / alterar coluna / índice / FK / drop?
> 2. **Entidade**: qual nome (singular/plural conforme convenção do projeto)?
> 3. **Campos**: descreva — nome, tipo, nullable?, default?, FK?
> 4. **Constraints**: unique? check? índice composto?
>
> Se for alteração, eu mostro o estado atual primeiro."

Se for alteração de schema existente, mostrar o `pgTable` atual antes de propor o diff.

---

## Passo 2 — Editar o schema

### 2.1 — Localizar/criar arquivo

Convenção: `packages/shared/src/schema/<entidade>.ts` (singular — padrão do template).

### 2.2 — Definir/alterar `pgTable`

Aplicar regra 16 (nullable explícito):

- Coluna sem `.notNull()` produz `T | null` no TypeScript — sinalizar isso na proposta
- Default explícito quando aplicável (`.default(...)`, `.defaultNow()`, `.defaultRandom()`)
- FK com `references(() => outraTabela.id, { onDelete: 'cascade' | 'set null' | 'restrict' })`
- Índice via `(table) => ({ ... })` no segundo argumento de `pgTable`

Exemplo cirúrgico (nova tabela):

```typescript
// packages/shared/src/schema/orders.ts
import { integer, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';
import { users } from './users';

export const orders = pgTable('orders', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  total: integer('total_cents').notNull(),
  status: text('status', { enum: ['pending', 'paid', 'cancelled'] }).notNull().default('pending'),
  notes: text('notes'),                                  // ← nullable: T | null
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

export type Order = typeof orders.$inferSelect;
export type NewOrder = typeof orders.$inferInsert;
```

**Conferir imports**: cada tipo usado (`integer`, `pgTable`, `text`, etc.) precisa estar no `import` de `drizzle-orm/pg-core`. Erro comum (capturado na auditoria do template): usar `integer` sem importar.

### 2.3 — Atualizar barrel file

`packages/shared/src/index.ts` (ou similar): re-exportar a nova tabela e tipos.

```typescript
export * from './schema/orders';
```

Sem isso, `apps/api` e `apps/web` não enxergam o novo schema.

---

## Passo 3 — Gerar Zod schemas

Conforme regra 24 e `docs/version-matrix.md`:

- **Drizzle stable (≥0.45.2)**: importar de `drizzle-zod`
- **Drizzle beta (≥1.0.0-beta.20)**: importar de `drizzle-orm/zod`

> ⚠️ **Nunca usar `drizzle-orm/zod` sem confirmação explícita do usuário** (regra 24). O padrão do template é Drizzle stable (≥0.45.2) com `drizzle-zod`. Beta apenas com aprovação.

Stable (padrão do template):

```typescript
// packages/shared/src/schema/orders.ts (continuação)
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';

export const orderSelectSchema = createSelectSchema(orders);
export const orderInsertSchema = createInsertSchema(orders, {
  // overrides quando precisar de validação extra:
  // total: (schema) => schema.min(1, 'total deve ser positivo'),
});
```

Para uso em formulários com React Hook Form, lembrar regra 24: `useForm<z.input<typeof orderInsertSchema>>()` (não `z.infer`).

---

## Passo 4 — Gerar migration

```bash
docker compose exec api bun run db:generate
```

Inspecionar o SQL gerado em `apps/api/src/db/migrations/` (ou onde estiver configurado em `drizzle.config.ts`):

> "Migration gerada em `[caminho]/[NNNN]_[nome].sql`. Vou mostrar o SQL antes de aplicar:
>
> ```sql
> [conteúdo do SQL]
> ```
>
> Posso aplicar com `bun run db:migrate`?"

**Nunca rodar `db:migrate` sem mostrar o SQL primeiro.** Mudanças destrutivas (`DROP COLUMN`, `ALTER COLUMN ... NOT NULL` em tabela com dados) precisam de aprovação explícita.

### Casos que exigem data migration separada (não só schema)

- Adicionar `NOT NULL` a coluna existente com nulls — backfill antes (ver `docs/data-migrations.md`)
- Mudar tipo de coluna com transformação (text → enum) — backfill antes
- Renomear coluna mantendo dados — Drizzle Kit pode pedir confirmação interativa; alertar

Se o caso pede data migration:

> "Esta mudança exige backfill antes de aplicar `NOT NULL`. Vou criar a data migration em `apps/api/src/data-migrations/[YYYYMMDD]-[descrição].ts` seguindo `docs/data-migrations.md`. Posso?"

---

## Passo 5 — Aplicar migration

Com aprovação do usuário:

```bash
docker compose exec api bun run db:migrate
```

Conferir que não há diff residual:

```bash
docker compose exec api bunx drizzle-kit check
# deve confirmar que todas as migrations estão em sincronia com o schema
```

Se houver diff residual, investigar — geralmente formatação ou order de colunas.

---

## Passo 6 — Validar end-to-end

```bash
docker compose exec api bun run typecheck     # confirma que tipos propagaram
docker compose exec api bunx biome check .    # confirma estilo
docker compose exec api bun test              # nada quebrou
```

Verificações específicas:

- Frontend trata nullable? (regra 16 — `order.notes ?? ''` ou `order.notes || 'Sem notas'`)
- API valida com Zod schema gerado? (rotas usando `sValidator` apontam para `orderInsertSchema`)
- Barrel file re-exporta? Usar o nome real do workspace lido em Passo 0.5 — ex: `grep -r "from '$(jq -r .name packages/shared/package.json)'" apps/api/src/` deve achar

---

## Passo 7 — Commit (opcional, se usuário pedir)

Conventional Commits, escopo `db` ou `schema`:

```bash
git add packages/shared/src/schema/orders.ts packages/shared/src/index.ts apps/api/src/db/migrations/
git commit -m "feat(db): add orders schema with status enum and FK to users"
```

Não chamar `db:migrate` em prod via skill — isso é responsabilidade do pre-deploy command (Railway) ou entrypoint (Portainer). Ver `docs/data-migrations.md` e `docs/deploy-*.md`.

---

## Notas para o assistente

### Nunca

- Rodar `db:migrate` sem mostrar o SQL primeiro
- Usar `db:push` em prod (só dev, e nem sempre — ver `docs/version-matrix.md` regra 26)
- Esquecer de re-exportar no barrel file (`packages/shared/src/index.ts`)
- Inferir nullability — sempre confirmar com o usuário se a coluna deve ser `NOT NULL`
- Usar `sql.raw()` com input externo (regra 11)

### Cuidados em alterações destrutivas

- `DROP COLUMN`: confirmar que ninguém mais lê (grep no monorepo). Coluna pode ter dados em prod
- `ALTER COLUMN ... NOT NULL`: validar que não há nulls em prod (`SELECT COUNT(*) WHERE coluna IS NULL`)
- `RENAME`: Drizzle Kit pergunta se é rename ou drop+add. Sempre rename para preservar dados

### Multi-tenancy / soft delete

Se o projeto usa soft delete (`deletedAt: timestamp('deleted_at')`), aplicar consistente em toda nova tabela. Idem para `orgId`/`tenantId` se houver multi-tenancy.

### Idioma

Toda comunicação em **português do Brasil**. Anunciar o que está fazendo em frase curta antes de cada Passo.
