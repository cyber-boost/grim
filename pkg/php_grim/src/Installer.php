<?php

namespace GrimReaper;

use Composer\Script\Event;
use Composer\Installer\PackageEvent;

/**
 * Grim Reaper PHP Package Installer
 * Handles post-installation tasks and dependency management
 */
class Installer
{
    private const GRIM_VERSION = '1.0.0';
    private const REQUIRED_EXTENSIONS = ['json', 'curl', 'openssl', 'zip'];
    private const REQUIRED_COMMANDS = ['rsync', 'tar', 'gzip', 'curl', 'wget'];

    /**
     * Post-installation hook for Composer
     */
    public static function postInstall(Event $event): void
    {
        $io = $event->getIO();
        $io->write('<info>🗡️  Grim Reaper PHP Package Installation</info>');
        
        try {
            self::checkRequirements($io);
            self::setupGrimDirectory($io);
            self::installDependencies($io);
            self::createSymlinks($io);
            self::verifyInstallation($io);
            
            $io->write('<info>✅ Grim Reaper installation completed successfully!</info>');
            $io->write('');
            $io->write('Usage:');
            $io->write('  grim help          - Show available commands');
            $io->write('  grim check-deps    - Verify dependencies');
            $io->write('  grim backup        - Start backup operations');
            $io->write('  grim monitor       - Monitor system health');
            $io->write('');
            $io->write('For more information: https://grim.so');
            
        } catch (\Exception $e) {
            $io->writeError('<error>❌ Installation failed: ' . $e->getMessage() . '</error>');
            throw $e;
        }
    }

    /**
     * Post-update hook for Composer
     */
    public static function postUpdate(Event $event): void
    {
        $io = $event->getIO();
        $io->write('<info>🔄 Grim Reaper PHP Package Update</info>');
        
        try {
            self::checkRequirements($io);
            self::updateDependencies($io);
            self::verifyInstallation($io);
            
            $io->write('<info>✅ Grim Reaper update completed successfully!</info>');
            
        } catch (\Exception $e) {
            $io->writeError('<error>❌ Update failed: ' . $e->getMessage() . '</error>');
            throw $e;
        }
    }

    /**
     * Install system dependencies
     */
    public static function installDependencies($io): void
    {
        $io->write('<info>📦 Installing system dependencies...</info>');
        
        // Skip system package installation in build environment
        if (getenv('PACKAGIST_BUILD') || getenv('COMPOSER_INSTALL')) {
            $io->write('<info>⏭️  Skipping system package installation in build environment</info>');
            return;
        }
        
        $installer = new self();
        $installer->detectOS();
        $installer->installSystemDependencies();
        $installer->installGo();
        $installer->buildBinaries();
        
        $io->write('<info>✅ Dependencies installed successfully</info>');
    }

    /**
     * Check system requirements
     */
    private static function checkRequirements($io): void
    {
        $io->write('<info>🔍 Checking system requirements...</info>');
        
        // Check PHP version
        if (version_compare(PHP_VERSION, '8.1.0', '<')) {
            throw new \RuntimeException('PHP 8.1 or higher is required. Current version: ' . PHP_VERSION);
        }
        
        // Check required extensions
        foreach (self::REQUIRED_EXTENSIONS as $ext) {
            if (!extension_loaded($ext)) {
                throw new \RuntimeException("Required PHP extension not loaded: $ext");
            }
        }
        
        // Check required commands
        foreach (self::REQUIRED_COMMANDS as $cmd) {
            if (!self::commandExists($cmd)) {
                $io->writeWarning("<warning>⚠️  Command not found: $cmd (will be installed)</warning>");
            }
        }
        
        $io->write('<info>✅ System requirements check passed</info>');
    }

    /**
     * Setup Grim Reaper directory structure
     */
    private static function setupGrimDirectory($io): void
    {
        $io->write('<info>📁 Setting up Grim Reaper directory...</info>');
        
        $grimRoot = self::getGrimRoot();
        $dirs = [
            $grimRoot,
            $grimRoot . '/bin',
            $grimRoot . '/config',
            $grimRoot . '/logs',
            $grimRoot . '/backups',
            $grimRoot . '/temp'
        ];
        
        foreach ($dirs as $dir) {
            if (!is_dir($dir)) {
                if (!mkdir($dir, 0755, true)) {
                    throw new \RuntimeException("Failed to create directory: $dir");
                }
            }
        }
        
        $io->write('<info>✅ Directory structure created</info>');
    }

    /**
     * Install system dependencies based on OS
     */
    private function installSystemDependencies(): void
    {
        $os = $this->detectOS();
        
        switch ($os) {
            case 'ubuntu':
            case 'debian':
                $this->installDebianDependencies();
                break;
            case 'centos':
            case 'rhel':
            case 'fedora':
                $this->installRedHatDependencies();
                break;
            default:
                throw new \RuntimeException("Unsupported operating system: $os");
        }
    }

    /**
     * Install Go programming language
     */
    private function installGo(): void
    {
        if ($this->commandExists('go')) {
            return; // Go already installed
        }
        
        $goVersion = '1.21.0';
        $goArch = 'linux-amd64';
        $goUrl = "https://go.dev/dl/go{$goVersion}.{$goArch}.tar.gz";
        
        $tempDir = sys_get_temp_dir();
        $goArchive = $tempDir . "/go{$goVersion}.{$goArch}.tar.gz";
        
        // Download Go
        if (!file_put_contents($goArchive, file_get_contents($goUrl))) {
            throw new \RuntimeException('Failed to download Go');
        }
        
        // Extract to /usr/local
        $command = "sudo tar -C /usr/local -xzf $goArchive";
        if (system($command) !== 0) {
            throw new \RuntimeException('Failed to install Go');
        }
        
        // Add to PATH
        $this->addToPath('/usr/local/go/bin');
        
        unlink($goArchive);
    }

    /**
     * Build Go binaries
     */
    private function buildBinaries(): void
    {
        $grimRoot = self::getGrimRoot();
        $goDir = $grimRoot . '/go_grim';
        
        if (!is_dir($goDir)) {
            throw new \RuntimeException("Go source directory not found: $goDir");
        }
        
        $currentDir = getcwd();
        chdir($goDir);
        
        // Download modules
        if (system('go mod download') !== 0) {
            throw new \RuntimeException('Failed to download Go modules');
        }
        
        // Build binaries
        if (file_exists('Makefile')) {
            if (system('make build') !== 0) {
                throw new \RuntimeException('Failed to build Go binaries with Makefile');
            }
        } else {
            if (system('go build -o build/grim-compression ./cmd/compression') !== 0) {
                throw new \RuntimeException('Failed to build Go compression binary');
            }
        }
        
        chdir($currentDir);
    }

    /**
     * Create symlinks for global access
     */
    private static function createSymlinks($io): void
    {
        $io->write('<info>🔗 Creating symlinks...</info>');
        
        $grimRoot = self::getGrimRoot();
        $binDir = $grimRoot . '/bin';
        $globalBinDir = '/usr/local/bin';
        
        // Create grim command symlink
        $grimBin = $binDir . '/grim';
        $globalGrimBin = $globalBinDir . '/grim';
        
        if (!file_exists($grimBin)) {
            // Create the grim wrapper script
            self::createGrimWrapper($grimBin);
        }
        
        if (!file_exists($globalGrimBin)) {
            if (!symlink($grimBin, $globalGrimBin)) {
                $io->writeWarning('<warning>⚠️  Failed to create global symlink (may need sudo)</warning>');
            }
        }
        
        $io->write('<info>✅ Symlinks created</info>');
    }

    /**
     * Create the grim wrapper script
     */
    private static function createGrimWrapper(string $binPath): void
    {
        $grimRoot = self::getGrimRoot();
        // Look for throne script in parent directory (main project root)
        $phpThrone = dirname($grimRoot) . '/throne/php_grim_throne.sh';
        
        $wrapper = "#!/bin/bash\n";
        $wrapper .= "# Grim Reaper PHP Wrapper\n";
        $wrapper .= "# Auto-generated by Grim Reaper PHP package\n\n";
        $wrapper .= "GRIM_ROOT=\"" . dirname($grimRoot) . "\"\n";
        $wrapper .= "cd \"\$GRIM_ROOT\"\n\n";
        $wrapper .= "if [[ -f \"$phpThrone\" ]]; then\n";
        $wrapper .= "    exec \"$phpThrone\" \"\$@\"\n";
        $wrapper .= "else\n";
        $wrapper .= "    echo \"❌ Grim Reaper throne script not found\" >&2\n";
        $wrapper .= "    exit 1\n";
        $wrapper .= "fi\n";
        
        if (!file_put_contents($binPath, $wrapper)) {
            throw new \RuntimeException('Failed to create grim wrapper script');
        }
        
        chmod($binPath, 0755);
    }

    /**
     * Verify installation
     */
    private static function verifyInstallation($io): void
    {
        $io->write('<info>🔍 Verifying installation...</info>');
        
        $grimRoot = self::getGrimRoot();
        
        // Check if grim command works
        if (self::commandExists('grim')) {
            $io->write('<info>✅ Grim command is available</info>');
        } else {
            $io->writeWarning('<warning>⚠️  Grim command not found in PATH</warning>');
        }
        
        // Check if throne script exists
        $throneScript = dirname(dirname($grimRoot)) . '/throne/php_grim_throne.sh';
        if (file_exists($throneScript)) {
            $io->write('<info>✅ Throne script found</info>');
        } else {
            throw new \RuntimeException('Throne script not found: ' . $throneScript);
        }
        
        $io->write('<info>✅ Installation verification complete</info>');
    }

    /**
     * Get Grim Reaper root directory
     */
    public static function getGrimRoot(): string
    {
        // Try to find the installation directory
        $possiblePaths = [
            // Current PHP package directory
            dirname(__DIR__),
            // Composer vendor directory
            dirname(dirname(__DIR__)) . '/grim-reaper/grim-reaper',
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
     * Detect operating system
     */
    private function detectOS(): string
    {
        if (file_exists('/etc/os-release')) {
            $content = file_get_contents('/etc/os-release');
            if (preg_match('/^ID=(.+)$/m', $content, $matches)) {
                return strtolower(trim($matches[1], '"'));
            }
        }
        
        return 'unknown';
    }

    /**
     * Install dependencies for Debian-based systems
     */
    private function installDebianDependencies(): void
    {
        $commands = [
            'sudo apt update',
            'sudo apt install -y rsync tar gzip bzip2 xz-utils openssl curl wget ssh-client scp findutils build-essential git'
        ];
        
        foreach ($commands as $command) {
            if (system($command) !== 0) {
                throw new \RuntimeException("Failed to execute: $command");
            }
        }
    }

    /**
     * Install dependencies for Red Hat-based systems
     */
    private function installRedHatDependencies(): void
    {
        $commands = [
            'sudo yum update -y',
            'sudo yum install -y rsync tar gzip bzip2 xz openssl curl wget openssh-clients findutils gcc gcc-c++ make git'
        ];
        
        foreach ($commands as $command) {
            if (system($command) !== 0) {
                throw new \RuntimeException("Failed to execute: $command");
            }
        }
    }

    /**
     * Update dependencies
     */
    private static function updateDependencies($io): void
    {
        $io->write('<info>🔄 Updating dependencies...</info>');
        
        $installer = new self();
        $installer->detectOS();
        $installer->installSystemDependencies();
        $installer->buildBinaries();
        
        $io->write('<info>✅ Dependencies updated successfully</info>');
    }

    /**
     * Add directory to PATH
     */
    private function addToPath(string $path): void
    {
        $bashrc = $_SERVER['HOME'] . '/.bashrc';
        $pathLine = "export PATH=\$PATH:$path";
        
        if (file_exists($bashrc) && !str_contains(file_get_contents($bashrc), $path)) {
            file_put_contents($bashrc, "\n$pathLine\n", FILE_APPEND);
        }
        
        // Also add to current session
        putenv("PATH=" . getenv('PATH') . ":$path");
    }

    /**
     * Check if command exists
     */
    private static function commandExists(string $command): bool
    {
        return !empty(shell_exec("which $command 2>/dev/null"));
    }
} 