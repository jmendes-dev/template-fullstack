# Web — nginx reverse proxy (on-premise Masterboi)

Ler ao criar o `Dockerfile` do web, o `nginx.conf`, ou ao debugar 404 em rotas do SPA / chamadas `/api` que não chegam no backend.

Princípio: em on-premise, o container `web` **não serve só arquivos estáticos** — ele roda **nginx:alpine** que (a) faz SPA fallback para `index.html` em rotas internas do React Router e (b) faz **proxy reverso** de `/api/*` para o container `api`. Resultado: browser faz todas as chamadas **same-origin**, sem CORS.

## Por que same-origin em UAT/PRD

- `VITE_API_URL=""` no build → o client RPC do Hono usa caminhos relativos (`/api/...`).
- Nginx no web redireciona `/api/*` para `http://api:3000` via rede Docker interna.
- Navegador não enxerga o backend diretamente; Traefik só expõe a porta 80 do web.
- Consequência: **sem CORS**, **sem preflight OPTIONS**, `APP_CORS_ORIGINS` relevante só em dev.

## `apps/web/nginx.conf`

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Security headers (extra ao que o Traefik já adiciona)
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # SPA catch-all — rotas internas do React Router resolvem no client
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy reverso para a API (resolução dinâmica do DNS do Docker)
    location /api/ {
        resolver 127.0.0.11 valid=30s;
        set $api_upstream http://api:3000;
        proxy_pass $api_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 10s;
        proxy_send_timeout 300s;
    }

    # Cache agressivo de assets imutáveis (hashes no nome)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### Pontos importantes

- **`resolver 127.0.0.11`**: DNS interno do Docker. Sem ele, nginx resolve `api` uma vez ao iniciar e não reage a reschedulamento do container (container da API cai e volta com IP novo → 502).
- **`set $api_upstream`**: combinado com `resolver`, força nginx a resolver o nome DNS a cada request.
- **Timeout alto** (`300s`): permite long-polling e uploads grandes. Ajustar se a API nunca precisa disso.
- **`try_files`**: chave para SPA — qualquer rota não-arquivo volta ao `index.html`, e o React Router pega na hora.

## `apps/web/Dockerfile`

Multi-stage — build com Bun (para tirar o bundle do Vite) + runtime nginx:

```dockerfile
# ───── Stage 1: build ─────
FROM oven/bun:1.3-alpine AS build
WORKDIR /app

# Build args (injetados pelo CD via BUILD_SECRETS)
ARG VITE_CLERK_PUBLISHABLE_KEY
ARG VITE_API_URL=""
ENV VITE_CLERK_PUBLISHABLE_KEY=$VITE_CLERK_PUBLISHABLE_KEY
ENV VITE_API_URL=$VITE_API_URL

COPY package.json bun.lock ./
COPY apps/web/package.json ./apps/web/
COPY packages/shared/package.json ./packages/shared/
RUN bun install --frozen-lockfile

COPY . .
RUN bun run --filter '@projeto/web' build

# ───── Stage 2: runtime ─────
FROM nginx:alpine AS runtime
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/apps/web/dist /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
```

**`Dockerfile.dev`** (dev usa bun direto com HMR) — sem nginx, só `bun run dev --host 0.0.0.0 --port 5173`.

## Variáveis

| Var | Valor | Notas |
|---|---|---|
| `VITE_API_URL` | `""` em UAT/PRD; URL absoluta só se quiser quebrar same-origin | **Build arg**, não runtime |
| `VITE_CLERK_PUBLISHABLE_KEY` | `pk_live_...` ou `pk_test_...` | **Build arg** via `BUILD_SECRETS` no CD |

Relembrando (regra 10 e doc `env-vars.md`): `VITE_*` é **compile-time**. Setar no Portainer UI **não tem efeito** na imagem já buildada.

## Healthcheck no compose

Web tem healthcheck simples (nginx deve responder 200 em `/`):

```yaml
web:
  image: ${REGISTRY}/${APP_NAME}-web:uat-latest
  healthcheck:
    test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost/ || exit 1"]
    interval: 30s
    retries: 3
```

API continua com healthcheck no `/health`. Ver `docs/observability.md`.

## Traefik labels (UAT/PRD)

No compose, labels do service `web` expõem o host via Traefik:

```yaml
web:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.${APP_NAME}-web.rule=Host(`${APP_HOST_UAT}`)"
    - "traefik.http.routers.${APP_NAME}-web.entrypoints=websecure"
    - "traefik.http.routers.${APP_NAME}-web.tls.certresolver=letsencrypt"
    - "traefik.http.services.${APP_NAME}-web.loadbalancer.server.port=80"
  networks:
    - default
    - traefik-net
```

Service `api` **não tem labels Traefik** — só é acessado internamente via nginx. Se precisar expor a API diretamente (ex: mobile app), adicionar labels ao `api` com `Host(api.meu-app.masterboi.local)` e manter `APP_CORS_ORIGINS`.

## Debug comum

| Sintoma | Causa provável | Fix |
|---|---|---|
| 404 em rotas do SPA após F5 | `try_files` faltando ou `index` errado | conferir `location /` no nginx.conf |
| `/api/*` volta 502 | API unhealthy OU nginx sem resolver dinâmico | `depends_on: api { condition: service_healthy }` e `resolver 127.0.0.11` |
| CORS error em UAT/PRD | Código do client chamou URL absoluta | confirmar `VITE_API_URL=""` no build arg |
| CSS/JS antigos após deploy | Cache do browser com `immutable` | Vite adiciona hash ao filename — se não tem, remover `immutable` |
| Uploads grandes caem | `proxy_*_timeout` padrão baixo | timeouts configurados em 300s; aumentar se precisar |

## Anti-patterns

- **Esquecer o `nginx.conf` no Dockerfile** — build sobe, mas SPA quebra em refresh e `/api` não chega no backend.
- **`VITE_API_URL` com URL absoluta em UAT/PRD** — quebra o same-origin, exige CORS, mais complexo sem ganho.
- **Usar `nginx:latest`** — fixar versão (`nginx:alpine` + tag específica para reprodutibilidade).
- **Expor a API via Traefik além do web** sem necessidade — superfície de ataque extra; manter API interna.
- **Esquecer `resolver 127.0.0.11`** — DNS resolve uma vez e reage mal a restart do container da API.
- **Cache de `index.html`** — nunca cachear `index.html` (só assets com hash). Adicionar `location = /index.html { add_header Cache-Control "no-cache"; }` se precisar explicitar.
- **Servir estáticos pela API** — tudo estático sai pelo nginx; API só serve JSON.
