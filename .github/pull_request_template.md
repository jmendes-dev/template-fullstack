## Story / Contexto

<!-- US-XX: Nome da story ou descrição resumida do que foi feito -->

## Tipo de mudança

- [ ] Bug fix
- [ ] Feature nova (US mapeada no backlog)
- [ ] Refactor (sem mudança de contrato)
- [ ] Config / infra / CI

## Spec

<!-- Link para docs/specs/US-XX-nome.spec.md ou "N/A - sem contrato novo" -->

## Checklist DoD

- [ ] `bun test` passa com cobertura ≥ 80%
- [ ] `bunx biome check` zero erros
- [ ] `tsc --noEmit` zero erros
- [ ] Todos os cenários do spec têm teste correspondente
- [ ] Componentes com 4 estados (Loading, Empty, Error, Success) — se frontend
- [ ] `docs/contracts/README.md` atualizado — se novo endpoint/schema/componente
- [ ] `docs/backlog.md` atualizado (tasks concluídas marcadas)
- [ ] Code review via `superpowers:requesting-code-review` executado

## Testes notáveis

<!-- Cenários críticos cobertos por testes — opcional mas útil para o revisor -->

---

🤖 Generated with [Claude Code](https://claude.ai/claude-code)
