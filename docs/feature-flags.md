# Feature flags

**Status: opcional.** Ler apenas se o projeto precisa desligar/ligar features em runtime (rollout progressivo, A/B test, kill switch). Projetos pequenos com deploys rápidos geralmente não precisam.

Princípio: **começar simples** (env var boolean) e só subir de nível quando a complexidade justificar. Feature flag é dívida técnica temporária — cada flag deve ter data de remoção.

## Quando usar

| Caso | Vale flag? |
|---|---|
| Feature completa em dev/staging, aguardando data de release | Sim — env var |
| Rollout progressivo (10% → 50% → 100%) | Sim — tabela no banco |
| Kill switch de integração externa (ex: desabilitar Stripe se quebrar) | Sim — tabela no banco |
| A/B test de UI | Sim — LaunchDarkly/Unleash |
| "Talvez um dia usemos" | **Não** — YAGNI, exclua e volte quando precisar |

Regra: toda flag tem **dono** e **data de morte**. Sem esses dois, vira código morto.

---

## Tier 1: env var boolean (mais simples)

Para features atrás de release date específica, sem necessidade de toggle em runtime:

### API

```typescript
// apps/api/src/config.ts
export const config = {
  newDashboardEnabled: process.env.FLAG_NEW_DASHBOARD === 'true',
};

// uso em route
app.get('/api/dashboard/v2', async (c) => {
  if (!config.newDashboardEnabled) {
    return c.json({ error: 'NOT_FOUND', code: 'NOT_FOUND' }, 404);
  }
  // ...
});
```

### Frontend

```typescript
// apps/web/src/config.ts
export const flags = {
  newDashboard: import.meta.env.VITE_FLAG_NEW_DASHBOARD === 'true',
};

// uso
{flags.newDashboard && <NewDashboard />}
```

### Tradeoffs

✅ Zero infra, zero complexidade, zero lib
✅ Controle via Railway/Portainer UI
❌ Mudar valor exige redeploy
❌ Binário — não dá pra rollout progressivo
❌ Frontend precisa rebuild se muda `VITE_*`

Usar quando: release date planejada, feature testada, flag vai sumir em ≤30 dias.

---

## Tier 2: tabela no Postgres

Para runtime toggling sem redeploy, rollout progressivo simples:

### Schema

```typescript
// packages/shared/src/schema/feature-flags.ts
import { pgTable, text, boolean, integer, timestamp } from 'drizzle-orm/pg-core';

export const featureFlags = pgTable('feature_flags', {
  key: text('key').primaryKey(),
  enabled: boolean('enabled').notNull().default(false),
  rolloutPercent: integer('rollout_percent').notNull().default(0), // 0-100
  description: text('description').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
  expiresAt: timestamp('expires_at'), // data-alvo para remover a flag (≠ soft-delete deletedAt)
});
```

### Serviço com cache

Flag é lida em hot path — não pode bater no banco a cada request.

```typescript
// apps/api/src/services/feature-flags.ts
import { db } from '@/db';
import { featureFlags } from '@projeto/shared';

let cache: Map<string, { enabled: boolean; rolloutPercent: number }> = new Map();
let lastLoad = 0;
const TTL_MS = 30_000;

async function refresh() {
  const rows = await db.select().from(featureFlags);
  const next = new Map<string, { enabled: boolean; rolloutPercent: number }>();
  for (const row of rows) {
    next.set(row.key, { enabled: row.enabled, rolloutPercent: row.rolloutPercent });
  }
  cache = next;
  lastLoad = Date.now();
}

export async function isEnabled(key: string, userId?: string): Promise<boolean> {
  if (Date.now() - lastLoad > TTL_MS) await refresh();
  const flag = cache.get(key);
  if (!flag) return false;
  if (!flag.enabled) return false;
  if (flag.rolloutPercent >= 100) return true;
  if (flag.rolloutPercent <= 0) return false;

  // Sticky por userId (mesmo user, mesma decisão) via hash
  if (!userId) return Math.random() * 100 < flag.rolloutPercent; // ⚠️ Anônimos recebem decisão não-sticky (rola a cada request). Para sticky sem login, usar fingerprint ou cookie como seed.
  const hash = hashString(`${key}:${userId}`) % 100;
  return hash < flag.rolloutPercent;
}

function hashString(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}
```

### Middleware Hono

```typescript
// apps/api/src/middleware/require-flag.ts
export const requireFlag = (key: string) => async (c: Context, next: () => Promise<void>) => {
  const userId = getAuth(c)?.userId;
  if (!(await isEnabled(key, userId))) {
    return c.json({ error: 'NOT_FOUND', code: 'NOT_FOUND' }, 404);
  }
  await next();
};

// uso
app.get('/api/dashboard/v2', requireFlag('new_dashboard'), handler);
```

Retornar 404 (não 403) para não vazar existência da feature.

### Frontend

API expõe `/api/me/flags` com flags relevantes ao usuário:

```typescript
// apps/api/src/routes/me.ts
app.get('/api/me/flags', async (c) => {
  const userId = getAuth(c)?.userId;
  const keys = ['new_dashboard', 'export_csv', 'bulk_actions'];
  const flags: Record<string, boolean> = {};
  for (const k of keys) flags[k] = await isEnabled(k, userId);
  return c.json({ data: flags });
});
```

Hook:

```typescript
// apps/web/src/hooks/use-feature-flag.ts
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@/lib/api';

export function useFeatureFlag(key: string): boolean {
  const { data } = useQuery({
    queryKey: ['flags'],
    queryFn: async () => (await apiClient.me.flags.$get()).json(),
    staleTime: 60_000,
  });
  return data?.data[key] ?? false;
}

// uso
function Component() {
  const showNewDashboard = useFeatureFlag('new_dashboard');
  return showNewDashboard ? <NewDashboard /> : <OldDashboard />;
}
```

### UI de admin

Simples CRUD em `/admin/flags` para ligar/desligar e ajustar rollout. Apenas admins (via middleware auth).

---

## Tier 3: SaaS (LaunchDarkly, Unleash, Flagsmith)

Quando justifica:
- A/B tests com métricas integradas
- Targeting complexo (por região, plano, cohort)
- Auditoria de quem mudou o quê, quando
- Mais de ~20 flags ativas simultaneamente

Custo: US$ por MAU/seat. Avaliar trade-off.

### Unleash self-hosted (gratuito)

Docker na stack do Portainer. **Antes**: Unleash exige database e usuário próprios — não compartilhar com o app.

1. Criar DB e role no Postgres da stack:

   ```sql
   CREATE USER unleash WITH PASSWORD '...';
   CREATE DATABASE unleash OWNER unleash;
   ```

   Salvar a senha em `${UNLEASH_DB_PASSWORD}` no env da stack.

2. Service no compose:

   ```yaml
   unleash:
     image: unleashorg/unleash-server:6
     restart: unless-stopped
     depends_on:
       postgres:
         condition: service_healthy
     environment:
       DATABASE_URL: postgres://unleash:${UNLEASH_DB_PASSWORD}@postgres:5432/unleash
       DATABASE_SSL: "false"   # rede interna do compose
       INIT_ADMIN_API_TOKENS: ${UNLEASH_ADMIN_TOKEN}
     ports:
       - "4242:4242"
     networks: [default, traefik-net]
   ```

3. App consome via SDK:

   ```bash
   bun add unleash-client
   ```

   ```typescript
   import { Unleash } from 'unleash-client';

   const unleash = new Unleash({
     url: process.env.UNLEASH_URL!,        // http://unleash:4242/api
     appName: 'masterboi-api',
     customHeaders: { Authorization: process.env.UNLEASH_CLIENT_TOKEN! },
   });

   if (unleash.isEnabled('new_dashboard', { userId })) { /* ... */ }
   ```

Vale apenas se o Tier 2 ficou pequeno e a empresa aceita manter mais um serviço.

---

## Ciclo de vida da flag

Toda flag passa por:

1. **Criada** — valor default `false` em prod, `true` em dev
2. **Em rollout** — 10% → 50% → 100%
3. **Estabilizada** — 100% em todos ambientes por ≥2 semanas sem issues
4. **Removida** — deletar código condicional, deletar flag da tabela

**Remoção** é a parte mais esquecida. Criar regra: toda PR que adiciona flag inclui `expires_at` em 30-90 dias. Revisão periódica:

```sql
SELECT key, description, expires_at
FROM feature_flags
WHERE expires_at < NOW() OR expires_at IS NULL;
```

Remover do código e da tabela no mesmo PR.

---

## Anti-patterns

- Flag sem dono e sem data de morte — vira código morto permanente
- Flag aninhada em flag (`if A && B`) — combinatória explode, testes impossíveis
- Flag lida em loop hot (ex: a cada render) — cache local obrigatório
- Flag exposta no bundle do frontend sem cuidado — competitor vê features não-lançadas nos sources
- Flag como feature config permanente (ex: `MAX_UPLOAD_MB`) — isso é env var, não flag
- Deletar flag da tabela antes de remover do código — handler retorna 404 em prod, usuário vê erro
- Logar `isEnabled` resultado em cada chamada — log floods

---

## Testes

```typescript
import { describe, it, expect, beforeEach } from 'bun:test';
import { isEnabled } from './feature-flags';

describe('isEnabled', () => {
  beforeEach(async () => {
    await db.insert(featureFlags).values({
      key: 'test_flag',
      enabled: true,
      rolloutPercent: 50,
      description: 'test',
    });
  });

  it('rollout sticky por userId', async () => {
    const a = await isEnabled('test_flag', 'user-1');
    const b = await isEnabled('test_flag', 'user-1');
    expect(a).toBe(b);
  });

  it('rollout 0% sempre falso', async () => {
    await db.update(featureFlags).set({ rolloutPercent: 0 }).where(eq(featureFlags.key, 'test_flag'));
    expect(await isEnabled('test_flag', 'user-1')).toBe(false);
  });

  it('rollout 100% sempre verdadeiro', async () => {
    await db.update(featureFlags).set({ rolloutPercent: 100 }).where(eq(featureFlags.key, 'test_flag'));
    expect(await isEnabled('test_flag', 'user-1')).toBe(true);
  });
});
```

---

## Checklist de rollout

- [ ] Nível escolhido (env var / tabela / SaaS) justificado por caso real
- [ ] Tabela `feature_flags` criada via Drizzle (se Tier 2)
- [ ] Cache com TTL implementado (se Tier 2)
- [ ] `useFeatureFlag` hook no frontend (se Tier 2)
- [ ] Sticky por `userId` em rollout progressivo
- [ ] UI admin para ligar/desligar (se Tier 2)
- [ ] `expires_at` preenchido em toda flag nova
- [ ] Revisão trimestral de flags expiradas
- [ ] Testes cobrindo rollout 0%, 100% e parcial
