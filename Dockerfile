# Estágio 1: Build - Usa o SDK do .NET 8 para compilar a aplicação
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copia o arquivo de projeto e restaura as dependências primeiro para aproveitar o cache do Docker
COPY ["src/LUUM.API/LUUM.API.csproj", "src/LUUM.API/"]
RUN dotnet restore "src/LUUM.API/LUUM.API.csproj"

# Copia todo o resto do código fonte
COPY . .
WORKDIR "/src/src/LUUM.API"

# Compila a aplicação em modo Release
RUN dotnet build "LUUM.API.csproj" -c Release -o /app/build

# Estágio 2: Publish - Publica a aplicação, otimizando para a execução
FROM build AS publish
RUN dotnet publish "LUUM.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Estágio 3: Final - Cria a imagem final com o runtime do ASP.NET, que é menor que o SDK
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Copia os arquivos publicados do estágio anterior
COPY --from=publish /app/publish .

# Expõe as portas que a aplicação vai usar dentro do container
EXPOSE 8080
EXPOSE 8081

# Define o comando de entrada para iniciar a aplicação quando o container for executado
ENTRYPOINT ["dotnet", "LUUM.API.dll"]