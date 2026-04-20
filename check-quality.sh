#!/usr/bin/env bash
# check-quality.sh — Atualiza docs/quality.md com resultados de bun test
# Chamado automaticamente pelo hook PostToolUse após bun test
# Também pode ser chamado manualmente: ./check-quality.sh

set -euo pipefail

# Argumento opcional: --from-output FILE (saída de bun test já capturada pelo hook)
FROM_OUTPUT=""
if [ "${1:-}" = "--from-output" ] && [ -n "${2:-}" ]; then
  FROM_OUTPUT="$2"
fi

QUALITY_FILE="docs/quality.md"
SPECS_DIR="docs/specs"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# ── Garantir que docs/ existe ──────────────────────────────────
mkdir -p docs

# ── Executar testes ou usar saída em cache ─────────────────────
if [ -n "$FROM_OUTPUT" ] && [ -f "$FROM_OUTPUT" ]; then
  echo "♻️  Usando saída de bun test em cache (evita dupla execução)..."
  TEST_OUTPUT=$(cat "$FROM_OUTPUT")
  if echo "$TEST_OUTPUT" | grep -qE "[0-9]+ fail"; then
    TEST_EXIT=1
  else
    TEST_EXIT=0
  fi
else
  echo "Executando bun test --coverage..."
  set +e
  TEST_OUTPUT=$(bun test --recursive --coverage 2>&1)
  TEST_EXIT=$?
  set -e
fi

# ── Parsear cobertura geral ────────────────────────────────────
COVERAGE=$(echo "$TEST_OUTPUT" | grep -E "^All files" | grep -oE "[0-9]+\.[0-9]+" | head -1 || echo "--")
PASS_COUNT=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ pass" | grep -oE "[0-9]+" || echo "0")
FAIL_COUNT=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ fail" | grep -oE "[0-9]+" || echo "0")

# ── Status geral ──────────────────────────────────────────────
if [ "$TEST_EXIT" -eq 0 ] && [ "${PASS_COUNT:-0}" -gt 0 ] 2>/dev/null; then
  TEST_STATUS="✅ Passou ($PASS_COUNT testes)"
elif [ "$TEST_EXIT" -eq 0 ] && [ "${PASS_COUNT:-0}" -eq 0 ] 2>/dev/null; then
  TEST_STATUS="⚠️ Nenhum teste encontrado"
else
  TEST_STATUS="❌ Falhou ($FAIL_COUNT falhas)"
fi

# Cobertura ≥ 95%?
COV_STATUS="⏳"
if [ "$COVERAGE" != "--" ]; then
  COV_INT=$(echo "$COVERAGE" | cut -d. -f1)
  if [ "$COV_INT" -ge 95 ] 2>/dev/null; then
    COV_STATUS="✅"
  else
    COV_STATUS="❌"
  fi
fi

# ── Parsear cobertura por módulo ───────────────────────────────
# Formato bun test --coverage: " path/to/file.ts  |  85.71 |   92.30 | 10-20"
# Colunas: % Funcs | % Lines | Uncovered Line #s
# Usa arquivo temporário para evitar que echo -e interprete \a, \n etc. em paths Windows
_MOD_TMP=$(mktemp)
printf '| Módulo | %% Funcs | %% Lines | Status |\n|--------|---------|---------|--------|\n' > "$_MOD_TMP"
while IFS= read -r line; do
  if echo "$line" | grep -qE '^\s+\S+\s+\|[[:space:]]+[0-9]+\.[0-9]+'; then
    MODULE=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')
    FUNCS=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
    LINES=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
    INT=$(echo "$LINES" | cut -d. -f1)
    if [ "$INT" -ge 95 ] 2>/dev/null; then MOD_STATUS="✅"; else MOD_STATUS="❌"; fi
    printf '| %s | %s%% | %s%% | %s |\n' "$MODULE" "$FUNCS" "$LINES" "$MOD_STATUS" >> "$_MOD_TMP"
  fi
done <<< "$TEST_OUTPUT"

# ── Lint (Biome) ──────────────────────────────────────────────
if command -v bunx &>/dev/null && ([ -f "biome.json" ] || [ -f "biome.jsonc" ]); then
  set +e
  LINT_OUTPUT=$(bunx biome check . 2>&1)
  LINT_EXIT=$?
  set -e
  if [ "$LINT_EXIT" -eq 0 ]; then
    DOD_LINT="- [x] \`bunx biome check\` zero erros"
  else
    DOD_LINT="- [ ] \`bunx biome check\` zero erros ← **FALHOU**"
  fi
else
  DOD_LINT="- [ ] \`bunx biome check\` zero erros (biome.json não encontrado — pulado)"
fi

# ── Typecheck ─────────────────────────────────────────────────
if command -v bun &>/dev/null && [ -f "package.json" ]; then
  set +e
  TYPE_OUTPUT=$(bun run typecheck 2>&1)
  TYPE_EXIT=$?
  set -e
  if [ "$TYPE_EXIT" -eq 0 ]; then
    DOD_TYPE="- [x] \`tsc --noEmit\` zero erros"
  else
    DOD_TYPE="- [ ] \`tsc --noEmit\` zero erros ← **FALHOU**"
  fi
else
  DOD_TYPE="- [ ] \`tsc --noEmit\` zero erros (tsconfig.json não encontrado — pulado)"
fi

# ── Gates DoD ─────────────────────────────────────────────────
if [ "$TEST_EXIT" -eq 0 ] && [ "$COV_STATUS" = "✅" ]; then
  DOD_TEST="- [x] \`bun test\` passa com cobertura ≥ 95%"
else
  DOD_TEST="- [ ] \`bun test\` passa com cobertura ≥ 95% ← **FALHOU**"
fi
DOD_SPEC=""  # será definido na seção Spec Coverage abaixo

# ── Spec Coverage ─────────────────────────────────────────────
# Delega para check-spec-coverage.sh (fonte única de verdade — também usada pelo CI)
SPEC_TABLE="| Spec | Cenário | Status |\n|------|---------|--------|"
SPEC_COVERED=0
SPEC_TOTAL=0

if [ -d "$SPECS_DIR" ] && ls "$SPECS_DIR"/*.spec.md 2>/dev/null | head -1 > /dev/null; then
  # Gerar tabela detalhada (lógica local apenas para o dashboard visual)
  for spec_file in "$SPECS_DIR"/*.spec.md; do
    spec_name=$(basename "$spec_file" .spec.md)
    while IFS= read -r scenario_line; do
      scenario=$(echo "$scenario_line" | grep -oE "Cenário [0-9]+\.[0-9]+" | head -1)
      [ -z "$scenario" ] && continue
      SPEC_TOTAL=$((SPEC_TOTAL + 1))
      if grep -r "it(.*$scenario:" . --include="*.test.ts" --include="*.test.tsx" -q 2>/dev/null; then
        SPEC_COVERED=$((SPEC_COVERED + 1))
        SPEC_TABLE="$SPEC_TABLE\n| $spec_name | $scenario | ✅ Coberto |"
      else
        SPEC_TABLE="$SPEC_TABLE\n| $spec_name | $scenario | ❌ Sem teste |"
      fi
    done < <(grep -E "Cenário [0-9]+\.[0-9]+" "$spec_file" 2>/dev/null || true)
  done
fi

# Gate: usa check-spec-coverage.sh como árbitro (consistência com CI)
if [ -x "./check-spec-coverage.sh" ]; then
  set +e
  SPEC_RESULT=$(./check-spec-coverage.sh "$SPECS_DIR" 2>&1)
  SPEC_EXIT=$?
  set -e
  if [ "$SPEC_EXIT" -eq 0 ]; then
    DOD_SPEC="- [x] Cenários do spec cobertos ($SPEC_COVERED/$SPEC_TOTAL)"
  else
    MISSING_COUNT=$((SPEC_TOTAL - SPEC_COVERED))
    DOD_SPEC="- [ ] Cenários do spec cobertos ($SPEC_COVERED/$SPEC_TOTAL) ← **FALTAM $MISSING_COUNT**"
  fi
elif [ "$SPEC_TOTAL" -gt 0 ]; then
  if [ "$SPEC_COVERED" -eq "$SPEC_TOTAL" ]; then
    DOD_SPEC="- [x] Cenários do spec cobertos ($SPEC_COVERED/$SPEC_TOTAL)"
  else
    DOD_SPEC="- [ ] Cenários do spec cobertos ($SPEC_COVERED/$SPEC_TOTAL) ← **FALTAM $((SPEC_TOTAL - SPEC_COVERED))**"
  fi
else
  DOD_SPEC="- [ ] Cenários do spec cobertos (nenhum spec encontrado em docs/specs/)"
fi

# ── Escrever quality.md ────────────────────────────────────────
cat > "$QUALITY_FILE" << QUALEOF
# Quality Dashboard

> Atualizado automaticamente após cada \`bun test\` via hook PostToolUse.
> Fonte de verdade para o estado de qualidade do projeto.

---

## Status Geral

| Métrica | Valor | Status |
|---------|-------|--------|
| Cobertura geral | ${COVERAGE}% | ${COV_STATUS} |
| Testes | ${TEST_STATUS} | -- |
| Última execução | ${TIMESTAMP} | -- |

---

## Cobertura por Módulo

$(cat "$_MOD_TMP")

---

## Gates do DoD

${DOD_TEST}
${DOD_LINT}
${DOD_TYPE}
${DOD_SPEC}
- [ ] Code review aprovado (\`superpowers:requesting-code-review\`)

---

## Spec Coverage

> Cenários do spec ativo mapeados a testes (nomenclatura: \`it('Cenário X.Y: ...')\`).

$(echo -e "$SPEC_TABLE")

---

## Bugs Abertos

> Registrados via \`escalation-and-bug-journal\` skill ou manualmente.

| ID | Descrição | Severidade | Status |
|----|-----------|------------|--------|
| -- | -- | -- | -- |

---

_Gerado por \`check-quality.sh\` · Última atualização: ${TIMESTAMP}_
QUALEOF

rm -f "$_MOD_TMP"
echo "✅ docs/quality.md atualizado (cobertura: ${COVERAGE}%)"
