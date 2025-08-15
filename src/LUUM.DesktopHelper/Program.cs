namespace LUUM.DesktopHelper
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("--- LUUM Desktop Helper ---");
            Console.WriteLine("Monitorando atividade de janela. Pressione Ctrl+C para sair.");
            Console.WriteLine("---------------------------\n");

            string lastTitle = string.Empty;

            // **LEMBRE-SE DE VERIFICAR ESTA PORTA!**
            var apiClient = new ApiClient("http://localhost:5000", "user-test-id-123");

            while (true)
            {
                var currentTitle = ActivityMonitor.GetActiveWindowTitle();

                if (currentTitle != lastTitle && !string.IsNullOrWhiteSpace(currentTitle))
                {
                    Console.ForegroundColor = ConsoleColor.White;
                    Console.WriteLine($"[ {DateTime.Now:HH:mm:ss} ] Nova janela: {currentTitle}");
                    lastTitle = currentTitle;

                    var category = await apiClient.CategorizeActivityAsync(currentTitle);

                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine($"                 -> Categoria da API: {category}\n");
                    Console.ResetColor();
                }
                await Task.Delay(TimeSpan.FromSeconds(10));
            }
        }
    }
}