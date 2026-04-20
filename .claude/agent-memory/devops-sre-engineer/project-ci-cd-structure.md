---
name: CI/CD structure — template-fullstack
description: Pipeline structure, CD patterns, and example file locations for this template repo
type: project
---

CI workflow is at `.github/workflows/ci.yml`. Pipeline order: lint → typecheck → test (lcov coverage) → spec coverage check → SonarQube scan.

Runs on `blacksmith-4vcpu-ubuntu-2404`. Triggers: push to `main`/`uat`, PR to `main`.

CD example files (`.yml.example`, must be renamed to activate):
- `.github/workflows/cd-portainer-uat.yml.example` — UAT deploy via Portainer reusable workflow
- `.github/workflows/cd-portainer-prd.yml.example` — PRD deploy via Portainer reusable workflow
- `.github/workflows/cd-railway.yml.example` — PRD deploy via Railway CLI

Root example configs:
- `biome.json.example` — Biome 2.x config (monorepo, Hono + React, double quotes)
- `tsconfig.json.example` — TS 6.0+ monorepo root (noEmit, bundler resolution, @projeto/* paths)
- `sonar-project.properties.example` — SonarCloud/SonarQube config (lcov at coverage/lcov.info)

**Why:** Template ships example files so bootstrapped projects copy and rename them; avoids committing project-specific values into the template.
**How to apply:** When setting up a new project from this template, rename all `.example` files, update `@projeto/*` path aliases, and configure GitHub secrets/vars listed in the CD workflow comments.
