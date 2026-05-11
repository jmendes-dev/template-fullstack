# Auth middleware — Clerk com graceful degradation

Ler ao configurar Clerk, ao criar helpers de auth, ou ao lidar com Clerk Core 3 breaking changes. Regra-resumo (Clerk condicional em dev, `getAuth(c)` síncrono) vive em `CLAUDE.md`.

## Versões e pacotes

- **Pacotes**: `@clerk/react` v6+ (frontend) e `@clerk/hono` v0.1+ (backend). Histórico: `@clerk/clerk-react` foi renomeado para `@clerk/react` no Core 2 (v5). `@hono/clerk-auth` foi depreciado na v3.1.1 — usar `@clerk/hono` (mesma API: `clerkMiddleware()` + `getAuth(c)`)
- **Clerk Core 3** (março 2026, v6+): `<Show when="signed-in">` substitui `<Protect>`/`<SignedIn>`/`<SignedOut>`. Upgrade automatizado: `bunx @clerk/upgrade`
- **Core 3 breaking**:
  - `getToken()` lança `ClerkOfflineError` (importar de `@clerk/react/errors`) quando offline. Ainda retorna `null` se não autenticado
  - `@clerk/types` deprecated → importar de `@clerk/react/types`
  - `<SignedIn>`, `<SignedOut>`, `<Protect>` deprecated e substituídos — usar `<Show when="signed-in">` / `<Show when="signed-out">` / `<Show when={({ has }) => has({ permission: 'org:admin' })}>`
  - `useAuth()` retorna `userId: string | null | undefined` (undefined enquanto carrega) — checar `isLoaded` antes
  - Redirect props removidas: `afterSignInUrl`/`afterSignUpUrl`/`redirectUrl` → usar `fallbackRedirectUrl`/`forceRedirectUrl`/`signUpFallbackRedirectUrl`
  - `client.activeSessions` → `client.sessions`
  - `OrganizationSwitcher`: `afterSwitchOrganizationUrl` → `afterSelectOrganizationUrl`
- **Variáveis de env**: `CLERK_SECRET_KEY` (backend, obrigatória em prod) e `VITE_CLERK_PUBLISHABLE_KEY` (frontend, prefixada com `VITE_` para Vite expor)

---

## Comportamento por ambiente

- Em **produção**, `CLERK_SECRET_KEY` é obrigatória — `clerkMiddleware()` é aplicado em `/api/*`
- Em **dev sem Clerk configurado**, o middleware deve ser condicional: só registrar se `CLERK_SECRET_KEY` existir no env
- Helpers de auth retornam `userId` fixo (`"dev-user"`) quando Clerk não está configurado — dev local sem auth real
- **No Hono, `getAuth(c)` é síncrono** — o middleware já populou o contexto
- Nunca deixar `clerkMiddleware()` crashar a API inteira por falta de env var

---

## Backend — Hono

### Middleware condicional

`apps/api/src/index.ts`:

```typescript
import { Hono } from 'hono';
import { clerkMiddleware } from '@clerk/hono';

const app = new Hono();

if (process.env.CLERK_SECRET_KEY) {
  app.use('/api/*', clerkMiddleware());
}

export default app;
```

`clerkMiddleware()` lê `CLERK_SECRET_KEY` e `CLERK_PUBLISHABLE_KEY` do env automaticamente. Sem essas envs, o middleware crasha — daí a checagem.

### Helper `requireAuth`

`apps/api/src/middleware/auth.ts`:

```typescript
import { getAuth } from '@clerk/hono';
import { HTTPException } from 'hono/http-exception';
import type { Context, Next } from 'hono';

export type AuthContext = {
  userId: string;
  sessionId: string | null;
  orgId: string | null;
};

export function getAuthContext(c: Context): AuthContext {
  // Dev sem Clerk configurado: usuário fake
  if (!process.env.CLERK_SECRET_KEY) {
    return { userId: 'dev-user', sessionId: null, orgId: null };
  }

  const auth = getAuth(c);
  if (!auth?.userId) {
    throw new HTTPException(401, { message: 'Unauthorized' });
  }

  return {
    userId: auth.userId,
    sessionId: auth.sessionId ?? null,
    orgId: auth.orgId ?? null,
  };
}

export async function requireAuth(c: Context, next: Next) {
  const ctx = getAuthContext(c);
  c.set('auth', ctx);
  await next();
}
```

### Uso em rota

```typescript
import { requireAuth } from '@/middleware/auth';

const users = new Hono();

users.get('/me', requireAuth, async (c) => {
  const auth = c.get('auth');
  const user = await db.select().from(usersTable).where(eq(usersTable.clerkId, auth.userId)).limit(1);
  return c.json({ data: user[0] });
});
```

### Webhook (sync user no DB)

Clerk envia eventos via webhook (`user.created`, `user.updated`, `user.deleted`). Usar `verifyWebhook` de `@clerk/hono/webhooks` (API nativa — não requer `svix` diretamente):

```typescript
import { verifyWebhook } from '@clerk/hono/webhooks';

users.post('/webhooks/clerk', async (c) => {
  if (!process.env.CLERK_WEBHOOK_SECRET) {
    return c.json({ error: 'Webhook não configurado', code: 'WEBHOOK_NOT_CONFIGURED' }, 503);
  }

  const evt = await verifyWebhook(c, {
    secret: process.env.CLERK_WEBHOOK_SECRET,
  });

  if (evt.type === 'user.created') {
    await db.insert(usersTable).values({
      clerkId: evt.data.id,
      email: evt.data.email_addresses[0].email_address,
    }).onConflictDoNothing();
  }

  return c.json({ data: { received: true } });
});
```

`verifyWebhook(c)` lê os headers `svix-*` e o body automaticamente — lança `WebhookVerificationError` se a assinatura for inválida (o erro propaga para o error handler global retornando 400).

---

## Frontend — React (Clerk Core 3)

### Provider raiz

`apps/web/src/main.tsx`:

```typescript
import { ClerkProvider } from '@clerk/react';

const PUBLISHABLE_KEY = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY;

if (!PUBLISHABLE_KEY) {
  console.warn('VITE_CLERK_PUBLISHABLE_KEY ausente — auth desabilitada');
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <ClerkProvider publishableKey={PUBLISHABLE_KEY}>
    <App />
  </ClerkProvider>
);
```

### Componente `<Show>` — Core 3

```tsx
import { Show, SignInButton, UserButton } from '@clerk/react';

function Header() {
  return (
    <header>
      <Show when="signed-in">
        <UserButton />
      </Show>
      <Show when="signed-out">
        <SignInButton />
      </Show>
      <Show when={({ has }) => has({ permission: 'org:admin' })}>
        <AdminPanel />
      </Show>
    </header>
  );
}
```

`<Show>` aceita string (`"signed-in" | "signed-out"`) ou função `({ has, user }) => boolean`. Substitui `<SignedIn>`, `<SignedOut>`, `<Protect>` do Core 2.

### Hook `useAuth` — Core 3

```tsx
import { useAuth } from '@clerk/react';
import { ClerkOfflineError } from '@clerk/react/errors';

function ProfilePage() {
  const { isLoaded, userId, getToken } = useAuth();

  if (!isLoaded) return null; // substituir por spinner/skeleton do projeto
  if (!userId) return <SignInButton />;

  const callApi = async () => {
    try {
      const token = await getToken();
      const res = await fetch('/api/me', {
        headers: { Authorization: `Bearer ${token}` },
      });
      // ...
    } catch (err) {
      if (err instanceof ClerkOfflineError) {
        toast.error('Sem conexão — tente novamente');
        return;
      }
      throw err;
    }
  };

  return <button onClick={callApi}>Carregar perfil</button>;
}
```

`getToken()` agora **lança** `ClerkOfflineError` quando offline (Core 3). Antes retornava `null`. Tratar com `try/catch`.

### Tipo de user

```tsx
import type { UserResource } from '@clerk/react/types';
//                              ^^^^^^^^^^^^^^^^^^
// Core 3: era '@clerk/types' (deprecated)
```

### Proteção de rota (React Router v7)

```tsx
import { useAuth } from '@clerk/react';
import { Navigate } from 'react-router';

export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { isLoaded, userId } = useAuth();
  if (!isLoaded) return null; // substituir por spinner/skeleton do projeto
  if (!userId) return <Navigate to="/sign-in" replace />;
  return <>{children}</>;
}
```

```tsx
<Route element={<RequireAuth><DashboardLayout /></RequireAuth>}>
  <Route path="/dashboard" element={<DashboardPage />} />
</Route>
```

---

## Testes

Mockar `@clerk/react` no `bun test`:

```typescript
import { mock } from 'bun:test';

mock.module('@clerk/react', () => ({
  useAuth: () => ({ isLoaded: true, userId: 'user_test', getToken: async () => 'fake-token' }),
  // Cobre string ("signed-in" | "signed-out") e função ({ has }) => boolean
  Show: ({ children, when, fallback }: any) => {
    const result = typeof when === 'function'
      ? when({ has: () => false })
      : when === 'signed-in';
    return result ? children : (fallback ?? null);
  },
}));
```

Para testes de backend, setar `CLERK_SECRET_KEY=sk_test_...` ou deixar vazio (helper retorna `dev-user`).

---

## Checklist de rollout

- [ ] `CLERK_SECRET_KEY` setado em prod (Railway dashboard ou Portainer env)
- [ ] `VITE_CLERK_PUBLISHABLE_KEY` setado no service `web`
- [ ] `clerkMiddleware()` envolvido em `if (process.env.CLERK_SECRET_KEY)`
- [ ] `getAuthContext()` retorna `dev-user` sem env (graceful degradation)
- [ ] Frontend usa `<Show when="...">` (Core 3) e `useAuth().isLoaded`
- [ ] Imports vêm de `@clerk/react/types` (não `@clerk/types`)
- [ ] `getToken()` em `try/catch` para `ClerkOfflineError`
- [ ] Webhook configurado se sincronizar user no DB local (`CLERK_WEBHOOK_SECRET`)
- [ ] Rotas protegidas com `<RequireAuth>` ou middleware backend
