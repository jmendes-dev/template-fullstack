# Changelog

Todas as mudanças notáveis neste template são documentadas aqui.
Formato: [Semver](https://semver.org) — `MAJOR.MINOR.PATCH`

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
