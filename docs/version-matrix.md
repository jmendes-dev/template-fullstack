# Matriz de versões — detalhes técnicos

Ler ao instalar/atualizar pacotes listados abaixo, ao escolher imports, ou ao migrar entre majors. As regras resumidas (uma linha cada) vivem em `CLAUDE.md` seção "Regras para IA".

## Verificação de pacotes — fontes por tipo de dúvida

| Dúvida | Fonte confiável |
|---|---|
| Versão latest de um pacote | `bun info <pacote>` (fallback: `npm view <pacote> version`) |
| Docs/API/sintaxe/breaking changes | context7 MCP → docs oficiais via web |
| Subpath/export existe? | `node_modules/<pacote>/package.json` (campo `exports`) |
| Compatibilidade entre versões | docs oficiais + release notes |

Context7 MCP **não é confiável** para versão latest — pode reportar versão defasada. Nunca migrar para beta/deprecated sem confirmar com o usuário.

## Versões mínimas (referência rápida)

Piso mínimo da stack. Versão latest é responsabilidade do `bun info` na hora da instalação.

| Pacote | Mínimo | Notas |
|---|---|---|
| TypeScript | ≥6.0 | `strict: true`, `moduleResolution: "bundler"` |
| Node | ≥22.12 ou ≥24.x | Vite 8 exige. Node 20.x EOL abr/2026. Node 21.x e 22.0-22.11 não suportados |
| Bun | ≥1.3 | Lockfile `bun.lock` (texto), imagem `oven/bun:1.3` |
| Hono | ≥4.12.14 | CVE-2026-29045 (encoded slash) corrigida em 4.12.4 · CVE-2026-39407 (slashes repetidos) corrigida em 4.12.12 · bypass de cookie parsing corrigido em 4.12.14. Preferir `@hono/standard-validator` |
| hono-rate-limiter | verificar via `bun info` | In-memory single-instance. Para multi-instance usar `@hono-rate-limiter/redis` |
| @hono/standard-validator | ≥0.2.2 | `sValidator` — Standard Schema Spec, aceita Zod/Valibot/ArkType |
| React | 19.2+ | Usar `use()` e Suspense nativo. Error boundaries — ver `docs/error-boundaries.md` |
| React Router | v7.14+ | Pacote `react-router` (não `react-router-dom`). v7.14.0 adicionou suporte ao Vite 8. v7.12.0 adicionou proteção CSRF nativa — ver seção abaixo |
| TanStack Query | v5.99+ | Defaults em `docs/tanstack-query.md` |
| Zustand | v5.0+ | `import { create }` — default export removido |
| Zod | v4.0+ | Com RHF: `z.input<typeof schema>` no useForm |
| Drizzle ORM | ≥0.45.2 stable (ou ≥1.0.0-beta.20) | **CVE-2026-39356** (CVSS 7.5 High — SQL injection via `sql.identifier()`/`.as()`) corrigida em 0.45.2. Stable é o padrão. Beta só com aprovação |
| Drizzle Kit | ≥0.31 | Alinhar com `drizzle-orm` stable. ⚠️ `@latest` no npm resolve para 1.0.0-beta.x — instalar explicitamente: `bun add drizzle-kit@0.31` |
| drizzle-zod | ≥0.8.3 | Suporta Zod v4. Só na stable — beta usa `drizzle-orm/zod` |
| Biome | 2.4+ | Rodar `bunx biome migrate --write` após upgrade |
| Vite | 8.0+ | Rolldown bundler, `build.rolldownOptions` |
| Tailwind CSS | v4.2+ | CSS-first, sem `tailwind.config.js` |
| @clerk/react | v6+ (Core 3) | Renomeado de `@clerk/clerk-react`. Ver `docs/auth-clerk.md` |
| @clerk/hono | v0.1+ | Substitui `@hono/clerk-auth` (depreciado na v3.1.1). `getAuth(c)` síncrono. Ver `docs/auth-clerk.md` |
| shadcn CLI | v4 | Pacote `radix-ui` unificado (new-york style) |
| @vitejs/plugin-react | v6+ | Requer Vite 8+. BREAKING: Babel removido — `react({ babel: {...} })` não funciona mais. Oxc substitui Babel para React Refresh |

## Zod v4 + Drizzle (regra 24)

Dois cenários conforme a versão do `drizzle-orm`:

- **Stable (0.45.x)**: usar pacote `drizzle-zod` (v0.8.3+, já suporta Zod v4 nativamente)

  ```typescript
  import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
  ```

- **Beta (≥1.0.0-beta.20)**: usar `drizzle-orm/zod` integrado (standalone `drizzle-zod` deprecated nesta versão)

  ```typescript
  import { createInsertSchema, createSelectSchema } from 'drizzle-orm/zod';
  ```

Com React Hook Form: usar `z.input<typeof schema>` no `useForm` (não `z.infer`). **`@hookform/resolvers` ≥5.1.0 obrigatório para Zod v4** — versões anteriores (4.x) não suportam Zod v4. Instalar: `bun add @hookform/resolvers@5`.

**Roadmap drizzle-zod**: ao migrar de stable para drizzle-orm v1, substituir `drizzle-zod` por `drizzle-orm/zod`. Os imports mudam mas a API (`createInsertSchema`, `createSelectSchema`) é idêntica.

## Zod v4 — validators top-level

Métodos de instância para formatos comuns foram deprecated no v4. Usar validators top-level:

| Deprecated | Correto |
|---|---|
| `z.string().email()` | `z.email()` |
| `z.string().uuid()` | `z.uuidv4()` |
| `z.string().url()` | `z.url()` |

Validators top-level são schemas independentes (não wrappers de `z.string()`), mais performáticos e compostos.

## Vite 8 / Rolldown (regra 25)

- `build.rollupOptions` substituído por `build.rolldownOptions` (auto-conversão existe para backward compat, mas usar `rolldownOptions` em projetos novos)
- `worker.rollupOptions` substituído por `worker.rolldownOptions`
- `optimizeDeps.esbuildOptions` substituído por `optimizeDeps.rolldownOptions` (afeta configuração do servidor de dev)
- `resolve.tsconfigPaths: true` elimina `vite-tsconfig-paths`
- CSS minification: agora usa **Lightning CSS** por padrão (não esbuild). Reverter com `build.cssMinify: 'esbuild'` se necessário
- Node ≥22.12 ou ≥24.x (Node 20.x EOL abr/2026; 21.x e 22.0-22.11 não suportados)
- **`@vitejs/plugin-react` v6 — Babel removido**: a opção `react({ babel: {...} })` **não funciona mais**. Oxc substitui Babel para React Refresh. Para usar React Compiler, migrar para `@rolldown/plugin-babel`

## Drizzle config (regra 26)

`defineConfig` de `drizzle-kit`. Comandos: `generate`, `migrate`, `push`, `pull`, `check`, `up`, `studio`.

Drizzle Kit migrou de `esbuild-register` para `tsx loader` internamente — melhora compatibilidade com ESM puro e com Bun/Deno. Sem breaking change para o usuário final; útil ao depurar erros de carregamento do `drizzle.config.ts`.

## Hono validator + Zod v4 (regra 27)

Preferir `@hono/standard-validator` (`sValidator`) — suporta qualquer lib via Standard Schema (Zod, Valibot, ArkType). `@hono/zod-validator` funciona com Zod v4 desde v0.7.6+, mas `standard-validator` é mais genérico e futuro-proof.

## Hono — CVEs conhecidas

Todas cobertas pelo pin `≥4.12.14`:

| CVE | CVSS | Descrição | Corrigida em |
|---|---|---|---|
| CVE-2026-29045 | Critical | Bypass de middleware via URL encoding inconsistente (`decodeURI` vs `decodeURIComponent`) em `serveStatic` | 4.12.4 |
| CVE-2026-39407 | Medium | Bypass de `serveStatic` via slashes repetidos (`//`) | 4.12.12 |
| cookie bypass | — | Bypass de cookie parsing via non-breaking space + validação de nomes | 4.12.14 |
| CVE-2026-22817 | 8.2 Critical | JWT Algorithm Confusion — `verify()` aceitava troca `RS256→HS256`. **⚠️ Breaking API**: `verify(token, secret, 'HS256')` — terceiro argumento (algoritmo) se tornou **obrigatório** na 4.11.4. Sem ele: `"alg parameter must be specified"` | ≥4.11.4 |
| CVE-2025-62610 | — | JWT Audience Validation — `aud` não validado por padrão (configurar `verification.aud` explicitamente) | 4.12.x |

## Drizzle ORM — CVEs conhecidas

| CVE | CVSS | Descrição | Corrigida em |
|---|---|---|---|
| CVE-2026-39356 | 7.5 High | SQL Injection via `sql.identifier()` e `.as()` — `escapeName()` não escapava aspas/backticks corretamente, permitindo injection com input não confiável | ≥0.45.2 (stable) · ≥1.0.0-beta.20 (beta) |

⚠️ A regra 11 do CLAUDE.md (`nunca sql.raw() com input externo`) **não cobre** este vetor — `sql.identifier()` e `.as()` também devem receber apenas valores confiáveis ou constantes.

## TypeScript 6.0 — breaking changes (lançado março 2026)

9 defaults mudaram ao mesmo tempo. Principais impactos para a stack:

| Mudança | Detalhe |
|---|---|
| `moduleResolution: "classic"` **removido** | Estratégia pré-Node.js eliminada. Usar `"bundler"` (padrão para ESNext) ou `"nodenext"`. Erro de compilação se ainda configurado explicitamente |
| `types` padrão mudou de auto-lookup → `[]` (array vazio) | Antes o TypeScript puxava automaticamente todos os `@types/*` de `node_modules/@types`. Agora `types: []` por padrão — declarar explicitamente onde necessário, ex: `"types": ["node"]` em `apps/api/tsconfig.json` |
| `esModuleInterop` + `allowSyntheticDefaultImports` sempre ativos | Antes opt-in. **Não é mais possível setar como `false`** — a flag é ignorada silenciosamente. Remover do tsconfig se estiver explicitamente declarado como `false` |
| `rootDir` agora é o diretório do `tsconfig.json` por padrão | Antes era inferido pela estrutura. Em monorepos, declarar `rootDir` explicitamente em cada workspace para evitar comportamento inesperado |
| `strict mode` JS assumido sempre | Sem impacto em TS puro; afeta bundling de módulos legados CJS |
| `target` padrão mudou de `ES3` → `ES2025` | Projetos que omitiam `target` agora compilam para ES2025. Declarar explicitamente em cada workspace |
| `target: "es2025"` + `lib: "es2025"` disponíveis | Tipagens para Temporal API e Map.getOrInsert nativas |

**tsconfig de monorepo**: cada workspace (`apps/api`, `apps/web`, `packages/shared`) deve declarar `"rootDir": "./src"` explicitamente. Para `apps/api`, adicionar `"types": ["node"]` (Bun expõe globals via `@types/bun`, mas Hono + Node.js types precisam ser explícitos). `paths` continuam resolvidos pelo `moduleResolution: "bundler"`.

## Biome 2.x (regra 19)

- `include`/`ignore` → `includes`
- Suppression: `// biome-ignore lint/group/rule:` (com `/`, não `()`)
- Após upgrade: `bunx biome migrate --write`
- **Linter Domains (2.x)**: Biome 2 introduziu domínios de lint (`linter.domains`). Habilitar `"react": "all"` no `biome.json` para ativar regras específicas de React — sem este campo, regras React não são ativadas automaticamente mesmo com `recommended: true`:

  ```json
  {
    "linter": {
      "enabled": true,
      "rules": { "recommended": true },
      "domains": { "react": "all", "types": "all" }
    }
  }
  ```

  `"types": "all"` ativa regras de type-aware linting (adicionadas no Biome 2.4) — requerem inferência de tipos e são mais precisas que análise puramente sintática.

**Biome 2.4.x — `noReactForwardRef` promovida a stable**: React 19 permite passar refs como props normais — `React.forwardRef()` está obsoleto. Com `recommended: true`, esta regra se torna ativa. Código gerado por versões antigas do shadcn/ui pode ter muitos hits. Corrigir: remover o wrapper `forwardRef` e aceitar `ref` como prop direta.

**Biome 2.4.8+ — regras Drizzle**: `noDrizzleUpdateWithoutWhere` e `noDrizzleDeleteWithoutWhere` previnem `db.update(table).set(...)` e `db.delete(table)` sem `.where()` (que afetariam toda a tabela). Habilitar no `biome.json`:

```json
{
  "linter": {
    "rules": {
      "correctness": {
        "noDrizzleUpdateWithoutWhere": "error",
        "noDrizzleDeleteWithoutWhere": "error"
      }
    }
  }
}
```

## shadcn/ui Radix unificado (regra 28)

Pacote `radix-ui` substitui `@radix-ui/react-*` (fev 2026).

- **Projeto existente** (migrar de uma vez): `bunx shadcn@latest migrate radix`
- **Componente avulso**: `bunx shadcn@latest add <componente> --overwrite`

**Base UI (jan 2026)**: shadcn CLI v4 agora permite escolher entre Radix UI e Base UI (MUI team) como primitivo de componentes. Para projetos deste template: **usar Radix UI** (já estabelecido, pacote `radix-ui` unificado). Base UI é alternativa válida mas não é o padrão testado aqui.

## React Router v7 (regra 22)

Instalar `react-router` (não `react-router-dom` — deprecated/unificado no v7, ainda funciona como re-export mas projetos novos usam `react-router` diretamente).

**v7.12.0 — proteção CSRF nativa**: React Router rejeita submissões de `action` vindas de origens externas por padrão. Comportamento correto para a maioria dos casos; configurar `allowedActionOrigins` apenas se a app aceitar submissões legítimas de múltiplas origens (mobile webview, embeds):

```typescript
// react-router.config.ts
import type { Config } from '@react-router/dev/config';

export default {
  allowedActionOrigins: ['https://app.exemplo.com.br'],
} satisfies Config;
```

## Zustand v5 (regra 23)

Usar `import { create } from 'zustand'` (default export removido no v5).

## React 19.2 — adições relevantes

| API | Descrição |
|---|---|
| `<Activity />` | Gerencia estado de atividade de partes da UI (ex: manter estado de aba suspensa sem desmontá-la) |
| `useEffectEvent` | Estabilizado — extrai lógica não-reativa de `useEffect` sem re-trigger desnecessário |
| `cacheSignal` | AbortSignal automático passado para funções cacheadas com React `cache()` |

Sem breaking changes dentro de 19.x. React Compiler (otimização automática de memoization) continua experimental mas estável — não exige alteração de código existente.

**`useId` prefix (19.2.0)**: o prefixo dos IDs gerados mudou de `«r»` (19.1) para `_r_`. Afeta snapshots de testes que comparam IDs hardcoded e hidratação SSR com IDs fixos — atualizar snapshots após migrar para 19.2.

## Zod v4 — mudanças de API (além de validators top-level)

- **`invalid_type_error` e `required_error` removidos**: substituídos pelo parâmetro unificado `error`. Código com esses parâmetros não gera erro de compilação — falha em runtime

  ```typescript
  // ❌ Zod v3 — não funciona em v4
  z.string({ invalid_type_error: 'Deve ser string', required_error: 'Obrigatório' })

  // ✓ Zod v4
  z.string({ error: 'Deve ser string' })
  ```

- **`@zod/mini`**: pacote alternativo (~1.9KB gzip) para frontends onde bundle size é crítico. API idêntica mas tree-shakeable agressivamente

- **`.pick()` e `.omit()` com refinements (v4.3.0+)**: lançam `TypeError` se o schema base tiver `.refine()`, `.superRefine()` ou `.transform()`. No v3 e v4.0–4.2 o comportamento era ignorar silenciosamente — agora é crash. Afeta schemas `drizzle-zod` com refinements customizados encadeados:

  ```typescript
  // ❌ Quebra em Zod v4.3+ se o schema base tem .refine()
  const insertSchema = createInsertSchema(users).refine(/* ... */);
  const dto = insertSchema.pick({ name: true, email: true }); // TypeError

  // ✅ Aplicar .pick() antes do .refine()
  const dto = createInsertSchema(users).pick({ name: true, email: true }).refine(/* ... */);
  ```

## Clerk

Ver `docs/auth-clerk.md` (versões, Core 3 breaking changes).
