#!/usr/bin/env bash
# Fonte de verdade: lista de arquivos globais do template.
# Usado por: sync-globals.sh, adopt-workflow.sh
# Atualizar AQUI ao adicionar/remover arquivos globais.

GLOBAL_FILES=(
  "claude-stacks.md"
  "claude-stacks-versions.md"
  "claude-sdd.md"
  "DESIGN.md"
  "claude-debug.md"
  "start_project.md"
  ".gitattributes"
  "setup-github-project.sh"
  "sync-github-issues.sh"
  "sync-globals.sh"
  "promote-learning.sh"
  "check-health.sh"
  "check-quality.sh"
  ".claude/lib/global-files.sh"
  ".claude/settings.local.example.json"
  ".claude/settings.example.json"
  ".claude/hooks/pre-tool-use.sh"
  ".claude/hooks/inject-context.sh"
  ".claude/hooks/post-tool-use.sh"
  "package.json.example"
  ".superpowers/agent-memory-bootstrap.md"
)

AGENT_FILES=(
  "backend-developer.md"
  "data-engineer-dba.md"
  "devops-sre-engineer.md"
  "frontend-developer.md"
  "project-manager.md"
  "qa-engineer.md"
  "requirements-roadmap-builder.md"
  "security-engineer.md"
  "software-architect.md"
  "ux-ui-designer.md"
)

COMMAND_FILES=(
  "bug.md"
  "triage.md"
  "feature.md"
  "finish.md"
  "continue.md"
  "new-project.md"
  "refactor.md"
)
