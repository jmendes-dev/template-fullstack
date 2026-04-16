# Agent Memory Bootstrap — Template Reutilizável

> Use este guia para pré-popular as memórias dos agentes em qualquer novo projeto.
> Objetivo: eliminar o período de "memória vazia" onde os agentes não têm contexto acumulado.

---

## Como funciona o sistema de memória

### Estrutura
```
.claude/agents/[agente].md              ← definição do agente (regras, comportamento)
.claude/agent-memory/[agente]/
    MEMORY.md                           ← índice (carregado automaticamente via memory: project)
    [topic].md                          ← arquivos temáticos detalhados
```

### Ciclo de vida
1. **Alimentação**: o agente usa `Write`/`Edit` para gravar em `.claude/agent-memory/[agente]/`
2. **Retroalimentação**: o frontmatter `memory: project` injeta `MEMORY.md` no contexto do agente na próxima sessão
3. **Evolução**: agente lê → usa conhecimento acumulado → descobre mais → atualiza

### Limitação crítica
- `MEMORY.md` tem limite de **200 linhas** antes de ser truncado — manter conciso
- Conhecimento detalhado vai em arquivos temáticos linkados pelo índice
- Memórias nunca devem duplicar o que está em `CLAUDE.md` ou `claude-stacks.md`

---

## Checklist de bootstrap (novo projeto)

### Passo 1 — Criar estrutura de pastas
```bash
mkdir -p .claude/agent-memory/{backend-developer,frontend-developer,data-engineer-dba,devops-sre-engineer,software-architect,project-manager,qa-engineer,ux-ui-designer,security-engineer,requirements-roadmap-builder}
```

### Passo 2 — Coletar informações do projeto

Antes de escrever qualquer MEMORY.md, extrair estas informações do projeto:

**Do `claude-stacks.md`:**
- [ ] Stack completa (runtime, framework, ORM, auth, UI, test runner)
- [ ] Estrutura de pastas
- [ ] Response format da API
- [ ] Padrões de estado (server/client/form/URL)
- [ ] Variáveis de ambiente obrigatórias
- [ ] Targets de deploy

**Do codebase:**
- [ ] Rotas já implementadas (`apps/api/src/routes/`)
- [ ] Páginas existentes (`apps/web/src/pages/`)
- [ ] Schemas existentes (`packages/shared/src/schemas/`)
- [ ] Helpers de teste existentes
- [ ] Dados de seed já cadastrados

**Do `docs/`:**
- [ ] Stories implementadas (`docs/backlog.md`)
- [ ] Fase atual do projeto
- [ ] Perfis de usuário do sistema
- [ ] ADRs existentes (`docs/adr/`)

### Passo 3 — Preencher MEMORY.md por agente

Use o template abaixo para cada agente. Adaptar a seção "Resumo crítico" com os dados coletados.

---

## Template de MEMORY.md

```markdown
# MEMORY.md — [nome-do-agente]

> Memória persistente do agente. Atualizada automaticamente durante o desenvolvimento.

## Índice

- [Tópico 1](topico-1.md) — descrição curta

---

## Resumo crítico (ler sempre)

**Projeto**: [nome do projeto] — [descrição em uma linha]
**Fase atual**: PHASE [N] — [nome da fase]

### [Seção relevante para o agente]
[Conteúdo específico]

### [Outra seção]
[Conteúdo]
```

---

## Conteúdo mínimo por agente

### backend-developer
- Stack backend (framework, validator, ORM, auth, test runner, lint)
- Padrão de resposta da API (sucesso item, lista, erro)
- Estrutura de pastas (`routes/`, `services/`, `middleware/`, `db/`)
- Lista de rotas já implementadas (para não recriar)
- Regras de import (schemas sempre de `@projeto/shared`)
- Convenção de contratos API

### frontend-developer
- Stack frontend (framework, router, data fetching, state, forms, UI, auth)
- Regras de estado (server/client/form/URL — nunca misturar)
- Estrutura de páginas existentes
- Regra de contratos (não implementar useQuery sem contrato)
- Imports monorepo (apenas `import type` da API)
- Quirks do framework UI (shadcn/ui: verificar antes de usar)

### data-engineer-dba
- Stack de dados (ORM, DB, versão, integração Zod)
- Localização dos schemas e convenção de nomenclatura
- Lista de schemas existentes (para não recriar)
- Padrões obrigatórios (colunas padrão, nullable handling)
- Comandos de migration
- Dados de seed já cadastrados

### devops-sre-engineer
- Targets de deploy e mecanismos
- Estrutura de compose files (quantos e qual uso)
- Regras CI/CD (ordem de deploy, guards, branch strategy)
- Regras obrigatórias de compose (healthcheck, resource limits, etc.)
- Secrets GitHub necessários
- Configuração nginx (produção)

### software-architect
- Estrutura do monorepo
- Grafo de dependências (quem importa quem)
- Decisões arquiteturais confirmadas (evitar reabrir debates)
- Localização da documentação arquitetural
- Regras invariáveis da stack

### project-manager
- Nome do projeto e cliente
- Fase atual e sprint corrente
- Localização dos artefatos (backlog, stories, specs, contratos)
- Metodologia e convenções (estimativas, prioridade, DoD)
- Scripts obrigatórios do workflow
- Perfis de usuário do sistema

### qa-engineer
- Runner e threshold de cobertura
- Localização de helpers e fixtures existentes
- Padrão de nomenclatura de testes
- Estado atual da cobertura
- DoD gates
- Checklist de security review por endpoint

### ux-ui-designer
- Hierarquia de documentação de design
- Stack visual (UI lib, ícones, charts, toasts)
- 4 estados obrigatórios por componente
- Quirks do Tailwind version (v4: CSS-first)
- Perfis de usuário e seus contextos de uso

### security-engineer
- Stack de autenticação e autorização
- Papéis do sistema
- Regras de segurança por status HTTP
- OWASP checklist local
- Localização de segredos por ambiente
- Padrão de logs de segurança

### requirements-roadmap-builder
- Nome do projeto, cliente e domínio de negócio
- Perfis de usuário e suas responsabilidades
- Localização dos documentos de requisitos
- Stories implementadas (para não regerar)
- Dados de seed já cadastrados
- Regras de triage (quando gerar spec vs TDD direto)

---

## Quando atualizar as memórias

Os agentes devem atualizar suas memórias ao:

1. **Descobrir um padrão novo** — ex: como o projeto trata erros de validação
2. **Completar uma feature** — adicionar rotas/páginas/schemas ao inventário
3. **Receber correção do usuário** — registrar feedback para evitar repetição
4. **Encontrar uma solução não-óbvia** — doc de troubleshooting em arquivo temático
5. **Confirmar uma decisão arquitetural** — gravar no agente relevante

## O que NÃO colocar na memória

- Contexto temporário da sessão atual (use tasks em vez disso)
- Código completo (apenas padrões e referências de localização)
- Duplicatas do `CLAUDE.md` ou `claude-stacks.md`
- Informação especulativa ou não-verificada
- Git history (use `git log` quando necessário)
