---
name: novo-prd
description: Cria um PRD (Produto — Documento de Requisitos) através de entrevista guiada com o usuário
user-invocable: true
---

Esta skill é invocada quando o usuário quer criar um PRD (Produto — Documento de Requisitos). Siga os passos abaixo **em ordem**. O público-alvo são pessoas com pouca bagagem técnica — conduza a conversa de forma acolhedora, prática e sem jargões desnecessários.

Toda a comunicação deve ser em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de fazer qualquer pergunta:

1. Leia o `CLAUDE.md` do projeto (se existir) para entender stack, regras e restrições arquiteturais
2. Explore a estrutura de diretórios do repositório (top-level: `apps/`, `packages/`, etc.)
3. Verifique se existem PRDs anteriores em `plans/*.md`
4. Identifique módulos, rotas, schemas e telas que já existem

Use esse contexto para fazer perguntas mais inteligentes nos passos seguintes. Nunca pergunte ao usuário algo que você já pode descobrir lendo o repositório.

---

## Passo 1 — Coleta inicial

Comece com uma abertura calorosa e de baixa pressão:

> "Me conta o que você quer construir, do jeito que vier na cabeça. Pode ser uma ideia vaga, um problema que você quer resolver, ou até uma referência tipo 'quero algo parecido com o Notion'."

**Regras desta etapa:**

- Faça **uma pergunta por vez**. Nunca despeje uma lista de perguntas
- Use linguagem simples — evite termos como "persona", "caso de uso", "endpoint"
- Se o usuário for vago, ofereça exemplos concretos ou múltipla escolha em vez de insistir genericamente
- Extraia progressivamente (em perguntas separadas):
  - Qual o problema ou necessidade que motivou isso
  - Quem vai usar (só o próprio usuário? outros papéis?)
  - Ideias iniciais de como deveria funcionar (se houver)
  - Se já existe algo parcialmente implementado ou uma referência visual

**Não avance** sem entender o problema com profundidade. Mas "profundidade" não significa "todos os detalhes técnicos" — significa entender claramente o que o usuário quer alcançar.

---

## Passo 2 — Reconhecimento do codebase

Explore o repositório para:

- Verificar as afirmações do usuário sobre o estado atual
- Entender a estrutura existente (quais módulos, rotas, schemas, telas já existem)
- Identificar quais camadas serão afetadas (API, Web, Shared, banco de dados)
- **Buscar features similares ou sobrepostas** que já existam (parcial ou completamente)
- **Verificar PRDs anteriores** em `plans/*.md` que possam se sobrepor

Se o projeto seguir a estrutura de monorepo (`apps/api`, `apps/web`, `packages/shared`), use essa estrutura para guiar suas perguntas.

Se encontrar algo relevante (feature existente, PRD anterior, código parcialmente implementado), informe o usuário: "Encontrei [X] que parece relacionado ao que você descreveu. É algo que você quer estender, substituir, ou a sua ideia é diferente?"

---

## Passo 3 — Entrevista estruturada

Conduza a entrevista em **3 rodadas**, cada uma focada em um nível de profundidade. Ao final de cada rodada, apresente um mini-resumo do que foi decidido e peça confirmação antes de avançar.

### Rodada 1 — Jornada do Usuário

Percorra o fluxo da feature como uma **história**. Use a técnica de wireframe verbal — descreva telas para o usuário confirmar:

> "Imagina que você abre o sistema e vê uma lista com todos os clientes. No topo tem um campo de busca e um botão 'Novo Cliente'. Quando clica no botão, abre um formulário pedindo nome, email e telefone. Faz sentido? É mais ou menos isso que você imagina?"

Cubra neste momento:
- O que o usuário vê em cada tela principal
- Quais ações ele pode tomar (criar, editar, listar, deletar, buscar, filtrar)
- Como navega entre telas (é uma página nova? modal? drawer?)
- O que acontece após cada ação (mensagem de sucesso, volta pra lista, etc.)

**Resumir e confirmar** antes de avançar para a Rodada 2.

### Rodada 2 — Decisões de produto

Para cada entidade/conceito identificado na Rodada 1, resolva:

- **Permissões**: quem pode ver? quem pode editar? quem pode deletar?
- **Estados e ciclo de vida**: o registro pode ser desativado? arquivado? tem status que muda?
- **Dados obrigatórios vs opcionais**: quais campos são obrigatórios na criação?
- **Validações**: algum campo tem formato específico? (email, telefone, CPF, etc.)
- **Volumes esperados**: dezenas? milhares? milhões? (impacta paginação e busca)
- **Notificações**: alguém precisa ser avisado quando algo acontece?

**Técnicas para esta rodada:**
- Ofereça **2-3 opções** quando o usuário não souber responder (ex: "Quer que qualquer usuário possa deletar, ou só o admin? A maioria dos sistemas restringe ao admin.")
- Para decisões técnicas que o CLAUDE.md já define (ex: paginação padrão, formato de response), **use o default sem perguntar** — apenas informe se relevante
- Se o usuário não souber responder após 2 tentativas, registre como **premissa** com nota de validação pendente

**Resumir e confirmar** antes de avançar para a Rodada 3.

### Rodada 3 — Casos extremos e escopo

Desafie gentilmente as premissas:

- "E se a lista estiver vazia? O que o usuário deveria ver?"
- "E se alguém tentar cadastrar um email que já existe?"
- "E se dois usuários editarem o mesmo registro ao mesmo tempo?"
- "Esse dado pode ser deletado de verdade ou é melhor desativar?"

Cubra neste momento:
- Estados vazios e de erro
- Conflitos e concorrência (se aplicável)
- O que acontece com dados relacionados quando algo é deletado

**Fechamento de escopo — obrigatório antes de avançar:**

1. Defina o que é **MVP** (o mínimo para a primeira entrega funcionar)
2. Defina o que é **pós-MVP** (melhorias para depois)
3. Defina o que está **fora do escopo** (não faz parte desta feature)

Se durante a entrevista ficar claro que a feature é grande demais para um único PRD, sugira dividir: "Essa feature tem pelo menos duas entregas independentes: [X] e [Y]. Sugiro criar um PRD para cada. Quer começar por qual?"

**Estacionamento de ideias**: quando o usuário mencionar algo tangencial, diga: "Boa ideia! Vou anotar isso na seção 'Fora do Escopo' para não perder, e podemos fazer um PRD separado depois. Agora vamos focar em [feature principal]."

### Checklist obrigatório (cobrir TODOS antes de avançar)

- [ ] CRUD completo para cada entidade identificada
- [ ] Modelo de permissões (quem pode fazer o quê)
- [ ] Campos e validações de cada entidade
- [ ] Estados vazios e de erro para cada tela
- [ ] Busca, filtros e ordenação (se houver listas)
- [ ] Relações entre entidades
- [ ] Features existentes que interagem com esta
- [ ] O que está explicitamente fora do escopo
- [ ] Definição de MVP vs pós-MVP
- [ ] Processamento assíncrono (se houver operações pesadas: envio de email, geração de relatório, etc.)

---

## Passo 4 — Resumo para aprovação

Antes de escrever o PRD, apresente um **resumo em linguagem simples** cobrindo:

1. O problema que estamos resolvendo (2-3 frases)
2. Como vai funcionar (fluxo principal em bullet points)
3. As histórias mais importantes (MVP)
4. O que ficou de fora
5. Decisões-chave que foram tomadas

Peça confirmação explícita: "Esse resumo reflete o que você quer? Quer mudar ou adicionar algo antes de eu montar o documento completo?"

**Nunca assuma aprovação.** Só avance para o Passo 5 com um "sim" claro.

---

## Passo 5 — Escrita do PRD

Escreva o PRD no arquivo `plans/<nome-do-prd>.md` usando o template abaixo.

O nome do arquivo deve ser descritivo e em kebab-case (ex: `gestao-de-clientes.md`, `dashboard-financeiro.md`).

<template-prd>

# [Nome da Feature]

> Implementação deve seguir todas as regras do `CLAUDE.md` do projeto.

## Declaração do Problema

O problema que o usuário enfrenta, descrito da perspectiva do usuário. Incluir o contexto e a motivação — por que isso é importante agora.

## Solução Proposta

Descrição clara da solução, da perspectiva do usuário. O que muda na experiência dele? Como o sistema se comporta depois da implementação?

## Histórias de Usuário

### Prioridade Alta (MVP — primeira entrega)

1. Como **[ator]**, quero **[funcionalidade]**, para que **[benefício]**

### Prioridade Média (pós-MVP)

1. Como **[ator]**, quero **[funcionalidade]**, para que **[benefício]**

### Prioridade Baixa (futuro)

1. Como **[ator]**, quero **[funcionalidade]**, para que **[benefício]**

<exemplo>
### Prioridade Alta (MVP)
1. Como gerente financeiro, quero visualizar o saldo consolidado de todas as contas, para que eu possa tomar decisões sobre gastos
2. Como administrador, quero cadastrar novas contas bancárias, para que elas apareçam no saldo consolidado

### Prioridade Média (pós-MVP)
3. Como gerente financeiro, quero exportar o relatório em PDF, para que eu possa compartilhar com a diretoria

### Prioridade Baixa (futuro)
4. Como administrador, quero integrar com a API do banco, para que os saldos sejam atualizados automaticamente
</exemplo>

## Modelo de Dados

Para cada entidade nova ou alterada, definir a estrutura usando a tabela abaixo. Não usar sintaxe de código — descrever em linguagem estruturada.

### Tabela: [nome_da_tabela]

| Coluna | Tipo | Obrigatório | Único | Default | Referência |
|--------|------|-------------|-------|---------|------------|
| id | uuid | sim | sim | random() | - |
| createdAt | timestamp | sim | não | now() | - |
| updatedAt | timestamp | sim | não | now() | - |

**Índices:** [listar colunas que precisam de índice e tipo (unique, btree, etc.)]
**Cascade:** [listar comportamento de FK on delete — CASCADE, SET NULL, RESTRICT]
**Enums:** [listar enums com seus valores, ex: status = draft | published | archived]

<exemplo>
### Tabela: clientes

| Coluna | Tipo | Obrigatório | Único | Default | Referência |
|--------|------|-------------|-------|---------|------------|
| id | uuid | sim | sim | random() | - |
| nome | text | sim | não | - | - |
| email | text | sim | sim | - | - |
| telefone | text | não | não | - | - |
| status | enum(ativo,inativo) | sim | não | 'ativo' | - |
| organizacaoId | uuid | sim | não | - | organizacoes.id |
| avatarUrl | text | não | não | null | - |
| createdAt | timestamp | sim | não | now() | - |
| updatedAt | timestamp | sim | não | now() | - |

**Índices:** email (unique), organizacaoId (btree)
**Cascade:** organizacaoId ON DELETE CASCADE
**Enums:** status = ativo | inativo
</exemplo>

## Fluxos de Usuário

Para cada fluxo principal, descrever a sequência de interações do usuário com o sistema.

### [Nome do fluxo]

1. [Trigger: o que o usuário faz para iniciar]
2. [O que o sistema mostra / tipo de UI: página, modal, drawer]
3. [Ações disponíveis]
4. [Comportamento de sucesso: o que acontece após a ação]
5. [Comportamento de erro: o que acontece se der errado]

<exemplo>
### Criar cliente

1. Na tela de listagem, usuário clica "Novo Cliente"
2. Abre modal com formulário (nome, email, telefone)
3. Validação inline nos campos (email obrigatório e válido, nome obrigatório)
4. Sucesso: modal fecha, lista atualiza, toast "Cliente criado com sucesso"
5. Erro 409 (email duplicado): mensagem inline no campo email "Este email já está cadastrado"

### Listar clientes

1. Tela principal mostra tabela com clientes paginados (20 por página)
2. Campo de busca filtra por nome ou email (debounce, via query param `?search=`)
3. Filtro por status via dropdown (via query param `?status=`)
4. Paginação no rodapé da tabela
5. Estado vazio: ilustração + texto "Nenhum cliente cadastrado" + botão "Criar primeiro cliente"
</exemplo>

## Contrato de API

Para cada endpoint novo, definir:

### [MÉTODO] [rota]

**Autenticação:** público | autenticado | admin
**Request body / Query params:**
```json
{ "campo": "tipo (obrigatório/opcional) — regra de validação" }
```
**Response de sucesso [status]:**
```json
{ "data": { ... } }
```
**Erros:**
| Status | Code | Quando |
|--------|------|--------|
| 400 | VALIDATION_ERROR | campos inválidos |

<exemplo>
### POST /api/clientes

**Autenticação:** autenticado
**Request body:**
```json
{
  "nome": "string (obrigatório) — mín 2, máx 100 caracteres",
  "email": "string (obrigatório) — formato email válido",
  "telefone": "string (opcional) — formato telefone brasileiro"
}
```
**Response 201:**
```json
{ "data": { "id": "uuid", "nome": "string", "email": "string", "telefone": "string | null", "status": "ativo", "createdAt": "datetime" } }
```
**Erros:**
| Status | Code | Quando |
|--------|------|--------|
| 400 | VALIDATION_ERROR | campos inválidos ou ausentes |
| 409 | DUPLICATE_EMAIL | email já cadastrado |

### GET /api/clientes

**Autenticação:** autenticado
**Query params:** `page` (int, default 1), `limit` (int, default 20, máx 100), `search` (string, opcional), `status` (enum, opcional)
**Response 200:**
```json
{ "data": [...], "pagination": { "page": 1, "limit": 20, "total": 87, "totalPages": 5 } }
```
**Erros:**
| Status | Code | Quando |
|--------|------|--------|
| 400 | VALIDATION_ERROR | query params inválidos |
</exemplo>

## Permissões

Matriz de quem pode fazer o quê. Listar todos os papéis e ações relevantes.

| Ação | [Papel 1] | [Papel 2] | [Papel 3] |
|------|-----------|-----------|-----------|
| [ação] | sim/não | sim/não | sim/não |

<exemplo>
| Ação | Admin | Membro |
|------|-------|--------|
| Listar clientes | sim | sim |
| Ver detalhes | sim | sim |
| Criar cliente | sim | sim |
| Editar cliente | sim | apenas os próprios |
| Deletar/desativar cliente | sim | não |
| Exportar lista | sim | não |
</exemplo>

## Módulos Afetados

Quais partes do sistema serão criadas ou modificadas:

- **API**: endpoints novos ou modificados (listar)
- **Frontend**: telas/componentes novos ou modificados (listar)
- **Shared**: schemas/tipos novos ou modificados (listar)

(Modelo de dados já detalhado na seção "Modelo de Dados" acima.)

## Decisões Arquiteturais

Lista de decisões técnicas e arquiteturais tomadas durante a entrevista. Incluir apenas decisões genuínas — não repetir o que o CLAUDE.md já define.

Pode incluir:
- Módulos que serão criados ou modificados
- Interfaces e contratos entre módulos
- Decisões arquiteturais (ex: processamento síncrono vs assíncrono)
- Estratégia de migração (se alterar tabelas existentes com dados)
- Processamento em background (se houver operações pesadas — especificar qual tier: fire-and-forget, tabela de jobs, ou fila robusta)

NÃO incluir caminhos de arquivos específicos ou trechos de código — ficam desatualizados rapidamente.

## Critérios de Aceite

Lista verificável que define quando a feature está **pronta**. Cada critério deve ser testável objetivamente.

<exemplo>
- [ ] Usuário consegue criar cliente com nome e email
- [ ] Sistema rejeita email duplicado com mensagem clara
- [ ] Admin consegue listar todos os clientes com paginação
- [ ] Busca por nome filtra resultados em tempo real
- [ ] Campos opcionais (telefone, avatar) aceitam null sem erro
- [ ] Endpoints protegidos retornam 401 sem autenticação
- [ ] Endpoints retornam respostas no formato padrão (`{ data }` / `{ error, code }`)
- [ ] Estado vazio mostra mensagem amigável + CTA para criar primeiro registro
- [ ] Membro não consegue deletar cliente (403)
</exemplo>

## Definição de MVP

**O que DEVE funcionar na primeira entrega:**
- [lista mínima de funcionalidades]

**O que pode esperar para uma segunda iteração:**
- [lista de melhorias futuras]

## Riscos e Dependências

- **Riscos**: o que pode dar errado ou complicar a implementação
- **Dependências**: features, serviços ou decisões que precisam estar prontas antes
- **Premissas**: o que estamos assumindo como verdade (e que, se mudar, invalida parte do plano)

## Fora do Escopo

Descrição explícita do que **não** faz parte desta entrega. Importante para evitar scope creep.

## Notas Adicionais

Qualquer informação complementar relevante: referências visuais, benchmarks, links para discussões, etc.

</template-prd>

---

## Passo 6 — Revisão final

Após escrever o PRD, apresente ao usuário:

1. Um **resumo executivo** do documento (5-10 bullet points em linguagem simples)
2. Pergunte: "Esse documento captura tudo o que discutimos? Quer ajustar alguma coisa?"
3. Se o usuário pedir mudanças, atualize o PRD e re-apresente o resumo
4. Só considere o PRD finalizado com aprovação explícita do usuário

---

## Notas para o assistente

### Idioma e tom
- Toda comunicação e o documento final devem ser em **português do Brasil**
- Tom: acolhedor, prático, paciente. Nunca interrogatório
- Evite jargões técnicos nas perguntas ao usuário. Use-os apenas no documento final onde necessário

### Diretório de saída
- Sempre salvar em `plans/`. Criar o diretório se não existir

### Sem prescrição de stack
- O PRD não deve ditar tecnologias — isso é responsabilidade do `CLAUDE.md` do projeto
- Decisões de implementação devem ser sobre arquitetura e comportamento, não sobre qual lib usar
- Para decisões técnicas que o CLAUDE.md já cobre (formato de response, paginação padrão, state management, etc.), **use o default sem perguntar ao usuário**

### Classificação de seções do template

**Seções que exigem validação do usuário** (apresentar em linguagem simples):
- Declaração do Problema, Solução Proposta, Histórias de Usuário, Fluxos de Usuário, Permissões, Fora do Escopo, Definição de MVP

**Seções que o assistente auto-gera** (apresentar apenas um resumo simplificado ao usuário):
- Modelo de Dados, Contrato de API, Módulos Afetados, Decisões Arquiteturais, Critérios de Aceite

### Técnicas de entrevista para vibecoders

- **Wireframe verbal**: descrever telas imaginadas para o usuário confirmar ("Imagina uma tabela com todos os pedidos. No topo tem um campo de busca e um botão 'Novo Pedido'. Quando clica, abre um formulário...")
- **Múltipla escolha**: quando o usuário não souber responder, ofereça 2-3 opções concretas com prós/contras simplificados
- **Defaults do projeto**: para decisões técnicas cobertas pelo CLAUDE.md, use o default e apenas informe se for relevante para o usuário
- **Fallback para vagueza**: se após 2 tentativas o usuário não conseguir detalhar um aspecto, registre como **premissa** no PRD com nota "[pendente validação]"
- **Estacionamento de ideias**: quando o usuário mencionar algo tangencial, diga que vai anotar em "Fora do Escopo" para não perder, e redirecione para o foco atual
- **Detecção de escopo excessivo**: se a feature se decompõe em 2+ entregas independentes, sugira dividir em PRDs separados. Um PRD = uma entrega deployável

### Contrato de API é obrigatório
- Se a feature tem endpoints, o contrato deve estar no PRD. Isso alinha frontend e backend antes do código
- Incluir autenticação por endpoint, query params para GETs, e códigos de erro com string `code`

### Entrevista > suposição
- Na dúvida, pergunte. Nunca invente requisitos que o usuário não mencionou
- Mas para decisões **técnicas** (não de produto), resolva usando o CLAUDE.md sem perguntar
