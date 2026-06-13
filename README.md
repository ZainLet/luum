# LUUM

O `luum` e um app de monitoramento de tempo com cliente macOS em SwiftUI, site no Firebase Hosting e backend oficial em rotas Vercel para login, planos, backup, workspace e Stripe.

## Estrutura

- `/src/LUUM.Mac`: app macOS com monitoramento de apps, URLs, agenda e lembretes.
- `/website`: site estatico, paginas de login/admin/conta e APIs Vercel em `website/api`.
- `/src/LUUM.API`: API local legada para desenvolvimento e experimentos com Firestore.
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
- backup Firebase via backend Vercel com plano Profissional ou maior
- PDF semanal por email gerado no backend com Gemini e enviado para o email verificado da conta

### Navegadores suportados

Safari, Google Chrome, Arc, Brave, Microsoft Edge, Chromium, Opera e Vivaldi.

### Permissoes

- `Automacao`: necessaria para ler a aba ativa dos navegadores.
- `Monitoramento de Entrada`: opcional, melhora a deteccao de inatividade.
- `Notificacoes`: usada pelos lembretes de foco e entretenimento.

### Google Agenda

Para o usuario final, o fluxo esperado e:

1. Abrir `Preferencias > Google Agenda`.
2. Clicar em `Conectar Google Calendar`.
3. Fazer login no Google no navegador.
4. Escolher os calendarios que entram no `luum`.

O app tenta carregar o `GOOGLE_CALENDAR_CLIENT_ID` publico em `https://luum-app.vercel.app/api/public/integrations`. Assim o usuario nao precisa colar Client ID ou secret.

As credenciais da agenda ficam em um cofre local cifrado neste Mac. O backup em nuvem salva apenas a configuracao das contas e dos calendarios, nao os dados sensiveis da conexao.

Para deixar o Google Calendar pronto em producao:

1. Ative a [Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com).
2. Crie um OAuth client do tipo `Desktop app`.
3. Salve o Client ID como `GOOGLE_CALENDAR_CLIENT_ID` na Vercel ou no cofre de integracoes do admin.
4. Republique a Vercel e valide `GET /api/public/integrations`.

### Modelo de integracoes

O objetivo de produto e que cada integracao tenha apenas um botao de conexao, sem pedir chaves tecnicas ao usuario comum. Na alpha atual, esse fluxo guiado esta ativo para Google Calendar.

- Google Calendar: ja usa OAuth no app e agora busca o Client ID publico no backend.
- IA de classificacao: usa o backend seguro do Luum por padrao; a chave Gemini deve ficar em `GEMINI_API_KEY` na Vercel.
- PDF semanal por email: o app envia dados semanais sanitizados para `/api/reports/weekly-email`; Gemini e provedor de email ficam na Vercel, e o backend envia apenas para o email verificado da conta Firebase.
- Firebase backup: usa a sessao Firebase do app e salva em `/api/sync/{uid}`.
- Stripe: checkout e webhook ficam no backend Vercel e escrevem o plano no Firestore.
- Notion, Outlook, ClickUp, Linear e Zapier: a tela do app mostra o status "em implantacao", sem pedir token/API key e sem abrir um login que nao conclui a conexao. Para ficarem 100% guiadas, ainda faltam callbacks OAuth/backend proprios e credenciais salvas na infraestrutura do Luum, nao no Mac do usuario.

As integracoes que ainda dependem de configuracao externa estao detalhadas em `docs/INTEGRACOES_PENDENTES.md` e no checklist operacional `docs/CHECKLIST_INTEGRACOES_EXTERNAS.md`.

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

Para validar apenas o bundle assinado, sem abrir o app:

```bash
./script/build_and_run.sh --verify-bundle
```

Para gerar uma alpha macOS compactada para teste de instalacao em outros Macs:

```bash
./script/build_and_run.sh --package
```

O pacote sai em `dist/releases/` com instalador `.pkg`, fallback `.zip`, checksums `.sha256` e notas de build. O `.pkg` instala `luum.app` em `/Applications`; o `.zip` contem o app bundle completo `luum.app`. A versao alpha atual e `0.0.3`, usa bundle id `com.luum.apple` e exige macOS 26 ou superior. Enquanto o app estiver assinado ad-hoc, o primeiro launch em outro Mac pode exigir `Control-click > Abrir` por causa do Gatekeeper. O passo a passo de teste fica em `docs/MACOS_ALPHA_INSTALL.md`.

Para assinar com uma identidade local de desenvolvedor:

```bash
APPLE_CODESIGN_IDENTITY="Developer ID Application: Seu Nome" ./script/build_and_run.sh
```

## Backend oficial e desenvolvimento local

O backend oficial usado pelo site e pelo app macOS fica em:

```text
https://luum-app.vercel.app
```

O app desktop fixa esse dominio para login, status de plano, backup e workspace. Isso evita que preferencias locais redirecionem o Firebase ID token para uma API falsa.

O site estatico fica em:

```text
https://luum-app.web.app
```

Para testar a API local legada e o Firestore Emulator:

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

O app macOS de produção não usa esse endpoint local para plano ou backup Firebase. Ele valida conta em `/api/auth/status` na Vercel e salva backup em `/api/sync/{uid}` com `Authorization: Bearer {firebase_id_token}`.

## Distribuicao Windows/Linux

O caminho de portabilidade esta documentado em `docs/MANUAL_DISTRIBUICAO_WINDOWS_LINUX.md`. A recomendacao atual e criar um cliente Windows nativo com WinUI 3/Windows App SDK, reaproveitando backend e contratos JSON, e tratar Linux como pesquisa posterior.
