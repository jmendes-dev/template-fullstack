# Backlog

> Waves = entregas visíveis ao cliente · P1/P2/P3 = ordem interna dentro da wave.
> Cada wave corresponde a um GitHub Milestone homônimo (ver `sync-github-issues.sh`).
> Gerado via `/new-project` (skill `novo-prd` → `prd-planejamento` → `project-manager` agent).

---

### Legenda de prioridade

| Prioridade | Significado |
|---|---|
| **P1** — Crítico | Bloqueia outras stories ou é requisito da wave atual |
| **P2** — Importante | Agrega valor significativo, fazer após P1 dentro da mesma wave |
| **P3** — Desejável | Nice-to-have, fazer se sobrar capacidade na wave |

---

### Formato

Cada wave começa com `## Wave: <Nome>` seguido de blockquote `> Milestone GitHub: \`<Nome>\` · Meta: <descrição>`.
USs dentro da wave usam heading nível-3 `### US-<N> — <título>` com metadata em uma linha:
`**Prioridade:** P<1|2|3>  ·  **Estimativa:** <valor>  ·  **Status:** <pendente|em andamento|concluída>`

Wave `Backlog` (catch-all) sempre existe no final — USs sem onda concreta caem aqui.

---

## Wave: Backlog
> Sem milestone atribuída. Mover para wave concreta ao priorizar.

<!-- Executar /new-project para popular waves (MVP, Release 1, etc.) e USs via entrevista guiada -->
