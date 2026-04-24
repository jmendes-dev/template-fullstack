# Onda 4 — Memória que aprende · Design Spec

**Status:** aprovado pelo usuário em 2026-04-24 (decisões A/A/A) · pronto para `writing-plans`
**Escopo:** meta-template — impacto em projetos consumidores via `./adopt-workflow.sh` e `./check-health.sh`
**Objetivo:** `adopt-workflow.sh` passa a popular MEMORY.md de cada agente com contexto real do projeto + seeds de domínio (eliminando arquivos vazios); `check-health.sh` ganha seção de densidade de memória por agente.

---

## 1. Problema

Diagnóstico da sessão 1 confirmou: `adopt-workflow.sh:168-180` cria `MEMORY.md` com 3-4 linhas de boilerplate. Apenas 2 de 10 agentes no template têm conteúdo real (backend-dev e devops-sre, por uso frequente acidental). Os outros 8 nascem "do zero" em cada projeto novo.

Consequência prática: agentes especializados (QA, Security, Data, etc) **não herdam contexto do stack/arquitetura do projeto** nem **padrões de domínio obrigatórios** — precisam re-descobrir a cada invocação lendo `claude-stacks.md` inteiro. Ineficiente e inconsistente.

## 2. Objetivos

1. `adopt-workflow.sh` detecta contexto do projeto e popula `MEMORY.md` de cada agente com:
   - **Project Context** (comum): stack, workspace, portas, env vars chave
   - **Agent-specific seeds**: 1-3 padrões mandatórios extraídos do domínio do agente
2. `check-health.sh` reporta **densidade de memória por agente** (tabela com barra visual).
3. Idempotente: re-rodar adopt-workflow **não sobrescreve** MEMORY.md com conteúdo real (>10 linhas não-boilerplate).
4. Detecta e substitui **boilerplate legacy** (formato antigo "Index" vazio) — força upgrade sem flag especial.

**Não-objetivo:** alterar prompts dos agentes (Decisão 3 = A). Alterar `MEMORY.md` do próprio template-fullstack repo (fora de escopo — são legacy com conteúdo útil em backend/devops, preservar).

## 3. Decisões de design

| # | Decisão | Escolha |
|---|---|---|
| 1 | População | **(A)** Duas seções — Project Context (comum) + Agent-specific seeds |
| 2 | check-health formato | **(A)** Tabela com barra visual |
| 3 | Agent prompts | **(A)** Não alterar (frontmatter `memory: project` já carrega automaticamente) |
| 4 | Idempotência | Preservar se >10 linhas não-boilerplate; substituir se detectar boilerplate legacy |
| 5 | Project Context inline | Sim (duplicação aceita) — `memory: project` do Claude Code carrega só o MEMORY.md, sem seguir links |
| 6 | Agent-specific seeds | Hardcoded em adopt-workflow (por agente, 1-3 linhas cada) — extraídos de claude-stacks.md |

## 4. Detecção de contexto (inputs)

`adopt-workflow.sh` detecta no `$TARGET_DIR`:

| Campo | Fonte (em ordem) | Fallback |
|---|---|---|
| `PROJECT_NAME` | `package.json` → `.name` | basename do `$TARGET_DIR` |
| `STACK_SUMMARY` | `claude-stacks.md` → linha "Stack" (primeira ocorrência) | "Stack não detectada" |
| `WORKSPACE_LAYOUT` | detectar `apps/api`, `apps/web`, `packages/shared` | "monorepo não inicializado" |
| `API_PORT` | `.env.example` → `PORT=` ou `API_PORT=` | "3000" |
| `WEB_PORT` | `.env.example` → `WEB_PORT=` | "5173" |
| `DB_URL_PATTERN` | `.env.example` → `DATABASE_URL=` (só a linha inteira) | "postgres://… (não configurada)" |
| `ADMIN_EMAIL` | `.env.example` → `ADMIN_EMAIL=` (só a linha) | "ADMIN_EMAIL não configurada — ver docs/auth-rbac.md" |

Detecção é best-effort e silenciosa. Campos ausentes → fallback documentado no próprio MEMORY.md.

## 5. Formato do MEMORY.md novo

```markdown
# MEMORY.md — <agente>

> Memória persistente do agente. Carregada automaticamente via frontmatter `memory: project`.
> Gerada inicialmente por `./adopt-workflow.sh` em <data>. Atualizada pelo próprio agente durante sessões.

---

## Project Context (comum)

**Projeto:** <PROJECT_NAME>
**Stack:** <STACK_SUMMARY>
**Workspace:** <WORKSPACE_LAYOUT>

**Portas:**
- API: <API_PORT>
- Web: <WEB_PORT>

**Env vars chave:**
- `<DB_URL_PATTERN>`
- `<ADMIN_EMAIL>`

> ℹ️ Se a stack ou estrutura mudou substancialmente, rodar `./adopt-workflow.sh --refresh-memory` para regenerar esta seção (preserva seeds custom).

---

## Agent-specific notes (seeds)

<seeds do agente — 1-3 bullets específicos do domínio>

<!-- Abaixo deste comentário, o agente adiciona suas próprias notas durante o trabalho -->

---

## Como Capturar Memória (Session Retrospective)

**Quando:** Padrão novo, bug resolvido >15min, decisão arquitetural, anti-pattern encontrado.

**Como:**
1. Criar arquivo `feedback_<topico>.md` neste diretório com frontmatter (`type: feedback`, `description: <1 linha>`)
2. Adicionar bullet em "Agent-specific notes" acima linkando para o arquivo

**Promover entre projetos:** marcar em `claude-stacks-refactor.md` como `⏳ Pendente` e rodar `./promote-learning.sh` no fim do ciclo.
```

## 6. Seeds por agente (hardcoded em adopt-workflow)

| Agente | Seeds (1-3 bullets) |
|---|---|
| `backend-developer` | Rotas em `apps/api/src/routes/<kebab-case>.ts` · Schemas em `packages/shared/src/schemas/` · `getAuth(c)` síncrono, nunca reimplementar JWT |
| `frontend-developer` | Ler `docs/design-system/design-brief.md` antes de implementar componente · 4 estados obrigatórios (loading/empty/error/success) · Data fetching em custom hooks, nunca em componentes |
| `data-engineer-dba` | Schemas Drizzle+Zod em `packages/shared/src/schemas/` (fonte única) · Migrations via `bun run db:generate && bun run db:migrate` · Cascade FK documentada no schema |
| `devops-sre-engineer` | Dockerfile sempre multi-stage + non-root · Base: `oven/bun:1.3` (nunca `:latest`) · docker-compose.dev.yml usa polling (CHOKIDAR_USEPOLLING) |
| `qa-engineer` | Cobertura mínima 95% em business code · Cenários de spec mapeados via `it('Cenário X.Y: ...')` · Test runner único: `bun test` |
| `project-manager` | Backlog em `docs/backlog.md` usa waves (`## Wave: <Nome>`) · P1/P2/P3 = ordem INTERNA da wave · `/finish` Passo 4 fecha issue + atualiza backlog |
| `requirements-roadmap-builder` | PRDs em `plans/<feature>.md` · Planos em `plans/<feature>-plano.md` · Cada Fase do plano vira Wave no backlog (via PM agent) |
| `security-engineer` | OWASP Top 10 + validação Zod em toda rota · RBAC: Clerk identity + tabela custom · `ADMIN_EMAIL` bootstrap (ver `docs/auth-rbac.md`) |
| `software-architect` | ADRs em `docs/adr/` · Monorepo `apps/` + `packages/shared/` · Decisões estruturais antes de código |
| `ux-ui-designer` | `docs/design-system/MASTER.md` é fonte de verdade visual · `design-brief.md` é resumo (~800 tokens) para subagentes · Sempre consultar `DESIGN.md` Parte 1 (estrutural) + MASTER.md (visual) |

## 7. Lógica de idempotência

```
para cada agente:
  memory_file = .claude/agent-memory/<agente>/MEMORY.md

  se NÃO existe:
    gerar novo formato (Project Context + seeds + guia)
  se existe E conteúdo > 10 linhas não-boilerplate:
    preservar (usuário customizou)
  se existe E conteúdo detectado como boilerplate legacy:
    (regex: só o cabeçalho "# MEMORY.md — <agente>" + "## Índice" + comentário)
    sobrescrever com novo formato
  se existe E boilerplate intermediário (formato "Agent Memory Index" antigo):
    idem — sobrescrever
```

Regex para detectar boilerplate legacy: MEMORY.md tem ≤ 10 linhas não-comentário E não contém `## Project Context` (marcador do formato novo). Simples e robusto.

Flag opcional `--force-memory`: sobrescreve sempre (não incluir na Onda 4 — YAGNI, adicionar se demanda aparecer).

## 8. Formato do report de densidade (check-health.sh)

```
🧠 Memória dos Agentes (densidade)

  backend-developer            : ██████████ 45L · 3 tópicos · atualizado 2d
  frontend-developer           : ██████░░░░ 28L · 1 tópico  · atualizado 7d
  data-engineer-dba            : ██░░░░░░░░ 12L · 0 tópicos · atualizado 30d+
  devops-sre-engineer          : █████████░ 42L · 2 tópicos · atualizado 1d
  project-manager              : ██░░░░░░░░ 10L · 0 tópicos · boilerplate
  qa-engineer                  : ██░░░░░░░░ 12L · 0 tópicos · atualizado 15d
  requirements-roadmap-builder : ██░░░░░░░░ 11L · 0 tópicos · atualizado 30d+
  security-engineer            : ██░░░░░░░░ 10L · 0 tópicos · boilerplate
  software-architect           : ██░░░░░░░░ 12L · 0 tópicos · atualizado 20d
  ux-ui-designer               : ██░░░░░░░░ 11L · 0 tópicos · boilerplate
  ────────────────────────────────────────────────────────────────────
  Média: 19L/agente · 3 agente(s) com boilerplate · 4 agente(s) sem tópicos
```

**Cálculos:**
- `<L>` linhas: `wc -l < MEMORY.md` (total)
- `<X> tópicos`: count de arquivos `*.md` no diretório do agente EXCLUINDO `MEMORY.md`
- `<atualizado Xd>`: `stat -c %Y` + delta de `date +%s`, convertido em dias; `30d+` se >30
- `boilerplate`: detecção conforme §7 (≤10L não-comentário E ausência de `## Project Context`)
- Barra: escala de 0 a max(linhas) entre os 10 agentes, 10 caracteres `█`/`░`
- Média: `total_lines / 10`

## 9. Testes

### 9.1 Fixture de bootstrap

Criar diretório temp sem `.claude/agent-memory/`:
```bash
TEMP=$(mktemp -d)
echo 'Stack: Bun + Hono + React 19' > "$TEMP/claude-stacks.md"
echo 'PORT=3001' > "$TEMP/.env.example"
echo 'WEB_PORT=5174' >> "$TEMP/.env.example"

./adopt-workflow.sh "$TEMP" --dry-run  # primeiro: dry-run OK
./adopt-workflow.sh "$TEMP"            # aplicar

# Validar que cada MEMORY.md tem:
for agent in backend-developer frontend-developer qa-engineer security-engineer; do
  grep -q "## Project Context" "$TEMP/.claude/agent-memory/$agent/MEMORY.md" || echo "FAIL: $agent sem Project Context"
  grep -q "Agent-specific notes" "$TEMP/.claude/agent-memory/$agent/MEMORY.md" || echo "FAIL: $agent sem seeds"
done

rm -rf "$TEMP"
```

Expected: cada arquivo contém as 3 seções e valores detectados (Stack: Bun + Hono... PORT 3001...).

### 9.2 Idempotência

Rodar adopt-workflow **duas vezes** no mesmo target:
- 1ª vez: cria MEMORY.md novos
- 2ª vez: preserva (não regenera)

Verificar via `git diff` ou `stat -c %Y` — timestamp do MEMORY.md não muda entre runs.

### 9.3 Detecção de boilerplate legacy

Criar um MEMORY.md no formato antigo (4 linhas, sem Project Context) e rodar adopt — deve substituir.

### 9.4 Density report

Rodar `./check-health.sh` no template repo (que tem mix de MEMORY.md ricos e vazios) — deve imprimir a tabela com barras proporcionais e contagem correta de boilerplate.

## 10. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Usuário perde conteúdo custom em MEMORY.md | Idempotência: só sobrescreve se detectar boilerplate; flag --force fica fora desta onda |
| Seeds desatualizam (stack evolui) | Usuário roda `adopt-workflow` de novo; seção "Project Context" é regenerável sem perder seeds custom (nota inline instrui) |
| Detecção regex frágil | Heurística é conservadora (≤10L + ausência de marcador) — em dúvida, preserva |
| Quebra testes em projetos consumidores | Escopo do adopt é só `.claude/agent-memory/`; não toca em apps/, tests, etc. Zero impacto no código |
| Tamanho do MEMORY.md > 200 linhas ao longo do tempo | Frontmatter avisa "lines after 200 will be truncated"; agentes já sabem splitar em `feedback_*.md` |

## 11. Fora de escopo

- Hook que auto-injeta `project-context.md` compartilhado (duplicação inline é OK por simplicidade)
- Alterar MEMORY.md do próprio template-fullstack repo
- Flag `--force-memory` (YAGNI)
- Sync automático de seeds quando `claude-stacks.md` muda (manual via re-run)

## 12. Arquivos afetados

| Arquivo | Mudança |
|---|---|
| `adopt-workflow.sh` | Novas funções `_detect_project_context()` e `_generate_memory_file()`; substitui bloco atual `cat > MEMORY.md` |
| `check-health.sh` | Nova função `_report_memory_density()` + invocação na seção existente "🧠 Memória dos Agentes" |
| `docs/superpowers/specs/2026-04-24-onda-4-memoria-design.md` | este documento |
| `docs/superpowers/plans/2026-04-24-onda-4-memoria.md` | plano (será gerado após aprovação deste spec) |

## 13. Critérios de aceite

- [ ] Em projeto novo, `./adopt-workflow.sh` gera 10 MEMORY.md com Project Context + seeds
- [ ] Stack e portas detectadas refletidas no Project Context de cada agente
- [ ] Rodar adopt 2× no mesmo projeto não destrói conteúdo (preserva se >10 linhas não-boilerplate)
- [ ] MEMORY.md com boilerplate legacy (formato antigo "Index") é substituído automaticamente
- [ ] `./check-health.sh` imprime tabela de densidade com barras proporcionais + contagem de boilerplate
- [ ] Todos os 10 agentes cobertos (seeds definidos)
- [ ] Nenhuma quebra em projetos consumidores (só adição em `.claude/agent-memory/`)

---

## Self-review

- **Placeholders**: nenhum TBD/TODO.
- **Consistência**: seeds da §6 coerentes com `.claude/agents/<nome>.md` e `claude-stacks.md`. `## Project Context` e `Agent-specific notes` grafias consistentes em §5 e §7.
- **Scope**: single-onda, 2 arquivos principais tocados. Cabe em 1 plan.
- **Ambiguidades**: lógica de idempotência (§7) explicita os 4 cases; regex de boilerplate documentada.
