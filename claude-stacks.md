# CLAUDE.md

## Diretrizes comportamentais

Reduzem erros comuns de LLM ao escrever código. Essas diretrizes têm precedência sobre as regras técnicas abaixo. Tradeoff: priorizam cautela sobre velocidade — para tarefas triviais, usar bom senso.

### 1. Pensar antes de codar

Não assumir. Não esconder confusão. Levantar tradeoffs.

Antes de implementar:

- Declarar assunções explicitamente. Se incerto, perguntar
- Se existem múltiplas interpretações, apresentar — não escolher em silêncio
- Se existe uma abordagem mais simples, dizer. Contrapor quando justificado
- Se algo não está claro, parar. Nomear o que confunde. Perguntar

### 2. Simplicidade primeiro

Código mínimo que resolve o problema. Nada especulativo.

- Sem features além do pedido
- Sem abstrações para código de uso único
- Sem "flexibilidade" ou "configurabilidade" que não foi pedida
- Sem error handling para cenários impossíveis
- Se escreveu 200 linhas e cabia em 50, reescrever

Pergunta de validação: "um engenheiro sênior diria que isso está overengineered?" Se sim, simplificar.

### 3. Mudanças cirúrgicas

Tocar só no que precisa. Limpar só a própria bagunça.

Ao editar código existente:

- Não "melhorar" código, comentários ou formatação adjacentes
- Não refactorar o que não está quebrado
- Manter o estilo existente, mesmo que você faria diferente
- Se notar código morto não relacionado, mencionar — não deletar

Quando suas mudanças criam órfãos:

- Remover imports/variáveis/funções que **suas** mudanças tornaram inúteis
- Não remover código morto pré-existente sem pedido

Teste: toda linha alterada rastreia direto até o pedido do usuário.

### 4. Execução dirigida por objetivo

Definir critério de sucesso. Iterar até verificar.

Transformar tarefas em goals verificáveis:

- "Adicionar validação" → "Escrever testes para inputs inválidos, então fazê-los passar"
- "Consertar o bug" → "Escrever teste que reproduz o bug, então fazê-lo passar"
- "Refactorar X" → "Garantir que os testes passam antes e depois"

Para tarefas multi-step, declarar plano breve:

```
1. [passo] → verificar: [check]
2. [passo] → verificar: [check]
3. [passo] → verificar: [check]
```

Critério forte de sucesso permite iterar independente. Critério fraco ("fazer funcionar") exige clarificação constante.

---

## Stack

Monorepo TypeScript ≥6.0 · Bun ≥1.3 · Hono ≥4.12.14 (CVE-2026-29045 corrigida em 4.12.4 · CVE-2026-39407 em 4.12.12 · cookie bypass em 4.12.14) · React 19.2+ · React Router v7.14+ · TanStack Query v5.99+ · Zustand v5+ · Drizzle ORM ≥0.45.2 · Drizzle Kit ≥0.31 · PostgreSQL · Biome 2.4+ · Vite 8 (Rolldown) · `@vitejs/plugin-react` v6+ · Tailwind CSS v4.2+ · Zod v4.0+ · `@clerk/react` v6+ (Core 3) · `@clerk/hono` v0.1+ · Node ≥22.12 ou ≥24.x (para tooling; Node 20 EOL abr/2026). Detalhes por camada: `docs/tech-stack.md`. Versões + breaking changes: `docs/version-matrix.md`.

## Bun 1.3

Lockfile `bun.lock` (não `bun.lockb`) · hot reload `bun --hot` · `Bun.cron()` in-process disponível desde Bun 1.3.12 (lançado 9/abr/2026, funciona em containers) · latest 1.3.13 (20/abr/2026) · imagem runtime `oven/bun:1.3-slim`. Notas completas: `docs/bun-notes.md`.

## Estrutura

```
apps/web/         # React 19 + React Router v7 + shadcn/ui (Vite)
apps/api/         # Hono REST + RPC
packages/shared/  # Zod schemas, Drizzle schema, tipos compartilhados
```

## Monorepo — regras de importação

- Bun workspaces (`"workspaces": ["apps/*", "packages/*"]` no root)
- `apps/api` → `packages/shared` · `apps/web` → `packages/shared`
- `apps/api` ✕ `apps/web` — nunca importar código runtime entre apps. Toda comunicação via HTTP/RPC. Única exceção: `import type { AppType }` no frontend para Hono RPC
- Apps importam de `@projeto/shared` (barrel file), nunca de caminhos internos
- Comandos por workspace: `bun run --filter=@projeto/<nome> <script>`

Setup completo (linkage, exports, RPC tipado): `docs/monorepo-setup.md`.

## Tailwind CSS v4

CSS-first: `@import "tailwindcss"` + `@theme {}` no CSS, plugin `@tailwindcss/vite` no Vite. Não criar `tailwind.config.js` em projeto novo. Detalhes e breaking changes: `docs/tailwind-v4.md`.

## Variáveis de ambiente obrigatórias

**Obrigatórias em `.env` local / Portainer**: `DATABASE_URL` · `CLERK_SECRET_KEY` · `VITE_CLERK_PUBLISHABLE_KEY` · `VITE_API_URL` · `APP_CORS_ORIGINS` · `PORT` · `WEB_PORT` · `PGPORT` · `S3_ENDPOINT` · `S3_ACCESS_KEY` · `S3_SECRET_KEY` · `S3_BUCKET`.

**Condicionais (Portainer/dev — MinIO em container)**: `MINIO_PORT` · `MINIO_CONSOLE_PORT`. Em Railway storage usa Railway Buckets — essas vars não existem.

Descrições, defaults e arquivos `.env.*`: `docs/env-vars.md`. Nunca commitar secrets. **Railway**: `PORT` é injetado automaticamente (não setar); vars `S3_*` vêm do addon Railway Buckets. **Portainer**: setar `PORT` explicitamente no compose (`${PORT:-3000}`).

## Regras de estado (nunca misture)

| Categoria | Dono |
|---|---|
| Server state | TanStack Query |
| Client state | Zustand |
| Form state | React Hook Form |
| URL state | React Router search params |

## TanStack Query defaults

`staleTime: 60_000` · `gcTime: 300_000` · `retry: 1` · `refetchOnWindowFocus: false`. Sobrescrever por query apenas quando justificado. Config completa: `docs/tanstack-query.md`.

## API response format (contrato)

- **Sucesso**: `{ data: ... }` (item ou lista) · listas paginadas incluem `pagination: { page, limit, total, totalPages }`
- **Erro**: `{ error: string, code: string, details?: object }`
- Status: 400 validação · 401 não autenticado · 403 sem permissão · 404 não encontrado · 429 rate limit · 500 interno (nunca expor stack em prod)
- Toda rota usa `c.json({ data })`. Nunca array/objeto solto. Middleware global captura exceções.

Exemplos JSON e detalhes: `docs/api-response.md`.

## Resource efficiency (obrigatório)

- Target: **≤256MB RAM por container** em produção
- Dockerfile **sempre multi-stage** (build → `oven/bun:1.3-slim`). Sem devDependencies na imagem final
- API: `bun build --minify --target=bun`. Web: Vite 8 build (Rolldown, 10-30x mais rápido)
- Monitorar: se ultrapassar 256MB, investigar leaks/dependências pesadas

## Deploy: dois targets

- **Railway**: um service por app + PostgreSQL addon + Railway Buckets. Migrations via pre-deploy command. Ver `docs/deploy-railway.md`
- **Portainer**: stack via docker-compose na UI + Traefik + MinIO. Migrations via entrypoint. Ver `docs/deploy-portainer.md`

## Storage

S3-compatible em todos os ambientes via `@aws-sdk/client-s3` + `S3_ENDPOINT`. Nunca filesystem local em prod. Endpoints por ambiente e caveat de checksum: `docs/storage-s3.md`.

## Production-readiness (obrigatório)

- **Health**: `GET /health` + `/ready` + `/live` (ver `docs/observability.md`). Compose: `healthcheck` com `wget`
- **Graceful shutdown**: capturar SIGTERM, fechar conexões DB
- **Logs**: JSON stdout via `pino` com `requestId`. Nunca `console.log` em prod. Error tracking via Sentry condicional: `docs/observability.md`
- **CORS**: origins explícitas via `APP_CORS_ORIGINS`. Nunca `origin: '*'` em prod
- **Security headers**: `hono/secure-headers` + CSP. Ver `docs/security-headers.md`
- **Rate limiting**: `hono-rate-limiter` com 429 + `Retry-After`. Ver `docs/rate-limiting.md`
- **Backup**: Postgres e S3 com retenção ≥30 dias, teste de restore trimestral. Ver `docs/backup-restore.md`
- **Secrets rotation**: Clerk/S3 semestral, Postgres anual, emergencial quando vazar. Ver `docs/secrets-rotation.md`
- **Error boundaries (frontend)**: `ErrorBoundary` raiz + por rota + feature, integrado ao Sentry. Ver `docs/error-boundaries.md`

## Background jobs

Escalar por níveis: `setTimeout`/`queueMicrotask` → tabela `jobs` + `setInterval` → pg-boss. Nunca começar pelo pg-boss. Detalhes: `docs/background-jobs.md`.

## Data migrations

Schema migrations (Drizzle Kit) ≠ data migrations (backfill, seed, transformação). Data migrations em `apps/api/src/data-migrations/YYYYMMDD-descricao.ts`, idempotentes, registradas em `data_migrations_log`, executadas no pre-deploy. Ver `docs/data-migrations.md`.

## Opcionais (adotar só se necessário)

- **i18n**: `@lingui/core` + `@lingui/react`, chaves em `src/locales/<locale>/messages.po`, `Intl` API para datas/números. Ver `docs/i18n.md`
- **Feature flags**: escalar por níveis — env var (Tier 1) → tabela `feature_flags` no Postgres (Tier 2) → SaaS (Tier 3). Toda flag com `expires_at` (data-alvo para remover a flag — semanticamente diferente de `deleted_at` de soft-delete). Ver `docs/feature-flags.md`
- **Email transacional**: Resend + React Email com client condicional (mesmo padrão Clerk/Sentry). Ver `docs/email-resend.md`
- **OpenAPI**: só se a API tem consumidores fora do `apps/web` (mobile, terceiros). Hono RPC já cobre frontend interno. Ver `docs/openapi.md`

## Auth (Clerk)

`clerkMiddleware()` condicional (`if (process.env.CLERK_SECRET_KEY)`), graceful degradation em dev, `getAuth(c)` síncrono no Hono. Padrão completo + Core 3 breaking changes: `docs/auth-clerk.md`.

## Dev workflow (Docker-first)

- **Tudo roda em container** — nunca no host (inclusive dev). `docker compose -f docker-compose.dev.yml up`
- Bind-mount do código para hot reload. `bun install` dentro do container
- Lint, typecheck, test, build: `docker compose exec <service> <comando>`
- Portas via env var com defaults (`PORT`, `WEB_PORT`, `PGPORT`). Se ocupada, incrementar +1
- Compose completo, Dockerfiles de dev e comandos do dia a dia: `docs/docker-dev.md`

## Git workflow

- **Branch strategy**: trunk-based — `main` sempre deployável, feature branches curtas (`feat/`, `fix/`, `chore/`)
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`)
- **PRs**: squash merge para main. CI deve passar antes de merge
- **GitHub setup**: `.github/dependabot.yml` (ecosystem `bun`), `pull_request_template.md`, `CODEOWNERS`, branch protection em `main`. Padrão completo: `docs/github-setup.md`

## Testes

- Runner único: **bun test** (backend e frontend)
- **Cobertura mínima: >= 80%** — enforced via `bunfig.toml` na raiz (`coverageThreshold = { line = 80, function = 80, statement = 80 }`). Sem este arquivo o threshold não é enforced
- **Security review por endpoint**: auth 401/403, injection (SQL/XSS), mass assignment (rejeitar `role`/`isAdmin`), rate limiting 429, CORS, headers (HSTS, X-Content-Type-Options, X-Frame-Options) — automatizado via skill `master-security-review`
- Testes rodam no CI antes de build
- Estrutura, fixtures, mocks e checklist completo: `docs/testing.md`

## CI/CD — GitHub Actions

Pipeline: `install → biome → typecheck → test:coverage → osv-scanner → SonarQube → build`. **Timeout máximo de 15 minutos por job** (`timeout-minutes: 15`) — padrão da org, obrigatório em qualquer pipeline (CI, CD, jobs reutilizáveis). Sem isso, GitHub aplica default de 360 min e job travado queima runner-minutes da org. Loop de autocorreção pós-push: máximo 7 tentativas até CI verde — após esgotar, parar e reportar o último erro ao usuário (nunca forçar merge com CI vermelho). YAML, scripts obrigatórios e loop completo: `docs/ci-github-actions.md`.

## Planejamento

Projeto novo → seguir `START_PROJECT.md`. Feature nova ou dependência desconhecida → consultar context7 MCP para documentação de API/sintaxe (ou docs oficiais). Para versão latest de pacotes, usar `bun info <pacote>` — context7 não é confiável como fonte de versão. Nunca assumir APIs, subpaths ou compatibilidade de versão de memória — sempre verificar.

## Skills disponíveis

Skills user-invocáveis em `.claude/skills/` automatizam fluxos críticos do template:

| Skill | Trigger | Cobre |
|---|---|---|
| `master-prd` | "criar PRD", "novo produto" | Entrevista guiada para gerar PRD |
| `master-plan` | "plano", "fasear PRD" | Quebra PRD em fases verticais |
| `master-fase` | "implementar fase N" | Executa próxima fase do plano até gate verde |
| `master-schema` | "criar tabela", "alterar schema" | Drizzle pgTable + Zod + migration com validação de nullability/imports |
| `master-deploy` | "configurar deploy", "primeiro deploy" | Gera railway.toml ou docker-compose prod (sempre pergunta target — regra 32) |
| `master-security-review` | "review de segurança", "auditar endpoint" | Checklist 9 itens por endpoint Hono com relatório arquivo:linha |
| `master-ci-fix` | "CI quebrou" | Loop de autocorreção até CI verde (máx 7 tentativas) |

## Regras para IA

1. **Schemas compartilhados**: todo tipo/schema novo nasce em `packages/shared` — nunca redefinir
2. **Imports monorepo**: apps importam de `@projeto/shared`, nunca código runtime entre si. Única exceção: `import type` do `AppType` (ver `docs/monorepo-setup.md`)
3. **UI components**: shadcn/ui sempre. Nunca criar do zero se existe equivalente
4. **Data fetching**: TanStack Query + Hono RPC client tipado (`hc<AppType>`). Nunca fetch manual solto
5. **DB changes**: migration Drizzle (`bun run db:generate && bun run db:migrate`)
6. **Estilos**: Tailwind classes. Nunca CSS inline ou arquivos `.css` **de componente** avulsos. O CSS global de entrada (`apps/web/src/index.css`) com `@import "tailwindcss"` + `@theme {}` é exigido pelo Tailwind v4 — ver `docs/tailwind-v4.md`
7. **Contexto de workspace**: informar qual workspace foi modificado (`apps/web`, `apps/api`, `packages/shared`)
8. **Economia de recursos**: antes de adicionar lib nova, verificar se já existe solução na stack atual (ex: não instalar axios — usar `hono/client`). Preferir imports pontuais a pacotes inteiros quando possível. Meta: ≤256MB RAM por container (ver Resource efficiency acima)
9. **Dockerfile**: sempre multi-stage. Imagem final sem devDeps
10. **Versões alinhadas**: pacotes do mesmo ecossistema (`@clerk/*`, `@tanstack/*`, `@hono/*`) devem usar a mesma major. Verificar antes de instalar
11. **SQL injection**: nunca `sql.raw()` com input externo — usar placeholders parametrizados. Converter `Date` com `.toISOString()` antes de interpolar em tagged templates
12. **API response**: envelope `{ data }` ou `{ error, code, details }` — ver `docs/api-response.md`
13. **Commits e branches**: Conventional Commits + branches `feat/`/`fix/`/`chore/` — ver Git workflow acima
14. **Storage**: sempre via S3 SDK (`@aws-sdk/client-s3` + `S3_ENDPOINT`). Nunca filesystem local em prod
15. **Projeto novo**: se o repo não contém `apps/` ou `packages/shared/`, abrir `START_PROJECT.md` e seguir todas as fases em sequência (0–8). Aprovação obrigatória do usuário na Fase 1 (plano + deploy target) **antes de criar qualquer arquivo**
16. **Nullable fields**: colunas Drizzle sem `.notNull()` produzem `T | null`. Frontend **deve** tratar nulls (`user.firstName || ""`, `user.avatarUrl ?? undefined`)
17. **shadcn/ui — verificar antes de usar**: conferir `src/components/ui/<componente>.tsx` antes de passar props. Variantes não-padrão não existem — usar `className`
18. **Contrato API-Frontend**: verificar responses reais da API (curl ou tests) antes de construir o frontend. Nunca inventar campos. Ver `docs/api-response.md`
19. **Biome 2.x**: `includes` (não `include`/`ignore`), suppression `// biome-ignore lint/group/rule:` com `/`. Rodar `bunx biome migrate --write` uma vez ao instalar Biome em projeto novo (Fase 5) ou ao atualizar de Biome 1.x para 2.x. **Linter Domains**: adicionar `"linter": { "domains": { "react": "all" } }` no `biome.json` — sem isso, regras de React não são ativadas automaticamente no 2.x. Detalhes: `docs/version-matrix.md`
20. **Clerk condicional + Core 3**: nunca `clerkMiddleware()` sem checar `CLERK_SECRET_KEY`. `getAuth(c)` síncrono. **Core 3 (v6+)**: `<SignedIn>`/`<SignedOut>`/`<Protect>` deprecated → usar `<Show when="signed-in">`. `@clerk/types` deprecated → importar de `@clerk/react/types`. `getToken()` lança `ClerkOfflineError` (de `@clerk/react/errors`). Ver `docs/auth-clerk.md`
21. **CI verde obrigatório**: loop de autocorreção até 7 tentativas. Ver `docs/ci-github-actions.md`. Nunca concluir com CI vermelho
22. **React Router v7**: instalar `react-router` (não `react-router-dom` — deprecated/unificado no v7, ainda funciona como re-export mas projetos novos usam `react-router` diretamente)
23. **Zustand v5**: `import { create } from 'zustand'` (default export removido)
24. **Zod v4 + Drizzle**: schemas em `packages/shared` como fonte única. Padrão do template: **Drizzle stable (0.45.x)** — usar `drizzle-zod` (v0.8.3+). Migração para beta só com aprovação explícita do usuário. **Com `react-hook-form`**: usar `z.input<typeof schema>` no `useForm` (não `z.infer`) — Zod v4 tornou `input` e `output` distintos. Ver `docs/version-matrix.md`
25. **Vite 8 (Rolldown)**: usar `build.rolldownOptions`. Node ≥22.12 ou ≥24.x (Node 20 EOL abr/2026). Detalhes: `docs/version-matrix.md`
26. **Drizzle**: `defineConfig` de `drizzle-kit`. Campo `out: "apps/api/src/db/migrations"` obrigatório no `drizzle.config.ts` — sem ele, migrations vão para `./drizzle` na raiz e os scripts `db:migrate` não encontram os arquivos. Comandos: `generate`, `migrate`, `push`, `pull`, `check`, `up`, `studio`
27. **Hono validator**: preferir `@hono/standard-validator` (`sValidator`) sobre `@hono/zod-validator`. Ver `docs/version-matrix.md`
28. **shadcn/ui Radix unificado**: pacote `radix-ui` substitui `@radix-ui/react-*` **no estilo `new-york`**. O estilo `default` ainda usa os pacotes individuais. Migrar projeto inteiro: `bunx shadcn@latest migrate radix`. Componente avulso: `bunx shadcn@latest add <componente> --overwrite`
29. **Pacotes**: instalar via `bun add <pacote>` ou `bun add <pacote>@<versão>` — nunca versão manual no `package.json`. Latest real via `bun info` (context7 não é confiável para versão, apenas para docs/API/sintaxe). Nunca migrar para beta/deprecated sem confirmar
30. **Bug fix**: ler arquivo e linha do erro antes de qualquer fix. Nunca adivinhar pela mensagem
31. **GitHub Actions — segurança**: nunca interpolar `${{ github.event.* }}` em `run:`. Passar via `env:` + variável shell. Ver [workflow injections](https://github.blog/security/vulnerability-research/how-to-catch-github-actions-workflow-injections-before-attackers-do/) e `docs/ci-github-actions.md`.
32. **Deploy target**: nunca assumir Railway ou Portainer. Se o usuário não informou, perguntar antes de gerar `docker-compose.yml`, `railway.toml`, Dockerfile de prod ou qualquer config de infra. Ver `docs/deploy-railway.md` e `docs/deploy-portainer.md`
33. **CI timeout obrigatório**: todo job de qualquer workflow GitHub Actions criado neste repo (CI, CD, manuais, reutilizáveis) deve declarar `timeout-minutes: 15` por job — teto da org. Sem isso, GitHub aplica default de 360 min e um job travado consome runner-minutes da org até o limite. Aumentar acima de 15 só com justificativa documentada no PR. Ver `docs/ci-github-actions.md`
