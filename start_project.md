# start_project.md — Gates de Projeto Novo

> Referência de hard-constraints para cada fase do bootstrap.
> Para o processo completo (entrevista de requisitos + sequência de agentes), usar `/new-project`.
> Para regras de stack, consultar `claude-stacks.md`.

---

## Gates por fase

| Fase | Ação principal | Output obrigatório | Aprovação? | Gate |
|---|---|---|---|---|
| **0 — Contexto** | Ler `CLAUDE.md` completo | — | Não | Consigo responder: stack, estrutura, tecnologias core, padrão de erro, deploy targets, env vars obrigatórias |
| **1 — Planejamento** | Produzir plano em texto (objetivo, deploy target, entidades, endpoints, telas, deps extras) | Plano aprovado | **Sim** | Deploy target confirmado; nenhum arquivo criado antes da aprovação |
| **2 — Scaffold** | Criar estrutura de pastas e configs de workspace | Árvore de diretórios completa | Não | `ls` confirma todas as pastas; estrutura bate com template em `start_project.md` (versão antiga) / `/new-project` |
| **3 — Configs** | `biome.json`, `tsconfig.json` (cada workspace), `vite.config.ts`, `drizzle.config.ts`, CSS principal | Todos os arquivos criados | Não | Arquivos presentes; validação com `bunx biome check .` na Fase 5 |
| **4 — Docker** | Dockerfiles multi-stage + compose files (conforme deploy target) | Containers subindo | Não | `docker compose -f docker-compose.dev.yml up` → todos `healthy`; API responde em `/health` |
| **5 — Deps** | `bun add` por workspace; `bunx biome migrate --write`; `bunx shadcn@latest init` | `bun.lock` commitado | Não | `bun install` sem erros; `bun run typecheck` passa; `bunx biome check .` passa |
| **6 — Banco** | Schema Drizzle + Zod em `packages/shared`; `db:generate`; `db:migrate` | Migration aplicada | Não | `bun run db:generate` → no changes; tabelas existem no PostgreSQL |
| **7 — App base** | Hono app + React app + hono/client RPC; Clerk condicional | Health check verde | Não | `curl /health` → `{ status: "ok" }`; frontend abre; `biome check` + `typecheck` + `db:generate` passam; responses verificadas com curl antes de construir frontend |
| **8 — CI/CD e Git** | `.github/workflows/ci.yml`; CD workflows (Portainer); `git init`; primeiro commit | CI verde | Não | Commit feito; CI passa; CD workflows criados; branches `main` e `uat` existem |
| **9 — Bootstrap memória** | Pré-popular `MEMORY.md` de cada agente via `.superpowers/agent-memory-bootstrap.md` | 10 arquivos MEMORY.md | Não | Todos os 10 `agent-memory/*/MEMORY.md` preenchidos com contexto do projeto |

---

## Hard-constraints globais (valem para todas as fases)

- Deploy target (Railway vs Portainer) é obrigatório — perguntar ao usuário se não informado. Nunca assumir.
- Nenhum arquivo criado antes do plano (Fase 1) ser aprovado pelo usuário.
- Verificar versões antes de instalar: `bun info <pacote>` para versão latest; context7/docs para API. Nunca assumir versões de memória.
- Dockerfiles sempre multi-stage para produção. Sem exceção.
- Toda porta configurável via env var. Nunca hardcoded.
- Todo service com healthcheck. `depends_on` com `condition: service_healthy`.
- Schemas em `packages/shared` — nunca em `apps/api`.
- `tsconfig strict: true` em todos os workspaces, sem exceção.
- Nenhum `eslint`, `prettier` ou linter além do Biome.
- Commit somente com Conventional Commits.
- CD via `workflow_run` escutando CI — nunca trigger direto em push.

---

## Anti-patterns (nunca fazer)

- Pular direto para código sem completar fases 0-4
- Assumir deploy target sem perguntar ao usuário
- Gerar artefatos do target errado (Traefik labels para Railway, railway.toml para Portainer)
- Instalar dependências no host em vez de dentro do container
- Instalar dependências sem verificar versão latest e documentação de API
- Criar schemas fora de `packages/shared`
- Usar `fetch()` manual em vez de hono/client RPC + TanStack Query
- Hardcodar portas nos Dockerfiles ou compose
- Subir API antes do banco estar healthy
- Criar Dockerfile single-stage para produção
- Fazer commit sem seguir Conventional Commits
- Criar container S3/MinIO no compose de dev — usar MinIO container; em UAT/PRD, S3 é serviço externo via env vars
- Retornar JSON sem envelope `{ data }` — frontend sempre espera `response.data`
- Registrar `clerkMiddleware()` sem checar `CLERK_SECRET_KEY` — crasha API em dev sem Clerk
- Construir frontend antes de testar a API com `curl`
- Usar arquivo `.env` nos compose de UAT/PRD — Portainer Stacks não processam `.env` files
- Disparar CD direto em push — CD deve usar `workflow_run` escutando CI
