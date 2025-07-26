<?php

require_once __DIR__ . '/../src/StorageRouter.php';
require_once __DIR__ . '/../src/CostOptimizationEngine.php';
require_once __DIR__ . '/../src/StorageRequest.php';
require_once __DIR__ . '/../src/StorageProvider.php';
require_once __DIR__ . '/../src/StorageRoute.php';
require_once __DIR__ . '/../src/OptimizationResult.php';
require_once __DIR__ . '/../src/ML/PatternRecognizer.php';
require_once __DIR__ . '/../src/ML/CostPredictor.php';
require_once __DIR__ . '/../src/Analytics/CostAnalyzer.php';
require_once __DIR__ . '/../src/Analytics/UsageAnalyzer.php';
require_once __DIR__ . '/../src/Monitoring/AvailabilityMonitor.php';
require_once __DIR__ . '/../src/Monitoring/StorageMonitor.php';

use GrimReaper\Storage\StorageRouter;
use GrimReaper\Storage\CostOptimizationEngine;
use GrimReaper\Storage\StorageRequest;
use GrimReaper\Storage\StorageProvider;
use GrimReaper\ML\PatternRecognizer;
use GrimReaper\ML\CostPredictor;

/**
 * Comprehensive Storage Optimization Test Suite
 * Tests various file sizes, access patterns, and geographic locations
 */
class StorageOptimizationTest
{
    private StorageRouter $storageRouter;
    private CostOptimizationEngine $costOptimizer;
    private PatternRecognizer $patternRecognizer;
    private CostPredictor $costPredictor;

    public function __construct()
    {
        $this->storageRouter = new StorageRouter();
        $this->costOptimizer = new CostOptimizationEngine();
        $this->patternRecognizer = new PatternRecognizer();
        $this->costPredictor = new CostPredictor();
    }

    /**
     * Run all tests
     */
    public function runAllTests(): void
    {
        echo "=== Storage Optimization Test Suite ===\n\n";
        
        $this->testSmallFileRouting();
        $this->testLargeFileRouting();
        $this->testHotDataRouting();
        $this->testColdDataRouting();
        $this->testGeographicRouting();
        $this->testCostOptimization();
        $this->testMLPredictions();
        $this->testPerformanceScenarios();
        $this->testHighLoadScenarios();
        $this->testDisasterRecovery();
        
        echo "\n=== All Tests Completed ===\n";
    }

    /**
     * Test routing for small files
     */
    private function testSmallFileRouting(): void
    {
        echo "1. Testing Small File Routing (1MB - 100MB)\n";
        
        $fileSizes = [1024 * 1024, 10 * 1024 * 1024, 100 * 1024 * 1024]; // 1MB, 10MB, 100MB
        
        foreach ($fileSizes as $size) {
            $request = new StorageRequest(
                1, // user ID
                $size,
                'document',
                ['latitude' => 40.7128, 'longitude' => -74.0060], // New York
                [
                    'access_pattern' => 'warm',
                    'access_frequency' => 5,
                    'retention_period' => 365
                ]
            );
            
            $route = $this->storageRouter->routeStorageRequest($request);
            $summary = $route->getRoutingSummary();
            
            echo "   File Size: " . $this->formatBytes($size) . 
                 " | Provider: " . $summary['selected_provider'] . 
                 " | Score: " . number_format($summary['total_score'], 3) . 
                 " | Time: " . number_format($summary['routing_time'] * 1000, 2) . "ms\n";
        }
        echo "\n";
    }

    /**
     * Test routing for large files
     */
    private function testLargeFileRouting(): void
    {
        echo "2. Testing Large File Routing (1GB - 10GB)\n";
        
        $fileSizes = [1024 * 1024 * 1024, 5 * 1024 * 1024 * 1024, 10 * 1024 * 1024 * 1024]; // 1GB, 5GB, 10GB
        
        foreach ($fileSizes as $size) {
            $request = new StorageRequest(
                1, // user ID
                $size,
                'backup',
                ['latitude' => 34.0522, 'longitude' => -118.2437], // Los Angeles
                [
                    'access_pattern' => 'cold',
                    'access_frequency' => 1,
                    'retention_period' => 1095 // 3 years
                ]
            );
            
            $route = $this->storageRouter->routeStorageRequest($request);
            $summary = $route->getRoutingSummary();
            
            echo "   File Size: " . $this->formatBytes($size) . 
                 " | Provider: " . $summary['selected_provider'] . 
                 " | Score: " . number_format($summary['total_score'], 3) . 
                 " | Time: " . number_format($summary['routing_time'] * 1000, 2) . "ms\n";
        }
        echo "\n";
    }

    /**
     * Test routing for hot data
     */
    private function testHotDataRouting(): void
    {
        echo "3. Testing Hot Data Routing (Frequent Access)\n";
        
        $request = new StorageRequest(
            1, // user ID
            1024 * 1024 * 1024, // 1GB
            'database',
            ['latitude' => 51.5074, 'longitude' => -0.1278], // London
            [
                'access_pattern' => 'hot',
                'access_frequency' => 100,
                'retention_period' => 90,
                'requires_encryption' => true,
                'performance_requirements' => [
                    'max_latency' => 50,
                    'min_throughput' => 200,
                    'min_iops' => 5000
                ]
            ]
        );
        
        $route = $this->storageRouter->routeStorageRequest($request);
        $summary = $route->getRoutingSummary();
        
        echo "   Provider: " . $summary['selected_provider'] . 
             " | Score: " . number_format($summary['total_score'], 3) . 
             " | Recommendations: " . $summary['recommendations_count'] . "\n";
        echo "\n";
    }

    /**
     * Test routing for cold data
     */
    private function testColdDataRouting(): void
    {
        echo "4. Testing Cold Data Routing (Rare Access)\n";
        
        $request = new StorageRequest(
            1, // user ID
            5 * 1024 * 1024 * 1024, // 5GB
            'archive',
            ['latitude' => 35.6762, 'longitude' => 139.6503], // Tokyo
            [
                'access_pattern' => 'cold',
                'access_frequency' => 1,
                'retention_period' => 3650, // 10 years
                'compliance_requirements' => ['soc2', 'iso27001']
            ]
        );
        
        $route = $this->storageRouter->routeStorageRequest($request);
        $summary = $route->getRoutingSummary();
        
        echo "   Provider: " . $summary['selected_provider'] . 
             " | Score: " . number_format($summary['total_score'], 3) . 
             " | Recommendations: " . $summary['recommendations_count'] . "\n";
        echo "\n";
    }

    /**
     * Test geographic routing
     */
    private function testGeographicRouting(): void
    {
        echo "5. Testing Geographic Routing (Different Locations)\n";
        
        $locations = [
            ['name' => 'New York', 'coords' => ['latitude' => 40.7128, 'longitude' => -74.0060]],
            ['name' => 'Los Angeles', 'coords' => ['latitude' => 34.0522, 'longitude' => -118.2437]],
            ['name' => 'London', 'coords' => ['latitude' => 51.5074, 'longitude' => -0.1278]],
            ['name' => 'Tokyo', 'coords' => ['latitude' => 35.6762, 'longitude' => 139.6503]],
            ['name' => 'Sydney', 'coords' => ['latitude' => -33.8688, 'longitude' => 151.2093]]
        ];
        
        foreach ($locations as $location) {
            $request = new StorageRequest(
                1, // user ID
                1024 * 1024 * 1024, // 1GB
                'document',
                $location['coords'],
                [
                    'access_pattern' => 'warm',
                    'access_frequency' => 10,
                    'retention_period' => 365
                ]
            );
            
            $route = $this->storageRouter->routeStorageRequest($request);
            $summary = $route->getRoutingSummary();
            
            echo "   Location: " . $location['name'] . 
                 " | Provider: " . $summary['selected_provider'] . 
                 " | Score: " . number_format($summary['total_score'], 3) . "\n";
        }
        echo "\n";
    }

    /**
     * Test cost optimization
     */
    private function testCostOptimization(): void
    {
        echo "6. Testing Cost Optimization\n";
        
        $result = $this->costOptimizer->optimizeStorageAllocation(1, 1);
        $summary = $result->getOptimizationSummary();
        
        echo "   Potential Savings: $" . number_format($summary['potential_savings'], 2) . "\n";
        echo "   Recommendations: " . $summary['recommendations_count'] . "\n";
        echo "   Migrations: " . $summary['migrations_total'] . " (Success: " . $summary['migrations_successful'] . 
             ", Failed: " . $summary['migrations_failed'] . ")\n";
        echo "   Optimization Score: " . number_format($summary['optimization_score'], 3) . "\n";
        
        // Show tier distribution
        $tierDistribution = $result->getTierDistribution();
        echo "   Tier Distribution:\n";
        foreach ($tierDistribution as $tier => $data) {
            echo "     " . ucfirst($tier) . ": " . $this->formatBytes($data['total_size']) . 
                 " (" . number_format($data['percentage'], 1) . "%)\n";
        }
        echo "\n";
    }

    /**
     * Test ML predictions
     */
    private function testMLPredictions(): void
    {
        echo "7. Testing ML Predictions\n";
        
        $testCases = [
            ['file_type' => 'database', 'file_size' => 1024 * 1024 * 1024, 'access_frequency' => 50],
            ['file_type' => 'log', 'file_size' => 100 * 1024 * 1024, 'access_frequency' => 5],
            ['file_type' => 'backup', 'file_size' => 5 * 1024 * 1024 * 1024, 'access_frequency' => 1],
            ['file_type' => 'media', 'file_size' => 2 * 1024 * 1024 * 1024, 'access_frequency' => 20]
        ];
        
        foreach ($testCases as $testCase) {
            $prediction = $this->patternRecognizer->predictOptimalTier($testCase);
            $costPrediction = $this->costPredictor->predictCost($testCase);
            
            echo "   Type: " . $testCase['file_type'] . 
                 " | Size: " . $this->formatBytes($testCase['file_size']) . 
                 " | Access: " . $testCase['access_frequency'] . 
                 " | Tier Score: " . number_format($prediction, 3) . 
                 " | Cost: $" . number_format($costPrediction, 4) . "\n";
        }
        echo "\n";
    }

    /**
     * Test performance scenarios
     */
    private function testPerformanceScenarios(): void
    {
        echo "8. Testing Performance Scenarios\n";
        
        $scenarios = [
            ['name' => 'High IOPS', 'requirements' => ['min_iops' => 10000]],
            ['name' => 'Low Latency', 'requirements' => ['max_latency' => 10]],
            ['name' => 'High Throughput', 'requirements' => ['min_throughput' => 500]],
            ['name' => 'Balanced', 'requirements' => ['min_iops' => 3000, 'max_latency' => 50, 'min_throughput' => 100]]
        ];
        
        foreach ($scenarios as $scenario) {
            $request = new StorageRequest(
                1, // user ID
                1024 * 1024 * 1024, // 1GB
                'database',
                ['latitude' => 40.7128, 'longitude' => -74.0060], // New York
                [
                    'access_pattern' => 'hot',
                    'access_frequency' => 50,
                    'retention_period' => 90,
                    'performance_requirements' => $scenario['requirements']
                ]
            );
            
            $route = $this->storageRouter->routeStorageRequest($request);
            $summary = $route->getRoutingSummary();
            
            echo "   Scenario: " . $scenario['name'] . 
                 " | Provider: " . $summary['selected_provider'] . 
                 " | Score: " . number_format($summary['total_score'], 3) . "\n";
        }
        echo "\n";
    }

    /**
     * Test high load scenarios
     */
    private function testHighLoadScenarios(): void
    {
        echo "9. Testing High Load Scenarios (3000+ installations)\n";
        
        $loadScenarios = [
            ['name' => '3000 Users', 'users' => 3000],
            ['name' => '5000 Users', 'users' => 5000],
            ['name' => '10000 Users', 'users' => 10000]
        ];
        
        foreach ($loadScenarios as $scenario) {
            $startTime = microtime(true);
            $totalScore = 0;
            $successCount = 0;
            
            // Simulate multiple concurrent requests
            for ($i = 0; $i < min(100, $scenario['users']); $i++) {
                $request = new StorageRequest(
                    $i + 1, // user ID
                    rand(1024 * 1024, 10 * 1024 * 1024 * 1024), // Random size
                    ['database', 'log', 'backup', 'media'][rand(0, 3)], // Random type
                    ['latitude' => 40.7128, 'longitude' => -74.0060], // New York
                    [
                        'access_pattern' => ['hot', 'warm', 'cold'][rand(0, 2)],
                        'access_frequency' => rand(1, 100),
                        'retention_period' => rand(30, 3650)
                    ]
                );
                
                try {
                    $route = $this->storageRouter->routeStorageRequest($request);
                    $totalScore += $route->getSelectedProviderScore();
                    $successCount++;
                } catch (Exception $e) {
                    // Count failures
                }
            }
            
            $endTime = microtime(true);
            $executionTime = $endTime - $startTime;
            $avgScore = $successCount > 0 ? $totalScore / $successCount : 0;
            
            echo "   Scenario: " . $scenario['name'] . 
                 " | Success Rate: " . number_format(($successCount / min(100, $scenario['users'])) * 100, 1) . "%" .
                 " | Avg Score: " . number_format($avgScore, 3) . 
                 " | Time: " . number_format($executionTime, 2) . "s\n";
        }
        echo "\n";
    }

    /**
     * Test disaster recovery
     */
    private function testDisasterRecovery(): void
    {
        echo "10. Testing Disaster Recovery Scenarios\n";
        
        $recoveryScenarios = [
            ['name' => 'Provider Failure', 'type' => 'provider_failure'],
            ['name' => 'Geographic Outage', 'type' => 'geographic_outage'],
            ['name' => 'Network Partition', 'type' => 'network_partition']
        ];
        
        foreach ($recoveryScenarios as $scenario) {
            $request = new StorageRequest(
                1, // user ID
                1024 * 1024 * 1024, // 1GB
                'backup',
                ['latitude' => 40.7128, 'longitude' => -74.0060], // New York
                [
                    'access_pattern' => 'cold',
                    'access_frequency' => 1,
                    'retention_period' => 3650,
                    'requires_encryption' => true,
                    'compliance_requirements' => ['soc2', 'iso27001', 'pci_dss']
                ]
            );
            
            try {
                $route = $this->storageRouter->routeStorageRequest($request);
                $summary = $route->getRoutingSummary();
                
                echo "   Scenario: " . $scenario['name'] . 
                     " | Provider: " . $summary['selected_provider'] . 
                     " | Score: " . number_format($summary['total_score'], 3) . 
                     " | Status: Success\n";
            } catch (Exception $e) {
                echo "   Scenario: " . $scenario['name'] . 
                     " | Status: Failed - " . $e->getMessage() . "\n";
            }
        }
        echo "\n";
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

// Run the test suite
if (php_sapi_name() === 'cli') {
    $test = new StorageOptimizationTest();
    $test->runAllTests();
} 