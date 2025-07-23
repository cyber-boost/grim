<?php

namespace GrimReaper;

/**
 * Grim Reaper PHP CLI Application
 * 
 * Main CLI class that handles command routing and delegates to the throne script.
 * This ensures the PHP package can orchestrate all Grim Reaper operations.
 */
class GrimCLI
{
    private const VERSION = '1.0.0';
    private string $grimRoot;
    private string $throneScript;

    public function __construct()
    {
        $this->grimRoot = $this->findGrimRoot();
        // Look for throne script in parent directory (main project root)
        $this->throneScript = dirname($this->grimRoot) . '/throne/php_grim_throne.sh';
        
        if (!file_exists($this->throneScript)) {
            throw new \RuntimeException("Throne script not found: {$this->throneScript}");
        }
    }

    /**
     * Run the CLI application
     */
    public function run(array $argv): int
    {
        // Remove script name from arguments
        array_shift($argv);
        
        // Handle special commands that don't need the throne script
        if (empty($argv)) {
            return $this->showHelp();
        }
        
        $command = $argv[0];
        
        // Handle PHP-specific commands
        switch ($command) {
            case '--version':
            case '-v':
                return $this->showVersion();
                
            case '--help':
            case '-h':
            case 'help':
                return $this->showHelp();
                
            case 'check-deps':
                return $this->checkDependencies();
                
            case 'install-deps':
                return $this->installDependencies();
                
            case 'setup':
                return $this->setup();
                
            case 'doctor':
                return $this->doctor();
        }
        
        // Delegate all other commands to the throne script
        return $this->delegateToThrone($argv);
    }

    /**
     * Show version information
     */
    private function showVersion(): int
    {
        echo "🗡️  Grim Reaper PHP Package v" . self::VERSION . "\n";
        echo "PHP Version: " . PHP_VERSION . "\n";
        echo "Grim Root: {$this->grimRoot}\n";
        echo "Throne Script: {$this->throneScript}\n";
        return 0;
    }

    /**
     * Show help information
     */
    private function showHelp(): int
    {
        echo "🗡️  Grim Reaper PHP Package\n";
        echo "============================\n\n";
        echo "Usage: grim <command> [options]\n\n";
        echo "PHP Package Commands:\n";
        echo "  --version, -v        Show version information\n";
        echo "  --help, -h           Show this help message\n";
        echo "  check-deps           Check system dependencies\n";
        echo "  install-deps         Install system dependencies\n";
        echo "  setup                Run initial setup\n";
        echo "  doctor               Diagnose installation issues\n\n";
        echo "Grim Reaper Commands:\n";
        echo "  health               Check all systems health\n";
        echo "  status               Overall system status\n";
        echo "  backup <path>        Orchestrated backup\n";
        echo "  restore <backup>     Coordinated restore\n";
        echo "  scan <path>          Unified file scanning\n";
        echo "  monitor <path>       Start monitoring\n";
        echo "  web                  Start web interface\n\n";
        echo "Command Categories:\n";
        echo "  backup-*             Backup operations\n";
        echo "  monitor-*            Monitoring commands\n";
        echo "  security-*           Security operations\n";
        echo "  ai-*                 AI/ML commands\n";
        echo "  optimize-*           System optimization\n";
        echo "  config-*             Configuration management\n";
        echo "  emergency-*          Emergency commands\n\n";
        echo "Examples:\n";
        echo "  grim health          # Check system health\n";
        echo "  grim backup /data    # Backup directory\n";
        echo "  grim check-deps      # Check dependencies\n";
        echo "  grim install-deps    # Install dependencies\n\n";
        echo "For full command list: grim help-all\n";
        return 0;
    }

    /**
     * Check system dependencies
     */
    private function checkDependencies(): int
    {
        echo "🔍 Checking Grim Reaper dependencies...\n\n";
        
        $issues = [];
        
        // Check PHP version
        if (version_compare(PHP_VERSION, '8.1.0', '<')) {
            $issues[] = "PHP 8.1+ required (current: " . PHP_VERSION . ")";
        } else {
            echo "✅ PHP version: " . PHP_VERSION . "\n";
        }
        
        // Check required extensions
        $requiredExtensions = ['json', 'curl', 'openssl', 'zip'];
        foreach ($requiredExtensions as $ext) {
            if (!extension_loaded($ext)) {
                $issues[] = "Missing PHP extension: $ext";
            } else {
                echo "✅ PHP extension: $ext\n";
            }
        }
        
        // Check required commands
        $requiredCommands = ['rsync', 'tar', 'gzip', 'curl', 'wget'];
        foreach ($requiredCommands as $cmd) {
            if (!$this->commandExists($cmd)) {
                $issues[] = "Missing command: $cmd";
            } else {
                echo "✅ Command: $cmd\n";
            }
        }
        
        // Check Go
        if (!$this->commandExists('go')) {
            $issues[] = "Missing Go programming language";
        } else {
            $goVersion = shell_exec('go version 2>/dev/null');
            echo "✅ Go: " . trim($goVersion) . "\n";
        }
        
        // Check throne script
        if (!file_exists($this->throneScript)) {
            $issues[] = "Throne script not found: {$this->throneScript}";
        } else {
            echo "✅ Throne script: {$this->throneScript}\n";
        }
        
        // Check grim command
        if (!$this->commandExists('grim')) {
            $issues[] = "Grim command not found in PATH";
        } else {
            echo "✅ Grim command: available\n";
        }
        
        if (!empty($issues)) {
            echo "\n❌ Issues found:\n";
            foreach ($issues as $issue) {
                echo "  - $issue\n";
            }
            echo "\nRun 'grim install-deps' to fix these issues.\n";
            return 1;
        }
        
        echo "\n✅ All dependencies are satisfied!\n";
        return 0;
    }

    /**
     * Install system dependencies
     */
    private function installDependencies(): int
    {
        echo "📦 Installing Grim Reaper dependencies...\n\n";
        
        try {
            // Use the Installer class to handle dependency installation
            $installer = new Installer();
            $installer->installDependencies();
            
            echo "\n✅ Dependencies installed successfully!\n";
            return 0;
            
        } catch (\Exception $e) {
            echo "\n❌ Failed to install dependencies: " . $e->getMessage() . "\n";
            return 1;
        }
    }

    /**
     * Run initial setup
     */
    private function setup(): int
    {
        echo "⚙️  Running Grim Reaper setup...\n\n";
        
        try {
            // Check dependencies first
            if ($this->checkDependencies() !== 0) {
                echo "\nInstalling missing dependencies...\n";
                if ($this->installDependencies() !== 0) {
                    return 1;
                }
            }
            
            // Create necessary directories
            $dirs = [
                $this->grimRoot . '/bin',
                $this->grimRoot . '/config',
                $this->grimRoot . '/logs',
                $this->grimRoot . '/backups',
                $this->grimRoot . '/temp'
            ];
            
            foreach ($dirs as $dir) {
                if (!is_dir($dir)) {
                    if (!mkdir($dir, 0755, true)) {
                        throw new \RuntimeException("Failed to create directory: $dir");
                    }
                    echo "✅ Created directory: $dir\n";
                }
            }
            
            // Create configuration file if it doesn't exist
            $configFile = $this->grimRoot . '/config/grim.json';
            if (!file_exists($configFile)) {
                $defaultConfig = [
                    'version' => self::VERSION,
                    'grim_root' => $this->grimRoot,
                    'backup_path' => $this->grimRoot . '/backups',
                    'log_path' => $this->grimRoot . '/logs',
                    'temp_path' => $this->grimRoot . '/temp'
                ];
                
                if (!file_put_contents($configFile, json_encode($defaultConfig, JSON_PRETTY_PRINT))) {
                    throw new \RuntimeException("Failed to create config file: $configFile");
                }
                echo "✅ Created config file: $configFile\n";
            }
            
            echo "\n✅ Setup completed successfully!\n";
            return 0;
            
        } catch (\Exception $e) {
            echo "\n❌ Setup failed: " . $e->getMessage() . "\n";
            return 1;
        }
    }

    /**
     * Diagnose installation issues
     */
    private function doctor(): int
    {
        echo "🏥 Grim Reaper Doctor - Diagnosing installation...\n\n";
        
        $issues = [];
        $warnings = [];
        
        // Check if we're running as root
        if (posix_getuid() === 0) {
            $warnings[] = "Running as root (this may cause permission issues)";
        }
        
        // Check disk space
        $freeSpace = disk_free_space($this->grimRoot);
        $totalSpace = disk_total_space($this->grimRoot);
        $usedSpace = $totalSpace - $freeSpace;
        $usagePercent = ($usedSpace / $totalSpace) * 100;
        
        if ($usagePercent > 90) {
            $issues[] = "Disk usage is high: " . round($usagePercent, 1) . "%";
        } else {
            echo "✅ Disk usage: " . round($usagePercent, 1) . "%\n";
        }
        
        // Check permissions
        if (!is_readable($this->grimRoot)) {
            $issues[] = "Cannot read Grim root directory";
        }
        
        if (!is_writable($this->grimRoot)) {
            $issues[] = "Cannot write to Grim root directory";
        }
        
        // Check throne script permissions
        if (!is_executable($this->throneScript)) {
            $issues[] = "Throne script is not executable";
        }
        
        // Check if grim command is in PATH
        if (!$this->commandExists('grim')) {
            $issues[] = "Grim command not found in PATH";
        }
        
        // Check for common issues
        if (!file_exists('/etc/os-release')) {
            $warnings[] = "Cannot detect operating system";
        }
        
        if (!is_dir('/tmp')) {
            $issues[] = "Temporary directory not accessible";
        }
        
        // Display results
        if (!empty($issues)) {
            echo "\n❌ Critical issues found:\n";
            foreach ($issues as $issue) {
                echo "  - $issue\n";
            }
        }
        
        if (!empty($warnings)) {
            echo "\n⚠️  Warnings:\n";
            foreach ($warnings as $warning) {
                echo "  - $warning\n";
            }
        }
        
        if (empty($issues) && empty($warnings)) {
            echo "\n✅ No issues found! Grim Reaper is healthy.\n";
            return 0;
        }
        
        if (!empty($issues)) {
            echo "\n💡 Run 'grim setup' to fix these issues.\n";
            return 1;
        }
        
        return 0;
    }

    /**
     * Delegate command to the throne script
     */
    private function delegateToThrone(array $argv): int
    {
        // Build command string
        $command = implode(' ', array_map('escapeshellarg', $argv));
        
        // Execute the throne script
        $fullCommand = "cd " . escapeshellarg($this->grimRoot) . " && " . escapeshellarg($this->throneScript) . " $command";
        
        passthru($fullCommand, $exitCode);
        
        return $exitCode;
    }

    /**
     * Find the Grim Reaper root directory
     */
    private function findGrimRoot(): string
    {
        // Try to find the installation directory
        $possiblePaths = [
            // Current PHP package directory
            dirname(__DIR__),
            // Composer vendor directory
            dirname(__DIR__, 2) . '/grim-reaper/grim-reaper',
            // Global composer installation
            '/usr/local/share/grim-reaper',
            '/usr/share/grim-reaper',
            // Local installation
            getcwd() . '/vendor/grim-reaper/grim-reaper',
            // Fallback to current directory
            getcwd()
        ];
        
        foreach ($possiblePaths as $path) {
            if (is_dir($path) && file_exists($path . '/composer.json')) {
                return realpath($path);
            }
        }
        
        // If not found, use current directory as fallback
        return realpath(getcwd());
    }

    /**
     * Check if command exists
     */
    private function commandExists(string $command): bool
    {
        return !empty(shell_exec("which $command 2>/dev/null"));
    }
} 