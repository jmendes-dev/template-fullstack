# Secrets rotation

Ler ao definir política de rotação de credenciais, responder a vazamento suspeito, ou onboardar um novo provider. Linha-resumo vive em `CLAUDE.md` seção "Production-readiness".

Princípio: **rotacionar antes de precisar**. Toda credencial vive num ciclo: criada → em uso → substituída → revogada. Nunca pular o "revogada".

## Política sugerida

| Secret | Frequência | Urgência se vazar |
|---|---|---|
| `CLERK_SECRET_KEY` | 6 em 6 meses | **Imediata** — todas as sessões invalidadas |
| `VITE_CLERK_PUBLISHABLE_KEY` | junto com secret | Menos urgente (é público por natureza), mas rotaciona junto |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | 6 em 6 meses | Alta — acesso direto ao bucket |
| `POSTGRES_PASSWORD` | 12 em 12 meses | Crítica — mas delicada, planejar maintenance |
| `SENTRY_DSN` | só se vazar | Baixa — DSN é semi-público |
| GitHub Actions tokens (`GITHUB_TOKEN`, `SONAR_TOKEN`) | 12 em 12 meses | Alta |

Política mínima: **rotação agendada no calendário**, revisão quando alguém sai do time com acesso produtivo.

---

## Clerk

### Rotação agendada

1. Clerk dashboard → `API Keys` → `Secret keys`
2. `Add secret key` (não deleta o antigo ainda)
3. Copiar a nova key
4. Atualizar no ambiente de produção:
   - **Railway**: `Variables` → editar `CLERK_SECRET_KEY` → `Deploy`
   - **Portainer**: `Stacks` → editar env → `Update the stack`
5. **Esperar 1 deploy ciclar completo** — healthcheck verde
6. Voltar ao Clerk dashboard → deletar a key antiga

Downtime: ~zero, porque Clerk aceita ambas em paralelo por ~5 min.

### Rotação emergencial (suspeita de vazamento)

1. Clerk dashboard → `Revoke` na key comprometida (invalida imediatamente)
2. **Todas as sessões ativas caem** — usuários precisam logar de novo
3. Criar nova key, deploy urgente
4. Revisar logs de auditoria Clerk em `Dashboard → Audit log` para identificar acesso suspeito
5. Post-mortem: como vazou? Commit acidental? Log externo? CI?

### Publishable key (VITE_CLERK_PUBLISHABLE_KEY)

Publishable key vai para o bundle do frontend — é **público por design**. Rotacionar só ajuda em caso de reuso indevido do `frontend-origin`. Fluxo:

1. Nova publishable key no Clerk
2. Atualizar `VITE_CLERK_PUBLISHABLE_KEY` no deploy do web
3. **Novo build** do frontend (publishable key vira hardcode no bundle)
4. Revogar a antiga após rollout completo

---

## S3 / MinIO

### AWS S3

1. IAM console → criar nova access key para o user/role do app
2. Adicionar ambas (antiga + nova) temporariamente se o SDK suportar — AWS SDK v3 só lê uma de cada vez, então:
3. Atualizar `S3_ACCESS_KEY` + `S3_SECRET_KEY` no ambiente
4. Deploy, esperar healthcheck
5. Revogar a key antiga no IAM

### Railway Buckets

Railway Buckets têm credenciais geradas automaticamente. Rotação:

1. Dashboard → Bucket → `Variables` → `Regenerate credentials` (atualiza `BUCKET_ACCESS_KEY_ID` e `BUCKET_SECRET_ACCESS_KEY`)
2. As references nos services linkados (`S3_ACCESS_KEY` ← `Bucket.BUCKET_ACCESS_KEY_ID`) atualizam automaticamente
3. Railway triggera redeploy dos services linkados
4. Validar com `/ready` (testa `headBucket`)
5. Não há "key antiga" para revogar — a regeneração já invalida a anterior

**Cuidado**: workers de sync (ver `docs/backup-restore.md` seção "Worker de sync") também precisam de redeploy se usam credenciais separadas. Verificar todos os services linkados antes de rotacionar.

### MinIO (Portainer)

MinIO usa usuários ou service accounts:

1. Console MinIO → `Identity` → `Service Accounts` → `Create`
2. Copiar access key + secret
3. Atualizar env `S3_ACCESS_KEY`/`S3_SECRET_KEY` no stack
4. Redeploy do service `api`
5. Esperar healthcheck
6. Console MinIO → deletar o service account antigo

### Post-rotação

Confirmar que uploads/downloads funcionam:

```bash
# healthcheck estendido
docker exec <api-container> sh -c "curl -sf http://localhost:\${PORT:-3000}/ready"
```

Se `/ready` retorna 503 porque o `headBucket` falha, a key não foi atualizada ou não tem permissão — corrigir antes de seguir.

---

## PostgreSQL password

Este é o mais delicado. Conexões abertas usam a senha em memória; mudar força reconexão.

### Railway (addon)

1. Dashboard → Postgres addon → `Variables` → `Regenerate credentials`
   - Isso muda `DATABASE_URL` automaticamente
2. Railway triggera redeploy dos services linkados (aguardar)
3. Monitorar logs da API por erros de conexão
4. Validar com `/ready`

Downtime: geralmente < 30s (Railway orquestra).

### Portainer (stack)

Mais manual, escolher estratégia:

#### Estratégia A — maintenance window (simples)

1. Avisar usuários
2. Parar o service `api`
3. Conectar no Postgres: `ALTER USER <user> WITH PASSWORD '<nova>'`
4. Atualizar `POSTGRES_PASSWORD` no stack
5. Subir `api` de volta
6. Validar

#### Estratégia B — dual-user (zero downtime)

1. Criar user 2 com nova senha: `CREATE USER <user2> WITH PASSWORD '<nova>' IN ROLE <role>`
2. Atualizar `DATABASE_URL` no stack apontando para user 2
3. Deploy (zero downtime — novo container usa user 2, antigo user 1 ainda)
4. Após rollout, dropar user 1: `DROP USER <user1>`

Estratégia B vale se o app não pode cair. Estratégia A serve pra maioria.

---

## Onde secrets vivem

| Local | Quando usar |
|---|---|
| Railway Variables | Padrão para Railway |
| Portainer Environments | Padrão para Portainer |
| `.env.local` (dev) | Apenas dev local — no `.gitignore` |
| 1Password / Bitwarden | Backup do time, source-of-truth humano |
| HashiCorp Vault / AWS Secrets Manager | Empresa de porte maior, CI integra via API |

**Nunca**:
- Commitar `.env*` (exceto `.env.example` sem valores)
- Secret em `docker-compose.yml` sem `${VAR}`
- Secret em log
- Secret em screenshot de dashboard compartilhado (Slack, Drive sem ACL)

## Auditoria de vazamento

Se suspeitar que um secret vazou:

1. **Rotacionar imediatamente** (não esperar investigar)
2. Pesquisar o secret em:
   - Histórico do git (`git log -p -S '<prefixo-do-secret>' --all`)
   - Logs de prod (Sentry, Railway, pino)
   - Screenshots em Slack/Drive
   - CI logs antigos (GitHub Actions retém 90 dias)
3. Se achou no git: `git filter-repo` ou BFG, force-push (coordenar com o time; repo público = assumir comprometido)
4. Se achou em log externo: pedir expurgo ao provider
5. Documentar em `docs/incidents/YYYY-MM-DD-<secret>-leak.md`

---

## Checklist de rollout

- [ ] Calendário com rotações agendadas (ex: Google Calendar recorrência)
- [ ] Runbook de rotação para cada secret (este doc + variações específicas do projeto)
- [ ] Runbook emergencial separado e testado uma vez
- [ ] `.env.example` atualizado a cada novo secret
- [ ] Nenhum secret em commits (verificar com `git secrets` ou `gitleaks` no pre-commit)
- [ ] Inventário de quem tem acesso a cada dashboard (Clerk, AWS, MinIO, Railway)
- [ ] Rotação quando alguém com acesso deixa o time — dentro de 24h
