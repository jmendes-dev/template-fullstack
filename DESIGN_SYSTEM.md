# DESIGN_SYSTEM.md — Pipeline de Geração do Design System

> **Como usar:** Este pipeline gera o design system completo do projeto em 3 passos:
> 1. **ui-ux-pro-max** gera a base automaticamente pela indústria/tipo do projeto
> 2. **Entrevista de refinamento** ajusta com preferências do autor (marca, referências, tom)
> 3. **design-brief.md** é gerado automaticamente como resumo compacto para subagentes
>
> **Pré-requisitos:**
> - `docs/user-stories.md` existente (gerado via REQUIREMENTS.md)
> - `docs/backlog.md` existente
> - `claude-design.md` acessível (regras estruturais de referência)
> - Plugin ui-ux-pro-max instalado no Claude Code (ver instruções abaixo)
>
> **Output:**
> - `docs/design-system/MASTER.md` — design system completo (fonte de verdade visual)
> - `docs/design-system/design-brief.md` — resumo compacto (~800 tokens) para subagentes
> - `docs/design-system/pages/*.md` — overrides por página (quando necessário)
>
> **O que este pipeline NÃO faz:**
> - Não define regras estruturais (isso está no `claude-design.md`)
> - Não substitui o levantamento de requisitos (isso está no `REQUIREMENTS.md`)
> - Não gera código — apenas documentação de design

---

## 🔧 Pré-requisito: instalar ui-ux-pro-max

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

## 📋 Pipeline em 3 Passos

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

#### 🤖 Prompt para colar no Claude (ou executar no Claude Code)

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

Você também conhece o `claude-design.md` que define os padrões estruturais reutilizáveis:
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
4. **Atualizar quando o MASTER.md muda.** Se a auto-atualização do design (ver CLAUDE.md) modificar o MASTER.md, o brief deve ser regenerado.

---

## 📄 Formato do MASTER.md

O MASTER.md gerado deve seguir esta estrutura (compatível com o output do ui-ux-pro-max):

```markdown
# Design System — [Nome do Projeto]

> Gerado em [data]. Fonte de verdade visual do projeto.
> Para regras estruturais (layout, responsividade, estados, acessibilidade): ver `claude-design.md`.
> Este arquivo define a **personalidade visual** — cores, tipografia, estilo, tokens.
>
> Em caso de conflito com `claude-design.md`, este arquivo prevalece para decisões visuais.
> `claude-design.md` prevalece para decisões estruturais.

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

```css
@theme {
  --color-primary: #XXXXXX;
  --color-primary-foreground: #XXXXXX;
  /* ... demais tokens ... */
}
```

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

[Apenas se o projeto exigir estilo diferente do padrão do claude-design.md]

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

## 📄 Formato do pages/*.md

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

## 📋 Checklist pós-pipeline

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

## 🔄 Uso para redesign ou evolução visual

Se o projeto já tem MASTER.md e você quer evoluir o visual:

1. Informe ao Claude o MASTER.md atual (cole ou referencie).
2. Descreva o que quer mudar e por quê.
3. Peça para gerar um **diff** do MASTER.md — apenas o que muda, não reescreva tudo.
4. Valide que os overrides de páginas ainda fazem sentido com o novo visual.
5. **Regenerar o design-brief.md** após qualquer mudança no MASTER.md.

---

## 🔄 Uso para features em projetos existentes

Se o projeto já tem design system e uma nova feature precisa de decisão visual:

1. O fluxo SDD avalia automaticamente se a feature precisa de page override (ver `claude-design.md` → Criação de page overrides durante o SDD).
2. Se precisa, o override é gerado junto com o spec e apresentado na mesma aprovação.
3. O MASTER.md não muda — apenas novos overrides em `pages/*.md`.
4. Se a feature introduz um padrão visual novo que afeta todo o projeto, o Claude atualiza o MASTER.md + brief via auto-atualização do design (ver CLAUDE.md).
