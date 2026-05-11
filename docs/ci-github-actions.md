# CI/CD — GitHub Actions

Ler ao criar `.github/workflows/ci.yml` (todos), `cd-uat.yml`/`cd-prd.yml` (on-premise apenas), ao debugar pipeline, ou ao aplicar o loop de autocorreção pós-push. Regra-resumo vive em `CLAUDE.md`.

## Pipeline CI (cloud e on-premise)

Ordem fixa: `install → biome → typecheck → test:coverage → osv-scanner → SonarQube → build`. Cada step falha o job inteiro.

**Segurança em workflows**: nunca interpolar `${{ github.event.* }}` diretamente em `run:` (command injection). Usar `env:` + variável shell.

**SonarQube**: `sonar-project.properties` na raiz. Quality gate: coverage ≥ 80%. Secrets: `SONAR_TOKEN`, `SONAR_HOST_URL`.

**Timeout obrigatório (≤ 15 min)**: todo job de qualquer pipeline (CI, CD, jobs reutilizáveis, manuais) deve declarar `timeout-minutes: 15` (limite máximo) — sem isso, o GitHub aplica o default de **360 minutos** e um job travado consome runner-minutes da org até o teto. Aplicar **por job**, não no nível do workflow. Steps individuais que dependem de rede externa (push de imagem, deploy webhook) podem usar `timeout-minutes` próprio menor (ex: 5 min para webhook). Se um job legítimo levar > 15 min, **investigar a causa** (tests lentos, cold cache, leak) antes de aumentar — o teto só sobe com justificativa documentada no PR.

## `.github/workflows/ci.yml`

A diferença entre cloud e on-premise está apenas nos **branches escutados** — on-premise tem a branch `uat` de staging obrigatória.

### Cloud (Railway)

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

### On-premise (Portainer)

```yaml
name: CI
on:
  push:
    branches: [main, uat]
  pull_request:
    branches: [main]
```

Estrutura do job (idêntica nos dois):

```yaml
permissions:
  contents: read
  pull-requests: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    runs-on: ubuntu-latest
    timeout-minutes: 15           # teto da org — nunca aumentar sem justificativa
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports: ["5432:5432"]
        options: >-
          --health-cmd="pg_isready -U test -d test"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
    env:
      DATABASE_URL: postgres://test:test@localhost:5432/test

    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with: { bun-version: 1.3 }
      - run: bun install --frozen-lockfile
      - run: bunx biome check .
      - run: bun run typecheck
      - run: bun run test:coverage
      - uses: google/osv-scanner-action/osv-scanner-action@v2
        with:
          scan-args: |-
            --lockfile=bun.lock
            --recursive
            ./
      - uses: SonarSource/sonarqube-scan-action@v4
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      - run: bun run build
```

**Notas**:
- `services.postgres` roda banco efêmero; sem isso `test:coverage` falha em projetos que tocam DB.
- `concurrency` cancela runs antigas no mesmo branch quando há push novo.
- Se o build precisa de `VITE_*` vars em compile time, adicionar em `env:` do job com valores de secrets.

---

## CD — aplicável **apenas on-premise (Portainer)**

Em cloud (Railway), **não há workflow de CD** — Railway detecta push em `main` automaticamente e redeploya. Variáveis são configuradas no Railway dashboard.

On-premise Masterboi usa CD via `workflow_run` + webhook Portainer. Princípio: **CD só roda após CI verde**. Nunca disparar deploy direto em push. Nunca deployar por feature branch.

### `.github/workflows/cd-uat.yml` (on-premise)

```yaml
name: Deploy UAT
on:
  workflow_run:
    workflows: ["CI"]
    branches: [uat]
    types: [completed]

jobs:
  deploy-api:
    if: github.event.workflow_run.conclusion == 'success'
    timeout-minutes: 15
    uses: masterboiteam/.github/.github/workflows/deploy-uat.yml@main
    with:
      app_name: ${{ vars.APP_NAME }}-api
      registry: ${{ vars.INTERNAL_REGISTRY }}
      dockerfile: apps/api/Dockerfile
      skip_deploy: true            # build+push sem disparar webhook
    secrets:
      PORTAINER_WEBHOOK_UAT: ${{ secrets.PORTAINER_WEBHOOK_UAT }}

  deploy-web:
    needs: deploy-api
    timeout-minutes: 15
    uses: masterboiteam/.github/.github/workflows/deploy-uat.yml@main
    with:
      app_name: ${{ vars.APP_NAME }}-web
      registry: ${{ vars.INTERNAL_REGISTRY }}
      dockerfile: apps/web/Dockerfile
    secrets:
      PORTAINER_WEBHOOK_UAT: ${{ secrets.PORTAINER_WEBHOOK_UAT }}
      BUILD_SECRETS: |
        VITE_CLERK_PUBLISHABLE_KEY=${{ secrets.VITE_CLERK_PUBLISHABLE_KEY }}
```

**Fluxo**:
1. Push em `uat` → CI roda.
2. CI verde → `workflow_run` dispara `cd-uat.yml`.
3. `deploy-api` builda e publica `${REGISTRY}/${APP_NAME}-api:uat-latest` (sem webhook).
4. `deploy-web` builda, publica `${REGISTRY}/${APP_NAME}-web:uat-latest` **e dispara webhook Portainer** — Portainer re-pulla ambas imagens e redeploya a stack UAT.

### `.github/workflows/cd-prd.yml` (on-premise)

Mesmo padrão, mas:
- `branches: [main]`
- Usa `deploy-prd.yml`
- Usa `PORTAINER_WEBHOOK_PRD`
- Tags sem prefixo: `:latest` (vs `:uat-latest`)

### Workflows reutilizáveis (org-level)

`masterboiteam/.github/.github/workflows/deploy-uat.yml` e `deploy-prd.yml` (mantidos no repo `.github` da org) encapsulam:

- Login no registry interno
- `docker build` com `BUILD_SECRETS` (via `--build-arg`)
- `docker push` com a tag correta
- POST para `PORTAINER_WEBHOOK_*` (exceto se `skip_deploy: true`)

Não copiar o workflow para o projeto — usar via `uses:`.

### Regras obrigatórias do CD (on-premise)

- **CD só roda após CI verde** — guard `if: github.event.workflow_run.conclusion == 'success'` é mandatório.
- **Branches permitidas**: `uat` → `cd-uat.yml`; `main` → `cd-prd.yml`. Nenhuma outra.
- **Ordem de deploy**: API primeiro (`skip_deploy: true`), depois Web (dispara webhook). Web pode depender de versão nova da API.
- **Tags de imagem**: UAT `:uat-latest`, PRD `:latest`. Nunca misturar.
- **`BUILD_SECRETS`** (só Web): `VITE_*` são compile-time; passar via `--build-arg`. Portainer UI não tem efeito sobre imagem já buildada.
- **`timeout-minutes: 15` por job** — todo job de CD precisa do teto. Sem ele, um webhook pendurado ou push de imagem travado consome runner-minutes da org indefinidamente.

---

## Security audit com osv-scanner

Preenche o gap do Dependabot (que não gera PR de security update para `bun` — só version updates). Roda sobre `bun.lock` nativamente via [OSV database](https://osv.dev).

Por padrão falha o job em `HIGH`/`CRITICAL`. Para reportar sem falhar: `--fail-on-vuln=NEVER` (usar com cuidado).

Setup completo do GitHub (Dependabot + CODEOWNERS + branch protection): `docs/github-setup.md`.

## Scripts obrigatórios no root `package.json`

- `lint` → `bunx biome check .`
- `typecheck` → `bun run --filter='*' typecheck`
- `test` → `bun test`
- `test:coverage` → `bun test --coverage` (usado no CI)
- `build` → build de cada app
- `dev` → dev de cada app com HMR
- `db:generate` → `drizzle-kit generate`
- `db:migrate` → `drizzle-kit migrate`

## Secrets e variables obrigatórios

Settings → Secrets and variables → Actions:

| Tipo | Nome | Cloud (Railway) | On-premise (Portainer) |
|---|---|---|---|
| var | `APP_NAME` | — | ✅ (CD usa como tag de imagem) |
| var | `INTERNAL_REGISTRY` | — | **var da org** — já disponível |
| secret | `SONAR_TOKEN` / `SONAR_HOST_URL` | ✅ | ✅ |
| secret | `PORTAINER_WEBHOOK_UAT` | — | ✅ |
| secret | `PORTAINER_WEBHOOK_PRD` | — | ✅ |
| secret | `VITE_CLERK_PUBLISHABLE_KEY` | — (Railway Variables + dashboard) | ✅ (build-time do web via `BUILD_SECRETS`) |

Em cloud, Clerk publishable key vai direto no Railway dashboard (injetada em runtime para a API; em build-time do web via `railway.toml`).

---

## Loop de autocorreção pós-push

Após cada push, verificar GitHub Actions. Máximo **7 tentativas** até CI verde. Ver skill `/master-ci-fix` para execução estruturada.

Passos:
1. Push → aguardar CI.
2. Passou → concluído.
3. Falhou → identificar step quebrado → logar `step → causa → correção` → fix → push.
4. Repetir até verde ou 7 tentativas.
5. Bateu 7 → parar e reportar (problema de design, não sintaxe).

Nunca considerar tarefa finalizada com CI vermelho.

## Anti-patterns

- **Disparar CD direto em `on: push`** (on-premise) — sempre `workflow_run` após CI verde.
- **CD escutando feature branches** — só `uat` e `main`.
- **Deployar Web antes da API** — API primeiro, Web depois.
- **Usar mesma tag em UAT e PRD** — sempre distinguir (`uat-latest` vs `latest`).
- **Copiar o workflow reutilizável para o projeto** — usar via `uses: masterboiteam/.github/...@main`.
- **Passar `VITE_*` apenas via Portainer UI** — compile-time, precisa `BUILD_SECRETS` no CD.
- **Pular o `osv-scanner`** — falha aqui indica CVE real; corrigir via `bun update`.
- **Criar CD workflows em projetos Railway** — Railway redeploya automático em push; não precisa CD no Git.
- **Mexer em config sem atualizar `package.json` scripts** — CI reproduz só o que está nos scripts.
- **Omitir `timeout-minutes`** — sem o campo, GitHub aplica default de 360 min e um job travado queima runner-minutes da org até o teto. Padrão da org: `timeout-minutes: 15` por job.
