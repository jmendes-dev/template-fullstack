---
name: master-deploy
description: Gera arquivos de deploy de produção (railway.toml ou docker-compose.yml + Dockerfile multi-stage) após perguntar o target obrigatoriamente. Valida resource budget (≤256MB), healthchecks, security headers e env vars. Usar quando o usuário disser "configurar deploy", "deploy em prod", "gerar railway.toml", "gerar docker-compose prod", "primeiro deploy" ou "publicar".
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

Esta skill formaliza a regra 32 do `CLAUDE.md` (**nunca assumir Railway ou Portainer — perguntar**), o budget de ≤256MB por container, e os requisitos de production-readiness (health endpoints, secure headers, rate limiting, CORS).

Toda comunicação em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de qualquer pergunta:

1. Ler `CLAUDE.md` — especialmente regras 9 (Dockerfile multi-stage), 14 (storage S3), 32 (deploy target), seções "Deploy: dois targets", "Production-readiness", "Resource efficiency"
2. Ler `docs/deploy-railway.md` e `docs/deploy-portainer.md` por completo
3. Ler `docs/env-vars.md` — lista canônica de envs
4. Ler `docs/storage-s3.md` — endpoints por ambiente
5. Inspecionar repo: `apps/api/`, `apps/web/`, `packages/shared/`. Se algum não existe, parar e apontar para `START_PROJECT.md`
6. Verificar arquivos já existentes: `railway.toml`, `docker-compose.yml`, `apps/*/Dockerfile`
7. `git status` — working tree limpo

---

## Passo 1 — Perguntar o target (obrigatório)

**Não assumir.** Mesmo se o repo já tem `railway.toml` ou `docker-compose.yml` na raiz, confirmar:

> "Antes de gerar arquivos de deploy, preciso do target. Qual destes?
>
> 1. **Railway** (PaaS) — Postgres addon + Railway Buckets, sem Traefik/MinIO no projeto
> 2. **Portainer** (on-premises) — Postgres em container + MinIO + Traefik na stack shared
>
> Se o projeto vai para os dois, gero os dois agora ou priorizamos um?"

Aguardar resposta. Se o usuário responder com termos ambíguos ("o que for melhor", "tanto faz"), explicar o trade-off:

- Railway: setup rápido, custo recorrente por serviço, ideal para times pequenos / MVP
- Portainer: infra controlada, custo de hardware/operação, ideal para empresa com on-premises

**Se o usuário não escolhe, parar.** Não gerar config.

---

## Passo 2 — Coletar contexto adicional

Conforme o target:

### Se Railway

> 1. Domínio custom? (ex: `api.<seu-dominio.com>`) — ou usar `*.up.railway.app` por enquanto?
> 2. Bucket Railway já criado? Se sim, qual o nome (`S3_BUCKET`)?
> 3. Plano (Hobby / Pro)? Pro permite réplicas
> 4. Pre-deploy command vai rodar migrations? (default: sim, `bun run db:migrate`)

### Se Portainer

> 1. Nome da stack (ex: `masterboi-prod`)?
> 2. Domínios (`api.<seu-dominio.com>` / `app.<seu-dominio.com>`)?
> 3. Nome da rede externa do Traefik (geralmente `traefik-net`)?
> 4. Resolver TLS configurado no Traefik (ex: `letsencrypt`)?
> 5. Modo do host: Docker Compose ou Swarm? (afeta `mem_limit` vs `deploy.resources`)

---

## Passo 3 — Gerar arquivos

### 3.1 — Dockerfile multi-stage (regra 9)

Criar `apps/api/Dockerfile` e `apps/web/Dockerfile`. Padrão multi-stage com `oven/bun:1.3` no build e `oven/bun:1.3-slim` no runtime (`distroless` não tem variante oficial para Bun — exigiria binário pré-compilado separado). **Sem devDependencies na imagem final.**

Referência: `docs/deploy-railway.md` seção "Dockerfile de produção" — o mesmo padrão funciona em ambos os targets.

Mostrar o conteúdo antes de criar:

> "Vou criar `apps/api/Dockerfile` com este conteúdo:
>
> ```dockerfile
> [conteúdo]
> ```
>
> E `apps/web/Dockerfile` (Vite build + servir estáticos):
>
> ```dockerfile
> [conteúdo]
> ```
>
> Posso criar?"

### 3.2 — Arquivo de orquestração

#### Railway

`apps/api/railway.toml` e `apps/web/railway.toml`. Exemplo em `docs/deploy-railway.md`. Pre-deploy command + healthcheck path obrigatórios.

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

**Antes de gerar**, ler `apps/api/package.json` e confirmar que os scripts `db:migrate` e `data-migrate` existem. Se algum estiver ausente:

- `db:migrate` ausente → parar, mandar o usuário rodar `bunx drizzle-kit migrate` manualmente ou criar o script primeiro (ver `docs/data-migrations.md`)
- `data-migrate` ausente → ou criar o runner conforme `docs/data-migrations.md` Seção "Runner", ou remover do `preDeployCommand` deixando só `bun run db:migrate`. Não gerar TOML referenciando script inexistente — pre-deploy falha e bloqueia todos os deploys futuros.

#### Portainer

`docker-compose.yml` na raiz (não confundir com `docker-compose.dev.yml`). Conteúdo segue o padrão de `docs/deploy-portainer.md`:

- `postgres`, `minio`, `api`, `web` services
- `restart: unless-stopped`
- `mem_limit: 256m` (ou `deploy.resources.limits.memory: 256M` se Swarm)
- `healthcheck` em todos
- `depends_on: condition: service_healthy`
- Traefik labels com domínios coletados no Passo 2
- `networks: traefik-net: external: true`
- `logging.options.max-size: 10m, max-file: 5`

### 3.3 — Lista de env vars

Gerar lista completa (do `docs/env-vars.md`) — diferenciada por target:

#### Railway

Cada service Railway tem **suas próprias** env vars. Não misturar `api` e `web` no mesmo bloco.

##### Service: `api`

Aba `Variables` → `Raw Editor`:

```env
CLERK_SECRET_KEY=sk_live_...
APP_CORS_ORIGINS=https://app.<seu-dominio.com>     # substituir pelo domínio real do projeto
SENTRY_DSN=https://...                            # opcional
RESEND_API_KEY=re_...                             # opcional, se enviar email

# DATABASE_URL: linkado do Postgres addon (Add Reference → Postgres.DATABASE_URL)
# S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET: linkados do Railway Bucket
#   (Add Reference → Bucket.BUCKET_ENDPOINT etc, com remap para os nomes S3_*)
# PORT: NÃO setar (Railway injeta dinamicamente)
```

##### Service: `web`

Aba `Variables` → `Raw Editor`:

```env
VITE_API_URL=https://api.<seu-dominio.com>        # substituir pelo domínio real do projeto
VITE_CLERK_PUBLISHABLE_KEY=pk_live_...
VITE_SENTRY_DSN=https://...                       # opcional

# PORT: NÃO setar
# Sem secrets de backend aqui — frontend só vê VITE_*
```

Avisar o usuário: vars `VITE_*` ficam **embutidas no bundle** após o build. Mudá-las exige redeploy.

#### Portainer — `.env.production` (não commitar)

```env
# Postgres (container) — credenciais
POSTGRES_USER=...
POSTGRES_PASSWORD=...
POSTGRES_DB=...

# Auth
CLERK_SECRET_KEY=sk_live_...
VITE_CLERK_PUBLISHABLE_KEY=pk_live_...

# URLs públicas — substituir pelo domínio real do projeto
VITE_API_URL=https://api.<seu-dominio.com>
APP_CORS_ORIGINS=https://app.<seu-dominio.com>

# Storage (MinIO no compose)
# S3_ENDPOINT NÃO vai aqui — é definido no compose como `S3_ENDPOINT: http://minio:9000`
# (rede interna do compose, não acessível por env do host)
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_BUCKET=uploads
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=...

# Portas (mapeamento host → container)
PORT=3000           # Portainer/compose: setar explicitamente (ao contrário de Railway)
WEB_PORT=4000
PGPORT=5432
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
```

**Avisar explicitamente**: `S3_ENDPOINT` é injetado pelo `docker-compose.yml` no service `api` (`environment: { S3_ENDPOINT: http://minio:9000 }`) — **não** entra no `.env.production`. Setá-lo no `.env` cria conflito de fonte e quebra a resolução interna do compose.

### 3.4 — Bucket no Storage (criar uma vez)

Procedimento centralizado em `docs/storage-s3.md` seção "Operações comuns por ambiente". Apontar o usuário para o procedimento conforme target.

---

## Passo 4 — Validações de production-readiness

Antes de declarar "pronto para deploy", checar no código (e avisar se faltar):

| Check | Onde olhar | Critério |
|---|---|---|
| Health endpoints | `apps/api/src/index.ts` ou rotas | `/health`, `/ready`, `/live` respondem 200 — ver `docs/observability.md` |
| Secure headers | middleware Hono | `secureHeaders()` ativo + CSP — ver `docs/security-headers.md` |
| Rate limiting | middleware Hono | `hono-rate-limiter` em rotas mutativas — ver `docs/rate-limiting.md` |
| CORS | middleware Hono | origins explícitas via `APP_CORS_ORIGINS`, **nunca** `*` em prod |
| Graceful shutdown | `apps/api/src/index.ts` | SIGTERM handler fecha conexões DB |
| Logs estruturados | middleware | `pino` JSON com `requestId` — não `console.log` |
| Error tracking | `apps/api/src/index.ts` | Sentry condicional em `SENTRY_DSN` (opcional) |
| Resource budget | imagem buildada | rodar `docker images` após build, target ≤256MB RAM em runtime |
| Multi-stage | Dockerfile | `FROM ... AS builder` + `FROM ... AS runtime` sem devDeps |
| Backup configurado | runbook | ver `docs/backup-restore.md` — automatizar antes de prod |
| Storage | grep `fs.writeFile\|fs.createWriteStream` em paths de upload | Nunca filesystem local — usar `@aws-sdk/client-s3` (regra 14) |
| Background jobs | grep `Bun.cron` no container | `Bun.cron` OS-level (≤1.3.11, latest em abr/2026) não funciona em container — usar `setInterval`. `Bun.cron()` in-process (≥1.3.12, não lançado) será alternativa futura. Ver `docs/bun-notes.md` |

Listar check-by-check para o usuário:

> "Production-readiness:
> - [✅/❌] Health endpoints (`/health`, `/ready`, `/live`)
> - [✅/❌] Secure headers + CSP
> - [✅/❌] Rate limiting nas rotas mutativas
> - [✅/❌] CORS com origins explícitas
> - [✅/❌] Graceful shutdown
> - [✅/❌] Logs JSON estruturados
> - [✅/❌] Multi-stage Dockerfile
>
> Faltando: [lista]. Resolvo agora ou aceitamos como gap conhecido?"

---

## Passo 5 — Validar build local

Antes de empurrar para Railway/Portainer, validar que o build funciona:

```bash
docker build -f apps/api/Dockerfile -t test-api .
docker images test-api --format '{{.Size}}'   # alvo: imagem ≤200MB
docker run --rm -e DATABASE_URL=... -p 3000:3000 test-api
curl http://localhost:3000/health             # { "status": "ok" }
```

Mesmo para `apps/web`. Se o build falha, parar — não gerar config quebrada.

---

## Passo 6 — Secrets

Listar secrets a configurar antes do primeiro deploy:

### GitHub Actions (CI)

```sh
gh secret set DATABASE_URL_TEST    # CI test DB (não prod)
gh secret set SONAR_TOKEN          # se usa SonarQube
# Não setar secrets de prod no GitHub — eles vivem no Railway/Portainer
```

### Railway

Dashboard → Variables → adicionar manualmente (ou via CLI: `railway variables set KEY=value`).

### Portainer

Aba `Environment variables` da stack — modo `Advanced` permite colar bloco do `.env.production`.

**Nunca commitar secrets.** Se detectar `.env*` no `git status`, alertar antes de qualquer commit.

---

## Passo 7 — Documentar e fechar

Gerar resumo:

> "Configuração de deploy gerada para **[target]**.
>
> Arquivos criados/modificados:
> - [lista]
>
> Próximos passos:
> 1. [se Railway] Setar env vars no dashboard do projeto
> 2. [se Railway] Linkar Postgres addon e Railway Bucket
> 3. [se Portainer] Subir stack via UI ou `docker compose up -d`
> 4. Validar `/health` no domínio público
> 5. Configurar backup conforme `docs/backup-restore.md`
> 6. Configurar alertas conforme `docs/observability.md`
>
> Production-readiness: **[N de M checks verdes]**. Gaps: [lista, se houver]."

---

## Notas para o assistente

### Regra 32 — sempre perguntar

Mesmo que o repo já tenha indícios (ex: `railway.toml` antigo), **perguntar de novo**. Targets podem mudar entre features, e gerar config errada é caro de reverter.

### Não tocar `.env*`

Nunca criar `.env.production` com valores reais — só template com placeholders. O usuário preenche manualmente.

### Resource budget é hard

≤256MB RAM por container. Se o build estourar (`docker stats` mostra >256MB no boot), investigar:
- devDependencies vazaram para runtime?
- bundle do web não foi minificado?
- alguma lib pesada (puppeteer, sharp full) sem propósito claro?

Não relaxar o limite sem aprovação explícita.

### Idioma

Toda comunicação em **português do Brasil**. Frase curta antes de cada Passo.

### Quando pular esta skill

Se o usuário está fazendo deploy incremental (já tem tudo configurado, só está empurrando código novo), esta skill é overkill. Use só para:
- Primeiro deploy do projeto
- Mudança de target (Railway → Portainer ou vice-versa)
- Adição de novo service (ex: worker, cron, sidecar)
