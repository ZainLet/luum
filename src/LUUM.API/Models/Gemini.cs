using System.Text.Json.Serialization;

namespace LUUM.API.Models.Gemini
{
    // --- Requisição (Já estava correta) ---
    public record GeminiRequest(
        [property: JsonPropertyName("contents")] List<Content> Contents
    );
    
    public record Content(
        [property: JsonPropertyName("parts")] List<Part> Parts
    );
    
    public record Part(
        [property: JsonPropertyName("text")] string Text
    );

    // --- Resposta (AQUI ESTÁ A CORREÇÃO FINAL) ---
    public record GeminiResponse(
        [property: JsonPropertyName("candidates")] List<Candidate> Candidates
    );

    public record Candidate
    {
        [JsonPropertyName("content")]
        public Content Content { get; set; } = new(new List<Part>());
    }
}