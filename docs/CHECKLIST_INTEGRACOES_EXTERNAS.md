# Checklist de integracoes externas do Luum

Atualizado em 2026-06-14.

Este arquivo separa o que o repositorio ja implementa do que precisa ser feito fora do codigo: contas, chaves, OAuth apps, webhooks e validacoes manuais. Nao cole segredos neste arquivo.

## Estado atual

- Backend oficial: Vercel em `https://luum-app.vercel.app`.
- Site oficial: Firebase Hosting em `https://luum-app.web.app`.
- Identidade: Firebase Auth.
- Fonte de verdade de plano: Firestore via backend Vercel, alimentado por Stripe ou admin manual.
- App macOS: usa `luum://auth`, valida `/api/auth/status`, salva sessao em cofre local cifrado e evita Keychain do macOS por padrao enquanto nao houver Apple Developer ID.
- Backup: usa `/api/sync/{uid}` com Firebase ID token e payload sanitizado.
- Google Calendar: o app ja tenta carregar `GOOGLE_CALENDAR_CLIENT_ID` em `/api/public/integrations`, para o usuario clicar em conectar sem colar chaves.
- Alpha macOS atual: `0.0.4-alpha`, bundle id `com.luum.apple`, instalador principal `.pkg` que coloca `luum.app` em `/Applications`; use `Luum-alpha-latest.pkg` para o teste interno mais recente e deixe `.zip` apenas como fallback tecnico.

## Politica de versao

- Builds pequenos de teste alpha devem avancar o ultimo digito: `v0.0.4`, `v0.0.5`, `v0.0.6`.
- Atualizacoes grandes, como a reformulacao de UI/UX, devem avancar o digito do meio: `v0.1.0`.
- A versao `v1.0.0` fica reservada para o lancamento final/publico.

## Responsabilidades que dependem do dono do projeto

Estas tarefas nao podem ser finalizadas apenas por codigo local, porque exigem acesso a paineis externos ou decisao de produto.

| Area | O que falta fora do codigo | Onde validar | Bloqueia |
| --- | --- | --- | --- |
| Firebase | Confirmar dominios autorizados, publicar `firestore.rules`, manter `FIREBASE_SERVICE_ACCOUNT_JSON` na Vercel | Firebase Console e `/api/admin/health` | Login, plano, admin, backup |
| Vercel | Manter variaveis sensiveis e redeploy quando mudarem | Vercel env vars e `/api/admin/health` | APIs oficiais |
| Stripe | Conferir produtos/precos reais, webhook, checkout e cancelamento com conta real | Stripe Dashboard e `/api/admin/stripe-health` | Billing automatico |
| Google Calendar | Ativar Calendar API, criar OAuth Client `Desktop app`, salvar Client ID publico | Google Cloud Console e `/api/public/integrations` | Conexao Google com um clique |
| Gemini | Rotacionar chave exposta em teste e salvar `GEMINI_API_KEY` na Vercel | `/api/ai/classify` e `/api/reports/weekly-email` | IA segura sem chave no app |
| Email transacional | Configurar Resend ou provedor equivalente para anexar PDFs semanais | `/api/reports/weekly-email` | Envio de PDF por email |
| Notion | Criar OAuth/backend de conexao, compartilhar data sources e definir selecao de fontes | Preferencias do app e rotas OAuth futuras | Agenda Notion |
| Outlook | Registrar app Microsoft Entra e obter fluxo Microsoft Graph adequado | Preferencias do app e rotas OAuth futuras | Agenda Outlook |
| ClickUp | Criar OAuth/app oficial e fluxo de selecao de listas | Preferencias do app e rotas OAuth futuras | Tarefas ClickUp |
| Linear | Criar OAuth/app oficial e fluxo de selecao de times | Preferencias do app e rotas OAuth futuras | Issues Linear |
| Zapier | Criar app Zapier publico ou fluxo OAuth | Teste Zapier futuro no app | Automacoes |
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
- `RESEND_API_KEY`
- `REPORT_EMAIL_FROM`

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
- Equipes: R$ 45,00/usuario/mes ou R$ 450,00/usuario/ano.
- Negocios: R$ 65,00/usuario/mes ou R$ 650,00/usuario/ano.

Por padrao, o checkout aceita 1 assento em todos os planos. Se quiser impor um minimo comercial para Equipes ou Negocios, configure `STRIPE_MIN_SEATS_EQUIPES` e/ou `STRIPE_MIN_SEATS_NEGOCIOS` na Vercel.

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

## PDF semanal por email

O app envia um resumo semanal sanitizado para `POST https://luum-app.vercel.app/api/reports/weekly-email`. O backend valida Firebase Auth, exige plano Profissional ou maior em assinaturas pagas, usa Gemini para gerar a narrativa e anexa um PDF simples ao email verificado da conta. O destino não deve ser aceito do corpo da requisição.

Use `GET https://luum-app.vercel.app/api/reports/weekly-email` para diagnosticar se a rota esta publicada e se `GEMINI_API_KEY`, `RESEND_API_KEY` e `REPORT_EMAIL_FROM`/`RESEND_FROM_EMAIL` existem na Vercel. Essa resposta mostra apenas booleanos e modelo, nunca o valor das chaves.

Checklist manual:

1. Salvar `GEMINI_API_KEY` na Vercel.
2. Criar conta/projeto no Resend ou provedor equivalente.
3. Validar dominio/remetente de email.
4. Salvar `RESEND_API_KEY` e `REPORT_EMAIL_FROM` na Vercel.
5. Redeploy da Vercel.
6. No app, entrar com uma conta validada.
7. Abrir `Relatorios` e clicar em `Enviar PDF por email`.
8. Confirmar chegada do email e do anexo PDF no email verificado da conta.

## Notion

A UI do app ja foi reduzida para status simples e botao `Conectar` bloqueado, sem pedir token ou Data Source ID ao usuario final e sem abrir login externo que nao conclui conexao. Para a conexao funcionar de ponta a ponta como produto, ainda falta backend OAuth.

Para finalizar:

- Criar `/api/integrations/notion/connect`.
- Criar `/api/integrations/notion/callback`.
- Guardar refresh/access tokens server-side com criptografia por usuario.
- Criar etapa guiada de selecao de data sources.
- Sincronizar e exibir mensagens de 403/404 quando uma fonte nao foi compartilhada corretamente.

## Outlook

A UI do app mostra status "em implantacao". Para uso comercial, precisa OAuth Microsoft Entra.

Para finalizar:

- Criar OAuth backend Microsoft.
- Suportar contas pessoais e tenants corporativos.
- Tratar consentimento de administrador quando a organizacao exigir.
- Renovar tokens no backend.

## ClickUp e Linear

A UI do app mostra status "em implantacao". Para integrar de verdade sem expor chaves ao usuario, precisa OAuth ou app oficial.

Para finalizar:

- Criar OAuth ou app oficial de cada plataforma.
- Salvar tokens no backend.
- Adicionar tela de selecao de listas/times depois do OAuth.

## Zapier

A UI do app mostra status "em implantacao". Para evitar webhook manual, precisa app publico ou fluxo OAuth.

Para finalizar:

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
12. Testar em Mac limpo com instalador alpha `.pkg`; usar `.zip` apenas como fallback tecnico.
