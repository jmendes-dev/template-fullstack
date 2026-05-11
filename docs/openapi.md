# OpenAPI / documentação de API (opcional)

Ler **se** a API é consumida por clientes que não são `apps/web` (mobile, terceiros, integrações). Para o frontend interno, o **Hono RPC** já dá type-safety end-to-end (ver `docs/monorepo-setup.md`) — OpenAPI é redundante. Linha-resumo não vive no `CLAUDE.md` por ser opcional.

Princípio: **reaproveitar os schemas Zod** que já vivem em `packages/shared` — não duplicar definições. OpenAPI gerado é fonte única para Swagger UI, geração de SDK em outras linguagens, e documentação consumível.

## Quando adotar

| Caso | Adotar OpenAPI? |
|---|---|
| API só consumida por `apps/web` | Não — Hono RPC cobre |
| Mobile (iOS/Android nativo, Flutter, RN) | Sim |
| Webhook ou integração com terceiros | Sim |
| Sandbox público para parceiros | Sim |
| Painel de admin separado em outro stack (Next.js externo, Vue) | Sim, ou usar Hono RPC se for TypeScript |

## Bibliotecas

| Lib | Quando usar |
|---|---|
| `@hono/zod-openapi` | Padrão recomendado — integra Zod direto no Hono |
| `hono-openapi` | Alternativa lightweight, menos opinionated |

Verificar versões mais recentes com `bun info @hono/zod-openapi` antes de instalar (regra 29).

## Setup com `@hono/zod-openapi`

```sh
bun add @hono/zod-openapi @scalar/hono-api-reference
```

Criar a app via `OpenAPIHono` em vez de `Hono`:

```typescript
// apps/api/src/app.ts
import { OpenAPIHono } from '@hono/zod-openapi';
import { apiReference } from '@scalar/hono-api-reference';

export const app = new OpenAPIHono();

// rotas (ver abaixo)

app.doc('/openapi.json', {
  openapi: '3.1.0',
  info: { title: 'Masterboi API', version: '1.0.0' },
  servers: [{ url: 'https://api.masterboi.com.br' }],
});

app.get('/docs', apiReference({ url: '/openapi.json' }));
```

Em prod, expor `/docs` apenas se for público. Caso contrário, gate por auth ou só em dev (`if (process.env.NODE_ENV !== 'production')`).

## Definição de rota com OpenAPI

Reusa Zod schemas de `packages/shared` — não duplicar:

```typescript
// apps/api/src/routes/users.ts
import { createRoute, OpenAPIHono } from '@hono/zod-openapi';
import { createUserSchema, userSchema } from '@projeto/shared';
import { z } from 'zod';

const errorSchema = z.object({ error: z.string(), code: z.string() });
const dataWrapper = <T extends z.ZodTypeAny>(s: T) => z.object({ data: s });

const createUser = createRoute({
  method: 'post',
  path: '/users',
  tags: ['users'],
  summary: 'Cria usuário',
  request: {
    body: { content: { 'application/json': { schema: createUserSchema } } },
  },
  responses: {
    201: { description: 'Criado', content: { 'application/json': { schema: dataWrapper(userSchema) } } },
    400: { description: 'Validação', content: { 'application/json': { schema: errorSchema } } },
    409: { description: 'Conflito', content: { 'application/json': { schema: errorSchema } } },
  },
});

export const usersRoute = new OpenAPIHono().openapi(createUser, async (c) => {
  const input = c.req.valid('json');
  // ... lógica
  return c.json({ data: created }, 201);
});
```

`c.req.valid('json')` é **tipado** automaticamente a partir do schema — funciona sem `sValidator` extra.

## Servir Swagger UI / Scalar

`@scalar/hono-api-reference` é mais moderno que Swagger UI clássico — UI cleaner, dark mode, exemplos auto-gerados.

```typescript
import { apiReference } from '@scalar/hono-api-reference';

app.get('/docs', apiReference({
  url: '/openapi.json',
  theme: 'purple',
}));
```

Alternativa Swagger UI (compatível com Hono):

```sh
bun add @hono/swagger-ui
```

```typescript
import { swaggerUI } from '@hono/swagger-ui';

app.get('/swagger', swaggerUI({ url: '/openapi.json' }));
```

`swagger-ui-express` **não funciona** com Hono — é middleware Express. Usar sempre `@hono/swagger-ui`. Mesmo assim, Scalar tende a ser melhor UX.

## Geração de cliente em outras linguagens

A partir de `/openapi.json`:

```sh
# TypeScript (alternativa ao Hono RPC para projetos externos)
bunx openapi-typescript https://api.masterboi.com.br/openapi.json -o ./api-types.ts

# Swift (iOS)
swagger-codegen generate -i openapi.json -l swift5 -o ./MasterboiAPI

# Kotlin (Android)
openapi-generator generate -i openapi.json -g kotlin -o ./masterboi-android

# Python
openapi-python-client generate --url https://api.masterboi.com.br/openapi.json
```

Gerar no CI quando a API muda — versionar o cliente como pacote separado.

## Auth no spec

Documentar `Authorization: Bearer <token>` no spec:

```typescript
app.openAPIRegistry.registerComponent('securitySchemes', 'BearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
});

const protectedRoute = createRoute({
  // ...
  security: [{ BearerAuth: [] }],
  responses: {
    401: { description: 'Sem auth', content: { 'application/json': { schema: errorSchema } } },
    // ...
  },
});
```

Scalar/Swagger renderizam botão "Authorize" quando o spec tem `securitySchemes`.

## Versionamento

URL versioned (`/v1/users`, `/v2/users`) em vez de header — mais simples para consumidores externos.

```typescript
const v1 = new OpenAPIHono();
v1.openapi(createUser, /* ... */);

app.route('/v1', v1);

app.doc('/v1/openapi.json', { /* ... */ });
```

## Coexistência com Hono RPC

`OpenAPIHono` ainda exporta `AppType` — Hono RPC continua funcionando para `apps/web`:

```typescript
export type AppType = typeof app;
```

Ou seja: zero custo de manter os dois ao mesmo tempo.

## Anti-patterns

- Manter spec OpenAPI **separado** dos schemas Zod (ex: arquivo `.yaml` à parte) — duplicação que diverge silenciosamente
- Expor `/docs` público em prod com endpoints sensíveis listados — gate por auth ou só em dev
- Versionar via header customizado (`X-API-Version: 2`) sem URL — confunde consumidores e ferramentas
- Gerar cliente no consumidor sem versionar — quebra silenciosamente quando a API muda
- Documentar errors genéricos (`500: 'Internal'`) sem o `code` real — consumer não sabe distinguir falhas
- Adicionar OpenAPI antes de ter consumidores externos reais — overhead sem ganho
