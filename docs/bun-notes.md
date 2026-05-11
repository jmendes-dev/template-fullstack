# Bun 1.3 — notas relevantes

Ler quando configurar o runtime, lockfile, hot reload, jobs ou imagens Docker. Regra-resumo vive em `CLAUDE.md`.

- **Lockfile**: `bun.lock` (JSONC, git-diffable) é o padrão desde Bun 1.2. `bun.lockb` (binário) não é mais o default — se existir no projeto, deletar e rodar `bun install` para gerar `bun.lock`
- **Hot reload**: `bun --hot` (soft reload, preserva `globalThis`) vs `--watch` (reinicia processo). Usar `--hot` para API
- **Opcionais**: `bun build --bytecode` (startup rápido), workspace `"catalog"` (centralizar versões)
- **Bun.cron (≤1.3.11)**: registra cron jobs no SO (crontab/launchd) — OS-level, **não** in-process. Não funciona em containers Docker
- **Bun.cron() (≥1.3.12)**: scheduler in-process — lançado em 9/abr/2026. Roda dentro do processo Bun, **funciona em containers**, sem dependência do crontab do host. API: `Bun.cron("*/5 * * * *", async () => { /* ... */ })`. Garantia de sem sobreposição entre execuções. Latest: **1.3.13** (20/abr/2026). Ver `docs/background-jobs.md`
- **Bun.SQL**: driver SQL unificado built-in (PostgreSQL + MySQL + SQLite). postgres.js continua como padrão
- **Isolated installs**: default em novos workspaces (`configVersion = 1`)
- **Docker images**: `oven/bun:1.3` (recomendado para reprodutibilidade), `oven/bun:slim`, `oven/bun:distroless`, `oven/bun:alpine`
- **`bun test` — novos flags (1.3.13)**: flags úteis para otimizar CI:
  - `--shard=M/N` — divide a suite em N partes, roda a parte M (matriz de CI: `--shard=1/4`, `2/4`, `3/4`, `4/4`)
  - `--changed` — roda apenas testes afetados por mudanças git (PRs menores, mais rápido)
  - `--parallel[=N]` — execução paralela de arquivos de teste com N workers
  - `--isolate` — isola cada arquivo de teste em contexto separado (sem vazamento de estado global)
- **`experimentalDecorators` (Bun ≥1.3.10)**: Bun migrou para Stage-3 decorators por padrão. Código com decorators Stage-2 legacy (`@Column()`, `@Entity()` do TypeORM) quebra nas versões ≥1.3.10/1.3.11. Workaround: adicionar `"experimentalDecorators": true` no `tsconfig.json` do workspace afetado — mas cria conflito com decorators nativos Stage-3. Stack deste template não usa decorators, então sem impacto direto.
