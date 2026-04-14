---
name: CRLF line endings cause Biome format errors on Windows
description: In this Windows dev environment, files edited by the OS or certain editors use CRLF. Biome's formatter expects LF, so any CRLF file fails `biome check`. Always run `bunx biome format --write src/` before `biome check` to convert line endings.
type: feedback
---

On Windows, files in `packages/web/src/` accumulate CRLF (`\r\n`) line endings after being edited outside Biome. This causes `biome check` to report format errors on every file.

**Why:** Biome is configured for LF (Unix) line endings. Git on Windows has `core.autocrlf` which converts back to CRLF on checkout.

**How to apply:** Before running `bunx biome check src/`, first run `bunx biome format --write src/` to normalize all line endings to LF. Then re-run `biome check --fix src/` for import ordering and safe fixes, then fix remaining lint errors manually.
