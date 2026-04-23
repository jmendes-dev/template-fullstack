# Onda 1 — Destravar o fluxo atual

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar 3 falhas sistêmicas do template: (a) agentes FE/BE contornam bugs pré-existentes, (b) agentes QA/Security/PM são órfãos (nunca invocados), (c) loop de aprendizado (`claude-stacks-refactor.md` → `promote-learning.sh`) não tem gatilho automático.

**Architecture:** Mudanças localizadas em 6 arquivos do template — 2 agent prompts, 2 commands, 1 hook, 1 arquivo raiz de protocolo (CLAUDE.md). Nenhuma mudança em código de aplicação (template não tem). Todas as mudanças são **aditivas** (não quebram fluxos atuais); apenas injetam gates de qualidade antes ausentes.

**Tech Stack:** Markdown (prompts/commands), bash (hooks), JSON (settings). Validação manual via fixtures + execução controlada de `/feature` em um projeto consumidor.

**Decisões de design (consolidadas com o usuário):**
- Política bug-pré-existente do `claude-debug.md` (≤30min corrige, >30min vira P1) passa a ser **obrigatória e explícita** nos prompts dos agentes FE/BE.
- QA-engineer vira gate obrigatório em `/feature` passo VERIFY.
- Security-engineer é invocado condicionalmente quando a task toca auth/validação de input/segredos.
- Project-manager vira responsável formal por atualizar `docs/backlog.md` em `/continue` (início e fim).
- `promote-learning.sh` permanece manual (sem auto-run), mas ganha **lembrete visível** via hook quando `claude-stacks-refactor.md` tem entries pendentes.

**Branch strategy:** Criar branch `feat/onda-1-destravar-fluxo` a partir de `main`. Commits atômicos por task. PR final com checklist de validação.

---

## File Structure

Arquivos modificados (todos existentes):

| Arquivo | Responsabilidade após mudança |
|---|---|
| `.claude/agents/backend-developer.md` | Adicionar seção "Bugs pré-existentes — STOP protocol" + gate nos quality self-checks |
| `.claude/agents/frontend-developer.md` | Idem FE |
| `.claude/commands/feature.md` | Passo VERIFY invoca QA-engineer; novo passo 4.5 "Security Review" condicional |
| `.claude/commands/continue.md` | Passos 0 (PM refresh backlog) e 5 (PM close item) |
| `.claude/hooks/post-tool-use.sh` | Detectar Edit/Write em `claude-stacks-refactor.md` e alertar sobre entries `⏳ Pendente` |
| `CLAUDE.md` | Atualizar tabelas "Routing" e "Ownership" para refletir invocações novas |

Arquivos criados: **nenhum** (mudanças aditivas em arquivos existentes).

---

## Task 1: Integrar claude-debug.md no backend-developer

**Files:**
- Modify: `.claude/agents/backend-developer.md`

- [ ] **Step 1.1: Adicionar seção "Bugs pré-existentes — STOP protocol" logo após "## STACK ESPECÍFICA DESTE PROJETO"**

Localizar o bloco que termina em `Se bug aparecer durante desenvolvimento, acionar hono-api-debugging skill.` (linha 115) e **após esse parágrafo**, inserir:

```markdown
**Bugs pré-existentes — STOP protocol (obrigatório)**:

Antes de declarar uma task pronta, rodar `bun test`, `bunx biome check`, `tsc --noEmit`.
Se aparecer QUALQUER erro que NÃO foi causado pela task atual:

1. NÃO contornar, NÃO usar try/catch para esconder, NÃO comentar teste que falha.
2. Aplicar política de `claude-debug.md` → seção "Bugs pré-existentes":
   - Escopo ≤ 30 min → corrigir agora, commit separado `fix: corrigir [descrição] pré-existente`
   - Escopo > 30 min → PARAR task atual, retornar ao orquestrador com `STATUS: BLOCKED` e `CONCERNS: bug pré-existente encontrado em [arquivo:linha], escopo estimado > 30min, recomendo criar P1 no backlog`
3. Se resolver na task atual: incluir o fix no relatório final (`ARTEFATOS` e `CONCERNS`).

Nunca entregar DONE com baseline quebrada. Nunca classificar algo como "pré-existente" para justificar seguir em frente.
```

- [ ] **Step 1.2: Ampliar QUALITY SELF-CHECKS**

Na seção `## QUALITY SELF-CHECKS` (linha 140), adicionar 2 itens ao final da lista (antes de `## UPDATE YOUR AGENT MEMORY`):

```markdown
- [ ] Nenhum erro pré-existente em `bun test`, `biome check`, `tsc --noEmit` (se houver, seguir STOP protocol em "Bugs pré-existentes")
- [ ] Memória do agente atualizada se esta task trouxe aprendizado (`.claude/agent-memory/backend-developer/MEMORY.md` ou arquivo temático) — caso contrário, registrar "nada novo" no relatório
```

- [ ] **Step 1.3: Validar o arquivo manualmente**

Ler o arquivo inteiro após edições. Confirmar:
- Seção "Bugs pré-existentes — STOP protocol" está presente e em bold.
- QUALITY SELF-CHECKS tem os 2 novos itens.
- Nenhum texto pré-existente foi removido.

- [ ] **Step 1.4: Commit**

```bash
git add .claude/agents/backend-developer.md
git commit -m "feat(agents): backend-developer passa a aplicar STOP protocol para bugs pré-existentes

- Integra política de claude-debug.md (≤30min corrige, >30min BLOCKED)
- Adiciona 2 checks em QUALITY SELF-CHECKS (baseline limpa + memória atualizada)

Onda 1 · Task 1"
```

---

## Task 2: Integrar claude-debug.md no frontend-developer

**Files:**
- Modify: `.claude/agents/frontend-developer.md`

- [ ] **Step 2.1: Adicionar seção "Bugs pré-existentes — STOP protocol" logo após o bloco de debugging skills**

Localizar o bloco que termina em `Para alta qualidade visual, usar frontend-design ou ui-ux-pro-max skill.` (linha 112) e **após esse parágrafo**, inserir:

```markdown
**Bugs pré-existentes — STOP protocol (obrigatório)**:

Antes de declarar uma task pronta, rodar `bun test`, `bunx biome check`, `tsc --noEmit`.
Se aparecer QUALQUER erro que NÃO foi causado pela task atual:

1. NÃO contornar, NÃO usar try/catch para esconder, NÃO comentar teste que falha.
2. Aplicar política de `claude-debug.md` → seção "Bugs pré-existentes":
   - Escopo ≤ 30 min → corrigir agora, commit separado `fix: corrigir [descrição] pré-existente`
   - Escopo > 30 min → PARAR task atual, retornar ao orquestrador com `STATUS: BLOCKED` e `CONCERNS: bug pré-existente encontrado em [arquivo:linha], escopo estimado > 30min, recomendo criar P1 no backlog`
3. Se resolver na task atual: incluir o fix no relatório final (`ARTEFATOS` e `CONCERNS`).

Nunca entregar DONE com baseline quebrada. Nunca classificar algo como "pré-existente" para justificar seguir em frente.
```

- [ ] **Step 2.2: Ampliar QUALITY ASSURANCE**

Na seção `## QUALITY ASSURANCE` (linha 127), adicionar 2 bullets ao final (antes de `## COMMUNICATION STYLE`):

```markdown
- Verify que `bun test`, `biome check`, `tsc --noEmit` estão zerados — se houver erro pré-existente, aplicar STOP protocol (ver seção "Bugs pré-existentes — STOP protocol").
- Verify que a memória do agente foi atualizada se houve aprendizado novo (`.claude/agent-memory/frontend-developer/MEMORY.md`); caso contrário, declarar "nada novo" no relatório.
```

- [ ] **Step 2.3: Validar o arquivo manualmente**

Ler o arquivo inteiro após edições. Confirmar as mesmas invariâncias da Task 1.3.

- [ ] **Step 2.4: Commit**

```bash
git add .claude/agents/frontend-developer.md
git commit -m "feat(agents): frontend-developer passa a aplicar STOP protocol para bugs pré-existentes

- Integra política de claude-debug.md
- Adiciona 2 checks em QUALITY ASSURANCE (baseline limpa + memória atualizada)

Onda 1 · Task 2"
```

---

## Task 3: /feature invocar QA-engineer e Security-engineer

**Files:**
- Modify: `.claude/commands/feature.md`

- [ ] **Step 3.1: Substituir o Passo 5 (VERIFY) inteiro**

Localizar a seção `## Passo 5 — VERIFY` (linhas 43-51) e substituir por:

```markdown
## Passo 5 — VERIFY

Invocar skill: `superpowers:verification-before-completion`

Antes de declarar qualquer coisa como pronto:
- Todos os testes passam: `bun test`
- Lint e typecheck limpos: `bunx biome check && tsc --noEmit`
- Cobertura ≥ 95% por módulo: `./check-quality.sh`
- Comportamento testado manualmente no happy path e edge cases

### 5.1 — QA Review (obrigatório)

Despachar `qa-engineer` via Agent tool. Prompt esperado ao agente:

> Revisar a implementação da feature `<título>` contra os cenários do spec `docs/specs/<US-XX>.spec.md` (se existir) e o relatório de cobertura em `docs/quality.md`. Identificar gaps de casos de teste, edge cases não cobertos, e regressões potenciais em features vizinhas. Reportar com `STATUS: DONE | DONE_WITH_CONCERNS | BLOCKED` e lista acionável de testes faltantes.

Se QA retornar `DONE_WITH_CONCERNS` ou `BLOCKED` → escrever tasks no backlog (P1 se bloqueia release) e iterar antes de prosseguir.

### 5.2 — Security Review (condicional)

Despachar `security-engineer` **APENAS SE** a feature toca um destes gatilhos:

- Qualquer arquivo em `apps/api/src/middleware/` ou que importa `getAuth`/`clerkMiddleware`
- Rota nova que recebe input do usuário (`c.req.json()`, `c.req.query()`, form data)
- Schema novo em `packages/shared/src/schemas/` com campos sensíveis (email, password, token, apiKey, secret)
- Variável nova em `.env.example` com sufixo `_SECRET`, `_KEY`, `_TOKEN`
- Mudança em políticas de CORS, CSP, rate-limit, ou headers de segurança

Prompt esperado ao `security-engineer`:

> Revisar a feature `<título>` contra OWASP Top 10 e checklist do template. Focar em: validação de input, autorização por role (RBAC), vazamento de segredos, cabeçalhos de segurança, rate-limiting. Reportar com `STATUS` e achados acionáveis.

Se Security retornar `DONE_WITH_CONCERNS` → avaliar com usuário se vira P1; se `BLOCKED` → não fazer merge.
```

- [ ] **Step 3.2: Ampliar seção "Regras"**

Na lista de regras (linhas 58-64), adicionar após `- ❌ Pular VERIFY antes de declarar pronto`:

```markdown
- ❌ Pular QA Review em 5.1 (sempre obrigatório)
- ❌ Pular Security Review em 5.2 quando algum gatilho (auth/input/segredo) é tocado
```

- [ ] **Step 3.3: Validar o arquivo manualmente**

Ler o arquivo inteiro. Confirmar que VERIFY agora tem subseções 5.1 e 5.2, e que a seção Regras reflete as novas obrigações.

- [ ] **Step 3.4: Commit**

```bash
git add .claude/commands/feature.md
git commit -m "feat(commands): /feature invoca qa-engineer e security-engineer no VERIFY

- Passo 5.1 (QA) vira obrigatório para toda feature
- Passo 5.2 (Security) dispara em gatilhos: auth, input, segredos, CORS/CSP
- Regras atualizadas proibindo pular qualquer um dos dois

Onda 1 · Task 3"
```

---

## Task 4: /continue invocar Project-Manager

**Files:**
- Modify: `.claude/commands/continue.md`

- [ ] **Step 4.1: Substituir o arquivo inteiro**

Conteúdo novo completo (substitui o existente):

```markdown
---
description: "Retoma o backlog: lê docs/backlog.md e executa a próxima P1"
---

# /continue — Retomar Backlog

Use para continuar o desenvolvimento a partir do backlog priorizado.

## Processo

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

### Passo 1 — Apresentar e executar

Com base no output do PM, apresentar o item ao usuário:

```
Próxima P1: [título]
Estimativa: [XS/S/M/L/XL]
Dependências: [nenhuma | lista]
```

Invocar `/feature [descrição do item]` diretamente — invocar `/continue` já é confirmação de intenção.

**Exceção**: se houver dependências não resolvidas → perguntar como proceder antes de iniciar.

### Passo 2 — PM close (ao fim da feature)

Após o `/feature` retornar DONE, despachar `project-manager` novamente. Prompt esperado:

> Fechar a task recém-concluída em `docs/backlog.md`: (a) marcar como concluída (riscar, mover para seção "Concluídas" ou aplicar convenção atual); (b) registrar referência ao commit de merge; (c) atualizar `docs/session-state.md` com próxima P1 sugerida; (d) se a issue do GitHub existir, chamar `./sync-github-issues.sh` para propagar. Reportar com `STATUS: DONE` e lista de arquivos atualizados.

## Regras

- ❌ Iniciar item P2 ou P3 enquanto houver P1 pendentes
- ❌ Iniciar item com dependências não resolvidas sem confirmar com o usuário
- ❌ Pular Passo 0 (PM refresh) — backlog pode estar desatualizado
- ❌ Pular Passo 2 (PM close) — deixa o backlog eternamente desalinhado com a realidade
- ✅ Se não houver P1 pendente: informar e perguntar se deve prosseguir com P2
```

- [ ] **Step 4.2: Validar manualmente**

Ler o arquivo completo após edição. Confirmar que Passos 0, 1 e 2 estão presentes e que o `project-manager` é invocado em 0 e 2.

- [ ] **Step 4.3: Commit**

```bash
git add .claude/commands/continue.md
git commit -m "feat(commands): /continue vira PM refresh → feature → PM close

- Passo 0: project-manager faz refresh do backlog antes de pegar próxima P1
- Passo 2: project-manager fecha a task concluída e sincroniza com GitHub
- Regras atualizadas

Onda 1 · Task 4"
```

---

## Task 5: Hook PostToolUse alerta sobre promote-learning pendente

**Files:**
- Modify: `.claude/hooks/post-tool-use.sh`

- [ ] **Step 5.1: Adicionar bloco de detecção ao final do script**

Localizar a última linha `fi` (linha 39) que fecha o `if [ -f "$ROOT/check-quality.sh" ]; then`. **Após esse `fi`**, adicionar:

```bash

# ── Alerta promote-learning: roda somente quando o hook disparou por
#    Edit/Write em claude-stacks-refactor.md ou claude-stacks.md ───────────
_TOUCHED_LEARNING=false
_TOOL_NAME=""
_FILE_PATH=""
if command -v jq &>/dev/null && [ -n "$_RAW" ]; then
  _TOOL_NAME=$(echo "$_RAW" | jq -r '.tool_name // empty' 2>/dev/null || true)
  _FILE_PATH=$(echo "$_RAW" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
fi

case "$_FILE_PATH" in
  *claude-stacks-refactor.md|*claude-stacks.md)
    _TOUCHED_LEARNING=true ;;
esac

if [ "$_TOUCHED_LEARNING" = "true" ] && [ -f "$ROOT/claude-stacks-refactor.md" ]; then
  # Procurar marcador de entries pendentes na tabela "Candidatos a promoção"
  if grep -qE '⏳ *Pendente' "$ROOT/claude-stacks-refactor.md"; then
    printf '\n[learning-loop] claude-stacks-refactor.md contém entries "⏳ Pendente". Rode: ./promote-learning.sh\n' >&2
  fi
fi
```

- [ ] **Step 5.2: Validar sintaxe do script**

```bash
bash -n .claude/hooks/post-tool-use.sh
```

Expected: saída vazia (sintaxe válida).

- [ ] **Step 5.3: Teste unitário do bloco novo (fixture)**

Criar fixture temporária com entry pendente e verificar que o alerta dispara:

```bash
cat > /tmp/fixture-hook.json <<'EOF'
{"tool_name":"Edit","tool_input":{"file_path":"claude-stacks-refactor.md"},"tool_result":"ok"}
EOF

# Injetar entry pendente temporária
cp claude-stacks-refactor.md claude-stacks-refactor.md.bak
printf '\n| Regra teste | Origem | Destino | ⏳ Pendente |\n' >> claude-stacks-refactor.md

# Executar
OUT=$(cat /tmp/fixture-hook.json | bash .claude/hooks/post-tool-use.sh 2>&1 || true)

# Restaurar
mv claude-stacks-refactor.md.bak claude-stacks-refactor.md
rm /tmp/fixture-hook.json

echo "$OUT" | grep -q "learning-loop" && echo "PASS" || { echo "FAIL"; exit 1; }
```

Expected: `PASS`.

- [ ] **Step 5.4: Teste negativo — sem entries pendentes, sem alerta**

```bash
cat > /tmp/fixture-hook.json <<'EOF'
{"tool_name":"Edit","tool_input":{"file_path":"claude-stacks-refactor.md"},"tool_result":"ok"}
EOF

OUT=$(cat /tmp/fixture-hook.json | bash .claude/hooks/post-tool-use.sh 2>&1 || true)
rm /tmp/fixture-hook.json

echo "$OUT" | grep -q "learning-loop" && { echo "FAIL — alerta disparou sem entry pendente"; exit 1; } || echo "PASS"
```

Expected: `PASS`.

- [ ] **Step 5.5: Commit**

```bash
git add .claude/hooks/post-tool-use.sh
git commit -m "feat(hooks): post-tool-use alerta quando claude-stacks-refactor.md tem entries pendentes

- Detecta edit/write em claude-stacks-refactor.md ou claude-stacks.md
- Se houver linha marcada ⏳ Pendente, emite lembrete para rodar promote-learning.sh
- Validado com fixture positiva e negativa

Onda 1 · Task 5"
```

---

## Task 6: Atualizar CLAUDE.md (routing + ownership)

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 6.1: Expandir tabela ROUTING DE AGENTES**

Na seção `## 🤖 ROUTING DE AGENTES — Referência rápida`, **substituir a tabela inteira** por:

```markdown
| Arquivo / Domínio / Gatilho | Agente | Invocação |
|---|---|---|
| `apps/api/**` (rotas, serviços, middleware) | `backend-developer` | Automática por arquivo |
| `apps/web/**` (componentes, pages, hooks) | `frontend-developer` | Automática por arquivo |
| `packages/shared/src/schemas/**` | `data-engineer-dba` | Automática por arquivo |
| CI/CD, Dockerfile, GitHub Actions, docker-compose | `devops-sre-engineer` | Automática por arquivo |
| `docs/design-system/**`, componentes visuais novos | `ux-ui-designer` | Via `/feature` quando há UI nova |
| Arquitetura, ADRs, revisão estrutural | `software-architect` | Via `/new-project` ou review explícito |
| Backlog, sprint, DoD, issues/PRs | `project-manager` | `/continue` Passo 0 e Passo 2 |
| Levantamento de requisitos, roadmap | `requirements-roadmap-builder` | `/new-project` Fase 1/2 |
| Test plans, coverage, bug reports | `qa-engineer` | `/feature` Passo 5.1 (sempre) |
| OWASP, dependency audit, security review | `security-engineer` | `/feature` Passo 5.2 (gatilhos: auth, input, segredos, CORS) |
```

- [ ] **Step 6.2: Atualizar tabela OWNERSHIP DE ETAPAS**

Na seção `## 🔁 OWNERSHIP DE ETAPAS — Commands vs Skills`, adicionar 2 linhas à tabela existente, logo após "Executar tasks em paralelo":

Localizar `| Executar tasks em paralelo | superpowers:subagent-driven-development | skill |` e **após ela**, inserir:

```markdown
| QA review de cada feature | `qa-engineer` + `/feature` Passo 5.1 | agente |
| Security review condicional | `security-engineer` + `/feature` Passo 5.2 | agente |
| Manter backlog vivo | `project-manager` + `/continue` Passos 0/2 | agente |
```

- [ ] **Step 6.3: Atualizar seção PROIBIÇÕES**

Na lista `## 🚫 PROIBIÇÕES`, adicionar 3 bullets logo após `❌ Declarar pronto sem superpowers:verification-before-completion`:

```markdown
- ❌ Pular QA review (`qa-engineer` em `/feature` 5.1) antes de merge
- ❌ Pular Security review (`security-engineer` em `/feature` 5.2) quando feature toca auth/input/segredos
- ❌ Contornar bug pré-existente — aplicar STOP protocol do `claude-debug.md`
```

- [ ] **Step 6.4: Ler CLAUDE.md inteiro e validar**

Confirmar coerência: não há agente mencionado na tabela de routing sem coluna "Invocação", não há agente órfão (sem caminho de invocação). Tabelas de routing e ownership refletem os commands atualizados nas Tasks 3 e 4.

- [ ] **Step 6.5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(protocolo): CLAUDE.md reflete agentes não-órfãos e invocações explícitas

- Tabela ROUTING ganha coluna Invocação (Automática/via command)
- Tabela OWNERSHIP inclui QA, Security, PM como donos formais de etapas
- PROIBIÇÕES bloqueia pular QA/Security e contornar bugs pré-existentes

Onda 1 · Task 6"
```

---

## Task 7: Validação end-to-end + PR

**Files:**
- Leitura apenas (checklist manual)

- [ ] **Step 7.1: Checklist de aceitação da Onda 1**

Marcar cada item após verificar:

- [ ] `backend-developer.md` tem seção "Bugs pré-existentes — STOP protocol" e 2 novos checks no QA
- [ ] `frontend-developer.md` tem a mesma seção STOP e 2 novos bullets no QA
- [ ] `/feature.md` Passo 5 tem subpassos 5.1 (QA obrigatório) e 5.2 (Security condicional)
- [ ] `/continue.md` tem Passos 0 (PM refresh) e 2 (PM close)
- [ ] `post-tool-use.sh` testado com fixture positiva e negativa
- [ ] `CLAUDE.md` tabelas coerentes, nenhum agente sem rota de invocação
- [ ] Nenhum arquivo pré-existente foi quebrado (`bash -n` em todos scripts toca; leitura completa de cada .md)

- [ ] **Step 7.2: Simulação em projeto consumidor (smoke test)**

Em um projeto real que adota este template (ou no próprio template-fullstack se tiver um `apps/api` mock):

```bash
# Instalar mudanças via git pull do template ou sync-globals.sh
./sync-globals.sh

# Disparar /continue e observar logs
# Resultado esperado: project-manager é invocado (aparece no histórico de tool calls)
```

Documentar no PR se smoke test foi feito ou adiado para Onda 2.

- [ ] **Step 7.3: Abrir PR**

```bash
git push -u origin feat/onda-1-destravar-fluxo

gh pr create --title "Onda 1 — Destravar fluxo (agentes órfãos + STOP protocol + learning loop)" --body "$(cat <<'EOF'
## Summary
- Integra STOP protocol de `claude-debug.md` nos agentes frontend-developer e backend-developer
- `/feature` passa a invocar `qa-engineer` (obrigatório) e `security-engineer` (condicional por gatilho)
- `/continue` vira PM refresh → feature → PM close (backlog sempre vivo)
- Hook `post-tool-use` alerta sobre entries `⏳ Pendente` em `claude-stacks-refactor.md`
- `CLAUDE.md` reflete agentes não-órfãos e proíbe atalhos

## Test plan
- [ ] QA dispara em toda feature (validar ao rodar próxima `/feature`)
- [ ] Security dispara apenas em gatilhos (auth/input/segredos)
- [ ] PM atualiza backlog ao fim de `/continue`
- [ ] Agente FE/BE para quando encontra bug pré-existente
- [ ] Hook post-tool-use emite alerta quando refactor.md tem pendente
- [ ] Nenhuma quebra em fluxos existentes

## Out of scope (Onda 2+)
- Sample docker-compose.dev.yml + vite.config.ts
- docs/auth-rbac.md (tabela custom, ADMIN_EMAIL)
- MASTER.md concreto via entrevista
- Backlog em ondas + sync bidirecional
- Bootstrap real das memórias dos agentes
EOF
)"
```

---

## Ondas subsequentes (planejadas após Onda 1 DONE)

| Onda | Plano a escrever | Status |
|---|---|---|
| **Onda 2 — Scaffold Quality** | `docs/superpowers/plans/YYYY-MM-DD-onda-2-scaffold-quality.md` | Pendente — escrever após Onda 1 merge |
| **Onda 3 — Backlog em Ondas** | `docs/superpowers/plans/YYYY-MM-DD-onda-3-backlog-ondas.md` | Pendente |
| **Onda 4 — Memória que aprende** | `docs/superpowers/plans/YYYY-MM-DD-onda-4-memoria.md` | Pendente |

### Decisões carregadas para Ondas futuras
- **Onda 2.3 (RBAC)**: tabela custom no DB, primeiro usuário cadastrado é admin, `ADMIN_EMAIL` no `.env` serve de gate para promoção inicial
- **Onda 2.4 (MASTER.md)**: personalizado por projeto via entrevista (não deployar exemplo genérico)
- **Onda 2.* (ui-ux-pro-max)**: manter como dependência externa com `DESIGN.md` instruindo instalação

---

## Self-Review (executada antes de handoff)

**1. Spec coverage:**
- Onda 1.1 (claude-debug.md nos agentes) → Tasks 1 e 2 ✅
- Onda 1.2 (QA+Security em /feature) → Task 3 ✅
- Onda 1.3 (PM em /continue) → Task 4 ✅
- Onda 1.5 (hook learning loop) → Task 5 ✅
- Atualização de CLAUDE.md para refletir mudanças → Task 6 ✅
- Onda 1.4 (inject MEMORY.md via hook) → **movido para Onda 4** (já coberto pelo frontmatter `memory: project`; problema real é MEMORY.md vazio, não injeção)

**2. Placeholder scan:** Nenhum TBD/TODO/etc. Todos os blocos de edição têm conteúdo completo.

**3. Type consistency:** Nomes de agentes (`qa-engineer`, `security-engineer`, `project-manager`) grafados de forma idêntica em todas as tasks. Convenção de commit `Onda 1 · Task N` consistente.
