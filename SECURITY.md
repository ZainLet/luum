# Security Policy

## Supported Versions

O Luum está em alpha. Correções de segurança são aplicadas ao branch alpha ativo e à versão alpha mais recente.

| Versão | Suportada |
| --- | --- |
| `v0.1.x` / build alpha mais recente | Sim |
| Builds alpha antigos | Melhor esforço |
| Builds locais não empacotados | Sem suporte público |

## Reporting a Vulnerability

Reporte problemas de segurança de forma privada para `oluum.app@gmail.com`. Não abra issues públicas com segredos, tokens, dados de clientes, prints de chaves de API ou detalhes de exploit.

Inclua:

- Breve descrição do problema e superfície afetada: app macOS, website, API Vercel, Firebase/Firestore, Stripe, OAuth de integração ou instalador.
- Passos para reproduzir com conta de teste quando possível.
- Request IDs, timestamps ou logs sanitizados relevantes.
- Se algum Firebase ID token, chave Stripe, chave Gemini, chave Resend, webhook secret, client_secret OAuth ou dados de backup de usuário podem ter sido expostos.

Tratamento esperado:

- Confirmamos reportes reproduzíveis assim que possível.
- Priorizamos problemas de takeover de conta, alterações de pagamento/plano, acesso indevido a backup Firebase, vazamento de segredos de integração ou comprometimento do instalador.
- Publicamos correções no próximo build alpha para problemas no app macOS ou redeploy Vercel/Firebase para problemas server-side.

## Secret Handling

Nunca commite segredos de produção neste repositório. Credenciais de produção devem ficar em variáveis de ambiente da Vercel, no storage admin cifrado de integrações, nos dashboards Firebase/Stripe, ou em um gerenciador de senhas separado.

Valores sensíveis incluem:

- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `LUUM_SETTINGS_ENCRYPTION_KEY`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `GEMINI_API_KEY`
- `RESEND_API_KEY`
- `NOTION_CLIENT_SECRET`
- `OUTLOOK_CLIENT_SECRET`
- OAuth client secrets, refresh tokens, URLs de webhook do Zapier, workspace secrets e chaves privadas.

A suite de testes do repositório inclui um scan de regressão para padrões comuns de chaves privadas. Se um segredo real for commitado, rotacione-o imediatamente no provedor externo, remova-o do branch ativo e trate qualquer artefato de build a partir desse commit como não confiável.

Chaves públicas (Firebase web API key, OAuth client IDs públicos como `GOOGLE_CALENDAR_CLIENT_ID`, `NOTION_CLIENT_ID`, `OUTLOOK_CLIENT_ID`) não são segredos, mas devem apontar apenas para o projeto oficial Luum e devem ser protegidas por Firebase Auth, regras do Firestore, origens permitidas e validação no backend.

## Modelo de segurança OAuth

O Luum usa dois padrões distintos para OAuth de integrações:

**PKCE sem client_secret (Google Calendar):** O app nativo usa PKCE com loopback em `127.0.0.1` (RFC 8252). O client_secret não está no app nem no servidor. O client ID deve ser do tipo "App para computador" (Desktop app) no GCP — client IDs do tipo "Aplicativo Web" causam `invalid_request: client_secret is missing`.

**OAuth gerenciado pelo servidor (Notion, Outlook):** O fluxo passa inteiramente pelo backend Vercel. O `client_secret` fica apenas nas variáveis de ambiente da Vercel e nunca é enviado ao app. O app recebe apenas o `access_token` (e `refresh_token` para Outlook) via redirect `luum://`. Renovação de tokens Outlook é feita server-side via `/api/integrations?action=outlook-refresh`.

URIs de redirect OAuth válidos (devem ser configurados nos portais de cada provedor):

- Notion: `https://luum-app.vercel.app/api/integrations?action=notion-callback`
- Outlook: `https://luum-app.vercel.app/api/integrations?action=outlook-callback`
- Google Calendar: `127.0.0.1:<porta-efêmera>` (loopback local, RFC 8252)

## Production Boundaries

- Website oficial: `https://luum-app.web.app`
- API backend oficial: `https://luum-app.vercel.app`
- Projeto Firebase oficial: `luum-app`
- Bundle ID macOS: `com.luum.apple`

O app macOS deve enviar Firebase ID tokens apenas ao backend oficial. Login, status de plano, backup em nuvem, PDF semanal por email, ranking de workspace e classificação de IA não devem ser redirecionados para preferências locais arbitrárias ou endpoints de terceiros em produção.

Integrações suportadas em produção:

- **Google Calendar** — PKCE loopback no app, client ID em `/api/public/integrations`
- **Notion Calendar** — OAuth server-side com `NOTION_CLIENT_ID` + `NOTION_CLIENT_SECRET` na Vercel
- **Outlook Calendar** — OAuth server-side com `OUTLOOK_CLIENT_ID` + `OUTLOOK_CLIENT_SECRET` na Vercel; refresh token armazenado no Keychain local cifrado
- **ClickUp / Linear** — API token pessoal inserido pelo usuário em Preferências, armazenado no Keychain

## macOS Alpha Distribution

Os builds alpha atuais são assinados ad-hoc e empacotados como instalador `.pkg` que coloca `luum.app` em `/Applications`. Até que o Apple Developer Program, assinatura Developer ID, hardened runtime e notarização sejam configurados, o Gatekeeper pode exigir `Control-click > Abrir` no primeiro launch.

Tokens OAuth e chaves de API de integrações ficam no Keychain local cifrado do macOS e nunca são enviados ao servidor de backup. Apenas metadados de atividade (com controles de privacidade opt-in) são sincronizados com o backend Vercel.
