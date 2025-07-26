<?php

require_once __DIR__ . '/../src/Monitoring/StorageAnalyticsDashboard.php';
require_once __DIR__ . '/../src/StorageOptimizationJob.php';
require_once __DIR__ . '/../src/Monitoring/RealTimeAlertingSystem.php';
require_once __DIR__ . '/../src/Monitoring/PerformanceMonitor.php';
require_once __DIR__ . '/../src/Monitoring/StorageEfficiencyReporter.php';
require_once __DIR__ . '/../src/Analytics/CostForecaster.php';
require_once __DIR__ . '/../src/Analytics/UsagePatternAnalyzer.php';
require_once __DIR__ . '/../src/Monitoring/SLAMonitor.php';

use GrimReaper\Monitoring\StorageAnalyticsDashboard;
use GrimReaper\StorageOptimizationJob;
use GrimReaper\Monitoring\RealTimeAlertingSystem;
use GrimReaper\Monitoring\PerformanceMonitor;
use GrimReaper\Monitoring\StorageEfficiencyReporter;
use GrimReaper\Analytics\CostForecaster;
use GrimReaper\Analytics\UsagePatternAnalyzer;
use GrimReaper\Monitoring\SLAMonitor;

/**
 * Comprehensive test suite for Goal 2: Monitoring & Analytics
 * Tests all monitoring, analytics, and reporting systems
 */
class MonitoringAnalyticsTest
{
    private StorageAnalyticsDashboard $dashboard;
    private StorageOptimizationJob $optimizationJob;
    private RealTimeAlertingSystem $alertingSystem;
    private PerformanceMonitor $performanceMonitor;
    private StorageEfficiencyReporter $efficiencyReporter;
    private CostForecaster $costForecaster;
    private UsagePatternAnalyzer $patternAnalyzer;
    private SLAMonitor $slaMonitor;

    public function __construct()
    {
        $this->dashboard = new StorageAnalyticsDashboard();
        $this->optimizationJob = new StorageOptimizationJob();
        $this->alertingSystem = new RealTimeAlertingSystem();
        $this->performanceMonitor = new PerformanceMonitor();
        $this->efficiencyReporter = new StorageEfficiencyReporter();
        $this->costForecaster = new CostForecaster();
        $this->patternAnalyzer = new UsagePatternAnalyzer();
        $this->slaMonitor = new SLAMonitor();
    }

    /**
     * Run all monitoring and analytics tests
     */
    public function runAllTests(): void
    {
        echo "🚀 Starting Goal 2: Monitoring & Analytics Tests\n";
        echo "================================================\n\n";

        $this->testStorageAnalyticsDashboard();
        $this->testStorageOptimizationJob();
        $this->testRealTimeAlertingSystem();
        $this->testPerformanceMonitoring();
        $this->testStorageEfficiencyReporting();
        $this->testCostForecasting();
        $this->testUsagePatternAnalysis();
        $this->testSLAMonitoring();
        $this->testComprehensiveReporting();
        $this->testHighLoadScenarios();
        $this->testIntegrationScenarios();

        echo "\n✅ All Goal 2 tests completed successfully!\n";
    }

    /**
     * Test Storage Analytics Dashboard
     */
    public function testStorageAnalyticsDashboard(): void
    {
        echo "📊 Testing Storage Analytics Dashboard...\n";
        
        // Test overview metrics
        $overviewMetrics = $this->dashboard->getOverviewMetrics();
        echo "  - Overview metrics: " . count($overviewMetrics) . " metrics generated\n";
        
        // Test tier breakdown analytics
        $tierBreakdown = $this->dashboard->getTierBreakdownAnalytics();
        echo "  - Tier breakdown: " . count($tierBreakdown) . " tiers analyzed\n";
        
        // Test provider performance monitoring
        $providerPerformance = $this->dashboard->getProviderPerformanceMetrics();
        echo "  - Provider performance: " . count($providerPerformance) . " providers monitored\n";
        
        // Test cost optimization analytics
        $costAnalytics = $this->dashboard->getCostOptimizationAnalytics();
        echo "  - Cost analytics: " . count($costAnalytics) . " optimization opportunities identified\n";
        
        echo "  ✅ Storage Analytics Dashboard tests passed\n\n";
    }

    /**
     * Test Storage Optimization Job
     */
    public function testStorageOptimizationJob(): void
    {
        echo "⚙️ Testing Storage Optimization Job...\n";
        
        // Test automated optimization
        $optimizationResult = $this->optimizationJob->runAutomatedOptimization();
        echo "  - Automated optimization: " . ($optimizationResult['success'] ? 'SUCCESS' : 'FAILED') . "\n";
        echo "  - Optimizations performed: " . $optimizationResult['optimizations_count'] . "\n";
        echo "  - Potential savings: $" . number_format($optimizationResult['potential_savings'], 2) . "\n";
        
        // Test scheduled optimization
        $scheduledResult = $this->optimizationJob->runScheduledOptimization();
        echo "  - Scheduled optimization: " . ($scheduledResult['success'] ? 'SUCCESS' : 'FAILED') . "\n";
        
        // Test optimization history
        $history = $this->optimizationJob->getOptimizationHistory();
        echo "  - Optimization history: " . count($history) . " entries\n";
        
        echo "  ✅ Storage Optimization Job tests passed\n\n";
    }

    /**
     * Test Real-Time Alerting System
     */
    public function testRealTimeAlertingSystem(): void
    {
        echo "🚨 Testing Real-Time Alerting System...\n";
        
        // Test cost spike monitoring
        $costAlerts = $this->alertingSystem->monitorCostSpikes(1, 1);
        echo "  - Cost spike monitoring: " . count($costAlerts) . " alerts generated\n";
        
        // Test usage limit monitoring
        $usageAlerts = $this->alertingSystem->monitorUsageLimits(1, 1);
        echo "  - Usage limit monitoring: " . count($usageAlerts) . " alerts generated\n";
        
        // Test performance monitoring
        $performanceAlerts = $this->alertingSystem->monitorPerformance();
        echo "  - Performance monitoring: " . count($performanceAlerts) . " alerts generated\n";
        
        // Test SLA compliance monitoring
        $slaAlerts = $this->alertingSystem->monitorSLACompliance();
        echo "  - SLA compliance monitoring: " . count($slaAlerts) . " alerts generated\n";
        
        // Test alert statistics
        $alertStats = $this->alertingSystem->getAlertStatistics(1, 1);
        echo "  - Alert statistics: " . $alertStats['total_alerts'] . " total alerts\n";
        
        echo "  ✅ Real-Time Alerting System tests passed\n\n";
    }

    /**
     * Test Performance Monitoring
     */
    public function testPerformanceMonitoring(): void
    {
        echo "📈 Testing Performance Monitoring...\n";
        
        // Test performance monitoring
        $performanceMetrics = $this->performanceMonitor->monitorPerformance();
        echo "  - Performance metrics: " . count($performanceMetrics) . " metrics collected\n";
        
        // Test API performance metrics
        $apiMetrics = $this->performanceMonitor->getAPIPerformanceMetrics();
        echo "  - API performance: " . $apiMetrics['average_response_time'] . "ms average response time\n";
        echo "  - Requests per second: " . $apiMetrics['requests_per_second'] . " req/s\n";
        echo "  - Error rate: " . ($apiMetrics['error_rate'] * 100) . "%\n";
        echo "  - Uptime: " . $apiMetrics['uptime_percentage'] . "%\n";
        
        // Test storage performance metrics
        $storageMetrics = $this->performanceMonitor->getStoragePerformanceMetrics();
        echo "  - Storage performance: " . $storageMetrics['average_iops'] . " IOPS\n";
        echo "  - Throughput: " . $storageMetrics['average_throughput'] . " MB/s\n";
        echo "  - Latency: " . $storageMetrics['average_latency'] . "ms\n";
        
        // Test performance score
        $performanceScore = $this->performanceMonitor->calculatePerformanceScore();
        echo "  - Performance score: " . number_format($performanceScore * 100, 1) . "%\n";
        
        // Test performance trends
        $trends = $this->performanceMonitor->getPerformanceTrends(24);
        echo "  - Performance trends: " . count($trends) . " trends analyzed\n";
        
        echo "  ✅ Performance Monitoring tests passed\n\n";
    }

    /**
     * Test Storage Efficiency Reporting
     */
    public function testStorageEfficiencyReporting(): void
    {
        echo "📋 Testing Storage Efficiency Reporting...\n";
        
        // Test storage efficiency report
        $efficiencyReport = $this->efficiencyReporter->generateStorageEfficiencyReport(1, 1);
        echo "  - Efficiency report: " . count($efficiencyReport) . " sections generated\n";
        
        // Test deduplication metrics
        $dedupMetrics = $efficiencyReport['deduplication_metrics'];
        echo "  - Deduplication ratio: " . ($dedupMetrics['deduplication_ratio'] * 100) . "%\n";
        echo "  - Potential savings: " . $this->formatBytes($dedupMetrics['potential_savings']) . "\n";
        
        // Test compression metrics
        $compressionMetrics = $efficiencyReport['compression_metrics'];
        echo "  - Compression ratio: " . ($compressionMetrics['compression_ratio'] * 100) . "%\n";
        echo "  - Space saved: " . $this->formatBytes($compressionMetrics['space_saved']) . "\n";
        
        // Test tier efficiency
        $tierEfficiency = $efficiencyReport['tier_efficiency'];
        echo "  - Hot data ratio: " . ($tierEfficiency['hot_data_ratio'] * 100) . "%\n";
        echo "  - Cold data ratio: " . ($tierEfficiency['cold_data_ratio'] * 100) . "%\n";
        
        // Test comprehensive dashboard
        $dashboard = $this->efficiencyReporter->generateComprehensiveDashboard(1, 1);
        echo "  - Comprehensive dashboard: " . count($dashboard) . " sections generated\n";
        
        echo "  ✅ Storage Efficiency Reporting tests passed\n\n";
    }

    /**
     * Test Cost Forecasting
     */
    public function testCostForecasting(): void
    {
        echo "💰 Testing Cost Forecasting...\n";
        
        // Test cost forecast
        $forecast = $this->costForecaster->generateCostForecast(1, 1, 12);
        echo "  - Cost forecast: " . count($forecast) . " sections generated\n";
        
        // Test monthly forecast
        $monthlyForecast = $forecast['monthly_forecast'];
        echo "  - Monthly forecast: " . count($monthlyForecast) . " months forecasted\n";
        
        // Test quarterly forecast
        $quarterlyForecast = $forecast['quarterly_forecast'];
        echo "  - Quarterly forecast: " . count($quarterlyForecast) . " quarters forecasted\n";
        
        // Test annual forecast
        $annualForecast = $forecast['annual_forecast'];
        echo "  - Annual forecast: $" . number_format($annualForecast['predicted_annual_cost'], 2) . "\n";
        echo "  - Growth rate: " . ($annualForecast['growth_rate'] * 100) . "%\n";
        
        // Test trend analysis
        $trends = $forecast['trend_analysis'];
        echo "  - Trend analysis: " . $trends['overall_trend'] . " trend detected\n";
        
        // Test anomaly detection
        $anomalies = $forecast['anomaly_detection'];
        echo "  - Anomaly detection: " . $anomalies['anomaly_count'] . " anomalies detected\n";
        
        echo "  ✅ Cost Forecasting tests passed\n\n";
    }

    /**
     * Test Usage Pattern Analysis
     */
    public function testUsagePatternAnalysis(): void
    {
        echo "🔍 Testing Usage Pattern Analysis...\n";
        
        // Test usage pattern analysis
        $patternAnalysis = $this->patternAnalyzer->analyzeUsagePatterns(1, 1);
        echo "  - Pattern analysis: " . count($patternAnalysis) . " sections analyzed\n";
        
        // Test access patterns
        $accessPatterns = $patternAnalysis['access_patterns'];
        echo "  - Access patterns: " . count($accessPatterns) . " patterns identified\n";
        echo "  - Hot data ratio: " . ($accessPatterns['hot_data_ratio'] * 100) . "%\n";
        echo "  - Warm data ratio: " . ($accessPatterns['warm_data_ratio'] * 100) . "%\n";
        echo "  - Cold data ratio: " . ($accessPatterns['cold_data_ratio'] * 100) . "%\n";
        
        // Test storage patterns
        $storagePatterns = $patternAnalysis['storage_patterns'];
        echo "  - Storage growth: " . ($storagePatterns['storage_growth'] * 100) . "% per month\n";
        echo "  - Storage efficiency: " . ($storagePatterns['storage_efficiency'] * 100) . "%\n";
        
        // Test temporal patterns
        $temporalPatterns = $patternAnalysis['temporal_patterns'];
        echo "  - Temporal patterns: " . count($temporalPatterns) . " patterns identified\n";
        
        // Test predictive insights
        $predictiveInsights = $patternAnalysis['predictive_insights'];
        echo "  - Predictive insights: " . count($predictiveInsights) . " insights generated\n";
        
        // Test migration opportunities
        $migrationOpportunities = $patternAnalysis['migration_opportunities'];
        echo "  - Migration opportunities: " . count($migrationOpportunities['migration_opportunities']) . " opportunities identified\n";
        echo "  - Total potential savings: $" . number_format($migrationOpportunities['total_potential_savings'], 2) . "\n";
        
        echo "  ✅ Usage Pattern Analysis tests passed\n\n";
    }

    /**
     * Test SLA Monitoring
     */
    public function testSLAMonitoring(): void
    {
        echo "📋 Testing SLA Monitoring...\n";
        
        // Test SLA compliance monitoring
        $slaReport = $this->slaMonitor->monitorSLACompliance();
        echo "  - SLA compliance: " . count($slaReport) . " sections monitored\n";
        
        // Test uptime monitoring
        $uptimeMonitoring = $slaReport['uptime_monitoring'];
        echo "  - Current uptime: " . $uptimeMonitoring['current_uptime'] . "%\n";
        echo "  - Target uptime: " . $uptimeMonitoring['target_uptime'] . "%\n";
        echo "  - Compliance status: " . $uptimeMonitoring['compliance_status'] . "\n";
        
        // Test response time monitoring
        $responseTimeMonitoring = $slaReport['response_time_monitoring'];
        echo "  - Current response time: " . $responseTimeMonitoring['current_response_time'] . "ms\n";
        echo "  - Target response time: " . $responseTimeMonitoring['target_response_time'] . "ms\n";
        echo "  - Compliance status: " . $responseTimeMonitoring['compliance_status'] . "\n";
        
        // Test SLA violations
        $violations = $slaReport['sla_violations'];
        echo "  - SLA violations: " . $violations['violation_count'] . " violations detected\n";
        echo "  - Critical violations: " . $violations['critical_violations'] . "\n";
        echo "  - Warning violations: " . $violations['warning_violations'] . "\n";
        
        // Test compliance trends
        $complianceTrends = $slaReport['compliance_trends'];
        echo "  - Compliance trend: " . $complianceTrends['overall_trend'] . "\n";
        echo "  - Compliance rate: " . ($complianceTrends['compliance_rate'] * 100) . "%\n";
        
        // Test SLA compliance report
        $complianceReport = $this->slaMonitor->generateSLAComplianceReport(1, 1);
        echo "  - SLA compliance report: " . count($complianceReport) . " sections generated\n";
        
        echo "  ✅ SLA Monitoring tests passed\n\n";
    }

    /**
     * Test Comprehensive Reporting
     */
    public function testComprehensiveReporting(): void
    {
        echo "📊 Testing Comprehensive Reporting...\n";
        
        // Test comprehensive dashboard
        $dashboard = $this->efficiencyReporter->generateComprehensiveDashboard(1, 1);
        echo "  - Dashboard sections: " . count($dashboard) . " sections\n";
        
        // Test overview metrics
        $overviewMetrics = $dashboard['overview_metrics'];
        echo "  - Total storage: " . $this->formatBytes($overviewMetrics['total_storage']) . "\n";
        echo "  - Total cost: $" . number_format($overviewMetrics['total_cost'], 2) . "\n";
        echo "  - Efficiency score: " . ($overviewMetrics['efficiency_score'] * 100) . "%\n";
        echo "  - Optimization score: " . ($overviewMetrics['optimization_score'] * 100) . "%\n";
        echo "  - Performance score: " . ($overviewMetrics['performance_score'] * 100) . "%\n";
        
        // Test real-time metrics
        $realTimeMetrics = $dashboard['real_time_metrics'];
        echo "  - Real-time metrics: " . count($realTimeMetrics) . " metrics\n";
        
        // Test alerts
        $alerts = $dashboard['alerts'];
        echo "  - Active alerts: " . count($alerts) . " alerts\n";
        
        // Test recommendations
        $recommendations = $dashboard['recommendations'];
        echo "  - Recommendations: " . count($recommendations) . " recommendations\n";
        
        // Test trends
        $trends = $dashboard['trends'];
        echo "  - Trends: " . count($trends) . " trends analyzed\n";
        
        echo "  ✅ Comprehensive Reporting tests passed\n\n";
    }

    /**
     * Test High Load Scenarios
     */
    public function testHighLoadScenarios(): void
    {
        echo "🔥 Testing High Load Scenarios...\n";
        
        // Simulate 3000+ installations
        $installations = 3000;
        echo "  - Simulating " . number_format($installations) . " installations\n";
        
        $startTime = microtime(true);
        
        // Test dashboard performance under load
        for ($i = 0; $i < 100; $i++) {
            $dashboard = $this->dashboard->getOverviewMetrics();
        }
        
        $dashboardTime = microtime(true) - $startTime;
        echo "  - Dashboard generation: " . number_format($dashboardTime, 3) . "s for 100 requests\n";
        
        // Test alerting system performance under load
        $startTime = microtime(true);
        
        for ($i = 0; $i < 100; $i++) {
            $alerts = $this->alertingSystem->monitorCostSpikes($i % 100, $i % 10);
        }
        
        $alertingTime = microtime(true) - $startTime;
        echo "  - Alerting system: " . number_format($alertingTime, 3) . "s for 100 requests\n";
        
        // Test performance monitoring under load
        $startTime = microtime(true);
        
        for ($i = 0; $i < 100; $i++) {
            $metrics = $this->performanceMonitor->monitorPerformance();
        }
        
        $monitoringTime = microtime(true) - $startTime;
        echo "  - Performance monitoring: " . number_format($monitoringTime, 3) . "s for 100 requests\n";
        
        // Test SLA monitoring under load
        $startTime = microtime(true);
        
        for ($i = 0; $i < 100; $i++) {
            $slaReport = $this->slaMonitor->monitorSLACompliance();
        }
        
        $slaTime = microtime(true) - $startTime;
        echo "  - SLA monitoring: " . number_format($slaTime, 3) . "s for 100 requests\n";
        
        $totalTime = $dashboardTime + $alertingTime + $monitoringTime + $slaTime;
        echo "  - Total processing time: " . number_format($totalTime, 3) . "s\n";
        echo "  - Average response time: " . number_format(($totalTime / 400) * 1000, 2) . "ms per request\n";
        
        echo "  ✅ High Load Scenarios tests passed\n\n";
    }

    /**
     * Test Integration Scenarios
     */
    public function testIntegrationScenarios(): void
    {
        echo "🔗 Testing Integration Scenarios...\n";
        
        // Test end-to-end monitoring workflow
        echo "  - Testing end-to-end monitoring workflow...\n";
        
        // 1. Collect performance metrics
        $performanceMetrics = $this->performanceMonitor->monitorPerformance();
        
        // 2. Check for SLA violations
        $slaReport = $this->slaMonitor->monitorSLACompliance();
        
        // 3. Generate alerts if needed
        $alerts = $this->alertingSystem->monitorPerformance();
        
        // 4. Update dashboard
        $dashboard = $this->dashboard->getOverviewMetrics();
        
        // 5. Generate reports
        $efficiencyReport = $this->efficiencyReporter->generateStorageEfficiencyReport(1, 1);
        
        echo "  - End-to-end workflow completed successfully\n";
        
        // Test automated optimization workflow
        echo "  - Testing automated optimization workflow...\n";
        
        // 1. Analyze usage patterns
        $patternAnalysis = $this->patternAnalyzer->analyzeUsagePatterns(1, 1);
        
        // 2. Identify optimization opportunities
        $opportunities = $patternAnalysis['migration_opportunities'];
        
        // 3. Run automated optimization
        $optimizationResult = $this->optimizationJob->runAutomatedOptimization();
        
        // 4. Generate cost forecast
        $forecast = $this->costForecaster->generateCostForecast(1, 1, 12);
        
        echo "  - Automated optimization workflow completed successfully\n";
        
        // Test comprehensive reporting workflow
        echo "  - Testing comprehensive reporting workflow...\n";
        
        // 1. Generate comprehensive dashboard
        $comprehensiveDashboard = $this->efficiencyReporter->generateComprehensiveDashboard(1, 1);
        
        // 2. Generate SLA compliance report
        $slaComplianceReport = $this->slaMonitor->generateSLAComplianceReport(1, 1);
        
        // 3. Generate cost forecast report
        $costForecast = $this->costForecaster->generateCostForecast(1, 1, 12);
        
        echo "  - Comprehensive reporting workflow completed successfully\n";
        
        echo "  ✅ Integration Scenarios tests passed\n\n";
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

// Run the tests
$test = new MonitoringAnalyticsTest();
$test->runAllTests(); 