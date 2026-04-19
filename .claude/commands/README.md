# .claude/commands/

Slash commands que encapsulam fluxos procedurais do template.

## Como usar

Digite `/nome-do-comando` em qualquer sessão Claude Code neste projeto.

## Comandos disponíveis

| Comando | Frequência | Propósito |
|---|---|---|
| `/bug` | Diário | Protocolo de debug: checkpoint git → skill stack-specific → agente correto → gates de escalação |
| `/triage` | Semanal | Decide se uma story precisa de spec formal ou vai direto para TDD |
| `/feature` | Semanal | Fluxo completo TRIAGE → SPEC → PLAN → EXECUTE → VERIFY → FINISH |
| `/finish` | Semanal | Cadeia de encerramento: verification → code review → merge |
| `/continue` | Diário | Retoma backlog: lê docs/backlog.md, seleciona próxima P1 |
| `/new-project` | Raro | Bootstrap de projeto novo: entrevista → stories → sequência de agentes |

## Formato dos arquivos

Cada `<nome>.md` pode ter frontmatter YAML opcional:

```yaml
---
description: "Descrição curta exibida no /help"
argument-hint: "[args-opcionais]"
allowed-tools: Read, Grep, Bash(git:*)
---
```

O corpo é um prompt template. Tokens especiais:
- `$ARGUMENTS` — args passados após o nome do comando
- `@path/to/file` — inline do conteúdo do arquivo no load

Comandos referenciam agentes e skills **por prosa** no corpo — ex: "Invoque o agente `backend-developer`".
