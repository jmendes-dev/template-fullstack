#!/usr/bin/env bash
set -euo pipefail

# sync-github-issues.sh
# Sincroniza docs/backlog.md com GitHub Issues.
#
# Uso:
#   ./sync-github-issues.sh                    # usa docs/backlog.md
#   ./sync-github-issues.sh path/backlog.md    # arquivo explícito
#   ./sync-github-issues.sh --dry-run          # mostra o que faria, sem criar Issues
#   ./sync-github-issues.sh --force            # ignora cache de fingerprints e sincroniza tudo
#   ./sync-github-issues.sh --init-cache       # popula cache sem escrever nada no GitHub (use na 1ª vez)
#   ./sync-github-issues.sh --debug            # diagnóstico do parser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Args ─────────────────────────────────────────────────────────────────────
DRY_RUN=false; DEBUG=false; FORCE=false; INIT_CACHE=false; BACKLOG_FILE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=true ;;
    --debug)      DEBUG=true ;;
    --force)      FORCE=true ;;
    --init-cache) INIT_CACHE=true ;;
    *) BACKLOG_FILE="$arg" ;;
  esac
done
BACKLOG_FILE="${BACKLOG_FILE:-$SCRIPT_DIR/docs/backlog.md}"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1" >&2; exit 1; }
skip()  { echo -e "\033[0;90m–\033[0m  $1"; }
debug() { [[ "$DEBUG" == true ]] && echo -e "\033[0;35m[DEBUG]\033[0m $1" >&2 || true; }
SEPARATOR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Project config ────────────────────────────────────────────────────────────
PROJECT_ID_FILE="$SCRIPT_DIR/.github/project-id"
OWNER=""; REPO_NAME=""; PROJECT_NUMBER="0"

if [[ -f "$PROJECT_ID_FILE" ]]; then
  IFS='/' read -r OWNER REPO_NAME PROJECT_NUMBER < "$PROJECT_ID_FILE"
elif [[ "$DRY_RUN" == false ]]; then
  error ".github/project-id nao encontrado. Rode: ./setup-github-project.sh"
fi

[[ ! -f "$BACKLOG_FILE" ]] && error "Backlog nao encontrado: $BACKLOG_FILE"

# ── Sync state ────────────────────────────────────────────────────────────────
# Format: US-ID <TAB> fingerprint <TAB> issue_number <TAB> issue_state
# Stores enough data to skip ALL API calls when nothing changed.
_SYNC_STATE_FILE="$SCRIPT_DIR/.github/sync-state.txt"
declare -A _HASH _NUM _STATE

if [[ "$FORCE" == false && -f "$_SYNC_STATE_FILE" ]]; then
  while IFS=$'\t' read -r _u _h _n _s; do
    [[ -z "$_u" ]] && continue
    _HASH["$_u"]="$_h"
    [[ -n "$_n" ]] && _NUM["$_u"]="$_n"
    [[ -n "$_s" ]] && _STATE["$_u"]="$_s"
  done < "$_SYNC_STATE_FILE"
fi

# ── Phase 1: Parse backlog (local — no API calls) ────────────────────────────
declare -a P_US=() P_TITLE=() P_PRIO=() P_MILE=() P_TASKS=() P_DONE=() P_TOTAL=()

# _current_wave: setado por heading `## Wave: <Nome>`, aplicado como default milestone
# para USs subsequentes quando `**Milestone:**` explícito não é fornecido.
# Wave "Backlog" (case-sensitive) → milestone vazia (USs sem agrupamento).
_current_wave=""
_cu=""; _ct=""; _cp=""; _cm=""; _cta=""; _cd=0; _cto=0; _inu=false; _int=false

_flush_parse() {
  [[ -z "$_cu" || -z "$_ct" ]] && return
  # Fallback: se US não tem Milestone explícito, herda a wave ativa (exceto "Backlog")
  if [[ -z "$_cm" && -n "$_current_wave" && "$_current_wave" != "Backlog" ]]; then
    _cm="$_current_wave"
  fi
  P_US+=("$_cu"); P_TITLE+=("$_ct"); P_PRIO+=("$_cp"); P_MILE+=("$_cm")
  P_TASKS+=("$_cta"); P_DONE+=("$_cd"); P_TOTAL+=("$_cto")
  debug "  stored: $_cu — $_ct (tasks=$_cto done=$_cd wave=${_current_wave:-<none>})"
  _cu=""; _ct=""; _cp=""; _cm=""; _cta=""; _cd=0; _cto=0; _inu=false; _int=false
}

while IFS= read -r line || [[ -n "$line" ]]; do
  debug "L: ${line:0:80}"
  # Wave heading: `## Wave: <Nome>` → seta contexto para USs subsequentes
  if [[ "$line" =~ ^##[[:space:]]+Wave:[[:space:]]+(.+)$ ]]; then
    _flush_parse  # Fecha qualquer US pendente antes de mudar contexto de wave
    _current_wave="${BASH_REMATCH[1]}"
    # Trim trailing whitespace do nome da wave
    _current_wave="${_current_wave%"${_current_wave##*[![:space:]]}"}"
    debug "  wave changed to: $_current_wave"
    continue
  fi
  if [[ "$line" =~ ^###[[:space:]]+(US-[0-9]+)[[:space:]]+(—|-)[[:space:]]+(.+)$ ]]; then
    _flush_parse; _cu="${BASH_REMATCH[1]}"; _ct="${BASH_REMATCH[3]}"; _inu=true; _int=false
  elif [[ "$line" =~ ^\*\*(US-[0-9]+):[[:space:]]+([^*]+)\*\* ]]; then
    _flush_parse; _cu="${BASH_REMATCH[1]}"; _ct="${BASH_REMATCH[2]}"; _inu=true; _int=false
  elif [[ "$_inu" == true ]]; then
    if [[ "$line" =~ \*\*Prioridade:\*\*[[:space:]]+([^[:space:]]+) ]]; then
      _cp="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \*\*Milestone:\*\*[[:space:]]+(.+)$ ]]; then
      _cm="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^(\*\*)?Tasks:(\*\*)?[[:space:]]*$ ]]; then
      _int=true
    elif [[ "$_int" == true && "$line" =~ ^-[[:space:]]\[(.?)\][[:space:]](.+)$ ]]; then
      _cb="${BASH_REMATCH[1]}"; _txt="${BASH_REMATCH[2]}"
      _cta="${_cta}- [${_cb}] ${_txt}\n"; _cto=$((_cto+1))
      [[ "$_cb" == "x" ]] && _cd=$((_cd+1))
    elif [[ "$line" =~ ^###[[:space:]] && ! "$line" =~ ^###[[:space:]]+US- ]]; then
      _flush_parse
    fi
  fi
done < "$BACKLOG_FILE"
_flush_parse

debug "Parser: ${#P_US[@]} USs encontradas"

# ── Phase 2: Compute fingerprints; check if anything needs syncing ───────────
info "Parser: ${#P_US[@]} USs lidas — computando fingerprints..."
declare -a FP=()
_needs_sync=false

priority_to_label() {
  case "${1:-P3}" in P1) echo "P1-critico" ;; P2) echo "P2-importante" ;; *) echo "P3-desejavel" ;; esac
}

for i in "${!P_US[@]}"; do
  _fp_raw=$(printf '%s|%s|%s|%s|%s' \
    "${P_PRIO[$i]}" "${P_MILE[$i]}" "${P_TASKS[$i]}" "${P_DONE[$i]}" "${P_TOTAL[$i]}" \
    | cksum)
  _fp="${_fp_raw%% *}"
  FP+=("$_fp")
  _us="${P_US[$i]}"
  if [[ "${_HASH[$_us]:-}" != "$_fp" || -z "${_NUM[$_us]:-}" ]]; then
    _needs_sync=true
    debug "  US $_us precisa sync (fp_match=$([[ "${_HASH[$_us]:-}" == "$_fp" ]] && echo sim || echo nao) num=${_NUM[$_us]:-vazio})"
  fi
done

# ── Early exit: nothing changed ───────────────────────────────────────────────
if [[ "$_needs_sync" == false && "$DRY_RUN" == false ]]; then
  echo ""
  info "Backlog já sincronizado — ${#P_US[@]} USs, 0 API calls"
  echo ""
  exit 0
fi

# ── --init-cache: seed cache from GitHub without writing anything ─────────────
# Use this on the first run to avoid the rate-limited bulk-update.
# Assumes issues already exist and bodies are roughly correct.
if [[ "$INIT_CACHE" == true ]]; then
  info "Modo --init-cache: buscando issues e gravando cache local..."
  info "  → chamando gh issue list (aguarde ~10s)..."
  _IC_CACHE=$(timeout 30 gh issue list \
    --repo "$OWNER/$REPO_NAME" \
    --state all \
    --limit 100 \
    --json number,title,state \
    --jq '.[] | "\(.number)\t\(.state)\t\(.title)"' 2>/dev/null || echo "")
  info "  → gh issue list concluído (${#_IC_CACHE} bytes)"

  _seeded=0
  for i in "${!P_US[@]}"; do
    us="${P_US[$i]}"
    issue_title="[${P_US[$i]}] ${P_TITLE[$i]}"
    fp="${FP[$i]}"
    _row=""; _n=""; _s=""
    while IFS=$'\t' read -r _n _s _t; do
      [[ "$_t" == "$issue_title" ]] && { _row="$_n"; _s="${_s,,}"; break; }
    done <<< "$_IC_CACHE"
    if [[ -n "$_row" ]]; then
      _HASH["$us"]="$fp"; _NUM["$us"]="$_row"; _STATE["$us"]="$_s"
      ok "Cacheada: $issue_title (#$_row)"; _seeded=$((_seeded+1))
    else
      warn "Não encontrada no GitHub: $issue_title (será criada no próximo run)"
    fi
  done
  {
    for _k in "${!_HASH[@]}"; do
      printf '%s\t%s\t%s\t%s\n' "$_k" "${_HASH[$_k]}" "${_NUM[$_k]:-}" "${_STATE[$_k]:-}"
    done
  } > "$_SYNC_STATE_FILE"
  echo ""
  info "Cache gravado em $_SYNC_STATE_FILE ($_seeded/${#P_US[@]} USs)"
  info "Próximo run será instantâneo."
  echo ""
  exit 0
fi

# ── Phase 3: Pre-fetch issues & board URL (only when sync is needed) ──────────

# Cache account type (one-time API call; cached in .github/account-type)
BOARD_URL=""
if [[ -n "$OWNER" ]]; then
  _ACCT_FILE="$SCRIPT_DIR/.github/account-type"
  if [[ -f "$_ACCT_FILE" ]]; then
    _ACCT_TYPE=$(cat "$_ACCT_FILE")
  else
    info "Detectando tipo de conta (uma vez)..."
    _ACCT_TYPE=$(gh api "users/$OWNER" --jq '.type' 2>/dev/null || echo "User")
    echo "$_ACCT_TYPE" > "$_ACCT_FILE"
  fi
  if [[ "$_ACCT_TYPE" == "Organization" ]]; then
    BOARD_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
  else
    BOARD_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
  fi
fi

# Pre-fetch all issues in one API call
_CACHE=""
if [[ -n "$OWNER" && -n "$REPO_NAME" ]]; then
  info "Buscando issues existentes..."
  _CACHE=$(gh issue list \
    --repo "$OWNER/$REPO_NAME" \
    --state all \
    --limit 100 \
    --json number,title,state \
    --jq '.[] | "\(.number)\t\(.state)\t\(.title)"' 2>/dev/null || echo "")
fi

echo ""
echo "$SEPARATOR"
if [[ "$DRY_RUN" == true ]]; then
  echo "  sync-github-issues.sh (DRY RUN)"
else
  echo "  sync-github-issues.sh"
fi
[[ -n "$OWNER" ]] && echo "  Repo: $OWNER/$REPO_NAME"
echo "  Backlog: $BACKLOG_FILE"
echo "$SEPARATOR"
echo ""

# ── Helper: lookup issue from cache ──────────────────────────────────────────
_lookup() {
  local search_title="$1" _n="" _s="" _t=""
  [[ -z "$_CACHE" ]] && return
  while IFS=$'\t' read -r _n _s _t; do
    if [[ "$_t" == "$search_title" ]]; then printf '%s\t%s' "$_n" "${_s,,}"; return; fi
  done <<< "$_CACHE"
}

# ── Helper: persist sync state ────────────────────────────────────────────────
_save_state() {
  [[ "$DRY_RUN" == true ]] && return
  {
    for _k in "${!_HASH[@]}"; do
      printf '%s\t%s\t%s\t%s\n' "$_k" "${_HASH[$_k]}" "${_NUM[$_k]:-}" "${_STATE[$_k]:-}"
    done
  } > "$_SYNC_STATE_FILE"
}

# ── Phase 4: Process each US ──────────────────────────────────────────────────
CREATED=0; UPDATED=0; SKIPPED=0

for i in "${!P_US[@]}"; do
  us="${P_US[$i]}"; title="${P_TITLE[$i]}"; priority="${P_PRIO[$i]}"
  milestone="${P_MILE[$i]}"; tasks_body="${P_TASKS[$i]}"
  done_count="${P_DONE[$i]}"; total_count="${P_TOTAL[$i]}"; fp="${FP[$i]}"

  issue_title="[$us] $title"
  priority_label=$(priority_to_label "$priority")
  full_body=""; [[ -n "$tasks_body" ]] && full_body="$(printf '## Tasks\n\n%b' "$tasks_body")"

  all_done=false
  [[ "$total_count" -gt 0 && "$done_count" -eq "$total_count" ]] && all_done=true

  status_str="sem tasks"
  [[ "$total_count" -gt 0 && "$done_count" -eq "$total_count" ]] && status_str="CONCLUÍDA ($done_count/$total_count tasks)"
  [[ "$total_count" -gt 0 && "$done_count" -gt 0 && "$done_count" -lt "$total_count" ]] && status_str="em andamento ($done_count/$total_count tasks)"
  [[ "$total_count" -gt 0 && "$done_count" -eq 0 ]] && status_str="pendente (0/$total_count tasks)"

  # Lookup from pre-fetched cache
  _row=$(_lookup "$issue_title")
  existing_number="${_row%%$'\t'*}"; existing_state="${_row##*$'\t'}"
  [[ "$_row" == "$existing_number" ]] && existing_state=""  # no tab found = empty

  # Dry-run output
  if [[ "$DRY_RUN" == true ]]; then
    if [[ -z "$existing_number" ]]; then
      echo "  [CRIAR]         $issue_title"; CREATED=$((CREATED+1))
    else
      echo "  [ATUALIZAR #$existing_number] $issue_title"; UPDATED=$((UPDATED+1))
    fi
    echo "    Status:    $status_str"
    [[ "$all_done" == true ]] && echo "    → Fecharia a issue"
    [[ "$all_done" == false && -n "$existing_number" ]] && echo "    → Reabriria se estiver fechada"
    echo "    Labels:    $priority_label, feature, spec-pendente"
    echo "    Milestone: ${milestone:-<sem milestone>}"
    echo ""
    continue
  fi

  # Skip if unchanged (fingerprint + issue number both match)
  if [[ "${_HASH[$us]:-}" == "$fp" && -n "${_NUM[$us]:-}" ]]; then
    skip "Sem mudanças: $issue_title (#${_NUM[$us]})"; SKIPPED=$((SKIPPED+1)); continue
  fi

  # Create new issue
  if [[ -z "$existing_number" ]]; then
    milestone_flag=()
    [[ -n "$milestone" ]] && milestone_flag=(--milestone "$milestone")
    new_url=$(gh issue create \
      --repo "$OWNER/$REPO_NAME" \
      --title "$issue_title" \
      --body "$full_body" \
      --label "$priority_label,feature,spec-pendente" \
      "${milestone_flag[@]}" 2>/dev/null || echo "")
    if [[ -n "$new_url" ]]; then
      issue_num=$(basename "$new_url")
      gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$new_url" &>/dev/null || true
      ok "Criada: $issue_title (#$issue_num)"; CREATED=$((CREATED+1))
      new_state="open"
      if [[ "$all_done" == true ]]; then
        gh issue close "$issue_num" --repo "$OWNER/$REPO_NAME" &>/dev/null || true
        info "  → Fechada"; new_state="closed"
      fi
      _HASH["$us"]="$fp"; _NUM["$us"]="$issue_num"; _STATE["$us"]="$new_state"
      _save_state
    else
      warn "Falha ao criar: $issue_title"
    fi

  # Update existing issue
  else
    gh issue edit "$existing_number" --repo "$OWNER/$REPO_NAME" --body "$full_body" &>/dev/null
    ok "Atualizada: $issue_title (#$existing_number)"; UPDATED=$((UPDATED+1))

    cur_state="$existing_state"
    if [[ "$all_done" == true && "$existing_state" != "closed" ]]; then
      gh issue close "$existing_number" --repo "$OWNER/$REPO_NAME" &>/dev/null || true
      info "  → Fechada"; cur_state="closed"
    elif [[ "$all_done" == false && "$existing_state" == "closed" ]]; then
      gh issue reopen "$existing_number" --repo "$OWNER/$REPO_NAME" &>/dev/null || true
      info "  → Reaberta"; cur_state="open"
    fi
    _HASH["$us"]="$fp"; _NUM["$us"]="$existing_number"; _STATE["$us"]="$cur_state"
    _save_state
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "$SEPARATOR"
if [[ "$DRY_RUN" == true ]]; then
  info "DRY RUN concluido — nenhuma Issue criada/alterada"
  echo "   A criar:     $CREATED"
  echo "   A atualizar: $UPDATED"
else
  info "GitHub Issues sincronizadas"
  echo "   Criadas:     $CREATED"
  echo "   Atualizadas: $UPDATED"
  echo "   Sem mudanças: $SKIPPED"
  if [[ -n "$BOARD_URL" ]]; then
    echo ""
    echo "   Board:  $BOARD_URL"
    echo "   Issues: https://github.com/$OWNER/$REPO_NAME/issues"
  fi
fi
echo "$SEPARATOR"
