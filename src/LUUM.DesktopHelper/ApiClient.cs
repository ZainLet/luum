using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

namespace LUUM.DesktopHelper
{
    public class ApiClient
    {
        private readonly HttpClient _httpClient;
        private readonly string _userId;

        public ApiClient(string apiBaseUrl, string userId)
        {
            // Ignora a verificação de certificado SSL para desenvolvimento local.
            // Não faça isso em produção!
            var handler = new HttpClientHandler
            {
                ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true
            };

            _httpClient = new HttpClient(handler) { BaseAddress = new System.Uri(apiBaseUrl) };
            _userId = userId;
        }

        public async Task<string> CategorizeActivityAsync(string windowTitle)
        {
            try
            {
                var response = await _httpClient.PostAsJsonAsync(
                    "/api/ai/categorize",
                    new { WindowTitle = windowTitle });

                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<CategorizationResult>();
                    return result?.Category ?? "N/A";
                }
                else
                {
                    var error = await response.Content.ReadAsStringAsync();
                    return $"Erro {response.StatusCode}: {error}";
                }
            }
            catch (System.Exception ex)
            {
                return $"Exceção: {ex.Message}";
            }
        }
    }

    public class CategorizationResult
    {
        public string? Category { get; set; }
    }
}