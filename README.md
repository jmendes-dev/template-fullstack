# template-fullstack

> Template de projeto fullstack com workflow SDD/TDD integrado ao Claude Code.
> Monorepo TypeScript · Bun · Hono · React 19 · Drizzle · PostgreSQL · Tailwind v4

---

## O que é

Este repositório template contém toda a estrutura de documentação e configuração do Claude Code para projetos fullstack. Inclui:

- **Orquestração** — `CLAUDE.md` como ponto de entrada + arquivos de SDD, subagentes, stack e design
- **Pipeline de requisitos** — `REQUIREMENTS.md` para levantamento com entrevista guiada
- **Pipeline de design** — `DESIGN_SYSTEM.md` com integração ui-ux-pro-max
- **Bootstrap** — `start_project.md` com fases de setup do zero
- **Docs vivos** — estrutura `docs/` para user stories, backlog, specs e design system

---

## Como usar

### Projeto novo (do zero)

1. Clique em **"Use this template"** no GitHub para criar um novo repositório
2. Clone o repositório criado
3. Renomeie referências de `@projeto/` para o nome do seu projeto em todos os `package.json`
4. Abra o Claude Code e diga: `Iniciar projeto novo`
5. O Claude lerá o `start_project.md` e guiará o bootstrap completo

### Projeto existente (retrofit)

1. Clone este template em um diretório temporário
2. Execute o script de adoção apontando para o seu projeto:

```bash
./adopt-workflow.sh /path/to/your/project
```

3. Abra o Claude Code no seu projeto e diga: `Adotar workflow SDD/TDD neste projeto`
4. O Claude detectará a estrutura existente e adaptará os arquivos

---

## Estrutura do template

```
template-fullstack/
│
│  ── Orquestração (auto-carregados pelo Claude Code) ──
├── CLAUDE.md                     ← Ponto de entrada. Orquestra todos os outros arquivos
├── claude-sdd.md                 ← Spec Driven Development: triage, geração de specs
├── claude-subagents.md           ← Delegação para subagentes: tipos, templates, budget
├── claude-stacks.md              ← Stack técnica: regras, padrões, anti-patterns
├── claude-stacks-refactor.md     ← Aprendizados e extensões (começa vazio, cresce com o projeto)
├── claude-design.md              ← Regras estruturais de UI/UX reutilizáveis entre projetos
│
│  ── Pipelines de geração (prompts para entrevista) ──
├── REQUIREMENTS.md               ← Prompt para levantar requisitos → gera user-stories + backlog
├── DESIGN_SYSTEM.md              ← Prompt para gerar design system → gera MASTER.md + brief
│
│  ── Bootstrap ──
├── start_project.md              ← Fases de setup do zero (scaffold, config, Docker, deps, CI)
│
│  ── Docs vivos (específicos por projeto) ──
├── docs/
│   ├── user-stories.md           ← Template vazio (gerado via REQUIREMENTS.md)
│   ├── backlog.md                ← Template vazio (gerado via REQUIREMENTS.md)
│   ├── specs/                    ← Vazio (specs gerados durante implementação via SDD)
│   │   └── .gitkeep
│   └── design-system/            ← Design system do projeto
│       ├── MASTER.md             ← Template vazio (gerado via DESIGN_SYSTEM.md)
│       ├── design-brief.md       ← Template vazio (gerado a partir do MASTER.md)
│       └── pages/                ← Overrides por página (gerados durante SDD)
│           └── .gitkeep
│
│  ── Ferramentas ──
├── adopt-workflow.sh             ← Script para retrofit em projetos existentes
│
│  ── Repo config ──
├── README.md                     ← Este arquivo
└── .gitignore
```

---

## Arquivos: globais vs instanciados

| Tipo | Arquivos | Comportamento |
|---|---|---|
| **Global** (fonte de verdade) | `claude-stacks.md`, `claude-design.md`, `claude-subagents.md`, `start_project.md`, `REQUIREMENTS.md`, `DESIGN_SYSTEM.md` | Reutilizáveis entre projetos. Quando atualizados aqui, projetos existentes podem puxar a versão nova |
| **Instanciado** (por projeto) | `CLAUDE.md`, `claude-sdd.md`, `claude-stacks-refactor.md`, `docs/*` | Específicos de cada projeto. Evoluem independentemente |

### Sincronizando projetos existentes

Quando os arquivos globais são atualizados neste template:

```bash
# No seu projeto existente, puxar apenas os globais atualizados
cd /path/to/your/project
curl -sL https://raw.githubusercontent.com/SEU_USER/template-fullstack/main/claude-stacks.md -o claude-stacks.md
curl -sL https://raw.githubusercontent.com/SEU_USER/template-fullstack/main/claude-design.md -o claude-design.md
# ... repetir para cada global que mudou
git add . && git commit -m "docs: sync global configs from template"
```

> **Dica**: criar um script `sync-globals.sh` no template que automatize isso.

---

## Fluxo completo de um projeto

```
1. REQUISITOS         REQUIREMENTS.md → entrevista → user-stories.md + backlog.md
                                                          │
2. DESIGN             DESIGN_SYSTEM.md → ui-ux-pro-max → MASTER.md + design-brief.md
                                                          │
3. BOOTSTRAP          start_project.md → 5 fases → projeto rodando com CI verde
                                                          │
4. IMPLEMENTAÇÃO      CLAUDE.md orquestra: story → spec → decompose → subagentes → TDD → commit
                           │                                    │
                           ├── claude-sdd.md (specs)            ├── claude-subagents.md (delegação)
                           ├── claude-stacks.md (regras)        ├── claude-design.md (UI patterns)
                           └── claude-stacks-refactor.md        └── design-brief.md (tokens visuais)
                               (aprendizados contínuos)
```

---

## Pré-requisitos

- **Claude Code** instalado e configurado
- **Bun** ≥ 1.3
- **Docker** + Docker Compose
- **Python 3.x** (para ui-ux-pro-max)
- **Node** ≥ 20.19 ou ≥ 22.12 (para tooling)
- **ui-ux-pro-max** instalado no Claude Code (ver `DESIGN_SYSTEM.md` para instruções)

---

## Licença

Uso interno.
