# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão geral

O Luum é um app macOS de rastreamento de tempo. O principal entregável é o app nativo SwiftUI (`src/LUUM.Mac`), distribuído como `.app`/`.pkg` assinado. O backend roda como funções serverless na Vercel (`website/api/`). O Firebase é a fonte de identidade e o Firestore gerencia assinaturas e entitlements. Os projetos `.NET` (`LUUM.API`, `LUUM.Client`, `LUUM.DesktopHelper`) são legados e não estão em desenvolvimento ativo.

## Comandos

### App macOS

Todas as ações de build e release passam pelo script único, executado a partir de `luum/`:

```bash
./script/build_and_run.sh                  # build + abre o app
./script/build_and_run.sh --verify         # build + verifica bundle + abre (sem debugger de UI)
./script/build_and_run.sh --verify-bundle  # verifica apenas o bundle assinado, sem abrir
./script/build_and_run.sh --package        # gera alpha .pkg + .zip em dist/releases/
./script/build_and_run.sh --verify-package # verifica o último pacote gerado
```

Para assinar com uma identidade real:
```bash
APPLE_CODESIGN_IDENTITY="Developer ID Application: …" ./script/build_and_run.sh
```

Para rodar os testes Swift diretamente (requer Xcode completo, não só Command Line Tools):
```bash
swift test --package-path src/LUUM.Mac
```

### Website / API Vercel

Os testes são executados a partir de `website/`:
```bash
npm test                                       # roda todos os arquivos de teste com node --test
node --test website/test/sync-api.test.js      # roda um único arquivo de teste
```

### API legada local + emulador Firestore

```bash
./script/run_api.sh                  # .NET API em http://localhost:5000
./script/run_local_sync_stack.sh     # API + Firestore Emulator juntos
```

## Arquitetura

### App macOS (`src/LUUM.Mac`)

Swift 6 com concorrência estrita, SwiftUI, macOS 26+, SPM puro (sem projeto Xcode).

**Objeto de estado central:** `ActivityStore` (`Stores/ActivityStore.swift`) — classe `@Observable` no `@MainActor`. Todos os serviços são criados aqui e não são injetados em outros lugares. As views recebem o store e leem dele de forma reativa.

**Fluxo de dados:**
1. `ActivityMonitor` faz polling a cada 8 s usando `NSWorkspace` + `BrowserURLProvider` (AppleScript) → emite `ActivitySnapshot`.
2. `ActivityStore` passa os snapshots para `ClassificationEngine` (baseado em regras) e opcionalmente `AIClassificationService` (Gemini via Vercel) → armazena o `ActivitySample` resultante em memória e persiste via `ActivityPersistence` (JSON em `~/Library/Application Support/luum/`).
3. As views (`DashboardView`, `TimelineActivityEditor`, `ReportsView`, etc.) leem do store; `ContentView` é o root switcher.

**Fluxo de autenticação:** URL scheme `luum://auth` → `LUUMAppDelegate` → `NotificationCenter` → `ActivityStore.handleAuthCallbackURL` → `FirebaseAuthService` valida o token contra `https://luum-app.vercel.app/api/auth/status`. O app fixa a URL de produção da Vercel para auth/sync — não usa a API legada local.

**Camada de persistência:**
- Log de atividade: `ActivityPersistence` — JSON em `~/Library/Application Support/luum/activity-log.json`, trimado pelo `retentionDays` (padrão 30).
- Credenciais: `KeychainService` — todos os tokens e segredos ficam no Keychain do macOS.
- Conexão Google Calendar: `GoogleCalendarPersistence`.
- Preferências de monitoramento: `MonitoringPreferencesPersistence`.

**Backup em nuvem:** `CloudSyncService` — envia `CloudBackupPayload` para `/api/sync/{uid}` (Vercel) com Firebase ID token. Controlado por plano (Profissional+). Upload de atividade bruta é opt-in via preferências de privacidade.

**Workspace/equipe:** `WorkspaceSyncService` — lê ranking de `/api/workspaces/{id}/ranking`, envia dados do membro. Vinculado aos planos Equipes/Negócios.

**Integrações pendentes:** Notion, Outlook, ClickUp, Linear, Zapier mostram botão de conexão, mas não têm implementação OAuth/backend; nunca devem pedir tokens ou chaves diretamente ao usuário.

### Backend Vercel (`website/api/`)

Node 22, CommonJS (`"type": "commonjs"`). Cada arquivo é uma função serverless da Vercel. Helpers compartilhados têm prefixo `_` (ex.: `_firebaseAdmin.js`, `_entitlements.js`).

Rotas principais:
- `auth/status.js` — valida Firebase ID token, retorna status de plano/trial/locked.
- `sync/[backupID].js` — leitura/escrita de backup; requer plano Profissional+.
- `ai/classify.js` — proxy para o Gemini; a chave fica no servidor como `GEMINI_API_KEY`.
- `reports/weekly-email.js` — recebe resumo semanal sanitizado, chama Gemini, envia e-mail apenas para o endereço verificado do Firebase.
- `checkout.js` / `webhook.js` — checkout e webhook handler do Stripe.
- `public/integrations.js` — retorna config pública sanitizada (ex.: `GOOGLE_CALENDAR_CLIENT_ID`) sem segredos.
- `admin/[action].js` — ações do painel admin, protegidas por `_adminAuth.js`.

Variáveis de ambiente obrigatórias na Vercel: `GEMINI_API_KEY`, `GOOGLE_CALENDAR_CLIENT_ID`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, credenciais da service account do Firebase.

### Skills locais (`.agents/skills/`)

Arquivos de skill para fluxos assistidos por agente neste repo. Use quando a tarefa se encaixar:

- `luum-context-router` — escolher o menor contexto útil antes de buscas ou edições amplas
- `luum-small-patch` — mudanças mínimas, seguras e verificáveis
- `luum-ui-polish` — melhorias pequenas de UI/UX
- `luum-auth-plans-sync` — Firebase Auth, Firestore, `luum://auth`, planos, backup, sync, segredos
- `luum-gemini-cost-control` — reduzir custo de chamadas de IA, tamanho de prompt, retries e risco de chave
- `luum-release-checklist` — checagens de release e empacotamento
- `luum-review-diff` — revisão focada de diff sem varrer o repo inteiro
- `luum-checkin` — retomada rápida de status (sem auditoria completa)
- `luum-handoff` — reinício ultra-curto a partir do handoff
- `luum-rollover` — checkpoint próximo ao limite de contexto

## Convenções importantes

- **Toda string de UI está em português (pt-BR).** Mensagens de erro em `FirebaseAuthService`, labels de botões, itens de menu — manter consistência.
- **Swift 6 strict concurrency:** todos os serviços são `@MainActor` ou `Sendable`. Evitar `@unchecked Sendable` sem justificativa.
- **Nenhum token/chave de API na UI.** Integrações sem OAuth/backend devem exibir botão "Conectar" desabilitado — nunca pedir token ou chave bruta ao usuário.
- **Versionamento em alpha:** incrementar patch (`v0.0.x`) para builds pequenos, minor (`v0.1.0`) para mudanças grandes de UI/UX. Não usar sufixos longos como `v0.0.2-alpha.5`.
- **`dist/` é saída de build** — não deve ser comitado. `dist/releases/` contém artefatos empacotados.

## Grafo de conhecimento (Graphify)

Um grafo de conhecimento do repositório está em `graphify-out/`. Antes de responder perguntas de arquitetura ou navegação no codebase, leia `graphify-out/GRAPH_REPORT.md` para a estrutura de comunidades e nós centrais.
