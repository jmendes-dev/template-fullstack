---
name: prd-planejamento
description: Transforma um PRD em plano de implementação faseado com fatias verticais (tracer bullets), salvo em ./plans/. Usar quando o usuário quiser quebrar um PRD em fases, criar plano de implementação, ou planejar entregas a partir de um PRD.
user-invocable: true
---

Esta skill é invocada quando o usuário quer transformar um PRD (Produto — Documento de Requisitos) em um **plano de implementação faseado**. Cada fase é uma fatia vertical — um pedaço fino que passa por todas as camadas ao mesmo tempo (banco, API, frontend, testes), entregando algo demonstrável.

O público-alvo são vibecoders — conduza a conversa de forma acolhedora, prática e sem jargões desnecessários.

Toda a comunicação deve ser em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de fazer qualquer pergunta:

1. Leia o `CLAUDE.md` do projeto (se existir) para entender stack, regras e restrições arquiteturais
2. Explore a estrutura de diretórios do repositório (top-level: `apps/`, `packages/`, etc.)
3. Escaneie `plans/*.md` para encontrar PRDs existentes
4. Identifique se há um PRD recente que ainda não tem um plano correspondente (`*-plano.md`)
5. Explore o codebase para saber o que já existe: tabelas (arquivos de schema Drizzle), rotas, schemas Zod em `packages/shared`

Use esse contexto para fazer perguntas mais inteligentes e evitar propor fases para coisas que já existem.

---

## Passo 1 — Localizar e confirmar o PRD

### Se encontrou exatamente um PRD sem plano correspondente:

> "Encontrei o PRD de **[nome da feature]** aqui: `plans/[arquivo].md`.
>
> Ele tem **N histórias** de Alta prioridade, **Y tabelas** e **Z endpoints**.
>
> É esse que você quer transformar em plano de implementação?"

Leia o PRD completo antes de prosseguir.

### Se encontrou múltiplos PRDs:

> "Encontrei mais de um PRD por aqui:
>
> 1. `plans/[arquivo1].md` — parece ser sobre [assunto em 5 palavras]
> 2. `plans/[arquivo2].md` — parece ser sobre [assunto em 5 palavras]
>
> Qual deles você quer transformar em plano?"

### Se não encontrou nenhum PRD:

> "Não encontrei nenhum PRD por aqui ainda.
>
> O prd-planejamento funciona a partir de um PRD pronto — é o documento que descreve o que você quer construir, pra quem, e como.
>
> Se você ainda não tem um, posso te ajudar a criar com o `/novo-prd`. Quer fazer isso primeiro?
>
> Ou se o PRD está em outro lugar, me diz o caminho do arquivo."

### Se o PRD já está na conversa:

Se o usuário colou o PRD ou apontou para o arquivo antes de invocar a skill, confirme: "Vou usar esse PRD como base. Me dá um segundo para ler com calma."

**Nunca avance** sem ter lido o PRD completo e recebido confirmação do usuário.

---

## Passo 2 — Análise de dependências

**Sem interação com o usuário.** Analise o PRD silenciosamente:

### 2.1 — Grafo de dependências do banco

A partir da seção "Modelo de Dados" do PRD:

1. Identifique todas as tabelas e suas foreign keys
2. Faça uma **ordenação topológica**: tabelas sem FK dependentes são raízes (vão primeiro)
3. Tabelas que referenciam outras devem vir depois das referenciadas

### 2.2 — Mapeamento histórias → recursos

Para cada história de **Prioridade Alta** (MVP):

- Quais tabelas ela lê/escreve?
- Quais endpoints ela precisa?
- Quais telas/componentes ela envolve?
- Ela depende de dados criados por outra história?

### 2.3 — Clusters de histórias

Agrupe histórias que formam uma fatia vertical coerente — ou seja, histórias que juntas entregam algo demonstrável de ponta a ponta. Critérios:

- Compartilham a mesma entidade principal
- Uma cria os dados que a outra lista/exibe
- Fazem sentido como uma demo conjunta ("criar e listar clientes" é uma demo, "criar cliente" sozinho não é útil)

### 2.4 — Ordem dos clusters

Ordene os clusters pela dependência de dados:

1. Clusters que operam em tabelas-raiz vêm primeiro
2. Clusters que dependem de dados de clusters anteriores vêm depois
3. Dentro do mesmo nível de dependência, priorize o que é mais visível/valioso para o usuário

### 2.5 — Preocupações transversais

Identifique o que precisa existir antes de qualquer fase de feature:

- Setup de auth (se o PRD tem rotas protegidas)
- Schemas compartilhados em `packages/shared`
- Migrations de todas as tabelas (ou ao menos as raízes)
- Infraestrutura de rotas no Hono e no React Router

Tudo isso vai para a **Fase 0**.

---

## Passo 3 — Proposta de fases

Apresente as fases ao usuário em linguagem simples. Use a metáfora de construção quando ajudar a explicar a sequência.

### Formato da apresentação:

> "Aqui está como eu dividiria a construção do **[nome da feature]** em etapas.
>
> Cada etapa entrega algo que você consegue abrir no sistema e usar (ou pelo menos ver funcionando). A ideia é ir construindo em camadas — como uma casa: primeiro a fundação, depois as paredes, depois os acabamentos.
>
> ---
>
> **Fase 0 — Fundação** (sem interface ainda, só estrutura)
> - Criar as tabelas no banco
> - Criar os tipos compartilhados
> - Registrar as rotas (vazias por enquanto)
> - Configurar auth nas rotas protegidas
>
> **Fase 1 — [Nome descritivo]**
> - Histórias: #N, #M
> - O que você vai construir: [lista em linguagem simples]
> - Ao terminar, você consegue: [descrição demonstrável]
>
> **Fase 2 — [Nome descritivo]**
> - Histórias: #N, #M
> - O que você vai construir: [lista em linguagem simples]
> - Ao terminar, você consegue: [descrição demonstrável]
>
> [... mais fases se necessário ...]
>
> ---
>
> Essa divisão faz sentido? Alguma fase parece grande demais ou pequena demais?"

### Tratando feedback do usuário:

**Se quer juntar fases** (sem conflito técnico):
> "Consigo juntar sim. Ficaria assim: [descrever fase combinada]. Vai ficar maior, mas dá pra fazer. Confirma?"

**Se quer quebrar uma fase:**
> "Posso quebrar a Fase [X] em duas partes menores:
> - Opção A: [descrição]
> - Opção B: [descrição]
> Qual faz mais sentido?"

**Se quer reordenar criando conflito técnico:**
> "Entendo a lógica — [reconhecer o raciocínio do usuário].
>
> O problema prático é que a Fase [X] usa coisas que só existem depois da Fase [Y]. É como querer colocar as janelas antes de ter as paredes — elas não têm onde se encaixar ainda.
>
> O que posso fazer é reorganizar assim: [propor alternativa que honra a intenção]. Dessa forma você chega mais cedo em [o que o usuário queria]. Resolve?"

Se o usuário insistir após a explicação, respeite a escolha e documente o risco no plano.

Itere até o usuário aprovar a divisão.

---

## Passo 4 — Aprovação

Antes de escrever o plano, apresente um resumo compacto:

> "Deixa eu confirmar o que vou escrever:
>
> **Projeto:** [nome]
> **Objetivo:** [1 frase]
>
> **[N] fases:**
> 1. Fundação — estrutura base (banco, tipos, rotas)
> 2. [nome] — [1 linha] → ao terminar: [demonstrável]
> 3. [nome] — [1 linha] → ao terminar: [demonstrável]
> 4. [nome] — [1 linha] → ao terminar: [demonstrável]
>
> Posso montar o plano de implementação com essa estrutura?"

**Nunca assuma aprovação.** Só avance para o Passo 5 com um "sim" claro.

---

## Passo 5 — Escrita do plano

Escreva o plano no arquivo `plans/<mesmo-nome-do-prd>-plano.md`.

Exemplo: se o PRD é `plans/gestao-de-clientes.md`, o plano fica em `plans/gestao-de-clientes-plano.md`.

Crie o diretório `plans/` se não existir.

<template-plano>

# Plano: [Nome da Feature]

> PRD de origem: `plans/[nome-do-prd].md`
> Criado em: [data]

## Contexto do plano

[2-3 frases descrevendo o que esta feature entrega ao usuário final. Sem jargão técnico. Extrair da "Solução Proposta" e "Definição de MVP" do PRD.]

## Estratégia de entregas

[Parágrafo explicando como as fases foram divididas e por quê. Esse é o mapa mental do plano inteiro — o leitor entende o arco completo antes de mergulhar nos detalhes. Ex: "A Fase 0 prepara o banco e os tipos. As Fases 1 e 2 entregam o CRUD principal. A Fase 3 adiciona busca, filtros e refinamentos. Cada fase exceto a 0 é demonstrável."]

**Pré-requisitos antes de começar:**
- [ ] [ex: variável de ambiente X configurada]
- [ ] [ex: serviço Y disponível]
- [ ] [ex: PRD revisado e aprovado]

---

## Fase 0: Fundação

> Não é demonstrável. Prepara a infraestrutura que todas as fases seguintes dependem.
> Se o projeto já tem a fundação pronta para esta feature, pular esta fase.

**Histórias cobertas:** nenhuma diretamente — habilita todas as do MVP

### Decisões arquiteturais desta fase

[Decisões de implementação próprias do plano — NÃO duplicar o que o CLAUDE.md já define. Exemplos válidos: "usar soft delete (campo deletedAt) em vez de delete físico", "processar uploads de forma síncrona no MVP". NÃO incluir: "usar Drizzle ORM", "retornar { data }" — isso já está no CLAUDE.md.]

### O que construir

**packages/shared** — tipos e schemas
- Schema Zod para [entidade]: campos [listar campos principais do PRD]
- Schema Zod para [entidade]: campos [listar campos principais do PRD]
- Tipos TypeScript exportados via barrel file

**apps/api** — banco de dados e rotas
- Migration Drizzle para tabela `[nome]`: [colunas principais]
- Migration Drizzle para tabela `[nome]`: [colunas principais]
- Índices e constraints conforme PRD
- Registrar router de [feature] no app principal
- Handlers vazios que retornam 200 com dados mock
- Middleware de auth aplicado nas rotas protegidas (conforme matriz de permissões do PRD)

**apps/web** — infraestrutura de frontend
- Rota `[/caminho]` registrada no React Router
- Query keys configuradas para [feature]
- Página placeholder: "[Feature] — em construção"

### Critérios de aceite

- [ ] `bun run db:migrate` roda sem erro
- [ ] `bun run typecheck` passa em todos os workspaces
- [ ] Schemas Zod exportados de `@projeto/shared` sem erro de import
- [ ] Rota `GET /api/[x]` retorna 200 com dados mock
- [ ] Página `[/x]` renderiza sem erro no browser
- [ ] 1 teste de integração confirmando que a rota existe e retorna 200

---

## Fase 1: [Nome descritivo — o que o usuário consegue fazer]

> Ao final desta fase: [frase de uma linha descrevendo o que fica demonstrável. Ex: "É possível criar clientes e ver a lista completa na tela."]

**Histórias cobertas:**
- História #N do PRD: "Como [ator], quero [funcionalidade]..."
- História #M do PRD: "Como [ator], quero [funcionalidade]..."

**Depende de:** Fase 0 concluída

### Entidades e tabelas tocadas

| Tabela | Operação | Observação |
|--------|----------|------------|
| `[nome]` | INSERT, SELECT | [ex: paginado, 20 por página] |

### Endpoints a implementar

Contrato completo no PRD — aqui listamos apenas o escopo desta fase:

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| POST | `/api/[rota]` | autenticado | [descrição curta] |
| GET | `/api/[rota]` | autenticado | [descrição curta + query params relevantes] |

### Telas e componentes a construir

**Tela: [Nome da tela] — `[/rota-no-frontend]`**
- Componente de listagem com [N] colunas
- Estado vazio: [texto do PRD — ex: "Nenhum cliente cadastrado" + botão "Criar primeiro"]
- Paginação no rodapé
- Botão "[Ação]" → abre modal/drawer

**Modal/Drawer: [Nome]**
- Formulário com campos: [listar campos do PRD]
- Validação inline (schema compartilhado via zodResolver)
- Toast de sucesso: "[mensagem]"
- Tratamento de erro [código]: [mensagem]

### Como demonstrar ao final desta fase

1. Abrir `[/rota]` no browser
2. Verificar que a tela aparece com estado vazio e CTA
3. Clicar em "[ação]" e preencher o formulário
4. Confirmar que o registro aparece na lista
5. Verificar paginação (se houver dados suficientes)

### Critérios de aceite

**Funcionais** (comportamento do usuário):
- [ ] [Critério extraído dos Critérios de Aceite do PRD, relevante a esta fase]
- [ ] [Critério de estado vazio/erro]
- [ ] [Critério de validação]

**Técnicos** (padrões obrigatórios):
- [ ] Endpoints retornam `{ data }` / `{ error, code }` conforme CLAUDE.md
- [ ] Endpoints sem auth retornam 401
- [ ] Cobertura de testes >= 95% nas rotas e handlers novos
- [ ] `bun run typecheck` e `bun run lint` passam

**Risco desta fase:** [risco do PRD que se torna real nesta fase, se houver. Omitir se não houver.]

---

## Fase 2: [Nome descritivo]

> Ao final desta fase: [frase demonstrável]

**Histórias cobertas:**
- História #N do PRD: "..."

**Depende de:** Fase 1 concluída [+ explicação se a dependência não for óbvia: "porque o formulário de [X] precisa buscar [Y] para o campo de seleção"]

### Entidades e tabelas tocadas

| Tabela | Operação | Observação |
|--------|----------|------------|

### Endpoints a implementar

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|

### Telas e componentes a construir

[Lista concreta]

### Como demonstrar ao final desta fase

1. [Passos]

### Critérios de aceite

**Funcionais:**
- [ ] ...

**Técnicos:**
- [ ] Endpoints sem permissão retornam 403
- [ ] Cobertura de testes >= 95% nas rotas e handlers novos
- [ ] `bun run typecheck` e `bun run lint` passam

<!-- Repetir para cada fase adicional -->

---

## Checklist de entrega do MVP

> Marcar apenas quando TODOS os critérios de aceite de todas as fases estiverem verdes.

- [ ] Todas as histórias de Prioridade Alta do PRD implementadas
- [ ] CI verde (lint, typecheck, testes, cobertura >= 95%)
- [ ] Deploy de staging validado
- [ ] Smoke test manual seguindo os "Como demonstrar" de cada fase
- [ ] PRD atualizado com decisões que mudaram durante a implementação

## Pós-MVP (não implementar agora)

Extraído das seções "Prioridade Média" e "Prioridade Baixa" do PRD:

- [História de Prioridade Média — copiar do PRD]
- [História de Prioridade Baixa — copiar do PRD]

**Criar PRD separado antes de implementar qualquer item desta lista.**

## Fora do Escopo

[Copiar da seção "Fora do Escopo" do PRD — manter como lembrete contra scope creep.]

</template-plano>

---

## Passo 5.5 — Sincronização com `docs/backlog.md`

Após escrever o plano em `plans/<feature>-plano.md`, o `project-manager` agent deve sincronizar com `docs/backlog.md`. Cada **Fase** do plano se mapeia a uma **Wave** do backlog:

- **Fase 0 — Fundação** → NÃO vira wave (é setup, não entrega ao cliente). USs dessa fase caem em `## Wave: Backlog`.
- **Fase 1+** → cada fase vira uma wave com nome descritivo extraído do título da fase (ex: "Fase 1 — Cadastro de clientes" → `## Wave: Cadastro de clientes`).

Instruções ao PM agent (ao sintetizar o backlog):

1. Para cada história MVP de uma Fase (exceto Fase 0), criar uma US em `docs/backlog.md` sob `## Wave: <nome-da-fase>`.
2. Histórias de "Prioridade Média/Baixa" do PRD (pós-MVP) vão para `## Wave: Backlog`.
3. Cada wave começa com blockquote `> Milestone GitHub: \`<nome>\` · Meta: <descrição de 1 linha da fase>`.
4. USs mantêm a prioridade P1/P2/P3 extraída do PRD (dentro da mesma wave).
5. Ordem das waves no backlog: mesma ordem das Fases no plano (Fase 1 primeiro, Fase N último, Backlog no final).

**Exemplo de geração:**

Plano tem Fase 1 ("Cadastro de clientes") com 2 histórias MVP, Fase 2 ("Dashboard") com 1 história MVP, e o PRD tem 1 história de Prioridade Média.

`docs/backlog.md` resultante:

```markdown
## Wave: Cadastro de clientes
> Milestone GitHub: `Cadastro de clientes` · Meta: usuário consegue criar e listar clientes

### US-1 — Criar cliente
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente
Tasks:
- [ ] TASK-1.1: ...

### US-2 — Listar clientes
**Prioridade:** P1  ·  **Estimativa:** 3  ·  **Status:** pendente
Tasks:
- [ ] TASK-2.1: ...

## Wave: Dashboard
> Milestone GitHub: `Dashboard` · Meta: usuário visualiza indicadores principais

### US-3 — KPIs cards
**Prioridade:** P1  ·  **Estimativa:** 5  ·  **Status:** pendente
Tasks:
- [ ] TASK-3.1: ...

## Wave: Backlog
> Sem milestone atribuída. Mover para wave concreta ao priorizar.

### US-10 — Exportar relatório (pós-MVP)
**Prioridade:** P2  ·  **Estimativa:** 5  ·  **Status:** pendente
Tasks:
- [ ] TASK-10.1: ...
```

Após gerar `docs/backlog.md`, o fluxo esperado é:
1. `./setup-github-project.sh` (se ainda não rodado) → cria milestones das waves
2. `./sync-github-issues.sh` → cria issues associadas às milestones corretas

---

## Passo 6 — Revisão final

Após escrever o plano, apresente ao usuário:

1. Um **resumo executivo** (5-10 bullet points em linguagem simples):

> "Pronto! Escrevi o plano em `plans/[arquivo]-plano.md`.
>
> Resumo:
> - O plano tem **[N] fases** para construir [feature]
> - A Fase 0 prepara [resumo da fundação]
> - A Fase 1 entrega [resumo demonstrável]
> - A Fase 2 entrega [resumo demonstrável]
> - [...]
> - No total, cobre todas as [N] histórias de Alta prioridade do PRD
> - Histórias de Média e Baixa ficaram no Pós-MVP
>
> Esse plano captura tudo o que discutimos? Quer ajustar alguma coisa?"

2. Se o usuário pedir mudanças, atualize o plano e re-apresente o resumo
3. Só considere o plano finalizado com aprovação explícita do usuário

4. Após aprovação, ofereça o próximo passo:

> "Para começar a Fase 0 agora, é só me dizer. Eu abro o plano, leio a primeira fase e te guio na implementação passo a passo."

---

## Notas para o assistente

### Idioma e tom
- Toda comunicação e o documento final devem ser em **português do Brasil**
- Tom: acolhedor, prático, paciente. Nunca interrogatório
- Evite jargões técnicos nas perguntas ao usuário. Use-os apenas no documento final onde necessário
- "Fatia vertical" pode ser usado **uma vez** na primeira menção, sempre acompanhado de explicação simples: "uma fatia vertical — ou seja, um pedaço fino que passa por todas as camadas ao mesmo tempo"
- "Tracer bullet" **nunca** aparece em texto ao usuário — é terminologia interna da skill
- Metáforas de construção (casa, fundação, paredes) ajudam a explicar sequência e dependência
- Uma pergunta por vez. Nunca despeje uma lista de perguntas

### Referência ao PRD, não duplicação
- O plano **referencia** o PRD como fonte de verdade — não duplica modelo de dados completo, contrato de API completo, ou fluxos de usuário detalhados
- Nas fases, listar endpoints por método + rota (ex: `POST /api/clientes`) mas direcionar ao PRD para o contrato completo
- Critérios de aceite do plano são **por fase** (mais granulares que os do PRD, que são por feature)
- Exceção: copiar literalmente "Fora do Escopo" do PRD para o plano como lembrete contra scope creep

### Decisões duráveis vs detalhes de implementação

**INCLUIR no plano** (decisões duráveis que não mudam entre fases):
- Nomes de rotas (`/api/clientes`)
- Nomes de tabelas (`clientes`, `pedidos`)
- Nomes de entidades e schemas (`clienteSchema`)
- Decisões arquiteturais próprias (soft delete vs hard delete, sync vs async)

**NÃO INCLUIR no plano** (detalhes que ficam desatualizados):
- Caminhos de arquivo (`apps/api/src/routes/clientes.ts`)
- Nomes de função (`createClienteHandler`)
- APIs específicas de lib (`createInsertSchema`, `sValidator`)
- Qualquer coisa que o CLAUDE.md já define (formato de response, paginação padrão, etc.)

### Heurística de dependência para ordem das fases

Ao analisar o PRD para determinar a ordem:

1. **Tabelas sem FK** → schema vai na Fase 0
2. **Tabelas com FK para tabelas da Fase 0** → candidatas para Fase 1
3. **Tabelas com FK para tabelas da Fase 1** → candidatas para Fase 2
4. **Teste da demo**: o usuário consegue demonstrar essa fase para alguém? Se não, juntar com a próxima
5. **Verificação transversal**: essa fase introduz um novo papel de permissão, novo fluxo de auth, ou novo padrão de componente compartilhado? Se sim, deve ser fase standalone ou ir para Fase 0/1, nunca postergada

### Fase 0 é obrigatória quando há banco de dados

Quase todo PRD toca o banco. A Fase 0 garante que o monorepo compila e o CI passa com os novos paths — mesmo que a lógica ainda seja stub. É o tracer bullet na forma mais pura.

Se o projeto já tem as tabelas e rotas da feature (porque alguém começou antes), a Fase 0 pode ser pulada ou reduzida.

### Naming do arquivo de plano

PRD em `plans/gestao-de-clientes.md` → Plano em `plans/gestao-de-clientes-plano.md`

Isso pareia os arquivos visualmente em qualquer listagem ordenada e torna a linhagem óbvia.

### Sweet spot de fases

Para um PRD típico com 5-8 histórias MVP:

- **Fase 0**: fundação (schema + infra)
- **Fase 1**: fluxo principal (criar + listar) — a parte mais visível
- **Fase 2**: completar CRUD (editar + deletar + permissões) ou segunda entidade
- **Fase 3**: refinamentos (busca, filtros, ordenação, estados de erro detalhados)

**3-4 fases** é o sweet spot. Mais de 5 fragmenta demais e cria ansiedade de "progresso lento". Menos de 3 cria fases densas demais para executar de uma vez.

Mais de 4 fases só se o MVP tiver 2 domínios independentes (ex: gestão de clientes + relatórios). Nesse caso, considerar se não deveria ser 2 PRDs separados.

### Técnicas de entrevista para vibecoders

- **Múltipla escolha**: quando o usuário não souber responder sobre granularidade, ofereça 2-3 opções concretas
- **Metáforas de construção**: "é como construir uma casa — primeiro a fundação, depois as paredes"
- **Linguagem de demo**: "ao terminar essa fase, você abre o sistema e consegue [X]" — torna a fatia tangível
- **Validação antes de correção**: quando o usuário sugere algo que cria conflito técnico, primeiro reconheça o raciocínio ("entendo, faz sentido querer isso primeiro") e depois explique a restrição com metáfora
- **Estacionamento**: se durante a revisão o usuário pedir algo novo que não está no PRD, sugira atualizar o PRD primeiro

### Feature grande demais

Se ao analisar o PRD o número de fases passar de 5-6, sugira dividir em planos separados: "Esse PRD é grande. Sugiro dois planos: um para [domínio A] e outro para [domínio B]. Assim cada plano fica focado e executável. Quer dividir?"

### Conexão com execução

O plano é projetado para ser consumido por um AI coding assistant (como o próprio Claude Code). Cada fase tem informação suficiente para que o assistente saiba exatamente o que construir sem precisar re-ler o PRD inteiro — mas referencia o PRD para os detalhes completos (contrato de API, modelo de dados).

### Contrato de API é obrigatório nas fases

Se a fase tem endpoints, eles devem estar listados na tabela com método + rota + auth. Isso alinha frontend e backend antes do código. O contrato completo (request/response/erros) fica no PRD — o plano só lista o escopo.
