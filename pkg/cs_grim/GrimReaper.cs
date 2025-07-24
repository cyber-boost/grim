using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

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

            throw new DirectoryNotFoundException(
                "Could not find Grim Reaper root directory.\n\n" +
                "Please ensure Grim Reaper is properly installed using:\n" +
                "  • curl -fsSL https://get.grim.so | sudo bash\n" +
                "  • wget -qO- https://get.grim.so | sudo bash\n\n" +
                "Or set GRIM_ROOT environment variable:\n" +
                "  export GRIM_ROOT=/path/to/your/grim/installation"
            );
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
    }
}