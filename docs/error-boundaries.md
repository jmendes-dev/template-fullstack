# Error boundaries (frontend)

Ler ao setup inicial do frontend, integrar Sentry, ou ao receber feedback de "tela branca" em produção. Linha-resumo vive em `CLAUDE.md` seção "Production-readiness".

Princípio: **nunca deixar o usuário ver tela branca**. Todo erro de render tem fallback UI, todo async tem Suspense, todo erro reportável vai pro Sentry.

## Por que error boundaries

React por padrão, quando um componente lança erro durante render, **desmonta a árvore inteira**. Sem error boundary, isso = tela branca. Com error boundary, a árvore desmontada é trocada por um fallback.

Error boundaries capturam:
- Erros durante render
- Erros em lifecycle methods
- Erros em constructors

**Não capturam:**
- Event handlers (usar try/catch)
- Código assíncrono fora de render (usar Sentry direto)
- Server-side rendering
- Erros dentro do próprio error boundary

---

## Lib: `react-error-boundary`

Hook-friendly, API melhor que class component custom. Instalar:

```bash
bun add react-error-boundary
```

## Setup no `main.tsx`

Error boundary **raiz** que captura qualquer coisa que escape:

```tsx
import { ErrorBoundary } from 'react-error-boundary';
import * as Sentry from '@sentry/react';
import { RootFallback } from './components/error/RootFallback';

function onError(error: Error, info: { componentStack: string }) {
  if (import.meta.env.VITE_SENTRY_DSN) {
    Sentry.captureException(error, {
      tags: { boundary: 'root' },
      extra: { componentStack: info.componentStack },
    });
  }
  console.error('[RootBoundary]', error, info);
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary FallbackComponent={RootFallback} onError={onError}>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </ErrorBoundary>
  </StrictMode>
);
```

### Componente fallback raiz

```tsx
// src/components/error/RootFallback.tsx
import type { FallbackProps } from 'react-error-boundary';
import { Button } from '@/components/ui/button';

export function RootFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="max-w-md space-y-4 text-center">
        <h1 className="text-2xl font-bold">Algo deu errado</h1>
        <p className="text-muted-foreground">
          Tivemos um erro inesperado. A equipe foi notificada.
        </p>
        {import.meta.env.DEV && (
          <pre className="text-xs text-left bg-muted p-2 rounded overflow-auto">
            {error.message}
          </pre>
        )}
        <div className="flex gap-2 justify-center">
          <Button onClick={resetErrorBoundary}>Tentar novamente</Button>
          <Button variant="outline" onClick={() => (window.location.href = '/')}>
            Ir para o início
          </Button>
        </div>
      </div>
    </div>
  );
}
```

- Stack só em dev (produção não expõe internals)
- `resetErrorBoundary` re-renderiza o subtree — útil pra retry
- `window.location.href = '/'` força reload limpo (limpa state corrompido)

---

## Boundaries aninhados por rota

Erro numa página não deve quebrar o layout inteiro. Cada rota com boundary próprio:

```tsx
// src/routes/dashboard/layout.tsx
import { ErrorBoundary } from 'react-error-boundary';
import { RouteFallback } from '@/components/error/RouteFallback';
import { Outlet } from 'react-router';

export function DashboardLayout() {
  return (
    <div className="flex">
      <Sidebar />
      <main className="flex-1">
        <ErrorBoundary
          FallbackComponent={RouteFallback}
          onError={(err) => reportRouteError(err, 'dashboard')}
        >
          <Outlet />
        </ErrorBoundary>
      </main>
    </div>
  );
}
```

`RouteFallback` mais simples — mantém sidebar/header visíveis, só a área de conteúdo é fallback.

### React Router v7 — errorElement

Alternativa nativa do router. React Router v7 suporta dois modos: **data router** (com `createBrowserRouter`, suporta `loader`/`action`/`errorElement`) e **declarative** (file-based / `<Routes>` JSX, sem loaders). O template default é **data router** — `createBrowserRouter` em `main.tsx`.

```tsx
import { createBrowserRouter, RouterProvider } from 'react-router';

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    errorElement: <RootFallback />, // para erros de loader/action
    children: [
      {
        path: 'dashboard',
        element: <Dashboard />,
        errorElement: <RouteFallback />,
      },
    ],
  },
]);

createRoot(document.getElementById('root')!).render(
  <RouterProvider router={router} />
);
```

`errorElement` captura erros de **loader/action**, não de render. Usar `ErrorBoundary` de `react-error-boundary` para erros de render.

Combinar ambos: router `errorElement` para data fetching, `ErrorBoundary` wrapping pra render.

---

## Suspense para loading

Error boundary + Suspense são pares:

```tsx
<ErrorBoundary FallbackComponent={RouteFallback}>
  <Suspense fallback={<DashboardSkeleton />}>
    <DashboardContent />
  </Suspense>
</ErrorBoundary>
```

- Loading (`Suspense`) e erro (`ErrorBoundary`) têm fallbacks separados
- Ordem importa: `ErrorBoundary` fora de `Suspense` — erro dentro do Suspense ainda é pego

### TanStack Query + Suspense

`useSuspenseQuery` em vez de `useQuery` para integrar com `<Suspense>`:

```tsx
import { useSuspenseQuery } from '@tanstack/react-query';

function Dashboard() {
  const { data } = useSuspenseQuery({
    queryKey: ['dashboard'],
    queryFn: fetchDashboard,
  });
  return <DashboardView data={data} />;
}

// Parent:
<ErrorBoundary FallbackComponent={RouteFallback}>
  <Suspense fallback={<DashboardSkeleton />}>
    <Dashboard />
  </Suspense>
</ErrorBoundary>
```

`useSuspenseQuery` throw errors — `ErrorBoundary` captura. Perfeito.

Ver `docs/tanstack-query.md` para defaults.

---

## Integração com Sentry

Sentry oferece `Sentry.ErrorBoundary` (wrapper sobre `react-error-boundary` com captura automática):

```tsx
import * as Sentry from '@sentry/react';

<Sentry.ErrorBoundary
  fallback={<RootFallback />}
  showDialog={false}  // não mostrar dialog de feedback ao usuário
>
  <App />
</Sentry.ErrorBoundary>
```

Vantagem: captura + contexto Sentry automático. Desvantagem: API `fallback` difere de `react-error-boundary` — se mudar depois, refactor.

**Recomendação**: usar `react-error-boundary` + capturar manualmente no `onError`. Mais controle, menos acoplamento.

### beforeSend sanitização

Sentry config (`apps/web/src/sentry.ts`):

```typescript
Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  tracesSampleRate: 0.1,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  beforeSend(event) {
    // Sanitizar PII
    if (event.user?.email) event.user.email = '[redacted]';
    if (event.request?.cookies) event.request.cookies = '[redacted]';
    return event;
  },
});
```

Carregar condicional:

```typescript
if (import.meta.env.VITE_SENTRY_DSN) {
  await import('./sentry');
}
```

---

## Erros assíncronos fora de render

Error boundaries **não pegam**:

```tsx
function Button() {
  const handleClick = async () => {
    await fetch('/api/fail'); // erro aqui não vai pro boundary
  };
  return <button onClick={handleClick}>Clique</button>;
}
```

Soluções:

### try/catch + toast (erros esperados)

```tsx
const handleClick = async () => {
  try {
    await fetch('/api/fail');
  } catch (err) {
    toast.error('Falha ao processar, tente de novo');
    if (import.meta.env.VITE_SENTRY_DSN) Sentry.captureException(err);
  }
};
```

### `useErrorBoundary` hook (erro deve subir)

`react-error-boundary` expõe hook pra lançar pra um boundary pai:

```tsx
import { useErrorBoundary } from 'react-error-boundary';

function Widget() {
  const { showBoundary } = useErrorBoundary();

  useEffect(() => {
    fetchData().catch(showBoundary);  // joga pro boundary
  }, []);

  return <div>...</div>;
}
```

Usar quando o erro é fatal pro componente — re-render não resolve.

---

## Padrão de fallback

### Níveis de fallback

| Nível | Escopo | UX |
|---|---|---|
| Root | toda a app | "Algo deu errado" + botão home |
| Route | página inteira | "Esta página falhou" + voltar + retry |
| Feature | widget ou card | "Não conseguimos carregar [X]" + retry inline |
| Form | submit falhou | toast + form mantém state |

Cada nível é mais granular e mantém mais contexto visível.

### Exemplo — Feature boundary

```tsx
<Card>
  <CardHeader>Últimas vendas</CardHeader>
  <CardContent>
    <ErrorBoundary fallback={<FeatureFallback label="últimas vendas" />}>
      <Suspense fallback={<Skeleton className="h-24" />}>
        <RecentSales />
      </Suspense>
    </ErrorBoundary>
  </CardContent>
</Card>
```

`FeatureFallback`:

```tsx
export function FeatureFallback({ label }: { label: string }) {
  return (
    <div className="text-sm text-muted-foreground py-4 text-center">
      Não conseguimos carregar {label}.{' '}
      <button className="underline" onClick={() => window.location.reload()}>
        Recarregar
      </button>
    </div>
  );
}
```

---

## Testes

> **Pré-requisito**: testes com `@testing-library/react` exigem setup com `happy-dom`. Ver `docs/testing.md` para instalação e `bunfig.toml`.

```tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'bun:test';
import { ErrorBoundary } from 'react-error-boundary';
import { RootFallback } from './RootFallback';

function Boom(): never {
  throw new Error('boom');
}

describe('ErrorBoundary', () => {
  it('renderiza fallback ao invés da árvore com erro', () => {
    render(
      <ErrorBoundary FallbackComponent={RootFallback}>
        <Boom />
      </ErrorBoundary>
    );

    expect(screen.getByText(/algo deu errado/i)).toBeTruthy();
  });
});
```

Bun test silencia console.error via config (evitar ruído).

---

## Anti-patterns

- Um único error boundary raiz sem boundaries internos — qualquer erro leva a página inteira virar fallback
- Fallback que não permite recover (sem retry, sem home) — usuário preso
- Expor stack trace em prod — leak de caminhos/nomes de função
- `Sentry.captureException` dentro de `render()` — duplica com o que o boundary já reporta
- Esquecer `Suspense` com `useSuspenseQuery` — app throw sem fallback
- Fallback sem estilo (texto cru) — parece bug
- Retry que re-monta com os mesmos dados corrompidos — precisa limpar state/cache primeiro

---

## Checklist de rollout

- [ ] `react-error-boundary` instalado
- [ ] `ErrorBoundary` raiz em `main.tsx` com `RootFallback`
- [ ] Boundaries por rota (React Router `errorElement` ou wrapping manual)
- [ ] Boundaries por feature crítica (cards, widgets)
- [ ] `Suspense` emparelhado com cada `ErrorBoundary` onde há async
- [ ] Sentry integrado via `onError` callback
- [ ] `beforeSend` sanitizando PII
- [ ] Stack só em `import.meta.env.DEV`
- [ ] Teste unitário do fallback raiz
- [ ] Teste de smoke: forçar um throw e confirmar que Sentry recebeu
