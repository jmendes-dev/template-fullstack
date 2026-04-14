# GitHub Issues Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic GitHub Issues sync to the template so User Stories in `docs/backlog.md` are created as Issues on a GitHub Projects board, giving the Scrum Master real-time visibility.

**Architecture:** Two bash scripts — `setup-github-project.sh` (one-time board setup) and `sync-github-issues.sh` (backlog parser + Issues sync) — triggered automatically by the `project-manager` agent after any backlog update. A `--dry-run` flag enables safe testing without GitHub API calls.

**Tech Stack:** bash, `gh` CLI (GitHub CLI), GitHub Issues API, GitHub Projects v2 API

---

## Files

| Action | Path | Responsibility |
|---|---|---|
| Create | `setup-github-project.sh` | One-time board setup: labels, milestones, project |
| Create | `sync-github-issues.sh` | Parse `backlog.md` → create/update GitHub Issues |
| Modify | `.claude/agents/project-manager.md` | Auto-trigger sync after backlog updates |
| Modify | `adopt-workflow.sh` | Mention setup script in "Próximos passos" |

---

## Task 1: `setup-github-project.sh`

**Files:**
- Create: `setup-github-project.sh`

- [ ] **Step 1: Write failing test — preconditions**

Create `/tmp/test-setup-preconditions.sh`:

```bash
#!/usr/bin/env bash
echo "Testing setup-github-project.sh preconditions..."
OUTPUT=$(bash setup-github-project.sh 2>&1 || true)
if echo "$OUTPUT" | grep -qE "No such file|nao autenticado|not found"; then
  echo "PASS: precondition check works (file missing or auth check triggered)"
else
  echo "Output: $OUTPUT"
  echo "FAIL: unexpected output"
fi
```

Run:
```bash
bash /tmp/test-setup-preconditions.sh
```
Expected: `PASS: precondition check works (file missing or auth check triggered)`

- [ ] **Step 2: Create `setup-github-project.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# setup-github-project.sh
# Setup único do GitHub Project board, labels e milestones.
# Rodar uma vez por projeto após adotar o workflow.
#
# Uso:
#   ./setup-github-project.sh              # usa git remote atual
#   ./setup-github-project.sh owner/repo   # repo explícito

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ─────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; exit 1; }

# ── Detect repo ─────────────────────────────────
if [[ -n "${1:-}" ]]; then
  REPO="$1"
else
  REMOTE_URL=$(git remote get-url origin 2>/dev/null) \
    || error "Sem git remote. Passe o repo como argumento: owner/repo"
  REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/](.+?)(\.git)?$|\1|')
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO#*/}"
[[ -z "$OWNER" || -z "$REPO_NAME" ]] && error "Repo inválido: '$REPO'. Formato esperado: owner/repo"

# ── Check gh auth ───────────────────────────────
if ! gh auth status &>/dev/null; then
  error "gh CLI nao autenticado. Rode: gh auth login"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  setup-github-project.sh"
echo "  Repo: $OWNER/$REPO_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Labels ──────────────────────────────────────
info "Criando labels..."

create_label() {
  local name="$1" color="$2" description="$3"
  local existing
  existing=$(gh label list --repo "$OWNER/$REPO_NAME" --json name \
    --jq ".[] | select(.name == \"$name\") | .name" 2>/dev/null || echo "")
  if [[ -n "$existing" ]]; then
    warn "Label '$name' ja existe — pulando"
  else
    gh label create "$name" \
      --color "$color" \
      --description "$description" \
      --repo "$OWNER/$REPO_NAME" > /dev/null
    ok "Label: $name"
  fi
}

# Prioridade (ASCII-safe para compatibilidade bash/Windows)
create_label "P1-critico"    "d73a4a" "Bloqueia outras stories ou e requisito de lancamento"
create_label "P2-importante" "e4a500" "Agrega valor significativo, fazer apos P1"
create_label "P3-desejavel"  "0075ca" "Nice-to-have, fazer se sobrar capacidade"
# Tipo
create_label "feature"       "7057ff" "Nova funcionalidade"
create_label "bug"           "e11d48" "Correcao de defeito"
create_label "refactor"      "6b7280" "Refatoracao sem mudanca de comportamento"
create_label "docs"          "0e8a16" "Documentacao"
# Estado
create_label "spec-pendente" "bfd4f2" "Spec ainda nao aprovada"
create_label "spec-aprovada" "c2e0c6" "Spec aprovada, pronto para implementar"
create_label "em-andamento"  "f9d0c4" "Em desenvolvimento ativo"

# ── Milestones ──────────────────────────────────
info "Criando milestones..."

create_milestone() {
  local title="$1"
  local existing
  existing=$(gh api "repos/$OWNER/$REPO_NAME/milestones" \
    --jq ".[] | select(.title == \"$title\") | .title" 2>/dev/null || echo "")
  if [[ -n "$existing" ]]; then
    warn "Milestone '$title' ja existe — pulando"
  else
    gh api "repos/$OWNER/$REPO_NAME/milestones" -f title="$title" > /dev/null
    ok "Milestone: $title"
  fi
}

create_milestone "Epico 1 — Levantamento e Planejamento"
create_milestone "Epico 2 — Arquitetura e Setup"
create_milestone "Epico 3 — Desenvolvimento"
create_milestone "Epico 4 — Qualidade e Testes"
create_milestone "Epico 5 — Seguranca e Revisao"
create_milestone "Epico 6 — Deploy e Entrega"

# ── GitHub Project ───────────────────────────────
info "Criando GitHub Project board..."

REPO_DISPLAY=$(gh repo view "$OWNER/$REPO_NAME" --json name --jq '.name' 2>/dev/null \
  || echo "$REPO_NAME")
PROJECT_TITLE="${REPO_DISPLAY} — Backlog"

EXISTING_PROJECT=$(gh project list --owner "$OWNER" --format json \
  --jq ".projects[] | select(.title == \"$PROJECT_TITLE\") | .number" 2>/dev/null || echo "")

if [[ -n "$EXISTING_PROJECT" ]]; then
  warn "Project '$PROJECT_TITLE' ja existe (numero: $EXISTING_PROJECT) — reutilizando"
  PROJECT_NUMBER="$EXISTING_PROJECT"
else
  PROJECT_NUMBER=$(gh project create \
    --owner "$OWNER" \
    --title "$PROJECT_TITLE" \
    --format json --jq '.number' 2>/dev/null) \
    || error "Falha ao criar project. Verifique permissoes (scope: project)."
  ok "Project criado: $PROJECT_TITLE (numero: $PROJECT_NUMBER)"
fi

# ── Save project config ──────────────────────────
mkdir -p "$SCRIPT_DIR/.github"
printf '%s/%s/%s' "$OWNER" "$REPO_NAME" "$PROJECT_NUMBER" > "$SCRIPT_DIR/.github/project-id"
ok ".github/project-id salvo"

# ── Summary ─────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup concluido!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "Board:  https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
info "Issues: https://github.com/$OWNER/$REPO_NAME/issues"
echo ""
echo "  Proximos passos:"
echo "  1. Commitar .github/project-id:"
echo "     git add .github/project-id && git commit -m 'chore: add github project id'"
echo "  2. Sincronizar backlog existente:"
echo "     ./sync-github-issues.sh"
echo "  3. Convencao de commits para fechar Issues automaticamente:"
echo "     git commit -m 'feat: ...' -m 'Closes #N'"
echo ""
```

- [ ] **Step 3: Make executable**

```bash
chmod +x setup-github-project.sh
```

- [ ] **Step 4: Run test again — verify precondition check works**

```bash
bash /tmp/test-setup-preconditions.sh
```
Expected: `PASS: precondition check works (file missing or auth check triggered)`

- [ ] **Step 5: Commit**

```bash
git add setup-github-project.sh
git commit -m "feat: add setup-github-project.sh for board, labels, and milestones"
```

---

## Task 2: `sync-github-issues.sh`

**Files:**
- Create: `sync-github-issues.sh`

- [ ] **Step 1: Create test backlog fixture**

```bash
cat > /tmp/test-backlog.md << 'EOF'
# Backlog

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** | Crítico |

---

### P1 — Critico

### US-01 — Autenticacao de usuario

**Prioridade:** P1
**Milestone:** Epico 3 — Desenvolvimento

**Tasks:**
- [ ] 1.1 Spec aprovada
- [ ] 1.2 Schema users (Drizzle)
- [ ] 1.3 Endpoint POST /auth/login
- [ ] 1.4 Componente LoginForm

### P2 — Importante

### US-02 — Perfil de usuario

**Prioridade:** P2
**Milestone:** Epico 3 — Desenvolvimento

**Tasks:**
- [ ] 2.1 Spec aprovada
- [ ] 2.2 Endpoint GET /users/:id
- [ ] 2.3 Componente ProfilePage
EOF
```

- [ ] **Step 2: Write dry-run test**

Create `/tmp/test-sync-dryrun.sh`:

```bash
#!/usr/bin/env bash
echo "Testing sync-github-issues.sh --dry-run..."
OUTPUT=$(bash sync-github-issues.sh --dry-run /tmp/test-backlog.md 2>&1 || true)
if echo "$OUTPUT" | grep -q "No such file\|Would create"; then
  echo "PASS (file missing or dry-run output correct)"
else
  echo "Output: $OUTPUT"
  echo "FAIL: unexpected output"
fi
```

Run:
```bash
bash /tmp/test-sync-dryrun.sh
```
Expected: `PASS (file missing or dry-run output correct)` — fails because file doesn't exist yet.

- [ ] **Step 3: Create `sync-github-issues.sh`**

```bash
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
  full_body="$(printf '## Tasks\n\n%b' "$tasks_body")"

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
    --jq ".[] | select(.title == \"$issue_title\") | .number" 2>/dev/null \
    | head -1 || echo "")

  if [[ -z "$existing_number" ]]; then
    # Create new issue
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

flush_us  # process last US

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
  echo "   Board:  https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
  echo "   Issues: https://github.com/$OWNER/$REPO_NAME/issues"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

- [ ] **Step 4: Make executable**

```bash
chmod +x sync-github-issues.sh
```

- [ ] **Step 5: Run dry-run against fixture — verify parser output**

```bash
bash sync-github-issues.sh --dry-run /tmp/test-backlog.md
```
Expected:
```
  Would create/update: [US-01] Autenticacao de usuario
    Labels:    P1-critico, feature, spec-pendente
    Milestone: Epico 3 — Desenvolvimento
    Tasks:
      - [ ] 1.1 Spec aprovada
      - [ ] 1.2 Schema users (Drizzle)
      - [ ] 1.3 Endpoint POST /auth/login
      - [ ] 1.4 Componente LoginForm

  Would create/update: [US-02] Perfil de usuario
    Labels:    P2-importante, feature, spec-pendente
    Milestone: Epico 3 — Desenvolvimento
    Tasks:
      - [ ] 2.1 Spec aprovada
      - [ ] 2.2 Endpoint GET /users/:id
      - [ ] 2.3 Componente ProfilePage

  Stories encontradas: 2
```

- [ ] **Step 6: Run dry-run test script**

```bash
bash /tmp/test-sync-dryrun.sh
```
Expected: `PASS (file missing or dry-run output correct)`

- [ ] **Step 7: Commit**

```bash
git add sync-github-issues.sh
git commit -m "feat: add sync-github-issues.sh for backlog to GitHub Issues sync"
```

---

## Task 3: Atualizar `project-manager.md`

**Files:**
- Modify: `.claude/agents/project-manager.md` (inserir antes da linha `## UPDATE AGENT MEMORY`, que está na linha 111)

- [ ] **Step 1: Insert GitHub Issues Sync section**

In `.claude/agents/project-manager.md`, find the text `## UPDATE AGENT MEMORY` and insert this block immediately before it (keeping the `---` separator that exists on line 109):

```markdown
## GITHUB ISSUES SYNC

After ANY operation that creates or updates `docs/backlog.md`, execute these steps automatically as the final step:

**1 — Check if board is configured:**
```bash
test -f .github/project-id
```

**2a — If `.github/project-id` exists**, run the sync:
```bash
bash sync-github-issues.sh
```

**2b — If `.github/project-id` does NOT exist**, show this message to the user:

> "Board GitHub ainda não configurado para este projeto. Para ativar rastreamento automático de Issues, rode:
> `./setup-github-project.sh`
> Requer `gh` autenticado com permissões `repo` e `project`."

**3 — After successful sync**, include in your output:
```
🔗 GitHub Issues sincronizadas — X criadas, Y atualizadas
   https://github.com/OWNER/REPO/issues
```

**Rules:**
- Sync is ALWAYS the last step — never blocks backlog generation
- If sync fails, warn the user but do not fail the task
- Never run sync without a `.github/project-id` file present

---

```

The final file around line 109-115 should look like:

```markdown
---

## GITHUB ISSUES SYNC
...
---

## UPDATE AGENT MEMORY
```

- [ ] **Step 2: Verify insertion is correct**

```bash
grep -n "GITHUB ISSUES SYNC\|UPDATE AGENT MEMORY" .claude/agents/project-manager.md
```
Expected: both lines present, `GITHUB ISSUES SYNC` appearing before `UPDATE AGENT MEMORY`.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/project-manager.md
git commit -m "feat: project-manager auto-syncs GitHub Issues after backlog updates"
```

---

## Task 4: Atualizar `adopt-workflow.sh`

**Files:**
- Modify: `adopt-workflow.sh` (bloco "Próximos passos", em torno das linhas 304–314)

- [ ] **Step 1: Update "Próximos passos" block**

Find:
```bash
echo "  Próximos passos:"
echo ""
echo "  1. Revisar o CLAUDE.md e ajustar ao seu projeto"
if [ "$HAS_CLAUDE" = true ]; then
  echo "     (backup do anterior em CLAUDE.md.bak)"
fi
echo "  2. Rodar REQUIREMENTS.md para gerar stories e backlog"
echo "  3. Rodar DESIGN_SYSTEM.md para gerar o design system"
echo "  4. Commitar:"
echo "     git add . && git commit -m 'docs: adopt SDD/TDD workflow'"
```

Replace with:
```bash
echo "  Próximos passos:"
echo ""
echo "  1. Revisar o CLAUDE.md e ajustar ao seu projeto"
if [ "$HAS_CLAUDE" = true ]; then
  echo "     (backup do anterior em CLAUDE.md.bak)"
fi
echo "  2. Ativar rastreamento GitHub Issues (requer gh autenticado):"
echo "     ./setup-github-project.sh"
echo "  3. Rodar REQUIREMENTS.md para gerar stories e backlog"
echo "  4. Rodar DESIGN_SYSTEM.md para gerar o design system"
echo "  5. Commitar:"
echo "     git add . && git commit -m 'docs: adopt SDD/TDD workflow'"
```

- [ ] **Step 2: Verify the change**

```bash
grep -A 12 "Próximos passos" adopt-workflow.sh
```
Expected: shows the updated block with step 2 referencing `./setup-github-project.sh`.

- [ ] **Step 3: Commit**

```bash
git add adopt-workflow.sh
git commit -m "docs: mention setup-github-project.sh in adopt-workflow next steps"
```

---

## Task 5: Verificação final

**Files:** nenhum arquivo novo

- [ ] **Step 1: Verify all scripts exist and are executable**

```bash
ls -la setup-github-project.sh sync-github-issues.sh
```
Expected: both files present, permissions include `x` (`-rwxr-xr-x` or similar).

- [ ] **Step 2: Verify project-manager.md has the sync section**

```bash
grep -c "GITHUB ISSUES SYNC" .claude/agents/project-manager.md
```
Expected: `1`

- [ ] **Step 3: Verify adopt-workflow.sh has the new step**

```bash
grep -c "setup-github-project.sh" adopt-workflow.sh
```
Expected: `1`

- [ ] **Step 4: Full dry-run against a realistic multi-priority backlog**

```bash
cat > /tmp/test-full-backlog.md << 'EOF'
# Backlog

---

### P1 — Critico

### US-01 — Autenticacao

**Prioridade:** P1
**Milestone:** Epico 3 — Desenvolvimento

**Tasks:**
- [ ] 1.1 Spec aprovada
- [ ] 1.2 Schema

### P2 — Importante

### US-02 — Dashboard

**Prioridade:** P2
**Milestone:** Epico 3 — Desenvolvimento

**Tasks:**
- [ ] 2.1 Spec aprovada

### P3 — Desejavel

### US-03 — Relatorios

**Prioridade:** P3
**Milestone:** Epico 3 — Desenvolvimento

**Tasks:**
- [ ] 3.1 Spec aprovada
EOF

bash sync-github-issues.sh --dry-run /tmp/test-full-backlog.md
```
Expected: 3 stories detected (`US-01` P1-critico, `US-02` P2-importante, `US-03` P3-desejavel), no errors.

- [ ] **Step 5: Confirm git log**

```bash
git log --oneline -6
```
Expected: shows the 4 commits from Tasks 1–4, all after the brainstorming commit.
