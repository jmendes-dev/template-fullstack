---
name: master-fase
description: Executa a próxima fase pendente de um plano gerado pelo master-plan, seguindo os critérios de aceite da fase até o gate verde. Usar quando o usuário disser "implementar fase", "executar fase", "continuar plano" ou "começar fase N".
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill
---

Esta skill implementa **uma fase por vez** de um plano `plans/<feature>-plano.md` gerado pelo `/master-plan`. O objetivo é fechar o ciclo planejamento → código sem perder os guardrails (critérios de aceite, CI verde, cobertura ≥80%).

O público-alvo são vibecoders — conduza a conversa de forma acolhedora, mas sem perder rigor técnico.

Toda a comunicação deve ser em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de qualquer pergunta:

1. Leia o `CLAUDE.md` do projeto por completo — stack, regras, contratos
2. Leia `docs/tech-stack.md` e `docs/version-matrix.md` para confirmar versões pinadas
3. Liste `plans/*.md` e identifique planos (`*-plano.md`)
4. Para cada plano encontrado, leia o checklist final e identifique qual fase é a "próxima pendente" (primeira com algum critério não-marcado)
5. Verifique o estado do repositório: `git status`, `git branch --show-current`, e se a branch está limpa

---

## Passo 1 — Localizar plano e fase

### Se encontrou exatamente um plano com fase pendente:

> "Encontrei o plano de **[feature]** em `plans/[arquivo]-plano.md`.
>
> A próxima fase pendente é a **Fase [N]: [nome]** — [frase demonstrável da fase].
>
> Ela cobre **[X] histórias** e toca **[Y] tabelas/endpoints/telas**.
>
> Posso começar por essa?"

### Se encontrou múltiplos planos com fases pendentes:

> "Tem mais de um plano em andamento:
>
> 1. `plans/[arquivo1]-plano.md` — próxima pendente: Fase [N] ([nome])
> 2. `plans/[arquivo2]-plano.md` — próxima pendente: Fase [N] ([nome])
>
> Qual você quer executar agora?"

### Se o usuário pediu uma fase específica:

Se o usuário disse "executa a Fase 2 do plano de clientes", ir direto para ela. Se houver fases anteriores com critérios não-marcados, avisar:

> "A Fase 2 pede que a Fase 1 esteja completa. Vi que ainda tem critérios abertos em Fase 1: [listar 2-3]. Quer terminar a Fase 1 primeiro, ou prefere pular (com risco)?"

### Se não encontrou plano:

> "Não achei nenhum plano aqui (`plans/*-plano.md`). A master-fase trabalha a partir de um plano criado pelo `/master-plan`. Quer criar um plano primeiro?"

**Nunca avance** sem confirmação explícita do usuário sobre qual fase executar.

---

## Passo 2 — Preparar ambiente

**Sem interação com o usuário** (mas anunciar o que está fazendo):

1. Criar branch da fase: `git checkout -b feat/[nome-feature]-fase-[N]`
2. Se já existe a branch, perguntar se é para continuar nela ou criar nova
3. Confirmar que Docker compose dev está rodando: `docker compose -f docker-compose.dev.yml ps` — se não estiver, subir
4. Rodar baseline: `docker compose exec api bun run typecheck`, `docker compose exec api bunx biome check .`, `docker compose exec api bun test` — registrar estado inicial

Se o baseline falhar antes de qualquer mudança, avisar o usuário:

> "Antes de começar, rodei os checks base e achei esses problemas preexistentes: [listar]. Quer corrigir antes, ignorar, ou parar?"

---

## Passo 3 — Implementar a fase

Para cada item da seção "O que construir" da fase, na ordem abaixo:

### 3.1 — Mudanças de schema (se houver)

Sempre delegar para `/master-schema` — a skill aplica os guardrails de barrel file, nullability, validação de imports e SQL review automaticamente. Não escrever `pgTable` direto aqui.

> "A Fase [N] envolve mudança de schema (`tabela X`). Vou invocar `/master-schema` para criar com guardrails. Posso?"

`/master-schema` cobre:
- Schema em `packages/shared/src/schema/`
- Schemas Zod via `drizzle-zod`
- Migration SQL gerada e revisada
- Validação de nullability (regra 16)
- Update do barrel file

### 3.2 — API (rotas, handlers)

- Criar/alterar rotas em `apps/api/src/routes/`
- Usar `sValidator` de `@hono/standard-validator` para validação
- Envelope `{ data }` / `{ error, code, details }` em todas as respostas
- Middleware de auth nas rotas protegidas (conforme permissões do PRD)
- Testar cada endpoint com `curl` antes de seguir para o frontend (regra 18 do CLAUDE.md)

### 3.3 — Frontend (telas, componentes)

#### Imports proibidos — verificar antes de aceitar

- `react-router-dom` → usar `react-router` (regra 22)
- `import zustand from 'zustand'` (default) → usar `import { create } from 'zustand'` (regra 23)
- `@radix-ui/react-*` → usar `radix-ui` unificado (regra 28)
- `<SignedIn>`, `<SignedOut>`, `<Protect>` de Clerk → usar `<Show when="signed-in">` (regra 20)
- `from '@clerk/types'` → usar `from '@clerk/react/types'` (regra 20)
- `getToken()` sem capturar `ClerkOfflineError` de `@clerk/react/errors` (regra 20)

- Criar/alterar páginas em `apps/web/src/pages/`
- TanStack Query + Hono RPC client tipado (`hc<AppType>`)
- shadcn/ui — verificar `src/components/ui/<componente>.tsx` antes de passar props
- Tratar nulls explicitamente (regra 16 do CLAUDE.md)
- Sonner para toasts
- Estados vazios e de erro conforme PRD

### 3.4 — Testes

- Cobertura **≥ 80%** nas partes novas: domínio, validators, routes, auth, edge cases, error handling
- Rodar: `docker compose exec api bun test --coverage`

### 3.4b — Security review (por endpoint novo)

Em vez de checklist inline, invocar `/master-security-review` — cobre os 9 itens (Auth 401, Authz 403, Validation 400, Mass assignment, Injection, Rate limiting 429, CORS, Secure headers, Response envelope) e gera relatório arquivo:linha.

> "Vou rodar `/master-security-review` nos endpoints novos da Fase [N]: [`POST /api/x`, `PATCH /api/x/:id`]. Reporto os achados antes do gate."

Não fechar a fase com achados de severity alta sem corrigir.

### 3.5 — Verificação incremental

Após cada sub-etapa, rodar:

```bash
docker compose exec api bun run typecheck
docker compose exec api bunx biome check .
```

Se falhar, corrigir antes de seguir. Nunca acumular dívida.

---

## Passo 4 — Gate da fase

Rodar todos os critérios de aceite listados no plano + os checks técnicos obrigatórios:

```bash
docker compose -f docker-compose.dev.yml ps                # todos healthy
curl http://localhost:${PORT:-3000}/health                 # { "status": "ok" }
docker compose exec api bun run --filter='*' typecheck     # api + web + shared, espelha CI
docker compose exec api bunx biome check .                 # zero erros
docker compose exec api bun test --coverage                # passa, cobertura ≥ 80%
docker compose exec api bun run db:generate                # no changes detected
```

**Não cobertos pelo gate local** (rodam só no CI):
- `osv-scanner` — vulnerabilidades de dependências
- SonarQube — quality gate (cobertura agregada, code smells)

Ambos rodam após o push. Se algum bloquear, `/master-ci-fix` aplica o loop de autocorreção. Não tem como rodar SonarQube local sem subir um servidor — aceitar que o gate completo só fecha pós-push.

Rodar **também** a demonstração manual da fase (seção "Como demonstrar ao final desta fase" do plano):

> "Vou testar o fluxo na prática:
> 1. [passo da demo]
> 2. [passo da demo]
> 3. [passo da demo]
>
> [Resultado observado]"

### Se algum critério falha:

- **Não marcar a fase como completa**
- Corrigir e rodar de novo
- Se o bloqueio for real (ex: lib quebrada, depende de algo externo), parar e escalar ao usuário

### Se todos os critérios passam:

- Marcar checkboxes dos critérios da fase no plano (`plans/<feature>-plano.md`)
- Confirmar com o usuário: "Todos os critérios da Fase [N] estão verdes. Posso commitar e abrir PR?"

---

## Passo 5 — Commit e PR

Com aprovação do usuário:

1. `git add` dos arquivos alterados (específicos, nunca `git add -A`)
2. Commit em Conventional Commits: `feat: implementar fase N do plano de <feature>`
3. Push da branch
4. Se configurado, criar PR: `gh pr create` com title curto + body contendo:
   - Resumo da fase em 2-3 bullets
   - Link para o plano
   - Checklist técnico (typecheck, lint, testes, cobertura)
   - Gate de demo executado

**Nunca** pular hooks (`--no-verify`). Se um hook falha, investigar e corrigir.

**Nunca** force push para `main`.

---

## Passo 6 — CI verde (regra 21)

Após push, monitorar CI. Se falhar, invocar `/master-ci-fix` para aplicar o loop de autocorreção (máx 7 tentativas).

Só considerar a fase **concluída** com:
- [ ] Todos os critérios de aceite marcados no plano
- [ ] CI verde no PR
- [ ] Usuário fez smoke test manual (ou aprovou explicitamente pular)

---

## Passo 7 — Próxima fase

Após conclusão, perguntar:

> "Fase [N] fechada. Quer emendar na Fase [N+1] agora, ou parar por aqui?"

Se o usuário quiser continuar, voltar ao Passo 1 já sabendo qual é a próxima. Se quiser parar, deixar a branch mergeada e a próxima execução começa limpa.

---

## Notas para o assistente

### Escopo e disciplina
- **Uma fase por vez**. Nunca antecipar trabalho de outras fases, mesmo que seja "rápido"
- Se durante a execução descobrir que algo da fase atual foi mal dimensionado no plano, parar e escalar: atualizar o plano primeiro, depois retomar
- Se o usuário pedir algo fora do escopo da fase atual, aplicar "estacionamento de ideias": anotar para PRD pós-MVP, redirecionar ao escopo

### Não refactorar o que não está quebrado
- Seguir as diretrizes do CLAUDE.md: mudanças cirúrgicas, nada especulativo
- Não "limpar" código adjacente que não foi tocado pela fase
- Não introduzir abstrações não pedidas

### Verificação com curl antes do frontend
- Regra 18 do CLAUDE.md: nunca construir frontend sem ter testado o endpoint e confirmado o shape real do JSON
- Anotar o JSON de cada endpoint em comentário temporário ou arquivo de scratch, não inventar campos

### Idioma e tom
- Toda comunicação em **português do Brasil**
- Anunciar o que está fazendo em uma frase curta antes de cada grupo de ações
- Não dar updates a cada linha de código — agrupar por sub-etapa (3.1, 3.2, etc.)

### Escalar, não escorregar
Se algo não funciona e você não sabe o motivo em 2 tentativas:
- Parar
- Nomear o problema ("a migration roda mas o type TS não atualiza")
- Mostrar o que já tentou
- Pedir orientação — nunca "gambiarrar" para seguir
