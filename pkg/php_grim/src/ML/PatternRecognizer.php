<?php

namespace GrimReaper\ML;

/**
 * ML-powered Pattern Recognizer for storage optimization
 */
class PatternRecognizer
{
    private array $models;
    private array $trainingData;
    private array $featureWeights;

    public function __construct()
    {
        $this->models = [];
        $this->trainingData = [];
        $this->initializeFeatureWeights();
    }

    /**
     * Predict optimal storage tier based on file characteristics
     */
    public function predictOptimalTier(array $features): float
    {
        // Extract features
        $fileType = $features['file_type'] ?? 'unknown';
        $fileSize = $features['file_size'] ?? 0;
        $accessFrequency = $features['access_frequency'] ?? 1;
        $timeOfDay = $features['time_of_day'] ?? 12;
        $userId = $features['user_id'] ?? 0;
        $projectId = $features['project_id'] ?? 0;

        // Calculate feature scores
        $typeScore = $this->calculateTypeScore($fileType);
        $sizeScore = $this->calculateSizeScore($fileSize);
        $frequencyScore = $this->calculateFrequencyScore($accessFrequency);
        $timeScore = $this->calculateTimeScore($timeOfDay);
        $userScore = $this->calculateUserScore($userId);
        $projectScore = $this->calculateProjectScore($projectId);

        // Weighted combination
        $prediction = ($typeScore * $this->featureWeights['type']) +
                     ($sizeScore * $this->featureWeights['size']) +
                     ($frequencyScore * $this->featureWeights['frequency']) +
                     ($timeScore * $this->featureWeights['time']) +
                     ($userScore * $this->featureWeights['user']) +
                     ($projectScore * $this->featureWeights['project']);

        // Normalize to 0-1 range
        return max(0, min(1, $prediction));
    }

    /**
     * Train model with historical data
     */
    public function trainModel(array $trainingData): void
    {
        $this->trainingData = array_merge($this->trainingData, $trainingData);
        
        // Update feature weights based on training data
        $this->updateFeatureWeights();
        
        // Save model
        $this->saveModel();
    }

    /**
     * Load ML model from file
     */
    public function loadModel(string $modelFile): object
    {
        $modelPath = "models/$modelFile";
        
        if (file_exists($modelPath)) {
            $modelData = json_decode(file_get_contents($modelPath), true);
            $this->models[$modelFile] = $modelData;
            return (object) $modelData;
        }
        
        // Return default model if file doesn't exist
        return $this->createDefaultModel();
    }

    /**
     * Calculate file type score
     */
    private function calculateTypeScore(string $fileType): float
    {
        $typeScores = [
            'database' => 0.9,    // High priority
            'log' => 0.3,         // Low priority
            'backup' => 0.2,      // Very low priority
            'archive' => 0.1,     // Archive tier
            'media' => 0.7,       // Medium priority
            'document' => 0.5,    // Medium priority
            'image' => 0.6,       // Medium-high priority
            'video' => 0.8,       // High priority
            'audio' => 0.4,       // Medium priority
            'compressed' => 0.2,  // Low priority
            'unknown' => 0.5      // Default
        ];
        
        return $typeScores[$fileType] ?? 0.5;
    }

    /**
     * Calculate file size score
     */
    private function calculateSizeScore(int $fileSize): float
    {
        $sizeInMB = $fileSize / (1024 * 1024);
        
        if ($sizeInMB < 1) {
            return 0.9; // Small files get high priority
        } elseif ($sizeInMB < 10) {
            return 0.8;
        } elseif ($sizeInMB < 100) {
            return 0.7;
        } elseif ($sizeInMB < 1000) {
            return 0.6;
        } elseif ($sizeInMB < 10000) {
            return 0.4;
        } else {
            return 0.2; // Large files get low priority
        }
    }

    /**
     * Calculate access frequency score
     */
    private function calculateFrequencyScore(int $accessFrequency): float
    {
        if ($accessFrequency >= 100) {
            return 1.0; // Very high frequency
        } elseif ($accessFrequency >= 50) {
            return 0.9;
        } elseif ($accessFrequency >= 20) {
            return 0.8;
        } elseif ($accessFrequency >= 10) {
            return 0.7;
        } elseif ($accessFrequency >= 5) {
            return 0.6;
        } elseif ($accessFrequency >= 2) {
            return 0.5;
        } else {
            return 0.3; // Low frequency
        }
    }

    /**
     * Calculate time of day score
     */
    private function calculateTimeScore(int $timeOfDay): float
    {
        // Business hours (9 AM - 5 PM) get higher priority
        if ($timeOfDay >= 9 && $timeOfDay <= 17) {
            return 0.8;
        } elseif ($timeOfDay >= 6 && $timeOfDay <= 22) {
            return 0.6;
        } else {
            return 0.4; // Off-hours
        }
    }

    /**
     * Calculate user-specific score
     */
    private function calculateUserScore(int $userId): float
    {
        // This would typically query user behavior data
        // For now, use a simple hash-based approach
        $userHash = crc32((string)$userId);
        return ($userHash % 100) / 100.0;
    }

    /**
     * Calculate project-specific score
     */
    private function calculateProjectScore(int $projectId): float
    {
        // This would typically query project characteristics
        // For now, use a simple hash-based approach
        $projectHash = crc32((string)$projectId);
        return ($projectHash % 100) / 100.0;
    }

    /**
     * Initialize feature weights
     */
    private function initializeFeatureWeights(): void
    {
        $this->featureWeights = [
            'type' => 0.25,
            'size' => 0.20,
            'frequency' => 0.30,
            'time' => 0.10,
            'user' => 0.10,
            'project' => 0.05
        ];
    }

    /**
     * Update feature weights based on training data
     */
    private function updateFeatureWeights(): void
    {
        if (empty($this->trainingData)) {
            return;
        }

        // Simple weight adjustment based on correlation
        $correlations = $this->calculateFeatureCorrelations();
        
        // Adjust weights based on correlations
        foreach ($correlations as $feature => $correlation) {
            if (isset($this->featureWeights[$feature])) {
                $this->featureWeights[$feature] *= (1 + $correlation * 0.1);
            }
        }
        
        // Normalize weights
        $totalWeight = array_sum($this->featureWeights);
        foreach ($this->featureWeights as $feature => $weight) {
            $this->featureWeights[$feature] = $weight / $totalWeight;
        }
    }

    /**
     * Calculate feature correlations with optimal tier
     */
    private function calculateFeatureCorrelations(): array
    {
        $correlations = [];
        
        // This is a simplified correlation calculation
        // In a real implementation, you'd use statistical methods
        
        $features = ['type', 'size', 'frequency', 'time', 'user', 'project'];
        
        foreach ($features as $feature) {
            // Mock correlation calculation
            $correlations[$feature] = (rand(-100, 100) / 100.0);
        }
        
        return $correlations;
    }

    /**
     * Save model to file
     */
    private function saveModel(): void
    {
        $modelData = [
            'feature_weights' => $this->featureWeights,
            'training_data_count' => count($this->trainingData),
            'last_updated' => time()
        ];
        
        // Ensure models directory exists
        if (!is_dir('models')) {
            mkdir('models', 0755, true);
        }
        
        file_put_contents('models/pattern_recognition_model.json', json_encode($modelData, JSON_PRETTY_PRINT));
    }

    /**
     * Create default model
     */
    private function createDefaultModel(): object
    {
        return (object) [
            'feature_weights' => $this->featureWeights,
            'training_data_count' => 0,
            'last_updated' => time(),
            'version' => '1.0'
        ];
    }

    /**
     * Get model accuracy
     */
    public function getModelAccuracy(): float
    {
        if (empty($this->trainingData)) {
            return 0.0;
        }
        
        // Calculate accuracy based on training data
        $correctPredictions = 0;
        $totalPredictions = 0;
        
        foreach ($this->trainingData as $dataPoint) {
            $predictedTier = $this->predictOptimalTier($dataPoint['features']);
            $actualTier = $dataPoint['actual_tier'];
            
            // Convert tiers to scores for comparison
            $tierScores = [
                'hot' => 0.8,
                'warm' => 0.5,
                'cold' => 0.2,
                'archive' => 0.1
            ];
            
            $predictedScore = $tierScores[$this->scoreToTier($predictedTier)] ?? 0.5;
            $actualScore = $tierScores[$actualTier] ?? 0.5;
            
            // Consider prediction correct if within 0.2 score difference
            if (abs($predictedScore - $actualScore) <= 0.2) {
                $correctPredictions++;
            }
            
            $totalPredictions++;
        }
        
        return $totalPredictions > 0 ? $correctPredictions / $totalPredictions : 0.0;
    }

    /**
     * Convert score to tier
     */
    private function scoreToTier(float $score): string
    {
        if ($score >= 0.7) {
            return 'hot';
        } elseif ($score >= 0.4) {
            return 'warm';
        } elseif ($score >= 0.2) {
            return 'cold';
        } else {
            return 'archive';
        }
    }

    /**
     * Get feature importance
     */
    public function getFeatureImportance(): array
    {
        return $this->featureWeights;
    }

    /**
     * Add training data point
     */
    public function addTrainingData(array $features, string $actualTier, float $performanceMetric): void
    {
        $this->trainingData[] = [
            'features' => $features,
            'actual_tier' => $actualTier,
            'performance_metric' => $performanceMetric,
            'timestamp' => time()
        ];
        
        // Retrain model periodically
        if (count($this->trainingData) % 100 === 0) {
            $this->trainModel([]);
        }
    }
} 