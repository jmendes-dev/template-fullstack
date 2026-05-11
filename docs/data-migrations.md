# Data migrations

Ler ao fazer backfill de dados, seed inicial, ou transformação em massa (normalizar coluna, preencher campo novo). Linha-resumo vive em `CLAUDE.md` seção "Data migrations".

Princípio: **schema migrations** (Drizzle Kit, mudam estrutura) são distintas de **data migrations** (script TS, mudam conteúdo). Nunca misturar na mesma pasta.

## Quando cada uma

| Caso | Tipo | Ferramenta |
|---|---|---|
| Adicionar coluna | Schema migration | Drizzle Kit (`bun run db:generate`) |
| Alterar constraint | Schema migration | Drizzle Kit |
| Criar índice | Schema migration | Drizzle Kit |
| Backfill de coluna nova | Data migration | Script TS |
| Normalizar emails para lowercase | Data migration | Script TS |
| Seed de dados iniciais (roles, admin) | Data migration | Script TS (ou `drizzle-seed` para dev) |
| Migrar formato de JSON em coluna | Data migration | Script TS |

Regra prática: se mexe em DDL (`CREATE`/`ALTER`/`DROP`), é schema. Se mexe em DML (`INSERT`/`UPDATE`/`DELETE` em massa), é data.

---

## Estrutura no monorepo

```
apps/api/
├── src/
│   ├── db/
│   │   ├── schema.ts              # Drizzle schema
│   │   └── migrations/            # ← Drizzle Kit (schema migrations)
│   │       └── 0001_initial.sql
│   └── data-migrations/           # ← scripts TS (data migrations)
│       ├── 20260419-backfill-user-locale.ts
│       ├── 20260420-seed-roles.ts
│       └── _runner.ts
├── drizzle.config.ts
└── package.json
```

`data-migrations/` vive dentro de `apps/api/src` porque tem acesso ao Drizzle client.

---

## Tabela de controle

Data migrations são **idempotentes por design** (rodar 2x = mesmo resultado), mas ainda assim vale registrar execução para auditoria e para pular migrations já feitas em re-deploys.

```typescript
// packages/shared/src/schema/data-migrations-log.ts
import { integer, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

export const dataMigrationsLog = pgTable('data_migrations_log', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull().unique(),
  ranAt: timestamp('ran_at').notNull().defaultNow(),
  durationMs: integer('duration_ms').notNull(),
  notes: text('notes'),
});
```

Gerar a migration com `bun run db:generate` — é schema, não data.

---

## Padrão de um script de data migration

Arquivo: `apps/api/src/data-migrations/YYYYMMDD-descricao-curta.ts`

```typescript
import { db } from '@/db';
import { users, dataMigrationsLog } from '@projeto/shared';
import { eq, inArray, isNull } from 'drizzle-orm';

export const name = '20260419-backfill-user-locale';

export async function run(logger: Logger) {
  const start = performance.now();

  // 1. Idempotência: já rodou? Retorna.
  const existing = await db
    .select()
    .from(dataMigrationsLog)
    .where(eq(dataMigrationsLog.name, name))
    .limit(1);

  if (existing.length > 0) {
    logger.info({ name }, 'data migration já executada, pulando');
    return;
  }

  // 2. Trabalho em batches (nunca UPDATE massivo sem LIMIT)
  const batchSize = 500;
  let totalUpdated = 0;

  while (true) {
    const batch = await db
      .select({ id: users.id })
      .from(users)
      .where(isNull(users.locale))
      .limit(batchSize);

    if (batch.length === 0) break;

    await db
      .update(users)
      .set({ locale: 'pt-BR' })
      .where(
        inArray(
          users.id,
          batch.map((u) => u.id)
        )
      );

    totalUpdated += batch.length;
    logger.info({ totalUpdated }, 'batch processado');
  }

  // 3. Registrar execução
  const durationMs = Math.round(performance.now() - start);
  await db.insert(dataMigrationsLog).values({
    name,
    durationMs,
    notes: `updated=${totalUpdated}`,
  });

  logger.info({ name, totalUpdated, durationMs }, 'data migration concluída');
}
```

## Runner

`apps/api/src/data-migrations/_runner.ts`:

```typescript
import pino from 'pino';
import { readdir } from 'node:fs/promises';
import path from 'node:path';

const logger = pino({ name: 'data-migrations' });

async function main() {
  const dir = __dirname;
  const files = (await readdir(dir))
    .filter((f) => f.endsWith('.ts') && !f.startsWith('_'))
    .sort(); // ordem lexicográfica = ordem cronológica (YYYYMMDD prefix)

  for (const file of files) {
    const modulePath = path.join(dir, file);
    const mod = await import(modulePath);
    if (typeof mod.run !== 'function') {
      logger.warn({ file }, 'sem export run(), pulando');
      continue;
    }
    logger.info({ file }, 'executando');
    await mod.run(logger.child({ migration: mod.name }));
  }

  logger.info('todas as data migrations finalizadas');
  process.exit(0);
}

main().catch((err) => {
  logger.error({ err }, 'data migration falhou');
  process.exit(1);
});
```

Adicionar em `apps/api/package.json`:

```json
{
  "scripts": {
    "data-migrate": "bun src/data-migrations/_runner.ts"
  }
}
```

---

## Execução

### Em dev

```bash
docker compose exec api bun run data-migrate
```

### Em prod

**Antes do deploy** que depende da migration (não depois — porque o novo código pode assumir dados já migrados):

#### Railway

Pre-deploy command no `railway.toml`:

```toml
[deploy]
preDeployCommand = "bun run db:migrate && bun run data-migrate"
```

Schema migration primeiro, data migration depois.

#### Portainer

Entrypoint do container `api`:

```sh
#!/bin/sh
set -e
bun run db:migrate
bun run data-migrate
exec bun run start
```

Ou service separado `migrate` que roda uma vez antes de o `api` subir.

---

## Boas práticas

### Idempotência obrigatória

Script precisa poder rodar 2x sem quebrar nada:

- Checar `dataMigrationsLog` no topo
- Usar `WHERE` filtros pra pegar só registros ainda não migrados (`WHERE locale IS NULL`)
- `INSERT ... ON CONFLICT DO NOTHING` pra seeds

### Batching

Nunca `UPDATE users SET ... ;` em tabela grande — lock prolongado. Sempre:

```typescript
const BATCH = 500;
while (...) {
  // update batch
  await new Promise((r) => setTimeout(r, 100)); // respiro
}
```

### Reversibilidade

Incluir comentário com SQL de rollback:

```typescript
/**
 * Rollback:
 *   UPDATE users SET locale = NULL WHERE locale = 'pt-BR';
 *   DELETE FROM data_migrations_log WHERE name = '20260419-backfill-user-locale';
 */
```

Não automatizar rollback — forçar revisão humana.

### Logs

Todo script loga:
- Início (com `name`)
- Progresso a cada batch
- Total migrado
- Duração

Formato JSON estruturado via pino (ver `docs/observability.md`).

### Testes

Testar em staging com snapshot de prod. Nunca rodar primeiro em prod.

```bash
# 1. Restore backup prod em staging
# 2. Rodar migration
# 3. Validar com SELECT COUNT(*) e comparação de samples
# 4. Só então aplicar em prod
```

---

## Anti-patterns

- Schema migration + data migration na mesma transação — lock longo, timeout em tabelas grandes
- Data migration dentro de Drizzle Kit migration (`.sql` com `UPDATE` massivo) — Drizzle Kit não foi feito pra isso, e não tem batching
- Script que depende de código do app — mantém independente, só imports de `@projeto/shared` e `drizzle-orm`
- Rodar data migration depois do deploy do novo código — se o código assume novo estado, backfill depois = race condition
- Rodar em prod sem testar em staging — alto risco de corrupção
- Migration não idempotente — re-run catastrófico

---

## Exemplo completo: adicionar `locale` a users

### 1. Schema migration (Drizzle Kit)

```typescript
// packages/shared/src/schema/users.ts
export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
  locale: text('locale'), // nullable inicialmente
});
```

```bash
bun run db:generate
bun run db:migrate
```

### 2. Data migration (script TS)

`apps/api/src/data-migrations/20260419-backfill-user-locale.ts` (exemplo acima).

### 3. Deploy da migration + script (sem código novo ainda)

Produção executa `db:migrate` + `data-migrate`. Locale agora está preenchido em todos os rows.

### 4. Segundo schema migration (fazer NOT NULL)

```typescript
// packages/shared/src/schema/users.ts
locale: text('locale').notNull().default('pt-BR'),
```

```bash
bun run db:generate  # gera ALTER COLUMN SET NOT NULL
bun run db:migrate
```

### 5. Código novo pode agora assumir `locale` sempre preenchido

Sem o passo 3, o passo 4 falha (column has null values).

---

## Checklist de rollout

- [ ] Tabela `data_migrations_log` criada via Drizzle
- [ ] Pasta `apps/api/src/data-migrations/` existe
- [ ] Runner `_runner.ts` funciona localmente
- [ ] Script `data-migrate` no `package.json`
- [ ] Integrado ao deploy: pre-deploy Railway ou entrypoint Portainer
- [ ] Primeiro script tem naming `YYYYMMDD-descricao`
- [ ] Script é idempotente (testar rodar 2x)
- [ ] Batches de ≤500 registros
- [ ] Testado em staging com dump de prod
