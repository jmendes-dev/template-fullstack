# START_PROJECT.md

> **HARD CONSTRAINTS para início de projeto.**
> Siga as fases em ordem sequencial. Não avance sem completar o gate da fase atual.
> Fonte de verdade da stack: `CLAUDE.md`. Leia-o primeiro.

---

## Fase 0 — Carregar contexto

**Ação**: ler `CLAUDE.md` na raiz do repositório por completo.

**Gate**: consigo responder sem consultar: qual a stack, estrutura de pastas, tecnologias core, regras de estado, padrão de erro, deploy targets, env vars obrigatórias e todas as regras para IA.

---

## Fase 1 — Planejamento

**Ação**: produzir um plano em texto respondendo:

1. Objetivo do projeto em uma frase
2. **Deploy target**: Railway ou Portainer? (define compose, infra e storage das fases seguintes)
3. Entidades/tabelas do banco na v1
4. Endpoints da API na v1
5. Telas do frontend na v1
6. Dependências extras além do CLAUDE.md (justificar cada uma)

**Hard constraints**:
- A pergunta sobre deploy target é obrigatória — não assumir. Perguntar ao usuário se não foi informado
- Nenhum arquivo pode ser criado antes do plano ser aprovado pelo usuário
- Se o usuário não aprovou, perguntar. Nunca assumir aprovação

**Gate**: usuário aprovou o plano explicitamente, incluindo o deploy target.

---

## Fase 2 — Scaffold

**Ação**: criar estrutura de pastas e configs de workspace. Nada mais.

```
<projeto>/
├── apps/
│   ├── api/
│   │   ├── src/
│   │   │   ├── routes/
│   │   │   ├── middlewares/
│   │   │   └── index.ts
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── web/
│       ├── src/
│       │   ├── components/
│       │   ├── pages/
│       │   ├── lib/
│       │   └── main.tsx
│       ├── Dockerfile
│       ├── Dockerfile.dev
│       ├── package.json
│       ├── tsconfig.json
│       └── vite.config.ts
├── packages/
│   └── shared/
│       ├── src/
│       │   ├── schemas/
│       │   └── types/
│       ├── package.json
│       └── tsconfig.json
├── docker-compose.yml          # dev local (build local) — só se target = Portainer
├── docker-compose-uat.yml      # homologação (imagens do registry) — só se target = Portainer
├── docker-compose-prd.yml      # produção (imagens do registry) — só se target = Portainer
├── docker-compose.dev.yml      # sempre (alternativa de dev com Dockerfile.dev)
├── railway.toml                # só se target = Railway (opcional)
├── package.json
├── biome.json
├── drizzle.config.ts
├── sonar-project.properties
├── .env.example
├── .gitignore
├── CLAUDE.md
└── START_PROJECT.md
```

**Hard constraints**:
- `package.json` raiz: `"workspaces": ["apps/*", "packages/*"]`
- Scripts obrigatórios na raiz: `lint`, `typecheck`, `test`, `test:coverage`, `build`, `dev`, `db:generate`, `db:migrate`
- Naming: `@projeto/api`, `@projeto/web`, `@projeto/shared`
- **Workspace linkage**: `packages/shared/package.json` deve ter `"name": "@projeto/shared"` e campo `"exports"` configurado. `apps/api/package.json` e `apps/web/package.json` devem ter `"@projeto/shared": "workspace:*"` em dependencies
- **Barrel file**: criar `packages/shared/src/index.ts` como ponto de entrada — re-exporta schemas e tipos. Apps importam de `@projeto/shared`, nunca de caminhos internos
- `.env.example` com todas as variáveis do CLAUDE.md (sem valores reais)
- `.gitignore`: `node_modules`, `.env*` (exceto `.env.example`), `dist`, `bun.lockb` (binário legacy — `bun.lock` texto deve ser commitado)
- Não instalar dependências ainda — só criar os arquivos

**Gate**: `ls` confirma todas as pastas e arquivos. Estrutura bate exatamente com o template acima.

---

## Fase 3 — Configurações

**Ação**: consultar docs atualizadas e criar arquivos de configuração. Ainda sem código de aplicação.

**Primeiro passo obrigatório**: usar context7 MCP para verificar a **syntax e API atual** de configuração de: Biome 2.x, TypeScript, Vite 8 (Rolldown), Drizzle Kit, Tailwind CSS v4. Context7 é confiável para documentação de API/sintaxe, mas **não para versão latest** de pacotes — para versões, usar `bun info <pacote>` (requer `package.json` no diretório; fallback: `npm view <pacote> version`). Não assumir syntax de memória — APIs de config mudam entre versões. Tailwind v4 não usa `tailwind.config.js` — config é CSS-first via `@import "tailwindcss"` + `@theme { }`.

**biome.json** (raiz):
- Criar o arquivo JSON manualmente com linter `recommended: true` (confirmado válido no 2.x), formatter `indentStyle: "space"`, `indentWidth: 2`
- **Biome 2.x breaking changes**: campos `include`/`ignore` foram substituídos por `includes` (array unificado). Formato de suppression comments: `// biome-ignore lint/group/rule:` (com `/` separando grupo e regra, não mais `()`)
- `bunx biome migrate --write` na Fase 5 ajusta automaticamente `$schema` e migra config de 1.x para 2.x
- **Não hardcodar `$schema`** — será ajustado na Fase 5 após instalar Biome com `bunx biome migrate --write`
- Adicionar overrides para código gerado por shadcn/ui (`**/components/ui/**`) se necessário

**tsconfig.json** (cada workspace):
- `strict: true`
- `moduleResolution: "bundler"`
- `target: "ESNext"`
- `paths`: `@projeto/shared` → caminho relativo do package

**vite.config.ts** (web) — Vite 8 (Rolldown):
- Plugins obrigatórios: `@vitejs/plugin-react` + `@tailwindcss/vite` (não PostCSS)
- Alias `@/` → `./src`, `@projeto/shared` → caminho do package
- Vite 8 usa Rolldown como bundler (10-30x mais rápido). `build.rollupOptions` substituído por `build.rolldownOptions` (auto-conversão existe para backward compat, mas usar `rolldownOptions` em projetos novos). Feature nova: `resolve.tsconfigPaths: true` resolve paths do tsconfig nativamente. Requer Node ≥20.19 ou ≥22.12

**drizzle.config.ts** (raiz do projeto):
- Usar `import { defineConfig } from 'drizzle-kit'` e `export default defineConfig({ ... })`
- `schema` → `packages/shared/src/schemas`
- `dialect: "postgresql"`
- `dbCredentials` → `{ url: process.env.DATABASE_URL! }`

**Hard constraints**:
- Biome na raiz, não dentro de apps. Versão 2.x — formato base compatível, `bunx biome migrate --write` trata breaking changes automaticamente
- tsconfig `strict: true` em todos os workspaces, sem exceção
- Nenhum `eslint`, `prettier` ou `.editorconfig` — Biome é o único linter/formatter
- **Sem `tailwind.config.js`** em projetos novos: Tailwind v4 usa configuração CSS-first. Nunca usar diretivas `@tailwind base/components/utilities`
- **CSS principal** (`apps/web/src/index.css` ou `globals.css`): criar nesta fase com `@import "tailwindcss";` e bloco `@theme { }` para tokens do projeto. Este é um arquivo de configuração, não código de aplicação

**Gate**: todos os arquivos de configuração criados (`biome.json`, `tsconfig.json` em cada workspace, `vite.config.ts`, `drizzle.config.ts`, CSS principal com `@import "tailwindcss"`). Validação com `bunx biome check .` será feita na Fase 5 após instalação de dependências.

---

## Fase 4 — Docker

**Ação**: criar Dockerfiles e compose files baseado no **deploy target escolhido na Fase 1**. Sem esta fase, nenhum código roda.

### Comum a ambos os targets

**Dockerfiles de produção** (`apps/api/Dockerfile`, `apps/web/Dockerfile`):
- Multi-stage obrigatório: `build` → `runtime`
- Stage build: `oven/bun` full, copia workspace, instala deps, builda
- Stage runtime: `oven/bun:slim` ou `distroless`, copia só artefatos de build
- Sem devDependencies na imagem final
- API: `bun build --minify --target=bun`
- Web: `vite build` → servir com server estático ou `bun`

**Dockerfiles de dev** (`apps/api/Dockerfile.dev`, `apps/web/Dockerfile.dev`):
- Imagem `oven/bun` full
- API: `bun --hot src/index.ts`
- Web: `bunx vite dev --host 0.0.0.0`
- Entrypoint: `bun install && <comando>`

**docker-compose.dev.yml** (igual para ambos os targets):
- Services: `api`, `web`, `postgres`, `minio`, `backup`
- Bind-mount do código-fonte para hot reload
- Portas lidas de env vars com defaults: `${PORT:-3000}`, `${WEB_PORT:-4000}`, `${PGPORT:-5432}`
- PostgreSQL com `healthcheck` usando `pg_isready`
- `depends_on` com `condition: service_healthy`
- **MinIO local** como container para desenvolvimento (S3-compatible):
  ```yaml
  minio:
    image: minio/minio:latest
    restart: unless-stopped
    ports:
      - "${MINIO_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
  ```
- **Backup automático** do PostgreSQL com envio para MinIO:
  ```yaml
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
      postgres:
        condition: service_healthy
      minio:
        condition: service_healthy
  ```
- Variáveis S3 da **aplicação** apontam para o MinIO local em dev:
  ```yaml
  # No service api
  environment:
    S3_ENDPOINT: http://minio:9000
    S3_ACCESS_KEY: ${MINIO_ROOT_USER}
    S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
    S3_REGION: ${S3_REGION:-us-east-1}
    S3_BUCKET: ${S3_BUCKET:-uploads}
    S3_FORCE_PATH_STYLE: "true"
  ```
- Volumes nomeados: `postgres_data`, `minio_data`
- **Todas as credenciais via `.env`** (nunca hardcoded). `.env.example` deve incluir: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `S3_BUCKET`, `BACKUP_RETENTION_DAYS`, `BACKUP_INTERVAL`

### Se deploy target = Portainer

Criar **três compose files**: dev (build local), UAT (imagens do registry), PRD (imagens do registry).

#### `docker-compose.yml` — Desenvolvimento local

Services: `api`, `web`, `postgres`, `minio`, `backup` (+ outros conforme necessidade, ex: `redis`).

- API e Web fazem **build local** (`build: { context: ., dockerfile: apps/{service}/Dockerfile }`)
- Portas via env var: `${API_PORT:-3000}`, `${WEB_PORT:-80}`, `${POSTGRES_PORT:-5432}`
- PostgreSQL com `healthcheck` (`pg_isready`)
- `depends_on: condition: service_healthy` para API → postgres
- Web depende de API (`depends_on: [api]`)
- `DATABASE_URL` construída com vars do postgres: `postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}`
- **MinIO local** para desenvolvimento (mesma config do docker-compose.dev.yml, credenciais via `.env`)
- **Backup** service conectando ao MinIO local (mesma config do docker-compose.dev.yml)
- Variáveis S3 da aplicação apontam para o MinIO local via `.env`:
  ```yaml
  # No service api
  environment:
    S3_ENDPOINT: http://minio:9000
    S3_ACCESS_KEY: ${MINIO_ROOT_USER}
    S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
    S3_REGION: ${S3_REGION:-us-east-1}
    S3_BUCKET: ${S3_BUCKET:-uploads}
    S3_FORCE_PATH_STYLE: "true"
  ```
- Web build args: `VITE_CLERK_PUBLISHABLE_KEY` e `VITE_API_URL: ""` (nginx faz proxy same-origin)
- Volumes nomeados: `postgres_data`, `minio_data`

#### `docker-compose-uat.yml` — Homologação

Mesma estrutura do dev, mas com as seguintes diferenças:

- API e Web usam **imagens pré-buildadas do registry** (nunca build local):
  ```yaml
  api:
    image: ${REGISTRY}/${APP_NAME}-api:uat-latest
  web:
    image: ${REGISTRY}/${APP_NAME}-web:uat-latest
  ```
- `restart: unless-stopped` em todos os services
- `deploy.resources.limits.memory` em todos os services (valores moderados)
- `NODE_ENV: production` na API
- Sem CORS (nginx faz proxy same-origin)
- **Variáveis de ambiente via Portainer UI** — nunca via arquivo `.env` (Portainer Stacks não processam `.env` files, quebrando o deploy). Todas as variáveis no compose devem usar sintaxe `${VARIAVEL}` e os valores são configurados na UI do Portainer
- **Backup** service conectando ao MinIO central (todas as variáveis via Portainer UI):
  ```yaml
  backup:
    image: ${REGISTRY}/backup-postgres:latest
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      S3_ENDPOINT: ${S3_ENDPOINT}
      S3_ACCESS_KEY: ${S3_ACCESS_KEY}
      S3_SECRET_KEY: ${S3_SECRET_KEY}
      S3_BACKUP_BUCKET: ${S3_BACKUP_BUCKET}
      APP_NAME: ${APP_NAME}
      RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}
      BACKUP_INTERVAL: ${BACKUP_INTERVAL}
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 128M
  ```

#### `docker-compose-prd.yml` — Produção

Mesma estrutura do UAT, mas com:

- Tags de imagem sem prefixo: `${REGISTRY}/${APP_NAME}-api:latest`, `${REGISTRY}/${APP_NAME}-web:latest`
- Resource limits maiores que UAT
- Mesmas regras de restart, healthcheck e depends_on
- **Backup** com mesma estrutura do UAT (bucket e retenção configurados via Portainer UI):
  ```yaml
  backup:
    image: ${REGISTRY}/backup-postgres:latest
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      S3_ENDPOINT: ${S3_ENDPOINT}
      S3_ACCESS_KEY: ${S3_ACCESS_KEY}
      S3_SECRET_KEY: ${S3_SECRET_KEY}
      S3_BACKUP_BUCKET: ${S3_BACKUP_BUCKET}
      APP_NAME: ${APP_NAME}
      RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}
      BACKUP_INTERVAL: ${BACKUP_INTERVAL}
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 128M
  ```

#### `apps/web/nginx.conf` — Reverse proxy

Criar o arquivo nginx.conf para o container web servir o SPA e fazer proxy reverso:

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # SPA catch-all
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests para o backend
    location /api/ {
        resolver 127.0.0.11 valid=30s;
        set $api_upstream http://api:3000;
        proxy_pass $api_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 10s;
        proxy_send_timeout 300s;
    }

    # Cache de assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Dockerfile do web** (produção) deve usar multi-stage com nginx:
1. Stage `build`: `oven/bun`, instala deps, roda `vite build`, injeta `VITE_*` como build args
2. Stage final: `nginx:alpine`, copia `dist/` para `/usr/share/nginx/html`, copia `nginx.conf`

**`VITE_API_URL` deve ser `""`** (vazio) em UAT/PRD — o frontend faz requests same-origin e o nginx roteia `/api/*` para o container API.

- Migrations via entrypoint da API: `bun run db:migrate && bun run start`
- Demais variáveis via Portainer UI (nunca via arquivo `.env` — Portainer Stacks não processam `.env` files)

### Se deploy target = Railway

**Não criar `docker-compose.yml` de produção** — Railway não usa compose.
- Railway detecta Dockerfile automaticamente
- PostgreSQL via Railway addon (não como container)
- Storage via Railway Buckets ou S3 externo (não container)
- Migrations via [pre-deploy command](https://docs.railway.com/guides/pre-deploy-command): `bun run db:migrate`
- Variáveis de ambiente configuradas via Railway dashboard
- Criar um `railway.toml` se necessário para configurar build/deploy commands

**Hard constraints**:
- Dockerfile sempre multi-stage para prod. Sem exceção
- Toda porta configurável via env var. Nunca hardcoded
- Todo service com healthcheck. Sem exceção
- `depends_on` com `condition: service_healthy` — nunca subir API antes do banco estar ready
- Não gerar artefatos do target errado (ex: Traefik labels para Railway, railway.toml para Portainer)
- **Nunca criar container S3/MinIO** — S3 é serviço externo acessado via env vars
- **Compose UAT/PRD: nunca usar `.env` file** — Portainer Stacks não processam arquivos `.env`. Todas as variáveis nos compose de UAT e PRD devem usar sintaxe `${VARIAVEL}` e ser configuradas na UI do Portainer. Arquivo `.env` é permitido apenas no compose de dev local

**Gate**: `docker compose -f docker-compose.dev.yml up` sobe todos os services. `docker compose ps` mostra todos como `healthy`. API responde em `http://localhost:${PORT}/health`.

---

## Fase 5 — Dependências

**Primeiro passo obrigatório**: antes de instalar qualquer pacote, consultar **duas fontes com escopos distintos**:
- **Versão latest real**: `bun info <pacote>` (consulta o registry — requer `package.json` no diretório; fallback: `npm view <pacote> version`). Context7 **não é confiável** para versões — pode reportar versões defasadas
- **Documentação de API, breaking changes e sintaxe**: context7 MCP (confiável para isso) ou docs oficiais via web
- **Compatibilidade entre ecossistemas** (`@hono/*`, `@tanstack/*`, `@clerk/*`): context7 MCP para docs + `bun info` para confirmar versões compatíveis

Não instalar nenhum pacote sem esta verificação. Versões desatualizadas ou incompatíveis quebram o projeto silenciosamente.

**Versões de referência (março 2026)** — piso mínimo na data deste documento. Confirmar versão latest atual via `bun info <pacote>` (não via context7, que pode estar defasado):
- Hono ≥4.12.4 (CVE-2026-29045 fix), React 19.2+, React Router v7.13+, TanStack Query v5.95+, Zustand v5.0+, Zod v4.3+, Drizzle ORM v0.45+ (stable) ou v1.0.0-beta (com `drizzle-orm/zod` integrado), Drizzle Kit ≥0.31, Biome 2.4+, Vite 8.0+, Tailwind CSS v4.2+, TypeScript ≥6.0, `@clerk/react` v6+ (Core 3), `@hono/clerk-auth` v3+, shadcn CLI v4, `@vitejs/plugin-react` v6+

**Ação**: instalar dependências dentro dos containers via `bun add` (nunca escrever versões manualmente no `package.json`). Rodar via compose.

**API** (`apps/api`) — instalar com `bun add`:
```
hono @hono/standard-validator @hono/clerk-auth
drizzle-orm postgres
pino pino-pretty (dev)
@aws-sdk/client-s3              # ⚠️ v3.729+ envia checksums por default — configurar requestChecksumCalculation: "WHEN_REQUIRED" se S3-compatible rejeitar
zod
```

**Web** (`apps/web`):
```
react react-dom react-router    # react-router-dom foi descontinuado no v7 — usar react-router
hono                            # necessário para hono/client (RPC client tipado)
@tanstack/react-query
zustand                         # v5: usar import { create } — default export removido
react-hook-form @hookform/resolvers    # Com Zod v4: usar z.input<typeof schema> no useForm (não z.infer)
@clerk/react                    # ⚠️ renomeado de @clerk/clerk-react no Core 2 (v5). Core 3 = v6+
sonner
tailwindcss @tailwindcss/vite
```

**Shared** (`packages/shared`):
```
zod drizzle-orm drizzle-zod    # drizzle-zod só na stable (0.45.x) — ver cenários abaixo
# Dois cenários conforme versão do drizzle-orm:
# Stable (0.45.x): instalar também drizzle-zod (v0.8.3+, suporta Zod v4 nativamente)
#   → import { createInsertSchema, createSelectSchema } from 'drizzle-zod'
# Beta (≥1.0.0-beta.15): drizzle-zod deprecated, usar drizzle-orm/zod integrado
#   → import { createInsertSchema, createSelectSchema } from 'drizzle-orm/zod'
# Na stable, NÃO usar drizzle-orm/zod (não existe). Na beta, NÃO instalar drizzle-zod
```

**Dev (raiz)**:
```
@biomejs/biome typescript drizzle-kit
# TypeScript ≥6.0, Drizzle Kit ≥0.31 (alinhar com drizzle-orm stable)
# Biome 2.x — rodar bunx biome migrate --write após instalar
# drizzle-kit: comandos principais são generate, migrate, push. Outros: pull, check, up (upgrade snapshots), studio
# Node ≥20.19 ou ≥22.12 obrigatório para Vite 8 e tooling (Node 21.x e 22.0-22.11 não suportados)
```

**Ordem obrigatória de instalação**:
1. Instalar deps base de cada workspace (`bun install` via compose — dentro do container, não no host)
2. Inicializar shadcn/ui: `bunx shadcn@latest init -t vite` (flag `-t vite` obrigatória para projetos Vite). Com Tailwind v4, deixar `tailwind.config` em branco no init. Config padrão: TypeScript, CSS variables, path alias `@/` → `./src`, estilo "new-york". **Nota (fev 2026)**: estilo "new-york" usa pacote `radix-ui` unificado (ex: `import { Dialog } from "radix-ui"`) em vez de `@radix-ui/react-*` individuais
3. Rodar `bunx biome migrate --write` para alinhar `biome.json` com a versão do binário. Verificar que `$schema` aponta para a versão correta

**Hard constraints**:
- Verificar versões: pacotes do mesmo ecossistema (`@clerk/*`, `@tanstack/*`, `@hono/*`) devem usar a mesma major version
- Usar `bun info` (fallback: `npm view`) para confirmar versões latest e context7 MCP (ou docs oficiais) para verificar compatibilidade de API antes de instalar
- Não instalar libs que já existem na stack (ex: não instalar axios se tem hono/client RPC)

**Gate** (rodar dentro do container via `docker compose exec`): `bun install` sem erros. `bun run typecheck` passa. `bunx biome check .` passa (confirmar que biome.json está alinhado com a versão instalada).

---

## Fase 6 — Banco de dados

**Ação**: criar schema base no shared, gerar e rodar primeira migration.

**Ordem obrigatória**:
1. Criar schema Drizzle em `packages/shared/src/schemas/`
2. Criar schemas Zod no mesmo arquivo (insert, select): na stable (0.45.x) `import { createInsertSchema, createSelectSchema } from 'drizzle-zod'`; na beta (≥1.0.0-beta.15) `import { createInsertSchema, createSelectSchema } from 'drizzle-orm/zod'`
3. Exportar tipos TypeScript inferidos dos schemas Zod
4. `bun run db:generate` → gera SQL de migration
5. `bun run db:migrate` → aplica no PostgreSQL (dentro do container)

**Hard constraints**:
- Schemas vivem em `packages/shared` — nunca em `apps/api`
- Todo schema tem `createdAt` e `updatedAt` com defaults
- IDs: `uuid` com `defaultRandom()` ou `serial` — escolher um padrão e manter
- Nunca `sql.raw()` com dados de input — usar sempre API tipada do Drizzle e placeholders parametrizados
- Em `sql` tagged templates, nunca interpolar objetos `Date` do JS — sempre converter com `.toISOString()` antes
- Zod v4 schemas são a fonte de verdade para validação — API e frontend importam do shared. Usar `drizzle-zod` na stable ou `drizzle-orm/zod` na beta (ver cenários na Fase 5)
- **Nullable fields**: colunas sem `.notNull()` geram `T | null` no TypeScript. Documentar quais campos são nullable no plano da Fase 1 e garantir que o frontend os trata explicitamente (nunca assumir `string` quando é `string | null`)

**Gate** (rodar dentro do container): migration aplicada. `bun run db:generate` não gera diff (schema em sync). Tabelas existem no PostgreSQL.

---

## Fase 7 — App base (mínimo viável)

**Primeiro passo obrigatório**: usar context7 MCP para verificar a **documentação e API atual** de: Hono (middlewares, RPC), React 19 (hooks, client/server), React Router v7 (route config), TanStack Query v5 (QueryClient, hooks), Clerk (provider setup, middleware). Context7 é confiável para sintaxe/API mas não para versão latest — para versões, usar `bun info` (fallback: `npm view`). Não escrever código com APIs deprecadas.

**Ação**: criar código mínimo para validar que tudo funciona integrado.

**API** (`apps/api/src/index.ts`):
- Hono app com middleware: CORS, error handler, pino logger, Clerk auth (**condicional** — ver abaixo). Validação: preferir `sValidator` de `@hono/standard-validator` (suporta qualquer lib via Standard Schema). `@hono/zod-validator` também funciona com Zod v4 (desde v0.7.6), mas `standard-validator` é mais genérico
- `GET /health` → `{ status: "ok", timestamp: ... }`
- Uma rota de exemplo conectando ao banco via Drizzle
- Graceful shutdown capturando SIGTERM
- Porta lida de `PORT` env var
- **Clerk condicional**: `clerkMiddleware()` só é registrado se `CLERK_SECRET_KEY` existir no env. Helper `requireAuth()` retorna `"dev-user"` quando Clerk não está configurado. Isso permite desenvolvimento local sem credenciais Clerk. **No Hono, `getAuth(c)` é síncrono** — importar de `@hono/clerk-auth`
- **Envelope de resposta**: toda rota retorna `{ data: ... }` para sucesso e `{ error, code, details }` para erro. Listas paginadas retornam `{ data: [...], pagination: { page, limit, total, totalPages } }`

**Web** (`apps/web/src/main.tsx`):
- React 19 + React Router v7
- QueryClient com defaults do CLAUDE.md (staleTime 1min, gcTime 5min, retry 1)
- Clerk provider — **Clerk Core 3 (março 2026, v6+)**: usar `<Show when="signed-in">` em vez de `<SignedIn>`/`<SignedOut>`/`<Protect>` (deprecated). `getToken()` agora lança `ClerkOfflineError` (importar de `@clerk/react/errors`) quando offline — ainda retorna `null` se não autenticado
- Uma página hello world que faz fetch via hono/client RPC tipado (ver abaixo)
- Sonner como toast provider
- Tailwind CSS configurado

**Hono RPC — type-safety end-to-end** (obrigatório):
- API deve exportar `type AppType = typeof app` (ou `typeof route` para sub-rotas)
- Frontend faz `import type { AppType } from "@projeto/api"` e cria client: `hc<AppType>(baseUrl)`
- Isso e um `import type` — eliminado em compile time, sem dependencia runtime. E a unica excecao permitida para imports entre apps (ver CLAUDE.md "Monorepo Architecture")
- Garante autocompletion e validacao de tipos em todas as chamadas — substitui definicao manual de tipos de resposta

**Shared**:
- Pelo menos um schema exportado com Zod validators
- Tipos TypeScript exportados

**Contrato API ↔ Frontend** (verificação obrigatória antes de construir o frontend):
1. Implementar os endpoints da API primeiro
2. Testar cada endpoint com `curl` e anotar o formato exato do JSON retornado
3. Definir interfaces TypeScript no frontend (ou em `packages/shared/src/types/`) que espelham **exatamente** o JSON retornado, incluindo o envelope `{ data }`
4. Hooks do frontend (TanStack Query) devem unwrap `response.data` para extrair o payload real
5. Nunca inventar campos, renomear propriedades ou assumir transformações que a API não faz

**shadcn/ui — verificação de props**:
- Antes de usar props de componentes shadcn, abrir o arquivo fonte em `src/components/ui/<componente>.tsx` e verificar quais variantes e props existem
- Props como `size="icon-sm"`, `variant="destructive"` em DropdownMenuItem, ou `size="sm"` em Avatar **não existem** por padrão no shadcn
- Quando a variante desejada não existe, usar `className` para estilizar

**Hard constraints**:
- Data fetching via TanStack Query + Hono RPC — nunca fetch manual
- Toasts via Sonner — nunca alert()
- Estado: TanStack Query para server state, Zustand para client state
- CORS configurado via `APP_CORS_ORIGINS` — nunca `origin: '*'`
- Error handler retorna formato padrão: `{ error, code, details }`
- Respostas de sucesso retornam formato padrão: `{ data }` ou `{ data, pagination }`
- Logs via pino com requestId — nunca console.log
- Campos nullable do banco (`T | null`) devem ser tratados explicitamente no frontend — nunca assumir `string` puro

**Gate**: todos os checks abaixo passam:

```bash
# containers rodando e saudáveis
docker compose -f docker-compose.dev.yml ps  # todos healthy

# API responde
curl http://localhost:${PORT:-3000}/health     # { "status": "ok" }

# frontend abre
curl -s http://localhost:${WEB_PORT:-4000} | head -1  # <!DOCTYPE html>

# lint + types (dentro do container)
docker compose exec api bunx biome check .     # zero erros
docker compose exec api bun run typecheck      # zero erros

# banco em sync (dentro do container)
docker compose exec api bun run db:generate    # no changes detected
```

---

## Fase 8 — CI/CD e Git

**Ação**: configurar CI, CD e fazer primeiro commit.

### 1. CI — `.github/workflows/ci.yml`

```yaml
name: CI
on:
  push:
    branches: [main, uat]
  pull_request:
    branches: [main]
```

Pipeline: install → lint → typecheck → test:coverage → SonarQube → build.

### 2. CD — `.github/workflows/cd-uat.yml` (só se target = Portainer)

```yaml
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
      skip_deploy: true
    secrets:
      PORTAINER_WEBHOOK_UAT: ${{ secrets.PORTAINER_WEBHOOK_UAT }}

  deploy-web:
    needs: deploy-api
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

### 3. CD — `.github/workflows/cd-prd.yml` (só se target = Portainer)

Mesmo padrão do UAT, mas:
- Escuta branch `main` (não `uat`)
- Usa `deploy-prd.yml` (não `deploy-uat.yml`)
- Usa `PORTAINER_WEBHOOK_PRD` (não `PORTAINER_WEBHOOK_UAT`)

### 4. Commit e push

```bash
git init && git add . && git commit -m "feat: initial scaffold"
git push -u origin main
git checkout -b uat && git push -u origin uat   # criar branch uat
```

**Hard constraints**:
- Conventional Commits desde o primeiro commit
- Branches `main` e `uat` criadas no primeiro push
- CI roda em push para `main` e `uat`: install → lint → typecheck → test → SonarQube → build
- CD roda **somente após CI verde** via `workflow_run` — nunca trigger direto em push
- CD-UAT escuta branch `uat`, CD-PRD escuta branch `main`. Nenhum outro branch dispara CD
- API deploya primeiro com `skip_deploy: true` (build+push sem webhook), Web deploya depois (dispara webhook)
- Build falha se qualquer step falhar

### 5. Configurar GitHub repo

Após push, configurar no GitHub (Settings → Secrets and variables):

| Tipo | Nome | Valor |
|---|---|---|
| var | `APP_NAME` | nome do app (ex: `awards`) |
| secret | `SONAR_TOKEN` | token SonarCloud |
| secret | `PORTAINER_WEBHOOK_UAT` | URL webhook Portainer UAT |
| secret | `PORTAINER_WEBHOOK_PRD` | URL webhook Portainer PRD |
| secret | `VITE_CLERK_PUBLISHABLE_KEY` | Clerk publishable key |

**Nota**: `INTERNAL_REGISTRY` é var da **organização** — já disponível em todos os repos, não precisa configurar.

**Gate**: commit feito, push realizado, CI passa no primeiro run (ou pelo menos lint + typecheck + build). Se CI falhar, aplicar o **loop de autocorreção pós-push** do CLAUDE.md: máximo 7 tentativas, logando `step → causa → correção` a cada fix. Nunca considerar tarefa finalizada com CI vermelho.

---

## Fase 9 — Bootstrap de memória dos agentes

**Ação**: pré-popular as memórias dos agentes com contexto do projeto para eliminar o período de cold start.

**Ler**: `.superpowers/agent-memory-bootstrap.md` — guia completo com checklist, template de MEMORY.md e conteúdo mínimo por agente.

**Por quê**: sem bootstrap, cada agente começa "do zero" e precisa redescobrir a stack, os padrões e o inventário de rotas/schemas nas primeiras sessões. Com o bootstrap, os agentes entram produtivos desde a primeira invocação.

**Hard constraints**:
- Executar somente após Fase 7 (app base funcionando) — precisa do inventário real do codebase
- MEMORY.md de cada agente: máximo 200 linhas (truncado automaticamente além disso)
- Nunca duplicar o que já está em `CLAUDE.md` ou `claude-stacks.md` nas memórias
- Informações de stack/padrões vão como fatos; código completo nunca entra na memória

**Gate**: todos os 10 diretórios de `agent-memory/` têm um `MEMORY.md` preenchido com o resumo crítico do projeto.

---

## Resumo de gates

| Fase | Gate |
|---|---|
| 0 — Contexto | CLAUDE.md lido e compreendido |
| 1 — Planejamento | Plano + deploy target aprovados pelo usuário |
| 2 — Scaffold | Estrutura de pastas completa no disco |
| 3 — Configs | Arquivos de config criados (biome, tsconfig, vite, drizzle, CSS principal) |
| 4 — Docker | Todos os containers `healthy` |
| 5 — Deps | `bun install` + `bun run typecheck` passam |
| 6 — Banco | Migration aplicada, schema em sync |
| 7 — App base | Health check + lint + typecheck + banco em sync + API responses verificadas com curl |
| 8 — CI/CD e Git | Primeiro commit + CI verde + CD workflows criados (Portainer) |
| 9 — Bootstrap memória | Todos os 10 `agent-memory/*/MEMORY.md` preenchidos |

---

## Anti-patterns (nunca fazer)

- Pular direto para código sem completar fases 0-4
- Assumir deploy target sem perguntar ao usuário
- Gerar artefatos do target errado (Traefik labels para Railway, railway.toml para Portainer)
- Criar `docker-compose.yml` de produção para projetos Railway
- Instalar dependências no host em vez de dentro do container
- Instalar dependências sem verificar versão latest (`bun info`; fallback: `npm view`) e documentação de API (context7/docs oficiais)
- Criar schemas fora de `packages/shared`
- Usar `fetch()` manual em vez de hono/client RPC + TanStack Query
- Hardcodar portas nos Dockerfiles ou compose
- Subir API antes do banco estar healthy
- Criar Dockerfile single-stage para produção
- Usar `console.log` em vez de pino
- Usar `origin: '*'` no CORS
- Instalar eslint, prettier ou qualquer linter que não seja Biome
- Fazer commit sem seguir Conventional Commits
- Criar arquivos `.css` avulsos em vez de usar Tailwind classes
- **Criar container S3/MinIO no compose** — S3 é serviço externo acessado via env vars (`S3_ENDPOINT`, `S3_ACCESS_KEY`, etc.)
- **Retornar JSON sem envelope `{ data }`** — frontend sempre espera `response.data`
- **Registrar `clerkMiddleware()` sem checar `CLERK_SECRET_KEY`** — crasha a API inteira em dev sem Clerk
- **Interpolar `Date` do JS em `sql` tagged templates do Drizzle** — sempre usar `.toISOString()`
- **Assumir props de shadcn/ui sem verificar o código fonte** — variantes não-padrão não existem
- **Ignorar campos nullable** — `T | null` do Drizzle propaga para o frontend; tratar com `|| ""` ou `?? undefined`
- **Hardcodar versão do Biome no `biome.json`** sem verificar a versão instalada — rodar `bunx biome migrate --write`
- **Construir frontend antes de testar a API** — verificar responses reais com `curl` antes de definir tipos no frontend
- **Instalar `@clerk/clerk-react`** — pacote renomeado para `@clerk/react` desde Core 2 (v5). Core 3 = v6+
- **Instalar `react-router-dom`** — descontinuado no v7, usar `react-router` (pacote unificado)
- **Criar `tailwind.config.js` em projeto novo** — Tailwind v4 usa `@import "tailwindcss"` + `@theme { }` no CSS e `@tailwindcss/vite` no Vite
- **Usar o pacote errado de Zod integration do Drizzle** — na stable (0.45.x) usar `drizzle-zod` (v0.8.3+); na beta (≥1.0.0-beta.15) usar `drizzle-orm/zod`. Nunca misturar
- **Usar `import create from 'zustand'`** — Zustand v5 removeu default export, usar `import { create } from 'zustand'`
- **Inventar comandos do drizzle-kit** — os comandos principais são `generate`, `migrate`, `push`. Outros válidos: `pull`, `check`, `up` (upgrade snapshots), `studio`. Não inventar comandos além destes
- **Assumir Biome 1.x config** — Biome agora é 2.x com breaking changes: `include`/`ignore` → `includes`, suppression comments mudaram
- **Usar `@hono/zod-validator` como padrão** — funciona com Zod v4 desde v0.7.6, mas preferir `@hono/standard-validator` que suporta qualquer lib via Standard Schema (mais genérico e futuro-proof)
- **Usar `build.rollupOptions` no Vite 8** — substituído por `build.rolldownOptions` (auto-conversão existe, mas usar `rolldownOptions` em projetos novos)
- **Importar de `@radix-ui/react-*` individualmente** — shadcn/ui (new-york) agora usa pacote `radix-ui` unificado
- **Ignorar breaking changes do Clerk Core 3** — `<Protect>`, `<SignedIn>`, `<SignedOut>` foram deprecated; usar `<Show when="signed-in">`. `getToken()` lança `ClerkOfflineError` (importar de `@clerk/react/errors`) quando offline. `@clerk/types` deprecated → usar `@clerk/shared/types`
- **Assumir compatibilidade automática entre majors** de `@clerk/*`, `@hono/*`, `@tanstack/*` — sempre verificar via context7/docs antes de instalar ou atualizar
- **Salvar uploads no filesystem local em produção** — sempre usar S3-compatible storage (`@aws-sdk/client-s3` + `S3_ENDPOINT`)
- **Disparar CD direto em push** — CD deve usar `workflow_run` escutando CI, nunca `on: push`. Sem CI verde, sem deploy
- **CD em branch diferente de `uat` ou `main`** — feature branches nunca disparam CD
- **Usar `image:` no compose de dev** — dev faz build local. Só UAT/PRD usam imagens do registry
- **Fazer build no compose de UAT/PRD** — UAT/PRD usam imagens pré-buildadas pelo CD. Nunca `build:` em compose de UAT/PRD
- **Deployar Web antes da API** — API primeiro (`skip_deploy: true`), depois Web (dispara webhook). Frontend pode depender da nova API
- **Misturar tags de imagem entre ambientes** — UAT usa `uat-latest`, PRD usa `latest`. Nunca usar tag de UAT em PRD
- **Setar `VITE_API_URL` com URL absoluta em UAT/PRD** — deve ser `""` (vazio). nginx faz proxy same-origin
- **Esquecer nginx.conf no Dockerfile do web** — sem ele, o SPA não faz fallback para `index.html` e `/api/*` não chega no backend
- **Usar arquivo `.env` nos compose de UAT/PRD** — Portainer Stacks não processam `.env` files, quebrando o deploy. Variáveis devem usar sintaxe `${VARIAVEL}` no compose e valores configurados na UI do Portainer
