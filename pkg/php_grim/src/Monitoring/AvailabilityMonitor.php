<?php

namespace GrimReaper\Monitoring;

/**
 * Availability Monitor for storage provider monitoring and SLA compliance
 */
class AvailabilityMonitor
{
    private array $providerStatus;
    private array $slaMetrics;
    private array $incidentHistory;
    private array $monitoringConfig;

    public function __construct()
    {
        $this->providerStatus = [];
        $this->slaMetrics = [];
        $this->incidentHistory = [];
        $this->initializeMonitoringConfig();
    }

    /**
     * Check if provider is available
     */
    public function isProviderAvailable(string $providerId): bool
    {
        $status = $this->getProviderStatus($providerId);
        return $status['current_status'] === 'available';
    }

    /**
     * Get provider availability data
     */
    public function getProviderAvailability(string $providerId): array
    {
        $status = $this->getProviderStatus($providerId);
        
        return [
            'historical_uptime' => $status['historical_uptime'],
            'current_status' => $status['current_status'] === 'available',
            'sla_compliance' => $status['sla_compliance'],
            'incidents_last_30_days' => $this->getIncidentCount($providerId, 30),
            'last_incident' => $this->getLastIncident($providerId),
            'response_time' => $status['response_time'],
            'error_rate' => $status['error_rate']
        ];
    }

    /**
     * Update migration status
     */
    public function updateMigrationStatus(string $migrationId, array $result): void
    {
        $this->logMigrationResult($migrationId, $result);
    }

    /**
     * Get provider status
     */
    private function getProviderStatus(string $providerId): array
    {
        if (!isset($this->providerStatus[$providerId])) {
            // Mock status - would query actual provider
            $this->providerStatus[$providerId] = [
                'current_status' => 'available',
                'historical_uptime' => 99.9,
                'sla_compliance' => 99.95,
                'response_time' => 50, // ms
                'error_rate' => 0.001,
                'last_check' => time()
            ];
        }
        
        return $this->providerStatus[$providerId];
    }

    /**
     * Get incident count for provider
     */
    private function getIncidentCount(string $providerId, int $days): int
    {
        $cutoffTime = time() - ($days * 24 * 3600);
        $count = 0;
        
        foreach ($this->incidentHistory as $incident) {
            if ($incident['provider_id'] === $providerId && $incident['timestamp'] >= $cutoffTime) {
                $count++;
            }
        }
        
        return $count;
    }

    /**
     * Get last incident for provider
     */
    private function getLastIncident(string $providerId): ?array
    {
        $lastIncident = null;
        
        foreach ($this->incidentHistory as $incident) {
            if ($incident['provider_id'] === $providerId) {
                if ($lastIncident === null || $incident['timestamp'] > $lastIncident['timestamp']) {
                    $lastIncident = $incident;
                }
            }
        }
        
        return $lastIncident;
    }

    /**
     * Log migration result
     */
    private function logMigrationResult(string $migrationId, array $result): void
    {
        $logEntry = [
            'migration_id' => $migrationId,
            'status' => $result['status'],
            'timestamp' => time(),
            'execution_time' => $result['execution_time'] ?? 0
        ];
        
        if (isset($result['error'])) {
            $logEntry['error'] = $result['error'];
        }
        
        file_put_contents('logs/migration_results.log', json_encode($logEntry) . "\n", FILE_APPEND);
    }

    /**
     * Initialize monitoring configuration
     */
    private function initializeMonitoringConfig(): void
    {
        $this->monitoringConfig = [
            'check_interval' => 60, // seconds
            'timeout' => 30, // seconds
            'retry_attempts' => 3,
            'sla_thresholds' => [
                'uptime' => 99.9,
                'response_time' => 100, // ms
                'error_rate' => 0.01 // 1%
            ]
        ];
    }
} 