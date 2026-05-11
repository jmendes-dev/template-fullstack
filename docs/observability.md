# Observability

Ler ao configurar logs estruturados, adicionar tracing, integrar error tracking, ou expor health endpoints além de `/health`. Linha-resumo vive em `CLAUDE.md` seção "Production-readiness".

Princípio: **três pilares** — logs (o que aconteceu), metrics (quanto aconteceu), traces (como se relacionaram). Começar simples; escalar por evidência.

## Logs estruturados com pino

Biblioteca: `pino` (já no CLAUDE.md como padrão).

**Campos obrigatórios em toda log line:**

| Campo | Tipo | Origem |
|---|---|---|
| `requestId` | string (UUID) | middleware Hono — gerar em cada request via `crypto.randomUUID()` |
| `userId` | string \| null | `getAuth(c)` se autenticado |
| `route` | string | `c.req.routePath` |
| `method` | string | `c.req.method` |
| `status` | number | response status |
| `durationMs` | number | calcular no middleware |
| `msg` | string | sempre em português, sem PII |

**Setup no Hono**:

```typescript
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  // Em prod: JSON puro para stdout (Railway/Portainer coletam)
  // Em dev: pino-pretty via pipe externo, nunca dentro da app
});

app.use('*', async (c, next) => {
  const requestId = c.req.header('x-request-id') ?? crypto.randomUUID();
  const start = performance.now();
  c.set('logger', logger.child({ requestId }));
  c.set('requestId', requestId);
  await next();
  const durationMs = Math.round(performance.now() - start);
  c.get('logger').info({
    route: c.req.routePath,
    method: c.req.method,
    status: c.res.status,
    durationMs,
    // userId só está disponível se o middleware de auth (Clerk) rodou antes deste ponto
    userId: c.get('userId') ?? null,
  }, 'request completed');
});
```

**Anti-patterns:**
- `console.log` em prod — nunca
- `pino-pretty` dentro do container de prod (overhead + vazamento de log no stdout)
- Logar body de request (PII, payload grande) — logar só shape/tamanho
- Logar `Authorization: Bearer ...` ou cookies — masked always

## Health endpoints (obrigatório em API)

Três endpoints, cada um com propósito diferente:

| Endpoint | Retorna 200 quando | Usado por |
|---|---|---|
| `GET /health` | processo vivo | Docker healthcheck, load balancer superficial |
| `GET /ready` | DB + S3 + deps críticas respondem | Railway/Traefik — decidir se envia tráfego |
| `GET /live` | event loop não travou (simples `{ ok: true }`) | Kubernetes-like autoscale (opcional) |

**`/ready` exemplo**:

```typescript
import { HeadBucketCommand } from '@aws-sdk/client-s3';

app.get('/ready', async (c) => {
  const checks = await Promise.allSettled([
    db.execute(sql`SELECT 1`),                                         // Postgres
    s3.send(new HeadBucketCommand({ Bucket: process.env.S3_BUCKET! })), // S3 (SDK v3)
  ]);
  const failed = checks.filter(r => r.status === 'rejected');
  if (failed.length > 0) {
    return c.json({ error: 'Serviço não pronto', code: 'NOT_READY', details: failed.map(f => f.reason.message) }, 503);
  }
  return c.json({ data: { status: 'ready' } });
});
```

## Error tracking — Sentry

Instalar condicionalmente, como o Clerk (só se `SENTRY_DSN` existir):

```typescript
// apps/api/src/index.ts
import * as Sentry from '@sentry/bun';
if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: 0.1,  // 10% em prod; 1.0 em dev/staging
  });
}

app.onError((err, c) => {
  if (process.env.SENTRY_DSN) Sentry.captureException(err, {
    tags: { requestId: c.get('requestId'), route: c.req.routePath },
  });
  c.get('logger').error({ err }, 'unhandled error');
  return c.json({ error: 'Erro interno', code: 'INTERNAL_ERROR' }, 500);
});
```

**Frontend** (`@sentry/react`):
- Env var: `VITE_SENTRY_DSN` (não `SENTRY_DSN` — Vite só expõe vars com prefixo `VITE_` ao client)
- Wrap `<App />` com `<Sentry.ErrorBoundary>` — ver `docs/error-boundaries.md`
- `beforeSend` para sanitizar PII

**Sampling**:
- `tracesSampleRate: 0.1` em prod (10%) — o suficiente sem custar caro
- Errors sempre 100% (default do Sentry)

## Tracing distribuído (OpenTelemetry)

Adicionar **apenas se houver necessidade real** (microserviços, latência cross-service importa). Para monolito Hono, pino + Sentry cobre 90% dos casos.

Se for necessário:

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

if (process.env.OTEL_EXPORTER_OTLP_ENDPOINT) {
  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter(),
    instrumentations: [getNodeAutoInstrumentations()],
  });
  sdk.start();
}
```

Destinos:
- **Railway**: exportar para Axiom, Honeycomb ou Better Stack via OTLP. Setar `OTEL_EXPORTER_OTLP_ENDPOINT=https://api.axiom.co/v1/traces` (ou equivalente) e `OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <token>"` no dashboard do service. Sem container extra.
- **Portainer**: Jaeger ou Tempo como container numa stack shared (idealmente separado da stack do produto). Exemplo Jaeger:

  ```yaml
  # stack shared/observability
  jaeger:
    image: jaegertracing/all-in-one:1.70  # Verificar versão latest em hub.docker.com antes de usar
    restart: unless-stopped
    ports:
      - "16686:16686"  # UI
    environment:
      COLLECTOR_OTLP_ENABLED: "true"
    networks: [traefik-net]
  ```

  No app, setar `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318/v1/traces`.

## Metrics

### Railway

Métricas nativas (CPU, RAM, req/s) — consultar via `Observability` → `Metrics`. Sem setup. Para métricas de aplicação custom, exportar via OTLP para o mesmo destino do tracing (Axiom/Honeycomb).

### Portainer

Sem métricas por padrão — subir Prometheus + Grafana numa stack shared:

```yaml
# stack shared/observability
prometheus:
  image: prom/prometheus:v3.3.0  # Verificar versão latest em hub.docker.com antes de usar
  restart: unless-stopped
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  ports:
    - "9090:9090"
  networks: [traefik-net]

grafana:
  image: grafana/grafana:12.0.0  # Verificar versão latest em hub.docker.com antes de usar
  restart: unless-stopped
  environment:
    GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
  volumes:
    - grafana_data:/var/lib/grafana
  ports:
    - "3001:3000"
  networks: [traefik-net]

volumes:
  prometheus_data:
  grafana_data:
```

`prometheus.yml`:

```yaml
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'api'
    static_configs:
      - targets: ['api:3000']
    metrics_path: '/metrics'
```

### Métricas de aplicação (`prom-client`)

Só se houver necessidade real (HTTP requests por status, duração por rota, uso de DB pool). Começar sem. Quando adicionar:

```typescript
import { Counter, Histogram, register } from 'prom-client';

const httpRequests = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
});

app.use('*', async (c, next) => {
  const end = httpDuration.startTimer({ method: c.req.method, route: c.req.routePath });
  await next();
  httpRequests.inc({ method: c.req.method, route: c.req.routePath, status: c.res.status });
  end();
});

app.get('/metrics', async (c) => {
  c.header('Content-Type', register.contentType);
  return c.body(await register.metrics());
});
```

Endpoint `/metrics` deve ficar atrás de auth ou rede privada — não expor publicamente.

## Alertas

Alvos mínimos para alertar (Sentry, Better Stack, ou via webhook Slack):

- Taxa de erro 5xx > 1% por 5min
- `/ready` retorna 503 por 2min consecutivos
- Response time p95 > 2s por 10min
- Disk do Postgres > 80% (Railway addon mostra; Portainer monitorar via node exporter)

## Checklist de rollout

- [ ] Middleware de logging com `requestId` + `durationMs` em todas as rotas
- [ ] `/health`, `/ready`, `/live` respondem corretamente
- [ ] Sentry configurado condicionalmente (`SENTRY_DSN`)
- [ ] Frontend com `Sentry.ErrorBoundary` no `main.tsx`
- [ ] Alertas configurados no destino (Sentry ou Better Stack)
- [ ] Retenção de logs validada no target (Railway: 7 dias Hobby / 30 Pro; Portainer: configurável via Docker log driver `max-size`/`max-file` — ver `docs/deploy-portainer.md` seção Logs)
