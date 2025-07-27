<?php

namespace GrimReaper\Monitoring;

use GrimReaper\Storage\StorageRouter;
use GrimReaper\Analytics\CostAnalyzer;

/**
 * Performance Monitor for monitoring and optimization
 * Ensures <100ms API response time tracking and performance optimization
 */
class PerformanceMonitor
{
    private StorageRouter $storageRouter;
    private CostAnalyzer $costAnalyzer;
    private array $performanceMetrics;
    private array $optimizationRules;
    private array $performanceHistory;
    private array $alertThresholds;

    public function __construct()
    {
        $this->storageRouter = new StorageRouter();
        $this->costAnalyzer = new CostAnalyzer();
        $this->initializePerformanceMetrics();
        $this->initializeOptimizationRules();
        $this->initializeAlertThresholds();
        $this->performanceHistory = [];
    }

    /**
     * Monitor performance and optimization
     */
    public function monitorPerformance(): array
    {
        $metrics = [
            'api_performance' => $this->getAPIPerformanceMetrics(),
            'storage_performance' => $this->getStoragePerformanceMetrics(),
            'optimization_metrics' => $this->getOptimizationMetrics(),
            'system_health' => $this->getSystemHealthMetrics(),
            'response_time_tracking' => $this->getResponseTimeTracking(),
            'performance_alerts' => $this->checkPerformanceAlerts()
        ];
        
        // Store metrics in history
        $this->performanceHistory[] = [
            'timestamp' => time(),
            'metrics' => $metrics
        ];
        
        // Keep only last 1000 entries
        if (count($this->performanceHistory) > 1000) {
            array_shift($this->performanceHistory);
        }
        
        return $metrics;
    }

    /**
     * Get API performance metrics
     */
    public function getAPIPerformanceMetrics(): array
    {
        return [
            'average_response_time' => $this->getAverageResponseTime(),
            'requests_per_second' => $this->getRequestsPerSecond(),
            'error_rate' => $this->getErrorRate(),
            'uptime_percentage' => $this->getUptimePercentage(),
            'response_time_percentiles' => $this->getResponseTimePercentiles(),
            'concurrent_connections' => $this->getConcurrentConnections(),
            'throughput' => $this->getThroughput()
        ];
    }

    /**
     * Get storage performance metrics
     */
    public function getStoragePerformanceMetrics(): array
    {
        return [
            'average_iops' => $this->getAverageIOPS(),
            'average_throughput' => $this->getAverageThroughput(),
            'average_latency' => $this->getAverageLatency(),
            'compression_ratio' => $this->getCompressionRatio(),
            'deduplication_ratio' => $this->getDeduplicationRatio(),
            'cache_hit_rate' => $this->getCacheHitRate(),
            'storage_efficiency' => $this->getStorageEfficiency()
        ];
    }

    /**
     * Get optimization metrics
     */
    public function getOptimizationMetrics(): array
    {
        return [
            'migrations_completed' => $this->getMigrationsCompleted(),
            'optimization_score' => $this->getOptimizationScore(),
            'cost_savings_achieved' => $this->getCostSavingsAchieved(),
            'performance_improvements' => $this->getPerformanceImprovements(),
            'automated_optimizations' => $this->getAutomatedOptimizations(),
            'optimization_efficiency' => $this->getOptimizationEfficiency()
        ];
    }

    /**
     * Get system health metrics
     */
    public function getSystemHealthMetrics(): array
    {
        return [
            'cpu_usage' => $this->getCPUUsage(),
            'memory_usage' => $this->getMemoryUsage(),
            'disk_usage' => $this->getDiskUsage(),
            'network_usage' => $this->getNetworkUsage(),
            'load_average' => $this->getLoadAverage(),
            'system_uptime' => $this->getSystemUptime(),
            'health_score' => $this->calculateHealthScore()
        ];
    }

    /**
     * Get response time tracking (<100ms target)
     */
    public function getResponseTimeTracking(): array
    {
        $currentResponseTime = $this->getCurrentResponseTime();
        $targetResponseTime = 100; // 100ms target
        
        return [
            'current_response_time' => $currentResponseTime,
            'target_response_time' => $targetResponseTime,
            'compliance_percentage' => $this->calculateCompliancePercentage($currentResponseTime, $targetResponseTime),
            'response_time_trend' => $this->getResponseTimeTrend(),
            'slow_queries' => $this->getSlowQueries(),
            'performance_bottlenecks' => $this->identifyPerformanceBottlenecks(),
            'optimization_recommendations' => $this->getPerformanceOptimizationRecommendations()
        ];
    }

    /**
     * Check performance alerts
     */
    public function checkPerformanceAlerts(): array
    {
        $alerts = [];
        
        // Check response time alerts
        $responseTime = $this->getCurrentResponseTime();
        if ($responseTime > $this->alertThresholds['response_time']) {
            $alerts[] = [
                'type' => 'response_time_exceeded',
                'severity' => $responseTime > 500 ? 'critical' : 'warning',
                'message' => "Response time exceeded threshold: " . number_format($responseTime, 2) . "ms",
                'current_value' => $responseTime,
                'threshold' => $this->alertThresholds['response_time']
            ];
        }
        
        // Check throughput alerts
        $throughput = $this->getAverageThroughput();
        if ($throughput < $this->alertThresholds['min_throughput']) {
            $alerts[] = [
                'type' => 'low_throughput',
                'severity' => 'warning',
                'message' => "Throughput below threshold: " . number_format($throughput, 2) . " MB/s",
                'current_value' => $throughput,
                'threshold' => $this->alertThresholds['min_throughput']
            ];
        }
        
        // Check error rate alerts
        $errorRate = $this->getErrorRate();
        if ($errorRate > $this->alertThresholds['max_error_rate']) {
            $alerts[] = [
                'type' => 'high_error_rate',
                'severity' => $errorRate > 0.05 ? 'critical' : 'warning',
                'message' => "Error rate exceeded threshold: " . number_format($errorRate * 100, 2) . "%",
                'current_value' => $errorRate,
                'threshold' => $this->alertThresholds['max_error_rate']
            ];
        }
        
        return $alerts;
    }

    /**
     * Get performance optimization recommendations
     */
    public function getPerformanceOptimizationRecommendations(): array
    {
        $recommendations = [];
        
        // Check response time optimization
        $responseTime = $this->getCurrentResponseTime();
        if ($responseTime > 50) {
            $recommendations[] = [
                'type' => 'response_time_optimization',
                'priority' => 'high',
                'message' => 'Response time can be optimized. Consider caching and query optimization.',
                'potential_improvement' => '20-30% reduction in response time',
                'implementation_effort' => 'medium'
            ];
        }
        
        // Check throughput optimization
        $throughput = $this->getAverageThroughput();
        if ($throughput < 150) {
            $recommendations[] = [
                'type' => 'throughput_optimization',
                'priority' => 'medium',
                'message' => 'Throughput can be improved. Consider parallel processing and compression.',
                'potential_improvement' => '15-25% increase in throughput',
                'implementation_effort' => 'low'
            ];
        }
        
        // Check cache optimization
        $cacheHitRate = $this->getCacheHitRate();
        if ($cacheHitRate < 0.8) {
            $recommendations[] = [
                'type' => 'cache_optimization',
                'priority' => 'medium',
                'message' => 'Cache hit rate can be improved. Consider cache warming and optimization.',
                'potential_improvement' => '10-20% improvement in cache efficiency',
                'implementation_effort' => 'low'
            ];
        }
        
        return $recommendations;
    }

    /**
     * Get performance trends
     */
    public function getPerformanceTrends(int $hours = 24): array
    {
        $cutoffTime = time() - ($hours * 3600);
        $recentMetrics = array_filter($this->performanceHistory, function($entry) use ($cutoffTime) {
            return $entry['timestamp'] >= $cutoffTime;
        });
        
        $trends = [
            'response_time_trend' => $this->calculateTrend(array_column($recentMetrics, 'metrics.api_performance.average_response_time')),
            'throughput_trend' => $this->calculateTrend(array_column($recentMetrics, 'metrics.storage_performance.average_throughput')),
            'error_rate_trend' => $this->calculateTrend(array_column($recentMetrics, 'metrics.api_performance.error_rate')),
            'optimization_score_trend' => $this->calculateTrend(array_column($recentMetrics, 'metrics.optimization_metrics.optimization_score'))
        ];
        
        return $trends;
    }

    /**
     * Calculate performance score
     */
    public function calculatePerformanceScore(): float
    {
        $responseTimeScore = $this->calculateResponseTimeScore();
        $throughputScore = $this->calculateThroughputScore();
        $errorRateScore = $this->calculateErrorRateScore();
        $uptimeScore = $this->calculateUptimeScore();
        
        // Weighted average
        $score = ($responseTimeScore * 0.3) + 
                ($throughputScore * 0.25) + 
                ($errorRateScore * 0.25) + 
                ($uptimeScore * 0.2);
        
        return min(1.0, max(0.0, $score));
    }

    /**
     * Initialize performance metrics
     */
    private function initializePerformanceMetrics(): void
    {
        $this->performanceMetrics = [
            'response_time' => 75.0,
            'throughput' => 120.0,
            'iops' => 3500,
            'error_rate' => 0.005,
            'uptime' => 99.95,
            'cache_hit_rate' => 0.85,
            'compression_ratio' => 0.65,
            'deduplication_ratio' => 0.15
        ];
    }

    /**
     * Initialize optimization rules
     */
    private function initializeOptimizationRules(): void
    {
        $this->optimizationRules = [
            'response_time_threshold' => 100, // ms
            'throughput_threshold' => 100, // MB/s
            'error_rate_threshold' => 0.01, // 1%
            'cache_hit_rate_threshold' => 0.8, // 80%
            'compression_ratio_threshold' => 0.6, // 60%
            'optimization_frequency' => 3600 // 1 hour
        ];
    }

    /**
     * Initialize alert thresholds
     */
    private function initializeAlertThresholds(): void
    {
        $this->alertThresholds = [
            'response_time' => 100, // ms
            'min_throughput' => 50, // MB/s
            'max_error_rate' => 0.01, // 1%
            'min_uptime' => 99.9, // 99.9%
            'max_cpu_usage' => 0.8, // 80%
            'max_memory_usage' => 0.85 // 85%
        ];
    }

    // Performance calculation methods
    private function calculateResponseTimeScore(): float
    {
        $responseTime = $this->getCurrentResponseTime();
        $target = 100; // 100ms target
        
        if ($responseTime <= $target) {
            return 1.0;
        } elseif ($responseTime <= $target * 2) {
            return 0.8;
        } elseif ($responseTime <= $target * 5) {
            return 0.5;
        } else {
            return 0.2;
        }
    }

    private function calculateThroughputScore(): float
    {
        $throughput = $this->getAverageThroughput();
        $target = 100; // 100 MB/s target
        
        return min(1.0, $throughput / $target);
    }

    private function calculateErrorRateScore(): float
    {
        $errorRate = $this->getErrorRate();
        $target = 0.01; // 1% target
        
        return max(0.0, 1 - ($errorRate / $target));
    }

    private function calculateUptimeScore(): float
    {
        $uptime = $this->getUptimePercentage();
        return $uptime / 100;
    }

    private function calculateCompliancePercentage(float $current, float $target): float
    {
        if ($current <= $target) {
            return 100.0;
        } else {
            return max(0.0, 100 - (($current - $target) / $target) * 100);
        }
    }

    private function calculateTrend(array $values): string
    {
        if (count($values) < 2) {
            return 'stable';
        }
        
        $firstHalf = array_slice($values, 0, floor(count($values) / 2));
        $secondHalf = array_slice($values, floor(count($values) / 2));
        
        $firstAvg = array_sum($firstHalf) / count($firstHalf);
        $secondAvg = array_sum($secondHalf) / count($secondHalf);
        
        $change = ($secondAvg - $firstAvg) / $firstAvg;
        
        if ($change > 0.05) {
            return 'increasing';
        } elseif ($change < -0.05) {
            return 'decreasing';
        } else {
            return 'stable';
        }
    }

    private function calculateHealthScore(): float
    {
        $cpuScore = 1 - $this->getCPUUsage();
        $memoryScore = 1 - $this->getMemoryUsage();
        $diskScore = 1 - $this->getDiskUsage();
        $networkScore = 1 - $this->getNetworkUsage();
        
        return ($cpuScore * 0.3) + ($memoryScore * 0.3) + ($diskScore * 0.2) + ($networkScore * 0.2);
    }

    // Mock implementations for performance metrics
    private function getAverageResponseTime(): float { return $this->performanceMetrics['response_time']; }
    private function getRequestsPerSecond(): float { return 150.0; }
    private function getErrorRate(): float { return $this->performanceMetrics['error_rate']; }
    private function getUptimePercentage(): float { return $this->performanceMetrics['uptime']; }
    private function getResponseTimePercentiles(): array { return ['p50' => 50, 'p95' => 120, 'p99' => 200]; }
    private function getConcurrentConnections(): int { return 250; }
    private function getThroughput(): float { return 180.0; }
    private function getAverageIOPS(): int { return $this->performanceMetrics['iops']; }
    private function getAverageThroughput(): float { return $this->performanceMetrics['throughput']; }
    private function getAverageLatency(): float { return 8.5; }
    private function getCompressionRatio(): float { return $this->performanceMetrics['compression_ratio']; }
    private function getDeduplicationRatio(): float { return $this->performanceMetrics['deduplication_ratio']; }
    private function getCacheHitRate(): float { return $this->performanceMetrics['cache_hit_rate']; }
    private function getStorageEfficiency(): float { return 0.85; }
    private function getMigrationsCompleted(): int { return 180; }
    private function getOptimizationScore(): float { return 0.88; }
    private function getCostSavingsAchieved(): float { return 35.75; }
    private function getPerformanceImprovements(): array { return ['response_time' => 25, 'throughput' => 30]; }
    private function getAutomatedOptimizations(): int { return 45; }
    private function getOptimizationEfficiency(): float { return 0.92; }
    private function getCPUUsage(): float { return 0.45; }
    private function getMemoryUsage(): float { return 0.65; }
    private function getDiskUsage(): float { return 0.35; }
    private function getNetworkUsage(): float { return 0.25; }
    private function getLoadAverage(): array { return ['1min' => 1.2, '5min' => 1.1, '15min' => 1.0]; }
    private function getSystemUptime(): int { return 86400 * 30; } // 30 days
    private function getCurrentResponseTime(): float { return $this->performanceMetrics['response_time']; }
    private function getResponseTimeTrend(): array { return ['trend' => 'stable', 'change' => 0.02]; }
    private function getSlowQueries(): array { return []; }
    private function identifyPerformanceBottlenecks(): array { return []; }
} 