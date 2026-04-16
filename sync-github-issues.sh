#!/usr/bin/env bash
set -euo pipefail

# sync-github-issues.sh
# Sincroniza docs/backlog.md com GitHub Issues.
# Cria Issues para User Stories novas; atualiza checklist em Issues existentes.
#
# Uso:
#   ./sync-github-issues.sh                    # usa docs/backlog.md
#   ./sync-github-issues.sh path/backlog.md    # arquivo explícito
#   ./sync-github-issues.sh --dry-run          # mostra o que faria, sem criar Issues
#   ./sync-github-issues.sh --dry-run path/... # dry-run em arquivo específico
#   ./sync-github-issues.sh --debug            # imprime cada linha do parser (diagnóstico)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse args ───────────────────────────────────
DRY_RUN=false
DEBUG=false
BACKLOG_FILE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --debug)   DEBUG=true ;;
    *) BACKLOG_FILE="$arg" ;;
  esac
done

BACKLOG_FILE="${BACKLOG_FILE:-$SCRIPT_DIR/docs/backlog.md}"

# ── Colors ──────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; exit 1; }
debug() { [[ "$DEBUG" == true ]] && echo -e "\033[0;35m[DEBUG]\033[0m $1" >&2 || true; }

# ── Read project config ──────────────────────────
PROJECT_ID_FILE="$SCRIPT_DIR/.github/project-id"

if [[ "$DRY_RUN" == false ]]; then
  [[ ! -f "$PROJECT_ID_FILE" ]] \
    && error ".github/project-id nao encontrado. Rode: ./setup-github-project.sh"
  IFS='/' read -r OWNER REPO_NAME PROJECT_NUMBER < "$PROJECT_ID_FILE"
  if ! gh auth status &>/dev/null; then
    error "gh CLI nao autenticado. Rode: gh auth login"
  fi
else
  # Dry-run: lê project-id se disponível (para lookup de issues existentes)
  if [[ -f "$PROJECT_ID_FILE" ]] && gh auth status &>/dev/null 2>&1; then
    IFS='/' read -r OWNER REPO_NAME PROJECT_NUMBER < "$PROJECT_ID_FILE"
  else
    OWNER=""; REPO_NAME=""; PROJECT_NUMBER="0"
  fi
fi

# Determine board URL (org vs user account)
BOARD_URL=""
if [[ "$DRY_RUN" == false ]]; then
  ACCOUNT_TYPE=$(gh api "users/$OWNER" --jq '.type' 2>/dev/null || echo "User")
  if [[ "$ACCOUNT_TYPE" == "Organization" ]]; then
    BOARD_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
  else
    BOARD_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
  fi
fi

[[ ! -f "$BACKLOG_FILE" ]] && error "Backlog nao encontrado: $BACKLOG_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  sync-github-issues.sh${DRY_RUN:+ (DRY RUN)}"
[[ "$DRY_RUN" == false ]] && echo "  Repo: $OWNER/$REPO_NAME"
echo "  Backlog: $BACKLOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Priority → label mapping ─────────────────────
priority_to_label() {
  case "${1:-P3}" in
    P1) echo "P1-critico" ;;
    P2) echo "P2-importante" ;;
    *)  echo "P3-desejavel" ;;
  esac
}

# ── Counters ─────────────────────────────────────
CREATED=0; UPDATED=0

# ── Process a single User Story ──────────────────
process_us() {
  local us="$1" title="$2" priority="$3" milestone="$4" tasks_body="$5" done_count="${6:-0}" total_count="${7:-0}"

  [[ -z "$us" || -z "$title" ]] && return

  local issue_title="[$us] $title"
  local priority_label
  priority_label=$(priority_to_label "$priority")
  local full_body
  if [[ -n "$tasks_body" ]]; then
    full_body="$(printf '## Tasks\n\n%b' "$tasks_body")"
  else
    full_body=""
  fi

  # Determine completion state
  local all_done=false has_progress=false
  [[ "$total_count" -gt 0 && "$done_count" -eq "$total_count" ]] && all_done=true
  [[ "$total_count" -gt 0 && "$done_count" -gt 0 && "$done_count" -lt "$total_count" ]] && has_progress=true

  local status_str="sem tasks"
  [[ "$total_count" -gt 0 && "$done_count" -eq "$total_count" ]] \
    && status_str="CONCLUÍDA ($done_count/$total_count tasks)"
  [[ "$total_count" -gt 0 && "$done_count" -gt 0 && "$done_count" -lt "$total_count" ]] \
    && status_str="em andamento ($done_count/$total_count tasks)"
  [[ "$total_count" -gt 0 && "$done_count" -eq 0 ]] \
    && status_str="pendente (0/$total_count tasks)"

  # Look up existing issue (before dry-run check, so output shows CRIAR vs ATUALIZAR)
  # NOTE: gh --jq does NOT support --arg; embed title directly in the expression
  local existing_number _escaped_title
  _escaped_title="${issue_title//\"/\\\"}"
  if [[ -n "$OWNER" && -n "$REPO_NAME" ]]; then
    existing_number=$(gh issue list \
      --repo "$OWNER/$REPO_NAME" \
      --state all \
      --limit 200 \
      --json number,title \
      --jq ".[] | select(.title == \"$_escaped_title\") | .number" 2>/dev/null \
      | head -1 || echo "")
  else
    existing_number=""
  fi

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -z "$existing_number" ]]; then
      echo "  [CRIAR]         $issue_title"
      CREATED=$((CREATED + 1))
    else
      echo "  [ATUALIZAR #$existing_number] $issue_title"
      UPDATED=$((UPDATED + 1))
    fi
    echo "    Status:    $status_str"
    [[ "$all_done" == true ]]  && echo "    → Fecharia a issue"
    [[ "$all_done" == false && -n "$existing_number" ]] && echo "    → Reabriria se estiver fechada"
    echo "    Labels:    $priority_label, feature, spec-pendente"
    echo "    Milestone: ${milestone:-<sem milestone>}"
    echo ""
    return
  fi

  if [[ -z "$existing_number" ]]; then
    # Build milestone flag conditionally (empty milestone causes gh error)
    local milestone_flag=()
    [[ -n "$milestone" ]] && milestone_flag=(--milestone "$milestone")

    local new_issue_url
    new_issue_url=$(gh issue create \
      --repo "$OWNER/$REPO_NAME" \
      --title "$issue_title" \
      --body "$full_body" \
      --label "$priority_label,feature,spec-pendente" \
      "${milestone_flag[@]}" 2>/dev/null || echo "")

    if [[ -n "$new_issue_url" ]]; then
      local issue_number
      issue_number=$(basename "$new_issue_url")
      # Add to project board
      gh project item-add "$PROJECT_NUMBER" \
        --owner "$OWNER" \
        --url "$new_issue_url" &>/dev/null || true
      ok "Criada: $issue_title (#$issue_number)"
      CREATED=$((CREATED + 1))
      # Close if all tasks are done
      if [[ "$all_done" == true ]]; then
        gh issue close "$issue_number" --repo "$OWNER/$REPO_NAME" &>/dev/null || true
        info "  → Fechada (todas as $total_count tasks concluídas)"
      fi
    else
      warn "Falha ao criar: $issue_title"
    fi

  else
    # Update tasks checklist — preserve everything before ## Tasks
    local current_body
    current_body=$(gh issue view "$existing_number" \
      --repo "$OWNER/$REPO_NAME" \
      --json body --jq '.body' 2>/dev/null || echo "")

    local before_tasks
    before_tasks=$(printf '%s' "$current_body" | awk '/^## Tasks/{exit} {print}')

    local updated_body
    if [[ -n "$before_tasks" ]]; then
      updated_body="${before_tasks}
${full_body}"
    else
      updated_body="$full_body"
    fi

    gh issue edit "$existing_number" \
      --repo "$OWNER/$REPO_NAME" \
      --body "$updated_body" &>/dev/null
    ok "Atualizada: $issue_title (#$existing_number)"
    UPDATED=$((UPDATED + 1))
    # Manage open/closed state based on task completion
    if [[ "$all_done" == true ]]; then
      gh issue close "$existing_number" --repo "$OWNER/$REPO_NAME" &>/dev/null || true
      info "  → Fechada (todas as $total_count tasks concluídas)"
    else
      gh issue reopen "$existing_number" --repo "$OWNER/$REPO_NAME" &>/dev/null || true
    fi
  fi
}

# ── State machine parser ──────────────────────────
current_us=""
current_title=""
current_priority=""
current_milestone=""
current_tasks=""
current_done=0
current_total=0
in_us_block=false
in_tasks=false
current_sprint=""

flush_us() {
  process_us "$current_us" "$current_title" "$current_priority" \
             "$current_milestone" "$current_tasks" "$current_done" "$current_total"
  current_us=""; current_title=""; current_priority=""
  current_milestone=""; current_tasks=""
  current_done=0; current_total=0
  in_us_block=false; in_tasks=false
}

_LINES_PARSED=0
_US_FOUND=0

while IFS= read -r line || [[ -n "$line" ]]; do
  _LINES_PARSED=$((_LINES_PARSED + 1))
  debug "L${_LINES_PARSED}: $(echo "$line" | head -c 80)"

  # Sprint section heading (para rastreamento de contexto)
  if [[ "$line" =~ ^##[[:space:]]+(Sprint[[:space:]]+[0-9]+[A-Za-z]*) ]]; then
    current_sprint="${BASH_REMATCH[1]}"
    debug "  → Sprint detectado: $current_sprint"

  # US heading: ### US-03 — Título  or  ### US-03 - Título
  elif [[ "$line" =~ ^###[[:space:]]+(US-[0-9]+)[[:space:]]+(—|-)[[:space:]]+(.+)$ ]]; then
    flush_us
    current_us="${BASH_REMATCH[1]}"
    current_title="${BASH_REMATCH[3]}"
    in_us_block=true
    in_tasks=false
    _US_FOUND=$((_US_FOUND + 1))
    debug "  → US detectada (formato ###): $current_us — $current_title"

  # US heading: **US-03: Título** — N pontos  (formato atual do backlog)
  elif [[ "$line" =~ ^\*\*(US-[0-9]+):[[:space:]]+([^*]+)\*\* ]]; then
    flush_us
    current_us="${BASH_REMATCH[1]}"
    current_title="${BASH_REMATCH[2]}"
    in_us_block=true
    in_tasks=false
    _US_FOUND=$((_US_FOUND + 1))
    debug "  → US detectada (formato **): $current_us — $current_title"

  elif [[ "$in_us_block" == true ]]; then
    if [[ "$line" =~ \*\*Prioridade:\*\*[[:space:]]+([^[:space:]]+) ]]; then
      current_priority="${BASH_REMATCH[1]}"
      debug "  → Prioridade: $current_priority"
    elif [[ "$line" =~ \*\*Milestone:\*\*[[:space:]]+(.+)$ ]]; then
      current_milestone="${BASH_REMATCH[1]}"
      debug "  → Milestone: $current_milestone"
    elif [[ "$line" =~ ^(\*\*)?Tasks:(\*\*)?[[:space:]]*$ ]]; then
      in_tasks=true
      debug "  → Início de Tasks"
    elif [[ "$in_tasks" == true && "$line" =~ ^-[[:space:]]\[(.?)\][[:space:]](.+)$ ]]; then
      _cb="${BASH_REMATCH[1]}"
      _txt="${BASH_REMATCH[2]}"
      current_tasks="${current_tasks}- [${_cb}] ${_txt}\n"
      current_total=$((current_total + 1))
      [[ "$_cb" == "x" ]] && current_done=$((current_done + 1))
      debug "  → Task [${_cb}]: ${_txt}"
    elif [[ "$line" =~ ^###[[:space:]] ]] && [[ ! "$line" =~ ^###[[:space:]]+US- ]]; then
      debug "  → Fim de bloco US (heading não-US)"
      flush_us
    fi
  fi
done < "$BACKLOG_FILE"

[[ "$DEBUG" == true ]] && echo -e "\033[0;35m[DEBUG]\033[0m Parser concluído: ${_LINES_PARSED} linhas lidas, ${_US_FOUND} US detectadas" >&2

flush_us  # process last US (safe to call even if already flushed — process_us guards on empty us/title)

# ── Summary ──────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$DRY_RUN" == true ]]; then
  info "DRY RUN concluido — nenhuma Issue criada/alterada"
  echo "   A criar:     $CREATED"
  echo "   A atualizar: $UPDATED"
  if [[ -z "$OWNER" ]]; then
    warn "Sem credenciais gh — não foi possível verificar issues existentes (contagem 'a atualizar' pode estar incorreta)"
  fi
else
  info "GitHub Issues sincronizadas"
  echo "   Criadas:     $CREATED"
  echo "   Atualizadas: $UPDATED"
  echo ""
  echo "   Board:  $BOARD_URL"
  echo "   Issues: https://github.com/$OWNER/$REPO_NAME/issues"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
