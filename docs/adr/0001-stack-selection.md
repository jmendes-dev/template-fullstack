# ADR-0001 — Seleção de Stack

**Data:** YYYY-MM-DD
**Status:** Aceito
**Autores:** [equipe]

---

## Contexto

Precisamos definir a stack tecnológica para [Nome do Projeto]. Os requisitos determinantes são:

- Runtime com performance de I/O alta e DX moderna (TS-first)
- ORM com inferência de tipos sem codegen
- Deploy target: [Railway / Portainer]
- Time pequeno — menos ferramentas é mais foco

---

## Decisão

Adotamos a stack definida em `claude-stacks.md`:

| Camada | Tecnologia | Versão |
|---|---|---|
| Runtime | Bun | ≥1.3 |
| Backend framework | Hono | ≥4.12 |
| Frontend | React 19 + Vite 8 | — |
| ORM | Drizzle + DrizzleKit | ≥0.31 |
| Banco | PostgreSQL | 16 |
| Validação | Zod v4 | — |
| Auth | Clerk | Core 3 |
| UI | Tailwind CSS v4 + shadcn/ui | — |
| Lint/Format | Biome 2.x | — |
| Monorepo | Turborepo | — |

---

## Alternativas consideradas

| Alternativa | Razão da rejeição |
|---|---|
| Node + Express | DX inferior ao Bun/Hono; sem types nativos no request |
| Prisma | Codegen pesado; Drizzle tem inferência mais enxuta |
| Vite + Remix | SSR não é requisito; SPA com TanStack Router é suficiente |
| Next.js | Coupling forte com Vercel; team prefere mais controle |

---

## Consequências

**Positivas:**
- Stack TypeScript end-to-end sem gaps de tipos entre camadas
- Startup time < 1s em dev (Bun)
- ORM sem magic — queries Drizzle são SQL previsível

**Negativas / riscos:**
- Bun ainda < 2.0 — breaking changes possíveis (monitorar CHANGELOG)
- Clerk pricing escala com MAU — avaliar self-hosted se MAU > 10k
- `shadcn/ui` adiciona componentes no source — cuidado com surface de manutenção

**Monitorar:**
- [ ] Bun releases (atualizar `claude-stacks.md` quando minor breaking)
- [ ] Clerk pricing tier atual: [link]

---

## Referências

- `claude-stacks.md` — regras detalhadas de cada tecnologia
- `start_project.md` — gates de fase para setup inicial
