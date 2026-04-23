# templates/ — Samples de referência

> **Não é runtime.** Estes arquivos são copiados (e adaptados) por `/new-project` no scaffold de um projeto consumidor do template.

## Arquivos

| Arquivo | Para onde copiar | Quando |
|---|---|---|
| `docker-compose.yml` | raiz do projeto consumidor | Fase 4 do `start_project.md` |
| `vite.config.ts` | `apps/web/vite.config.ts` | Fase 4, após `bunx shadcn@latest init -t vite` |

## Regras ao copiar

1. **NUNCA** referenciar `templates/` em tempo de execução — é só um ponto de partida.
2. **SEMPRE** ajustar:
   - `docker-compose.yml`: nome do service `backup` (`${APP_NAME}`), portas se conflitam, env vars específicas do projeto.
   - `vite.config.ts`: plugins extras (ex: `@sentry/vite-plugin`), aliases adicionais.
3. **SEMPRE** validar:
   - `docker compose -f docker-compose.yml config --quiet` → sintaxe OK
   - `bun run dev` → HMR funciona: editar um componente → browser recarrega em < 2s

## Checklist HMR (obrigatório em Fase 4)

- [ ] `docker compose up` sobe sem erro
- [ ] `curl http://localhost:${WEB_PORT:-5173}` retorna HTML da app
- [ ] Editar `apps/web/src/App.tsx` (trocar texto) → browser recarrega em < 2s sem F5 manual
- [ ] `docker compose exec web touch /app/apps/web/src/test-hmr.txt` → Vite detecta o evento via polling
- [ ] `docker compose logs postgres` → `database system is ready`
- [ ] `curl http://localhost:${API_PORT:-3000}/health` → `200 OK`

Se qualquer item falhar → não prosseguir para Fase 5. Revisar bind-mounts, env vars de polling, portas.
