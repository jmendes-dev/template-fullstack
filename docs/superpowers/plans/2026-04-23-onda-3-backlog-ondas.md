# Onda 3 — Backlog em Ondas · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar eixo "Wave" ao backlog (agrupador business-meaningful), mapeado 1:1 com GitHub Milestones, com sync automático e integração em `/continue` e `/finish`.

**Architecture:** Formato novo em `docs/backlog.md` usa heading nível-2 `## Wave: <Nome>` como contexto persistente para todas as USs subsequentes. `sync-github-issues.sh` detecta headings e injeta `--milestone <Nome>` no `gh issue create`. `setup-github-project.sh` lê backlog, extrai waves únicas, cria milestones idempotentemente. `/finish` e `/continue` incorporam waves via prompts ao `project-manager` agent.

**Tech Stack:** Markdown (templates/docs), Bash (parsers/scripts), GitHub REST API via `gh`.

**Decisões consolidadas do spec (§3):**
- Wave → GitHub Milestone (Opção A)
- Só texto nas waves (sem emojis)
- Sem script de migração (só projetos novos)
- Marcação de conclusão: `**Status:** concluída` + tasks `[x]`
- Sync one-way (backlog → GitHub)
- Wave `Backlog` é default para USs sem onda concreta

**Branch strategy:** `feat/onda-3-backlog-ondas` (já criada a partir de main após merges das Ondas 1-2 e fixes sync-globals).

---

## File Structure

| Arquivo | Tipo | Responsabilidade |
|---|---|---|
| `docs/backlog.md` | reescrita | Template raiz com formato de waves |
| `sync-github-issues.sh` | modify | Parser detecta `## Wave:` e mapeia para milestone |
| `setup-github-project.sh` | modify | Cria milestones a partir de waves do backlog (remove hardcoded Épicos) |
| `.claude/commands/finish.md` | modify | Passo 4 invoca PM para marcar US concluída em backlog + fechar issue |
| `.claude/commands/continue.md` | modify | Passo 0 refinado — PM prioriza wave ativa |
| `.claude/skills/prd-planejamento/SKILL.md` | modify | Seção nova explicando que plano→backlog usa Waves como grouping |
| `claude-stacks.md` | modify | Referência ao formato de waves (seção próxima ao backlog) |
| `CLAUDE.md` | modify | Seção SCRIPTS explica fluxo wave → milestone |

---

## Task 1: Reescrever `docs/backlog.md` com formato de waves

**Files:**
- Modify: `docs/backlog.md`

- [ ] **Step 1.1: Sobrescrever `docs/backlog.md` com este conteúdo exato**

```markdown
# Backlog

> Waves = entregas visíveis ao cliente · P1/P2/P3 = ordem interna dentro da wave.
> Cada wave corresponde a um GitHub Milestone homônimo (ver `sync-github-issues.sh`).
> Gerado via `/new-project` (skill `novo-prd` → `prd-planejamento` → `project-manager` agent).

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** — Crítico | Bloqueia outras stories ou é requisito da wave atual |
| **P2** — Importante | Agrega valor significativo, fazer após P1 dentro da mesma wave |
| **P3** — Desejável | Nice-to-have, fazer se sobrar capacidade na wave |

---

### Formato

Cada wave começa com `## Wave: <Nome>` seguido de blockquote `> Milestone GitHub: \`<Nome>\` · Meta: <descrição>`.
USs dentro da wave usam heading nível-3 `### US-<N> — <título>` com metadata em uma linha:
`**Prioridade:** P<1|2|3>  ·  **Estimativa:** <valor>  ·  **Status:** <pendente|em andamento|concluída>`

Wave `Backlog` (catch-all) sempre existe no final — USs sem onda concreta caem aqui.

---

## Wave: Backlog
> Sem milestone atribuída. Mover para wave concreta ao priorizar.

<!-- Executar /new-project para popular waves (MVP, Release 1, etc.) e USs via entrevista guiada -->
```

- [ ] **Step 1.2: Validar**

Ler o arquivo. Confirmar:
- Tem 3 blocos separados por `---` (header/legenda, formato, wave Backlog)
- Wave `Backlog` com blockquote correto
- Comentário HTML informativo no final

- [ ] **Step 1.3: Commit**

```bash
git add docs/backlog.md
git commit -m "feat(backlog): template com formato de waves (P1/P2/P3 dentro de cada onda)

- Introduz heading '## Wave: <Nome>' como agrupador de alto nível
- Cada wave mapeia 1:1 a um GitHub Milestone homônimo
- Wave 'Backlog' é catch-all para USs sem onda concreta
- Legenda de P1/P2/P3 ajustada para enfatizar ordem interna da wave

Onda 3 · Task 1"
```

---

## Task 2: Parser de waves em `sync-github-issues.sh`

**Files:**
- Modify: `sync-github-issues.sh`

**Contexto**: o parser atual (linhas 67-102) extrai metadata de cada US via regex. Precisamos adicionar um estado `_current_wave` que é setado por `## Wave:` heading e aplicado às USs subsequentes quando `**Milestone:**` explícito não está presente.

- [ ] **Step 2.1: Adicionar estado de wave + regex na função `_flush_parse` e no loop**

Localizar o bloco (linhas ~67-102):

```bash
# ── Phase 1: Parse backlog (local — no API calls) ────────────────────────────
declare -a P_US=() P_TITLE=() P_PRIO=() P_MILE=() P_TASKS=() P_DONE=() P_TOTAL=()

_cu=""; _ct=""; _cp=""; _cm=""; _cta=""; _cd=0; _cto=0; _inu=false; _int=false

_flush_parse() {
  [[ -z "$_cu" || -z "$_ct" ]] && return
  P_US+=("$_cu"); P_TITLE+=("$_ct"); P_PRIO+=("$_cp"); P_MILE+=("$_cm")
  P_TASKS+=("$_cta"); P_DONE+=("$_cd"); P_TOTAL+=("$_cto")
  debug "  stored: $_cu — $_ct (tasks=$_cto done=$_cd)"
  _cu=""; _ct=""; _cp=""; _cm=""; _cta=""; _cd=0; _cto=0; _inu=false; _int=false
}

while IFS= read -r line || [[ -n "$line" ]]; do
  debug "L: ${line:0:80}"
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
```

Substituir por (adiciona `_current_wave` + regex do heading `## Wave:` + fallback em `_flush_parse`):

```bash
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
```

- [ ] **Step 2.2: Validar sintaxe + parser**

```bash
bash -n sync-github-issues.sh && echo "SYNTAX OK"
```

Fixture positiva — criar backlog de teste:

```bash
cat > /tmp/backlog-test.md <<'EOF'
# Backlog Test

## Wave: MVP
> Milestone GitHub: `MVP` · Meta: primeira entrega

### US-1 — Criar cliente
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente

Tasks:
- [ ] TASK-1.1: Schema
- [ ] TASK-1.2: Rota

### US-2 — Listar clientes
**Prioridade:** P2  ·  **Estimativa:** 3  ·  **Status:** pendente

Tasks:
- [ ] TASK-2.1: Handler GET

## Wave: Release 1
> Milestone GitHub: `Release 1` · Meta: expansão

### US-5 — Exportar CSV
**Prioridade:** P2  ·  **Estimativa:** 5  ·  **Status:** pendente

Tasks:
- [ ] TASK-5.1: Endpoint

## Wave: Backlog
> Sem milestone atribuída.

### US-20 — i18n
**Prioridade:** P3  ·  **Estimativa:** L  ·  **Status:** pendente

Tasks:
- [ ] TASK-20.1: Integrar lib
EOF

./sync-github-issues.sh /tmp/backlog-test.md --dry-run --debug 2>&1 | tee /tmp/sync-debug.log

# Validar saída esperada:
# - US-1: milestone MVP
# - US-2: milestone MVP
# - US-5: milestone Release 1
# - US-20: sem milestone (wave=Backlog)
grep -E "^\s+\[CRIAR\]" /tmp/sync-debug.log
grep -E "Milestone:" /tmp/sync-debug.log
```

Expected no dry-run output:
- `[CRIAR] [US-1] Criar cliente` com `Milestone: MVP`
- `[CRIAR] [US-2] Listar clientes` com `Milestone: MVP`
- `[CRIAR] [US-5] Exportar CSV` com `Milestone: Release 1`
- `[CRIAR] [US-20] i18n` com `Milestone: <sem milestone>`

Limpar:
```bash
rm -f /tmp/backlog-test.md /tmp/sync-debug.log
```

- [ ] **Step 2.3: Fixture back-compat — backlog sem waves**

```bash
cat > /tmp/backlog-legacy.md <<'EOF'
# Backlog

### US-100 — Legacy item
**Prioridade:** P1  ·  **Estimativa:** S  ·  **Status:** pendente

Tasks:
- [ ] TASK-100.1
EOF

./sync-github-issues.sh /tmp/backlog-legacy.md --dry-run 2>&1 | grep "US-100"
rm /tmp/backlog-legacy.md
```

Expected: US-100 aparece no dry-run **sem** milestone (back-compat OK, sem erro).

- [ ] **Step 2.4: Commit**

```bash
git add sync-github-issues.sh
git commit -m "feat(sync): parser detecta '## Wave: <Nome>' e mapeia para --milestone

- Nova variável _current_wave persiste entre USs dentro da mesma onda
- _flush_parse usa wave como milestone default quando **Milestone:** não é explícito
- Wave 'Backlog' (catch-all) → milestone vazia (USs sem agrupamento)
- Back-compat: backlogs sem '## Wave:' headings funcionam como antes (sem milestone)
- Validado com fixture positiva (3 waves) e legacy (sem waves)

Onda 3 · Task 2"
```

---

## Task 3: Milestones de waves em `setup-github-project.sh`

**Files:**
- Modify: `setup-github-project.sh`

**Contexto**: o script atual cria 6 milestones hardcoded "Epico 1-6" (linhas 99-104) que não refletem waves de entrega. Substituir por lógica que lê `docs/backlog.md`, extrai waves únicas (exceto "Backlog"), e cria milestones correspondentes. Manter idempotência via função `create_milestone` existente.

- [ ] **Step 3.1: Substituir bloco de milestones hardcoded**

Localizar o bloco (linhas 83-104):

```bash
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
```

Substituir por:

```bash
# ── Milestones ──────────────────────────────────
# Gera milestones a partir das waves em docs/backlog.md (heading `## Wave: <Nome>`).
# Cada wave vira um milestone homônimo; "Backlog" (catch-all) é ignorada.
# Idempotente: milestones já existentes são preservadas.
info "Criando milestones a partir de docs/backlog.md..."

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

BACKLOG_FILE="$SCRIPT_DIR/docs/backlog.md"
if [[ -f "$BACKLOG_FILE" ]]; then
  # Extrair waves únicas do backlog (exceto "Backlog")
  WAVE_COUNT=0
  while IFS= read -r wave; do
    [[ -z "$wave" ]] && continue
    [[ "$wave" == "Backlog" ]] && continue
    create_milestone "$wave"
    WAVE_COUNT=$((WAVE_COUNT + 1))
  done < <(grep -E "^##[[:space:]]+Wave:" "$BACKLOG_FILE" 2>/dev/null \
           | sed -E 's/^##[[:space:]]+Wave:[[:space:]]+//' \
           | sed -E 's/[[:space:]]+$//' \
           | sort -u)

  if [[ "$WAVE_COUNT" -eq 0 ]]; then
    warn "Nenhuma wave concreta encontrada em docs/backlog.md — nenhum milestone criado."
    warn "  Adicione seções '## Wave: <Nome>' ao backlog (exceto 'Backlog' que é catch-all)."
  else
    info "  $WAVE_COUNT wave(s) processada(s)."
  fi
else
  warn "docs/backlog.md não encontrado — pulando criação de milestones."
  warn "  Rode ./setup-github-project.sh novamente após gerar o backlog via /new-project."
fi
```

- [ ] **Step 3.2: Validar sintaxe**

```bash
bash -n setup-github-project.sh && echo "SYNTAX OK"
```

- [ ] **Step 3.3: Commit**

```bash
git add setup-github-project.sh
git commit -m "feat(setup): milestones derivadas de waves em docs/backlog.md

- Substitui milestones hardcoded 'Epico 1-6' (artefato de design antigo) por
  geração automática a partir de headings '## Wave: <Nome>' do backlog
- Wave 'Backlog' (catch-all) ignorada — só waves concretas viram milestones
- Idempotente: preserva milestones já existentes (via função create_milestone)
- Se backlog ausente ou sem waves: warn informativo, não falha

Onda 3 · Task 3"
```

---

## Task 4: `/finish` invoca PM para atualizar backlog + fechar issue

**Files:**
- Modify: `.claude/commands/finish.md`

- [ ] **Step 4.1: Adicionar Passo 4 ao final do arquivo**

Localizar o bloco final do arquivo (as regras):

```markdown
### 3 — Merge

Invocar skill: `superpowers:finishing-a-development-branch`

Seguir o procedimento da skill para:
- Criar PR com template
- Aguardar aprovação ou auto-merge se configurado
- Limpar a branch e o worktree
- Atualizar `docs/backlog.md` com o item concluído

## Regras

- ❌ Merge sem todos os itens da verificação passando
- ❌ Merge sem code review
- ❌ `--force`, `--no-verify`, `[skip ci]`
```

Substituir por:

```markdown
### 3 — Merge

Invocar skill: `superpowers:finishing-a-development-branch`

Seguir o procedimento da skill para:
- Criar PR com template
- Aguardar aprovação ou auto-merge se configurado
- Limpar a branch e o worktree

### 4 — Atualizar backlog + fechar issue (obrigatório)

Após merge do PR, despachar `project-manager` via Agent tool. Prompt esperado:

> Para a US recém-finalizada (ID extraído do título do PR/commit, formato `US-<N>`):
> (a) Em `docs/backlog.md`: alterar `**Status:** pendente|em andamento` para `**Status:** concluída`; marcar todas as tasks pendentes (`- [ ]`) da US como concluídas (`- [x]`).
> (b) Commitar com mensagem `docs(backlog): US-<N> concluída`.
> (c) Rodar `./sync-github-issues.sh` — fingerprint detecta mudança de status e fecha a issue GitHub correspondente automaticamente.
> (d) Confirmar via `gh issue view <N>` que a issue está `state: closed`.
> (e) Se a US era a última pendente da wave ativa, mencionar no relatório que a wave foi completada e sugerir próximos passos (iniciar próxima wave, ou promover USs da wave `Backlog`).
>
> Reportar com `STATUS: DONE` e lista de arquivos atualizados + número da issue fechada + status da milestone da wave.

## Regras

- ❌ Merge sem todos os itens da verificação passando
- ❌ Merge sem code review
- ❌ `--force`, `--no-verify`, `[skip ci]`
- ❌ Pular Passo 4 (backlog desatualizado rompe visibilidade de progresso das waves no GitHub Milestones)
```

- [ ] **Step 4.2: Validar**

Ler o arquivo e confirmar:
- Passo 4 presente com as 5 sub-ações (a-e)
- `project-manager` invocado explicitamente
- Regra nova proibindo pular Passo 4

- [ ] **Step 4.3: Commit**

```bash
git add .claude/commands/finish.md
git commit -m "feat(commands): /finish Passo 4 invoca PM para atualizar backlog + fechar issue

- Após merge, project-manager marca US como concluída em docs/backlog.md
- Commit docs(backlog): US-N concluída
- Roda ./sync-github-issues.sh para fechar issue automaticamente via fingerprint
- Reporta se a wave inteira foi completada (sugere próximos passos)
- Regra nova: proibido pular Passo 4 (backlog desatualizado quebra visibilidade)

Onda 3 · Task 4"
```

---

## Task 5: `/continue` prioriza wave ativa

**Files:**
- Modify: `.claude/commands/continue.md`

- [ ] **Step 5.1: Refinar prompt do PM no Passo 0**

Localizar o bloco:

```markdown
### Passo 0 — PM refresh (obrigatório)

Despachar `project-manager` via Agent tool. Prompt esperado:

> Refresh do backlog em `docs/backlog.md`: (a) reconciliar status de tasks concluídas no último ciclo cruzando com `git log --since="7 days ago"`; (b) recalcular ordem de prioridade (P1 > P2 > P3); (c) identificar a próxima P1 pronta para execução (sem dependências não resolvidas). Reportar com `STATUS: DONE` e bloco:
>
> ```
> PRÓXIMA P1: <título>
> Dependências: <nenhuma | lista>
> Estimativa: XS/S/M/L/XL
> ```

Se PM retornar `STATUS: BLOCKED` (ex: nenhuma P1 pronta) → perguntar ao usuário como proceder antes de seguir.
```

Substituir por:

```markdown
### Passo 0 — PM refresh (obrigatório)

Despachar `project-manager` via Agent tool. Prompt esperado:

> Refresh do backlog em `docs/backlog.md`:
> (a) reconciliar status de tasks concluídas no último ciclo cruzando com `git log --since="7 days ago"`
> (b) identificar a **wave ativa** — primeira wave (do topo para baixo) com pelo menos uma US que NÃO está `**Status:** concluída`. Ignorar wave `Backlog` para essa finalidade.
> (c) dentro da wave ativa, recalcular ordem de prioridade (P1 > P2 > P3) e identificar a próxima P1 pronta (sem dependências não resolvidas).
> (d) se a wave ativa está completa (todas USs com status concluída), informar e sugerir iniciar a próxima wave OU promover USs da wave `Backlog`.
>
> Reportar com `STATUS: DONE` e bloco:
>
> ```
> WAVE ATIVA: <nome> (<X> de <Y> USs concluídas)
> PRÓXIMA P1: <título>
> Dependências: <nenhuma | lista>
> Estimativa: XS/S/M/L/XL
> ```

Se PM retornar `STATUS: BLOCKED` (ex: nenhuma wave com P1 pronta) → perguntar ao usuário como proceder antes de seguir.
```

- [ ] **Step 5.2: Validar**

Ler arquivo. Confirmar que:
- Prompt cita "wave ativa" e critérios (a)-(d)
- Bloco de resposta inclui linha `WAVE ATIVA: <nome> (<X> de <Y> USs concluídas)` antes da PRÓXIMA P1
- Seções posteriores (Passo 1, Passo 2, Regras) intocadas

- [ ] **Step 5.3: Commit**

```bash
git add .claude/commands/continue.md
git commit -m "feat(commands): /continue Passo 0 prioriza wave ativa

- PM identifica wave ativa (1ª wave não-concluída, excluindo 'Backlog')
- Próxima P1 é buscada DENTRO dessa wave (não globalmente)
- Quando wave ativa completa → sugere próxima wave OU promover USs do Backlog
- Resposta inclui progresso da wave (X de Y USs concluídas)

Onda 3 · Task 5"
```

---

## Task 6: `prd-planejamento` orienta geração de backlog com waves

**Files:**
- Modify: `.claude/skills/prd-planejamento/SKILL.md`

**Contexto**: essa skill produz planos de implementação (`plans/*-plano.md`) divididos em "Fases" (Fase 0 = fundação, Fases 1+ = entregas demonstráveis). As Fases já são conceitualmente próximas das Waves. Precisamos ensinar a skill a produzir também um bloco que o `project-manager` agent use para popular `docs/backlog.md` com `## Wave:` headings.

- [ ] **Step 6.1: Adicionar nova seção `## Passo 5.5 — Geração de backlog com waves`**

Localizar o final do `## Passo 5 — Escrita do plano` (logo antes de `## Passo 6 — Revisão final`). Inserir nova seção `## Passo 5.5 — Sincronização com docs/backlog.md`:

Encontrar a linha:

```markdown
## Passo 6 — Revisão final
```

Substituir por (injeta Passo 5.5 antes):

```markdown
## Passo 5.5 — Sincronização com `docs/backlog.md`

Após escrever o plano em `plans/<feature>-plano.md`, o `project-manager` agent deve sincronizar com `docs/backlog.md`. Cada **Fase** do plano se mapeia a uma **Wave** do backlog:

- **Fase 0 — Fundação** → NÃO vira wave (é setup, não entrega ao cliente). USs dessa fase caem em `## Wave: Backlog`.
- **Fase 1+** → cada fase vira uma wave com nome descritivo extraído do título da fase (ex: "Fase 1 — Cadastro de clientes" → `## Wave: Cadastro de clientes`).

Instruções ao PM agent (ao sintetizar o backlog):

1. Para cada história MVP de uma Fase (exceto Fase 0), criar uma US em `docs/backlog.md` sob `## Wave: <nome-da-fase>`.
2. Histórias de "Prioridade Média/Baixa" do PRD (pós-MVP) vão para `## Wave: Backlog`.
3. Cada wave começa com blockquote `> Milestone GitHub: \`<nome>\` · Meta: <descrição de 1 linha da fase>`.
4. USs mantêm a prioridade P1/P2/P3 extraída do PRD (dentro da mesma wave).
5. Ordem das waves no backlog: mesma ordem das Fases no plano (Fase 1 primeiro, Fase N último, Backlog no final).

**Exemplo de geração:**

Plano tem Fase 1 ("Cadastro de clientes") com 2 histórias MVP, Fase 2 ("Dashboard") com 1 história MVP, e o PRD tem 1 história de Prioridade Média.

`docs/backlog.md` resultante:

```markdown
## Wave: Cadastro de clientes
> Milestone GitHub: `Cadastro de clientes` · Meta: usuário consegue criar e listar clientes

### US-1 — Criar cliente
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente
Tasks:
- [ ] TASK-1.1: ...

### US-2 — Listar clientes
**Prioridade:** P1  ·  **Estimativa:** 3  ·  **Status:** pendente
Tasks:
- [ ] TASK-2.1: ...

## Wave: Dashboard
> Milestone GitHub: `Dashboard` · Meta: usuário visualiza indicadores principais

### US-3 — KPIs cards
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente
Tasks:
- [ ] TASK-3.1: ...

## Wave: Backlog
> Sem milestone atribuída. Mover para wave concreta ao priorizar.

### US-10 — Exportar relatório (pós-MVP)
**Prioridade:** P2  ·  **Estimativa:** 5  ·  **Status:** pendente
Tasks:
- [ ] TASK-10.1: ...
```

Após gerar `docs/backlog.md`, o fluxo esperado é:
1. `./setup-github-project.sh` (se ainda não rodado) → cria milestones das waves
2. `./sync-github-issues.sh` → cria issues associadas às milestones corretas

---

## Passo 6 — Revisão final
```

- [ ] **Step 6.2: Validar**

Ler arquivo e confirmar:
- Novo Passo 5.5 presente antes do Passo 6
- Mapeamento Fase→Wave documentado (Fase 0 → Backlog; Fase 1+ → wave concreta)
- Exemplo de backlog gerado está correto
- Instruções ao PM agent (5 itens)

- [ ] **Step 6.3: Commit**

```bash
git add .claude/skills/prd-planejamento/SKILL.md
git commit -m "feat(skill): prd-planejamento gera backlog com waves a partir de fases

- Novo Passo 5.5 explica sincronização com docs/backlog.md
- Fase 0 (fundação) → Wave: Backlog (não é entrega visível)
- Fase 1+ → Wave concreta com nome extraído do título da fase
- Instruções ao PM agent para sintetizar backlog com '## Wave:' headings
- Exemplo concreto de backlog gerado inclui 3 waves (2 fases + Backlog)

Onda 3 · Task 6"
```

---

## Task 7: Referências em `claude-stacks.md` e `CLAUDE.md`

**Files:**
- Modify: `claude-stacks.md`
- Modify: `CLAUDE.md`

- [ ] **Step 7.1: Adicionar seção "Backlog — formato com waves" em `claude-stacks.md`**

Localizar a seção `## Git workflow` (procurar pelo heading `## Git workflow`). **Imediatamente antes dela**, inserir nova seção:

```markdown
## Backlog — formato com waves

Projeto usa formato de waves em `docs/backlog.md`. Cada wave é uma entrega visível ao cliente final (ex: "MVP", "Release 1") e corresponde a um GitHub Milestone homônimo.

Regras:
- Heading `## Wave: <Nome>` inicia um bloco de USs da mesma onda
- Blockquote seguinte: `> Milestone GitHub: \`<Nome>\` · Meta: <descrição>`
- Wave `Backlog` (catch-all) no final — USs sem onda concreta
- Dentro de cada wave, USs mantêm P1/P2/P3 (ordem interna)
- `sync-github-issues.sh` mapeia wave → milestone automaticamente
- `setup-github-project.sh` cria milestones das waves

Ver `docs/superpowers/specs/2026-04-23-onda-3-backlog-ondas-design.md` para formato completo.

```

- [ ] **Step 7.2: Atualizar tabela SCRIPTS em `CLAUDE.md`**

Localizar a tabela `## 🚀 SCRIPTS — EXECUÇÃO OBRIGATÓRIA` (procurar pelo heading). Localizar a linha:

```
| `docs/backlog.md` atualizado | `./sync-github-issues.sh` |
```

Substituir por (amplia a explicação — mesma linha + 1 nota):

```
| `docs/backlog.md` atualizado | `./sync-github-issues.sh` (detecta `## Wave:` e mapeia para GitHub Milestone) |
```

E localizar a linha:

```
| Primeiro uso em projeto novo | `./setup-github-project.sh` |
```

Substituir por:

```
| Primeiro uso em projeto novo | `./setup-github-project.sh` (cria milestones a partir das waves do backlog) |
```

- [ ] **Step 7.3: Validar**

Ler `claude-stacks.md` — confirmar seção "Backlog — formato com waves" presente antes de "Git workflow", sem remover conteúdo anterior. Ler `CLAUDE.md` — confirmar 2 linhas da tabela SCRIPTS atualizadas com explicações sobre waves.

- [ ] **Step 7.4: Commit**

```bash
git add claude-stacks.md CLAUDE.md
git commit -m "docs(stacks,protocolo): formato de waves em backlog.md + integração GitHub

- claude-stacks.md ganha seção 'Backlog — formato com waves' antes de Git workflow
- CLAUDE.md tabela SCRIPTS: sync-github-issues.sh e setup-github-project.sh
  agora explicitam que usam waves (milestone automation)
- Referência ao spec da Onda 3 para formato completo

Onda 3 · Task 7"
```

---

## Task 8: Validação E2E + PR

- [ ] **Step 8.1: Checklist consolidado**

- [ ] `docs/backlog.md` no formato novo (legenda + wave Backlog placeholder)
- [ ] `sync-github-issues.sh` detecta `## Wave:` (validado com fixture positiva + legacy)
- [ ] `setup-github-project.sh` cria milestones das waves (substituiu os 6 Épicos hardcoded)
- [ ] `/finish` Passo 4 invoca PM para atualizar backlog + fechar issue
- [ ] `/continue` Passo 0 prioriza wave ativa
- [ ] `prd-planejamento` Passo 5.5 explica mapeamento Fase→Wave para PM agent
- [ ] `claude-stacks.md` tem seção "Backlog — formato com waves"
- [ ] `CLAUDE.md` tabela SCRIPTS atualizada
- [ ] `bash -n` em `sync-github-issues.sh` e `setup-github-project.sh` OK
- [ ] Nenhum arquivo pré-existente quebrado (`git diff --stat main..HEAD` mostra só os 8 arquivos planejados)

- [ ] **Step 8.2: Push + PR**

```bash
git push -u origin feat/onda-3-backlog-ondas

gh pr create --title "Onda 3 — Backlog em Ondas (waves → GitHub Milestones)" --body "$(cat <<'EOF'
## Summary

Onda 3 de 4 da remediação do template. Adiciona eixo **Wave** ao backlog — agrupador business-meaningful (MVP, Release 1, etc.) mapeado 1:1 com GitHub Milestones. O cliente final acessa `github.com/<repo>/milestones` e vê progresso real por onda de entrega.

### Entregas

- `docs/backlog.md`: novo formato com `## Wave: <Nome>` + blockquote milestone
- `sync-github-issues.sh`: parser detecta waves, injeta `--milestone` ao criar issues (back-compat com formato antigo)
- `setup-github-project.sh`: substitui 6 milestones hardcoded ("Épico 1-6") por geração automática a partir de waves do backlog
- `/finish` Passo 4: PM marca US concluída em backlog + fecha issue GitHub + reporta se wave foi completada
- `/continue` Passo 0: PM prioriza US da wave ativa (primeira não-concluída), sugere próxima wave quando ativa termina
- `prd-planejamento` Passo 5.5: ensina PM agent a sintetizar backlog com waves (Fase → Wave)
- Docs: `claude-stacks.md` + `CLAUDE.md` com referências ao novo fluxo

### Decisões

- Wave → GitHub Milestone (Opção A, aprovada no brainstorm)
- Só texto (sem emojis) · sem script de migração (só projetos novos)
- Status concluída + tasks `[x]` (ambos)
- Sync one-way (backlog → GitHub); bidirecional fora de escopo

### Test plan

- [x] Fixture positiva: backlog com 3 waves e 4 USs → dry-run mapeia corretamente
- [x] Fixture back-compat: backlog legacy sem waves → USs criadas sem milestone, sem erro
- [x] `bash -n` em todos scripts modificados
- [ ] Smoke test em projeto consumidor após merge: `./sync-globals.sh` + `/new-project` + conferir milestones no GitHub

### Plano completo

`docs/superpowers/plans/2026-04-23-onda-3-backlog-ondas.md`

### Spec

`docs/superpowers/specs/2026-04-23-onda-3-backlog-ondas-design.md`

### Out of scope (Onda 4)

- Bootstrap real das memórias de agentes em `adopt-workflow.sh`
- `check-health.sh` reportar densidade de memória por agente
- Hook que injeta MEMORY.md no contexto do agente antes da invocação

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (aplicada antes de handoff)

**1. Spec coverage:**

| Spec §/Objetivo | Task |
|---|---|
| §4 Formato do backlog | Task 1 ✅ |
| §5.1 Template backlog.md | Task 1 ✅ |
| §5.2 prd-planejamento com waves | Task 6 ✅ |
| §5.3 sync-github-issues parser | Task 2 ✅ |
| §5.4 setup-github-project milestones | Task 3 ✅ |
| §5.5 /finish backlog update | Task 4 ✅ |
| §5.6 /continue wave ativa | Task 5 ✅ |
| §6 Fluxo E2E | Validado via Tasks 1-5 |
| §7 Testes | Fixtures em Tasks 2.2, 2.3 |
| §8 Riscos (back-compat) | Task 2.3 + Task 3 (backlog ausente warn) |

**2. Placeholder scan:** Nenhum TBD/TODO. Todos os blocos de código têm conteúdo completo.

**3. Type/naming consistency:**
- `_current_wave` grafado igual em Task 2 (variável bash)
- `## Wave:` com espaço após `:` em Tasks 1, 2, 3, 6 (regex `^##[[:space:]]+Wave:[[:space:]]+` consistente)
- `Backlog` com B maiúsculo em Tasks 1, 2, 3 (case-sensitive)
- `project-manager` agent invocado em Tasks 4 e 5 (consistente com Onda 1)
- Commit footers `Onda 3 · Task N` padrão em Tasks 1-7
