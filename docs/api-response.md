# API response format (obrigatório)

Ler ao criar/revisar rotas Hono, ao consumir a API no frontend, ou ao definir contrato API-Frontend. Contrato resumido (envelope `{ data }` / `{ error, code, details }`) vive em `CLAUDE.md`.

Frontend e backend devem concordar neste contrato **antes** de escrever código.

## Sucesso — item único

```json
{ "data": { ... } }
```

## Sucesso — lista paginada

```json
{ "data": [ ... ], "pagination": { "page": 1, "limit": 10, "total": 87, "totalPages": 9 } }
```

## Erro

```json
{ "error": "mensagem legível", "code": "VALIDATION_ERROR", "details": {} }
```

## Status codes

| Status | Uso |
|---|---|
| 400 | Validação / input inválido |
| 401 | Não autenticado |
| 403 | Sem permissão |
| 404 | Recurso não encontrado |
| 429 | Rate limit excedido |
| 500 | Erro interno (nunca expor stack trace em prod) |

Middleware global de error handling no Hono captura exceções e retorna no formato de erro.

Toda rota usa `c.json({ data: ... })`. Nunca array/objeto solto. Frontend acessa `response.data`.
