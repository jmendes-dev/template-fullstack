# CLAUDE.md

## Stack

Monorepo TypeScript ≥6.0 · Bun ≥1.3 · Hono ≥4.12.4 · React 19 · Drizzle ORM · Drizzle Kit ≥0.31 · PostgreSQL · Biome 2.x · Vite 8 (Rolldown) · Tailwind CSS v4 · Zod v4 · Node ≥20.19 ou ≥22.12 (para tooling)

## Bun 1.3 — notas relevantes

- **Lockfile**: `bun.lock` (JSONC, git-diffable) é o padrão desde Bun 1.2. `bun.lockb` (binário) não é mais o default — se existir no projeto, deletar e rodar `bun install` para gerar `bun.lock`
- **Hot reload**: `bun --hot` (soft reload, preserva `globalThis`) vs `--watch` (reinicia processo). Usar `--hot` para API
- **Opcionais**: `bun build --bytecode` (startup rápido), workspace `"catalog"` (centralizar versões)
- **Bun.cron**: registra cron jobs no SO (crontab/launchd) — OS-level, **não** in-process. Não funciona em containers Docker. Em containers, usar `setInterval` + tabela `jobs`
- **Bun.SQL**: driver SQL unificado built-in (PostgreSQL + MySQL + SQLite). postgres.js continua como padrão
- **Isolated installs**: default em novos workspaces (`configVersion = 1`)
- **Docker images**: `oven/bun:1.3` (recomendado para reprodutibilidade), `oven/bun:slim`, `oven/bun:distroless`, `oven/bun:alpine`

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
```

Arquivos: `.env.development`, `.env.staging`, `.env.production`. Nunca commitar secrets.

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
- Deploy via **Portainer Stacks** (docker-compose.yml na UI)
- PostgreSQL como container na mesma stack
- Reverse proxy: **Traefik** (labels no compose)
- Migrations: via entrypoint script (`bun run db:migrate && bun run start`)
- Volumes nomeados para dados persistentes (postgres data)

### Storage (S3-compatible — serviço externo)

Código da aplicação usa `@aws-sdk/client-s3` apontando para `S3_ENDPOINT`. Nunca usar filesystem local para uploads em prod. **Caveat**: SDK v3.729+ envia checksums que S3-compatible pode rejeitar — usar `requestChecksumCalculation: "WHEN_REQUIRED"` no client config.

S3 é sempre um **serviço externo** — nunca criar container S3/MinIO no compose do projeto. Conexão via variáveis de ambiente seguindo o mesmo padrão do registry Docker:

```env
S3_ENDPOINT=           # URL do serviço S3 (ex: http://minio-host:9000)
S3_ACCESS_KEY=         # access key
S3_SECRET_KEY=         # secret key
S3_REGION=             # região (default: us-east-1)
S3_BUCKET=             # nome do bucket
S3_FORCE_PATH_STYLE=   # "true" para S3-compatible
```

Compose para Portainer — ver regras detalhadas em `START_PROJECT.md` Fase 4. Regras obrigatórias por service:

| Regra | Aplica a |
|---|---|
| `restart: unless-stopped` | todos |
| `mem_limit: 256m` | api, web |
| Traefik labels (`traefik.enable`, `routers`, `services`) | api, web |
| `healthcheck` | todos |
| `depends_on: condition: service_healthy` | api, web |
| Portas via env var com default (`${PORT:-3000}`) | todos |
| Volumes nomeados | postgres |

## Production-readiness (obrigatório)

- **Health**: `GET /health` em toda API. Compose: `healthcheck` com `wget`
- **Graceful shutdown**: capturar SIGTERM, fechar conexões DB
- **Logs**: JSON stdout via `pino` com `requestId`. Nunca `console.log` em prod
- **CORS**: origins explícitas via `APP_CORS_ORIGINS`. Nunca `origin: '*'` em prod

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

- **Tudo roda em container** — nunca no host (inclusive dev). `docker compose -f docker-compose.dev.yml up`
- Bind-mount do código para hot reload. `bun install` dentro do container
- Lint, typecheck, test, build: `docker compose exec <service> <comando>`
- Portas via env var com defaults (`PORT`, `WEB_PORT`, `PGPORT`). Se ocupada, incrementar +1

## Git workflow

- **Branch strategy**: trunk-based — `main` sempre deployável, feature branches curtas (`feat/`, `fix/`, `chore/`)
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`)
- **PRs**: squash merge para main. CI deve passar antes de merge

## Testes

- Runner único: **bun test** (backend e frontend)
- **Cobertura mínima: >= 80%** — enforced via quality gate (domínio, validators, routes, auth, edge cases, error handling)
- **Security review por endpoint**: auth 401/403, injection (SQL/XSS), mass assignment (rejeitar `role`/`isAdmin`), rate limiting 429, CORS, headers (HSTS, X-Content-Type-Options, X-Frame-Options)
- Testes rodam no CI antes de build

## CI/CD — GitHub Actions

### CI (`ci.yml`)

Roda em push para `main` e em PRs para `main`.

```yaml
name: CI
on:
  push:
    branches: [main]
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
      - run: bun test --recursive --coverage --coverage-reporter lcov --coverage-dir ./coverage || true
      - uses: SonarSource/sonarqube-scan-action@v6
        env: { SONAR_TOKEN: "${{ secrets.SONAR_TOKEN }}" }
```

### CD — Railway

Railway faz deploy automático ao detectar push no branch configurado. O CD é gerenciado pelo próprio Railway (não por GitHub Actions). Configurar no Railway dashboard:
- **Auto-deploy**: ativado para branch `main`
- **Pre-deploy command**: `bun run db:migrate`
- **Build**: Railway detecta Dockerfile automaticamente

**Importante**: Railway deploya automaticamente em push para `main`, mas o CI (GitHub Actions) deve passar antes do merge. Configurar branch protection rules no GitHub para exigir CI verde antes de merge em `main`.

**SonarQube**: `sonar-project.properties` na raiz. Quality gate: coverage >= 80%.

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
2. Passou → concluído (Railway deploya automaticamente)
3. Falhou → identificar step quebrado → logar `step → causa → correção` → fix → push
4. Repetir até verde ou 7 tentativas
5. Se 7 tentativas: parar, reportar resumo das tentativas + erro persistente + próximos passos

Nunca considerar tarefa finalizada com CI vermelho.

## Planejamento

Projeto novo → seguir `START_PROJECT.md`. Feature nova ou dependência desconhecida → consultar context7 MCP para documentação de API/sintaxe (ou docs oficiais). Para versão latest de pacotes, usar `bun info <pacote>` (requer `package.json` no diretório — se falhar, usar `npm view <pacote> version` como fallback) — context7 não é confiável como fonte de versão. Nunca assumir APIs, subpaths ou compatibilidade de versão de memória — sempre verificar.

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
15. **Storage sempre via S3 SDK** (`@aws-sdk/client-s3` + `S3_ENDPOINT` env var). Nunca salvar uploads no filesystem local em prod. S3 é serviço externo — nunca criar container S3/MinIO no compose
16. **Projeto novo**: se o repositório não contém `apps/` ou `packages/shared/`, considerar projeto novo. Ler e executar `START_PROJECT.md` **antes de qualquer outra ação**
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
