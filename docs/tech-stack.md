# Tecnologias core — tabela de stack

Ler para referência de escolhas por camada. O stack resumido em uma linha vive em `CLAUDE.md`.

| Camada | Tech | Versão mínima |
|---|---|---|
| Runtime/PM/Test | Bun | ≥1.3 |
| API | Hono + @hono/standard-validator (Zod v4 via Standard Schema) + hono/client RPC | Hono ≥4.12.14 |
| Frontend | React 19 + React Router v7 (`react-router`) | React 19.2+, RR v7.14+ |
| Data fetching | TanStack Query (nunca React Router loaders) | v5.99+ |
| Client state | Zustand | v5.0+ |
| Forms | React Hook Form + zodResolver (`@hookform/resolvers/zod`) + schema de shared/ | RHF latest, `@hookform/resolvers` ≥5.1.0 (Zod v4) |
| UI | shadcn/ui + Tailwind CSS v4 (CSS-first) | Tailwind v4.2+, shadcn CLI v4 |
| Toasts | Sonner (nunca alert() ou outra lib) | latest |
| Charts | shadcn Charts (Recharts). Tremor para dashboards | latest |
| DB | PostgreSQL + Drizzle ORM | Drizzle ≥0.45.2 (CVE-2026-39356) |
| Schemas | Zod v4 + Drizzle Zod integration em packages/shared (fonte única de verdade) — ver `docs/version-matrix.md` para stable vs beta | Zod v4.0+, drizzle-zod ≥0.8.3 |
| Auth | Clerk | `@clerk/react` v6+ (Core 3) · `@clerk/hono` v0.1+ (backend) |
| Lint/Format | Biome 2.x | 2.4+ |
| Bundler | Vite 8 (Rolldown) | 8.0+ |
| TS tooling | TypeScript + Node | TS ≥6.0, Node ≥22.12 ou ≥24.x (Node 20 EOL abr/2026) |
| CI | GitHub Actions + SonarQube (Blacksmith runners opcional — ver `docs/ci-github-actions.md`) | — |
| Email | Resend + React Email (on demand) | latest |
| Jobs | Nativo primeiro → pg-boss só se necessário (ver `docs/background-jobs.md`) | — |
| Storage | S3-compatible: Railway Buckets (Railway) · MinIO (Portainer/dev) | @aws-sdk/client-s3 latest |

Versões detalhadas e fontes de verdade: `docs/version-matrix.md`.
