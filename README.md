# LUUM - Seu Assistente de Produtividade

Este é o código-fonte do LUUM, um aplicativo de rastreamento de tempo e produtividade construído com .NET, Firebase e agora também com um cliente nativo macOS em SwiftUI e Liquid Glass.

## Como Executar

1.  **Pré-requisitos:**
    * [.NET 8 SDK](https://dotnet.microsoft.com/download)
    * [Visual Studio Code](https://code.visualstudio.com/)
    * [Firebase CLI](https://firebase.google.com/docs/cli)

2.  **Configuração:**
    * Clone este repositório.
    * Preencha os valores dos placeholders em `src/LUUM.API/appsettings.json`.
    * Defina a variável de ambiente `GOOGLE_APPLICATION_CREDENTIALS` com o caminho completo para o seu arquivo de chave da conta de serviço do Firebase.

3.  **Executando no VSCode:**
    * Abra a pasta do projeto no VSCode.
    * Instale a extensão C# Dev Kit da Microsoft.
    * Pressione `F5` para iniciar a depuração da API. A interface do Swagger será aberta no seu navegador.

## Estrutura do Projeto

* `/src/LUUM.API`: O backend da aplicação (ASP.NET Core Web API).
* `/src/LUUM.Client`: O painel web em Blazor para consultar sessões.
* `/src/LUUM.DesktopHelper`: Um helper de console para monitorar atividade no Windows.
* `/src/LUUM.Mac`: O novo app macOS do luum, feito em SwiftUI com visual Liquid Glass preto e roxo.

## LUUM para macOS

O app nativo macOS rastreia:

* aplicativo em foco
* domínio e URL da aba ativa em navegadores suportados
* agenda do Google conectada via OAuth desktop com retorno local em `127.0.0.1`
* categorias como Trabalho, Entretenimento, Comunicação, Aprendizado e Utilitários
* resumos diários por categoria, aplicativo, site e compromissos

### Navegadores suportados

Safari, Google Chrome, Arc, Brave, Microsoft Edge, Chromium, Opera e Vivaldi.

### Permissões

Para ler a URL da aba ativa, o macOS vai solicitar permissão de Automação quando o luum tentar conversar com o navegador pela primeira vez.

O app também já inclui o texto de uso para Automação no `Info.plist`, então o prompt do macOS fica pronto para aparecer normalmente.

Se você quiser que o luum detecte quando ficou longe do teclado ou mouse, pode liberar também Monitoramento de Entrada nas Preferências do Sistema. Essa permissão é opcional.

### Google Agenda

O luum agora já traz o fluxo completo de conexão com Google Agenda no app, mas o Google exige um `OAuth Client ID` seu para apps desktop. O setup é:

1. Ative a Google Calendar API no seu projeto do Google Cloud.
2. Crie um OAuth client do tipo `Desktop app`.
3. Cole o `Client ID` em `Preferências > Google Agenda`.
4. Clique em `Conectar Google Agenda`.

O app abre o navegador padrão, conclui o login via OAuth desktop e salva localmente a configuração para as próximas sincronizações.

### Como rodar o app macOS

```bash
./script/build_and_run.sh
```

O app macOS atual usa APIs modernas de Liquid Glass e foi preparado para macOS 26.

Por padrão o bundle é assinado localmente com assinatura ad hoc. Se você quiser testar uma assinatura de desenvolvedor depois, pode rodar:

```bash
APPLE_CODESIGN_IDENTITY="Developer ID Application: Seu Nome" ./script/build_and_run.sh
```
