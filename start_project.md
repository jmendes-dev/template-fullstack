# START_PROJECT.md

> **HARD CONSTRAINTS para início de projeto.**
> Siga as fases em ordem sequencial. Não avance sem completar o gate da fase atual.
> Fonte de verdade da stack: `CLAUDE.md`. Leia-o primeiro.

---

## Fase 0 — Carregar contexto

**Ação**: ler `CLAUDE.md` na raiz do repositório por completo.

**Gate** (auto-avaliação interna do agente — não apresentar ao usuário): o modelo deve conseguir responder sem consultar: qual a stack, estrutura de pastas, tecnologias core, regras de estado, padrão de erro, deploy targets, env vars obrigatórias e todas as regras para IA.

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
│       │   ├── schema/
│       │   └── types/
│       ├── package.json
│       └── tsconfig.json
├── package.json
├── biome.json
├── drizzle.config.ts
├── sonar-project.properties
├── .env.example
├── .gitignore
├── CLAUDE.md
└── START_PROJECT.md
```

> **Nota**: `docker-compose.yml` (prod, Portainer) e `railway.toml` (Railway) não são criados nesta fase. A regra 32 do CLAUDE.md proíbe gerar config de infra antes da Fase 4, que respeita o deploy target escolhido na Fase 1. `docker-compose.dev.yml` é criado na Fase 4 (igual para ambos os targets).

**Hard constraints**:
- `package.json` raiz: `"workspaces": ["apps/*", "packages/*"]`
- Scripts obrigatórios na raiz: `lint`, `typecheck`, `test`, `test:coverage`, `build`, `dev`, `db:generate`, `db:migrate`
- Naming: `@projeto/api`, `@projeto/web`, `@projeto/shared`
- **Workspace linkage**: `packages/shared/package.json` deve ter `"name": "@projeto/shared"` e campo `"exports"` configurado. `apps/api/package.json` e `apps/web/package.json` devem ter `"@projeto/shared": "workspace:*"` em dependencies
- **Barrel file**: criar `packages/shared/src/index.ts` como ponto de entrada — re-exporta schemas e tipos. Apps importam de `@projeto/shared`, nunca de caminhos internos
- `.env.example` com todas as variáveis do CLAUDE.md (sem valores reais) — **deve ser commitado**
- `.gitignore` (sintaxe exata):
  ```gitignore
  node_modules
  dist
  .env*
  !.env.example
  bun.lockb
  .DS_Store
  ```
  `bun.lock` (texto, padrão Bun ≥1.0) **não** deve estar no `.gitignore` e **deve ser commitado**. `bun.lockb` (binário legacy) só importa em projetos migrados de Bun <1.0.
- Não instalar dependências ainda — só criar os arquivos

**Gate**: `ls` confirma todas as pastas e arquivos. Estrutura bate exatamente com o template acima.

---

## Fase 3 — Configurações

**Ação**: consultar docs atualizadas e criar arquivos de configuração. Ainda sem código de aplicação.

**Primeiro passo obrigatório**: usar context7 MCP para verificar a **syntax e API atual** de configuração de: Biome 2.x, TypeScript, Vite 8 (Rolldown), Drizzle Kit, Tailwind CSS v4. Context7 é confiável para documentação de API/sintaxe, mas **não para versão latest** de pacotes — para versões, usar `bun info <pacote>` (requer `package.json` no diretório; fallback: `npm view <pacote> version`). Não assumir syntax de memória — APIs de config mudam entre versões. Tailwind v4 não usa `tailwind.config.js` — config é CSS-first via `@import "tailwindcss"` + `@theme { }`.

**biome.json** (raiz):
- Criar o arquivo JSON manualmente com linter `recommended: true` (confirmado válido no 2.x), formatter `indentStyle: "space"`, `indentWidth: 2`
- **Biome 2.x — Linter Domains**: adicionar `"linter": { "domains": { "react": "all" } }` para ativar regras específicas de React (sem este campo, Biome 2.x não ativa automaticamente regras de React mesmo com `recommended: true`). Adicionar `"node": "all"` para `apps/api` se necessário
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
- Vite 8 usa Rolldown como bundler (10-30x mais rápido). `build.rollupOptions` substituído por `build.rolldownOptions` (auto-conversão existe para backward compat, mas usar `rolldownOptions` em projetos novos). Feature nova: `resolve.tsconfigPaths: true` resolve paths do tsconfig nativamente. Requer Node ≥22.12 ou ≥24.x

**drizzle.config.ts** (raiz do projeto):
- Usar `import { defineConfig } from 'drizzle-kit'` e `export default defineConfig({ ... })`
- `schema` → `packages/shared/src/schema`
- `out` → `"apps/api/src/db/migrations"` (obrigatório — sem este campo, Drizzle Kit gera em `./drizzle` na raiz, quebrando os scripts `db:migrate`)
- `dialect: "postgresql"`
- `dbCredentials` → `{ url: process.env.DATABASE_URL! }`

**sonar-project.properties** (raiz — conteúdo mínimo):
```properties
sonar.projectKey=<nome-do-projeto>
sonar.projectName=<Nome do Projeto>
sonar.sources=apps,packages
sonar.exclusions=**/node_modules/**,**/dist/**,**/*.test.ts,**/*.spec.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.typescript.tsconfigPath=tsconfig.json
```
Substituir `<nome-do-projeto>` e `<Nome do Projeto>`. Se não usar SonarQube, deixar o arquivo vazio — o CI vai precisar de `SONAR_TOKEN` + `SONAR_HOST_URL` configurados nos GitHub Secrets (ver Fase 8).

**bunfig.toml** (raiz):
- Criar para configurar cobertura de testes obrigatória (coverage gate do CI):

```toml
[test]
coverage = true
coverageThreshold = { line = 80, function = 80, statement = 80 }
coverageReporter = ["lcov", "text"]
coverageSkipTestFiles = true
preload = []  # adicionar mocks globais aqui quando necessário (ex: "@/test/setup.ts")
# dom = "happy-dom"                 # descomentar se usar Testing Library (@testing-library/react)
```

Sem este arquivo, `bun test --coverage` passa independentemente da cobertura — o quality gate de 80% do CI não é enforced.

**Hard constraints**:
- Biome na raiz, não dentro de apps. Versão 2.x — formato base compatível, `bunx biome migrate --write` trata breaking changes automaticamente
- tsconfig `strict: true` em todos os workspaces, sem exceção
- Nenhum `eslint`, `prettier` ou `.editorconfig` — Biome é o único linter/formatter
- **Sem `tailwind.config.js`** em projetos novos: Tailwind v4 usa configuração CSS-first. Nunca usar diretivas `@tailwind base/components/utilities`
- **CSS principal** (`apps/web/src/index.css`): criar nesta fase com `@import "tailwindcss";` e bloco `@theme { }` para tokens do projeto. Este é um arquivo de configuração, não código de aplicação

**Gate**: todos os arquivos de configuração criados (`biome.json`, `tsconfig.json` em cada workspace, `vite.config.ts`, `drizzle.config.ts`, `bunfig.toml`, CSS principal com `@import "tailwindcss"`). Validação com `bunx biome check .` será feita na Fase 5 após instalação de dependências.

---

## Fase 4 — Docker

**Ação**: criar Dockerfiles e compose files baseado no **deploy target escolhido na Fase 1**. Sem esta fase, nenhum código roda.

### Comum a ambos os targets

**Dockerfiles de produção** (`apps/api/Dockerfile`, `apps/web/Dockerfile`):
- Multi-stage obrigatório: `build` → `runtime`
- Stage build: `oven/bun:1.3` full, copia workspace, instala deps, builda
- Stage runtime: `oven/bun:1.3-slim`, copia só artefatos de build. **Sempre fixar a tag** (nunca `:latest` ou `:slim` sem versão — quebra reprodutibilidade)
- Sem devDependencies na imagem final — fazer `bun install --production --frozen-lockfile` no runtime ou bundlar tudo com `bun build` e copiar só `dist/`
- API: `bun build --minify --target=bun`
- Web: `vite build` → servir com server estático ou `bun`

**Dockerfiles de dev** (`apps/api/Dockerfile.dev`, `apps/web/Dockerfile.dev`):
- Imagem `oven/bun:1.3` full, `WORKDIR /app`
- Sem CMD — o `command:` do docker-compose.dev.yml sobrescreve. API: `bun run --hot apps/api/src/index.ts`. Web: `bun run --filter=@projeto/web dev`
- Entrypoint: `bun install` no boot (via `RUN bun install` no Dockerfile ou `command:` no compose)

**docker-compose.dev.yml** (igual para ambos os targets):
- Services: `api`, `web`, `postgres`, `minio`
- Bind-mount do código-fonte para hot reload
- Portas lidas de env vars com defaults: `${PORT:-3000}`, `${WEB_PORT:-4000}`, `${PGPORT:-5432}`, `${MINIO_PORT:-9000}`, `${MINIO_CONSOLE_PORT:-9001}`
- PostgreSQL com `healthcheck` usando `pg_isready`
- MinIO com `healthcheck`: `["CMD-SHELL", "curl -f http://localhost:9000/minio/health/live || exit 1"]` (não usar `mc ready local` — o alias `local` não existe na imagem oficial sem setup adicional, o healthcheck nunca fica `healthy`)
- `depends_on` com `condition: service_healthy`
- **Se target = Railway**: o MinIO em dev é apenas um substituto local — em prod, storage usa Railway Buckets via `S3_ENDPOINT` injetado pelo addon. Trocar `S3_ENDPOINT` no `.env` ao mudar de ambiente

### Se deploy target = Portainer

Criar `docker-compose.yml` com as seguintes regras obrigatórias:

**Services**: `api`, `web`, `postgres`, `minio`

| Regra | Aplica a |
|---|---|
| `restart: unless-stopped` | todos |
| `mem_limit: 256m` | api, web |
| Traefik labels (`traefik.enable`, `routers`, `services`) | api, web |
| `healthcheck` com `wget` (api/web), `pg_isready` (postgres), `curl -f http://localhost:9000/minio/health/live` (minio) | todos |
| `depends_on: condition: service_healthy` | api → postgres, web (se depende de API) |
| Portas via env var com defaults (`${PORT:-3000}`, `${WEB_PORT:-4000}`, `${PGPORT:-5432}`) | todos |
| Volumes nomeados | postgres (`pgdata`), minio (`minio_data`) |
| `DATABASE_URL` apontando para service `postgres` | api |

- Migrations via entrypoint: `bun run db:migrate && bun run start`
- Demais variáveis via `.env` ou Portainer UI

### Se deploy target = Railway

**Não criar `docker-compose.yml` de produção** — Railway não usa compose.
- Railway detecta Dockerfile automaticamente
- PostgreSQL via Railway addon (não como container)
- Storage via Railway Buckets (não MinIO)
- Migrations via [pre-deploy command](https://docs.railway.com/guides/pre-deploy-command): `bun run db:migrate`
- Variáveis de ambiente configuradas via Railway dashboard
- Criar um `railway.toml` se necessário para configurar build/deploy commands

**Hard constraints**:
- Dockerfile sempre multi-stage para prod. Sem exceção
- Toda porta configurável via env var. Nunca hardcoded
- Todo service com healthcheck. Sem exceção
- `depends_on` com `condition: service_healthy` — nunca subir API antes do banco estar ready
- Não gerar artefatos do target errado (ex: Traefik labels para Railway, railway.toml para Portainer)

**Gate**: `docker compose -f docker-compose.dev.yml up` sobe todos os services. `docker compose ps` mostra todos como `healthy`. API responde em `http://localhost:${PORT}/health`. **Se target = Railway**: o storage real (Railway Buckets) só é validável após configurar `.env` com `S3_ENDPOINT` injetado pelo Railway — em dev usa MinIO local como stand-in.

---

## Fase 5 — Dependências

**Primeiro passo obrigatório**: antes de instalar qualquer pacote, consultar **duas fontes com escopos distintos**:
- **Versão latest real**: `bun info <pacote>` (consulta o registry — requer `package.json` no diretório; fallback: `npm view <pacote> version`). Context7 **não é confiável** para versões — pode reportar versões defasadas
- **Documentação de API, breaking changes e sintaxe**: context7 MCP (confiável para isso) ou docs oficiais via web
- **Compatibilidade entre ecossistemas** (`@hono/*`, `@tanstack/*`, `@clerk/*`): context7 MCP para docs + `bun info` para confirmar versões compatíveis

Não instalar nenhum pacote sem esta verificação. Versões desatualizadas ou incompatíveis quebram o projeto silenciosamente.

**Versões de referência (abril 2026)** — piso mínimo na data deste documento. Confirmar versão latest atual via `bun info <pacote>` (não via context7, que pode estar defasado):
- Hono ≥4.12.14 (CVE-2026-29045 corrigida em 4.12.4 · CVE-2026-39407 em 4.12.12 · cookie bypass em 4.12.14), React 19.2+, React Router v7.14+, TanStack Query v5.99+, Zustand v5.0+, Zod v4.0+, Drizzle ORM v0.45.2+ (stable — CVE-2026-39356) ou v1.0.0-beta.20+ (com `drizzle-orm/zod` integrado), Drizzle Kit ≥0.31, Biome 2.4+, Vite 8.0+, Tailwind CSS v4.2+, TypeScript ≥6.0, `@clerk/react` v6+ (Core 3), `@clerk/hono` v0.1+, shadcn CLI v4, `@vitejs/plugin-react` v6+

**Ação**: instalar dependências dentro dos containers via `bun add` (nunca escrever versões manualmente no `package.json`). Rodar via compose.

**API** (`apps/api`) — instalar com `bun add`:
```
hono @hono/standard-validator @clerk/hono
drizzle-orm postgres
pino pino-pretty (dev)
@aws-sdk/client-s3              # ⚠️ v3.729+ envia checksums por default — configurar requestChecksumCalculation: "WHEN_REQUIRED" se MinIO/Railway Buckets rejeitar
zod
```

**Web** (`apps/web`):
```
react react-dom react-router    # react-router-dom deprecated/unificado no v7 — usar react-router
hono                            # necessário para hono/client (RPC client tipado)
@tanstack/react-query
zustand                         # v5: usar import { create } — default export removido
react-hook-form @hookform/resolvers    # ⚠️ v5.1.0+ obrigatório para Zod v4. Com Zod v4: usar z.input<typeof schema> no useForm (não z.infer)
@clerk/react                    # ⚠️ renomeado de @clerk/clerk-react no Core 2 (v5). Core 3 = v6+
sonner
tailwindcss @tailwindcss/vite
```

**Shared** (`packages/shared`):
```
zod drizzle-orm drizzle-zod
# Padrão do template: Drizzle stable (0.45.x) + drizzle-zod (v0.8.3+, suporta Zod v4 nativamente)
#   → import { createInsertSchema, createSelectSchema } from 'drizzle-zod'
# Migração para Drizzle beta (≥1.0.0-beta.20) exige aprovação explícita do usuário.
#   Na beta, drizzle-zod é deprecated e se usa drizzle-orm/zod integrado. Ver docs/version-matrix.md
```

**Dev (raiz)**:
```
@biomejs/biome typescript drizzle-kit
# TypeScript ≥6.0, Drizzle Kit ≥0.31 (alinhar com drizzle-orm stable) — ⚠️ instalar como drizzle-kit@0.31 (não @latest, que aponta para 1.0.0-beta.x no npm)
# Biome 2.x — rodar bunx biome migrate --write após instalar
# drizzle-kit: comandos principais são generate, migrate, push. Outros: pull, check, up (upgrade snapshots), studio
# Node ≥22.12 ou ≥24.x obrigatório para Vite 8 e tooling (Node 20.x EOL abr/2026; Node 21.x e 22.0-22.11 não suportados)
```

**Ordem obrigatória de instalação**:
1. Instalar deps base de cada workspace (`bun install` via compose — dentro do container, não no host)
2. Inicializar shadcn/ui: confirmar sintaxe atual com `bunx shadcn@latest init --help` antes de rodar (a CLI evolui — flags como `-t vite` podem mudar entre majors). Para shadcn CLI v4: `bunx shadcn@latest init -t vite` (flag `-t vite` obrigatória para projetos Vite). Com Tailwind v4, deixar `tailwind.config` em branco no init. Config padrão: TypeScript, CSS variables, path alias `@/` → `./src`, estilo "new-york". **Nota (fev 2026)**: estilo "new-york" usa pacote `radix-ui` unificado (ex: `import { Dialog } from "radix-ui"`) em vez de `@radix-ui/react-*` individuais
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
1. Criar schema Drizzle em `packages/shared/src/schema/`
2. Criar schemas Zod no mesmo arquivo (insert, select): `import { createInsertSchema, createSelectSchema } from 'drizzle-zod'` (padrão stable). Beta só com aprovação — ver `docs/version-matrix.md`
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

**Script `data-migrate` obrigatório desde o início**: o pre-deploy command (Railway) e entrypoint (Portainer) executam `bun run data-migrate`. Em projetos novos sem data migrations, criar o script como no-op em `apps/api/package.json`:

```json
{
  "scripts": {
    "data-migrate": "echo 'No data migrations'"
  }
}
```

Sem este script, o primeiro deploy falha com "script not found". Substituir pelo runner real quando houver a primeira data migration (ver `docs/data-migrations.md`).

**Gate** (rodar dentro do container): migration aplicada. `bun run db:generate` não gera diff (schema em sync). Tabelas existem no PostgreSQL. `bun run data-migrate` retorna exit 0.

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
- **Background jobs**: `setInterval` para agendamento periódico. `Bun.cron()` in-process disponível desde Bun 1.3.12 (lançado 9/abr/2026, funciona em containers). Ver `docs/bun-notes.md`
- **Clerk condicional**: `clerkMiddleware()` só é registrado se `CLERK_SECRET_KEY` existir no env. Helper `requireAuth()` retorna `"dev-user"` quando Clerk não está configurado. Isso permite desenvolvimento local sem credenciais Clerk. **No Hono, `getAuth(c)` é síncrono** — importar de `@clerk/hono`
- **Envelope de resposta**: toda rota retorna `{ data: ... }` para sucesso e `{ error, code, details }` para erro. Listas paginadas retornam `{ data: [...], pagination: { page, limit, total, totalPages } }`

**Web** (`apps/web/src/main.tsx`):
- React 19 + React Router v7
- QueryClient com defaults do CLAUDE.md (staleTime 1min, gcTime 5min, retry 1, refetchOnWindowFocus: false). Config completa em `docs/tanstack-query.md`
- Clerk provider — **Clerk Core 3 (março 2026, v6+)**: usar `<Show when="signed-in">` em vez de `<SignedIn>`/`<SignedOut>`/`<Protect>` (deprecated). `getToken()` agora lança `ClerkOfflineError` (importar de `@clerk/react/errors`) quando offline — ainda retorna `null` se não autenticado
- Uma página hello world que faz fetch via hono/client RPC tipado (ver abaixo)
- Sonner como toast provider
- Tailwind CSS configurado

**Hono RPC — type-safety end-to-end** (obrigatório):
- API deve exportar `type AppType = typeof app` (ou `typeof route` para sub-rotas)
- Frontend faz `import type { AppType } from "@projeto/api"` e cria client: `hc<AppType>(baseUrl)`
- Isso é um `import type` — eliminado em compile time, sem dependência runtime. É a única exceção permitida para imports entre apps (ver `docs/monorepo-setup.md`)
- Garante autocompletion e validação de tipos em todas as chamadas — substitui definição manual de tipos de resposta

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

## Fase 8 — CI, GitHub e Git

**Ação**: configurar CI, padrão GitHub e fazer primeiro commit.

1. Criar `.github/workflows/ci.yml` seguindo o pipeline em `docs/ci-github-actions.md`
2. Criar `.github/dependabot.yml` seguindo `docs/github-setup.md` (ecosystem `bun` + `docker` + `github-actions`, com `directories` plural para workspaces)
3. Criar `.github/pull_request_template.md` e `.github/CODEOWNERS` seguindo `docs/github-setup.md`
4. **Antes de commitar**: validar que `.gitignore` (criado na Fase 2) cobre `.env*`, `node_modules/`, `dist/`, `.DS_Store`. Sem isso, `git add .` pode incluir secrets.
5. `git init && git add . && git commit -m "feat: initial scaffold"`
6. Criar repositório vazio no GitHub (UI ou `gh repo create <org>/<nome> --private --source=. --remote=origin`)
7. Se criou pela UI: `git remote add origin <url-do-repo>` e depois `git push -u origin main`
8. Configurar **branch protection em `main`** via UI do GitHub (checklist em `docs/github-setup.md`)

**Hard constraints**:
- Conventional Commits desde o primeiro commit
- Branch `main` — trunk-based
- CI roda: install → lint → typecheck → test:coverage → osv-scanner → SonarQube → build
- Build falha se qualquer step falhar
- Dependabot com `package-ecosystem: "bun"` (nativo), nunca `"npm"`
- **`timeout-minutes: 15` em todo job** do `ci.yml` (e qualquer outro workflow criado depois) — teto da org. Sem o campo, GitHub aplica default de 360 min e um job travado consome runner-minutes da org. Ver `docs/ci-github-actions.md`

**Gate**: commit feito, push realizado, CI passa no primeiro run (ou pelo menos lint + typecheck + build). Branch protection ativa em `main`. Primeiro PR do Dependabot aparece conforme o schedule configurado em `.github/dependabot.yml` (padrão: semanal, segunda-feira). Se CI falhar, aplicar o **loop de autocorreção pós-push** de `docs/ci-github-actions.md`: máximo 7 tentativas, logando `step → causa → correção` a cada fix. Nunca considerar tarefa finalizada com CI vermelho.

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
| 8 — CI e Git | Primeiro commit + CI verde |

---

## Anti-patterns (nunca fazer)

- Pular direto para código sem completar as fases — pelo menos 0 a 4 de estrutura, idealmente até 8
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
- **Retornar JSON sem envelope `{ data }`** — frontend sempre espera `response.data`
- **Registrar `clerkMiddleware()` sem checar `CLERK_SECRET_KEY`** — crasha a API inteira em dev sem Clerk
- **Interpolar `Date` do JS em `sql` tagged templates do Drizzle** — sempre usar `.toISOString()`
- **Assumir props de shadcn/ui sem verificar o código fonte** — variantes não-padrão não existem
- **Ignorar campos nullable** — `T | null` do Drizzle propaga para o frontend; tratar com `|| ""` ou `?? undefined`
- **Hardcodar versão do Biome no `biome.json`** sem verificar a versão instalada — rodar `bunx biome migrate --write`
- **Construir frontend antes de testar a API** — verificar responses reais com `curl` antes de definir tipos no frontend
- **Instalar `@hono/clerk-auth`** — depreciado na v3.1.1; usar `@clerk/hono` (mesma API: `clerkMiddleware()` + `getAuth(c)`)
- **Instalar `@clerk/clerk-react`** — pacote renomeado para `@clerk/react` desde Core 2 (v5). Core 3 = v6+
- **Instalar `react-router-dom`** — deprecated/unificado no v7 (ainda funciona como re-export, mas projetos novos usam `react-router` diretamente)
- **Criar `tailwind.config.js` em projeto novo** — Tailwind v4 usa `@import "tailwindcss"` + `@theme { }` no CSS e `@tailwindcss/vite` no Vite
- **Usar o pacote errado de Zod integration do Drizzle** — na stable (0.45.x) usar `drizzle-zod` (v0.8.3+); na beta (≥1.0.0-beta.20) usar `drizzle-orm/zod`. Nunca misturar
- **Usar `import create from 'zustand'`** — Zustand v5 removeu default export, usar `import { create } from 'zustand'`
- **Inventar comandos do drizzle-kit** — os comandos principais são `generate`, `migrate`, `push`. Outros válidos: `pull`, `check`, `up` (upgrade snapshots), `studio`. Não inventar comandos além destes
- **Assumir Biome 1.x config** — Biome agora é 2.x com breaking changes: `include`/`ignore` → `includes`, suppression comments mudaram
- **Usar `@hono/zod-validator` como padrão** — funciona com Zod v4 desde v0.7.6, mas preferir `@hono/standard-validator` que suporta qualquer lib via Standard Schema (mais genérico e futuro-proof)
- **Usar `build.rollupOptions` no Vite 8** — substituído por `build.rolldownOptions` (auto-conversão existe, mas usar `rolldownOptions` em projetos novos)
- **Omitir `out` no `drizzle.config.ts`** — sem o campo `out: "apps/api/src/db/migrations"`, Drizzle Kit gera migrations em `./drizzle` na raiz e os scripts `db:migrate` não encontram os arquivos
- **Não criar o script `data-migrate` no `apps/api/package.json`** — Railway e Portainer executam `bun run data-migrate` no boot; projeto sem o script falha no primeiro deploy com "script not found"
- **Omitir `bunfig.toml`** — sem o arquivo, `bun test --coverage` não enforça o threshold de 80%; o CI passa mesmo com cobertura insuficiente
- **Importar de `@radix-ui/react-*` individualmente** — shadcn/ui (new-york) agora usa pacote `radix-ui` unificado
- **Ignorar breaking changes do Clerk Core 3** — `<Protect>`, `<SignedIn>`, `<SignedOut>` foram deprecated; usar `<Show when="signed-in">`. `getToken()` lança `ClerkOfflineError` (importar de `@clerk/react/errors`) quando offline. `@clerk/types` deprecated → usar `@clerk/react/types`
- **Assumir compatibilidade automática entre majors** de `@clerk/*`, `@hono/*`, `@tanstack/*` — sempre verificar via context7/docs antes de instalar ou atualizar
- **Salvar uploads no filesystem local em produção** — sempre usar S3-compatible storage (`@aws-sdk/client-s3` + `S3_ENDPOINT`)
- **Omitir `timeout-minutes` em jobs de workflows** — sem o campo, GitHub aplica default de 360 min e um job travado consome runner-minutes da org até o teto. Padrão da org: `timeout-minutes: 15` por job em todo workflow
