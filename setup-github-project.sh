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
  if [[ "$REMOTE_URL" != *"github.com"* ]]; then
    error "Remote origin nao e GitHub: $REMOTE_URL. Passe o repo como argumento: owner/repo"
  fi
  REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com(:[0-9]+)?[:/]||; s|\.git$||')
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
  existing=$(gh label list --repo "$OWNER/$REPO_NAME" --json name --limit 100 \
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
# Os labels abaixo são aplicados manualmente ou pelo agente project-manager — não pelo sync script
# Estado
create_label "spec-pendente" "bfd4f2" "Spec ainda nao aprovada"
create_label "spec-aprovada" "c2e0c6" "Spec aprovada, pronto para implementar"
create_label "em-andamento"  "f9d0c4" "Em desenvolvimento ativo"

# ── Milestones ──────────────────────────────────
info "Criando milestones..."

create_milestone() {
  local title="$1"
  local existing
  existing=$(gh api "repos/$OWNER/$REPO_NAME/milestones?state=all&per_page=100" \
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

EXISTING_PROJECT=$(gh project list --owner "$OWNER" --format json --limit 100 \
  --jq ".projects[] | select(.title == \"$PROJECT_TITLE\") | .number" 2>/dev/null \
  | head -1 || echo "")

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
[[ "$PROJECT_NUMBER" =~ ^[0-9]+$ ]] || error "Numero de project invalido: '$PROJECT_NUMBER'"

# ── Save project config ──────────────────────────
mkdir -p "$SCRIPT_DIR/.github"
printf '%s/%s/%s\n' "$OWNER" "$REPO_NAME" "$PROJECT_NUMBER" > "$SCRIPT_DIR/.github/project-id"
ok ".github/project-id salvo"

# ── Summary ─────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Setup concluido!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ACCOUNT_TYPE=$(gh api "users/$OWNER" --jq '.type' 2>/dev/null || echo "User")
if [[ "$ACCOUNT_TYPE" == "Organization" ]]; then
  BOARD_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
else
  BOARD_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
fi
info "Board:  $BOARD_URL"
info "Issues: https://github.com/$OWNER/$REPO_NAME/issues"
echo ""

# ── Branch Protection (main) ────────────────────────────────
info "Configurando branch protection em main..."
gh api \
  --method PUT \
  "repos/$OWNER/$REPO_NAME/branches/main/protection" \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null \
  --field required_linear_history=false \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  > /dev/null 2>&1 \
  && ok "Branch protection em main: require PR + 1 review + no force push" \
  || warn "Branch protection não configurada (requer GitHub Pro/Team ou repo público) — configurar manualmente se necessário"

echo ""
echo "  Proximos passos:"
echo "  1. Commitar .github/project-id:"
echo "     git add .github/project-id && git commit -m 'chore: add github project id'"
echo "  2. Sincronizar backlog existente:"
echo "     ./sync-github-issues.sh"
echo "  3. Convencao de commits para fechar Issues automaticamente:"
echo "     git commit -m 'feat: ...' -m 'Closes #N'"
echo ""
