# Variáveis de ambiente obrigatórias

Ler ao criar `.env.example`, configurar Railway Variables ou Portainer Stacks, ou debugar problemas de configuração.

## Comuns (cloud e on-premise)

```env
# Banco
DATABASE_URL=                 # connection string PostgreSQL

# Auth (Clerk)
CLERK_SECRET_KEY=             # backend
VITE_CLERK_PUBLISHABLE_KEY=   # frontend (build-time)

# API ↔ Web
VITE_API_URL=                 # URL da API para o frontend (ver "VITE_API_URL por target" abaixo)
APP_CORS_ORIGINS=             # origins permitidas (ex: https://app.exemplo.com)
PORT=                         # porta da API (ver "PORT por target" abaixo)
WEB_PORT=                     # porta do frontend

# Storage (S3 / MinIO)
S3_ENDPOINT=                  # ver "S3 vars por target" abaixo
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_REGION=                    # default: us-east-1 (dummy — MinIO ignora)
S3_BUCKET=                    # bucket de uploads
S3_FORCE_PATH_STYLE=true      # obrigatório para MinIO
```

Arquivos: `.env.example` (committado, sem valores de secret), `.env` (local, nunca commitar).

**Em Railway**: todas as vars via Railway dashboard → Variables. Nunca arquivos `.env` em prod.

**Em Portainer (on-premise UAT/PRD)**: nada de `.env` files — Portainer Stacks não processam `.env`. Todas as variáveis via Portainer UI (sintaxe `${VAR}` no compose).

---

## Variáveis on-premise only (Portainer)

Quando deploy target = Portainer, adicionar:

### MinIO local (apenas dev)

```env
MINIO_ROOT_USER=              # credencial root do MinIO local
MINIO_ROOT_PASSWORD=
MINIO_PORT=                   # default: 9000
MINIO_CONSOLE_PORT=           # default: 9001
```

Em UAT/PRD, `MINIO_*` **não se aplica** (MinIO é central, credenciais chegam via `S3_*` do Portainer UI).

### Registry interno

```env
REGISTRY=                     # ex: registry.masterboi.local
APP_NAME=                     # nome do app (usado nas tags de imagem e no backup)
```

`REGISTRY` vem de `INTERNAL_REGISTRY` (variable da org no GitHub) durante CI/CD, e como variable da stack no Portainer.

### Backup PostgreSQL

```env
S3_BACKUP_BUCKET=             # ex: backup-${APP_NAME}-db
BACKUP_RETENTION_DAYS=        # dev: 7 | UAT: 14 | PRD: 30+
BACKUP_INTERVAL=              # segundos entre backups; default: 86400 (24h)
```

Detalhes em `docs/backup-restore.md`.

### Hostnames Traefik (labels)

```env
APP_HOST_UAT=                 # ex: meu-app-uat.masterboi.local
APP_HOST_PRD=                 # ex: meu-app.masterboi.local
```

Referenciados nos labels Traefik dos composes UAT/PRD.

---

## PORT por target

`PORT` se comporta diferente em cada deploy target:

- **Dev (docker-compose)**: `PORT` no `.env` controla o mapeamento de porta; dentro do container, app lê `process.env.PORT` vindo do compose.
- **Railway**: **NÃO** setar `PORT`. Railway injeta `PORT` dinamicamente a cada deploy — hardcodar quebra o roteamento. Ver `docs/deploy-railway.md`.
- **Portainer (on-premise)**: API ouve internamente em `3000` (fixo), porta **não publicada no host** — Traefik roteia via rede Docker interna. Web ouve em `80` (nginx) — também não publicada. Ver `docs/deploy-portainer.md` e `docs/web-nginx.md`.

App lê com fallback:

```typescript
Bun.serve({ port: Number(process.env.PORT) || 3000 });
```

---

## VITE_API_URL por target

`VITE_API_URL` é **compile-time** — Vite substitui no bundle no momento do `bun run build`. Setar em runtime (Railway/Portainer) **não tem efeito** na imagem já buildada.

- **Railway**: passar como build arg no `railway.toml` ou via `--build-arg`, valor = URL absoluta da API (ex: `https://api.meu-app.up.railway.app`).
- **Portainer (on-premise)**: **`VITE_API_URL=""`** (vazio) em UAT/PRD — nginx do container web faz proxy same-origin de `/api/*` para a API. Ver `docs/web-nginx.md`.
- **Dev**: normalmente `""` também (Vite proxy configurado em `vite.config.ts`).

---

## S3 vars por target

| Var | Dev (on-prem, MinIO local) | UAT/PRD (on-prem, MinIO central) | Railway (Buckets) |
|---|---|---|---|
| `S3_ENDPOINT` | `http://minio:9000` (compose) | valor via Portainer UI (ex: `http://minio-central.masterboi.local:9000`) | injetado: `$BUCKET_ENDPOINT` |
| `S3_ACCESS_KEY` | `MINIO_ROOT_USER` | credencial do projeto no MinIO central (via Portainer UI) | injetado: `$BUCKET_ACCESS_KEY_ID` |
| `S3_SECRET_KEY` | `MINIO_ROOT_PASSWORD` | credencial do projeto no MinIO central | injetado: `$BUCKET_SECRET_ACCESS_KEY` |
| `S3_BUCKET` | `uploads` ou `${APP_NAME}-uploads` | `${APP_NAME}-uploads` (criado pela infra) | injetado: `$BUCKET_NAME` |

Em Railway, usar **References** no dashboard para mapear `Bucket.BUCKET_*` → `S3_*` do app. Ver `docs/deploy-railway.md`.

Em on-prem UAT/PRD, **nunca** setar `S3_ENDPOINT` no compose — sempre via Portainer UI.

---

## Variáveis condicionais (opcional)

Adicionar conforme features adotadas:

```env
SENTRY_DSN=                   # backend error tracking
VITE_SENTRY_DSN=              # frontend error tracking
RESEND_API_KEY=               # email transacional
EMAIL_FROM=                   # remetente padrão
CLERK_WEBHOOK_SECRET=         # webhook de sync user
```

Detalhes: `docs/email-resend.md`, `docs/observability.md`, `docs/auth-clerk.md`.

---

## GitHub repo — secrets e variables

Configurados no repo (não `.env`), usados pelo CI/CD:

| Tipo | Nome | Cloud | On-premise |
|---|---|---|---|
| var | `APP_NAME` | — | ✅ |
| var | `INTERNAL_REGISTRY` | — | **var da org** — já disponível |
| secret | `SONAR_TOKEN` / `SONAR_HOST_URL` | ✅ | ✅ |
| secret | `PORTAINER_WEBHOOK_UAT` | — | ✅ |
| secret | `PORTAINER_WEBHOOK_PRD` | — | ✅ |
| secret | `VITE_CLERK_PUBLISHABLE_KEY` | — | ✅ (build-time do web) |

Ver `docs/ci-github-actions.md`.

---

## Checklist antes de deploy

- [ ] `.env.example` committado, com todas as vars comuns.
- [ ] `.env` local **não** committado (`.gitignore`).
- [ ] **Cloud**: Railway Variables com todas as vars (usando References para S3 e Postgres).
- [ ] **On-premise**: stack UAT e PRD no Portainer com todas as vars configuradas na UI, incluindo `REGISTRY`, `APP_NAME`, `S3_BACKUP_BUCKET`, `APP_HOST_*`.
- [ ] `BACKUP_RETENTION_DAYS ≥ 30` em PRD (on-premise).
- [ ] `VITE_API_URL=""` nos composes UAT/PRD (on-premise) ou URL absoluta em Railway.
- [ ] `S3_ENDPOINT` em UAT/PRD aponta para MinIO central, não `http://minio:9000`.
- [ ] `PORT` não está setado em Railway.
