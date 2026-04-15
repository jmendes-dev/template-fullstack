# START_PROJECT.md

> **HARD CONSTRAINTS para início de projeto.**
> Siga as fases em ordem sequencial. Não avance sem completar o gate da fase atual.
> Fonte de verdade da stack: `claude-stacks.md`. Leia-o primeiro.
>
> **Este arquivo define a ORDEM e os TEMPLATES de bootstrap.**
> Regras técnicas detalhadas (versões, anti-patterns, compatibilidade) estão em `claude-stacks.md`.
> Não duplicar conteúdo — referenciar.

---

## Sequência Obrigatória de Agentes — Projeto Novo

> Execute **nesta ordem** com handoff explícito entre agentes.
> Cada agente DEVE LER os artefatos gerados pelo anterior antes de começar.
> **Aguardar aprovação do usuário** nos gates marcados com ⏸️.

| Passo | Agente | Input | Output | Gate |
|-------|--------|-------|--------|------|
| 1 | `requirements-roadmap-builder` | Conversa com usuário | `docs/user-stories.md` + `docs/backlog.md` | ⏸️ Aprovação do backlog |
| 2 | `software-architect` | backlog.md + stacks | `docs/adr/ADR-001-stack-selection.md` | — |
| 3 | `ux-ui-designer` | user-stories.md | `docs/design-system/MASTER.md` | ⏸️ Aprovação do design system |
| 4 | `ux-ui-designer` | MASTER.md aprovado | `docs/design-system/design-brief.md` | — |
| 5 | `data-engineer-dba` | user-stories.md + ADRs | Schema inicial em `packages/shared/src/schemas/` | — |
| 6 | `devops-sre-engineer` | stacks + deploy target | CI/CD + docker-compose + `.github/workflows/` | — |
| 7 | — (humano) | repo configurado | `./setup-github-project.sh` | — |

**Handoff explícito:** Ao lançar cada agente, incluir no prompt:
- Artefatos gerados pelos agentes anteriores (caminhos dos arquivos)
- Deploy target confirmado (Railway vs Portainer)
- Fase atual do projeto

---

## Fase 0 — Carregar contexto

**Ação**: ler `CLAUDE.md` e `claude-stacks.md` na raiz do repositório por completo.

**Gate**: consigo responder sem consultar: qual a stack, estrutura de pastas, tecnologias core, regras de estado, padrão de erro, deploy targets, env vars obrigatórias e todas as regras para IA.

---

## Fase 1 — Planejamento

**Ação**: produzir um plano em texto respondendo:

1. Objetivo do projeto em uma frase
2. **Deploy target**: Railway ou Portainer? (define compose, infra e storage das fases seguintes)
3. Entidades/tabelas do banco na v1 (marcar campos nullable)
4. Endpoints da API na v1
5. Telas do frontend na v1
6. Dependências extras além do `claude-stacks.md` (justificar cada uma)

**Hard constraints**:
- A pergunta sobre deploy target é obrigatória — não assumir. Perguntar ao usuário se não foi informado
- Nenhum arquivo pode ser criado antes do plano ser aprovado pelo usuário
- Se o usuário não aprovou, perguntar. Nunca assumir aprovação

**Gate**: usuário aprovou o plano explicitamente, incluindo o deploy target.

---

## Fase 2 — Scaffold, Configurações e Docker

> Esta fase cria toda a infraestrutura do projeto: pastas, configs e containers.
> São três sub-etapas executadas em sequência sem pausa entre elas.
> Gate único no final: containers healthy.

### 2A — Scaffold (estrutura de pastas)

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

**Regras**:
- `package.json` raiz: `"workspaces": ["apps/*", "packages/*"]`
- Scripts obrigatórios na raiz: `lint`, `typecheck`, `test`, `test:coverage`, `build`, `dev`, `db:generate`, `db:migrate`
- Naming: `@projeto/api`, `@projeto/web`, `@projeto/shared`
- Workspace linkage: `"@projeto/shared": "workspace:*"` em dependencies de api e web
- Barrel file: `packages/shared/src/index.ts` como ponto de entrada
- `.env.example` com todas as variáveis do `claude-stacks.md` → seção "Variáveis de ambiente obrigatórias"
- `.gitignore`: `node_modules`, `.env*` (exceto `.env.example`), `dist`, `bun.lockb`
- Não instalar dependências ainda — só criar os arquivos

### 2B — Configurações

**Primeiro passo obrigatório**: usar context7 MCP para verificar a **syntax e API atual** de configuração de: Biome 2.x, TypeScript, Vite 8 (Rolldown), Drizzle Kit, Tailwind CSS v4. Para versões, usar `bun info <pacote>` (não context7). Não assumir syntax de memória.

**biome.json** (raiz):
- Linter `recommended: true`, formatter `indentStyle: "space"`, `indentWidth: 2`
- Não hardcodar `$schema` — será ajustado na Fase 3 com `bunx biome migrate --write`
- Ver `claude-stacks.md` → seção "Biome 2.x" para breaking changes

**tsconfig.json** (cada workspace):
- `strict: true`, `moduleResolution: "bundler"`, `target: "ESNext"`
- `paths`: `@projeto/shared` → caminho relativo do package

**vite.config.ts** (web):
- Plugins: `@vitejs/plugin-react` + `@tailwindcss/vite` (não PostCSS)
- Alias `@/` → `./src`, `@projeto/shared` → caminho do package
- Ver `claude-stacks.md` → seção "Vite 8" para `rolldownOptions` e `tsconfigPaths`

**drizzle.config.ts** (raiz):
- `defineConfig` de `drizzle-kit`, `dialect: "postgresql"`, schema em `packages/shared/src/schemas/`

**CSS principal** (`apps/web/src/index.css`):
- `@import "tailwindcss";` + bloco `@theme { }` para tokens do projeto
- Sem `tailwind.config.js` — Tailwind v4 é CSS-first (ver `claude-stacks.md` → seção "Tailwind CSS v4")

**Regras**:
- Biome na raiz, não dentro de apps
- `strict: true` em todos os workspaces
- Nenhum `eslint`, `prettier` ou `.editorconfig`
- Sem `tailwind.config.js` em projetos novos

### 2C — Docker

**Ação**: criar Dockerfiles e compose files baseado no **deploy target escolhido na Fase 1**.

#### Comum a ambos os targets

**Dockerfiles de produção** (`apps/api/Dockerfile`, `apps/web/Dockerfile`):
- Multi-stage obrigatório: `build` → `runtime`
- Stage build: `oven/bun` full, copia workspace, instala deps, builda
- Stage runtime: `oven/bun:slim` ou `distroless`, copia só artefatos de build
- Sem devDependencies na imagem final
- API: `bun build --minify --target=bun`
- Web: `vite build` → servir com nginx (ver template nginx.conf abaixo)

**Dockerfiles de dev** (`apps/api/Dockerfile.dev`, `apps/web/Dockerfile.dev`):
- Imagem `oven/bun` full
- API: `bun --hot src/index.ts`
- Web: `bunx vite dev --host 0.0.0.0`
- Entrypoint: `bun install && <comando>`

**docker-compose.dev.yml** (igual para ambos os targets):
- Services: `api`, `web`, `postgres`, `minio`, `backup`
- Bind-mount do código-fonte para hot reload
- Portas via env vars com defaults: `${PORT:-3000}`, `${WEB_PORT:-4000}`, `${PGPORT:-5432}`
- PostgreSQL com `healthcheck` usando `pg_isready`
- `depends_on` com `condition: service_healthy`
- MinIO local como container para dev (S3-compatible):

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

- Backup automático do PostgreSQL com envio para MinIO:

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

- Variáveis S3 da aplicação apontam para MinIO local em dev:

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
- Todas as credenciais via `.env` (nunca hardcoded). `.env.example` deve incluir: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `S3_BUCKET`, `BACKUP_RETENTION_DAYS`, `BACKUP_INTERVAL`

#### Se deploy target = Portainer

Criar **três compose files**: dev (build local), UAT (imagens do registry), PRD (imagens do registry).

**`docker-compose.yml`** — Desenvolvimento local:
- API e Web fazem **build local** (`build: { context: ., dockerfile: apps/{service}/Dockerfile }`)
- Mesma estrutura de services do docker-compose.dev.yml
- MinIO local + backup service

**`docker-compose-uat.yml`** — Homologação:
- API e Web usam **imagens pré-buildadas**: `${REGISTRY}/${APP_NAME}-api:uat-latest`
- `restart: unless-stopped` + `deploy.resources.limits.memory` em todos os services
- `NODE_ENV: production` na API
- **Variáveis via Portainer UI** — nunca via arquivo `.env` (Portainer Stacks não processam `.env` files)
- Backup service conectando ao MinIO central (variáveis via Portainer UI)

**`docker-compose-prd.yml`** — Produção:
- Tags sem prefixo: `${REGISTRY}/${APP_NAME}-api:latest`
- Resource limits maiores que UAT
- Mesmas regras de restart, healthcheck e depends_on

**`apps/web/nginx.conf`** — Reverse proxy:

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

**Dockerfile do web** (produção): multi-stage com nginx — build: `oven/bun` + `vite build`; final: `nginx:alpine` + `dist/` + `nginx.conf`. `VITE_API_URL=""` em UAT/PRD (nginx faz proxy same-origin).

Migrations via entrypoint da API: `bun run db:migrate && bun run start`

#### Se deploy target = Railway

**Não criar `docker-compose.yml` de produção** — Railway não usa compose.
- Railway detecta Dockerfile automaticamente
- PostgreSQL via Railway addon
- Storage via Railway Buckets ou S3 externo
- Migrations via pre-deploy command: `bun run db:migrate`
- Variáveis via Railway dashboard
- Criar `railway.toml` se necessário

**Regras (ambos os targets)**:
- Dockerfile sempre multi-stage para prod
- Toda porta configurável via env var
- Todo service com healthcheck
- `depends_on` com `condition: service_healthy`
- Não gerar artefatos do target errado
- Nunca criar container S3/MinIO nos composes de UAT/PRD
- Compose UAT/PRD: nunca usar `.env` file — variáveis via `${VAR}` e Portainer UI

**Gate**: `docker compose -f docker-compose.dev.yml up` sobe todos os services. `docker compose ps` mostra todos como `healthy`. API responde em `http://localhost:${PORT}/health`.

---

## Fase 3 — Dependências e Banco de Dados

> Esta fase instala deps e cria o banco. Duas sub-etapas sem pausa.

### 3A — Dependências

**Primeiro passo obrigatório**: verificar versões reais com `bun info <pacote>` (não context7 para versões) e API/sintaxe com context7 MCP. Ver `claude-stacks.md` → seção "Planejamento" para regra completa de verificação.

**Ação**: instalar dependências dentro dos containers via `bun add` (nunca escrever versões manualmente).

**API** (`apps/api`):
```
hono @hono/standard-validator @hono/clerk-auth
drizzle-orm postgres
pino pino-pretty (dev)
@aws-sdk/client-s3
zod
```

**Web** (`apps/web`):
```
react react-dom react-router
hono
@tanstack/react-query
zustand
react-hook-form @hookform/resolvers
@clerk/react
sonner
tailwindcss @tailwindcss/vite
```

**Shared** (`packages/shared`):
```
zod drizzle-orm drizzle-zod
```

> Para cenários de versão Drizzle stable vs beta e Zod integration: ver `claude-stacks.md` → regra 26.

**Dev (raiz)**:
```
@biomejs/biome typescript drizzle-kit
```

**Ordem obrigatória**:
1. Instalar deps base de cada workspace (dentro do container)
2. Inicializar shadcn/ui: `bunx shadcn@latest init -t vite` (flag `-t vite` obrigatória). Com Tailwind v4, deixar `tailwind.config` em branco. Estilo "new-york"
3. Rodar `bunx biome migrate --write` para alinhar `biome.json` com a versão do binário

**Regras**:
- Pacotes do mesmo ecossistema devem usar mesma major version (ver `claude-stacks.md` → regra 11)
- Usar `bun add`, nunca escrever versões manualmente (ver `claude-stacks.md` → regra 33)
- Não instalar libs que já existem na stack

### 3B — Banco de dados

**Ação**: criar schema base no shared, gerar e rodar primeira migration.

**Ordem obrigatória**:
1. Criar schema Drizzle em `packages/shared/src/schemas/`
2. Criar schemas Zod no mesmo arquivo (insert, select) — ver `claude-stacks.md` → regra 26 para import correto
3. Exportar tipos TypeScript inferidos dos schemas Zod
4. `bun run db:generate` → gera SQL de migration
5. `bun run db:migrate` → aplica no PostgreSQL (dentro do container)

**Regras**:
- Schemas vivem em `packages/shared` — nunca em `apps/api`
- Todo schema tem `createdAt` e `updatedAt` com defaults
- IDs: `uuid` com `defaultRandom()` ou `serial` — escolher um padrão e manter
- Para demais regras de banco e nullable fields: ver `claude-stacks.md` → regras 12, 17, 26

**Gate** (rodar dentro do container):
- `bun install` sem erros
- `bun run typecheck` passa
- `bunx biome check .` passa
- Migration aplicada, `bun run db:generate` não gera diff

---

## Fase 4 — App base (mínimo viável)

**Primeiro passo obrigatório**: usar context7 MCP para verificar a **documentação e API atual** de: Hono, React 19, React Router v7, TanStack Query v5, Clerk. Não escrever código com APIs deprecadas.

**Ação**: criar código mínimo para validar que tudo funciona integrado.

**API** (`apps/api/src/index.ts`):
- Hono app com middleware: CORS, error handler, pino logger, Clerk auth condicional
- `GET /health` → `{ status: "ok", timestamp: ... }`
- Uma rota de exemplo conectando ao banco via Drizzle
- Graceful shutdown capturando SIGTERM
- Porta lida de `PORT` env var
- Clerk condicional: ver `claude-stacks.md` → seção "Auth middleware"
- Envelope de resposta: ver `claude-stacks.md` → seção "API response format"

**Web** (`apps/web/src/main.tsx`):
- React 19 + React Router v7
- QueryClient com defaults do `claude-stacks.md` → seção "TanStack Query defaults"
- Clerk provider — ver `claude-stacks.md` → seção "Auth middleware" para Core 3
- Uma página hello world que faz fetch via Hono RPC tipado
- Sonner como toast provider
- Tailwind CSS configurado

**Hono RPC — type-safety end-to-end** (obrigatório):
- API exporta `type AppType = typeof app`
- Frontend faz `import type { AppType } from "@projeto/api"` + `hc<AppType>(baseUrl)`
- Ver `claude-stacks.md` → seção "Monorepo Architecture" para detalhes

**Shared**:
- Pelo menos um schema exportado com Zod validators
- Tipos TypeScript exportados

**Contrato API ↔ Frontend** (verificação obrigatória):
1. Implementar endpoints da API primeiro
2. Testar com `curl` e anotar formato exato do JSON
3. Frontend espelha exatamente o JSON retornado incluindo envelope `{ data }`
4. Nunca inventar campos ou assumir transformações

**Regras**:
- Data fetching via TanStack Query + Hono RPC — nunca fetch manual
- Toasts via Sonner — nunca alert()
- Estado: ver `claude-stacks.md` → seção "Regras de estado"
- CORS via `APP_CORS_ORIGINS` — nunca `origin: '*'`
- Logs via pino — nunca console.log
- shadcn/ui: verificar props no código fonte antes de usar (ver `claude-stacks.md` → regra 18)

**Gate**:

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

## Fase 5 — CI/CD e Git

**Ação**: configurar CI, CD e fazer primeiro commit.

### 1. CI — `.github/workflows/ci.yml`

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
      - run: bun run lint
      - run: bun run typecheck
      - run: bun test --recursive --coverage --coverage-reporter lcov --coverage-dir ./coverage || true
      - uses: SonarSource/sonarqube-scan-action@v6
        env: { SONAR_TOKEN: "${{ secrets.SONAR_TOKEN }}" }
```

Pipeline: install → lint → typecheck → test:coverage → SonarQube.

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

### 5. Configurar GitHub repo

Após push, configurar no GitHub (Settings → Secrets and variables):

| Tipo | Nome | Valor |
|---|---|---|
| var | `APP_NAME` | nome do app (ex: `awards`) |
| secret | `SONAR_TOKEN` | token SonarCloud |
| secret | `PORTAINER_WEBHOOK_UAT` | URL webhook Portainer UAT |
| secret | `PORTAINER_WEBHOOK_PRD` | URL webhook Portainer PRD |
| secret | `VITE_CLERK_PUBLISHABLE_KEY` | Clerk publishable key |

> `INTERNAL_REGISTRY` é var da **organização** — já disponível em todos os repos.

**Regras**:
- Conventional Commits desde o primeiro commit
- Branches `main` e `uat` criadas no primeiro push
- CI roda em push para `main` e `uat`
- CD roda somente após CI verde via `workflow_run`
- CD-UAT escuta `uat`, CD-PRD escuta `main`
- API deploya primeiro com `skip_deploy: true`, Web deploya depois (dispara webhook)
- Para segurança em workflows: ver `claude-stacks.md` → regra 35

**Gate**: commit feito, push realizado, CI passa no primeiro run. Se CI falhar, aplicar o **loop de autocorreção pós-push** do `claude-stacks.md` → seção "CI/CD": máximo 7 tentativas. Nunca considerar tarefa finalizada com CI vermelho.

---

## Resumo de gates

| Fase | Gate |
|---|---|
| 0 — Contexto | CLAUDE.md + claude-stacks.md lidos e compreendidos |
| 1 — Planejamento | Plano + deploy target aprovados pelo usuário |
| 2 — Scaffold, Config, Docker | Todos os containers `healthy`, API responde em /health |
| 3 — Deps e Banco | `bun install` + `typecheck` + `biome check` passam, migration aplicada |
| 4 — App base | Health check + lint + typecheck + banco em sync + frontend abre + API responses verificadas |
| 5 — CI/CD e Git | Primeiro commit + CI verde + CD workflows criados (Portainer) |

---

## Anti-patterns (bootstrap-specific)

> Para a lista completa de anti-patterns de desenvolvimento, ver `claude-stacks.md` → regras para IA e anti-patterns.
> Abaixo estão apenas os anti-patterns **específicos de bootstrap** que não estão no stacks:

- ❌ Pular direto para código sem completar fases 0-2
- ❌ Assumir deploy target sem perguntar ao usuário
- ❌ Gerar artefatos do target errado (Traefik labels para Railway, railway.toml para Portainer)
- ❌ Criar `docker-compose.yml` de produção para projetos Railway
- ❌ Instalar dependências no host em vez de dentro do container
- ❌ Subir API antes do banco estar healthy
- ❌ Fazer build no compose de UAT/PRD (devem usar imagens pré-buildadas pelo CD)
- ❌ Usar `image:` no compose de dev (dev faz build local)
- ❌ Misturar tags de imagem entre ambientes (UAT: `uat-latest`, PRD: `latest`)
- ❌ Setar `VITE_API_URL` com URL absoluta em UAT/PRD (deve ser `""` — nginx faz proxy)
- ❌ Esquecer `nginx.conf` no Dockerfile do web
- ❌ Usar arquivo `.env` nos compose de UAT/PRD (Portainer Stacks não processam `.env` files)
- ❌ Disparar CD direto em push (deve usar `workflow_run` escutando CI)
- ❌ CD em branch diferente de `uat` ou `main`
- ❌ Deployar Web antes da API
