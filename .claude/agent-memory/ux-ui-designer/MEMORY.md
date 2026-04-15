# Agent Memory Index — ux-ui-designer

Quando notar um padrão relevante para preservar entre sessões, registrar aqui.
Este arquivo é carregado automaticamente no prompt — manter conciso (máx 200 linhas).

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

