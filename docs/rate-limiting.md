# Rate limiting

Ler ao proteger endpoints contra abuse, implementar quotas por usuário, ou investigar 429 inesperados. Linha-resumo vive em `CLAUDE.md` seção "Production-readiness".

Princípio: rate limit **no edge se possível** (Traefik/Railway), **no app como fallback**. O app nunca é a única linha de defesa — mas deve sempre existir como backup.

## Quando aplicar

| Endpoint | Limite sugerido | Chave |
|---|---|---|
| Auth (login, signup, reset password) | 5/min | IP |
| Busca e autocomplete | 30/min | userId (fallback IP) |
| Criação/escrita geral | 60/min | userId |
| Leitura autenticada | 300/min | userId |
| Webhooks externos (Clerk, Stripe) | não rate-limitar — validar assinatura |
| `/health`, `/ready`, `/live` | não rate-limitar |

## Lib: `hono-rate-limiter`

Instalar: `bun add hono-rate-limiter`.

**Setup básico (in-memory, single instance)**:

```typescript
import { rateLimiter } from 'hono-rate-limiter';

const authLimiter = rateLimiter({
  windowMs: 60_000,
  limit: 5,
  keyGenerator: (c) => c.req.header('x-forwarded-for')?.split(',')[0].trim()
                    ?? c.req.header('x-real-ip')
                    ?? 'unknown',
  handler: (c) => c.json({
    error: 'RATE_LIMITED',
    code: 'RATE_LIMITED',
    details: { retryAfter: 60 }
  }, 429, { 'Retry-After': '60' }),
});

app.use('/api/auth/*', authLimiter);
```

**Por usuário autenticado (Clerk)**:

```typescript
const userLimiter = rateLimiter({
  windowMs: 60_000,
  limit: 60,
  keyGenerator: (c) => {
    const auth = getAuth(c);
    return auth?.userId ?? c.req.header('x-forwarded-for') ?? 'unknown';
  },
  skip: (c) => !getAuth(c)?.userId,  // pula para anônimos (pega o de IP)
  handler: (c) => c.json({
    error: 'RATE_LIMITED',
    code: 'RATE_LIMITED',
    details: { retryAfter: 60 }
  }, 429, { 'Retry-After': '60' }),
});
```

## Contrato de resposta 429 (consistente com o template)

Sempre retornar envelope padrão:

```json
{
  "error": "RATE_LIMITED",
  "code": "RATE_LIMITED",
  "details": { "retryAfter": 60 }
}
```

Com header `Retry-After: 60`. Frontend usa o header para saber quando retentar.

TanStack Query retry automático. Hono RPC client lança `Error` quando o response não é OK — não joga `Response` diretamente. Usar uma classe custom para preservar status/headers:

```typescript
// src/lib/api-error.ts
export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    public retryAfter?: number,
  ) {
    super(code);
    this.name = 'ApiError';
  }
}

// src/lib/api-client.ts — wrapper sobre o RPC client
import { hc } from 'hono/client';
import type { AppType } from '@projeto/api';

// Singleton — nunca recriar em outros arquivos; importar sempre de @/lib/api-client
const raw = hc<AppType>(import.meta.env.VITE_API_URL);

async function check<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body = await res.json().catch(() => ({ code: 'UNKNOWN' }));
    const retryAfter = Number(res.headers.get('Retry-After')) || undefined;
    throw new ApiError(res.status, body.code ?? 'UNKNOWN', retryAfter);
  }
  return res.json();
}
```

```typescript
// src/lib/query-client.ts
import { QueryClient } from '@tanstack/react-query';
import { ApiError } from './api-error';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => {
        if (error instanceof ApiError && error.status === 429) {
          return failureCount < 2;
        }
        return failureCount < 1;
      },
      retryDelay: (attempt, error) => {
        if (error instanceof ApiError && error.status === 429 && error.retryAfter) {
          return error.retryAfter * 1000;
        }
        return Math.min(1000 * 2 ** attempt, 30_000);
      },
    },
  },
});
```

Chamadas dentro do `queryFn` usam o wrapper:

```typescript
useQuery({
  queryKey: ['users', id],
  queryFn: () => check(raw.users[':id'].$get({ param: { id } })),
});
```

## Storage distribuído (multi-instance)

In-memory funciona com **1 instância**. Se tiver réplicas (Railway `replicas > 1` ou Swarm), trocar para storage compartilhado:

- **Redis**: `hono-rate-limiter` com `@hono-rate-limiter/redis` store (exige Redis na stack)
- **Postgres**: contador em tabela com `LOCK IN SHARE MODE` — viável para baixo volume, acaba virando gargalo
- **Upstash Redis**: REST-based, sem manter conexão — serve Railway sem addon

Começar single-instance + in-memory. Só escalar quando houver réplicas.

## Rate limit no edge

**Traefik (Portainer)** — middleware de rate limit global:

```yaml
# stack do Traefik
labels:
  - "traefik.http.middlewares.apirate.ratelimit.average=60"
  - "traefik.http.middlewares.apirate.ratelimit.burst=120"
  - "traefik.http.routers.api.middlewares=apirate"
```

**Railway** — não há rate limit nativo no edge; aplicar 100% no app ou via Cloudflare/Fastly como CDN na frente.

Regra geral: edge protege contra floods brutos (DDoS-lite), app protege contra quotas por usuário.

## Anti-patterns

- Usar `Retry-After` em segundos e o frontend assumir milissegundos (ou vice-versa) — sempre segundos em 429
- Rate limit em health checks — quebra monitoramento
- Rate limit por userId em webhook externo — webhooks não têm userId, valida assinatura em vez
- Retornar 429 sem `Retry-After` — cliente fica adivinhando
- Logar rate limit como ERROR — é WARN ou INFO, é comportamento esperado
- Loggar o IP bruto sem proxy awareness — Railway/Traefik colocam IP real em `x-forwarded-for`

## Checklist de rollout

- [ ] Lib `hono-rate-limiter` instalada
- [ ] Limiter de auth aplicado (5/min por IP)
- [ ] Limiter de escrita por usuário (60/min)
- [ ] Limiter de leitura por usuário (300/min)
- [ ] Resposta 429 com envelope padrão + `Retry-After`
- [ ] TanStack Query com retry respeitando `Retry-After`
- [ ] Teste: disparar 10 requests em 1s num endpoint de auth → 5 passam, 5 retornam 429
- [ ] Se multi-instance: trocar store in-memory por Redis
