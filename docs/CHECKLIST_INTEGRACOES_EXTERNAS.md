# Checklist de integracoes externas do Luum

Atualizado em 2026-06-12.

Este arquivo separa o que o repositorio ja implementa do que precisa ser feito fora do codigo: contas, chaves, OAuth apps, webhooks e validacoes manuais. Nao cole segredos neste arquivo.

## Estado atual

- Backend oficial: Vercel em `https://luum-app.vercel.app`.
- Site oficial: Firebase Hosting em `https://luum-app.web.app`.
- Identidade: Firebase Auth.
- Fonte de verdade de plano: Firestore via backend Vercel, alimentado por Stripe ou admin manual.
- App macOS: usa `luum://auth`, valida `/api/auth/status`, salva sessao em cofre local cifrado e evita Keychain do macOS por padrao enquanto nao houver Apple Developer ID.
- Backup: usa `/api/sync/{uid}` com Firebase ID token e payload sanitizado.
- Google Calendar: o app ja tenta carregar `GOOGLE_CALENDAR_CLIENT_ID` em `/api/public/integrations`, para o usuario clicar em conectar sem colar chaves.

## Responsabilidades que dependem do dono do projeto

Estas tarefas nao podem ser finalizadas apenas por codigo local, porque exigem acesso a paineis externos ou decisao de produto.

| Area | O que falta fora do codigo | Onde validar | Bloqueia |
| --- | --- | --- | --- |
| Firebase | Confirmar dominios autorizados, publicar `firestore.rules`, manter `FIREBASE_SERVICE_ACCOUNT_JSON` na Vercel | Firebase Console e `/api/admin/health` | Login, plano, admin, backup |
| Vercel | Manter variaveis sensiveis e redeploy quando mudarem | Vercel env vars e `/api/admin/health` | APIs oficiais |
| Stripe | Conferir produtos/precos reais, webhook, checkout e cancelamento com conta real | Stripe Dashboard e `/api/admin/stripe-health` | Billing automatico |
| Google Calendar | Ativar Calendar API, criar OAuth Client `Desktop app`, salvar Client ID publico | Google Cloud Console e `/api/public/integrations` | Conexao Google com um clique |
| Gemini | Rotacionar chave exposta em teste e salvar `GEMINI_API_KEY` na Vercel | `/api/ai/classify` | IA segura sem chave no app |
| Notion | Criar integracao, compartilhar data sources, escolher propriedades de data/titulo | Preferencias do app e sync manual | Agenda Notion |
| Outlook | Registrar app Microsoft Entra e obter fluxo Microsoft Graph adequado | Preferencias do app e sync manual | Agenda Outlook |
| ClickUp | Gerar token/API app e listar List IDs | Preferencias do app e sync manual | Tarefas ClickUp |
| Linear | Gerar API key/OAuth app e listar Team IDs | Preferencias do app e sync manual | Issues Linear |
| Zapier | Criar Catch Hook ou app Zapier publico | Teste Zapier no app | Automacoes |
| Apple | Entrar no Apple Developer Program, Developer ID, notarizacao | `spctl`, `notarytool`, Mac limpo | Distribuicao sem alerta Gatekeeper |

## Variaveis de producao obrigatorias

Configure na Vercel, nunca no Git:

- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `ADMIN_EMAILS`
- `LUUM_SETTINGS_ENCRYPTION_KEY`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `STRIPE_PRICE_ESSENCIAL_MONTHLY`
- `STRIPE_PRICE_ESSENCIAL_ANNUALLY`
- `STRIPE_PRICE_PROFISSIONAL_MONTHLY`
- `STRIPE_PRICE_PROFISSIONAL_ANNUALLY`
- `STRIPE_PRICE_EQUIPES_MONTHLY`
- `STRIPE_PRICE_EQUIPES_ANNUALLY`
- `STRIPE_PRICE_NEGOCIOS_MONTHLY`
- `STRIPE_PRICE_NEGOCIOS_ANNUALLY`
- `PUBLIC_SITE_URL`
- `GEMINI_API_KEY`
- `GOOGLE_CALENDAR_CLIENT_ID`

O cofre de integracoes do `admin.html` pode armazenar parte desses valores criptografados, mas o bootstrap inicial ainda depende de `LUUM_SETTINGS_ENCRYPTION_KEY` e credenciais de admin configuradas na Vercel.

## Firebase

1. Confirmar projeto `luum-app`.
2. Em Firebase Auth, manter autorizados:
   - `luum-app.web.app`
   - dominio customizado futuro, se existir
3. Publicar `firestore.rules`.
4. Criar uma service account restrita para o backend.
5. Salvar o JSON como `FIREBASE_SERVICE_ACCOUNT_JSON` na Vercel.
6. Validar `GET /api/admin/health` logado como `oluum.app@gmail.com`.
7. Validar que `POST /api/auth/upsert-user` cria `users/{uid}`.
8. Validar que `GET /api/auth/status` retorna o plano efetivo correto.

Contrato esperado do app:

- Login comum do site termina em `account.html`.
- Login do app usa `login.html?app=mac`.
- O site abre `luum://auth?token=...&refreshToken=...&uid=...`.
- O app rejeita UID divergente, projeto Firebase errado e endpoint de backend nao oficial.

## Stripe

Planos oficiais:

- Essencial: R$ 29,90/mes ou R$ 299,00/ano.
- Profissional: R$ 49,90/mes ou R$ 499,00/ano.
- Equipes: R$ 45,00/usuario/mes ou R$ 450,00/usuario/ano, minimo 2 usuarios.
- Negocios: R$ 65,00/usuario/mes ou R$ 650,00/usuario/ano, minimo 5 usuarios.

Eventos do webhook:

- `checkout.session.completed`
- `invoice.payment_succeeded`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Checklist manual:

1. Criar ou conferir os produtos e precos no Stripe.
2. Salvar todos os Price IDs no cofre/admin ou env vars.
3. Configurar webhook para `https://luum-app.vercel.app/api/webhook`.
4. Salvar `STRIPE_WEBHOOK_SECRET`.
5. Rodar um checkout real ou modo teste.
6. Confirmar que `users/{uid}.plan` e `users/{uid}.subscription` foram atualizados.
7. Abrir app macOS e clicar em `Validar plano`.
8. Testar cancelamento via `/api/cancel-subscription` ou decidir migrar para Stripe Customer Portal.

## Google Calendar

O codigo ja implementa OAuth desktop com callback local e busca do Client ID publico no backend.

Checklist manual:

1. Ativar Google Calendar API no Google Cloud.
2. Criar OAuth Client do tipo `Desktop app`.
3. Salvar o Client ID em `GOOGLE_CALENDAR_CLIENT_ID`.
4. Nao salvar Client Secret no repositorio. Para desktop app, o secret deve continuar opcional.
5. Redeploy da Vercel.
6. Validar `GET https://luum-app.vercel.app/api/public/integrations`.
7. No app, entrar com conta Firebase validada.
8. Clicar em `Conectar Google Calendar`.
9. Escolher calendarios e sincronizar.

## IA de classificacao

O app usa por padrao `https://luum-app.vercel.app/api/ai/classify`, com Firebase ID token. Isso evita expor chave Gemini no binario macOS.

Checklist manual:

1. Revogar qualquer chave Gemini exposta em teste.
2. Criar uma nova chave.
3. Salvar como `GEMINI_API_KEY` na Vercel.
4. Opcional: configurar `GEMINI_MODEL` e `GEMINI_ENDPOINT`.
5. Testar classificacao em Apps/Sites no app.

## Notion

Implementado hoje como token manual no app. Para virar conexao de um clique, ainda falta backend OAuth.

Checklist manual atual:

1. Criar uma integracao interna no Notion.
2. Copiar token da integracao.
3. Compartilhar cada data source com a integracao.
4. Copiar Data Source IDs.
5. Informar token, Data Source IDs, propriedade de data e propriedade de titulo no app.
6. Sincronizar e conferir mensagens de 403/404 quando uma data source nao foi compartilhada.

Para finalizar como produto:

- Criar `/api/integrations/notion/connect`.
- Criar `/api/integrations/notion/callback`.
- Guardar refresh/access tokens server-side com criptografia por usuario.
- Deixar o app apenas com botao `Conectar Notion`.

## Outlook

Implementado hoje como token Microsoft Graph manual. Para uso comercial, precisa OAuth Microsoft Entra.

Checklist manual atual:

1. Registrar app no Microsoft Entra.
2. Definir permissoes de calendario no Microsoft Graph.
3. Obter token adequado para teste.
4. Colar token no app.
5. Selecionar calendarios.

Para finalizar como produto:

- Criar OAuth backend Microsoft.
- Suportar contas pessoais e tenants corporativos.
- Tratar consentimento de administrador quando a organizacao exigir.
- Renovar tokens no backend.

## ClickUp e Linear

Implementados hoje com API keys/tokens manuais e IDs de listas/times.

Checklist manual atual:

1. Gerar token/API key.
2. Copiar Workspace ID quando aplicavel.
3. Copiar List IDs do ClickUp ou Team IDs do Linear.
4. Ativar a integracao no app.
5. Sincronizar e validar datas/prazos.

Para finalizar como produto:

- Criar OAuth ou app oficial de cada plataforma.
- Salvar tokens no backend.
- Adicionar tela de selecao de listas/times depois do OAuth.

## Zapier

Implementado hoje como webhook manual.

Checklist manual atual:

1. Criar Zap com `Catch Hook`.
2. Copiar URL do webhook.
3. Colar no app.
4. Enviar evento de teste.

Para finalizar como produto:

- Criar app publico no Zapier ou fluxo OAuth.
- Separar eventos suportados: foco, calendario sincronizado, ranking/workspace.
- Permitir usuario escolher quais eventos enviar.

## Validacao ponta a ponta antes de chamar de pronto

1. Criar usuario novo no site.
2. Confirmar `users/{uid}` no Firestore.
3. Abrir app pelo login `?app=mac`.
4. Confirmar plano trial ativo e recursos liberados conforme matriz de trial.
5. Promover usuario no `admin.html`.
6. Revalidar no app e conferir bloqueios/liberacoes.
7. Fazer checkout Stripe.
8. Confirmar webhook gravando assinatura.
9. Testar backup e restore.
10. Testar Google Calendar sem Client ID manual.
11. Testar Notion/Outlook/ClickUp/Linear/Zapier com credenciais reais.
12. Testar em Mac limpo com alpha zip.

