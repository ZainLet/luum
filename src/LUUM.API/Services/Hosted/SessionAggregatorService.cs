// File: src/LUUM.API/Services/Hosted/SessionAggregatorService.cs
using LUUM.API.Models;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Google.Cloud.Firestore;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic; // Adicionado para ICollection

namespace LUUM.API.Services.Hosted
{
    public class SessionAggregatorService : IHostedService
    {
        private readonly FirestoreDb _db;
        private readonly ILogger<SessionAggregatorService> _logger;
        private Timer? _timer;

        public SessionAggregatorService(FirestoreDb db, ILogger<SessionAggregatorService> logger)
        {
            _db = db;
            _logger = logger;
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Session Aggregator Hosted Service está iniciando.");
            _timer = new Timer(DoWork, null, TimeSpan.Zero, TimeSpan.FromMinutes(1)); // Executa a cada 1 minuto
            return Task.CompletedTask;
        }

        private async void DoWork(object? state)
        {
            try
            {
                _logger.LogInformation("Executando trabalho de agregação de sessões.");
                
                // 1. Encontra logs não processados e sem erro
                var query = _db.Collection("activityLogs")
                               .WhereEqualTo("IsProcessed", false)
                               .WhereNotEqualTo("Category", "Uncategorized-API-Error");
                var snapshots = await query.GetSnapshotAsync();

                if (snapshots.Count == 0)
                {
                    _logger.LogInformation("Nenhum log de atividade novo para processar.");
                    return;
                }

                // 2. Agrupa os logs por usuário e categoria
                var logsBySession = snapshots.Documents
                    .Select(doc => doc.ConvertTo<ActivityLog>())
                    .Where(log => !string.IsNullOrWhiteSpace(log.UserId) && !string.IsNullOrWhiteSpace(log.Category))
                    .GroupBy(log => new { log.UserId, log.Category, log.WindowTitle });

                var writeBatch = _db.StartBatch();
                
                foreach (var group in logsBySession)
                {
                    var firstLog = group.OrderBy(log => log.Timestamp).First();
                    var lastLog = group.OrderBy(log => log.Timestamp).Last();
                    
                    // 3. Cria a sessão
                    var newSession = new Session
                    {
                        UserId = group.Key.UserId,
                        Category = group.Key.Category,
                        AssociatedProject = group.Key.WindowTitle, // Usamos o título da janela como projeto por enquanto
                        StartTime = firstLog.Timestamp,
                        EndTime = lastLog.Timestamp
                    };

                    var sessionRef = _db.Collection("sessions").Document();
                    writeBatch.Create(sessionRef, newSession);

                    _logger.LogInformation("Nova sessão criada para o usuário {UserId} na categoria {Category}.", group.Key.UserId, group.Key.Category);

                    // 4. Marca os logs como processados
                    foreach (var log in group)
                    {
                        var logRef = _db.Collection("activityLogs").Document(log.Id);
                        writeBatch.Update(logRef, "IsProcessed", true);
                    }
                }

                // 5. Envia o lote de escritas para o Firestore
                await writeBatch.CommitAsync();

                _logger.LogInformation($"Agregação concluída. Processados {snapshots.Count} logs.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ocorreu um erro no Session Aggregator Hosted Service.");
            }
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Session Aggregator Hosted Service está parando.");
            _timer?.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }
    }
}