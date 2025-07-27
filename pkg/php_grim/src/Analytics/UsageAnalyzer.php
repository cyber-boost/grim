<?php

namespace GrimReaper\Analytics;

/**
 * Usage Analyzer for storage usage pattern analysis
 */
class UsageAnalyzer
{
    private array $usageData;
    private array $analysisCache;

    public function __construct()
    {
        $this->usageData = [];
        $this->analysisCache = [];
    }

    /**
     * Get user usage data
     */
    public function getUserUsage(int $userId, ?int $projectId = null): array
    {
        $cacheKey = "user_{$userId}_project_{$projectId}";
        
        if (isset($this->analysisCache[$cacheKey])) {
            return $this->analysisCache[$cacheKey];
        }
        
        // Mock implementation - would query database
        $usageData = [
            'user_id' => $userId,
            'project_id' => $projectId,
            'total_size' => 1024 * 1024 * 1024 * 100, // 100GB
            'total_cost' => 2.30, // $2.30
            'files' => [
                [
                    'id' => 1,
                    'name' => 'database_backup.sql',
                    'size' => 1024 * 1024 * 1024 * 10, // 10GB
                    'type' => 'database',
                    'tier' => 'hot',
                    'access_count' => 50,
                    'last_access_time' => time() - 3600,
                    'created_time' => time() - 86400,
                    'hash' => 'abc123'
                ],
                [
                    'id' => 2,
                    'name' => 'application_logs.log',
                    'size' => 1024 * 1024 * 1024 * 20, // 20GB
                    'type' => 'log',
                    'tier' => 'warm',
                    'access_count' => 10,
                    'last_access_time' => time() - 86400,
                    'created_time' => time() - 172800,
                    'hash' => 'def456'
                ],
                [
                    'id' => 3,
                    'name' => 'old_backup.tar.gz',
                    'size' => 1024 * 1024 * 1024 * 70, // 70GB
                    'type' => 'backup',
                    'tier' => 'cold',
                    'access_count' => 2,
                    'last_access_time' => time() - 604800,
                    'created_time' => time() - 2592000,
                    'hash' => 'ghi789'
                ]
            ],
            'access_patterns' => [
                'hot' => 0.1,
                'warm' => 0.2,
                'cold' => 0.7
            ],
            'storage_tiers' => [
                'hot' => 1024 * 1024 * 1024 * 10,
                'warm' => 1024 * 1024 * 1024 * 20,
                'cold' => 1024 * 1024 * 1024 * 70
            ]
        ];
        
        $this->analysisCache[$cacheKey] = $usageData;
        return $usageData;
    }

    /**
     * Analyze access patterns
     */
    public function analyzeAccessPatterns(array $usageData): array
    {
        $patterns = [
            'frequent' => ['count' => 0, 'size' => 0],
            'moderate' => ['count' => 0, 'size' => 0],
            'rare' => ['count' => 0, 'size' => 0],
            'never' => ['count' => 0, 'size' => 0]
        ];
        
        foreach ($usageData['files'] as $file) {
            $accessCount = $file['access_count'];
            $fileSize = $file['size'];
            
            if ($accessCount >= 20) {
                $patterns['frequent']['count']++;
                $patterns['frequent']['size'] += $fileSize;
            } elseif ($accessCount >= 5) {
                $patterns['moderate']['count']++;
                $patterns['moderate']['size'] += $fileSize;
            } elseif ($accessCount >= 1) {
                $patterns['rare']['count']++;
                $patterns['rare']['size'] += $fileSize;
            } else {
                $patterns['never']['count']++;
                $patterns['never']['size'] += $fileSize;
            }
        }
        
        return $patterns;
    }

    /**
     * Get storage tier breakdown
     */
    public function getStorageTierBreakdown(array $usageData): array
    {
        $breakdown = [];
        
        foreach ($usageData['storage_tiers'] as $tier => $size) {
            $breakdown[$tier] = [
                'size' => $size,
                'percentage' => ($size / $usageData['total_size']) * 100,
                'cost' => $this->calculateTierCost($tier, $size)
            ];
        }
        
        return $breakdown;
    }

    /**
     * Calculate tier cost
     */
    private function calculateTierCost(string $tier, int $size): float
    {
        $sizeInGB = $size / (1024 * 1024 * 1024);
        
        $tierCosts = [
            'hot' => 0.023,
            'warm' => 0.0125,
            'cold' => 0.004,
            'archive' => 0.0004
        ];
        
        $costPerGB = $tierCosts[$tier] ?? 0.0125;
        return $costPerGB * $sizeInGB;
    }
} 