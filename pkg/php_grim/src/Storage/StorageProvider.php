<?php

namespace GrimReaper\Storage;

/**
 * Storage Provider with capabilities, costs, and performance metrics
 */
class StorageProvider
{
    private string $id;
    private string $name;
    private array $config;
    private array $performanceMetrics;
    private array $reliabilityMetrics;
    private array $complianceCertifications;
    private array $geographicLocations;
    private array $costStructure;

    public function __construct(string $id, string $name, array $config = [])
    {
        $this->id = $id;
        $this->name = $name;
        $this->config = $config;
        $this->initializeMetrics();
        $this->initializeCompliance();
        $this->initializeCostStructure();
    }

    // Getters
    public function getId(): string
    {
        return $this->id;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getGeographicLocation(): array
    {
        return $this->config['geographic_location'] ?? ['unknown'];
    }

    public function getCostPerGB(): float
    {
        return $this->config['cost_per_gb'] ?? 0.023;
    }

    public function getTransferCostPerGB(): float
    {
        return $this->config['transfer_cost_per_gb'] ?? 0.09;
    }

    public function getPerformanceTier(): string
    {
        return $this->config['performance_tier'] ?? 'standard';
    }

    public function getPerformanceMetrics(): array
    {
        return $this->performanceMetrics;
    }

    public function getReliabilityMetrics(): array
    {
        return $this->reliabilityMetrics;
    }

    public function getComplianceCertifications(): array
    {
        return $this->complianceCertifications;
    }

    public function getGeographicLocations(): array
    {
        return $this->geographicLocations;
    }

    public function getCostStructure(): array
    {
        return $this->costStructure;
    }

    /**
     * Get IOPS (Input/Output Operations Per Second)
     */
    public function getIOPS(): int
    {
        return $this->performanceMetrics['iops'] ?? 3000;
    }

    /**
     * Get throughput in MB/s
     */
    public function getThroughput(): float
    {
        return $this->performanceMetrics['throughput'] ?? 100.0;
    }

    /**
     * Get latency in milliseconds
     */
    public function getLatency(): float
    {
        return $this->performanceMetrics['latency'] ?? 10.0;
    }

    /**
     * Get uptime percentage
     */
    public function getUptime(): float
    {
        return $this->reliabilityMetrics['uptime'] ?? 99.9;
    }

    /**
     * Get error rate percentage
     */
    public function getErrorRate(): float
    {
        return $this->reliabilityMetrics['error_rate'] ?? 0.001;
    }

    /**
     * Get durability percentage
     */
    public function getDurability(): float
    {
        return $this->reliabilityMetrics['durability'] ?? 99.999999999;
    }

    /**
     * Check if provider supports specific compliance
     */
    public function supportsCompliance(string $compliance): bool
    {
        return in_array($compliance, $this->complianceCertifications);
    }

    /**
     * Check if provider is available in geographic location
     */
    public function isAvailableInLocation(array $location): bool
    {
        foreach ($this->geographicLocations as $providerLocation) {
            if ($this->isLocationMatch($location, $providerLocation)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Calculate cost for storage request
     */
    public function calculateCost(StorageRequest $request): float
    {
        $fileSize = $request->getFileSize();
        $retentionPeriod = $request->getRetentionPeriod();
        $accessPattern = $request->getAccessPattern();
        
        // Get tier-specific costs
        $tierCosts = $this->getTierCosts($accessPattern);
        
        // Calculate storage cost
        $sizeInGB = $fileSize / (1024 * 1024 * 1024);
        $months = $retentionPeriod / 30;
        $storageCost = $tierCosts['storage'] * $sizeInGB * $months;
        
        // Calculate transfer cost
        $transferMultiplier = $this->getTransferMultiplier($accessPattern);
        $transferCost = $tierCosts['transfer'] * $sizeInGB * $transferMultiplier;
        
        // Calculate operational cost
        $operationalCost = $tierCosts['operational'] * $request->getComplexityScore();
        
        return $storageCost + $transferCost + $operationalCost;
    }

    /**
     * Get performance score for request
     */
    public function getPerformanceScore(StorageRequest $request): float
    {
        $requirements = $request->getPerformanceRequirements();
        
        if (empty($requirements)) {
            return 1.0; // Default perfect score if no requirements
        }
        
        $score = 1.0;
        
        // Check latency requirements
        if (isset($requirements['max_latency'])) {
            $latencyScore = max(0, 1 - ($this->getLatency() / $requirements['max_latency']));
            $score *= $latencyScore;
        }
        
        // Check throughput requirements
        if (isset($requirements['min_throughput'])) {
            $throughputScore = min(1, $this->getThroughput() / $requirements['min_throughput']);
            $score *= $throughputScore;
        }
        
        // Check IOPS requirements
        if (isset($requirements['min_iops'])) {
            $iopsScore = min(1, $this->getIOPS() / $requirements['min_iops']);
            $score *= $iopsScore;
        }
        
        return $score;
    }

    /**
     * Get reliability score
     */
    public function getReliabilityScore(): float
    {
        $uptimeScore = $this->getUptime() / 100;
        $errorRateScore = max(0, 1 - ($this->getErrorRate() / 0.01)); // 1% max error rate
        $durabilityScore = $this->getDurability() / 100;
        
        return ($uptimeScore * 0.4) + ($errorRateScore * 0.3) + ($durabilityScore * 0.3);
    }

    /**
     * Get compliance score for request
     */
    public function getComplianceScore(StorageRequest $request): float
    {
        $requiredCompliance = $request->getComplianceRequirements();
        
        if (empty($requiredCompliance)) {
            return 1.0; // Perfect score if no compliance requirements
        }
        
        $supportedCount = 0;
        foreach ($requiredCompliance as $compliance) {
            if ($this->supportsCompliance($compliance)) {
                $supportedCount++;
            }
        }
        
        return $supportedCount / count($requiredCompliance);
    }

    /**
     * Initialize performance metrics
     */
    private function initializeMetrics(): void
    {
        $this->performanceMetrics = [
            'iops' => $this->config['iops'] ?? 3000,
            'throughput' => $this->config['throughput'] ?? 100.0,
            'latency' => $this->config['latency'] ?? 10.0,
            'bandwidth' => $this->config['bandwidth'] ?? 1000.0
        ];

        $this->reliabilityMetrics = [
            'uptime' => $this->config['uptime'] ?? 99.9,
            'error_rate' => $this->config['error_rate'] ?? 0.001,
            'durability' => $this->config['durability'] ?? 99.999999999,
            'availability' => $this->config['availability'] ?? 99.9
        ];
    }

    /**
     * Initialize compliance certifications
     */
    private function initializeCompliance(): void
    {
        $this->complianceCertifications = $this->config['compliance'] ?? [
            'soc2',
            'iso27001',
            'pci_dss'
        ];

        $this->geographicLocations = $this->config['geographic_location'] ?? [
            ['latitude' => 40.7128, 'longitude' => -74.0060, 'region' => 'us-east-1'],
            ['latitude' => 34.0522, 'longitude' => -118.2437, 'region' => 'us-west-2'],
            ['latitude' => 51.5074, 'longitude' => -0.1278, 'region' => 'eu-west-1']
        ];
    }

    /**
     * Initialize cost structure
     */
    private function initializeCostStructure(): void
    {
        $this->costStructure = [
            'hot' => [
                'storage' => $this->config['cost_per_gb'] ?? 0.023,
                'transfer' => $this->config['transfer_cost_per_gb'] ?? 0.09,
                'operational' => 0.001
            ],
            'warm' => [
                'storage' => ($this->config['cost_per_gb'] ?? 0.023) * 0.6,
                'transfer' => ($this->config['transfer_cost_per_gb'] ?? 0.09) * 0.8,
                'operational' => 0.0005
            ],
            'cold' => [
                'storage' => ($this->config['cost_per_gb'] ?? 0.023) * 0.2,
                'transfer' => ($this->config['transfer_cost_per_gb'] ?? 0.09) * 1.2,
                'operational' => 0.0002
            ],
            'archive' => [
                'storage' => ($this->config['cost_per_gb'] ?? 0.023) * 0.02,
                'transfer' => ($this->config['transfer_cost_per_gb'] ?? 0.09) * 2.0,
                'operational' => 0.0001
            ]
        ];
    }

    /**
     * Get tier-specific costs
     */
    private function getTierCosts(string $tier): array
    {
        return $this->costStructure[$tier] ?? $this->costStructure['warm'];
    }

    /**
     * Get transfer multiplier based on access pattern
     */
    private function getTransferMultiplier(string $accessPattern): float
    {
        $multipliers = [
            'hot' => 10.0,
            'warm' => 2.0,
            'cold' => 0.1,
            'archive' => 0.01
        ];
        
        return $multipliers[$accessPattern] ?? 1.0;
    }

    /**
     * Check if two locations match
     */
    private function isLocationMatch(array $location1, array $location2): bool
    {
        // Simple region-based matching
        if (isset($location1['region']) && isset($location2['region'])) {
            return $location1['region'] === $location2['region'];
        }
        
        // Geographic proximity check (within 100km)
        if (isset($location1['latitude']) && isset($location1['longitude']) &&
            isset($location2['latitude']) && isset($location2['longitude'])) {
            
            $distance = $this->calculateDistance($location1, $location2);
            return $distance <= 100; // 100km radius
        }
        
        return false;
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
     * Convert to array for serialization
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'config' => $this->config,
            'performance_metrics' => $this->performanceMetrics,
            'reliability_metrics' => $this->reliabilityMetrics,
            'compliance_certifications' => $this->complianceCertifications,
            'geographic_locations' => $this->geographicLocations,
            'cost_structure' => $this->costStructure
        ];
    }

    /**
     * Create from array
     */
    public static function fromArray(array $data): self
    {
        $provider = new self($data['id'], $data['name'], $data['config'] ?? []);
        
        // Override with stored data
        if (isset($data['performance_metrics'])) {
            $provider->performanceMetrics = $data['performance_metrics'];
        }
        
        if (isset($data['reliability_metrics'])) {
            $provider->reliabilityMetrics = $data['reliability_metrics'];
        }
        
        if (isset($data['compliance_certifications'])) {
            $provider->complianceCertifications = $data['compliance_certifications'];
        }
        
        if (isset($data['geographic_locations'])) {
            $provider->geographicLocations = $data['geographic_locations'];
        }
        
        if (isset($data['cost_structure'])) {
            $provider->costStructure = $data['cost_structure'];
        }
        
        return $provider;
    }
} 