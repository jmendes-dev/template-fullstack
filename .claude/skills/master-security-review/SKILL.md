---
name: master-security-review
description: Roda checklist de segurança por endpoint (auth, authz, validation, mass assignment, injection, rate limit, CORS, secure headers, response envelope) em arquivos de rotas Hono e gera relatório com arquivo:linha + correção mínima. Usar quando o usuário disser "review de segurança", "security review", "auditar endpoint", "revisar rotas", "checar autenticação" ou antes de abrir PR para main com rotas novas.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash
---

Esta skill formaliza a seção "Security review por endpoint" do `CLAUDE.md` (que vive na seção "Testes") e os documentos `docs/security-headers.md`, `docs/rate-limiting.md`, `docs/api-response.md`. Pode rodar em qualquer momento — durante desenvolvimento, antes de commit, ou em revisão de PR.

Toda comunicação em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de qualquer pergunta:

1. Ler `CLAUDE.md` — regras 11 (SQL injection), 12 (response envelope), 18 (contrato API/frontend), 20 (Clerk), seção "Testes" (security review por endpoint)
2. Ler `docs/security-headers.md`, `docs/rate-limiting.md`, `docs/api-response.md`, `docs/auth-clerk.md`
3. Listar arquivos em `apps/api/src/routes/` (ou onde estiverem as rotas Hono)
4. Identificar middleware global em `apps/api/src/index.ts` (CORS, secure headers, rate limit base)

---

## Passo 1 — Definir escopo

Perguntar:

> "Vou fazer security review. Qual o escopo?
>
> 1. **Tudo** — todos os arquivos de rotas em `apps/api/src/routes/`
> 2. **Arquivo específico** — me diz o path (ex: `routes/users.ts`)
> 3. **Mudanças do PR atual** — só arquivos modificados na branch (`git diff main --name-only`)
>
> Default: opção 3 se há diff vs main, senão opção 1."

Tomar decisão sem perguntar se for óbvio (PR aberto = opção 3, branch limpa em main = opção 1).

---

## Passo 2 — Inventariar endpoints

Para cada arquivo no escopo, parsear as rotas Hono:

```typescript
app.get('/users', ...)              // listar
app.get('/users/:id', ...)          // ler
app.post('/users', ...)             // criar (mutativa)
app.patch('/users/:id', ...)        // atualizar (mutativa)
app.delete('/users/:id', ...)       // deletar (mutativa)
```

Anotar: método, path, é mutativa? (POST/PUT/PATCH/DELETE), middlewares aplicados, validators usados.

Mostrar o inventário antes do review:

> "Encontrei **[N] endpoints** em **[M] arquivos**:
>
> | Arquivo | Método | Path | Mutativa? |
> |---|---|---|---|
> | `routes/users.ts` | GET | `/users` | não |
> | `routes/users.ts` | POST | `/users` | sim |
> | [...] |
>
> Vou rodar o checklist completo. Pode levar alguns minutos."

---

## Passo 3 — Aplicar checklist por endpoint

Para cada endpoint, checar os 9 itens abaixo. **Reportar arquivo:linha** para cada falha.

### 3.1 — Auth (401)

- Endpoint protegido tem middleware `clerkMiddleware()` aplicado?
- `getAuth(c)` é chamado e retorna `userId` antes de qualquer lógica que precise de identidade?
- Falta de `userId` retorna `c.json({ error: 'UNAUTHORIZED', code: 'UNAUTHORIZED' }, 401)`?
- Grep por uso de componentes deprecated do Clerk Core 3: `<SignedIn`, `<SignedOut`, `<Protect`, `from '@clerk/types'` → reportar como 🟡 (migrar para `<Show when="signed-in">`, `@clerk/react/types`)

Endpoint público (login, signup, health) está em allowlist explícita? Se sim, marcar como intencional.

### 3.2 — Authz (403)

- Endpoint que mexe em recurso de outro usuário valida ownership?
- `WHERE userId = ${getAuth(c).userId}` em queries de leitura/mutação?
- Roles/permissões verificadas antes da lógica de negócio?
- Negação retorna `c.json({ error: 'FORBIDDEN', code: 'FORBIDDEN' }, 403)`?

Padrão: AuthN ≠ AuthZ. Estar logado não dá direito de mexer em qualquer coisa.

### 3.3 — Validation (400)

- Body/query/params validados com `sValidator` de `@hono/standard-validator`?
- Schema vem de `packages/shared`?
- Erro de validação retorna `c.json({ error: 'VALIDATION', code: 'VALIDATION', details: ... }, 400)`?

Sem validation = aceita qualquer payload. Risco alto.

### 3.4 — Mass assignment

- Schema de input usa `omit({ role: true, isAdmin: true, userId: true, createdAt: true, ... })` ou `pick()` de campos seguros?
- O insert/update no DB usa apenas o objeto validado, **não** o body cru?

Anti-pattern detectável:

```typescript
// ❌ vazamento
const body = await c.req.json();
await db.insert(users).values(body);

// ✅ seguro
const input = c.req.valid('json');  // schema com .omit({ role: true, ... })
await db.insert(users).values(input);
```

### 3.5 — Injection (SQL/XSS)

- Nenhum `sql.raw()` com input externo (regra 11)?
- Tagged templates (`sql\`SELECT ... ${input}\``) com placeholders parametrizados?
- `Date` convertido com `.toISOString()` antes de interpolar?
- Frontend renderiza markdown/HTML user-generated com sanitização (DOMPurify)?

Grep helper: `grep -rn 'sql\.raw' apps/api/src/` e `grep -rn "sql\`" apps/api/src/` (aspas duplas permitem backtick literal sem escape).

### 3.6 — Rate limiting (429)

- Rota mutativa tem `rateLimiter()` de `hono-rate-limiter` aplicado?
- Limites por escopo (login mais restrito que GET genérico)?
- Resposta 429 inclui header `Retry-After`?

Rota de login sem rate limit = brute force aberto.

### 3.7 — CORS

- Middleware `cors()` global usa `origin: (process.env.APP_CORS_ORIGINS ?? '').split(',').filter(Boolean)` (não `'*'`)?
- Se múltiplas origens, validação por callback?
- `credentials: true` apenas se realmente envia cookies?

`origin: '*'` em prod = nenhuma proteção CSRF.

### 3.8 — Secure headers

- Middleware `secureHeaders()` global aplicado em `apps/api/src/index.ts`?
- CSP configurada (mesmo que permissiva no início)?
- HSTS, X-Content-Type-Options, X-Frame-Options presentes?

Verificar com `curl -I https://api.<seu-dominio.com>/health`.

### 3.9 — Response envelope (regra 12)

- Sucesso: `c.json({ data: ... })`?
- Erro: `c.json({ error: '...', code: '...', details: ... }, status)`?
- **Nunca** array/objeto solto no top level?

Anti-pattern detectável: `return c.json(users)` (sem `{ data: }`).

---

## Passo 4 — Checks globais (uma vez por API)

Não por endpoint, mas por boot:

| Check | Verificar em |
|---|---|
| Middleware ordem: `logger/requestId` → `secureHeaders` → `cors` → `rateLimiter` → `clerkMiddleware` → rotas | `apps/api/src/index.ts` |
| Error handler global retorna envelope `{ error, code }` | `app.onError(...)` |
| `process.env.NODE_ENV === 'production'` não vaza stack trace | error handler |
| `clerkMiddleware()` é condicional (regra 20: só se `CLERK_SECRET_KEY` existir) | `apps/api/src/index.ts` |
| Logger não loga `Authorization` header ou body com PII | middleware de log |

---

## Passo 5 — Gerar relatório

Formato Markdown, pronto para colar em comentário de PR:

```markdown
## Security Review — [data] — [N] endpoints

### 🔴 Críticos ([X])

- `apps/api/src/routes/users.ts:42` — POST /users **sem validation** (body cru passado ao insert)
  Fix: criar `createUserSchema` em `packages/shared` e usar `sValidator('json', createUserSchema)`
- `apps/api/src/routes/orders.ts:18` — GET /orders/:id **sem authz** (qualquer user lê pedido alheio)
  Fix: adicionar `WHERE user_id = ${userId}` na query

### 🟡 Médios ([Y])

- `apps/api/src/routes/auth.ts:25` — POST /login sem rate limit
  Fix: aplicar `rateLimiter({ windowMs: 60_000, max: 5 })`
- `apps/api/src/routes/users.ts:50` — response sem envelope `{ data }` (regra 12)
  Fix: `return c.json({ data: user })`

### 🟢 OK

- secureHeaders global ativo
- CORS com origins explícitas
- clerkMiddleware condicional
- 12 endpoints com auth+validation corretos

### Resumo

- Endpoints revisados: [N]
- Críticos: [X]
- Médios: [Y]
- OK: [Z]
- Cobertura: 100% dos endpoints no escopo
```

Se rodando em PR aberto, oferecer:

> "Posso colar este relatório no PR via `gh pr comment`?"

---

## Passo 6 — Aplicar correções (opcional, se usuário pedir)

Se o usuário responder "sim, corrige os críticos", aplicar fix por fix:

1. Ler arquivo
2. Aplicar correção mínima (apenas o que está apontado, sem refactor)
3. Rodar `bun run typecheck` + `bunx biome check .` após cada fix
4. Mostrar diff antes de cada Edit (transparência)

**Nunca** corrigir mais do que o relatório aponta. Se descobrir problema novo durante a correção, anotar para próximo review — não expandir escopo.

---

## Passo 7 — Validação final

Após correções, rodar testes específicos de segurança (idealmente já existem — ver `docs/testing.md` seção "Security review por endpoint"):

```bash
docker compose exec api bun test --grep "security\|401\|403\|429\|injection"
```

Se não existem testes, sugerir:

> "Não achei testes cobrindo cenários de segurança. Recomendo adicionar (ver `docs/testing.md` seção Security review por endpoint). Quer que eu gere os esqueletos para os endpoints revisados?"

---

## Notas para o assistente

### Confidence-based reporting

- **🔴 Crítico**: bug real, exploitable, com fix óbvio (auth ausente, mass assignment, injection)
- **🟡 Médio**: hardening — não é bug ativo, mas recomendado (rate limit em rota não-crítica, CSP mais restritiva)
- **🟢 OK**: já está bom — listar para dar visibilidade ao que está correto

Não inventar problemas. Se `auth` está OK, dizer.

### Falsos positivos

- Endpoint público intencional (login, signup, health) — não reportar como "sem auth"
- `sql.raw()` com input **literal** (não vindo de request) — tolerar como 🟡, mas reportar pedindo comentário inline justificando o uso (regra 11 desencoraja geral)
- `origin: '*'` em **dev** (`if (process.env.NODE_ENV !== 'production')`) — OK

### Não cobrir o que não consegue verificar

- Lógica de negócio errada (ex: cálculo de preço) — fora do escopo desta skill
- Vulnerabilidades de dependências — usar `osv-scanner` (ver `docs/ci-github-actions.md`)
- Secrets vazados em código — `gitleaks` é a ferramenta certa

### Sugestão: integrar `gitleaks` no CI

Se o relatório identificou padrões de secret no código (mesmo que falso positivo), recomendar adicionar `gitleaks` como step no workflow `.github/workflows/ci.yml`:

```yaml
- name: gitleaks
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Roda em todo PR. Bloqueia merge se achar secret. Custo: ~10s a mais no pipeline.

### Idioma

Toda comunicação em **português do Brasil**. Relatório em markdown, frases curtas, foco em ação.

### Quando esta skill ajuda mais

- Antes de PR para `main` com rotas novas
- Após adicionar nova entidade (mass assignment é o erro mais comum)
- Após mudança em middleware global (CORS, rate limit, headers)
- Audit periódico (mensal/trimestral)
