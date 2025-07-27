<?php

namespace GrimReaper\Monitoring;

use GrimReaper\Analytics\CostAnalyzer;
use GrimReaper\Analytics\UsageAnalyzer;
use GrimReaper\Storage\StorageRouter;

/**
 * Comprehensive Storage Analytics Dashboard
 * Provides overview metrics, tier breakdown, provider performance, and cost optimization analytics
 */
class StorageAnalyticsDashboard
{
    private CostAnalyzer $costAnalyzer;
    private UsageAnalyzer $usageAnalyzer;
    private StorageRouter $storageRouter;
    private array $dashboardConfig;
    private array $metricsCache;

    public function __construct()
    {
        $this->costAnalyzer = new CostAnalyzer();
        $this->usageAnalyzer = new UsageAnalyzer();
        $this->storageRouter = new StorageRouter();
        $this->initializeDashboardConfig();
        $this->metricsCache = [];
    }

    /**
     * Get storage analytics dashboard with overview metrics
     */
    public function getDashboardOverview(int $userId = null, ?int $projectId = null): array
    {
        $cacheKey = "dashboard_overview_{$userId}_{$projectId}";
        
        if (isset($this->metricsCache[$cacheKey])) {
            return $this->metricsCache[$cacheKey];
        }
        
        $overview = [
            'timestamp' => time(),
            'user_id' => $userId,
            'project_id' => $projectId,
            'storage_metrics' => $this->getStorageMetrics($userId, $projectId),
            'cost_metrics' => $this->getCostMetrics($userId, $projectId),
            'performance_metrics' => $this->getPerformanceMetrics($userId, $projectId),
            'optimization_metrics' => $this->getOptimizationMetrics($userId, $projectId),
            'tier_breakdown' => $this->getTierBreakdown($userId, $projectId),
            'provider_performance' => $this->getProviderPerformance($userId, $projectId),
            'alerts' => $this->getActiveAlerts($userId, $projectId),
            'recommendations' => $this->getOptimizationRecommendations($userId, $projectId)
        ];
        
        $this->metricsCache[$cacheKey] = $overview;
        return $overview;
    }

    /**
     * Get tier breakdown analytics (free, pro, master, reaper)
     */
    public function getTierBreakdownAnalytics(int $userId = null, ?int $projectId = null): array
    {
        $tierData = $this->getTierBreakdown($userId, $projectId);
        
        return [
            'free_tier' => [
                'storage_used' => $tierData['free']['storage_used'] ?? 0,
                'storage_limit' => $tierData['free']['storage_limit'] ?? 1024 * 1024 * 1024 * 5, // 5GB
                'usage_percentage' => $tierData['free']['usage_percentage'] ?? 0,
                'cost' => $tierData['free']['cost'] ?? 0,
                'files_count' => $tierData['free']['files_count'] ?? 0
            ],
            'pro_tier' => [
                'storage_used' => $tierData['pro']['storage_used'] ?? 0,
                'storage_limit' => $tierData['pro']['storage_limit'] ?? 1024 * 1024 * 1024 * 100, // 100GB
                'usage_percentage' => $tierData['pro']['usage_percentage'] ?? 0,
                'cost' => $tierData['pro']['cost'] ?? 0,
                'files_count' => $tierData['pro']['files_count'] ?? 0
            ],
            'master_tier' => [
                'storage_used' => $tierData['master']['storage_used'] ?? 0,
                'storage_limit' => $tierData['master']['storage_limit'] ?? 1024 * 1024 * 1024 * 1000, // 1TB
                'usage_percentage' => $tierData['master']['usage_percentage'] ?? 0,
                'cost' => $tierData['master']['cost'] ?? 0,
                'files_count' => $tierData['master']['files_count'] ?? 0
            ],
            'reaper_tier' => [
                'storage_used' => $tierData['reaper']['storage_used'] ?? 0,
                'storage_limit' => $tierData['reaper']['storage_limit'] ?? 1024 * 1024 * 1024 * 10000, // 10TB
                'usage_percentage' => $tierData['reaper']['usage_percentage'] ?? 0,
                'cost' => $tierData['reaper']['cost'] ?? 0,
                'files_count' => $tierData['reaper']['files_count'] ?? 0
            ],
            'total_metrics' => [
                'total_storage' => array_sum(array_column($tierData, 'storage_used')),
                'total_cost' => array_sum(array_column($tierData, 'cost')),
                'total_files' => array_sum(array_column($tierData, 'files_count'))
            ]
        ];
    }

    /**
     * Get provider performance monitoring
     */
    public function getProviderPerformanceMonitoring(): array
    {
        $providers = ['aws_s3', 'gcp_storage', 'azure_blob', 'local_storage'];
        $performanceData = [];
        
        foreach ($providers as $providerId) {
            $performanceData[$providerId] = [
                'uptime' => $this->getProviderUptime($providerId),
                'response_time' => $this->getProviderResponseTime($providerId),
                'throughput' => $this->getProviderThroughput($providerId),
                'error_rate' => $this->getProviderErrorRate($providerId),
                'cost_per_gb' => $this->getProviderCostPerGB($providerId),
                'sla_compliance' => $this->getProviderSLACompliance($providerId),
                'incidents_last_30_days' => $this->getProviderIncidents($providerId, 30),
                'status' => $this->getProviderStatus($providerId)
            ];
        }
        
        return $performanceData;
    }

    /**
     * Get cost optimization analytics and recommendations
     */
    public function getCostOptimizationAnalytics(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        $costAnalysis = $this->costAnalyzer->analyzeUsagePatterns($userId);
        
        return [
            'current_costs' => [
                'total_monthly_cost' => $costAnalysis['total_cost'] ?? 0,
                'storage_cost' => $costAnalysis['storage_cost'] ?? 0,
                'transfer_cost' => $costAnalysis['transfer_cost'] ?? 0,
                'operational_cost' => $costAnalysis['operational_cost'] ?? 0
            ],
            'optimization_opportunities' => [
                'tier_optimization' => $this->getTierOptimizationOpportunities($usageData),
                'compression_opportunities' => $this->getCompressionOpportunities($usageData),
                'deduplication_opportunities' => $this->getDeduplicationOpportunities($usageData),
                'lifecycle_optimization' => $this->getLifecycleOptimizationOpportunities($usageData)
            ],
            'potential_savings' => [
                'total_potential_savings' => $costAnalysis['potential_savings'] ?? 0,
                'monthly_savings' => ($costAnalysis['potential_savings'] ?? 0) / 12,
                'annual_savings' => $costAnalysis['potential_savings'] ?? 0,
                'savings_percentage' => $this->calculateSavingsPercentage($costAnalysis)
            ],
            'cost_trends' => $this->getCostTrends($userId, $projectId),
            'recommendations' => $this->getCostOptimizationRecommendations($usageData)
        ];
    }

    /**
     * Get storage optimization job for automated optimization
     */
    public function createStorageOptimizationJob(int $userId, ?int $projectId = null): array
    {
        $jobId = uniqid('opt_');
        $job = [
            'job_id' => $jobId,
            'user_id' => $userId,
            'project_id' => $projectId,
            'status' => 'pending',
            'created_at' => time(),
            'scheduled_at' => time(),
            'priority' => 'medium',
            'type' => 'storage_optimization',
            'parameters' => [
                'optimize_tiers' => true,
                'enable_compression' => true,
                'enable_deduplication' => true,
                'migrate_cold_data' => true,
                'apply_lifecycle_policies' => true
            ]
        ];
        
        // Store job in database/cache
        $this->storeOptimizationJob($job);
        
        return $job;
    }

    /**
     * Get real-time alerting system for cost spikes and usage limits
     */
    public function getRealTimeAlerts(int $userId = null, ?int $projectId = null): array
    {
        $alerts = [];
        
        // Check for cost spikes
        $costAlerts = $this->checkCostSpikes($userId, $projectId);
        $alerts = array_merge($alerts, $costAlerts);
        
        // Check for usage limits
        $usageAlerts = $this->checkUsageLimits($userId, $projectId);
        $alerts = array_merge($alerts, $usageAlerts);
        
        // Check for performance issues
        $performanceAlerts = $this->checkPerformanceIssues($userId, $projectId);
        $alerts = array_merge($alerts, $performanceAlerts);
        
        // Check for SLA violations
        $slaAlerts = $this->checkSLAViolations($userId, $projectId);
        $alerts = array_merge($alerts, $slaAlerts);
        
        return $alerts;
    }

    /**
     * Get performance monitoring and optimization metrics
     */
    public function getPerformanceMonitoringMetrics(int $userId = null, ?int $projectId = null): array
    {
        return [
            'api_performance' => [
                'average_response_time' => $this->getAverageResponseTime(),
                'requests_per_second' => $this->getRequestsPerSecond(),
                'error_rate' => $this->getErrorRate(),
                'uptime_percentage' => $this->getUptimePercentage()
            ],
            'storage_performance' => [
                'average_iops' => $this->getAverageIOPS(),
                'average_throughput' => $this->getAverageThroughput(),
                'average_latency' => $this->getAverageLatency(),
                'compression_ratio' => $this->getCompressionRatio()
            ],
            'optimization_metrics' => [
                'migrations_completed' => $this->getMigrationsCompleted(),
                'optimization_score' => $this->getOptimizationScore(),
                'cost_savings_achieved' => $this->getCostSavingsAchieved(),
                'performance_improvements' => $this->getPerformanceImprovements()
            ]
        ];
    }

    /**
     * Get storage efficiency reports and deduplication tracking
     */
    public function getStorageEfficiencyReports(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        
        return [
            'deduplication_metrics' => [
                'total_duplicates_found' => $this->getTotalDuplicates($usageData),
                'duplicate_size' => $this->getDuplicateSize($usageData),
                'potential_savings' => $this->getDeduplicationSavings($usageData),
                'deduplication_ratio' => $this->getDeduplicationRatio($usageData)
            ],
            'compression_metrics' => [
                'compressed_files' => $this->getCompressedFilesCount($usageData),
                'compression_ratio' => $this->getOverallCompressionRatio($usageData),
                'space_saved' => $this->getCompressionSpaceSaved($usageData),
                'compression_efficiency' => $this->getCompressionEfficiency($usageData)
            ],
            'tier_efficiency' => [
                'hot_data_ratio' => $this->getHotDataRatio($usageData),
                'cold_data_ratio' => $this->getColdDataRatio($usageData),
                'tier_optimization_score' => $this->getTierOptimizationScore($usageData),
                'migration_efficiency' => $this->getMigrationEfficiency($usageData)
            ]
        ];
    }

    /**
     * Get cost forecasting and trend analysis
     */
    public function getCostForecasting(int $userId = null, ?int $projectId = null): array
    {
        $forecast = $this->costAnalyzer->getCostForecast($userId, 12);
        
        return [
            'current_month' => [
                'cost' => $forecast[0]['projected_cost'] ?? 0,
                'growth_rate' => $forecast[0]['growth_rate'] ?? 0
            ],
            'forecast' => $forecast,
            'trends' => [
                'monthly_growth' => $this->calculateMonthlyGrowth($forecast),
                'seasonal_patterns' => $this->identifySeasonalPatterns($forecast),
                'anomalies' => $this->detectCostAnomalies($forecast)
            ],
            'predictions' => [
                'next_month_cost' => $forecast[1]['projected_cost'] ?? 0,
                'quarterly_projection' => $this->calculateQuarterlyProjection($forecast),
                'annual_projection' => $this->calculateAnnualProjection($forecast)
            ]
        ];
    }

    /**
     * Get usage pattern analysis and predictive modeling
     */
    public function getUsagePatternAnalysis(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        $patterns = $this->usageAnalyzer->analyzeAccessPatterns($usageData);
        
        return [
            'access_patterns' => $patterns,
            'usage_trends' => [
                'daily_patterns' => $this->getDailyUsagePatterns($userId, $projectId),
                'weekly_patterns' => $this->getWeeklyUsagePatterns($userId, $projectId),
                'monthly_patterns' => $this->getMonthlyUsagePatterns($userId, $projectId)
            ],
            'predictive_insights' => [
                'storage_growth_prediction' => $this->predictStorageGrowth($usageData),
                'cost_prediction' => $this->predictCostGrowth($usageData),
                'usage_anomalies' => $this->detectUsageAnomalies($usageData),
                'optimization_opportunities' => $this->predictOptimizationOpportunities($usageData)
            ],
            'behavioral_analysis' => [
                'peak_usage_times' => $this->getPeakUsageTimes($userId, $projectId),
                'file_type_preferences' => $this->getFileTypePreferences($usageData),
                'access_frequency_distribution' => $this->getAccessFrequencyDistribution($usageData)
            ]
        ];
    }

    // Private helper methods

    private function getStorageMetrics(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        
        return [
            'total_storage' => $usageData['total_size'] ?? 0,
            'files_count' => count($usageData['files'] ?? []),
            'average_file_size' => $this->calculateAverageFileSize($usageData),
            'largest_file' => $this->getLargestFile($usageData),
            'storage_growth_rate' => $this->calculateStorageGrowthRate($userId, $projectId)
        ];
    }

    private function getCostMetrics(int $userId = null, ?int $projectId = null): array
    {
        $costAnalysis = $this->costAnalyzer->analyzeUsagePatterns($userId);
        
        return [
            'total_cost' => $costAnalysis['total_cost'] ?? 0,
            'cost_per_gb' => $this->calculateCostPerGB($costAnalysis),
            'monthly_cost_trend' => $this->getMonthlyCostTrend($userId, $projectId),
            'cost_optimization_score' => $this->calculateCostOptimizationScore($costAnalysis)
        ];
    }

    private function getPerformanceMetrics(int $userId = null, ?int $projectId = null): array
    {
        return [
            'average_response_time' => $this->getAverageResponseTime(),
            'throughput' => $this->getAverageThroughput(),
            'iops' => $this->getAverageIOPS(),
            'uptime' => $this->getUptimePercentage()
        ];
    }

    private function getOptimizationMetrics(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        
        return [
            'optimization_score' => $this->getOptimizationScore(),
            'potential_savings' => $this->calculatePotentialSavings($usageData),
            'migrations_completed' => $this->getMigrationsCompleted(),
            'compression_ratio' => $this->getCompressionRatio()
        ];
    }

    private function getTierBreakdown(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        $breakdown = $this->usageAnalyzer->getStorageTierBreakdown($usageData);
        
        // Add tier-specific limits and usage percentages
        $tierLimits = [
            'free' => 1024 * 1024 * 1024 * 5, // 5GB
            'pro' => 1024 * 1024 * 1024 * 100, // 100GB
            'master' => 1024 * 1024 * 1024 * 1000, // 1TB
            'reaper' => 1024 * 1024 * 1024 * 10000 // 10TB
        ];
        
        foreach ($breakdown as $tier => &$data) {
            $data['storage_limit'] = $tierLimits[$tier] ?? 0;
            $data['usage_percentage'] = $data['storage_limit'] > 0 ? 
                ($data['size'] / $data['storage_limit']) * 100 : 0;
            $data['files_count'] = $this->getFilesCountByTier($usageData, $tier);
        }
        
        return $breakdown;
    }

    private function getProviderPerformance(int $userId = null, ?int $projectId = null): array
    {
        return $this->getProviderPerformanceMonitoring();
    }

    private function getActiveAlerts(int $userId = null, ?int $projectId = null): array
    {
        return $this->getRealTimeAlerts($userId, $projectId);
    }

    private function getOptimizationRecommendations(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        return $this->getCostOptimizationRecommendations($usageData);
    }

    // Additional helper methods for specific metrics...

    private function initializeDashboardConfig(): void
    {
        $this->dashboardConfig = [
            'refresh_interval' => 60, // seconds
            'cache_duration' => 300, // seconds
            'alert_thresholds' => [
                'cost_spike' => 0.2, // 20% increase
                'usage_limit' => 0.9, // 90% of limit
                'performance_degradation' => 0.1 // 10% degradation
            ]
        ];
    }

    // Mock implementations for various metrics...
    private function getProviderUptime(string $providerId): float { return 99.9; }
    private function getProviderResponseTime(string $providerId): float { return 50.0; }
    private function getProviderThroughput(string $providerId): float { return 100.0; }
    private function getProviderErrorRate(string $providerId): float { return 0.001; }
    private function getProviderCostPerGB(string $providerId): float { return 0.023; }
    private function getProviderSLACompliance(string $providerId): float { return 99.95; }
    private function getProviderIncidents(string $providerId, int $days): int { return 0; }
    private function getProviderStatus(string $providerId): string { return 'available'; }
    
    private function getAverageResponseTime(): float { return 45.0; }
    private function getRequestsPerSecond(): float { return 100.0; }
    private function getErrorRate(): float { return 0.001; }
    private function getUptimePercentage(): float { return 99.9; }
    private function getAverageIOPS(): int { return 3000; }
    private function getAverageThroughput(): float { return 100.0; }
    private function getAverageLatency(): float { return 10.0; }
    private function getCompressionRatio(): float { return 0.6; }
    private function getMigrationsCompleted(): int { return 150; }
    private function getOptimizationScore(): float { return 0.85; }
    private function getCostSavingsAchieved(): float { return 25.50; }
    private function getPerformanceImprovements(): array { return ['latency' => 15, 'throughput' => 20]; }

    private function storeOptimizationJob(array $job): void
    {
        // Store job in database/cache
        file_put_contents('logs/optimization_jobs.log', json_encode($job) . "\n", FILE_APPEND);
    }

    private function checkCostSpikes(int $userId = null, ?int $projectId = null): array
    {
        // Mock implementation
        return [];
    }

    private function checkUsageLimits(int $userId = null, ?int $projectId = null): array
    {
        // Mock implementation
        return [];
    }

    private function checkPerformanceIssues(int $userId = null, ?int $projectId = null): array
    {
        // Mock implementation
        return [];
    }

    private function checkSLAViolations(int $userId = null, ?int $projectId = null): array
    {
        // Mock implementation
        return [];
    }

    // Additional helper methods would be implemented here...
    private function calculateAverageFileSize(array $usageData): float { return 1024 * 1024 * 100; }
    private function getLargestFile(array $usageData): array { return ['size' => 1024 * 1024 * 1024 * 5]; }
    private function calculateStorageGrowthRate(int $userId, ?int $projectId): float { return 0.05; }
    private function calculateCostPerGB(array $costAnalysis): float { return 0.023; }
    private function getMonthlyCostTrend(int $userId, ?int $projectId): array { return []; }
    private function calculateCostOptimizationScore(array $costAnalysis): float { return 0.85; }
    private function calculatePotentialSavings(array $usageData): float { return 15.75; }
    private function getFilesCountByTier(array $usageData, string $tier): int { return 10; }
    private function getTierOptimizationOpportunities(array $usageData): array { return []; }
    private function getCompressionOpportunities(array $usageData): array { return []; }
    private function getDeduplicationOpportunities(array $usageData): array { return []; }
    private function getLifecycleOptimizationOpportunities(array $usageData): array { return []; }
    private function calculateSavingsPercentage(array $costAnalysis): float { return 15.5; }
    private function getCostTrends(int $userId, ?int $projectId): array { return []; }
    private function getCostOptimizationRecommendations(array $usageData): array { return []; }
    private function getTotalDuplicates(array $usageData): int { return 25; }
    private function getDuplicateSize(array $usageData): int { return 1024 * 1024 * 1024 * 2; }
    private function getDeduplicationSavings(array $usageData): float { return 8.50; }
    private function getDeduplicationRatio(array $usageData): float { return 0.15; }
    private function getCompressedFilesCount(array $usageData): int { return 150; }
    private function getOverallCompressionRatio(array $usageData): float { return 0.65; }
    private function getCompressionSpaceSaved(array $usageData): int { return 1024 * 1024 * 1024 * 10; }
    private function getCompressionEfficiency(array $usageData): float { return 0.85; }
    private function getHotDataRatio(array $usageData): float { return 0.2; }
    private function getColdDataRatio(array $usageData): float { return 0.6; }
    private function getTierOptimizationScore(array $usageData): float { return 0.75; }
    private function getMigrationEfficiency(array $usageData): float { return 0.90; }
    private function calculateMonthlyGrowth(array $forecast): float { return 0.05; }
    private function identifySeasonalPatterns(array $forecast): array { return []; }
    private function detectCostAnomalies(array $forecast): array { return []; }
    private function calculateQuarterlyProjection(array $forecast): float { return 150.0; }
    private function calculateAnnualProjection(array $forecast): float { return 600.0; }
    private function getDailyUsagePatterns(int $userId, ?int $projectId): array { return []; }
    private function getWeeklyUsagePatterns(int $userId, ?int $projectId): array { return []; }
    private function getMonthlyUsagePatterns(int $userId, ?int $projectId): array { return []; }
    private function predictStorageGrowth(array $usageData): float { return 0.08; }
    private function predictCostGrowth(array $usageData): float { return 0.06; }
    private function detectUsageAnomalies(array $usageData): array { return []; }
    private function predictOptimizationOpportunities(array $usageData): array { return []; }
    private function getPeakUsageTimes(int $userId, ?int $projectId): array { return []; }
    private function getFileTypePreferences(array $usageData): array { return []; }
    private function getAccessFrequencyDistribution(array $usageData): array { return []; }
} 