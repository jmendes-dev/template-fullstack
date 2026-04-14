# claude-debug.md — Protocolo de Debugging

> **Este arquivo orquestra o debugging integrando Superpowers (plugin) com o workflow SDD/TDD do projeto.**
>
> **Superpowers** fornece: metodologia de debugging sistemático (4 fases), root cause tracing, hard gates, TDD enforcement.
> **Personal skills** fornecem: diagnóstico rápido por stack (Hono, Drizzle, React, TanStack).
> **Este arquivo** fornece: escalação, bug journal, integração com spec/backlog/design, e regras do projeto.
>
> **Quando ler**: ao receber prompt de bug fix, troubleshooting, ou quando o ciclo TDD falhar após 2 tentativas.
>
> **Hierarquia**: `CLAUDE.md` > `claude-debug.md` > `claude-stacks.md`

---

## Bugs pré-existentes — Política obrigatória

Quando `bun test`, `bunx biome check`, ou `tsc` encontrar erros que **não foram causados pela task atual**:

### Decisão obrigatória (não é opcional)

```
Bug pré-existente encontrado
│
├── Escopo pequeno (≤ 30 min para corrigir)?
│     └── ✅ CORRIGIR AGORA, antes de continuar a task atual
│           Commit separado: "fix: corrigir [descrição] pré-existente"
│
└── Escopo grande (> 30 min)?
      └── ✅ PARAR task atual → criar item P1 no backlog → corrigir ANTES de qualquer nova feature
            Nunca desenvolver nova funcionalidade sobre baseline quebrada
```

### O que NUNCA fazer

- ❌ **Nunca classificar como "pré-existente" e continuar** — isso cria bola de neve de débito técnico
- ❌ **Nunca usar `git stash` para "verificar se era pré-existente" e depois ignorar** — se existe, é bug
- ❌ **Nunca mencionar bugs pré-existentes em relatório sem resolver ou criar P1** — citar não é resolver

### Por que esta regra existe

Toda feature nova desenvolvida sobre um baseline com bugs:
1. Mascara causa raiz dos bugs originais
2. Adiciona complexidade que dificulta o fix posterior
3. Pode fazer testes novos passarem por razões erradas (falsos verdes)
4. Transforma bugs pontuais em problemas sistêmicos

**Baseline verde é pré-condição para qualquer desenvolvimento**, não um bônus.

---

## Regra Zero — Checkpoint antes de tudo

**ANTES de qualquer investigação ou correção**, criar checkpoint git:

```bash
git stash  # ou
git commit -m "wip: checkpoint before debug" --no-verify
```

Se já tentou corrigir e piorou: `git stash pop` ou `git reset --hard HEAD~N` para voltar ao estado original. Recomeçar do zero.

---

## Como o debugging funciona neste projeto

```
1. Bug reportado ou teste falhando
   │
   ├── Bug óbvio (typo, import, campo faltando)?
   │     └── TDD direto: Red → Green → Refactor → commit
   │
   └── Bug não-óbvio (causa desconhecida, já tentou e falhou)?
         │
         ├── Checkpoint git (Regra Zero)
         │
         ├── Superpowers: systematic-debugging skill (4 fases)
         │     └── Root cause investigation → isolation → hypothesis → fix
         │
         ├── Personal skills acionadas automaticamente por contexto:
         │     ├── hono-api-debugging (erros de API, auth, middleware)
         │     ├── drizzle-database-debugging (schema, migration, queries)
         │     ├── react-tanstack-debugging (componentes, data fetching, tipos)
         │     └── escalation-and-bug-journal (quando fix falha 3x)
         │
         ├── Fix com TDD: teste que reproduz → fix mínimo → regressão completa
         │
         └── Se não convergir → escalação (4 níveis)
```

---

## Integração com o workflow SDD/TDD

### Quando o CLAUDE.md aciona este protocolo

| Situação | Ação |
|---|---|
| Prompt "Corrigir o erro X" | Ler este arquivo → Superpowers systematic-debugging |
| Teste falhou 2x no ciclo TDD | Escalar para debugging (não continuar tentando Green) |
| CI falhou na 3ª tentativa do loop de autocorreção | Escalar para Nível 2 |
| fix-agent falhou 3x | Agente principal assume com este protocolo |

### O que muda no fix-agent

O `fix-agent` (ver `claude-subagents.md`) segue Superpowers systematic-debugging + personal skills. O template do fix-agent inclui:

- Mensagem de erro exata + stack trace
- Contexto de reprodução
- **Tentativas anteriores** (para não repetir — critical para evitar loops)
- Seção do spec (se aplicável)

Se o fix-agent não conseguir diagnosticar em 3 tentativas, retorna diagnóstico parcial ao agente principal em vez de continuar tentando.

### Contexto do projeto que Superpowers não tem

Quando o debugging envolver lógica de negócio ou integração entre camadas, o Claude deve consultar:

| Informação | Onde encontrar |
|---|---|
| Comportamento esperado | `docs/specs/US-XX.spec.md` → cenários |
| Contrato API ↔ Frontend | `claude-stacks.md` → "API response format" |
| Regras de auth | `claude-stacks.md` → "Auth middleware (Clerk)" |
| Design tokens | `docs/design-system/design-brief.md` |
| Aprendizados anteriores | `claude-stacks-refactor.md` → "Regras descobertas" |
| Bugs anteriores similares | `claude-stacks-refactor.md` → "Bug Journal" |

---

## Escalação (complementa Superpowers)

O Superpowers tem hard gates mas não tem escalação estruturada para humano. Este protocolo adiciona 4 níveis:

| Nível | Quando | O que fazer |
|---|---|---|
| **1 — Fix direto** | Causa raiz identificada | Superpowers systematic-debugging normal |
| **2 — Investigação profunda** | 3 tentativas falharam | Parar, reportar tentativas, ampliar escopo (git bisect, docs, issues) |
| **3 — Abordagem alternativa** | Nível 2 falhou 2x | Questionar premissa, considerar workaround, simplificar, reescrever |
| **4 — Escalar para humano** | Nível 3 falhou | Report completo com diagnóstico, tentativas, e sugestões |

O formato de report de cada nível está na personal skill `escalation-and-bug-journal`.

---

## Bug Journal (obrigatório para bugs > 30 min)

Após resolver bug que levou mais de 30 minutos, documentar no `claude-stacks-refactor.md` → seção "Bug Journal":

```markdown
#### [data] — [título do bug]
- **Sintoma**: [o que acontecia]
- **Causa raiz**: [o que estava errado]
- **Correção**: [o que foi feito]
- **Tempo investido**: [estimativa]
- **Nível de escalação**: [1/2/3/4]
- **Lição aprendida**: [o que preveniria este bug no futuro]
- **Candidato a promoção?**: [sim/não]
```

Se a lição é reutilizável entre projetos, adicionar na tabela de "Candidatos a promoção".

---

## Anti-patterns de debugging (proibições)

- ❌ **Nunca "tentar" um fix sem diagnóstico.** "Vou tentar trocar X por Y" é chute
- ❌ **Nunca adicionar try-catch para esconder erro.** Mascara o bug
- ❌ **Nunca mexer em arquivo fora da cadeia de execução.** Stack trace é o mapa
- ❌ **Nunca aplicar fix em mais de 3 arquivos para um bug.** Diagnóstico está errado
- ❌ **Nunca repetir fix que já falhou.** Ler tentativas anteriores primeiro
- ❌ **Nunca ignorar a stack trace.** Ler linha por linha
- ❌ **Nunca atualizar dependência como primeiro recurso.** Só com evidência concreta
- ❌ **Nunca refatorar durante debugging.** Fix first, refactor later
- ❌ **Nunca debugar mais de 1 bug ao mesmo tempo.** Um, commit, próximo
- ❌ **Nunca continuar após 5 tentativas sem escalar.** Ir para Nível 2/3/4
- ❌ **Nunca ignorar bugs pré-existentes.** "Não foi eu que causei" não é justificativa — ver política em `Bugs pré-existentes`
- ❌ **Nunca desenvolver nova funcionalidade com testes falhando, lint com erros, ou typecheck com erros.** Baseline verde primeiro
