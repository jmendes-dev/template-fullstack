# Changelog

Todas as mudanças notáveis neste template são documentadas aqui.
Formato: [Semver](https://semver.org) — `MAJOR.MINOR.PATCH`

---

## [2.0.0] — 2026-04-24

### Mudanças estruturais (4 ondas de remediação baseadas em diagnóstico de uso real)

#### Onda 1 — Destravar fluxo (agentes não-órfãos + STOP protocol)
- **`backend-developer.md` + `frontend-developer.md`**: integração explícita do STOP protocol do `claude-debug.md` — agentes nunca contornam bugs pré-existentes (≤30min corrige em commit separado, >30min retorna `STATUS: BLOCKED` e cria P1 no backlog). Novos checks em QUALITY SELF-CHECKS / ASSURANCE.
- **`/feature`**: Passo 5 reescrito com subpassos 5.1 (QA review via `qa-engineer` — sempre obrigatório) e 5.2 (Security review via `security-engineer` — condicional em gatilhos: auth, input, segredos, CORS/CSP, middleware).
- **`/continue`**: vira PM refresh → feature → PM close. Passo 0 (PM refresh) reconcilia status com git log. Passo 2 (PM close) fecha task e sincroniza GitHub Issues.
- **`post-tool-use.sh`**: detecta edits em `claude-stacks-refactor.md`/`claude-stacks.md` e alerta sobre entries `⏳ Pendente` (lembra de rodar `./promote-learning.sh`). Restruturado com `_RUN_QUALITY` flag + async para não bloquear.
- **`CLAUDE.md`**: tabela ROUTING expandida com coluna "Invocação" (zero agentes órfãos). OWNERSHIP inclui QA, Security, PM como donos formais. PROIBIÇÕES novas bloqueando pular QA/Security e contornar bugs pré-existentes.

#### Onda 2 — Scaffold Quality (templates + RBAC + ui-ux pré-requisito)
- **`templates/docker-compose.yml`**: sample novo com stack completa (api, web, postgres, minio, backup) + bind-mounts + `CHOKIDAR_USEPOLLING` + `WATCHPACK_POLLING` para Windows/Docker + healthchecks.
- **`templates/vite.config.ts`**: sample com `server.host: true` + `server.hmr.host: "localhost"` + `server.watch.usePolling: true` — HMR funciona em WSL2 bind-mounts.
- **`templates/README.md`**: regras de uso + checklist HMR de 6 itens obrigatório para advance à Fase 5.
- **`docs/auth-rbac.md`**: padrão RBAC híbrido documentado — Clerk (identidade) + tabela `users` custom (role enum) + bootstrap determinístico (`email === ADMIN_EMAIL` → `role=admin`). Schema Drizzle, middleware `requireRole`, service `ensureUser`, 6 casos de teste obrigatórios.
- **`claude-stacks.md`**: nova env var `ADMIN_EMAIL` + nota RBAC no Auth middleware + nota templates/ no Dev workflow.
- **`DESIGN.md`**: `ui-ux-pro-max` elevada a pré-requisito explícito de `/new-project` (aviso ⚠️ no topo da Parte 2).
- **`devops-sre-engineer.md`**: FASE 4 ganha baseline templates/ + checklist HMR de 9 itens como gate para FASE 5.

#### Hotfixes de performance (durante Onda 2)
- **`.claude/settings.json`**: hook `bun install` agora é **condicional por hash SHA-256** de `package.json`+`bun.lock` (só roda quando deps mudaram) + `async: true` (não bloqueia `bun test`). Em ciclos TDD, economia de 5-30min por feature.
- **`CLAUDE_TEMPLATE_ROOT`**: exportado pelos hooks em `settings.json`, eliminando `git rev-parse` redundante em `post-tool-use.sh` (~100-200ms/invocação no Windows).
- **`check-quality.sh` HOOK_MODE**: quando chamado com `--from-output` (via hook PostToolUse), pula `bunx biome check .` (2-10s) e `bun run typecheck` (5-30s) — deferido para execução manual em VERIFY/FINISH/CI. DoD markers mostram `⏸️ deferido`.

#### Hotfixes sync-globals.sh (durante remediação — 2 bugs pré-existentes)
- **`DOWNLOAD_ERRORS unbound variable`**: variável referenciada mas nunca inicializada → `set -u` matava o script após downloads bem-sucedidos. Fix: `DOWNLOAD_ERRORS=0` antes do loop.
- **Self-overwrite mid-execution**: script se sobrescrevia durante `cp` no loop de apply, causando `bash: syntax error near unexpected token '('`. Fix: self-update deferido para o final do script com `exit 0` explícito.

#### Onda 3 — Backlog em Ondas (waves → GitHub Milestones)
- **`docs/backlog.md`**: novo formato com `## Wave: <Nome>` como agrupador de alto nível (entrega ao cliente final) + blockquote `> Milestone GitHub: \`<Nome>\` · Meta: <descrição>`. P1/P2/P3 vira ordem **INTERNA** da wave ativa.
- **`sync-github-issues.sh`**: parser detecta waves e injeta `--milestone <Nome>` em `gh issue create`. Wave `Backlog` (catch-all) → issue sem milestone. Back-compat com formato antigo preservada.
- **`setup-github-project.sh`**: substitui 6 milestones hardcoded (`Epico 1-6`) por geração automática a partir de waves do backlog. Idempotente.
- **`/finish`**: novo Passo 4 — PM marca US concluída em backlog (`**Status:** concluída` + tasks `[x]`) + roda sync-github-issues.sh para fechar issue.
- **`/continue`**: Passo 0 PM prioriza **wave ativa** (primeira wave não-concluída) em vez de P1 global.
- **`prd-planejamento` skill**: novo Passo 5.5 ensina PM agent a sintetizar backlog com waves a partir das Fases do plano.

#### Onda 4 — Memória que aprende (bootstrap real + density report)
- **`adopt-workflow.sh`**: 4 funções novas — `_detect_project_context` (extrai nome, stack, workspace, portas, env vars do target), `_agent_seeds` (seeds de domínio hardcoded por agente — 10 agentes cobertos), `_is_boilerplate` (detecta formato legacy: ≤10L não-comentário sem marcador `## Project Context`), `_generate_memory_file` (idempotente — preserva custom, substitui boilerplate).
- Cada MEMORY.md gerado tem 3 seções: **Project Context** (comum — inline), **Agent-specific notes** (seeds de domínio — rotas em apps/api/src/routes para backend, 4 estados obrigatórios para frontend, etc.), **Como Capturar Memória** (guia de retrospective).
- **`check-health.sh`**: substitui resumo binário por **tabela visual de densidade por agente** — barra proporcional 10-char + linhas + tópicos + idade/status (`atualizado Xd` ou `boilerplate`). Resumo com média, contagem de boilerplate, contagem de sem-tópicos. Assert mode (`--assert`) falha se há boilerplate.

### Observações da jornada

- **~2.600 linhas** alteradas no template (excluindo specs/plans das ondas)
- **~50% redução de overhead de processo** ao longo das 4 ondas (paralelismo de subagentes evoluiu de 18 invocações serial na Onda 1 para ~9 na Onda 3)
- **0 agentes órfãos** após Onda 1 (10 de 10 com caminho de invocação explícito)
- **2 bugs pré-existentes** consertados dogfood-style (sync-globals — unbound var + self-overwrite)
- **4 ofensores de performance** identificados e corrigidos

### Arquivos novos

- `templates/README.md`, `templates/docker-compose.yml`, `templates/vite.config.ts`
- `docs/auth-rbac.md`
- `docs/superpowers/specs/2026-04-23-onda-1-destravar-fluxo.md`
- `docs/superpowers/specs/2026-04-23-onda-3-backlog-ondas-design.md`
- `docs/superpowers/specs/2026-04-24-onda-4-memoria-design.md`
- `docs/superpowers/plans/2026-04-23-onda-1-destravar-fluxo.md`
- `docs/superpowers/plans/2026-04-23-onda-2-scaffold-quality.md`
- `docs/superpowers/plans/2026-04-23-onda-3-backlog-ondas.md`
- `docs/superpowers/plans/2026-04-24-onda-4-memoria.md`

---

## [1.7.0] — 2026-04-20

### Refatorado (P2.1 + P2.3)
- `DESIGN.md`: 1162 → 460 linhas (60% redução) — Parte 1 condensada preservando toda estrutura; Parte 2 condensada mantendo pipeline completo
- `.claude/lib/global-files.sh`: novo arquivo — fonte de verdade única para `GLOBAL_FILES`, `AGENT_FILES` e `COMMAND_FILES`
- `sync-globals.sh`: sourcing do lib (bootstrap inline se lib ausente na 1ª execução remota)
- `adopt-workflow.sh`: sourcing do lib; `TEMPLATE_VERSION` permanece exclusivo do sync — elimina drift entre listas independentes

---

## [1.6.0] — 2026-04-19

### Refatorado (P2.1 — redução de massa documental)
- `README.md`: 510 → 147 linhas — mantido apenas quickstart, pré-requisitos e tabelas de referência rápida
- `claude-stacks.md`: versões pinadas e notas de compatibilidade extraídas para arquivo separado; header corrigido
- `claude-stacks-versions.md`: novo arquivo dedicado a versões pinadas (Bun, React, Hono, Tailwind v4, Zod v4, Clerk Core 3, etc.) e notas de compatibilidade por versão
- `adopt-workflow.sh` + `sync-globals.sh`: `claude-stacks-versions.md` adicionado à lista `GLOBAL_FILES`

---

## [1.5.1] — 2026-04-19

### Corrigido
- `CLAUDE.md`: threshold de escalação alinhado com `claude-debug.md` ("2-3" → "3 tentativas") — fonte única
- `pre-tool-use.sh`: extração de `file_path` usa `jq` quando disponível (regex como fallback) — robusto com paths especiais

### Adicionado
- `pre-tool-use.sh`: soft warning ao editar `apps/*/src/**` ou `packages/shared/src/**` — lembra delegação ao agente

---

## [1.5.0] — 2026-04-19

### Corrigido (P0 — críticos)
- `check-quality.sh`: gate de testes estava sempre reportando ✅ por bug no exit capture (`|| true` mascarava falhas)
- `.claude/settings.json`: hooks com path relativo quebravam silenciosamente em git worktrees — migrado para resolução via `git rev-parse --git-common-dir`
- `adopt-workflow.sh`: CLAUDE.md era sobrescrito em toda re-execução — agora só copia na 1ª vez (use `--force-claude-md` para reinstalar)
- `.claude/hooks/post-tool-use.sh`: erros do check-quality eram engolidos com `2>/dev/null` — agora logados em `.claude/logs/quality.log`

### Adicionado (P0/P1/P2)
- `.github/workflows/ci.yml`: CI mínimo com lint + typecheck + test (gates de qualidade agora têm enforcement externo)
- `check-quality.sh`: lint (Biome) e typecheck (tsc) agora verificados e reportados no quality dashboard
- `CLAUDE.md`: tabela "OWNERSHIP DE ETAPAS" clarifica commands vs Superpowers skills (elimina ambiguidade)
- `pre-tool-use.sh`: lembrete automático de `./sync-github-issues.sh` ao editar `docs/backlog.md`

### Corrigido (P1 — refs e redundâncias)
- `triage.md`: tabela de agentes removida (deduplicada com CLAUDE.md) — fonte única
- `claude-stacks.md`: 4 refs `START_PROJECT.md` → `start_project.md` (case fix para Linux CI)
- `claude-sdd.md`: encoding corrompido `S🔴 prosseguir` → `Só prosseguir`
- `docs/backlog.md`, `docs/user-stories.md`: substituídas refs fantasma a `REQUIREMENTS.md`
- `docs/design-system/MASTER.md`: substituídas refs fantasma a `DESIGN_SYSTEM.md` e `claude-design.md`

### Corrigido (P3 — robustez)
- `promote-learning.sh`: `sed -i` → `sed -i.bak` (portável macOS/BSD/Linux)

---

## [1.4.0] — 2026-04-19

### Adicionado
- `.claude/commands/refactor.md`: `/refactor` com guardrails de isolamento (branch obrigatória, baseline verde, inventário de testes, proibição de novo comportamento)
- `inject-context.sh`: reminder de triagem obrigatória injetado em todo prompt que não começa com slash command

### Corrigido
- Loop circular `/feature` ↔ `/triage`: `/feature` agora classifica inline sem reinvocar `/triage`; `/triage` indica próximo passo como referência documentacional
- Contradição entre `/triage` (roteava refactor via `/feature`) e `CLAUDE.md` (proíbe misturar refactor com novas features) — resolvida com `/refactor` dedicado

### Alterado
- `CLAUDE.md`: bloco TRIAGEM menciona `/refactor` explicitamente
- `sync-globals.sh`: `refactor.md` adicionado a `COMMAND_FILES`

---

## [1.3.0] — 2026-04-19

### Adicionado
- `.claude/commands/` com 6 slash commands: `/bug`, `/triage`, `/feature`, `/finish`, `/continue`, `/new-project`
- `DESIGN.md` (merge de `claude-design.md` + `DESIGN_SYSTEM.md`)

### Removido
- `claude-subagents.md` (absorvido em `claude-sdd.md`)
- `DESIGN_SYSTEM.md` (merged em `DESIGN.md`)
- `REQUIREMENTS.md` (absorvido em `/new-project`)

### Alterado
- `CLAUDE.md`: hierarquia canônica atualizada, árvore de decisão movida para `/triage`
- `claude-debug.md`: reduzido a reference card (protocolo em `/bug`)
- `start_project.md`: reduzido a gates de fase (procedimento em `/new-project`)
- `claude-sdd.md`: absorveu contextos de subagente de `claude-subagents.md`
- `sync-globals.sh`: agora sincroniza `.claude/commands/` via glob

---

## [1.2.0] — 2026-04-16

### Added
- **Agent Memory Bootstrap** (`.superpowers/agent-memory-bootstrap.md`)
  - Guia para pré-popular memórias dos 10 agentes em projetos novos
  - Elimina o período de "cold start" onde agentes não têm contexto acumulado
  - Checklist de coleta de informações (stack, rotas, schemas, stories, perfis)
  - Template de MEMORY.md + conteúdo mínimo por agente
  - Regras sobre o que colocar (e não colocar) na memória
- **Fase 9 no `start_project.md`** — Bootstrap de memória dos agentes após app base

### Changed
- **`.claude/settings.json`**: hooks simplificados
  - `PreToolUse`: Write + Edit unificados em um único matcher `Write|Edit`
  - `UserPromptSubmit` e `PreToolUse`: comandos com path direto (`bash .claude/hooks/...`) em vez de resolução dinâmica via `git rev-parse`
  - `PostToolUse`: substituído de `post-tool-use.sh` externo para comando inline que aciona `check-quality.sh` diretamente após `bun test`
- **`check-quality.sh`**: parsing de cobertura por módulo refatorado
  - Usa arquivo temporário (`mktemp`) em vez de string concatenation com `echo -e`
  - Evita interpretação incorreta de `\a`, `\n` etc. em paths do Windows
  - Adaptado ao formato real de output do `bun test --coverage` (colunas Funcs | Lines, não Stmts | Branch | Funcs | Lines)
- **`sync-github-issues.sh`**: melhorias significativas
  - Rastreamento de tasks concluídas (`done_count` / `total_count`) por story
  - Output de dry-run diferencia `[CRIAR]` vs `[ATUALIZAR #N]` com status da issue
  - Auto-fecha issues quando todas as tasks estão concluídas; reabre se tasks pendentes surgem
  - Suporte ao formato `**US-XX: Título**` além do formato `### US-XX — Título`
  - Dry-run usa credenciais gh disponíveis para lookup real de issues existentes
- **`.github/pull_request_template.md`**: reestruturado
  - "Story / Contexto" como primeiro campo com referência a US-XX
  - Seção "Spec" para link do spec SDD
  - DoD com itens específicos: 4 estados de componente, atualização de contracts
  - Seção "Testes notáveis" e footer "Generated with Claude Code"
- **`.gitignore`**: expandido de 11 para 24 entradas organizadas por categoria
- **`claude-stacks-refactor.md`**: adicionado workaround Vite/Windows
  - `bunx vite` em vez de `vite` direto em `apps/web` para evitar segfault (Bun 1.3.12 + Vite 8.x + Windows)

---

## [1.1.0] — 2026-04-15

### Added — Harness Engineering
- **PreToolUse hooks** (`.claude/hooks/pre-tool-use.sh`)
  - Hard blocks writes to `.github/workflows/` — requer devops-sre-engineer
  - Soft warning para arquivos globais do template (claude-stacks.md etc.)
- **Structured agent output protocol** (todos os 10 agentes)
  - Bloco obrigatório: STATUS / ARTEFATOS / PRÓXIMO / CONCERNS
  - Status: DONE | BLOCKED | NEEDS_CONTEXT | DONE_WITH_CONCERNS
  - Permite ao orquestrador processar respostas mecanicamente
- **Context budget condicional** (`.claude/hooks/inject-context.sh`)
  - `session-state.md` sempre injetado
  - `quality.md` injetado apenas se prompt menciona testes/bugs/qualidade
  - `backlog.md` injetado apenas se prompt menciona tasks/stories/implementação
  - Reduz ~2000 tokens/turno em contexto irrelevante
- **`check-health.sh --assert` mode**
  - Exit code 1 se verificações críticas falham (para CI pipelines)
  - Exit code 0 se tudo passa
  - Warnings não contam como falha crítica

### Changed
- `settings.json`: hooks agora referenciam scripts externos (mais limpo que bash inline)
- `adopt-workflow.sh` e `sync-globals.sh`: incluem `.claude/hooks/` nos arquivos globais

---

## [1.0.0] — 2026-04-15

### Breaking Changes
- `CLAUDE.md` reescrito como protocolo executável (354 → 141 linhas)
  - Remover seções de metodologia/SDD do CLAUDE.md (vivem nos sub-arquivos)
  - Routing de agentes agora é OBRIGATÓRIO, não sugestão
  - Skills pessoais agora têm invocação mandatória documentada

### Added
- **Enforcement layer** (hooks no settings.json)
  - `UserPromptSubmit`: injeta session-state + quality + backlog em todo prompt
  - `Stop`: cria docs/session-state.md se não existe
  - `PostToolUse`: aciona check-quality.sh após bun test
- **scripts/permissions**: settings.local.example.json com permissões para todos os scripts
- **post-commit** estendido: detecta mudanças em backlog.md e MASTER.md
- **adopt-workflow.sh**: cria settings.json com hooks e settings.local.json no projeto alvo
- `docs/quality.md`: quality dashboard template
- `check-quality.sh`: script que atualiza quality.md após bun test
- `docs/session-state.md`: template de estado de sessão para continuidade
- `docs/contracts/README.md`: contract registry inter-agente
- `check-health.sh`: diagnóstico de saúde do projeto
- `TEMPLATE_VERSION` + `CHANGELOG.md`: versionamento semver do template
- `.github/pull_request_template.md`: checklist DoD no GitHub
- `.github/CODEOWNERS`: proteção de arquivos de arquitetura
- **Session Retrospective** em todos os 10 MEMORY.md dos agentes
- **Bug Journal** template em claude-stacks-refactor.md
- **Design Brief Pipeline**: regras OBRIGATÓRIO em claude-design.md
- **Contract Registry**: seções obrigatórias em backend-developer.md e frontend-developer.md
- **Bootstrap Agent Sequence**: sequência de 7 passos em start_project.md
- **Spec-Test Traceability**: convenção `it('Cenário X.Y: ...')` em claude-sdd.md
- **Template versioning** em sync-globals.sh e adopt-workflow.sh
- **Branch protection** em setup-github-project.sh

### Fixed
- post-commit hook: fix COUNT check (CRLF/integer issue no Windows)
- adopt-workflow.sh: adiciona sync-globals.sh e promote-learning.sh ao GLOBAL_FILES

---

## Versões Anteriores

Este template não tinha versionamento antes da v1.0.0.
