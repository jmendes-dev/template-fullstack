# TanStack Query — defaults e padrões

Ler ao configurar o `QueryClient` no frontend, ao decidir sobrescrever defaults por query, ou ao escrever mutations/invalidations. Regra-resumo (valores dos defaults em uma linha) vive em `CLAUDE.md`.

## Defaults globais

```typescript
// apps/web/src/lib/query-client.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60,        // 1 min — cache "fresco" sem refetch
      gcTime: 1000 * 60 * 5,       // 5 min — quanto tempo mantém em memória após sair
      retry: 1,                    // retry uma vez em erro de rede
      refetchOnWindowFocus: false, // evitar refetch agressivo
    },
    mutations: {
      retry: 0,                    // nunca repetir mutation automaticamente
    },
  },
});
```

## Quando sobrescrever defaults

| Caso | Override | Justificativa |
|---|---|---|
| Polling de dashboard | `refetchInterval: 5000` | dado muda em background |
| Recurso muito custoso | `staleTime: 1000 * 60 * 30` | evitar refetch em navegação rápida |
| Recurso volátil (notificações) | `staleTime: 0, refetchOnMount: 'always'` | sempre buscar fresh |
| Lista paginada | `placeholderData: (prev) => prev` | evitar flicker entre páginas (keepPreviousData removido no v5) |

Sem override sem motivo — defaults cobrem 90% dos casos.

## queryFn padrão com Hono RPC

```typescript
// apps/web/src/lib/api-client.ts
import { hc } from 'hono/client';
import type { AppType } from '@projeto/api';

export const api = hc<AppType>(import.meta.env.VITE_API_URL);
```

```typescript
// apps/web/src/features/users/hooks.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api-client';
// ApiError — definida em apps/web/src/lib/api-client.ts (ver docs/rate-limiting.md)
import { ApiError } from '@/lib/api-client';

export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const res = await api.users.$get();
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const { data } = await res.json();   // unwrap envelope (regra 12)
      return data;
    },
  });
}
```

## Mutations + invalidation

```typescript
export function useCreateUser() {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: async (input: { name: string; email: string }) => {
      const res = await api.users.$post({ json: input });
      if (!res.ok) {
        const { error, code, details } = await res.json();
        throw new ApiError(error, code, details);
      }
      const { data } = await res.json();
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

**Princípios**:
- `queryKey` hierárquica: `['users']` invalida tudo; `['users', userId]` invalida só um
- Invalidate no `onSuccess`, nunca no componente
- Tratar erro fora do hook (toast no consumer via `useEffect` ou `onError` do useMutation)

## Optimistic updates

Para UX instantânea (toggle de like, marcar como lida):

```typescript
export function useToggleFavorite() {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: async (postId: string) => {
      const res = await api.posts[':id'].favorite.$post({ param: { id: postId } });
      if (!res.ok) throw new Error('failed');
    },

    // Antes do request: atualiza o cache e guarda snapshot pra rollback
    onMutate: async (postId) => {
      await qc.cancelQueries({ queryKey: ['posts'] });
      const previous = qc.getQueryData<Post[]>(['posts']);

      qc.setQueryData<Post[]>(['posts'], (old) =>
        old?.map((p) => (p.id === postId ? { ...p, favorite: !p.favorite } : p))
      );

      return { previous };
    },

    // Falhou: rollback
    onError: (_err, _postId, context) => {
      if (context?.previous) qc.setQueryData(['posts'], context.previous);
    },

    // Sempre: garantir consistência com o servidor
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ['posts'] });
    },
  });
}
```

Não usar optimistic update para tudo — só onde a latência machuca a UX. Para forms tradicionais, mostrar loading state e esperar resposta.

## Anti-patterns

- `enabled: !!user` em query que depende de auth — preferir `useSuspenseQuery` + Suspense boundary
- Esquecer de unwrap `{ data }` — TypeScript pega, mas vale lembrar (regra 18)
- `queryKey` com objeto não-serializável (Date sem ISO, Map, Set) — usar primitivos ou strings
- Mutation com `retry: 1+` — pode duplicar inserts/cobrar 2x
- `refetchOnWindowFocus: true` global — agressivo demais, ativa em cada Alt+Tab
- `staleTime: 0` global — derruba o ponto de ter cache

## Provider no root

```typescript
// apps/web/src/main.tsx
import { QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { queryClient } from './lib/query-client';

createRoot(document.getElementById('root')!).render(
  <QueryClientProvider client={queryClient}>
    <App />
    {import.meta.env.DEV && <ReactQueryDevtools initialIsOpen={false} />}
  </QueryClientProvider>
);
```

Devtools só em dev — não bundlear em prod.
