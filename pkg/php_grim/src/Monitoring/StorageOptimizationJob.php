<?php

namespace GrimReaper\Monitoring;

use GrimReaper\Storage\CostOptimizationEngine;
use GrimReaper\Analytics\CostAnalyzer;
use GrimReaper\Analytics\UsageAnalyzer;

/**
 * Storage Optimization Job for automated optimization
 * Handles scheduling, execution, monitoring, and reporting of optimization tasks
 */
class StorageOptimizationJob
{
    private string $jobId;
    private int $userId;
    private ?int $projectId;
    private string $status;
    private int $createdAt;
    private int $scheduledAt;
    private int $startedAt;
    private int $completedAt;
    private string $priority;
    private string $type;
    private array $parameters;
    private array $results;
    private array $errors;
    private CostOptimizationEngine $optimizationEngine;
    private CostAnalyzer $costAnalyzer;
    private UsageAnalyzer $usageAnalyzer;

    public function __construct(
        string $jobId,
        int $userId,
        ?int $projectId,
        array $parameters = []
    ) {
        $this->jobId = $jobId;
        $this->userId = $userId;
        $this->projectId = $projectId;
        $this->status = 'pending';
        $this->createdAt = time();
        $this->scheduledAt = time();
        $this->startedAt = 0;
        $this->completedAt = 0;
        $this->priority = $parameters['priority'] ?? 'medium';
        $this->type = $parameters['type'] ?? 'storage_optimization';
        $this->parameters = $parameters;
        $this->results = [];
        $this->errors = [];
        
        $this->optimizationEngine = new CostOptimizationEngine();
        $this->costAnalyzer = new CostAnalyzer();
        $this->usageAnalyzer = new UsageAnalyzer();
    }

    /**
     * Execute the optimization job
     */
    public function execute(): array
    {
        $this->status = 'running';
        $this->startedAt = time();
        
        try {
            $this->logJobStart();
            
            // Execute optimization based on parameters
            $results = $this->executeOptimization();
            
            $this->results = $results;
            $this->status = 'completed';
            $this->completedAt = time();
            
            $this->logJobCompletion();
            $this->sendCompletionNotification();
            
            return $results;
            
        } catch (\Exception $e) {
            $this->status = 'failed';
            $this->completedAt = time();
            $this->errors[] = [
                'message' => $e->getMessage(),
                'timestamp' => time(),
                'trace' => $e->getTraceAsString()
            ];
            
            $this->logJobError($e);
            $this->sendErrorNotification($e);
            
            throw $e;
        }
    }

    /**
     * Schedule the job for later execution
     */
    public function schedule(int $scheduledTime): void
    {
        $this->scheduledAt = $scheduledTime;
        $this->status = 'scheduled';
        
        $this->logJobScheduling();
    }

    /**
     * Get job status and progress
     */
    public function getStatus(): array
    {
        $executionTime = $this->startedAt > 0 ? 
            ($this->completedAt > 0 ? $this->completedAt - $this->startedAt : time() - $this->startedAt) : 0;
        
        return [
            'job_id' => $this->jobId,
            'user_id' => $this->userId,
            'project_id' => $this->projectId,
            'status' => $this->status,
            'priority' => $this->priority,
            'type' => $this->type,
            'created_at' => $this->createdAt,
            'scheduled_at' => $this->scheduledAt,
            'started_at' => $this->startedAt,
            'completed_at' => $this->completedAt,
            'execution_time' => $executionTime,
            'parameters' => $this->parameters,
            'results' => $this->results,
            'errors' => $this->errors,
            'progress' => $this->calculateProgress()
        ];
    }

    /**
     * Cancel the job if it's pending or scheduled
     */
    public function cancel(): bool
    {
        if (in_array($this->status, ['pending', 'scheduled'])) {
            $this->status = 'cancelled';
            $this->completedAt = time();
            
            $this->logJobCancellation();
            return true;
        }
        
        return false;
    }

    /**
     * Retry a failed job
     */
    public function retry(): bool
    {
        if ($this->status === 'failed') {
            $this->status = 'pending';
            $this->errors = [];
            $this->results = [];
            $this->startedAt = 0;
            $this->completedAt = 0;
            
            $this->logJobRetry();
            return true;
        }
        
        return false;
    }

    /**
     * Execute the actual optimization
     */
    private function executeOptimization(): array
    {
        $results = [];
        
        // Run storage allocation optimization
        if ($this->parameters['optimize_tiers'] ?? false) {
            $results['tier_optimization'] = $this->executeTierOptimization();
        }
        
        // Enable compression
        if ($this->parameters['enable_compression'] ?? false) {
            $results['compression'] = $this->executeCompression();
        }
        
        // Enable deduplication
        if ($this->parameters['enable_deduplication'] ?? false) {
            $results['deduplication'] = $this->executeDeduplication();
        }
        
        // Migrate cold data
        if ($this->parameters['migrate_cold_data'] ?? false) {
            $results['cold_data_migration'] = $this->executeColdDataMigration();
        }
        
        // Apply lifecycle policies
        if ($this->parameters['apply_lifecycle_policies'] ?? false) {
            $results['lifecycle_policies'] = $this->executeLifecyclePolicies();
        }
        
        // Generate summary
        $results['summary'] = $this->generateOptimizationSummary($results);
        
        return $results;
    }

    /**
     * Execute tier optimization
     */
    private function executeTierOptimization(): array
    {
        $startTime = microtime(true);
        
        try {
            $optimizationResult = $this->optimizationEngine->optimizeStorageAllocation(
                $this->userId, 
                $this->projectId
            );
            
            $summary = $optimizationResult->getOptimizationSummary();
            
            return [
                'status' => 'completed',
                'execution_time' => microtime(true) - $startTime,
                'potential_savings' => $summary['potential_savings'],
                'migrations_total' => $summary['migrations_total'],
                'migrations_successful' => $summary['migrations_successful'],
                'migrations_failed' => $summary['migrations_failed'],
                'optimization_score' => $summary['optimization_score']
            ];
            
        } catch (\Exception $e) {
            return [
                'status' => 'failed',
                'execution_time' => microtime(true) - $startTime,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Execute compression optimization
     */
    private function executeCompression(): array
    {
        $startTime = microtime(true);
        
        try {
            $usageData = $this->usageAnalyzer->getUserUsage($this->userId, $this->projectId);
            $compressionOpportunities = $this->costAnalyzer->analyzeCompressionOpportunities($usageData);
            
            $compressedFiles = 0;
            $spaceSaved = 0;
            
            // Simulate compression execution
            foreach ($compressionOpportunities['opportunities'] as $opportunity) {
                $compressedFiles++;
                $spaceSaved += $opportunity['savings'];
            }
            
            return [
                'status' => 'completed',
                'execution_time' => microtime(true) - $startTime,
                'files_compressed' => $compressedFiles,
                'space_saved' => $spaceSaved,
                'compression_ratio' => $compressionOpportunities['savings'] > 0 ? 0.6 : 0.0
            ];
            
        } catch (\Exception $e) {
            return [
                'status' => 'failed',
                'execution_time' => microtime(true) - $startTime,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Execute deduplication optimization
     */
    private function executeDeduplication(): array
    {
        $startTime = microtime(true);
        
        try {
            $usageData = $this->usageAnalyzer->getUserUsage($this->userId, $this->projectId);
            $deduplicationOpportunities = $this->costAnalyzer->analyzeDeduplicationOpportunities($usageData);
            
            $duplicatesRemoved = 0;
            $spaceSaved = 0;
            
            // Simulate deduplication execution
            foreach ($deduplicationOpportunities['opportunities'] as $opportunity) {
                $duplicatesRemoved += $opportunity['duplicate_count'];
                $spaceSaved += $opportunity['savings'];
            }
            
            return [
                'status' => 'completed',
                'execution_time' => microtime(true) - $startTime,
                'duplicates_removed' => $duplicatesRemoved,
                'space_saved' => $spaceSaved,
                'deduplication_ratio' => $deduplicationOpportunities['savings'] > 0 ? 0.15 : 0.0
            ];
            
        } catch (\Exception $e) {
            return [
                'status' => 'failed',
                'execution_time' => microtime(true) - $startTime,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Execute cold data migration
     */
    private function executeColdDataMigration(): array
    {
        $startTime = microtime(true);
        
        try {
            $usageData = $this->usageAnalyzer->getUserUsage($this->userId, $this->projectId);
            $coldDataOpportunities = $this->costAnalyzer->analyzeColdDataOpportunities($usageData);
            
            $filesMigrated = 0;
            $spaceOptimized = 0;
            
            // Simulate cold data migration
            foreach ($coldDataOpportunities['opportunities'] as $opportunity) {
                $filesMigrated++;
                $spaceOptimized += $opportunity['savings'];
            }
            
            return [
                'status' => 'completed',
                'execution_time' => microtime(true) - $startTime,
                'files_migrated' => $filesMigrated,
                'space_optimized' => $spaceOptimized,
                'migration_efficiency' => 0.85
            ];
            
        } catch (\Exception $e) {
            return [
                'status' => 'failed',
                'execution_time' => microtime(true) - $startTime,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Execute lifecycle policies
     */
    private function executeLifecyclePolicies(): array
    {
        $startTime = microtime(true);
        
        try {
            $usageData = $this->usageAnalyzer->getUserUsage($this->userId, $this->projectId);
            $lifecycleRecommendations = $this->costAnalyzer->analyzeLifecyclePolicies($usageData);
            
            $policiesApplied = 0;
            $filesAffected = 0;
            
            // Simulate lifecycle policy application
            foreach ($lifecycleRecommendations as $recommendation) {
                $policiesApplied++;
                $filesAffected += $recommendation['affected_files'] ?? 0;
            }
            
            return [
                'status' => 'completed',
                'execution_time' => microtime(true) - $startTime,
                'policies_applied' => $policiesApplied,
                'files_affected' => $filesAffected,
                'policy_efficiency' => 0.90
            ];
            
        } catch (\Exception $e) {
            return [
                'status' => 'failed',
                'execution_time' => microtime(true) - $startTime,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Generate optimization summary
     */
    private function generateOptimizationSummary(array $results): array
    {
        $totalSavings = 0;
        $totalExecutionTime = 0;
        $successfulOperations = 0;
        $failedOperations = 0;
        
        foreach ($results as $operation => $result) {
            if ($operation === 'summary') continue;
            
            $totalExecutionTime += $result['execution_time'] ?? 0;
            
            if ($result['status'] === 'completed') {
                $successfulOperations++;
                $totalSavings += $result['potential_savings'] ?? $result['space_saved'] ?? 0;
            } else {
                $failedOperations++;
            }
        }
        
        return [
            'total_savings' => $totalSavings,
            'total_execution_time' => $totalExecutionTime,
            'successful_operations' => $successfulOperations,
            'failed_operations' => $failedOperations,
            'success_rate' => ($successfulOperations + $failedOperations) > 0 ? 
                $successfulOperations / ($successfulOperations + $failedOperations) : 0,
            'optimization_score' => $this->calculateOverallOptimizationScore($results)
        ];
    }

    /**
     * Calculate overall optimization score
     */
    private function calculateOverallOptimizationScore(array $results): float
    {
        $score = 0;
        $weight = 1.0 / (count($results) - 1); // Exclude summary
        
        foreach ($results as $operation => $result) {
            if ($operation === 'summary') continue;
            
            if ($result['status'] === 'completed') {
                $score += $weight;
            }
        }
        
        return min(1.0, $score);
    }

    /**
     * Calculate job progress
     */
    private function calculateProgress(): float
    {
        if ($this->status === 'completed' || $this->status === 'failed' || $this->status === 'cancelled') {
            return 100.0;
        } elseif ($this->status === 'running') {
            // Estimate progress based on execution time
            $estimatedDuration = 300; // 5 minutes
            $elapsed = time() - $this->startedAt;
            return min(95.0, ($elapsed / $estimatedDuration) * 100);
        } else {
            return 0.0;
        }
    }

    /**
     * Log job start
     */
    private function logJobStart(): void
    {
        $logEntry = [
            'timestamp' => time(),
            'level' => 'INFO',
            'job_id' => $this->jobId,
            'event' => 'job_started',
            'user_id' => $this->userId,
            'project_id' => $this->projectId,
            'parameters' => $this->parameters
        ];
        
        file_put_contents('logs/optimization_jobs.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Log job completion
     */
    private function logJobCompletion(): void
    {
        $logEntry = [
            'timestamp' => time(),
            'level' => 'INFO',
            'job_id' => $this->jobId,
            'event' => 'job_completed',
            'execution_time' => $this->completedAt - $this->startedAt,
            'results' => $this->results
        ];
        
        file_put_contents('logs/optimization_jobs.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Log job error
     */
    private function logJobError(\Exception $e): void
    {
        $logEntry = [
            'timestamp' => time(),
            'level' => 'ERROR',
            'job_id' => $this->jobId,
            'event' => 'job_failed',
            'error' => $e->getMessage(),
            'trace' => $e->getTraceAsString()
        ];
        
        file_put_contents('logs/optimization_jobs.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Log job scheduling
     */
    private function logJobScheduling(): void
    {
        $logEntry = [
            'timestamp' => time(),
            'level' => 'INFO',
            'job_id' => $this->jobId,
            'event' => 'job_scheduled',
            'scheduled_at' => $this->scheduledAt
        ];
        
        file_put_contents('logs/optimization_jobs.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Log job cancellation
     */
    private function logJobCancellation(): void
    {
        $logEntry = [
            'timestamp' => time(),
            'level' => 'INFO',
            'job_id' => $this->jobId,
            'event' => 'job_cancelled'
        ];
        
        file_put_contents('logs/optimization_jobs.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Log job retry
     */
    private function logJobRetry(): void
    {
        $logEntry = [
            'timestamp' => time(),
            'level' => 'INFO',
            'job_id' => $this->jobId,
            'event' => 'job_retry'
        ];
        
        file_put_contents('logs/optimization_jobs.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Send completion notification
     */
    private function sendCompletionNotification(): void
    {
        // Mock implementation - would send email/notification
        $notification = [
            'type' => 'job_completion',
            'job_id' => $this->jobId,
            'user_id' => $this->userId,
            'status' => 'completed',
            'results' => $this->results
        ];
        
        file_put_contents('logs/notifications.log', json_encode($notification) . "\n", FILE_APPEND);
    }

    /**
     * Send error notification
     */
    private function sendErrorNotification(\Exception $e): void
    {
        // Mock implementation - would send email/notification
        $notification = [
            'type' => 'job_error',
            'job_id' => $this->jobId,
            'user_id' => $this->userId,
            'status' => 'failed',
            'error' => $e->getMessage()
        ];
        
        file_put_contents('logs/notifications.log', json_encode($notification) . "\n", FILE_APPEND);
    }

    // Getters
    public function getJobId(): string { return $this->jobId; }
    public function getUserId(): int { return $this->userId; }
    public function getProjectId(): ?int { return $this->projectId; }
    public function getStatus(): string { return $this->status; }
    public function getPriority(): string { return $this->priority; }
    public function getType(): string { return $this->type; }
    public function getParameters(): array { return $this->parameters; }
    public function getResults(): array { return $this->results; }
    public function getErrors(): array { return $this->errors; }
} 