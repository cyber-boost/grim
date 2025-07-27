<?php

namespace GrimReaper\Monitoring;

use GrimReaper\Analytics\CostAnalyzer;
use GrimReaper\Analytics\UsageAnalyzer;

/**
 * Distributed Monitoring Hub
 * Collects and aggregates monitoring data from multiple CLI user installations
 * across separate servers
 */
class DistributedMonitoringHub
{
    private array $remoteServers;
    private array $serverConfigs;
    private array $aggregatedData;
    private CostAnalyzer $costAnalyzer;
    private UsageAnalyzer $usageAnalyzer;

    public function __construct()
    {
        $this->costAnalyzer = new CostAnalyzer();
        $this->usageAnalyzer = new UsageAnalyzer();
        $this->loadServerConfigurations();
        $this->aggregatedData = [];
    }

    /**
     * Load server configurations from config file
     */
    private function loadServerConfigurations(): void
    {
        $configFile = __DIR__ . '/../../../config/distributed_monitoring.yaml';
        
        if (file_exists($configFile)) {
            $config = yaml_parse_file($configFile);
            $this->serverConfigs = $config['servers'] ?? [];
        } else {
            // Default configuration
            $this->serverConfigs = [
                'server1' => [
                    'name' => 'Production Server 1',
                    'url' => 'http://server1.example.com:8082',
                    'api_key' => 'your_api_key_here',
                    'enabled' => true,
                    'location' => 'US-East',
                    'type' => 'production'
                ],
                'server2' => [
                    'name' => 'Development Server',
                    'url' => 'http://server2.example.com:8082',
                    'api_key' => 'your_api_key_here',
                    'enabled' => true,
                    'location' => 'US-West',
                    'type' => 'development'
                ]
            ];
            
            // Create default config file
            $this->createDefaultConfig($configFile);
        }
    }

    /**
     * Create default configuration file
     */
    private function createDefaultConfig(string $configFile): void
    {
        $config = [
            'servers' => $this->serverConfigs,
            'polling_interval' => 60, // seconds
            'timeout' => 30, // seconds
            'retry_attempts' => 3,
            'alert_channels' => [
                'email' => true,
                'slack' => true,
                'webhook' => true
            ]
        ];
        
        yaml_emit_file($configFile, $config);
    }

    /**
     * Collect monitoring data from all remote servers
     */
    public function collectFromAllServers(): array
    {
        $this->aggregatedData = [
            'servers' => [],
            'summary' => [],
            'alerts' => [],
            'performance' => [],
            'costs' => [],
            'last_updated' => time()
        ];

        foreach ($this->serverConfigs as $serverId => $config) {
            if (!$config['enabled']) {
                continue;
            }

            try {
                $serverData = $this->collectFromServer($serverId, $config);
                $this->aggregatedData['servers'][$serverId] = $serverData;
            } catch (\Exception $e) {
                $this->aggregatedData['servers'][$serverId] = [
                    'status' => 'error',
                    'error' => $e->getMessage(),
                    'last_check' => time()
                ];
            }
        }

        // Aggregate summary data
        $this->aggregateSummaryData();
        
        return $this->aggregatedData;
    }

    /**
     * Collect data from a specific server
     */
    private function collectFromServer(string $serverId, array $config): array
    {
        $baseUrl = $config['url'];
        $apiKey = $config['api_key'];
        
        $endpoints = [
            'dashboard' => '/monitoring.php?action=dashboard',
            'performance' => '/monitoring.php?action=performance',
            'alerts' => '/monitoring.php?action=alerts',
            'sla' => '/monitoring.php?action=sla',
            'health' => '/monitoring.php?action=health'
        ];

        $serverData = [
            'server_id' => $serverId,
            'name' => $config['name'],
            'location' => $config['location'],
            'type' => $config['type'],
            'status' => 'online',
            'last_check' => time(),
            'data' => []
        ];

        foreach ($endpoints as $endpoint => $path) {
            try {
                $response = $this->makeApiRequest($baseUrl . $path, $apiKey);
                $serverData['data'][$endpoint] = $response;
            } catch (\Exception $e) {
                $serverData['data'][$endpoint] = [
                    'error' => $e->getMessage(),
                    'status' => 'failed'
                ];
            }
        }

        return $serverData;
    }

    /**
     * Make API request to remote server
     */
    private function makeApiRequest(string $url, string $apiKey): array
    {
        $ch = curl_init();
        
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $apiKey,
                'Content-Type: application/json',
                'User-Agent: GrimReaper-Monitoring-Hub/1.0'
            ],
            CURLOPT_SSL_VERIFYPEER => false, // For development
            CURLOPT_SSL_VERIFYHOST => false  // For development
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        
        curl_close($ch);

        if ($error) {
            throw new \Exception("cURL error: $error");
        }

        if ($httpCode !== 200) {
            throw new \Exception("HTTP error: $httpCode");
        }

        $data = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new \Exception("JSON decode error: " . json_last_error_msg());
        }

        return $data;
    }

    /**
     * Aggregate summary data from all servers
     */
    private function aggregateSummaryData(): void
    {
        $totalStorage = 0;
        $totalCost = 0;
        $totalAlerts = 0;
        $onlineServers = 0;
        $totalUsers = 0;
        $performanceScores = [];

        foreach ($this->aggregatedData['servers'] as $serverId => $serverData) {
            if ($serverData['status'] === 'online') {
                $onlineServers++;
                
                $dashboardData = $serverData['data']['dashboard']['data'] ?? [];
                $performanceData = $serverData['data']['performance']['data'] ?? [];
                $alertsData = $serverData['data']['alerts']['data'] ?? [];

                // Aggregate storage
                $totalStorage += $dashboardData['total_storage'] ?? 0;
                $totalCost += $dashboardData['total_cost'] ?? 0;
                $totalAlerts += count($alertsData);
                $totalUsers += $dashboardData['total_users'] ?? 0;

                // Collect performance scores
                if (isset($performanceData['performance_score'])) {
                    $performanceScores[] = $performanceData['performance_score'];
                }
            }
        }

        $this->aggregatedData['summary'] = [
            'total_servers' => count($this->serverConfigs),
            'online_servers' => $onlineServers,
            'offline_servers' => count($this->serverConfigs) - $onlineServers,
            'total_storage' => $totalStorage,
            'total_cost' => $totalCost,
            'total_alerts' => $totalAlerts,
            'total_users' => $totalUsers,
            'average_performance_score' => !empty($performanceScores) ? array_sum($performanceScores) / count($performanceScores) : 0,
            'uptime_percentage' => $onlineServers > 0 ? ($onlineServers / count($this->serverConfigs)) * 100 : 0
        ];

        // Aggregate alerts
        $this->aggregateAlerts();
        
        // Aggregate performance metrics
        $this->aggregatePerformanceMetrics();
        
        // Aggregate cost data
        $this->aggregateCostData();
    }

    /**
     * Aggregate alerts from all servers
     */
    private function aggregateAlerts(): void
    {
        $allAlerts = [];
        $alertStats = [
            'total' => 0,
            'critical' => 0,
            'warning' => 0,
            'by_type' => [],
            'by_server' => []
        ];

        foreach ($this->aggregatedData['servers'] as $serverId => $serverData) {
            if ($serverData['status'] === 'online') {
                $alerts = $serverData['data']['alerts']['data'] ?? [];
                
                foreach ($alerts as $alert) {
                    $alert['server_id'] = $serverId;
                    $alert['server_name'] = $serverData['name'];
                    $allAlerts[] = $alert;

                    // Count by severity
                    $severity = $alert['severity'] ?? 'info';
                    if ($severity === 'critical') {
                        $alertStats['critical']++;
                    } elseif ($severity === 'warning') {
                        $alertStats['warning']++;
                    }

                    // Count by type
                    $type = $alert['type'] ?? 'unknown';
                    $alertStats['by_type'][$type] = ($alertStats['by_type'][$type] ?? 0) + 1;

                    // Count by server
                    $alertStats['by_server'][$serverId] = ($alertStats['by_server'][$serverId] ?? 0) + 1;
                }
            }
        }

        $alertStats['total'] = count($allAlerts);

        $this->aggregatedData['alerts'] = [
            'all_alerts' => $allAlerts,
            'stats' => $alertStats,
            'critical_alerts' => array_filter($allAlerts, fn($a) => ($a['severity'] ?? '') === 'critical'),
            'recent_alerts' => array_slice($allAlerts, 0, 10) // Last 10 alerts
        ];
    }

    /**
     * Aggregate performance metrics from all servers
     */
    private function aggregatePerformanceMetrics(): void
    {
        $performanceMetrics = [
            'average_response_time' => 0,
            'average_uptime' => 0,
            'average_error_rate' => 0,
            'total_requests' => 0,
            'server_performance' => []
        ];

        $responseTimes = [];
        $uptimes = [];
        $errorRates = [];
        $totalRequests = 0;

        foreach ($this->aggregatedData['servers'] as $serverId => $serverData) {
            if ($serverData['status'] === 'online') {
                $perfData = $serverData['data']['performance']['data'] ?? [];
                $apiPerf = $perfData['api_performance'] ?? [];

                if (isset($apiPerf['average_response_time'])) {
                    $responseTimes[] = $apiPerf['average_response_time'];
                }
                if (isset($apiPerf['uptime_percentage'])) {
                    $uptimes[] = $apiPerf['uptime_percentage'];
                }
                if (isset($apiPerf['error_rate'])) {
                    $errorRates[] = $apiPerf['error_rate'];
                }
                if (isset($apiPerf['requests_per_second'])) {
                    $totalRequests += $apiPerf['requests_per_second'];
                }

                $performanceMetrics['server_performance'][$serverId] = [
                    'name' => $serverData['name'],
                    'response_time' => $apiPerf['average_response_time'] ?? 0,
                    'uptime' => $apiPerf['uptime_percentage'] ?? 0,
                    'error_rate' => $apiPerf['error_rate'] ?? 0,
                    'requests_per_second' => $apiPerf['requests_per_second'] ?? 0
                ];
            }
        }

        // Calculate averages
        if (!empty($responseTimes)) {
            $performanceMetrics['average_response_time'] = array_sum($responseTimes) / count($responseTimes);
        }
        if (!empty($uptimes)) {
            $performanceMetrics['average_uptime'] = array_sum($uptimes) / count($uptimes);
        }
        if (!empty($errorRates)) {
            $performanceMetrics['average_error_rate'] = array_sum($errorRates) / count($errorRates);
        }

        $performanceMetrics['total_requests'] = $totalRequests;

        $this->aggregatedData['performance'] = $performanceMetrics;
    }

    /**
     * Aggregate cost data from all servers
     */
    private function aggregateCostData(): void
    {
        $costData = [
            'total_monthly_cost' => 0,
            'cost_by_server' => [],
            'cost_by_location' => [],
            'cost_by_type' => [],
            'optimization_opportunities' => []
        ];

        foreach ($this->aggregatedData['servers'] as $serverId => $serverData) {
            if ($serverData['status'] === 'online') {
                $dashboardData = $serverData['data']['dashboard']['data'] ?? [];
                $cost = $dashboardData['total_cost'] ?? 0;
                $location = $serverData['location'];
                $type = $serverData['type'];

                $costData['total_monthly_cost'] += $cost;
                $costData['cost_by_server'][$serverId] = $cost;
                $costData['cost_by_location'][$location] = ($costData['cost_by_location'][$location] ?? 0) + $cost;
                $costData['cost_by_type'][$type] = ($costData['cost_by_type'][$type] ?? 0) + $cost;
            }
        }

        $this->aggregatedData['costs'] = $costData;
    }

    /**
     * Get server status overview
     */
    public function getServerStatus(): array
    {
        $status = [
            'total_servers' => count($this->serverConfigs),
            'online_servers' => 0,
            'offline_servers' => 0,
            'servers' => []
        ];

        foreach ($this->aggregatedData['servers'] as $serverId => $serverData) {
            $status['servers'][$serverId] = [
                'name' => $serverData['name'],
                'status' => $serverData['status'],
                'last_check' => $serverData['last_check'],
                'location' => $serverData['location'],
                'type' => $serverData['type']
            ];

            if ($serverData['status'] === 'online') {
                $status['online_servers']++;
            } else {
                $status['offline_servers']++;
            }
        }

        return $status;
    }

    /**
     * Get alerts summary
     */
    public function getAlertsSummary(): array
    {
        return $this->aggregatedData['alerts']['stats'] ?? [];
    }

    /**
     * Get performance summary
     */
    public function getPerformanceSummary(): array
    {
        return $this->aggregatedData['performance'] ?? [];
    }

    /**
     * Get cost summary
     */
    public function getCostSummary(): array
    {
        return $this->aggregatedData['costs'] ?? [];
    }

    /**
     * Get overall summary
     */
    public function getOverallSummary(): array
    {
        return $this->aggregatedData['summary'] ?? [];
    }

    /**
     * Add a new server to monitor
     */
    public function addServer(string $serverId, array $config): bool
    {
        $this->serverConfigs[$serverId] = $config;
        return $this->saveServerConfigurations();
    }

    /**
     * Remove a server from monitoring
     */
    public function removeServer(string $serverId): bool
    {
        if (isset($this->serverConfigs[$serverId])) {
            unset($this->serverConfigs[$serverId]);
            return $this->saveServerConfigurations();
        }
        return false;
    }

    /**
     * Save server configurations to file
     */
    private function saveServerConfigurations(): bool
    {
        $configFile = __DIR__ . '/../../../config/distributed_monitoring.yaml';
        $config = [
            'servers' => $this->serverConfigs,
            'polling_interval' => 60,
            'timeout' => 30,
            'retry_attempts' => 3,
            'alert_channels' => [
                'email' => true,
                'slack' => true,
                'webhook' => true
            ]
        ];
        
        return yaml_emit_file($configFile, $config) !== false;
    }
} 