<?php

namespace GrimReaper\Storage;

/**
 * Optimization Result representing storage optimization outcomes
 */
class OptimizationResult
{
    private int $userId;
    private ?int $projectId;
    private array $currentUsage;
    private array $dataClassification;
    private array $recommendations;
    private float $potentialSavings;
    private array $migrationPlan;
    private array $migrationResults;
    private float $executionTime;

    public function __construct(
        int $userId,
        ?int $projectId,
        array $currentUsage,
        array $dataClassification,
        array $recommendations,
        float $potentialSavings,
        array $migrationPlan,
        array $migrationResults,
        float $executionTime
    ) {
        $this->userId = $userId;
        $this->projectId = $projectId;
        $this->currentUsage = $currentUsage;
        $this->dataClassification = $dataClassification;
        $this->recommendations = $recommendations;
        $this->potentialSavings = $potentialSavings;
        $this->migrationPlan = $migrationPlan;
        $this->migrationResults = $migrationResults;
        $this->executionTime = $executionTime;
    }

    // Getters
    public function getUserId(): int
    {
        return $this->userId;
    }

    public function getProjectId(): ?int
    {
        return $this->projectId;
    }

    public function getCurrentUsage(): array
    {
        return $this->currentUsage;
    }

    public function getDataClassification(): array
    {
        return $this->dataClassification;
    }

    public function getRecommendations(): array
    {
        return $this->recommendations;
    }

    public function getPotentialSavings(): float
    {
        return $this->potentialSavings;
    }

    public function getMigrationPlan(): array
    {
        return $this->migrationPlan;
    }

    public function getMigrationResults(): array
    {
        return $this->migrationResults;
    }

    public function getExecutionTime(): float
    {
        return $this->executionTime;
    }

    /**
     * Get optimization summary
     */
    public function getOptimizationSummary(): array
    {
        $successfulMigrations = 0;
        $failedMigrations = 0;
        
        foreach ($this->migrationResults as $result) {
            if ($result['status'] === 'completed') {
                $successfulMigrations++;
            } else {
                $failedMigrations++;
            }
        }
        
        return [
            'user_id' => $this->userId,
            'project_id' => $this->projectId,
            'potential_savings' => $this->potentialSavings,
            'recommendations_count' => count($this->recommendations),
            'migrations_total' => count($this->migrationResults),
            'migrations_successful' => $successfulMigrations,
            'migrations_failed' => $failedMigrations,
            'execution_time' => $this->executionTime,
            'optimization_score' => $this->calculateOptimizationScore()
        ];
    }

    /**
     * Calculate optimization score
     */
    private function calculateOptimizationScore(): float
    {
        $score = 0.0;
        
        // Base score from potential savings
        if ($this->potentialSavings > 0) {
            $score += min(0.5, $this->potentialSavings / 100); // Max 50% from savings
        }
        
        // Score from successful migrations
        $totalMigrations = count($this->migrationResults);
        if ($totalMigrations > 0) {
            $successfulMigrations = 0;
            foreach ($this->migrationResults as $result) {
                if ($result['status'] === 'completed') {
                    $successfulMigrations++;
                }
            }
            $score += 0.3 * ($successfulMigrations / $totalMigrations); // Max 30% from migrations
        }
        
        // Score from recommendations
        $highPriorityRecommendations = 0;
        foreach ($this->recommendations as $recommendation) {
            if ($recommendation['priority'] === 'high') {
                $highPriorityRecommendations++;
            }
        }
        $score += 0.2 * min(1, $highPriorityRecommendations / 5); // Max 20% from recommendations
        
        return min(1.0, $score);
    }

    /**
     * Get data tier distribution
     */
    public function getTierDistribution(): array
    {
        $distribution = [];
        
        foreach ($this->dataClassification as $tier => $files) {
            $totalSize = 0;
            foreach ($files as $file) {
                $totalSize += $file['size'] ?? 0;
            }
            
            $distribution[$tier] = [
                'file_count' => count($files),
                'total_size' => $totalSize,
                'percentage' => 0 // Will be calculated below
            ];
        }
        
        // Calculate percentages
        $totalSize = array_sum(array_column($distribution, 'total_size'));
        if ($totalSize > 0) {
            foreach ($distribution as $tier => &$data) {
                $data['percentage'] = ($data['total_size'] / $totalSize) * 100;
            }
        }
        
        return $distribution;
    }

    /**
     * Get high-priority recommendations
     */
    public function getHighPriorityRecommendations(): array
    {
        return array_filter($this->recommendations, function($recommendation) {
            return $recommendation['priority'] === 'high';
        });
    }

    /**
     * Get failed migrations
     */
    public function getFailedMigrations(): array
    {
        return array_filter($this->migrationResults, function($result) {
            return $result['status'] === 'failed';
        });
    }
} 