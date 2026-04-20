#!/usr/bin/env bash
# check-spec-coverage.sh — Verifica se todos os cenários dos specs têm testes correspondentes.
# Exit 0: todos cobertos. Exit 1: cenários sem teste.
# Uso: ./check-spec-coverage.sh [specs-dir]

set -euo pipefail

SPECS_DIR="${1:-docs/specs}"
MISSING=0

if ! ls "$SPECS_DIR"/*.spec.md 2>/dev/null | head -1 > /dev/null 2>&1; then
  echo "No spec files found in $SPECS_DIR — skipping"
  exit 0
fi

while IFS= read -r spec_file; do
  while IFS= read -r scenario_line; do
    scenario_id=$(echo "$scenario_line" | grep -oE "Cenário [0-9]+\.[0-9]+" | head -1)
    [ -z "$scenario_id" ] && continue
    if ! grep -r "it(.*${scenario_id}:" . --include="*.test.ts" --include="*.test.tsx" --include="*.spec.ts" --include="*.spec.tsx" -q 2>/dev/null; then
      echo "  FALTANDO: $scenario_id em $(basename "$spec_file")"
      MISSING=$((MISSING + 1))
    fi
  done < <(grep -E "Cenário [0-9]+\.[0-9]+" "$spec_file" 2>/dev/null || true)
done < <(ls "$SPECS_DIR"/*.spec.md 2>/dev/null)

if [ "$MISSING" -gt 0 ]; then
  echo "❌ $MISSING cenário(s) sem teste correspondente"
  exit 1
fi

echo "✅ Todos os cenários do spec têm testes correspondentes"
exit 0
