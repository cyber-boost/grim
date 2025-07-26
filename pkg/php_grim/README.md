# Grim Reaper 🗡️ PHP Package

[![Packagist](https://img.shields.io/packagist/v/grim/reaper)](https://packagist.org/packages/grim/reaper)
[![Downloads](https://img.shields.io/packagist/dt/grim/reaper)](https://packagist.org/packages/grim/reaper)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://grim.so/license)

**When data death comes knocking, Grim ensures resurrection is just a command away.**

Enterprise-grade data protection platform with AI-powered backup decisions, military-grade encryption, multi-algorithm compression, content-based deduplication, real-time monitoring, and automated threat response.

## 🚀 Quick Install

```bash
composer require grim/reaper
```

## 🎯 Quick Start

```php
<?php
use Grim\Reaper\GrimReaper;

// Initialize Grim Reaper
$grim = new GrimReaper();

// Quick backup
$grim->backup('/var/www/html');

// Start monitoring
$grim->monitor('/var/log');

// Health check
$health = $grim->healthCheck();
echo "System Status: " . $health->status;
```

## 📋 Complete Command Reference

All commands use the unified Grim Reaper command structure:

### 🤖 AI & Machine Learning

```bash
# AI Decision Engine
grim ai-decision init                    # Initialize AI decision engine
grim ai-decision analyze                 # Analyze files for intelligent backup decisions
grim ai-decision backup-priority         # Determine backup priorities using AI
grim ai-decision storage-optimize        # Optimize storage allocation with AI
grim ai-decision resource-manage         # Manage system resources intelligently
grim ai-decision validate                # Validate AI models and decisions
grim ai-decision report                  # Generate AI analysis report
grim ai-decision config                  # Configure AI parameters
grim ai-decision status                  # Check AI engine status

# AI Integration
grim ai init                             # Initialize AI integration framework
grim ai install                          # Install AI dependencies (TensorFlow/PyTorch)
grim ai train                            # Train AI models on your data
grim ai predict                          # Generate predictions from models
grim ai analyze                          # Analyze data patterns
grim ai optimize                         # Optimize AI performance
grim ai monitor                          # Monitor AI operations
grim ai validate                         # Validate model accuracy
grim ai report                           # Generate integration report
grim ai config                           # Configure AI integration
grim ai status                           # Check integration status

# AI Production Deployment
grim ai-deploy deploy                    # Deploy AI models to production
grim ai-deploy test                      # Run automated deployment tests
grim ai-deploy rollback                  # Rollback to previous version
grim ai-deploy monitor                   # Monitor deployed models
grim ai-deploy health                    # Check deployment health
grim ai-deploy backup                    # Backup current deployment
grim ai-deploy restore                   # Restore from backup
grim ai-deploy status                    # Check deployment status

# AI Training
grim ai-train analyze                    # Analyze training data
grim ai-train train                      # Train base models
grim ai-train predict                    # Generate predictions
grim ai-train cluster                    # Perform clustering analysis
grim ai-train extract                    # Extract features from data
grim ai-train validate                   # Validate model performance
grim ai-train report                     # Generate training report
grim ai-train neural                     # Train neural networks
grim ai-train ensemble                   # Train ensemble models
grim ai-train timeseries                 # Time series analysis
grim ai-train regression                 # Train regression models
grim ai-train classify                   # Train classification models
grim ai-train config                     # Configure training parameters
grim ai-train init                       # Initialize training environment

# AI Velocity Enhancement
grim ai-turbo turbo                      # Activate turbo mode for AI
grim ai-turbo optimize                   # Optimize AI performance
grim ai-turbo benchmark                  # Run performance benchmarks
grim ai-turbo validate                   # Validate optimizations
grim ai-turbo deploy                     # Deploy optimized models
grim ai-turbo monitor                    # Monitor performance gains
grim ai-turbo report                     # Generate performance report
```

### 💾 Backup & Recovery

```bash
# Core Backup Operations
grim backup create                       # Create intelligent backup
grim backup verify                       # Verify backup integrity
grim backup list                         # List all backups

# Core Backup Engine
grim backup-core create                  # Create core backup with progress
grim backup-core verify                  # Verify backup checksums
grim backup-core restore                 # Restore from backup
grim backup-core status                  # Check backup system status
grim backup-core init                    # Initialize backup system

# Automatic Backup Daemon
grim auto-backup start                   # Start automatic backup daemon
grim auto-backup stop                    # Stop backup daemon
grim auto-backup restart                 # Restart backup daemon
grim auto-backup status                  # Check daemon status
grim auto-backup health                  # Health check with diagnostics

# Restore Operations
grim restore recover                     # Restore from backup
grim restore list                        # List available restore points
grim restore verify                      # Verify restore integrity

# Deduplication
grim dedup dedup                         # Deduplicate files
grim dedup restore                       # Restore deduplicated files
grim dedup cleanup                       # Clean orphaned chunks
grim dedup stats                         # Show deduplication statistics
grim dedup verify                        # Verify dedup integrity
grim dedup benchmark                     # Run deduplication benchmarks
```

### 📊 System Monitoring & Health

```bash
# System Monitoring
grim monitor start                       # Start system monitoring
grim monitor stop                        # Stop monitoring
grim monitor status                      # Check monitor status
grim monitor show                        # Show current metrics
grim monitor report                      # Generate monitoring report

# Health Checking
grim health check                        # Complete health check
grim health fix                          # Auto-fix detected issues
grim health report                       # Generate health report
grim health monitor                      # Continuous health monitoring

# Enhanced Health Monitoring
grim health-check check                  # Enhanced health check
grim health-check services               # Check all services
grim health-check disk                   # Check disk health
grim health-check memory                 # Check memory status
grim health-check network                # Check network health
grim health-check fix                    # Auto-fix all issues
grim health-check report                 # Detailed health report
```

### 🔒 Security & Compliance

```bash
# Security Auditing
grim audit full                          # Complete security audit
grim audit permissions                   # Audit file permissions
grim audit compliance                    # Check compliance (CIS/STIG/NIST)
grim audit backups                       # Audit backup integrity
grim audit logs                          # Audit access logs
grim audit config                        # Audit configuration security
grim audit report                        # Generate audit report

# Security Operations
grim security scan                       # Run security scan
grim security audit                      # Deep security audit
grim security fix                        # Auto-fix vulnerabilities
grim security report                     # Generate security report
grim security monitor                    # Start security monitoring

# Security Testing
grim security-testing vulnerability      # Run vulnerability tests
grim security-testing penetration        # Run penetration tests
grim security-testing compliance         # Test compliance standards
grim security-testing report             # Generate test report

# File Encryption
grim encrypt encrypt                     # Encrypt files
grim encrypt decrypt                     # Decrypt files
grim encrypt key-gen                     # Generate encryption keys
grim encrypt verify                      # Verify encryption

# File Verification
grim verify integrity                    # Verify file integrity
grim verify checksum                     # Verify checksums
grim verify signature                    # Verify digital signatures
grim verify backup                       # Verify backup integrity

# Multi-Language Scanner
grim scanner scan                        # Multi-threaded file system scan
grim scanner info                        # Get file information and summary
grim scanner hash                        # Calculate file hashes (MD5/SHA256)
grim scanner py-scan                     # Python-based security scanning
grim scanner security                    # Security vulnerability scan
grim scanner malware                     # Malware detection scan
grim scanner vulnerability               # Deep vulnerability scan
grim scanner compliance                  # Compliance verification scan
grim scanner report                      # Generate scan report
```

### 🚀 Performance & Optimization

```bash
# High-Performance Compression
grim compression compress                # Compress with Go binary (8 algorithms)
grim compression decompress              # Decompress files
grim compression benchmark               # Run compression benchmarks
grim compression optimize                # Optimize compression
grim compression analyze                 # Analyze compression potential
grim compression list                    # List compressed files
grim compression cleanup                 # Clean temporary files

# System Optimization
grim blacksmith optimize                 # System-wide optimization
grim blacksmith maintain                 # Run maintenance tasks
grim blacksmith forge                    # Create new tools
grim blacksmith list-tools               # List available tools
grim blacksmith run-tool                 # Run specific tool
grim blacksmith schedule                 # Schedule maintenance
grim blacksmith list-scheduled           # List scheduled tasks
grim blacksmith backup-tools             # Backup custom tools
grim blacksmith restore-tools            # Restore tools
grim blacksmith update-tools             # Update all tools
grim blacksmith stats                    # Show forge statistics
grim blacksmith config                   # Configure forge

# Performance Testing
grim performance-test cpu                # Test CPU performance
grim performance-test memory             # Test memory performance
grim performance-test disk               # Test disk I/O
grim performance-test network            # Test network throughput
grim performance-test full               # Run all performance tests
grim performance-test report             # Generate performance report

# System Cleanup
grim cleanup all                         # Clean everything safely
grim cleanup backups                     # Clean old backups
grim cleanup temp                        # Clean temporary files
grim cleanup logs                        # Clean old logs
grim cleanup database                    # Clean database
grim cleanup duplicates                  # Remove duplicate files
grim cleanup report                      # Preview cleanup actions
```

### 🌐 Web Services & APIs

```bash
# Web Services
grim web start                           # Start FastAPI web server
grim web stop                            # Stop all web services
grim web restart                         # Restart web server
grim web gateway                         # Start API gateway with load balancing
grim web api                             # Start API application
grim web status                          # Show web services status

# Monitoring Dashboard
grim dashboard start                     # Start web dashboard
grim dashboard stop                      # Stop dashboard
grim dashboard restart                   # Restart dashboard
grim dashboard status                    # Check dashboard status
grim dashboard config                    # Configure dashboard
grim dashboard init                      # Initialize dashboard
grim dashboard setup                     # Run setup wizard
grim dashboard logs                      # View dashboard logs

# API Gateway
grim gateway start                       # Start API gateway
grim gateway stop                        # Stop gateway
grim gateway status                      # Gateway status
grim gateway config                      # Configure gateway
```

### ☁️ Cloud & Distributed Systems

```bash
# Cloud Platform Integration
grim cloud init                          # Initialize cloud platform
grim cloud aws                           # Deploy to AWS
grim cloud azure                         # Deploy to Azure
grim cloud gcp                           # Deploy to Google Cloud
grim cloud serverless                    # Deploy serverless functions
grim cloud comprehensive                 # Full cloud deployment

# Distributed Architecture
grim distributed init                    # Initialize distributed system
grim distributed deploy                  # Deploy microservices
grim distributed scale                   # Scale services
grim distributed balance                 # Configure load balancing
grim distributed monitor                 # Monitor distributed system

# Load Balancing
grim load-balancer start                 # Start load balancer
grim load-balancer stop                  # Stop load balancer
grim load-balancer status                # Check balancer status
grim load-balancer add-server            # Add backend server
grim load-balancer remove-server         # Remove backend server

# File Transfer (Multi-Protocol)
grim transfer upload                     # Upload files to destination
grim transfer download                   # Download files from source
grim transfer resume                     # Resume interrupted transfer
grim transfer verify                     # Verify transfer integrity
```

### 🧪 Testing & Quality Assurance

```bash
# Testing Framework
grim testing run                         # Run all tests
grim testing benchmark                   # Run benchmarks
grim testing ci                          # CI/CD test suite
grim testing report                      # Generate test report

# Quality Assurance
grim qa code-review                      # Automated code review
grim qa static-analysis                  # Static code analysis
grim qa security-scan                    # Security scanning
grim qa performance-test                 # Performance testing
grim qa integration-test                 # Integration testing
grim qa report                           # Generate QA report

# User Acceptance Testing
grim user-acceptance run                 # Run acceptance tests
grim user-acceptance generate            # Generate test scenarios
grim user-acceptance validate            # Validate user workflows
grim user-acceptance report              # Generate UAT report
```

### 🔧 System Maintenance & Operations

```bash
# Central Orchestrator (Scythe)
grim scythe harvest                      # Orchestrate all operations
grim scythe analyze                      # Analyze system state
grim scythe report                       # Generate master report
grim scythe monitor                      # Monitor all operations
grim scythe status                       # Show orchestrator status
grim scythe backup                       # Orchestrated backup operations

# Logging System
grim log init                            # Initialize logging system
grim log setup                           # Setup logger configuration
grim log event                           # Log structured event
grim log metric                          # Log performance metric
grim log rotate                          # Rotate log files
grim log cleanup                         # Clean up old log files
grim log status                          # Show logging system status
grim log tail                            # Tail log file

# Configuration Management
grim config load                         # Load configuration
grim config save                         # Save configuration
grim config get                          # Get configuration value
grim config set                          # Set configuration value
grim config validate                     # Validate configuration
```

## 🟣 PHP-Specific Integration

### Laravel Integration

```php
<?php
// config/grim.php
return [
    'backup_path' => storage_path('backups'),
    'compression' => 'zstd',
    'encryption' => true,
    'ai_enabled' => true,
    'php_specific' => [
        'monitor_logs' => true,
        'optimize_composer' => true,
        'track_sessions' => true,
        'secure_uploads' => true
    ]
];

// Service Provider - app/Providers/GrimServiceProvider.php
use Grim\Reaper\GrimReaper;
use Illuminate\Support\ServiceProvider;

class GrimServiceProvider extends ServiceProvider
{
    public function register()
    {
        $this->app->singleton(GrimReaper::class, function ($app) {
            return new GrimReaper(config('grim'));
        });
    }

    public function boot()
    {
        // Auto-backup on deployment
        if (app()->runningInConsole()) {
            $this->app[GrimReaper::class]->backup(base_path(), [
                'exclude' => ['vendor/', 'node_modules/', 'storage/logs/'],
                'laravel_specific' => true
            ]);
        }
    }
}

// Controller - app/Http/Controllers/BackupController.php
use Grim\Reaper\Facades\Grim;
use Illuminate\Http\Request;

class BackupController extends Controller
{
    public function create(Request $request)
    {
        $result = Grim::backup($request->input('path', storage_path('app')), [
            'compression' => 'zstd',
            'laravel' => [
                'include_config' => true,
                'include_migrations' => true,
                'backup_database' => true,
                'optimize_storage' => true
            ]
        ]);

        return response()->json([
            'success' => true,
            'backup_id' => $result->backupId,
            'size' => $result->compressedSize,
            'ratio' => $result->compressionRatio
        ]);
    }

    public function monitor()
    {
        Grim::monitor(storage_path('logs'), [
            'laravel' => [
                'track_queries' => true,
                'monitor_cache' => true,
                'watch_queues' => true,
                'alert_on_errors' => true
            ]
        ]);

        return response()->json(['status' => 'monitoring_started']);
    }

    public function health()
    {
        $health = Grim::healthCheck([
            'check_database' => true,
            'check_cache' => true,
            'check_queue' => true,
            'check_storage' => true,
            'laravel_specific' => true
        ]);

        return response()->json($health->toArray());
    }
}

// Artisan Command - app/Console/Commands/GrimBackup.php
use Grim\Reaper\Facades\Grim;
use Illuminate\Console\Command;

class GrimBackup extends Command
{
    protected $signature = 'grim:backup {path?} {--compress=zstd} {--encrypt}';
    protected $description = 'Create backup using Grim Reaper';

    public function handle()
    {
        $path = $this->argument('path') ?: base_path();
        
        $this->info('🗡️ Starting Laravel backup...');
        
        $result = Grim::backup($path, [
            'compression' => $this->option('compress'),
            'encryption' => $this->option('encrypt'),
            'laravel' => [
                'include_env' => false,  // Security: exclude .env
                'backup_storage' => true,
                'optimize_assets' => true,
                'include_vendor' => false
            ]
        ]);

        $this->info("✅ Backup completed: {$result->backupId}");
        $this->info("📊 Compression: {$result->compressionRatio}x");
        $this->info("💾 Size: " . $this->formatBytes($result->compressedSize));
    }

    private function formatBytes($size, $precision = 2)
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $base = log($size, 1024);
        return round(pow(1024, $base - floor($base)), $precision) . ' ' . $units[floor($base)];
    }
}
```

### Symfony Integration

```php
<?php
// config/packages/grim.yaml
grim:
    backup_path: '%kernel.project_dir%/var/backups'
    compression: 'zstd'
    encryption: true
    symfony:
        monitor_logs: true
        track_performance: true
        secure_uploads: true

// src/Service/GrimService.php
use Grim\Reaper\GrimReaper;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

class GrimService
{
    private GrimReaper $grim;

    public function __construct(
        #[Autowire('%kernel.project_dir%')] private string $projectDir
    ) {
        $this->grim = new GrimReaper([
            'backup_path' => $this->projectDir . '/var/backups',
            'compression' => 'zstd',
            'encryption' => true
        ]);
    }

    public function backupProject(array $options = []): array
    {
        return $this->grim->backup($this->projectDir, array_merge([
            'exclude' => ['var/cache/', 'var/log/', 'vendor/', 'node_modules/'],
            'symfony' => [
                'include_config' => true,
                'backup_database' => true,
                'optimize_assets' => true
            ]
        ], $options));
    }

    public function startMonitoring(): void
    {
        $this->grim->monitor($this->projectDir . '/var/log', [
            'symfony' => [
                'track_requests' => true,
                'monitor_doctrine' => true,
                'watch_security' => true
            ]
        ]);
    }
}

// src/Controller/BackupController.php
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/backup')]
class BackupController extends AbstractController
{
    public function __construct(private GrimService $grimService) {}

    #[Route('/create', methods: ['POST'])]
    public function create(): JsonResponse
    {
        $result = $this->grimService->backupProject([
            'compression' => 'zstd',
            'ai_analysis' => true
        ]);

        return $this->json([
            'success' => true,
            'backup_id' => $result['backupId'],
            'compression_ratio' => $result['compressionRatio']
        ]);
    }

    #[Route('/health', methods: ['GET'])]
    public function health(): JsonResponse
    {
        $health = $this->grimService->healthCheck();
        return $this->json($health);
    }
}
```

### WordPress Plugin Integration

```php
<?php
/**
 * Plugin Name: Grim Reaper Backup
 * Description: Enterprise backup and monitoring for WordPress
 * Version: 1.0.0
 */

require_once plugin_dir_path(__FILE__) . 'vendor/autoload.php';

use Grim\Reaper\GrimReaper;

class GrimReaperWordPress
{
    private GrimReaper $grim;

    public function __construct()
    {
        $this->grim = new GrimReaper([
            'backup_path' => WP_CONTENT_DIR . '/backups',
            'compression' => 'zstd',
            'encryption' => true
        ]);

        add_action('admin_menu', [$this, 'addAdminMenu']);
        add_action('wp_ajax_grim_backup', [$this, 'handleBackup']);
        add_action('wp_ajax_grim_health', [$this, 'handleHealth']);
        
        // Auto-backup on plugin/theme updates
        add_action('upgrader_process_complete', [$this, 'autoBackup']);
    }

    public function addAdminMenu()
    {
        add_management_page(
            'Grim Reaper Backup',
            'Grim Backup',
            'manage_options',
            'grim-backup',
            [$this, 'adminPage']
        );
    }

    public function handleBackup()
    {
        check_ajax_referer('grim_backup_nonce');

        $result = $this->grim->backup(ABSPATH, [
            'exclude' => [
                'wp-content/cache/',
                'wp-content/backups/',
                '*.log'
            ],
            'wordpress' => [
                'backup_database' => true,
                'backup_uploads' => true,
                'backup_themes' => true,
                'backup_plugins' => true,
                'optimize_media' => true
            ]
        ]);

        wp_send_json_success([
            'backup_id' => $result['backupId'],
            'size' => size_format($result['compressedSize']),
            'ratio' => $result['compressionRatio']
        ]);
    }

    public function handleHealth()
    {
        check_ajax_referer('grim_health_nonce');

        $health = $this->grim->healthCheck([
            'wordpress' => [
                'check_database' => true,
                'check_plugins' => true,
                'check_themes' => true,
                'check_uploads' => true,
                'check_updates' => true
            ]
        ]);

        wp_send_json_success($health);
    }

    public function autoBackup()
    {
        // Automatic backup after updates
        wp_schedule_single_event(time() + 60, 'grim_auto_backup');
    }

    public function adminPage()
    {
        ?>
        <div class="wrap">
            <h1>🗡️ Grim Reaper Backup</h1>
            <div id="grim-dashboard">
                <div class="card">
                    <h2>System Health</h2>
                    <button id="check-health" class="button button-secondary">Check Health</button>
                    <div id="health-status"></div>
                </div>
                <div class="card">
                    <h2>Backup Operations</h2>
                    <button id="create-backup" class="button button-primary">Create Backup</button>
                    <div id="backup-status"></div>
                </div>
            </div>
        </div>
        
        <script>
        jQuery(document).ready(function($) {
            $('#create-backup').click(function() {
                $.post(ajaxurl, {
                    action: 'grim_backup',
                    _ajax_nonce: '<?php echo wp_create_nonce('grim_backup_nonce'); ?>'
                }, function(response) {
                    if (response.success) {
                        $('#backup-status').html('✅ Backup completed: ' + response.data.backup_id);
                    }
                });
            });

            $('#check-health').click(function() {
                $.post(ajaxurl, {
                    action: 'grim_health',
                    _ajax_nonce: '<?php echo wp_create_nonce('grim_health_nonce'); ?>'
                }, function(response) {
                    if (response.success) {
                        $('#health-status').html('Status: ' + response.data.status);
                    }
                });
            });
        });
        </script>
        <?php
    }
}

new GrimReaperWordPress();
```

### Generic PHP Integration

```php
<?php
use Grim\Reaper\GrimReaper;

// Initialize with custom configuration
$grim = new GrimReaper([
    'backup_path' => '/opt/backups',
    'compression_algorithm' => 'zstd',
    'encryption_enabled' => true,
    'ai_analysis' => true,
    'max_concurrent_operations' => 4
]);

// Advanced backup with PHP-specific options
function backupPhpProject($projectPath, $grim)
{
    try {
        $result = $grim->backup($projectPath, [
            'exclude_patterns' => [
                'vendor/', 'node_modules/', '.git/',
                'storage/logs/', 'cache/', 'tmp/',
                '*.log', '.env', '.env.*'
            ],
            'php_specific' => [
                'analyze_composer' => true,      // Analyze composer.json dependencies
                'include_autoload' => true,      // Include autoload information
                'check_syntax' => true,          // Validate PHP syntax
                'optimize_classes' => true,      // Optimize class loading
                'backup_sessions' => false,      // Exclude session files (security)
                'scan_vulnerabilities' => true   // Scan for known vulnerabilities
            ],
            'compression' => 'zstd',
            'encryption' => true
        ]);

        echo "✅ PHP project backup completed:\n";
        echo "   ID: {$result['backupId']}\n";
        echo "   Original size: " . formatBytes($result['originalSize']) . "\n";
        echo "   Compressed size: " . formatBytes($result['compressedSize']) . "\n";
        echo "   Compression ratio: {$result['compressionRatio']}x\n";
        echo "   Files backed up: {$result['filesCount']}\n";

        return $result;
    } catch (Exception $e) {
        echo "❌ Backup failed: " . $e->getMessage() . "\n";
        throw $e;
    }
}

// Monitor PHP application with specialized tracking
function monitorPhpApp($appPath, $grim)
{
    try {
        $monitorConfig = [
            'watch_patterns' => ['*.php', '*.json', '*.xml', '*.yaml', '*.yml'],
            'php_specific' => [
                'track_errors' => true,          // Monitor PHP errors
                'track_performance' => true,     // Monitor execution time
                'track_memory_usage' => true,    // Monitor memory consumption
                'track_database_queries' => true, // Monitor database performance
                'alert_on_fatal_errors' => true, // Alert on fatal errors
                'log_security_events' => true,   // Log security-related events
                'monitor_file_uploads' => true,  // Monitor file upload activities
                'track_session_usage' => true    // Track session management
            ],
            'alert_thresholds' => [
                'memory_usage' => 128 * 1024 * 1024, // 128MB
                'execution_time' => 30,              // 30 seconds
                'error_rate' => 10                   // 10 errors per minute
            ]
        ];

        $grim->monitor($appPath, $monitorConfig);
        echo "🔍 Monitoring started for PHP app: $appPath\n";

        // Set up error handling
        set_error_handler(function($severity, $message, $file, $line) use ($grim) {
            $grim->logEvent('php_error', [
                'severity' => $severity,
                'message' => $message,
                'file' => $file,
                'line' => $line,
                'timestamp' => date('Y-m-d H:i:s')
            ]);
        });

    } catch (Exception $e) {
        echo "❌ Monitoring failed: " . $e->getMessage() . "\n";
        throw $e;
    }
}

// Health check with PHP-specific diagnostics
function phpHealthCheck($grim)
{
    try {
        $health = $grim->healthCheck([
            'check_php_version' => true,
            'check_extensions' => true,
            'check_composer_packages' => true,
            'check_file_permissions' => true,
            'check_memory_limits' => true,
            'check_security_settings' => true,
            'validate_configuration' => true
        ]);

        echo "🟣 PHP Environment Health Check:\n";
        echo "   Overall Status: {$health['overall_status']}\n";
        echo "   PHP Version: {$health['php_version']}\n";
        echo "   Memory Limit: {$health['memory_limit']}\n";
        echo "   Max Execution Time: {$health['max_execution_time']}\n";
        echo "   Loaded Extensions: " . count($health['loaded_extensions']) . "\n";
        echo "   Security Issues: " . count($health['security_issues']) . "\n";

        if (!empty($health['security_issues'])) {
            echo "\n🔒 Security Issues:\n";
            foreach (array_slice($health['security_issues'], 0, 5) as $issue) {
                echo "   • {$issue['type']}: {$issue['description']}\n";
            }
        }

        if (!empty($health['recommendations'])) {
            echo "\n💡 Recommendations:\n";
            foreach ($health['recommendations'] as $rec) {
                echo "   • $rec\n";
            }
        }

        return $health;
    } catch (Exception $e) {
        echo "❌ Health check failed: " . $e->getMessage() . "\n";
        throw $e;
    }
}

// Utility function to format bytes
function formatBytes($size, $precision = 2)
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $base = log($size, 1024);
    return round(pow(1024, $base - floor($base)), $precision) . ' ' . $units[floor($base)];
}

// Example usage
try {
    $projectPath = '/var/www/html';

    // Backup the PHP project
    echo "🗡️ Starting PHP project backup...\n";
    $backupResult = backupPhpProject($projectPath, $grim);

    // Start monitoring
    echo "\n🔍 Starting project monitoring...\n";
    monitorPhpApp($projectPath, $grim);

    // Check system health
    echo "\n🏥 Checking system health...\n";
    $health = phpHealthCheck($grim);

    // AI-powered analysis
    if ($health['overall_status'] === 'healthy') {
        echo "\n🤖 Running AI analysis...\n";
        $analysis = $grim->aiAnalyze($projectPath, [
            'analyze_code_quality' => true,
            'detect_patterns' => true,
            'suggest_optimizations' => true,
            'assess_security' => true
        ]);

        echo "   Code Quality Score: {$analysis['quality_score']}/100\n";
        echo "   Security Score: {$analysis['security_score']}/100\n";
        echo "   Backup Priority: {$analysis['backup_priority']}\n";
    }

    echo "\n✅ All operations completed successfully!\n";

} catch (Exception $e) {
    echo "\n❌ Operation failed: " . $e->getMessage() . "\n";
    exit(1);
}
```

## 🔗 Links & Resources

- **Website**: [grim.so](https://grim.so)
- **GitHub**: [github.com/cyber-boost/grim](https://github.com/cyber-boost/grim)
- **Download**: [get.grim.so](https://get.grim.so)
- **Packagist**: [packagist.org/packages/grim/reaper](https://packagist.org/packages/grim/reaper)
- **Documentation**: [grim.so/docs](https://grim.so/docs)

## 📄 License

By using this software you agree to the official license available at https://grim.so/license

---

<div align="center">
<strong>🗡️ GRIM REAPER</strong><br>
<i>"When data death comes knocking, resurrection is just a command away"</i>
</div>