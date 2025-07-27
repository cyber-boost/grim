<?php

/**
 * Grim CLI - Command Line Interface for Grim Reaper
 * Provides monitoring and analytics commands for user CLI installations
 *
 * @copyright 2025 Bernie Gengel and CyberBoost LLC
 * @license MIT License - see LICENSE file for full terms
 * @package GrimReaper
 */

namespace GrimReaper;

use GrimReaper\Monitoring\StorageAnalyticsDashboard;
use GrimReaper\Monitoring\RealTimeAlertingSystem;
use GrimReaper\Monitoring\PerformanceMonitor;
use GrimReaper\Monitoring\SLAMonitor;
use GrimReaper\Analytics\CostForecaster;
use GrimReaper\Analytics\UsagePatternAnalyzer;
class GrimCLI
{
    private StorageAnalyticsDashboard $dashboard;
    private RealTimeAlertingSystem $alertingSystem;
    private PerformanceMonitor $performanceMonitor;
    private SLAMonitor $slaMonitor;
    private CostForecaster $costForecaster;
    private UsagePatternAnalyzer $patternAnalyzer;

    public function __construct()
    {
        $this->dashboard = new StorageAnalyticsDashboard();
        $this->alertingSystem = new RealTimeAlertingSystem();
        $this->performanceMonitor = new PerformanceMonitor();
        $this->slaMonitor = new SLAMonitor();
        $this->costForecaster = new CostForecaster();
        $this->patternAnalyzer = new UsagePatternAnalyzer();
    }

    /**
     * Main CLI entry point
     */
    public function run(array $args): void
    {
        $command = $args[1] ?? 'help';
        $subcommand = $args[2] ?? '';
        $options = array_slice($args, 3);

        switch ($command) {
            case 'monitor':
                $this->handleMonitorCommand($subcommand, $options);
                break;
            case 'analytics':
                $this->handleAnalyticsCommand($subcommand, $options);
                break;
            case 'alerts':
                $this->handleAlertsCommand($subcommand, $options);
                break;
            case 'optimize':
                $this->handleOptimizeCommand($subcommand, $options);
                break;
            case 'health':
                $this->handleHealthCommand($subcommand, $options);
                break;
            case 'help':
            default:
                $this->showHelp();
                break;
        }
    }

    /**
     * Handle monitor commands
     */
    private function handleMonitorCommand(string $subcommand, array $options): void
    {
        switch ($subcommand) {
            case 'dashboard':
                $this->showDashboard();
                break;
            case 'performance':
                $this->showPerformance();
                break;
            case 'sla':
                $this->showSLA();
                break;
            case 'live':
                $this->showLiveMonitoring();
                break;
            default:
                echo "Available monitor commands:\n";
                echo "  dashboard   - Show monitoring dashboard\n";
                echo "  performance - Show performance metrics\n";
                echo "  sla         - Show SLA compliance\n";
                echo "  live        - Show live monitoring data\n";
                break;
        }
    }

    /**
     * Handle analytics commands
     */
    private function handleAnalyticsCommand(string $subcommand, array $options): void
    {
        switch ($subcommand) {
            case 'cost':
                $this->showCostAnalysis();
                break;
            case 'usage':
                $this->showUsagePatterns();
                break;
            case 'forecast':
                $this->showCostForecast();
                break;
            case 'efficiency':
                $this->showStorageEfficiency();
                break;
            default:
                echo "Available analytics commands:\n";
                echo "  cost       - Show cost analysis\n";
                echo "  usage      - Show usage patterns\n";
                echo "  forecast   - Show cost forecast\n";
                echo "  efficiency - Show storage efficiency\n";
                break;
        }
    }

    /**
     * Handle alerts commands
     */
    private function handleAlertsCommand(string $subcommand, array $options): void
    {
        switch ($subcommand) {
            case 'list':
                $this->showActiveAlerts();
                break;
            case 'acknowledge':
                $alertId = $options[0] ?? '';
                if ($alertId) {
                    $this->acknowledgeAlert($alertId);
                } else {
                    echo "Usage: grim alerts acknowledge <alert_id>\n";
                }
                break;
            case 'history':
                $this->showAlertHistory();
                break;
            default:
                echo "Available alerts commands:\n";
                echo "  list         - Show active alerts\n";
                echo "  acknowledge  - Acknowledge an alert\n";
                echo "  history      - Show alert history\n";
                break;
        }
    }

    /**
     * Handle optimize commands
     */
    private function handleOptimizeCommand(string $subcommand, array $options): void
    {
        switch ($subcommand) {
            case 'run':
                $this->runOptimization();
                break;
            case 'recommendations':
                $this->showOptimizationRecommendations();
                break;
            case 'status':
                $this->showOptimizationStatus();
                break;
            default:
                echo "Available optimize commands:\n";
                echo "  run            - Run storage optimization\n";
                echo "  recommendations - Show optimization recommendations\n";
                echo "  status         - Show optimization status\n";
                break;
        }
    }

    /**
     * Handle health commands
     */
    private function handleHealthCommand(string $subcommand, array $options): void
    {
        switch ($subcommand) {
            case 'check':
                $this->showHealthCheck();
                break;
            case 'status':
                $this->showSystemStatus();
                break;
            default:
                echo "Available health commands:\n";
                echo "  check  - Run health check\n";
                echo "  status - Show system status\n";
                break;
        }
    }

    /**
     * Show monitoring dashboard
     */
    private function showDashboard(): void
    {
        echo "📊 Grim Reaper Monitoring Dashboard\n";
        echo "====================================\n\n";

        $overviewMetrics = $this->dashboard->getOverviewMetrics();
        
        echo "📈 Overview Metrics:\n";
        echo "  Total Storage: " . $this->formatBytes($overviewMetrics['total_storage']) . "\n";
        echo "  Total Cost: $" . number_format($overviewMetrics['total_cost'], 2) . "\n";
        echo "  Efficiency Score: " . number_format($overviewMetrics['efficiency_score'] * 100, 1) . "%\n";
        echo "  Optimization Score: " . number_format($overviewMetrics['optimization_score'] * 100, 1) . "%\n";
        echo "  Performance Score: " . number_format($overviewMetrics['performance_score'] * 100, 1) . "%\n\n";

        $tierBreakdown = $this->dashboard->getTierBreakdownAnalytics();
        echo "🗂️  Tier Breakdown:\n";
        foreach ($tierBreakdown as $tier => $data) {
            echo "  {$tier}: " . $this->formatBytes($data['storage_used']) . " / " . $this->formatBytes($data['storage_limit']) . " (" . number_format($data['usage_percentage'], 1) . "%)\n";
        }
        echo "\n";

        $providerPerformance = $this->dashboard->getProviderPerformanceMetrics();
        echo "🏢 Provider Performance:\n";
        foreach ($providerPerformance as $provider => $metrics) {
            echo "  {$provider}: " . number_format($metrics['uptime'], 2) . "% uptime, " . number_format($metrics['response_time'], 1) . "ms response\n";
        }
    }

    /**
     * Show performance metrics
     */
    private function showPerformance(): void
    {
        echo "⚡ Performance Metrics\n";
        echo "======================\n\n";

        $performanceMetrics = $this->performanceMonitor->monitorPerformance();
        
        $apiMetrics = $performanceMetrics['api_performance'];
        echo "🌐 API Performance:\n";
        echo "  Response Time: " . number_format($apiMetrics['average_response_time'], 2) . "ms\n";
        echo "  Requests/sec: " . number_format($apiMetrics['requests_per_second'], 1) . "\n";
        echo "  Error Rate: " . number_format($apiMetrics['error_rate'] * 100, 2) . "%\n";
        echo "  Uptime: " . number_format($apiMetrics['uptime_percentage'], 2) . "%\n\n";

        $storageMetrics = $performanceMetrics['storage_performance'];
        echo "💾 Storage Performance:\n";
        echo "  IOPS: " . number_format($storageMetrics['average_iops']) . "\n";
        echo "  Throughput: " . number_format($storageMetrics['average_throughput'], 1) . " MB/s\n";
        echo "  Latency: " . number_format($storageMetrics['average_latency'], 2) . "ms\n";
        echo "  Cache Hit Rate: " . number_format($storageMetrics['cache_hit_rate'] * 100, 1) . "%\n\n";

        $performanceScore = $this->performanceMonitor->calculatePerformanceScore();
        echo "📊 Overall Performance Score: " . number_format($performanceScore * 100, 1) . "%\n";
    }

    /**
     * Show SLA compliance
     */
    private function showSLA(): void
    {
        echo "📋 SLA Compliance\n";
        echo "=================\n\n";

        $slaReport = $this->slaMonitor->monitorSLACompliance();
        
        $uptimeMonitoring = $slaReport['uptime_monitoring'];
        echo "⏰ Uptime Monitoring:\n";
        echo "  Current Uptime: " . number_format($uptimeMonitoring['current_uptime'], 3) . "%\n";
        echo "  Target Uptime: " . number_format($uptimeMonitoring['target_uptime'], 1) . "%\n";
        echo "  Status: " . strtoupper($uptimeMonitoring['compliance_status']) . "\n\n";

        $responseTimeMonitoring = $slaReport['response_time_monitoring'];
        echo "⚡ Response Time Monitoring:\n";
        echo "  Current Response Time: " . number_format($responseTimeMonitoring['current_response_time'], 2) . "ms\n";
        echo "  Target Response Time: " . number_format($responseTimeMonitoring['target_response_time'], 0) . "ms\n";
        echo "  Status: " . strtoupper($responseTimeMonitoring['compliance_status']) . "\n\n";

        $violations = $slaReport['sla_violations'];
        echo "🚨 SLA Violations:\n";
        echo "  Total Violations: " . $violations['violation_count'] . "\n";
        echo "  Critical: " . $violations['critical_violations'] . "\n";
        echo "  Warnings: " . $violations['warning_violations'] . "\n";
    }

    /**
     * Show active alerts
     */
    private function showActiveAlerts(): void
    {
        echo "🚨 Active Alerts\n";
        echo "================\n\n";

        $alerts = $this->alertingSystem->getActiveAlerts();
        
        if (empty($alerts)) {
            echo "✅ No active alerts\n";
            return;
        }

        foreach ($alerts as $alert) {
            $severity = strtoupper($alert['severity']);
            $severityColor = $alert['severity'] === 'critical' ? '🔴' : '🟡';
            
            echo "{$severityColor} [{$severity}] {$alert['message']}\n";
            echo "   Type: {$alert['type']}\n";
            echo "   Time: " . date('Y-m-d H:i:s', $alert['timestamp']) . "\n";
            if (isset($alert['user_id'])) {
                echo "   User: {$alert['user_id']}\n";
            }
            echo "\n";
        }
    }

    /**
     * Show cost analysis
     */
    private function showCostAnalysis(): void
    {
        echo "💰 Cost Analysis\n";
        echo "================\n\n";

        $costAnalysis = $this->dashboard->getCostOptimizationAnalytics();
        
        echo "📊 Current Costs:\n";
        echo "  Total Monthly Cost: $" . number_format($costAnalysis['total_monthly_cost'], 2) . "\n";
        echo "  Cost per GB: $" . number_format($costAnalysis['cost_per_gb'], 3) . "\n";
        echo "  Cost Efficiency Score: " . number_format($costAnalysis['cost_efficiency_score'] * 100, 1) . "%\n\n";

        echo "🎯 Optimization Opportunities:\n";
        foreach ($costAnalysis['optimization_opportunities'] as $opportunity) {
            echo "  • {$opportunity['description']}\n";
            echo "    Potential Savings: $" . number_format($opportunity['potential_savings'], 2) . "\n";
        }
    }

    /**
     * Show usage patterns
     */
    private function showUsagePatterns(): void
    {
        echo "📈 Usage Pattern Analysis\n";
        echo "=========================\n\n";

        $patternAnalysis = $this->patternAnalyzer->analyzeUsagePatterns();
        
        $accessPatterns = $patternAnalysis['access_patterns'];
        echo "🔍 Access Patterns:\n";
        echo "  Hot Data Ratio: " . number_format($accessPatterns['hot_data_ratio'] * 100, 1) . "%\n";
        echo "  Warm Data Ratio: " . number_format($accessPatterns['warm_data_ratio'] * 100, 1) . "%\n";
        echo "  Cold Data Ratio: " . number_format($accessPatterns['cold_data_ratio'] * 100, 1) . "%\n\n";

        $storagePatterns = $patternAnalysis['storage_patterns'];
        echo "💾 Storage Patterns:\n";
        echo "  Growth Rate: " . number_format($storagePatterns['storage_growth'] * 100, 1) . "% per month\n";
        echo "  Storage Efficiency: " . number_format($storagePatterns['storage_efficiency'] * 100, 1) . "%\n\n";

        $predictiveInsights = $patternAnalysis['predictive_insights'];
        echo "🔮 Predictive Insights:\n";
        foreach ($predictiveInsights['usage_forecast'] as $period => $forecast) {
            echo "  {$period}: " . $this->formatBytes($forecast) . " predicted usage\n";
        }
    }

    /**
     * Show cost forecast
     */
    private function showCostForecast(): void
    {
        echo "🔮 Cost Forecast\n";
        echo "================\n\n";

        $forecast = $this->costForecaster->generateCostForecast();
        
        $monthlyForecast = $forecast['monthly_forecast'];
        echo "📅 Monthly Forecast:\n";
        foreach (array_slice($monthlyForecast, 0, 6) as $month => $data) {
            echo "  {$month}: $" . number_format($data['predicted_cost'], 2) . " (Growth: " . number_format($data['growth_rate'] * 100, 1) . "%)\n";
        }
        echo "\n";

        $annualForecast = $forecast['annual_forecast'];
        echo "📊 Annual Forecast:\n";
        echo "  Predicted Annual Cost: $" . number_format($annualForecast['predicted_annual_cost'], 2) . "\n";
        echo "  Growth Rate: " . number_format($annualForecast['growth_rate'] * 100, 1) . "%\n";
        echo "  Risk Level: " . strtoupper($annualForecast['risk_level']) . "\n";
    }

    /**
     * Show storage efficiency
     */
    private function showStorageEfficiency(): void
    {
        echo "💾 Storage Efficiency Report\n";
        echo "============================\n\n";

        $efficiencyReport = $this->dashboard->getStorageEfficiencyReport();
        
        $dedupMetrics = $efficiencyReport['deduplication_metrics'];
        echo "🔄 Deduplication:\n";
        echo "  Duplicate Files: " . number_format($dedupMetrics['total_duplicates_found']) . "\n";
        echo "  Duplicate Size: " . $this->formatBytes($dedupMetrics['duplicate_size']) . "\n";
        echo "  Potential Savings: " . $this->formatBytes($dedupMetrics['potential_savings']) . "\n";
        echo "  Deduplication Ratio: " . number_format($dedupMetrics['deduplication_ratio'] * 100, 1) . "%\n\n";

        $compressionMetrics = $efficiencyReport['compression_metrics'];
        echo "🗜️  Compression:\n";
        echo "  Compression Ratio: " . number_format($compressionMetrics['compression_ratio'] * 100, 1) . "%\n";
        echo "  Space Saved: " . $this->formatBytes($compressionMetrics['space_saved']) . "\n\n";

        $tierEfficiency = $efficiencyReport['tier_efficiency'];
        echo "📊 Tier Efficiency:\n";
        echo "  Hot Data Ratio: " . number_format($tierEfficiency['hot_data_ratio'] * 100, 1) . "%\n";
        echo "  Cold Data Ratio: " . number_format($tierEfficiency['cold_data_ratio'] * 100, 1) . "%\n";
        echo "  Tier Optimization Score: " . number_format($tierEfficiency['tier_optimization_score'] * 100, 1) . "%\n";
    }

    /**
     * Run optimization
     */
    private function runOptimization(): void
    {
        echo "⚙️  Running Storage Optimization...\n";
        echo "==================================\n\n";

        $optimizationJob = new \GrimReaper\StorageOptimizationJob();
        $result = $optimizationJob->runAutomatedOptimization();
        
        if ($result['success']) {
            echo "✅ Optimization completed successfully!\n";
            echo "  Optimizations performed: " . $result['optimizations_count'] . "\n";
            echo "  Potential savings: $" . number_format($result['potential_savings'], 2) . "\n";
            echo "  Execution time: " . number_format($result['execution_time'], 2) . " seconds\n";
        } else {
            echo "❌ Optimization failed: " . $result['error'] . "\n";
        }
    }

    /**
     * Show optimization recommendations
     */
    private function showOptimizationRecommendations(): void
    {
        echo "💡 Optimization Recommendations\n";
        echo "===============================\n\n";

        $efficiencyReport = $this->dashboard->getStorageEfficiencyReport();
        $recommendations = $efficiencyReport['recommendations'];
        
        foreach ($recommendations as $rec) {
            echo "🔸 {$rec['type']} (Priority: " . strtoupper($rec['priority']) . ")\n";
            echo "   {$rec['message']}\n";
            echo "   Potential Savings: $" . number_format($rec['potential_savings'], 2) . "\n";
            echo "   Implementation Effort: " . strtoupper($rec['implementation_effort']) . "\n\n";
        }
    }

    /**
     * Show optimization status
     */
    private function showOptimizationStatus(): void
    {
        echo "📊 Optimization Status\n";
        echo "======================\n\n";

        $optimizationJob = new \GrimReaper\StorageOptimizationJob();
        $history = $optimizationJob->getOptimizationHistory();
        
        echo "🕒 Recent Optimizations:\n";
        foreach (array_slice($history, -5) as $entry) {
            echo "  " . date('Y-m-d H:i:s', $entry['timestamp']) . " - " . $entry['optimizations_count'] . " optimizations, $" . number_format($entry['potential_savings'], 2) . " savings\n";
        }
    }

    /**
     * Show health check
     */
    private function showHealthCheck(): void
    {
        echo "🏥 System Health Check\n";
        echo "======================\n\n";

        $health = $this->slaMonitor->getHealthStatus();
        
        echo "📊 Overall Health: " . strtoupper($health['monitoring_status']) . "\n";
        echo "  Last Check: " . $health['last_check'] . "\n\n";

        $services = $health['services'] ?? [];
        echo "🔧 Service Status:\n";
        foreach ($services as $service => $status) {
            $icon = $status === 'active' ? '✅' : '❌';
            echo "  {$icon} {$service}: {$status}\n";
        }
    }

    /**
     * Show system status
     */
    private function showSystemStatus(): void
    {
        echo "📈 System Status\n";
        echo "================\n\n";

        $performanceMetrics = $this->performanceMonitor->monitorPerformance();
        $systemHealth = $performanceMetrics['system_health'];
        
        echo "💻 System Resources:\n";
        echo "  CPU Usage: " . number_format($systemHealth['cpu_usage'] * 100, 1) . "%\n";
        echo "  Memory Usage: " . number_format($systemHealth['memory_usage'] * 100, 1) . "%\n";
        echo "  Disk Usage: " . number_format($systemHealth['disk_usage'] * 100, 1) . "%\n";
        echo "  Network Usage: " . number_format($systemHealth['network_usage'] * 100, 1) . "%\n";
        echo "  Health Score: " . number_format($systemHealth['health_score'] * 100, 1) . "%\n\n";

        $loadAverage = $systemHealth['load_average'];
        echo "⚡ Load Average:\n";
        echo "  1 min: " . $loadAverage['1min'] . "\n";
        echo "  5 min: " . $loadAverage['5min'] . "\n";
        echo "  15 min: " . $loadAverage['15min'] . "\n";
    }

    /**
     * Acknowledge an alert
     */
    private function acknowledgeAlert(string $alertId): void
    {
        $result = $this->alertingSystem->acknowledgeAlert($alertId, 1); // User ID 1 for CLI
        
        if ($result) {
            echo "✅ Alert {$alertId} acknowledged successfully\n";
        } else {
            echo "❌ Failed to acknowledge alert {$alertId}\n";
        }
    }

    /**
     * Show alert history
     */
    private function showAlertHistory(): void
    {
        echo "📜 Alert History\n";
        echo "================\n\n";

        $stats = $this->alertingSystem->getAlertStatistics();
        
        echo "📊 Alert Statistics:\n";
        echo "  Total Alerts: " . $stats['total_alerts'] . "\n";
        echo "  Active Alerts: " . $stats['active_alerts'] . "\n";
        echo "  Resolved Alerts: " . $stats['resolved_alerts'] . "\n";
        echo "  Critical Alerts: " . $stats['critical_alerts'] . "\n";
        echo "  Warning Alerts: " . $stats['warning_alerts'] . "\n\n";

        echo "📈 Alerts by Type:\n";
        foreach ($stats['alerts_by_type'] as $type => $count) {
            echo "  {$type}: {$count}\n";
        }
    }

    /**
     * Show live monitoring
     */
    private function showLiveMonitoring(): void
    {
        echo "📡 Live Monitoring (Press Ctrl+C to stop)\n";
        echo "========================================\n\n";

        $startTime = time();
        
        while (true) {
            $currentTime = time();
            $uptime = $currentTime - $startTime;
            
            // Clear screen (works on most terminals)
            system('clear');
            
            echo "📡 Live Monitoring (Running for " . gmdate('H:i:s', $uptime) . ")\n";
            echo "========================================\n\n";

            $performanceMetrics = $this->performanceMonitor->monitorPerformance();
            $apiMetrics = $performanceMetrics['api_performance'];
            
            echo "🌐 API Performance:\n";
            echo "  Response Time: " . number_format($apiMetrics['average_response_time'], 2) . "ms\n";
            echo "  Requests/sec: " . number_format($apiMetrics['requests_per_second'], 1) . "\n";
            echo "  Error Rate: " . number_format($apiMetrics['error_rate'] * 100, 2) . "%\n";
            echo "  Uptime: " . number_format($apiMetrics['uptime_percentage'], 2) . "%\n\n";

            $alerts = $this->alertingSystem->getActiveAlerts();
            echo "🚨 Active Alerts: " . count($alerts) . "\n";
            
            if (!empty($alerts)) {
                foreach (array_slice($alerts, 0, 3) as $alert) {
                    $severity = strtoupper($alert['severity']);
                    echo "  [{$severity}] {$alert['message']}\n";
                }
            }

            echo "\nLast updated: " . date('H:i:s') . "\n";
            
            sleep(5); // Update every 5 seconds
        }
    }

    /**
     * Show help
     */
    private function showHelp(): void
    {
        echo "Grim Reaper CLI - Monitoring & Analytics\n";
        echo "=========================================\n\n";
        echo "Usage: grim <command> [subcommand] [options]\n\n";
        echo "Commands:\n";
        echo "  monitor    - Monitoring commands\n";
        echo "  analytics  - Analytics commands\n";
        echo "  alerts     - Alert management\n";
        echo "  optimize   - Storage optimization\n";
        echo "  health     - Health checks\n";
        echo "  help       - Show this help\n\n";
        echo "Examples:\n";
        echo "  grim monitor dashboard     - Show monitoring dashboard\n";
        echo "  grim analytics cost        - Show cost analysis\n";
        echo "  grim alerts list           - Show active alerts\n";
        echo "  grim optimize run          - Run storage optimization\n";
        echo "  grim health check          - Run health check\n";
    }

    /**
     * Format bytes to human readable format
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        
        $bytes /= pow(1024, $pow);
        
        return round($bytes, 2) . ' ' . $units[$pow];
    }
} 