<?php

namespace GrimReaper\ML;

/**
 * ML-powered Cost Predictor for storage cost forecasting
 */
class CostPredictor
{
    private array $models;
    private array $trainingData;
    private array $predictionFeatures;

    public function __construct()
    {
        $this->models = [];
        $this->trainingData = [];
        $this->initializePredictionFeatures();
    }

    /**
     * Predict storage cost for request
     */
    public function predictCost(array $features): float
    {
        // Extract features
        $fileSize = $features['file_size'] ?? 0;
        $retentionPeriod = $features['retention_period'] ?? 365;
        $accessPattern = $features['access_pattern'] ?? 'warm';
        $fileType = $features['file_type'] ?? 'unknown';
        $geographicLocation = $features['geographic_location'] ?? 'us-east-1';
        
        // Calculate base cost
        $baseCost = $this->calculateBaseCost($fileSize, $retentionPeriod, $accessPattern);
        
        // Apply geographic multiplier
        $geographicMultiplier = $this->getGeographicMultiplier($geographicLocation);
        $baseCost *= $geographicMultiplier;
        
        // Apply file type multiplier
        $typeMultiplier = $this->getFileTypeMultiplier($fileType);
        $baseCost *= $typeMultiplier;
        
        // Apply ML-based adjustments
        $mlAdjustment = $this->getMLAdjustment($features);
        $baseCost *= (1 + $mlAdjustment);
        
        return $baseCost;
    }

    /**
     * Load cost prediction model
     */
    public function loadModel(string $modelFile): object
    {
        $modelPath = "models/$modelFile";
        
        if (file_exists($modelPath)) {
            $modelData = json_decode(file_get_contents($modelPath), true);
            $this->models[$modelFile] = $modelData;
            return (object) $modelData;
        }
        
        return $this->createDefaultModel();
    }

    /**
     * Calculate base cost
     */
    private function calculateBaseCost(int $fileSize, int $retentionPeriod, string $accessPattern): float
    {
        $sizeInGB = $fileSize / (1024 * 1024 * 1024);
        $months = $retentionPeriod / 30;
        
        $tierCosts = [
            'hot' => 0.023,
            'warm' => 0.0125,
            'cold' => 0.004,
            'archive' => 0.0004
        ];
        
        $costPerGB = $tierCosts[$accessPattern] ?? 0.0125;
        return $costPerGB * $sizeInGB * $months;
    }

    /**
     * Get geographic multiplier
     */
    private function getGeographicMultiplier(string $location): float
    {
        $multipliers = [
            'us-east-1' => 1.0,
            'us-west-2' => 1.1,
            'eu-west-1' => 1.2,
            'ap-southeast-1' => 1.3
        ];
        
        return $multipliers[$location] ?? 1.0;
    }

    /**
     * Get file type multiplier
     */
    private function getFileTypeMultiplier(string $fileType): float
    {
        $multipliers = [
            'database' => 1.2,
            'log' => 0.8,
            'backup' => 0.6,
            'archive' => 0.4,
            'media' => 1.1,
            'document' => 1.0
        ];
        
        return $multipliers[$fileType] ?? 1.0;
    }

    /**
     * Get ML-based adjustment
     */
    private function getMLAdjustment(array $features): float
    {
        // Simple ML adjustment based on feature weights
        $adjustment = 0.0;
        
        foreach ($this->predictionFeatures as $feature => $weight) {
            if (isset($features[$feature])) {
                $adjustment += $weight * $this->normalizeFeature($feature, $features[$feature]);
            }
        }
        
        return $adjustment;
    }

    /**
     * Normalize feature value
     */
    private function normalizeFeature(string $feature, $value): float
    {
        switch ($feature) {
            case 'file_size':
                return min(1.0, $value / (1024 * 1024 * 1024 * 100)); // Normalize to 100GB
            case 'retention_period':
                return min(1.0, $value / 3650); // Normalize to 10 years
            case 'access_frequency':
                return min(1.0, $value / 100); // Normalize to 100 accesses
            default:
                return 0.5; // Default normalization
        }
    }

    /**
     * Initialize prediction features
     */
    private function initializePredictionFeatures(): void
    {
        $this->predictionFeatures = [
            'file_size' => 0.3,
            'retention_period' => 0.25,
            'access_pattern' => 0.2,
            'file_type' => 0.15,
            'geographic_location' => 0.1
        ];
    }

    /**
     * Create default model
     */
    private function createDefaultModel(): object
    {
        return (object) [
            'type' => 'linear_regression',
            'features' => $this->predictionFeatures,
            'accuracy' => 0.85,
            'version' => '1.0'
        ];
    }
} 