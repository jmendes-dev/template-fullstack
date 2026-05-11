# Deploy — Railway

Ler ao configurar deploy no Railway, criar `railway.toml`, configurar migrations ou linkar addons. Linha-resumo vive em `CLAUDE.md`. Para storage S3 (Railway Buckets) ver `docs/storage-s3.md`.

Princípio: no Railway **usamos só serviços nativos**. Nada de MinIO, Traefik ou Postgres em container — isso é padrão Portainer. Railway resolve com addons (PostgreSQL, Buckets) e roteamento automático.

## Arquitetura

- 1 service por app: `api`, `web` (dois services separados no mesmo projeto Railway)
- PostgreSQL como **Railway addon** (não container)
- Storage: **Railway Buckets** (S3-compatible, via `@aws-sdk/client-s3`)
- Roteamento: domínios públicos gerados pelo Railway (`*.up.railway.app`) ou custom domain
- TLS e load balancing: automáticos

## `railway.toml` (por service)

Um arquivo por app, em `apps/api/railway.toml` e `apps/web/railway.toml`:

```toml
# apps/api/railway.toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "Dockerfile"

[deploy]
startCommand = "bun run start"
healthcheckPath = "/health"
healthcheckTimeout = 30
preDeployCommand = "bun run db:migrate && bun run data-migrate"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

`preDeployCommand` é a fonte única de migrations: schema (Drizzle Kit) **e** data migrations (ver `docs/data-migrations.md`). Versionado no git — não duplicar no campo `Settings → Deploy → Pre-deploy Command` da UI.

Web service: remover `healthcheckPath` se o frontend não expõe `/health`, ou apontar para `/` (Vite preview/nginx responde 200).

## PostgreSQL addon

1. Dashboard do projeto → `+ New` → `Database` → `PostgreSQL`
2. Railway injeta automaticamente `DATABASE_URL` no service que for **linkado** ao Postgres
3. Linkar: abrir o service `api` → `Variables` → `Add Reference` → selecionar `Postgres.DATABASE_URL`
4. `DATABASE_URL` fica disponível em `process.env.DATABASE_URL` sem configuração manual

## Railway Buckets (storage)

1. Dashboard → `+ New` → `Database` → `Railway Bucket`
2. Railway fornece credenciais S3-compatible: `BUCKET_ENDPOINT`, `BUCKET_ACCESS_KEY_ID`, `BUCKET_SECRET_ACCESS_KEY`, `BUCKET_NAME`
3. Linkar ao service `api` como references e **remapear** para as envs do projeto:
   - `S3_ENDPOINT` ← `Bucket.BUCKET_ENDPOINT`
   - `S3_ACCESS_KEY` ← `Bucket.BUCKET_ACCESS_KEY_ID`
   - `S3_SECRET_KEY` ← `Bucket.BUCKET_SECRET_ACCESS_KEY`
   - `S3_BUCKET` ← `Bucket.BUCKET_NAME`
4. Client S3 no código usa `S3_ENDPOINT` como em qualquer outro ambiente (ver `docs/storage-s3.md`)

## Migrations — pre-deploy command

Definido no `railway.toml` (versionado), bloco `[deploy].preDeployCommand` (ver acima):

```toml
preDeployCommand = "bun run db:migrate && bun run data-migrate"
```

Railway roda o pre-deploy antes de promover o novo deploy. Se a migration falha, o deploy é abortado e o tráfego continua no deploy anterior (sem downtime). **Não duplicar o comando** em `Settings → Deploy → Pre-deploy Command` na UI — isso cria conflito de fonte de verdade. Usar apenas o TOML.

Garanta que `apps/api/package.json` tem os scripts `db:migrate` e `data-migrate` antes do deploy. Para data migrations: ver `docs/data-migrations.md`.

## Variáveis de ambiente

Dashboard do service → `Variables` → `Raw Editor` (cola as vars em formato `KEY=value` linha a linha):

```env
CLERK_SECRET_KEY=sk_live_...
APP_CORS_ORIGINS=https://app.masterboi.com.br
```

**Nunca setar `PORT` manualmente** — Railway injeta `PORT` dinamicamente no container a cada deploy. O app deve ler `process.env.PORT` (Hono: `Bun.serve({ port: process.env.PORT })`). Hardcodar `PORT=3000` nas env vars quebra o roteamento do Railway.

Vars linkadas (`DATABASE_URL`, `S3_*`) aparecem automaticamente — não digitar manualmente.

Vars do frontend (`VITE_*`) vão no service `web`, não no `api`.

## Healthcheck

- `healthcheckPath = "/health"` no `railway.toml` do service
- O endpoint deve retornar `200` em < 30s após o container subir
- Hono: `app.get('/health', (c) => c.json({ status: 'ok' }))`
- Se falhar, Railway não promove o deploy e mantém o anterior ativo

## Custom domain

Dashboard do service → `Settings` → `Networking` → `Custom Domain` → adicionar CNAME apontando para o target que o Railway fornecer. TLS automático via Let's Encrypt.

## Logs

- Dashboard do service → `Deployments` → selecionar deploy → `View Logs` (live stream)
- CLI: `railway logs --service <api|web>` (após `railway login` e `railway link`)
- Filtros por nível (`info`, `warn`, `error`) funcionam se logs forem JSON estruturado via `pino`
- Retenção padrão: 7 dias no plano Hobby, 30 dias no Pro
- Integração externa: `Settings` → `Observability` → exportar para Better Stack, Datadog, ou Axiom (requer plano Pro+)

## Scaling

- **Vertical**: `Settings` → `Resources` → ajustar RAM/CPU. Respeitar alvo de ≤256MB por container
- **Horizontal**: `Settings` → `Replicas` → setar N > 1 (disponível a partir do plano Pro). Railway faz round-robin automaticamente
- **Regional**: deploys multi-região só no Enterprise
- Escalar só após confirmar via métricas (`Observability` → `Metrics`) que CPU/RAM estão saturados — adicionar réplicas sem necessidade desperdiça recursos

## Memory limit

Railway não tem `mem_limit` em compose (não usa compose em prod). Configurar pela UI:

- `Settings` → `Resources` → `Memory Limit` → setar **256 MB** (alvo do CLAUDE.md)
- Acima disso o container é OOM-killed e Railway re-tenta conforme `restartPolicy`
- Ativar alerta em `Observability` → `Alerts` → "Memory > 200MB" para investigar leaks antes do OOM

## Dockerfile de produção (referência)

Railway detecta `Dockerfile` automaticamente. Exemplo multi-stage para `apps/api/Dockerfile` (o mesmo padrão funciona em Portainer):

```dockerfile
FROM oven/bun:1.3 AS builder
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/api/package.json apps/api/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN bun install --frozen-lockfile
COPY . .
RUN bun build apps/api/src/index.ts \
    --minify --target=bun --sourcemap=linked \
    --outfile apps/api/dist/index.js

# Stage só de production deps (sem dev) — bundle não cobre módulos nativos
FROM oven/bun:1.3 AS deps
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/api/package.json apps/api/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN bun install --production --frozen-lockfile

FROM oven/bun:1.3-slim AS runtime
WORKDIR /app
COPY --from=builder /app/apps/api/dist ./dist
COPY --from=deps /app/node_modules ./node_modules
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://localhost:${PORT:-3000}/health || exit 1
USER bun
CMD ["bun", "run", "dist/index.js"]
```

Pontos críticos:
- Stage `deps` separado roda `bun install --production` — sem devDeps na imagem final (regra 9 do CLAUDE.md)
- `bun build --target=bun` bundla a maior parte do código; mas drivers nativos (ex: `postgres`, `@aws-sdk/*`) precisam de `node_modules` em runtime — daí o stage `deps`
- Não copiar `packages/shared/` para runtime — está bundlado dentro de `dist/index.js`
- Tags fixadas (`oven/bun:1.3`, `oven/bun:1.3-slim`) — nunca `:latest` ou `:slim` sem versão

### Dockerfile da Web (apps/web/Dockerfile)

```dockerfile
# apps/web/Dockerfile
FROM oven/bun:1.3 AS deps
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/web/package.json ./apps/web/
COPY packages/shared/package.json ./packages/shared/
RUN bun install --frozen-lockfile

FROM deps AS builder
COPY . .
RUN bun run --filter=@projeto/web build

FROM nginx:alpine AS runtime
COPY --from=builder /app/apps/web/dist /usr/share/nginx/html
EXPOSE 80
```

Para web não há `node_modules` em runtime se servir assets estáticos via nginx.

## Rollback

Dashboard do service → `Deployments` → selecionar deploy anterior → `Redeploy`. Não precisa de Git revert.
