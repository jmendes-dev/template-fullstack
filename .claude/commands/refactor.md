---
description: "Refatoração disciplinada: branch isolada, sem novas features, testes preservados"
---

# /refactor — Refatoração Segura

Use para reestruturar código sem mudar comportamento observável.
Passe o escopo: `/refactor extrair módulo de autenticação de apps/api/src/routes`

## Passo 1 — Checkpoint git (OBRIGATÓRIO)

```bash
git stash
# ou, se houver trabalho em andamento a preservar:
git commit -m "wip: pre-refactor checkpoint" --no-verify
```

Se algo piorar durante o refactor: `git stash pop` ou `git reset --hard HEAD~N`.

## Passo 2 — Branch isolada

Invocar skill: `superpowers:using-git-worktrees`

Nome da branch: `refactor/<escopo-curto>` (ex: `refactor/extract-auth-module`)

## Passo 3 — Baseline verde (OBRIGATÓRIO)

```bash
bun test && bunx biome check && tsc --noEmit
```

Se houver falhas → **não é refactor, é fix**. Invocar `/bug` primeiro, depois retornar aqui.

## Passo 4 — Inventário de testes

Identificar quais testes cobrem o código a reestruturar.

- Cobertura do escopo < 80% → **PARAR**. Solicitar ao usuário: escrever testes antes de refatorar.
- Cobertura ≥ 95% → prosseguir.

## Passo 5 — Refatorar

Invocar skill: `superpowers:subagent-driven-development`

Delegar ao agente correto (ver tabela em `/triage`).

**Regra absoluta:** nenhum novo comportamento. Apenas reestruturação interna.
- ❌ Novos parâmetros públicos
- ❌ Novo comportamento em edge cases
- ❌ Novos endpoints, schemas, ou componentes
- ✅ Renomear, mover, extrair, consolidar, melhorar legibilidade

## Passo 6 — Verificar

Invocar skill: `superpowers:verification-before-completion`

Critérios:
- `bun test`: exatamente os mesmos testes passam, sem alteração nos testes
- Cobertura não cai em relação ao baseline
- `bunx biome check && tsc --noEmit`: limpos
- Diff revisado: zero mudança de comportamento observável

## Passo 7 — Encerrar

Invocar `/finish` para encerrar o ciclo.

---

## Proibições

- ❌ Adicionar feature nova no mesmo ciclo de refactor
- ❌ Alterar testes para "fazer passar" (isso indica mudança de comportamento, não refactor)
- ❌ Commit sem baseline verde (Passo 3)
- ❌ Pular `using-git-worktrees` — refactor deve ser em branch isolada
- ❌ Misturar múltiplos escopos de refactor em um único ciclo
