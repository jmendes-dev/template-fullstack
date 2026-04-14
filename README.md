# template-fullstack

> Template de projeto fullstack com workflow SDD/TDD + Superpowers para Claude Code.

**Stack**: Monorepo TypeScript · Bun · Hono · React 19 · Drizzle ORM · PostgreSQL · Tailwind CSS v4 · shadcn/ui

**Plugins**: [Superpowers](https://github.com/obra/superpowers) (execução + TDD + code review) · [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) (design system)

---

## Arquitetura

O sistema funciona em **4 camadas**:

```
┌─────────────────────────────────────────────────────────┐
│              REQUISITOS (PRD + fases)                     │
│  novo-prd · prd-planejamento · plans/<feature>.md        │
└───────────────────────┬─────────────────────────────────┘
                        │ alimenta o spec
                        ▼
┌─────────────────────────────────────────────────────────┐
│              SEU WORKFLOW (conhecimento)                  │
│  Specs SDD · Design Brief · Stack Rules · Backlog P1/P2/P3  │
└───────────────────────┬─────────────────────────────────┘
                        │ injeta contexto
                        ▼
┌─────────────────────────────────────────────────────────┐
│            SUPERPOWERS (execução + enforcement)           │
│  Plans · Subagentes · TDD Gates · Code Review · Verify   │
└───────────────────────┬─────────────────────────────────┘
                        │ diagnóstico por stack
                        ▼
┌─────────────────────────────────────────────────────────┐
│            PERSONAL SKILLS (debugging da stack)           │
│  Hono · Drizzle · React/TanStack · Escalação             │
└─────────────────────────────────────────────────────────┘
```

---

## Estrutura do template

```
template-fullstack/
│
│  ── Orquestração ──
├── CLAUDE.md                     ← Ponto de entrada. 9 prompts reconhecidos
├── claude-sdd.md                 ← Specs: define O QUÊ implementar (contratos, cenários)
├── claude-subagents.md           ← Templates de contexto para subagentes (conhecimento injetado)
├── claude-stacks.md              ← Stack técnica: regras, padrões, anti-patterns
├── claude-stacks-refactor.md     ← Aprendizados (começa vazio, cresce com o projeto)
├── claude-design.md              ← Regras estruturais de UI/UX reutilizáveis
├── claude-debug.md               ← Orquestração de debugging (Superpowers + personal skills)
│
│  ── Pipelines de geração ──
├── REQUIREMENTS.md               ← Entrevista → user-stories + backlog (Kanban P1/P2/P3)
├── DESIGN_SYSTEM.md              ← ui-ux-pro-max → entrevista → MASTER.md + design-brief.md
│
│  ── Bootstrap ──
├── start_project.md              ← 5 fases: planejamento → scaffold → deps/banco → app → CI/CD
│
│  ── Artefatos por feature ──
├── plans/                        ← PRDs e planos faseados gerados pelo Claude
│   ├── <feature>.md              ← PRD (problema, stories, API, MVP, escopo)
│   └── <feature>-plano.md        ← Plano faseado com tracer bullets
│
│  ── Docs vivos (por projeto) ──
├── docs/
│   ├── user-stories.md           ← Stories com critérios de aceite
│   ├── backlog.md                ← Kanban P1/P2/P3 com tasks
│   ├── specs/                    ← Specs SDD por story
│   └── design-system/
│       ├── MASTER.md             ← Fonte de verdade visual do projeto
│       ├── design-brief.md       ← Resumo ~800 tokens para subagentes de frontend
│       └── pages/                ← Overrides por página
│
│  ── Agentes especializados ──
├── .claude/
│   ├── agents/                   ← 10 agentes por papel técnico (global — sincronizado)
│   │   ├── backend-developer.md
│   │   ├── frontend-developer.md
│   │   ├── data-engineer-dba.md
│   │   ├── qa-engineer.md
│   │   ├── devops-sre-engineer.md
│   │   ├── security-engineer.md
│   │   ├── software-architect.md
│   │   ├── ux-ui-designer.md
│   │   ├── project-manager.md
│   │   └── requirements-roadmap-builder.md
│   └── agent-memory/             ← Memória persistente por agente (instanciado — versionado)
│       ├── backend-developer/MEMORY.md
│       ├── frontend-developer/MEMORY.md
│       └── ...                   ← um diretório por agente
│
│  ── Ferramentas ──
├── adopt-workflow.sh             ← Adotar workflow em projeto existente
├── sync-globals.sh               ← Template → projetos (distribuir atualizações + agentes)
├── promote-learning.sh           ← Projetos → template (coletar aprendizados)
│
│  ── Git ──
├── .gitattributes                ← Força LF nos .sh (evita falhas no Windows)
├── .githooks/post-commit         ← Avisa sobre candidatos pendentes de promoção
├── .gitignore
└── README.md
```

---

## Globais vs Instanciados

| Tipo | Arquivos | Comportamento |
|---|---|---|
| **Global** | `claude-stacks.md`, `claude-design.md`, `claude-subagents.md`, `claude-debug.md`, `start_project.md`, `REQUIREMENTS.md`, `DESIGN_SYSTEM.md`, `.gitattributes`, `.claude/agents/*.md` | Reutilizáveis. Atualizados no template, propagados via `sync-globals.sh` |
| **Instanciado** | `CLAUDE.md`, `claude-sdd.md`, `claude-stacks-refactor.md`, tudo em `docs/`, `.claude/agent-memory/` | Específicos por projeto. Nunca sobrescritos pelo sync |

### Onde cada ferramenta vive

| Arquivo | Template | Projetos |
|---|---|---|
| `adopt-workflow.sh` | ✅ | ❌ (roda uma vez, do template para o projeto) |
| `sync-globals.sh` | ✅ | ✅ (roda nos projetos para puxar atualizações) |
| `promote-learning.sh` | ✅ | ✅ (roda nos projetos para enviar aprendizados) |
| `.githooks/post-commit` | ✅ | ✅ (avisa sobre candidatos pendentes) |

### Personal skills (globais, em ~/.claude/skills/)

| Skill | Descrição |
|---|---|
| `hono-api-debugging` | Debugging de rotas, middleware, auth, response format |
| `drizzle-database-debugging` | Debugging de queries, migrations, schemas, Zod |
| `react-tanstack-debugging` | Debugging de React 19, TanStack Query, Hono RPC, shadcn/ui |
| `escalation-and-bug-journal` | Protocolo de escalação 4 níveis + Bug Journal |

---

## Guia 1 — Projeto novo (do zero)

**1. Criar repositório** — clique "Use this template" no GitHub, clone localmente.

**2. Configurar:**
```bash
git config core.hooksPath .githooks
```

Configurar a URL do template para sincronização (substitua pelo seu repositório):
```bash
# Opção A — variável de ambiente (sem editar o script)
export TEMPLATE_REPO_URL="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main"

# Opção B — editar o fallback no script (linha ~29 de sync-globals.sh)
# GITHUB_RAW_BASE="${TEMPLATE_REPO_URL:-https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main}"
```

**3. Levantar requisitos** — no Claude Code:
```
/novo-prd
```
Claude conduz uma entrevista guiada e gera `plans/<projeto>.md` com problema, stories, modelo de dados, fluxos, contrato de API e escopo do MVP.

**4. Criar plano faseado** — no Claude Code:
```
/prd-planejamento
```
Claude analisa o PRD e gera `plans/<projeto>-plano.md` com fases ordenadas por dependência (Fase 0: fundação → banco + tipos + rotas vazias; Fases 1+: features verticais completas).

**5. Gerar design system** (requer [ui-ux-pro-max](#pré-requisitos)):
```bash
# Passo 1: engine gera a base
python3 .claude/skills/ui-ux-pro-max/scripts/search.py \
  "[indústria]" --design-system --persist -p "[NomeProjeto]"

# Passo 2: colar prompt do DESIGN_SYSTEM.md no Claude para refinar

# Passo 3: design-brief.md gerado automaticamente
```

**6. Bootstrap** — no Claude Code: `Iniciar projeto novo` (5 fases automáticas).

**7. Implementar fase por fase** — no Claude Code:
```
Implementar a Fase 0 do plano
Implementar a Fase 1 do plano
```
Cada fase passa pelo ciclo completo: spec técnico → micro-tasks → testes → revisão → merge.

---

## Guia 2 — Projeto existente (retrofit)

**1. Rodar script de adoção** (do diretório do template):
```bash
./adopt-workflow.sh /path/to/seu-projeto
```

O script copia automaticamente:
- Arquivos globais (`claude-stacks.md`, `claude-design.md`, `claude-subagents.md`, `claude-debug.md`, `.gitattributes`, etc.)
- `.claude/agents/` — todos os 10 agentes especializados
- `.claude/agent-memory/` — estrutura de memória criada vazia para cada agente
- `docs/` — estrutura com templates para user-stories, backlog e design system
- `.githooks/post-commit` — hook de candidatos (com `core.hooksPath` configurado automaticamente)

**2. Copiar scripts de sync para o projeto:**
```bash
cp sync-globals.sh promote-learning.sh /path/to/seu-projeto/
```

**3. Configurar URL do template** no projeto (para sincronizações futuras):
```bash
cd /path/to/seu-projeto
export TEMPLATE_REPO_URL="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main"
# Ou edite sync-globals.sh linha ~29 com sua URL
```

**4. Ajustar CLAUDE.md** ao projeto ou no Claude Code: `Adotar workflow SDD/TDD neste projeto`.

**5. Gerar docs** — REQUIREMENTS.md (stories + backlog) e DESIGN_SYSTEM.md (design system).

**6. Commitar:**
```bash
git add . && git commit -m "docs: adopt SDD/TDD workflow"
```

---

## Guia 3 — Sincronização: Template → Projetos

> Quando: você atualizou um arquivo global ou um agente no template e quer propagar para projetos.

**1. Atualize e pushe o template:**
```bash
cd /path/to/template-fullstack
git add claude-design.md && git commit -m "docs: update" && git push
```

**2. Em cada projeto, rode o sync:**
```bash
cd /path/to/seu-projeto

# Do GitHub (padrão)
./sync-globals.sh

# Com URL customizada via env var
TEMPLATE_REPO_URL="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main" ./sync-globals.sh

# De cópia local (sem internet)
./sync-globals.sh /path/to/template-fullstack
```

**3. O script mostra diff e pede confirmação:**
```
~~~ ALTERADO: claude-design.md           (+12 -3 linhas)
    sem alteração: claude-stacks.md
+++ NOVO: claude-debug.md
~~~ ALTERADO: .claude/agents/backend-developer.md  (+5 -1 linhas)
    sem alteração: .claude/agents/frontend-developer.md
    ...
  Aplicar alterações? (s/N)
```

**4. Confirme e commite:**
```bash
git add . && git commit -m "docs: sync from template"
```

> O sync **nunca** toca em: `CLAUDE.md`, `claude-sdd.md`, `claude-stacks-refactor.md`, `docs/`, `.claude/agent-memory/`.

---

## Guia 4 — Sincronização: Projetos → Template

> Quando: o Claude descobriu algo útil e marcou como candidato no `claude-stacks-refactor.md`.

**Como candidatos aparecem:** o Claude auto-atualiza `claude-stacks-refactor.md` durante o dev. Se o aprendizado é reutilizável, marca como `Pendente` na tabela de candidatos.

**Como você sabe:** o git hook avisa após cada commit:
```
>>> 2 candidato(s) pendente(s) de promocao no claude-stacks-refactor.md
    Rode: ./promote-learning.sh /path/to/template-fullstack
```

**1. Rode o promote no projeto:**
```bash
./promote-learning.sh /path/to/template-fullstack
```

**2. Para cada candidato, escolha:** `p` (promover) / `s` (pular) / `r` (rejeitar).

**3. Commite em ambos:**
```bash
# Projeto
git add claude-stacks-refactor.md && git commit -m "docs: review candidates"

# Template
cd /path/to/template-fullstack
git add . && git commit -m "docs: promote learnings from cotamar" && git push
```

**4. Propague** para outros projetos via `sync-globals.sh`.

### O ciclo completo

```
Claude descobre algo → auto-atualiza refactor.md → marca Pendente
  → hook avisa → promote-learning.sh → template atualizado
    → sync-globals.sh → todos os projetos atualizados
```

---

## Fluxos de desenvolvimento

> Diga ao Claude Code exatamente os comandos indicados. Ele orquestra o resto automaticamente.

---

### Novo projeto

**O que produz:** PRD + plano faseado + projeto rodando + features implementadas com testes.

```
1. /novo-prd
   → Claude entrevista você e gera plans/<projeto>.md
     (problema, usuários, fluxos, modelo de dados, API, MVP, fora de escopo)

2. /prd-planejamento
   → Claude analisa o PRD e gera plans/<projeto>-plano.md
     (Fase 0: fundação — banco + tipos + rotas vazias
      Fase 1+: features verticais completas, cada uma demonstrável)

3. Iniciar projeto novo
   → Claude faz o bootstrap (scaffold, deps, banco, app, CI/CD)

4. Implementar a Fase 0 do plano
   Implementar a Fase 1 do plano
   ...
   → Cada fase: spec técnico → testes → código → revisão → merge
```

---

### Nova feature (projeto existente)

**O que produz:** PRD da feature + plano faseado + feature implementada com testes e revisão.

```
1. /novo-prd
   → Claude entrevista você e gera plans/<feature>.md

2. /prd-planejamento
   → Claude gera plans/<feature>-plano.md com fases ordenadas

3. Implementar a Fase 0 do plano
   Implementar a Fase 1 do plano
   ...
   → Cada fase: spec técnico → micro-tasks → testes → revisão → merge

4. Finalizar branch
   → Claude sugere merge ou PR, atualiza o backlog
```

---

### Correção de bug

**O que produz:** bug corrigido com teste que previne regressão.

```
1. Corrigir [descrição do bug]
   → Claude investiga sistematicamente: reproduz, isola a causa, formula hipóteses

2. Claude escreve o teste que falha (reproduz o bug)
   → Você aprova

3. Claude implementa o fix mínimo para o teste passar
   → Sem alterar comportamento de outras áreas

4. Claude verifica: testes, lint, typecheck, cobertura
   → Apresenta resultado antes de commitar
```

---

### Refatoração de backend

**O que produz:** módulo refatorado com cobertura de testes mantida, sem funcionalidades novas.

```
1. Refatorar [módulo/camada] no backend
   → Claude confirma: sem contrato novo → decompõe em micro-tasks de refactor

2. Nenhuma task adiciona funcionalidade nova (YAGNI enforced)

3. Para cada task:
   Red: teste que cobre o comportamento atual
   Green: código refatorado
   → Comportamento externo não muda

4. Claude verifica: testes ≥ 80%, lint, typecheck
   → Finaliza branch
```

---

### Refatoração estrutural

**O que produz:** decisão arquitetural registrada + refactor executado em micro-tasks com testes.

```
1. Refatorar a estrutura de [módulo/sistema]
   → Claude explora alternativas com você antes de propor qualquer mudança

2. Claude apresenta 2–3 abordagens com trade-offs
   → Você escolhe

3. Decisão registrada em docs/ como ADR
   → Claude decompõe em micro-tasks

4. Para cada task:
   Red → Green → Refactor
   → Sem misturar refactor com novas funcionalidades

5. Claude verifica e finaliza branch
```

---

### Refatoração de frontend e UX/UI

**O que produz:** componentes/páginas refatorados com checklist visual completo (4 estados, responsivo, animações, acessibilidade).

```
1. Refatorar [componente/página] no frontend
   → Claude explora o design com você antes de qualquer mudança

2. Se houver mudança no design system:
   → Claude atualiza design-brief.md e/ou MASTER.md antes de implementar

3. Claude decompõe em micro-tasks de componentes
   → Cada componente tem 4 estados obrigatórios:
      default · hover/focus · loading · empty/error

4. Para cada componente:
   Teste → implementação → checklist visual
   → Cores, tipografia e espaçamentos do design brief (sem hardcode)

5. Claude verifica: testes, lint, typecheck, checklist visual completo
   → Finaliza branch
```

---

### Aprendizado contínuo

```
Claude descobre algo → auto-atualiza claude-stacks-refactor.md → marca Pendente
  → hook avisa → promote-learning.sh → template atualizado
    → sync-globals.sh → todos os projetos atualizados
```

---

## Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | — | Orquestração do workflow |
| [Bun](https://bun.sh) | ≥ 1.3 | Runtime, PM, test runner |
| [Docker](https://docker.com) + Compose | — | Dev environment |
| [Node](https://nodejs.org) | ≥ 20.19 ou ≥ 22.12 | Tooling (Vite 8, TypeScript) |
| [Python](https://python.org) | 3.x | ui-ux-pro-max scripts |
| Git | — | Versionamento + hooks |

### Plugins (instalar no Claude Code)

**Superpowers** — execução, TDD, code review, debugging:
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

**ui-ux-pro-max** — geração de design system:
```
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

Ou via CLI: `npm install -g uipro-cli && uipro init --ai claude`

### Personal skills de debugging

Instalar em `~/.claude/skills/`:
```bash
mkdir -p ~/.claude/skills/{hono-api-debugging,drizzle-database-debugging,react-tanstack-debugging,escalation-and-bug-journal}
# Copiar SKILL.md de cada skill para a pasta correspondente
```

---

## Referência rápida

### Claude Code

| Comando | O que faz |
|---|---|
| `/novo-prd` | Entrevista guiada → PRD em `plans/<feature>.md` |
| `/prd-planejamento` | PRD → plano faseado em `plans/<feature>-plano.md` |
| `Iniciar projeto novo` | Bootstrap completo (5 fases) |
| `Adotar workflow SDD/TDD neste projeto` | Retrofit em projeto existente |
| `Continuar o backlog` | Próxima task P1 pendente |
| `Continuar o backlog da US-03` | Próxima task da story |
| `Implementar a US-03` | Story completa: spec → plan → execute |
| `Executar a task 3.2 do backlog` | Task específica |
| `Corrigir o erro 500 ao criar evento` | Bug fix com debugging protocol |

### Terminal

| Comando | Onde | O que faz |
|---|---|---|
| `./adopt-workflow.sh /path/projeto` | Template | Adotar workflow: copia globais, agentes, cria agent-memory e docs/ |
| `cp sync-globals.sh promote-learning.sh /path/projeto` | Template | Copiar scripts de manutenção para o projeto |
| `./sync-globals.sh` | Projeto | Puxar globais + agentes do GitHub |
| `TEMPLATE_REPO_URL="..." ./sync-globals.sh` | Projeto | Puxar com URL customizada |
| `./sync-globals.sh /path/template` | Projeto | Puxar de cópia local |
| `./promote-learning.sh /path/template` | Projeto | Enviar aprendizados para o template |

---

## Licença

Uso interno.
