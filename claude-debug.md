# claude-debug.md — Referência de Debug

> Reference card lida pelo comando `/bug`. Contém apenas as políticas que outros arquivos referenciam diretamente.
> Para o protocolo completo de debugging, usar `/bug` em vez de ler este arquivo.

---

## Bugs pré-existentes — Política obrigatória

Quando `bun test`, `bunx biome check`, ou `tsc` encontrar erros que **não foram causados pela task atual**:

```
Bug pré-existente encontrado
│
├── Escopo pequeno (≤ 30 min para corrigir)?
│     └── ✅ CORRIGIR AGORA, antes de continuar a task atual
│           Commit separado: "fix: corrigir [descrição] pré-existente"
│
└── Escopo grande (> 30 min)?
      └── ✅ PARAR task atual → criar item P1 no backlog → corrigir ANTES de qualquer nova feature
            Nunca desenvolver nova funcionalidade sobre baseline quebrada
```

**Nunca:**
- ❌ Classificar como "pré-existente" e continuar — cria bola de neve de débito técnico
- ❌ Mencionar o bug em relatório sem resolver ou criar P1 — citar não é resolver

**Por quê:** Feature nova sobre baseline com bugs mascara causa raiz, adiciona complexidade e pode gerar falsos-verdes nos testes novos.

---

## Escalação — 4 níveis

| Nível | Quando | O que fazer |
|---|---|---|
| **1 — Fix direto** | Causa raiz identificada | `superpowers:systematic-debugging` normal |
| **2 — Investigação profunda** | 3 tentativas falharam | Parar, reportar tentativas, ampliar escopo (git bisect, docs, issues) |
| **3 — Abordagem alternativa** | Nível 2 falhou 2x | Questionar premissa, considerar workaround, simplificar, reescrever |
| **4 — Escalar para humano** | Nível 3 falhou | Report completo: diagnóstico + tentativas + sugestões |

Formato do report de cada nível: skill `escalation-and-bug-journal`.
