using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using LUUM.API.Models;
using LUUM.API.Models.Gemini;
using Microsoft.Extensions.Options;

namespace LUUM.API.Services
{
    public class GeminiService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<GeminiService> _logger;
        private readonly GeminiSettings _settings;

        public GeminiService(HttpClient httpClient, IOptions<GeminiSettings> geminiSettings, ILogger<GeminiService> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
            _settings = geminiSettings.Value;

            _httpClient.BaseAddress = new Uri(_settings.Endpoint);
            _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        }

        public async Task<string> CategorizeTextAsync(string textToCategorize)
        {
            if (string.IsNullOrWhiteSpace(_settings.ApiKey))
            {
                _logger.LogError("Gemini API key is not configured.");
                return "Error: Unconfigured";
            }
            
            try
            {
                var prompt = $"Categorize the following application window title into one of these categories: 'Work', 'Communication', 'Learning', 'Entertainment', 'Utilities', or 'Distraction'. Respond with only the category name, without any extra text or markdown. Title: \"{textToCategorize}\"";

                var requestPayload = new GeminiRequest(
                    new List<Content> { new Content(new List<Part> { new Part(prompt) }) }
                );

                var jsonPayload = JsonSerializer.Serialize(requestPayload);
                
                // ESTA É A LINHA QUE MUDOU: trocamos 'gemini-pro' por 'gemini-1.5-flash-latest'
                var request = new HttpRequestMessage(
                    HttpMethod.Post,
                    $"/v1beta/models/gemini-1.5-flash-latest:generateContent?key={_settings.ApiKey}")
                {
                    Content = new StringContent(jsonPayload, Encoding.UTF8, "application/json")
                };

                var response = await _httpClient.SendAsync(request);

                if (!response.IsSuccessStatusCode)
                {
                    var errorBody = await response.Content.ReadAsStringAsync();
                    _logger.LogError("Gemini API request failed with status {StatusCode}. Body: {ErrorBody}", response.StatusCode, errorBody);
                    return "Uncategorized-API-Error";
                }

                var responseBody = await response.Content.ReadAsStringAsync();
                var geminiResponse = JsonSerializer.Deserialize<GeminiResponse>(responseBody);

                var category = geminiResponse?.Candidates.FirstOrDefault()?.Content.Parts.FirstOrDefault()?.Text.Trim() ?? "Uncategorized";
                return category;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An exception occurred while calling Gemini API.");
                return "Uncategorized-Exception";
            }
        }
    }
}