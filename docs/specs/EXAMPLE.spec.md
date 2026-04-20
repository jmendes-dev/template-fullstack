# Spec — US-01: Cadastro de Produto

> Gerado em: YYYY-MM-DD · Aprovado por: [usuário]
> Status: ✅ Aprovado · Spec ≤ 150 linhas (regra)

---

## Contexto

Permite que o admin cadastre produtos no catálogo. Primeiro schema do projeto — base para todas as features de venda.

---

## Contratos — Schema (`packages/shared/src/schemas/`)

### Tabela: `products`

| Coluna | Tipo Drizzle | Nullable | Default | Nota |
|---|---|---|---|---|
| id | uuid | não | defaultRandom() | PK |
| name | varchar(200) | não | — | |
| description | text | sim | null | |
| priceInCents | integer | não | — | Evitar float |
| active | boolean | não | true | |
| createdAt | timestamp | não | now() | |
| updatedAt | timestamp | não | now() | |

### Zod Schemas

- `insertProductSchema` — campos: name, description, priceInCents, active · omit: id, createdAt, updatedAt
- `selectProductSchema` — todos os campos
- `updateProductSchema` — partial de insert com id obrigatório

### Tipos exportados

- `type InsertProduct = z.input<typeof insertProductSchema>`
- `type SelectProduct = z.infer<typeof selectProductSchema>`

---

## Contratos — API (`apps/api/src/routes/products.ts`)

### `POST /api/v1/products`

- **Auth**: requer userId (admin)
- **Body**: `insertProductSchema`
- **201**: `{ data: SelectProduct }`
- **400**: `{ error: string, code: "VALIDATION_ERROR", details: ZodIssue[] }`
- **401**: `{ error: "Unauthorized", code: 401 }`

### `GET /api/v1/products`

- **Auth**: requer userId
- **Query**: `?active=true|false`
- **200**: `{ data: SelectProduct[] }`

---

## Contratos — Componente (`apps/web/src/features/products/`)

### `ProductForm`

- **Props**: `{ onSuccess: () => void }`
- **Estado interno**: React Hook Form com `insertProductSchema`
- **Submissão**: mutation TanStack Query → `POST /api/v1/products`
- **Estados**:
  - idle: form habilitado, botão "Salvar" ativo
  - submitting: campos disabled + spinner no botão
  - error: toast Sonner com mensagem do backend
  - success: `onSuccess()` + toast "Produto cadastrado"

---

## Cenários de teste

### API

1. DADO body válido, QUANDO `POST /products`, ENTÃO 201 + produto criado
2. DADO `name` ausente, QUANDO `POST /products`, ENTÃO 400 + code VALIDATION_ERROR
3. DADO sem auth header, QUANDO `POST /products`, ENTÃO 401
4. DADO `?active=true`, QUANDO `GET /products`, ENTÃO só produtos ativos

### Componente

5. DADO form preenchido, QUANDO submeter, ENTÃO mutation chamada com dados corretos
6. DADO form vazio, QUANDO submeter, ENTÃO erro de validação em `name`
7. DADO mutation erro 400, QUANDO resposta, ENTÃO toast com mensagem do backend

---

## Dependências

- Nenhuma (primeiro schema — sem dependências)

## Fora do escopo

- Upload de imagem de produto
- Categorias / tags
- Histórico de preço

## Checklist de conclusão

- [ ] Schema Drizzle criado e migration gerada
- [ ] Tipos Zod exportados no barrel de `packages/shared/src/index.ts`
- [ ] Endpoints POST + GET implementados e testados
- [ ] `ProductForm` com 4 estados (idle/submitting/error/success)
- [ ] Cenários 1-7 cobertos com nomenclatura `it('Cenário X.Y: ...')`
- [ ] Cobertura ≥ 95%
