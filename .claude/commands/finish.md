---
description: "Encerra o ciclo de entrega: verificação → code review → merge"
---

# /finish — Encerramento de Feature

Use ao concluir a implementação de uma feature ou fix, antes de fazer merge.

## Sequência obrigatória (nesta ordem)

### 1 — Verificação antes de declarar pronto

Invocar skill: `superpowers:verification-before-completion`

Checklist mínimo:
- `bun test` — todos os testes passam
- `bunx biome check` — lint sem erros
- `tsc --noEmit` — typecheck sem erros
- `./check-quality.sh` — cobertura ≥ 95% por módulo
- Happy path testado manualmente (ou declarar impossibilidade justificada)

**Não avançar se qualquer item falhar.**

### 2 — Code review

Invocar skill: `superpowers:requesting-code-review`

O review deve validar:
- Aderência ao spec aprovado (se houver)
- Conformidade com `claude-stacks.md`
- Ausência de `any` sem justificativa
- Ausência de cores/espaçamentos hardcoded (frontend)
- Testes cobrem casos de borda relevantes

### 3 — Merge

Invocar skill: `superpowers:finishing-a-development-branch`

Seguir o procedimento da skill para:
- Criar PR com template
- Aguardar aprovação ou auto-merge se configurado
- Limpar a branch e o worktree

### 4 — Atualizar backlog + fechar issue (obrigatório)

Após merge do PR, despachar `project-manager` via Agent tool. Prompt esperado:

> Para a US recém-finalizada (ID extraído do título do PR/commit, formato `US-<N>`):
> (a) Em `docs/backlog.md`: alterar `**Status:** pendente|em andamento` para `**Status:** concluída`; marcar todas as tasks pendentes (`- [ ]`) da US como concluídas (`- [x]`).
> (b) Commitar com mensagem `docs(backlog): US-<N> concluída`.
> (c) Rodar `./sync-github-issues.sh` — fingerprint detecta mudança de status e fecha a issue GitHub correspondente automaticamente.
> (d) Confirmar via `gh issue view <N>` que a issue está `state: closed`.
> (e) Se a US era a última pendente da wave ativa, mencionar no relatório que a wave foi completada e sugerir próximos passos (iniciar próxima wave, ou promover USs da wave `Backlog`).
>
> Reportar com `STATUS: DONE` e lista de arquivos atualizados + número da issue fechada + status da milestone da wave.

## Regras

- ❌ Merge sem todos os itens da verificação passando
- ❌ Merge sem code review
- ❌ `--force`, `--no-verify`, `[skip ci]`
- ❌ Pular Passo 4 (backlog desatualizado rompe visibilidade de progresso das waves no GitHub Milestones)
