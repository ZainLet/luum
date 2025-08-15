// File: src/LUUM.API/Services/GeminiMockService.cs
using System.Threading.Tasks;

namespace LUUM.API.Services
{
    public class GeminiMockService
    {
        public Task<string> CategorizeTextAsync(string textToCategorize)
        {
            // Simula a lógica de categorização, sempre retornando "Work"
            return Task.FromResult("Work");
        }
    }
}   