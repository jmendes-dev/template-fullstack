# Design: Integração GitHub Issues com Backlog

**Título:** Sincronização automática backlog.md → GitHub Issues  
**Data:** 2026-04-14  
**Fase:** Template — infraestrutura de rastreamento  
**Versão:** 1.0  
**Autor:** Brainstorming Agent

---

## Contexto

O template `template-fullstack` usa `docs/backlog.md` como fonte de verdade do backlog (Kanban P1/P2/P3). O Scrum Master precisa de visibilidade em tempo real do progresso sem depender do desenvolvedor para relatórios manuais. A solução integra o backlog com GitHub Projects + Issues, mantendo o `backlog.md` como fonte de verdade e o GitHub como surface de visualização.

---

## Objetivo

Criar rastreamento automático de User Stories como GitHub Issues, com board visual acessível ao Scrum Master, sem alterar o fluxo de desenvolvimento existente.

---

## Escopo

- Projetos novos (via `adopt-workflow.sh`)
- Projetos existentes com `docs/backlog.md` já preenchido

Fora do escopo:
- Sincronização bidirecional (GitHub → backlog.md)
- Integração com Jira, Linear ou outras ferramentas
- Criação de Issues para tasks individuais (apenas User Stories)

---

## Arquitetura

### Componentes

```
template-fullstack/
├── setup-github-project.sh       ← NOVO: setup do board (run once)
├── sync-github-issues.sh         ← NOVO: parser backlog.md → Issues
├── adopt-workflow.sh             ← ATUALIZADO: menciona scripts no resumo
└── .claude/agents/
    └── project-manager.md        ← ATUALIZADO: chama sync após gerar backlog
```

`.github/project-id` — arquivo gerado pelo setup, persiste o Project ID numérico do GitHub Projects.

### Fluxo — Projeto novo

```
adopt-workflow.sh
  └→ setup-github-project.sh (1x manual)
       └→ /novo-prd → /prd-planejamento
            └→ project-manager gera backlog.md
                 └→ sync-github-issues.sh (automático)
                      └→ Issues criadas no GitHub
```

### Fluxo — Projeto existente

```
setup-github-project.sh (1x manual)
  └→ sync-github-issues.sh (manual, importa histórico)
       └→ daqui em diante: project-manager sincroniza automaticamente
```

### Fluxo — Fechamento de Issue

```
git commit -m "feat(auth): implement login — Closes #12"
  └→ merge na main
       └→ GitHub fecha Issue automaticamente + move para Concluído
```

---

## Board Structure

### Colunas (GitHub Projects — status-based)

```
📋 Backlog → 🎯 A Fazer → 🔄 Em Andamento → 👀 Em Review → ✅ Concluído
```

### Labels

| Grupo | Labels |
|---|---|
| Prioridade | `P1-crítico`, `P2-importante`, `P3-desejável` |
| Tipo | `feature`, `bug`, `refactor`, `docs` |
| Estado | `spec-pendente`, `spec-aprovada`, `em-andamento` |

### Milestones

```
Épico 1 — Levantamento & Planejamento
Épico 2 — Arquitetura & Setup
Épico 3 — Desenvolvimento
Épico 4 — Qualidade & Testes
Épico 5 — Segurança & Revisão
Épico 6 — Deploy & Entrega
```

---

## Especificação dos Scripts

### `setup-github-project.sh`

**Responsabilidade:** Setup único do board por projeto.

**Comportamento:**
1. Verifica autenticação do `gh` CLI
2. Cria GitHub Project board com as 5 colunas de status
3. Cria os 10 labels (prioridade + tipo + estado)
4. Cria os 6 milestones (Épicos 1–6)
5. Salva o Project ID em `.github/project-id`
6. Imprime instruções de commit convention (`Closes #N`)

**Uso:**
```bash
./setup-github-project.sh              # repo do git remote atual
./setup-github-project.sh owner/repo   # repo explícito
```

**Idempotência:** Labels e milestones já existentes são ignorados (sem erro). Project board existente com o mesmo nome é reutilizado — não cria duplicata.

**Pré-requisitos:** `gh` autenticado com permissões `repo` e `project`.

### `sync-github-issues.sh`

**Responsabilidade:** Parser de `backlog.md` → criação/atualização de Issues.

**Comportamento:**
1. Lê `docs/backlog.md` e extrai User Stories pelo padrão `### US-XX — Título`
2. Para cada US:
   - Verifica se Issue com o título já existe via `gh issue list --search`
   - Se não existe: cria com labels, milestone e checklist de tasks
   - Se existe: atualiza checklist de tasks sem sobrescrever título/labels/comentários
3. Adiciona Issue ao Project board na coluna `Backlog`
4. Imprime resumo: `X criadas, Y atualizadas, Z sem mudança`

**Uso:**
```bash
./sync-github-issues.sh                    # usa docs/backlog.md
./sync-github-issues.sh path/backlog.md    # arquivo explícito
```

**Formato esperado no `backlog.md`:**
```markdown
### US-03 — Importação de CSV
**Prioridade:** P1
**Milestone:** Épico 3 — Desenvolvimento
**Tasks:**
- [ ] 3.1 Spec aprovada
- [ ] 3.2 Schema Drizzle
- [ ] 3.3 Endpoint POST /imports
- [ ] 3.4 Componente ImportForm
```

### Formato de uma Issue gerada

```
Title:    [US-03] Importação de CSV
Labels:   P1-crítico, feature, spec-pendente
Milestone: Épico 3 — Desenvolvimento
Body:
  ## Objetivo
  <extraído do user-stories.md se disponível, senão vazio>

  ## Critérios de aceite
  <extraído do user-stories.md se disponível, senão vazio>

  ## Tasks
  - [ ] 3.1 Spec aprovada
  - [ ] 3.2 Schema Drizzle
  - [ ] 3.3 Endpoint POST /imports
  - [ ] 3.4 Componente ImportForm
```

---

## Atualização do `project-manager.md`

Nova seção adicionada ao agente:

```
GITHUB ISSUES SYNC

Após qualquer operação que crie ou atualize docs/backlog.md:

1. Verificar se .github/project-id existe
2. Se sim: executar bash sync-github-issues.sh
3. Se não: avisar o usuário:
   "Board GitHub não configurado ainda. Rode ./setup-github-project.sh
    para ativar rastreamento automático de Issues no GitHub."

Após sync bem-sucedido, incluir no output:
  "🔗 GitHub Issues sincronizadas — X criadas, Y atualizadas"
  + link: https://github.com/OWNER/REPO/issues

O sync nunca bloqueia nem altera a geração do backlog.md.
Acontece sempre como último passo.
```

---

## Atualização do `adopt-workflow.sh`

No bloco "Próximos passos" do resumo final, adicionar:

```
  2. Configure o board de rastreamento:
     ./setup-github-project.sh
     (requer gh autenticado com permissões repo + project)
```

---

## Critérios de Aceite

- [ ] `setup-github-project.sh` cria board, labels e milestones sem erro em repo limpo
- [ ] `setup-github-project.sh` é idempotente (reexecutar não duplica labels/milestones)
- [ ] `sync-github-issues.sh` cria Issues para todas as US do `backlog.md`
- [ ] `sync-github-issues.sh` não duplica Issues em reexecuções
- [ ] `sync-github-issues.sh` atualiza checklist de tasks em Issues existentes
- [ ] `project-manager` chama sync automaticamente após gerar backlog
- [ ] `project-manager` exibe aviso amigável quando board não está configurado
- [ ] Commit com `Closes #N` fecha Issue automaticamente no merge para main
- [ ] Issues ficam visíveis no board com coluna, label de prioridade e milestone corretos

---

## Decisões de Design

| Decisão | Alternativa descartada | Motivo |
|---|---|---|
| Scripts bash + agent instructions | GitHub Actions | Menor complexidade, sem parser YAML frágil |
| US como Issues, tasks como checklist | Tasks como Issues separadas | Reduz ruído no board, SM vê progresso sem granularidade excessiva |
| `.github/project-id` como flag de setup | Variável de ambiente | Versionável, compartilhável entre devs do mesmo projeto |
| Sync unidirecional (backlog.md → GitHub) | Bidirecional | Evita conflitos de fonte de verdade; backlog.md permanece autoritativo |
