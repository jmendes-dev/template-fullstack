# Onda 2 — Scaffold Quality

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer com que projetos scaffoldados a partir deste template **nasçam com docker-compose dev funcional, Vite HMR respondendo em Docker+Windows, padrão RBAC documentado (tabela custom + ADMIN_EMAIL), e pipeline do design system disparando como pré-requisito**. Elimina 3 gaps identificados no diagnóstico: (a) "docker dev quebra", (b) "HMR não funciona no Windows", (c) "routes/roles não funcionam direito".

**Architecture:** Criação de `templates/` no repo raiz contendo samples testados de `docker-compose.yml` e `vite.config.ts` com as flags necessárias para Windows+Docker (`watch.usePolling`, `server.host`, `server.hmr.host`, `CHOKIDAR_USEPOLLING`). Novo `docs/auth-rbac.md` documentando o pattern híbrido Clerk (auth identity) + tabela custom (role) com bootstrap automático via `ADMIN_EMAIL`. Atualização de `claude-stacks.md`, `DESIGN.md`, `.claude/agents/devops-sre-engineer.md` para referenciar esses novos artefatos.

**Tech Stack:** TypeScript (vite.config.ts), YAML (docker-compose), Markdown (docs/agents).

**Decisões do usuário carregadas:**
- RBAC: tabela custom no DB; primeiro usuário é admin via `email === ADMIN_EMAIL` (determinístico, não depende de ordem de cadastro); Clerk continua provendo auth identity.
- MASTER.md: **personalizado por projeto via entrevista** — template NÃO popula valor concreto. Fix: deixar a skill externa `ui-ux-pro-max` como **pré-requisito explícito** de `/new-project`.
- ui-ux-pro-max: dependência externa; instruções de instalação em `DESIGN.md` Parte 2.

**Branch strategy:** `feat/onda-2-scaffold-quality` a partir de main (já mergeada com Onda 1). Commits atômicos por task.

---

## File Structure

| Arquivo | Tipo | Responsabilidade |
|---|---|---|
| `templates/docker-compose.yml` | novo | Sample dev local: api, web, postgres, minio com bind-mounts + polling env vars |
| `templates/vite.config.ts` | novo | Sample com `server.host`, `server.hmr`, `watch.usePolling` para Docker+Windows |
| `templates/README.md` | novo | Explica que `templates/` é fonte de referência para `/new-project`, não runtime |
| `docs/auth-rbac.md` | novo | Padrão RBAC: schema Drizzle + middleware `requireRole` + bootstrap via ADMIN_EMAIL |
| `claude-stacks.md` | modify | Referência a `docs/auth-rbac.md`; adicionar `ADMIN_EMAIL` em env vars; referência a `templates/` |
| `DESIGN.md` | modify | Elevar `ui-ux-pro-max` a pré-requisito explícito no topo da Parte 2 |
| `.claude/agents/devops-sre-engineer.md` | modify | Fase 4 checklist: validar HMR + copiar de `templates/` como baseline |

---

## Task 1: Criar `templates/docker-compose.yml`

**Files:**
- Create: `templates/docker-compose.yml`

- [ ] **Step 1.1: Criar o arquivo com este conteúdo exato**

```yaml
# templates/docker-compose.yml — Sample dev local (copiar para raiz de projeto novo)
#
# Fonte de referência para `/new-project` — devops-sre-engineer deve copiar este arquivo
# e adaptar portas/volumes conforme o projeto específico.
#
# Regras obrigatórias mantidas (ver claude-stacks.md "Dev workflow"):
# - Bind-mount do código para hot reload
# - Env vars CHOKIDAR_USEPOLLING + WATCHPACK_POLLING para Windows+Docker (Vite HMR)
# - Healthcheck em postgres e minio
# - Variáveis via ${VAR:-default}, valores reais no .env local (dev) ou Portainer UI (UAT/PRD)
# - Service backup obrigatório

services:
  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
      target: dev
    ports:
      - "${API_PORT:-3000}:3000"
    environment:
      NODE_ENV: development
      DATABASE_URL: postgres://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@postgres:5432/${POSTGRES_DB:-app}
      CLERK_SECRET_KEY: ${CLERK_SECRET_KEY:-}
      ADMIN_EMAIL: ${ADMIN_EMAIL:-}
      APP_CORS_ORIGINS: ${APP_CORS_ORIGINS:-http://localhost:5173}
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: ${MINIO_ROOT_USER:-minioadmin}
      S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD:-minioadmin}
      S3_REGION: ${S3_REGION:-us-east-1}
      S3_BUCKET: ${S3_BUCKET:-uploads}
      S3_FORCE_PATH_STYLE: "true"
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
    command: bun run --filter=@projeto/api dev
    restart: unless-stopped

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
      target: dev
    ports:
      - "${WEB_PORT:-5173}:5173"
    environment:
      NODE_ENV: development
      VITE_API_URL: ${VITE_API_URL:-http://localhost:3000}
      VITE_CLERK_PUBLISHABLE_KEY: ${VITE_CLERK_PUBLISHABLE_KEY:-}
      # HMR polling obrigatório em Windows+Docker (inotify não propaga pelo WSL2)
      CHOKIDAR_USEPOLLING: "true"
      WATCHPACK_POLLING: "true"
    volumes:
      - ./apps/web:/app/apps/web
      - ./packages/shared:/app/packages/shared
      - /app/node_modules
      - /app/apps/web/node_modules
    depends_on:
      - api
    command: bun run --filter=@projeto/web dev
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    ports:
      - "${PGPORT:-5432}:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-app}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 5s
      timeout: 3s
      retries: 10
    restart: unless-stopped

  minio:
    image: minio/minio:latest
    ports:
      - "${MINIO_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  backup:
    image: ${REGISTRY:-localhost:5000}/backup-postgres:latest
    environment:
      PGHOST: postgres
      PGUSER: ${POSTGRES_USER:-postgres}
      PGPASSWORD: ${POSTGRES_PASSWORD:-postgres}
      PGDATABASE: ${POSTGRES_DB:-app}
      S3_ENDPOINT: http://minio:9000
      S3_ACCESS_KEY: ${MINIO_ROOT_USER:-minioadmin}
      S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD:-minioadmin}
      S3_BACKUP_BUCKET: ${S3_BACKUP_BUCKET:-backup-${APP_NAME:-app}-db}
      BACKUP_INTERVAL: ${BACKUP_INTERVAL:-86400}
      BACKUP_RETENTION_DAYS: ${BACKUP_RETENTION_DAYS:-7}
    depends_on:
      postgres:
        condition: service_healthy
      minio:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:
  minio_data:
```

- [ ] **Step 1.2: Validar sintaxe YAML**

```bash
# Preferir docker compose (v2). Se não disponível, `python -c 'import yaml; yaml.safe_load(open("templates/docker-compose.yml"))'`.
if command -v docker &>/dev/null; then
  docker compose -f templates/docker-compose.yml config --quiet && echo "YAML OK" || echo "FAIL"
elif command -v python3 &>/dev/null; then
  python3 -c "import yaml; yaml.safe_load(open('templates/docker-compose.yml'))" && echo "YAML OK" || echo "FAIL"
else
  echo "SKIP — nenhuma ferramenta de validação disponível"
fi
```

Expected: `YAML OK` ou `SKIP`.

- [ ] **Step 1.3: Commit**

```bash
git add templates/docker-compose.yml
git commit -m "feat(templates): sample docker-compose.yml dev com HMR polling para Windows+Docker

- Services: api, web, postgres, minio, backup (stack completa)
- Bind-mount + anonymous volume para node_modules (hot reload sem sobrescrever deps)
- CHOKIDAR_USEPOLLING + WATCHPACK_POLLING para Windows+WSL2
- Healthcheck em postgres e minio
- Variáveis ${VAR:-default}, nenhum secret hardcoded

Onda 2 · Task 1"
```

---

## Task 2: Criar `templates/vite.config.ts`

**Files:**
- Create: `templates/vite.config.ts`

- [ ] **Step 2.1: Criar o arquivo com este conteúdo exato**

```typescript
// templates/vite.config.ts — Sample para apps/web (copiar e adaptar em /new-project)
//
// Flags obrigatórias para Vite HMR funcionar em Docker+Windows (WSL2):
// - server.host: true  → bind 0.0.0.0 (acessível pelo host)
// - server.hmr.host/clientPort → browser conecta ao host, não ao container
// - server.watch.usePolling → inotify não propaga pelo WSL2 volume mounts
//
// Stack: Vite 8 (Rolldown) + React 19 + Tailwind v4 + React Router v7
// Refs: claude-stacks.md regra 23 (Tailwind v4 CSS-first) e regra 27 (Vite 8).

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],

  resolve: {
    // Vite 8+ resolve paths do tsconfig nativamente — não precisa de vite-tsconfig-paths
    tsconfigPaths: true,
  },

  server: {
    // Expor em 0.0.0.0 para ser acessível pelo host quando rodando em container
    host: true,
    port: Number(process.env.WEB_PORT) || 5173,
    strictPort: true,

    hmr: {
      // Browser conecta no host — não no hostname do container (`web`)
      host: "localhost",
      port: Number(process.env.WEB_PORT) || 5173,
      clientPort: Number(process.env.WEB_PORT) || 5173,
    },

    watch: {
      // Inotify não funciona em volumes bind-mounted no Docker Desktop (Windows/WSL2)
      // Polling é a única opção confiável. 1000ms = balanço entre CPU e latência de HMR.
      usePolling: true,
      interval: 1000,
    },
  },

  build: {
    // Vite 8: rolldownOptions substitui rollupOptions (auto-convert ainda existe para compat)
    rolldownOptions: {
      output: {
        // Chunking padrão — projetos específicos podem override
      },
    },
  },
});
```

- [ ] **Step 2.2: Validar sintaxe TypeScript (sem instalar deps)**

```bash
# Check puramente sintático — não precisa de deps instaladas.
# Usa node para parsear e reportar erros de sintaxe.
node --check templates/vite.config.ts 2>&1 || \
  bun --bun -e "import('./templates/vite.config.ts').catch(e => process.exit(e.message.includes('Cannot find') ? 0 : 1))" 2>&1 || \
  echo "SKIP — sem runtime disponível"
```

Expected: sem erros de parse. Erros de "Cannot find module" são esperados (deps não instaladas) e NÃO são falha.

- [ ] **Step 2.3: Commit**

```bash
git add templates/vite.config.ts
git commit -m "feat(templates): sample vite.config.ts com HMR polling Windows+Docker

- server.host: true + server.port env-aware
- server.hmr.host=localhost + clientPort (browser conecta ao host, não ao container)
- server.watch.usePolling: true interval 1000ms (inotify falha em WSL2 bind-mounts)
- Plugins: @vitejs/plugin-react + @tailwindcss/vite
- resolve.tsconfigPaths: true (Vite 8+)
- build.rolldownOptions (Vite 8 — rollupOptions está deprecated)

Onda 2 · Task 2"
```

---

## Task 3: Criar `templates/README.md`

**Files:**
- Create: `templates/README.md`

- [ ] **Step 3.1: Criar com este conteúdo exato**

```markdown
# templates/ — Samples de referência

> **Não é runtime.** Estes arquivos são copiados (e adaptados) por `/new-project` no scaffold de um projeto consumidor do template.

## Arquivos

| Arquivo | Para onde copiar | Quando |
|---|---|---|
| `docker-compose.yml` | raiz do projeto consumidor | Fase 4 do `start_project.md` |
| `vite.config.ts` | `apps/web/vite.config.ts` | Fase 4, após `bunx shadcn@latest init -t vite` |

## Regras ao copiar

1. **NUNCA** referenciar `templates/` em tempo de execução — é só um ponto de partida.
2. **SEMPRE** ajustar:
   - `docker-compose.yml`: nome do service `backup` (`${APP_NAME}`), portas se conflitam, env vars específicas do projeto.
   - `vite.config.ts`: plugins extras (ex: `@sentry/vite-plugin`), aliases adicionais.
3. **SEMPRE** validar:
   - `docker compose -f docker-compose.yml config --quiet` → sintaxe OK
   - `bun run dev` → HMR funciona: editar um componente → browser recarrega em < 2s

## Checklist HMR (obrigatório em Fase 4)

- [ ] `docker compose up` sobe sem erro
- [ ] `curl http://localhost:${WEB_PORT:-5173}` retorna HTML da app
- [ ] Editar `apps/web/src/App.tsx` (trocar texto) → browser recarrega em < 2s sem F5 manual
- [ ] `docker compose exec web touch /app/apps/web/src/test-hmr.txt` → Vite detecta o evento via polling
- [ ] `docker compose logs postgres` → `database system is ready`
- [ ] `curl http://localhost:${API_PORT:-3000}/health` → `200 OK`

Se qualquer item falhar → não prosseguir para Fase 5. Revisar bind-mounts, env vars de polling, portas.
```

- [ ] **Step 3.2: Commit**

```bash
git add templates/README.md
git commit -m "docs(templates): README explica uso dos samples + checklist HMR obrigatório

Onda 2 · Task 3"
```

---

## Task 4: Criar `docs/auth-rbac.md`

**Files:**
- Create: `docs/auth-rbac.md`

- [ ] **Step 4.1: Criar com este conteúdo exato**

````markdown
# Auth + RBAC — Padrão obrigatório

> Complementa a seção "Auth middleware" de `claude-stacks.md`. Clerk provê **identidade** (quem é o usuário); **papel** (admin/user) é responsabilidade deste projeto, via tabela custom no DB.

---

## Arquitetura

```
┌────────────┐        ┌──────────────┐       ┌──────────────────┐
│  Browser   │ ─JWT─▶ │ clerkMiddle  │──────▶│ getAuth(c)       │
│  (Clerk)   │        │ ware (Hono)  │       │ .userId="user_…" │
└────────────┘        └──────────────┘       └────────┬─────────┘
                                                      │
                                                      ▼
                                             ┌─────────────────┐
                                             │ users (DB)      │
                                             │ clerk_user_id PK│
                                             │ email           │
                                             │ role: admin|user│
                                             └─────────────────┘
```

- **Clerk**: login, sessão, JWT. Fornece `userId` e `email`.
- **Tabela `users`** (neste projeto): espelha o usuário Clerk + guarda o papel.
- **Middleware `requireRole`**: decide permissão consultando a tabela local.

---

## Regra de bootstrap — primeiro admin

Variável de ambiente: `ADMIN_EMAIL` (string — obrigatória).

Ao criar a linha na tabela `users` (primeiro login de cada usuário), o role é atribuído assim:

```ts
const role = user.email === process.env.ADMIN_EMAIL ? "admin" : "user";
```

**Determinístico, não depende de ordem de cadastro.** Quem registrar com `ADMIN_EMAIL` vira admin; todos os outros são `user`. Para promover outros a admin depois, atualizar manualmente a coluna `role` (ou criar endpoint admin-only).

---

## Schema Drizzle

Arquivo: `packages/shared/src/schemas/users.ts`

```ts
import { pgTable, text, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { createInsertSchema, createSelectSchema } from "drizzle-zod";
import { z } from "zod";

export const userRoleEnum = pgEnum("user_role", ["admin", "user"]);

export const users = pgTable("users", {
  clerkUserId: text("clerk_user_id").primaryKey(),
  email: text("email").notNull().unique(),
  role: userRoleEnum("role").notNull().default("user"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const selectUserSchema = createSelectSchema(users);
export const insertUserSchema = createInsertSchema(users);
export type User = z.infer<typeof selectUserSchema>;
export type UserRole = (typeof userRoleEnum.enumValues)[number];
```

Gerar migration: `bun run db:generate && bun run db:migrate`.

---

## Service — ensureUser

Arquivo: `apps/api/src/services/users-service.ts`

```ts
import { db } from "../db";
import { users, type UserRole } from "@projeto/shared";
import { eq } from "drizzle-orm";

/**
 * Garante que o usuário Clerk existe na tabela local.
 * Cria no primeiro acesso com role derivado de ADMIN_EMAIL.
 * Retorna o usuário (com o role persistido).
 */
export async function ensureUser(args: { clerkUserId: string; email: string }) {
  const existing = await db.query.users.findFirst({
    where: eq(users.clerkUserId, args.clerkUserId),
  });
  if (existing) return existing;

  const role: UserRole =
    args.email === process.env.ADMIN_EMAIL ? "admin" : "user";

  const [inserted] = await db
    .insert(users)
    .values({ clerkUserId: args.clerkUserId, email: args.email, role })
    .returning();

  return inserted;
}
```

---

## Middleware — requireRole

Arquivo: `apps/api/src/middleware/require-role.ts`

```ts
import { getAuth } from "@hono/clerk-auth";
import type { MiddlewareHandler } from "hono";
import { ensureUser } from "../services/users-service";
import type { UserRole } from "@projeto/shared";

export function requireRole(...allowed: UserRole[]): MiddlewareHandler {
  return async (c, next) => {
    const auth = getAuth(c);
    if (!auth?.userId) {
      return c.json({ error: "Não autenticado", code: "UNAUTHORIZED" }, 401);
    }

    // Clerk fornece email via sessionClaims.email (requer JWT template configurado)
    // ou via API adicional — aqui assume-se claim presente.
    const email = (auth.sessionClaims?.email as string | undefined) ?? "";
    if (!email) {
      return c.json({ error: "JWT sem email claim", code: "JWT_MISSING_EMAIL" }, 401);
    }

    const user = await ensureUser({ clerkUserId: auth.userId, email });
    if (!allowed.includes(user.role)) {
      return c.json(
        { error: "Sem permissão", code: "FORBIDDEN", details: { required: allowed, actual: user.role } },
        403,
      );
    }

    // Disponibilizar o user no context para o handler
    c.set("currentUser", user);
    await next();
  };
}
```

Tipar o contexto: em `apps/api/src/types/hono.d.ts`:

```ts
import type { User } from "@projeto/shared";
declare module "hono" {
  interface ContextVariableMap {
    currentUser: User;
  }
}
```

---

## Uso em rotas

```ts
// apps/api/src/routes/admin-reports.ts
import { Hono } from "hono";
import { requireRole } from "../middleware/require-role";

export const adminReports = new Hono()
  .use(requireRole("admin"))   // toda rota abaixo exige admin
  .get("/", async (c) => {
    const me = c.get("currentUser");   // tipado como User
    return c.json({ data: { msg: `Olá, admin ${me.email}` } });
  });

// apps/api/src/routes/my-profile.ts — aberto para admin e user
export const myProfile = new Hono()
  .use(requireRole("admin", "user"))
  .get("/", async (c) => {
    const me = c.get("currentUser");
    return c.json({ data: me });
  });
```

---

## Configuração do JWT Clerk

Em `clerk.com → Dashboard → JWT Templates`, criar template que inclui `email` nos claims:

```json
{
  "email": "{{user.primary_email_address}}"
}
```

Frontend pega o token via `<ClerkProvider>` e manda no header `Authorization: Bearer <token>`. Backend lê via `getAuth(c).sessionClaims.email`.

---

## `.env.example` — entries novas

```env
ADMIN_EMAIL=           # email do usuário que vira admin no primeiro cadastro
```

Adicionar a `claude-stacks.md` seção "Variáveis de ambiente obrigatórias".

---

## Testes obrigatórios

Arquivo: `apps/api/src/middleware/__tests__/require-role.test.ts`

Casos mínimos (95% coverage):

| Cenário | Setup | Esperado |
|---|---|---|
| Sem JWT | `Authorization` ausente | 401 `UNAUTHORIZED` |
| JWT sem email claim | Clerk retorna userId sem email | 401 `JWT_MISSING_EMAIL` |
| User novo com email = ADMIN_EMAIL | Primeiro login, env ADMIN_EMAIL=x@y.com, JWT email=x@y.com | 200, role=admin persistido |
| User novo com email ≠ ADMIN_EMAIL | Primeiro login, env ADMIN_EMAIL=x@y.com, JWT email=outro@y.com | 200, role=user persistido |
| User existente acessa rota que exige admin | Role=user na tabela, rota exige admin | 403 `FORBIDDEN` |
| User existente acessa rota que exige qualquer role permitido | Role=user, rota exige admin\|user | 200 |

---

## Checklist de segurança

- [ ] Middleware aplicado em TODA rota que expõe dados sensíveis
- [ ] `ADMIN_EMAIL` definido em produção (validar na boot da API)
- [ ] JWT template do Clerk inclui email claim
- [ ] Rotas admin têm testes 401/403 explícitos
- [ ] Nunca aceitar `role` como input do cliente (mass-assignment protection)
- [ ] Logs de tentativas de FORBIDDEN (para auditoria/alerta)
````

- [ ] **Step 4.2: Commit**

```bash
git add docs/auth-rbac.md
git commit -m "docs(auth): padrão RBAC híbrido Clerk + tabela custom + ADMIN_EMAIL

- Clerk provê identidade; papel (admin/user) vive na tabela users do projeto
- Bootstrap determinístico: email === ADMIN_EMAIL → role=admin (não depende de ordem)
- Schema Drizzle com enum user_role
- Service ensureUser, middleware requireRole, tipagem de context
- JWT template Clerk com email claim
- 6 casos de teste obrigatórios
- Checklist de segurança

Onda 2 · Task 4"
```

---

## Task 5: Atualizar `claude-stacks.md`

**Files:**
- Modify: `claude-stacks.md`

- [ ] **Step 5.1: Adicionar `ADMIN_EMAIL` à lista de env vars**

Localizar o bloco `## Variáveis de ambiente obrigatórias` (linha 83 aprox). O bloco termina com `BACKUP_INTERVAL=...` seguido de fechamento `` ``` ``. Dentro do bloco de código, localizar a linha:

```
CLERK_SECRET_KEY=      # backend auth
```

E inserir **imediatamente após** ela (antes de `VITE_CLERK_PUBLISHABLE_KEY=...`):

```
ADMIN_EMAIL=           # email que vira admin no primeiro cadastro (ver docs/auth-rbac.md)
```

- [ ] **Step 5.2: Atualizar seção "Auth middleware (Clerk) — graceful degradation"**

Localizar o título `## Auth middleware (Clerk) — graceful degradation` (linha 290 aprox) e **imediatamente após o título (antes do primeiro bullet)**, inserir este parágrafo:

```
> **RBAC**: Clerk provê apenas identidade. Papel (`admin`/`user`) vive em tabela custom do projeto. Ver `docs/auth-rbac.md` para schema Drizzle, middleware `requireRole`, service `ensureUser` e bootstrap via `ADMIN_EMAIL`.

```

(Note: the line after the `>` quote has a blank line before the next paragraph — preserve that blank line.)

- [ ] **Step 5.3: Adicionar entry sobre `templates/` na seção "Dev workflow (Docker-first)"**

Localizar o título `## Dev workflow (Docker-first)` (linha 302 aprox) e o primeiro bullet `- **Tudo roda em container**...`. **Antes desse primeiro bullet**, inserir um novo parágrafo:

```
> **Scaffold**: samples de referência em `templates/docker-compose.yml` e `templates/vite.config.ts` — copiar e adaptar em `/new-project`. Contêm flags obrigatórias para HMR funcionar em Docker+Windows (polling do inotify). Ver `templates/README.md`.

```

(Preserve blank line between the `>` quote and the first bullet.)

- [ ] **Step 5.4: Validar**

Ler o arquivo inteiro. Confirmar:
- `ADMIN_EMAIL=` está presente dentro do bloco de env vars, imediatamente após `CLERK_SECRET_KEY=` com comentário correto.
- Seção "Auth middleware" tem o novo parágrafo `> **RBAC**...` como primeira coisa após o título.
- Seção "Dev workflow (Docker-first)" tem o novo parágrafo `> **Scaffold**...` antes do primeiro bullet.
- Nenhum texto existente foi removido.

- [ ] **Step 5.5: Commit**

```bash
git add claude-stacks.md
git commit -m "docs(stacks): referenciar templates/ e docs/auth-rbac.md + ADMIN_EMAIL env var

- Auth middleware: linka para docs/auth-rbac.md (RBAC pattern)
- Dev workflow: linka para templates/ (samples docker-compose e vite.config)
- Env vars: ADMIN_EMAIL adicionada após CLERK_SECRET_KEY

Onda 2 · Task 5"
```

---

## Task 6: Elevar ui-ux-pro-max a pré-requisito em `DESIGN.md`

**Files:**
- Modify: `DESIGN.md`

- [ ] **Step 6.1: Substituir o subtítulo "Instalar ui-ux-pro-max"**

Localizar o título `### Instalar ui-ux-pro-max` (linha 251 aprox) e **substituir apenas essa linha** por:

```markdown
### Pré-requisito — Instalar ui-ux-pro-max ANTES de rodar `/new-project`

> Esta skill é **dependência externa obrigatória**. Sem ela, o Passo 1 do pipeline falha e o `MASTER.md` não é gerado — resultado: projeto nasce com UI genérica shadcn/ui sem personalidade (anti-pattern documentado).
```

- [ ] **Step 6.2: Adicionar nota no topo da Parte 2**

Localizar o título `## Parte 2 — Pipeline do Design System` (linha 239). A linha imediatamente seguinte é o bloco citação `> Gera o design system completo em 3 passos:`. Antes desse bloco de citação, inserir:

```markdown
> ⚠️ **Rodar ANTES** de `/new-project` — ver seção "Pré-requisito — Instalar ui-ux-pro-max" abaixo. O pipeline não tem fallback: sem a skill, não há design system personalizado, e projetos nascem com aparência genérica.

```

(Preserve blank line between this new quote and the existing `> Gera o design system...` quote.)

- [ ] **Step 6.3: Validar**

Ler o arquivo. Confirmar:
- Parte 2 começa com aviso ⚠️ ANTES do `> Gera o design system...`.
- Subtítulo antigo "Instalar ui-ux-pro-max" agora é "Pré-requisito — Instalar ui-ux-pro-max ANTES de rodar `/new-project`".
- Opções A/B de instalação seguem intactas.
- Nenhum outro conteúdo removido.

- [ ] **Step 6.4: Commit**

```bash
git add DESIGN.md
git commit -m "docs(design): ui-ux-pro-max elevada a pré-requisito explícito de /new-project

- Nota ⚠️ no topo da Parte 2: sem skill, pipeline falha
- Subtítulo renomeado para 'Pré-requisito — Instalar ui-ux-pro-max ANTES de /new-project'
- Mantém opções A (Marketplace) e B (CLI) de instalação intactas

Onda 2 · Task 6"
```

---

## Task 7: Atualizar `devops-sre-engineer.md` Fase 4 com checklist HMR

**Files:**
- Modify: `.claude/agents/devops-sre-engineer.md`

- [ ] **Step 7.1: Adicionar bloco ao FINAL da seção FASE 4**

Localizar a seção `### FASE 4 — Desenvolvimento & Integração` (linha 37 aprox). Ela termina com o bullet `- **.env.example** with all required environment variables documented with descriptions.` (linha 51). **Imediatamente após esse bullet e antes do próximo header `### FASE 5`**, inserir:

```markdown
- **Baseline obrigatório**: copiar `templates/docker-compose.yml` e `templates/vite.config.ts` do repo raiz como ponto de partida. Adaptar (não reescrever do zero).
- **Checklist de validação HMR** (gate para avançar à Fase 5 — todos obrigatórios):
  - [ ] `docker compose up -d` sobe todos os services sem erro
  - [ ] `docker compose ps` mostra api, web, postgres, minio, backup como `running/healthy`
  - [ ] `curl http://localhost:${API_PORT:-3000}/health` retorna 200
  - [ ] `curl -I http://localhost:${WEB_PORT:-5173}` retorna 200 com HTML do Vite
  - [ ] Editar `apps/web/src/App.tsx` (trocar uma string visível) → browser recarrega em < 2s SEM F5 manual
  - [ ] `docker compose exec web sh -c 'touch /app/apps/web/src/test-hmr.txt'` é detectado pelo Vite (confirma polling ativo)
  - [ ] `apps/web/vite.config.ts` tem `server.host: true`, `server.hmr.host: "localhost"`, `server.watch.usePolling: true`
  - [ ] `docker-compose.yml` tem `CHOKIDAR_USEPOLLING=true` e `WATCHPACK_POLLING=true` no service `web`
  - [ ] Se qualquer item falhar → não avançar; revisar bind-mounts e env vars de polling antes de continuar
```

- [ ] **Step 7.2: Validar**

Ler o arquivo. Confirmar:
- Seção FASE 4 tem novo bloco "Baseline obrigatório" e "Checklist de validação HMR" antes da FASE 5.
- Nenhum outro conteúdo foi removido.
- Protocolo de Output Obrigatório (final do arquivo) intacto.

- [ ] **Step 7.3: Commit**

```bash
git add .claude/agents/devops-sre-engineer.md
git commit -m "feat(agents): devops-sre Fase 4 ganha baseline templates/ + checklist HMR

- Instrução: copiar templates/docker-compose.yml e templates/vite.config.ts como baseline
- 9 itens de checklist de validação HMR (gate para avançar à Fase 5)
- Bloqueia avanço com HMR quebrado — evita o bug 'editor salva, browser não recarrega'

Onda 2 · Task 7"
```

---

## Task 8: Validação E2E + PR da Onda 2

- [ ] **Step 8.1: Checklist consolidado**

- [ ] `templates/docker-compose.yml` existe e valida em `docker compose config` (ou python yaml)
- [ ] `templates/vite.config.ts` existe e tem `server.host`, `server.hmr.host`, `server.watch.usePolling`
- [ ] `templates/README.md` existe com tabelas e checklist HMR
- [ ] `docs/auth-rbac.md` existe com schema + middleware + testes + checklist de segurança
- [ ] `claude-stacks.md` tem `ADMIN_EMAIL`, referência a `docs/auth-rbac.md` e referência a `templates/`
- [ ] `DESIGN.md` Parte 2 começa com aviso ⚠️ de pré-requisito e subtítulo renomeado
- [ ] `.claude/agents/devops-sre-engineer.md` FASE 4 tem baseline `templates/` e checklist HMR
- [ ] Nenhum arquivo anteriormente presente foi quebrado (git diff shows apenas adições/edições intencionais)

- [ ] **Step 8.2: Push + PR**

```bash
git push -u origin feat/onda-2-scaffold-quality

gh pr create --title "Onda 2 — Scaffold Quality (docker-compose + vite HMR + auth-rbac)" --body "$(cat <<'EOF'
## Summary

Onda 2 de 4 da remediação do template. Corrige 3 gaps de scaffold identificados no diagnóstico:

- **Docker dev quebra + HMR não funciona em Windows** → novos samples em `templates/docker-compose.yml` e `templates/vite.config.ts` com flags corretas (`CHOKIDAR_USEPOLLING`, `server.watch.usePolling`, `server.hmr.host`).
- **Routes/Roles não funcionam direito** → `docs/auth-rbac.md` documenta padrão híbrido Clerk (identidade) + tabela custom (role) com bootstrap determinístico via `ADMIN_EMAIL`.
- **UI feia em projetos novos** → `DESIGN.md` eleva `ui-ux-pro-max` a pré-requisito explícito de `/new-project` (skill externa mantida conforme decisão do usuário).

Também:
- `devops-sre-engineer` ganha checklist de validação HMR como gate da Fase 4 → Fase 5.
- `claude-stacks.md` cita os novos artefatos.

## Commits

- T1 templates/docker-compose.yml (services, polling, healthchecks)
- T2 templates/vite.config.ts (HMR Windows+Docker)
- T3 templates/README.md (uso dos samples + checklist)
- T4 docs/auth-rbac.md (padrão RBAC completo)
- T5 claude-stacks.md (refs + ADMIN_EMAIL)
- T6 DESIGN.md (ui-ux-pro-max pré-requisito)
- T7 devops-sre-engineer.md (FASE 4 checklist HMR)

Plano completo: `docs/superpowers/plans/2026-04-23-onda-2-scaffold-quality.md`

## Test plan

- [x] `docker compose config` valida `templates/docker-compose.yml`
- [x] `node --check` valida sintaxe de `templates/vite.config.ts`
- [x] `docs/auth-rbac.md` tem 6 casos de teste explícitos para `requireRole`
- [x] Revisão independente de cada task (spec + quality)
- [ ] **Smoke test**: em um projeto consumidor do template, copiar `templates/docker-compose.yml` + `templates/vite.config.ts`, rodar `docker compose up`, editar componente → HMR funciona em < 2s (validar após merge, fora desta PR)

## Decisões carregadas desta Onda

- RBAC: tabela custom, `ADMIN_EMAIL` determinístico (não depende de ordem de cadastro)
- MASTER.md: continua vazio no template; personalizado por projeto via entrevista
- ui-ux-pro-max: mantido como dep externa, agora pré-requisito explícito

## Out of scope (Ondas 3-4)

- Onda 3 — Backlog em Ondas: formato `## Wave:` + sync bidirecional + `/finish` atualiza backlog
- Onda 4 — Memória: `adopt-workflow.sh` popular MEMORY.md real; `check-health.sh` densidade por agente

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Ondas subsequentes (planejadas após Onda 2 DONE)

| Onda | Plano a escrever | Status |
|---|---|---|
| Onda 3 — Backlog em Ondas | `docs/superpowers/plans/YYYY-MM-DD-onda-3-backlog-ondas.md` | Pendente |
| Onda 4 — Memória que aprende | `docs/superpowers/plans/YYYY-MM-DD-onda-4-memoria.md` | Pendente |

---

## Self-Review (executada antes de handoff)

**1. Spec coverage:**
- Item 2.1 (docker-compose.dev.yml) → Task 1 ✅
- Item 2.2 (vite.config.ts) → Task 2 ✅
- Item 2.3 (auth-rbac.md) → Task 4 ✅
- Item 2.4 (MASTER.md via entrevista) → Task 6 (eleva skill a pré-requisito, não popula MASTER.md) ✅
- Item 2.5 (checklist DevOps Fase 4) → Task 7 ✅
- Referências cruzadas (claude-stacks.md) → Task 5 ✅
- Explicação do uso dos templates → Task 3 ✅

**2. Placeholder scan:** Nenhum TBD/TODO. Todos os edits têm conteúdo completo.

**3. Type consistency:**
- `ADMIN_EMAIL` grafado igualzinho em Tasks 1, 4, 5.
- `requireRole`, `ensureUser`, `currentUser` têm assinaturas consistentes entre middleware, service e hono.d.ts.
- Task 1 usa `${WEB_PORT:-5173}`; Task 2 usa `process.env.WEB_PORT || 5173`; Task 3 README usa `${WEB_PORT:-5173}` — todos referenciam o MESMO env var com o MESMO default.
- `CHOKIDAR_USEPOLLING` e `WATCHPACK_POLLING` aparecem em Task 1 (docker-compose) e Task 7 (checklist) — nomes idênticos.
