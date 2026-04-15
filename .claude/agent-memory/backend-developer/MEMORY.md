# Agent Memory Index

## Feedback
- [feedback_crlf_line_endings.md](./feedback_crlf_line_endings.md) — Biome expects LF; Windows CRLF files trigger format errors on every lint run
- [feedback_noThenProperty_mock_pattern.md](./feedback_noThenProperty_mock_pattern.md) — Fix for Biome noThenProperty in test mocks; use Object.assign+queueMicrotask; use "" not undefined for env var clearing

## Como Capturar Memória (Session Retrospective)

> Ao fim de cada sessão de implementação, registre aprendizados **antes** de enviar notificação ntfy.

**Quando capturar:**
- Padrão novo descoberto (configuração, workaround, decisão de design)
- Bug resolvido após > 15 min de investigação
- Decisão arquitetural tomada (e o motivo)
- Anti-pattern encontrado que deve ser evitado

**Como registrar:**
1. Criar arquivo `feedback_[topico].md` neste diretório
2. Usar frontmatter: `type: feedback | user | project | reference`
3. Adicionar entrada no índice deste arquivo (seção ## Feedback ou ## Índice)

**Formato do arquivo de memória:**
```markdown
---
name: [nome curto]
description: [uma linha — usado para decidir relevância em futuras sessões]
type: feedback
---

[Regra principal]

**Why:** [motivo — incidente passado ou preferência forte]
**How to apply:** [quando/onde esta regra entra em vigor]
```

**Atualizar também:**
- Se for aprendizado reutilizável em outros projetos: marcar em `claude-stacks-refactor.md` como `⏳ Pendente`
- Atualizar `docs/session-state.md` com o que foi feito e próximo passo

