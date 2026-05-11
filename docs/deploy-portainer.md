# Deploy — Portainer (on-premise Masterboi)

Ler ao criar os compose files de produção, labels do Traefik, entrypoint da API, ou ao debugar uma stack no Portainer. Linha-resumo vive em `CLAUDE.md`. Para dev local ver `docs/docker-dev.md`. Para storage ver `docs/storage-s3.md`. Para nginx do web ver `docs/web-nginx.md`. Para CI/CD ver `docs/ci-github-actions.md`.

Princípio: **três compose files** por projeto — dev (build local), UAT (imagens pré-buildadas do registry interno), PRD (imagens pré-buildadas do registry interno). Traefik vive em stack separada (shared) e expõe os services via labels + rede externa.

## Pré-requisitos

- Host com **Traefik** rodando (stack separada) e uma **rede externa** (`traefik-net` ou similar).
- **MinIO centralizado** de monitoramento já rodando em UAT/PRD (não sobe MinIO por projeto em UAT/PRD).
- **Registry Docker privado** (`${REGISTRY}` / `INTERNAL_REGISTRY`) onde o CD publica as imagens.
- Imagem `${REGISTRY}/backup-postgres:latest` publicada (ver `docs/backup-restore.md`).
- Variáveis do GitHub da org disponíveis: `INTERNAL_REGISTRY` (var), `PORTAINER_WEBHOOK_UAT` / `PORTAINER_WEBHOOK_PRD` (secrets), `SONAR_TOKEN` (secret).

## Estrutura de arquivos

```
<projeto>/
├── docker-compose.yml           # dev local (build local, MinIO próprio)
├── docker-compose-uat.yml       # homologação (imagens uat-latest, MinIO central)
├── docker-compose-prd.yml       # produção (imagens :latest, MinIO central)
├── apps/
│   ├── api/
│   │   ├── Dockerfile           # produção (multi-stage)
│   │   └── Dockerfile.dev
│   └── web/
│       ├── Dockerfile           # multi-stage: build bun + nginx:alpine
│       ├── Dockerfile.dev
│       └── nginx.conf           # proxy reverso SPA + /api
```

## `docker-compose.yml` — Desenvolvimento local

Services: `api`, `web`, `postgres`, `minio`, `init-bucket`, `backup`.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports: ["${POSTGRES_PORT:-5432}:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      retries: 5

  minio:
    image: minio/minio:RELEASE.2025-09-07T16-13-09Z
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports:
      - "${MINIO_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    volumes: [minio_data:/data]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      retries: 3

  init-bucket:
    image: minio/mc:RELEASE.2025-09-07T16-13-09Z
    depends_on:
      minio: { condition: service_healthy }
    entrypoint: >
      sh -c "
        mc alias set local http://minio:9000 $$MINIO_ROOT_USER $$MINIO_ROOT_PASSWORD &&
        mc mb --ignore-existing local/$$S3_BUCKET &&
        mc mb --ignore-existing local/backup-$$APP_NAME-db
      "
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      S3_BUCKET: ${S3_BUCKET:-uploads}
      APP_NAME: ${APP_NAME}
    restart: "no"

  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    restart: unless-stopped
    ports: ["${API_PORT:-3000}:3000"]
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      CLERK_SECRET_KEY: ${CLERK_SECRET_KEY}
      APP_CORS_ORIGINS: ${APP_CORS_ORIGINS}
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: ${MINIO_ROOT_USER}
      S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      S3_REGION: ${S3_REGION:-us-east-1}
      S3_BUCKET: ${S3_BUCKET:-uploads}
      S3_FORCE_PATH_STYLE: "true"
      PORT: 3000
    entrypoint: ["sh", "-c", "bun run db:migrate && bun run start"]
    depends_on:
      postgres: { condition: service_healthy }
      minio: { condition: service_healthy }
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1"]
      interval: 30s
      retries: 3

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
      args:
        VITE_CLERK_PUBLISHABLE_KEY: ${VITE_CLERK_PUBLISHABLE_KEY}
        VITE_API_URL: ""
    restart: unless-stopped
    ports: ["${WEB_PORT:-80}:80"]
    depends_on:
      api: { condition: service_healthy }

  backup:
    image: ${REGISTRY}/backup-postgres:latest
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: ${MINIO_ROOT_USER}
      S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      S3_BACKUP_BUCKET: backup-${APP_NAME}-db
      APP_NAME: ${APP_NAME}
      RETENTION_DAYS: "${BACKUP_RETENTION_DAYS:-7}"
      BACKUP_INTERVAL: "${BACKUP_INTERVAL:-86400}"
    depends_on:
      postgres: { condition: service_healthy }
      minio: { condition: service_healthy }

volumes:
  postgres_data:
  minio_data:
```

- API e Web fazem **build local**.
- MinIO local inclui seu próprio `init-bucket`.
- `backup` usa a **imagem centralizada** `${REGISTRY}/backup-postgres:latest` (mesma de UAT/PRD).
- `VITE_API_URL: ""` — nginx do web faz proxy same-origin.
- Credenciais via `.env` (nunca commitar).

## `docker-compose-uat.yml` — Homologação

Mudanças vs dev:

- API e Web usam **imagens pré-buildadas do registry interno**:

  ```yaml
  api:
    image: ${REGISTRY}/${APP_NAME}-api:uat-latest
    # (sem build:, sem ports: — Traefik expõe via labels)
  web:
    image: ${REGISTRY}/${APP_NAME}-web:uat-latest
  ```

- **Nunca** usar `build:` em UAT/PRD — imagens são publicadas pelo CD.
- **Sem `minio` e sem `init-bucket`** — MinIO é o **central de monitoramento**. Buckets são criados manualmente pela infra no MinIO central.
- `NODE_ENV: production` na API.
- Sem `CORS` no compose — nginx faz proxy same-origin.
- `restart: unless-stopped` + `deploy.resources.limits.memory` em todos (256M apps, 128M backup).
- **Variáveis via Portainer UI** — nunca `.env` file. Portainer Stacks não processam `.env`.
- Backup aponta para MinIO central:

  ```yaml
  backup:
    image: ${REGISTRY}/backup-postgres:latest
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      S3_ENDPOINT: ${S3_ENDPOINT}          # MinIO central — valor via Portainer UI
      S3_ACCESS_KEY: ${S3_ACCESS_KEY}
      S3_SECRET_KEY: ${S3_SECRET_KEY}
      S3_BACKUP_BUCKET: ${S3_BACKUP_BUCKET}
      APP_NAME: ${APP_NAME}
      RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}
      BACKUP_INTERVAL: ${BACKUP_INTERVAL}
    depends_on:
      postgres: { condition: service_healthy }
    deploy:
      resources:
        limits: { memory: 128M }
  ```

- Labels Traefik (api e web):

  ```yaml
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.${APP_NAME}-web.rule=Host(`${APP_HOST_UAT}`)"
    - "traefik.http.routers.${APP_NAME}-web.entrypoints=websecure"
    - "traefik.http.routers.${APP_NAME}-web.tls.certresolver=letsencrypt"
    - "traefik.http.services.${APP_NAME}-web.loadbalancer.server.port=80"
  ```

## `docker-compose-prd.yml` — Produção

Idêntico ao UAT, com as diferenças:

- Tags sem prefixo: `${REGISTRY}/${APP_NAME}-api:latest`, `${REGISTRY}/${APP_NAME}-web:latest`.
- Resource limits maiores (ex: 512M API, 256M backup). Ajustar por carga real.
- Rotas Traefik com `Host` de produção.
- Backup: mesmas variáveis do UAT, mas com `S3_BACKUP_BUCKET` apontando para bucket de PRD (ex: `backup-${APP_NAME}-db` em MinIO PRD).

## Regras aplicadas

| Item | Por quê |
|---|---|
| `restart: unless-stopped` | Reinicia em falha, não após parada manual |
| `mem_limit: 256m` nos apps | Alvo de `CLAUDE.md` (≤256MB) |
| `healthcheck` em todos | Startup ordering + detecção de falhas |
| `depends_on: condition: service_healthy` | API só sobe com Postgres healthy; web só sobe com API healthy |
| `entrypoint` da API roda migrations | Sem etapa manual pós-deploy |
| Três composes separados | Dev faz build; UAT/PRD usam imagens do CD. Nunca misturar |
| Imagens do registry em UAT/PRD | Deploy consistente — mesma imagem pode rodar em UAT e PRD |
| Variáveis via Portainer UI em UAT/PRD | Portainer Stacks não processam `.env` files |
| MinIO local **só no dev** | UAT/PRD usam MinIO central (serviço compartilhado) |
| Labels Traefik em UAT/PRD | TLS + roteamento automáticos |

## Deploy via Portainer UI

1. Portainer → `Stacks` → `Add stack`.
2. Nome: `${APP_NAME}-uat` ou `${APP_NAME}-prd`.
3. `Build method`: **Repository** apontando para o Git, **Compose path**: `docker-compose-uat.yml` (ou `-prd.yml`). Evita copiar/colar.
4. `Environment variables` → aba `Advanced mode` → colar o bloco. Exemplo UAT:
   ```env
   REGISTRY=registry.masterboi.local
   APP_NAME=meu-app

   POSTGRES_USER=...
   POSTGRES_PASSWORD=...
   POSTGRES_DB=...

   CLERK_SECRET_KEY=sk_live_...
   VITE_CLERK_PUBLISHABLE_KEY=pk_live_...

   S3_ENDPOINT=http://minio-central.masterboi.local:9000
   S3_ACCESS_KEY=...
   S3_SECRET_KEY=...
   S3_BUCKET=meu-app-uploads
   S3_BACKUP_BUCKET=backup-meu-app-db
   BACKUP_RETENTION_DAYS=14
   BACKUP_INTERVAL=86400

   APP_HOST_UAT=meu-app-uat.masterboi.local
   ```
5. `Deploy the stack`.
6. Confirmar que `postgres`, `api`, `web`, `backup` estão `healthy` em `Containers`.

Depois do primeiro deploy manual, todos os deploys subsequentes são **automáticos via webhook Portainer** acionado pelo CD (ver `docs/ci-github-actions.md`).

## Custom domain

Pré-requisito: Traefik na stack shared configurado com resolver Let's Encrypt (ou certresolver interno da org).

1. **DNS**: criar `A`/`CNAME` apontando para o IP do host Traefik.
2. **Labels Traefik** (já nos composes): definem `Host(...)`, entrypoint HTTPS e certresolver.
3. Validar:
   ```sh
   dig meu-app.masterboi.local
   curl -I https://meu-app.masterboi.local/health
   ```

## Logs

Driver padrão: `json-file`. Sempre configurar rotação no compose:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "5"
```

Acessar via Portainer UI → `Containers` → service → `Logs`. Agregação (Loki) opcional via stack shared.

## Scaling

- **Vertical**: `mem_limit` em modo compose standalone ou `deploy.resources.limits.memory` em Swarm.
- **Horizontal** (só Swarm): `deploy.replicas`. Extrair migrations para service `migrate` com `replicas: 1` antes de subir as réplicas da API.
- **Postgres**: NÃO replicar via `deploy.replicas` — corrompe dados. HA via Patroni/shared stack.

## Rollback

Manual via tag de imagem:

1. Identificar a SHA/tag anterior publicada no registry.
2. Stack no Portainer → `Editor` → trocar `image:` para tag anterior (ex: `${REGISTRY}/${APP_NAME}-api:uat-<sha>`) → `Update the stack`.
3. Monitorar healthchecks.

Regra: **sempre taggear imagens com SHA do commit além de `:latest` / `:uat-latest`**. Sem tag estável, rollback fica impossível.

## Anti-patterns

- **Usar `image:` no compose de dev** — dev faz build local; só UAT/PRD usam imagens do registry.
- **Usar `build:` no compose de UAT/PRD** — UAT/PRD devem usar imagens publicadas pelo CD.
- **Subir MinIO próprio em UAT/PRD** — use o MinIO central. MinIO local é só dev.
- **Arquivo `.env` no compose de UAT/PRD** — Portainer Stacks não processam `.env`. Usar `${VAR}` no compose + valores na Portainer UI.
- **Deployar Web antes da API** — CD faz API com `skip_deploy: true`, depois Web (dispara webhook).
- **Misturar tags entre ambientes** — UAT usa `:uat-latest`, PRD usa `:latest`.
- **`VITE_API_URL` com URL absoluta em UAT/PRD** — deve ser `""`; nginx faz proxy same-origin.
- **Esquecer healthcheck da API** — web espera API healthy antes de subir.
- **Esquecer rotação de logs** — `json-file` sem rotação enche o disco.
