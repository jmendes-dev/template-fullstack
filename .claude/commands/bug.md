---
description: "Protocolo completo de debug: checkpoint → diagnóstico → fix → journal"
---

# /bug — Protocolo de Debug

Use este comando ao receber qualquer bug report, teste falhando, ou CI quebrando.
Passe o contexto como argumento: `/bug rota /xyz retorna 500 após deploy`

## Passo 1 — Checkpoint git (OBRIGATÓRIO, antes de tudo)

```bash
git stash
# ou
git commit -m "wip: checkpoint before debug" --no-verify
```

Se piorou após tentar corrigir: `git stash pop` ou `git reset --hard HEAD~N` para voltar.

## Passo 2 — Verificar bugs pré-existentes

Antes de corrigir $ARGUMENTS, rodar `bun test && bunx biome check && tsc --noEmit`.

Se encontrar erros **que não são o bug reportado**, aplicar a política de `claude-debug.md` → seção "Bugs pré-existentes".

## Passo 3 — Triagem

```
Bug óbvio (typo, import errado, campo faltando, erro de configuração)?
  └── Sim → TDD direto: Red → Green → Refactor → commit
           Invocar skill: superpowers:test-driven-development

Bug não-óbvio (causa desconhecida, já tentou e falhou, comportamento inesperado)?
  └── Não → Seguir Passo 4
```

## Passo 4 — Skill de diagnóstico

Invocar **primeiro** a skill de debugging do Superpowers:

> Invocar skill: `superpowers:systematic-debugging`

Depois, invocar automaticamente a personal skill correspondente ao contexto:

| Contexto do erro | Skill a invocar |
|---|---|
| Rota Hono, middleware, auth, response format | `hono-api-debugging` |
| Query Drizzle, migration, schema, Zod | `drizzle-database-debugging` |
| Componente React, TanStack Query, RPC client, shadcn | `react-tanstack-debugging` |
| 2-3 tentativas já falharam | `escalation-and-bug-journal` |

**Nunca invocar mais de uma personal skill simultaneamente.** Diagnosticar, isolar, fixar uma de cada vez.

## Passo 4.5 — Tech Lead Brief (bugs não-óbvios)

> **Aplicar apenas se o bug passou pelo Passo 4** (systematic-debugging + personal skill).
> Bugs óbvios (triados no Passo 3 → TDD direto) pulam este passo.

Invocar agente `tech-lead` via Agent tool com o seguinte contexto:

```
Tipo: BUG_FIX
Descrição original: <bug reportado em $ARGUMENTS>
Output do diagnóstico: <resultado do systematic-debugging e personal skill do Passo 4>
Spec de referência: <docs/specs/US-XX.spec.md se existir, senão omitir>
```

O tech-lead assume a implementação a partir daqui:
- ANALYZE → confirma causa raiz diretamente no código
- BRIEF → cria `docs/tasks/brief-YYYY-MM-DD-<slug>.md` com critérios de aceite específicos
- DELEGATE → despacha ao especialista correto (backend-developer, frontend-developer, etc.)
- VALIDATE → verifica critérios de aceite de forma independente; back-delega se necessário

O Passo 5 (Fix com TDD) é executado **dentro** do tech-lead, pelo agente especialista.
Avançar para Passo 6 apenas após o tech-lead reportar `STATUS: VALIDATED`.

## Passo 5 — Fix com TDD (bugs óbvios — sem tech-lead)

> **Apenas para bugs triados no Passo 3 como óbvios** (typo, import errado, campo faltando, configuração).
> Bugs não-óbvios são tratados no Passo 4.5.

1. Escrever **teste que reproduz o bug** (Red)
2. Implementar fix mínimo (Green) — não refatorar
3. Rodar suite completa para verificar regressões
4. Refactor se necessário
5. Commit: `fix: [descrição concisa do bug]`

## Passo 6 — Verificar escalação

Após cada tentativa frustrada, consultar tabela de escalação em `claude-debug.md`:

- **Nível 1** (1ª tentativa): fix direto via systematic-debugging
- **Nível 2** (3ª tentativa): parar, reportar tentativas, ampliar escopo
- **Nível 3** (2ª falha em Nível 2): questionar premissa, considerar workaround
- **Nível 4** (Nível 3 falhou): escalar para humano com report completo

> Após 3 falhas sem diagnóstico: invocar `escalation-and-bug-journal` para estruturar o report.

## Passo 7 — Bug Journal (bugs > 30 min)

Se o fix levou mais de 30 minutos, documentar em `claude-stacks-refactor.md` → seção "Bug Journal":

```markdown
#### [data] — [título do bug]
- **Sintoma**: [o que acontecia]
- **Causa raiz**: [o que estava errado]
- **Correção**: [o que foi feito]
- **Tempo investido**: [estimativa]
- **Nível de escalação**: [1/2/3/4]
- **Lição aprendida**: [o que preveniria no futuro]
- **Candidato a promoção?**: [sim/não]
```

## Proibições

- ❌ "Vou tentar trocar X por Y" sem diagnóstico — chute não é debugging
- ❌ `try-catch` para esconder erro — mascara o bug
- ❌ Mexer em arquivo fora da cadeia de execução do stack trace
- ❌ Fix em mais de 3 arquivos para um único bug — diagnóstico está errado
- ❌ Repetir fix que já falhou — ler tentativas anteriores primeiro
- ❌ Ignorar a stack trace — ler linha por linha
- ❌ Atualizar dependência como primeiro recurso — só com evidência concreta
- ❌ Refatorar durante debugging — fix first, refactor later
- ❌ Debugar mais de 1 bug ao mesmo tempo — um, commit, próximo
- ❌ Continuar após 5 tentativas sem escalar — ir para Nível 2/3/4
- ❌ Desenvolver nova feature com testes falhando, lint com erros, ou typecheck com erros

## Referências

- `claude-debug.md` — Política de bugs pré-existentes + tabela de 4 níveis de escalação
- `claude-stacks.md` — Contratos API, regras de auth, padrões técnicos
- `claude-stacks-refactor.md` — Bug journal + aprendizados anteriores
- `docs/specs/US-XX.spec.md` — Comportamento esperado para o contexto bugado
