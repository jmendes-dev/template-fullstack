# Tailwind CSS v4 — configuração CSS-first

Ler ao configurar Tailwind v4 em projeto novo, ao migrar de v3, ou ao integrar com shadcn/ui. Regra-resumo (CSS-first, sem `tailwind.config.js`, plugin `@tailwindcss/vite`) vive em `CLAUDE.md`.

## O que mudou no v4

| v3 | v4 |
|---|---|
| `tailwind.config.js` (JS) | `@theme {}` no CSS (CSS-first) |
| `@tailwind base; @tailwind components; @tailwind utilities;` | `@import "tailwindcss";` (uma linha) |
| Plugin PostCSS (`tailwindcss`, `autoprefixer`) | `@tailwindcss/vite` (sem PostCSS) |
| `dark:` via `darkMode: 'class'` no config | `@variant dark (...)` no CSS |
| `border-*` default = `gray-200` | `border-*` default = `currentColor` |
| `theme.extend.colors` no JS | `@theme { --color-brand: oklch(...); }` |

`tailwind.config.js` ainda é suportado via `@config "./tailwind.config.js";` para migração — **projetos novos não devem criá-lo**.

---

## Setup em projeto novo (Vite 8)

### 1. Instalar

```bash
bun add tailwindcss @tailwindcss/vite
```

Sem `postcss`, sem `autoprefixer`. O plugin Vite cobre tudo.

### 2. `vite.config.ts`

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
```

Ordem importa: `react()` antes de `tailwindcss()`.

### 3. CSS de entrada — `apps/web/src/index.css`

```css
@import "tailwindcss";

@theme {
  /* Cores customizadas — geram classes bg-brand-500, text-brand-500, etc */
  --color-brand-50:  oklch(0.97 0.02 250);
  --color-brand-500: oklch(0.55 0.18 250);
  --color-brand-900: oklch(0.25 0.10 250);

  /* Fontes — geram font-sans, font-display */
  --font-sans: 'Inter', system-ui, sans-serif;
  --font-display: 'Cal Sans', sans-serif;

  /* Breakpoints — sobrescreve os defaults */
  --breakpoint-3xl: 1920px;

  /* Espaçamento extra */
  --spacing-128: 32rem;
}

/* Dark mode — Tailwind v4 sintaxe nova */
@variant dark (&:where(.dark, .dark *));
```

Importar em `main.tsx`:

```typescript
import './index.css';
```

### 4. Tipos de tokens em `@theme`

| Prefixo | Gera classes |
|---|---|
| `--color-*` | `bg-*`, `text-*`, `border-*`, `fill-*`, `stroke-*` |
| `--font-*` | `font-*` |
| `--text-*` | `text-*` (tamanho) |
| `--spacing-*` | `m-*`, `p-*`, `w-*`, `h-*`, `gap-*` |
| `--radius-*` | `rounded-*` |
| `--shadow-*` | `shadow-*` |
| `--breakpoint-*` | media query (`md:`, `lg:`, etc) |
| `--container-*` | `container` |
| `--animate-*` | `animate-*` |

### 5. Dark mode

Tailwind v4 não tem `darkMode: 'class'` config. Definir no CSS:

```css
@variant dark (&:where(.dark, .dark *));
```

E aplicar em `<html class="dark">` ou via `document.documentElement.classList.toggle('dark')` em runtime. Use `next-themes` ou Zustand:

```typescript
import { create } from 'zustand';

const useTheme = create<{ theme: 'light' | 'dark'; toggle: () => void }>((set) => ({
  theme: 'light',
  toggle: () => set((s) => {
    const next = s.theme === 'light' ? 'dark' : 'light';
    document.documentElement.classList.toggle('dark', next === 'dark');
    return { theme: next };
  }),
}));
```

---

## shadcn/ui no Tailwind v4

shadcn/ui suporta v4 nativamente desde dez/2025. Init:

```bash
# Verificar sintaxe atual antes de rodar
bunx shadcn@latest --help

bunx shadcn@latest init -t vite
```

`components.json` deve ter:

```json
{
  "tailwind": {
    "config": "",
    "css": "src/index.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui"
  }
}
```

`tailwind.config: ""` é o sinal de v4 (vazio porque não existe arquivo de config JS).

### CSS variables do shadcn no `@theme`

shadcn injeta CSS variables (`--background`, `--foreground`, `--primary`, etc) em `:root` e `.dark`. Para Tailwind reconhecer essas variáveis como classes:

```css
@import "tailwindcss";

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  /* ... resto dos tokens shadcn */
}

@variant dark (&:where(.dark, .dark *));

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.15 0 0);
  --primary: oklch(0.55 0.18 250);
  --primary-foreground: oklch(0.98 0 0);
  /* ... */
}

.dark {
  --background: oklch(0.15 0 0);
  --foreground: oklch(0.98 0 0);
  --primary: oklch(0.65 0.18 250);
  --primary-foreground: oklch(0.15 0 0);
  /* ... */
}
```

`@theme inline` (vs `@theme`) — tokens são resolvidos em runtime, permitindo dark mode reativo via `.dark`. Sem `inline`, os valores são compilados no build e dark mode quebra.

### Pacote unificado `radix-ui`

shadcn/ui novo (style "new-york" desde nov/2025) usa o pacote unificado **`radix-ui`** ao invés de `@radix-ui/react-*` individuais:

```bash
# Antes (vários pacotes):
bun add @radix-ui/react-dialog @radix-ui/react-dropdown-menu @radix-ui/react-select

# Agora (um pacote):
bun add radix-ui
```

Migrar projeto existente (troca todos os `@radix-ui/react-*` pelo pacote unificado):

```bash
bunx shadcn@latest migrate radix
```

Imports nos componentes de `src/components/ui/*.tsx` mudam de:

```typescript
import * as DialogPrimitive from '@radix-ui/react-dialog';
```

para:

```typescript
import { Dialog as DialogPrimitive } from 'radix-ui';
```

Detalhes: `docs/version-matrix.md` regra 28.

---

## Migração v3 → v4

### Automatizado

```bash
bunx @tailwindcss/upgrade@latest
```

Cobre: troca de imports, conversão de `tailwind.config.js` para `@theme`, ajuste de classes deprecadas. **Não cobre**: `border-*` defaults, `divide-*` defaults, plugins customizados.

### Manual — checklist

- [ ] Remover `postcss.config.js` (se Vite)
- [ ] Trocar `@tailwind base; @tailwind components; @tailwind utilities;` por `@import "tailwindcss";`
- [ ] Mover tokens de `tailwind.config.js` para `@theme {}` no CSS
- [ ] Adicionar `@variant dark (...)` se usa dark mode
- [ ] Buscar `border-*` sem cor explícita no JSX e adicionar `border-gray-200` (ou outra)
- [ ] Buscar `divide-*` sem cor e adicionar `divide-gray-200`
- [ ] Atualizar `vite.config.ts`: trocar PostCSS por `@tailwindcss/vite`
- [ ] Plugins JS deprecados: alguns não têm equivalente CSS-first. Manter `@config "./tailwind.config.js"` se essencial

### `border-*` / `divide-*` — breaking

```tsx
// v3: usava gray-200 como default
<div className="border" />

// v4: usa currentColor — herda cor do texto, normalmente preto, fica fora do design
<div className="border border-gray-200" />  // explícito
```

Procurar todas ocorrências:

```bash
rg -n 'className="[^"]*\bborder\b[^-"]' apps/web/src
```

---

## Custom utilities — `@utility`

Para criar utility classes próprias (substitui `addUtilities` do v3):

```css
@utility scroll-snap-x {
  scroll-snap-type: x mandatory;
}

@utility no-scrollbar {
  scrollbar-width: none;
  &::-webkit-scrollbar {
    display: none;
  }
}
```

Usar como qualquer classe Tailwind: `<div class="scroll-snap-x no-scrollbar">`.

---

## Plugins JS (compatibilidade)

Plugins v3 (`tailwindcss/plugin`) ainda funcionam via `@plugin`:

```css
@import "tailwindcss";

@plugin "@tailwindcss/typography";
@plugin "@tailwindcss/forms";
```

Sem necessidade de `tailwind.config.js` para isso.

---

## Mudanças dentro da série v4.x

**v4.2 — utilities deprecated**: `start-*` e `end-*` (posicionamento de insets) foram depreciados em favor de `inset-s-*` e `inset-e-*` (nomenclatura de bloco lógico). Substituir:

| Deprecated (v4.2) | Correto |
|---|---|
| `start-4` | `inset-s-4` |
| `end-4` | `inset-e-4` |

---

## Anti-patterns

- Criar `tailwind.config.js` em projeto novo — usar `@theme {}` no CSS
- Manter `@tailwind base/components/utilities` — substituir por `@import "tailwindcss"`
- Usar PostCSS quando há plugin Vite oficial — remove dependência desnecessária
- Configurar dark mode em JS sem `@variant dark` no CSS
- Usar `<div className="border">` sem cor após v4 — vira `currentColor` (preto)
- Importar de `@radix-ui/react-*` em projeto shadcn novo — usar `radix-ui` unificado
- `@theme {}` sem `inline` quando os valores vêm de CSS vars (dark mode quebra)
- Usar `start-*`/`end-*` — deprecated no v4.2, substituídos por `inset-s-*`/`inset-e-*`

---

## Checklist de rollout

- [ ] `tailwindcss` e `@tailwindcss/vite` instalados (sem PostCSS, sem autoprefixer)
- [ ] `vite.config.ts` com plugin `tailwindcss()`
- [ ] `index.css` com `@import "tailwindcss"` (não `@tailwind ...`)
- [ ] `@theme {}` com tokens custom (cores, fontes)
- [ ] `@variant dark (&:where(.dark, .dark *))` se usa dark mode
- [ ] shadcn `components.json` com `tailwind.config: ""`
- [ ] `@theme inline` com tokens shadcn se dark mode reativo
- [ ] Sem `tailwind.config.js` no projeto (a menos que migração explícita)
- [ ] Border/divide sem cor revisados (não confiar no default v3)
