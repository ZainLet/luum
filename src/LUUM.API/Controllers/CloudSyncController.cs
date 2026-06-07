using LUUM.API.Models;
using LUUM.API.Services;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace LUUM.API.Controllers
{
    [ApiController]
    [Route("api/sync")]
    public class CloudSyncController : ControllerBase
    {
        private readonly FirestoreService _firestoreService;
        private readonly ILogger<CloudSyncController> _logger;

        public CloudSyncController(FirestoreService firestoreService, ILogger<CloudSyncController> logger)
        {
            _firestoreService = firestoreService;
            _logger = logger;
        }

        [HttpPut("{backupId}")]
        public async Task<IActionResult> SaveBackup(string backupId, [FromBody] CloudSyncSaveRequest request)
        {
            if (string.IsNullOrWhiteSpace(backupId))
            {
                return BadRequest(new CloudSyncErrorResponse { Message = "Informe um Backup ID valido." });
            }

            if (string.IsNullOrWhiteSpace(request.BackupSecret))
            {
                return BadRequest(new CloudSyncErrorResponse { Message = "Informe a chave de backup." });
            }

            if (request.Payload.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
            {
                return BadRequest(new CloudSyncErrorResponse { Message = "O payload do backup esta vazio." });
            }

            try
            {
                var payloadJson = request.Payload.GetRawText();
                var updatedAt = await _firestoreService.SaveCloudBackupAsync(backupId, request.BackupSecret, payloadJson);
                return Ok(new CloudSyncSnapshotResponse
                {
                    UpdatedAt = updatedAt
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to save cloud backup {BackupId}.", backupId);
                return StatusCode(500, new CloudSyncErrorResponse { Message = "Nao foi possivel salvar o backup agora." });
            }
        }

        [HttpPost("{backupId}")]
        public async Task<IActionResult> RestoreBackup(string backupId, [FromBody] CloudSyncRestoreRequest request)
        {
            if (string.IsNullOrWhiteSpace(backupId))
            {
                return BadRequest(new CloudSyncErrorResponse { Message = "Informe um Backup ID valido." });
            }

            if (string.IsNullOrWhiteSpace(request.BackupSecret))
            {
                return BadRequest(new CloudSyncErrorResponse { Message = "Informe a chave de backup." });
            }

            try
            {
                var record = await _firestoreService.GetCloudBackupAsync(backupId);
                if (record == null)
                {
                    return Ok(new CloudSyncSnapshotResponse());
                }

                if (!_firestoreService.BackupSecretMatches(request.BackupSecret, record.SecretHash))
                {
                    return StatusCode(403, new CloudSyncErrorResponse { Message = "A chave de backup nao confere com o backup salvo." });
                }

                using var document = JsonDocument.Parse(record.PayloadJson);
                return Ok(new CloudSyncSnapshotResponse
                {
                    Payload = document.RootElement.Clone(),
                    UpdatedAt = record.UpdatedAt.ToDateTimeOffset()
                });
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Failed to parse cloud backup payload for {BackupId}.", backupId);
                return StatusCode(500, new CloudSyncErrorResponse { Message = "O backup salvo esta corrompido." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to restore cloud backup {BackupId}.", backupId);
                return StatusCode(500, new CloudSyncErrorResponse { Message = "Nao foi possivel restaurar o backup agora." });
            }
        }
    }
}
