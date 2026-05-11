# Security headers

Ler ao configurar CSP, HSTS, X-Content-Type-Options, X-Frame-Options, ou ao preparar para security review. Linha-resumo vive em `CLAUDE.md` seção Testes.

Princípio: **defesa em profundidade** — aplicar no app (Hono) **e** no edge (Traefik/Railway), não um ou outro. Browsers confiam nos headers, então cada camada eleva o custo do ataque.

## Headers obrigatórios

| Header | Valor recomendado | O que protege |
|---|---|---|
| `Strict-Transport-Security` (HSTS) | `max-age=31536000; includeSubDomains; preload` | downgrade HTTPS→HTTP |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing attacks |
| `X-Frame-Options` | `DENY` (ou `SAMEORIGIN`) | clickjacking via iframe |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | leak de URL via referrer |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` (ajustar) | APIs do browser que app não usa |
| `Content-Security-Policy` | ver seção CSP abaixo | XSS, data exfiltration |
| `X-XSS-Protection` | **não setar** — legacy, pode criar vulnerabilidade | — |

## Hono — `hono/secure-headers`

Middleware built-in, aplicar globalmente:

```typescript
import { secureHeaders } from 'hono/secure-headers';

app.use('*', secureHeaders({
  strictTransportSecurity: 'max-age=31536000; includeSubDomains; preload',
  xContentTypeOptions: 'nosniff',
  xFrameOptions: 'DENY',
  referrerPolicy: 'strict-origin-when-cross-origin',
  permissionsPolicy: {
    camera: [],
    microphone: [],
    geolocation: [],
    interestCohort: [],  // FLoC opt-out
  },
  // CSP gerenciada separadamente — ver abaixo
}));
```

## Content Security Policy (CSP)

CSP é o mais complexo — erra fácil, quebra a app se restritivo demais.

**Estratégia**: começar em `Report-Only` por 1-2 semanas, coletar violations, depois migrar para enforcement.

### Report-Only (fase de observação)

```typescript
app.use('*', async (c, next) => {
  await next();
  c.header('Content-Security-Policy-Report-Only',
    "default-src 'self'; " +
    "script-src 'self' https://*.clerk.accounts.dev; " +
    "style-src 'self' 'unsafe-inline'; " +  // Tailwind inline em dev
    "img-src 'self' data: https:; " +
    "connect-src 'self' https://api.exemplo.com.br https://*.clerk.accounts.dev; " +  // substituir pelo domínio real da API
    "frame-ancestors 'none'; " +
    "report-uri /api/csp-report"
  );
});

app.post('/api/csp-report', async (c) => {
  const report = await c.req.json();
  c.get('logger').warn({ cspReport: report }, 'CSP violation');
  return c.body(null, 204);
});
```

### Enforcement (após observação)

Trocar `Content-Security-Policy-Report-Only` → `Content-Security-Policy`, mantendo `report-uri` ativo.

### Clerk considerations

Clerk Core 3 exige domínios específicos no CSP. Consultar [docs Clerk CSP](https://clerk.com/docs/security/clerk-csp) — domínios variam por versão. Confirmar via context7 MCP antes de lockar.

Mínimo típico: `https://*.clerk.accounts.dev`, `https://clerk.com`, `https://*.clerk.dev`.

### Tailwind v4 e inline styles

Tailwind v4 JIT gera styles inline que exigem `'unsafe-inline'` em `style-src` — **aceitável** pois não é script. Nunca colocar `'unsafe-inline'` em `script-src`.

Alternativa (avançada): `style-src-attr 'unsafe-inline'` + `style-src-elem 'self'` — mais restritivo, mas pode quebrar. Testar.

## Traefik (Portainer) — labels de middleware

Defesa adicional na borda — os headers do Hono persistem, mas Traefik garante mesmo se app falhar:

```yaml
# no service api do docker-compose.yml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.middlewares=api-headers"
  - "traefik.http.middlewares.api-headers.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.api-headers.headers.stsIncludeSubdomains=true"
  - "traefik.http.middlewares.api-headers.headers.stsPreload=true"
  - "traefik.http.middlewares.api-headers.headers.contentTypeNosniff=true"
  - "traefik.http.middlewares.api-headers.headers.frameDeny=true"
  - "traefik.http.middlewares.api-headers.headers.referrerPolicy=strict-origin-when-cross-origin"
```

Aplicar o mesmo middleware no router do `web` para o frontend.

## Railway — via app middleware

Railway não edita headers no edge. Toda a proteção vem do middleware Hono. Considerar CDN (Cloudflare) na frente se quiser camada extra.

## CORS (revisão do CLAUDE.md)

`docs/api-response.md` e CLAUDE.md já cobrem. Reforçando aqui:

- `APP_CORS_ORIGINS` com lista explícita, nunca `*`
- `credentials: true` só se usa cookies (Clerk usa Authorization header, então não precisa)

## Testes automatizados

Adicionar teste que valida headers em toda rota:

```typescript
import { describe, it, expect } from 'bun:test';

describe('security headers', () => {
  it('aplicar headers em GET /api/health', async () => {
    const res = await app.request('/health');
    expect(res.headers.get('strict-transport-security')).toMatch(/max-age=/);
    expect(res.headers.get('x-content-type-options')).toBe('nosniff');
    expect(res.headers.get('x-frame-options')).toBe('DENY');
    expect(res.headers.get('referrer-policy')).toBe('strict-origin-when-cross-origin');
  });

  it('aplicar CSP em GET /api/health', async () => {
    const res = await app.request('/health');
    const csp = res.headers.get('content-security-policy')
            ?? res.headers.get('content-security-policy-report-only');
    expect(csp).toContain("default-src 'self'");
  });
});
```

## Checklist de rollout

- [ ] `hono/secure-headers` middleware aplicado globalmente
- [ ] CSP em Report-Only por 1-2 semanas
- [ ] Endpoint `/api/csp-report` configurado (com rate limit)
- [ ] Violations analisadas, CSP ajustada
- [ ] CSP promovida a enforcement
- [ ] Traefik labels de headers (se Portainer)
- [ ] Teste automatizado de headers no CI
- [ ] Scan externo validando: https://securityheaders.com (alvo grade A)
- [ ] `X-Powered-By` removido (default em Hono já é)

## Anti-patterns

- CSP com `'unsafe-eval'` em produção — abre XSS-via-eval
- `frame-ancestors 'self'` quando app não precisa ser embedado — usar `'none'` (ou `X-Frame-Options: DENY`)
- HSTS em desenvolvimento (http://localhost) — navegadores recusam, quebra dev; aplicar só em prod
- Copiar-colar CSP sem testar — sempre Report-Only primeiro
- Esquecer Clerk no CSP — login quebra silenciosamente
