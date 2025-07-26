<?php
/**
 * Web Entry Point for Grim Reaper Monitoring & Analytics
 * Access via: http://your-domain/monitoring.php
 */

require_once __DIR__ . '/../vendor/autoload.php';

use GrimReaper\Monitoring\StorageAnalyticsDashboard;
use GrimReaper\Monitoring\RealTimeAlertingSystem;
use GrimReaper\Monitoring\PerformanceMonitor;
use GrimReaper\Monitoring\SLAMonitor;

// Set content type for JSON responses
header('Content-Type: application/json');

// Get the requested action
$action = $_GET['action'] ?? 'dashboard';

try {
    switch ($action) {
        case 'dashboard':
            $dashboard = new StorageAnalyticsDashboard();
            $data = $dashboard->getOverviewMetrics();
            echo json_encode(['success' => true, 'data' => $data]);
            break;
            
        case 'alerts':
            $alertingSystem = new RealTimeAlertingSystem();
            $alerts = $alertingSystem->getActiveAlerts();
            echo json_encode(['success' => true, 'data' => $alerts]);
            break;
            
        case 'performance':
            $performanceMonitor = new PerformanceMonitor();
            $metrics = $performanceMonitor->monitorPerformance();
            echo json_encode(['success' => true, 'data' => $metrics]);
            break;
            
        case 'sla':
            $slaMonitor = new SLAMonitor();
            $slaReport = $slaMonitor->monitorSLACompliance();
            echo json_encode(['success' => true, 'data' => $slaReport]);
            break;
            
        case 'health':
            // Quick health check
            $health = [
                'status' => 'healthy',
                'timestamp' => time(),
                'version' => '1.0.0',
                'services' => [
                    'monitoring' => 'active',
                    'analytics' => 'active',
                    'alerting' => 'active'
                ]
            ];
            echo json_encode(['success' => true, 'data' => $health]);
            break;
            
        default:
            echo json_encode(['success' => false, 'error' => 'Invalid action']);
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
} 