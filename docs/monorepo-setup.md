# Monorepo — setup e exemplos

Ler ao criar/modificar estrutura de workspaces, ao setar a ligação entre apps, ou ao configurar o Hono RPC. Regras de importação entre workspaces vivem em `CLAUDE.md`.

## Workspace manager

Bun workspaces — config no `package.json` raiz:

```json
{ "workspaces": ["apps/*", "packages/*"] }
```

## Grafo de dependências

Direção de quem depende de quem:

- `apps/api` → `packages/shared`
- `apps/web` → `packages/shared`
- `apps/api` ✕ `apps/web` — **nunca** importar código runtime entre apps. Toda comunicação via HTTP/RPC. **Exceção única**: `import type` do `AppType` da API para Hono RPC (ver abaixo)

## Workspace linkage

Obrigatório em cada `package.json` de app:

```json
{ "dependencies": { "@projeto/shared": "workspace:*" } }
```

Frontend também precisa de `"@projeto/api": "workspace:*"` como **devDependency** (apenas para `import type` do `AppType` — sem código runtime).

## Exports do shared

`packages/shared/src/index.ts` é barrel file — re-exporta schemas, tipos e constantes. Apps importam de `@projeto/shared`, nunca de caminhos internos do package.

## Hono RPC

API exporta `type AppType = typeof app`. Frontend:

```typescript
import type { AppType } from "@projeto/api";
import { hc } from "hono/client";

const client = hc<AppType>(baseUrl);
```

`import type` é eliminado em compile time — type-safety end-to-end sem dep runtime.

## Comandos por workspace

```bash
bun run --filter=@projeto/api <script>
```
