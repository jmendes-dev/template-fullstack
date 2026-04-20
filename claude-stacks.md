# claude-stacks.md — Regras e Padrões Técnicos

> **Versões pinadas e notas de compatibilidade**: ver `claude-stacks-versions.md`.
> Este arquivo contém apenas regras de uso, padrões e anti-patterns (princípios estáveis).

## Stack

Monorepo TypeScript ≥6.0 · Bun ≥1.3 · Hono ≥4.12.4 · React 19 · Drizzle ORM · Drizzle Kit ≥0.31 · PostgreSQL · Biome 2.x · Vite 8 (Rolldown) · Tailwind CSS v4 · Zod v4 · Node ≥20.19 ou ≥22.12 (para tooling)

## Bun — regras de uso

- **Lockfile**: `bun.lock` (JSONC). Se `bun.lockb` existir, deletar e rodar `bun install`.
- **Hot reload**: `bun --hot` para API (preserva `globalThis`). `--watch` reinicia processo.
- **Bun.cron**: **não funciona em containers Docker** — usar `setInterval` + tabela `jobs` em containers.
- **Docker image**: `oven/bun:1.3` (reprodutibilidade). Alternativas: `slim`, `distroless`, `alpine`.

## Estrutura

```
apps/web/         # React 19 + React Router v7 + shadcn/ui (Vite)
apps/api/         # Hono REST + RPC
packages/shared/  # Zod schemas, Drizzle schema, tipos compartilhados
```

## Monorepo Architecture

**Workspace manager**: Bun workspaces — config no `package.json` raiz:
```json
{ "workspaces": ["apps/*", "packages/*"] }
```

**Grafo de dependencias** (direcao: quem depende de quem):
- `apps/api` → `packages/shared`
- `apps/web` → `packages/shared`
- `apps/api` ✕ `apps/web` — **nunca** importar codigo runtime entre apps. Toda comunicacao via HTTP/RPC. **Excecao unica**: `import type` do AppType da API para Hono RPC (ver abaixo)

**Workspace linkage** (obrigatorio em cada `package.json` de app):
```json
{ "dependencies": { "@projeto/shared": "workspace:*" } }
```
Frontend tambem precisa de `"@projeto/api": "workspace:*"` como **devDependency** (apenas para `import type` do AppType — sem codigo runtime).

**Exports do shared**: `packages/shared/src/index.ts` e barrel file — re-exporta schemas, tipos e constantes. Apps importam de `@projeto/shared`, nunca de caminhos internos do package.

**Hono RPC**: API exporta `type AppType = typeof app`. Frontend: `import type { AppType } from "@projeto/api"` → `hc<AppType>(baseUrl)`. `import type` eliminado em compile time — type-safety end-to-end sem dep runtime.

**Comandos por workspace**: `bun run --filter=@projeto/api <script>`

## Tecnologias core

| Camada | Tech |
|---|---|
| Runtime/PM/Test | Bun |
| API | Hono + @hono/standard-validator (Zod v4 via Standard Schema) + hono/client RPC |
| Frontend | React 19 + React Router v7 (`react-router`) |
| Data fetching | TanStack Query (nunca React Router loaders) |
| Client state | Zustand |
| Forms | React Hook Form + zodResolver (`@hookform/resolvers/zod`) + schema de shared/ |
| UI | shadcn/ui + Tailwind CSS v4 (CSS-first) |
| Toasts | Sonner (nunca alert() ou outra lib) |
| Charts | shadcn Charts (Recharts). Tremor para dashboards |
| DB | PostgreSQL + Drizzle ORM |
| Schemas | Zod v4 + Drizzle Zod integration em packages/shared (fonte única de verdade) — ver regra 26 para stable vs beta |
| Auth | Clerk |
| Lint/Format | Biome 2.x |
| CI | GitHub Actions + Blacksmith runners + SonarQube |
| Email | Resend + React Email (on demand) |
| Jobs | Nativo primeiro → pg-boss só se necessário (ver seção Background jobs) |
| Storage | S3-compatible via serviço externo (env vars) — nunca container local |

## Tailwind CSS v4 — configuração CSS-first

`tailwind.config.js` é opcional (suportado via `@config` para migração), mas **projetos novos não devem criá-lo**.

**CSS principal**: substituir todas as diretivas `@tailwind` por `@import "tailwindcss"` (uma linha). Customizar via `@theme { --{tipo}-{nome}: valor; }` no mesmo CSS — gera classes automaticamente.

**Vite plugin**: usar `@tailwindcss/vite` (não PostCSS) — adicionar como plugin no `vite.config.ts`.

**Breaking v4**: `border-*`/`divide-*` usam `currentColor` (era `gray-200` no v3) — especificar cor.

**shadcn/ui**: `bunx shadcn@latest init -t vite`. `components.json`: `tailwind.config: ""` para v4. Estilo "new-york" usa pacote **unificado `radix-ui`** (ver regra 31).

## Variáveis de ambiente obrigatórias

```env
DATABASE_URL=          # connection string PostgreSQL
CLERK_SECRET_KEY=      # backend auth
VITE_CLERK_PUBLISHABLE_KEY=  # frontend auth
VITE_API_URL=          # URL da API para o frontend
APP_CORS_ORIGINS=      # origins permitidas (ex: https://app.exemplo.com)
PORT=                  # porta da API (default: 3000)
WEB_PORT=              # porta do frontend (default: 4000)
PGPORT=                # porta do PostgreSQL (default: 5432)
S3_ENDPOINT=           # URL do serviço S3 externo (ex: http://minio-host:9000)
S3_ACCESS_KEY=         # access key do bucket
S3_SECRET_KEY=         # secret key do bucket
S3_REGION=             # região S3 (default: us-east-1)
S3_BUCKET=             # nome do bucket (default: uploads)
S3_FORCE_PATH_STYLE=   # "true" para S3-compatible (MinIO, etc.)
MINIO_ROOT_USER=       # usuário admin do MinIO local (dev)
MINIO_ROOT_PASSWORD=   # senha admin do MinIO local (dev)
MINIO_PORT=            # porta API S3 do MinIO local (default: 9000, dev only)
MINIO_CONSOLE_PORT=    # porta console web do MinIO local (default: 9001, dev only)
REGISTRY=              # endereço do registry Docker privado (ex: 10.10.254.66:5000)
APP_NAME=              # nome do app (prefixo das imagens: APP_NAME-api, APP_NAME-web)
S3_BACKUP_BUCKET=      # bucket de backup do banco (ex: backup-app-name-db)
BACKUP_RETENTION_DAYS= # dias de retenção dos backups (default: 30 PRD, 7 UAT/dev)
BACKUP_INTERVAL=       # intervalo entre backups em segundos (default: 86400 = 24h)
```

Arquivos: `.env` (dev local apenas), `.env.example`. **UAT e PRD**: variáveis configuradas exclusivamente na UI do Portainer — nunca via arquivo `.env` (Portainer Stacks não processam `.env` files, quebrando o deploy). Compose de UAT/PRD usam sintaxe `${VARIAVEL}` e os valores são definidos na UI do Portainer. Nunca commitar secrets.

## Regras de estado (nunca misture)

| Categoria | Dono |
|---|---|
| Server state | TanStack Query |
| Client state | Zustand |
| Form state | React Hook Form |
| URL state | React Router search params |

## TanStack Query defaults

```typescript
new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60,     // 1 min
      gcTime: 1000 * 60 * 5,    // 5 min
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})
```

Sobrescrever por query apenas quando justificado (ex: dashboard com polling).

## API response format (obrigatório)

Frontend e backend devem concordar neste contrato **antes** de escrever código.

**Sucesso — item único**:
```json
{ "data": { ... } }
```

**Sucesso — lista paginada**:
```json
{ "data": [ ... ], "pagination": { "page": 1, "limit": 10, "total": 87, "totalPages": 9 } }
```

**Erro**:
```json
{ "error": "mensagem legível", "code": "VALIDATION_ERROR", "details": {} }
```

| Status | Uso |
|---|---|
| 400 | Validação / input inválido |
| 401 | Não autenticado |
| 403 | Sem permissão |
| 404 | Recurso não encontrado |
| 429 | Rate limit excedido |
| 500 | Erro interno (nunca expor stack trace em prod) |

Middleware global de error handling no Hono captura exceções e retorna no formato de erro.

Toda rota usa `c.json({ data: ... })`. Nunca array/objeto solto. Frontend acessa `response.data`.

## Resource efficiency (obrigatório)

- Target: **≤256MB RAM por container** em produção
- Dockerfile **sempre multi-stage** (build → `oven/bun:slim` ou `distroless`). Sem devDependencies na imagem final
- API: `bun build --minify --target=bun`. Web: Vite 8 build (Rolldown, 10-30x mais rápido)
- Monitorar: se ultrapassar 256MB, investigar leaks/dependências pesadas

## Deploy: dois targets

### Railway
- Um service por app (api, web) + PostgreSQL addon
- Railway Buckets para object storage S3-compatible
- Variáveis de ambiente via Railway dashboard
- Railway detecta Dockerfile automaticamente
- **Migrations**: rodar como [pre-deploy command](https://docs.railway.com/guides/pre-deploy-command) → `bun run db:migrate`

### Portainer (on-premises)
- Deploy via **Portainer Stacks** — cada ambiente (UAT, PRD) é uma stack separada com seu próprio compose
- PostgreSQL como container na mesma stack
- Imagens pré-buildadas pelo CD e pushadas para registry interno
- Migrations: via entrypoint script (`bun run db:migrate && bun run start`)
- Volumes nomeados para dados persistentes (postgres data)
- Webhook Portainer dispara redeploy após push da imagem

**Três compose files**:

| Arquivo | Uso | Imagens |
|---|---|---|
| `docker-compose.yml` | Dev local | Build local (Dockerfile) |
| `docker-compose-uat.yml` | Homologação (Portainer) | `${REGISTRY}/${APP_NAME}-{service}:uat-latest` |
| `docker-compose-prd.yml` | Produção (Portainer) | `${REGISTRY}/${APP_NAME}-{service}:latest` |

**Diferenças entre ambientes**:
- **Dev**: build local, portas mapeadas no host, volumes bind-mount, sem resource limits
- **UAT**: imagens do registry com tag `uat-latest`, resource limits moderados, `restart: unless-stopped`
- **PRD**: imagens do registry com tag `latest`, resource limits maiores, `restart: unless-stopped`

**UAT e PRD não fazem build** — usam `image:` apontando para o registry interno. O CD faz build e push; o webhook Portainer faz pull e redeploy.

### Web serving — nginx reverse proxy

O container `web` em produção/UAT usa **nginx** para servir o SPA e fazer proxy reverso para a API:

- `/` → serve `index.html` (SPA catch-all via `try_files`)
- `/api/*` → proxy para `http://api:3000` (backend)
- `/uploads/*` → proxy para `http://api:3000` (se houver uploads servidos pela API)
- Assets estáticos (`.js`, `.css`, `.woff2`, etc.) → cache 1 ano com `immutable`
- Security headers: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`
- `VITE_API_URL` deve ser `""` (vazio) — frontend faz requests same-origin, nginx roteia

Criar `apps/web/nginx.conf` com esta configuração. O Dockerfile do web copia o nginx.conf para `/etc/nginx/conf.d/default.conf`.

### Storage (S3-compatible — serviço externo)

Código da aplicação usa `@aws-sdk/client-s3` apontando para `S3_ENDPOINT`. Nunca usar filesystem local para uploads em prod. **Caveat**: SDK v3.729+ envia checksums que S3-compatible pode rejeitar — usar `requestChecksumCalculation: "WHEN_REQUIRED"` no client config.

**Em dev**: MinIO roda como container local no compose para desenvolvimento (service `minio`). **Em UAT/PRD**: MinIO é serviço externo centralizado no servidor de monitoramento, conexão via env vars do Portainer. Conexão via variáveis de ambiente seguindo o mesmo padrão do registry Docker:

```env
S3_ENDPOINT=           # URL do serviço S3 (ex: http://minio-host:9000)
S3_ACCESS_KEY=         # access key
S3_SECRET_KEY=         # secret key
S3_REGION=             # região (default: us-east-1)
S3_BUCKET=             # nome do bucket
S3_FORCE_PATH_STYLE=   # "true" para S3-compatible
```

Compose para Portainer — ver regras detalhadas em `start_project.md` Fase 4. Regras obrigatórias por service:

| Regra | Aplica a |
|---|---|
| `restart: unless-stopped` | todos |
| `deploy.resources.limits.memory` | todos (variar por ambiente: UAT menor, PRD maior) |
| `healthcheck` | postgres, redis (se houver) |
| `depends_on: condition: service_healthy` | api → postgres/redis, web → api |
| Portas via env var com default (`${API_PORT:-3000}`, `${WEB_PORT:-80}`) | todos |
| Volumes nomeados | postgres, redis (se houver) |
| `image: ${REGISTRY}/${APP_NAME}-{service}:{tag}` | api, web (UAT/PRD — nunca build local) |
| Service `backup` com `${REGISTRY}/backup-postgres:latest` | UAT/PRD (backup automático do PostgreSQL para MinIO) |
| Service `minio` (container local) | apenas dev (UAT/PRD usam MinIO central via env vars) |

## Production-readiness (obrigatório)

- **Health**: `GET /health` em toda API. Compose: `healthcheck` com `wget`
- **Graceful shutdown**: capturar SIGTERM, fechar conexões DB
- **Logs**: JSON stdout via `pino` com `requestId`. Nunca `console.log` em prod
- **CORS**: origins explícitas via `APP_CORS_ORIGINS`. Nunca `origin: '*'` em prod

## Backup PostgreSQL (obrigatório)

Todo projeto on-premises deve ter backup automático do PostgreSQL com envio para MinIO.

**Imagem**: `${REGISTRY}/backup-postgres:latest` — container sidecar que roda `pg_dump | gzip | mc pipe` em loop, enviando diretamente para o MinIO sem uso de disco local.

**Compose**: service `backup` obrigatório em todos os compose files (dev, UAT, PRD). Ver `start_project.md` Fase 4 para configuração completa.

| Ambiente | S3_ENDPOINT | Bucket | Retenção |
|---|---|---|---|
| Dev | `http://minio:9000` (container local, credenciais via `.env`) | `backup-${APP_NAME}-db` | via `.env` |
| UAT | `${S3_ENDPOINT}` (MinIO central, via Portainer UI) | `${S3_BACKUP_BUCKET}` (via Portainer UI) | via Portainer UI |
| PRD | `${S3_ENDPOINT}` (MinIO central, via Portainer UI) | `${S3_BACKUP_BUCKET}` (via Portainer UI) | via Portainer UI |

**Restore**: o mesmo container suporta restore via variáveis de ambiente:
- Listar backups: `docker compose run --rm -e MODE=restore backup`
- Restaurar: `docker compose run --rm -e MODE=restore -e RESTORE_FILE=<arquivo> backup`
- Antes de restaurar, parar services `api` e `web` para evitar escrita durante o restore

**MinIO em dev**: o compose de dev inclui um container MinIO local (`minio/minio:latest`) com credenciais via `.env` (`MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`), acessível em `http://localhost:${MINIO_PORT:-9000}` (API S3) e `http://localhost:${MINIO_CONSOLE_PORT:-9001}` (console web). Nunca hardcodar credenciais nos compose files, usar sempre `${VARIAVEL}` com valores definidos no `.env` (dev) ou Portainer UI (UAT/PRD).

## Background jobs (escala progressiva)

Escalar só quando necessário:

1. **Fire-and-forget** → `setTimeout` ou `queueMicrotask`. Nota: `c.executionCtx.waitUntil()` é exclusivo de Cloudflare Workers
2. **Jobs com retry/agendamento** → tabela `jobs` no Drizzle + `setInterval`. `Bun.cron` é OS-level (não funciona em containers)
3. **Filas robustas** (retry exponencial, concurrency, scheduling complexo) → pg-boss

Nunca começar pelo pg-boss. Só introduzir se os níveis 1-2 forem insuficientes.

## Auth middleware (Clerk) — graceful degradation

- **Pacotes**: `@clerk/react` v6+ (frontend) e `@hono/clerk-auth` v3+ (backend). Histórico: `@clerk/clerk-react` foi renomeado para `@clerk/react` no Core 2 (v5)
- **Clerk Core 3** (março 2026, v6+): `<Show when="signed-in">` substitui `<Protect>`/`<SignedIn>`/`<SignedOut>`. Upgrade: `npx @clerk/upgrade`
- **Core 3 breaking**: `getToken()` lança `ClerkOfflineError` (importar de `@clerk/react/errors`) quando offline — ainda retorna `null` se não autenticado; `@clerk/types` deprecated → importar de `@clerk/shared/types`
- Em **produção**, `CLERK_SECRET_KEY` é obrigatória — `clerkMiddleware()` é aplicado em `/api/*`
- Em **dev sem Clerk configurado**, o middleware deve ser condicional: só registrar se `CLERK_SECRET_KEY` existir no env
- Helpers de auth retornam `userId` fixo (`"dev-user"`) quando Clerk não está configurado — dev local sem auth real
- **No Hono, `getAuth(c)` é síncrono** — o middleware já populou o contexto
- Nunca deixar `clerkMiddleware()` crashar a API inteira por falta de env var
- **Padrão obrigatório**: registrar `clerkMiddleware()` dentro de `if (process.env.CLERK_SECRET_KEY)`. Nos handlers, `getAuth(c)` retorna o auth context (síncrono). Sem Clerk configurado, helper retorna `userId: "dev-user"`

## Dev workflow (Docker-first)

- **Tudo roda em container** — nunca no host (inclusive dev). `docker compose up` — arquivo único `docker-compose.yml` para dev local em todos os targets (Railway e Portainer)
- Bind-mount do código para hot reload. `bun install` dentro do container
- Lint, typecheck, test, build: `docker compose exec <service> <comando>`
- Portas via env var com defaults (`API_PORT`, `WEB_PORT`, `POSTGRES_PORT`). Se ocupada, incrementar +1
- **UAT/PRD**: deploy automático via CD → webhook Portainer. Nunca fazer deploy manual

## Git workflow

- **Branch strategy**: trunk-based com staging — `main` (produção), `uat` (homologação), feature branches curtas (`feat/`, `fix/`, `chore/`)
- **Fluxo**: feature branch → PR para `uat` → teste em UAT → merge para `main` → deploy PRD
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`)
- **PRs**: squash merge. CI deve passar antes de merge

| Branch | CI | CD | Ambiente |
|---|---|---|---|
| `main` | push + PR target | `cd-prd.yml` (após CI verde) | Produção |
| `uat` | push | `cd-uat.yml` (após CI verde) | Homologação |
| `feat/*` | PR para main/uat | nenhum | — |

## Testes

- Runner único: **bun test** (backend e frontend)
- **Cobertura mínima: >= 95%** — enforced via quality gate (domínio, validators, routes, auth, edge cases, error handling)
- **Security review por endpoint**: auth 401/403, injection (SQL/XSS), mass assignment (rejeitar `role`/`isAdmin`), rate limiting 429, CORS, headers (HSTS, X-Content-Type-Options, X-Frame-Options)
- Testes rodam no CI antes de build

## CI/CD — GitHub Actions

### CI (`ci.yml`)

Roda em push para `main` e `uat`, e em PRs para `main`.

```yaml
name: CI
on:
  push:
    branches: [main, uat]
  pull_request:
    branches: [main]

jobs:
  quality:
    runs-on: blacksmith-4vcpu-ubuntu-2404
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: oven-sh/setup-bun@v2
        with: { bun-version: latest }
      - run: bun install --frozen-lockfile
      - run: bun run lint                    # bunx biome check .
      - run: bun run typecheck               # tsc --noEmit
      - run: bun test --recursive --coverage --coverage-reporter lcov --coverage-dir ./coverage
      - uses: SonarSource/sonarqube-scan-action@v6
        env: { SONAR_TOKEN: "${{ secrets.SONAR_TOKEN }}" }
```

**SonarQube**: `sonar-project.properties` na raiz. Quality gate: coverage >= 95%.

### CD — Deploy Portainer (`cd-uat.yml` / `cd-prd.yml`)

CD **nunca** roda diretamente em push — é acionado via `workflow_run` após CI verde. Isso garante que código quebrado jamais chegue a UAT ou PRD.

**Mecanismo**: `workflow_run` com `types: [completed]` + guard `if: github.event.workflow_run.conclusion == 'success'`.

```yaml
# cd-uat.yml — deploy para homologação
name: Deploy UAT
on:
  workflow_run:
    workflows: ['CI']
    branches: [uat]
    types: [completed]

jobs:
  deploy-api:
    if: github.event.workflow_run.conclusion == 'success'
    uses: masterboiteam/.github/.github/workflows/deploy-uat.yml@main
    with:
      app_name: ${{ vars.APP_NAME }}-api
      registry: ${{ vars.INTERNAL_REGISTRY }}
      dockerfile: apps/api/Dockerfile
      skip_deploy: true           # build + push, mas NÃO dispara webhook ainda
    secrets:
      PORTAINER_WEBHOOK_UAT: ${{ secrets.PORTAINER_WEBHOOK_UAT }}

  deploy-web:
    needs: deploy-api               # web só deploya após API estar no registry
    uses: masterboiteam/.github/.github/workflows/deploy-uat.yml@main
    with:
      app_name: ${{ vars.APP_NAME }}-web
      registry: ${{ vars.INTERNAL_REGISTRY }}
      dockerfile: apps/web/Dockerfile
    secrets:
      PORTAINER_WEBHOOK_UAT: ${{ secrets.PORTAINER_WEBHOOK_UAT }}
      BUILD_SECRETS: |
        VITE_CLERK_PUBLISHABLE_KEY=${{ secrets.VITE_CLERK_PUBLISHABLE_KEY }}
```

```yaml
# cd-prd.yml — deploy para produção (mesmo padrão, branch main)
name: Deploy PRD
on:
  workflow_run:
    workflows: ['CI']
    branches: [main]
    types: [completed]
# ... mesma estrutura, usando deploy-prd.yml e PORTAINER_WEBHOOK_PRD
```

**Regras obrigatórias do CD**:

| Regra | Detalhe |
|---|---|
| CD só roda após CI verde | `workflow_run` + `conclusion == 'success'` — nunca trigger direto em push |
| Branches permitidas | `uat` → `cd-portainer-uat.yml`, `main` → `cd-portainer-prd.yml`. Nenhum outro branch dispara CD |
| Runner | Self-hosted on-prem: UAT usa `[self-hosted, onprem, uat]`, PRD usa `[self-hosted, onprem, prd]` — não GitHub-hosted |
| Ordem de deploy | API primeiro (`skip_deploy: true` = build+push sem webhook), depois Web (dispara webhook que atualiza a stack inteira) |
| Reusable workflows | Usar workflows do org repo (`masterboiteam/.github`) para padronizar build/push/webhook |
| Image tags | UAT: `uat-{sha}` + `uat-latest`. PRD: `{sha}` + `latest`. Nunca misturar tags entre ambientes |
| Build context | Sempre `.` (raiz do repo) para Dockerfiles em `apps/*/` que precisam de `packages/shared` |
| Build args públicos | Usar `build_args` do reusable workflow (multiline `KEY=VALUE`) para args não-sensíveis |
| Build secrets (Web) | `VITE_*` injetadas via `BUILD_SECRETS` como build args do Docker — embutidas no bundle JS em build time |
| Webhook Portainer | Após push da imagem, o reusable workflow chama o webhook para Portainer redeployar a stack |
| PRD environment | O reusable `deploy-prd.yml` usa `environment: production` (aprovação manual se configurada no GitHub) |
| Cleanup automático | Reusable workflows rodam `docker image prune -f` após cada deploy (UAT: 72h, PRD: 168h) |

**Inputs do reusable workflow** (`deploy-uat.yml` / `deploy-prd.yml`):

| Input | Obrigatório | Default | Descrição |
|---|---|---|---|
| `app_name` | ✅ | — | Nome da imagem: `{APP_NAME}-api` ou `{APP_NAME}-web` |
| `registry` | ✅ | — | Endereço do registry: `${{ vars.INTERNAL_REGISTRY }}` |
| `dockerfile` | ❌ | `Dockerfile` | Caminho do Dockerfile (ex: `apps/api/Dockerfile`) |
| `build_context` | ❌ | `.` | Contexto do build — sempre `.` em monorepo |
| `build_args` | ❌ | `''` | Build args públicos (multiline `KEY=VALUE`) |
| `skip_deploy` | ❌ | `false` | `true` = build+push sem webhook (API na ordem de deploy) |

**Secrets do reusable workflow**:

| Secret | Descrição |
|---|---|
| `PORTAINER_WEBHOOK_UAT` / `PORTAINER_WEBHOOK_PRD` | URL do webhook Portainer |
| `BUILD_SECRETS` | Build args sensíveis (ex: `VITE_CLERK_PUBLISHABLE_KEY=...`) |

**Secrets e vars obrigatórias no GitHub**:

| Tipo | Escopo | Nome | Descrição |
|---|---|---|---|
| var | organização | `APP_NAME` | Nome do app (prefixo das imagens: `{APP_NAME}-api`, `{APP_NAME}-web`) |
| var | organização | `INTERNAL_REGISTRY` | Endereço do registry Docker privado |
| secret | repositório | `SONAR_TOKEN` | Token SonarCloud/SonarQube |
| secret | repositório | `PORTAINER_WEBHOOK_UAT` | URL do webhook Portainer stack UAT |
| secret | repositório | `PORTAINER_WEBHOOK_PRD` | URL do webhook Portainer stack PRD |
| secret | repositório | `VITE_CLERK_PUBLISHABLE_KEY` | Clerk publishable key (injetada no build do frontend) |

**Nota**: `APP_NAME` e `INTERNAL_REGISTRY` são vars da **organização** — disponíveis em todos os repos sem configuração por repo.

**Segurança em workflows**: nunca interpolar `${{ github.event.* }}` diretamente em `run:` (command injection). Usar `env:` + variável shell. Ver regra 35.

Scripts obrigatórios no root `package.json`:
- `lint` → `bunx biome check .`
- `typecheck` → `bun run --filter='*' typecheck`
- `test` → `bun test`
- `test:coverage` → `bun test --coverage` (usado no CI)
- `build` → build de cada app
- `dev` → dev de cada app com HMR
- `db:generate` → `drizzle-kit generate`
- `db:migrate` → `drizzle-kit migrate`

### Loop de autocorreção pós-push (obrigatório)

Após cada push, verificar GitHub Actions. Máximo **7 tentativas** até CI verde.

1. Push → aguardar CI
2. Passou → concluído (CD dispara automaticamente via `workflow_run`)
3. Falhou → identificar step quebrado → logar `step → causa → correção` → fix → push
4. Repetir até verde ou 7 tentativas
5. Se 7 tentativas: parar, reportar resumo das tentativas + erro persistente + próximos passos

Nunca considerar tarefa finalizada com CI vermelho. CD bloqueado automaticamente quando CI falha.

### Rollback (Portainer)

Se um deploy quebrar produção:

1. Identificar SHA anterior: GitHub Actions history do CD ou `docker images` no registry
2. No Portainer, editar a stack PRD e trocar tag `latest` pelo SHA anterior:
   - `${REGISTRY}/${APP_NAME}-api:latest` → `${REGISTRY}/${APP_NAME}-api:{sha}`
   - `${REGISTRY}/${APP_NAME}-web:latest` → `${REGISTRY}/${APP_NAME}-web:{sha}`
3. Portainer faz pull e reinicia (ou acionar webhook manualmente se necessário)
4. Após estabilizar: criar `hotfix/` branch, corrigir, seguir fluxo normal `uat` → `main`

> Tags SHA ficam no registry por 168h em PRD e 72h em UAT (cleanup automático do CD).
> UAT: mesma lógica com tag `uat-latest` → `uat-{sha}`.

## Planejamento

Projeto novo → seguir `start_project.md`. Feature nova ou dependência desconhecida → consultar context7 MCP para documentação de API/sintaxe (ou docs oficiais). Para versão latest de pacotes, usar `bun info <pacote>` (requer `package.json` no diretório — se falhar, usar `npm view <pacote> version` como fallback) — context7 não é confiável como fonte de versão. Nunca assumir APIs, subpaths ou compatibilidade de versão de memória — sempre verificar.

## Regras para IA

1. Todo tipo/schema novo nasce em `packages/shared` — nunca redefinir
2. **Imports monorepo**: apps importam de `@projeto/shared`, nunca codigo runtime entre si. Unica excecao: `import type` do AppType (ver seção "Monorepo Architecture")
3. Componentes UI → shadcn/ui. Nunca criar do zero se existe equivalente
4. Data fetching → TanStack Query + Hono RPC client tipado (`hc<AppType>`). Nunca fetch manual solto
5. DB changes → migration Drizzle (`bun run db:generate && bun run db:migrate`)
6. Estilos → Tailwind classes. Nunca CSS inline ou arquivos .css avulsos
7. Informar contexto de workspace ao modificar (`apps/web`, `apps/api`, `packages/shared`)
8. Priorizar economia de recursos: evitar dependências pesadas, preferir libs leves
9. Dockerfile sempre multi-stage. Imagem final sem devDeps
10. Compose para Portainer: seguir tabela de regras em "Deploy: dois targets"
11. **Versões alinhadas**: pacotes do mesmo ecossistema (`@clerk/*`, `@tanstack/*`, `@hono/*`) devem usar a mesma major. Verificar compatibilidade antes de instalar/atualizar
12. **Nunca `sql.raw()` com input externo** — usar placeholders parametrizados. Em `sql` tagged templates, converter `Date` com `.toISOString()` antes de interpolar
13. **API response format**: seguir rigorosamente a seção "API response format". Nunca retornar sem envelope `{ data }`
14. Commits seguem Conventional Commits. Branches seguem o padrão `feat/`/`fix/`/`chore/`
15. **Storage sempre via S3 SDK** (`@aws-sdk/client-s3` + `S3_ENDPOINT` env var). Nunca salvar uploads no filesystem local em prod. **Em dev**: MinIO roda como container local no compose (service `minio`) — credenciais via `.env`, nunca hardcoded. **Em UAT/PRD**: MinIO é serviço externo centralizado — conexão via env vars do Portainer, nunca container no compose de produção
16. **Projeto novo**: se o repositório não contém `apps/` ou `packages/shared/`, considerar projeto novo. Ler e executar `start_project.md` **antes de qualquer outra ação**
17. **Nullable fields**: colunas Drizzle sem `.notNull()` produzem `T | null` no TypeScript. Frontend **deve** tratar nulls explicitamente (ex: `user.firstName || ""`, `user.avatarUrl ?? undefined`)
18. **shadcn/ui — verificar antes de usar**: conferir o código real em `src/components/ui/<componente>.tsx` antes de passar props. Variantes não-padrão não existem — usar `className`
19. **Contrato API-Frontend**: antes de construir o frontend, verificar responses reais da API (via curl ou tests). Nunca inventar campos ou assumir transformações. Ver seção "API response format"
20. **Tooling version sync**: após instalar/atualizar Biome (agora 2.x), rodar `bunx biome migrate --write`. Nunca hardcodar versão do schema sem verificar
21. **Clerk condicional**: nunca `clerkMiddleware()` sem checar `CLERK_SECRET_KEY`. `getAuth(c)` é síncrono no Hono. Ver seção "Auth middleware"
22. **CI verde obrigatório**: ver seção "Loop de autocorreção pós-push". Nunca considerar tarefa concluída com CI vermelho
23. **Tailwind v4 CSS-first**: não criar `tailwind.config.js` — usar `@import "tailwindcss"` + `@theme { }` no CSS e `@tailwindcss/vite` plugin no Vite. Ver seção "Tailwind CSS v4"
24. **React Router v7 — pacote unificado**: instalar `react-router` (não `react-router-dom`, que foi descontinuado)
25. **Zustand v5 — named exports**: usar `import { create } from 'zustand'` (default export removido no v5)
26. **Zod v4 + Drizzle**: dois cenários conforme a versão do drizzle-orm: **Stable (0.45.x)**: usar pacote `drizzle-zod` (v0.8.3+, já suporta Zod v4 nativamente) — `import { createInsertSchema, createSelectSchema } from 'drizzle-zod'`. **Beta (≥1.0.0-beta.15)**: usar `drizzle-orm/zod` integrado (standalone `drizzle-zod` deprecated nesta versão) — `import { createInsertSchema, createSelectSchema } from 'drizzle-orm/zod'`. Com React Hook Form: usar `z.input<typeof schema>` no useForm (não `z.infer`)
27. **Vite 8 (Rolldown)**: `build.rollupOptions` substituído por `build.rolldownOptions` (auto-conversão existe para backward compat, mas usar `rolldownOptions` em projetos novos). `resolve.tsconfigPaths: true` elimina `vite-tsconfig-paths`. Node ≥20.19 ou ≥22.12 (21.x e 22.0-22.11 não suportados)
28. **Drizzle config**: `defineConfig` de `drizzle-kit`. Comandos: `generate`, `migrate`, `push`, `pull`, `check`, `up`, `studio`
29. **Hono validator + Zod v4**: preferir `@hono/standard-validator` (`sValidator`) — suporta qualquer lib via Standard Schema (Zod, Valibot, ArkType). `@hono/zod-validator` funciona com Zod v4 desde v0.7.6+, mas `standard-validator` é mais genérico e futuro-proof
30. **Biome 2.x**: `include`/`ignore` → `includes`. Suppression: `// biome-ignore lint/group/rule:` (com `/`, não `()`)
31. **shadcn/ui Radix unificado** (fev 2026): pacote `radix-ui` substitui `@radix-ui/react-*`. Verificar com `bunx shadcn@latest diff`
32. **Verificar antes de afirmar inexistência**: antes de dizer que um pacote, subpath, API ou feature não existe em determinada versão, **verificar** usando context7 MCP (para documentação de API/sintaxe — não confiar em versões reportadas), `bun info <pacote>` (para versão latest real), docs oficiais ou `node_modules/<pacote>/package.json` (campo `exports`). Nunca migrar para versão beta, deprecated ou alternativa sem confirmar com o usuário primeiro. Se a verificação falhar (ex: subpath não exportado), informar o resultado exato e perguntar como proceder
33. **Instalar pacotes com `bun add`, nunca escrever versões manualmente**: ao adicionar dependências, usar `bun add <pacote>` (resolve a latest automaticamente). **Nunca** editar `package.json` à mão com versões inventadas (ex: `"^0.3.0"` quando a latest é `0.2.x`). Se precisar de versão específica: `bun add <pacote>@<versão>` — e verificar que a versão existe antes via `bun info <pacote>`
34. **Diagnosticar antes de corrigir**: ao encontrar um erro de build/typecheck/runtime, **ler o arquivo e a linha exata do erro** antes de tentar qualquer fix. Rastrear a cadeia de tipos/imports até a causa raiz. Nunca adivinhar a causa pelo texto do erro e mexer em arquivos não relacionados (ex: erro de tipo `unknown` no RPC client → ler o arquivo do hook e o setup do client, não mexer em `tsconfig.json` ou `vite-env.d.ts`)
35. **GitHub Actions — segurança obrigatória**: nunca usar input não-confiável (`github.event.issue.title`, `github.event.pull_request.body`, `github.event.comment.body`, commit messages) diretamente em `run:`. Passar via `env:` com quoting. Padrão seguro: `env: TITLE: ${{ github.event.issue.title }}` → `run: echo "$TITLE"`. Ref: https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/
36. **Context7 MCP — escopo de confiança**: context7 é confiável para documentação de API, sintaxe, exemplos de uso e breaking changes. **Não é confiável para versão latest** de pacotes — pode reportar versões defasadas. Para verificar versão atual: `bun info <pacote>` (requer `package.json` no diretório; fallback: `npm view <pacote> version`). Para documentação/como usar: context7 MCP. Para fallback de ambos: docs oficiais via web
37. **CD nunca roda direto em push** — sempre via `workflow_run` após CI verde. Guard obrigatório: `if: github.event.workflow_run.conclusion == 'success'`. CD sem este guard é deploy cego
38. **CD só em `uat` e `main`** — `cd-uat.yml` escuta branch `uat`, `cd-prd.yml` escuta branch `main`. Nenhum outro branch dispara CD
39. **Deploy order**: API primeiro com `skip_deploy: true` (build+push sem webhook), depois Web (dispara webhook que atualiza a stack). Nunca inverter — frontend pode depender da nova API
40. **Image tags por ambiente**: UAT usa `uat-latest`, PRD usa `latest`. Nunca misturar tags entre ambientes
41. **Build secrets do frontend**: `VITE_*` são variáveis de build (embutidas no bundle pelo Vite). Passar via `BUILD_SECRETS` no CD, não como env var runtime. nginx não tem acesso a env vars
42. **Três compose files**: `docker-compose.yml` (dev, build local), `docker-compose-uat.yml` (imagens do registry com tag `uat-latest`), `docker-compose-prd.yml` (imagens do registry com tag `latest`). UAT/PRD nunca fazem build local
43. **nginx reverse proxy**: Web em UAT/PRD usa nginx. `VITE_API_URL` deve ser `""` (vazio) — frontend faz requests same-origin, nginx roteia `/api/*` para o container `api`. Criar `apps/web/nginx.conf`
44. **Compose UAT/PRD: nunca `.env` file** — Portainer Stacks não processam arquivos `.env`, quebrando o deploy. Compose de UAT e PRD devem usar `${VARIAVEL}` com valores configurados na UI do Portainer. `.env` é permitido apenas no compose de dev local
45. **Service backup obrigatório** em todos os compose files (dev, UAT, PRD). Imagem: `${REGISTRY}/backup-postgres:latest`. Em dev, MinIO roda como container local (service `minio`). Em UAT/PRD, MinIO é serviço externo via env vars do Portainer. Nunca hardcodar credenciais nos compose files — usar sempre `${VARIAVEL}` com valores definidos no `.env` (dev) ou Portainer UI (UAT/PRD)
46. **Credenciais nunca hardcoded** em compose files. Mesmo em dev, usar `${MINIO_ROOT_USER}`, `${MINIO_ROOT_PASSWORD}`, etc. com valores no `.env`. O `.env.example` deve listar todas as variáveis com valores de exemplo
