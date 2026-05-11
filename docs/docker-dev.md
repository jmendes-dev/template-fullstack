# Dev workflow — Docker-first

Ler ao criar `docker-compose.dev.yml`, configurar hot reload local, ou rodar lint/test/migrations dentro do container. Regra-resumo (tudo em container, nunca no host) vive em `CLAUDE.md`.

Princípio: **o host só roda Docker**. Bun, Node, Postgres e MinIO vivem em containers com bind-mount do código para hot reload.

## `docker-compose.dev.yml`

```yaml
services:
  postgres:
    image: postgres:16-alpine
    ports:
      - "${PGPORT:-5432}:5432"
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: dev
    volumes:
      - postgres_dev:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev -d dev"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:RELEASE.2025-09-07T16-13-09Z  # última release antes do repo ser arquivado (fev/2026). Para longo prazo ver alternativas em docs/storage-s3.md
    command: server /data --console-address ":9001"
    ports:
      - "${MINIO_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_dev:/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/minio/health/live || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile.dev
    ports:
      - "${PORT:-3000}:3000"
    volumes:
      - ./apps/api:/app/apps/api
      - ./packages/shared:/app/packages/shared
      - /app/node_modules
      - /app/apps/api/node_modules
    depends_on:
      postgres:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://dev:dev@postgres:5432/dev
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: minioadmin
      S3_SECRET_KEY: minioadmin
      S3_BUCKET: uploads
      APP_CORS_ORIGINS: http://localhost:4000
      PORT: 3000
      # Auth — descomentar quando configurar Clerk em dev:
      # CLERK_SECRET_KEY: ${CLERK_SECRET_KEY}
    command: bun run --hot apps/api/src/index.ts

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile.dev
    ports:
      - "${WEB_PORT:-4000}:4000"
    volumes:
      - ./apps/web:/app/apps/web
      - ./packages/shared:/app/packages/shared
      - /app/node_modules
      - /app/apps/web/node_modules
    environment:
      VITE_API_URL: http://localhost:${PORT:-3000}
      # Auth — descomentar quando configurar Clerk em dev:
      # VITE_CLERK_PUBLISHABLE_KEY: ${VITE_CLERK_PUBLISHABLE_KEY}
    depends_on:
      - api
    command: bun run --filter=@projeto/web dev

volumes:
  postgres_dev:
  minio_dev:
```

## Dockerfiles de dev (minimalistas)

`apps/api/Dockerfile.dev`:

```dockerfile
FROM oven/bun:1.3
WORKDIR /app
COPY package.json bun.lock ./
COPY apps/api/package.json ./apps/api/
COPY packages/shared/package.json ./packages/shared/
RUN bun install
COPY . .
EXPOSE 3000
```

`apps/web/Dockerfile.dev` segue a mesma lógica, expondo `4000`.

## Comandos do dia a dia

Subir tudo:
```sh
docker compose -f docker-compose.dev.yml up
```

Em background:
```sh
docker compose -f docker-compose.dev.yml up -d
```

Derrubar:
```sh
docker compose -f docker-compose.dev.yml down
```

Derrubar **e apagar dados**:
```sh
docker compose -f docker-compose.dev.yml down -v
```

## Rodar comandos dentro dos containers

Lint:
```sh
docker compose exec api bunx biome check .
```

Typecheck:
```sh
docker compose exec api bun run typecheck
docker compose exec web bun run typecheck
```

Testes:
```sh
docker compose exec api bun test
docker compose exec api bun test --coverage
```

Migrations:
```sh
docker compose exec api bun run db:generate   # gera SQL a partir do schema
docker compose exec api bun run db:migrate    # aplica migrations
docker compose exec api bunx drizzle-kit studio   # UI web do Drizzle
```

Instalar pacote:
```sh
docker compose exec api bun add <pacote>
docker compose exec web bun add <pacote>
```

Shell interativo:
```sh
docker compose exec api sh
```

## Portas

Defaults via env var no host (`.env.local`):

```env
PORT=3000              # controla o mapeamento host→container; a app dentro do container lê via Compose
WEB_PORT=4000          # frontend
PGPORT=5432            # Postgres
MINIO_PORT=9000        # MinIO S3 API
MINIO_CONSOLE_PORT=9001 # MinIO console web
```

Se alguma porta estiver ocupada no host, **incrementar +1** (PORT=3001, etc). Dentro do container, as portas continuam fixas — o mapeamento é só do host.

## Hot reload

- **API**: `bun run --hot` recarrega ao salvar qualquer arquivo montado via bind-mount
- **Web**: Vite HMR — reload imediato no browser
- **packages/shared**: mudanças aparecem em api e web sem rebuild (barrel file re-exporta)

Se parou de recarregar, conferir se o bind-mount está ativo (`docker compose exec api ls /app/apps/api` deve mostrar o código atualizado).

## Acessar MinIO Console

`http://localhost:9001` — login `minioadmin` / `minioadmin`. Para criar bucket via Console ou `mc` CLI, ver `docs/storage-s3.md` seção "Operações comuns por ambiente → Dev local".

## Problemas comuns

- **"port already in use"**: incrementar `PORT`/`WEB_PORT`/`PGPORT` no `.env.local` e reiniciar
- **`bun install` não pegou pacote novo**: rebuildar a imagem (`docker compose -f docker-compose.dev.yml build api`)
- **Mudei o schema Drizzle e o typescript não vê**: gerou migration? (`bun run db:generate`) — os tipos saem do schema, mas o barrel file de `@projeto/shared` precisa exportar
- **MinIO rejeita upload com erro de checksum**: conferir `requestChecksumCalculation: "WHEN_REQUIRED"` no client S3 (ver `docs/storage-s3.md`)
