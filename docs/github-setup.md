# GitHub — configuração padrão

Ler ao criar um projeto novo ou ao auditar a configuração do GitHub de um projeto existente. Cobre `.github/` (Dependabot, PR template, CODEOWNERS) e branch protection. Regra-resumo vive em `CLAUDE.md` seção "Git workflow".

Princípio: **todo projeto Masterboi nasce com o mesmo kit de GitHub**. Evita configuração manual repetitiva e garante que alertas de dependência, review obrigatório e proteção de `main` estejam ativos desde o primeiro commit.

## `.github/dependabot.yml`

Suporte nativo ao Bun foi GA em fev/2025 ([changelog](https://github.blog/changelog/2025-02-13-dependabot-version-updates-now-support-the-bun-package-manager-ga/)). O Dependabot atualiza `package.json` **e** `bun.lock` automaticamente.

```yaml
version: 2
updates:
  # Bun — usa package-ecosystem nativo, não "npm"
  - package-ecosystem: "bun"
    directories:
      - "/"
      - "/apps/api"
      - "/apps/web"
      - "/packages/shared"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    groups:
      minor-and-patch:
        update-types: ["minor", "patch"]
    commit-message:
      prefix: "chore(deps)"
      include: "scope"

  # Dockerfiles (multi-stage builds)
  - package-ecosystem: "docker"
    directories:
      - "/apps/api"
      - "/apps/web"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore(docker)"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "chore(ci)"
```

**Por que `directories` (plural, array) e não `directory`**: o Dependabot tem um bug ativo ([dependabot-core#14223](https://github.com/dependabot/dependabot-core/issues/14223), fev/2026) em que o `bun.lock` não é atualizado em projetos com `"workspaces"` no `package.json` raiz quando se usa `directory: "/"` sozinho. Listar cada workspace explicitamente em `directories` contorna o bug.

**Gap conhecido**: Dependabot para Bun **não gera PRs de security update** (só version updates). Alertas de CVE continuam aparecendo na aba Security do repo, mas o fix automático via PR ainda não existe. Complementamos no CI com `osv-scanner` (ver `docs/ci-github-actions.md`).

## `.github/pull_request_template.md`

```markdown
## O que mudou

<!-- resumo curto em 1-2 frases -->

## Por quê

<!-- motivação / issue / contexto -->

## Como testar

- [ ] rodei `docker compose -f docker-compose.dev.yml up`
- [ ] `bun run typecheck` verde
- [ ] `bun test` verde
- [ ] testei manualmente o fluxo afetado

## Checklist

- [ ] commits seguem Conventional Commits
- [ ] não há `console.log` / `TODO` órfão
- [ ] schemas novos nasceram em `packages/shared`
- [ ] API responses respeitam envelope `{ data }` / `{ error, code }`
- [ ] variáveis de ambiente novas foram documentadas em `.env.example`
- [ ] se endpoint novo: auth + validação + rate limit revisados
```

## `.github/CODEOWNERS`

```
# Donos globais — review obrigatório em qualquer PR
* @masterboi/dev-team

# Infraestrutura crítica exige review adicional
/.github/                @masterboi/dev-leads
/apps/api/src/middleware/  @masterboi/dev-leads
/packages/shared/src/schema/  @masterboi/dev-leads
drizzle.config.ts        @masterboi/dev-leads
docker-compose.yml       @masterboi/dev-leads
Dockerfile               @masterboi/dev-leads
```

Ajustar nomes dos times conforme organização real no GitHub da Masterboi.

## Branch protection rules (configurar na UI do GitHub)

Settings → Branches → Add rule → `main`:

- [x] **Require a pull request before merging**
  - [x] Require approvals: **1**
  - [x] Dismiss stale approvals on new push
  - [x] Require review from Code Owners
- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date
  - Checks obrigatórios (devem bater com o nome dos jobs no `.github/workflows/ci.yml` — ver `docs/ci-github-actions.md`):
    - `ci` (job único do template — cobre lint, typecheck, test, build, osv-scanner, SonarQube)

  Se o time decidir quebrar o pipeline em jobs separados (`lint`, `typecheck`, `test`, `build`, `osv-scanner`), atualizar essa lista para refletir os nomes reais. O default do template é **um job** chamado `ci`.
- [x] **Require conversation resolution before merging**
- [x] **Require signed commits** (opcional, se o time usa GPG/SSH signing)
- [x] **Require linear history** (força squash ou rebase — não permite merge commits)
- [x] **Do not allow bypassing the above settings**

Não habilitar `Allow force pushes` nem `Allow deletions` em `main`.

## Verificação pós-setup

```sh
# Dependabot ativo
gh api repos/:owner/:repo/vulnerability-alerts   # 204 = ativo

# PRs do Dependabot aparecem no próximo dia configurado em dependabot.yml (default: segunda)
gh pr list --author "app/dependabot"

# Branch protection
gh api repos/:owner/:repo/branches/main/protection   # retorna as regras
```
