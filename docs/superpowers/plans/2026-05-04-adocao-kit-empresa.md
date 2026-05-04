# Adoção do Kit Oficial Empresa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Costurar o kit oficial da empresa (`master-*` skills + `claude-stacks.md` + `start_project.md` + `docs/<empresa>`) ao sistema de orquestração do template, sem perder os commands pt-BR, agentes, hooks, design system ou waves.

**Architecture:** 3 camadas — (1) **Kit Empresa** imutável sincronizado pela GitHub Action corporativa via allowlist (`.claude/skills/master-*/`, `claude-stacks.md`, `start_project.md`, `docs/<empresa>`); (2) **Template** preservado, costurado ao kit via routing atualizado em `CLAUDE.md`, `/triage`, `/feature`, `/bug`; (3) Skills duplicadas do template (`novo-prd`, `prd-planejamento`) são removidas — kit empresa cobre.

**Tech Stack:** Markdown (CLAUDE.md, commands, skills), Edit tool, git, ripgrep para verificação. Sem código de produção tocado.

**Decisões de entrada (do usuário, 2026-05-04):**
1. Kit empresa é **obrigatório** e **inalterado** em todo projeto.
2. Em conflito, **empresa ganha**.
3. Sync já é resolvido pela **GitHub Action corporativa** (allowlist).
4. Sistema do template é **preservado**.

---

## File Structure

| Tipo | Arquivo | Mudança |
|---|---|---|
| MODIFICA | `CLAUDE.md` | Hierarquia + nova seção "Kit Empresa" + 7 linhas na tabela de skills + 1 linha na tabela de sub-arquivos |
| MODIFICA | `.claude/commands/triage.md` | 6 nós novos na árvore de decisão |
| MODIFICA | `.claude/commands/feature.md` | Nota de delegação ao `master-fase`; Passo 5.2 invoca `master-security-review` antes do agente |
| MODIFICA | `.claude/commands/bug.md` | Novo nó "CI quebrou" → `master-ci-fix` na triagem |
| MODIFICA | `claude-stacks-versions.md` | Aviso de fonte de verdade |
| MODIFICA | `docs/auth-rbac.md` | Cross-reference apontando para `docs/auth-clerk.md` (kit empresa) |
| MODIFICA | `.claude/commands/new-project.md` | Substituir refs a `novo-prd`/`prd-planejamento` por `master-prd`/`master-plan` |
| MODIFICA | `adopt-workflow.sh` e `.ps1` | Remover `novo-prd` e `prd-planejamento` da lista de skills propagadas |
| MODIFICA | `docs/backlog.md` | Remover/atualizar referências a `novo-prd`/`prd-planejamento` |
| MODIFICA | `docs/user-stories.md` | Remover/atualizar referências a `novo-prd`/`prd-planejamento` |
| DELETA | `.claude/skills/novo-prd/SKILL.md` | Substituído por `master-prd` (kit empresa) |
| DELETA | `.claude/skills/prd-planejamento/SKILL.md` | Substituído por `master-plan` (kit empresa) |
| INTACTO | `.claude/agents/*`, `agent-memory/*`, `.claude/hooks/*`, `DESIGN.md`, `docs/design-system/`, `docs/superpowers/*` (exceto plano novo), `docs/specs/`, `docs/contracts/`, `docs/adr/`, `docs/quality.md`, `claude-debug.md`, `claude-stacks-refactor.md`, `claude-sdd.md`, `claude-stacks.md` (será substituído pela Action), `start_project.md` (será substituído pela Action), `.claude/skills/five-response-selector/`, `templates/`, `README.md`, `CHANGELOG.md` | Sem mudança neste plano |

**Pré-requisitos:**
- [ ] Branch limpa ou worktree dedicado (recomendado: `feat/adocao-kit-empresa`)
- [ ] `gh auth status` autenticado (para validações futuras)
- [ ] Working tree sem mudanças não-commitadas

---

## Task 1: CLAUDE.md — Hierarquia + Kit Empresa + Skills

**Files:**
- Modify: `CLAUDE.md` (4 edits cirúrgicos)

- [ ] **Step 1.1: Verificar conteúdo atual da linha de hierarquia**

Run: `Read CLAUDE.md offset=4 limit=1`
Expected: linha contém `> **Hierarquia:** Instruções do usuário > Superpowers skills > ... > claude-stacks-refactor.md`

- [ ] **Step 1.2: Atualizar linha de hierarquia (Edit)**

Old string (exato, único na linha 4):
```
> **Hierarquia:** Instruções do usuário > Superpowers skills > `.claude/commands/` > `claude-sdd.md` > `claude-stacks.md` > `DESIGN.md` > `claude-stacks-refactor.md`
```

New string:
```
> **Hierarquia:** Instruções do usuário > **Kit Empresa** (`claude-stacks.md`, `start_project.md`, `master-*` skills, `docs/<empresa>`) > Superpowers skills > `.claude/commands/` > `claude-sdd.md` > `DESIGN.md` > `claude-stacks-refactor.md`
```

(Removeu `claude-stacks.md` da posição original — agora vive em "Kit Empresa".)

- [ ] **Step 1.3: Inserir nova seção "📦 KIT EMPRESA" antes de "🔀 TRIAGEM"**

Old string (linha 28-30, único no arquivo):
```
---

## 🔀 TRIAGEM — Todo pedido segue este fluxo
```

New string:
```
---

## 📦 KIT EMPRESA — Camada imutável (sincronizada via Action)

A organização mantém um kit oficial obrigatório em todos os projetos. Esses arquivos são **sincronizados pela GitHub Action corporativa** (allowlist) e **não devem ser editados localmente** — em conflito, a versão da empresa prevalece.

| Caminho | Conteúdo |
|---|---|
| `claude-stacks.md` | Stack pinada + 33 regras técnicas (fonte de verdade) |
| `start_project.md` | 8 fases com gates para projeto novo |
| `.claude/skills/master-*/` | 7 skills operacionais oficiais (PRD, plan, fase, schema, deploy, security review, CI fix) |
| `docs/auth-clerk.md`, `docs/deploy-*.md`, `docs/observability.md`, etc. | ~33 guias técnicos por domínio |

**Conteúdo local** (template) costura sobre o kit via `CLAUDE.md`, `.claude/commands/`, `.claude/agents/` — preservado integralmente.

---

## 🔀 TRIAGEM — Todo pedido segue este fluxo
```

- [ ] **Step 1.4: Adicionar 7 linhas na tabela "⚡ SKILLS — INVOCAÇÃO OBRIGATÓRIA"**

Old string (linha 87, único — usar essa linha como âncora para inserir as 7 acima):
```
| **Antes de qualquer resposta substantiva** | `five-response-selector` |
| Qualquer feature nova ou criativa | `superpowers:brainstorming` |
```

New string:
```
| **Antes de qualquer resposta substantiva** | `five-response-selector` |
| **Criar PRD / novo produto** | `master-prd` (kit empresa) — substitui `novo-prd` |
| **Transformar PRD em plano de fases** | `master-plan` (kit empresa) — substitui `prd-planejamento` |
| **Executar fase pendente do plano** | `master-fase` (kit empresa) |
| **Mudança de schema (Drizzle/Zod) ou migration** | `master-schema` (kit empresa) |
| **Configurar deploy de produção** | `master-deploy` (kit empresa) — pergunta target obrigatoriamente (regra 32) |
| **CI quebrou após push** | `master-ci-fix` (kit empresa) — loop ≤7 tentativas |
| **Security review por endpoint Hono** | `master-security-review` (kit empresa) — gatilho do Passo 5.2 do `/feature` |
| Qualquer feature nova ou criativa | `superpowers:brainstorming` |
```

- [ ] **Step 1.5: Adicionar linha na tabela "📂 SUB-ARQUIVOS"**

Old string (único no arquivo):
```
| `claude-stacks.md` | Regras de stack, padrões técnicos |
```

New string:
```
| `claude-stacks.md` | Regras de stack, padrões técnicos (kit empresa — fonte de verdade) |
| `docs/auth-clerk.md`, `docs/deploy-*.md`, `docs/observability.md`, etc. | Guias técnicos por domínio (kit empresa) |
```

- [ ] **Step 1.6: Verificar mudanças**

Run: `Grep "Kit Empresa" CLAUDE.md -n`
Expected: 3+ matches (hierarquia, seção nova, eventualmente skills table notes)

Run: `Grep "master-prd|master-plan|master-fase|master-schema|master-deploy|master-ci-fix|master-security-review" CLAUDE.md -c`
Expected: 7+ matches

- [ ] **Step 1.7: Commit**

```bash
git add CLAUDE.md
git commit -m "feat(orchestration): integrar kit empresa em CLAUDE.md (hierarquia + skills)"
```

---

## Task 2: triage.md — Adicionar gatilhos master-*

**Files:**
- Modify: `.claude/commands/triage.md` (1 edit, expansão da árvore de decisão)

- [ ] **Step 2.1: Adicionar nós master-* na árvore de decisão**

Old string (único no arquivo):
```
├── Refatoração
│     └── Próximo passo: /refactor (branch isolada, sem novas features)
│
└── Pedido ambíguo
      └── Fazer UMA pergunta antes de qualquer ação
```

New string:
```
├── Refatoração
│     └── Próximo passo: /refactor (branch isolada, sem novas features)
│
├── "criar PRD" / "novo produto" / "documentar feature"
│     └── Invocar skill `master-prd` (kit empresa)
│
├── "fasear PRD" / "plano de implementação" / "quebrar em fases"
│     └── Invocar skill `master-plan` (kit empresa)
│
├── "executar próxima fase" / "fase N" / "continuar plano"
│     └── Invocar skill `master-fase` (kit empresa)
│
├── "criar tabela" / "alterar schema" / "nova entidade" / "migration"
│     └── Invocar skill `master-schema` (kit empresa)
│
├── "configurar deploy" / "primeiro deploy" / "publicar"
│     └── Invocar skill `master-deploy` (kit empresa) — pergunta target
│
├── "review de segurança" / "auditar endpoint" / "security review"
│     └── Invocar skill `master-security-review` (kit empresa)
│
└── Pedido ambíguo
      └── Fazer UMA pergunta antes de qualquer ação
```

- [ ] **Step 2.2: Verificar**

Run: `Grep "master-" .claude/commands/triage.md -c`
Expected: 6 matches

- [ ] **Step 2.3: Commit**

```bash
git add .claude/commands/triage.md
git commit -m "feat(triage): rotear gatilhos PRD/plano/fase/schema/deploy/security para skills master-*"
```

---

## Task 3: feature.md — Delegação ao master-fase + master-security-review no 5.2

**Files:**
- Modify: `.claude/commands/feature.md` (2 edits)

- [ ] **Step 3.1: Adicionar nota de delegação ao master-fase no Passo 4**

Old string (único no arquivo):
```
## Passo 4 — EXECUTE

Invocar skill: `superpowers:subagent-driven-development`

### Fluxo por task (via tech-lead)
```

New string:
```
## Passo 4 — EXECUTE

> **Plano gerado pelo `master-plan`?** Se o plano em uso é `plans/<slug>-plano.md` (kit empresa), preferir a skill `master-fase` para execução fase a fase. O `master-fase` cuida do gate da fase, security review por endpoint (via `master-security-review`) e fechamento do CI (via `master-ci-fix`). O fluxo `tech-lead` abaixo aplica-se a planos do template em `docs/superpowers/plans/`.

Invocar skill: `superpowers:subagent-driven-development`

### Fluxo por task (via tech-lead)
```

- [ ] **Step 3.2: Atualizar Passo 5.2 para invocar master-security-review antes do agente**

Old string (único no arquivo):
```
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

New string:
```
### 5.2 — Security Review (condicional)

**Gatilhos** — feature toca qualquer um destes:

- Qualquer arquivo em `apps/api/src/middleware/` ou que importa `getAuth`/`clerkMiddleware`
- Rota nova que recebe input do usuário (`c.req.json()`, `c.req.query()`, form data)
- Schema novo em `packages/shared/src/schemas/` com campos sensíveis (email, password, token, apiKey, secret)
- Variável nova em `.env.example` com sufixo `_SECRET`, `_KEY`, `_TOKEN`
- Mudança em políticas de CORS, CSP, rate-limit, ou headers de segurança

Quando algum gatilho aplica, executar **dois passos em sequência**:

**5.2.a — Skill operacional (kit empresa):**
Invocar `master-security-review` para rodar checklist 9-itens por endpoint Hono (auth, authz, validation, mass assignment, injection, rate limit, CORS, secure headers, response envelope) e gerar relatório arquivo:linha. Achados 🔴 críticos bloqueiam o merge — corrigir antes de prosseguir.

**5.2.b — Agente estrutural (template):**
Despachar `security-engineer` para review OWASP Top 10 estrutural complementar (vazamento de segredos em logs, RBAC consistency, ataques de timing, considerações de modelo de ameaça).

Prompt esperado ao `security-engineer`:

> Revisar a feature `<título>` contra OWASP Top 10 e o relatório do `master-security-review` em [arquivo, se gerado]. Focar em: validação de input, autorização por role (RBAC), vazamento de segredos, cabeçalhos de segurança, rate-limiting, gaps que o checklist por endpoint não cobre. Reportar com `STATUS` e achados acionáveis.

Se algum dos dois passos retornar `DONE_WITH_CONCERNS` → avaliar com usuário se vira P1; se `BLOCKED` → não fazer merge.
```

- [ ] **Step 3.3: Verificar**

Run: `Grep "master-fase|master-security-review" .claude/commands/feature.md -c`
Expected: ≥3 matches

- [ ] **Step 3.4: Commit**

```bash
git add .claude/commands/feature.md
git commit -m "feat(feature): delegar EXECUTE ao master-fase quando plano é do kit; 5.2 usa master-security-review + agente"
```

---

## Task 4: bug.md — CI quebrado invoca master-ci-fix

**Files:**
- Modify: `.claude/commands/bug.md` (1 edit no Passo 3)

- [ ] **Step 4.1: Adicionar branch CI no Passo 3 — Triagem**

Old string (único no arquivo):
```
## Passo 3 — Triagem

```
Bug óbvio (typo, import errado, campo faltando, erro de configuração)?
  └── Sim → TDD direto: Red → Green → Refactor → commit
           Invocar skill: superpowers:test-driven-development

Bug não-óbvio (causa desconhecida, já tentou e falhou, comportamento inesperado)?
  └── Não → Seguir Passo 4
```
```

New string:
```
## Passo 3 — Triagem

```
Bug é "CI quebrou após push" (workflow GitHub Actions vermelho)?
  └── Sim → Invocar skill `master-ci-fix` (kit empresa) — loop ≤7 tentativas até CI verde
           NÃO seguir Passos 4–7 (skill assume o ciclo completo)

Bug óbvio (typo, import errado, campo faltando, erro de configuração)?
  └── Sim → TDD direto: Red → Green → Refactor → commit
           Invocar skill: superpowers:test-driven-development

Bug não-óbvio (causa desconhecida, já tentou e falhou, comportamento inesperado)?
  └── Não → Seguir Passo 4
```
```

- [ ] **Step 4.2: Verificar**

Run: `Grep "master-ci-fix" .claude/commands/bug.md -c`
Expected: 1

- [ ] **Step 4.3: Commit**

```bash
git add .claude/commands/bug.md
git commit -m "feat(bug): rotear CI quebrado para skill master-ci-fix (kit empresa)"
```

---

## Task 5: claude-stacks-versions.md — Nota sobre fonte de verdade

**Files:**
- Modify: `claude-stacks-versions.md` (1 edit no topo)

- [ ] **Step 5.1: Adicionar nota após cabeçalho**

Old string (único no arquivo):
```
# claude-stacks-versions.md — Versões Pinadas

> **Arquivo de manutenção fácil.** Atualizar aqui quando uma versão muda.
> Para regras de uso e padrões técnicos, ver `claude-stacks.md`.
> Sincronizado via `sync-globals.sh` (arquivo global).

---
```

New string:
```
# claude-stacks-versions.md — Versões Pinadas

> **Arquivo de manutenção fácil.** Atualizar aqui quando uma versão muda.
> Para regras de uso e padrões técnicos, ver `claude-stacks.md`.
> Sincronizado via `sync-globals.sh` (arquivo global).

> ⚠️ **Fonte de verdade**: a partir da adoção do kit empresa, `claude-stacks.md` (sincronizado via Action corporativa) é a fonte canônica das versões pinadas. Este arquivo registra apenas notas locais de compatibilidade e diffs entre upgrades. Em conflito, `claude-stacks.md` da empresa prevalece — atualizar este arquivo para alinhar.

---
```

- [ ] **Step 5.2: Verificar**

Run: `Grep "Fonte de verdade" claude-stacks-versions.md -c`
Expected: 1

- [ ] **Step 5.3: Commit**

```bash
git add claude-stacks-versions.md
git commit -m "docs(stacks): marcar claude-stacks.md (kit empresa) como fonte de verdade de versões"
```

---

## Task 6: docs/auth-rbac.md — Atualizar cross-reference

**Files:**
- Modify: `docs/auth-rbac.md` (1 edit na linha 3)

- [ ] **Step 6.1: Atualizar referência cruzada**

Old string (único no arquivo):
```
> Complementa a seção "Auth middleware" de `claude-stacks.md`. Clerk provê **identidade** (quem é o usuário); **papel** (admin/user) é responsabilidade deste projeto, via tabela custom no DB.
```

New string:
```
> Complementa `docs/auth-clerk.md` (kit empresa, fonte canônica de Clerk). Clerk provê **identidade** (quem é o usuário); **papel** (admin/user) é responsabilidade deste projeto, via tabela custom no DB. Este doc trata só do RBAC — para detalhes de Clerk middleware, Core 3 breaking changes, dev sem Clerk, etc., ver `docs/auth-clerk.md`.
```

- [ ] **Step 6.2: Verificar**

Run: `Grep "auth-clerk.md" docs/auth-rbac.md -c`
Expected: ≥1

- [ ] **Step 6.3: Commit**

```bash
git add docs/auth-rbac.md
git commit -m "docs(auth): apontar auth-rbac.md para docs/auth-clerk.md (kit empresa)"
```

---

## Task 7: Remover skills obsoletas (novo-prd + prd-planejamento)

**Files:**
- Delete: `.claude/skills/novo-prd/SKILL.md` (e diretório)
- Delete: `.claude/skills/prd-planejamento/SKILL.md` (e diretório)

- [ ] **Step 7.1: Deletar diretório novo-prd**

```bash
git rm -r .claude/skills/novo-prd
```

Expected: arquivo removido do index

- [ ] **Step 7.2: Deletar diretório prd-planejamento**

```bash
git rm -r .claude/skills/prd-planejamento
```

Expected: arquivo removido do index

- [ ] **Step 7.3: Verificar que diretórios sumiram**

Run: `Glob ".claude/skills/novo-prd/**"`
Expected: vazio

Run: `Glob ".claude/skills/prd-planejamento/**"`
Expected: vazio

- [ ] **Step 7.4: Verificar que five-response-selector permanece**

Run: `Glob ".claude/skills/five-response-selector/**"`
Expected: 1 arquivo (`SKILL.md`)

- [ ] **Step 7.5: Commit**

```bash
git commit -m "chore(skills): remover novo-prd e prd-planejamento (substituídos por master-prd e master-plan do kit empresa)"
```

---

## Task 8: Atualizar referências em new-project.md

**Files:**
- Modify: `.claude/commands/new-project.md`

- [ ] **Step 8.1: Ler arquivo para localizar referências exatas**

Run: `Read .claude/commands/new-project.md`
Expected: identificar trechos que mencionam `novo-prd` ou `prd-planejamento`

- [ ] **Step 8.2: Para cada referência encontrada, aplicar Edit substituindo:**

Substituições padrão:
- `novo-prd` → `master-prd` (do kit empresa)
- `prd-planejamento` → `master-plan` (do kit empresa)

Para cada match único, usar Edit com contexto suficiente para garantir unicidade. Se a frase precisa ajuste para fazer sentido (ex: "skill local `novo-prd`" → "skill `master-prd` do kit empresa"), reescrever a frase.

- [ ] **Step 8.3: Verificar que não restaram referências**

Run: `Grep "novo-prd|prd-planejamento" .claude/commands/new-project.md -c`
Expected: 0

- [ ] **Step 8.4: Commit**

```bash
git add .claude/commands/new-project.md
git commit -m "feat(new-project): apontar para master-prd e master-plan (kit empresa) ao invés das skills locais removidas"
```

---

## Task 9: Atualizar adopt-workflow scripts

**Files:**
- Modify: `adopt-workflow.sh`
- Modify: `adopt-workflow.ps1`

- [ ] **Step 9.1: Ler ambos para localizar listas de skills propagadas**

Run: `Read adopt-workflow.sh`
Run: `Read adopt-workflow.ps1`

- [ ] **Step 9.2: Remover entradas de novo-prd e prd-planejamento**

Para cada script, encontrar a lista (provavelmente um array/coleção de paths) e remover as duas entradas. Manter `five-response-selector` e demais entradas.

Aplicar Edit com old_string contendo a entrada exata + linhas adjacentes para unicidade. New string remove só a entrada alvo.

- [ ] **Step 9.3: Verificar que não restaram referências**

Run: `Grep "novo-prd|prd-planejamento" adopt-workflow.sh adopt-workflow.ps1 -c`
Expected: 0

- [ ] **Step 9.4: Commit**

```bash
git add adopt-workflow.sh adopt-workflow.ps1
git commit -m "chore(adopt): remover novo-prd e prd-planejamento dos scripts de adoção"
```

---

## Task 10: Limpar referências em docs/backlog.md e docs/user-stories.md

**Files:**
- Modify: `docs/backlog.md`
- Modify: `docs/user-stories.md`

- [ ] **Step 10.1: Localizar e contar referências**

Run: `Grep "novo-prd|prd-planejamento" docs/backlog.md docs/user-stories.md -n`
Expected: lista de linhas com matches

- [ ] **Step 10.2: Para cada match, decidir uma de três ações**

Para cada referência:

1. Se é uma **task ainda pendente** que dependia da skill removida: marcar como concluída/obsoleta com nota "→ resolvido pela adoção do kit empresa (`master-prd`/`master-plan`)"
2. Se é uma **referência de documentação / explicação de uso**: substituir o nome (`novo-prd` → `master-prd`, `prd-planejamento` → `master-plan`)
3. Se é uma **task histórica já concluída**: deixar como está (registro histórico)

Aplicar Edit por match com contexto suficiente para unicidade.

- [ ] **Step 10.3: Verificar resultado**

Run: `Grep "novo-prd|prd-planejamento" docs/backlog.md docs/user-stories.md -n`
Expected: apenas matches em contexto histórico documentado (ou 0 se decidiu substituir tudo)

- [ ] **Step 10.4: Commit**

```bash
git add docs/backlog.md docs/user-stories.md
git commit -m "docs: alinhar backlog e user-stories à substituição de novo-prd/prd-planejamento por master-* (kit empresa)"
```

---

## Task 11: Verificação final cross-cutting

**Files:**
- Read-only verification

- [ ] **Step 11.1: Confirmar que CLAUDE.md tem todas as costuras**

Run: `Grep "Kit Empresa" CLAUDE.md -n`
Expected: ≥3 matches (hierarquia + título da seção + corpo)

Run: `Grep "master-(prd|plan|fase|schema|deploy|ci-fix|security-review)" CLAUDE.md -c`
Expected: 7

- [ ] **Step 11.2: Confirmar que routings estão completos**

Run: `Grep "master-prd" .claude/commands/triage.md -c`
Expected: 1

Run: `Grep "master-fase" .claude/commands/feature.md -c`
Expected: 1

Run: `Grep "master-security-review" .claude/commands/feature.md -c`
Expected: 1

Run: `Grep "master-ci-fix" .claude/commands/bug.md -c`
Expected: 1

- [ ] **Step 11.3: Confirmar que skills obsoletas não vivem em paths ativos**

Run: `Grep "novo-prd|prd-planejamento" -l --glob "!CHANGELOG.md" --glob "!docs/superpowers/plans/**" --glob "!docs/superpowers/specs/**" --glob "!docs/backlog.md" --glob "!docs/user-stories.md"`
Expected: vazio (referências históricas em planos antigos e CHANGELOG são intencionais)

- [ ] **Step 11.4: Confirmar que five-response-selector continua intacto**

Run: `Read .claude/skills/five-response-selector/SKILL.md offset=1 limit=5`
Expected: arquivo existe e tem frontmatter de skill

- [ ] **Step 11.5: Rodar check de saúde do projeto**

```bash
./check-health.sh
```

Expected: todas as verificações verdes (ou justificadas como pré-existentes)

Se `check-health.sh` não existe ou não cobrir os arquivos modificados, executar manualmente:
```bash
ls -la .claude/skills/master-* 2>&1 | head -5
# Esperado: "No such file" — kit empresa só chega após Action sincronizar
```

(Comentário: as skills `master-*` só vão materializar quando a Action corporativa rodar pela primeira vez nesta branch / projeto. O plano costura **referências** ao kit; a presença física dos arquivos é responsabilidade da Action.)

- [ ] **Step 11.6: Resumo final + push**

```bash
git log --oneline -10
git status
```

Expected:
- 8-10 commits novos (Task 1–10)
- Working tree clean

```bash
git push -u origin feat/adocao-kit-empresa
```

(Ou nome de branch escolhido no pré-requisito.)

- [ ] **Step 11.7: Abrir PR**

```bash
gh pr create --title "feat: adoção do kit oficial empresa (master-* skills + costura template)" --body "$(cat <<'EOF'
## Sumário

Costura o kit oficial corporativo (`master-*` skills + `claude-stacks.md` + `start_project.md` + `docs/<empresa>`) ao sistema de orquestração do template, sem perder commands pt-BR, agentes, hooks, design system ou waves.

## Decisões registradas

1. Kit empresa **obrigatório** e **inalterado** em todo projeto.
2. Em conflito, **empresa ganha**.
3. Sync via **GitHub Action corporativa** (allowlist).
4. Sistema do template **preservado**.

## Arquitetura — 3 camadas

- **Kit Empresa** (sincronizado via Action): `claude-stacks.md`, `start_project.md`, `.claude/skills/master-*/`, `docs/<empresa>`
- **Template** (preservado): commands pt-BR, agentes, hooks, design system, waves, debug, refactor learnings
- **Skills duplicadas removidas**: `novo-prd` (substituída por `master-prd`), `prd-planejamento` (substituída por `master-plan`)

## Mudanças

- `CLAUDE.md`: hierarquia atualizada + nova seção "Kit Empresa" + 7 linhas em SKILLS + ref em SUB-ARQUIVOS
- `.claude/commands/triage.md`: 6 nós novos (criar PRD, fasear, executar fase, schema, deploy, security review)
- `.claude/commands/feature.md`: Passo 4 delega ao `master-fase` quando plano é do kit; Passo 5.2 invoca `master-security-review` antes do agente
- `.claude/commands/bug.md`: novo nó "CI quebrou" → `master-ci-fix`
- `claude-stacks-versions.md`: aviso de fonte de verdade
- `docs/auth-rbac.md`: cross-reference para `docs/auth-clerk.md` (kit empresa)
- `.claude/commands/new-project.md`, `adopt-workflow.{sh,ps1}`, `docs/backlog.md`, `docs/user-stories.md`: substituições `novo-prd` → `master-prd`, `prd-planejamento` → `master-plan`
- Removidas: `.claude/skills/novo-prd/`, `.claude/skills/prd-planejamento/`

## Test plan

- [ ] CLAUDE.md mantém hierarquia coerente (todas as referências seguem a ordem nova)
- [ ] `/triage`, `/feature`, `/bug` rodam sem broken references
- [ ] `Grep` confirma que `novo-prd` e `prd-planejamento` não vivem em paths ativos (CHANGELOG e planos históricos OK)
- [ ] Após Action corporativa sincronizar pela 1ª vez, `master-*` ficam disponíveis e `claude-stacks.md` da empresa sobrescreve a versão local

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**Spec coverage:** Cada uma das 4 decisões do usuário é coberta — (1) e (2) ficam explícitas em CLAUDE.md hierarchy + KIT EMPRESA section; (3) é referenciada em CLAUDE.md e PR body; (4) é o postulado-chave (todas as Tasks de 1–6 e 8–10 preservam o sistema do template).

**Placeholder scan:** Nenhum "TODO", "TBD", "implement later". Cada Step contém o old_string e new_string exatos extraídos do conteúdo lido. Tasks 8 e 10 instruem o executor a Read primeiro porque o conteúdo varia (não há um único trecho conhecido) — isso é apropriado, não placeholder.

**Type consistency:** N/A (sem código) — mas verifiquei consistência de naming: `master-prd`, `master-plan`, `master-fase`, `master-schema`, `master-deploy`, `master-ci-fix`, `master-security-review` aparecem com a grafia correta em todas as Tasks.

**Mudanças no kit empresa em si:** zero. Apenas referências e costura.

---

## Execution Handoff

Plano salvo em `docs/superpowers/plans/2026-05-04-adocao-kit-empresa.md`.

Duas opções de execução:

1. **Subagent-Driven (recomendado)** — despacho um subagent fresco por task, revisão entre tasks, iteração rápida. Ideal para mudanças de orquestração com múltiplos arquivos.

2. **Inline Execution** — executo as tasks nesta sessão usando `superpowers:executing-plans`, com checkpoints para revisão a cada commit.

Qual abordagem prefere?
