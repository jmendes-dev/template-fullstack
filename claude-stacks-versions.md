# claude-stacks-versions.md — Versões Pinadas

> **Arquivo de manutenção fácil.** Atualizar aqui quando uma versão muda.
> Para regras de uso e padrões técnicos, ver `claude-stacks.md`.
> Sincronizado via `sync-globals.sh` (arquivo global).

> ⚠️ **Fonte de verdade**: a partir da adoção do kit empresa, `claude-stacks.md` (sincronizado via Action corporativa) é a fonte canônica das versões pinadas. Este arquivo registra apenas notas locais de compatibilidade e diffs entre upgrades. Em conflito, `claude-stacks.md` da empresa prevalece — atualizar este arquivo para alinhar.

---

## Versões Atuais

| Tecnologia | Versão mínima | Notas |
|---|---|---|
| TypeScript | ≥ 6.0 | Strict mode obrigatório |
| Bun | ≥ 1.3 | Runtime, PM e test runner |
| Hono | ≥ 4.12.4 | + @hono/standard-validator |
| React | 19 | React Router v7 (não v6) |
| Drizzle ORM | latest | + drizzle-zod para schemas |
| Drizzle Kit | ≥ 0.31 | Geração de migrations |
| PostgreSQL | 16 | |
| Biome | 2.x | Lint + format |
| Vite | 8 (Rolldown) | Plugin @tailwindcss/vite |
| Tailwind CSS | v4 | CSS-first, sem tailwind.config.js |
| Zod | v4 | Via Standard Schema em Hono |
| Node | ≥ 20.19 ou ≥ 22.12 | Apenas para tooling |
| Clerk | Core 3 | @clerk/react (não @clerk/clerk-react) |
| TanStack Query | v5 | |
| shadcn/ui | latest | Instalação via CLI |
| Sonner | latest | Toasts |
| Docker image Bun | oven/bun:1.3 | Para reprodutibilidade |

---

## Notas de Compatibilidade por Versão

### Bun ≥ 1.2

- **Lockfile**: `bun.lock` (JSONC, git-diffable) — padrão. `bun.lockb` (binário) é legado. Se existir, deletar e rodar `bun install`.
- **Isolated installs**: default em novos workspaces (`configVersion = 1`)
- **Bun.SQL**: driver SQL built-in — `postgres.js` continua como padrão no projeto.

### Bun ≥ 1.3

- **Hot reload**: `bun --hot` (soft reload, preserva `globalThis`) vs `--watch` (reinicia). Usar `--hot` para API.
- **Bun.cron**: registra cron jobs no SO — **não funciona em containers Docker**. Em containers, usar `setInterval` + tabela `jobs`.
- **Opcionais**: `bun build --bytecode` (startup rápido), workspace `"catalog"` (centralizar versões).

### Tailwind CSS v4

- Projetos novos: **não criar** `tailwind.config.js`. Configurar via `@theme {}` no CSS.
- Substituir `@tailwind base/components/utilities` por `@import "tailwindcss"` (uma linha).
- `border-*` / `divide-*` usam `currentColor` agora (era `gray-200` no v3) — especificar cor explicitamente.

### Zod v4

- `z.string().email()` e `.url()` sem `z.string().min(1)` aceitam string vazia — adicionar `.min(1)`.
- `z.object().passthrough()` é o padrão — usar `.strip()` explicitamente se quiser remover campos extras.
- `z.infer<>` vs `z.input<>`: usar `z.input<>` para dados de entrada (antes de transformações), `z.infer<>` para dados validados.

### Clerk Core 3

- Pacote: `@clerk/react` (não mais `@clerk/clerk-react` — alias legado ainda funciona mas deprecado).
- `useAuth()` retorna `{ userId, orgId, ... }` — não mais `{ user }`.

### Hono ≥ 4.12

- `@hono/standard-validator` é o middleware de validação recomendado com Zod v4 via Standard Schema.
- `hono/client` para RPC: exportar `type AppType = typeof app`, importar no frontend como `import type`.

---

## Como Atualizar

1. Mudar versão na tabela acima.
2. Adicionar nota de compatibilidade se houver breaking changes.
3. Atualizar `package.json.example` com as versões novas.
4. Commitar e rodar `./sync-globals.sh` nos projetos.
5. Se a mudança é breaking: adicionar entrada no `claude-stacks-refactor.md` do projeto.
