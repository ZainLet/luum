// File: src/LUUM.API/Controllers/AiController.cs
using LUUM.API.Models;
using LUUM.API.Services;
using Microsoft.AspNetCore.Mvc;
using Google.Cloud.Firestore;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace LUUM.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AiController : ControllerBase
    {
        private readonly GeminiMockService _geminiMockService;
        private readonly FirestoreService _firestoreService;
        private readonly ILogger<AiController> _logger;

        public AiController(GeminiMockService geminiMockService, FirestoreService firestoreService, ILogger<AiController> logger)
        {
            _geminiMockService = geminiMockService;
            _firestoreService = firestoreService;
            _logger = logger;
        }

        [HttpPost("categorize")]
        [ProducesResponseType(typeof(CategorizeResponse), 200)]
        [ProducesResponseType(400)]
        public async Task<IActionResult> CategorizeActivity([FromBody] CategorizeRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.WindowTitle))
            {
                return BadRequest("Window title cannot be empty.");
            }
            
            string userId = "user-test-id-123";

            _logger.LogInformation("Requesting categorization for title: {WindowTitle}", request.WindowTitle);
            
            string category = await _firestoreService.GetCategoryFromCache(request.WindowTitle);

            if (category == "Uncategorized-Cache-Miss")
            {
                category = await _geminiMockService.CategorizeTextAsync(request.WindowTitle);
                if (category != "Uncategorized-API-Error")
                {
                    await _firestoreService.SaveCategoryToCache(request.WindowTitle, category);
                }
            }

            var activityLog = new ActivityLog
            {
                UserId = userId,
                WindowTitle = request.WindowTitle,
                Category = category,
                Timestamp = Timestamp.FromDateTimeOffset(DateTimeOffset.UtcNow)
            };

            if (category != "Uncategorized-API-Error")
            {
                await _firestoreService.AddDocumentAsync("activityLogs", activityLog);
            }
            
            return Ok(new CategorizeResponse(category));
        }
    }

    public record CategorizeRequest(string WindowTitle);
    public record CategorizeResponse(string Category);
}