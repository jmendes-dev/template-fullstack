# Testes

Ler ao escrever testes, configurar coverage, definir fixtures, ou estruturar mocks. Regra-resumo (cobertura ≥80%, runner único `bun test`, security review por endpoint) vive em `CLAUDE.md`.

Princípio: **uma só ferramenta** (`bun test`), **três níveis** (unit, integration, e2e), **cobertura como gate** (não decoração).

## Estrutura por workspace

```
apps/api/
├── src/
│   └── routes/users.ts
└── tests/
    ├── routes/users.test.ts        # integration (DB real)
    └── domain/user-service.test.ts # unit (puro)

apps/web/
├── src/
│   └── features/users/UsersList.tsx
└── tests/
    └── features/users/UsersList.test.tsx  # render + interaction

packages/shared/
├── src/
│   └── schema/users.ts
└── tests/
    ├── schema/users.test.ts
    └── test-helpers/
        ├── factories.ts            # createUser(), createOrder()
        └── db.ts                    # setup/teardown de DB de teste
```

Convenção: `<arquivo>.test.ts` ou `<arquivo>.spec.ts`. Bun coleta automaticamente.

## Níveis de teste

| Nível | O que testa | Exemplo | Ferramentas |
|---|---|---|---|
| **Unit** | função pura, sem I/O | validador Zod, formatador de data | `bun test` (sem mocks externos) |
| **Integration** | endpoint + DB real | `POST /users` cria registro | `bun test` + DB de teste |
| **E2E** | fluxo cross-app | login → criar pedido → ver na lista | Playwright (opcional) |

Pirâmide: muito unit, alguns integration, poucos e2e.

## Setup do `bunfig.toml`

> O `bunfig.toml` principal fica na **raiz do monorepo** (conforme `CLAUDE.md` e `START_PROJECT.md` Fase 3). O arquivo raiz aplica a configuração a todos os workspaces. Para override por workspace (ex: `dom = "happy-dom"` apenas no `apps/web`), criar um `bunfig.toml` adicional dentro do diretório do workspace.

```toml
[test]
preload = ["./tests/setup.ts"]      # setup global (DB, mocks)
coverage = true
coverageThreshold = { line = 80, function = 80, statement = 80 }  # falha CI abaixo disso
coverageSkipTestFiles = true
coverageReporter = ["text", "lcov"] # lcov para SonarQube
# dom = "happy-dom"                 # descomentar se usar Testing Library (@testing-library/react)
```

`tests/setup.ts` (root do workspace):

```typescript
import '@testing-library/jest-dom';
import { afterAll, beforeAll } from 'bun:test';
import { setupTestDb, teardownTestDb } from './test-helpers/db';

beforeAll(async () => {
  await setupTestDb();
});

afterAll(async () => {
  await teardownTestDb();
});
```

## Test DB (integration)

Princípio: **DB real, não mock**. Postgres em container ou em-memória (`pg-mem`).

Opção 1 — Postgres em container (mesma imagem da prod, recomendado):

```typescript
// packages/shared/tests/test-helpers/db.ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { migrate } from 'drizzle-orm/postgres-js/migrator';

const TEST_DB_URL = process.env.TEST_DATABASE_URL ?? 'postgres://test:test@localhost:5433/test';

const sql = postgres(TEST_DB_URL, { max: 1 });
export const db = drizzle(sql);

export async function setupTestDb() {
  await migrate(db, { migrationsFolder: 'apps/api/src/db/migrations' });
}

export async function teardownTestDb() {
  await sql`TRUNCATE TABLE users, orders RESTART IDENTITY CASCADE`;
  await sql.end();
}
```

Subir Postgres dedicado em `docker-compose.test.yml` ou reusar o de dev (porta diferente). CI sobe via `services` no GitHub Actions.

Opção 2 — `pg-mem` (mais rápido, menor cobertura de comportamentos reais):

```typescript
import { newDb } from 'pg-mem';
const mem = newDb();
const { db } = mem.adapters.createDrizzle();
```

Use `pg-mem` apenas para validar lógica que não depende de extensões/`gen_random_uuid()`.

## Mocks com Bun

`mock.module()` substitui um módulo inteiro:

```typescript
import { mock, test, expect } from 'bun:test';

mock.module('@projeto/shared/storage', () => ({
  s3: { send: mock(() => Promise.resolve({})) },
  BUCKET: 'test-bucket',
}));

test('upload route calls S3', async () => {
  // ...
});
```

Mocks parciais (só alguns exports):

```typescript
import { spyOn } from 'bun:test';
import * as Clerk from '@clerk/hono';

const getAuthSpy = spyOn(Clerk, 'getAuth').mockReturnValue({ userId: 'user_test_123' });
```

Restaurar no `afterEach`:

```typescript
import { afterEach } from 'bun:test';
afterEach(() => mock.restore());
```

## Fixtures e factories

Centralizar criação de dados de teste:

```typescript
// packages/shared/tests/test-helpers/factories.ts
import { faker } from '@faker-js/faker';
import { db } from './db';
import { users, type User } from '../../src/schema/users';

export async function createUser(overrides: Partial<User> = {}): Promise<User> {
  const [user] = await db.insert(users).values({
    email: faker.internet.email(),
    name: faker.person.fullName(),
    ...overrides,
  }).returning();
  return user;
}
```

Anti-pattern: hardcoded data por teste. Reusa nada, polui o código, esconde intent.

## Exemplos por nível

### Unit (puro)

```typescript
import { describe, expect, test } from 'bun:test';
import { createUserSchema } from '@projeto/shared';

describe('createUserSchema', () => {
  test('aceita email válido', () => {
    expect(() => createUserSchema.parse({ email: 'a@b.com', name: 'X' })).not.toThrow();
  });

  test('rejeita email inválido', () => {
    expect(() => createUserSchema.parse({ email: 'invalido', name: 'X' })).toThrow();
  });
});
```

### Integration (endpoint + DB)

```typescript
import { describe, expect, test, afterEach } from 'bun:test';
import { app } from '../../src/app';
import { db, teardownTestDb } from '../test-helpers/db';
import { users } from '@projeto/shared';
import { createUser } from '../test-helpers/factories';

describe('POST /users', () => {
  afterEach(() => teardownTestDb());

  test('cria usuário', async () => {
    const res = await app.request('/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'novo@exemplo.com', name: 'Novo' }),
    });

    expect(res.status).toBe(201);
    const { data } = await res.json();
    expect(data.email).toBe('novo@exemplo.com');

    const inDb = await db.select().from(users);
    expect(inDb).toHaveLength(1);
  });

  test('rejeita email duplicado com 409', async () => {
    await createUser({ email: 'dup@exemplo.com' });

    const res = await app.request('/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'dup@exemplo.com', name: 'X' }),
    });

    expect(res.status).toBe(409);
  });
});
```

### Frontend (render + interaction)

```typescript
import { describe, expect, test } from 'bun:test';
import { render, screen, fireEvent } from '@testing-library/react';
import { UsersList } from '../../src/features/users/UsersList';

describe('UsersList', () => {
  test('mostra mensagem quando lista vazia', () => {
    render(<UsersList users={[]} />);
    expect(screen.getByText('Nenhum usuário')).toBeInTheDocument();
  });
});
```

Testing Library com Bun: instalar `@testing-library/react`, `@testing-library/dom`, `@testing-library/jest-dom`, `happy-dom` e configurar `bunfig.toml` `[test] dom = "happy-dom"`.

```bash
bun add -d @testing-library/react @testing-library/dom @testing-library/jest-dom happy-dom
```

## Security review por endpoint (obrigatório)

Cada rota mutativa precisa de testes para:

| Cenário | Status esperado | Como testar |
|---|---|---|
| Sem auth | 401 | request sem header `Authorization` |
| Auth de outro user (resource alheio) | 403 | `mock.module(@clerk/hono)` retorna user errado |
| Body inválido (Zod) | 400 | enviar payload faltando campo obrigatório |
| Mass assignment (`role: 'admin'`) | rejeitado ou sanitizado | enviar `role`, `isAdmin`, `userId` no body — esperar que sejam ignorados |
| Rate limit excedido | 429 | loop de N+1 requests no mesmo IP |
| CORS de origem não permitida | bloqueado | request com `Origin` fora do allowlist |
| Headers de segurança | presentes | checar `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security` |
| SQL injection | parâmetro escapado | enviar `'; DROP TABLE users; --` em query/param |
| Response envelope | `{ data }` ou `{ error, code }` | parse JSON e verificar shape |

A skill `/master-security-review` automatiza essa checklist por arquivo de rotas (ver `.claude/skills/master-security-review/`).

Refs: `docs/security-headers.md`, `docs/rate-limiting.md`, `docs/api-response.md`.

## CI

Pipeline completo (incluindo setup do Postgres via `services:` do GitHub Actions) em `docs/ci-github-actions.md`. O threshold de cobertura ≥80% é enforced via `coverageThreshold = { line = 80, function = 80, statement = 80 }` no `bunfig.toml` — o CI falha automaticamente se a cobertura cair abaixo disso.

## Anti-patterns

- Mockar o próprio módulo que está sendo testado — não testa nada
- Teste sem `expect` (passa se rodar sem crashar) — sem assertion = sem teste
- Compartilhar estado entre testes (variáveis globais, DB sem teardown) — flaky
- Testar implementação (`expect(spy).toHaveBeenCalledTimes(2)`) em vez de comportamento (`expect(result).toBe(...)`)
- E2E para tudo — caro, lento, frágil. Use só para fluxos críticos
- Skipar testes em CI (`test.skip`) sem ticket — vira código morto
- Coverage como meta única — 90% de getters/setters não significa qualidade
