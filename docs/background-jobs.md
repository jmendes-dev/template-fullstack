# Background jobs — escala progressiva

Ler ao decidir como processar trabalho assíncrono, ao criar tabela `jobs`, ou ao avaliar se pg-boss é necessário. Regra-resumo (escalar por níveis) vive em `CLAUDE.md`.

Escalar só quando necessário:

1. **Fire-and-forget** → `setTimeout` ou `queueMicrotask`. Padrão Hono em Bun/Node: usar `void promise.catch(logErr)` direto na rota — não há `c.executionCtx.waitUntil()` (esse helper existe **apenas** em Cloudflare Workers, e nosso deploy é Bun em container)
2. **Jobs com retry/agendamento** → tabela `jobs` no Drizzle + `setInterval` no boot da API. Ou `Bun.cron()` in-process (Bun ≥1.3.12, lançado 9/abr/2026, funciona em containers) — ver nota abaixo
3. **Filas robustas** (retry exponencial, concurrency, scheduling complexo) → pg-boss

Nunca começar pelo pg-boss. Só introduzir se os níveis 1-2 forem insuficientes.

## Tier 1 — fire-and-forget

```typescript
app.post('/orders', async (c) => {
  const order = await createOrder(/* ... */);

  // Não bloquear o response — log se falhar, mas siga em frente
  void sendOrderConfirmationEmail(order)
    .catch((err) => c.get('logger').error({ err, orderId: order.id }, 'email falhou'));

  return c.json({ data: order }, 201);
});
```

Ok para email, webhook, métrica. **Não usar** se a operação precisa garantir entrega — se o container reinicia antes do `then`, perde-se silenciosamente.

## Tier 2 — tabela `jobs` + `setInterval`

Quando precisa de retry/persistência mas pg-boss é overkill:

```typescript
// packages/shared/src/schema/jobs.ts
export const jobs = pgTable('jobs', {
  id: uuid('id').primaryKey().defaultRandom(),
  type: text('type').notNull(),
  payload: jsonb('payload').notNull(),
  status: text('status', { enum: ['pending', 'running', 'done', 'failed'] }).notNull().default('pending'),
  attempts: integer('attempts').notNull().default(0),
  runAfter: timestamp('run_after').notNull().defaultNow(),
  lastError: text('last_error'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});
```

Worker no boot da API:

```typescript
// apps/api/src/jobs/runner.ts
import { db } from '@/db';
import { jobs } from '@projeto/shared';
import { and, eq, inArray, lte, sql } from 'drizzle-orm';

const handlers: Record<string, (payload: any) => Promise<void>> = {
  'send-email': async (p) => sendEmail(p),
  // ...
};

setInterval(async () => {
  // Drizzle não suporta .limit() após .returning() em UPDATE — selecionar IDs primeiro
  const pending = await db
    .select({ id: jobs.id })
    .from(jobs)
    .where(and(eq(jobs.status, 'pending'), lte(jobs.runAfter, new Date())))
    .limit(5);

  if (pending.length === 0) return;

  const claimed = await db
    .update(jobs)
    .set({ status: 'running', attempts: sql`${jobs.attempts} + 1` })
    .where(inArray(jobs.id, pending.map((j) => j.id)))
    .returning();

  for (const job of claimed) {
    const handler = handlers[job.type];
    if (!handler) {
      await db.update(jobs).set({
        status: 'failed',
        lastError: `handler desconhecido: ${job.type}`,
      }).where(eq(jobs.id, job.id));
      continue;
    }
    try {
      await handler(job.payload);
      await db.update(jobs).set({ status: 'done' }).where(eq(jobs.id, job.id));
    } catch (err) {
      const next = job.attempts >= 5 ? 'failed' : 'pending';
      await db.update(jobs).set({
        status: next,
        lastError: String(err),
        runAfter: new Date(Date.now() + 2 ** job.attempts * 60_000),  // backoff exponencial
      }).where(eq(jobs.id, job.id));
    }
  }
}, 5_000);
```

**Nota sobre `Bun.cron`**: a implementação original (≤1.3.11) é OS-level (registra no crontab do host) e **não funciona em container**. Desde Bun 1.3.12 (lançado 9/abr/2026), `Bun.cron()` é in-process e **funciona em containers** — alternativa ao `setInterval`. API: `Bun.cron("*/5 * * * *", async () => { /* job */ })`. Sem sobreposição de execuções. Ver `docs/bun-notes.md`.

## Tier 3 — pg-boss

Quando: > 1000 jobs/min, retry policies por tipo de job, prioridade, scheduling cron, dead letter queue. Doc oficial: https://github.com/timgit/pg-boss
