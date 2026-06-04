# Integrações pendentes para finalizar produção

Este arquivo lista o que depende de contas, chaves externas ou decisões que não devem ficar hardcoded no repositório.

## Estado validado em 04/06/2026

- Vercel production atualizado em `https://luum-app.vercel.app` com as APIs de login, admin, checkout, backup, workspace e CORS restrito.
- `login.html` e `cadastro.html` em produção usam `user.getIdToken(true)` antes de chamar `/api/auth/upsert-user` e antes de abrir `luum://auth`, reduzindo falhas por token Firebase antigo no app.
- Firebase Hosting publicado em `https://luum-app.web.app` com `auth.js?v=8`.
- `OPTIONS /api/auth/upsert-user` aceita `Origin: https://luum-app.web.app` e rejeita origem desconhecida.
- `auth.js` compartilhado cria/atualiza `users/{uid}` via `/api/auth/upsert-user` antes de abrir o app com `luum://auth`.
- `login.html?app=mac` é o único fluxo web que abre `luum://auth`; login comum do site redireciona para `account.html`.
- `cadastro.html?app=mac` preserva o retorno para o app; cadastro comum do site redireciona para `account.html`.
- App macOS validado localmente com `swift test`, `swift build` e `./script/build_and_run.sh --verify`.
- Build local do app continua assinado ad-hoc e usa cofre local cifrado por padrão, sem Keychain do macOS, para evitar prompts recorrentes enquanto não houver Apple Developer ID estável.

Progresso aproximado para finalizar o produto:

- Login, Firebase e gates por plano: 90%.
- Backup Firebase: 80-85%.
- Stripe e billing: 75-80%, pendente de compra/cancelamento real e conferência do webhook no painel.
- App macOS completo: 70-75%, pendente de QA manual ponta a ponta no Mac.
- Integrações externas de agenda/tarefas/automação: 45-60%, porque dependem de credenciais e contas reais.

Ainda precisa de validação manual com uma conta real: entrar no site, abrir o app pelo deeplink, alterar plano no `admin.html` e clicar em validar assinatura no app.

## Firebase

- Regras `firestore.rules` publicadas em produção. A política versionada permite ao usuário autenticado ler apenas o próprio perfil e bloqueia gravações diretas, backups e o cofre fora do backend Admin.
- Confirmar o projeto final (`luum-app`) e domínios autorizados do Firebase Auth.
- Endpoint `POST /api/auth/upsert-user` validado em produção para criar/atualizar `users/{uid}` via Admin SDK após login/cadastro.
- Endpoint `GET /api/auth/status` validado em produção recebendo exclusivamente `Authorization: Bearer {firebase_id_token}` e retornando `locked`, `plan`, `trial`, `expiresAt`, `trialEndsAt` e `reason`.
- Configurar `ADMIN_EMAILS` no backend com o primeiro email administrador, separado por vírgula se houver mais de um.
- Usar `admin.html` para promover usuários e definir `plan`, `subscription.status`, validade, assentos e `role`.
- Opcional: manter custom claims `luumAdmin` para admins; a fonte de verdade dos planos deve continuar sendo Firestore/Stripe.

## Credenciais removidas do histórico ativo

- Rotacionar a chave Gemini que estava em `src/LUUM.API/appsettings.json`; o backend `.NET` agora espera `Gemini__ApiKey` ou `GEMINI_API_KEY` fora do Git.
- Rotacionar o Google OAuth client secret que estava em `src/LUUM.API/appsettings.json`; segredos OAuth devem ficar somente em configuração local ignorada ou em cofre externo.
- O projeto Firestore padrão do backend `.NET` foi alinhado para `luum-app`. O desenvolvimento local continua usando o emulador.

## Backend escolhido

Use Vercel para as rotas Node já existentes do site, porque `website/api/*.js` já segue o formato serverless. Firebase Hosting deve continuar servindo o site estático e chamar a API oficial em `https://luum-app.vercel.app`.

Variáveis necessárias no deploy:

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `PUBLIC_SITE_URL` com a URL pública do site usada no retorno do Checkout; depois do bootstrap também pode ser salva pelo cofre do admin
- `LUUM_SETTINGS_ENCRYPTION_KEY` com uma chave aleatória longa para criptografar o cofre de integrações no Firestore
- `STRIPE_MIN_SEATS_EQUIPES=2` e `STRIPE_MIN_SEATS_NEGOCIOS=5` se quiser sobrescrever os mínimos já protegidos no backend
- `FIREBASE_SERVICE_ACCOUNT_JSON` com a credencial técnica restrita do Admin SDK
- `ADMIN_EMAILS` com os emails autorizados a acessar `admin.html`

Domínio oficial usado pelo app desktop: `https://luum-app.vercel.app`. Login, backup e ranking rejeitam endpoints alternativos para impedir que preferências locais redirecionem o Firebase ID token.

## Stripe

Stripe configurado em produção:

- `essencial`: R$ 29,90/mês; anual com 2 meses grátis: R$ 299,00/ano, equivalente a R$ 24,92/mês.
- `profissional`: R$ 49,90/mês; anual com 2 meses grátis: R$ 499,00/ano, equivalente a R$ 41,58/mês.
- `equipes`: R$ 45,00/usuário/mês; anual com 2 meses grátis: R$ 450,00/usuário/ano, equivalente a R$ 37,50/usuário/mês; mínimo 2 usuários.
- `negocios`: R$ 65,00/usuário/mês; anual com 2 meses grátis: R$ 650,00/usuário/ano, equivalente a R$ 54,17/usuário/mês; mínimo 5 usuários.

- Produtos, preços mensais/anuais, `STRIPE_WEBHOOK_SECRET`, `PUBLIC_SITE_URL` e todos os `STRIPE_PRICE_*` foram salvos no cofre criptografado.
- Revogar qualquer chave `sk_live_` ou `rk_live_` exposta em chat, log ou captura antes de uso. Salvar a substituta diretamente no cofre admin, nunca em arquivos versionados.
- Para uma chave restrita, liberar somente o necessário ao backend: criação de Checkout Sessions, leitura/escrita de assinaturas e acesso exigido pelo Stripe para clientes. A assinatura do webhook usa uma credencial separada `whsec_`.
- Diagnóstico criado em `GET /api/admin/stripe-health`; `POST /api/admin/stripe-health` faz bootstrap admin sem criar função Vercel extra.
- Checkout de Equipes e Negócios solicita quantidade de assentos e respeita os mínimos configurados.
- Webhook configurado para `checkout.session.completed`, `invoice.payment_succeeded`, `customer.subscription.updated` e `customer.subscription.deleted`.
- Validar em produção o cancelamento em `POST /api/cancel-subscription` após existir uma assinatura real, ou substituir pelo Stripe Customer Portal.
- Testar checkout com cartões de teste antes de produção.

## App macOS

- O app já recebe `luum://auth?token=...&refreshToken=...&uid=...`, exige que o UID do callback confira com o token, renova token Firebase expirado, consulta `/api/auth/status`, usa a validade de trial enviada pelo backend, aplica gates por plano e salva sessão local em cofre cifrado sem acionar o Keychain do macOS em builds ad-hoc.
- Sessões locais só mantêm acesso offline por até 24 horas após uma validação real do servidor. Falhas de rede não renovam essa tolerância; rejeições explícitas da API bloqueiam a sessão e exigem novo login.
- Ao aplicar uma sessão Firebase, o app fixa backup e workspace no domínio oficial, troca o `backupID` para o UID Firebase e desliga backup bruto quando a conta está bloqueada ou não está no plano Negócios. Mesmo que uma preferência antiga esteja suja em disco, push/restore usam o domínio oficial e o UID da sessão.
- O monitoramento local só inicia depois de uma sessão local ainda válida ou de uma validação real no backend. Logout, sessão bloqueada ou rejeição explícita da API param a captura local.
- Notificações, lembretes, metas e perfis de foco respeitam os gates de plano antes de pedir permissão do macOS, criar regras ou avaliar alertas locais.
- Toggles de integrações premium e workspace também respeitam o plano antes de ficarem ativos; Zapier exige integrações avançadas e ranking corporativo exige plano de equipe. O endpoint do workspace fica fixo no domínio oficial da Vercel.
- Sem Apple Developer, mantenha assinatura ad-hoc (`codesign --sign -`) para builds locais. O armazenamento local cifrado evita o prompt recorrente “Luum deseja usar as informações confidenciais…” causado pelo Keychain quando a assinatura muda.
- Verificação local atual: `./script/build_and_run.sh --verify` compila e assina o app ad-hoc. Nesta máquina, `swift test` compila o bundle de testes com sucesso, mas as Command Line Tools não expõem o runner `xctest`.
- Para reduzir crack em distribuição real, mover validação final para servidor: expiração curta, refresh obrigatório, device id por instalação e checagem de assinatura no backend. Nenhum bloqueio local é 100% à prova de crack.
- O desktop fixa login, backup e ranking em `https://luum-app.vercel.app`: preferências locais não podem redirecionar o Firebase ID token para outro domínio.

### Roteiro de validação do login e planos

1. Abrir `https://luum-app.vercel.app/admin.html` com `oluum.app@gmail.com` e confirmar que `/api/admin/health` mostra Firebase Admin, Firestore e permissão de admin como OK.
2. Se `/api/admin/health` acusar configuração ausente, revisar `FIREBASE_SERVICE_ACCOUNT_JSON`, `ADMIN_EMAILS`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` e `LUUM_SETTINGS_ENCRYPTION_KEY` na Vercel e republicar.
3. Entrar no site com uma conta comum. O login deve chamar `/api/auth/upsert-user` e criar/atualizar `users/{uid}` no Firestore.
4. No site, clicar em Entrar ou Começar Grátis sem `app=mac` deve terminar em `account.html`, sem tentar abrir o app.
5. Em `login.html?app=mac`, clicar em `Criar conta` deve manter o fluxo em `cadastro.html?app=mac`; em `cadastro.html?app=mac`, clicar em `Faça login` deve voltar para `login.html?app=mac`.
6. No app macOS, clicar em Entrar. O site deve abrir `login.html?app=mac` e retornar para o app com `luum://auth?token=...&refreshToken=...&uid=...`.
7. No app, confirmar que o status muda para `Plano {nome} validado.`. Sem token ou com UID divergente, o app deve rejeitar o callback.
8. No `admin.html`, alterar o plano/status do usuário. No app, clicar em `Validar assinatura` e confirmar que telas premium liberam ou bloqueiam conforme o plano.
9. Testar logout no app. A captura local deve parar e as telas voltam para o bloqueio de login.
10. Testar offline por menos de 24 horas após uma validação real: o app pode manter recursos do plano localmente. Depois dessa janela, deve pedir nova validação online.
11. Validar backup: em plano Profissional ou maior, `Sincronizar agora` deve gravar em `/api/sync/{uid}`. Backup bruto só deve ficar disponível no plano Negócios.

## Calendários e integrações

- Google Calendar: criar OAuth Client tipo Desktop app, autorizar redirect local do fluxo nativo e colar o Client ID no app. Client secret é opcional no app desktop e, se usado, fica no cofre local cifrado.
- Outlook: registrar app no Azure/Microsoft Entra, gerar token Microsoft Graph com permissões de calendário e colar no app.
- Notion: criar integração interna, copiar token, compartilhar as data sources com ela e informar os IDs/URLs no app.
- ClickUp: gerar API token pessoal ou de workspace e informar os List IDs que devem entrar na agenda.
- Linear: gerar API key e informar Workspace/Team IDs.
- Zapier: criar webhook Catch Hook e colar URL no app. O backup remove a URL completa antes de enviar preferências ao Firebase.

## Backup Firebase

- API criada no site/backend: `website/api/sync/[backupID].js`.
- O app macOS envia backup com `Authorization: Bearer {firebase_id_token}` para `/api/sync/{backupID}`.
- `backupID` vira obrigatoriamente o UID Firebase após login e a API rejeita identificadores alternativos.
- Atividades brutas continuam desligadas por privacidade e só podem ser armadas/enviadas se o app estiver com sessão validada em plano `rawActivityBackup` (Negócios).
- Antes do envio, o app remove tokens OAuth, client secret Google, URL privada do webhook Zapier e eventos temporários da agenda Google. O Firestore recebe estrutura de contas, configurações sanitizadas e resumos.
- O backup mantém metadados úteis de integração, como IDs de databases/listas/times e labels de workspace, para facilitar restauração. Tokens/API keys de Notion, Outlook, ClickUp, Linear, Google, segredo de workspace e webhook completo do Zapier continuam somente no cofre local deste Mac.
- A API também valida assinatura e plano no Firestore antes de aceitar push ou restore. Essa checagem server-side impede que um binário desktop modificado libere backup ou atividades brutas apenas removendo gates locais.
- Não salvar tokens OAuth de calendários no Firestore sem criptografia por usuário/dispositivo.

## Workspace e ranking corporativo

- APIs Vercel criadas em `/api/workspaces/{workspaceID}/members/{memberID}` e `/api/workspaces/{workspaceID}/ranking`.
- O app usa o domínio Vercel por padrão, envia o Firebase ID token e exige plano `equipes` ou `negocios`.
- A chave compartilhada funciona como convite do workspace: o backend salva apenas SHA-256 no Firestore e compara hashes em tempo constante.
- O primeiro membro com plano elegível cria o workspace; membros seguintes entram usando o mesmo Workspace ID e chave compartilhada.
- Snapshots publicados contêm métricas agregadas semanais. Tokens OAuth e atividades brutas não entram no ranking.


## Admin de planos

- Página criada no site: `website/admin.html`.
- APIs criadas no backend Vercel: `website/api/admin/users.js` e `website/api/admin/health.js`.
- Ao abrir `admin.html` logado, o painel testa `/api/admin/health` e mostra API base, Firebase Admin, Firestore, `ADMIN_EMAILS` e sua permissão.
- A tela usa `window.LUUM_API_BASE` para chamar o backend. O padrão atual é `https://luum-app.vercel.app`; se publicar em outro domínio, altere em `firebase-config.js`.
- O admin inicial autorizado no backend é `oluum.app@gmail.com`. Use `ADMIN_EMAILS` na Vercel para incluir emails adicionais; depois disso, a página também pode promover outros usuários para `role: admin`.
- A Vercel também precisa de `FIREBASE_SERVICE_ACCOUNT_JSON`; sem isso a API não consegue gravar o plano nem criar o documento `users/{uid}` no Firestore. Crie uma conta técnica restrita para o backend Vercel e não cole o JSON em código, commits ou conversas.
- A seção `Cofre de integrações` em `admin.html` salva segredos criptografados no Firestore e nunca devolve valores completos ao navegador. Para ativá-la, configure uma vez `LUUM_SETTINGS_ENCRYPTION_KEY` na Vercel.
- A API exige Firebase ID token e só permite acesso para emails em `ADMIN_EMAILS` ou usuários com custom claim `luumAdmin: true`.
- Para dar plano manual, o usuário precisa existir no Firebase Auth. Busque por email ou UID, selecione plano/status/dias/assentos e salve.
- Depois de alterar um plano, peça para a pessoa clicar em `Validar plano` no app ou fazer login novamente, porque o app mantém uma sessão local para funcionar offline.


## Marca e ícone

- Nova logo aplicada como `luum_website/favicon.png`.
- A fonte do ícone do app macOS também usa `src/LUUM.Client/wwwroot/favicon.png`; o script `build_and_run.sh` gera `AppIcon.icns` a partir dela.

## Bootstrap mínimo de produção

1. Criar uma conta técnica restrita para o backend Vercel no projeto Firebase `luum-app`.
2. Salvar o JSON diretamente na variável sensível `FIREBASE_SERVICE_ACCOUNT_JSON` da Vercel.
3. Gerar uma chave aleatória longa e salvar diretamente em `LUUM_SETTINGS_ENCRYPTION_KEY`.
4. Republicar a Vercel quando variáveis sensíveis mudarem e validar `/api/auth/upsert-user`, `/api/auth/status` e `/api/admin/health`.
5. Publicar `firestore.rules` e o Hosting Firebase quando regras ou arquivos estáticos mudarem.
6. Entrar como `oluum.app@gmail.com` em `admin.html` e preencher integrações adicionais pelo cofre.
