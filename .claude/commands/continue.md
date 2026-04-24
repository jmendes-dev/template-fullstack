---
description: "Retoma o backlog: lê docs/backlog.md e executa a próxima P1"
---

# /continue — Retomar Backlog

Use para continuar o desenvolvimento a partir do backlog priorizado.

## Processo

### Passo 0 — PM refresh (obrigatório)

Despachar `project-manager` via Agent tool. Prompt esperado:

> Refresh do backlog em `docs/backlog.md`:
> (a) reconciliar status de tasks concluídas no último ciclo cruzando com `git log --since="7 days ago"`
> (b) identificar a **wave ativa** — primeira wave (do topo para baixo) com pelo menos uma US que NÃO está `**Status:** concluída`. Ignorar wave `Backlog` para essa finalidade.
> (c) dentro da wave ativa, recalcular ordem de prioridade (P1 > P2 > P3) e identificar a próxima P1 pronta (sem dependências não resolvidas).
> (d) se a wave ativa está completa (todas USs com status concluída), informar e sugerir iniciar a próxima wave OU promover USs da wave `Backlog`.
>
> Reportar com `STATUS: DONE` e bloco:
>
> ```
> WAVE ATIVA: <nome> (<X> de <Y> USs concluídas)
> PRÓXIMA P1: <título>
> Dependências: <nenhuma | lista>
> Estimativa: XS/S/M/L/XL
> ```

Se PM retornar `STATUS: BLOCKED` (ex: nenhuma wave com P1 pronta) → perguntar ao usuário como proceder antes de seguir.

### Passo 1 — Apresentar e executar

Com base no output do PM, apresentar o item ao usuário:

```
Próxima P1: [título]
Estimativa: [XS/S/M/L/XL]
Dependências: [nenhuma | lista]
```

Invocar `/feature [descrição do item]` diretamente — invocar `/continue` já é confirmação de intenção.

**Exceção**: se houver dependências não resolvidas → perguntar como proceder antes de iniciar.

### Passo 2 — PM close (ao fim da feature)

Após o `/feature` retornar DONE, despachar `project-manager` novamente. Prompt esperado:

> Fechar a task recém-concluída em `docs/backlog.md`: (a) marcar como concluída (riscar, mover para seção "Concluídas" ou aplicar convenção atual); (b) registrar referência ao commit de merge; (c) atualizar `docs/session-state.md` com próxima P1 sugerida; (d) se a issue do GitHub existir, chamar `./sync-github-issues.sh` para propagar. Reportar com `STATUS: DONE` e lista de arquivos atualizados.

## Regras

- ❌ Iniciar item P2 ou P3 enquanto houver P1 pendentes
- ❌ Iniciar item com dependências não resolvidas sem confirmar com o usuário
- ❌ Pular Passo 0 (PM refresh) — backlog pode estar desatualizado
- ❌ Pular Passo 2 (PM close) — deixa o backlog eternamente desalinhado com a realidade
- ✅ Se não houver P1 pendente: informar e perguntar se deve prosseguir com P2
