# Changelog

Todas as mudanças notáveis neste template são documentadas aqui.
Formato: [Semver](https://semver.org) — `MAJOR.MINOR.PATCH`

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
