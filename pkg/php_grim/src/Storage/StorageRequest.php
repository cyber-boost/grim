<?php

namespace GrimReaper\Storage;

/**
 * Storage Request with comprehensive metadata for intelligent routing
 */
class StorageRequest
{
    private string $id;
    private int $userId;
    private ?int $projectId;
    private int $fileSize;
    private string $fileType;
    private string $accessPattern;
    private int $accessFrequency;
    private int $retentionPeriod;
    private array $geographicLocation;
    private int $timeOfDay;
    private bool $requiresEncryption;
    private bool $requiresCompression;
    private bool $requiresDeduplication;
    private array $complianceRequirements;
    private array $performanceRequirements;
    private int $createdTime;

    public function __construct(
        int $userId,
        int $fileSize,
        string $fileType,
        array $geographicLocation,
        array $options = []
    ) {
        $this->id = uniqid('req_');
        $this->userId = $userId;
        $this->projectId = $options['project_id'] ?? null;
        $this->fileSize = $fileSize;
        $this->fileType = $fileType;
        $this->accessPattern = $options['access_pattern'] ?? 'warm';
        $this->accessFrequency = $options['access_frequency'] ?? 1;
        $this->retentionPeriod = $options['retention_period'] ?? 365; // days
        $this->geographicLocation = $geographicLocation;
        $this->timeOfDay = $options['time_of_day'] ?? (int)date('H');
        $this->requiresEncryption = $options['requires_encryption'] ?? false;
        $this->requiresCompression = $options['requires_compression'] ?? false;
        $this->requiresDeduplication = $options['requires_deduplication'] ?? false;
        $this->complianceRequirements = $options['compliance_requirements'] ?? [];
        $this->performanceRequirements = $options['performance_requirements'] ?? [];
        $this->createdTime = time();
    }

    // Getters
    public function getId(): string
    {
        return $this->id;
    }

    public function getUserId(): int
    {
        return $this->userId;
    }

    public function getProjectId(): ?int
    {
        return $this->projectId;
    }

    public function getFileSize(): int
    {
        return $this->fileSize;
    }

    public function getFileType(): string
    {
        return $this->fileType;
    }

    public function getAccessPattern(): string
    {
        return $this->accessPattern;
    }

    public function getAccessFrequency(): int
    {
        return $this->accessFrequency;
    }

    public function getRetentionPeriod(): int
    {
        return $this->retentionPeriod;
    }

    public function getGeographicLocation(): array
    {
        return $this->geographicLocation;
    }

    public function getTimeOfDay(): int
    {
        return $this->timeOfDay;
    }

    public function requiresEncryption(): bool
    {
        return $this->requiresEncryption;
    }

    public function requiresCompression(): bool
    {
        return $this->requiresCompression;
    }

    public function requiresDeduplication(): bool
    {
        return $this->requiresDeduplication;
    }

    public function getComplianceRequirements(): array
    {
        return $this->complianceRequirements;
    }

    public function getPerformanceRequirements(): array
    {
        return $this->performanceRequirements;
    }

    public function getCreatedTime(): int
    {
        return $this->createdTime;
    }

    /**
     * Get request complexity score
     */
    public function getComplexityScore(): float
    {
        $score = 1.0;
        
        if ($this->requiresEncryption) {
            $score *= 1.2;
        }
        
        if ($this->requiresCompression) {
            $score *= 1.1;
        }
        
        if ($this->requiresDeduplication) {
            $score *= 1.3;
        }
        
        if (!empty($this->complianceRequirements)) {
            $score *= 1.15;
        }
        
        return $score;
    }

    /**
     * Get priority score based on access pattern and frequency
     */
    public function getPriorityScore(): float
    {
        $patternScores = [
            'hot' => 1.0,
            'warm' => 0.7,
            'cold' => 0.4,
            'archive' => 0.1
        ];
        
        $baseScore = $patternScores[$this->accessPattern] ?? 0.5;
        $frequencyMultiplier = min(2.0, $this->accessFrequency / 10.0);
        
        return $baseScore * $frequencyMultiplier;
    }

    /**
     * Convert to array for serialization
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->userId,
            'project_id' => $this->projectId,
            'file_size' => $this->fileSize,
            'file_type' => $this->fileType,
            'access_pattern' => $this->accessPattern,
            'access_frequency' => $this->accessFrequency,
            'retention_period' => $this->retentionPeriod,
            'geographic_location' => $this->geographicLocation,
            'time_of_day' => $this->timeOfDay,
            'requires_encryption' => $this->requiresEncryption,
            'requires_compression' => $this->requiresCompression,
            'requires_deduplication' => $this->requiresDeduplication,
            'compliance_requirements' => $this->complianceRequirements,
            'performance_requirements' => $this->performanceRequirements,
            'created_time' => $this->createdTime
        ];
    }

    /**
     * Create from array
     */
    public static function fromArray(array $data): self
    {
        return new self(
            $data['user_id'],
            $data['file_size'],
            $data['file_type'],
            $data['geographic_location'],
            [
                'project_id' => $data['project_id'] ?? null,
                'access_pattern' => $data['access_pattern'] ?? 'warm',
                'access_frequency' => $data['access_frequency'] ?? 1,
                'retention_period' => $data['retention_period'] ?? 365,
                'time_of_day' => $data['time_of_day'] ?? 12,
                'requires_encryption' => $data['requires_encryption'] ?? false,
                'requires_compression' => $data['requires_compression'] ?? false,
                'requires_deduplication' => $data['requires_deduplication'] ?? false,
                'compliance_requirements' => $data['compliance_requirements'] ?? [],
                'performance_requirements' => $data['performance_requirements'] ?? []
            ]
        );
    }
} 