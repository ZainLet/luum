// File: src/LUUM.API/Program.cs
using System.Net;
using LUUM.API.Models;
using LUUM.API.Services;
using LUUM.API.Services.Hosted;
using Polly;
using Polly.Extensions.Http;
using Google.Api.Gax;
using Google.Cloud.Firestore;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Builder;

var builder = WebApplication.CreateBuilder(args);

// Configuração de serviços para a API e o Hosted Service
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo { Title = "LUUM API", Version = "v1" });
});

builder.Services.Configure<FirestoreSettings>(builder.Configuration.GetSection("Firestore"));
builder.Services.Configure<GeminiSettings>(builder.Configuration.GetSection("Gemini"));

builder.Services.AddSingleton<FirestoreDb>(sp => 
{
    var settings = sp.GetRequiredService<IOptions<FirestoreSettings>>().Value;
    var dbBuilder = new FirestoreDbBuilder
    {
        ProjectId = settings.ProjectId,
        EmulatorDetection = settings.UseEmulator ? EmulatorDetection.EmulatorOnly : EmulatorDetection.None,
    };
    if (settings.UseEmulator)
    {
        Environment.SetEnvironmentVariable("FIRESTORE_EMULATOR_HOST", $"{settings.EmulatorHost}:{settings.EmulatorPort}");
    }
    return dbBuilder.Build();
});

builder.Services.AddScoped<FirestoreService>();
builder.Services.AddHostedService<SessionAggregatorService>();

// Substituímos a injeção do serviço real pelo mock
builder.Services.AddScoped<GeminiMockService>();

// Configuração do Kestrel para usar a porta 5000
builder.WebHost.UseUrls("http://localhost:5000");

// Construção do App
var app = builder.Build();

// Configuração do Pipeline de Middleware HTTP
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "LUUM API V1");
        c.RoutePrefix = string.Empty;
    });
}

app.UseHttpsRedirection();
app.UseRouting();
app.UseAuthorization();
app.MapControllers();

// Execução do App
app.Run();

// Define uma política de retentativa para requisições HTTP que falham
static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
{
    return HttpPolicyExtensions
        .HandleTransientHttpError()
        .OrResult(msg => msg.StatusCode == HttpStatusCode.TooManyRequests)
        .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)), onRetry: (outcome, timespan, retryAttempt, context) =>
        {
            Console.WriteLine($"[Polly] Retrying request... attempt {retryAttempt}. Waited {timespan.TotalSeconds}s. Reason: {outcome.Result?.StatusCode}");
        });
}