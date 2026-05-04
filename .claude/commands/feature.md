---
description: "Fluxo completo de feature: TRIAGE → SPEC → PLAN → EXECUTE → VERIFY → FINISH"
---

# /feature — Fluxo de Feature

Use para qualquer feature nova ou existente. Passe o contexto:
`/feature adicionar autenticação com Clerk na rota /api/me`

## Passo 1 — Classificar

Se não veio de `/triage` → invocar `/triage` primeiro.
Após triage: seguir Passo 2 se spec necessária, Passo 3 se TDD direto.

## Passo 2 — SPEC (apenas se triage indicou "contrato novo")

1. Ler `claude-sdd.md` para estrutura e campos obrigatórios do spec
2. Localizar ou criar `docs/specs/US-XX.spec.md`
3. Gerar o spec com todos os campos do template: contexto, contratos (request/response), cenários BDD, critérios de aceite
4. **Aguardar aprovação do usuário antes de continuar** — spec é um contrato, não pode ser modificado unilateralmente

## Passo 3 — PLAN

Invocar skill: `superpowers:writing-plans`

O plano deve:
- Decompor a feature em micro-tasks independentes
- Mapear cada task ao agente responsável
- Identificar dependências entre tasks
- Atualizar `docs/backlog.md` com as tasks geradas

## Passo 4 — EXECUTE

> **Plano gerado pelo `master-plan`?** Se o plano em uso é `plans/<slug>-plano.md` (kit empresa), preferir a skill `master-fase` para execução fase a fase. O `master-fase` cuida do gate da fase, security review por endpoint (via `master-security-review`) e fechamento do CI (via `master-ci-fix`). O fluxo `tech-lead` abaixo aplica-se a planos do template em `docs/superpowers/plans/`.

Invocar skill: `superpowers:subagent-driven-development`

### Fluxo por task (via tech-lead)

Para cada task do plano, **não despachar o especialista diretamente**. Invocar o agente `tech-lead` como intermediário:

```
Para tasks independentes (sem dependência entre si):
  1. [PARALELO] Invocar tech-lead para cada task com:
       - Contexto da task (descrição do plano)
       - Spec de referência: docs/specs/US-XX.spec.md (se existir)
       - Critérios de aceite do spec mapeados para esta task
     → Tech-lead executa ANALYZE + BRIEF em paralelo para todas
  2. [PARALELO] Tech-lead executa DELEGATE em paralelo → especialistas trabalham
  3. [INDIVIDUAL] Tech-lead executa VALIDATE por task:
       STATUS: VALIDATED → avançar para próxima task
       STATUS: ESCALATED → pausar essa task, reportar ao orquestrador, continuar as outras

Para tasks com dependência (ex: schema antes de endpoint):
  → Executar em sequência mesmo no modo paralelo
  → Aguardar VALIDATED da task anterior antes de iniciar a seguinte
```

- `superpowers:test-driven-development` é executado pelo especialista, dentro do tech-lead
- Nenhuma task P2/P3 iniciada com P1 pendentes
- Avançar para Passo 5 apenas após todas as tasks reportarem `VALIDATED`

**O orquestrador não escreve código de produção diretamente.**

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

## Passo 6 — FINISH

Invocar `/finish` para encerrar o ciclo de entrega.

## Regras

- ❌ Spec com contrato novo sem aprovação do usuário
- ❌ Funcionalidade não mapeada em `docs/backlog.md`
- ❌ Iniciar EXECUTE sem PLAN aprovado
- ❌ Pular VERIFY antes de declarar pronto
- ❌ Pular QA Review em 5.1 (sempre obrigatório)
- ❌ Pular Security Review em 5.2 quando algum gatilho (auth/input/segredo) é tocado
- ❌ Misturar refactor com nova funcionalidade no mesmo ciclo
- ❌ Tecnologias fora de `claude-stacks.md` sem aprovação explícita
