# Backup e restore

Ler ao configurar backups, testar restore, ou planejar disaster recovery. Linha-resumo vive em `CLAUDE.md` seção "Production-readiness".

Princípio: **backup não testado = sem backup**. Testar restore trimestralmente. Retenção mínima em prod: 30 dias.

## Escopo

1. **PostgreSQL** — dados da aplicação (schema + tuplas).
2. **S3 storage** — uploads de usuário (Railway Buckets ou MinIO central, dependendo do target).

Clerk (auth) é gerenciado pelo provider, fora do escopo.

---

## PostgreSQL — Railway (cloud)

### Backups automáticos (addon)

O addon Postgres do Railway tem backup nativo:

- Dashboard → `Databases` → `Postgres` → `Backups`
- Snapshots diários automáticos (plano Pro+)
- Retenção: 7 dias no Hobby, 30 dias no Pro, configurável no Enterprise

### Snapshot manual

Antes de operação destrutiva (migration grande, rollback de schema):

```bash
railway login
railway link <project>
railway run pg_dump --schema=public --no-owner --no-privileges -Fc > backup-$(date +%Y%m%d-%H%M).dump
```

Upload o `.dump` para S3/Railway Buckets ou armazenar localmente encriptado.

### Restore

1. Criar novo addon Postgres (ou dropar o atual se autorizado).
2. Restaurar:
   ```bash
   cat backup.sql | railway run psql
   # ou: railway connect Postgres  (shell interativo, depois \i backup.sql)
   ```
   > **Nota**: o redirecionamento `<` é processado pelo shell local antes de passar para `railway run`, o que não funciona. Usar `cat ... |` ou o shell interativo via `railway connect`.

   Para formato custom (`-Fc`): `cat backup.dump | railway run pg_restore`.
3. Atualizar `DATABASE_URL` se mudou o addon.
4. Validar com `SELECT COUNT(*)` nas tabelas principais.

---

## PostgreSQL — Portainer (on-premise Masterboi)

On-premise Masterboi usa uma **imagem Docker centralizada** publicada no registry interno:

- **Imagem**: `${REGISTRY}/backup-postgres:latest`
- **Responsabilidade**: container sidecar que faz `pg_dump | gzip | mc pipe` periodicamente para o MinIO (local em dev, central em UAT/PRD).
- **Localização do Dockerfile**: `infra-github-org-config/images/backup-postgres/`.

Diferente do padrão cloud/generic (Dockerfile ad-hoc por projeto), aqui **todo projeto consome a mesma imagem** — atualizações chegam via `docker pull` / redeploy da stack.

### Service no compose (on-premise)

Os três compose files declaram o service `backup`:

**Dev** (`docker-compose.yml`) — aponta para MinIO local:

```yaml
backup:
  image: ${REGISTRY}/backup-postgres:latest
  restart: unless-stopped
  environment:
    DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    S3_ENDPOINT: http://minio:9000
    S3_ACCESS_KEY: ${MINIO_ROOT_USER}
    S3_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
    S3_BACKUP_BUCKET: backup-${APP_NAME}-db
    APP_NAME: ${APP_NAME}
    RETENTION_DAYS: "${BACKUP_RETENTION_DAYS:-7}"
    BACKUP_INTERVAL: "${BACKUP_INTERVAL:-86400}"
  depends_on:
    postgres: { condition: service_healthy }
    minio: { condition: service_healthy }
```

**UAT / PRD** (`docker-compose-uat.yml` / `-prd.yml`) — aponta para MinIO central via Portainer UI:

```yaml
backup:
  image: ${REGISTRY}/backup-postgres:latest
  restart: unless-stopped
  environment:
    DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    S3_ENDPOINT: ${S3_ENDPOINT}              # MinIO central, via Portainer UI
    S3_ACCESS_KEY: ${S3_ACCESS_KEY}
    S3_SECRET_KEY: ${S3_SECRET_KEY}
    S3_BACKUP_BUCKET: ${S3_BACKUP_BUCKET}    # ex: backup-meu-app-db
    APP_NAME: ${APP_NAME}
    RETENTION_DAYS: ${BACKUP_RETENTION_DAYS}
    BACKUP_INTERVAL: ${BACKUP_INTERVAL}
  depends_on:
    postgres: { condition: service_healthy }
  deploy:
    resources:
      limits: { memory: 128M }
```

### Variáveis aceitas pela imagem

| Variável | Descrição | Default |
|---|---|---|
| `DATABASE_URL` | Connection string Postgres | — (obrigatório) |
| `S3_ENDPOINT` | Endpoint do MinIO (local em dev, central em UAT/PRD) | — |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | Credenciais S3 | — |
| `S3_BACKUP_BUCKET` | Bucket destino (convenção: `backup-${APP_NAME}-db`) | — |
| `APP_NAME` | Nome do app (prefixo no path dos objetos) | — |
| `RETENTION_DAYS` | Dias de retenção; backups mais antigos são deletados | `7` (dev), configurar 30+ em PRD |
| `BACKUP_INTERVAL` | Intervalo em segundos entre backups | `86400` (24h) |

### Operação

- Backup roda automático a cada `BACKUP_INTERVAL`. Object key: `${APP_NAME}/pg-YYYYMMDD-HHMMSS.sql.gz`.
- Rotação automática: mantém últimos `RETENTION_DAYS` dias.
- Falhas ficam nos logs do container `backup` — configurar alerta via Sentry/Loki se necessário.

### Bucket no MinIO central (UAT / PRD)

Pedir para a infra criar os buckets antes do primeiro deploy:

- UAT: `backup-${APP_NAME}-db` no MinIO UAT
- PRD: `backup-${APP_NAME}-db` no MinIO PRD

Policies restritas (só a credencial do projeto lê/escreve nesse bucket).

### Backup manual (ad-hoc, on-premise)

```bash
docker exec <postgres-container> \
  pg_dump -U $POSTGRES_USER -Fc $POSTGRES_DB > backup-$(date +%Y%m%d-%H%M).dump
```

### Restore — do backup automático (formato `pg-*.sql.gz`)

```bash
# 1. Parar a api (evitar writes concorrentes)
docker stop <projeto>-api

# 2. Baixar e restaurar (pipe)
mc cat central/backup-<projeto>-db/<projeto>/pg-20260420-030000.sql.gz \
  | gunzip -c \
  | docker exec -i <projeto>-postgres \
      pg_restore -U $POSTGRES_USER -d $POSTGRES_DB --clean

# 3. Subir api de volta
docker start <projeto>-api

# 4. Validar contagens
```

> **Cuidado**: backup automático aplica `gzip` depois do `pg_dump -Fc`. Não tentar `pg_restore < pg-xxx.sql.gz` direto — `pg_restore` falha no header compactado. `gunzip -c` no meio é obrigatório.

### Restore — do backup manual (formato `.dump`)

```bash
docker exec -i <projeto>-postgres \
  pg_restore -U $POSTGRES_USER -d $POSTGRES_DB --clean < backup.dump
```

---

## S3 / storage

### Railway Buckets

Railway Buckets são S3-compatible mas **não têm versioning nativo**. Para backup:

1. Bucket secundário (`<bucket>-backups`) — outro Railway Bucket no mesmo projeto, ou AWS S3 real.
2. Worker dedicado (service Railway separado) rodando `aws s3 sync` em loop.

#### Worker de sync — `apps/sync-backup/`

```dockerfile
# apps/sync-backup/Dockerfile
FROM amazon/aws-cli:2.22
COPY sync.sh /usr/local/bin/sync.sh
RUN chmod +x /usr/local/bin/sync.sh
ENTRYPOINT ["/usr/local/bin/sync.sh"]
```

```bash
# apps/sync-backup/sync.sh
#!/bin/sh
set -e
while true; do
  tmpdir=$(mktemp -d)
  aws --endpoint-url "$S3_SOURCE_ENDPOINT" s3 sync "s3://$S3_SOURCE_BUCKET/" "$tmpdir/"
  aws --endpoint-url "$S3_DEST_ENDPOINT"   s3 sync "$tmpdir/" "s3://$S3_DEST_BUCKET/" --delete=false
  rm -rf "$tmpdir"
  sleep 3600
done
```

Linkar dois buckets no Railway (origem e destino). Variáveis:
- `S3_SOURCE_ENDPOINT` ← `Bucket.BUCKET_ENDPOINT`
- `S3_SOURCE_BUCKET` ← `Bucket.BUCKET_NAME`
- `S3_DEST_ENDPOINT` ← `BucketBackup.BUCKET_ENDPOINT`
- `S3_DEST_BUCKET` ← `BucketBackup.BUCKET_NAME`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — credenciais do destino.

### MinIO central (on-premise UAT / PRD)

MinIO central tem **versioning** e **replication** habilitados pela stack shared. Uploads ficam replicados automaticamente — sem ação no projeto.

Para inspecionar / restaurar um objeto específico:

```bash
mc ls central/${APP_NAME}-uploads --versions
mc cp --version-id=<ID> central/${APP_NAME}-uploads/<key> ./restored
```

Lifecycle rules configuradas pela infra.

---

## Teste de restore (obrigatório)

Cadência mínima: **trimestral** em PRD. Procedimento:

1. Escolher backup aleatório (não o último).
2. Subir staging isolada.
3. Restaurar apenas o backup (banco + amostra de uploads).
4. Smoke test:
   - Login funciona
   - Listagens principais retornam dados
   - Upload persiste no bucket
5. Documentar em `docs/backup/restore-test-YYYYMMDD.md`: tempo total, problemas, correções.

Se o teste falhar, backup **não está funcional** — corrigir imediatamente e reagendar.

---

## Secrets no backup

Nunca incluir:
- Secrets em `.env` — vivem no Railway dashboard / Portainer UI.
- Tokens Clerk — gerenciados externamente.

Se o banco tiver colunas com PII/tokens, considerar:
- Encriptação do dump: `pg_dump | gpg --symmetric --cipher-algo AES256 > backup.dump.gpg`
- Chave em vault externo (1Password, HashiCorp Vault) — nunca no mesmo storage do backup.

---

## Incident runbook

### Perdi a instância de produção

1. Confirmar perda (não é só rede).
2. Provisionar nova instância (Railway addon novo ou Portainer stack nova).
3. Restaurar backup mais recente válido.
4. Atualizar `DATABASE_URL`/S3 vars nos services.
5. Rodar migrations para cobrir lacuna (entrypoint normalmente faz).
6. Smoke test antes de direcionar tráfego.
7. Post-mortem em `docs/incidents/YYYY-MM-DD-<descricao>.md`.

### Corrupção silenciosa

1. **Não** rodar backup antes de investigar (sobrescreve backup limpo).
2. Identificar último backup pré-corrupção.
3. Restaurar em staging primeiro.
4. Comparar diffs. Decidir: rollback total ou restore cirúrgico de tabelas.

---

## Checklist de rollout

- [ ] Backup automático ativo (Railway addon **ou** container `backup` on-premise).
- [ ] Imagem `${REGISTRY}/backup-postgres:latest` disponível (on-premise).
- [ ] Buckets `backup-${APP_NAME}-db` criados no MinIO UAT/PRD pela infra (on-premise).
- [ ] Backup de S3/MinIO configurado (versioning ou worker).
- [ ] `RETENTION_DAYS` ≥ 30 em PRD.
- [ ] Secrets de encriptação em vault externo (se aplicável).
- [ ] Runbook de restore documentado.
- [ ] Teste de restore executado e passou.
- [ ] Alerta se backup falhar.
- [ ] Próxima data de teste trimestral agendada.
