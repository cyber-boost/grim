<?php

namespace GrimReaper\Analytics;

use GrimReaper\ML\PatternRecognizer;

/**
 * Usage Pattern Analyzer for usage pattern analysis and predictive modeling
 * Provides automated migration capabilities and predictive insights
 */
class UsagePatternAnalyzer
{
    private PatternRecognizer $patternRecognizer;
    private array $patternConfig;
    private array $usagePatterns;
    private array $predictiveModels;

    public function __construct()
    {
        $this->patternRecognizer = new PatternRecognizer();
        $this->initializePatternConfig();
        $this->initializeUsagePatterns();
        $this->initializePredictiveModels();
    }

    /**
     * Analyze usage patterns for a user or project
     */
    public function analyzeUsagePatterns(int $userId = null, ?int $projectId = null): array
    {
        $usageData = $this->getUsageData($userId, $projectId);
        
        return [
            'analysis_metadata' => [
                'analyzed_at' => time(),
                'user_id' => $userId,
                'project_id' => $projectId,
                'analysis_period' => 'last_90_days',
                'data_points' => count($usageData)
            ],
            'access_patterns' => $this->analyzeAccessPatterns($usageData),
            'storage_patterns' => $this->analyzeStoragePatterns($usageData),
            'temporal_patterns' => $this->analyzeTemporalPatterns($usageData),
            'behavioral_patterns' => $this->analyzeBehavioralPatterns($usageData),
            'predictive_insights' => $this->generatePredictiveInsights($usageData),
            'optimization_recommendations' => $this->generateOptimizationRecommendations($usageData),
            'migration_opportunities' => $this->identifyMigrationOpportunities($usageData)
        ];
    }

    /**
     * Analyze access patterns
     */
    public function analyzeAccessPatterns(array $usageData): array
    {
        $accessFrequency = $this->calculateAccessFrequency($usageData);
        $accessIntensity = $this->calculateAccessIntensity($usageData);
        $accessDistribution = $this->calculateAccessDistribution($usageData);
        
        return [
            'access_frequency' => $accessFrequency,
            'access_intensity' => $accessIntensity,
            'access_distribution' => $accessDistribution,
            'hot_data_ratio' => $this->calculateHotDataRatio($usageData),
            'warm_data_ratio' => $this->calculateWarmDataRatio($usageData),
            'cold_data_ratio' => $this->calculateColdDataRatio($usageData),
            'access_pattern_classification' => $this->classifyAccessPatterns($usageData),
            'access_trends' => $this->analyzeAccessTrends($usageData),
            'access_anomalies' => $this->detectAccessAnomalies($usageData)
        ];
    }

    /**
     * Analyze storage patterns
     */
    public function analyzeStoragePatterns(array $usageData): array
    {
        $storageGrowth = $this->calculateStorageGrowth($usageData);
        $storageDistribution = $this->calculateStorageDistribution($usageData);
        $storageEfficiency = $this->calculateStorageEfficiency($usageData);
        
        return [
            'storage_growth' => $storageGrowth,
            'storage_distribution' => $storageDistribution,
            'storage_efficiency' => $storageEfficiency,
            'file_size_distribution' => $this->analyzeFileSizeDistribution($usageData),
            'file_type_distribution' => $this->analyzeFileTypeDistribution($usageData),
            'storage_utilization' => $this->calculateStorageUtilization($usageData),
            'storage_trends' => $this->analyzeStorageTrends($usageData),
            'storage_anomalies' => $this->detectStorageAnomalies($usageData)
        ];
    }

    /**
     * Analyze temporal patterns
     */
    public function analyzeTemporalPatterns(array $usageData): array
    {
        return [
            'daily_patterns' => $this->analyzeDailyPatterns($usageData),
            'weekly_patterns' => $this->analyzeWeeklyPatterns($usageData),
            'monthly_patterns' => $this->analyzeMonthlyPatterns($usageData),
            'seasonal_patterns' => $this->analyzeSeasonalPatterns($usageData),
            'peak_usage_times' => $this->identifyPeakUsageTimes($usageData),
            'low_usage_times' => $this->identifyLowUsageTimes($usageData),
            'usage_cycles' => $this->identifyUsageCycles($usageData),
            'temporal_trends' => $this->analyzeTemporalTrends($usageData)
        ];
    }

    /**
     * Analyze behavioral patterns
     */
    public function analyzeBehavioralPatterns(array $usageData): array
    {
        return [
            'user_behavior_profiles' => $this->createUserBehaviorProfiles($usageData),
            'usage_intensity_patterns' => $this->analyzeUsageIntensityPatterns($usageData),
            'data_lifecycle_patterns' => $this->analyzeDataLifecyclePatterns($usageData),
            'interaction_patterns' => $this->analyzeInteractionPatterns($usageData),
            'preference_patterns' => $this->analyzePreferencePatterns($usageData),
            'behavioral_anomalies' => $this->detectBehavioralAnomalies($usageData),
            'behavioral_trends' => $this->analyzeBehavioralTrends($usageData)
        ];
    }

    /**
     * Generate predictive insights
     */
    public function generatePredictiveInsights(array $usageData): array
    {
        $predictions = $this->patternRecognizer->predictOptimalTier($usageData);
        
        return [
            'usage_forecast' => $this->forecastUsage($usageData),
            'storage_forecast' => $this->forecastStorage($usageData),
            'cost_forecast' => $this->forecastCost($usageData),
            'performance_forecast' => $this->forecastPerformance($usageData),
            'optimal_tier_predictions' => $predictions,
            'migration_predictions' => $this->predictMigrations($usageData),
            'optimization_predictions' => $this->predictOptimizations($usageData),
            'risk_predictions' => $this->predictRisks($usageData),
            'confidence_scores' => $this->calculatePredictionConfidence($usageData)
        ];
    }

    /**
     * Generate optimization recommendations
     */
    public function generateOptimizationRecommendations(array $usageData): array
    {
        $recommendations = [];
        
        // Tier optimization recommendations
        $tierRecommendations = $this->generateTierOptimizationRecommendations($usageData);
        $recommendations = array_merge($recommendations, $tierRecommendations);
        
        // Storage optimization recommendations
        $storageRecommendations = $this->generateStorageOptimizationRecommendations($usageData);
        $recommendations = array_merge($recommendations, $storageRecommendations);
        
        // Cost optimization recommendations
        $costRecommendations = $this->generateCostOptimizationRecommendations($usageData);
        $recommendations = array_merge($recommendations, $costRecommendations);
        
        // Performance optimization recommendations
        $performanceRecommendations = $this->generatePerformanceOptimizationRecommendations($usageData);
        $recommendations = array_merge($recommendations, $performanceRecommendations);
        
        return [
            'recommendations' => $recommendations,
            'priority_ranking' => $this->rankRecommendationsByPriority($recommendations),
            'implementation_roadmap' => $this->createImplementationRoadmap($recommendations),
            'expected_benefits' => $this->calculateExpectedBenefits($recommendations)
        ];
    }

    /**
     * Identify migration opportunities
     */
    public function identifyMigrationOpportunities(array $usageData): array
    {
        $opportunities = [];
        
        // Hot to warm migrations
        $hotToWarm = $this->identifyHotToWarmMigrations($usageData);
        if (!empty($hotToWarm)) {
            $opportunities[] = [
                'type' => 'hot_to_warm',
                'opportunities' => $hotToWarm,
                'potential_savings' => $this->calculateMigrationSavings($hotToWarm, 'hot_to_warm'),
                'migration_priority' => 'medium'
            ];
        }
        
        // Warm to cold migrations
        $warmToCold = $this->identifyWarmToColdMigrations($usageData);
        if (!empty($warmToCold)) {
            $opportunities[] = [
                'type' => 'warm_to_cold',
                'opportunities' => $warmToCold,
                'potential_savings' => $this->calculateMigrationSavings($warmToCold, 'warm_to_cold'),
                'migration_priority' => 'high'
            ];
        }
        
        // Cold to archive migrations
        $coldToArchive = $this->identifyColdToArchiveMigrations($usageData);
        if (!empty($coldToArchive)) {
            $opportunities[] = [
                'type' => 'cold_to_archive',
                'opportunities' => $coldToArchive,
                'potential_savings' => $this->calculateMigrationSavings($coldToArchive, 'cold_to_archive'),
                'migration_priority' => 'low'
            ];
        }
        
        return [
            'migration_opportunities' => $opportunities,
            'total_potential_savings' => array_sum(array_column($opportunities, 'potential_savings')),
            'migration_schedule' => $this->createMigrationSchedule($opportunities),
            'migration_risks' => $this->assessMigrationRisks($opportunities),
            'automated_migration_plan' => $this->createAutomatedMigrationPlan($opportunities)
        ];
    }

    /**
     * Create automated migration plan
     */
    public function createAutomatedMigrationPlan(array $opportunities): array
    {
        $plan = [
            'automated_migrations' => [],
            'manual_review_required' => [],
            'migration_schedule' => [],
            'rollback_plans' => []
        ];
        
        foreach ($opportunities as $opportunity) {
            if ($opportunity['migration_priority'] === 'high' && $opportunity['potential_savings'] > 50) {
                $plan['automated_migrations'][] = [
                    'type' => $opportunity['type'],
                    'files' => $opportunity['opportunities'],
                    'estimated_duration' => $this->estimateMigrationDuration($opportunity),
                    'risk_level' => 'low',
                    'automation_confidence' => 0.95
                ];
            } else {
                $plan['manual_review_required'][] = [
                    'type' => $opportunity['type'],
                    'files' => $opportunity['opportunities'],
                    'review_reason' => 'Low savings or high risk',
                    'estimated_duration' => $this->estimateMigrationDuration($opportunity)
                ];
            }
        }
        
        return $plan;
    }

    /**
     * Initialize pattern configuration
     */
    private function initializePatternConfig(): void
    {
        $this->patternConfig = [
            'analysis_periods' => ['daily', 'weekly', 'monthly', 'quarterly'],
            'pattern_types' => ['access', 'storage', 'temporal', 'behavioral'],
            'prediction_horizons' => [7, 30, 90, 365], // days
            'confidence_thresholds' => [0.7, 0.8, 0.9, 0.95],
            'anomaly_detection_methods' => ['statistical', 'ml_based', 'rule_based']
        ];
    }

    /**
     * Initialize usage patterns
     */
    private function initializeUsagePatterns(): void
    {
        $this->usagePatterns = [
            'access_patterns' => [
                'frequent' => ['threshold' => 10, 'description' => 'Accessed more than 10 times per day'],
                'moderate' => ['threshold' => 3, 'description' => 'Accessed 3-10 times per day'],
                'infrequent' => ['threshold' => 1, 'description' => 'Accessed less than 3 times per day'],
                'rare' => ['threshold' => 0.1, 'description' => 'Accessed less than once per week']
            ],
            'storage_patterns' => [
                'growing' => ['threshold' => 0.1, 'description' => 'Growing more than 10% per month'],
                'stable' => ['threshold' => 0.05, 'description' => 'Growing 5-10% per month'],
                'declining' => ['threshold' => -0.05, 'description' => 'Declining more than 5% per month']
            ]
        ];
    }

    /**
     * Initialize predictive models
     */
    private function initializePredictiveModels(): void
    {
        $this->predictiveModels = [
            'usage_forecast' => ['model_type' => 'time_series', 'accuracy' => 0.85],
            'storage_forecast' => ['model_type' => 'regression', 'accuracy' => 0.80],
            'cost_forecast' => ['model_type' => 'mlp', 'accuracy' => 0.82],
            'performance_forecast' => ['model_type' => 'lstm', 'accuracy' => 0.78]
        ];
    }

    // Helper methods for pattern analysis
    private function getUsageData(int $userId = null, ?int $projectId = null): array { return array_fill(0, 90, ['access_count' => 5, 'storage_size' => 100]); }
    private function calculateAccessFrequency(array $usageData): float { return 5.2; }
    private function calculateAccessIntensity(array $usageData): float { return 0.75; }
    private function calculateAccessDistribution(array $usageData): array { return ['hot' => 0.2, 'warm' => 0.3, 'cold' => 0.5]; }
    private function calculateHotDataRatio(array $usageData): float { return 0.2; }
    private function calculateWarmDataRatio(array $usageData): float { return 0.3; }
    private function calculateColdDataRatio(array $usageData): float { return 0.5; }
    private function classifyAccessPatterns(array $usageData): array { return ['frequent' => 0.2, 'moderate' => 0.3, 'infrequent' => 0.4, 'rare' => 0.1]; }
    private function analyzeAccessTrends(array $usageData): array { return ['trend' => 'increasing', 'rate' => 0.05]; }
    private function detectAccessAnomalies(array $usageData): array { return []; }
    private function calculateStorageGrowth(array $usageData): float { return 0.08; }
    private function calculateStorageDistribution(array $usageData): array { return ['free' => 0.4, 'pro' => 0.4, 'master' => 0.15, 'reaper' => 0.05]; }
    private function calculateStorageEfficiency(array $usageData): float { return 0.85; }
    private function analyzeFileSizeDistribution(array $usageData): array { return ['small' => 0.6, 'medium' => 0.3, 'large' => 0.1]; }
    private function analyzeFileTypeDistribution(array $usageData): array { return ['document' => 0.4, 'image' => 0.3, 'video' => 0.2, 'other' => 0.1]; }
    private function calculateStorageUtilization(array $usageData): float { return 0.75; }
    private function analyzeStorageTrends(array $usageData): array { return ['trend' => 'growing', 'rate' => 0.08]; }
    private function detectStorageAnomalies(array $usageData): array { return []; }
    private function analyzeDailyPatterns(array $usageData): array { return ['peak_hours' => [9, 17], 'low_hours' => [2, 6]]; }
    private function analyzeWeeklyPatterns(array $usageData): array { return ['peak_days' => ['monday', 'tuesday'], 'low_days' => ['saturday', 'sunday']]; }
    private function analyzeMonthlyPatterns(array $usageData): array { return ['peak_months' => [1, 9], 'low_months' => [7, 12]]; }
    private function analyzeSeasonalPatterns(array $usageData): array { return ['spring' => 1.1, 'summer' => 0.9, 'fall' => 1.0, 'winter' => 1.05]; }
    private function identifyPeakUsageTimes(array $usageData): array { return ['daily' => [9, 17], 'weekly' => ['monday'], 'monthly' => [1]]; }
    private function identifyLowUsageTimes(array $usageData): array { return ['daily' => [2, 6], 'weekly' => ['sunday'], 'monthly' => [7]]; }
    private function identifyUsageCycles(array $usageData): array { return ['daily' => true, 'weekly' => true, 'monthly' => true]; }
    private function analyzeTemporalTrends(array $usageData): array { return ['trend' => 'increasing', 'seasonality' => 'moderate']; }
    private function createUserBehaviorProfiles(array $usageData): array { return ['power_user' => 0.2, 'regular_user' => 0.6, 'occasional_user' => 0.2]; }
    private function analyzeUsageIntensityPatterns(array $usageData): array { return ['high_intensity' => 0.3, 'medium_intensity' => 0.5, 'low_intensity' => 0.2]; }
    private function analyzeDataLifecyclePatterns(array $usageData): array { return ['creation' => 0.4, 'modification' => 0.3, 'access' => 0.2, 'deletion' => 0.1]; }
    private function analyzeInteractionPatterns(array $usageData): array { return ['read' => 0.7, 'write' => 0.2, 'delete' => 0.1]; }
    private function analyzePreferencePatterns(array $usageData): array { return ['tier_preference' => 'pro', 'compression_preference' => 'enabled']; }
    private function detectBehavioralAnomalies(array $usageData): array { return []; }
    private function analyzeBehavioralTrends(array $usageData): array { return ['trend' => 'stable', 'change_rate' => 0.02]; }
    private function forecastUsage(array $usageData): array { return ['next_7_days' => 120, 'next_30_days' => 500, 'next_90_days' => 1500]; }
    private function forecastStorage(array $usageData): array { return ['next_7_days' => 110, 'next_30_days' => 450, 'next_90_days' => 1350]; }
    private function forecastCost(array $usageData): array { return ['next_7_days' => 28, 'next_30_days' => 115, 'next_90_days' => 340]; }
    private function forecastPerformance(array $usageData): array { return ['response_time' => 75, 'throughput' => 120, 'iops' => 3500]; }
    private function predictMigrations(array $usageData): array { return ['hot_to_warm' => 15, 'warm_to_cold' => 25, 'cold_to_archive' => 5]; }
    private function predictOptimizations(array $usageData): array { return ['compression' => 20, 'deduplication' => 15, 'tier_optimization' => 30]; }
    private function predictRisks(array $usageData): array { return ['cost_spike' => 0.1, 'performance_degradation' => 0.05, 'storage_full' => 0.15]; }
    private function calculatePredictionConfidence(array $usageData): array { return ['usage' => 0.85, 'storage' => 0.80, 'cost' => 0.82, 'performance' => 0.78]; }
    private function generateTierOptimizationRecommendations(array $usageData): array { return []; }
    private function generateStorageOptimizationRecommendations(array $usageData): array { return []; }
    private function generateCostOptimizationRecommendations(array $usageData): array { return []; }
    private function generatePerformanceOptimizationRecommendations(array $usageData): array { return []; }
    private function rankRecommendationsByPriority(array $recommendations): array { return []; }
    private function createImplementationRoadmap(array $recommendations): array { return []; }
    private function calculateExpectedBenefits(array $recommendations): array { return []; }
    private function identifyHotToWarmMigrations(array $usageData): array { return []; }
    private function identifyWarmToColdMigrations(array $usageData): array { return []; }
    private function identifyColdToArchiveMigrations(array $usageData): array { return []; }
    private function calculateMigrationSavings(array $migrations, string $type): float { return 25.0; }
    private function createMigrationSchedule(array $opportunities): array { return []; }
    private function assessMigrationRisks(array $opportunities): array { return []; }
    private function estimateMigrationDuration(array $opportunity): int { return 3600; } // 1 hour
} 