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

## Contratos Disponíveis

<!-- Lista gerada automaticamente ao criar arquivos *.contract.md -->
<!-- Nenhum contrato ainda — backend-developer deve criar ao implementar endpoints -->
