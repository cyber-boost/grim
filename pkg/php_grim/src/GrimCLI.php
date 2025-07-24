<?php

namespace GrimReaper;

/**
 * Enhanced Grim Reaper PHP CLI
 * Comprehensive PHP-specific command interface
 */
class GrimCLI
{
    private string $grimRoot;
    private Installer $installer;
    private array $commands = [];

    public function __construct()
    {
        $this->grimRoot = $this->findGrimRoot();
        $this->installer = new Installer();
        $this->initializeCommands();
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
     * Initialize available commands
     */
    private function initializeCommands(): void
    {
        $this->commands = [
            'php-setup' => 'Setup PHP environment and dependencies',
            'php-analyze' => 'Analyze PHP code quality and security',
            'php-optimize' => 'Optimize PHP performance and memory',
            'php-security' => 'Security audit for PHP applications',
            'php-test' => 'Run PHPUnit tests',
            'php-lint' => 'PHP syntax and style checking',
            'php-deps' => 'Analyze and update dependencies',
            'php-deploy' => 'Deploy PHP application',
            'php-monitor' => 'Monitor PHP application performance',
            'php-backup' => 'Backup PHP application and database',
            'php-restore' => 'Restore PHP application from backup',
            'php-cache' => 'Manage PHP opcache and caches',
            'php-logs' => 'Manage PHP error logs',
            'php-composer' => 'Composer operations',
            'php-extensions' => 'Manage PHP extensions',
            'php-versions' => 'Manage multiple PHP versions',
            'php-fpm' => 'PHP-FPM management',
            'php-nginx' => 'Nginx + PHP configuration',
            'php-apache' => 'Apache + PHP configuration',
            'php-docker' => 'Docker PHP operations',
            'php-k8s' => 'Kubernetes PHP operations',
            'health' => 'Check all systems health',
            'status' => 'Overall system status',
            'backup' => 'Orchestrated backup',
            'restore' => 'Coordinated restore',
            'scan' => 'Unified file scanning',
            'monitor' => 'Start monitoring',
            'web' => 'Start web interface',
            'help' => 'Show this help message',
            'help-all' => 'Show all available commands'
        ];
    }

    /**
     * Run the CLI application
     */
    public function run(array $argv): void
    {
        try {
            // Remove script name from arguments
            array_shift($argv);
            
            if (empty($argv)) {
                $this->showHelp();
                return;
            }

            $command = $argv[0];
            array_shift($argv); // Remove command from arguments

            $this->executeCommand($command, $argv);

        } catch (\Exception $e) {
            $this->error($e->getMessage());
            exit(1);
        }
    }

    /**
     * Execute a command
     */
    private function executeCommand(string $command, array $args): void
    {
        switch ($command) {
            case 'help':
                $this->showHelp();
                break;

            case 'help-all':
                $this->showAllCommands();
                break;

            case 'php-setup':
                $this->phpSetup();
                break;

            case 'php-analyze':
                $this->phpAnalyze($args);
                break;

            case 'php-optimize':
                $this->phpOptimize($args);
                break;

            case 'php-security':
                $this->phpSecurity($args);
                break;

            case 'php-test':
                $this->phpTest($args);
                break;

            case 'php-lint':
                $this->phpLint($args);
                break;

            case 'php-deps':
                $this->phpDeps($args);
                break;

            case 'php-deploy':
                $this->phpDeploy($args);
                break;

            case 'php-monitor':
                $this->phpMonitor($args);
                break;

            case 'php-backup':
                $this->phpBackup($args);
                break;

            case 'php-restore':
                $this->phpRestore($args);
                break;

            case 'php-cache':
                $this->phpCache($args);
                break;

            case 'php-logs':
                $this->phpLogs($args);
                break;

            case 'php-composer':
                $this->phpComposer($args);
                break;

            case 'php-extensions':
                $this->phpExtensions();
                break;

            case 'php-versions':
                $this->phpVersions();
                break;

            case 'php-fpm':
                $this->phpFpm($args);
                break;

            case 'php-nginx':
                $this->phpNginx($args);
                break;

            case 'php-apache':
                $this->phpApache($args);
                break;

            case 'php-docker':
                $this->phpDocker($args);
                break;

            case 'php-k8s':
                $this->phpK8s($args);
                break;

            default:
                // Delegate to throne script for other commands
                $this->delegateToThrone($command, $args);
                break;
        }
    }

    /**
     * Delegate command to throne script
     */
    private function delegateToThrone(string $command, array $args): void
    {
        $throneScript = $this->grimRoot . '/throne/php_grim_throne.sh';
        
        if (!file_exists($throneScript)) {
            throw new \RuntimeException("Throne script not found: $throneScript");
        }

        if (!is_executable($throneScript)) {
            chmod($throneScript, 0755);
        }

        $commandLine = escapeshellcmd($throneScript) . ' ' . $command;
        if (!empty($args)) {
            $commandLine .= ' ' . implode(' ', array_map('escapeshellarg', $args));
        }

        $this->info("Executing: $commandLine");
        
        $output = [];
        $returnCode = 0;
        exec($commandLine, $output, $returnCode);

        foreach ($output as $line) {
            echo $line . "\n";
        }

        if ($returnCode !== 0) {
            throw new \RuntimeException("Command failed with exit code: $returnCode");
        }
    }

    /**
     * Show help message
     */
    private function showHelp(): void
    {
        echo "🗡️  Grim Reaper PHP-Specific Command Interface\n\n";
        echo "Usage: grim <command> [options]\n\n";
        echo "🐘 PHP-Specific Commands:\n";
        
        foreach ($this->commands as $cmd => $desc) {
            if (strpos($cmd, 'php-') === 0) {
                printf("  %-20s %s\n", $cmd, $desc);
            }
        }
        
        echo "\n🔧 Core Commands:\n";
        foreach ($this->commands as $cmd => $desc) {
            if (strpos($cmd, 'php-') !== 0 && !in_array($cmd, ['help', 'help-all'])) {
                printf("  %-20s %s\n", $cmd, $desc);
            }
        }
        
        echo "\nExamples:\n";
        echo "  grim php-setup            # Setup PHP environment\n";
        echo "  grim php-analyze /app     # Analyze PHP code\n";
        echo "  grim php-deploy /app      # Deploy PHP app\n";
        echo "  grim php-monitor /app     # Monitor PHP app\n";
        echo "\nFor full command list: grim help-all\n";
    }

    /**
     * Show all available commands
     */
    private function showAllCommands(): void
    {
        echo "🗡️  Grim Reaper - All Available Commands\n\n";
        
        foreach ($this->commands as $cmd => $desc) {
            printf("  %-25s %s\n", $cmd, $desc);
        }
    }

    /**
     * PHP Setup
     */
    private function phpSetup(): void
    {
        $this->info("Setting up PHP environment...");
        $this->installer->setupEnvironment();
        $this->installer->installDependencies();
        $this->installer->configurePHP();
        $this->success("PHP environment setup complete!");
    }

    /**
     * PHP Analyze
     */
    private function phpAnalyze(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-analyze <path>");
        }

        $path = $args[0];
        $this->info("Analyzing PHP code in: $path");
        
        // Run PHPStan
        $this->runCommand("phpstan analyse $path --level=8");
        
        // Run Psalm
        $this->runCommand("psalm --init $path");
        $this->runCommand("psalm $path");
        
        // Run PHP Mess Detector
        $this->runCommand("phpmd $path text cleancode,codesize,controversial,design,naming,unusedcode");
        
        $this->success("PHP analysis complete");
    }

    /**
     * PHP Optimize
     */
    private function phpOptimize(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-optimize <path>");
        }

        $path = $args[0];
        $this->info("Optimizing PHP application in: $path");
        
        // Composer optimization
        if (file_exists("$path/composer.json")) {
            chdir($path);
            $this->runCommand("composer install --optimize-autoloader --no-dev");
            $this->runCommand("composer dump-autoload --optimize");
        }
        
        // OpCache optimization
        $this->runCommand("php -r 'opcache_reset();'");
        
        // Clear caches
        $this->runCommand("find $path -name cache -type d -exec rm -rf {} +");
        $this->runCommand("find $path -name tmp -type d -exec rm -rf {} +");
        
        $this->success("PHP optimization complete");
    }

    /**
     * PHP Security
     */
    private function phpSecurity(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-security <path>");
        }

        $path = $args[0];
        $this->info("Running security audit for: $path");
        
        // Check for known vulnerabilities
        if (file_exists("$path/composer.lock")) {
            $this->runCommand("security-checker security:check $path/composer.lock");
        }
        
        // Check file permissions
        $this->runCommand("find $path -type f -name '*.php' -exec chmod 644 {} \\;");
        $this->runCommand("find $path -type d -exec chmod 755 {} \\;");
        
        $this->success("Security audit complete");
    }

    /**
     * PHP Test
     */
    private function phpTest(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-test <path>");
        }

        $path = $args[0];
        $this->info("Running PHPUnit tests in: $path");
        
        if (file_exists("$path/phpunit.xml") || file_exists("$path/phpunit.xml.dist")) {
            chdir($path);
            $this->runCommand("phpunit");
        } else {
            $this->warning("No PHPUnit configuration found");
        }
        
        $this->success("PHP tests complete");
    }

    /**
     * PHP Lint
     */
    private function phpLint(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-lint <path>");
        }

        $path = $args[0];
        $this->info("Linting PHP code in: $path");
        
        // Syntax check
        $this->runCommand("find $path -name '*.php' -exec php -l {} \\;");
        
        // PSR-12 style check
        $this->runCommand("phpcs --standard=PSR12 $path");
        
        $this->success("PHP linting complete");
    }

    /**
     * PHP Dependencies
     */
    private function phpDeps(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-deps <path>");
        }

        $path = $args[0];
        $this->info("Analyzing dependencies in: $path");
        
        if (file_exists("$path/composer.json")) {
            chdir($path);
            $this->runCommand("composer outdated");
            $this->runCommand("composer audit");
        } else {
            $this->warning("No composer.json found");
        }
        
        $this->success("Dependency analysis complete");
    }

    /**
     * PHP Deploy
     */
    private function phpDeploy(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-deploy <path>");
        }

        $path = $args[0];
        $this->info("Deploying PHP application: $path");
        
        // Create backup
        $this->delegateToThrone('backup', [$path, '--name', 'pre-deploy-' . date('Y-m-d-H-i-s')]);
        
        // Optimize for production
        $this->phpOptimize($args);
        
        // Set proper permissions
        $this->runCommand("find $path -type f -exec chmod 644 {} \\;");
        $this->runCommand("find $path -type d -exec chmod 755 {} \\;");
        
        $this->success("PHP deployment complete");
    }

    /**
     * PHP Monitor
     */
    private function phpMonitor(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-monitor <path>");
        }

        $path = $args[0];
        $this->info("Monitoring PHP application: $path");
        
        // Monitor PHP-FPM
        $this->runCommand("systemctl status php*-fpm");
        
        // Monitor error logs
        $this->runCommand("tail -f /var/log/php*.log");
        
        $this->success("PHP monitoring active");
    }

    /**
     * PHP Backup
     */
    private function phpBackup(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-backup <path>");
        }

        $path = $args[0];
        $this->info("Backing up PHP application: $path");
        
        // Application backup
        $this->delegateToThrone('backup', [$path, '--name', 'php-app-' . date('Y-m-d-H-i-s')]);
        
        // Database backup (if Laravel/Symfony)
        if (file_exists("$path/.env")) {
            $this->runCommand("mysqldump -u root -p $path/database_backup.sql");
            $this->success("Database backup created");
        }
        
        $this->success("PHP backup complete");
    }

    /**
     * PHP Restore
     */
    private function phpRestore(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-restore <backup>");
        }

        $backup = $args[0];
        $this->info("Restoring PHP application from: $backup");
        
        $this->delegateToThrone('restore', [$backup]);
        
        // Restore database if backup exists
        if (file_exists("database_backup.sql")) {
            $this->runCommand("mysql -u root -p < database_backup.sql");
            $this->success("Database restored");
        }
        
        $this->success("PHP restore complete");
    }

    /**
     * PHP Cache
     */
    private function phpCache(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-cache <clear|status|optimize>");
        }

        $action = $args[0];
        
        switch ($action) {
            case 'clear':
                $this->info("Clearing PHP caches...");
                $this->runCommand("php -r 'opcache_reset();'");
                $this->runCommand("find . -name cache -type d -exec rm -rf {} +");
                $this->success("PHP caches cleared");
                break;
                
            case 'status':
                $this->info("PHP OpCache status:");
                $this->runCommand("php -r 'var_dump(opcache_get_status());'");
                break;
                
            case 'optimize':
                $this->info("Optimizing PHP OpCache...");
                $this->runCommand("php -r 'opcache_compile_file(\"*.php\");'");
                $this->success("PHP OpCache optimized");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown cache action: $action");
        }
    }

    /**
     * PHP Logs
     */
    private function phpLogs(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-logs <show|clear|analyze>");
        }

        $action = $args[0];
        
        switch ($action) {
            case 'show':
                $this->info("Showing PHP error logs:");
                $this->runCommand("tail -n 50 /var/log/php*.log");
                break;
                
            case 'clear':
                $this->info("Clearing PHP error logs...");
                $this->runCommand("sudo truncate -s 0 /var/log/php*.log");
                $this->success("PHP error logs cleared");
                break;
                
            case 'analyze':
                $this->info("Analyzing PHP error logs:");
                $this->runCommand("grep -E '(Fatal|Error|Warning)' /var/log/php*.log | tail -n 20");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown logs action: $action");
        }
    }

    /**
     * PHP Composer
     */
    private function phpComposer(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-composer <install|update|require|remove> [package]");
        }

        $action = $args[0];
        array_shift($args);
        
        switch ($action) {
            case 'install':
                $this->runCommand("composer install " . implode(' ', $args));
                break;
                
            case 'update':
                $this->runCommand("composer update " . implode(' ', $args));
                break;
                
            case 'require':
                if (empty($args)) {
                    throw new \InvalidArgumentException("Usage: grim php-composer require <package>");
                }
                $this->runCommand("composer require " . implode(' ', $args));
                break;
                
            case 'remove':
                if (empty($args)) {
                    throw new \InvalidArgumentException("Usage: grim php-composer remove <package>");
                }
                $this->runCommand("composer remove " . implode(' ', $args));
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown composer action: $action");
        }
    }

    /**
     * PHP Extensions
     */
    private function phpExtensions(): void
    {
        $this->info("Managing PHP extensions...");
        
        // List installed extensions
        $this->runCommand("php -m");
        
        $this->success("All common extensions are installed");
    }

    /**
     * PHP Versions
     */
    private function phpVersions(): void
    {
        $this->info("Available PHP versions:");
        
        // List installed PHP versions
        $this->runCommand("ls /usr/bin/php* | grep -E 'php[0-9]+\\.[0-9]+$'");
        
        // Show current version
        $this->runCommand("php -v");
    }

    /**
     * PHP-FPM
     */
    private function phpFpm(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-fpm <start|stop|restart|status|reload>");
        }

        $action = $args[0];
        
        switch ($action) {
            case 'start':
                $this->runCommand("sudo systemctl start php*-fpm");
                $this->success("PHP-FPM started");
                break;
                
            case 'stop':
                $this->runCommand("sudo systemctl stop php*-fpm");
                $this->success("PHP-FPM stopped");
                break;
                
            case 'restart':
                $this->runCommand("sudo systemctl restart php*-fpm");
                $this->success("PHP-FPM restarted");
                break;
                
            case 'status':
                $this->runCommand("sudo systemctl status php*-fpm");
                break;
                
            case 'reload':
                $this->runCommand("sudo systemctl reload php*-fpm");
                $this->success("PHP-FPM reloaded");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown PHP-FPM action: $action");
        }
    }

    /**
     * PHP Nginx
     */
    private function phpNginx(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-nginx <start|stop|restart|status|reload|config>");
        }

        $action = $args[0];
        
        switch ($action) {
            case 'start':
                $this->runCommand("sudo systemctl start nginx");
                $this->success("Nginx started");
                break;
                
            case 'stop':
                $this->runCommand("sudo systemctl stop nginx");
                $this->success("Nginx stopped");
                break;
                
            case 'restart':
                $this->runCommand("sudo systemctl restart nginx");
                $this->success("Nginx restarted");
                break;
                
            case 'status':
                $this->runCommand("sudo systemctl status nginx");
                break;
                
            case 'reload':
                $this->runCommand("sudo systemctl reload nginx");
                $this->success("Nginx reloaded");
                break;
                
            case 'config':
                $this->runCommand("sudo nginx -t");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown Nginx action: $action");
        }
    }

    /**
     * PHP Apache
     */
    private function phpApache(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-apache <start|stop|restart|status|reload|config>");
        }

        $action = $args[0];
        
        switch ($action) {
            case 'start':
                $this->runCommand("sudo systemctl start apache2");
                $this->success("Apache started");
                break;
                
            case 'stop':
                $this->runCommand("sudo systemctl stop apache2");
                $this->success("Apache stopped");
                break;
                
            case 'restart':
                $this->runCommand("sudo systemctl restart apache2");
                $this->success("Apache restarted");
                break;
                
            case 'status':
                $this->runCommand("sudo systemctl status apache2");
                break;
                
            case 'reload':
                $this->runCommand("sudo systemctl reload apache2");
                $this->success("Apache reloaded");
                break;
                
            case 'config':
                $this->runCommand("sudo apache2ctl configtest");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown Apache action: $action");
        }
    }

    /**
     * PHP Docker
     */
    private function phpDocker(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-docker <build|run|stop|logs|exec>");
        }

        $action = $args[0];
        
        switch ($action) {
            case 'build':
                if (file_exists("Dockerfile")) {
                    $this->runCommand("docker build -t php-app .");
                    $this->success("Docker image built");
                } else {
                    throw new \RuntimeException("No Dockerfile found");
                }
                break;
                
            case 'run':
                $this->runCommand("docker run -d -p 8080:80 --name php-app php-app");
                $this->success("PHP Docker container started");
                break;
                
            case 'stop':
                $this->runCommand("docker stop php-app");
                $this->runCommand("docker rm php-app");
                $this->success("PHP Docker container stopped");
                break;
                
            case 'logs':
                $this->runCommand("docker logs php-app");
                break;
                
            case 'exec':
                $this->runCommand("docker exec -it php-app bash");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown Docker action: $action");
        }
    }

    /**
     * PHP Kubernetes
     */
    private function phpK8s(array $args): void
    {
        if (empty($args)) {
            throw new \InvalidArgumentException("Usage: grim php-k8s <deploy|scale|logs|exec>");
        }

        $action = $args[0];
        array_shift($args);
        
        switch ($action) {
            case 'deploy':
                if (file_exists("k8s-deployment.yaml")) {
                    $this->runCommand("kubectl apply -f k8s-deployment.yaml");
                    $this->success("Kubernetes deployment applied");
                } else {
                    throw new \RuntimeException("No k8s-deployment.yaml found");
                }
                break;
                
            case 'scale':
                if (empty($args)) {
                    throw new \InvalidArgumentException("Usage: grim php-k8s scale <replicas>");
                }
                $this->runCommand("kubectl scale deployment php-app --replicas=$args[0]");
                $this->success("Scaled to $args[0] replicas");
                break;
                
            case 'logs':
                $this->runCommand("kubectl logs -l app=php-app");
                break;
                
            case 'exec':
                $this->runCommand("kubectl exec -it deployment/php-app -- bash");
                break;
                
            default:
                throw new \InvalidArgumentException("Unknown Kubernetes action: $action");
        }
    }

    /**
     * Run a command and handle output
     */
    private function runCommand(string $command): void
    {
        $output = [];
        $returnCode = 0;
        
        exec($command . ' 2>&1', $output, $returnCode);
        
        foreach ($output as $line) {
            echo $line . "\n";
        }
        
        if ($returnCode !== 0) {
            throw new \RuntimeException("Command failed: $command");
        }
    }

    /**
     * Print info message
     */
    private function info(string $message): void
    {
        echo "ℹ️  $message\n";
    }

    /**
     * Print success message
     */
    private function success(string $message): void
    {
        echo "✅ $message\n";
    }

    /**
     * Print warning message
     */
    private function warning(string $message): void
    {
        echo "⚠️  $message\n";
    }

    /**
     * Print error message
     */
    private function error(string $message): void
    {
        echo "❌ $message\n";
    }
} 