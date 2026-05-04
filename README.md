# LUUM

O `luum` e um app de monitoramento de tempo com cliente macOS em SwiftUI e backend opcional em ASP.NET Core + Firestore para backup e sincronizacao.

## Estrutura

- `/src/LUUM.Mac`: app macOS com monitoramento de apps, URLs, agenda e lembretes.
- `/src/LUUM.API`: API local para backup em Firestore e futuras automacoes.
- `/src/LUUM.Client`: painel web legado em Blazor.
- `/src/LUUM.DesktopHelper`: helper legado para Windows.

## Cliente macOS

O app monitora:

- app em foco
- dominio e URL da aba ativa nos navegadores suportados
- categorias editaveis com regras por app, bundle e site
- lembretes por categoria
- timeline diaria com edicao manual
- Google Agenda com varias contas e varios calendarios por conta
- backup opcional em Firestore

### Navegadores suportados

Safari, Google Chrome, Arc, Brave, Microsoft Edge, Chromium, Opera e Vivaldi.

### Permissoes

- `Automacao`: necessaria para ler a aba ativa dos navegadores.
- `Monitoramento de Entrada`: opcional, melhora a deteccao de inatividade.
- `Notificacoes`: usada pelos lembretes de foco e entretenimento.

### Google Agenda

1. Ative a [Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com).
2. Crie um OAuth client do tipo `Desktop app`.
3. Em `Preferencias > Google Agenda`, cole o `Client ID`.
4. Opcionalmente, cole o `Client secret`.
5. Clique em `Adicionar conta Google`.
6. Escolha os calendarios que entram no `luum`.

Os tokens OAuth ficam no Keychain deste Mac. O backup em nuvem salva apenas a configuracao das contas e dos calendarios, nao os tokens.

### Privacidade e backup

Em `Preferencias` voce pode controlar:

- se titulos de abas sao salvos
- se URLs completas sao salvas
- por quantos dias o historico fica no disco
- se o backup envia apenas dominios
- se atividades brutas entram ou nao no backup

## Como rodar o app macOS

```bash
./script/build_and_run.sh
```

Para validar sem abrir o debugger:

```bash
./script/build_and_run.sh --verify
```

Para assinar com uma identidade local de desenvolvedor:

```bash
APPLE_CODESIGN_IDENTITY="Developer ID Application: Seu Nome" ./script/build_and_run.sh
```

## API local e Firestore Emulator

Pre-requisitos:

- [.NET 8 SDK](https://dotnet.microsoft.com/download)
- [Firebase CLI](https://firebase.google.com/docs/cli)

Para subir a API local em `http://localhost:5000`:

```bash
./script/run_api.sh
```

Para subir API + Firestore Emulator em um comando so:

```bash
./script/run_local_sync_stack.sh
```

O `luum` usa esse endpoint local para o backup em Firestore quando voce ativa `Preferencias > Backup Firestore`.
