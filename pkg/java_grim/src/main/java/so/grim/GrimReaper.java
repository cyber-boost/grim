package so.grim;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * Grim Reaper Java Package
 * Real core integration with sh_grim, py_grim, and go_grim
 * No mock files - calls actual core modules and binaries
 */
public class GrimReaper implements AutoCloseable {
    private final String grimRoot;
    private final String apiBase;
    private final OkHttpClient httpClient;
    private final ObjectMapper objectMapper;

    /**
     * Initializes a new instance of GrimReaper with portable path discovery
     * @param grimRoot Optional custom Grim root path
     * @throws IOException If Grim installation cannot be found
     */
    public GrimReaper(String grimRoot) throws IOException {
        this.grimRoot = grimRoot != null ? grimRoot : findGrimRoot();
        this.apiBase = "http://localhost:8000";
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .build();
        this.objectMapper = new ObjectMapper();
    }

    /**
     * Initializes a new instance of GrimReaper with automatic path discovery
     * @throws IOException If Grim installation cannot be found
     */
    public GrimReaper() throws IOException {
        this(null);
    }

    /**
     * Gets the Grim root directory
     * @return Grim root path
     */
    public String getGrimRoot() {
        return grimRoot;
    }

    /**
     * Gets the API base URL
     * @return API base URL
     */  
    public String getApiBase() {
        return apiBase;
    }

    /**
     * Finds Grim Reaper installation directory using portable discovery
     * @return Path to Grim installation
     * @throws IOException When Grim installation is not found
     */
    private static String findGrimRoot() throws IOException {
        // Check environment variable first
        String envPath = System.getenv("GRIM_ROOT");
        if (envPath != null && !envPath.isEmpty() && isGrimInstallation(envPath)) {
            return envPath;
        }

        // Search up directory tree
        Path currentDir = Paths.get(System.getProperty("user.dir"));
        for (int i = 0; i < 10; i++) {
            if (isGrimInstallation(currentDir.toString())) {
                return currentDir.toString();
            }

            Path parentDir = currentDir.getParent();
            if (parentDir == null || parentDir.equals(currentDir)) {
                break;
            }
            currentDir = parentDir;
        }

        // Try common installation paths
        String[] possiblePaths = {
            System.getProperty("user.home") + "/reaper",
            System.getProperty("user.home") + "/.reaper",
            "/root/reaper",
            "/root/.reaper",
            "/usr/local/reaper",
            "/usr/local/share/reaper",
            "/usr/share/reaper",
            "/opt/reaper",
            "/usr/local/lib/grim-reaper",
            "/usr/lib/grim-reaper"
        };

        for (String path : possiblePaths) {
            if (isGrimInstallation(path)) {
                return path;
            }
        }

        // Auto-download if not in CI/build environment
        if (System.getenv("CI") == null && System.getenv("MAVEN_OPTS") == null) {
            System.out.println("🔍 Grim Reaper not found locally");
            System.out.println("📥 Auto-downloading from get.grim.so...");
            
            try {
                String downloadPath = downloadLatest();
                if (downloadPath != null) {
                    return downloadPath;
                }
            } catch (Exception e) {
                System.err.println("❌ Auto-download failed: " + e.getMessage());
                System.out.println("💡 Please install manually: curl -fsSL https://get.grim.so | sudo bash");
            }
        }

        throw new IOException("Grim installation not found and auto-download failed");
    }

    /**
     * Downloads latest.tar.gz from get.grim.so and extracts with proper graveyard/reaper/ handling
     * @return Path to extracted Grim installation or null if failed
     * @throws IOException If download or extraction fails
     */
    private static String downloadLatest() throws IOException {
        System.out.println("📥 Downloading from https://get.grim.so/latest.tar.gz...");
        
        // Determine GRIM_ROOT with permission checks
        String grimRoot = determineGrimRoot();
        Path tempFile = Paths.get(System.getProperty("java.io.tmpdir"), "grim-latest.tar.gz");
        
        // Download latest.tar.gz
        OkHttpClient client = new OkHttpClient.Builder()
            .connectTimeout(Duration.ofSeconds(60))
            .readTimeout(Duration.ofSeconds(60))
            .build();
            
        Request request = new Request.Builder()
            .url("https://get.grim.so/latest.tar.gz")
            .addHeader("User-Agent", "Grim-Reaper-Java/1.0.35")
            .build();
            
        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Download failed with status: " + response.code());
            }
            
            byte[] data = response.body().bytes();
            Files.write(tempFile, data);
            
            System.out.println("✅ Download complete (" + formatBytes(data.length) + ")");
            
            // Create GRIM_ROOT directory
            Files.createDirectories(Paths.get(grimRoot));
            
            // Extract with --strip-components=2 to handle graveyard/reaper/ prefix
            System.out.println("📦 Extracting with graveyard/reaper/ structure handling...");
            
            String extractCommand = String.format(
                "cd \"%s\" && tar -xzf \"%s\" --strip-components=2 2>/dev/null || tar -xzf \"%s\" --strip-components=1 2>/dev/null || tar -xzf \"%s\"",
                grimRoot, tempFile.toString(), tempFile.toString(), tempFile.toString()
            );
            
            Process process = Runtime.getRuntime().exec(new String[]{"/bin/bash", "-c", extractCommand});
            int exitCode = process.waitFor();
            
            if (exitCode != 0) {
                BufferedReader errorReader = new BufferedReader(new InputStreamReader(process.getErrorStream()));
                StringBuilder errorOutput = new StringBuilder();
                String line;
                while ((line = errorReader.readLine()) != null) {
                    errorOutput.append(line).append("\n");
                }
                throw new IOException("Failed to extract archive: " + errorOutput.toString());
            }
            
            // Clean up temp file
            Files.deleteIfExists(tempFile);
            
            // Setup environment variables
            setupEnvironmentVariables(grimRoot);
            
            // Make scripts executable
            makeScriptsExecutable(grimRoot);
            
            System.out.println("✅ Extraction complete to: " + grimRoot);
            return grimRoot;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Download interrupted", e);
        }
    }

    /**
     * Determines optimal GRIM_ROOT with permission checking
     * @return Optimal GRIM_ROOT path
     * @throws IOException If no writable directory found
     */
    private static String determineGrimRoot() throws IOException {
        // Check GRIM_REAPER mode
        if ("TRUE".equals(System.getenv("GRIM_REAPER"))) {
            String existing = System.getenv("GRIM_ROOT");
            if (existing != null && Files.isDirectory(Paths.get(existing))) {
                return existing;
            }
        }
        
        // Try permission hierarchy
        String home = System.getProperty("user.home");
        String[] candidates = {
            home + "/.grim",
            "/root/.grim",
            System.getProperty("user.dir") + "/.grim"
        };
        
        for (String path : candidates) {
            Path dir = Paths.get(path).getParent();
            if (dir != null && Files.isWritable(dir)) {
                return path;
            }
        }
        
        throw new IOException("No writable directory found. Please chmod +x install.sh or run with proper permissions");
    }

    /**
     * Setup environment variables with persistence
     * @param grimRoot The GRIM_ROOT path
     */
    private static void setupEnvironmentVariables(String grimRoot) {
        System.out.println("🌍 Setting up environment variables...");
        
        // Set system properties (Java equivalent of environment variables)
        System.setProperty("GRIM_ROOT", grimRoot);
        System.setProperty("GRIM_LICENSE", "FREE");
        System.setProperty("GRIM_REAPER", "FALSE");
        
        // Read version from manifest.tsk if available
        Path manifestPath = Paths.get(grimRoot, "manifest.tsk");
        if (Files.exists(manifestPath)) {
            try {
                String content = Files.readString(manifestPath);
                String[] lines = content.split("\n");
                for (String line : lines) {
                    if (line.contains("version") && line.contains(":")) {
                        String[] parts = line.split(":");
                        if (parts.length >= 2) {
                            String version = parts[1].trim().replaceAll("[\"]", "");
                            System.setProperty("GRIM_VERSION", version);
                            System.out.println("📋 Set GRIM_VERSION=" + version + " from manifest");
                            break;
                        }
                    }
                }
            } catch (IOException e) {
                // Ignore read errors
            }
        }
        
        System.out.println("✅ Environment variables configured");
    }

    /**
     * Make all Grim scripts executable
     * @param grimRoot The GRIM_ROOT path
     */
    private static void makeScriptsExecutable(String grimRoot) {
        System.out.println("🔧 Making scripts executable...");
        
        String[] scriptPatterns = {
            "reaper.sh", "install.sh", "throne/*.sh", "sh_grim/*.sh",
            "scripts/*.sh", "bin/*", ".rip/*", "py_grim/**/*.py", "go_grim/build/*"
        };
        
        for (String pattern : scriptPatterns) {
            String command = String.format("find \"%s\" -name \"%s\" -type f -exec chmod +x {} \\;", 
                grimRoot, Paths.get(pattern).getFileName().toString());
            try {
                Runtime.getRuntime().exec(new String[]{"/bin/bash", "-c", command}).waitFor();
            } catch (IOException | InterruptedException e) {
                // Ignore permission errors
            }
        }
        
        System.out.println("✅ Scripts made executable");
    }

    /**
     * Format bytes for display
     * @param bytes Number of bytes
     * @return Formatted string
     */
    private static String formatBytes(long bytes) {
        String[] units = {"B", "KB", "MB", "GB"};
        double size = bytes;
        int unitIndex = 0;
        
        while (size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024;
            unitIndex++;
        }
        
        return String.format("%.2f %s", size, units[unitIndex]);
    }

    /**
     * Checks if path contains a valid Grim installation
     * @param path Path to check
     * @return True if valid Grim installation
     */
    private static boolean isGrimInstallation(String path) {
        File dir = new File(path);
        if (!dir.exists() || !dir.isDirectory()) {
            return false;
        }

        // Check for key Grim files
        String[] keyFiles = {
            "throne/grim_throne.sh",
            "tsk_flask/grim_admin_server.py",
            "sh_grim/backup.sh",
            "go_grim/build/grim-compression"
        };

        for (String keyFile : keyFiles) {
            if (new File(path, keyFile).exists()) {
                return true;
            }
        }

        return false;
    }

    /**
     * Executes sh_grim module with proper error handling
     * @param module Module name
     * @param args Module arguments
     * @return Module output
     * @throws IOException If module execution fails
     */
    private String executeShModule(String module, String... args) throws IOException {
        String modulePath = Paths.get(grimRoot, "sh_grim", module + ".sh").toString();
        
        File moduleFile = new File(modulePath);
        if (!moduleFile.exists()) {
            throw new IOException("Module not found: " + module);
        }

        List<String> command = new ArrayList<>();
        command.add(modulePath);
        command.addAll(Arrays.asList(args));

        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.directory(new File(grimRoot));
        processBuilder.redirectErrorStream(true);

        Process process = processBuilder.start();
        
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }

        try {
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new IOException("Module " + module + " failed with exit code " + exitCode + ": " + output);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Module execution interrupted", e);
        }

        return output.toString();
    }

    /**
     * Executes go_grim binary with proper error handling
     * @param binary Binary name
     * @param args Binary arguments
     * @return Binary output
     * @throws IOException If binary execution fails
     */
    private String executeGoBinary(String binary, String... args) throws IOException {
        String binaryPath = Paths.get(grimRoot, "go_grim", "build", binary).toString();
        
        File binaryFile = new File(binaryPath);
        if (!binaryFile.exists()) {
            throw new IOException("Go binary not found: " + binary);
        }

        List<String> command = new ArrayList<>();
        command.add(binaryPath);
        command.addAll(Arrays.asList(args));

        ProcessBuilder processBuilder = new ProcessBuilder(command);
        processBuilder.directory(new File(grimRoot));
        processBuilder.redirectErrorStream(true);

        Process process = processBuilder.start();
        
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }

        try {
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new IOException("Go binary " + binary + " failed with exit code " + exitCode + ": " + output);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Binary execution interrupted", e);
        }

        return output.toString();
    }

    /**
     * Calls py_grim FastAPI service
     * @param endpoint API endpoint
     * @return API response as Map
     * @throws IOException If API call fails
     */
    private Map<String, Object> callPyApi(String endpoint) throws IOException {
        String url = apiBase + endpoint;
        
        Request request = new Request.Builder()
                .url(url)
                .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("API call failed with status: " + response.code());
            }

            String responseBody = response.body().string();
            return objectMapper.readValue(responseBody, new TypeReference<Map<String, Object>>() {});
        }
    }

    // ============================================================================
    // BACKUP OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Creates backup using sh_grim/backup.sh
     * @param source Source path to backup
     * @param name Backup name (optional)
     * @param compress Compression algorithm (default: zstd)
     * @param incremental Create incremental backup
     * @return Backup operation result
     * @throws IOException If backup fails
     */
    public String backup(String source, String name, String compress, boolean incremental) throws IOException {
        List<String> args = new ArrayList<>();
        args.add(source);

        if (name != null && !name.isEmpty()) {
            args.add("--name");
            args.add(name);
        }

        if (compress != null && !compress.isEmpty()) {
            args.add("--compress");
            args.add(compress);
        }

        if (incremental) {
            args.add("--incremental");
        }

        return executeShModule("backup", args.toArray(new String[0]));
    }

    /**
     * Creates backup using sh_grim/backup.sh with default options
     * @param source Source path to backup
     * @return Backup operation result
     * @throws IOException If backup fails
     */
    public String backup(String source) throws IOException {
        return backup(source, null, "zstd", false);
    }

    /**
     * Restores from backup using sh_grim/restore.sh
     * @param backup Backup file to restore
     * @param destination Destination path
     * @param overwrite Overwrite existing files
     * @return Restore operation result
     * @throws IOException If restore fails
     */
    public String restore(String backup, String destination, boolean overwrite) throws IOException {
        List<String> args = new ArrayList<>();
        args.add(backup);
        args.add(destination);

        if (overwrite) {
            args.add("--overwrite");  
        }

        return executeShModule("restore", args.toArray(new String[0]));
    }

    /**
     * Restores from backup using sh_grim/restore.sh with default options
     * @param backup Backup file to restore
     * @param destination Destination path
     * @return Restore operation result
     * @throws IOException If restore fails
     */
    public String restore(String backup, String destination) throws IOException {
        return restore(backup, destination, false);
    }

    /**
     * Lists available backups
     * @return List of available backups
     * @throws IOException If listing fails
     */
    public String listBackups() throws IOException {
        return executeShModule("backup", "--list");
    }

    // ============================================================================
    // COMPRESSION OPERATIONS (via go_grim)
    // ============================================================================

    /**
     * Compresses file using go_grim compression engine
     * @param filePath File to compress
     * @param algorithm Compression algorithm (default: zstd)
     * @param level Compression level (default: 6)
     * @param output Output file path (optional)
     * @return Compression operation result
     * @throws IOException If compression fails
     */
    public String compress(String filePath, String algorithm, int level, String output) throws IOException {
        List<String> args = new ArrayList<>();

        if (algorithm != null && !algorithm.isEmpty()) {
            args.add("-a");
            args.add(algorithm);
        }

        if (level > 0) {
            args.add("-l");
            args.add(String.valueOf(level));
        }

        if (output != null && !output.isEmpty()) {
            args.add("-o");
            args.add(output);
        }

        args.add(filePath);

        return executeGoBinary("grim-compression", args.toArray(new String[0]));
    }

    /**
     * Compresses file using go_grim compression engine with default options
     * @param filePath File to compress
     * @return Compression operation result
     * @throws IOException If compression fails
     */
    public String compress(String filePath) throws IOException {
        return compress(filePath, "zstd", 6, null);
    }

    /**
     * Decompresses file using go_grim
     * @param filePath File to decompress
     * @param output Output file path (optional)
     * @return Decompression operation result
     * @throws IOException If decompression fails
     */
    public String decompress(String filePath, String output) throws IOException {
        List<String> args = new ArrayList<>();
        args.add("-d");

        if (output != null && !output.isEmpty()) {
            args.add("-o");
            args.add(output);
        }

        args.add(filePath);

        return executeGoBinary("grim-compression", args.toArray(new String[0]));
    }

    /**
     * Decompresses file using go_grim with default output
     * @param filePath File to decompress
     * @return Decompression operation result
     * @throws IOException If decompression fails
     */
    public String decompress(String filePath) throws IOException {
        return decompress(filePath, null);
    }

    /**
     * Gets compression benchmarks
     * @param filePath File to benchmark
     * @return Benchmark results
     * @throws IOException If benchmarking fails
     */
    public String benchmarkCompression(String filePath) throws IOException {
        return executeGoBinary("grim-compression", "-benchmark", filePath);
    }

    // ============================================================================
    // MONITORING OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Starts monitoring using sh_grim/monitor.sh
     * @param path Path to monitor
     * @param interval Monitoring interval in seconds (default: 5)
     * @param events Events to monitor (default: all)
     * @return Monitoring operation result
     * @throws IOException If monitoring start fails
     */
    public String startMonitoring(String path, int interval, String events) throws IOException {
        List<String> args = new ArrayList<>();
        args.add("start");
        args.add(path);

        if (interval > 0) {
            args.add("--interval");
            args.add(String.valueOf(interval));
        }

        if (events != null && !events.isEmpty()) {
            args.add("--events");
            args.add(events);
        }

        return executeShModule("monitor", args.toArray(new String[0]));
    }

    /**
     * Starts monitoring using sh_grim/monitor.sh with default options
     * @param path Path to monitor
     * @return Monitoring operation result
     * @throws IOException If monitoring start fails
     */
    public String startMonitoring(String path) throws IOException {
        return startMonitoring(path, 5, "all");
    }

    /**
     * Stops monitoring
     * @return Stop monitoring result
     * @throws IOException If monitoring stop fails
     */
    public String stopMonitoring() throws IOException {
        return executeShModule("monitor", "stop");
    }

    /**
     * Gets monitoring status
     * @return Monitoring status
     * @throws IOException If status retrieval fails
     */
    public String getMonitoringStatus() throws IOException {
        return executeShModule("monitor", "status");
    }

    // ============================================================================
    // SCANNING OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Scans directory using sh_grim/scan.sh
     * @param path Path to scan
     * @param recursive Recursive scan (default: true)
     * @param types File types to scan (optional)
     * @param output Output file path (optional)
     * @return Scan operation result
     * @throws IOException If scan fails
     */
    public String scan(String path, boolean recursive, String types, String output) throws IOException {
        List<String> args = new ArrayList<>();
        args.add(path);

        if (recursive) {
            args.add("--recursive");
        }

        if (types != null && !types.isEmpty()) {
            args.add("--types");
            args.add(types);
        }

        if (output != null && !output.isEmpty()) {
            args.add("--output");
            args.add(output);
        }

        return executeShModule("scan", args.toArray(new String[0]));
    }

    /**
     * Scans directory using sh_grim/scan.sh with default options
     * @param path Path to scan
     * @return Scan operation result
     * @throws IOException If scan fails
     */
    public String scan(String path) throws IOException {
        return scan(path, true, null, null);
    }

    /**
     * Performs security scan using sh_grim/security.sh
     * @param path Path to scan
     * @param deep Deep security scan
     * @param report Report output file (optional)
     * @return Security scan result
     * @throws IOException If security scan fails
     */
    public String securityScan(String path, boolean deep, String report) throws IOException {
        List<String> args = new ArrayList<>();
        args.add(path);

        if (deep) {
            args.add("--deep");
        }

        if (report != null && !report.isEmpty()) {
            args.add("--report");
            args.add(report);
        }

        return executeShModule("security", args.toArray(new String[0]));
    }

    /**
     * Performs security scan using sh_grim/security.sh with default options
     * @param path Path to scan
     * @return Security scan result
     * @throws IOException If security scan fails
     */
    public String securityScan(String path) throws IOException {
        return securityScan(path, false, null);
    }

    // ============================================================================
    // SYSTEM OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Performs system health check using sh_grim/health.sh
     * @return Health check result
     * @throws IOException If health check fails
     */
    public String healthCheck() throws IOException {
        return executeShModule("health", "check");
    }

    /**
     * Gets system status
     * @return System status
     * @throws IOException If status retrieval fails
     */
    public String getStatus() throws IOException {
        return executeShModule("health", "status");
    }

    /**
     * Optimizes system using sh_grim/blacksmith.sh
     * @param target Optimization target (default: all)
     * @return Optimization result
     * @throws IOException If optimization fails
     */
    public String optimize(String target) throws IOException {
        if (target == null || target.isEmpty()) {
            target = "all";
        }
        return executeShModule("blacksmith", "optimize", target);
    }

    /**
     * Optimizes system using sh_grim/blacksmith.sh with default target
     * @return Optimization result
     * @throws IOException If optimization fails
     */
    public String optimize() throws IOException {
        return optimize("all");
    }

    /**
     * Performs self-healing using sh_grim/healer.sh
     * @return Healing result
     * @throws IOException If healing fails
     */
    public String heal() throws IOException {
        return executeShModule("healer", "heal");
    }

    // ============================================================================
    // API INTEGRATION (via py_grim FastAPI)
    // ============================================================================

    /**
     * Gets system status via API
     * @return API status response
     * @throws IOException If API call fails
     */
    public Map<String, Object> getApiStatus() throws IOException {
        return callPyApi("/api/status");
    }

    /**
     * Gets backup information via API
     * @return Backup information
     * @throws IOException If API call fails
     */
    public Map<String, Object> getBackupInfo() throws IOException {
        return callPyApi("/api/backups");
    }

    /**
     * Gets monitoring data via API
     * @return Monitoring data
     * @throws IOException If API call fails
     */
    public Map<String, Object> getMonitoringData() throws IOException {
        return callPyApi("/api/monitoring");
    }

    // ============================================================================
    // UTILITY METHODS
    // ============================================================================

    /**
     * Executes raw grim command via throne script
     * @param command Command to execute
     * @param args Command arguments
     * @return Command output
     * @throws IOException If command execution fails
     */
    public String executeCommand(String command, String... args) throws IOException {
        String thronePath = Paths.get(grimRoot, "throne", "grim_throne.sh").toString();

        File throneFile = new File(thronePath);
        if (!throneFile.exists()) {
            throw new IOException("Throne script not found: " + thronePath);
        }

        List<String> fullCommand = new ArrayList<>();
        fullCommand.add(thronePath);
        fullCommand.add(command);
        fullCommand.addAll(Arrays.asList(args));

        ProcessBuilder processBuilder = new ProcessBuilder(fullCommand);
        processBuilder.directory(new File(grimRoot));
        processBuilder.redirectErrorStream(true);

        Process process = processBuilder.start();
        
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }

        try {
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new IOException("Command " + command + " failed with exit code " + exitCode + ": " + output);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Command execution interrupted", e);
        }

        return output.toString();
    }

    /**
     * Gets Grim version and build info
     * @return Version information
     * @throws IOException If version retrieval fails
     */
    public String getVersion() throws IOException {
        Path manifestPath = Paths.get(grimRoot, "builds", "latest", "manifest.tsk");

        if (Files.exists(manifestPath)) {
            return Files.readString(manifestPath);
        }

        return executeCommand("version");
    }

    /**
     * Checks if Grim services are running
     * @return Map of service statuses
     */
    public Map<String, Boolean> checkServices() {
        Map<String, Boolean> services = new HashMap<>();
        services.put("api", false);
        services.put("monitoring", false);
        services.put("admin", false);

        // Check FastAPI service
        try {
            ProcessBuilder pb = new ProcessBuilder("pgrep", "-f", "grim_web");
            Process process = pb.start();
            services.put("api", process.waitFor() == 0);
        } catch (Exception ignored) {
            // Ignore errors
        }

        // Check monitoring service
        try {
            ProcessBuilder pb = new ProcessBuilder("pgrep", "-f", "monitor.sh");
            Process process = pb.start();
            services.put("monitoring", process.waitFor() == 0);
        } catch (Exception ignored) {
            // Ignore errors
        }

        // Check admin server
        try {
            ProcessBuilder pb = new ProcessBuilder("pgrep", "-f", "grim_admin_server.py");
            Process process = pb.start();
            services.put("admin", process.waitFor() == 0);
        } catch (Exception ignored) {
            // Ignore errors
        }

        return services;
    }

    /**
     * Closes resources
     */
    public void close() {
        if (httpClient != null) {
            httpClient.dispatcher().executorService().shutdown();
            httpClient.connectionPool().evictAll();
        }
    }
}

/**
 * Static convenience methods for quick operations
 */
class GrimQuick {
    /**
     * Quick backup with default options
     * @param source Source path
     * @return Backup result
     * @throws IOException If backup fails
     */
    public static String backup(String source) throws IOException {
        try (GrimReaper grim = new GrimReaper()) {
            return grim.backup(source);
        }
    }

    /**
     * Quick restore with default options
     * @param backup Backup file
     * @param destination Destination path
     * @return Restore result
     * @throws IOException If restore fails
     */
    public static String restore(String backup, String destination) throws IOException {
        try (GrimReaper grim = new GrimReaper()) {
            return grim.restore(backup, destination);
        }
    }

    /**
     * Quick compress with default options
     * @param filePath File to compress
     * @return Compression result
     * @throws IOException If compression fails
     */
    public static String compress(String filePath) throws IOException {
        try (GrimReaper grim = new GrimReaper()) {
            return grim.compress(filePath);
        }
    }

    /**
     * Quick health check
     * @return Health check result
     * @throws IOException If health check fails
     */
    public static String healthCheck() throws IOException {
        try (GrimReaper grim = new GrimReaper()) {
            return grim.healthCheck();
        }
    }

    /**
     * Quick scan with default options
     * @param path Path to scan
     * @return Scan result
     * @throws IOException If scan fails
     */
    public static String scan(String path) throws IOException {
        try (GrimReaper grim = new GrimReaper()) {
            return grim.scan(path);
        }
    }
}