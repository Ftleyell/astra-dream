using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Text;
using System.Threading;

namespace AstraLauncher
{
    class Program
    {
        private const string RepoOwner = "Ftleyell";
        private const string RepoName = "astra-dream";
        private const string Branch = "master";
        private const string ExeName = "AstraDream.exe";
        private const string PckName = "AstraDream.pck";
        private const string VersionFileName = "version.sha";
        private const string ReadmeFileName = "LEEME_PLAYTEST.txt";

        static void Main(string[] args)
        {
            try
            {
                Console.Title = "Astra Dream // Auto-Launcher";
            }
            catch { }

            // Habilitar TLS 1.2 para peticiones HTTPS seguras
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072; // SecurityProtocolType.Tls12

            PrintBanner();

            // Ubicación centralizada en AppData (evita desparramar archivos en el Escritorio o Descargas)
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string gameDir = Path.Combine(localAppData, "AstraDream").TrimEnd('\\', '/');

            if (!Directory.Exists(gameDir))
            {
                Directory.CreateDirectory(gameDir);
            }

            Console.ForegroundColor = ConsoleColor.DarkCyan;
            Console.WriteLine("  Ubicacion del juego: " + gameDir);
            Console.ResetColor();
            Console.WriteLine();

            string gameExePath = Path.Combine(gameDir, ExeName);
            string gamePckPath = Path.Combine(gameDir, PckName);
            string versionFile = Path.Combine(gameDir, VersionFileName);

            string embeddedSha = GetEmbeddedVersionSha();
            string localSha = "";
            if (File.Exists(versionFile))
            {
                try { localSha = File.ReadAllText(versionFile).Trim(); } catch { }
            }

            bool versionMismatch = !string.IsNullOrEmpty(embeddedSha) &&
                                   !string.IsNullOrEmpty(localSha) &&
                                   !embeddedSha.Equals(localSha, StringComparison.OrdinalIgnoreCase);

            // 1. Verificar si los archivos del juego estan presentes en AppData o si hay una version mas nueva en el launcher.
            bool needsExtraction = !File.Exists(gameExePath) || !File.Exists(gamePckPath) ||
                                  (new FileInfo(gameExePath)).Length < 1000000 ||
                                  (new FileInfo(gamePckPath)).Length < 1000000 ||
                                  versionMismatch;

            if (needsExtraction)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                if (versionMismatch)
                {
                    Console.WriteLine("  [*] Nueva version de juego detectada en el launcher (" + (embeddedSha.Length > 7 ? embeddedSha.Substring(0, 7) : embeddedSha) + "). Actualizando archivos...");
                }
                else
                {
                    Console.WriteLine("  [*] Desempaquetando archivos del juego en AppData por primera vez...");
                }
                Console.ResetColor();

                bool extracted = ExtractEmbeddedPayload(gameDir);
                if (!extracted)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("\n  [X] Error: No se pudieron extraer los archivos del juego en AppData.");
                    Console.ResetColor();
                    Console.WriteLine("  Presiona ENTER para salir...");
                    Console.ReadLine();
                    return;
                }
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  [+] Instalacion en AppData completada con exito!\n");
                Console.ResetColor();
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  [+] Archivos de juego en AppData listos (" + (localSha.Length > 7 ? localSha.Substring(0, 7) : "OK") + ").");
                Console.ResetColor();
            }

            // 2. Comprobar actualizaciones en GitHub (opcional y rapido, sin bloquear en caso de fallo u offline)
            CheckForOnlineUpdates(gameDir);

            // 3. Iniciar el juego desde AppData
            LaunchGame(gameDir, gameExePath, gamePckPath);
        }

        static void PrintBanner()
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine();
            Console.WriteLine("  ========================================================================");
            Console.WriteLine("                    *  ASTRA DREAM // AUTO-LAUNCHER  *                    ");
            Console.WriteLine("                 Edicion Standalone Portatil Autocontenida                ");
            Console.WriteLine("  ========================================================================");
            Console.WriteLine();
            Console.ResetColor();
        }

        static string GetEmbeddedVersionSha()
        {
            try
            {
                Assembly asm = Assembly.GetExecutingAssembly();
                using (Stream stream = asm.GetManifestResourceStream("payload.zip"))
                {
                    if (stream == null) return null;
                    using (ZipArchive archive = new ZipArchive(stream, ZipArchiveMode.Read))
                    {
                        ZipArchiveEntry entry = archive.GetEntry(VersionFileName);
                        if (entry != null)
                        {
                            using (Stream entryStream = entry.Open())
                            using (StreamReader reader = new StreamReader(entryStream))
                            {
                                return reader.ReadToEnd().Trim();
                            }
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        static bool ExtractEmbeddedPayload(string targetDir)
        {
            try
            {
                // Limpiar posibles archivos residuales de descargas previas de codigo fuente
                try
                {
                    string oldGodotFile = Path.Combine(targetDir, "project.godot");
                    if (File.Exists(oldGodotFile)) File.Delete(oldGodotFile);
                    string[] subDirsToClean = new string[] { "core", "scenes", "addons", "data", "tests", "narrative", "tools" };
                    foreach (string sub in subDirsToClean)
                    {
                        string p = Path.Combine(targetDir, sub);
                        if (Directory.Exists(p)) Directory.Delete(p, true);
                    }
                }
                catch { }

                Assembly asm = Assembly.GetExecutingAssembly();
                using (Stream stream = asm.GetManifestResourceStream("payload.zip"))
                {
                    if (stream == null)
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("  [!] Error critico: Payload no encontrado en los recursos del launcher.");
                        Console.ResetColor();
                        return false;
                    }

                    using (ZipArchive archive = new ZipArchive(stream, ZipArchiveMode.Read))
                    {
                        long totalBytes = 0;
                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            totalBytes += entry.Length;
                        }

                        long extractedBytes = 0;
                        byte[] buffer = new byte[64 * 1024];

                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            string destPath = Path.Combine(targetDir, entry.FullName);
                            string destDir = Path.GetDirectoryName(destPath);
                            if (!Directory.Exists(destDir))
                            {
                                Directory.CreateDirectory(destDir);
                            }

                            if (string.IsNullOrEmpty(entry.Name))
                            {
                                continue; // Carpeta
                            }

                            using (Stream entryStream = entry.Open())
                            using (FileStream fs = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None))
                            {
                                int bytesRead;
                                while ((bytesRead = entryStream.Read(buffer, 0, buffer.Length)) > 0)
                                {
                                    fs.Write(buffer, 0, bytesRead);
                                    extractedBytes += bytesRead;
                                    RenderProgressBar(extractedBytes, totalBytes, entry.Name);
                                }
                            }
                        }
                        Console.WriteLine();
                    }
                }
                return true;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("\n  [!] Excepcion al desempaquetar: " + ex.Message);
                Console.ResetColor();
                return false;
            }
        }

        static void RenderProgressBar(long current, long total, string currentFileName)
        {
            int barWidth = 30;
            double progress = total > 0 ? (double)current / total : 1.0;
            if (progress > 1.0) progress = 1.0;
            int filled = (int)(progress * barWidth);

            StringBuilder sb = new StringBuilder();
            sb.Append("  [");
            for (int i = 0; i < filled; i++) sb.Append("#");
            for (int i = filled; i < barWidth; i++) sb.Append("-");
            sb.Append(string.Format("] {0,3:P0} | {1}", progress, currentFileName));

            string display = sb.ToString();
            if (display.Length > 75)
            {
                display = display.Substring(0, 72) + "...";
            }
            Console.Write("\r" + display.PadRight(78));
        }

        static void CheckForOnlineUpdates(string gameDir)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("  [1/2] Verificando parches en GitHub (origin/" + Branch + ")...");
            Console.ResetColor();

            string versionFile = Path.Combine(gameDir, VersionFileName);
            string localSha = "";
            if (File.Exists(versionFile))
            {
                try { localSha = File.ReadAllText(versionFile).Trim(); } catch { }
            }

            string remoteSha = null;
            string commitMsg = "";
            string apiErrorReason = null;

            try
            {
                string apiUrl = "https://api.github.com/repos/" + RepoOwner + "/" + RepoName + "/commits/" + Branch;
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(apiUrl);
                request.UserAgent = "AstraDreamLauncher";
                request.Accept = "application/vnd.github.v3+json";
                request.Timeout = 3500; // Max 3.5s para no hacer esperar al jugador si esta offline

                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                {
                    string json = reader.ReadToEnd();
                    int shaIndex = json.IndexOf("\"sha\":");
                    if (shaIndex != -1)
                    {
                        int firstQuote = json.IndexOf("\"", shaIndex + 6);
                        if (firstQuote != -1)
                        {
                            int secondQuote = json.IndexOf("\"", firstQuote + 1);
                            if (secondQuote != -1)
                            {
                                remoteSha = json.Substring(firstQuote + 1, secondQuote - firstQuote - 1).Trim();
                            }
                        }
                    }

                    int msgIndex = json.IndexOf("\"message\":");
                    if (msgIndex != -1)
                    {
                        int firstQuote = json.IndexOf("\"", msgIndex + 10);
                        if (firstQuote != -1)
                        {
                            int secondQuote = json.IndexOf("\"", firstQuote + 1);
                            if (secondQuote != -1)
                            {
                                commitMsg = json.Substring(firstQuote + 1, secondQuote - firstQuote - 1).Replace("\\n", " ").Trim();
                                if (commitMsg.Length > 50) commitMsg = commitMsg.Substring(0, 47) + "...";
                            }
                        }
                    }
                }
            }
            catch (WebException wex)
            {
                HttpWebResponse httpRes = wex.Response as HttpWebResponse;
                if (httpRes != null)
                {
                    if (httpRes.StatusCode == HttpStatusCode.NotFound)
                    {
                        apiErrorReason = "Repositorio privado en GitHub (requiere acceso publico o token)";
                    }
                    else
                    {
                        apiErrorReason = "HTTP " + (int)httpRes.StatusCode + " " + httpRes.StatusDescription;
                    }
                }
                else
                {
                    apiErrorReason = "Sin conexion con GitHub (" + wex.Message + ")";
                }
            }
            catch (Exception ex)
            {
                apiErrorReason = ex.Message;
            }

            if (!string.IsNullOrEmpty(remoteSha))
            {
                if (!string.IsNullOrEmpty(localSha) && localSha.Equals(remoteSha, StringComparison.OrdinalIgnoreCase))
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("  [+] El juego esta al dia con la version mas reciente!");
                    Console.WriteLine("      Version instalada: " + (remoteSha.Length > 7 ? remoteSha.Substring(0, 7) : remoteSha));
                    Console.ResetColor();
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Magenta;
                    Console.WriteLine("  [*] NUEVA ACTUALIZACION DISPONIBLE EN GITHUB!");
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("      Ultimo commit: " + (remoteSha.Length > 7 ? remoteSha.Substring(0, 7) : remoteSha) + (string.IsNullOrEmpty(commitMsg) ? "" : " - " + commitMsg));
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("      Para descargar la version mas reciente del launcher, ejecuta en PowerShell:");
                    Console.ForegroundColor = ConsoleColor.White;
                    Console.WriteLine("      irm https://github.com/" + RepoOwner + "/" + RepoName + "/raw/" + Branch + "/AstraLauncher.exe -OutFile \"$env:USERPROFILE\\Desktop\\AstraLauncher.exe\"");
                    Console.ForegroundColor = ConsoleColor.DarkGray;
                    Console.WriteLine("      Iniciando con la version instalada localmente...\n");
                    Console.ResetColor();
                }
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkGray;
                if (!string.IsNullOrEmpty(apiErrorReason))
                {
                    Console.WriteLine("  [!] " + apiErrorReason + ". Usando version local instalada.");
                }
                else
                {
                    Console.WriteLine("  [!] Servidor no accesible o modo offline. Usando version local instalada.");
                }
                Console.ResetColor();
            }
        }

        static void LaunchGame(string gameDir, string gameExePath, string gamePckPath)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("  [2/2] Iniciando Astra Dream...");
            Console.ResetColor();

            if (!File.Exists(gameExePath))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("  [X] No se encontro " + ExeName + " en " + gameDir);
                Console.ResetColor();
                Console.WriteLine("  Presiona ENTER para salir...");
                Console.ReadLine();
                return;
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("  [+] Ejecutable listo: " + Path.GetFileName(gameExePath));
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("  >> Iniciando Astra Dream... Que disfrutes la partida!");
            Console.ResetColor();
            Console.WriteLine();

            string safeGameDir = gameDir.TrimEnd('\\', '/');
            string projectGodotPath = Path.Combine(safeGameDir, "project.godot");

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = gameExePath;
            psi.WorkingDirectory = safeGameDir;

            // Importante: En AppData el juego debe correr siempre mediante su paquete compilado (.pck)
            if (File.Exists(gamePckPath))
            {
                psi.Arguments = "--main-pack \"" + gamePckPath.TrimEnd('\\', '/') + "\"";
            }
            else if (File.Exists(projectGodotPath))
            {
                psi.Arguments = "--path \"" + safeGameDir + "\"";
            }

            psi.UseShellExecute = false;

            try
            {
                Process proc = Process.Start(psi);
                Thread.Sleep(2000);
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("  [!] Error al iniciar el proceso: " + ex.Message);
                Console.ResetColor();
                Console.WriteLine("  Presiona ENTER para salir...");
                Console.ReadLine();
            }
        }
    }
}
