---
description: "Fluxo completo de feature: TRIAGE → SPEC → PLAN → EXECUTE → VERIFY → FINISH"
---

# /feature — Fluxo de Feature

Use para qualquer feature nova ou existente. Passe o contexto:
`/feature adicionar autenticação com Clerk na rota /api/me`

## Passo 1 — TRIAGE

Executar `/triage $ARGUMENTS` para classificar o pedido.

A saída do triage determina o próximo passo:
- **Spec necessária = sim** → Passo 2
- **Spec necessária = não** → Pular para Passo 3

## Passo 2 — SPEC (apenas se triage indicou "contrato novo")

1. Ler `claude-sdd.md` para estrutura e campos obrigatórios do spec
2. Localizar ou criar `docs/specs/US-XX.spec.md`
3. Gerar o spec com todos os campos do template: contexto, contratos (request/response), cenários BDD, critérios de aceite
4. **Aguardar aprovação do usuário antes de continuar** — spec é um contrato, não pode ser modificado unilateralmente
5. Após aprovação, registrar o spec em `docs/contracts/README.md`

## Passo 3 — PLAN

Invocar skill: `superpowers:writing-plans`

O plano deve:
- Decompor a feature em micro-tasks independentes
- Mapear cada task ao agente responsável
- Identificar dependências entre tasks
- Salvar em `docs/superpowers/plans/`

## Passo 4 — EXECUTE

Invocar skill: `superpowers:subagent-driven-development`

Para cada task do plano:
- Invocar skill: `superpowers:test-driven-development` (obrigatório por task)
- Despachar agente correto conforme tabela de routing (ver `/triage`)
- Verificar que nenhuma task P2/P3 é iniciada com P1 pendentes

**O orquestrador não escreve código de produção diretamente.**

## Passo 5 — VERIFY

Invocar skill: `superpowers:verification-before-completion`

Antes de declarar qualquer coisa como pronto:
- Todos os testes passam: `bun test`
- Lint e typecheck limpos: `bunx biome check && tsc --noEmit`
- Cobertura ≥ 80% por módulo: `./check-quality.sh`
- Comportamento testado manualmente no happy path e edge cases

## Passo 6 — FINISH

Invocar `/finish` para encerrar o ciclo de entrega.

## Regras

- ❌ Spec com contrato novo sem aprovação do usuário
- ❌ Funcionalidade não mapeada em `docs/backlog.md`
- ❌ Iniciar EXECUTE sem PLAN aprovado
- ❌ Pular VERIFY antes de declarar pronto
- ❌ Misturar refactor com nova funcionalidade no mesmo ciclo
- ❌ Tecnologias fora de `claude-stacks.md` sem aprovação explícita
