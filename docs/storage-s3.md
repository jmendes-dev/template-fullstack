# Storage — S3-compatible em todos os ambientes

Ler ao configurar uploads, criar client S3, definir `S3_ENDPOINT` por ambiente, gerar presigned URL ou criar bucket. Regra-resumo (usar S3 SDK sempre, nunca filesystem) vive em `CLAUDE.md`.

Princípio: **um único client S3** com `S3_ENDPOINT` apontando para o provider do ambiente. O código da aplicação não muda entre Railway, Portainer e dev.

## Endpoints por deploy target

| Deploy target | Ambiente | Provider | `S3_ENDPOINT` |
|---|---|---|---|
| Railway (cloud) | qualquer | Railway Buckets | injetado pelo Bucket via `$BUCKET_ENDPOINT` (linkar como reference) |
| Portainer (on-premise) | Dev local | MinIO container | `http://minio:9000` |
| Portainer (on-premise) | UAT / PRD | **MinIO centralizado** (serviço compartilhado da org) | valor via Portainer UI (ex: `http://minio-central.masterboi.local:9000`) |

**Diferença importante on-premise**: em UAT/PRD, o MinIO **não é um container na stack do projeto** — é o MinIO central de monitoramento da organização. Cada projeto reutiliza esse MinIO; **nunca subir MinIO próprio em Portainer UAT/PRD**. MinIO local sobe apenas no `docker-compose.yml` de dev.

**Nunca hardcodar** o endpoint no código. Sempre ler de `process.env.S3_ENDPOINT`.

**Caveat de checksum**: `@aws-sdk/client-s3` v3.729+ envia checksums que MinIO/Railway podem rejeitar. Setar `requestChecksumCalculation: "WHEN_REQUIRED"` no client.

## Setup do client

Único arquivo em `packages/shared`, reusável em backend e scripts:

```typescript
// packages/shared/src/storage/s3-client.ts
import { S3Client } from '@aws-sdk/client-s3';

export const s3 = new S3Client({
  endpoint: process.env.S3_ENDPOINT,
  region: process.env.S3_REGION ?? 'us-east-1',  // dummy — MinIO/Railway ignoram
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY!,
    secretAccessKey: process.env.S3_SECRET_KEY!,
  },
  forcePathStyle: true,                          // MinIO requer; Railway aceita
  requestChecksumCalculation: 'WHEN_REQUIRED',
});

export const BUCKET = process.env.S3_BUCKET!;
```

`forcePathStyle: true` cobre tanto MinIO quanto Railway.

## Criação de bucket

### Railway (cloud)

Criar bucket via dashboard: `+ New` → `Database` → `Railway Bucket`. Linkar como reference no service (`S3_BUCKET` ← `Bucket.BUCKET_NAME`). **Não usar `CreateBucketCommand`** em prod — Railway não permite criação programática via SDK.

### Portainer — dev local

MinIO sobe no compose junto da aplicação. Service `init-bucket` cria os buckets automaticamente:

```yaml
init-bucket:
  image: minio/mc:RELEASE.2025-09-07T16-13-09Z
  depends_on:
    minio: { condition: service_healthy }
  entrypoint: >
    sh -c "
      mc alias set local http://minio:9000 $$MINIO_ROOT_USER $$MINIO_ROOT_PASSWORD &&
      mc mb --ignore-existing local/$$S3_BUCKET &&
      mc mb --ignore-existing local/backup-$$APP_NAME-db
    "
  environment:
    MINIO_ROOT_USER: ${MINIO_ROOT_USER}
    MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    S3_BUCKET: ${S3_BUCKET:-uploads}
    APP_NAME: ${APP_NAME}
  restart: "no"
```

Alternativa: `ensureBucket()` no boot da API quando `NODE_ENV !== 'production'`.

### Portainer — UAT / PRD

**Buckets criados manualmente pela infra no MinIO central**, uma única vez. **Não há `init-bucket` nos composes UAT/PRD** — aplicação assume bucket já existente. Convenção de nomes:

- Uploads: `${APP_NAME}-uploads`
- Backup do Postgres: `backup-${APP_NAME}-db` (ver `docs/backup-restore.md`)

Solicitar criação desses buckets com a infra antes do primeiro deploy.

Se a API precisa verificar existência no boot, usar `HeadBucketCommand` e logar (não criar):

```typescript
try {
  await s3.send(new HeadBucketCommand({ Bucket: BUCKET }));
} catch (err: any) {
  if (err.name === 'NotFound') {
    logger.error({ bucket: BUCKET }, 'Bucket missing — peça para infra criar no MinIO central');
    process.exit(1);
  }
  throw err;
}
```

## Upload via presigned URL (recomendado)

Browser faz upload direto para o S3. API só assina a URL — reduz tráfego da API:

```typescript
// apps/api/src/routes/uploads.ts
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Hono } from 'hono';
import { s3, BUCKET } from '@projeto/shared/storage';

export const uploads = new Hono()
  .post('/presign', async (c) => {
    const { filename, contentType } = await c.req.json<{ filename: string; contentType: string }>();
    const key = `${crypto.randomUUID()}-${filename}`;
    const url = await getSignedUrl(
      s3,
      new PutObjectCommand({ Bucket: BUCKET, Key: key, ContentType: contentType }),
      { expiresIn: 60 * 5 }
    );
    return c.json({ data: { url, key } });
  });
```

> **On-premise**: o MinIO central precisa ser **acessível pela rede onde o browser roda**. Se só existe na rede Docker interna, presigned URL não funciona — use rota da API que faz `GetObject` (apenas arquivos pequenos) ou expor o MinIO central via Traefik com TLS.

## Operações básicas (SDK v3)

```typescript
import {
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
} from '@aws-sdk/client-s3';

// Upload server-side
await s3.send(new PutObjectCommand({
  Bucket: BUCKET,
  Key: 'reports/2026-04.pdf',
  Body: pdfBuffer,
  ContentType: 'application/pdf',
}));

// Download
const obj = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: 'reports/2026-04.pdf' }));
const body = await obj.Body!.transformToByteArray();

// Delete
await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: 'reports/2026-04.pdf' }));

// List (paginado)
const list = await s3.send(new ListObjectsV2Command({
  Bucket: BUCKET,
  Prefix: 'reports/',
  MaxKeys: 100,
}));
const keys = list.Contents?.map(o => o.Key!) ?? [];
```

## Tratamento de erros comuns

| Erro | Causa | Fix |
|---|---|---|
| `NoSuchBucket` | bucket não existe | Railway: criar via dashboard. On-prem dev: rodar `init-bucket`. On-prem UAT/PRD: pedir para infra criar |
| `AccessDenied` | credenciais erradas ou bucket policy | conferir `S3_ACCESS_KEY`/`S3_SECRET_KEY` |
| `InvalidAccessKeyId` | typo na env var | revisar Railway Variables / Portainer UI |
| `RequestTimeout` | endpoint errado ou rede | conferir `S3_ENDPOINT` — on-prem UAT/PRD aponta para MinIO central, não `http://minio:9000` |
| `BadDigest` / checksum mismatch | SDK v3.729+ sem fix | garantir `requestChecksumCalculation: 'WHEN_REQUIRED'` |
| `EntityTooLarge` | arquivo > 5GB em PUT único | usar multipart via `Upload` de `@aws-sdk/lib-storage` |

## Operações comuns por ambiente

### Railway

- **Criar bucket**: dashboard → `+ New` → `Database` → `Railway Bucket`.
- **Listar/inspecionar**: dashboard do Bucket mostra objetos e métricas.
- **Deletar bucket**: dashboard → Settings → Delete.

### Portainer (MinIO) — dev local

MinIO Console em `http://localhost:9001` (login `${MINIO_ROOT_USER}` / `${MINIO_ROOT_PASSWORD}`), ou via `mc`:

```sh
docker run --rm -it --network <compose-network> \
  minio/mc:RELEASE.2025-09-07T16-13-09Z \
  alias set local http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD

docker run --rm --network <compose-network> \
  minio/mc:RELEASE.2025-09-07T16-13-09Z mb --ignore-existing local/uploads
```

### Portainer (MinIO central) — UAT / PRD

Console gerenciado pela infra. Acesso via `mc` apontando para endpoint central:

```sh
docker run --rm -it \
  minio/mc:RELEASE.2025-09-07T16-13-09Z \
  alias set central http://minio-central.masterboi.local:9000 <ACCESS> <SECRET>

docker run --rm minio/mc:RELEASE.2025-09-07T16-13-09Z ls central/<app>-uploads
```

## MinIO em Portainer — nota de longo prazo

O repositório MinIO foi **arquivado em fev/2026** (`RELEASE.2025-09-07T16-13-09Z` é a última release). Alternativas S3-compatible ativamente mantidas:

| Alternativa | Notas |
|---|---|
| **Garage** (https://garagehq.deuxfleurs.fr) | Open-source, Go, ativo. Self-hosted distribuído |
| **SeaweedFS** | Escalável, ampla comunidade |
| **Cloudflare R2** | SaaS S3-compatible, egress gratuito |
| **Backblaze B2** | Barato, S3-compatible |

Código da aplicação não muda — apenas `S3_ENDPOINT` no ambiente.

## Anti-patterns

- Persistir arquivo em filesystem local (`/uploads/`) em prod — **regra 14**, não fazer.
- Subir **MinIO próprio no compose de UAT/PRD on-premise** — UAT/PRD usam MinIO centralizado; MinIO local é só dev.
- Hardcodar `S3_ENDPOINT` no código — sempre via env var.
- Rodar `ensureBucket()` em prod — Railway não permite; on-prem UAT/PRD usa buckets pré-criados pela infra.
- Servir arquivos pelo backend (`api.get('/file/:key')` com `GetObject` no body) em alto volume — preferir presigned URLs.
- Esquecer `forcePathStyle: true` — MinIO falha com 403.
- Bucket público sem necessidade — MinIO central da org é privado por padrão.
