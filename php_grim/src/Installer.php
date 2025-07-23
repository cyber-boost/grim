<?php

namespace GrimReaper;

/**
 * Enhanced PHP Installer for Grim Reaper
 * Comprehensive PHP environment setup and management
 */
class Installer
{
    private string $grimRoot;
    private array $requiredExtensions = [
        'json', 'curl', 'openssl', 'zip', 'mbstring', 'xml', 'opcache'
    ];
    
    private array $optionalExtensions = [
        'mysql', 'pgsql', 'redis', 'gd', 'imagick', 'intl', 'bcmath'
    ];
    
    private array $composerPackages = [
        'phpunit/phpunit' => '^10.0',
        'phpstan/phpstan' => '^1.10',
        'squizlabs/php_codesniffer' => '^3.7',
        'phpmd/phpmd' => '^2.15',
        'vimeo/psalm' => '^5.0',
        'enlightn/security-checker' => '^1.0'
    ];

    public function __construct()
    {
        $this->grimRoot = $this->findGrimRoot();
    }

    /**
     * Find Grim Reaper root directory
     */
    private function findGrimRoot(): string
    {
        $currentDir = getcwd();
        $maxDepth = 10;
        $depth = 0;

        // First, try to find from current directory
        while ($depth < $maxDepth) {
            // Check for throne scripts
            if (file_exists($currentDir . '/throne/grim_throne.sh') ||
                file_exists($currentDir . '/throne/php_grim_throne.sh')) {
                return $currentDir;
            }

            // Check for grim_admin_server.py
            if (file_exists($currentDir . '/tsk_flask/grim_admin_server.py')) {
                return $currentDir;
            }

            $parentDir = dirname($currentDir);
            if ($parentDir === $currentDir) {
                break;
            }

            $currentDir = $parentDir;
            $depth++;
        }

        // If not found, try common installation paths
        $possiblePaths = [
            // User's home directory
            $_SERVER['HOME'] . '/reaper',
            $_SERVER['HOME'] . '/.reaper',
            // Root user paths
            '/root/reaper',
            '/root/.reaper',
            // System paths (fallback)
            '/usr/local/reaper',
            '/usr/share/reaper',
            // Current directory as last resort
            getcwd()
        ];

        foreach ($possiblePaths as $path) {
            if (is_dir($path) && (
                file_exists($path . '/throne/grim_throne.sh') ||
                file_exists($path . '/throne/php_grim_throne.sh') ||
                file_exists($path . '/tsk_flask/grim_admin_server.py')
            )) {
                return $path;
            }
        }

        throw new \RuntimeException('Could not find Grim Reaper root directory. Please ensure Grim Reaper is properly installed.');
    }

    /**
     * Get backup directory
     */
    private function getBackupDir(): string
    {
        // Use graveyard if available
        $graveyard = $_SERVER['HOME'] . '/.graveyard';
        if (is_dir($graveyard) || is_writable(dirname($graveyard))) {
            return $graveyard;
        }

        // Fallback to user's home
        return $_SERVER['HOME'] . '/backups';
    }

    /**
     * Get installation directory
     */
    private function getInstallDir(): string
    {
        // Use user's home directory
        return $_SERVER['HOME'] . '/reaper';
    }

    /**
     * Post-install command for Composer
     */
    public static function postInstall(): void
    {
        $installer = new self();
        $installer->setupEnvironment();
        $installer->installDependencies();
        $installer->configurePHP();
        echo "✅ PHP Grim Reaper setup complete!\n";
    }

    /**
     * Post-update command for Composer
     */
    public static function postUpdate(): void
    {
        $installer = new self();
        $installer->updateDependencies();
        echo "✅ PHP Grim Reaper updated successfully!\n";
    }

    /**
     * Install all dependencies
     */
    public static function installDependencies(): void
    {
        $installer = new self();
        $installer->installSystemDependencies();
        $installer->installComposerDependencies();
        $installer->installDevelopmentTools();
    }

    /**
     * Setup PHP environment
     */
    public function setupEnvironment(): void
    {
        echo "🐘 Setting up PHP environment...\n";

        // Check PHP version
        $this->checkPHPVersion();

        // Check Composer
        $this->checkComposer();

        // Create necessary directories
        $this->createDirectories();

        // Set up environment variables
        $this->setupEnvironmentVariables();

        echo "✅ PHP environment setup complete\n";
    }

    /**
     * Check PHP version requirements
     */
    private function checkPHPVersion(): void
    {
        $version = PHP_VERSION;
        $major = (int)explode('.', $version)[0];
        $minor = (int)explode('.', $version)[1];

        if ($major < 8 || ($major === 8 && $minor < 1)) {
            throw new \RuntimeException("PHP 8.1+ required, found $version");
        }

        echo "✅ PHP version $version is compatible\n";
    }

    /**
     * Check and install Composer
     */
    private function checkComposer(): void
    {
        if (!$this->commandExists('composer')) {
            echo "📦 Installing Composer...\n";
            $this->installComposer();
        } else {
            echo "✅ Composer is already installed\n";
        }
    }

    /**
     * Install Composer
     */
    private function installComposer(): void
    {
        $installer = file_get_contents('https://getcomposer.org/installer');
        if ($installer === false) {
            throw new \RuntimeException('Failed to download Composer installer');
        }

        file_put_contents('composer-setup.php', $installer);
        
        $signature = file_get_contents('https://composer.github.io/installer.sig');
        if (hash_file('SHA384', 'composer-setup.php') !== $signature) {
            unlink('composer-setup.php');
            throw new \RuntimeException('Composer installer signature verification failed');
        }

        exec('php composer-setup.php --install-dir=/usr/local/bin --filename=composer');
        unlink('composer-setup.php');
    }

    /**
     * Create necessary directories
     */
    private function createDirectories(): void
    {
        $backupDir = $this->getBackupDir();
        $installDir = $this->getInstallDir();
        
        $directories = [
            $this->grimRoot . '/logs',
            $this->grimRoot . '/cache',
            $backupDir,
            $this->grimRoot . '/temp'
        ];

        foreach ($directories as $dir) {
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
                echo "📁 Created directory: $dir\n";
            }
        }
    }

    /**
     * Setup environment variables
     */
    private function setupEnvironmentVariables(): void
    {
        $envFile = $this->grimRoot . '/.env';
        $backupDir = $this->getBackupDir();
        
        if (!file_exists($envFile)) {
            $envContent = "GRIM_ROOT={$this->grimRoot}\n";
            $envContent .= "GRIM_ENV=production\n";
            $envContent .= "GRIM_LOG_LEVEL=info\n";
            $envContent .= "GRIM_CACHE_DIR={$this->grimRoot}/cache\n";
            $envContent .= "GRIM_BACKUP_DIR={$backupDir}\n";
            $envContent .= "GRIM_HOME={$_SERVER['HOME']}\n";
            
            file_put_contents($envFile, $envContent);
            echo "📝 Created environment file: $envFile\n";
        }
    }

    /**
     * Install system dependencies
     */
    public function installSystemDependencies(): void
    {
        echo "🔧 Installing system dependencies...\n";

        if ($this->commandExists('apt-get')) {
            $this->installUbuntuDependencies();
        } elseif ($this->commandExists('yum')) {
            $this->installCentOSDependencies();
        } else {
            echo "⚠️  Unsupported package manager, please install dependencies manually\n";
        }
    }

    /**
     * Install Ubuntu/Debian dependencies
     */
    private function installUbuntuDependencies(): void
    {
        $packages = [
            'php8.1', 'php8.1-cli', 'php8.1-common', 'php8.1-curl', 'php8.1-mbstring',
            'php8.1-xml', 'php8.1-zip', 'php8.1-opcache', 'php8.1-mysql', 'php8.1-pgsql',
            'php8.1-redis', 'php8.1-gd', 'php8.1-imagick', 'php8.1-intl', 'php8.1-bcmath',
            'composer', 'git', 'curl', 'wget', 'unzip', 'tar', 'gzip'
        ];

        $packageList = implode(' ', $packages);
        exec("sudo apt-get update && sudo apt-get install -y $packageList", $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \RuntimeException('Failed to install Ubuntu dependencies');
        }

        echo "✅ Ubuntu dependencies installed\n";
    }

    /**
     * Install CentOS/RHEL dependencies
     */
    private function installCentOSDependencies(): void
    {
        $packages = [
            'php', 'php-cli', 'php-common', 'php-curl', 'php-mbstring',
            'php-xml', 'php-zip', 'php-opcache', 'php-mysql', 'php-pgsql',
            'php-redis', 'php-gd', 'php-imagick', 'php-intl', 'php-bcmath',
            'git', 'curl', 'wget', 'unzip', 'tar', 'gzip'
        ];

        $packageList = implode(' ', $packages);
        exec("sudo yum install -y $packageList", $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \RuntimeException('Failed to install CentOS dependencies');
        }

        echo "✅ CentOS dependencies installed\n";
    }

    /**
     * Install Composer dependencies
     */
    public function installComposerDependencies(): void
    {
        echo "📦 Installing Composer dependencies...\n";

        $composerJson = dirname(__DIR__) . '/composer.json';
        if (file_exists($composerJson)) {
            chdir(dirname(__DIR__));
            exec('composer install --optimize-autoloader', $output, $returnCode);

            if ($returnCode !== 0) {
                throw new \RuntimeException('Failed to install Composer dependencies');
            }

            echo "✅ Composer dependencies installed\n";
        }
    }

    /**
     * Install development tools
     */
    public function installDevelopmentTools(): void
    {
        echo "🛠️  Installing development tools...\n";

        foreach ($this->composerPackages as $package => $version) {
            echo "Installing $package...\n";
            exec("composer global require $package:$version", $output, $returnCode);
            
            if ($returnCode !== 0) {
                echo "⚠️  Failed to install $package\n";
            }
        }

        echo "✅ Development tools installed\n";
    }

    /**
     * Update dependencies
     */
    public function updateDependencies(): void
    {
        echo "🔄 Updating dependencies...\n";

        chdir(dirname(__DIR__));
        exec('composer update', $output, $returnCode);

        if ($returnCode !== 0) {
            throw new \RuntimeException('Failed to update dependencies');
        }

        echo "✅ Dependencies updated\n";
    }

    /**
     * Configure PHP settings
     */
    public function configurePHP(): void
    {
        echo "⚙️  Configuring PHP settings...\n";

        $phpIniFiles = [
            '/etc/php/8.1/cli/php.ini',
            '/etc/php/8.1/apache2/php.ini',
            '/etc/php/8.1/fpm/php.ini',
            '/etc/php.ini'
        ];

        foreach ($phpIniFiles as $iniFile) {
            if (file_exists($iniFile)) {
                $this->configurePHPIni($iniFile);
            }
        }

        echo "✅ PHP configuration complete\n";
    }

    /**
     * Configure specific PHP INI file
     */
    private function configurePHPIni(string $iniFile): void
    {
        $content = file_get_contents($iniFile);
        if ($content === false) {
            return;
        }

        $replacements = [
            'upload_max_filesize = 2M' => 'upload_max_filesize = 100M',
            'post_max_size = 8M' => 'post_max_size = 100M',
            'memory_limit = 128M' => 'memory_limit = 512M',
            'max_execution_time = 30' => 'max_execution_time = 300',
            'max_input_time = 60' => 'max_input_time = 300',
            'display_errors = On' => 'display_errors = Off',
            'log_errors = Off' => 'log_errors = On',
            'error_log = php_errors.log' => 'error_log = /var/log/php_errors.log'
        ];

        foreach ($replacements as $search => $replace) {
            $content = str_replace($search, $replace, $content);
        }

        file_put_contents($iniFile, $content);
        echo "✅ Configured: $iniFile\n";
    }

    /**
     * Check if command exists
     */
    private function commandExists(string $command): bool
    {
        $output = [];
        exec("which $command", $output, $returnCode);
        return $returnCode === 0;
    }

    /**
     * Verify installation
     */
    public function verifyInstallation(): bool
    {
        echo "🔍 Verifying installation...\n";

        $checks = [
            'PHP Version' => $this->checkPHPVersion(),
            'Composer' => $this->commandExists('composer'),
            'Required Extensions' => $this->checkRequiredExtensions(),
            'Grim Root' => is_dir($this->grimRoot),
            'Throne Scripts' => file_exists($this->grimRoot . '/throne/php_grim_throne.sh')
        ];

        $allPassed = true;
        foreach ($checks as $check => $result) {
            $status = $result ? '✅' : '❌';
            echo "$status $check\n";
            if (!$result) {
                $allPassed = false;
            }
        }

        return $allPassed;
    }

    /**
     * Check required PHP extensions
     */
    private function checkRequiredExtensions(): bool
    {
        $missing = [];
        foreach ($this->requiredExtensions as $ext) {
            if (!extension_loaded($ext)) {
                $missing[] = $ext;
            }
        }

        if (!empty($missing)) {
            echo "❌ Missing extensions: " . implode(', ', $missing) . "\n";
            return false;
        }

        return true;
    }

    /**
     * Get installation status
     */
    public function getStatus(): array
    {
        return [
            'grim_root' => $this->grimRoot,
            'php_version' => PHP_VERSION,
            'composer_installed' => $this->commandExists('composer'),
            'required_extensions' => $this->getExtensionStatus($this->requiredExtensions),
            'optional_extensions' => $this->getExtensionStatus($this->optionalExtensions),
            'throne_scripts' => [
                'grim_throne.sh' => file_exists($this->grimRoot . '/throne/grim_throne.sh'),
                'php_grim_throne.sh' => file_exists($this->grimRoot . '/throne/php_grim_throne.sh')
            ]
        ];
    }

    /**
     * Get extension status
     */
    private function getExtensionStatus(array $extensions): array
    {
        $status = [];
        foreach ($extensions as $ext) {
            $status[$ext] = extension_loaded($ext);
        }
        return $status;
    }

    /**
     * Clean up installation
     */
    public function cleanup(): void
    {
        echo "🧹 Cleaning up installation...\n";

        $tempFiles = [
            'composer-setup.php',
            'composer.phar'
        ];

        foreach ($tempFiles as $file) {
            if (file_exists($file)) {
                unlink($file);
                echo "🗑️  Removed: $file\n";
            }
        }

                 echo "✅ Cleanup complete\n";
    }
} 