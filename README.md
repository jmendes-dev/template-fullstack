# template-fullstack

> Template de projeto fullstack com workflow SDD/TDD integrado ao Claude Code.
> Monorepo TypeScript · Bun · Hono · React 19 · Drizzle · PostgreSQL · Tailwind v4

---

## O que é

Este repositório template contém toda a estrutura de documentação e configuração do Claude Code para projetos fullstack. Inclui:

- **Orquestração** — `CLAUDE.md` como ponto de entrada + arquivos de SDD, subagentes, stack e design
- **Pipeline de requisitos** — `REQUIREMENTS.md` para levantamento com entrevista guiada
- **Pipeline de design** — `DESIGN_SYSTEM.md` com integração ui-ux-pro-max (3 passos)
- **Bootstrap** — `start_project.md` com 5 fases de setup do zero
- **Docs vivos** — estrutura `docs/` para user stories, backlog, specs e design system
- **Sincronização** — scripts para manter projetos atualizados e propagar aprendizados

---

## Estrutura do template

```
template-fullstack/
│
│  ── Orquestração (lidos pelo Claude Code) ──
├── CLAUDE.md                     ← Ponto de entrada. 9 prompts reconhecidos
├── claude-sdd.md                 ← Spec Driven Development: triage, specs
├── claude-subagents.md           ← Delegação: tipos, templates, budget por tipo
├── claude-stacks.md              ← Stack técnica: regras, padrões, anti-patterns
├── claude-stacks-refactor.md     ← Aprendizados (começa vazio, cresce com o projeto)
├── claude-design.md              ← Regras estruturais de UI/UX (reutilizáveis)
│
│  ── Pipelines de geração (prompts de entrevista) ──
├── REQUIREMENTS.md               ← Levanta requisitos → gera user-stories + backlog (Kanban P1/P2/P3)
├── DESIGN_SYSTEM.md              ← Gera design system → MASTER.md + design-brief.md
│
│  ── Bootstrap ──
├── start_project.md              ← 5 fases: planejamento → scaffold/config/docker → deps/banco → app → CI/CD
│
│  ── Docs vivos (específicos por projeto) ──
├── docs/
│   ├── user-stories.md           ← (gerado via REQUIREMENTS.md)
│   ├── backlog.md                ← (gerado via REQUIREMENTS.md, Kanban P1/P2/P3)
│   ├── specs/                    ← (specs gerados durante implementação via SDD)
│   └── design-system/
│       ├── MASTER.md             ← (gerado via DESIGN_SYSTEM.md — fonte de verdade visual)
│       ├── design-brief.md       ← (resumo ~800 tokens do MASTER.md para subagentes)
│       └── pages/                ← (overrides por página, gerados durante SDD)
│
│  ── Ferramentas ──
├── adopt-workflow.sh             ← Adotar workflow em projeto existente
├── sync-globals.sh               ← Template → projetos (distribuir atualizações)
├── promote-learning.sh           ← Projetos → template (coletar aprendizados)
│
│  ── Git ──
├── .githooks/
│   └── post-commit               ← Avisa sobre candidatos pendentes de promoção
├── .gitignore
└── README.md
```

---

## Arquivos: globais vs instanciados

| Tipo | Arquivos | Comportamento |
|---|---|---|
| **Global** | `claude-stacks.md`, `claude-design.md`, `claude-subagents.md`, `start_project.md`, `REQUIREMENTS.md`, `DESIGN_SYSTEM.md` | Reutilizáveis. Atualizados no template e propagados via `sync-globals.sh` |
| **Instanciado** | `CLAUDE.md`, `claude-sdd.md`, `claude-stacks-refactor.md`, tudo em `docs/` | Específicos de cada projeto. Evoluem independentemente. Nunca sobrescritos pelo sync |

### Onde cada ferramenta vive

| Arquivo | Template | Projetos |
|---|---|---|
| `adopt-workflow.sh` | ✅ | ❌ (roda uma vez, do template para o projeto) |
| `sync-globals.sh` | ✅ | ✅ (roda nos projetos para puxar atualizações) |
| `promote-learning.sh` | ✅ | ✅ (roda nos projetos para enviar aprendizados) |
| `.githooks/post-commit` | ✅ | ✅ (avisa sobre candidatos pendentes) |

---

## Guia 1 — Projeto novo (do zero)

### Passo 1: Criar o repositório

1. Acesse este template no GitHub
2. Clique em **"Use this template"** → **"Create a new repository"**
3. Nomeie o repositório e clone localmente:

```bash
git clone https://github.com/SEU_USUARIO/novo-projeto.git
cd novo-projeto
```

### Passo 2: Configurar

```bash
# Ativar o git hook
git config core.hooksPath .githooks

# Ajustar a URL do template no sync-globals.sh (linha 24)
# Abra o arquivo e substitua SEU_USUARIO pelo seu username:
# GITHUB_RAW_BASE="https://raw.githubusercontent.com/SEU_USUARIO/template-fullstack/main"
```

### Passo 3: Levantar requisitos

Abra o Claude (chat ou Claude Code) e cole o conteúdo do `REQUIREMENTS.md`. O Claude conduzirá uma entrevista e gerará:
- `docs/user-stories.md` — stories com critérios de aceite
- `docs/backlog.md` — backlog Kanban com prioridades P1/P2/P3

### Passo 4: Gerar o design system

**Pré-requisito**: ui-ux-pro-max instalado (ver seção Pré-requisitos).

Siga o pipeline de 3 passos do `DESIGN_SYSTEM.md`:

1. **ui-ux-pro-max gera a base:**
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py \
  "[indústria do projeto]" \
  --design-system --persist -p "[NomeDoProjeto]"
```

2. **Entrevista de refinamento:** Cole o prompt do `DESIGN_SYSTEM.md` no Claude. Ele lê a base gerada e faz ~5 perguntas para refinar.

3. **design-brief.md é gerado automaticamente** pelo Claude ao final da entrevista.

### Passo 5: Bootstrap do projeto

No Claude Code, digite:

```
Iniciar projeto novo
```

O Claude executará as 5 fases do `start_project.md`.

### Passo 6: Começar a implementar

```
Continuar o backlog
```

O Claude pega a próxima task P1 pendente e executa com SDD + TDD.

---

## Guia 2 — Projeto existente (retrofit)

### Passo 1: Rodar o script de adoção

No diretório do **template** (não do projeto):

```bash
cd /path/to/template-fullstack
./adopt-workflow.sh /path/to/seu-projeto-existente
```

O script:
- ✅ Copia os 6 arquivos globais
- ✅ Copia `CLAUDE.md` e `claude-sdd.md` (só se não existem)
- ✅ Cria `claude-stacks-refactor.md` vazio com estrutura de candidatos
- ✅ Cria `docs/` com templates vazios
- ✅ Instala `.githooks/post-commit` e configura `core.hooksPath`
- ⚠️ Se `CLAUDE.md` já existia, renomeia para `.bak`

### Passo 2: Copiar os scripts de sync para o projeto

```bash
cp /path/to/template-fullstack/sync-globals.sh /path/to/seu-projeto/
cp /path/to/template-fullstack/promote-learning.sh /path/to/seu-projeto/
```

### Passo 3: Ajustar o CLAUDE.md

Revise e ajuste ao projeto: naming de workspace, schemas existentes, etc.
Ou use o Claude Code:

```
Adotar workflow SDD/TDD neste projeto
```

### Passo 4: Gerar os docs vivos

- Rode `REQUIREMENTS.md` → gera stories + backlog
- Rode `DESIGN_SYSTEM.md` → gera MASTER.md + design-brief.md

### Passo 5: Commitar

```bash
cd /path/to/seu-projeto
git add .
git commit -m "docs: adopt SDD/TDD workflow"
```

---

## Guia 3 — Sincronização: Template → Projetos

> **Quando usar**: você atualizou um arquivo global no template e quer propagar para projetos existentes.

### Passo a passo

**1. Atualize o template e faça push:**

```bash
cd /path/to/template-fullstack
# Edite o arquivo global (ex: claude-design.md)
git add claude-design.md
git commit -m "docs(design): add new empty state pattern"
git push
```

**2. Em cada projeto, rode o sync:**

```bash
cd /path/to/cotamar

# Opção A — Baixar do GitHub
./sync-globals.sh

# Opção B — Copiar de cópia local
./sync-globals.sh /path/to/template-fullstack
```

**3. O script mostra o que mudou e pede confirmação:**

```
ℹ  Comparando com arquivos locais...

    sem alteração: claude-stacks.md
~~~ ALTERADO: claude-design.md  (+12 -3 linhas)
    sem alteração: claude-subagents.md
    sem alteração: start_project.md
    sem alteração: REQUIREMENTS.md
    sem alteração: DESIGN_SYSTEM.md

ℹ  1 arquivo(s) com alterações.

  Aplicar alterações? (s/N)
```

**4. Confirme e commite:**

```bash
git add claude-design.md
git commit -m "docs: sync global configs from template"
git push
```

**5. Repita para cada projeto:**

```bash
cd /path/to/freelancer-hunter && ./sync-globals.sh && git add . && git commit -m "docs: sync from template"
cd /path/to/showtech && ./sync-globals.sh && git add . && git commit -m "docs: sync from template"
```

### O que o sync NÃO toca

| Arquivo | Motivo |
|---|---|
| `CLAUDE.md` | Pode ter ajustes específicos do projeto |
| `claude-sdd.md` | Pode ter customizações |
| `claude-stacks-refactor.md` | Contém aprendizados do projeto |
| `docs/*` | Tudo específico do projeto |

---

## Guia 4 — Sincronização: Projetos → Template

> **Quando usar**: o Claude descobriu algo útil durante o desenvolvimento e marcou como
> "candidato a promoção". Você quer enviar esse aprendizado para o template.

### Como candidatos aparecem

Durante o desenvolvimento, o Claude auto-atualiza `claude-stacks-refactor.md`. Se o aprendizado é reutilizável, marca na tabela:

```markdown
## Candidatos a promoção

| Regra | Origem | Destino | Status |
|---|---|---|---|
| sValidator requer enctype multipart para file upload | US-08 | claude-stacks.md global | Pendente |
```

### Como você sabe que há candidatos

O git hook avisa automaticamente após cada commit:

```
>>> 2 candidato(s) pendente(s) de promocao no claude-stacks-refactor.md
    Rode: ./promote-learning.sh /path/to/template-fullstack
```

### Passo a passo

**1. No projeto com candidatos, rode o promote:**

```bash
cd /path/to/cotamar
./promote-learning.sh /path/to/template-fullstack
```

**2. Para cada candidato, escolha:**

```
[1/2] sValidator requer enctype multipart para file upload
  Origem:  US-08
  Destino: claude-stacks.md global

  p = Promover (adicionar ao template + marcar ✅)
  s = Pular (manter Pendente)
  r = Rejeitar (marcar ❌)

  Ação? (p/s/r)
```

**3. Commite em ambos:**

```bash
# No projeto
git add claude-stacks-refactor.md
git commit -m "docs: review promotion candidates"
git push

# No template
cd /path/to/template-fullstack
git diff  # revisar as adições
git add .
git commit -m "docs: promote learnings from cotamar"
git push
```

**4. Propague para outros projetos:**

```bash
cd /path/to/freelancer-hunter
./sync-globals.sh
git add . && git commit -m "docs: sync from template" && git push
```

### O ciclo completo

```
  1. Claude descobre algo útil durante dev
     └→ auto-atualiza claude-stacks-refactor.md
        └→ marca como Pendente na tabela de candidatos

  2. Git hook avisa após cada commit
     ">>> N candidato(s) pendente(s)"

  3. Você roda promote-learning.sh quando quiser
     └→ revisa cada candidato (promover / pular / rejeitar)
        └→ promovidos vão para os arquivos globais no template

  4. Você roda sync-globals.sh nos outros projetos
     └→ todos recebem os novos aprendizados
```

---

## Fluxo completo de um projeto

```
1. REQUISITOS         REQUIREMENTS.md → entrevista → user-stories.md + backlog.md (P1/P2/P3)

2. DESIGN             DESIGN_SYSTEM.md → ui-ux-pro-max → MASTER.md + design-brief.md

3. BOOTSTRAP          start_project.md → 5 fases → projeto rodando com CI verde

4. IMPLEMENTAÇÃO      CLAUDE.md orquestra:
                      ├── "Continuar o backlog" → próxima task P1
                      ├── story → spec → aprovação → decompose → tasks
                      ├── subagentes:
                      │     ├── schema-agent (≤1500 tokens)
                      │     ├── api-agent (≤1500 tokens)
                      │     └── component-agent (≤3500 tokens + design-brief.md)
                      ├── TDD: Red → Green → Refactor
                      └── validate + commit + atualizar backlog

5. APRENDIZADO        Auto-atualização contínua:
                      ├── claude-stacks-refactor.md (erros técnicos)
                      ├── claude-design.md / MASTER.md (padrões visuais)
                      └── candidatos a promoção → hook → promote → sync
```

---

## Pré-requisitos

| Ferramenta | Versão mínima | Para quê |
|---|---|---|
| Claude Code | — | Orquestração do workflow |
| Bun | ≥ 1.3 | Runtime, PM, test runner |
| Docker + Compose | — | Dev environment |
| Node | ≥ 20.19 ou ≥ 22.12 | Tooling (Vite 8, TypeScript) |
| Python | 3.x | ui-ux-pro-max scripts |
| Git | — | Versionamento + hooks |

### Instalar ui-ux-pro-max

```bash
# Via Claude Code Marketplace (2 comandos)
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill

# Ou via CLI (recomendado para múltiplos projetos)
npm install -g uipro-cli
uipro init --ai claude          # por projeto
uipro init --ai claude --global # global
```

---

## Referência rápida

### Claude Code

| Comando | O que faz |
|---|---|
| `Iniciar projeto novo` | Bootstrap completo (5 fases) |
| `Adotar workflow SDD/TDD neste projeto` | Retrofit em projeto existente |
| `Continuar o backlog` | Próxima task P1 pendente |
| `Continuar o backlog da US-03` | Próxima task da story |
| `Implementar a US-03` | Story completa: spec → implement |
| `Executar a task 3.2 do backlog` | Task específica |
| `Corrigir o erro 500 ao criar evento` | Bug fix com TDD |

### Terminal

| Comando | Onde rodar | O que faz |
|---|---|---|
| `./adopt-workflow.sh /path/projeto` | Template | Adotar workflow em projeto existente |
| `./sync-globals.sh` | Projeto | Puxar atualizações do template (GitHub) |
| `./sync-globals.sh /path/template` | Projeto | Puxar atualizações (local) |
| `./promote-learning.sh /path/template` | Projeto | Enviar aprendizados para o template |

---

## Licença

Uso interno.
