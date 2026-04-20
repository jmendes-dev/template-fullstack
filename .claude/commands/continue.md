---
description: "Retoma o backlog: lê docs/backlog.md e executa a próxima P1"
---

# /continue — Retomar Backlog

Use para continuar o desenvolvimento a partir do backlog priorizado.

## Processo

1. Ler `docs/backlog.md`
2. Identificar o próximo item com prioridade **P1** que ainda não está concluído
3. Apresentar o item brevemente:
   ```
   Próxima P1: [título]
   Estimativa: [XS/S/M/L/XL]
   Dependências: [nenhuma | lista]
   ```
4. Invocar `/feature [descrição do item]` diretamente — invocar `/continue` já é confirmação de intenção
   **Exceção**: se houver dependências não resolvidas → perguntar como proceder antes de iniciar

## Regras

- ❌ Iniciar item P2 ou P3 enquanto houver P1 pendentes
- ❌ Iniciar item com dependências não resolvidas sem confirmar com o usuário
- ✅ Se não houver P1 pendente: informar e perguntar se deve prosseguir com P2
