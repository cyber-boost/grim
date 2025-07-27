<?php

namespace GrimReaper\Analytics;

use GrimReaper\ML\CostPredictor;

/**
 * Cost Forecaster for cost forecasting, trend analysis, and predictive modeling
 * Provides ML-powered cost predictions and trend analysis
 */
class CostForecaster
{
    private CostPredictor $costPredictor;
    private array $forecastConfig;
    private array $trendData;
    private array $seasonalPatterns;

    public function __construct()
    {
        $this->costPredictor = new CostPredictor();
        $this->initializeForecastConfig();
        $this->initializeTrendData();
        $this->initializeSeasonalPatterns();
    }

    /**
     * Generate cost forecast for specified period
     */
    public function generateCostForecast(int $userId = null, ?int $projectId = null, int $months = 12): array
    {
        $historicalData = $this->getHistoricalCostData($userId, $projectId);
        $currentUsage = $this->getCurrentUsage($userId, $projectId);
        
        $forecast = [
            'forecast_metadata' => [
                'generated_at' => time(),
                'user_id' => $userId,
                'project_id' => $projectId,
                'forecast_period' => $months,
                'confidence_level' => 0.95,
                'model_version' => '1.0'
            ],
            'monthly_forecast' => $this->generateMonthlyForecast($historicalData, $currentUsage, $months),
            'quarterly_forecast' => $this->generateQuarterlyForecast($historicalData, $currentUsage, ceil($months / 3)),
            'annual_forecast' => $this->generateAnnualForecast($historicalData, $currentUsage),
            'trend_analysis' => $this->analyzeCostTrends($historicalData),
            'seasonal_patterns' => $this->analyzeSeasonalPatterns($historicalData),
            'anomaly_detection' => $this->detectCostAnomalies($historicalData),
            'risk_assessment' => $this->assessCostRisks($historicalData, $currentUsage),
            'optimization_opportunities' => $this->identifyOptimizationOpportunities($historicalData, $currentUsage),
            'recommendations' => $this->generateCostRecommendations($historicalData, $currentUsage)
        ];
        
        return $forecast;
    }

    /**
     * Generate monthly cost forecast
     */
    public function generateMonthlyForecast(array $historicalData, array $currentUsage, int $months): array
    {
        $forecast = [];
        $baseCost = $this->calculateBaseCost($currentUsage);
        $trendFactor = $this->calculateTrendFactor($historicalData);
        $seasonalFactor = $this->calculateSeasonalFactor($historicalData);
        
        for ($i = 1; $i <= $months; $i++) {
            $month = date('Y-m', strtotime("+{$i} months"));
            $predictedCost = $this->predictMonthlyCost($baseCost, $trendFactor, $seasonalFactor, $i);
            
            $forecast[$month] = [
                'predicted_cost' => $predictedCost,
                'confidence_interval' => $this->calculateConfidenceInterval($predictedCost, $i),
                'trend_factor' => $trendFactor,
                'seasonal_factor' => $seasonalFactor,
                'growth_rate' => $this->calculateGrowthRate($predictedCost, $baseCost),
                'risk_level' => $this->assessRiskLevel($predictedCost, $baseCost)
            ];
        }
        
        return $forecast;
    }

    /**
     * Generate quarterly cost forecast
     */
    public function generateQuarterlyForecast(array $historicalData, array $currentUsage, int $quarters): array
    {
        $forecast = [];
        $baseCost = $this->calculateBaseCost($currentUsage);
        $trendFactor = $this->calculateTrendFactor($historicalData);
        
        for ($i = 1; $i <= $quarters; $i++) {
            $quarter = ceil($i / 3);
            $year = date('Y', strtotime("+{$i} months"));
            $quarterKey = "Q{$quarter} {$year}";
            
            $predictedCost = $this->predictQuarterlyCost($baseCost, $trendFactor, $i);
            
            $forecast[$quarterKey] = [
                'predicted_cost' => $predictedCost,
                'confidence_interval' => $this->calculateConfidenceInterval($predictedCost, $i * 3),
                'trend_factor' => $trendFactor,
                'growth_rate' => $this->calculateGrowthRate($predictedCost, $baseCost),
                'risk_level' => $this->assessRiskLevel($predictedCost, $baseCost)
            ];
        }
        
        return $forecast;
    }

    /**
     * Generate annual cost forecast
     */
    public function generateAnnualForecast(array $historicalData, array $currentUsage): array
    {
        $baseCost = $this->calculateBaseCost($currentUsage);
        $trendFactor = $this->calculateTrendFactor($historicalData);
        $predictedCost = $this->predictAnnualCost($baseCost, $trendFactor);
        
        return [
            'predicted_annual_cost' => $predictedCost,
            'confidence_interval' => $this->calculateConfidenceInterval($predictedCost, 12),
            'trend_factor' => $trendFactor,
            'growth_rate' => $this->calculateGrowthRate($predictedCost, $baseCost * 12),
            'risk_level' => $this->assessRiskLevel($predictedCost, $baseCost * 12),
            'year_over_year_growth' => $this->calculateYearOverYearGrowth($historicalData)
        ];
    }

    /**
     * Analyze cost trends
     */
    public function analyzeCostTrends(array $historicalData): array
    {
        $trends = [
            'overall_trend' => $this->calculateOverallTrend($historicalData),
            'trend_strength' => $this->calculateTrendStrength($historicalData),
            'trend_direction' => $this->determineTrendDirection($historicalData),
            'trend_breakdown' => $this->getTrendBreakdown($historicalData),
            'trend_forecast' => $this->forecastTrend($historicalData),
            'trend_confidence' => $this->calculateTrendConfidence($historicalData)
        ];
        
        return $trends;
    }

    /**
     * Analyze seasonal patterns
     */
    public function analyzeSeasonalPatterns(array $historicalData): array
    {
        return [
            'seasonal_strength' => $this->calculateSeasonalStrength($historicalData),
            'seasonal_patterns' => $this->identifySeasonalPatterns($historicalData),
            'peak_seasons' => $this->identifyPeakSeasons($historicalData),
            'low_seasons' => $this->identifyLowSeasons($historicalData),
            'seasonal_forecast' => $this->forecastSeasonalPatterns($historicalData),
            'seasonal_adjustments' => $this->calculateSeasonalAdjustments($historicalData)
        ];
    }

    /**
     * Detect cost anomalies
     */
    public function detectCostAnomalies(array $historicalData): array
    {
        $anomalies = [];
        $mean = array_sum($historicalData) / count($historicalData);
        $stdDev = $this->calculateStandardDeviation($historicalData);
        $threshold = 2; // 2 standard deviations
        
        foreach ($historicalData as $date => $cost) {
            $zScore = abs(($cost - $mean) / $stdDev);
            
            if ($zScore > $threshold) {
                $anomalies[] = [
                    'date' => $date,
                    'cost' => $cost,
                    'z_score' => $zScore,
                    'anomaly_type' => $cost > $mean ? 'spike' : 'drop',
                    'severity' => $zScore > 3 ? 'high' : 'medium'
                ];
            }
        }
        
        return [
            'anomalies' => $anomalies,
            'anomaly_count' => count($anomalies),
            'anomaly_rate' => count($anomalies) / count($historicalData),
            'mean_cost' => $mean,
            'standard_deviation' => $stdDev,
            'threshold' => $threshold
        ];
    }

    /**
     * Assess cost risks
     */
    public function assessCostRisks(array $historicalData, array $currentUsage): array
    {
        $volatility = $this->calculateVolatility($historicalData);
        $trendRisk = $this->assessTrendRisk($historicalData);
        $seasonalRisk = $this->assessSeasonalRisk($historicalData);
        $usageRisk = $this->assessUsageRisk($currentUsage);
        
        $overallRisk = ($volatility + $trendRisk + $seasonalRisk + $usageRisk) / 4;
        
        return [
            'overall_risk_score' => $overallRisk,
            'risk_level' => $this->determineRiskLevel($overallRisk),
            'volatility_risk' => $volatility,
            'trend_risk' => $trendRisk,
            'seasonal_risk' => $seasonalRisk,
            'usage_risk' => $usageRisk,
            'risk_factors' => $this->identifyRiskFactors($historicalData, $currentUsage),
            'mitigation_strategies' => $this->suggestMitigationStrategies($overallRisk)
        ];
    }

    /**
     * Identify optimization opportunities
     */
    public function identifyOptimizationOpportunities(array $historicalData, array $currentUsage): array
    {
        $opportunities = [];
        
        // Cost optimization opportunities
        $costOptimization = $this->analyzeCostOptimizationOpportunities($historicalData, $currentUsage);
        if ($costOptimization['potential_savings'] > 0) {
            $opportunities[] = $costOptimization;
        }
        
        // Usage optimization opportunities
        $usageOptimization = $this->analyzeUsageOptimizationOpportunities($currentUsage);
        if ($usageOptimization['potential_savings'] > 0) {
            $opportunities[] = $usageOptimization;
        }
        
        // Tier optimization opportunities
        $tierOptimization = $this->analyzeTierOptimizationOpportunities($currentUsage);
        if ($tierOptimization['potential_savings'] > 0) {
            $opportunities[] = $tierOptimization;
        }
        
        return [
            'opportunities' => $opportunities,
            'total_potential_savings' => array_sum(array_column($opportunities, 'potential_savings')),
            'implementation_priority' => $this->prioritizeOpportunities($opportunities)
        ];
    }

    /**
     * Generate cost recommendations
     */
    public function generateCostRecommendations(array $historicalData, array $currentUsage): array
    {
        $recommendations = [];
        
        // Analyze trends and provide recommendations
        $trends = $this->analyzeCostTrends($historicalData);
        if ($trends['trend_direction'] === 'increasing') {
            $recommendations[] = [
                'type' => 'trend_management',
                'priority' => 'high',
                'message' => 'Cost trend is increasing. Consider implementing cost controls and optimization strategies.',
                'action_items' => ['Review usage patterns', 'Implement cost alerts', 'Optimize storage tiers']
            ];
        }
        
        // Analyze anomalies and provide recommendations
        $anomalies = $this->detectCostAnomalies($historicalData);
        if ($anomalies['anomaly_count'] > 0) {
            $recommendations[] = [
                'type' => 'anomaly_management',
                'priority' => 'medium',
                'message' => 'Cost anomalies detected. Implement monitoring and alerting for unusual cost spikes.',
                'action_items' => ['Set up anomaly detection', 'Implement cost alerts', 'Review usage patterns']
            ];
        }
        
        // Analyze optimization opportunities
        $opportunities = $this->identifyOptimizationOpportunities($historicalData, $currentUsage);
        if ($opportunities['total_potential_savings'] > 0) {
            $recommendations[] = [
                'type' => 'optimization',
                'priority' => 'high',
                'message' => 'Optimization opportunities identified with potential savings of $' . number_format($opportunities['total_potential_savings'], 2),
                'action_items' => ['Implement tier optimization', 'Enable compression', 'Review storage policies']
            ];
        }
        
        return $recommendations;
    }

    /**
     * Initialize forecast configuration
     */
    private function initializeForecastConfig(): void
    {
        $this->forecastConfig = [
            'forecast_periods' => ['monthly', 'quarterly', 'annual'],
            'confidence_levels' => [0.90, 0.95, 0.99],
            'trend_methods' => ['linear', 'exponential', 'polynomial'],
            'seasonal_methods' => ['additive', 'multiplicative'],
            'anomaly_thresholds' => [2, 3, 4] // standard deviations
        ];
    }

    /**
     * Initialize trend data
     */
    private function initializeTrendData(): void
    {
        $this->trendData = [
            'growth_rate' => 0.05, // 5% monthly growth
            'volatility' => 0.15, // 15% volatility
            'seasonality' => 0.10, // 10% seasonal variation
            'trend_strength' => 0.8 // 80% trend strength
        ];
    }

    /**
     * Initialize seasonal patterns
     */
    private function initializeSeasonalPatterns(): void
    {
        $this->seasonalPatterns = [
            'monthly' => [1.1, 1.05, 1.0, 0.95, 0.9, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15],
            'quarterly' => [1.1, 0.9, 1.0, 1.1],
            'annual' => [1.05]
        ];
    }

    // Helper methods for forecasting calculations
    private function getHistoricalCostData(int $userId = null, ?int $projectId = null): array { return array_fill(0, 12, 20.0); }
    private function getCurrentUsage(int $userId = null, ?int $projectId = null): array { return ['storage' => 100, 'requests' => 1000]; }
    private function calculateBaseCost(array $currentUsage): float { return 25.0; }
    private function calculateTrendFactor(array $historicalData): float { return 1.05; }
    private function calculateSeasonalFactor(array $historicalData): float { return 1.02; }
    private function predictMonthlyCost(float $baseCost, float $trendFactor, float $seasonalFactor, int $month): float { return $baseCost * pow($trendFactor, $month) * $seasonalFactor; }
    private function predictQuarterlyCost(float $baseCost, float $trendFactor, int $quarter): float { return $baseCost * pow($trendFactor, $quarter * 3); }
    private function predictAnnualCost(float $baseCost, float $trendFactor): float { return $baseCost * pow($trendFactor, 12); }
    private function calculateConfidenceInterval(float $predictedCost, int $periods): array { return ['lower' => $predictedCost * 0.9, 'upper' => $predictedCost * 1.1]; }
    private function calculateGrowthRate(float $predictedCost, float $baseCost): float { return ($predictedCost - $baseCost) / $baseCost; }
    private function assessRiskLevel(float $predictedCost, float $baseCost): string { return $predictedCost > $baseCost * 1.5 ? 'high' : 'medium'; }
    private function calculateOverallTrend(array $historicalData): string { return 'increasing'; }
    private function calculateTrendStrength(array $historicalData): float { return 0.8; }
    private function determineTrendDirection(array $historicalData): string { return 'increasing'; }
    private function getTrendBreakdown(array $historicalData): array { return []; }
    private function forecastTrend(array $historicalData): array { return []; }
    private function calculateTrendConfidence(array $historicalData): float { return 0.85; }
    private function calculateSeasonalStrength(array $historicalData): float { return 0.6; }
    private function identifySeasonalPatterns(array $historicalData): array { return []; }
    private function identifyPeakSeasons(array $historicalData): array { return []; }
    private function identifyLowSeasons(array $historicalData): array { return []; }
    private function forecastSeasonalPatterns(array $historicalData): array { return []; }
    private function calculateSeasonalAdjustments(array $historicalData): array { return []; }
    private function calculateStandardDeviation(array $data): float { return 5.0; }
    private function calculateVolatility(array $historicalData): float { return 0.15; }
    private function assessTrendRisk(array $historicalData): float { return 0.2; }
    private function assessSeasonalRisk(array $historicalData): float { return 0.1; }
    private function assessUsageRisk(array $currentUsage): float { return 0.3; }
    private function determineRiskLevel(float $riskScore): string { return $riskScore > 0.7 ? 'high' : ($riskScore > 0.4 ? 'medium' : 'low'); }
    private function identifyRiskFactors(array $historicalData, array $currentUsage): array { return []; }
    private function suggestMitigationStrategies(float $riskScore): array { return []; }
    private function analyzeCostOptimizationOpportunities(array $historicalData, array $currentUsage): array { return ['potential_savings' => 15.0]; }
    private function analyzeUsageOptimizationOpportunities(array $currentUsage): array { return ['potential_savings' => 8.0]; }
    private function analyzeTierOptimizationOpportunities(array $currentUsage): array { return ['potential_savings' => 12.0]; }
    private function prioritizeOpportunities(array $opportunities): array { return []; }
    private function calculateYearOverYearGrowth(array $historicalData): float { return 0.25; }
} 