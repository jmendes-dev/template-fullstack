---
name: master-ci-fix
description: Aplica o loop de autocorreção pós-push (máx 7 tentativas) quando o CI do GitHub Actions quebra. Lê logs do step que falhou, aplica correção mínima, push, monitora até CI verde. Usar quando o usuário disser "CI quebrou", "fix CI", "PR com check vermelho", ou após um push que resultou em falha.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

Esta skill formaliza a regra 21 do `CLAUDE.md` e o fluxo descrito em `docs/ci-github-actions.md`: **CI verde obrigatório**, loop de no máximo **7 tentativas** até o pipeline passar. Nunca concluir uma tarefa com CI vermelho.

Toda a comunicação deve ser em **português do Brasil**.

---

## Passo 0 — Orientação silenciosa

**Sem interação com o usuário.** Antes de começar:

1. Ler `CLAUDE.md` seção CI/CD + regra 21
2. Ler `docs/ci-github-actions.md` por completo — pipeline, YAML, fontes de falha comuns
3. Confirmar autenticação do `gh`: `gh auth status` — se não logado, parar e pedir `gh auth login`
4. Identificar a branch atual: `git branch --show-current`
5. Identificar o último push: `git log -1 --format='%H %s'`
6. Listar runs recentes: `gh run list --branch $(git branch --show-current) --limit 3`

---

## Passo 1 — Identificar o run quebrado

Pegar o run mais recente que está `failure` ou `action_required`:

```bash
gh run list --branch $(git branch --show-current) --limit 5 --json databaseId,status,conclusion,createdAt,displayTitle
```

Se não há run falhando recente:
> "Não achei CI vermelho recente na branch **[branch]**. Último run está **[status]**. Quer que eu force um novo push pra testar? Ou o problema é em outra branch?"

Se há:
> "Achei o run **[ID]** falhando no commit **[sha-curto]** (_[título do commit]_).
>
> Tentativa **1 de 7**. Vou ver qual step quebrou."

---

## Passo 2 — Ler logs do step que falhou

```bash
gh run view <RUN_ID> --log-failed
```

Capturar:
- Nome do step que falhou (ex: `typecheck`, `biome`, `test:coverage`, `osv-scanner`, `SonarQube`, `build`)
- Mensagem de erro específica (primeiras 50 linhas relevantes, ignorar ruído)
- Arquivos/linhas envolvidos

Se o output for enorme, filtrar: `gh run view <RUN_ID> --log-failed | grep -A 20 -i "error\|fail"`.

---

## Passo 3 — Classificar a causa e aplicar correção

Mapa comum de falhas → correção (seguir fonte da verdade em `docs/ci-github-actions.md`):

| Step | Sintoma | Causa comum | Correção |
|---|---|---|---|
| `biome` | `unsafe usage`, `unused variable` | código novo desviou do padrão | rodar `docker compose exec api bunx biome check --write .`; se regra específica, `// biome-ignore lint/<grupo>/<regra>: motivo` |
| `typecheck` | `Cannot find module '@projeto/shared'` | barrel file ou `workspace:*` quebrado | verificar `packages/shared/src/index.ts` re-exporta tudo; `apps/*/package.json` tem `"@projeto/shared": "workspace:*"` (substituir pelo nome real do workspace em packages/shared/package.json) |
| `typecheck` | `Type X is not assignable` | mudança de schema não propagou | `bun run db:generate` + atualizar inferências Zod |
| `test:coverage` | `Coverage below 80%` | testes novos insuficientes | adicionar testes no arquivo apontado pelo relatório |
| `test:coverage` | teste falhou | regressão | corrigir código (não o teste) — entender a regressão primeiro |
| `osv-scanner` | `vulnerability found` | dep com CVE | `bun update <pacote>` para versão patched; se não há patch, avaliar substituição |
| `SonarQube` | `quality gate failed` | code smells ou dupe | abrir dashboard SonarQube, corrigir issues apontadas |
| `build` | `Module not found` ou path quebrado | import relativo frágil ou plugin Vite faltando | alinhar imports com alias `@/` (se o projeto usa este alias — verificar tsconfig.json paths) e `@projeto/shared` (substituir pelo nome real do workspace em packages/shared/package.json) |
| `build` | OOM no Node | Vite sem memória | `NODE_OPTIONS="--max-old-space-size=4096"` no step (último recurso) |
| action version | `Node 16 deprecated` etc | actions defasadas | atualizar versão de `actions/*` (não assumir versão; conferir releases) |
| secrets | `env var undefined` | secret faltando em Actions | `gh secret set NOME` localmente; **não** commitar secrets |

**Princípios da correção:**
- Correção **mínima e cirúrgica** — só o necessário para passar
- **Nunca** suprimir o check (`--no-verify`, desativar step, lowering coverage)
- **Nunca** commitar secrets, credentials ou `.env*`
- Se o erro é em action injection (`${{ github.event.* }}` em `run:`), corrigir usando `env:` + variável shell (regra 31)

---

## Passo 4 — Commit e push da correção

```bash
git add <arquivos-específicos>
git commit -m "fix(ci): <descrição-curta>"
git push
```

Em Conventional Commits, tipo `fix` com escopo `ci` (ou `test`, `build` conforme o step).

**Nunca** `git add -A` — adicionar só o que você editou.

---

## Passo 5 — Monitorar o novo run

```bash
gh run watch <NOVO_RUN_ID>
```

Ou, se não souber o ID, descobrir e acompanhar com `gh run watch` (espera real, sem polling cego):

```bash
# pegar o ID do run mais recente da branch e acompanhar até concluir
RUN_ID=$(gh run list --branch $(git branch --show-current) --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

`--exit-status` faz o comando retornar non-zero se o run falhar — útil para encadear com `&& echo "verde"`. **Não usar `sleep <N>` para "esperar o CI"** — builds reais variam de 30s a 10min, e `sleep` cego desperdiça tempo ou subestima.

### Se passou:

> "Tentativa **[N] de 7** passou. CI verde no commit **[sha]**.
>
> Resumo das correções aplicadas ao longo do loop:
> - Tentativa 1: [step] → [correção]
> - Tentativa 2: [step] → [correção]
> - [...]"

### Se falhou de novo:

Voltar ao Passo 2 **incrementando o contador**. Se o mesmo step falha 2x seguidas com a mesma mensagem, escalar:

> "Aplicou a correção mas o step **[nome]** falhou de novo com a mesma mensagem. Preciso de contexto adicional antes da próxima tentativa:
>
> - [perguntas específicas ao usuário]
>
> Pausando o loop em **[N] de 7**."

---

## Passo 6 — Limite de 7 tentativas

Se chegar em **7 tentativas sem CI verde**, parar e escalar:

> "Bati o limite de 7 tentativas sem conseguir passar o CI. Resumo do que tentei:
>
> 1. [step] → [correção] → [resultado]
> 2. [step] → [correção] → [resultado]
> [...]
>
> Problemas persistentes:
> - [padrão que se repete]
>
> Recomendo [sugestão concreta: investigação manual de X, pair debugging, ou revisitar o plano da fase]. Não vou tentar uma 8ª."

O limite existe para forçar reflexão — 7 tentativas sem sucesso geralmente significa que o problema é de design, não de sintaxe.

---

## Passo 7 — Log do ciclo

Após conclusão (sucesso ou limite), registrar o histórico no corpo do PR (via `gh pr edit --body`) ou em um comentário:

```
## CI fix loop

| Tentativa | Step | Causa | Correção | Resultado |
|---|---|---|---|---|
| 1 | typecheck | type mismatch em clienteSchema | regenerar migration + atualizar Zod | ✅ passou biome e typecheck, falhou test |
| 2 | test:coverage | cobertura 74% em routes/clientes.ts | adicionar 3 testes de erro | ✅ verde |
```

Isso vira documentação para a próxima vez que alguém tocar naquela parte.

---

## Notas para o assistente

### Nunca contornar o guardrail
- **Não** reduzir threshold de cobertura
- **Não** adicionar `continue-on-error: true` no step
- **Não** pular hooks locais (`--no-verify`)
- **Não** comentar testes ou asserts
- **Não** força push para `main`

Se o CI parece "errado", o problema é o código, não o CI. Regra 30 (CLAUDE.md): ler o erro real antes de adivinhar.

### Versão das actions
Regra 29 + `docs/ci-github-actions.md`: nunca assumir versão de `actions/*`. Confirmar antes de bumpar.

### Security
Regra 31: nunca interpolar `${{ github.event.* }}` em `run:`. Se o step falha por tentativa de exploit detectada, **não** suprimir — corrigir estrutura.

### Idioma
Toda comunicação em **português do Brasil**. Reports de progresso concisos — uma frase por tentativa.

### Cache do CI
Se a falha for por cache corrompido, invalidar via `gh cache list` + `gh cache delete <id>`. Só como último recurso, nunca primeira tentativa.
