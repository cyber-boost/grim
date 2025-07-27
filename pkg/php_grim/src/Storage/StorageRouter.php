<?php

namespace GrimReaper\Storage;

use GrimReaper\ML\PatternRecognizer;
use GrimReaper\Analytics\CostAnalyzer;
use GrimReaper\Monitoring\AvailabilityMonitor;

/**
 * Intelligent Storage Router with ML-powered optimization
 * Handles geographic proximity, cost efficiency, performance, and availability
 */
class StorageRouter
{
    private PatternRecognizer $patternRecognizer;
    private CostAnalyzer $costAnalyzer;
    private AvailabilityMonitor $availabilityMonitor;
    private array $storageProviders;
    private array $routingWeights;
    private array $mlModels;

    public function __construct()
    {
        $this->patternRecognizer = new PatternRecognizer();
        $this->costAnalyzer = new CostAnalyzer();
        $this->availabilityMonitor = new AvailabilityMonitor();
        $this->initializeProviders();
        $this->initializeWeights();
        $this->loadMLModels();
    }

    /**
     * Main routing method with intelligent decision making
     */
    public function routeStorageRequest(StorageRequest $request): StorageRoute
    {
        $startTime = microtime(true);
        
        try {
            // Analyze request patterns using ML
            $patternScore = $this->analyzeAccessPatterns($request);
            
            // Get available providers with real-time status
            $availableProviders = $this->getAvailableProviders($request->getGeographicLocation());
            
            // Calculate routing scores for each provider
            $providerScores = $this->calculateProviderScores($request, $availableProviders, $patternScore);
            
            // Select optimal provider based on weighted scoring
            $selectedProvider = $this->selectOptimalProvider($providerScores);
            
            // Generate cost optimization recommendations
            $optimizationRecommendations = $this->generateOptimizationRecommendations($request, $selectedProvider);
            
            // Create storage route with metadata
            $route = new StorageRoute(
                $selectedProvider,
                $request,
                $providerScores,
                $optimizationRecommendations,
                microtime(true) - $startTime
            );
            
            // Log routing decision for ML training
            $this->logRoutingDecision($route);
            
            return $route;
            
        } catch (\Exception $e) {
            error_log("Storage routing error: " . $e->getMessage());
            return $this->getFallbackRoute($request);
        }
    }

    /**
     * Geographic proximity scoring (40% weight)
     */
    private function calculateGeographicScore(StorageRequest $request, StorageProvider $provider): float
    {
        $userLocation = $request->getGeographicLocation();
        $providerLocation = $provider->getGeographicLocation();
        
        // Calculate distance using Haversine formula
        $distance = $this->calculateDistance($userLocation, $providerLocation);
        
        // Normalize distance (0-1 scale, closer is better)
        $maxDistance = 20000; // 20,000 km max
        $normalizedDistance = min($distance / $maxDistance, 1.0);
        
        // Convert to score (closer = higher score)
        $geographicScore = 1.0 - $normalizedDistance;
        
        // Apply network latency factor
        $latencyFactor = $this->getNetworkLatencyFactor($userLocation, $providerLocation);
        $geographicScore *= $latencyFactor;
        
        return $geographicScore;
    }

    /**
     * Cost efficiency algorithms (30% weight)
     */
    private function calculateCostScore(StorageRequest $request, StorageProvider $provider): float
    {
        $fileSize = $request->getFileSize();
        $accessPattern = $request->getAccessPattern();
        $retentionPeriod = $request->getRetentionPeriod();
        
        // Calculate storage cost
        $storageCost = $this->calculateStorageCost($provider, $fileSize, $retentionPeriod);
        
        // Calculate transfer cost
        $transferCost = $this->calculateTransferCost($provider, $fileSize, $accessPattern);
        
        // Calculate operational cost
        $operationalCost = $this->calculateOperationalCost($provider, $request);
        
        $totalCost = $storageCost + $transferCost + $operationalCost;
        
        // Normalize cost (lower is better)
        $maxExpectedCost = $this->getMaxExpectedCost($request);
        $costScore = max(0, 1 - ($totalCost / $maxExpectedCost));
        
        // Apply cost optimization factors
        $costScore *= $this->getCostOptimizationFactor($provider, $request);
        
        return $costScore;
    }

    /**
     * Performance-based routing (20% weight)
     */
    private function calculatePerformanceScore(StorageRequest $request, StorageProvider $provider): float
    {
        $performanceMetrics = $this->getProviderPerformanceMetrics($provider);
        
        // I/O performance score
        $ioScore = $this->calculateIOScore($performanceMetrics, $request);
        
        // Throughput score
        $throughputScore = $this->calculateThroughputScore($performanceMetrics, $request);
        
        // Latency score
        $latencyScore = $this->calculateLatencyScore($performanceMetrics, $request);
        
        // Availability score
        $availabilityScore = $performanceMetrics['uptime'] / 100;
        
        // Weighted performance score
        $performanceScore = ($ioScore * 0.3) + ($throughputScore * 0.3) + 
                           ($latencyScore * 0.2) + ($availabilityScore * 0.2);
        
        return $performanceScore;
    }

    /**
     * Availability monitoring (10% weight)
     */
    private function calculateAvailabilityScore(StorageProvider $provider): float
    {
        $availabilityData = $this->availabilityMonitor->getProviderAvailability($provider->getId());
        
        // Historical uptime
        $historicalUptime = $availabilityData['historical_uptime'] / 100;
        
        // Current status
        $currentStatus = $availabilityData['current_status'] ? 1.0 : 0.0;
        
        // SLA compliance
        $slaCompliance = $availabilityData['sla_compliance'] / 100;
        
        // Incident frequency (lower is better)
        $incidentFrequency = max(0, 1 - ($availabilityData['incidents_last_30_days'] / 10));
        
        // Weighted availability score
        $availabilityScore = ($historicalUptime * 0.4) + ($currentStatus * 0.3) + 
                            ($slaCompliance * 0.2) + ($incidentFrequency * 0.1);
        
        return $availabilityScore;
    }

    /**
     * ML-powered pattern recognition for access patterns
     */
    private function analyzeAccessPatterns(StorageRequest $request): float
    {
        $fileType = $request->getFileType();
        $fileSize = $request->getFileSize();
        $accessFrequency = $request->getAccessFrequency();
        $timeOfDay = $request->getTimeOfDay();
        
        // Use ML model to predict optimal storage tier
        $patternFeatures = [
            'file_type' => $fileType,
            'file_size' => $fileSize,
            'access_frequency' => $accessFrequency,
            'time_of_day' => $timeOfDay,
            'user_id' => $request->getUserId(),
            'project_id' => $request->getProjectId()
        ];
        
        $patternScore = $this->patternRecognizer->predictOptimalTier($patternFeatures);
        
        return $patternScore;
    }

    /**
     * Calculate weighted provider scores
     */
    private function calculateProviderScores(StorageRequest $request, array $providers, float $patternScore): array
    {
        $scores = [];
        
        foreach ($providers as $provider) {
            $geographicScore = $this->calculateGeographicScore($request, $provider);
            $costScore = $this->calculateCostScore($request, $provider);
            $performanceScore = $this->calculatePerformanceScore($request, $provider);
            $availabilityScore = $this->calculateAvailabilityScore($provider);
            
            // Apply weights
            $weightedScore = ($geographicScore * $this->routingWeights['geographic']) +
                           ($costScore * $this->routingWeights['cost']) +
                           ($performanceScore * $this->routingWeights['performance']) +
                           ($availabilityScore * $this->routingWeights['availability']);
            
            // Apply ML pattern adjustment
            $adjustedScore = $weightedScore * (1 + ($patternScore * 0.1));
            
            $scores[$provider->getId()] = [
                'provider' => $provider,
                'total_score' => $adjustedScore,
                'geographic_score' => $geographicScore,
                'cost_score' => $costScore,
                'performance_score' => $performanceScore,
                'availability_score' => $availabilityScore,
                'pattern_score' => $patternScore
            ];
        }
        
        return $scores;
    }

    /**
     * Select optimal provider based on scores
     */
    private function selectOptimalProvider(array $providerScores): StorageProvider
    {
        // Sort by total score (descending)
        uasort($providerScores, function($a, $b) {
            return $b['total_score'] <=> $a['total_score'];
        });
        
        // Get top provider
        $topProvider = reset($providerScores);
        
        // Apply load balancing for high-scoring providers
        if (count($providerScores) > 1) {
            $topProviders = array_slice($providerScores, 0, 3, true);
            $totalScore = array_sum(array_column($topProviders, 'total_score'));
            
            // Weighted random selection among top providers
            $random = mt_rand() / mt_getrandmax() * $totalScore;
            $cumulativeScore = 0;
            
            foreach ($topProviders as $providerId => $scoreData) {
                $cumulativeScore += $scoreData['total_score'];
                if ($random <= $cumulativeScore) {
                    return $scoreData['provider'];
                }
            }
        }
        
        return $topProvider['provider'];
    }

    /**
     * Generate cost optimization recommendations
     */
    private function generateOptimizationRecommendations(StorageRequest $request, StorageProvider $provider): array
    {
        $recommendations = [];
        
        // Analyze current usage patterns
        $usageAnalysis = $this->costAnalyzer->analyzeUsagePatterns($request->getUserId());
        
        // Storage tier optimization
        if ($usageAnalysis['hot_data_ratio'] > 0.8) {
            $recommendations[] = [
                'type' => 'tier_optimization',
                'message' => 'High hot data ratio detected. Consider moving cold data to lower-cost tiers.',
                'potential_savings' => $usageAnalysis['potential_tier_savings'],
                'priority' => 'high'
            ];
        }
        
        // Compression optimization
        $compressionAnalysis = $this->costAnalyzer->analyzeCompressionOpportunities($request);
        if ($compressionAnalysis['compression_ratio'] > 1.5) {
            $recommendations[] = [
                'type' => 'compression',
                'message' => 'High compression potential detected. Enable compression for cost savings.',
                'potential_savings' => $compressionAnalysis['potential_savings'],
                'priority' => 'medium'
            ];
        }
        
        // Deduplication opportunities
        $deduplicationAnalysis = $this->costAnalyzer->analyzeDeduplicationOpportunities($request);
        if ($deduplicationAnalysis['duplicate_ratio'] > 0.1) {
            $recommendations[] = [
                'type' => 'deduplication',
                'message' => 'Duplicate data detected. Enable deduplication for storage optimization.',
                'potential_savings' => $deduplicationAnalysis['potential_savings'],
                'priority' => 'medium'
            ];
        }
        
        return $recommendations;
    }

    /**
     * Initialize storage providers
     */
    private function initializeProviders(): void
    {
        $this->storageProviders = [
            'aws_s3' => new StorageProvider('aws_s3', 'Amazon S3', [
                'geographic_location' => ['us-east-1', 'us-west-2', 'eu-west-1'],
                'cost_per_gb' => 0.023,
                'transfer_cost_per_gb' => 0.09,
                'performance_tier' => 'standard'
            ]),
            'gcp_storage' => new StorageProvider('gcp_storage', 'Google Cloud Storage', [
                'geographic_location' => ['us-central1', 'europe-west1'],
                'cost_per_gb' => 0.020,
                'transfer_cost_per_gb' => 0.12,
                'performance_tier' => 'standard'
            ]),
            'azure_blob' => new StorageProvider('azure_blob', 'Azure Blob Storage', [
                'geographic_location' => ['eastus', 'westeurope'],
                'cost_per_gb' => 0.018,
                'transfer_cost_per_gb' => 0.087,
                'performance_tier' => 'standard'
            ]),
            'local_storage' => new StorageProvider('local_storage', 'Local Storage', [
                'geographic_location' => ['local'],
                'cost_per_gb' => 0.001,
                'transfer_cost_per_gb' => 0.0,
                'performance_tier' => 'premium'
            ])
        ];
    }

    /**
     * Initialize routing weights
     */
    private function initializeWeights(): void
    {
        $this->routingWeights = [
            'geographic' => 0.40,  // 40% weight
            'cost' => 0.30,        // 30% weight
            'performance' => 0.20, // 20% weight
            'availability' => 0.10 // 10% weight
        ];
    }

    /**
     * Load ML models for pattern recognition
     */
    private function loadMLModels(): void
    {
        $this->mlModels = [
            'access_pattern' => $this->patternRecognizer->loadModel('access_pattern_model.json'),
            'cost_prediction' => $this->costAnalyzer->loadModel('cost_prediction_model.json'),
            'performance_prediction' => $this->loadPerformanceModel()
        ];
    }

    /**
     * Calculate distance between two geographic points
     */
    private function calculateDistance(array $point1, array $point2): float
    {
        $lat1 = deg2rad($point1['latitude']);
        $lon1 = deg2rad($point1['longitude']);
        $lat2 = deg2rad($point2['latitude']);
        $lon2 = deg2rad($point2['longitude']);
        
        $dlat = $lat2 - $lat1;
        $dlon = $lon2 - $lon1;
        
        $a = sin($dlat/2) * sin($dlat/2) + cos($lat1) * cos($lat2) * sin($dlon/2) * sin($dlon/2);
        $c = 2 * atan2(sqrt($a), sqrt(1-$a));
        
        return 6371 * $c; // Earth radius in km
    }

    /**
     * Get network latency factor
     */
    private function getNetworkLatencyFactor(array $userLocation, array $providerLocation): float
    {
        // Simplified latency calculation
        $distance = $this->calculateDistance($userLocation, $providerLocation);
        
        // Base latency: 1ms per 100km + 50ms base
        $latency = ($distance * 0.01) + 50;
        
        // Normalize to 0-1 scale (lower latency = higher factor)
        $maxLatency = 500; // 500ms max
        return max(0.1, 1 - ($latency / $maxLatency));
    }

    /**
     * Calculate storage cost
     */
    private function calculateStorageCost(StorageProvider $provider, int $fileSize, int $retentionPeriod): float
    {
        $costPerGB = $provider->getCostPerGB();
        $sizeInGB = $fileSize / (1024 * 1024 * 1024);
        $months = $retentionPeriod / 30;
        
        return $costPerGB * $sizeInGB * $months;
    }

    /**
     * Calculate transfer cost
     */
    private function calculateTransferCost(StorageProvider $provider, int $fileSize, string $accessPattern): float
    {
        $transferCostPerGB = $provider->getTransferCostPerGB();
        $sizeInGB = $fileSize / (1024 * 1024 * 1024);
        
        // Estimate transfer frequency based on access pattern
        $transferMultiplier = $this->getTransferMultiplier($accessPattern);
        
        return $transferCostPerGB * $sizeInGB * $transferMultiplier;
    }

    /**
     * Calculate operational cost
     */
    private function calculateOperationalCost(StorageProvider $provider, StorageRequest $request): float
    {
        // Base operational cost
        $baseCost = 0.01; // $0.01 per request
        
        // Additional costs based on request complexity
        $complexityMultiplier = $this->getRequestComplexityMultiplier($request);
        
        return $baseCost * $complexityMultiplier;
    }

    /**
     * Get transfer multiplier based on access pattern
     */
    private function getTransferMultiplier(string $accessPattern): float
    {
        $multipliers = [
            'hot' => 10.0,    // Frequent access
            'warm' => 2.0,    // Moderate access
            'cold' => 0.1,    // Rare access
            'archive' => 0.01 // Very rare access
        ];
        
        return $multipliers[$accessPattern] ?? 1.0;
    }

    /**
     * Get request complexity multiplier
     */
    private function getRequestComplexityMultiplier(StorageRequest $request): float
    {
        $multiplier = 1.0;
        
        if ($request->requiresEncryption()) {
            $multiplier *= 1.2;
        }
        
        if ($request->requiresCompression()) {
            $multiplier *= 1.1;
        }
        
        if ($request->requiresDeduplication()) {
            $multiplier *= 1.3;
        }
        
        return $multiplier;
    }

    /**
     * Get max expected cost for normalization
     */
    private function getMaxExpectedCost(StorageRequest $request): float
    {
        $fileSize = $request->getFileSize();
        $sizeInGB = $fileSize / (1024 * 1024 * 1024);
        
        // Conservative estimate: $0.05 per GB per month
        return $sizeInGB * 0.05 * 12; // 12 months
    }

    /**
     * Get cost optimization factor
     */
    private function getCostOptimizationFactor(StorageProvider $provider, StorageRequest $request): float
    {
        $factor = 1.0;
        
        // Volume discounts
        $volumeDiscount = $this->getVolumeDiscount($provider, $request);
        $factor *= (1 - $volumeDiscount);
        
        // Reserved capacity discounts
        $reservedDiscount = $this->getReservedCapacityDiscount($provider, $request);
        $factor *= (1 - $reservedDiscount);
        
        return $factor;
    }

    /**
     * Get volume discount
     */
    private function getVolumeDiscount(StorageProvider $provider, StorageRequest $request): float
    {
        $monthlyUsage = $this->getMonthlyUsage($request->getUserId());
        
        if ($monthlyUsage > 1000) { // 1TB
            return 0.15; // 15% discount
        } elseif ($monthlyUsage > 100) { // 100GB
            return 0.10; // 10% discount
        } elseif ($monthlyUsage > 10) { // 10GB
            return 0.05; // 5% discount
        }
        
        return 0.0;
    }

    /**
     * Get reserved capacity discount
     */
    private function getReservedCapacityDiscount(StorageProvider $provider, StorageRequest $request): float
    {
        // Check if user has reserved capacity
        $reservedCapacity = $this->getReservedCapacity($request->getUserId());
        
        if ($reservedCapacity > 0) {
            return 0.20; // 20% discount for reserved capacity
        }
        
        return 0.0;
    }

    /**
     * Get provider performance metrics
     */
    private function getProviderPerformanceMetrics(StorageProvider $provider): array
    {
        return [
            'iops' => $provider->getIOPS(),
            'throughput' => $provider->getThroughput(),
            'latency' => $provider->getLatency(),
            'uptime' => $provider->getUptime(),
            'error_rate' => $provider->getErrorRate()
        ];
    }

    /**
     * Calculate I/O score
     */
    private function calculateIOScore(array $metrics, StorageRequest $request): float
    {
        $requiredIOPS = $this->estimateRequiredIOPS($request);
        $availableIOPS = $metrics['iops'];
        
        return min(1.0, $availableIOPS / $requiredIOPS);
    }

    /**
     * Calculate throughput score
     */
    private function calculateThroughputScore(array $metrics, StorageRequest $request): float
    {
        $requiredThroughput = $this->estimateRequiredThroughput($request);
        $availableThroughput = $metrics['throughput'];
        
        return min(1.0, $availableThroughput / $requiredThroughput);
    }

    /**
     * Calculate latency score
     */
    private function calculateLatencyScore(array $metrics, StorageRequest $request): float
    {
        $maxAcceptableLatency = $this->getMaxAcceptableLatency($request);
        $actualLatency = $metrics['latency'];
        
        return max(0, 1 - ($actualLatency / $maxAcceptableLatency));
    }

    /**
     * Estimate required IOPS
     */
    private function estimateRequiredIOPS(StorageRequest $request): int
    {
        $fileSize = $request->getFileSize();
        $accessPattern = $request->getAccessPattern();
        
        $baseIOPS = 100;
        
        // Adjust based on file size
        if ($fileSize > 1024 * 1024 * 1024) { // > 1GB
            $baseIOPS *= 2;
        }
        
        // Adjust based on access pattern
        $patternMultipliers = [
            'hot' => 3,
            'warm' => 1,
            'cold' => 0.5,
            'archive' => 0.1
        ];
        
        return $baseIOPS * ($patternMultipliers[$accessPattern] ?? 1);
    }

    /**
     * Estimate required throughput
     */
    private function estimateRequiredThroughput(StorageRequest $request): float
    {
        $fileSize = $request->getFileSize();
        $accessPattern = $request->getAccessPattern();
        
        $baseThroughput = 100; // MB/s
        
        // Adjust based on access pattern
        $patternMultipliers = [
            'hot' => 2,
            'warm' => 1,
            'cold' => 0.5,
            'archive' => 0.2
        ];
        
        return $baseThroughput * ($patternMultipliers[$accessPattern] ?? 1);
    }

    /**
     * Get max acceptable latency
     */
    private function getMaxAcceptableLatency(StorageRequest $request): float
    {
        $accessPattern = $request->getAccessPattern();
        
        $maxLatencies = [
            'hot' => 50,    // 50ms for hot data
            'warm' => 200,  // 200ms for warm data
            'cold' => 1000, // 1s for cold data
            'archive' => 5000 // 5s for archive data
        ];
        
        return $maxLatencies[$accessPattern] ?? 500;
    }

    /**
     * Get available providers for location
     */
    private function getAvailableProviders(array $userLocation): array
    {
        $availableProviders = [];
        
        foreach ($this->storageProviders as $provider) {
            if ($this->availabilityMonitor->isProviderAvailable($provider->getId())) {
                $availableProviders[] = $provider;
            }
        }
        
        return $availableProviders;
    }

    /**
     * Get monthly usage for user
     */
    private function getMonthlyUsage(int $userId): float
    {
        // This would typically query a database
        // For now, return a mock value
        return 50.0; // 50GB
    }

    /**
     * Get reserved capacity for user
     */
    private function getReservedCapacity(int $userId): float
    {
        // This would typically query a database
        // For now, return a mock value
        return 0.0; // No reserved capacity
    }

    /**
     * Load performance model
     */
    private function loadPerformanceModel(): object
    {
        // Mock performance model
        return (object) [
            'predict' => function($features) {
                return 0.85; // Mock prediction
            }
        ];
    }

    /**
     * Log routing decision for ML training
     */
    private function logRoutingDecision(StorageRoute $route): void
    {
        $decisionLog = [
            'timestamp' => time(),
            'request_id' => $route->getRequest()->getId(),
            'selected_provider' => $route->getProvider()->getId(),
            'provider_scores' => $route->getProviderScores(),
            'optimization_recommendations' => $route->getOptimizationRecommendations(),
            'routing_time' => $route->getRoutingTime()
        ];
        
        // Store in database or log file for ML training
        file_put_contents('logs/routing_decisions.log', json_encode($decisionLog) . "\n", FILE_APPEND);
    }

    /**
     * Get fallback route when routing fails
     */
    private function getFallbackRoute(StorageRequest $request): StorageRoute
    {
        $fallbackProvider = $this->storageProviders['local_storage'];
        
        return new StorageRoute(
            $fallbackProvider,
            $request,
            [],
            [],
            0.0
        );
    }
} 