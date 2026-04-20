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
- Atualizar `docs/backlog.md` com o item concluído

## Regras

- ❌ Merge sem todos os itens da verificação passando
- ❌ Merge sem code review
- ❌ `--force`, `--no-verify`, `[skip ci]`
