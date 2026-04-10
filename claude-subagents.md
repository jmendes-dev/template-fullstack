# claude-subagents.md — Templates de Contexto para Subagentes

> **Este arquivo define os templates de CONHECIMENTO injetados nos subagentes.**
> A EXECUÇÃO dos subagentes é dirigida pelo Superpowers (`subagent-driven-development`).
> Este arquivo fornece o que o Superpowers não tem: regras de stack, design brief, cenários do spec.
>
> **Quando ler**: ao preparar contexto para subagentes durante o Step 2 (PLAN) ou Step 3 (EXECUTE).
>
> **Pré-requisito**: spec aprovado em `docs/specs/`. Sem spec, sem contexto para injetar.

---

## 🧠 Princípio: Superpowers Executa, Workflow Injeta

```
Superpowers (execução):                Workflow (conhecimento):
├── writing-plans (decompõe)           ├── claude-stacks.md (regras de stack)
├── subagent-driven-development        ├── design-brief.md (tokens visuais)
├── test-driven-development (TDD)      ├── pages/*.md (overrides de página)
├── requesting-code-review             ├── specs/US-XX.spec.md (cenários)
└── verification-before-completion     └── claude-design.md (regras UI)
```

O agente principal lê este arquivo para saber **qual contexto injetar** em cada tipo de task quando o Superpowers solicita. O Superpowers cuida de: ordem de execução, TDD gates, code review, verificação.

---

## 🏷️ Tipos de Contexto por Task

### Schema & Types (packages/shared)

**Contexto injetado no plan/subagente**:
- Seção "Contratos — Schema" do spec
- Regras: Drizzle config, Zod v4, barrel exports, naming conventions
- Arquivo atual de `packages/shared/src/schemas/` (se existir)

**Stack rules aplicáveis**:
```
- Schemas em packages/shared/src/schemas/ — kebab-case.ts
- Exportar via barrel file: packages/shared/src/index.ts
- Todo schema tem createdAt e updatedAt com defaults
- IDs: uuid com defaultRandom() (padrão do projeto)
- Zod schemas via drizzle-zod: createInsertSchema, createSelectSchema
- Tipos: z.input<typeof insertSchema> para forms, z.infer<typeof selectSchema> para reads
- Rodar `bun run db:generate` após criar o schema
```

**Budget máximo de contexto**: ≤ 1500 tokens

---

### API Endpoints (apps/api)

**Contexto injetado no plan/subagente**:
- Seção "Contratos — API" do spec
- Schemas Zod importáveis (nomes e paths)
- Rotas existentes (se integrar com endpoint existente)

**Stack rules aplicáveis**:
```
- Framework: Hono. Validação: sValidator de @hono/standard-validator
- Response sucesso: c.json({ data: ... })
- Response lista: c.json({ data: [...], pagination: { page, limit, total, totalPages } })
- Response erro: c.json({ error, code, details }, status)
- Auth: getAuth(c) — síncrono. userId = auth?.userId ?? "dev-user"
- Importar schemas de @projeto/shared
- Importar db de ../db (nunca criar nova instância)
- Arquivo de rota: apps/api/src/routes/kebab-case.ts
- Registrar rota no apps/api/src/index.ts
- Exportar tipo da rota para AppType
```

**Budget máximo de contexto**: ≤ 1500 tokens

---

### React Components (apps/web)

**Contexto injetado no plan/subagente**:
- Seção "Contratos — Componente" do spec
- Types importáveis (nomes e paths)
- API contract (endpoints que o componente consome)
- **Design brief** (`docs/design-system/design-brief.md`) — colado literalmente
- **Page override** (`docs/design-system/pages/*.md`) — se existir

**Stack rules aplicáveis**:
```
- React 19 + TypeScript strict
- Data fetching: TanStack Query + Hono RPC client tipado
- Forms: React Hook Form + standardSchemaResolver (Zod v4)
- UI: shadcn/ui + Tailwind CSS v4 classes. Nunca CSS inline
- States obrigatórios: loading (Skeleton), empty (ícone+msg+CTA), error (Alert+retry), success
- Toasts: Sonner (nunca alert())
- Estado: TanStack Query para server state, Zustand para client state
- Um componente por arquivo, PascalCase.tsx
```

**Design rules** (do design-brief.md):
```
{conteúdo de docs/design-system/design-brief.md — colado literalmente}
```

**Page override**:
```
{conteúdo de docs/design-system/pages/<nome>.md se existir, senão "Sem override. Seguir o brief."}
```

**Visual checklist**:
```
- [ ] Cores usam tokens do design brief (sem hex hardcoded, sem defaults shadcn)
- [ ] Tipografia segue escala do brief (font family, weight, size)
- [ ] Border-radius conforme brief
- [ ] Density e spacing conforme brief
- [ ] Animações de entrada conforme brief
- [ ] 4 estados: loading/empty/error/success
- [ ] Responsivo: mobile stack → desktop grid
- [ ] Hover/focus states com transition
```

**Budget máximo de contexto**: ≤ 3500 tokens
> **Nunca cortar design rules para caber** — cortar stack rules genéricas primeiro.

---

### Fix / Debugging

**Contexto injetado no subagente de fix**:
- Mensagem de erro exata + stack trace
- Contexto de reprodução
- Seção do spec que define o comportamento esperado
- **Tentativas anteriores** (para não repetir)
- Regra de stack violada (se aplicável)

**Protocolo**: seguir `claude-debug.md` + `superpowers:systematic-debugging`.
Se não conseguir diagnosticar em 3 tentativas, PARAR e retornar diagnóstico parcial.

**Budget máximo de contexto**: ≤ 1500 tokens

---

## 📊 Budget de Contexto — Resumo

| Tipo de task | Budget máx | Composição |
|---|---|---|
| Schema/Types | ≤ 1500 tokens | spec (~600) + paths (~100) + stack rules (~400) + cenários (~400) |
| API Endpoints | ≤ 1500 tokens | spec (~600) + paths (~100) + stack rules (~400) + cenários (~400) |
| React Components | ≤ 3500 tokens | spec (~600) + paths (~100) + stack rules (~500) + design brief (~800) + override (~300) + cenários (~400) + checklist (~200) |
| Fix/Debug | ≤ 1500 tokens | erro (~300) + stack trace (~200) + arquivo (~300) + spec (~300) + tentativas (~200) + regra (~200) |

---

## 💡 O que NÃO enviar para subagentes

- ❌ `CLAUDE.md` inteiro
- ❌ `claude-stacks.md` inteiro — apenas regras da camada relevante
- ❌ `claude-stacks-refactor.md` inteiro — apenas seções aplicáveis
- ❌ `claude-design.md` inteiro — apenas regras estruturais relevantes
- ❌ `MASTER.md` inteiro — subagente recebe `design-brief.md` (resumo compacto)
- ❌ Código de outros módulos/features
- ❌ Histórico de conversa anterior

## ✅ O que SEMPRE enviar

- ✅ Seção exata do spec (copiada, não referenciada)
- ✅ Paths de arquivos (input e output)
- ✅ Stack rules aplicáveis (extraídas e coladas)
- ✅ Cenários de teste do spec
- ✅ Design brief — apenas para tasks de frontend
- ✅ Page override — quando existir, apenas para frontend
- ✅ Tentativas anteriores — apenas para fix (evitar loops)

---

## 🚫 Proibições

- ❌ Subagente nunca faz commit, push, install, ou modifica docs/specs
- ❌ Nunca enviar mais que o budget de contexto do tipo
- ❌ Nunca cortar design brief do contexto de componente
- ❌ Nunca repetir fix que já falhou (ler tentativas anteriores)
- ❌ Fix-agent que falha 3x deve parar e retornar diagnóstico, não continuar tentando
