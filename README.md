# LUUM - Seu Assistente de Produtividade

Este é o código-fonte do LUUM, um aplicativo de rastreamento de tempo e produtividade construído com .NET, Firebase e a API Gemini, com foco em integrações com o ecossistema Google.

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
* `/src/LUUM.DesktopHelper`: Um aplicativo de console para monitorar a atividade do usuário no Windows.