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
