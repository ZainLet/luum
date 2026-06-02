# Integrações pendentes para finalizar produção

Este arquivo lista o que depende de contas, chaves externas ou decisões que não devem ficar hardcoded no repositório.

## Firebase

- Publicar `luum_website/firestore.rules` em produção. A política versionada permite ao usuário autenticado ler apenas o próprio perfil e bloqueia gravações diretas, backups e o cofre fora do backend Admin.
- Confirmar o projeto final (`luum-app`) e domínios autorizados do Firebase Auth.
- Validar em produção o endpoint `POST /api/auth/upsert-user`, já implementado em `luum_website/api/auth/upsert-user.js`, para criar/atualizar `users/{uid}` via Admin SDK após login/cadastro.
- Validar em produção o endpoint `GET /api/auth/status`, já implementado em `luum_website/api/auth/status.js`, recebendo `Authorization: Bearer {firebase_id_token}` e retornando `locked`, `plan`, `trial`, `expiresAt` e `reason`.
- Configurar `ADMIN_EMAILS` no backend com o primeiro email administrador, separado por vírgula se houver mais de um.
- Usar `admin.html` para promover usuários e definir `plan`, `subscription.status`, validade, assentos e `role`.
- Opcional: manter custom claims `luumAdmin` para admins; a fonte de verdade dos planos deve continuar sendo Firestore/Stripe.

## Backend escolhido

Use Vercel para as rotas Node já existentes do site, porque `luum_website/api/*.js` já segue o formato serverless. Firebase Hosting deve continuar servindo o site estático e redirecionar ou chamar a API no domínio escolhido.

Variáveis necessárias no deploy:

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `PUBLIC_SITE_URL` com a URL pública do site usada no retorno do Checkout; depois do bootstrap também pode ser salva pelo cofre do admin
- `LUUM_SETTINGS_ENCRYPTION_KEY` com uma chave aleatória longa para criptografar o cofre de integrações no Firestore
- `STRIPE_MIN_SEATS_EQUIPES=2` e `STRIPE_MIN_SEATS_NEGOCIOS=5` se quiser sobrescrever os mínimos já protegidos no backend
- `FIREBASE_SERVICE_ACCOUNT_JSON` com a credencial técnica restrita do Admin SDK
- `ADMIN_EMAILS` com os emails autorizados a acessar `admin.html`
- `API_KEY` apenas se mantiver fallback por chave compartilhada

Domínio padrão usado pelo app desktop: `https://luum-app.vercel.app`. Se publicar com outro domínio, configure no Mac com `defaults write com.zainlet.luum LuumBackendBaseURL "https://seu-dominio.com"` ou lance o app com `LUUM_BACKEND_BASE_URL`.

## Stripe

Preços confirmados e unificados no site:

- `essencial`: R$ 29,90/mês; anual exibido R$ 269,00/ano.
- `profissional`: R$ 49,90/mês; anual exibido R$ 449,00/ano.
- `equipes`: R$ 45,00/usuário/mês; anual exibido R$ 33,75/usuário/mês; mínimo 2 usuários.
- `negocios`: R$ 65,00/usuário/mês; anual exibido R$ 48,75/usuário/mês; mínimo 5 usuários.

- Criar produtos e preços no Stripe para `essencial`, `profissional`, `equipes` e `negocios`.
- Preencher os valores Stripe pelo cofre criptografado em `admin.html` ou pelas variáveis `STRIPE_PRICE_*` do deploy para cada plano e ciclo mensal/anual.
- Diagnóstico criado em `GET /api/admin/stripe-health`; a tela `admin.html` lista envs Stripe ausentes sem revelar valores secretos.
- Checkout de Equipes e Negócios solicita quantidade de assentos e respeita os mínimos configurados.
- Configurar webhook para `checkout.session.completed`, `invoice.payment_succeeded`, `customer.subscription.updated` e `customer.subscription.deleted`.
- Validar em produção o cancelamento em `POST /api/cancel-subscription` ou substituir pelo Stripe Customer Portal.
- Testar checkout com cartões de teste antes de produção.

## App macOS

- O app já recebe `luum://auth?token=...&refreshToken=...&uid=...`, renova token Firebase expirado, consulta `/api/auth/status`, aplica gates por plano e salva sessão local com fallback quando o Keychain falha.
- Sessões locais só mantêm acesso offline por até 24 horas após uma validação real do servidor; falhas de rede não renovam essa tolerância.
- Sem Apple Developer, mantenha assinatura ad-hoc (`codesign --sign -`) para builds locais.
- Para reduzir crack em distribuição real, mover validação final para servidor: expiração curta, refresh obrigatório, device id por instalação e checagem de assinatura no backend. Nenhum bloqueio local é 100% à prova de crack.

## Calendários e integrações

- Google Calendar: criar OAuth Client tipo Desktop app e colar Client ID no app.
- Outlook: registrar app no Azure/Microsoft Entra e revisar escopos Graph.
- Notion: criar integração interna e compartilhar databases com ela.
- ClickUp/Linear: gerar tokens/API keys por workspace.
- Zapier: criar webhook Catch Hook e colar URL no app.

## Backup Firebase

- API criada no site/backend: `luum_website/api/sync/[backupID].js`.
- O app macOS envia backup com `Authorization: Bearer {firebase_id_token}` para `/api/sync/{backupID}`.
- Por padrão, `backupID` vira o UID Firebase após login e o endpoint vira o domínio Vercel configurado.
- Atividades brutas continuam desligadas por privacidade e só são enviadas se o plano permitir `rawActivityBackup` (Negócios).
- Não salvar tokens OAuth de calendários no Firestore sem criptografia por usuário/dispositivo.


## Admin de planos

- Página criada no site: `luum_website/admin.html`.
- APIs criadas no backend Vercel: `luum_website/api/admin/users.js` e `luum_website/api/admin/health.js`.
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
4. Republicar a Vercel e validar `/api/auth/upsert-user`, `/api/auth/status` e `/api/admin/health`.
5. Publicar `firestore.rules` e o Hosting Firebase para remover arquivos operacionais da superfície pública.
6. Entrar como `oluum.app@gmail.com` em `admin.html` e preencher integrações adicionais pelo cofre.
