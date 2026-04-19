# DESIGN.md — Regras de Design e Pipeline do Design System

> Substitui `claude-design.md` (regras estruturais de UI/UX) e `DESIGN_SYSTEM.md` (pipeline de geração do design system via ui-ux-pro-max).
> Ler quando: (a) task de frontend (criar/modificar componente), ou (b) gerar/regenerar o design system do projeto.

---

## Parte 1 — Regras Estruturais de UI/UX

> Este arquivo define os padrões de UI/UX e frontend design reutilizáveis entre projetos.
> Contém regras estruturais (layout, componentes, responsividade, acessibilidade) amarradas à stack do projeto.
> Não contém identidade visual, paleta de cores nem tipografia — isso é responsabilidade do `docs/design-system/MASTER.md` de cada projeto.
>
> **Override por projeto**: qualquer regra desta parte pode ser sobrescrita pelo `docs/design-system/MASTER.md` do projeto.
> Se houver conflito, `MASTER.md` prevalece sobre as regras desta parte para decisões visuais.
> Esta parte prevalece para decisões estruturais (acessibilidade, responsividade, estados obrigatórios).

---

## Stack de UI (referência rápida)

| Camada | Tecnologia | Papel |
|---|---|---|
| Componentes | shadcn/ui | Primitivos (Button, Input, Select, Dialog, Sheet, etc.) |
| Estilização | Tailwind CSS v4 | Utility-first, config via `@theme { }` no CSS |
| Ícones | Lucide React | Biblioteca default — consistente com shadcn/ui |
| Gráficos | Recharts | Biblioteca default para charts e dashboards |
| Forms | React Hook Form + standardSchemaResolver (Zod v4) | Validação client-side |
| Data fetching | TanStack Query + Hono RPC | Server state |
| Client state | Zustand | Estado local compartilhado (auth, UI prefs) |
| Toasts | Sonner | Feedback de ações (nunca `alert()`) |
| Animações | Tailwind `transition-*` + `animate-*` | Sem libs externas de animação |

> O `docs/design-system/MASTER.md` de cada projeto pode sugerir bibliotecas complementares (ex: outra lib de gráficos, outra lib de ícones), mas as acima são o default e não devem ser substituídas sem justificativa.

---

## Qualidade Visual — Princípios

> Esta seção define os princípios que diferenciam UI profissional de UI genérica.
> Aplicar estes princípios em conjunto com os tokens do `MASTER.md` de cada projeto.

### Antes de implementar qualquer componente, considerar:

1. **Tipografia com intenção.** As fontes do MASTER.md foram escolhidas por um motivo. Respeitar a escala tipográfica (H1, H2, body, small, mono) rigorosamente. Nunca usar font-size arbitrário. O pairing display + body cria hierarquia — não achatar tudo em uma só fonte.

2. **Cor com hierarquia.** A paleta do MASTER.md tem cores dominantes e cores de accent. Usar a primary como dominante em CTAs e elementos de destaque. Não distribuir cores uniformemente — a hierarquia visual vem da dominância de uma cor sobre as outras.

3. **Composição espacial com ritmo.** O MASTER.md define density e spacing. Respeitar padding, gap e margin conforme definido. White space é um elemento de design — não preencher tudo. Alinhar elementos em grid com consistência.

4. **Motion nos momentos certos.** Animações definidas no MASTER.md devem ser aplicadas em: page load (entrada de conteúdo), transição de estados (loading → success), feedback de interação (hover, focus). Stagger delays criam ritmo. Não animar tudo — animar o que importa.

5. **Detalhes fazem a diferença.** Border-radius, hover states, focus rings, transições de cor — cada detalhe do MASTER.md existe por uma razão. Não usar defaults genéricos do shadcn/ui quando o MASTER.md define valores específicos.

### O que evitar em TODOS os projetos:

- ❌ UI genérica do shadcn/ui sem customização (cores, radius, font, spacing do MASTER.md não aplicados)
- ❌ Todos os componentes com mesmo peso visual (sem hierarquia — KPIs, cards e tabelas indistinguíveis)
- ❌ Layouts previsíveis sem tensão visual (tudo centralizado, tudo com mesmo padding, tudo simétrico)
- ❌ Cores distribuídas uniformemente sem dominância (3 cores com mesma presença visual)
- ❌ Componentes sem hover/focus state customizado (usando apenas defaults do browser/shadcn)
- ❌ Tabelas sem header estilizado (header e body visualmente iguais)
- ❌ Empty states com apenas texto sem ícone e sem CTA

### Como o design-brief.md conecta design e código

O `docs/design-system/design-brief.md` é o resumo compacto (~800 tokens) do MASTER.md, otimizado para injeção no prompt do `component-agent`. Ele contém:

- Valores literais (hex, px, weights) — não variáveis CSS
- Regras por componente (tabelas, KPIs, cards, badges)
- Animações com duração e easing
- Anti-patterns específicos do projeto
- Visual checklist

O agente principal injeta o design-brief.md no prompt do component-agent (ver `claude-sdd.md → seção "Contextos de Subagente"` → Template: component-agent). O subagente aplica esses valores diretamente no código.

### Geração e Manutenção do Design Brief

> **OBRIGATÓRIO**: Sempre que `docs/design-system/MASTER.md` for criado ou atualizado:

1. Lançar `ux-ui-designer` com a task: _"Regenerar design-brief.md a partir do MASTER.md atualizado"_
2. O design-brief.md deve ter exatamente ~800 tokens (±10%)
3. Estrutura obrigatória do brief: Paleta → Tipografia → Spacing/Radius → Componentes principais → Tom e Voz → Anti-patterns
4. Commitar após regeneração: `docs(design): regenerate design-brief from MASTER.md`

**Sinais de que o brief está desatualizado:**
- O hook `post-commit` avisou que MASTER.md foi modificado
- Novo projeto (brief é template vazio)
- Componente frontend diverge visualmente do MASTER.md

**Nunca:**
- ❌ Cortar o design-brief do contexto de subagente para economizar tokens (usar stack rules primeiro)
- ❌ Referenciar design-brief sem verificar se está sincronizado com MASTER.md
- ❌ Criar page override sem antes verificar se o MASTER.md base está completo

---

## Layout: Sidebar + Top Bar

### Estrutura default de página

```
┌─────────────────────────────────────────────────────┐
│ [Sidebar]  │  [Top Bar: breadcrumb / tabs / busca / avatar] │
│            │──────────────────────────────────────────────────│
│  ☰ Logo    │                                                  │
│            │  [Page Content]                                  │
│  □ Nav 1   │                                                  │
│  □ Nav 2   │  ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  □ Nav 3   │  │ Card    │ │ Card    │ │ Card    │           │
│  □ Nav 4   │  └─────────┘ └─────────┘ └─────────┘           │
│            │                                                  │
│  ─────     │  ┌───────────────────────────────────┐           │
│  □ Config  │  │ Table / Content                   │           │
│  ○ Avatar  │  │                                   │           │
│            │  └───────────────────────────────────┘           │
└─────────────────────────────────────────────────────┘
```

### Sidebar

- **Desktop (≥ 1024px)**: sidebar expandida com ícones + labels. Largura: 240px (override no MASTER.md)
- **Tablet (768px–1023px)**: sidebar colapsada, apenas ícones. Largura: 64px
- **Mobile (< 768px)**: sidebar oculta, acessível via hamburger menu (Sheet do shadcn/ui, side="left")
- Itens de navegação mudam conforme o perfil do usuário (ex: armador vs exportação vs admin)
- Seção inferior fixa: configurações + avatar/perfil
- Logo no topo da sidebar, colapsado em tablet (ícone only)
- Item ativo com background accent + indicador lateral (borda esquerda ou pill)
- Separadores visuais entre grupos de navegação (Separator do shadcn/ui)
- **Cores e estilo visual da sidebar**: definidos no `MASTER.md` do projeto

### Top Bar

- Sempre visível, altura fixa: 48px
- Conteúdo contextual por página: breadcrumb, tabs de sub-navegação, campo de busca, filtros
- Lado direito fixo: notificações (bell icon), avatar com dropdown menu
- Em mobile: hamburger menu no lado esquerdo, título da página no centro, avatar à direita
- Não usar top bar para navegação principal — isso é papel da sidebar

### Área de conteúdo

- Padding horizontal: 24px desktop, 16px mobile
- Padding vertical: 24px desktop, 16px mobile
- Max-width do conteúdo: 1280px (centralizado quando tela > 1280px)
- Scroll vertical no conteúdo, sidebar e top bar fixos

### Padrão PageHeader (páginas autenticadas)

Usar o componente `PageHeader` em **todas** as páginas com AppShell:

```tsx
<PageHeader
  title="Título da Página"
  subtitle="Subtítulo opcional"   // omitir se não houver
  actions={<Button>Ação</Button>} // omitir se não houver ação
/>
```

- Animação automática: usar animação de entrada definida no MASTER.md do projeto
- Tipografia: seguir escala do MASTER.md (H1 para título, small/muted para subtítulo)
- `actions`: alinhados à direita com `flex shrink-0 items-center gap-2`
- Nunca usar `<h1>` inline em páginas — sempre PageHeader

### Padrão de páginas standalone (sem sidebar)

Páginas fora do AppShell (onboarding, pending, 404, 403, loading state):

O estilo visual de páginas standalone é definido no `docs/design-system/MASTER.md` de cada projeto (background pattern, brand mark, card style, animações). Esta parte define apenas as regras **estruturais**:

- **Wrapper**: `min-h-screen flex flex-col items-center justify-center`
- **Card**: max-width responsivo (ex: `sm:max-w-[480px]`), full-width em mobile, padding responsivo
- **Animação de entrada**: obrigatória (definida no MASTER.md)
- **Brand mark**: obrigatório no card (formato e estilo definidos no MASTER.md)
- **Loading state global**: usar Spinner com cor do MASTER.md sobre background pattern do MASTER.md

> **Regra**: nunca hardcodar cores, backgrounds ou brand marks neste arquivo.
> Esses elementos são visuais e pertencem ao MASTER.md de cada projeto.

---

## Breakpoints e Responsividade

| Breakpoint | Largura | Sidebar | Tabelas | Formulários |
|---|---|---|---|---|
| Mobile | < 768px | Drawer (Sheet) | Cards empilhados | Campos full-width, 1 coluna |
| Tablet | 768px–1023px | Colapsada (ícones) | Tabela com colunas reduzidas | 2 colunas quando cabe |
| Desktop | 1024px–1439px | Expandida (240px) | Tabela completa | 2-3 colunas |
| Wide | ≥ 1440px | Expandida (240px) | Tabela completa + mais colunas | 2-3 colunas |

### Regras de responsividade

- **Mobile-first nos estilos**: começar com layout mobile, expandir com breakpoints
- **Conteúdo não desaparece**: em mobile, conteúdo que não cabe é reorganizado (stack vertical), nunca escondido
- **Toque**: alvos de toque mínimo 44x44px em mobile (botões, links, itens de lista)
- **Tabelas**: ver seção "Tabelas de dados" — colapsar para cards em mobile
- **Gráficos**: redimensionar proporcionalmente. Em mobile, empilhar verticalmente (nunca lado a lado)

---

## Tabelas de Dados (padrão híbrido)

### Desktop (≥ 768px): tabela completa

```
┌──────────────────────────────────────────────────────────┐
│ [Busca]  [Filtro 1]  [Filtro 2]        [Ações: export] │
├──────────────────────────────────────────────────────────┤
│ Coluna ↕ │ Coluna   │ Coluna   │ Status   │ Ações      │
│──────────┼──────────┼──────────┼──────────┼────────────│
│ valor    │ valor    │ valor    │ ● Ativo  │ ⋯          │
│ valor    │ valor    │ valor    │ ○ Vencido│ ⋯          │
├──────────────────────────────────────────────────────────┤
│ Mostrando 1-20 de 156              │ ← 1 2 3 ... 8 → │
└──────────────────────────────────────────────────────────┘
```

### Mobile (< 768px): lista de cards

```
┌──────────────────────────┐
│ [Busca]     [Filtros ▾]  │
├──────────────────────────┤
│ ┌──────────────────────┐ │
│ │ Título         ● Ativo│ │
│ │ Label: valor         │ │
│ │ Label: valor         │ │
│ │ Label: valor    [⋯]  │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Título       ○ Vencido│ │
│ │ Label: valor         │ │
│ │ Label: valor         │ │
│ │ Label: valor    [⋯]  │ │
│ └──────────────────────┘ │
│      Carregar mais ↓     │
└──────────────────────────┘
```

### Regras de tabelas

- **Componente base**: usar `<Table>` do shadcn/ui para a versão desktop
- **Sorting**: sorting por header de coluna (indicador visual ↑↓). Server-side para datasets > 100 registros
- **Filtros**: acima da tabela (padrão filtros externos). Busca textual + dropdowns de filtro. Em mobile, filtros colapsam em dropdown/sheet
- **Paginação**: server-side. Formato: "Mostrando X-Y de Z" + botões de página. Em mobile, usar "Carregar mais" (infinite scroll) ou paginação simplificada (anterior/próximo)
- **Status badges**: usar Badge do shadcn/ui com variantes semânticas (default, secondary, destructive, outline)
- **Ações por linha**: DropdownMenu do shadcn/ui no ícone `⋯` (MoreHorizontal do Lucide)
- **Linha clicável**: quando existe página de detalhe, a linha inteira é clicável (cursor-pointer, hover com background)
- **Seleção de linhas**: Checkbox na primeira coluna quando há ações em batch (ex: deletar múltiplos)
- **Empty state**: quando tabela vazia, exibir ilustração + mensagem + CTA (ver seção "Estados obrigatórios")
- **Colunas em mobile**: identificar 3-4 campos prioritários para o card. Demais ficam na tela de detalhe
- **Estilização visual** (density, header bg, cell size, hover color): definidos no `MASTER.md` do projeto

---

## Formulários

### Regra de complexidade

| Quantidade de campos visíveis | Padrão | Componente |
|---|---|---|
| ≤ 6 campos | Seção única | Form simples com submit |
| 7–15 campos | Multi-step wizard | Stepper + navegação entre steps |
| Tela de edição/settings | Seções colapsáveis | Accordion/Collapsible por grupo |

> O `docs/design-system/MASTER.md` do projeto pode sobrescrever essa regra para formulários específicos.

### Seção única (≤ 6 campos)

- Todos os campos visíveis, sem scroll excessivo
- Campos relacionados lado a lado em desktop (grid 2 colunas), empilhados em mobile
- Botões de ação no rodapé: "Cancelar" (secondary) à esquerda, "Salvar" (primary) à direita
- Validação inline (erro abaixo do campo) via React Hook Form + Zod

### Multi-step wizard (7–15 campos)

- Stepper visual no topo mostrando etapas (step atual highlighted, concluídos com check, pendentes em cinza)
- Barra de progresso opcional abaixo do stepper
- Máximo 4-5 campos por step
- Navegação: "Voltar" (ghost) à esquerda, "Próximo" (primary) à direita. Último step: "Enviar" / "Confirmar"
- Validação por step: não avança se o step atual tem erros
- Step final de revisão: resumo read-only de todos os dados preenchidos, com link "Editar" por seção
- Dados persistidos entre steps via React Hook Form (um form wrapping todos os steps) ou Zustand

### Seções colapsáveis (edição/settings)

- Cada grupo de campos em um Collapsible do shadcn/ui
- Header do collapsible: título do grupo + ícone chevron
- Primeira seção aberta por default, demais fechadas
- Botão "Salvar" global no rodapé da página (não por seção)
- Indicador visual de campos modificados (dirty state)

### Regras gerais de formulários

- **Labels**: sempre acima do campo, nunca placeholder-only (acessibilidade)
- **Placeholders**: exemplo do formato esperado, não repetição do label
- **Campos obrigatórios**: indicar com asterisco `*` no label
- **Erros**: texto vermelho abaixo do campo, borda do campo vermelha. Usar FormMessage do shadcn/ui
- **Sucesso de submissão**: toast Sonner com mensagem de confirmação + redirect ou close
- **Loading durante submit**: botão disabled com spinner (Loader2 do Lucide girando)
- **Campos condicionais**: exibir/ocultar com animação suave (Tailwind `animate-in`). Não usar display:none abrupto
- **Máscaras de input**: usar para CNPJ, CPF, telefone, CEP (formatar enquanto digita)
- **Autocomplete**: usar Combobox/Command do shadcn/ui para campos com busca (portos, cidades, etc.)

---

## Gráficos e Dashboards

### Biblioteca default: Recharts

- Usar `ResponsiveContainer` em todo gráfico para redimensionar automaticamente
- Cores dos gráficos: puxar do design system do projeto (`MASTER.md`). Se não definido, usar a paleta semântica do Tailwind/shadcn
- Tooltip em todo gráfico: exibir valores ao hover
- Legenda quando há múltiplas séries
- Eixos com labels legíveis (formatar números: milhares com K, milhões com M, moeda com R$/USD)

### Layout de dashboard

```
┌─────────────────────────────────────────────────┐
│ [Filtros globais: período, origem, destino...]  │
├────────┬────────┬────────┬──────────────────────┤
│ KPI 1  │ KPI 2  │ KPI 3  │ KPI 4              │
├────────┴────────┴────────┴──────────────────────┤
│ ┌───────────────────┐ ┌───────────────────────┐ │
│ │ Gráfico principal │ │ Gráfico secundário    │ │
│ │ (LineChart)        │ │ (BarChart)            │ │
│ └───────────────────┘ └───────────────────────┘ │
│ ┌───────────────────────────────────────────────┐│
│ │ Tabela/lista de dados                        ││
│ └───────────────────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

- **KPI cards**: grid de 2-4 cards no topo. Cada card: label muted + número grande + variação percentual (verde/vermelho). Estilo visual do card definido no MASTER.md
- **Filtros globais**: acima dos KPIs. Todos os componentes reagem ao mesmo filtro (compartilhar via query params ou Zustand)
- **Gráficos**: grid 2 colunas em desktop, empilhados em mobile
- **Tabela de dados**: abaixo dos gráficos, full-width
- **Skeleton**: cada componente do dashboard tem seu próprio skeleton independente (carregar progressivamente, não tudo ou nada)

### Tipos de gráfico recomendados por uso

| Dado | Tipo de gráfico | Componente Recharts |
|---|---|---|
| Evolução ao longo do tempo | Linha | `LineChart` / `AreaChart` |
| Comparação entre categorias | Barras | `BarChart` (vertical) |
| Proporção/distribuição | Pizza/Donut | `PieChart` com innerRadius |
| Ranking | Barras horizontais | `BarChart` (layout="vertical") |
| Correlação entre 2 variáveis | Dispersão | `ScatterChart` |
| Composição ao longo do tempo | Área empilhada | `AreaChart` (stacked) |

> O `docs/design-system/MASTER.md` do projeto pode sugerir bibliotecas alternativas (Chart.js, D3, Nivo) para casos específicos. O default é Recharts.

---

## Estados Obrigatórios de UI

Todo componente que exibe dados assíncronos DEVE implementar todos os quatro estados:

### 1. Loading

- **Tabelas**: Skeleton rows (4-6 linhas de Skeleton do shadcn/ui com widths variados)
- **Cards/KPIs**: Skeleton retangular no tamanho do card
- **Gráficos**: Skeleton retangular no tamanho do gráfico
- **Formulários**: campos disabled com Skeleton no lugar dos valores
- **Nunca**: tela em branco, spinner genérico centralizado, texto "Carregando..."

### 2. Empty

- **Ícone**: ícone Lucide relevante em tamanho grande (48-64px), cor muted
- **Mensagem**: texto descritivo centralizado ("Nenhuma cotação cadastrada ainda")
- **CTA**: botão primário com ação ("Cadastrar primeira cotação")
- **Nunca**: apenas texto sem CTA, tabela vazia com headers

### 3. Error

- **Componente**: Alert do shadcn/ui com `variant="destructive"`
- **Mensagem**: texto descritivo do erro (não stack trace, não código técnico)
- **Ação**: botão "Tentar novamente" que re-executa a query
- **Nunca**: erro silencioso, console.error sem feedback ao usuário

### 4. Success (dados presentes)

- O estado normal de exibição dos dados
- Transição suave do loading para o conteúdo (sem flash/jump)

### Pattern de implementação

```tsx
const { data, isLoading, error } = useQuery({ ... });

if (isLoading) return <TableSkeleton />;
if (error) return <ErrorAlert onRetry={refetch} message={error.message} />;
if (!data?.length) return <EmptyState icon={FileX} message="Nenhum item" cta="Criar" />;
return <DataTable data={data} />;
```

---

## Acessibilidade (WCAG AA obrigatório)

### Contraste

- Texto normal: ratio mínimo 4.5:1 contra o background
- Texto grande (≥ 18px ou ≥ 14px bold): ratio mínimo 3:1
- Ícones e elementos gráficos informativos: ratio mínimo 3:1
- Validar com DevTools ou extensão de acessibilidade

### Navegação por teclado

- Todo elemento interativo acessível via Tab
- Ordem de tab lógica (segue a ordem visual)
- Focus ring visível em todo elemento focável (shadcn/ui já trata isso — não desabilitar `outline`)
- Modais (Dialog do shadcn/ui): trap focus dentro do modal, Escape fecha
- Dropdowns: arrow keys para navegar, Enter para selecionar, Escape para fechar

### Semântica

- Usar elementos HTML semânticos: `<nav>`, `<main>`, `<header>`, `<aside>`, `<section>`, `<article>`
- Sidebar: `<aside>` com `<nav>` interno
- Top bar: `<header>`
- Área de conteúdo: `<main>`
- Heading hierarchy: h1 para título da página (um por página), h2 para seções, h3 para sub-seções
- Imagens: `alt` text obrigatório (decorativas: `alt=""`)
- Formulários: todo input com `<label>` associado (shadcn/ui FormField já faz isso)

### Motion

- Respeitar `prefers-reduced-motion`: desabilitar animações decorativas quando ativo
- Implementar via `motion-safe:` prefix do Tailwind (ex: `motion-safe:animate-in`)
- Nunca depender de animação para comunicar informação

---

## Dark Mode (opcional por projeto)

Dark mode não é obrigatório. O `docs/design-system/MASTER.md` de cada projeto declara se o projeto suporta dark mode.

### Se o projeto suportar dark mode:

- Usar variáveis CSS do Tailwind v4 / shadcn/ui (já preparadas para dark mode)
- Toggle no header ou settings (ícone Sun/Moon do Lucide)
- Respeitar `prefers-color-scheme` do sistema como default
- Persistir preferência no localStorage ou no perfil do usuário
- Testar todo componente em ambos os modos

### Se o projeto NÃO suportar dark mode:

- Usar apenas o tema light
- Não incluir toggle de tema
- Ainda assim usar variáveis CSS (não hardcodar cores) para facilitar adição futura

---

## Animações e Transições

### Princípios

- Animações são funcionais, não decorativas. Indicam mudança de estado, entrada/saída, feedback
- Duração: 150-300ms para micro-interações, máximo 500ms para transições de página
- Easing: `ease-out` para entradas, `ease-in` para saídas
- Sem animação de loading além de skeleton pulse e spinner de botão
- **Tokens de animação específicos**: definidos no `MASTER.md` do projeto

### Padrões permitidos

| Ação | Animação | Implementação Tailwind |
|---|---|---|
| Hover em botão/card | Leve mudança de background | `transition-colors duration-150` |
| Abrir modal/sheet | Fade in + slide | shadcn/ui Dialog/Sheet (built-in) |
| Toast aparecendo | Slide in pela borda | Sonner (built-in) |
| Campo condicional aparecendo | Expand + fade | `animate-in fade-in slide-in-from-top-2` |
| Skeleton pulsando | Pulse | `animate-pulse` (shadcn/ui Skeleton built-in) |
| Spinner de loading | Rotação | `animate-spin` no ícone Loader2 |
| Accordion expandindo | Height transition | shadcn/ui Collapsible (built-in) |

### Proibições

- ❌ Animações de parallax ou scroll-driven
- ❌ Transições de página full-screen (fade entre rotas)
- ❌ Animações que bloqueiam interação (sem delay antes de poder clicar)
- ❌ Bouncing, jiggling ou animações "chamativas"
- ❌ Auto-play de qualquer tipo (sem carrosséis automáticos)

---

## Feedback ao Usuário

### Toasts (Sonner)

| Ação | Tipo de toast | Duração |
|---|---|---|
| Criação/update com sucesso | `toast.success("Item criado")` | 3s (auto-dismiss) |
| Ação com erro | `toast.error("Falha ao salvar")` | 5s (auto-dismiss) |
| Ação que pode ser desfeita | `toast("Item removido", { action: { label: "Desfazer", onClick } })` | 5s |
| Processo em andamento | `toast.loading("Importando planilha...")` | Até completar |

### Quando usar cada tipo de feedback

| Feedback | Usar quando |
|---|---|
| Toast | Ações CRUD com sucesso/erro, notificações transitórias |
| Alert inline | Erros de validação de formulário, avisos dentro do contexto da página |
| Dialog de confirmação | Ações destrutivas (deletar, desativar) — sempre pedir confirmação |
| Badge/indicador | Status de entidade (ativo/inativo, pendente/aprovado) |
| Empty state | Lista/tabela sem dados |

### Ações destrutivas

- Sempre usar AlertDialog do shadcn/ui (não Dialog simples)
- Botão de confirmação com `variant="destructive"`
- Texto claro do que será afetado: "Isso vai desativar o usuário João Silva. Ele perderá acesso ao sistema."
- Botão de cancelar com foco default (não o botão destrutivo)

---

## Componentes Recorrentes

### Page header

Toda página tem um header consistente:

```
[Breadcrumb (se profundidade > 1)]
[Título da página]                    [Ações: botão primário, filtros]
[Descrição opcional em texto muted]
```

- Título: `h1`, seguir escala tipográfica do MASTER.md
- Descrição: texto small em cor muted do MASTER.md
- Ações primárias: lado direito, botão com ícone (ex: `<Plus /> Nova cotação`)

### Badges de status

Padronizar variantes de Badge do shadcn/ui para status recorrentes:

| Status | Variante | Cor sugerida |
|---|---|---|
| Ativo / Aprovado / Vigente | `default` ou custom success | Verde |
| Pendente / Aguardando | `secondary` ou custom warning | Amarelo/amber |
| Vencido / Inativo / Rejeitado | `destructive` ou custom | Vermelho |
| Rascunho / Novo | `outline` | Neutro |

> Cores exatas e estilo de badges definidos no `MASTER.md` do projeto.

### Modais e Sheets

| Tamanho do conteúdo | Componente | Uso |
|---|---|---|
| Confirmação simples (1-2 parágrafos) | AlertDialog | Ações destrutivas |
| Formulário curto (≤ 4 campos) | Dialog | Criação rápida, edição inline |
| Formulário médio (5-8 campos) | Sheet (side="right") | Criação/edição sem sair da página |
| Conteúdo complexo | Página dedicada (rota) | Formulário wizard, detalhe completo |

### Notificações in-app (sino)

- Ícone Bell do Lucide no top bar, lado direito
- Badge numérico (vermelho) quando há notificações não lidas
- Dropdown (Popover do shadcn/ui) com lista de notificações
- Cada item: título + mensagem resumida + tempo relativo ("há 5 min")
- Clique marca como lida + redireciona
- "Marcar todas como lidas" no footer do dropdown
- Polling via TanStack Query com `refetchInterval` (30s default)

---

## Onde ficam os arquivos de design

```
docs/
├── design-system/
│   ├── MASTER.md            ← design system do projeto (fonte de verdade visual)
│   ├── design-brief.md      ← resumo compacto (~800 tokens) para subagentes
│   └── pages/               ← overrides por página (opcional)
│       ├── dashboard.md
│       ├── onboarding.md
│       └── ...
├── user-stories.md
├── backlog.md
└── specs/
```

### MASTER.md — o que contém (gerado via Parte 2 deste arquivo)

- Direção visual (estilo, referências, anti-referências)
- Paleta de cores (primary, secondary, accent, semantic, sidebar, charts)
- Tipografia (font families, scale completa, Google Fonts import)
- Superfícies e elevação (backgrounds, bordas, sombras, border-radius)
- Espaçamento customizado (se divergir do default Tailwind)
- Componentes com override visual (sidebar, cards, tabelas, badges, gráficos, animações)
- Tokens do `@theme { }` do Tailwind v4
- Checklist de qualidade visual
- Changelog de alterações

### design-brief.md — o que contém (gerado a partir do MASTER.md)

- Resumo compacto (~800 tokens) com valores literais (hex, px, weights)
- Otimizado para injeção no prompt do `component-agent` (ver `claude-sdd.md → seção "Contextos de Subagente"`)
- Não contém justificativas, histórico ou referências — apenas dados actionable
- Deve ser regenerado sempre que o MASTER.md mudar

### pages/*.md — quando criar

Criar override por página quando:
- A página tem estilo visual significativamente diferente do resto do app (ex: landing page vs dashboard)
- A página tem componentes complexos que precisam de decisões de design específicas (ex: mapa interativo, comparação lado a lado)
- A página tem layout que diverge do padrão sidebar + top bar (ex: onboarding fullscreen)

---

## Integração com SDD (claude-sdd.md)

### No spec de componente

Quando o spec (`docs/specs/US-XX.spec.md`) descreve um componente, deve referenciar:

1. **Qual padrão de tabela/form/chart** desta parte se aplica
2. **Quais tokens do MASTER.md** o componente usa (se houver override)
3. **Quais estados** o componente implementa (loading/empty/error/success)

### No prompt do component-agent

O agente principal deve injetar no contexto do subagente de componente:

1. Regras estruturais aplicáveis desta parte (seção relevante — ex: "Formulários > Multi-step wizard")
2. **Design brief** (`docs/design-system/design-brief.md`) — resumo compacto com todos os tokens visuais
3. **Page override** (`docs/design-system/pages/*.md`) — se a página tiver override
4. Cenários de teste de UI do spec

> O subagente de componente não lê `DESIGN.md` inteiro nem o `MASTER.md` inteiro.
> O agente principal extrai regras estruturais desta parte e injeta o design-brief.md para tokens visuais.

### Criação de page overrides durante o SDD

Durante a geração do spec (Step 1 do fluxo SDD), o agente principal deve avaliar se a página do componente diverge do `MASTER.md`. A avaliação segue esta tabela:

| A página... | Decisão |
|---|---|
| Usa layout diferente do sidebar + top bar (ex: onboarding fullscreen, login) | → Criar/atualizar `pages/*.md` |
| Tem componentes visuais complexos que não existem em outras páginas (ex: mapa, comparação lado a lado, editor) | → Criar/atualizar `pages/*.md` |
| Precisa de paleta de cores ou tipografia diferente do MASTER.md | → Criar/atualizar `pages/*.md` |
| Tem densidade de informação significativamente diferente (ex: dashboard denso vs portal arejado) | → Criar/atualizar `pages/*.md` |
| Segue o padrão do MASTER.md sem desvios | → Não criar override |

**Regras:**

1. **O agente avalia automaticamente** — não pergunta ao usuário se precisa de page override.
2. **Se o override é necessário, ele é gerado junto com o spec** e apresentado na mesma aprovação. O usuário vê o spec + o page override e aprova ambos (ou pede ajustes).
3. **O formato de apresentação** inclui o override após o spec:

```
📐 SPEC GERADO — docs/specs/US-XX-nome.spec.md
─────────────────────────────────────────────
[conteúdo do spec]
─────────────────────────────────────────────

📎 PAGE OVERRIDE GERADO — docs/design-system/pages/nome-da-pagina.md
─────────────────────────────────────────────
[conteúdo do override — apenas desvios do MASTER.md]
─────────────────────────────────────────────

Aprova o spec e o override para iniciar a implementação?
```

4. **Se o `pages/*.md` já existe**, o agente verifica se o spec atual exige mudanças no override. Se sim, gera um amendment do override (mesma lógica do spec amendment).
5. **O page override é lido pelo component-agent** como parte do contexto injetado — os tokens específicos da página substituem os do design-brief.md para aquele componente.

---

## Anti-patterns de UI/UX

- ❌ Usar `alert()`, `confirm()` ou `prompt()` nativo do browser
- ❌ Tela em branco durante loading (sem skeleton)
- ❌ Tabela vazia sem empty state
- ❌ Erro silencioso (fetch falha sem feedback visual)
- ❌ Botão de ação destrutiva sem confirmação
- ❌ Formulário sem validação client-side (depender apenas do backend)
- ❌ Placeholder como label (some quando digita)
- ❌ Scroll horizontal em mobile (layout quebrando)
- ❌ Ícones sem significado acessível (sem `aria-label` ou texto adjacente)
- ❌ Múltiplos toasts empilhados (limitar a 3 simultâneos)
- ❌ Modal dentro de modal
- ❌ Cores hardcodadas no código (usar variáveis CSS / tokens do MASTER.md)
- ❌ Componentes de UI de libs diferentes misturados (shadcn + Material UI, por ex)
- ❌ CSS inline em componentes React (usar Tailwind classes)
- ❌ Emojis como ícones funcionais (usar Lucide)
- ❌ Gradientes, shadows pesados, efeitos neon ou glassmorphism como default (reservar para MASTER.md se o projeto pedir)
- ❌ UI genérica do shadcn/ui sem customização de cores/radius/font do MASTER.md
- ❌ Componentes sem hover/focus state customizado
- ❌ Todos os cards/elementos com mesmo peso visual (sem hierarquia)

---

## Changelog (Parte 1)

| Data | Tipo | Alteração | Motivo |
|---|---|---|---|

---

## Parte 2 — Pipeline do Design System (ui-ux-pro-max)

> Este pipeline gera o design system completo do projeto em 3 passos:
> 1. **ui-ux-pro-max** gera a base automaticamente pela indústria/tipo do projeto
> 2. **Entrevista de refinamento** ajusta com preferências do autor (marca, referências, tom)
> 3. **design-brief.md** é gerado automaticamente como resumo compacto para subagentes
>
> **Pré-requisitos:**
> - `docs/user-stories.md` existente (gerado via `/new-project`)
> - `docs/backlog.md` existente
> - Plugin ui-ux-pro-max instalado no Claude Code (ver instruções abaixo)
>
> **Output:**
> - `docs/design-system/MASTER.md` — design system completo (fonte de verdade visual)
> - `docs/design-system/design-brief.md` — resumo compacto (~800 tokens) para subagentes
> - `docs/design-system/pages/*.md` — overrides por página (quando necessário)
>
> **O que esta parte NÃO faz:**
> - Não define regras estruturais (isso está na Parte 1)
> - Não substitui o levantamento de requisitos (usar `/new-project`)
> - Não gera código — apenas documentação de design

---

## Pré-requisito: instalar ui-ux-pro-max

### Opção A — Via Claude Code Marketplace (2 comandos)

```
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

### Opção B — Via CLI (recomendado para múltiplos projetos)

```bash
# Instalar a CLI globalmente
npm install -g uipro-cli

# Instalar para o Claude Code (por projeto)
cd /path/to/your/project
uipro init --ai claude

# Ou instalar globalmente (disponível para todos os projetos)
uipro init --ai claude --global
```

### Verificar instalação

Após instalar, confirmar que o script de busca funciona:

```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "test" --domain style
```

> **Requisito**: Python 3.x instalado no sistema.

---

## Pipeline em 3 Passos

### Passo 1: ui-ux-pro-max gera a base

O engine de design analisa a indústria/tipo do projeto e gera automaticamente:
- Estilo recomendado (de 67 estilos disponíveis)
- Paleta de cores alinhada à indústria (de 161 paletas)
- Tipografia com pairing (de 57 combinações)
- Efeitos e animações recomendados
- Anti-patterns específicos para evitar
- Pre-delivery checklist

**Comando:**

```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py \
  "[indústria/tipo do projeto]" \
  --design-system \
  --persist \
  -p "[NomeDoProjeto]"
```

**Exemplos por tipo de projeto:**

```bash
# SaaS B2B de logística
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "logistics SaaS B2B shipping" --design-system --persist -p "Cotamar"

# CRM de freelancers
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "CRM freelance lead management" --design-system --persist -p "FreelancerHunter"

# Dashboard financeiro interno
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "financial dashboard internal tool" --design-system --persist -p "BankBalance"

# Agregador de eventos tech
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "tech events aggregator community" --design-system --persist -p "ShowTech"
```

**Output**: `design-system/MASTER.md` (base) gerado automaticamente.

> O agente deve ler o output gerado antes de prosseguir para o Passo 2.

---

### Passo 2: Entrevista de refinamento

Com a base gerada pelo engine, o Claude conduz uma entrevista **reduzida** (~5-7 perguntas) para refinar com preferências do autor.

#### Prompt para colar no Claude (ou executar no Claude Code)

```
Você é um design lead sênior REFINANDO um design system base gerado automaticamente.

O engine de design já analisou a indústria do projeto e gerou recomendações em
docs/design-system/MASTER.md. Seu trabalho é:
1. Ler o MASTER.md gerado + docs/user-stories.md + docs/backlog.md
2. Validar se as recomendações fazem sentido para este projeto específico
3. Refinar com preferências do autor (marca, referências, tom)
4. Gerar o MASTER.md final refinado
5. Gerar o design-brief.md (resumo compacto para subagentes)
6. Se necessário, gerar overrides por página em docs/design-system/pages/*.md

Você também conhece o `DESIGN.md` (Parte 1) que define os padrões estruturais reutilizáveis:
- Layout: sidebar + top bar
- Tabelas: híbrido tabela→cards
- Formulários: seção única (≤6), wizard (7-15), colapsável (settings)
- Gráficos: Recharts
- UI: shadcn/ui + Tailwind v4 + Lucide + Sonner
- Acessibilidade: WCAG AA obrigatório
- Dark mode: decisão deste design system

---

REGRAS DA ENTREVISTA (REDUZIDA):
- A base já foi gerada — NÃO repetir perguntas que o engine já respondeu.
- Máximo 5-7 perguntas. Faça UMA por vez.
- Comece apresentando o que o engine gerou e validando com o autor.
- Foque em: marca existente, referências pessoais, overrides específicos, tom.
- Quando a resposta for vaga, ofereça opções concretas (ex: "prefere mais Linear ou mais Notion?").
- Quando sentir que tem informação suficiente, avise e gere os artefatos.
- Se o autor enviar imagem/screenshot como referência, extraia: cores, tipografia, estilo, densidade.

PERGUNTAS OBRIGATÓRIAS (adaptar ordem ao contexto):

1. **Validação da base**:
   "Li o design system base gerado para o projeto. O engine recomendou estilo [X],
   com paleta [cores principais] e tipografia [fontes]. Isso está alinhado com sua visão?
   Tem algo que destoa?"

2. **Marca existente**:
   "O projeto tem marca existente (logo, cores definidas, fonte da marca)?
   Se sim, essas cores/fontes substituem as geradas pelo engine."

3. **Referências visuais**:
   "Além do que o engine sugeriu, tem algum produto/site/app que tem a 'cara' que você quer?
   E algum que representa o OPOSTO?"

4. **Tom e densidade**:
   "O tom está certo? E a densidade de informação — prefere mais arejado (whitespace generoso)
   ou mais denso (mais dados por viewport)?"

5. **Dark mode**:
   "O projeto precisa de dark mode? Se sim, como default ou opção toggle?"

6. **Páginas especiais** (se aplicável):
   "Há páginas que divergem do layout padrão? (onboarding fullscreen, landing page, login)"

7. **Componentes com personalidade** (se aplicável):
   "Algum componente precisa de atenção visual especial? (dashboard, mapa, formulário complexo)"

---

Após a entrevista, gere TRÊS artefatos:

1. `docs/design-system/MASTER.md` — design system completo refinado
2. `docs/design-system/design-brief.md` — resumo compacto para subagentes
3. `docs/design-system/pages/*.md` — overrides por página (se necessário)

Comece lendo o `docs/design-system/MASTER.md` (gerado pelo engine), `docs/user-stories.md` e `docs/backlog.md`.
Depois apresente o que o engine gerou e faça a primeira pergunta de validação.
```

---

### Passo 3: Geração do design-brief.md

Após o MASTER.md estar finalizado, o Claude gera automaticamente o `design-brief.md`. Este arquivo é o **resumo compacto** (~800 tokens) que será injetado no prompt de cada `component-agent`.

#### Formato do design-brief.md

```markdown
# Design Brief — [Nome do Projeto]

> Resumo compacto do design system para injeção em subagentes de componente.
> Gerado automaticamente a partir do MASTER.md. Fonte de verdade: MASTER.md.
> Atualizar este arquivo sempre que o MASTER.md mudar.

## Visual
Estilo: [1 linha — ex: flat, densidade compacta, sidebar escura, workspace branco]
Radius: [por elemento — ex: buttons 6px, cards 8px, modals 12px, badges full]
Shadows: [ex: nenhuma exceto dropdowns (0 4px 12px rgba(0,0,0,0.08))]

## Tipografia
Fontes: [ex: Inter (400/500/600), JetBrains Mono (dados/valores)]
H1: [font] [weight] [size] — H2: [font] [weight] [size]
Body: [font] [weight] [size] — Small: [font] [weight] [size]
Mono: [font] [weight] [size] — usada para: [ex: valores monetários, datas, códigos]

## Cores
Primary: [hex] — Primary hover: [hex] — Primary fg: [hex]
Secondary: [hex] — Accent: [hex]
Background: [hex] — Subtle: [hex] — Surface: [hex]
Foreground: [hex] — Muted: [hex]
Border: [hex] — Border hover: [hex]
Sidebar: bg [hex], text [hex], active [hex]
Success: [hex] (bg [hex]) — Warning: [hex] (bg [hex]) — Error: [hex] (bg [hex])

## Componentes
Tabelas: [ex: density compacta py-6px, header 12px muted bg-subtle, cells 13px]
KPIs: [ex: bg-subtle, label 11px muted, value 20px semibold, grid 4col]
Cards: [ex: sem borda sem sombra, padding 12px 16px]
Badges: [ex: pill full-round, 11px weight-500, pad 2px 8px]

## Animações
Entrada: [ex: animate-fade-slide-up 380ms cubic-bezier(0.16,1,0.3,1)]
Stagger: [ex: 60ms por elemento, max 300ms total]
Regra: somente transform e opacity — nunca width/height/top/left

## Anti-patterns
[1-2 linhas — ex: sem gradientes, sem neon, sem sombras em cards, sem cores default shadcn]

## Checklist
- [ ] Cores do brief (sem hex hardcoded, sem defaults shadcn)
- [ ] Tipografia do brief (font, weight, size por elemento)
- [ ] Radius do brief (não defaults shadcn)
- [ ] 4 estados: loading (Skeleton) / empty (icon+msg+CTA) / error (Alert+retry) / success
- [ ] Responsivo: mobile stack → desktop grid
- [ ] Animação de entrada aplicada
- [ ] Hover/focus states com transition
```

#### Regras de geração do brief

1. **Máximo ~800 tokens.** Se ultrapassar, comprimir informação (abreviar, remover redundâncias).
2. **Valores literais, não referências.** O brief contém os hex, não `--color-primary`. O subagente não lê CSS.
3. **Tudo que o component-agent precisa, nada que não precisa.** Sem histórico, sem justificativas, sem anti-referências. Apenas dados actionable.
4. **Atualizar quando o MASTER.md muda.** Se o MASTER.md for modificado, o brief deve ser regenerado.

---

## Formato do MASTER.md

O MASTER.md gerado deve seguir esta estrutura (compatível com o output do ui-ux-pro-max):

```markdown
# Design System — [Nome do Projeto]

> Gerado em [data]. Fonte de verdade visual do projeto.
> Para regras estruturais (layout, responsividade, estados, acessibilidade): ver `DESIGN.md` (Parte 1).
> Este arquivo define a **personalidade visual** — cores, tipografia, estilo, tokens.
>
> Em caso de conflito com `DESIGN.md` (Parte 1), este arquivo prevalece para decisões visuais.
> `DESIGN.md` (Parte 1) prevalece para decisões estruturais.

---

## Direção visual

**Tom**: [ex: profissional e moderno, com toques de calor humano]
**Estilo**: [ex: clean/flat com bordas sutis, densidade média, cantos arredondados]
**Referências**: [ex: Linear para a sidebar, Vercel para tabelas, Stripe para formulários]
**Anti-referências**: [ex: não queremos parecer com Salesforce (denso demais) nem com um tema WordPress]

---

## Paleta de cores

### Cores do projeto
| Token | Hex | Uso |
|---|---|---|
| `--color-primary` | #XXXXXX | Ações primárias, links, sidebar ativa |
| `--color-primary-foreground` | #XXXXXX | Texto sobre primary |
| `--color-secondary` | #XXXXXX | Ações secundárias, badges |
| `--color-accent` | #XXXXXX | Destaque, CTA, elementos interativos |
| `--color-background` | #XXXXXX | Background principal da aplicação |
| `--color-surface` | #XXXXXX | Background de cards e superfícies elevadas |
| `--color-muted` | #XXXXXX | Textos secundários, placeholders |
| `--color-border` | #XXXXXX | Bordas de cards, inputs, separadores |

### Cores semânticas
| Token | Hex | Uso |
|---|---|---|
| `--color-success` | #XXXXXX | Ativo, aprovado, vigente |
| `--color-warning` | #XXXXXX | Pendente, atenção |
| `--color-error` | #XXXXXX | Erro, rejeitado, vencido |
| `--color-info` | #XXXXXX | Informativo, dicas |

### Tokens Tailwind v4 (@theme)
[Bloco de CSS pronto para colar no arquivo de tema do projeto]

​```css
@theme {
  --color-primary: #XXXXXX;
  --color-primary-foreground: #XXXXXX;
  /* ... demais tokens ... */
}
​```

---

## Tipografia

| Elemento | Font | Weight | Tamanho | Line-height |
|---|---|---|---|---|
| H1 (título de página) | [fonte] | 600 | 30px / 1.875rem | 1.2 |
| H2 (seção) | [fonte] | 600 | 24px / 1.5rem | 1.3 |
| H3 (sub-seção) | [fonte] | 500 | 20px / 1.25rem | 1.4 |
| Body | [fonte] | 400 | 16px / 1rem | 1.5 |
| Small / caption | [fonte] | 400 | 14px / 0.875rem | 1.4 |
| Label | [fonte] | 500 | 14px / 0.875rem | 1.4 |
| Mono (código, dados) | [fonte mono] | 400 | 14px / 0.875rem | 1.5 |

### Google Fonts import
[URL pronta para adicionar ao HTML ou CSS]

---

## Dark mode

**Suporte**: [sim/não]
**Modo default**: [light/dark/system]
[Se sim, incluir mapeamento de tokens dark]

---

## Superfícies e elevação

[Tabela de superfícies: background, borda, sombra, uso]
[Tabela de border-radius por tipo de elemento]

---

## Overrides de componentes

[Apenas se o projeto exigir estilo diferente do padrão de DESIGN.md (Parte 1)]

### Sidebar
[Cor de fundo, estilo dos itens, etc.]

### Cards
[Bordas, sombras, hover, etc.]

### Tabelas
[Densidade, estilo de header, etc.]

### Badges
[Tabela de tipos: success/warning/error/info/neutro com cores]

### Gráficos
[Paleta de cores para séries, estilo de tooltip, etc.]

### Animações
[Tokens de animação com duração, easing, uso]

---

## Overrides por página

[Listar quais páginas têm override em docs/design-system/pages/*.md]

| Página | Arquivo | Motivo do override |
|---|---|---|
| Dashboard | pages/dashboard.md | Layout de gráficos e KPIs |
| Onboarding | pages/onboarding.md | Fullscreen, sem sidebar |

---

## Checklist de qualidade visual

Antes de considerar qualquer componente pronto, verificar:

- [ ] Cores seguem a paleta definida neste arquivo (sem hex hardcodado)
- [ ] Tipografia segue a escala definida (sem font-size arbitrário)
- [ ] Contraste WCAG AA validado (4.5:1 texto normal, 3:1 texto grande)
- [ ] Estados de UI implementados (loading/empty/error/success)
- [ ] Responsivo testado nos 4 breakpoints (mobile/tablet/desktop/wide)
- [ ] Hover e focus states presentes em todos os elementos interativos
- [ ] Ícones são Lucide (ou lib definida neste arquivo) — sem emojis funcionais
- [ ] Animações respeitam prefers-reduced-motion
- [ ] [Se dark mode] Testado em ambos os modos

---

## Changelog

| Data | Tipo | Alteração | Motivo |
|---|---|---|---|
| [data de criação] | create | Design system inicial | Gerado via ui-ux-pro-max + entrevista de refinamento |
```

---

## Formato do pages/*.md

```markdown
# Override de Design — [Nome da Página]

> Override para `docs/design-system/MASTER.md`.
> Apenas os desvios do Master estão documentados aqui.
> Tudo que não está aqui segue o Master.

## Layout
[Se diferente do padrão sidebar + top bar]

## Componentes específicos
[Componentes que só existem nesta página e suas regras visuais]

## Cores/tokens específicos
[Se esta página usa cores diferentes]
```

---

## Checklist pós-pipeline

Antes de considerar o design system completo, confirme:

- [ ] Passo 1 executado: ui-ux-pro-max gerou base com `--design-system --persist`
- [ ] Passo 2 executado: entrevista de refinamento concluída
- [ ] Tom visual e referências definidos
- [ ] Paleta de cores completa (projeto + semânticas)
- [ ] Tipografia escolhida com fallbacks e Google Fonts URL
- [ ] Decisão de dark mode tomada
- [ ] Tokens Tailwind v4 (`@theme { }`) prontos para colar
- [ ] Overrides de componentes documentados (se houver)
- [ ] Páginas com override identificadas e documentadas
- [ ] `docs/design-system/MASTER.md` gerado e refinado
- [ ] `docs/design-system/design-brief.md` gerado (~800 tokens)
- [ ] `docs/design-system/pages/*.md` gerados (se aplicável)
- [ ] Checklist de qualidade visual incluso no MASTER.md
- [ ] Changelog iniciado no MASTER.md

---

## Uso para redesign ou evolução visual

Se o projeto já tem MASTER.md e você quer evoluir o visual:

1. Informe ao Claude o MASTER.md atual (cole ou referencie).
2. Descreva o que quer mudar e por quê.
3. Peça para gerar um **diff** do MASTER.md — apenas o que muda, não reescreva tudo.
4. Valide que os overrides de páginas ainda fazem sentido com o novo visual.
5. **Regenerar o design-brief.md** após qualquer mudança no MASTER.md.

---

## Uso para features em projetos existentes

Se o projeto já tem design system e uma nova feature precisa de decisão visual:

1. O fluxo SDD avalia automaticamente se a feature precisa de page override (ver `DESIGN.md` Parte 1 → Criação de page overrides durante o SDD).
2. Se precisa, o override é gerado junto com o spec e apresentado na mesma aprovação.
3. O MASTER.md não muda — apenas novos overrides em `pages/*.md`.
4. Se a feature introduz um padrão visual novo que afeta todo o projeto, o Claude atualiza o MASTER.md + brief.
