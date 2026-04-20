---
description: "Bootstrap de projeto novo: requisitos → stories → sequência de agentes"
---

# /new-project — Bootstrap de Projeto Novo

Use este comando ao iniciar qualquer projeto novo do zero. Ele guia o processo completo:
levantamento de requisitos → geração de artefatos → sequência de agentes especialistas → validação de saúde.

> Para hard-constraints e gates de cada fase, consultar `start_project.md`.
> Para regras de stack, consultar `claude-stacks.md`.

---

## Pré-requisito: ler start_project.md

Antes de qualquer ação, ler `start_project.md` para verificar os gates obrigatórios de cada fase.
Nenhuma fase pode ser iniciada sem o gate da fase anterior estar cumprido.

---

## Fase 1 — Levantamento de Requisitos

> **Skills disponíveis**: invocar `novo-prd` (entrevista guiada) e `prd-planejamento` (geração de backlog).
> Se as skills estiverem disponíveis, prefira-as — elas mantêm o mesmo protocolo de entrevista abaixo.
> Se as skills não estiverem disponíveis, executar o protocolo inline a seguir.

Assumir o papel de analista XP sênior e conduzir a entrevista abaixo com o usuário.
O objetivo é extrair requisitos suficientes para gerar `docs/user-stories.md` e `docs/backlog.md`.

### Prompt de entrevista

```
Você é um analista XP sênior conduzindo o levantamento de requisitos de um novo projeto (ou nova feature).
Sua função é me entrevistar para extrair requisitos e ao final gerar dois arquivos:
1. `docs/user-stories.md` — histórias de usuário com critérios de aceite
2. `docs/backlog.md` — backlog XP com stories priorizadas, quebradas em tasks e testes planejados

[SE HOUVER PDF] Leia o PDF de mapeamento de processos anexado antes de começar.
Use-o como base para as perguntas, mas complete as lacunas com a entrevista.

[SE NÃO HOUVER PDF] Conduza a entrevista do zero, cobrindo todas as dimensões abaixo.

---

REGRAS DA ENTREVISTA:
- Faça UMA pergunta por vez. Nunca um bloco de perguntas.
- Adapte as próximas perguntas com base nas respostas anteriores.
- Quando um requisito for vago, peça um exemplo concreto.
- Confirme seu entendimento antes de avançar para o próximo tema.
- Ao identificar uma regra de negócio implícita, sinalize e confirme.
- Quando sentir que tem informação suficiente, avise e peça confirmação para gerar os artefatos.
- Antes de gerar, pergunte sobre a **prioridade** de cada story (P1/P2/P3) — ou sugira com base no contexto.

DIMENSÕES A COBRIR (na ordem que fizer sentido para o contexto):
1. Contexto e objetivo — por que esse projeto/feature existe? Qual problema resolve?
2. Atores — quem são os usuários? Quais perfis/papéis existem?
3. Fluxo principal — qual é o caminho feliz passo a passo?
4. Fluxos alternativos — o que pode dar errado? Quais exceções existem?
5. Regras de negócio — há validações, cálculos, restrições ou políticas?
6. Integrações — depende de sistemas externos? Quais? Como se comunicam?
7. Dados — quais entidades e campos são necessários?
8. Não-funcionais — há requisitos de performance, segurança, acessibilidade?
9. Critérios de pronto — como saberemos que a feature está completa?
10. Fora de escopo — o que explicitamente NÃO faz parte desta entrega?
11. Priorização — quais stories são críticas (P1), importantes (P2) ou desejáveis (P3)?
12. Direção visual (sementes para o design system) — NÃO aprofundar aqui, apenas capturar sementes:
    - O projeto tem marca existente? (logo, cores, fonte)
    - Qual o tom geral? (formal/corporativo, moderno/tech, casual/amigável)
    - Alguma referência visual rápida? (ex: "quero algo parecido com o Linear")
    - O público é técnico ou leigo? (afeta densidade de informação)
    - Desktop-first ou mobile-first?

    > NOTA: não aprofundar design nesta entrevista. Registrar as respostas no final do
    > `user-stories.md` como seção "Sementes de Design" para alimentar o DESIGN.md depois.

---

FORMATO DOS ARTEFATOS GERADOS:

### user-stories.md
Cada story no formato:
**US-[número]: [título curto]**
Como [ator], quero [ação], para que [valor/benefício].

Prioridade: **P[1/2/3]**

Critérios de aceite:
- [ ] [critério 1 — comportamento verificável]
- [ ] [critério 2]
- [ ] [critério n]

Regras de negócio relacionadas: [lista]
Fora de escopo: [o que não faz parte desta story]

### Seção adicional no user-stories.md (ao final do arquivo):

---

## Sementes de Design

> Respostas coletadas durante o levantamento de requisitos.
> Estas sementes alimentam a entrevista de design system (`DESIGN.md`).
> Não são decisões finais — serão aprofundadas na etapa de design.

- **Marca existente**: [sim/não — se sim, descrever brevemente]
- **Tom visual**: [ex: moderno e profissional]
- **Referências**: [ex: Linear, Vercel]
- **Público**: [ex: equipe interna técnica + armadores externos com pouca familiaridade digital]
- **Dispositivo primário**: [ex: desktop-first, mobile como secondary]
- **Notas adicionais**: [qualquer observação visual que surgiu durante a entrevista]

---

### backlog.md

O backlog segue modelo **Kanban com priorização** (não Scrum/sprints).
Ordenar stories por prioridade: todas as P1 primeiro, depois P2, depois P3.

Para cada US:

**US-[número]: [título]** — **P[1/2/3]** · [estimativa em pontos XP: 1/2/3/5/8]

Tasks:
- [ ] TASK-[us].[n]: [descrição técnica da task]
  - Teste: `deve [comportamento] quando [condição]`
  - Tipo: [unitário / integração / E2E]
- [ ] TASK-[us].[n]: [descrição técnica da task]
  - Teste: `deve [comportamento] quando [condição]`
  - Tipo: [unitário / integração / E2E]

---

### Legenda de prioridade

| Prioridade | Significado | Quando usar |
|---|---|---|
| **P1** — Crítico | Bloqueia outras stories ou é requisito de lançamento | MVP, fluxo principal, auth, schemas base |
| **P2** — Importante | Agrega valor significativo, fazer após P1 | Features secundárias, relatórios, integrações |
| **P3** — Desejável | Nice-to-have, fazer se sobrar capacidade | Melhorias de UX, otimizações, extras |

### Regras de priorização

- O agente sugere prioridades com base no contexto da entrevista, mas o autor aprova
- Stories que são dependência de outras stories devem ser P1 (mesmo que o valor isolado seja P2)
- Auth, schemas base e setup de infra são sempre P1
- Se o autor não definir prioridade, o agente pergunta antes de gerar

---

Comece perguntando: "Qual é o nome do projeto (ou da feature) e qual problema ele resolve para o usuário?"
```

### Checklist pós-entrevista

Antes de avançar para a Fase 2, confirmar:

- [ ] Todos os atores identificados
- [ ] Fluxo principal documentado
- [ ] Fluxos de exceção cobertos
- [ ] Regras de negócio explicitadas e confirmadas
- [ ] Integrações mapeadas com protocolo/contrato
- [ ] Critérios de pronto definidos
- [ ] Escopo negativo declarado (o que NÃO entra)
- [ ] Prioridades definidas e aprovadas (P1/P2/P3 para cada story)
- [ ] Sementes de design coletadas e registradas

### Uso para features em projetos existentes

Se o projeto já existe e você está levantando uma **nova feature**:

1. Informe ao Claude quais stories já existem (cole o `user-stories.md` atual).
2. Peça para numerar as novas stories continuando a sequência.
3. Peça para o Claude identificar impactos em stories existentes.
4. Defina a prioridade das novas stories em relação às existentes.
5. Ao final, gere apenas o **diff** do backlog — novas tasks, não reescreva o backlog inteiro.
6. Novas stories P1 entram antes das P2/P3 existentes na ordem do backlog.

---

## Fase 2 — Aprovação e Documentação

Após concluir a entrevista, invocar o agente `requirements-roadmap-builder` para gerar os artefatos formais.

**Handoff para o agente:**

```
Você é o requirements-roadmap-builder. Com base na entrevista de levantamento de requisitos
já concluída, gerar:
1. `docs/user-stories.md` — stories no formato XP com critérios de aceite e seção "Sementes de Design"
2. `docs/backlog.md` — Kanban priorizado (P1/P2/P3) com tasks e testes planejados

Aguardar aprovação explícita do usuário antes de avançar.
```

**Gate**: usuário aprovou `docs/user-stories.md` e `docs/backlog.md` explicitamente.

---

## Fase 3 — Sequência de Agentes

Executar nesta ordem com handoff explícito entre cada etapa. **Não avançar sem aprovação quando indicado.**

### Passo 1 — requirements-roadmap-builder (já concluído na Fase 2)

Saída: `docs/user-stories.md` + `docs/backlog.md`
Gate: aprovação explícita do usuário.

### Passo 2 — software-architect

```
Você é o software-architect. Ler `docs/backlog.md` e `docs/user-stories.md`.
Gerar `docs/adr/ADR-001-stack-selection.md` com a decisão de stack justificada
para este projeto específico. Confirmar deploy target (Railway ou Portainer).
```

Saída: `docs/adr/ADR-001-stack-selection.md`
Gate: ADR commitado (não requer aprovação explícita, mas deve ser revisado antes do passo 3).

### Passo 3 — ux-ui-designer (design system)

```
Você é o ux-ui-designer. Ler `DESIGN.md` (Parte 2) + `docs/user-stories.md`
(seção "Sementes de Design") + `docs/adr/ADR-001-stack-selection.md`.
Executar o pipeline de 3 passos da Parte 2 do DESIGN.md para gerar
`docs/design-system/MASTER.md`.
```

Saída: `docs/design-system/MASTER.md`
Gate: **aguardar aprovação explícita do usuário** antes de avançar.

### Passo 4 — ux-ui-designer (design brief)

```
Você é o ux-ui-designer. O MASTER.md foi aprovado.
Regenerar `docs/design-system/design-brief.md` a partir do MASTER.md aprovado.
O brief deve ter ~800 tokens — resumo compacto para injeção em contextos de componente.
```

Saída: `docs/design-system/design-brief.md`
Gate: brief commitado.

### Passo 5 — data-engineer-dba

```
Você é o data-engineer-dba. Ler `docs/user-stories.md` + `docs/adr/ADR-001-stack-selection.md`.
Criar schema inicial Drizzle em `packages/shared/src/schemas/` com:
- Todas as entidades identificadas nas stories P1
- createdAt + updatedAt em todos os schemas
- Schemas Zod derivados (insert + select)
- Tipos TypeScript exportados
- Barrel em packages/shared/src/index.ts
```

Saída: schemas em `packages/shared/src/schemas/`
Gate: `bun run db:generate` sem erros.

### Passo 6 — devops-sre-engineer

```
Você é o devops-sre-engineer. Ler `docs/adr/ADR-001-stack-selection.md` para confirmar
deploy target (Railway ou Portainer). Criar:
- Dockerfiles multi-stage (api + web, prod + dev)
- docker-compose.yml (dev local — sempre)
- docker-compose.yml / docker-compose-uat.yml / docker-compose-prd.yml (só Portainer)
- .github/workflows/ci.yml
- .github/workflows/cd-uat.yml + cd-prd.yml (só Portainer)
Consultar start_project.md para as constraints detalhadas de cada arquivo.
```

Saída: arquivos Docker + CI/CD
Gate: `docker compose up` → todos os services `healthy`.

### Passo 7 — setup-github-project.sh

```bash
./setup-github-project.sh
```

Gate: GitHub Project criado e sincronizado com `docs/backlog.md`.

---

## Fase 4 — Validação de Saúde

Após concluir a sequência de agentes, verificar que o projeto está saudável:

```bash
./check-health.sh --assert
```

Se o comando reportar falhas, corrigir antes de declarar o bootstrap completo.

---

## Regras

- **Deploy target é obrigatório**: perguntar ao usuário se não foi informado. Nunca assumir.
- **Nenhum arquivo criado antes do plano aprovado**: se o usuário não aprovou, perguntar. Nunca assumir aprovação.
- **Agentes em sequência**: não invocar o passo N+1 sem o gate do passo N cumprido.
- **Aprovação explícita obrigatória** nos gates marcados — "ok", "pode continuar" ou equivalente não é aprovação de artefato. O usuário deve confirmar o conteúdo.
- **Sem código de produção antes da Fase 3 passo 5**: o data-engineer-dba cria o primeiro schema. Antes disso, apenas artefatos de documentação.
- **Anti-patterns proibidos**: ver seção "Anti-patterns" em `start_project.md` — especialmente não pular fases, não assumir deploy target, não hardcodar portas ou credenciais.
