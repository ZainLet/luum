# Luum Distribution and Platform Roadmap

Updated: 2026-05-12

## Objetivo

Este documento resume o que o `luum` precisa para sair do modo de desenvolvimento local e chegar a:

- distribuicao real no macOS
- preparacao arquitetural para Windows
- integracoes de agenda mais fortes
- base comercial para times e empresas
- suporte futuro para site, onboarding e vendas B2B

## Estado atual do app

Hoje o `luum` ja possui uma base funcional de:

- monitoramento de apps em primeiro plano
- leitura de URLs em navegadores suportados via Automacao do macOS
- categorizacao manual e por regras
- lembretes, metas e foco
- multi-conta Google Calendar
- multi-calendario Google
- integracao inicial com Notion via API oficial do Notion sobre data sources
- ranking de equipe em modo preview/demo
- backup/sync com backend sobre Firestore

## O que falta para distribuir o app no macOS

### 1. Fechar identidade de produto

- definir `bundle identifiers` finais para app, helper e servicos relacionados
- fechar nome, icone oficial, screenshots e copy publica
- padronizar versao semantica e build number
- revisar strings de permissao do macOS para Automacao, Notificacoes e Input Monitoring

### 2. Assinatura e notarizacao

- entrar no Apple Developer Program
- gerar certificado `Developer ID Application`
- configurar assinatura automatica ou scriptavel para o bundle
- usar `notarytool` para enviar o app para notarizacao
- aplicar `stapler` no artefato aprovado
- validar em uma maquina limpa com Gatekeeper

Referencias oficiais:

- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution?changes=_1)
- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/)

### 3. QA de distribuicao

- testar instalacao em Mac limpo sem Xcode
- testar primeiro launch
- testar fluxo de permissao de Automacao
- testar reconexao do Google Calendar
- testar sync do Notion com token novo
- testar restauracao de backup
- testar retomada do monitoramento depois de reiniciar o Mac

### 4. Atualizacao e suporte

- definir estrategia de update
- opcao 1: distribuicao direta com atualizador posterior
- opcao 2: Sparkle para atualizacao fora da App Store
- opcao 3: App Store mais tarde, se o escopo de automacao e monitoramento permitir
- adicionar coleta minima de crash logs e diagnostico

## O que falta para vender para empresas

### 1. Camada real de workspace

- criar conceito de `workspace`
- criar `members`, `teams`, `roles` e `admin controls`
- ligar ranking a dados reais de usuarios e nao apenas preview/demo
- permitir politicas por empresa: categorias, metas, lembretes, bloqueios e dashboards

### 2. Privacidade e compliance

Esse ponto e obrigatorio antes de vender monitoramento para equipes.

- criar politica de privacidade clara
- separar modo individual de modo corporativo
- explicar exatamente o que e coletado: app, dominio, titulo, duracao, calendario, notas
- permitir configuracao por empresa para nao salvar URL completa
- permitir ocultar titulos e dados sensiveis
- adicionar consentimento e onboarding explicito
- registrar quem pode ver ranking, comparativos e dados individuais
- revisar exigencias legais com advogado, principalmente para monitoramento de funcionarios em home office

### 3. Backend corporativo

- autenticar usuarios e workspaces
- sincronizar ranking, metas, preferencias e agenda configurada
- guardar somente o minimo necessario para comparativos
- separar dados pessoais de dados agregados
- adicionar auditoria de alteracoes administrativas

## Google Calendar: o que melhorar a seguir

### UX multi-conta

- tela melhor para adicionar varias contas uma atras da outra
- agrupar contas por workspace/pessoal
- filtros por conta
- filtro por calendario
- esconder calendarios ruidosos sem desconectar a conta
- mostrar origem do evento com cor e badge

### Confiabilidade

- refresh de token com mensagens melhores
- deteccao clara quando o token expirou ou perdeu escopo
- diagnostico visual para conta conectada mas sem calendarios selecionados

Referencia oficial:

- [OAuth 2.0 for Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)

## Notion Calendar: como tratar corretamente

Importante: o `luum` nao deve depender de uma “API separada do Notion Calendar”.

O caminho robusto e:

- usar a API oficial do Notion
- consultar `data sources` e paginas com propriedade de data
- transformar essas paginas em eventos internos do `luum`

Isso combina com a forma como o proprio ecossistema do Notion trata calendarios baseados em banco de dados.

Referencias oficiais:

- [Notion API intro](https://developers.notion.com/reference/intro)
- [Query a data source](https://developers.notion.com/reference/query-a-data-source)
- [Calendar view in Notion](https://www.notion.com/help/calendars)
- [Notion Calendar for teams](https://www.notion.com/en-gb/help/notion-calendar-for-teams)

### Proximas melhorias de Notion

- permitir varias fontes por workspace com nomes customizados
- escolher manualmente qual propriedade de data usar quando houver varias
- escolher propriedades adicionais para exibir no card
- mapear tipo de item: reuniao, deadline, projeto, entrega
- detectar 404/403 com mensagem clara quando a fonte nao foi compartilhada com a integracao

## Outlook e outros conectores

### Outlook Calendar

Prioridade alta para mercado corporativo.

- integrar Microsoft Graph
- suportar varias contas/tenants
- listar calendarios e permitir selecao por fonte
- tratar licencas e permissao organizacional

### ClickUp

- usar para tarefas, deadlines, projetos e contexto de trabalho
- cruzar tempo capturado com tasks e spaces

### Linear

- usar para issues, ciclos e roadmap
- associar blocos de tempo a issue ou projeto

### Zapier

- criar entrada de automacao
- enviar resumo diario/semanal
- receber gatilhos externos para criar lembretes ou atualizar contexto

## Firebase / Firestore

### Papel recomendado

Usar Firebase para:

- autenticacao de usuario
- sincronizacao entre dispositivos
- workspace e ranking
- configuracoes de equipe
- dashboards agregados
- relatorios e historico resumido

### O que nao colocar diretamente no Firestore

- tokens OAuth puros do Google sem estrategia segura
- segredos sensiveis sem criptografia/controle server-side
- URLs completas e titulos sensiveis sem governanca

### Arquitetura sugerida

- `Firebase Auth` para identidade
- `Firestore` para preferencias, ranking, resumos e metadados
- `Cloud Functions` ou API existente para tarefas sensiveis
- `Keychain` local para segredos do desktop quando possivel

## Ranking entre pessoas da mesma empresa

### Objetivo de produto

Transformar o ranking em um painel de:

- foco
- previsibilidade
- cobertura entre agenda e trabalho real
- excesso de trocas de contexto
- carga semanal

### Regras de produto importantes

- evitar ranking baseado apenas em horas brutas
- preferir score composto
- permitir ranking por time, nao so por empresa inteira
- permitir modo privado e modo compartilhado
- permitir benchmark anonimo

### Regras de UX

- sempre explicar como o score e calculado
- separar comparativo individual de comparativo de equipe
- sinalizar claramente quando os dados sao `preview` ou `dados reais`

## Windows: como comecar do jeito certo

### Recomendacao arquitetural

Nao tentar “portar SwiftUI” diretamente.

O caminho mais seguro e:

1. manter os conceitos do produto em um contrato compartilhado
2. extrair servicos e modelos independentes de plataforma
3. construir um cliente Windows nativo com acesso ao sistema operacional

### Stack recomendada

Para Windows, a recomendacao principal e:

- `WinUI 3` para a interface
- `.NET 8+` para a aplicacao desktop
- servico nativo de monitoramento de janela/URL conforme permissao do Windows

Motivo:

- o `luum` depende de monitoramento profundo do sistema
- precisa ler app ativo, navegacao, notificacoes e estados locais
- isso tende a ficar melhor em cliente nativo do que em stack multiplataforma superficial

### O que compartilhar entre macOS e Windows

- modelos de dominio
- contrato de sync
- score de ranking
- regras de categoria
- payloads de exportacao
- backend/API

### O que deve ser nativo por plataforma

- captura de app ativo
- leitura de navegador
- permissoes do sistema
- notificacoes
- empacotamento e distribuicao

### Distribuicao no Windows

Comecar com empacotamento MSIX e instalacao controlada.

Referencias oficiais:

- [What is MSIX?](https://learn.microsoft.com/en-us/windows/msix/overview?source=recommendations)
- [MSIX containerization overview](https://learn.microsoft.com/en-us/windows/msix/msix-containerization-overview)

## Site e distribuicao web

Isso pode vir depois, mas ja vale estruturar.

### Site publico

Criar um site inspirado em produtos como Rize, mas com identidade propria do `luum`.

Sugestao:

- `Next.js`
- landing page
- comparativo individual vs equipe
- mockups do dashboard
- pricing futuro
- docs de privacidade
- FAQ sobre permissao e monitoramento

### Objetivo do site

- explicar o produto em 30 segundos
- converter usuarios individuais
- abrir porta para demos B2B
- separar claramente o produto pessoal do produto para empresas

## Ordem recomendada de execucao

### Fase 1

- estabilizar integracoes Google + Notion
- fechar QA de monitoramento
- finalizar tela de ranking
- endurecer sync e estados de erro

### Fase 2

- fechar assinatura, notarizacao e release local do macOS
- adicionar crash reporting
- criar onboarding polido
- melhorar o design em direcao ao nivel de refinamento do Rize

### Fase 3

- workspace real com Firebase/Auth
- ranking corporativo real
- Outlook Calendar
- primeira landing page

### Fase 4

- arquitetura compartilhada para Windows
- cliente Windows nativo
- distribuicao por MSIX

## Checklist pratico para a proxima semana

- [ ] fechar o fluxo final de multi-conta Google
- [ ] validar Notion com 2 ou 3 data sources reais
- [ ] revisar copy e estados vazios da agenda integrada
- [ ] definir score final do ranking
- [ ] escolher stack do backend corporativo
- [ ] entrar com conta Apple Developer se ainda nao entrou
- [ ] preparar assinatura e notarizacao
- [ ] escrever politica de privacidade inicial
- [ ] decidir stack do site
- [ ] decidir stack do cliente Windows

## Observacao final

Para o modo empresa, o diferencial do `luum` nao vai ser apenas “monitorar funcionarios”.
O diferencial precisa ser:

- contexto
- foco
- previsibilidade
- saude operacional
- comparativos responsaveis

Se o produto parecer apenas vigilancia, a adocao e a retencao caem.
Se ele parecer uma ferramenta de clareza, coaching e operacao remota, o valor comercial sobe muito.
