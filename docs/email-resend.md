# Email transacional — Resend + React Email (opcional)

Ler **se** o projeto envia email (signup confirmation, reset de senha, notificações). Se não envia, pular este doc. Linha-resumo (Resend como provider padrão) vive em `docs/tech-stack.md`.

Princípio: emails são **componentes React** (com `@react-email/components`), enviados via **Resend** com env condicional (mesma estratégia do Clerk e Sentry — graceful degradation em dev).

## Setup

```sh
bun add resend @react-email/components @react-email/render
bun add -D react-email                     # CLI para preview local
```

Env var (condicional, padrão Clerk/Sentry):

```env
RESEND_API_KEY=re_...                       # de resend.com/api-keys
EMAIL_FROM="Masterboi <noreply@masterboi.com.br>"  # domain verificado no Resend
```

CLAUDE.md `Variáveis de ambiente obrigatórias`: marcar `RESEND_API_KEY` e `EMAIL_FROM` como **condicionais (apenas se projeto envia email)**.

## Estrutura

```
apps/api/
└── src/
    └── emails/
        ├── _client.ts              # singleton do Resend
        ├── _send.ts                # helper sendEmail()
        ├── welcome.tsx             # template React Email
        ├── reset-password.tsx
        └── order-confirmation.tsx
```

## Cliente condicional

```typescript
// apps/api/src/emails/_client.ts
import { Resend } from 'resend';

export const resend = process.env.RESEND_API_KEY
  ? new Resend(process.env.RESEND_API_KEY)
  : null;

if (!process.env.EMAIL_FROM) throw new Error('EMAIL_FROM não configurado');
export const FROM = process.env.EMAIL_FROM;
```

`null` em dev sem `RESEND_API_KEY` permite app subir; `_send.ts` faz no-op com log.

## Helper de envio

```typescript
// apps/api/src/emails/_send.ts
import { render } from '@react-email/render';
import type { ReactElement } from 'react';
import { resend, FROM } from './_client';

export type SendEmailInput = {
  to: string | string[];
  subject: string;
  template: ReactElement;
  replyTo?: string;
};

export async function sendEmail(
  { to, subject, template, replyTo }: SendEmailInput,
  logger?: { warn: (...args: unknown[]) => void }
) {
  if (!resend) {
    logger?.warn({ to, subject }, '[email] RESEND_API_KEY ausente — pulando envio');
    return { id: 'dev-noop' };
  }

  const html = await render(template);
  const text = await render(template, { plainText: true });

  const { data, error } = await resend.emails.send({
    from: FROM,
    to,
    subject,
    html,
    text,
    replyTo,
  });

  if (error) throw new Error(`Resend error: ${error.message}`);
  return { id: data!.id };
}
```

## Template em React

```typescript
// apps/api/src/emails/welcome.tsx
import { Html, Head, Body, Container, Heading, Text, Button } from '@react-email/components';

type Props = { name: string; loginUrl: string };

export function WelcomeEmail({ name, loginUrl }: Props) {
  return (
    <Html lang="pt-BR">
      <Head />
      <Body style={{ fontFamily: 'system-ui, sans-serif', backgroundColor: '#f5f5f5' }}>
        <Container style={{ padding: 24, maxWidth: 560 }}>
          <Heading>Bem-vindo, {name}</Heading>
          <Text>Sua conta foi criada com sucesso.</Text>
          <Button href={loginUrl} style={{ background: '#000', color: '#fff', padding: '12px 24px' }}>
            Acessar
          </Button>
        </Container>
      </Body>
    </Html>
  );
}
```

## Uso na rota

```typescript
// apps/api/src/routes/auth.ts
import { sendEmail } from '../emails/_send';
import { WelcomeEmail } from '../emails/welcome';

app.post('/signup', async (c) => {
  const user = await createUser(/* ... */);

  // Não bloquear o response no envio do email
  void sendEmail(
    {
      to: user.email,
      subject: 'Bem-vindo à Masterboi',
      template: WelcomeEmail({ name: user.name, loginUrl: 'https://app.masterboi.com.br' }),
    },
    c.get('logger')
  ).catch((err) => c.get('logger').error({ err }, 'falha ao enviar welcome email'));

  return c.json({ data: user }, 201);
});
```

`void` + `.catch` é o padrão para envio assíncrono não-bloqueante. Para garantir entrega, escalar para `jobs` table (ver `docs/background-jobs.md`).

## Preview em dev

```sh
bunx react-email dev --dir apps/api/src/emails
```

Sobe interface web em `http://localhost:3001` mostrando todos os templates com hot reload. Não envia email — só renderiza.

## Testes

Mock do Resend em testes:

```typescript
import { mock, test, expect } from 'bun:test';

const sendMock = mock(() => Promise.resolve({ data: { id: 'test_123' }, error: null }));

mock.module('resend', () => ({
  Resend: class { emails = { send: sendMock }; },
}));

test('signup envia welcome email', async () => {
  await app.request('/signup', { /* ... */ });
  expect(sendMock).toHaveBeenCalledWith(expect.objectContaining({
    to: 'novo@exemplo.com',
    subject: expect.stringContaining('Bem-vindo'),
  }));
});
```

Render do template puro (snapshot test):

```typescript
import { render } from '@react-email/render';
import { WelcomeEmail } from '../src/emails/welcome';

test('WelcomeEmail renderiza nome', async () => {
  const html = await render(WelcomeEmail({ name: 'Ana', loginUrl: 'https://app' }));
  expect(html).toContain('Bem-vindo, Ana');
});
```

## Domain verification

Resend exige domínio verificado para enviar como `noreply@masterboi.com.br`. Sem isso, só envia de `onboarding@resend.dev`.

1. Resend dashboard → `Domains` → `Add Domain`
2. Adicionar registros DNS no provedor:
   - `MX` (recebimento de bounce)
   - `TXT` (SPF — autoriza Resend a enviar pelo domínio)
   - `TXT` (DKIM — assinatura criptográfica)
   - `TXT` (DMARC — política de rejeição) — opcional mas recomendado
3. Aguardar verificação (até 24h, geralmente minutos)
4. `EMAIL_FROM=Masterboi <noreply@masterboi.com.br>` agora funciona

DMARC mínimo (após SPF+DKIM verdes por 1 semana):

```
_dmarc.masterboi.com.br  TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@masterboi.com.br"
```

## Anti-patterns

- Email síncrono no response da rota — atrasa UX, falha cascateia
- Sem verificação de domínio em prod — vai pra spam
- Hardcodar `from` no código — usar `EMAIL_FROM` env
- HTML inline sem componentes React Email — quebra em Outlook, Gmail dark mode
- Logar email completo (PII) — só destinatário e subject
- Sem `replyTo` em emails que esperam resposta — usuários respondem ao void
- Enviar bulk sem rate limiting da Resend (10 req/s no plano free) — implementar throttle
