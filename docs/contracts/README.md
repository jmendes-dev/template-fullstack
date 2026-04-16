# Contract Registry

> Contratos versionados entre backend e frontend.
> **Criado por:** `backend-developer` após criar/modificar endpoints.
> **Lido por:** `frontend-developer` antes de implementar data fetching.
> **Validado por:** `qa-engineer` na cobertura de testes.

---

## Como usar

### Backend (criar/atualizar contrato)

Após criar ou modificar qualquer endpoint, criar/atualizar `docs/contracts/[domínio].contract.md`:

```bash
# Exemplo: novo endpoint de usuários
docs/contracts/users.contract.md
```

### Frontend (ler contrato)

Antes de implementar qualquer hook TanStack Query ou data fetching:
1. Verificar se existe `docs/contracts/[domínio].contract.md`
2. Se não existe, solicitar ao `backend-developer` que crie
3. Nunca assumir formato de resposta sem contrato documentado

---

## Formato Padrão de Contrato

```markdown
# Contract: [Domínio]

> Versão: 1.0.0
> Criado: YYYY-MM-DD
> Última atualização: YYYY-MM-DD

## Endpoints

### [METHOD] /[path]

**Descrição:** O que este endpoint faz

**Auth:** Bearer token (Clerk) | Público

**Request:**
\`\`\`typescript
// Query params, body ou path params
{
  field: string
  // ...
}
\`\`\`

**Response (200):**
\`\`\`typescript
{
  data: {
    // estrutura do objeto retornado
  }
}
\`\`\`

**Errors:**
| Status | Código | Descrição |
|--------|--------|-----------|
| 400 | VALIDATION_ERROR | Campos inválidos |
| 401 | UNAUTHORIZED | Token ausente ou inválido |
| 404 | NOT_FOUND | Recurso não encontrado |
| 500 | INTERNAL_ERROR | Erro interno |
```

---

## Estratégia de Versionamento

Contratos seguem **semver simplificado** no campo `Versão`:

| Tipo de mudança | Versão | Ação obrigatória |
|-----------------|--------|-----------------|
| Novo campo opcional na response | `MINOR` (1.0.0 → 1.1.0) | Atualizar contrato; frontend ignora campo novo |
| Renomear campo / mudar tipo | `MAJOR` (1.x.x → 2.0.0) | Criar `v2` no path (`/api/v2/...`); manter v1 ativa por 1 sprint |
| Novo endpoint no mesmo domínio | `MINOR` | Adicionar seção no contrato existente |
| Remover campo ou endpoint | `MAJOR` | Deprecation notice no contrato antes de remover |

**Regras de breaking change:**
- Frontend deve ser atualizado **antes** de remover suporte à versão antiga
- `qa-engineer` valida que todos os cenários do spec ainda passam após mudança MAJOR
- Contratos MAJOR ficam em `docs/contracts/[domínio].v[N].contract.md` durante período de transição

---

## Contratos Disponíveis

<!-- Lista gerada automaticamente ao criar arquivos *.contract.md -->
<!-- Nenhum contrato ainda — backend-developer deve criar ao implementar endpoints -->
