---
name: noThenProperty mock pattern fix
description: How to fix Biome noThenProperty lint errors in test mock objects that need to be awaitable
type: feedback
---

When mock objects need to be both directly awaitable (via `await`) AND support builder method chains (e.g., `.where().limit()`), the original pattern uses a `then` property on a plain object — which Biome flags as `noThenProperty`.

**Fix:** Use `Object.assign(promise, { builderMethods })` with a deferred Promise via `queueMicrotask` to keep lazy counter evaluation.

**Key constraint:** The counter (e.g., `selectCallIdx++`) must NOT be consumed eagerly at creation time. Use a `branchTaken` flag + `queueMicrotask` so the base promise only resolves via the direct-await path if no builder method was called first:

```ts
let branchTaken = false;
const basePromise = new Promise<unknown[]>((resolve) => {
  queueMicrotask(() => {
    if (!branchTaken) resolve(results[counter++] ?? []);
    else resolve([]);
  });
});
return Object.assign(basePromise, {
  where: (_cond: unknown) => {
    branchTaken = true;
    return { limit: (_n: number) => Promise.resolve(results[counter++] ?? []) };
  },
});
```

**Why:** `Promise.resolve(value)` evaluates `value` synchronously (before any branch method fires), consuming the counter slot even when a builder chain is used. `queueMicrotask` defers the base resolution to after all synchronous builder calls have run.

**Also relevant:** For `delete process.env.X` (noDelete lint rule) when the service checks `if (!envVar)`, use `process.env.X = ""` (empty string is falsy) instead of `undefined` (which becomes the string "undefined" — truthy).
