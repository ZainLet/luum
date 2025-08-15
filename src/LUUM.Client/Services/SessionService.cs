// File: src/LUUM.Client/Services/SessionService.cs
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using LUUM.API.Models; // Reutilizamos os modelos do backend

namespace LUUM.Client.Services
{
    public class SessionService
    {
        private readonly HttpClient _httpClient;

        public SessionService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<List<Session>> GetSessionsAsync()
        {
            return await _httpClient.GetFromJsonAsync<List<Session>>("api/sessions") ?? new List<Session>();
        }
    }
}