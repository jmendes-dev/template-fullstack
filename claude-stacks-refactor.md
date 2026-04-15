# claude-stacks-refactor.md — Aprendizados e Extensões

> **Este arquivo é um documento vivo.**
> Contém regras, padrões e configurações descobertos durante o desenvolvimento
> que complementam o `claude-stacks.md`.
>
> **Auto-atualizado pelo Claude** quando um erro evitável é encontrado (ver CLAUDE.md → Auto-atualização do Stacks).

---

## Regras descobertas

### Bugs pré-existentes devem ser corrigidos, não ignorados

**Regra**: Quando `bun test`, `bunx biome check`, ou `tsc` encontrar erros pré-existentes durante qualquer ciclo de desenvolvimento, eles devem ser corrigidos antes de continuar — nunca classificar como "pré-existente" e prosseguir.

**Por quê**: Ignorar bugs pré-existentes cria bola de neve: cada feature nova adiciona complexidade sobre um baseline quebrado, torna o fix mais difícil e pode criar falsos verdes nos testes novos.

**Como aplicar**:
- Escopo pequeno (≤ 30 min): corrigir imediatamente com commit separado — `fix: corrigir [descrição] pré-existente`
- Escopo grande: criar P1 no backlog e bloquear qualquer nova feature até resolver

Ver política completa em `claude-debug.md → Bugs pré-existentes`.

<!-- Adicionadas automaticamente pelo Claude durante o desenvolvimento -->

---

## Bug Journal

> Preenchido automaticamente via skill `escalation-and-bug-journal` para bugs com > 30 min de investigação.
> **Como preencher**: Após resolver bug de escopo grande, adicionar uma entrada abaixo.

<!-- Template de entrada:
### Bug: [descrição curta] — [data]
- **Sintoma**: O que estava acontecendo
- **Causa raiz**: O que causou o problema
- **Correção**: Como foi resolvido
- **Tempo investido**: Xh Ymin
- **Nível de escalação**: 1-4
- **Lição aprendida**: O que evitar no futuro
- **Candidato a promoção?**: Sim / Não
-->

---

## Candidatos a promoção

> Regras que podem beneficiar todos os projetos. Revisar periodicamente e promover para os arquivos globais.

| Regra | Origem | Destino | Status |
|---|---|---|---|
