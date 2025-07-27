<?php

namespace GrimReaper\Analytics;

use GrimReaper\Storage\StorageRequest;

/**
 * Cost Analyzer for storage cost optimization and analysis
 */
class CostAnalyzer
{
    private array $costData;
    private array $usagePatterns;
    private array $optimizationModels;

    public function __construct()
    {
        $this->costData = [];
        $this->usagePatterns = [];
        $this->initializeOptimizationModels();
    }

    /**
     * Analyze usage patterns for a user
     */
    public function analyzeUsagePatterns(int $userId): array
    {
        $usageData = $this->getUserUsageData($userId);
        
        return [
            'total_size' => $usageData['total_size'],
            'total_cost' => $usageData['total_cost'],
            'hot_data_ratio' => $this->calculateHotDataRatio($usageData),
            'cold_data_ratio' => $this->calculateColdDataRatio($usageData),
            'access_patterns' => $this->analyzeAccessPatterns($usageData),
            'cost_trends' => $this->analyzeCostTrends($usageData),
            'potential_tier_savings' => $this->calculatePotentialTierSavings($usageData),
            'optimization_opportunities' => $this->identifyOptimizationOpportunities($usageData)
        ];
    }

    /**
     * Analyze compression opportunities
     */
    public function analyzeCompressionOpportunities(StorageRequest $request): array
    {
        $fileType = $request->getFileType();
        $fileSize = $request->getFileSize();
        
        $compressionRatios = [
            'text' => 0.3,
            'log' => 0.2,
            'json' => 0.4,
            'xml' => 0.5,
            'csv' => 0.3,
            'document' => 0.6,
            'image' => 0.8,
            'video' => 0.9,
            'audio' => 0.7
        ];
        
        $compressionRatio = $compressionRatios[$fileType] ?? 0.5;
        $originalSize = $fileSize;
        $compressedSize = $fileSize * $compressionRatio;
        $savings = $originalSize - $compressedSize;
        
        return [
            'compression_ratio' => $compressionRatio,
            'original_size' => $originalSize,
            'compressed_size' => $compressedSize,
            'savings' => $savings,
            'savings_percentage' => (1 - $compressionRatio) * 100,
            'recommended' => $compressionRatio < 0.8
        ];
    }

    /**
     * Analyze deduplication opportunities
     */
    public function analyzeDeduplicationOpportunities(StorageRequest $request): array
    {
        $userId = $request->getUserId();
        $fileType = $request->getFileType();
        $fileSize = $request->getFileSize();
        
        // Get user's existing files
        $existingFiles = $this->getUserFiles($userId);
        
        // Find potential duplicates
        $duplicates = $this->findPotentialDuplicates($existingFiles, $fileType, $fileSize);
        
        $totalDuplicateSize = 0;
        foreach ($duplicates as $duplicate) {
            $totalDuplicateSize += $duplicate['size'];
        }
        
        $savings = $totalDuplicateSize * 0.8; // Assume 80% savings from deduplication
        
        return [
            'duplicate_count' => count($duplicates),
            'duplicate_size' => $totalDuplicateSize,
            'savings' => $savings,
            'savings_percentage' => $totalDuplicateSize > 0 ? ($savings / $totalDuplicateSize) * 100 : 0,
            'recommended' => count($duplicates) > 0
        ];
    }

    /**
     * Get user usage data
     */
    private function getUserUsageData(int $userId): array
    {
        // Mock implementation - would query database
        return [
            'total_size' => 1024 * 1024 * 1024 * 100, // 100GB
            'total_cost' => 2.30, // $2.30
            'files' => [
                [
                    'id' => 1,
                    'size' => 1024 * 1024 * 1024 * 10, // 10GB
                    'tier' => 'hot',
                    'access_count' => 50,
                    'last_access' => time() - 3600
                ],
                [
                    'id' => 2,
                    'size' => 1024 * 1024 * 1024 * 20, // 20GB
                    'tier' => 'warm',
                    'access_count' => 10,
                    'last_access' => time() - 86400
                ],
                [
                    'id' => 3,
                    'size' => 1024 * 1024 * 1024 * 70, // 70GB
                    'tier' => 'cold',
                    'access_count' => 2,
                    'last_access' => time() - 604800
                ]
            ]
        ];
    }

    /**
     * Calculate hot data ratio
     */
    private function calculateHotDataRatio(array $usageData): float
    {
        $totalSize = 0;
        $hotSize = 0;
        
        foreach ($usageData['files'] as $file) {
            $totalSize += $file['size'];
            if ($file['tier'] === 'hot') {
                $hotSize += $file['size'];
            }
        }
        
        return $totalSize > 0 ? $hotSize / $totalSize : 0.0;
    }

    /**
     * Calculate cold data ratio
     */
    private function calculateColdDataRatio(array $usageData): float
    {
        $totalSize = 0;
        $coldSize = 0;
        
        foreach ($usageData['files'] as $file) {
            $totalSize += $file['size'];
            if ($file['tier'] === 'cold' || $file['tier'] === 'archive') {
                $coldSize += $file['size'];
            }
        }
        
        return $totalSize > 0 ? $coldSize / $totalSize : 0.0;
    }

    /**
     * Analyze access patterns
     */
    private function analyzeAccessPatterns(array $usageData): array
    {
        $patterns = [
            'frequent' => 0,
            'moderate' => 0,
            'rare' => 0,
            'never' => 0
        ];
        
        foreach ($usageData['files'] as $file) {
            $accessCount = $file['access_count'];
            
            if ($accessCount >= 20) {
                $patterns['frequent']++;
            } elseif ($accessCount >= 5) {
                $patterns['moderate']++;
            } elseif ($accessCount >= 1) {
                $patterns['rare']++;
            } else {
                $patterns['never']++;
            }
        }
        
        return $patterns;
    }

    /**
     * Analyze cost trends
     */
    private function analyzeCostTrends(array $usageData): array
    {
        // Mock implementation - would analyze historical cost data
        return [
            'monthly_growth' => 0.05, // 5% monthly growth
            'cost_per_gb' => 0.023,
            'projected_monthly_cost' => $usageData['total_cost'] * 1.05,
            'trend' => 'increasing'
        ];
    }

    /**
     * Calculate potential tier savings
     */
    private function calculatePotentialTierSavings(array $usageData): float
    {
        $potentialSavings = 0.0;
        
        foreach ($usageData['files'] as $file) {
            $currentTier = $file['tier'];
            $fileSize = $file['size'];
            $accessCount = $file['access_count'];
            
            // Determine optimal tier based on access pattern
            $optimalTier = $this->determineOptimalTier($accessCount);
            
            if ($optimalTier !== $currentTier) {
                $currentCost = $this->getTierCost($currentTier, $fileSize);
                $optimalCost = $this->getTierCost($optimalTier, $fileSize);
                $potentialSavings += ($currentCost - $optimalCost);
            }
        }
        
        return $potentialSavings;
    }

    /**
     * Identify optimization opportunities
     */
    private function identifyOptimizationOpportunities(array $usageData): array
    {
        $opportunities = [];
        
        // Check for underutilized hot storage
        $hotDataRatio = $this->calculateHotDataRatio($usageData);
        if ($hotDataRatio > 0.8) {
            $opportunities[] = [
                'type' => 'hot_storage_optimization',
                'priority' => 'high',
                'description' => 'High hot data ratio detected',
                'potential_savings' => $usageData['total_cost'] * 0.2
            ];
        }
        
        // Check for compression opportunities
        $compressionOpportunities = $this->findCompressionOpportunities($usageData);
        if (!empty($compressionOpportunities)) {
            $opportunities[] = [
                'type' => 'compression_optimization',
                'priority' => 'medium',
                'description' => 'Compression opportunities found',
                'potential_savings' => $compressionOpportunities['total_savings']
            ];
        }
        
        // Check for lifecycle policy opportunities
        $lifecycleOpportunities = $this->findLifecycleOpportunities($usageData);
        if (!empty($lifecycleOpportunities)) {
            $opportunities[] = [
                'type' => 'lifecycle_optimization',
                'priority' => 'medium',
                'description' => 'Lifecycle policy opportunities found',
                'potential_savings' => $lifecycleOpportunities['total_savings']
            ];
        }
        
        return $opportunities;
    }

    /**
     * Determine optimal tier based on access count
     */
    private function determineOptimalTier(int $accessCount): string
    {
        if ($accessCount >= 20) {
            return 'hot';
        } elseif ($accessCount >= 5) {
            return 'warm';
        } elseif ($accessCount >= 1) {
            return 'cold';
        } else {
            return 'archive';
        }
    }

    /**
     * Get tier cost
     */
    private function getTierCost(string $tier, int $fileSize): float
    {
        $sizeInGB = $fileSize / (1024 * 1024 * 1024);
        
        $tierCosts = [
            'hot' => 0.023,
            'warm' => 0.0125,
            'cold' => 0.004,
            'archive' => 0.0004
        ];
        
        $costPerGB = $tierCosts[$tier] ?? 0.0125;
        return $costPerGB * $sizeInGB;
    }

    /**
     * Find compression opportunities
     */
    private function findCompressionOpportunities(array $usageData): array
    {
        $opportunities = [];
        $totalSavings = 0.0;
        
        $compressibleTypes = ['text', 'log', 'json', 'xml', 'csv', 'document'];
        
        foreach ($usageData['files'] as $file) {
            if (in_array($file['type'] ?? 'unknown', $compressibleTypes)) {
                $compressionRatio = 0.5; // Assume 50% compression
                $savings = $file['size'] * (1 - $compressionRatio) * 0.023; // Cost per GB
                
                $opportunities[] = [
                    'file_id' => $file['id'],
                    'compression_ratio' => $compressionRatio,
                    'savings' => $savings
                ];
                
                $totalSavings += $savings;
            }
        }
        
        return [
            'opportunities' => $opportunities,
            'total_savings' => $totalSavings
        ];
    }

    /**
     * Find lifecycle opportunities
     */
    private function findLifecycleOpportunities(array $usageData): array
    {
        $opportunities = [];
        $totalSavings = 0.0;
        
        $currentTime = time();
        $oneYearAgo = $currentTime - (365 * 24 * 3600);
        
        foreach ($usageData['files'] as $file) {
            if ($file['last_access'] < $oneYearAgo && $file['tier'] !== 'archive') {
                $currentCost = $this->getTierCost($file['tier'], $file['size']);
                $archiveCost = $this->getTierCost('archive', $file['size']);
                $savings = $currentCost - $archiveCost;
                
                $opportunities[] = [
                    'file_id' => $file['id'],
                    'current_tier' => $file['tier'],
                    'recommended_tier' => 'archive',
                    'savings' => $savings
                ];
                
                $totalSavings += $savings;
            }
        }
        
        return [
            'opportunities' => $opportunities,
            'total_savings' => $totalSavings
        ];
    }

    /**
     * Get user files
     */
    private function getUserFiles(int $userId): array
    {
        // Mock implementation - would query database
        return [
            [
                'id' => 1,
                'name' => 'document1.pdf',
                'size' => 1024 * 1024 * 1024, // 1GB
                'type' => 'document',
                'hash' => 'abc123'
            ],
            [
                'id' => 2,
                'name' => 'document2.pdf',
                'size' => 1024 * 1024 * 1024, // 1GB
                'type' => 'document',
                'hash' => 'abc123' // Same hash = potential duplicate
            ]
        ];
    }

    /**
     * Find potential duplicates
     */
    private function findPotentialDuplicates(array $files, string $fileType, int $fileSize): array
    {
        $duplicates = [];
        
        foreach ($files as $file) {
            // Check for exact size matches (potential duplicates)
            if ($file['size'] === $fileSize && $file['type'] === $fileType) {
                $duplicates[] = $file;
            }
        }
        
        return $duplicates;
    }

    /**
     * Initialize optimization models
     */
    private function initializeOptimizationModels(): void
    {
        $this->optimizationModels = [
            'cost_prediction' => [
                'type' => 'linear_regression',
                'features' => ['file_size', 'access_frequency', 'retention_period'],
                'accuracy' => 0.85
            ],
            'tier_optimization' => [
                'type' => 'classification',
                'features' => ['access_pattern', 'file_type', 'size_category'],
                'accuracy' => 0.92
            ]
        ];
    }

    /**
     * Load cost prediction model
     */
    public function loadModel(string $modelFile): object
    {
        $modelPath = "models/$modelFile";
        
        if (file_exists($modelPath)) {
            $modelData = json_decode(file_get_contents($modelPath), true);
            return (object) $modelData;
        }
        
        return (object) [
            'type' => 'default',
            'version' => '1.0',
            'accuracy' => 0.0
        ];
    }

    /**
     * Get cost forecast
     */
    public function getCostForecast(int $userId, int $months = 12): array
    {
        $currentUsage = $this->getUserUsageData($userId);
        $monthlyGrowth = 0.05; // 5% monthly growth
        
        $forecast = [];
        $currentCost = $currentUsage['total_cost'];
        
        for ($i = 1; $i <= $months; $i++) {
            $currentCost *= (1 + $monthlyGrowth);
            $forecast[] = [
                'month' => $i,
                'projected_cost' => $currentCost,
                'growth_rate' => $monthlyGrowth
            ];
        }
        
        return $forecast;
    }

    /**
     * Get cost breakdown by tier
     */
    public function getCostBreakdownByTier(int $userId): array
    {
        $usageData = $this->getUserUsageData($userId);
        $breakdown = [];
        
        foreach ($usageData['files'] as $file) {
            $tier = $file['tier'];
            $cost = $this->getTierCost($tier, $file['size']);
            
            if (!isset($breakdown[$tier])) {
                $breakdown[$tier] = [
                    'total_cost' => 0,
                    'total_size' => 0,
                    'file_count' => 0
                ];
            }
            
            $breakdown[$tier]['total_cost'] += $cost;
            $breakdown[$tier]['total_size'] += $file['size'];
            $breakdown[$tier]['file_count']++;
        }
        
        return $breakdown;
    }
} 