---
description: "Retoma o backlog: lê docs/backlog.md e executa a próxima P1"
---

# /continue — Retomar Backlog

Use para continuar o desenvolvimento a partir do backlog priorizado.

## Processo

1. Ler `docs/backlog.md`
2. Identificar o próximo item com prioridade **P1** que ainda não está concluído
3. Apresentar o item ao usuário:
   ```
   Próxima P1: [título]
   Estimativa: [XS/S/M/L/XL]
   Dependências: [nenhuma | lista]
   ```
4. Aguardar confirmação antes de iniciar
5. Invocar `/feature [descrição do item]` para executar o fluxo completo

## Regras

- ❌ Iniciar item P2 ou P3 enquanto houver P1 pendentes
- ❌ Iniciar item com dependências não resolvidas
- ❌ Pular a confirmação do usuário antes de iniciar
- ✅ Se não houver P1 pendente: informar e perguntar se deve prosseguir com P2
