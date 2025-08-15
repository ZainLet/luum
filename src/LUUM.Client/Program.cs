// File: src/LUUM.Client/Program.cs
using LUUM.Client.Components;
using LUUM.Client.Services;
using LUUM.API.Models;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Net.Http;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.AddScoped<SessionService>();
builder.Services.AddHttpClient<SessionService>(client => 
{
    client.BaseAddress = new Uri(builder.Configuration["API:BaseUrl"] ?? "http://localhost:5000"); 
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();
app.UseAntiforgery(); // A linha foi movida para este local

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();