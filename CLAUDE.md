# CLAUDE.md — Orquestrador do Projeto

> **Este é o ponto de entrada.** O Claude lê este arquivo automaticamente ao iniciar.
> Os demais arquivos são lidos **sob demanda** — nunca todos de uma vez.
>
> ### Quando ler cada arquivo
>
> | Arquivo | Ler quando... |
> |---|---|
> | `claude-sdd.md` | O fluxo exigir geração de spec (triage resultou em "gerar spec") |
> | `claude-subagents.md` | For delegar task para subagente via Task tool |
> | `claude-stacks.md` | Precisar de regras de stack, estrutura do monorepo ou padrões técnicos |
> | `claude-stacks-refactor.md` | Precisar de padrões de implementação, aprendizados ou regras complementares |
> | `claude-debug.md` | Bug fix, troubleshooting, teste falhando após 2 tentativas, CI quebrando |
> | `claude-design.md` | Task envolver criação ou modificação de componentes frontend |
> | `docs/design-system/design-brief.md` | Montar prompt de subagente de componente (injetar no contexto do component-agent) |
> | `docs/design-system/pages/*.md` | Montar prompt de subagente de componente para página com override |
> | `docs/user-stories.md` | O usuário referenciar uma story ou pedir para criar feature |
> | `docs/backlog.md` | O usuário pedir para continuar, executar task ou verificar progresso |
> | `docs/specs/US-XX-nome.spec.md` | Implementar uma story que já tem spec gerado |
>
> **Nunca abrir todos os arquivos preventivamente.** Ler apenas o necessário para a ação atual.
>
> Em caso de conflito, a hierarquia é: `CLAUDE.md` > `claude-sdd.md` > `claude-stacks.md` > `claude-debug.md` > `claude-design.md` > `claude-stacks-refactor.md` > `docs/*`
Para decisões visuais de projeto, `docs/design-system/MASTER.md` prevalece sobre `claude-design.md`. Para decisões estruturais (acessibilidade, responsividade, estados obrigatórios), `claude-design.md` prevalece.
---

## 🧭 Metodologia

Este projeto segue **XP (Extreme Programming)** com **TDD (Test-Driven Development)** rigoroso e **SDD (Spec Driven Development)** como camada de planejamento técnico.

### Princípios inegociáveis

- **Spec antes de código**: toda feature com contrato novo exige um spec aprovado antes da implementação.
- **Red → Green → Refactor**: nenhum código de produção é escrito sem um teste falhando primeiro.
- **Baby steps**: cada ciclo TDD deve ser o menor possível. Sem antecipar funcionalidades.
- **YAGNI** (You Ain't Gonna Need It): não implementar o que não está na story atual.
- **KISS**: soluções simples e legíveis antes de soluções "elegantes".
- **DRY**: eliminar duplicação, mas somente após o Green — nunca durante o Red.
- **Contexto mínimo**: subagentes recebem apenas o necessário do spec — nunca o codebase inteiro.

---

## 📁 Estrutura de orquestração

```
/
├── CLAUDE.md                 ← este arquivo (auto-carregado pelo Claude Code)
├── claude-sdd.md             ← Spec Driven Development (ler sob demanda: triage → spec)
├── claude-subagents.md       ← Orquestração de subagentes (ler sob demanda: delegação)
├── claude-stacks.md          ← stack base e padrões técnicos (ler sob demanda: implementação)
├── claude-stacks-refactor.md ← extensões e aprendizados (ler sob demanda: implementação)
├── claude-design.md          ← regras estruturais de UI/UX (ler sob demanda: tasks de frontend)
├── claude-debug.md           ← protocolo de debugging sistemático (ler sob demanda: bug fix, troubleshooting)
├── docs/
│   ├── user-stories.md       ← histórias de usuário + critérios de aceite
│   ├── backlog.md            ← backlog XP: stories, tasks e testes planejados
│   ├── specs/                ← specs SDD por story (US-XX-nome.spec.md)
│   └── design-system/        ← design system do projeto
│       ├── MASTER.md         ← tokens visuais, paleta, tipografia, overrides (fonte de verdade visual)
│       ├── design-brief.md   ← resumo compacto (~800 tokens) para injeção em subagentes
│       └── pages/            ← overrides por página (quando necessário)
```

> A estrutura completa do monorepo (apps/, packages/, configs) está definida em `claude-stacks.md`.
> **Não crie pastas ou arquivos fora do padrão sem consultar o stacks primeiro.**
> **Não abra arquivos além do necessário para a ação atual** — cada leitura consome tokens.

---

## 🎯 Prompts de entrada — como o usuário inicia o trabalho

O Claude deve interpretar o prompt do usuário e disparar o fluxo correto automaticamente. Abaixo estão os padrões reconhecidos:

### Iniciar projeto novo

```
Iniciar projeto novo
```

**Fluxo**: verificar se repo está vazio ou sem `apps/` → ler `start_project.md` → executar fases sequencialmente → ao completar todas as fases, perguntar se usuário quer rodar REQUIREMENTS.md para levantar as primeiras stories.

> Se o repositório já contém `apps/` ou `packages/shared/`, o projeto NÃO é novo — informar ao usuário e sugerir outro fluxo.

### Adotar workflow em projeto existente

```
Adotar workflow SDD/TDD neste projeto
```

**Fluxo**: verificar estrutura existente do repositório → identificar o que já existe (apps/, docs/, configs) → adaptar o `CLAUDE.md` ao projeto (ajustar paths, naming, stack existente) → criar `docs/` se não existir → perguntar se usuário quer rodar `REQUIREMENTS.md` para mapear stories existentes → perguntar se quer rodar `DESIGN_SYSTEM.md` para gerar o design system.

> Se o script `adopt-workflow.sh` já foi executado, os arquivos estruturais já estão no lugar.
> O Claude deve verificar e adaptar, não sobrescrever.

### Implementar feature (story existe)

```
Implementar a US-03 — Cadastro de Palestrantes
```

**Fluxo**: ler `docs/user-stories.md` → triage → (se spec necessário: ler `claude-sdd.md` → gerar spec → aprovação) → ler `claude-subagents.md` + `claude-stacks.md` → decompose → implement → validate → commit.

### Implementar feature (story ainda não existe)

```
Preciso de uma funcionalidade de importação de eventos via CSV. Criar a story e implementar.
```

**Fluxo**: criar story em `docs/user-stories.md` com critérios de aceite → **apresentar story para aprovação** → triage → (se spec necessário: ler `claude-sdd.md` → gerar spec → aprovação) → decompose → implement → validate → commit.

> Quando a story não existe, o agente cria e apresenta para aprovação **antes** do triage. São duas aprovações: story e spec.

### Refatoração

```
Refatorar o módulo de autenticação para extrair o middleware em arquivo separado
```

**Fluxo**: triage detecta que não há contrato novo → ler `claude-stacks.md` → TDD direto (sem spec, sem `claude-sdd.md`). Se a refatoração alterar um contrato existente (ex: mudar assinatura de função pública), o agente gera spec amendment.

### Continuar backlog de uma story

```
Continuar o backlog da US-03
```

**Fluxo**: ler `docs/backlog.md` → encontrar a **próxima task pendente** da US-03 → verificar se existe spec em `docs/specs/` (se sim, ler) → ler `claude-stacks.md` → executar task com TDD → validar → marcar como done no backlog → prosseguir para a próxima task pendente (ou informar que a story está concluída).

### Continuar backlog (sem story específica)

```
Continuar o backlog
```

**Fluxo**: ler `docs/backlog.md` → selecionar a **próxima task pendente por prioridade**:
1. Primeiro: tasks de stories **P1** (na ordem do backlog)
2. Depois: tasks de stories **P2**
3. Por último: tasks de stories **P3**

Dentro da mesma prioridade, respeitar ordem de dependência (schema → api → componente).
Apresentar a task selecionada e pedir confirmação antes de executar:

```
Próxima task por prioridade: TASK-3.2 (US-03 — P1)
Criar endpoint POST /events com validação Zod.
Posso executar?
```

> Se todas as tasks P1 estiverem concluídas ou bloqueadas, informar antes de avançar para P2.

### Executar task específica

```
Executar a task 3.2 do backlog
```

**Fluxo**: ler `docs/backlog.md` → localizar task 3.2 → se houver spec, localizar a seção correspondente → ler `claude-stacks.md` → executar com TDD → validar → marcar como done.

### Corrigir bug

```
Corrigir o erro 500 ao criar evento sem campo location
```

**Fluxo**: ler `claude-debug.md` → criar checkpoint git → seguir protocolo de 5 fases (reproduzir → isolar → diagnosticar → formular → corrigir) → commit.

> **Quando usar o protocolo completo vs TDD direto**:
> - Bug óbvio (typo, import errado, campo faltando): TDD direto
> - Bug que precisa de investigação (causa não óbvia, já tentou corrigir e não funcionou): protocolo completo
> - Após 2 tentativas falhas de fix em qualquer contexto: protocolo completo obrigatório

### Quando o prompt é ambíguo

Se o agente não conseguir determinar o fluxo correto (ex: "trabalhar no módulo de eventos"), ele deve perguntar **uma única vez**:

```
Encontrei a US-03 (Cadastro de Eventos) no backlog com 3 tasks pendentes.
Deseja que eu continue o backlog a partir da task 3.4, ou tem algo diferente em mente?
```

Nunca adivinhar — perguntar é mais barato que refazer.

---

## 📐 Fluxo SDD → TDD (automático, inline)

Quando o usuário pede para implementar uma story (ex: `Implementar a US-03`), o agente principal:

### Step 0: TRIAGE (automático, sem perguntar)

Avalia se a story introduz schemas, endpoints ou componentes com estado novos.
- **SIM** → **ler `claude-sdd.md`** → gerar spec (steps 1-4)
- **NÃO** (fix, refactor, config, task < 10 linhas) → **ler `claude-stacks.md`** → TDD direto

> A tabela de decisão completa está em `claude-sdd.md`. Na dúvida, gerar spec.

### Step 1: SPEC (se necessário)

> **Pré-requisito de leitura**: `claude-sdd.md` (templates e regras de spec)

1. Lê a User Story + estado atual do código (schemas, rotas, componentes)
2. Gera `docs/specs/US-XX-nome.spec.md` com contratos, cenários e checklist
3. **Apresenta o spec e aguarda aprovação explícita** — único ponto de pausa do fluxo
4. Se o usuário pedir ajustes, ajusta e re-apresenta. Não implementa sem "sim"

### Step 2: DECOMPOSE

> **Pré-requisito de leitura**: `claude-subagents.md` (tipos de subagente e prompt templates)

1. Decompõe o spec em tasks: schema → api → componente (ordem de dependência)
2. Cada task = 1 subagente (ver `claude-subagents.md`)
3. Atualiza `docs/backlog.md`

### Step 3: IMPLEMENT (subagentes)

> **Pré-requisito de leitura**: `claude-stacks.md` (para extrair regras aplicáveis ao prompt do subagente)
>
> **Se task de componente frontend**: ler também:
> - `claude-design.md` (regras estruturais de UI — acessibilidade, responsividade, estados)
> - `docs/design-system/design-brief.md` (resumo visual compacto — **injetar no prompt do subagente**)
> - `docs/design-system/pages/*.md` (se a página tiver override — **injetar no prompt do subagente**)
>
> O agente principal **NÃO** envia o `MASTER.md` inteiro ao subagente.
> O `design-brief.md` é o resumo otimizado (~800 tokens) que contém tudo que o component-agent precisa.
> Se o design brief não existir, o agente principal deve gerá-lo a partir do `MASTER.md` antes de delegar.

### Step 4: VALIDATE

1. `bun test` + `bun test --coverage` (≥ 80%) + `bun run lint` + `bun run typecheck`
2. Commit + atualizar backlog

> **Quando NÃO usar SDD**: tasks triviais (< 10 linhas, sem contrato novo), fixes, configs, refactors puros.
> Nesses casos, o agente segue direto para TDD sem gerar spec.

---

## 🔴🟢♻️ Fluxo TDD obrigatório

Para **cada tarefa** do backlog (com ou sem SDD), siga estritamente:

1. **RED**: Escreva o teste que descreve o comportamento esperado. Execute — deve falhar.
2. **GREEN**: Escreva o mínimo de código para o teste passar. Execute — deve passar.
3. **REFACTOR**: Melhore o código sem quebrar os testes. Execute — todos devem passar.
4. Faça commit ao final de cada ciclo completo Red→Green→Refactor.

> ⚠️ Nunca pule direto para o Green. Se o teste passou sem você escrever código, o teste está errado.

---

## 🧪 Padrões de teste

- **Runner único**: `bun test` — nenhum outro runner é permitido (ver `claude-stacks.md` → Testes).
- **Cobertura**: ≥ 80% line/function, enforced via quality gate (SonarQube).
- **Nomenclatura**: `*.test.ts` / `*.test.tsx` — não usar `.spec.ts`.
- Estrutura de cada teste:

```typescript
describe('NomeDaUnidade', () => {
  it('deve [comportamento esperado] quando [condição]', () => {
    // Arrange
    // Act
    // Assert
  });
});
```

- **Um assert por teste** sempre que possível.
- Testes devem ser independentes entre si — sem estado compartilhado.
- **Mocking**: mock Clerk, Resend e object storage nos testes. Nunca chamar APIs reais no CI.
- O que testar: utils, rotas API, services, schemas Zod, componentes React, workers pg-boss.
- **Cenários do spec**: quando houver spec, cada cenário listado deve ter pelo menos um teste correspondente.

---

## 🃏 User Stories, Specs & Backlog

- Toda implementação deve estar rastreada a uma story em `docs/user-stories.md`.
- Antes de implementar, confirme que a story tem critérios de aceite claros.
- **Para stories com contratos novos**: gerar spec em `docs/specs/` antes de implementar (ver `claude-sdd.md`).
- Quebre stories grandes em tasks menores em `docs/backlog.md`.
- Cada task deve caber em um único ciclo TDD.
- **Specs não substituem stories** — stories definem o "porquê" e os critérios de aceite; specs definem o "como" técnico.

---

## 📱 Notificação ntfy (obrigatório ao aguardar input)

**TODA** resposta que termina aguardando input do usuário DEVE escrever no arquivo de notificação da sessão.
Isso é obrigatório — não opcional. O hook lê esse arquivo para montar a notificação do celular.

**Formato**: `{resumo ≤ 130 chars}. {pergunta}?`
**Exemplo**: `Finalizei task 3.2 — schema User criado e testado. Posso iniciar task 3.3 (API endpoint)?`

**Como escrever** (usar exatamente este comando Bash, antes do texto final da resposta):
```bash
bash -c 'printf "%s" "Finalizei X e fiz Y. Posso continuar com Z?" > ~/.claude/ntfy-msg-$WT_SESSION.txt'
```

> ⚠️ `$WT_SESSION` é único por aba do Windows Terminal — evita que múltiplos terminais misturem mensagens.
> `printf "%s"` evita que o bash interprete caracteres especiais. Não use `echo` com acentos.
> O hook extrai contexto do transcript como fallback, mas a mensagem escrita por Claude é mais precisa.

---

## 💬 Comunicação durante o desenvolvimento

Ao propor código, o Claude deve:

1. Indicar em qual **task do backlog** está trabalhando.
2. **Se houver spec**: indicar qual seção do spec está implementando.
3. Mostrar o **teste primeiro** (Red), depois o **código** (Green).
4. Sinalizar quando está na fase de **Refactor**.
5. Apontar dívidas técnicas identificadas sem resolvê-las fora do escopo da task.
6. **Se delegando**: indicar qual tipo de subagente será invocado e com qual contexto.

### ✅ Definição de Pronto (Task Completion)

Uma task só está concluída quando **todos** estes critérios forem verdadeiros:

1. Testes existem e passam com ≥ 80% de cobertura
2. `bun run lint` passa com zero erros
3. `bun run typecheck` passa com zero erros
4. Código commitado e pushado
5. Todas as GitHub Actions estão verdes
6. **Se houver spec**: todos os cenários do spec estão cobertos por testes
7. **Se task de frontend**:
   a. Nenhum hex/cor hardcodado — apenas tokens do design brief / MASTER.md
   b. 4 estados implementados (loading com Skeleton, empty com ícone+msg+CTA, error com Alert+retry, success)
   c. Responsivo verificado (mobile + desktop no mínimo)
   d. Animações de entrada aplicadas conforme o design brief
   e. Tipografia e density conforme o design brief (não defaults genéricos do shadcn)
   f. Hover e focus states presentes em todos os elementos interativos

> Detalhes sobre CI, auto-verificação pós-push e ciclo de correção: ver `claude-stacks.md` → CI/CD.

---

## 🤖 Delegação para Subagentes

Quando o agente principal decide delegar (ver tabela de decisão em `claude-subagents.md`):

1. **Montar prompt** com contexto mínimo: seção do spec + paths + regras aplicáveis
2. **Para component-agent**: incluir obrigatoriamente `design-brief.md` + page override (se existir)
3. **Invocar** via Task tool do Claude Code
4. **Validar** o resultado (testes + lint + typecheck + visual checklist para frontend)
5. **Se falhou**: invocar `fix-agent` com o erro exato (máx 3 retries)
6. **Se passou**: prosseguir para a próxima task

### Regras de delegação

- Subagente nunca faz commit, push, install, ou modifica docs/specs
- Budget de contexto por tipo (ver `claude-subagents.md` → Budget de contexto):
  - `schema-agent` / `api-agent`: ≤ 1500 tokens
  - `component-agent`: ≤ 3500 tokens (inclui design brief + page override)
  - `fix-agent`: ≤ 1000 tokens
- Para `component-agent`: **nunca cortar design brief para economizar tokens** — cortar stack rules genéricas primeiro
- Ordem de execução: schema → api → componente (respeitar dependências)
- Agente principal é responsável pela integração final

> Detalhes completos: ver `claude-subagents.md`.

---

## 🔄 Auto-atualização do Stacks

> **Aprendizado contínuo: erros evitáveis devem virar regras documentadas.**

Sempre que o Claude encontrar um erro durante o desenvolvimento que **poderia ter sido evitado** se a informação estivesse documentada no `claude-stacks-refactor.md`, ele deve:

1. **Corrigir o erro** no código normalmente (dentro do ciclo TDD).
2. **Atualizar o `claude-stacks-refactor.md`** adicionando a regra, padrão ou configuração que preveniria o erro.
3. **Mostrar no terminal** exatamente o que foi alterado e o motivo, no formato:

```
📝 STACKS ATUALIZADO — claude-stacks-refactor.md
───────────────────────────────────────────────
📍 Seção: [nome da seção onde a alteração foi feita]
✏️  Alteração: [descrição concisa do que foi adicionado/modificado]
💡 Motivo: [qual erro ocorreu e por que essa regra o preveniria]
───────────────────────────────────────────────
```

4. **Commitar** a atualização do stacks junto com o fix, na mensagem de commit usar o prefixo `docs(stacks):`.

### Exemplos de quando atualizar

- Erro de import por path errado → documentar convenção de paths no stacks.
- Dependência usada sem estar listada → adicionar à tabela de Tech Stack.
- Configuração de build que causou falha no CI → documentar na seção relevante.
- Padrão de código que gerou bug sutil → adicionar regra/convenção.

### Quando NÃO atualizar

- Erros de lógica de negócio (pertencem às user stories, não ao stacks).
- Typos ou erros triviais que não representam padrões recorrentes.

---

## 🔄 Auto-atualização do Design

> **Aprendizado visual contínuo: padrões visuais melhores devem ser documentados.**

Sempre que o Claude identificar um padrão visual que **funciona melhor** do que o documentado no `claude-design.md` ou no `docs/design-system/MASTER.md`, ele deve:

1. **Implementar** o padrão na task atual normalmente.
2. **Atualizar o arquivo correto**:
   - Se é padrão **reutilizável entre projetos** (ex: empty state melhorado, novo padrão de tabela) → atualizar `claude-design.md`
   - Se é **específico deste projeto** (ex: novo token de cor, nova animação, componente com estilo único) → atualizar `docs/design-system/MASTER.md` + regenerar `docs/design-system/design-brief.md`
3. **Mostrar no terminal** exatamente o que foi alterado e o motivo:

```
📎 DESIGN ATUALIZADO — [claude-design.md | docs/design-system/MASTER.md]
───────────────────────────────────────────────
📍 Seção: [nome da seção onde a alteração foi feita]
✏️  Alteração: [descrição concisa do que foi adicionado/modificado]
💡 Motivo: [por que este padrão funciona melhor que o anterior]
───────────────────────────────────────────────
```

4. **Commitar** junto com a task, usando o prefixo `docs(design):`.
5. **Se atualizou o MASTER.md**: regenerar o `design-brief.md` para que subagentes futuros recebam o padrão atualizado.

### Exemplos de quando atualizar

- Empty state com ilustração SVG se mostrou melhor que apenas ícone Lucide → atualizar `claude-design.md`
- Nova cor semântica necessária (ex: "em análise" precisou de tom púrpura) → atualizar `MASTER.md` + brief
- Padrão de card com hover effect refinado funcionou melhor → avaliar se é reutilizável ou específico
- Animação de entrada com delay staggered melhorou a experiência → documentar no arquivo correto
- Componente shadcn/ui precisou de customização recorrente → documentar no `claude-design.md`

### Quando NÃO atualizar

- Preferência estética pessoal sem justificativa funcional (ex: "achei mais bonito").
- Mudança que quebraria consistência visual do projeto sem ganho claro.
- Padrão que funciona para um caso isolado mas não generaliza.

### Candidatos a promoção (cross-projeto)

Quando uma atualização no `claude-design.md` ou `MASTER.md` pode beneficiar **todos** os projetos, marcar como candidato no `claude-stacks-refactor.md`:

```markdown
## Candidatos a promoção

| Regra | Origem | Destino | Status |
|---|---|---|---|
| Empty state SVG > ícone Lucide | MASTER.md Cotamar | claude-design.md global | ⏳ Pendente |
| Tabela compacta 6px > 8px | MASTER.md Cotamar + BankBalance | claude-design.md global | ⏳ Pendente |
```

O autor revisa periodicamente e promove para os arquivos globais.

---

## 🚫 Proibições

- ❌ Não escreva código de produção sem teste correspondente.
- ❌ Não implemente features com contratos novos sem spec aprovado em `docs/specs/`.
- ❌ Não implemente funcionalidades não mapeadas no backlog.
- ❌ Não use `any` no TypeScript sem justificativa explícita.
- ❌ Não faça commits com testes falhando ou cobertura abaixo de 80%.
- ❌ Não misture refactor com novas funcionalidades no mesmo ciclo.
- ❌ Não use outro test runner além de `bun test`.
- ❌ Não ignore erros de `bun run lint` (Biome) ou `bun run typecheck`.
- ❌ Não use `[skip ci]`, `--no-verify` ou `--force` em commits.
- ❌ Não pré-configure serviços opcionais (pg-boss, Resend, Railway Buckets) sem necessidade explícita.
- ❌ Não introduza tecnologias fora do `claude-stacks.md` sem aprovação do autor.
- ❌ Não delegue para subagente sem spec existente e aprovado.
- ❌ Não envie mais que o budget de contexto para um subagente (ver `claude-subagents.md` → Budget).
- ❌ Não modifique spec durante implementação sem amendment aprovado pelo usuário.
- ❌ Não crie componentes frontend sem consultar `claude-design.md` para padrões de UI.
- ❌ Não hardcode cores, fontes ou espaçamentos — usar tokens do `docs/design-system/MASTER.md`.
- ❌ Não implemente componentes sem os 4 estados obrigatórios (loading/empty/error/success).
- ❌ Não delegue task de componente sem incluir o `design-brief.md` no prompt do subagente.
- ❌ Não corte o design brief do prompt do component-agent para economizar tokens.
- ❌ Não implemente tasks de stories P2/P3 enquanto houver tasks P1 pendentes (exceto se bloqueadas).
