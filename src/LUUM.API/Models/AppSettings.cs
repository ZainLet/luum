namespace LUUM.API.Models
{
    public class FirestoreSettings
    {
        public string ProjectId { get; set; } = string.Empty;
        public bool UseEmulator { get; set; } = false;
        public string? EmulatorHost { get; set; }
        public int? EmulatorPort { get; set; }
    }

    public class GeminiSettings
    {
        public string ApiKey { get; set; } = string.Empty;
        public string Endpoint { get; set; } = string.Empty;
    }

    public class OAuthSettings
    {
        public GoogleOAuthSettings Google { get; set; } = new();
    }

    public class GoogleOAuthSettings
    {
        public string ClientId { get; set; } = string.Empty;
        public string ClientSecret { get; set; } = string.Empty;
    }
}