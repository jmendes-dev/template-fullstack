---
name: five-response-selector
description: Use when formulating any substantive response to the user — generates 5 candidate answers, scores each with a weighted probability formula, and returns only the highest-scoring candidate
---

# Five Response Selector

## Overview

Before delivering any substantive response, reason internally through 5 distinct candidate answers, score each using a weighted probability formula, and return only the highest-probability candidate. Forces multi-angle reasoning and surfaces the best possible answer every time.

## When to Use

- **Always** — before any substantive response to a user request
- **Skip** — one-word confirmations ("ok", "sim"), pure echo responses, internal workflow steps mid-skill

## Protocol

### Step 1 — Generate 5 Candidates

Reason through 5 distinct approaches (internally, never shown):

| # | Abordagem |
|---|-----------|
| A | Direta/literal — interpretação mais próxima do pedido |
| B | Contextual — o que o usuário realmente precisa, além do literal |
| C | Alternativa — ângulo diferente, outra técnica ou framing |
| D | Mínima — menor mudança que atinge o objetivo |
| E | Criativa — abordagem não óbvia que pode surpreender positivamente |

### Step 2 — Score Each (0.0–1.0 per criterion)

| Critério | Peso | O que avaliar |
|----------|------|---------------|
| Acurácia | 0.30 | Correção factual e precisão técnica |
| Completude | 0.25 | Cobre todos os aspectos do pedido |
| Alinhamento | 0.25 | Compatível com CLAUDE.md, stack, memórias e preferências do usuário |
| Praticidade | 0.15 | Acionável sem bloqueadores |
| Segurança | 0.05 | Sem riscos éticos, de segurança ou de dados |

**Fórmula:**
```
P = 0.30·acurácia + 0.25·completude + 0.25·alinhamento + 0.15·praticidade + 0.05·segurança
```

### Step 3 — Entregar o Melhor

Retorne **apenas** o candidato de maior P. Adicione rodapé ao final da resposta:

```
---
[Candidato X selecionado | P = 0.XX | 5 avaliados]
```

Se dois candidatos estiverem dentro de 0.03 entre si, prefira o de maior **segurança**.

## Exemplo

Pedido: "Como devo estruturar os services no backend?"

Avaliação interna:
- A (direta): Explica o padrão service/repository genérico — P = 0.68
- B (contextual): Explica + mapeia ao stack Hono/Drizzle do projeto atual — P = 0.91 ✓
- C (alternativa): Compara com arquitetura hexagonal — P = 0.61
- D (mínima): Uma frase sobre separação de responsabilidades — P = 0.55
- E (criativa): Propõe refatoração ao vivo com exemplo — P = 0.74

→ Entrega Candidato B (P = 0.91)

## Regras Críticas

- O processo interno (5 candidatos + scores) **nunca** é mostrado ao usuário
- Apenas o rodapé `[Candidato X | P = 0.XX | 5 avaliados]` sinaliza o protocolo
- Alinhamento sempre verifica: CLAUDE.md, `claude-stacks.md`, memórias do projeto
- Não aplicar em respostas de uma palavra ou etapas internas de fluxo de skills
