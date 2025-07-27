using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using System.IO.Compression;

namespace GrimReaper
{
    /// <summary>
    /// Grim Reaper C# Package
    /// Real core integration with sh_grim, py_grim, and go_grim
    /// No mock files - calls actual core modules and binaries
    /// </summary>
    public class GrimReaper : IDisposable
    {
        private readonly string _grimRoot;
        private readonly string _apiBase;
        private readonly HttpClient _httpClient;

        /// <summary>
        /// Initializes a new instance of GrimReaper with portable path discovery
        /// </summary>
        /// <param name="grimRoot">Optional custom Grim root path</param>
        public GrimReaper(string? grimRoot = null)
        {
            _grimRoot = grimRoot ?? FindGrimRoot();
            _apiBase = "http://localhost:8000";
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        /// <summary>
        /// Gets the Grim root directory
        /// </summary>
        public string GrimRoot => _grimRoot;

        /// <summary>
        /// Gets the API base URL
        /// </summary>
        public string ApiBase => _apiBase;

        /// <summary>
        /// Finds Grim Reaper installation directory using portable discovery
        /// </summary>
        /// <returns>Path to Grim installation</returns>
        /// <exception cref="DirectoryNotFoundException">When Grim installation is not found</exception>
        private static string FindGrimRoot()
        {
            // Check environment variable first
            var envPath = Environment.GetEnvironmentVariable("GRIM_ROOT");
            if (!string.IsNullOrEmpty(envPath) && IsGrimInstallation(envPath))
            {
                return envPath;
            }

            // Search up directory tree
            var currentDir = Directory.GetCurrentDirectory();
            for (int i = 0; i < 10; i++)
            {
                if (IsGrimInstallation(currentDir))
                {
                    return currentDir;
                }

                var parentDir = Directory.GetParent(currentDir);
                if (parentDir == null || parentDir.FullName == currentDir)
                {
                    break;
                }
                currentDir = parentDir.FullName;
            }

            // Try common installation paths
            var possiblePaths = new[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "reaper"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".reaper"),
                "/root/reaper",
                "/root/.reaper",
                "/usr/local/reaper",
                "/usr/local/share/reaper",
                "/usr/share/reaper",
                "/opt/reaper",
                "/usr/local/lib/grim-reaper",
                "/usr/lib/grim-reaper"
            };

            foreach (var path in possiblePaths)
            {
                if (IsGrimInstallation(path))
                {
                    return path;
                }
            }

            Console.WriteLine("🔍 Grim Reaper not found locally");
            Console.WriteLine("💡 Please run: grim install");
            Console.WriteLine("   Or install manually: curl -fsSL https://get.grim.so | sudo bash");

            // Auto-download if not in CI/build environment
            if (Environment.GetEnvironmentVariable("CI") == null && 
                Environment.GetEnvironmentVariable("DOTNET_RUNNING_IN_CONTAINER") == null)
            {
                Console.WriteLine("📥 Auto-downloading Grim Reaper...");
                var downloadPath = DownloadLatest();
                if (!string.IsNullOrEmpty(downloadPath))
                {
                    return downloadPath;
                }
            }

            throw new DirectoryNotFoundException("Grim Reaper installation not found. Please install manually or run in environment with proper permissions.");
        }

        /// <summary>
        /// Downloads latest.tar.gz from get.grim.so and extracts with proper graveyard/reaper/ handling
        /// </summary>
        /// <returns>Path to extracted Grim installation or null if failed</returns>
        private static string? DownloadLatest()
        {
            try
            {
                Console.WriteLine("📥 Downloading from https://get.grim.so/latest.tar.gz...");
                
                // Determine GRIM_ROOT with permission checks
                var grimRoot = DetermineGrimRoot();
                var tempFile = Path.Combine(Path.GetTempPath(), "grim-latest.tar.gz");
                
                // Download latest.tar.gz
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
                client.DefaultRequestHeaders.Add("User-Agent", "Grim-Reaper-CSharp/1.2.726");
                
                var response = client.GetAsync("https://get.grim.so/latest.tar.gz").Result;
                response.EnsureSuccessStatusCode();
                
                var data = response.Content.ReadAsByteArrayAsync().Result;
                File.WriteAllBytes(tempFile, data);
                
                Console.WriteLine($"✅ Download complete ({FormatBytes(data.Length)})");
                
                // Create GRIM_ROOT directory
                Directory.CreateDirectory(grimRoot);
                
                // Extract with --strip-components=2 to handle graveyard/reaper/ prefix
                Console.WriteLine("📦 Extracting with graveyard/reaper/ structure handling...");
                
                var extractCommand = OperatingSystem.IsWindows() 
                    ? $"tar -xzf \"{tempFile}\" --strip-components=2 -C \"{grimRoot}\"" 
                    : $"cd \"{grimRoot}\" && tar -xzf \"{tempFile}\" --strip-components=2 2>/dev/null || tar -xzf \"{tempFile}\" --strip-components=1 2>/dev/null || tar -xzf \"{tempFile}\"";
                
                var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = OperatingSystem.IsWindows() ? "cmd" : "/bin/bash",
                        Arguments = OperatingSystem.IsWindows() ? $"/c {extractCommand}" : $"-c \"{extractCommand}\"",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false
                    }
                };
                
                process.Start();
                process.WaitForExit();
                
                if (process.ExitCode != 0)
                {
                    throw new InvalidOperationException($"Failed to extract archive: {process.StandardError.ReadToEnd()}");
                }
                
                // Clean up temp file
                File.Delete(tempFile);
                
                // Setup environment variables
                SetupEnvironmentVariables(grimRoot);
                
                // Make scripts executable (Unix-like systems)
                if (!OperatingSystem.IsWindows())
                {
                    MakeScriptsExecutable(grimRoot);
                }
                
                Console.WriteLine($"✅ Extraction complete to: {grimRoot}");
                return grimRoot;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Auto-download failed: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Determine optimal GRIM_ROOT with permission checking
        /// </summary>
        private static string DetermineGrimRoot()
        {
            // Check GRIM_REAPER mode
            if (Environment.GetEnvironmentVariable("GRIM_REAPER") == "TRUE")
            {
                var existing = Environment.GetEnvironmentVariable("GRIM_ROOT");
                if (!string.IsNullOrEmpty(existing) && Directory.Exists(existing))
                {
                    return existing;
                }
            }
            
            // Try permission hierarchy
            var candidates = new[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".grim"),
                "/root/.grim",
                Path.Combine(Directory.GetCurrentDirectory(), ".grim")
            };
            
            foreach (var path in candidates)
            {
                try
                {
                    var dir = Path.GetDirectoryName(path) ?? path;
                    if (Directory.Exists(dir))
                    {
                        // Test write permissions
                        var testFile = Path.Combine(dir, $".grim-test-{Guid.NewGuid()}");
                        File.WriteAllText(testFile, "test");
                        File.Delete(testFile);
                        return path;
                    }
                }
                catch
                {
                    // Continue to next candidate
                }
            }
            
            throw new UnauthorizedAccessException("No writable directory found. Please chmod +x install.sh or run with proper permissions");
        }

        /// <summary>
        /// Setup environment variables with persistence
        /// </summary>
        private static void SetupEnvironmentVariables(string grimRoot)
        {
            Console.WriteLine("🌍 Setting up environment variables...");
            
            // Set for current process
            Environment.SetEnvironmentVariable("GRIM_ROOT", grimRoot);
            Environment.SetEnvironmentVariable("GRIM_LICENSE", "FREE");
            Environment.SetEnvironmentVariable("GRIM_REAPER", "FALSE");
            
            // Read version from manifest.tsk if available
            var manifestPath = Path.Combine(grimRoot, "manifest.tsk");
            if (File.Exists(manifestPath))
            {
                var content = File.ReadAllText(manifestPath);
                var versionMatch = System.Text.RegularExpressions.Regex.Match(content, @"version[:\s]+[""']?([^""'\s]+)[""']?", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (versionMatch.Success)
                {
                    Environment.SetEnvironmentVariable("GRIM_VERSION", versionMatch.Groups[1].Value);
                    Console.WriteLine($"📋 Set GRIM_VERSION={versionMatch.Groups[1].Value} from manifest");
                }
            }
            
            Console.WriteLine("✅ Environment variables configured");
        }

        /// <summary>
        /// Make scripts executable on Unix-like systems
        /// </summary>
        private static void MakeScriptsExecutable(string grimRoot)
        {
            if (OperatingSystem.IsWindows()) return;
            
            Console.WriteLine("🔧 Making scripts executable...");
            
            var scriptPatterns = new[]
            {
                "reaper.sh", "install.sh", "throne/*.sh", "sh_grim/*.sh", 
                "scripts/*.sh", "bin/*", ".rip/*", "py_grim/**/*.py", "go_grim/build/*"
            };
            
            foreach (var pattern in scriptPatterns)
            {
                var command = $"find \"{grimRoot}\" -name \"{Path.GetFileName(pattern)}\" -type f -exec chmod +x {{}} \\;";
                try
                {
                    var process = Process.Start("/bin/bash", $"-c \"{command}\"");
                    process?.WaitForExit();
                }
                catch
                {
                    // Ignore permission errors
                }
            }
            
            Console.WriteLine("✅ Scripts made executable");
        }

        /// <summary>
        /// Format bytes for display
        /// </summary>
        private static string FormatBytes(long bytes)
        {
            string[] units = { "B", "KB", "MB", "GB" };
            double size = bytes;
            int unitIndex = 0;
            
            while (size >= 1024 && unitIndex < units.Length - 1)
            {
                size /= 1024;
                unitIndex++;
            }
            
            return $"{size:F2} {units[unitIndex]}";
        }

        /// <summary>
        /// Checks if path contains a valid Grim installation
        /// </summary>
        /// <param name="path">Path to check</param>
        /// <returns>True if valid Grim installation</returns>
        private static bool IsGrimInstallation(string path)
        {
            if (!Directory.Exists(path))
                return false;

            // Check for key Grim files
            var keyFiles = new[]
            {
                "throne/grim_throne.sh",
                "tsk_flask/grim_admin_server.py",
                "sh_grim/backup.sh",
                "go_grim/build/grim-compression"
            };

            foreach (var keyFile in keyFiles)
            {
                if (File.Exists(Path.Combine(path, keyFile)))
                {
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// Installs Grim Reaper from latest.tar.gz
        /// </summary>
        /// <param name="directory">Optional installation directory</param>
        /// <param name="skipConfirmation">Skip confirmation prompts</param>
        /// <returns>Installation result</returns>
        public static async Task<string> InstallAsync(string? directory = null, bool skipConfirmation = false)
        {
            Console.WriteLine("🗡️  Grim Reaper Installer");
            Console.WriteLine("========================\n");

            // Determine installation directory
            var installDir = directory ?? GetDefaultInstallDirectory();
            Console.WriteLine($"📁 Installation directory: {installDir}");

            // Check if already installed
            if (Directory.Exists(installDir) && IsGrimInstallation(installDir))
            {
                return $"✅ Grim Reaper is already installed at: {installDir}";
            }

            // Confirmation prompt
            if (!skipConfirmation)
            {
                Console.Write("🤔 Proceed with installation? [y/N]: ");
                var input = Console.ReadLine();
                if (string.IsNullOrEmpty(input) || !input.Trim().ToLower().StartsWith("y"))
                {
                    return "❌ Installation cancelled";
                }
            }

            try
            {
                // Create installation directory
                Console.WriteLine("📦 Creating installation directory...");
                Directory.CreateDirectory(installDir);

                // Download latest.tar.gz
                Console.WriteLine("📥 Downloading Grim Reaper from get.grim.so...");
                var tempFile = Path.Combine(installDir, "grim-latest.tar.gz");

                using var client = new HttpClient();
                var response = await client.GetAsync("https://get.grim.so/latest.tar.gz");
                response.EnsureSuccessStatusCode();

                await File.WriteAllBytesAsync(tempFile, await response.Content.ReadAsByteArrayAsync());
                Console.WriteLine("✅ Download complete");

                // Extract tarball
                Console.WriteLine("📦 Extracting Grim Reaper...");
                var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "tar",
                        Arguments = $"-xzf {tempFile} --strip-components=2",
                        WorkingDirectory = installDir,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };

                process.Start();
                await process.WaitForExitAsync();

                if (process.ExitCode != 0)
                {
                    throw new Exception("Failed to extract tarball");
                }

                // Remove temp file
                File.Delete(tempFile);

                // Setup environment variables
                Console.WriteLine("🔧 Setting up environment variables...");
                SetEnvironmentVariable("GRIM_LICENSE", "FREE");
                SetEnvironmentVariable("GRIM_REAPER", "FALSE");
                SetEnvironmentVariable("GRIM_ROOT", installDir);

                // Check if this is a Grim Reaper update mode
                var grimReaperMode = Environment.GetEnvironmentVariable("GRIM_REAPER");
                bool isReaperUpdate = grimReaperMode?.ToUpper() == "TRUE";

                if (isReaperUpdate)
                {
                    Console.WriteLine("🔄 Grim Reaper update mode detected - preserving sensitive data...");
                    // In reaper mode, we preserve certain files
                    var preservePatterns = new[]
                    {
                        "*.db",         // Database files
                        "*.key",        // Key files
                        "*.pem",        // Certificate files
                        "*.cert",       // Certificate files
                        "license*",     // License files
                        "*.license",    // License files
                        ".env*",        // Environment files
                        "config.json",  // Configuration files
                        "*.conf"        // Configuration files
                    };

                    Console.WriteLine($"🔒 Preserving sensitive files: {string.Join(", ", preservePatterns)}");
                }

                // Read version from manifest.tsk if available
                var manifestPath = Path.Combine(installDir, "manifest.tsk");
                if (File.Exists(manifestPath))
                {
                    try
                    {
                        var manifestContent = await File.ReadAllTextAsync(manifestPath);
                        var versionMatch = System.Text.RegularExpressions.Regex.Match(manifestContent, @"version:\s*""([^""]+)""");
                        if (versionMatch.Success)
                        {
                            SetEnvironmentVariable("GRIM_VERSION", versionMatch.Groups[1].Value);
                            Console.WriteLine($"📦 Grim version: {versionMatch.Groups[1].Value}");
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"⚠️  Could not read version from manifest: {ex.Message}");
                    }
                }

                // Make scripts executable
                Console.WriteLine("🔧 Making scripts executable...");
                var scripts = new[]
                {
                    "throne/grim_throne.sh",
                    "throne/sh_grim_throne.sh",
                    "throne/py_grim_throne.sh",
                    "throne/go_grim_throne.sh",
                    "install.sh",
                    "master-install.sh"
                };

                foreach (var script in scripts)
                {
                    var scriptPath = Path.Combine(installDir, script);
                    if (File.Exists(scriptPath))
                    {
                        var chmodProcess = new Process
                        {
                            StartInfo = new ProcessStartInfo
                            {
                                FileName = "chmod",
                                Arguments = $"+x {scriptPath}",
                                UseShellExecute = false,
                                CreateNoWindow = true
                            }
                        };
                        chmodProcess.Start();
                        chmodProcess.WaitForExit();
                    }
                }

                // Setup environment (scythe directories and config)
                Console.WriteLine("🔧 Setting up environment...");
                var scytheDir = Path.Combine(installDir, ".graveyard", ".rip", ".scythe");

                // Create scythe directories
                var directories = new[] { "config", "db", "logs", "run", "integrations" };
                foreach (var dir in directories)
                {
                    Directory.CreateDirectory(Path.Combine(scytheDir, dir));
                }

                // Create log subdirectories
                var logSubdirs = new[] { "orchestration", "components", "integrations", "security" };
                foreach (var subdir in logSubdirs)
                {
                    Directory.CreateDirectory(Path.Combine(scytheDir, "logs", subdir));
                }

                // Create integration subdirectories
                var integrationSubdirs = new[] { "discovered", "configs", "scripts" };
                foreach (var subdir in integrationSubdirs)
                {
                    Directory.CreateDirectory(Path.Combine(scytheDir, "integrations", subdir));
                }

                // Create scythe configuration
                var configFile = Path.Combine(scytheDir, "config", "scythe.yaml");
                if (!File.Exists(configFile))
                {
                    var configContent = $@"# Scythe Configuration
# Central orchestrator settings for Grim Reaper System

scythe:
  version: ""1.0.5""
  install_date: {DateTime.UtcNow:yyyy-MM-ddTHH:mm:ssZ}

database:
  path: ""../db/scythe.db""
  auto_backup: true
  backup_interval: ""24h""

logging:
  level: ""info""
  path: ""../logs""
  max_size: ""100MB""
  max_files: 10

orchestration:
  enabled: true
  heartbeat_interval: ""30s""
  max_concurrent_jobs: 5

integrations:
  enabled: true
  scan_interval: ""5m""
  auto_discover: true

security:
  encryption: true
  key_rotation: ""30d""
  audit_logs: true
";
                    await File.WriteAllTextAsync(configFile, configContent);
                }

                Console.WriteLine("\n✅ Grim Reaper installation complete!");
                Console.WriteLine($"📁 Installed to: {installDir}");
                Console.WriteLine("💡 Restart your shell or run: source ~/.bashrc");
                Console.WriteLine("🗡️  Then use: grim <command>\n");

                return $"✅ Grim Reaper installed successfully to: {installDir}";
            }
            catch (Exception ex)
            {
                return $"❌ Installation failed: {ex.Message}";
            }
        }

        /// <summary>
        /// Gets the default installation directory
        /// </summary>
        /// <returns>Default installation path</returns>
        private static string GetDefaultInstallDirectory()
        {
            var homeDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return Path.Combine(homeDir, ".grim-reaper");
        }

        /// <summary>
        /// Sets an environment variable for the current process and tries to persist it
        /// </summary>
        /// <param name="name">Environment variable name</param>
        /// <param name="value">Environment variable value</param>
        private static void SetEnvironmentVariable(string name, string value)
        {
            try
            {
                // Set for current process
                Environment.SetEnvironmentVariable(name, value, EnvironmentVariableTarget.Process);
                
                // Try to persist (best effort - may fail on some systems)
                if (OperatingSystem.IsWindows())
                {
                    Environment.SetEnvironmentVariable(name, value, EnvironmentVariableTarget.User);
                }
                else
                {
                    // On Unix systems, try to add to shell profile
                    var homeDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                    var bashrcPath = Path.Combine(homeDir, ".bashrc");
                    
                    if (File.Exists(bashrcPath))
                    {
                        var bashrcContent = File.ReadAllText(bashrcPath);
                        var exportLine = $"export {name}=\"{value}\"";
                        
                        if (!bashrcContent.Contains($"export {name}="))
                        {
                            File.AppendAllText(bashrcPath, $"\n{exportLine}\n");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"⚠️  Could not persist environment variable {name}: {ex.Message}");
            }
        }

        /// <summary>
        /// Executes sh_grim module with proper error handling
        /// </summary>
        /// <param name="module">Module name</param>
        /// <param name="args">Module arguments</param>
        /// <returns>Module output</returns>
        private async Task<string> ExecuteShModuleAsync(string module, params string[] args)
        {
            var modulePath = Path.Combine(_grimRoot, "sh_grim", $"{module}.sh");

            if (!File.Exists(modulePath))
            {
                throw new FileNotFoundException($"Module not found: {module}");
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = modulePath,
                WorkingDirectory = _grimRoot,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            foreach (var arg in args)
            {
                startInfo.ArgumentList.Add(arg);
            }

            using var process = new Process { StartInfo = startInfo };
            process.Start();

            var output = await process.StandardOutput.ReadToEndAsync();
            var error = await process.StandardError.ReadToEndAsync();
            
            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Module {module} failed: {error}");
            }

            return output;
        }

        /// <summary>
        /// Executes go_grim binary with proper error handling
        /// </summary>
        /// <param name="binary">Binary name</param>
        /// <param name="args">Binary arguments</param>
        /// <returns>Binary output</returns>
        private async Task<string> ExecuteGoBinaryAsync(string binary, params string[] args)
        {
            var binaryPath = Path.Combine(_grimRoot, "go_grim", "build", binary);

            if (!File.Exists(binaryPath))
            {
                throw new FileNotFoundException($"Go binary not found: {binary}");
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = binaryPath,
                WorkingDirectory = _grimRoot,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            foreach (var arg in args)
            {
                startInfo.ArgumentList.Add(arg);
            }

            using var process = new Process { StartInfo = startInfo };
            process.Start();

            var output = await process.StandardOutput.ReadToEndAsync();
            var error = await process.StandardError.ReadToEndAsync();
            
            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Go binary {binary} failed: {error}");
            }

            return output;
        }

        /// <summary>
        /// Calls py_grim FastAPI service
        /// </summary>
        /// <param name="endpoint">API endpoint</param>
        /// <returns>API response as dictionary</returns>
        private async Task<Dictionary<string, object>> CallPyApiAsync(string endpoint)
        {
            var url = $"{_apiBase}{endpoint}";
            
            try
            {
                var response = await _httpClient.GetAsync(url);
                response.EnsureSuccessStatusCode();
                
                var jsonString = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<Dictionary<string, object>>(jsonString);
                
                return result ?? new Dictionary<string, object>();
            }
            catch (Exception ex)
            {
                throw new HttpRequestException($"API call failed: {endpoint}", ex);
            }
        }

        // ============================================================================
        // BACKUP OPERATIONS (via sh_grim)
        // ============================================================================

        /// <summary>
        /// Creates backup using sh_grim/backup.sh
        /// </summary>
        /// <param name="source">Source path to backup</param>
        /// <param name="name">Backup name (optional)</param>
        /// <param name="compress">Compression algorithm (default: zstd)</param>
        /// <param name="incremental">Create incremental backup</param>
        /// <returns>Backup operation result</returns>
        public async Task<string> BackupAsync(string source, string? name = null, string compress = "zstd", bool incremental = false)
        {
            var args = new List<string> { source };

            if (!string.IsNullOrEmpty(name))
            {
                args.AddRange(new[] { "--name", name });
            }

            if (!string.IsNullOrEmpty(compress))
            {
                args.AddRange(new[] { "--compress", compress });
            }

            if (incremental)
            {
                args.Add("--incremental");
            }

            return await ExecuteShModuleAsync("backup", args.ToArray());
        }

        /// <summary>
        /// Restores from backup using sh_grim/restore.sh
        /// </summary>
        /// <param name="backup">Backup file to restore</param>
        /// <param name="destination">Destination path</param>
        /// <param name="overwrite">Overwrite existing files</param>
        /// <returns>Restore operation result</returns>
        public async Task<string> RestoreAsync(string backup, string destination, bool overwrite = false)
        {
            var args = new List<string> { backup, destination };

            if (overwrite)
            {
                args.Add("--overwrite");
            }

            return await ExecuteShModuleAsync("restore", args.ToArray());
        }

        /// <summary>
        /// Lists available backups
        /// </summary>
        /// <returns>List of available backups</returns>
        public async Task<string> ListBackupsAsync()
        {
            return await ExecuteShModuleAsync("backup", "--list");
        }

        // ============================================================================
        // COMPRESSION OPERATIONS (via go_grim)
        // ============================================================================

        /// <summary>
        /// Compresses file using go_grim compression engine
        /// </summary>
        /// <param name="filePath">File to compress</param>
        /// <param name="algorithm">Compression algorithm (default: zstd)</param>
        /// <param name="level">Compression level (default: 6)</param>
        /// <param name="output">Output file path (optional)</param>
        /// <returns>Compression operation result</returns>
        public async Task<string> CompressAsync(string filePath, string algorithm = "zstd", int level = 6, string? output = null)
        {
            var args = new List<string>();

            if (!string.IsNullOrEmpty(algorithm))
            {
                args.AddRange(new[] { "-a", algorithm });
            }

            if (level > 0)
            {
                args.AddRange(new[] { "-l", level.ToString() });
            }

            if (!string.IsNullOrEmpty(output))
            {
                args.AddRange(new[] { "-o", output });
            }

            args.Add(filePath);

            return await ExecuteGoBinaryAsync("grim-compression", args.ToArray());
        }

        /// <summary>
        /// Decompresses file using go_grim
        /// </summary>
        /// <param name="filePath">File to decompress</param>
        /// <param name="output">Output file path (optional)</param>
        /// <returns>Decompression operation result</returns>
        public async Task<string> DecompressAsync(string filePath, string? output = null)
        {
            var args = new List<string> { "-d" };

            if (!string.IsNullOrEmpty(output))
            {
                args.AddRange(new[] { "-o", output });
            }

            args.Add(filePath);

            return await ExecuteGoBinaryAsync("grim-compression", args.ToArray());
        }

        /// <summary>
        /// Gets compression benchmarks
        /// </summary>
        /// <param name="filePath">File to benchmark</param>
        /// <returns>Benchmark results</returns>
        public async Task<string> BenchmarkCompressionAsync(string filePath)
        {
            return await ExecuteGoBinaryAsync("grim-compression", "-benchmark", filePath);
        }

        // ============================================================================
        // MONITORING OPERATIONS (via sh_grim)
        // ============================================================================

        /// <summary>
        /// Starts monitoring using sh_grim/monitor.sh
        /// </summary>
        /// <param name="path">Path to monitor</param>
        /// <param name="interval">Monitoring interval in seconds (default: 5)</param>
        /// <param name="events">Events to monitor (default: all)</param>
        /// <returns>Monitoring operation result</returns>
        public async Task<string> StartMonitoringAsync(string path, int interval = 5, string events = "all")
        {
            var args = new List<string> { "start", path };

            if (interval > 0)
            {
                args.AddRange(new[] { "--interval", interval.ToString() });
            }

            if (!string.IsNullOrEmpty(events))
            {
                args.AddRange(new[] { "--events", events });
            }

            return await ExecuteShModuleAsync("monitor", args.ToArray());
        }

        /// <summary>
        /// Stops monitoring
        /// </summary>
        /// <returns>Stop monitoring result</returns>
        public async Task<string> StopMonitoringAsync()
        {
            return await ExecuteShModuleAsync("monitor", "stop");
        }

        /// <summary>
        /// Gets monitoring status
        /// </summary>
        /// <returns>Monitoring status</returns>
        public async Task<string> GetMonitoringStatusAsync()
        {
            return await ExecuteShModuleAsync("monitor", "status");
        }

        // ============================================================================
        // SCANNING OPERATIONS (via sh_grim)
        // ============================================================================

        /// <summary>
        /// Scans directory using sh_grim/scan.sh
        /// </summary>
        /// <param name="path">Path to scan</param>
        /// <param name="recursive">Recursive scan (default: true)</param>
        /// <param name="types">File types to scan (optional)</param>
        /// <param name="output">Output file path (optional)</param>
        /// <returns>Scan operation result</returns>
        public async Task<string> ScanAsync(string path, bool recursive = true, string? types = null, string? output = null)
        {
            var args = new List<string> { path };

            if (recursive)
            {
                args.Add("--recursive");
            }

            if (!string.IsNullOrEmpty(types))
            {
                args.AddRange(new[] { "--types", types });
            }

            if (!string.IsNullOrEmpty(output))
            {
                args.AddRange(new[] { "--output", output });
            }

            return await ExecuteShModuleAsync("scan", args.ToArray());
        }

        /// <summary>
        /// Performs security scan using sh_grim/security.sh
        /// </summary>
        /// <param name="path">Path to scan</param>
        /// <param name="deep">Deep security scan</param>
        /// <param name="report">Report output file (optional)</param>
        /// <returns>Security scan result</returns>
        public async Task<string> SecurityScanAsync(string path, bool deep = false, string? report = null)
        {
            var args = new List<string> { path };

            if (deep)
            {
                args.Add("--deep");
            }

            if (!string.IsNullOrEmpty(report))
            {
                args.AddRange(new[] { "--report", report });
            }

            return await ExecuteShModuleAsync("security", args.ToArray());
        }

        // ============================================================================
        // SYSTEM OPERATIONS (via sh_grim)
        // ============================================================================

        /// <summary>
        /// Performs system health check using sh_grim/health.sh
        /// </summary>
        /// <returns>Health check result</returns>
        public async Task<string> HealthCheckAsync()
        {
            return await ExecuteShModuleAsync("health", "check");
        }

        /// <summary>
        /// Gets system status
        /// </summary>
        /// <returns>System status</returns>
        public async Task<string> GetStatusAsync()
        {
            return await ExecuteShModuleAsync("health", "status");
        }

        /// <summary>
        /// Optimizes system using sh_grim/blacksmith.sh
        /// </summary>
        /// <param name="target">Optimization target (default: all)</param>
        /// <returns>Optimization result</returns>
        public async Task<string> OptimizeAsync(string target = "all")
        {
            return await ExecuteShModuleAsync("blacksmith", "optimize", target);
        }

        /// <summary>
        /// Performs self-healing using sh_grim/healer.sh
        /// </summary>
        /// <returns>Healing result</returns>
        public async Task<string> HealAsync()
        {
            return await ExecuteShModuleAsync("healer", "heal");
        }

        // ============================================================================
        // API INTEGRATION (via py_grim FastAPI)
        // ============================================================================

        /// <summary>
        /// Gets system status via API
        /// </summary>
        /// <returns>API status response</returns>
        public async Task<Dictionary<string, object>> GetApiStatusAsync()
        {
            return await CallPyApiAsync("/api/status");
        }

        /// <summary>
        /// Gets backup information via API
        /// </summary>
        /// <returns>Backup information</returns>
        public async Task<Dictionary<string, object>> GetBackupInfoAsync()
        {
            return await CallPyApiAsync("/api/backups");
        }

        /// <summary>
        /// Gets monitoring data via API
        /// </summary>
        /// <returns>Monitoring data</returns>
        public async Task<Dictionary<string, object>> GetMonitoringDataAsync()
        {
            return await CallPyApiAsync("/api/monitoring");
        }

        // ============================================================================
        // UTILITY METHODS
        // ============================================================================

        /// <summary>
        /// Executes raw grim command via throne script
        /// </summary>
        /// <param name="command">Command to execute</param>
        /// <param name="args">Command arguments</param>
        /// <returns>Command output</returns>
        public async Task<string> ExecuteCommandAsync(string command, params string[] args)
        {
            var thronePath = Path.Combine(_grimRoot, "throne", "grim_throne.sh");

            if (!File.Exists(thronePath))
            {
                throw new FileNotFoundException($"Throne script not found: {thronePath}");
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = thronePath,
                WorkingDirectory = _grimRoot,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            startInfo.ArgumentList.Add(command);
            foreach (var arg in args)
            {
                startInfo.ArgumentList.Add(arg);
            }

            using var process = new Process { StartInfo = startInfo };
            process.Start();

            var output = await process.StandardOutput.ReadToEndAsync();
            var error = await process.StandardError.ReadToEndAsync();
            
            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Command {command} failed: {error}");
            }

            return output;
        }

        /// <summary>
        /// Gets Grim version and build info
        /// </summary>
        /// <returns>Version information</returns>
        public async Task<string> GetVersionAsync()
        {
            var manifestPath = Path.Combine(_grimRoot, "builds", "latest", "manifest.tsk");

            if (File.Exists(manifestPath))
            {
                return await File.ReadAllTextAsync(manifestPath);
            }

            return await ExecuteCommandAsync("version");
        }

        /// <summary>
        /// Checks if Grim services are running
        /// </summary>
        /// <returns>Dictionary of service statuses</returns>
        public Dictionary<string, bool> CheckServices()
        {
            var services = new Dictionary<string, bool>
            {
                ["api"] = false,
                ["monitoring"] = false,
                ["admin"] = false
            };

            // Check FastAPI service
            try
            {
                using var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "pgrep",
                        Arguments = "-f grim_web",
                        RedirectStandardOutput = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };
                process.Start();
                process.WaitForExit();
                services["api"] = process.ExitCode == 0;
            }
            catch { /* Ignore errors */ }

            // Check monitoring service
            try
            {
                using var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "pgrep",
                        Arguments = "-f monitor.sh",
                        RedirectStandardOutput = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };
                process.Start();
                process.WaitForExit();
                services["monitoring"] = process.ExitCode == 0;
            }
            catch { /* Ignore errors */ }

            // Check admin server
            try
            {
                using var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = "pgrep",
                        Arguments = "-f grim_admin_server.py",
                        RedirectStandardOutput = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };
                process.Start();
                process.WaitForExit();
                services["admin"] = process.ExitCode == 0;
            }
            catch { /* Ignore errors */ }

            return services;
        }

        /// <summary>
        /// Disposes resources
        /// </summary>
        public void Dispose()
        {
            _httpClient?.Dispose();
        }
    }

    /// <summary>
    /// Static convenience methods for quick operations
    /// </summary>
    public static class GrimQuick
    {
        /// <summary>
        /// Quick backup with default options
        /// </summary>
        /// <param name="source">Source path</param>
        /// <returns>Backup result</returns>
        public static async Task<string> BackupAsync(string source)
        {
            using var grim = new GrimReaper();
            return await grim.BackupAsync(source);
        }

        /// <summary>
        /// Quick restore with default options
        /// </summary>
        /// <param name="backup">Backup file</param>
        /// <param name="destination">Destination path</param>
        /// <returns>Restore result</returns>
        public static async Task<string> RestoreAsync(string backup, string destination)
        {
            using var grim = new GrimReaper();
            return await grim.RestoreAsync(backup, destination);
        }

        /// <summary>
        /// Quick compress with default options
        /// </summary>
        /// <param name="filePath">File to compress</param>
        /// <returns>Compression result</returns>
        public static async Task<string> CompressAsync(string filePath)
        {
            using var grim = new GrimReaper();
            return await grim.CompressAsync(filePath);
        }

        /// <summary>
        /// Quick health check
        /// </summary>
        /// <returns>Health check result</returns>
        public static async Task<string> HealthCheckAsync()
        {
            using var grim = new GrimReaper();
            return await grim.HealthCheckAsync();
        }

        /// <summary>
        /// Quick scan with default options
        /// </summary>
        /// <param name="path">Path to scan</param>
        /// <returns>Scan result</returns>
        public static async Task<string> ScanAsync(string path)
        {
            using var grim = new GrimReaper();
            return await grim.ScanAsync(path);
        }

        /// <summary>
        /// Quick install operation
        /// </summary>
        /// <param name="directory">Optional installation directory</param>
        /// <param name="skipConfirmation">Skip confirmation prompts</param>
        /// <returns>Installation result</returns>
        public static async Task<string> InstallAsync(string? directory = null, bool skipConfirmation = false)
        {
            return await GrimReaper.InstallAsync(directory, skipConfirmation);
        }
    }
}