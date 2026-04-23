# Onda 3 — Backlog em Ondas · Design Spec

**Status:** aprovado pelo usuário em 2026-04-23 · pronto para `writing-plans`
**Escopo:** meta-template (arquivos em `template-fullstack`); impacto em projetos consumidores via `sync-globals.sh`
**Objetivo:** adicionar "waves" de entrega ao cliente final como agrupador de alto nível no backlog, mapeadas 1:1 com GitHub Milestones.

---

## 1. Problema

O formato atual de `docs/backlog.md` usa apenas priorização técnica P1/P2/P3, sem camada visível ao cliente final. Diagnóstico original (sessão 1 deste projeto):

> "Gostaria de ver todas as milestones no meu backlog e que ele fosse divido em ondas de entregas visíveis para o cliente final."

Causas raízes encontradas:
- Template do backlog não tem conceito de épico, release ou onda.
- `sync-github-issues.sh` mapeia prioridade para labels, mas não cria/usa milestones.
- `setup-github-project.sh` cria milestones pré-definidos ("Épico 1-6") desconectados do backlog.
- `/finish` e `/continue` não atualizam o backlog após conclusão de task → backlog fica dessincronizado da realidade.

## 2. Objetivos

1. Adicionar eixo **Wave** ao backlog — agrupador business-meaningful (MVP, Release 1, etc.) complementar ao P1/P2/P3 técnico.
2. Mapear cada Wave 1:1 para um **GitHub Milestone** (nome idêntico).
3. `setup-github-project.sh` cria milestones automaticamente a partir das waves detectadas no backlog.
4. `sync-github-issues.sh` associa cada issue à milestone correspondente à wave da US.
5. `/finish` atualiza o backlog (marca US/tasks como concluídos) + fecha a issue do GitHub.
6. Workflow fim-a-fim: o cliente olha o GitHub Milestones e vê progresso real (% concluído) por onda.

**Não-objetivo nesta onda:** sync bidirecional GitHub → backlog. Script de migração de backlogs legados (usuário usará só em projetos novos).

## 3. Decisões de design (consolidadas com usuário)

| Decisão | Escolha |
|---|---|
| Mapeamento Wave → GitHub | **Milestone** (Opção A no brainstorm) |
| Estilo visual | **Só texto** (sem emojis) |
| Script de migração | **Não incluir** (apenas projetos novos) |
| Marcação de conclusão | **Ambos** — `**Status:** concluída` humano-legível + tasks `[x]` máquina-legíveis |
| Sync direção | **One-way** (backlog → GitHub); bidirecional fora de escopo |
| Default wave | `Backlog` (para USs ainda não priorizadas em onda concreta) |

## 4. Formato do `docs/backlog.md` (novo template)

```markdown
# Backlog

> Waves = entregas visíveis ao cliente · P1/P2/P3 = ordem interna dentro da wave.
> Cada wave corresponde a um GitHub Milestone homônimo (ver `sync-github-issues.sh`).

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** — Crítico | Bloqueia outras stories ou é requisito da wave atual |
| **P2** — Importante | Agrega valor significativo, fazer após P1 dentro da mesma wave |
| **P3** — Desejável | Nice-to-have, fazer se sobrar capacidade na wave |

---

## Wave: MVP
> Milestone GitHub: `MVP` · Meta: primeira entrega viável ao cliente final

### US-1 — Autenticação de usuário
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente

Tasks:
- [ ] TASK-1.1: Schema users (Drizzle)
- [ ] TASK-1.2: Middleware requireRole
- [ ] TASK-1.3: Página de login

### US-2 — Dashboard principal
**Prioridade:** P1  ·  **Estimativa:** 8  ·  **Status:** em andamento

Tasks:
- [x] TASK-2.1: Layout sidebar + topbar
- [ ] TASK-2.2: KPIs cards

---

## Wave: Release 1
> Milestone GitHub: `Release 1` · Meta: funcionalidades complementares pós-MVP

### US-5 — Relatórios exportáveis
**Prioridade:** P2  ·  **Estimativa:** 5  ·  **Status:** pendente

Tasks:
- [ ] TASK-5.1: Gerador de PDF
- [ ] TASK-5.2: Endpoint de export

---

## Wave: Backlog
> Sem milestone atribuída. Mover para wave concreta ao priorizar.

### US-20 — Internacionalização
**Prioridade:** P3  ·  **Estimativa:** L  ·  **Status:** pendente

Tasks:
- [ ] TASK-20.1: Integrar react-i18next
```

**Regras do formato (normativas):**

1. Cada wave começa com heading nível-2: `## Wave: <Nome>` (sem emojis, espaço após `:`).
2. Linha seguinte: blockquote `> Milestone GitHub: \`<Nome>\` · Meta: <descrição curta>`. O nome da milestone é **igual** ao da wave (case-sensitive) — isso é o contrato com `sync-github-issues.sh`.
3. USs são headings nível-3: `### US-<N> — <título>`.
4. Metadata da US em uma linha: `**Prioridade:** P<1|2|3>  ·  **Estimativa:** <XS|S|M|L|XL|número>  ·  **Status:** <pendente|em andamento|concluída>`.
5. Tasks em checkboxes dentro de bloco `Tasks:\n- [ ]` ou `- [x]`.
6. Wave `Backlog` sempre existe como catch-all (USs sem wave específica).
7. Ordem recomendada (mas não obrigatória): waves mais urgentes primeiro (MVP → Release 1 → Backlog).

## 5. Componentes alterados

### 5.1 `docs/backlog.md` (template raiz)

Reescrever o conteúdo atual (placeholder gerado por `/new-project`) para refletir o novo formato. Template fica com uma wave default `Backlog` + legenda atualizada. O comentário `<!-- Executar /new-project para gerar o backlog via entrevista guiada -->` permanece.

### 5.2 `.claude/skills/prd-planejamento/SKILL.md`

Adicionar passo entre "Análise do PRD" e "Geração de USs":

> **Passo X — Definir Waves de entrega**
>
> Antes de gerar as USs, perguntar ao usuário (1 pergunta):
>
> > Quais são as waves de entrega deste projeto? (Cada wave é uma entrega visível ao cliente final.)
> > Exemplos: "MVP", "Release 1", "Release 2" · ou nomes semânticos: "Autenticação", "Relatórios".
> > Pode deixar USs não priorizadas em "Backlog".
>
> Gerar backlog atribuindo cada US à wave correspondente. Default: `Backlog` quando o usuário não especifica.

### 5.3 `sync-github-issues.sh`

Parser atual extrai `**Milestone:**` de cada US. Substituir por:

1. Detectar heading `## Wave: <Nome>` — esse nome vira a milestone ativa para todas as USs subsequentes até o próximo `## Wave:` ou fim do arquivo.
2. Se a US tem `**Milestone:**` explícito (formato antigo), usar esse valor (back-compat).
3. Wave `Backlog` → issue criada **sem** `--milestone` (backlog puro).
4. Adicionar campo `wave` ao fingerprint cache (`.github/sync-state.txt`) para detectar mudança de onda (re-associar issue à milestone nova).

### 5.4 `setup-github-project.sh`

Após criar o GitHub Project e labels padrão, adicionar passo:

1. Parser do backlog: extrair lista única de waves (excluir `Backlog`).
2. Para cada wave: verificar se milestone homônima existe no repo (`gh api /repos/:owner/:repo/milestones`).
3. Criar milestones faltantes (`gh api /repos/:owner/:repo/milestones -X POST -f title="<Nome>" -f description="<Meta>"`).
4. Idempotente: re-rodar é seguro.

### 5.5 `.claude/commands/finish.md`

O comando atual invoca `superpowers:finishing-a-development-branch`. Adicionar passo final PM-driven:

> **Passo N — Atualizar backlog + fechar issue**
>
> Despachar `project-manager` via Agent tool. Prompt:
> > Para a US `<ID>` recém-finalizada:
> > (a) No `docs/backlog.md`: marcar `**Status:** concluída` e todas as tasks pendentes como `[x]`.
> > (b) Commitar mudança com mensagem `docs(backlog): US-<ID> concluída`.
> > (c) Rodar `./sync-github-issues.sh` para propagar — vai fechar a issue automaticamente (fingerprint detecta `status=concluída`).
> > (d) Confirmar no terminal que `gh issue view <N>` retorna `state: closed`.
> > Reportar `STATUS: DONE` com confirmação de (a)–(d).

### 5.6 `.claude/commands/continue.md` — Passo 0 (PM refresh)

Já existe desde a Onda 1. Agora o prompt do `project-manager` ganha contexto de wave:

> Refresh do backlog... (c) identificar a próxima P1 pronta — **priorizar USs da wave ativa mais próxima de entrega** (primeira wave com USs incompletas, excluindo `Backlog`). Se toda a wave ativa está completa, informar e perguntar se deve iniciar a próxima wave.

## 6. Fluxo end-to-end

```
┌─────────────────┐
│  /new-project   │
└────────┬────────┘
         ▼
   novo-prd (PRD)
         ▼
   prd-planejamento
   "Quais waves?" → gera backlog com Wave: MVP / Release 1 / Backlog
         ▼
   setup-github-project.sh
   → cria milestones MVP, Release 1 (skip Backlog)
         ▼
   sync-github-issues.sh
   → para cada US em Wave: X, cria issue com --milestone X
         ▼
   /continue → /feature → /finish
                              ▼
                   PM marca US status=concluída
                   PM roda sync-github-issues.sh
                   → issue fecha automaticamente
                              ▼
         GitHub Milestone mostra X% concluído ao cliente final
```

## 7. Testes

### 7.1 Parser de waves (`sync-github-issues.sh`)

Fixture: backlog com:
- Wave `MVP` com 2 USs (uma P1, uma P2)
- Wave `Release 1` com 1 US (P1)
- Wave `Backlog` com 1 US (P3)
- 1 US antes de qualquer wave (formato antigo, sem wave heading)

**Esperado em `--dry-run`:**
- 2 issues em milestone `MVP`
- 1 issue em milestone `Release 1`
- 1 issue **sem** milestone (Wave `Backlog`)
- 1 issue **sem** milestone (US pré-wave, sem heading — default para `Backlog`)

### 7.2 Criação idempotente de milestones (`setup-github-project.sh`)

- Primeiro run em repo vazio: cria milestones `MVP` e `Release 1`.
- Segundo run sem mudanças no backlog: reporta "sem mudanças" (idempotente).
- Adicionar wave `Release 2` ao backlog e re-rodar: cria apenas `Release 2` (mantém as existentes).

### 7.3 Status transitions em `/finish`

- US `US-1` passa de `em andamento` → `concluída` via `/finish`.
- `git log --oneline -1` mostra `docs(backlog): US-1 concluída`.
- Issue correspondente no GitHub: state=closed após sync.
- Milestone da wave mostra a contagem de concluídas += 1.

### 7.4 Back-compat

Backlog sem waves (formato antigo) → `sync-github-issues.sh` **não falha**. USs são criadas sem milestone. Mensagem informativa: `ℹ formato antigo (sem waves) — issues criadas sem milestone. Adicionar "## Wave: <Nome>" headings para agrupar em milestones.`

## 8. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Parser novo quebra backlogs antigos | Fallback para formato antigo se nenhum `## Wave:` heading encontrado |
| Usuário cria wave com nome conflitante (ex: duas "MVP" maiúscula/minúscula) | `setup-github-project.sh` faz case-insensitive check; warn + usa existente |
| Wave renomeada depois que issues foram criadas | Fingerprint detecta mudança; issue é re-associada à nova milestone (ou warn se milestone nova não existe) |
| Milestone com accentos ou caracteres especiais | gh API aceita; testar com fixture contendo "Lançamento 1.0" |
| `/finish` falha ao rodar sync-github-issues.sh (rede/auth) | PM reporta `DONE_WITH_CONCERNS` + instrui rodar manualmente |

## 9. Fora de escopo desta onda

- **Script de migração** de backlogs legados (decisão: só projetos novos).
- **Sync bidirecional** GitHub → backlog.
- **Drag-and-drop visual** em GitHub Project board (milestones já são visíveis nativamente).
- **Reordenar waves** automaticamente por urgência (humano decide a ordem).
- **Sub-waves ou wave hierárquica** (YAGNI — se precisar, adicionar em futura onda).

## 10. Arquivos afetados (resumo)

| Arquivo | Tipo de mudança | Responsabilidade pós-onda |
|---|---|---|
| `docs/backlog.md` (template raiz) | reescrita | Placeholder com formato de waves |
| `.claude/skills/prd-planejamento/SKILL.md` | adição de passo | Pergunta "quais waves?" no fluxo de PRD |
| `sync-github-issues.sh` | parser + mapping | Detecta waves, cria issues com milestone |
| `setup-github-project.sh` | criação de milestones | Gera milestones a partir do backlog |
| `.claude/commands/finish.md` | passo PM final | Atualiza backlog + fecha issue |
| `.claude/commands/continue.md` | refinamento do prompt PM | Prioriza USs da wave ativa |
| `claude-stacks.md` | doc update | Referência ao formato de waves no backlog |
| `CLAUDE.md` | doc update | Seção SCRIPTS explica o fluxo wave → milestone |

## 11. Pré-requisitos para execução

- `gh` CLI autenticado (já exigido pelos scripts atuais)
- `jq` disponível (já usado pelos hooks e scripts)
- Ondas 1 e 2 mergeadas (já atendido)

## 12. Critérios de aceite

- [ ] Em projeto novo, `/new-project` gera backlog com pelo menos 2 waves concretas (além de `Backlog`)
- [ ] `setup-github-project.sh` cria milestones correspondentes no GitHub (verificável via `gh api /repos/:owner/:repo/milestones`)
- [ ] `sync-github-issues.sh` cria issues associadas às milestones certas (verificável em `gh issue list --milestone "MVP"`)
- [ ] `/finish` de uma US marca status=concluída no backlog E fecha issue no GitHub
- [ ] Cliente final navegando em `github.com/<owner>/<repo>/milestones` vê barras de progresso coerentes com o estado real
- [ ] Back-compat: um projeto consumidor com backlog no formato antigo pode rodar `sync-github-issues.sh` sem erro (issues criadas sem milestone + warn informativo)
- [ ] Zero breaking change em `/continue` — Passo 0 e Passo 2 (da Onda 1) continuam funcionando

---

## Self-review (checklist aplicado antes de handoff)

- **Placeholders**: nenhum "TBD"/"TODO" deixado.
- **Consistência interna**: formato de backlog da seção 4 coerente com regras da seção 4, componentes da seção 5 e fluxo da seção 6.
- **Scope check**: single-onda, focado, não precisa decompor. 7 arquivos alterados + 1 template reescrito.
- **Ambiguidades resolvidas**: nome de milestone = nome de wave (case-sensitive), blockquote `> Milestone GitHub:` é o delimitador canônico (não ambíguo com P1/P2/P3 que ficam no metadata da US).
