# HANDOFF — Luum

**Data:** 2026-06-23  
**Branch:** main (13 commits à frente do estado anterior)

---

## O que foi feito nesta sessão

### Ticket #50 — Workspace Admin (roles + UI)
- `website/api/_workspace.js`: `ensureWorkspace` cria workspaces com `admins: [uid]`; `requireWorkspaceAdmin` exportado
- `website/api/workspaces/[workspaceID]/ranking.js`: POST retorna `isCurrentUserAdmin` + `isAdmin` por entry; PATCH com actions `list/promote/demote/remove`
- `ActivityStore.swift`: bug do Keychain corrigido em `runFetchAdminList`/`runAdminAction` (chave hardcoded → `Self.teamWorkspaceSecretKey`)
- `WorkspaceAdminView.swift`: nova view com lista de membros, badges, botões promover/rebaixar/remover
- `TeamRankingView.swift`: botão "Admin" visível só para admins

### Ticket #56 — Notion OAuth
- Backend: `_notion-auth.js` (GET, retorna URL) + `_notion-callback.js` (troca código, redireciona para `luum://notion`)
- Swift: `connectNotionCalendar()`, `handleNotionOAuthCallback()`, seção Notion em `SettingsView`
- **Pendência Zain:** criar integração pública em notion.so/my-integrations; adicionar `NOTION_CLIENT_ID` + `NOTION_CLIENT_SECRET` no Vercel

### Ticket #78 — LUUM-DIFF-001
- `ActivityStore.signOut()`: reset de `isCurrentUserWorkspaceAdmin = false` e `workspaceAdminEntries = []`

### Ticket #51 — Outlook Calendar OAuth
- Backend: `_outlook-auth.js` + `_outlook-callback.js` + `_outlook-refresh.js` (refresh automático, `client_secret` server-side)
- Swift: `OutlookCalendarTokens: Codable, Sendable`, `loadValidOutlookTokens()` com refresh automático
- **Pendência Zain:** criar app no Azure Portal; adicionar `OUTLOOK_CLIENT_ID` + `OUTLOOK_CLIENT_SECRET` no Vercel

### Fix — Google Calendar erro 400
- `GoogleCalendarService.perform()`: adicionado `OAuthErrorEnvelope` decoder para erros OAuth do token endpoint
- `friendlyOAuthError()`: mapeia `invalid_client` → "use 'App para computador' no GCP", `invalid_grant`, `redirect_uri_mismatch`
- **Diagnóstico:** `GOOGLE_CALENDAR_CLIENT_ID` atual é tipo "Aplicativo Web" → precisa ser recriado como "App para computador"

### Redesign onboarding (`website/cadastro.html`)
- Glassmorphism no card, progress bar com glow + label numérica, ícones em caixinhas 30×30
- Estados de seleção com gradiente + box-shadow, hover com pseudo-elemento `::before`
- Emoji problemáticos corrigidos: 🗂️ → "•••", 👨‍👩‍👧‍👦 → 🏛
- Boas-vindas com badge "CONFIGURAÇÃO RÁPIDA" e feature list

---

## Pendências para o usuário (Zain)

| Item | Ação |
|------|------|
| Google Calendar | Recriar OAuth client como "App para computador" no GCP; atualizar `GOOGLE_CALENDAR_CLIENT_ID` no Vercel |
| Notion | Criar integração pública em notion.so/my-integrations; redirect URI: `https://luum-app.vercel.app/api/integrations?action=notion-callback`; adicionar `NOTION_CLIENT_ID` + `NOTION_CLIENT_SECRET` no Vercel |
| Outlook | Criar app no Azure Portal; redirect URI: `https://luum-app.vercel.app/api/integrations?action=outlook-callback`; adicionar `OUTLOOK_CLIENT_ID` + `OUTLOOK_CLIENT_SECRET` no Vercel |
| ClickUp / Linear | Entrar API token em Preferências > Conexões (não é OAuth) |
| `appcast.xml` | v0.1.2 tem `sparkle:edSignature="PLACEHOLDER"` — precisa assinar após `./script/build_and_run.sh --package` |

---

## Tickets abertos relevantes

- **#57** — Completar e validar Google Calendar OAuth em produção (Codex)
- **#42** — Verificar Google Calendar em produção (Codex)
- **#58** — OAuth ClickUp (Claude)
- **#59** — OAuth Linear (Claude)
- **#60** — Integração Zapier (Claude)
- **#79** — Fechar branch codex/cloud-sync-coalesce (Claude)
- **#85** — Revisão visual completa website (comentado com onboarding feito)
- **#41** — Revisão final de segurança (OpenCode)
- **#44** — Identidade de produto: ícone, bundle ID (Zain)

---

## Estado do repositório

- **Branch:** main, todos os commits pushed para origin
- **Vercel:** 11/12 funções (limite Hobby = 12)
- **Build:** `swift build --package-path src/LUUM.Mac` ✅ Build complete
- **Testes backend:** `cd website && npm test` — devem passar

---

## Próximas sessões sugeridas

1. Configurar env vars OAuth (Google/Notion/Outlook) → testar fluxo ponta a ponta
2. Implementar OAuth ClickUp (#58) e Linear (#59)
3. Revisão de segurança (#41) antes de distribuição pública
