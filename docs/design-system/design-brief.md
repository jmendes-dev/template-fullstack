# Design Brief

> Resumo compacto (~800 tokens) do MASTER.md para injeção em subagentes de componente.
> **Fonte de verdade:** `docs/design-system/MASTER.md` — regenerar se MASTER.md mudar.
> **Gerado por:** `ux-ui-designer` (Passo 4 do `/new-project`).

---

<!-- EXEMPLO — Substituir quando MASTER.md estiver preenchido -->
<!-- Este arquivo deve ser preenchido pelo ux-ui-designer após aprovação do MASTER.md -->

## Identidade Visual

- **Tom**: [ex: Moderno e profissional — confiança sem ser corporativo]
- **Público**: [ex: Gestores técnicos de médias empresas — denso em informação, mobile secundário]

## Paleta (tokens Tailwind)

| Token | Hex | Uso |
|---|---|---|
| `primary` | `#2563EB` | CTAs, links, foco |
| `primary-foreground` | `#FFFFFF` | Texto sobre primary |
| `secondary` | `#F1F5F9` | Backgrounds, cards |
| `muted` | `#64748B` | Texto secundário |
| `destructive` | `#EF4444` | Erros, deleção |
| `success` | `#22C55E` | Confirmações |
| `background` | `#FFFFFF` | Fundo base |
| `foreground` | `#0F172A` | Texto principal |
| `border` | `#E2E8F0` | Bordas e divisores |

## Tipografia

- **Família**: `Inter` (corpo) · `Cal Sans` ou `Inter` semibold (headings)
- **Escala**: xs=12 · sm=14 · base=16 · lg=18 · xl=20 · 2xl=24 · 3xl=30
- **Peso**: 400 (corpo) · 500 (labels) · 600 (headings) · 700 (display)

## Espaçamento e Layout

- **Grid**: 12 colunas · gutter 24px (desktop) · 16px (mobile)
- **Sidebar**: 240px fixa (desktop) · drawer em mobile
- **Container max**: 1280px · padding lateral 24px
- **Border radius**: sm=4px · base=8px · lg=12px · xl=16px · full=9999px

## Sombras

- `sm`: `0 1px 2px rgba(0,0,0,0.05)` — cards elevados levemente
- `md`: `0 4px 6px rgba(0,0,0,0.07)` — dropdowns, modais
- `lg`: `0 10px 15px rgba(0,0,0,0.10)` — modais focus

## Animações

- **Duração padrão**: 150ms (micro) · 200ms (hover) · 300ms (modais/drawers)
- **Easing**: `ease-out` para entradas · `ease-in` para saídas
- **Regra**: nunca animar layout (position/width) — apenas opacity/transform

## Componentes shadcn/ui — Overrides

| Componente | Override |
|---|---|
| Button (primary) | `bg-primary text-primary-foreground hover:bg-primary/90` |
| Button (destructive) | `bg-destructive/10 text-destructive border border-destructive/20 hover:bg-destructive/20` |
| Input | `border-border focus:ring-2 focus:ring-primary/20 focus:border-primary` |
| Card | `border border-border shadow-sm rounded-lg` |
| Badge (success) | `bg-success/10 text-success` |
| Badge (error) | `bg-destructive/10 text-destructive` |

## Estados obrigatórios (todos os componentes)

1. **Loading**: skeleton com `animate-pulse` · nunca spinner global
2. **Empty**: ícone + copy contextual + CTA quando aplicável
3. **Error**: mensagem clara + botão de retry · nunca stack trace exposto
4. **Success**: dados renderizados · toast Sonner para feedback de ação

## Acessibilidade

- Contraste mínimo AA (4.5:1 para texto, 3:1 para UI)
- Focus ring: `focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2`
- Labels visíveis em todos os inputs (nunca só placeholder)
- Aria-live regions para estados de loading/erro

## Anti-patterns proibidos

- ❌ Cores hardcoded — usar apenas tokens CSS/Tailwind
- ❌ Z-index arbitrário — usar escala: 10/20/30/40/50
- ❌ `overflow: hidden` em containers scrolláveis
- ❌ Texto em imagem (acessibilidade)
- ❌ Animações sem `prefers-reduced-motion` check
