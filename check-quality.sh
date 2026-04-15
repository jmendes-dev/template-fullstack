#!/usr/bin/env bash
# check-quality.sh — Atualiza docs/quality.md com resultados de bun test
# Chamado automaticamente pelo hook PostToolUse após bun test
# Também pode ser chamado manualmente: ./check-quality.sh

set -euo pipefail

QUALITY_FILE="docs/quality.md"
SPECS_DIR="docs/specs"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# ── Garantir que docs/ existe ──────────────────────────────────
mkdir -p docs

# ── Executar testes e capturar output ─────────────────────────
echo "Executando bun test --coverage..."
TEST_OUTPUT=$(bun test --coverage 2>&1 || true)
TEST_EXIT=$?

# ── Parsear cobertura geral ────────────────────────────────────
COVERAGE=$(echo "$TEST_OUTPUT" | grep -E "^All files" | grep -oE "[0-9]+\.[0-9]+" | head -1 || echo "--")
PASS_COUNT=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ pass" | grep -oE "[0-9]+" || echo "0")
FAIL_COUNT=$(echo "$TEST_OUTPUT" | grep -oE "[0-9]+ fail" | grep -oE "[0-9]+" || echo "0")

# ── Status geral ──────────────────────────────────────────────
if [ "$TEST_EXIT" -eq 0 ]; then
  TEST_STATUS="✅ Passou ($PASS_COUNT testes)"
else
  TEST_STATUS="❌ Falhou ($FAIL_COUNT falhas)"
fi

# Cobertura ≥ 80%?
COV_STATUS="⏳"
if [ "$COVERAGE" != "--" ]; then
  COV_INT=$(echo "$COVERAGE" | cut -d. -f1)
  if [ "$COV_INT" -ge 80 ] 2>/dev/null; then
    COV_STATUS="✅"
  else
    COV_STATUS="❌"
  fi
fi

# ── Parsear cobertura por módulo ───────────────────────────────
MODULE_TABLE="| Módulo | Stmts | Branch | Funcs | Lines | Status |\n|--------|-------|--------|-------|-------|--------|"
while IFS= read -r line; do
  # Linhas com percentuais: "apps/api/routes  85.71  100  75  85.71"
  if echo "$line" | grep -qE "^\s+[a-zA-Z].*\|.*[0-9]+\.[0-9]+"; then
    MODULE=$(echo "$line" | awk '{print $1}' | tr -d '|' | tr -d ' ')
    STMTS=$(echo "$line" | awk '{print $2}' | tr -d '|' | tr -d ' ')
    BRANCH=$(echo "$line" | awk '{print $3}' | tr -d '|' | tr -d ' ')
    FUNCS=$(echo "$line" | awk '{print $4}' | tr -d '|' | tr -d ' ')
    LINES=$(echo "$line" | awk '{print $5}' | tr -d '|' | tr -d ' ')
    INT=$(echo "$LINES" | cut -d. -f1)
    if [ "$INT" -ge 80 ] 2>/dev/null; then MOD_STATUS="✅"; else MOD_STATUS="❌"; fi
    MODULE_TABLE="$MODULE_TABLE\n| $MODULE | $STMTS% | $BRANCH% | $FUNCS% | $LINES% | $MOD_STATUS |"
  fi
done <<< "$TEST_OUTPUT"

# ── Gates DoD ─────────────────────────────────────────────────
if [ "$TEST_EXIT" -eq 0 ] && [ "$COV_STATUS" = "✅" ]; then
  DOD_TEST="- [x] \`bun test\` passa com cobertura ≥ 80%"
else
  DOD_TEST="- [ ] \`bun test\` passa com cobertura ≥ 80% ← **FALHOU**"
fi
DOD_LINT="- [ ] \`bunx biome check\` zero erros"
DOD_TYPE="- [ ] \`tsc --noEmit\` zero erros"

# ── Spec Coverage ─────────────────────────────────────────────
SPEC_TABLE="| Spec | Cenário | Teste | Status |\n|------|---------|-------|--------|"
if [ -d "$SPECS_DIR" ] && ls "$SPECS_DIR"/*.spec.md 2>/dev/null | head -1 > /dev/null; then
  for spec_file in "$SPECS_DIR"/*.spec.md; do
    spec_name=$(basename "$spec_file" .spec.md)
    # Extrair cenários (linhas como "### Cenário X.Y:" ou "- Cenário X.Y:")
    while IFS= read -r scenario_line; do
      scenario=$(echo "$scenario_line" | sed 's/.*Cenário /Cenário /' | sed 's/:.*//')
      # Verificar se existe teste com esse cenário
      test_found="--"
      if grep -r "Cenário" . --include="*.test.ts" --include="*.test.tsx" -l 2>/dev/null | head -1 > /dev/null; then
        if grep -r "$scenario" . --include="*.test.ts" --include="*.test.tsx" -q 2>/dev/null; then
          test_found="✅"
        else
          test_found="❌ Não encontrado"
        fi
      fi
      SPEC_TABLE="$SPEC_TABLE\n| $spec_name | $scenario | $test_found | -- |"
    done < <(grep -E "Cenário [0-9]" "$spec_file" 2>/dev/null || true)
  done
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

$(echo -e "$MODULE_TABLE")

---

## Gates do DoD

${DOD_TEST}
${DOD_LINT}
${DOD_TYPE}
- [ ] Cenários do spec ativos cobertos (ver Spec Coverage abaixo)
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

echo "✅ docs/quality.md atualizado (cobertura: ${COVERAGE}%)"
