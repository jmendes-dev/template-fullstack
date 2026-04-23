# DESIGN.md — Regras Estruturais de UI/UX e Pipeline do Design System

> Ler quando: (a) task de frontend (criar/modificar componente), ou (b) gerar/regenerar o design system do projeto.
> **Identidade visual** (paleta, tipografia, tokens): responsabilidade de `docs/design-system/MASTER.md` de cada projeto.
> Em conflito: `MASTER.md` prevalece para visuais; este arquivo prevalece para estrutura (acessibilidade, responsividade, estados).

---

## Parte 1 — Regras Estruturais

### Stack de UI

| Camada | Tecnologia | Papel |
|---|---|---|
| Componentes | shadcn/ui | Primitivos (Button, Input, Select, Dialog, Sheet…) |
| Estilização | Tailwind CSS v4 | Utility-first, config via `@theme { }` no CSS |
| Ícones | Lucide React | Default — consistente com shadcn/ui |
| Gráficos | Recharts | Default para charts e dashboards |
| Forms | React Hook Form + standardSchemaResolver (Zod v4) | Validação client-side |
| Data fetching | TanStack Query + Hono RPC | Server state |
| Client state | Zustand | Auth, UI prefs |
| Toasts | Sonner | Feedback de ações (nunca `alert()`) |
| Animações | Tailwind `transition-*` + `animate-*` | Sem libs externas de animação |

---

### Layout: Sidebar + Top Bar

```
┌─────────────────────────────────────────────────────┐
│ [Sidebar]  │  [Top Bar: breadcrumb / tabs / busca / avatar] │
│            │──────────────────────────────────────────────────│
│  ☰ Logo    │                                                  │
│  □ Nav 1   │  [Page Content]                                  │
│  □ Nav 2   │  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  □ Nav 3   │  │ Card    │ │ Card    │ │ Card    │           │
│  ─────     │  └─────────┘ └─────────┘ └─────────┘           │
│  □ Config  │  ┌───────────────────────────────────┐           │
│  ○ Avatar  │  │ Table / Content                   │           │
│            │  └───────────────────────────────────┘           │
└─────────────────────────────────────────────────────┘
```

**Sidebar**
- Desktop (≥ 1024px): expandida, 240px (override no MASTER.md)
- Tablet (768–1023px): colapsada, ícones apenas, 64px
- Mobile (< 768px): oculta, acessível via hamburger (Sheet do shadcn/ui, `side="left"`)
- Item ativo: background accent + indicador lateral; separadores entre grupos (Separator)
- Seção inferior fixa: configurações + avatar; logo no topo

**Top Bar**
- Altura fixa: 48px. Sempre visível
- Conteúdo contextual: breadcrumb, tabs, busca, filtros
- Direito fixo: notificações (Bell) + avatar com dropdown
- Mobile: hamburger à esquerda, título no centro, avatar à direita

**Área de conteúdo**
- Padding: 24px desktop / 16px mobile. Max-width: 1280px
- Sidebar e top bar fixos; scroll vertical no conteúdo

**PageHeader** — usar em todas as páginas autenticadas:
```tsx
<PageHeader title="Título" subtitle="Opcional" actions={<Button>Ação</Button>} />
```
Tipografia e animação de entrada: seguir MASTER.md. Nunca usar `<h1>` inline.

**Páginas standalone** (onboarding, 404, login): `min-h-screen flex flex-col items-center justify-center`, card responsivo (`sm:max-w-[480px]`), animação de entrada obrigatória, brand mark obrigatório. Estilo visual: MASTER.md.

---

### Breakpoints e Responsividade

| Breakpoint | Largura | Sidebar | Tabelas |
|---|---|---|---|
| Mobile | < 768px | Drawer | Cards empilhados |
| Tablet | 768–1023px | Ícones (64px) | Colunas reduzidas |
| Desktop | 1024–1439px | Expandida (240px) | Tabela completa |
| Wide | ≥ 1440px | Expandida (240px) | + mais colunas |

- Mobile-first nos estilos. Conteúdo reorganiza, nunca some
- Toque: mínimo 44×44px. Gráficos: empilhados em mobile
- Tabelas: colapsar para cards (ver padrão abaixo)

---

### Tabelas de Dados (padrão híbrido)

Desktop: `<Table>` do shadcn/ui com sorting por header (↑↓), filtros acima (busca + dropdowns), paginação server-side ("Mostrando X-Y de Z"), status com `<Badge>`, ações por linha via `<DropdownMenu>` no ícone `⋯`.

Mobile: lista de cards com 3–4 campos prioritários + "Carregar mais" ou paginação anterior/próximo.

Regras: linha inteira clicável se há detalhe; checkbox para batch; empty state com ícone + mensagem + CTA; estilização (density, header, hover) no MASTER.md.

---

### Formulários

| Campos visíveis | Padrão |
|---|---|
| ≤ 6 | Seção única, submit no rodapé |
| 7–15 | Multi-step wizard (stepper + progresso + step de revisão) |
| Settings / edição | Seções colapsáveis (Collapsible), salvar global no rodapé |

Regras: labels acima do campo (nunca placeholder-only), `*` em obrigatórios, erros via `<FormMessage>`, loading com botão disabled + Loader2, campos condicionais com `animate-in`. Wizard: máx 4–5 campos por step; dados persistidos via React Hook Form ou Zustand.

---

### Gráficos e Dashboards

Usar `<ResponsiveContainer>` em todo gráfico. Cores: puxar do MASTER.md. Tooltip em todo gráfico; legenda em múltiplas séries. KPIs em grid 2–4 cards (label muted + número grande + variação). Skeleton por componente (progressivo, não tudo ou nada).

| Dado | Gráfico | Recharts |
|---|---|---|
| Evolução no tempo | Linha/Área | `LineChart` / `AreaChart` |
| Comparação | Barras | `BarChart` |
| Proporção | Donut | `PieChart` c/ innerRadius |
| Ranking | Barras horizontais | `BarChart layout="vertical"` |

---

### Estados Obrigatórios de UI

Todo componente com dados assíncronos DEVE implementar os 4 estados:

**1. Loading** — Skeleton rows/cards/retângulos (shadcn/ui). Nunca tela em branco ou spinner genérico.

**2. Empty** — Ícone Lucide grande (48–64px, muted) + mensagem descritiva + botão CTA primário.

**3. Error** — `<Alert variant="destructive">` + mensagem legível (não stack trace) + botão "Tentar novamente" que re-executa a query.

**4. Success** — Dados visíveis; transição suave do loading sem flash.

```tsx
const { data, isLoading, error } = useQuery({ ... });
if (isLoading) return <TableSkeleton />;
if (error) return <ErrorAlert onRetry={refetch} message={error.message} />;
if (!data?.length) return <EmptyState icon={FileX} message="Nenhum item" cta="Criar" />;
return <DataTable data={data} />;
```

---

### Acessibilidade (WCAG AA obrigatório)

**Contraste**: 4.5:1 texto normal, 3:1 texto grande (≥ 18px ou ≥ 14px bold) e ícones informativos.

**Teclado**: todo interativo acessível via Tab, ordem lógica, focus ring visível (não desabilitar `outline`). Modais: trap focus + Escape fecha. Dropdowns: arrow keys + Enter + Escape.

**Semântica**: `<nav>`, `<main>`, `<header>`, `<aside>`, `<section>`. Sidebar: `<aside><nav>`. Um `<h1>` por página. Inputs sempre com `<label>` associado.

**Motion**: `motion-safe:animate-*` do Tailwind. Nunca depender de animação para comunicar informação.

---

### Dark Mode

Não obrigatório. MASTER.md de cada projeto declara suporte.

- Com dark mode: variáveis CSS Tailwind v4/shadcn/ui, toggle Sun/Moon, respeitar `prefers-color-scheme`, persistir preferência
- Sem dark mode: usar apenas tema light, ainda usar variáveis CSS (não hardcodar)

---

### Animações e Transições

- Duração: 150–300ms micro, máx 500ms página. Easing: `ease-out` entradas, `ease-in` saídas
- Tokens específicos: definidos no MASTER.md

| Ação | Animação | Tailwind |
|---|---|---|
| Hover botão/card | Mudança de background | `transition-colors duration-150` |
| Abrir modal/sheet | Fade + slide | shadcn/ui (built-in) |
| Toast | Slide in | Sonner (built-in) |
| Campo condicional | Expand + fade | `animate-in fade-in slide-in-from-top-2` |
| Skeleton | Pulse | `animate-pulse` (built-in) |
| Spinner | Rotação | `animate-spin` no Loader2 |

Proibido: parallax, fade full-screen entre rotas, animações que bloqueiam interação, bouncing, auto-play.

---

### Feedback ao Usuário

| Ação | Toast |
|---|---|
| CRUD com sucesso | `toast.success("Item criado")` — 3s |
| Erro | `toast.error("Falha ao salvar")` — 5s |
| Desfazível | `toast("Removido", { action: { label: "Desfazer", onClick } })` — 5s |
| Processo | `toast.loading("Importando...")` — até completar |

Ações destrutivas: sempre `<AlertDialog>`, botão `variant="destructive"`, texto claro do impacto, cancelar com foco default.

---

### Design Brief e Integração com SDD

O `docs/design-system/design-brief.md` (~800 tokens) é o resumo compacto do MASTER.md injetado no prompt de cada `component-agent`. Contém valores literais (hex, px, weights) — não variáveis CSS. Regenerar sempre que MASTER.md mudar (via `ux-ui-designer`).

No spec de componente (`docs/specs/US-XX.spec.md`): referenciar qual padrão de tabela/form/chart se aplica, quais tokens do MASTER.md usa, quais estados implementa.

No prompt do component-agent, injetar: regra estrutural aplicável (seção deste arquivo) + `design-brief.md` + `pages/*.md` (se houver override).

**Page overrides** (`docs/design-system/pages/*.md`) — criar quando a página diverge significativamente:

| Condição | Decisão |
|---|---|
| Layout diferente do sidebar+topbar (onboarding, login) | → Criar override |
| Componentes complexos únicos (mapa, comparação) | → Criar override |
| Paleta/tipografia diferente do MASTER.md | → Criar override |
| Segue o padrão sem desvios | → Não criar |

O agente avalia automaticamente; override gerado junto com o spec na mesma aprovação.

---

### Anti-patterns

- ❌ UI genérica shadcn/ui sem customização de cores/radius/font do MASTER.md
- ❌ Todos os elementos com mesmo peso visual (sem hierarquia)
- ❌ Tela em branco durante loading (sempre Skeleton)
- ❌ Tabela/lista vazia sem empty state
- ❌ Erro silencioso (fetch falha sem feedback visual)
- ❌ Botão destrutivo sem `<AlertDialog>` de confirmação
- ❌ Placeholder como label (some ao digitar)
- ❌ `alert()`, `confirm()`, `prompt()` do browser
- ❌ Cores, fonts ou espaçamentos hardcoded (usar tokens do MASTER.md)
- ❌ CSS inline em React (usar Tailwind classes)
- ❌ Emojis como ícones funcionais (usar Lucide)
- ❌ Scroll horizontal em mobile
- ❌ Ícones sem `aria-label` ou texto adjacente
- ❌ Múltiplos toasts empilhados (máx 3 simultâneos)
- ❌ Modal dentro de modal
- ❌ Gradientes/neon/glassmorphism como default (reservar para MASTER.md)
- ❌ Componentes sem hover/focus state customizado
- ❌ `<h1>` inline — usar sempre `<PageHeader>`

---

## Parte 2 — Pipeline do Design System

> ⚠️ **Rodar ANTES** de `/new-project` — ver seção "Pré-requisito — Instalar ui-ux-pro-max" abaixo. O pipeline não tem fallback: sem a skill, não há design system personalizado, e projetos nascem com aparência genérica.

> Gera o design system completo em 3 passos:
> 1. **ui-ux-pro-max** gera base automática pela indústria/tipo do projeto
> 2. **Entrevista de refinamento** (~5–7 perguntas) ajusta com preferências do autor
> 3. **design-brief.md** gerado como resumo compacto para subagentes
>
> Output: `docs/design-system/MASTER.md` + `design-brief.md` + `pages/*.md` (quando necessário)
> Pré-requisitos: `docs/user-stories.md` e `docs/backlog.md` existentes

---

### Pré-requisito — Instalar ui-ux-pro-max ANTES de rodar `/new-project`

> Esta skill é **dependência externa obrigatória**. Sem ela, o Passo 1 do pipeline falha e o `MASTER.md` não é gerado — resultado: projeto nasce com UI genérica shadcn/ui sem personalidade (anti-pattern documentado).

**Opção A — Claude Code Marketplace:**
```
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

**Opção B — CLI:**
```bash
npm install -g uipro-cli
uipro init --ai claude       # por projeto
uipro init --ai claude --global  # global
```

Verificar: `python3 .claude/skills/ui-ux-pro-max/scripts/search.py "test" --domain style`

---

### Passo 1 — ui-ux-pro-max gera a base

```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py \
  "[indústria/tipo]" --design-system --persist -p "[NomeDoProjeto]"
```

Exemplos:
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "logistics SaaS B2B shipping" --design-system --persist -p "Cotamar"
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "CRM freelance lead management" --design-system --persist -p "FreelancerHunter"
```

Output: `docs/design-system/MASTER.md` (base). Ler antes do Passo 2.

---

### Passo 2 — Entrevista de refinamento

Colar no Claude (ou executar no Claude Code):

```
Você é um design lead sênior REFINANDO um design system base gerado automaticamente.

Leia: docs/design-system/MASTER.md + docs/user-stories.md + docs/backlog.md
Valide as recomendações do engine e refine com preferências do autor.
Gere: MASTER.md refinado + design-brief.md + pages/*.md (se necessário)

Você conhece DESIGN.md Parte 1: layout sidebar+topbar, tabelas híbridas,
formulários (seção única/wizard/colapsável), Recharts, shadcn/ui+Tailwind v4,
WCAG AA, dark mode opcional.

REGRAS DA ENTREVISTA:
- Máx 5–7 perguntas, UMA por vez
- Apresente o que o engine gerou antes de perguntar
- Quando vago, ofereça opções concretas (ex: "prefere Linear ou Notion?")
- Aceita screenshot/imagem como referência visual

PERGUNTAS OBRIGATÓRIAS (adaptar ordem):
1. Validação da base — engine gerou [estilo/paleta/tipografia]. Está alinhado?
2. Marca existente — logo, cores, fonte da marca já definidos?
3. Referências visuais — produto com a "cara" que você quer? E o oposto?
4. Tom e densidade — mais arejado ou mais denso?
5. Dark mode — precisa? Default ou toggle?
6. Páginas especiais — onboarding fullscreen, landing, login diverge do padrão?
7. Componentes com personalidade — dashboard, mapa, formulário complexo?
```

---

### Passo 3 — design-brief.md

Gerado automaticamente após o MASTER.md estar finalizado. Estrutura obrigatória:

```markdown
# Design Brief — [Nome do Projeto]
> Resumo compacto para subagentes. Fonte de verdade: MASTER.md. Regenerar ao mudar MASTER.md.

## Visual
Estilo: [1 linha]  Radius: [por elemento]  Shadows: [descrição]

## Tipografia
Fontes: [family (weights)]
H1: [font weight size] — H2: ... — Body: ... — Small: ... — Mono: ...

## Cores
Primary: [hex] — hover: [hex] — fg: [hex]
Secondary: [hex] — Accent: [hex]
Background: [hex] — Surface: [hex] — Foreground: [hex] — Muted: [hex]
Border: [hex] — Sidebar: bg [hex] text [hex] active [hex]
Success/Warning/Error: [hex] (bg [hex])

## Componentes
Tabelas: [density, header, cell]  KPIs: [bg, label, value, grid]
Cards: [borda, sombra, padding]   Badges: [radius, size, padding]

## Animações
Entrada: [duração easing]  Stagger: [delay]  Regra: só transform e opacity

## Anti-patterns
[1–2 linhas específicas do projeto]

## Checklist
- [ ] Cores do brief (sem hex hardcoded, sem defaults shadcn)
- [ ] Tipografia do brief (font, weight, size por elemento)
- [ ] Radius do brief
- [ ] 4 estados: loading/empty/error/success
- [ ] Responsivo: mobile stack → desktop grid
- [ ] Animação de entrada aplicada
- [ ] Hover/focus states com transition
```

**Regras**: máx ~800 tokens; valores literais (hex/px/weights), não variáveis CSS; sem histórico ou justificativas.

---

### Formato do MASTER.md

Estrutura obrigatória do output:

```markdown
# Design System — [Nome do Projeto]
> Gerado em [data]. Fonte de verdade visual.
> Regras estruturais: DESIGN.md Parte 1. Este arquivo: personalidade visual.

## Direção visual
Tom / Estilo / Referências / Anti-referências

## Paleta de cores
Token | Hex | Uso — projeto (primary, secondary, accent, background, surface, muted, border)
                   + semânticas (success, warning, error, info)

## Tokens Tailwind v4
@theme { --color-primary: #...; ... }

## Tipografia
Elemento | Font | Weight | Tamanho | Line-height + Google Fonts URL

## Dark mode
Suporte (sim/não) + modo default + mapeamento dark (se sim)

## Superfícies e elevação
Tabela de superfícies + border-radius por tipo de elemento

## Overrides de componentes
Sidebar / Cards / Tabelas / Badges / Gráficos / Animações
(documentar apenas o que diverge de DESIGN.md Parte 1)

## Overrides por página
Página | Arquivo pages/*.md | Motivo

## Checklist de qualidade visual
- [ ] Cores seguem paleta (sem hex hardcoded)
- [ ] Tipografia segue escala
- [ ] Contraste WCAG AA validado
- [ ] 4 estados implementados
- [ ] Responsivo nos 4 breakpoints
- [ ] Hover/focus states presentes
- [ ] Ícones Lucide (sem emojis)
- [ ] Animações com prefers-reduced-motion

## Changelog
| Data | Tipo | Alteração | Motivo |
```

---

### Formato dos pages/*.md

```markdown
# Override de Design — [Nome da Página]
> Override para MASTER.md. Apenas desvios documentados aqui. Resto segue o Master.

## Layout
[Se diferente do padrão sidebar+topbar]

## Componentes específicos desta página
[Regras visuais de componentes únicos]

## Tokens específicos
[Cores/tokens que diferem do MASTER.md]
```

---

### Checklist pós-pipeline

- [ ] Passo 1: ui-ux-pro-max executado com `--design-system --persist`
- [ ] Passo 2: entrevista concluída e preferências incorporadas
- [ ] Paleta completa (projeto + semânticas)
- [ ] Tipografia com Google Fonts URL
- [ ] Tokens `@theme { }` prontos
- [ ] Dark mode decidido
- [ ] `docs/design-system/MASTER.md` gerado e refinado
- [ ] `docs/design-system/design-brief.md` gerado (~800 tokens)
- [ ] `docs/design-system/pages/*.md` gerados (se aplicável)
- [ ] Checklist de qualidade visual incluso no MASTER.md

---

### Redesign ou evolução visual

1. Informe o MASTER.md atual
2. Descreva o que quer mudar e por quê
3. Peça um **diff** — apenas o que muda, não reescrita completa
4. Valide se os overrides de páginas ainda fazem sentido
5. Regenerar `design-brief.md` após qualquer mudança no MASTER.md

### Features em projetos existentes

O fluxo SDD avalia automaticamente se a feature precisa de page override. Se precisa, o override é gerado junto com o spec na mesma aprovação. MASTER.md não muda — apenas novos `pages/*.md`. Se a feature introduz padrão visual que afeta todo o projeto, atualizar MASTER.md + brief.
