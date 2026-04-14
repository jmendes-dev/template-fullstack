---
name: feedback-bun-mocks
description: Bun 1.3.10 mock patterns — what works vs what fails in test isolation
type: feedback
---

## Rule: Never use spyOn().mockResolvedValue() in Bun 1.3.10

In Bun 1.3.10 on Windows, `spyOn(obj, method).mockResolvedValue(val)` has a bug:
it can set `obj.method = Promise.resolve(val)` (a Promise instance) instead of
configuring the spy to return a resolved Promise when called.

**Why:** Confirmed empirically — error message was `api.put is not a function; api.put is an instance of Promise`.

**How to apply:** Always use the two-step pattern:
```typescript
const spy = spyOn(obj, method);
spy.mockImplementation(() => Promise.resolve(val));
// NOT: spyOn(obj, method).mockResolvedValue(val)
```
Same for mockRejectedValue:
```typescript
spy.mockImplementation(() => Promise.reject(new Error("...")));
```

## Rule: mock.module() leaks affect subsequent test files

When a test file uses `mock.module("@/lib/api", ...)` and then `mock.restore()`,
the static import bindings in OTHER test files running in the same Bun process
may still point to the mock module's objects. This causes `spyOn(apiModule.api, "put")`
to fail if the mocked `api.put` is not a proper function.

**Why:** Bun 1.3.10 module mock restoration does not fully fix static ESM bindings
across test files when running `bun test` with multiple files in one process.

**How to apply:** Add a defensive `beforeEach` in test files that spy on api methods:
```typescript
beforeEach(() => {
  if (typeof apiModule.api.put !== "function") {
    (apiModule.api as Record<string, unknown>).put = () => Promise.resolve({});
  }
});
```

## Rule: Always use waitFor() for async assertions after userEvent.click

When `handleSubmit` or `handleDelete` makes async API calls before calling `onSave`/`onDelete`,
`await userEvent.click(...)` does NOT guarantee the async chain inside the handler completes.

**How to apply:** Always wrap assertions about async side effects in `waitFor`:
```typescript
await userEvent.click(screen.getByRole("button", { name: /salvar/i }));
await waitFor(() => expect(onSave).toHaveBeenCalled()); // NOT: expect(onSave).toHaveBeenCalled()
```

## Rule: Bun 1.3.10 crashes with Illegal Instruction when running all web tests together

Running `bun test packages/web` or `bun test` consumes 3-4GB RAM and crashes with
`Illegal instruction` when all React/Happy-DOM test files run in the same process.

**Why:** Bun 1.3.10 Windows bug — memory pressure with Happy-DOM global registrator.

**How to apply:** Run tests file-by-file or in small groups. CI runs on Ubuntu where
this crash does not occur. The crash exit code is 3.
