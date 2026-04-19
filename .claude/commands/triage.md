---
description: "Classifica o pedido e decide qual fluxo seguir"
---

# /triage — Triagem de Pedidos

Use quando receber qualquer pedido novo ou ambíguo. Classifica o pedido e indica o próximo passo correto.

## Árvore de decisão

```
Pedido recebido: $ARGUMENTS
│
├── "Iniciar projeto novo"
│     └── Invocar /new-project
│
├── "Adotar workflow / retrofit"
│     └── Rodar ./adopt-workflow.sh no projeto alvo
│
├── Bug / erro / CI quebrando
│     └── Invocar /bug [descrição do erro]
│
├── "Continuar backlog"
│     └── Invocar /continue
│
├── Encerrar feature / declarar pronto
│     └── Invocar /finish
│
├── Feature / Story (nova ou existente)
│     └── Seguir decisão de TRIAGE abaixo
│
├── Refatoração
│     └── Próximo passo: /refactor (branch isolada, sem novas features)
│
└── Pedido ambíguo
      └── Fazer UMA pergunta antes de qualquer ação
```

## TRIAGE — Feature precisa de spec?

Avaliar a story/request:

```
Story introduz schemas, endpoints ou componentes NOVOS (contrato novo)?
│
├── SIM → Spec obrigatória
│     └── Próximo passo: SPEC → PLAN → EXECUTE → VERIFY → FINISH (ver /feature para o roteiro)
│
└── NÃO → TDD direto
      └── Próximo passo: PLAN → EXECUTE → VERIFY → FINISH (ver /feature, pule Passo 2)
```

**Sinais de "contrato novo":**
- Novo endpoint de API (rota, método, payload, response)
- Novo schema de banco (tabela, coluna, relação)
- Novo componente público consumido por múltiplas páginas
- Integração com serviço externo novo

**Sinais de "TDD direto":**
- Ajuste em endpoint existente (sem quebrar contrato)
- Refactor interno sem mudar interface pública
- Bug fix
- Style/UI tweak em componente existente
- Adicionar teste a código já existente

## Regras de roteamento de agentes

Ver tabela de routing em `CLAUDE.md` (seção "ROUTING DE AGENTES"). Fonte de verdade única.

O orquestrador **nunca** escreve código de produção diretamente — toda implementação é delegada ao agente correto.

## Saída esperada

Ao final do triage, declarar explicitamente:

```
Tipo: [bug | feature-nova | feature-existente | refatoração | novo-projeto | ambíguo]
Spec necessária: [sim | não]
Próximo passo: [invocar /bug | /feature | /continue | /finish | /new-project | fazer pergunta X]
Agente: [nome do agente que vai implementar]
```
