# LUUM

App de monitoramento de tempo com cliente macOS em SwiftUI, site no Firebase Hosting e backend oficial em rotas Vercel para login, planos, backup, workspace e Stripe.

## Estrutura

- `/src/LUUM.Mac` — app macOS com monitoramento de apps, URLs, agenda integrada, workspace e lembretes.
- `/website` — site estático, páginas de login/admin/conta e APIs Vercel em `website/api`.
- `/src/LUUM.API` — API local legada para desenvolvimento e experimentos com Firestore.
- `/src/LUUM.Client` — painel web legado em Blazor.
- `/src/LUUM.DesktopHelper` — helper legado para Windows.

## Cliente macOS

O app monitora:

- app em foco e domínio/URL da aba ativa nos navegadores suportados
- categorias editáveis com regras por app, bundle e site
- lembretes por categoria (foco, entretenimento etc.)
- timeline diária com edição manual
- agenda integrada: Google Calendar (múltiplas contas), Notion Calendar, Outlook Calendar, ClickUp e Linear numa linha do tempo unificada
- ranking de workspace com comparativo de produtividade do time
- backup Firebase via backend Vercel (plano Profissional ou maior)
- PDF semanal por email gerado no backend com Gemini e enviado para o email verificado da conta

### Navegadores suportados

Safari, Google Chrome, Arc, Brave, Microsoft Edge, Chromium, Opera e Vivaldi.

### Permissões

- `Automação` — necessária para ler a aba ativa dos navegadores.
- `Monitoramento de Entrada` — opcional, melhora a detecção de inatividade.
- `Notificações` — usada pelos lembretes de foco e entretenimento.

---

## Integrações

### Modelo geral

O objetivo é que cada integração tenha apenas um botão de conexão, sem pedir chaves técnicas ao usuário comum. O `GOOGLE_CALENDAR_CLIENT_ID` público é carregado em `/api/public/integrations`, e os fluxos OAuth do Notion e do Outlook passam inteiramente pelo backend Vercel — o `client_secret` nunca chega ao app.

### Google Calendar

Fluxo para o usuário final:

1. Abrir `Preferências > Google Calendar`.
2. Clicar em `Conectar Google Agenda`.
3. Fazer login no Google no navegador (fluxo PKCE + loopback local).
4. Escolher os calendários que entram no Luum.

Para deixar o Google Calendar pronto em produção:

1. Ative a [Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com).
2. Crie um OAuth client do tipo **`App para computador` (Desktop app)** — não "Aplicativo Web".
3. Salve o Client ID como `GOOGLE_CALENDAR_CLIENT_ID` na Vercel.
4. Republique a Vercel e valide `GET /api/public/integrations`.

> **Importante:** client IDs do tipo "Aplicativo Web" exigem `client_secret` no token exchange e causam erro `invalid_request: client_secret is missing`. Use sempre o tipo "App para computador" para aplicativos nativos com PKCE.

### Notion Calendar

Fluxo OAuth gerenciado pelo backend:

1. `GET /api/integrations?action=notion-auth` — retorna URL de autorização do Notion.
2. Usuário autoriza no browser.
3. Notion redireciona para `/api/integrations?action=notion-callback` — backend troca código por token e redireciona para `luum://notion?access_token=...`.

Para ativar em produção:

1. Crie uma integração pública em [notion.so/my-integrations](https://www.notion.so/my-integrations).
2. Defina a redirect URI: `https://luum-app.vercel.app/api/integrations?action=notion-callback`.
3. Adicione `NOTION_CLIENT_ID` e `NOTION_CLIENT_SECRET` na Vercel.

### Outlook Calendar (Microsoft Graph)

Fluxo OAuth com refresh automático de token:

1. `GET /api/integrations?action=outlook-auth` — retorna URL de autorização Microsoft.
2. Usuário autoriza no browser.
3. Microsoft redireciona para `/api/integrations?action=outlook-callback` — backend troca código por `access_token + refresh_token` e redireciona para `luum://outlook`.
4. Renovação automática via `POST /api/integrations?action=outlook-refresh` — o `client_secret` nunca sai do servidor.

Para ativar em produção:

1. Crie um app no [Azure Portal](https://portal.azure.com) > Azure Active Directory > Registros de aplicativo.
2. Defina a redirect URI: `https://luum-app.vercel.app/api/integrations?action=outlook-callback`.
3. Scopes necessários: `offline_access openid profile Calendars.Read Mail.ReadBasic`.
4. Adicione `OUTLOOK_CLIENT_ID` e `OUTLOOK_CLIENT_SECRET` na Vercel.

### ClickUp

Usa API token pessoal (não OAuth). O usuário insere o token em `Preferências > Conexões`. Adicione o Workspace ID e os IDs de listas para ativar o sync.

### Linear

Usa API token pessoal (não OAuth). O usuário insere o token em `Preferências > Conexões`. Adicione o Workspace ID e os IDs de times para ativar o sync.

### Outros

- **IA de classificação** — usa o backend seguro do Luum por padrão; a chave Gemini deve ficar em `GEMINI_API_KEY` na Vercel.
- **PDF semanal por email** — o app envia dados semanais sanitizados para `/api/reports/weekly-email`; Gemini e provedor de email ficam na Vercel, e o backend envia apenas para o email verificado da conta Firebase.
- **Firebase backup** — usa a sessão Firebase do app e salva em `/api/sync/{uid}`.
- **Stripe** — checkout e webhook ficam no backend Vercel e escrevem o plano no Firestore.
- **Zapier** — webhook configurável nas preferências de integração.

---

## Workspace e Admin

O Luum suporta workspaces corporativos com membros, papéis e controles de admin:

- Ranking de produtividade compartilhado entre membros do workspace
- Painel de admin acessível para usuários com papel `admin` (`Preferências > Equipe`)
- Actions disponíveis: listar membros, promover/rebaixar admin, remover membro
- O primeiro usuário a criar um workspace é automaticamente admin

---

## Privacidade e backup

Em `Preferências` você pode controlar:

- se títulos de abas são salvos
- se URLs completas são salvas
- por quantos dias o histórico fica no disco
- se o backup envia apenas domínios
- se atividades brutas entram ou não no backup

Credenciais de integrações (tokens OAuth, API tokens) ficam no Keychain local cifrado e nunca são enviadas ao servidor de backup.

---

## Como rodar o app macOS

```bash
./script/build_and_run.sh                  # build + abre o app
./script/build_and_run.sh --verify         # build + valida bundle + abre
./script/build_and_run.sh --verify-bundle  # valida apenas o bundle, sem abrir
./script/build_and_run.sh --package        # gera alpha .pkg + .zip em dist/releases/
./script/build_and_run.sh --verify-package # revalida o instalador gerado
```

Para assinar com identidade real:

```bash
APPLE_CODESIGN_IDENTITY="Developer ID Application: Seu Nome" ./script/build_and_run.sh
```

### Versão atual

**v0.1.2** · bundle id `com.luum.apple` · macOS 26+

Política de versão enquanto o Luum estiver em alpha:

- Último dígito para builds pequenos: `v0.1.2`, `v0.1.3`...
- Dígito do meio para mudanças grandes de UI/UX: `v0.2.0`
- `v1.0.0` reservado para a primeira versão pública

O pacote sai em `dist/releases/` com instalador `.pkg`, fallback `.zip`, checksums `.sha256` e notas de build. Enquanto o app estiver assinado ad-hoc, o primeiro launch em outro Mac pode exigir `Control-click > Abrir` por causa do Gatekeeper.

---

## Backend (Vercel)

```
https://luum-app.vercel.app
```

O app desktop fixa esse domínio para login, status de plano, backup e workspace. **Não redirecione Firebase ID tokens para endpoints arbitrários.**

Funções serverless ativas (11/12 no Hobby plan):

| Função | Responsabilidade |
|--------|-----------------|
| `admin/[action].js` | Painel admin autenticado |
| `ai/[action].js` | Classify + query Gemini |
| `auth/[action].js` | Status de conta + upsert-user |
| `checkout.js` | Sessão Stripe + cancelamento |
| `integrations/[action].js` | OAuth Notion, Outlook (helpers com `_` prefix) |
| `public/integrations.js` | Config pública de integrações |
| `reports/weekly-email.js` | PDF semanal por email |
| `sync/[backupID].js` | Backup Firebase |
| `webhook.js` | Webhook Stripe |
| `workspaces/[workspaceID]/members/[memberID].js` | Membership |
| `workspaces/[workspaceID]/ranking.js` | Ranking + admin actions |

Variáveis de ambiente obrigatórias na Vercel:

```
FIREBASE_SERVICE_ACCOUNT_JSON
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
GEMINI_API_KEY
GOOGLE_CALENDAR_CLIENT_ID     # tipo "App para computador"
NOTION_CLIENT_ID              # pendente
NOTION_CLIENT_SECRET          # pendente
OUTLOOK_CLIENT_ID             # pendente
OUTLOOK_CLIENT_SECRET         # pendente
RESEND_API_KEY                # para envio de email
```

Para rodar os testes do backend:

```bash
cd website && npm test
```

---

## Site estático

```
https://luum-app.web.app
```

O onboarding (`/cadastro.html`) coleta cargo, tamanho do time, ferramentas e objetivo antes de criar a conta Firebase. Os dados são enviados para `/api/auth/upsert-user` e salvos no perfil do usuário.

---

## API legada (desenvolvimento local)

Requer [.NET 8 SDK](https://dotnet.microsoft.com/download) e [Firebase CLI](https://firebase.google.com/docs/cli).

```bash
./script/run_api.sh                  # API em http://localhost:5000
./script/run_local_sync_stack.sh     # API + Firestore Emulator
```

---

## Roadmap Windows/Linux

A estratégia de portabilidade (Tauri + Rust core) está documentada em `docs/windows-linux-roadmap.md`. O monitoramento de janelas usaria `win32 GetForegroundWindow` no Windows e `X11/xcb` + `Wayland ext_foreign_toplevel_handle` no Linux.
