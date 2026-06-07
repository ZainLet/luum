using LUUM.API.Models;
using LUUM.API.Services;
using Microsoft.AspNetCore.Mvc;

namespace LUUM.API.Controllers
{
    [ApiController]
    [Route("api/workspaces")]
    public class WorkspaceController : ControllerBase
    {
        private readonly FirestoreService _firestoreService;
        private readonly ILogger<WorkspaceController> _logger;

        public WorkspaceController(FirestoreService firestoreService, ILogger<WorkspaceController> logger)
        {
            _firestoreService = firestoreService;
            _logger = logger;
        }

        [HttpPut("{workspaceId}/members/{memberId}")]
        public async Task<IActionResult> SaveMemberSnapshot(string workspaceId, string memberId, [FromBody] WorkspaceSyncSaveRequest request)
        {
            if (string.IsNullOrWhiteSpace(workspaceId) || string.IsNullOrWhiteSpace(memberId))
            {
                return BadRequest(new WorkspaceErrorResponse { Message = "Informe Workspace ID e Member ID validos." });
            }

            if (string.IsNullOrWhiteSpace(request.WorkspaceSecret))
            {
                return BadRequest(new WorkspaceErrorResponse { Message = "Informe a chave do workspace." });
            }

            try
            {
                var updatedAt = await _firestoreService.SaveWorkspaceMemberSnapshotAsync(
                    workspaceId,
                    memberId,
                    request.WorkspaceSecret,
                    request.Payload
                );

                return Ok(new WorkspaceSyncSaveResponse
                {
                    UpdatedAt = updatedAt
                });
            }
            catch (UnauthorizedAccessException ex)
            {
                _logger.LogWarning(ex, "Workspace secret mismatch for workspace {WorkspaceId}.", workspaceId);
                return StatusCode(403, new WorkspaceErrorResponse { Message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to save workspace member snapshot for workspace {WorkspaceId}.", workspaceId);
                return StatusCode(500, new WorkspaceErrorResponse { Message = "Nao foi possivel salvar o ranking corporativo agora." });
            }
        }

        [HttpPost("{workspaceId}/ranking")]
        public async Task<IActionResult> GetRanking(string workspaceId, [FromBody] WorkspaceRankingRequest request)
        {
            if (string.IsNullOrWhiteSpace(workspaceId))
            {
                return BadRequest(new WorkspaceErrorResponse { Message = "Informe um Workspace ID valido." });
            }

            if (string.IsNullOrWhiteSpace(request.WorkspaceSecret))
            {
                return BadRequest(new WorkspaceErrorResponse { Message = "Informe a chave do workspace." });
            }

            try
            {
                var ranking = await _firestoreService.GetWorkspaceRankingAsync(
                    workspaceId,
                    request.WorkspaceSecret,
                    request.RequestingMemberId
                );
                return Ok(ranking);
            }
            catch (UnauthorizedAccessException ex)
            {
                _logger.LogWarning(ex, "Workspace secret mismatch while fetching ranking for {WorkspaceId}.", workspaceId);
                return StatusCode(403, new WorkspaceErrorResponse { Message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load workspace ranking for {WorkspaceId}.", workspaceId);
                return StatusCode(500, new WorkspaceErrorResponse { Message = "Nao foi possivel carregar o ranking corporativo agora." });
            }
        }
    }
}
