<?php

namespace GrimReaper\Monitoring;

use GrimReaper\Analytics\CostAnalyzer;
use GrimReaper\Analytics\UsageAnalyzer;

/**
 * Real-Time Alerting System for cost spikes, usage limits, and performance monitoring
 * Ensures 99.9% uptime monitoring and <100ms API response time tracking
 */
class RealTimeAlertingSystem
{
    private CostAnalyzer $costAnalyzer;
    private UsageAnalyzer $usageAnalyzer;
    private array $alertThresholds;
    private array $activeAlerts;
    private array $alertHistory;
    private array $notificationChannels;

    public function __construct()
    {
        $this->costAnalyzer = new CostAnalyzer();
        $this->usageAnalyzer = new UsageAnalyzer();
        $this->initializeAlertThresholds();
        $this->initializeNotificationChannels();
        $this->activeAlerts = [];
        $this->alertHistory = [];
    }

    /**
     * Monitor for cost spikes and usage limits
     */
    public function monitorCostSpikes(int $userId = null, ?int $projectId = null): array
    {
        $alerts = [];
        
        // Get current cost data
        $currentCost = $this->getCurrentCost($userId, $projectId);
        $historicalCosts = $this->getHistoricalCosts($userId, $projectId, 30); // Last 30 days
        
        // Check for cost spikes
        $costSpikeThreshold = $this->alertThresholds['cost_spike'];
        $averageCost = array_sum($historicalCosts) / count($historicalCosts);
        $costIncrease = ($currentCost - $averageCost) / $averageCost;
        
        if ($costIncrease > $costSpikeThreshold) {
            $alert = [
                'id' => uniqid('alert_'),
                'type' => 'cost_spike',
                'severity' => $costIncrease > 0.5 ? 'critical' : 'warning',
                'message' => "Cost spike detected: " . number_format($costIncrease * 100, 1) . "% increase",
                'current_cost' => $currentCost,
                'average_cost' => $averageCost,
                'increase_percentage' => $costIncrease * 100,
                'timestamp' => time(),
                'user_id' => $userId,
                'project_id' => $projectId
            ];
            
            $alerts[] = $alert;
            $this->triggerAlert($alert);
        }
        
        return $alerts;
    }

    /**
     * Monitor usage limits
     */
    public function monitorUsageLimits(int $userId = null, ?int $projectId = null): array
    {
        $alerts = [];
        
        $usageData = $this->usageAnalyzer->getUserUsage($userId, $projectId);
        $tierBreakdown = $this->getTierBreakdown($userId, $projectId);
        
        foreach ($tierBreakdown as $tier => $data) {
            $usagePercentage = $data['usage_percentage'] ?? 0;
            $limit = $this->alertThresholds['usage_limit'];
            
            if ($usagePercentage > $limit) {
                $alert = [
                    'id' => uniqid('alert_'),
                    'type' => 'usage_limit',
                    'severity' => $usagePercentage > 0.95 ? 'critical' : 'warning',
                    'message' => "Usage limit exceeded for {$tier} tier: " . number_format($usagePercentage, 1) . "%",
                    'tier' => $tier,
                    'usage_percentage' => $usagePercentage,
                    'current_usage' => $data['storage_used'] ?? 0,
                    'limit' => $data['storage_limit'] ?? 0,
                    'timestamp' => time(),
                    'user_id' => $userId,
                    'project_id' => $projectId
                ];
                
                $alerts[] = $alert;
                $this->triggerAlert($alert);
            }
        }
        
        return $alerts;
    }

    /**
     * Monitor performance and API response times
     */
    public function monitorPerformance(): array
    {
        $alerts = [];
        
        // Monitor API response time
        $responseTime = $this->getCurrentResponseTime();
        $responseTimeThreshold = $this->alertThresholds['api_response_time'];
        
        if ($responseTime > $responseTimeThreshold) {
            $alert = [
                'id' => uniqid('alert_'),
                'type' => 'performance_degradation',
                'severity' => $responseTime > 500 ? 'critical' : 'warning',
                'message' => "API response time degraded: " . number_format($responseTime, 2) . "ms",
                'current_response_time' => $responseTime,
                'threshold' => $responseTimeThreshold,
                'timestamp' => time()
            ];
            
            $alerts[] = $alert;
            $this->triggerAlert($alert);
        }
        
        // Monitor uptime
        $uptime = $this->getCurrentUptime();
        $uptimeThreshold = $this->alertThresholds['uptime'];
        
        if ($uptime < $uptimeThreshold) {
            $alert = [
                'id' => uniqid('alert_'),
                'type' => 'uptime_degradation',
                'severity' => $uptime < 99.0 ? 'critical' : 'warning',
                'message' => "Uptime degraded: " . number_format($uptime, 3) . "%",
                'current_uptime' => $uptime,
                'threshold' => $uptimeThreshold,
                'timestamp' => time()
            ];
            
            $alerts[] = $alert;
            $this->triggerAlert($alert);
        }
        
        // Monitor error rate
        $errorRate = $this->getCurrentErrorRate();
        $errorRateThreshold = $this->alertThresholds['error_rate'];
        
        if ($errorRate > $errorRateThreshold) {
            $alert = [
                'id' => uniqid('alert_'),
                'type' => 'high_error_rate',
                'severity' => $errorRate > 0.05 ? 'critical' : 'warning',
                'message' => "High error rate detected: " . number_format($errorRate * 100, 2) . "%",
                'current_error_rate' => $errorRate,
                'threshold' => $errorRateThreshold,
                'timestamp' => time()
            ];
            
            $alerts[] = $alert;
            $this->triggerAlert($alert);
        }
        
        return $alerts;
    }

    /**
     * Monitor SLA compliance
     */
    public function monitorSLACompliance(): array
    {
        $alerts = [];
        
        $slaMetrics = $this->getSLAMetrics();
        
        foreach ($slaMetrics as $metric => $data) {
            $currentValue = $data['current'];
            $slaTarget = $data['target'];
            $isViolation = $data['type'] === 'minimum' ? $currentValue < $slaTarget : $currentValue > $slaTarget;
            
            if ($isViolation) {
                $alert = [
                    'id' => uniqid('alert_'),
                    'type' => 'sla_violation',
                    'severity' => 'critical',
                    'message' => "SLA violation for {$metric}: " . number_format($currentValue, 2) . " (target: " . number_format($slaTarget, 2) . ")",
                    'metric' => $metric,
                    'current_value' => $currentValue,
                    'target_value' => $slaTarget,
                    'violation_type' => $data['type'],
                    'timestamp' => time()
                ];
                
                $alerts[] = $alert;
                $this->triggerAlert($alert);
            }
        }
        
        return $alerts;
    }

    /**
     * Get all active alerts
     */
    public function getActiveAlerts(int $userId = null, ?int $projectId = null): array
    {
        if ($userId !== null) {
            return array_filter($this->activeAlerts, function($alert) use ($userId, $projectId) {
                return $alert['user_id'] === $userId && 
                       ($projectId === null || $alert['project_id'] === $projectId);
            });
        }
        
        return $this->activeAlerts;
    }

    /**
     * Acknowledge an alert
     */
    public function acknowledgeAlert(string $alertId, int $userId): bool
    {
        foreach ($this->activeAlerts as &$alert) {
            if ($alert['id'] === $alertId) {
                $alert['acknowledged'] = true;
                $alert['acknowledged_by'] = $userId;
                $alert['acknowledged_at'] = time();
                
                $this->logAlertAcknowledgment($alert);
                return true;
            }
        }
        
        return false;
    }

    /**
     * Resolve an alert
     */
    public function resolveAlert(string $alertId, int $userId, string $resolution = ''): bool
    {
        foreach ($this->activeAlerts as $key => $alert) {
            if ($alert['id'] === $alertId) {
                $alert['resolved'] = true;
                $alert['resolved_by'] = $userId;
                $alert['resolved_at'] = time();
                $alert['resolution'] = $resolution;
                
                // Move to history
                $this->alertHistory[] = $alert;
                unset($this->activeAlerts[$key]);
                
                $this->logAlertResolution($alert);
                return true;
            }
        }
        
        return false;
    }

    /**
     * Get alert statistics
     */
    public function getAlertStatistics(int $userId = null, ?int $projectId = null): array
    {
        $allAlerts = array_merge($this->activeAlerts, $this->alertHistory);
        
        if ($userId !== null) {
            $allAlerts = array_filter($allAlerts, function($alert) use ($userId, $projectId) {
                return $alert['user_id'] === $userId && 
                       ($projectId === null || $alert['project_id'] === $projectId);
            });
        }
        
        $stats = [
            'total_alerts' => count($allAlerts),
            'active_alerts' => count($this->activeAlerts),
            'resolved_alerts' => count($this->alertHistory),
            'critical_alerts' => 0,
            'warning_alerts' => 0,
            'alerts_by_type' => [],
            'alerts_by_severity' => []
        ];
        
        foreach ($allAlerts as $alert) {
            $severity = $alert['severity'];
            $type = $alert['type'];
            
            $stats['alerts_by_severity'][$severity] = ($stats['alerts_by_severity'][$severity] ?? 0) + 1;
            $stats['alerts_by_type'][$type] = ($stats['alerts_by_type'][$type] ?? 0) + 1;
            
            if ($severity === 'critical') {
                $stats['critical_alerts']++;
            } elseif ($severity === 'warning') {
                $stats['warning_alerts']++;
            }
        }
        
        return $stats;
    }

    /**
     * Trigger an alert
     */
    private function triggerAlert(array $alert): void
    {
        $this->activeAlerts[] = $alert;
        
        // Log the alert
        $this->logAlert($alert);
        
        // Send notifications
        $this->sendNotifications($alert);
        
        // Store in database
        $this->storeAlert($alert);
    }

    /**
     * Send notifications for an alert
     */
    private function sendNotifications(array $alert): void
    {
        foreach ($this->notificationChannels as $channel => $config) {
            if ($config['enabled'] && $this->shouldSendNotification($alert, $channel)) {
                $this->sendNotification($alert, $channel);
            }
        }
    }

    /**
     * Check if notification should be sent
     */
    private function shouldSendNotification(array $alert, string $channel): bool
    {
        $severity = $alert['severity'];
        $channelConfig = $this->notificationChannels[$channel];
        
        // Check severity threshold
        $severityLevels = ['info' => 1, 'warning' => 2, 'critical' => 3];
        $alertLevel = $severityLevels[$severity] ?? 1;
        $channelLevel = $severityLevels[$channelConfig['min_severity']] ?? 1;
        
        return $alertLevel >= $channelLevel;
    }

    /**
     * Send notification via specific channel
     */
    private function sendNotification(array $alert, string $channel): void
    {
        $notification = [
            'channel' => $channel,
            'alert_id' => $alert['id'],
            'severity' => $alert['severity'],
            'message' => $alert['message'],
            'timestamp' => time(),
            'user_id' => $alert['user_id'] ?? null,
            'project_id' => $alert['project_id'] ?? null
        ];
        
        switch ($channel) {
            case 'email':
                $this->sendEmailNotification($notification);
                break;
            case 'slack':
                $this->sendSlackNotification($notification);
                break;
            case 'webhook':
                $this->sendWebhookNotification($notification);
                break;
            case 'sms':
                $this->sendSMSNotification($notification);
                break;
        }
        
        $this->logNotification($notification);
    }

    /**
     * Initialize alert thresholds
     */
    private function initializeAlertThresholds(): void
    {
        $this->alertThresholds = [
            'cost_spike' => 0.2, // 20% increase
            'usage_limit' => 0.9, // 90% of limit
            'api_response_time' => 100, // 100ms
            'uptime' => 99.9, // 99.9%
            'error_rate' => 0.01, // 1%
            'performance_degradation' => 0.1 // 10% degradation
        ];
    }

    /**
     * Initialize notification channels
     */
    private function initializeNotificationChannels(): void
    {
        $this->notificationChannels = [
            'email' => [
                'enabled' => true,
                'min_severity' => 'warning',
                'recipients' => ['admin@grimreaper.com', 'ops@grimreaper.com']
            ],
            'slack' => [
                'enabled' => true,
                'min_severity' => 'warning',
                'webhook_url' => 'https://hooks.slack.com/services/xxx/yyy/zzz'
            ],
            'webhook' => [
                'enabled' => true,
                'min_severity' => 'critical',
                'url' => 'https://api.grimreaper.com/webhooks/alerts'
            ],
            'sms' => [
                'enabled' => true,
                'min_severity' => 'critical',
                'phone_numbers' => ['+1234567890']
            ]
        ];
    }

    // Mock implementations for monitoring methods
    private function getCurrentCost(int $userId = null, ?int $projectId = null): float { return 25.50; }
    private function getHistoricalCosts(int $userId = null, ?int $projectId = null, int $days = 30): array { return array_fill(0, $days, 20.0); }
    private function getTierBreakdown(int $userId = null, ?int $projectId = null): array { return ['free' => ['usage_percentage' => 85], 'pro' => ['usage_percentage' => 60]]; }
    private function getCurrentResponseTime(): float { return 75.0; }
    private function getCurrentUptime(): float { return 99.95; }
    private function getCurrentErrorRate(): float { return 0.005; }
    private function getSLAMetrics(): array { 
        return [
            'uptime' => ['current' => 99.95, 'target' => 99.9, 'type' => 'minimum'],
            'response_time' => ['current' => 75, 'target' => 100, 'type' => 'maximum'],
            'error_rate' => ['current' => 0.005, 'target' => 0.01, 'type' => 'maximum']
        ];
    }

    // Notification methods
    private function sendEmailNotification(array $notification): void { file_put_contents('logs/email_notifications.log', json_encode($notification) . "\n", FILE_APPEND); }
    private function sendSlackNotification(array $notification): void { file_put_contents('logs/slack_notifications.log', json_encode($notification) . "\n", FILE_APPEND); }
    private function sendWebhookNotification(array $notification): void { file_put_contents('logs/webhook_notifications.log', json_encode($notification) . "\n", FILE_APPEND); }
    private function sendSMSNotification(array $notification): void { file_put_contents('logs/sms_notifications.log', json_encode($notification) . "\n", FILE_APPEND); }

    // Logging methods
    private function logAlert(array $alert): void { file_put_contents('logs/alerts.log', json_encode($alert) . "\n", FILE_APPEND); }
    private function logNotification(array $notification): void { file_put_contents('logs/notifications.log', json_encode($notification) . "\n", FILE_APPEND); }
    private function logAlertAcknowledgment(array $alert): void { file_put_contents('logs/alert_acknowledgments.log', json_encode($alert) . "\n", FILE_APPEND); }
    private function logAlertResolution(array $alert): void { file_put_contents('logs/alert_resolutions.log', json_encode($alert) . "\n", FILE_APPEND); }
    private function storeAlert(array $alert): void { file_put_contents('logs/stored_alerts.log', json_encode($alert) . "\n", FILE_APPEND); }
} 