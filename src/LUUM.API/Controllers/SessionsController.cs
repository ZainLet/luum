// File: src/LUUM.API/Controllers/SessionsController.cs
using LUUM.API.Models;
using LUUM.API.Services;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Mvc;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Extensions.Logging;

namespace LUUM.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SessionsController : ControllerBase
    {
        private readonly FirestoreService _firestoreService;
        private readonly ILogger<SessionsController> _logger;

        public SessionsController(FirestoreService firestoreService, ILogger<SessionsController> logger)
        {
            _firestoreService = firestoreService;
            _logger = logger;
        }

        [HttpPost("start")]
        [ProducesResponseType(typeof(StartSessionResponse), 201)]
        [ProducesResponseType(400)]
        public async Task<IActionResult> StartSession([FromBody] StartSessionRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.UserId))
            {
                return BadRequest("UserId is required.");
            }

            var newSession = new Session
            {
                UserId = request.UserId,
                StartTime = Timestamp.FromDateTime(DateTime.UtcNow),
                Category = "Initial"
            };

            var sessionId = await _firestoreService.CreateSessionAsync(newSession);

            _logger.LogInformation("Started session {SessionId} for user {UserId}", sessionId, request.UserId);

            return CreatedAtAction(nameof(GetSession), new { id = sessionId }, new StartSessionResponse(sessionId));
        }

        [HttpGet("{id}")]
        [ProducesResponseType(typeof(Session), 200)]
        [ProducesResponseType(404)]
        public async Task<IActionResult> GetSession(string id)
        {
            var session = await _firestoreService.GetSessionAsync(id);
            if (session == null)
            {
                return NotFound();
            }
            return Ok(session);
        }

        [HttpGet]
        public async Task<ActionResult<List<Session>>> GetSessionsAsync()
        {
            // TODO: Filtrar por usuário autenticado
            var userId = "user-test-id-123";
            _logger.LogInformation("Recebendo solicitação de sessões para o usuário {UserId}", userId);
            var sessions = await _firestoreService.GetSessionsForUserAsync(userId);
            return Ok(sessions);
        }
    }

    public record StartSessionRequest(string UserId);
    public record StartSessionResponse(string SessionId);
}