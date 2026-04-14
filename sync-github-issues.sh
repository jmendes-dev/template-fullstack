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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse args ───────────────────────────────────
DRY_RUN=false
BACKLOG_FILE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
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
  OWNER="dry-run"; REPO_NAME="dry-run"; PROJECT_NUMBER="0"
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
  local us="$1" title="$2" priority="$3" milestone="$4" tasks_body="$5"

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

  if [[ "$DRY_RUN" == true ]]; then
    echo "  Would create/update: $issue_title"
    echo "    Labels:    $priority_label, feature, spec-pendente"
    echo "    Milestone: ${milestone:-<sem milestone>}"
    echo "    Tasks:"
    printf '%b' "$tasks_body" | sed 's/^/      /'
    echo ""
    CREATED=$((CREATED + 1))
    return
  fi

  # Check if issue already exists
  local existing_number
  existing_number=$(gh issue list \
    --repo "$OWNER/$REPO_NAME" \
    --search "in:title \"$issue_title\"" \
    --state all \
    --json number,title \
    --jq --arg title "$issue_title" \
    '.[] | select(.title == $title) | .number' 2>/dev/null \
    | head -1 || echo "")

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
  fi
}

# ── State machine parser ──────────────────────────
current_us=""
current_title=""
current_priority=""
current_milestone=""
current_tasks=""
in_us_block=false
in_tasks=false

flush_us() {
  process_us "$current_us" "$current_title" "$current_priority" \
             "$current_milestone" "$current_tasks"
  current_us=""; current_title=""; current_priority=""
  current_milestone=""; current_tasks=""
  in_us_block=false; in_tasks=false
}

while IFS= read -r line || [[ -n "$line" ]]; do
  # US heading: ### US-03 — Título  or  ### US-03 - Título
  if [[ "$line" =~ ^###[[:space:]]+(US-[0-9]+)[[:space:]]+(—|-)[[:space:]]+(.+)$ ]]; then
    flush_us
    current_us="${BASH_REMATCH[1]}"
    current_title="${BASH_REMATCH[3]}"
    in_us_block=true
    in_tasks=false

  elif [[ "$in_us_block" == true ]]; then
    if [[ "$line" =~ \*\*Prioridade:\*\*[[:space:]]+([^[:space:]]+) ]]; then
      current_priority="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \*\*Milestone:\*\*[[:space:]]+(.+)$ ]]; then
      current_milestone="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\*\*Tasks:\*\*[[:space:]]*$ ]]; then
      in_tasks=true
    elif [[ "$in_tasks" == true && "$line" =~ ^-[[:space:]]\[.?\][[:space:]](.+)$ ]]; then
      current_tasks="${current_tasks}- [ ] ${BASH_REMATCH[1]}\n"
    elif [[ "$line" =~ ^###[[:space:]] ]] && [[ ! "$line" =~ ^###[[:space:]]+US- ]]; then
      flush_us
    fi
  fi
done < "$BACKLOG_FILE"

flush_us  # process last US (safe to call even if already flushed — process_us guards on empty us/title)

# ── Summary ──────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$DRY_RUN" == true ]]; then
  info "DRY RUN concluido — nenhuma Issue criada"
  echo "   Stories encontradas: $CREATED"
else
  info "GitHub Issues sincronizadas"
  echo "   Criadas:     $CREATED"
  echo "   Atualizadas: $UPDATED"
  echo ""
  echo "   Board:  $BOARD_URL"
  echo "   Issues: https://github.com/$OWNER/$REPO_NAME/issues"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
