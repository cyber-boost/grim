<?php

/**
 * Grim Reaper PHP Package
 * Real core integration with sh_grim, py_grim, and go_grim
 * No mock files - calls actual core modules and binaries
 *
 * @copyright 2025 Bernie Gengel and CyberBoost LLC
 * @license MIT License - see LICENSE file for full terms
 * @package GrimReaper
 */

namespace GrimReaper;
class GrimReaper
{
    private string $grimRoot;
    private string $apiBase;

    public function __construct(?string $grimRoot = null)
    {
        $this->grimRoot = $grimRoot ?: $this->findGrimRoot();
        $this->apiBase = 'http://localhost:8000';
    }

    /**
     * Find Grim Reaper installation directory using portable discovery
     */
    private function findGrimRoot(): string
    {
        // Check environment variable first
        $envPath = $_ENV['GRIM_ROOT'] ?? $_SERVER['GRIM_ROOT'] ?? null;
        if ($envPath && $this->isGrimInstallation($envPath)) {
            return $envPath;
        }

        // Search up directory tree
        $currentDir = getcwd();
        for ($i = 0; $i < 10; $i++) {
            if ($this->isGrimInstallation($currentDir)) {
                return $currentDir;
            }
            
            $parentDir = dirname($currentDir);
            if ($parentDir === $currentDir) {
                break;
            }
            $currentDir = $parentDir;
        }

        // Try common installation paths
        $possiblePaths = [
            $_SERVER['HOME'] . '/reaper',
            $_SERVER['HOME'] . '/.reaper',
            '/root/reaper',
            '/root/.reaper',
            '/usr/local/reaper',
            '/usr/local/share/reaper',
            '/usr/share/reaper',
            '/opt/reaper',
            '/usr/local/lib/grim-reaper',
            '/usr/lib/grim-reaper',
        ];

        foreach ($possiblePaths as $path) {
            if ($this->isGrimInstallation($path)) {
                return $path;
            }
        }

        throw new \RuntimeException(
            "Could not find Grim Reaper root directory.\n" .
            "Please ensure Grim Reaper is properly installed using:\n" .
            "  • curl -fsSL https://get.grim.so | sudo bash\n" .
            "  • wget -qO- https://get.grim.so | sudo bash\n\n" .
            "Or set GRIM_ROOT environment variable:\n" .
            "  export GRIM_ROOT=/path/to/your/grim/installation"
        );
    }

    /**
     * Check if path contains a valid Grim installation
     */
    private function isGrimInstallation(string $path): bool
    {
        if (!is_dir($path)) {
            return false;
        }

        // Check for key Grim files
        $keyFiles = [
            'throne/grim_throne.sh',
            'tsk_flask/grim_admin_server.py',
            'sh_grim/backup.sh',
            'go_grim/build/grim-compression',
        ];

        foreach ($keyFiles as $keyFile) {
            if (file_exists($path . '/' . $keyFile)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Execute sh_grim module with proper error handling
     */
    private function executeShModule(string $module, array $args = []): string
    {
        $modulePath = $this->grimRoot . "/sh_grim/{$module}.sh";
        
        if (!file_exists($modulePath)) {
            throw new \RuntimeException("Module not found: {$module}");
        }

        if (!is_executable($modulePath)) {
            chmod($modulePath, 0755);
        }

        $command = escapeshellcmd($modulePath);
        if (!empty($args)) {
            $command .= ' ' . implode(' ', array_map('escapeshellarg', $args));
        }

        $output = [];
        $returnCode = 0;
        
        exec("cd {$this->grimRoot} && {$command} 2>&1", $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \RuntimeException("Module {$module} failed: " . implode("\n", $output));
        }

        return implode("\n", $output);
    }

    /**
     * Execute go_grim binary with proper error handling
     */
    private function executeGoBinary(string $binary, array $args = []): string
    {
        $binaryPath = $this->grimRoot . "/go_grim/build/{$binary}";
        
        if (!file_exists($binaryPath)) {
            throw new \RuntimeException("Go binary not found: {$binary}");
        }

        if (!is_executable($binaryPath)) {
            chmod($binaryPath, 0755);
        }

        $command = escapeshellcmd($binaryPath);
        if (!empty($args)) {
            $command .= ' ' . implode(' ', array_map('escapeshellarg', $args));
        }

        $output = [];
        $returnCode = 0;
        
        exec("cd {$this->grimRoot} && {$command} 2>&1", $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \RuntimeException("Go binary {$binary} failed: " . implode("\n", $output));
        }

        return implode("\n", $output);
    }

    /**
     * Call py_grim FastAPI service
     */
    private function callPyApi(string $endpoint, string $method = 'GET', ?array $data = null): array
    {
        $url = $this->apiBase . $endpoint;
        
        $context = stream_context_create([
            'http' => [
                'method' => $method,
                'header' => 'Content-Type: application/json',
                'timeout' => 30,
            ]
        ]);

        if ($method === 'POST' && $data) {
            $context['http']['content'] = json_encode($data);
        }

        $response = @file_get_contents($url, false, $context);
        
        if ($response === false) {
            throw new \RuntimeException("API call failed: {$endpoint}");
        }

        $json = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new \RuntimeException("Invalid JSON response from API");
        }

        return $json;
    }

    // ============================================================================
    // BACKUP OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Create backup using sh_grim/backup.sh
     */
    public function backup(string $source, ?string $name = null, string $compress = 'zstd', bool $incremental = false): string
    {
        $args = [$source];
        
        if ($name) {
            $args[] = '--name';
            $args[] = $name;
        }
        
        if ($compress) {
            $args[] = '--compress';
            $args[] = $compress;
        }
        
        if ($incremental) {
            $args[] = '--incremental';
        }

        return $this->executeShModule('backup', $args);
    }

    /**
     * Restore from backup using sh_grim/restore.sh
     */
    public function restore(string $backup, string $destination, bool $overwrite = false): string
    {
        $args = [$backup, $destination];
        
        if ($overwrite) {
            $args[] = '--overwrite';
        }

        return $this->executeShModule('restore', $args);
    }

    /**
     * List available backups
     */
    public function listBackups(): string
    {
        return $this->executeShModule('backup', ['--list']);
    }

    // ============================================================================
    // COMPRESSION OPERATIONS (via go_grim)
    // ============================================================================

    /**
     * Compress file using go_grim compression engine
     */
    public function compress(string $filePath, string $algorithm = 'zstd', int $level = 6, ?string $output = null): string
    {
        $args = [];
        
        if ($algorithm) {
            $args[] = '-a';
            $args[] = $algorithm;
        }
        
        if ($level) {
            $args[] = '-l';
            $args[] = (string)$level;
        }
        
        if ($output) {
            $args[] = '-o';
            $args[] = $output;
        }
        
        $args[] = $filePath;

        return $this->executeGoBinary('grim-compression', $args);
    }

    /**
     * Decompress file using go_grim
     */
    public function decompress(string $filePath, ?string $output = null): string
    {
        $args = ['-d'];
        
        if ($output) {
            $args[] = '-o';
            $args[] = $output;
        }
        
        $args[] = $filePath;

        return $this->executeGoBinary('grim-compression', $args);
    }

    /**
     * Get compression benchmarks
     */
    public function benchmarkCompression(string $filePath): string
    {
        return $this->executeGoBinary('grim-compression', ['-benchmark', $filePath]);
    }

    // ============================================================================
    // MONITORING OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Start monitoring using sh_grim/monitor.sh
     */
    public function startMonitoring(string $path, int $interval = 5, string $events = 'all'): string
    {
        $args = ['start', $path];
        
        if ($interval) {
            $args[] = '--interval';
            $args[] = (string)$interval;
        }
        
        if ($events) {
            $args[] = '--events';
            $args[] = $events;
        }

        return $this->executeShModule('monitor', $args);
    }

    /**
     * Stop monitoring
     */
    public function stopMonitoring(): string
    {
        return $this->executeShModule('monitor', ['stop']);
    }

    /**
     * Get monitoring status
     */
    public function getMonitoringStatus(): string
    {
        return $this->executeShModule('monitor', ['status']);
    }

    // ============================================================================
    // SCANNING OPERATIONS (via sh_grim)
    // ============================================================================

    /**
     * Scan directory using sh_grim/scan.sh
     */
    public function scan(string $path, bool $recursive = true, ?string $types = null, ?string $output = null): string
    {
        $args = [$path];
        
        if ($recursive) {
            $args[] = '--recursive';
        }
        
        if ($types) {
            $args[] = '--types';
            $args[] = $types;
        }
        
        if ($output) {
            $args[] = '--output';
            $args[] = $output;
        }

        return $this->executeShModule('scan', $args);
    }

    /**
     * Security scan using sh_grim/security.sh
     */
    public function securityScan(string $path, bool $deep = false, ?string $report = null): string
    {
        $args = [$path];
        
        if ($deep) {
            $args[] = '--deep';
        }
        
        if ($report) {
            $args[] = '--report';
            $args[] = $report;
        }

        return $this->executeShModule('security', $args);
    }

    // ============================================================================
    // SYSTEM OPERATIONS (via sh_grim) 
    // ============================================================================

    /**
     * System health check using sh_grim/health.sh
     */
    public function healthCheck(): string
    {
        return $this->executeShModule('health', ['check']);
    }

    /**
     * Get system status
     */
    public function getStatus(): string
    {
        return $this->executeShModule('health', ['status']);
    }

    /**
     * Optimize system using sh_grim/blacksmith.sh
     */
    public function optimize(string $target = 'all'): string
    {
        return $this->executeShModule('blacksmith', ['optimize', $target]);
    }

    /**
     * Self-healing using sh_grim/healer.sh
     */
    public function heal(): string
    {
        return $this->executeShModule('healer', ['heal']);
    }

    // ============================================================================
    // API INTEGRATION (via py_grim FastAPI)
    // ============================================================================

    /**
     * Get system status via API
     */
    public function getApiStatus(): array
    {
        return $this->callPyApi('/api/status');
    }

    /**
     * Get backup information via API
     */
    public function getBackupInfo(): array
    {
        return $this->callPyApi('/api/backups');
    }

    /**
     * Start backup via API
     */
    public function startApiBackup(string $source, array $options = []): array
    {
        $data = array_merge(['source' => $source], $options);
        return $this->callPyApi('/api/backup', 'POST', $data);
    }

    /**
     * Get monitoring data via API
     */
    public function getMonitoringData(): array
    {
        return $this->callPyApi('/api/monitoring');
    }

    // ============================================================================
    // UTILITY METHODS
    // ============================================================================

    /**
     * Execute raw grim command via throne script
     */
    public function executeCommand(string $command, array $args = []): string
    {
        $thronePath = $this->grimRoot . '/throne/grim_throne.sh';
        
        if (!file_exists($thronePath)) {
            throw new \RuntimeException("Throne script not found: {$thronePath}");
        }

        if (!is_executable($thronePath)) {
            chmod($thronePath, 0755);
        }

        $fullCommand = escapeshellcmd($thronePath) . ' ' . escapeshellarg($command);
        if (!empty($args)) {
            $fullCommand .= ' ' . implode(' ', array_map('escapeshellarg', $args));
        }

        $output = [];
        $returnCode = 0;
        
        exec("cd {$this->grimRoot} && {$fullCommand} 2>&1", $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \RuntimeException("Command {$command} failed: " . implode("\n", $output));
        }

        return implode("\n", $output);
    }

    /**
     * Get Grim version and build info
     */
    public function getVersion(): string
    {
        $manifestPath = $this->grimRoot . '/builds/latest/manifest.tsk';
        
        if (file_exists($manifestPath)) {
            return file_get_contents($manifestPath) ?: '';
        }

        return $this->executeCommand('version');
    }

    /**
     * Check if Grim services are running
     */
    public function checkServices(): array
    {
        $services = [
            'api' => false,
            'monitoring' => false,
            'admin' => false,
        ];

        // Check FastAPI service
        exec('pgrep -f grim_web', $output, $returnCode);
        $services['api'] = ($returnCode === 0);

        // Check monitoring service
        exec('pgrep -f monitor.sh', $output, $returnCode);
        $services['monitoring'] = ($returnCode === 0);

        // Check admin server
        exec('pgrep -f grim_admin_server.py', $output, $returnCode);
        $services['admin'] = ($returnCode === 0);

        return $services;
    }

    /**
     * Get Grim root directory
     */
    public function getGrimRoot(): string
    {
        return $this->grimRoot;
    }

    /**
     * Get API base URL
     */
    public function getApiBase(): string
    {
        return $this->apiBase;
    }

    /**
     * Set API base URL
     */
    public function setApiBase(string $apiBase): void
    {
        $this->apiBase = $apiBase;
    }
}

// Convenience functions for direct use
function grim_backup(string $source, array $options = []): string
{
    $grim = new GrimReaper();
    return $grim->backup($source, $options['name'] ?? null, $options['compress'] ?? 'zstd', $options['incremental'] ?? false);
}

function grim_restore(string $backup, string $destination, bool $overwrite = false): string
{
    $grim = new GrimReaper();
    return $grim->restore($backup, $destination, $overwrite);
}

function grim_compress(string $filePath, array $options = []): string
{
    $grim = new GrimReaper();
    return $grim->compress($filePath, $options['algorithm'] ?? 'zstd', $options['level'] ?? 6, $options['output'] ?? null);
}

function grim_health_check(): string
{
    $grim = new GrimReaper();
    return $grim->healthCheck();
}

function grim_scan(string $path, array $options = []): string
{
    $grim = new GrimReaper();
    return $grim->scan($path, $options['recursive'] ?? true, $options['types'] ?? null, $options['output'] ?? null);
}