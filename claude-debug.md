# claude-debug.md — Protocolo de Debugging Sistemático

> **Este arquivo define como o Claude investiga e corrige bugs.**
> O princípio central: **DIAGNOSTICAR antes de CORRIGIR. Sempre.**
>
> **Quando ler**: ao receber qualquer prompt de correção de bug, fix, troubleshooting ou
> quando o ciclo TDD falhar (teste passou mas comportamento está errado, teste não passa após 2 tentativas, etc.)
>
> **Hierarquia**: `CLAUDE.md` > `claude-debug.md` > `claude-stacks.md`
>
> **Regra de ouro**: se você não consegue explicar a causa raiz em uma frase,
> você não entendeu o bug. Não toque no código.

---

## 🚨 Regra Zero — Checkpoint antes de tudo

**ANTES de qualquer investigação ou correção**, criar um checkpoint git:

```bash
git stash # ou
git commit -m "wip: checkpoint before debug" --no-verify
```

> Isso garante rollback limpo. Sem checkpoint, cada tentativa de fix polui o código
> e torna impossível voltar ao estado original do bug.
>
> **Se já tentou corrigir e piorou**: `git stash pop` ou `git reset --hard HEAD~N`
> para voltar ao estado original. Recomeçar a investigação do zero.

---

## 🔍 Protocolo de Investigação (obrigatório)

### Os 4 padrões de falha e por que acontecem

| Padrão | Causa real | O que o Claude faz errado |
|---|---|---|
| Loop infinito de fix | Tratando sintoma, não causa raiz | Aplica fix superficial → novo erro → outro fix → loop |
| Não entende causa raiz | Não leu código suficiente | Adivinha pelo texto do erro sem rastrear a cadeia de execução |
| Fix quebra outra coisa | Não testou regressão | Corrige ponto A sem verificar impacto em B, C, D |
| Erro vai e volta | Causa raiz está em outro lugar | Corrige efeito colateral, causa real permanece |

### O protocolo combate TODOS esses padrões com 5 fases obrigatórias:

```
FASE 1: REPRODUZIR    → Confirmar que o bug existe e é consistente
FASE 2: ISOLAR        → Encontrar o menor pedaço de código que causa o bug
FASE 3: DIAGNOSTICAR  → Rastrear a cadeia de execução até a causa raiz
FASE 4: FORMULAR      → Propor hipótese + plano de correção (sem tocar no código)
FASE 5: CORRIGIR      → Aplicar fix com TDD + verificar regressão
```

> **Não pular fases.** Cada fase que você pula é uma tentativa de fix que vai falhar.

---

## FASE 1 — REPRODUZIR

**Objetivo**: confirmar que o bug existe, é consistente e é reproduzível.

**Ações obrigatórias**:

1. **Definir o comportamento esperado vs real** (sem ambiguidade):
```
ESPERADO: ao clicar "Salvar", a cotação é criada e um toast "Cotação criada" aparece
REAL: ao clicar "Salvar", aparece erro 500 no console e nenhum toast
```

2. **Reproduzir o bug com um teste** (se ainda não existe):
```bash
# Escrever teste que captura o bug
bun test [arquivo] -- --grep "deve criar cotação"
```

3. **Reproduzir manualmente** (se o teste não é suficiente):
```bash
# API: reproduzir com curl
curl -X POST http://localhost:3000/api/quotations -H "Content-Type: application/json" -d '{"origin":"BRSSZ","destination":"CNSHA"}'

# Frontend: reproduzir no browser e capturar:
# - Console errors (copiar texto exato)
# - Network tab (status, response body)
# - React DevTools (estado do componente)
```

4. **Classificar o bug**:

| Tipo | Exemplo | Nível de investigação |
|---|---|---|
| **Crash** | Erro 500, exception não capturada, tela branca | Rastrear stack trace completo |
| **Lógica** | Cálculo errado, filtro não funciona, dados duplicados | Rastrear fluxo de dados ponto a ponto |
| **Visual** | Layout quebrado, estado errado, componente não renderiza | Inspecionar props, estado, CSS |
| **Timing** | Race condition, dados carregam fora de ordem | Rastrear lifecycle e async flow |
| **Integração** | API retorna formato inesperado, tipo incompatível | Verificar contrato entre camadas |
| **Environment** | Funciona local, falha no CI/Docker/prod | Comparar env vars, versões, configs |

**Gate da Fase 1**: "Consigo reproduzir o bug 100% das vezes com este passo a passo: [lista]". Se não consegue reproduzir consistentemente, a Fase 2 é sobre encontrar as condições de reprodução.

---

## FASE 2 — ISOLAR

**Objetivo**: reduzir o escopo do bug ao menor pedaço de código possível.

**Técnicas de isolamento** (usar de cima para baixo, parar na primeira que funcionar):

### 2A — Bisect por camada

```
Frontend → API → Service → Schema → Banco

Pergunta: "O bug está no frontend ou no backend?"
Teste: curl na API diretamente. Se a API retorna correto, o bug está no frontend.
Se a API retorna errado, o bug está no backend.

Pergunta: "O bug está na rota ou no service?"
Teste: chamar o service diretamente no teste unitário.

Pergunta: "O bug está no service ou no schema/banco?"
Teste: verificar os dados no banco diretamente.
```

### 2B — Bisect por tempo (git bisect)

Se o bug é uma regressão (funcionava antes, parou de funcionar):

```bash
git bisect start
git bisect bad                  # commit atual está bugado
git bisect good <commit-hash>   # último commit que funcionava
# git bisect vai pedir para testar commits intermediários
# testar cada um e marcar como good/bad
# ao final, mostra o commit exato que introduziu o bug
```

### 2C — Eliminação progressiva

Comentar/desabilitar partes do código até o bug desaparecer:

```
1. Desabilitar middleware X → bug persiste? Sim → não é o middleware
2. Desabilitar validação Y → bug persiste? Não → a validação Y causa o bug
3. Dentro de Y, qual campo? → testar campo a campo
```

### 2D — Teste mínimo reproduzível

Criar o menor teste possível que reproduz o bug:

```typescript
// NÃO: teste que depende de 10 coisas
describe('QuotationService', () => {
  it('deve criar cotação completa com todos os campos', () => {
    // 50 linhas de setup...
  })
})

// SIM: teste que isola exatamente o problema
describe('QuotationService', () => {
  it('deve aceitar destination null quando tipo é domestic', () => {
    // 5 linhas focadas no bug exato
  })
})
```

**Gate da Fase 2**: "O bug está em [arquivo específico], [função/componente específico], [linha ~N]. Sei isso porque ao isolar [X], o bug desapareceu."

---

## FASE 3 — DIAGNOSTICAR

**Objetivo**: entender a CAUSA RAIZ — não o sintoma.

**Regra**: a causa raiz é SEMPRE uma destas:

| Categoria | Exemplos |
|---|---|
| **Dado errado** | Valor null onde esperava string, tipo errado, campo faltando |
| **Lógica errada** | Condição invertida, off-by-one, comparação errada (== vs ===) |
| **Timing errado** | Async não awaited, race condition, state update antes do render |
| **Contrato quebrado** | API mudou retorno, schema não bate com banco, tipo TS mente |
| **Config errada** | Env var faltando, import errado, versão incompatível |
| **Efeito colateral** | Mutação de estado compartilhado, cache stale, closure capturando valor antigo |

**Ações obrigatórias**:

1. **Ler o código na linha do erro** — não adivinhar pelo texto do erro:
```bash
# Ler o arquivo e a linha exata
cat -n apps/api/src/routes/quotations.ts | sed -n '45,65p'
```

2. **Rastrear a cadeia de execução** — de onde o dado errado veio:
```
Erro na linha 52: Cannot read property 'id' of undefined
→ 'quotation' é undefined na linha 52
→ 'quotation' vem do retorno de db.query na linha 48
→ db.query retorna undefined quando o ID não existe
→ O ID vem do req.params.id que é "undefined" (string)
→ CAUSA RAIZ: o frontend envia o ID como string "undefined" quando o item não foi selecionado
```

3. **Verificar contratos entre camadas**:
```bash
# O que a API realmente retorna?
curl http://localhost:3000/api/quotations/123 | jq .

# O que o schema Zod espera?
# Ler packages/shared/src/schemas/quotation.ts

# O que o frontend assume?
# Ler o hook/componente que consome a API
```

4. **Verificar se o bug é de ambiente**:
```bash
# Versões
bun --version
docker compose exec api bun --version

# Env vars
docker compose exec api env | grep -E "(DATABASE|CLERK|S3)"

# Banco
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT * FROM quotations LIMIT 1"
```

**Gate da Fase 3**: "A causa raiz é: [frase única]. Isso acontece porque [cadeia de execução]. Sei que é a causa raiz e não um sintoma porque [evidência]."

> **Se não consegue completar o gate**: você não entendeu o bug ainda. Volte para Fase 2.
> NÃO tente corrigir.

---

## FASE 4 — FORMULAR

**Objetivo**: propor hipótese de correção + plano de ação ANTES de tocar no código.

**Formato obrigatório**:

```
📋 BUG REPORT
─────────────────────────────────────
🐛 Bug: [descrição em uma frase]
📍 Localização: [arquivo:linha]
🔍 Causa raiz: [explicação em uma frase]
📊 Evidência: [como confirmei a causa raiz]

💊 Plano de correção:
1. [ação específica no arquivo X, linha Y]
2. [ação específica no arquivo Z, linha W]

🧪 Teste de validação:
- [teste que prova que o fix funciona]
- [teste de regressão: verificar que X, Y, Z continuam funcionando]

⚠️ Risco de regressão:
- [componente/funcionalidade que pode ser afetado pelo fix]
- [como vou verificar que não quebrou]
─────────────────────────────────────
```

**Regras**:
- O plano deve ter no **máximo 3 ações**. Se precisa de mais, o diagnóstico está incompleto
- Cada ação referencia **arquivo e linha exata**. Nada genérico como "ajustar o handler"
- O teste de validação é escrito ANTES do fix (TDD)
- **Apresentar o plano ao usuário e aguardar aprovação** antes de executar

**Anti-patterns de plano**:
- ❌ "Vou tentar mudar X para ver se funciona" → isso é chute, não plano
- ❌ "Vou refatorar o módulo inteiro" → escopo excessivo, provavelmente não entendeu o bug
- ❌ "Vou adicionar try-catch para não crashar" → mascara o bug, não corrige
- ❌ "Vou atualizar a dependência" → sem evidência de que a versão é o problema

---

## FASE 5 — CORRIGIR

**Objetivo**: aplicar o fix com TDD e verificar regressão.

**Procedimento**:

```
1. CHECKPOINT — git stash ou commit WIP (se não fez na Fase 0)

2. RED — Escrever teste que reproduz o bug exato
   → bun test [arquivo] → deve FALHAR (confirma que o teste captura o bug)

3. GREEN — Aplicar a correção (mínimo necessário)
   → bun test [arquivo] → deve PASSAR

4. REGRESSÃO — Rodar suite completa
   → bun test → TODOS devem passar
   → bun run lint → zero erros
   → bun run typecheck → zero erros

5. VERIFICAÇÃO MANUAL (se aplicável)
   → Reproduzir o cenário original → bug não aparece mais
   → Verificar cenários adjacentes → nenhum efeito colateral

6. COMMIT
   → git commit -m "fix: [descrição concisa do bug e da correção]"
```

**Se o fix quebrar algo**:
```
→ PARAR imediatamente
→ git reset --hard HEAD (descartar o fix)
→ Voltar para Fase 3 — o diagnóstico está incompleto
→ A coisa que quebrou É PISTA da causa raiz real
```

---

## 🚨 Protocolo de Escalação

### Quando escalar?

| Situação | Ação |
|---|---|
| Fix não converge após **3 tentativas** no mesmo bug | → Escalar para Nível 2 |
| Nível 2 não resolve após **2 tentativas** | → Escalar para Nível 3 |
| Nível 3 não resolve | → Escalar para Nível 4 (humano) |

### Nível 1 — Fix direto (padrão)

O fluxo normal das 5 fases. O Claude tenta resolver sozinho.

### Nível 2 — Investigação profunda

Quando o Nível 1 falha, o Claude deve:

1. **Parar e reportar** o que sabe até agora:
```
🔴 ESCALAÇÃO NÍVEL 2 — Bug não resolvido após 3 tentativas
─────────────────────────────────────
Tentativa 1: [o que tentei] → [resultado]
Tentativa 2: [o que tentei] → [resultado]
Tentativa 3: [o que tentei] → [resultado]

O que sei:
- Causa raiz provável: [hipótese]
- Evidência: [o que confirma/contradiz]
- O que NÃO sei: [lacuna de conhecimento]
─────────────────────────────────────
```

2. **Ampliar escopo de investigação**:
   - Ler arquivos adjacentes que não foram lidos antes
   - Verificar git log para quando o bug foi introduzido (`git bisect`)
   - Verificar se o bug existe em versões anteriores das dependências
   - Consultar context7 MCP para documentação da API/lib envolvida
   - Verificar issues conhecidas da dependência (`bun`, `hono`, `drizzle`, etc.)

3. **Reformular diagnóstico** — a causa raiz original estava errada. Voltar à Fase 3.

### Nível 3 — Abordagem alternativa

Quando o Nível 2 falha, considerar mudanças de abordagem:

1. **Questionar a premissa**: o design/spec está correto? O bug pode ser um sinal de que a abordagem está errada.
2. **Workaround documentado**: se a causa raiz está em dependência externa, implementar workaround com `// WORKAROUND: [explicação e link do issue]`
3. **Simplificar**: o código é complexo demais? Reescrever a funcionalidade do zero pode ser mais rápido que debugar.
4. **Isolar com feature flag**: se o fix é arriscado, proteger com feature flag para rollback rápido.

### Nível 4 — Escalar para humano

```
🔴 ESCALAÇÃO NÍVEL 4 — Requer intervenção humana
─────────────────────────────────────
Bug: [descrição]
Tentativas: [N]
Tempo investido: [estimativa]

Diagnóstico atual:
- Causa raiz mais provável: [hipótese]
- Evidência a favor: [lista]
- Evidência contra: [lista]

O que já tentei:
1. [tentativa] → [resultado]
2. [tentativa] → [resultado]
...

Sugestões para o humano:
- [ ] Verificar [X] que eu não tenho acesso/conhecimento para verificar
- [ ] Consultar [documentação/fórum/issue] sobre [problema específico]
- [ ] Considerar [abordagem alternativa]
─────────────────────────────────────
```

---

## 🧠 Padrões de bugs recorrentes e diagnóstico rápido

> Atalhos para bugs comuns. Se o bug se encaixa em um padrão, pular para o diagnóstico rápido.
> Se não se encaixa, seguir o protocolo completo.

### TypeScript / Build

| Erro | Causa provável | Verificação |
|---|---|---|
| `Type 'X' is not assignable to type 'Y'` | Schema Zod diverge do tipo TS ou do retorno da API | Comparar `z.infer<typeof schema>` com o tipo esperado |
| `Cannot find module '@projeto/shared'` | Workspace linkage quebrado | Verificar `package.json` → `"@projeto/shared": "workspace:*"` |
| `Property 'X' does not exist on type` | API retorna campo diferente do esperado | `curl` na API e comparar com o tipo |
| `Module not found` em imports relativos | Path errado ou barrel file não exporta | Verificar `packages/shared/src/index.ts` |

### API / Hono

| Erro | Causa provável | Verificação |
|---|---|---|
| 500 sem mensagem clara | Exception não capturada no handler | Verificar se o error handler global está registrado |
| 401 inesperado | Clerk middleware ativo sem `CLERK_SECRET_KEY` | Verificar env var e middleware condicional |
| Body undefined no POST | Faltou `sValidator` ou content-type errado | Verificar middleware de validação na rota |
| Resposta sem `{ data }` | Handler retornando sem envelope | Buscar `c.json(` sem wrapper `{ data: }` |

### Frontend / React

| Erro | Causa provável | Verificação |
|---|---|---|
| Componente não renderiza | Dados undefined na primeira render (loading state faltando) | Verificar `isLoading` antes de acessar `data` |
| Hydration mismatch | Renderização diferente no servidor vs client | Verificar uso de `window`, `localStorage`, `Date.now()` |
| State não atualiza | Mutação direta de objeto (React não detecta) | Verificar se está usando spread `{...obj}` ou `structuredClone` |
| useQuery não refetcha | `queryKey` estático quando deveria incluir variável | Verificar que o queryKey inclui os params que mudam |
| Form não submete | Schema Zod rejeita mas FormMessage não mostra | Verificar `console.log(form.formState.errors)` |

### Banco / Drizzle

| Erro | Causa provável | Verificação |
|---|---|---|
| Column "X" does not exist | Migration não foi rodada | `bun run db:generate && bun run db:migrate` |
| null em campo obrigatório | Coluna sem `.notNull()` no schema | Verificar schema Drizzle |
| Tipo errado no JS | `Date` do PG vira string no JSON | Verificar serialização |
| Unique constraint violation | Tentando inserir duplicata | Verificar lógica de upsert |

### Docker / CI

| Erro | Causa provável | Verificação |
|---|---|---|
| Funciona local, falha no CI | Env var faltando no CI ou versão diferente | Comparar env vars e versões |
| Container não starta | Port conflict ou dep não está healthy | `docker compose logs [service]` |
| Build falha no CI | Cache de node_modules obsoleto | `--frozen-lockfile` sem `bun.lock` atualizado |

---

## 📊 Bug Journal (obrigatório para bugs > 30 min)

Se o bug levar mais de 30 minutos para resolver, documentar no `claude-stacks-refactor.md`:

```markdown
### Bug Journal

#### [data] — [título do bug]
- **Sintoma**: [o que acontecia]
- **Causa raiz**: [o que estava errado]
- **Correção**: [o que foi feito]
- **Tempo investido**: [estimativa]
- **Nível de escalação**: [1/2/3/4]
- **Lição aprendida**: [o que preveniria este bug no futuro]
- **Candidato a promoção?**: [sim/não — se sim, adicionar na tabela de candidatos]
```

> O Bug Journal alimenta o aprendizado contínuo. Bugs que se repetem entre projetos
> devem ser promovidos para regras no `claude-stacks.md` ou `claude-design.md`.

---

## 🔗 Integração com o workflow existente

### Atualização do fix-agent (claude-subagents.md)

O `fix-agent` agora segue este protocolo. O template atualizado:

```
PROTOCOLO: Seguir claude-debug.md — Fases 1-5. Sem atalhos.

ERRO ENCONTRADO:
{mensagem de erro exata — copiar literalmente, não resumir}

STACK TRACE (se houver):
{stack trace completo}

CONTEXTO DE REPRODUÇÃO:
{como o erro foi produzido: comando, ação do usuário, teste que falhou}

ARQUIVO(S) SUSPEITO(S):
{path — baseado na stack trace ou no bisect do agente principal}

SPEC SECTION (se aplicável):
{seção do spec que define o comportamento esperado}

TENTATIVAS ANTERIORES (se houver):
{lista de fixes já tentados e por que falharam — para não repetir}

INSTRUÇÕES:
1. REPRODUZIR: confirmar o erro executando o teste ou comando indicado
2. ISOLAR: ler o arquivo na linha do erro, rastrear a cadeia de execução
3. DIAGNOSTICAR: identificar causa raiz em uma frase
4. FORMULAR: propor fix com máximo 3 ações + teste de validação
5. CORRIGIR: aplicar fix + verificar regressão

Se não conseguir completar a Fase 3 (diagnosticar), PARAR e retornar:
- O que sabe até agora
- O que não sabe
- Sugestão de próximo passo de investigação
NÃO aplicar fix sem diagnóstico completo.
```

### Quando o CLAUDE.md aciona o debug

O protocolo é acionado automaticamente quando:

1. **Prompt de bug fix**: "Corrigir o erro X" → ler `claude-debug.md` + seguir protocolo
2. **Teste falhou no ciclo TDD**: após 2 tentativas de Green que falham → escalar para protocolo de debug
3. **CI falhou**: loop de autocorreção do `claude-stacks.md` falha na 3ª tentativa → escalar para Nível 2
4. **Subagente falha 3x**: agente principal assume e segue o protocolo em vez de delegar de novo

---

## 🚫 Anti-patterns de debugging (proibições)

- ❌ **Nunca "tentar" um fix sem diagnóstico.** "Vou tentar trocar X por Y" é chute, não debugging
- ❌ **Nunca adicionar try-catch para esconder erro.** Isso mascara o bug, não corrige
- ❌ **Nunca mexer em arquivo que não está na cadeia de execução.** Se o erro é na rota, não mexa no tsconfig
- ❌ **Nunca aplicar fix em mais de 3 arquivos para um único bug.** Se precisa de mais, o diagnóstico está errado
- ❌ **Nunca repetir um fix que já falhou.** Cada tentativa é registrada, ler antes de tentar de novo
- ❌ **Nunca ignorar a stack trace.** A stack trace é o mapa do tesouro — ler linha por linha
- ❌ **Nunca atualizar dependência como primeiro recurso.** Só atualizar se há evidência concreta de bug na versão
- ❌ **Nunca refatorar durante debugging.** Fix first, refactor later. Misturar = bugs novos
- ❌ **Nunca debugar mais de 1 bug ao mesmo tempo.** Resolver um, commitar, depois o próximo
- ❌ **Nunca continuar debugging após 5 tentativas falhas sem escalar.** Escalar para Nível 2/3/4
