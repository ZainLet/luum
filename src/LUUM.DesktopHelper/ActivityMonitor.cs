using System.Runtime.InteropServices;
using System.Text;

namespace LUUM.DesktopHelper
{
    public static class ActivityMonitor
    {
        [DllImport("user32.dll")]
        private static extern System.IntPtr GetForegroundWindow();

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(System.IntPtr hWnd, StringBuilder text, int count);

        public static string GetActiveWindowTitle()
        {
            const int nChars = 256;
            var buff = new StringBuilder(nChars);
            var handle = GetForegroundWindow();

            if (GetWindowText(handle, buff, nChars) > 0)
            {
                return buff.ToString();
            }
            return string.Empty;
        }
    }
}