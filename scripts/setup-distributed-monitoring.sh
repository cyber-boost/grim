#!/bin/bash

# Grim Reaper Distributed Monitoring Setup Script
# This script sets up distributed monitoring for multiple CLI user installations

set -e

echo "🌐 Setting up Grim Reaper Distributed Monitoring..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "composer.json" ]; then
    print_error "composer.json not found. Please run this script from the Grim Reaper root directory."
    exit 1
fi

print_status "Starting distributed monitoring setup..."

# Step 1: Install PHP dependencies
print_status "Installing PHP dependencies..."
if command -v composer &> /dev/null; then
    composer install --no-dev --optimize-autoloader
    print_success "PHP dependencies installed"
else
    print_error "Composer not found. Please install Composer first."
    exit 1
fi

# Step 2: Create required directories
print_status "Creating required directories..."
mkdir -p logs
mkdir -p data/monitoring
mkdir -p data/analytics
mkdir -p data/alerts
mkdir -p config
mkdir -p public
print_success "Directories created"

# Step 3: Set proper permissions
print_status "Setting permissions..."
chmod +x bin/monitoring-daemon.php
chmod +x bin/distributed-monitoring-daemon.php
chmod 755 logs
chmod 755 data
print_success "Permissions set"

# Step 4: Create distributed monitoring configuration
print_status "Creating distributed monitoring configuration..."
if [ ! -f "config/distributed_monitoring.yaml" ]; then
    print_warning "config/distributed_monitoring.yaml not found. Creating default configuration..."
    # The config file should already exist from our previous creation
fi

# Step 5: Test distributed monitoring systems
print_status "Testing distributed monitoring systems..."
if php -r "
require_once 'vendor/autoload.php';
use GrimReaper\Monitoring\DistributedMonitoringHub;
\$hub = new DistributedMonitoringHub();
echo 'Distributed monitoring systems loaded successfully' . PHP_EOL;
" 2>/dev/null; then
    print_success "Distributed monitoring systems are working"
else
    print_error "Failed to load distributed monitoring systems"
    exit 1
fi

# Step 6: Create systemd service for distributed monitoring daemon
if command -v systemctl &> /dev/null; then
    print_status "Creating systemd service for distributed monitoring daemon..."

    cat > /etc/systemd/system/grim-distributed-monitoring.service << EOF
[Unit]
Description=Grim Reaper Distributed Monitoring Daemon
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/php $(pwd)/bin/distributed-monitoring-daemon.php
Restart=always
RestartSec=10
Environment=PHP_MEMORY_LIMIT=512M

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable grim-distributed-monitoring.service
    print_success "Systemd service created and enabled"
    print_status "To start the service: sudo systemctl start grim-distributed-monitoring"
    print_status "To check status: sudo systemctl status grim-distributed-monitoring"
fi

# Step 7: Create API key generation script
print_status "Creating API key generation script..."

cat > bin/generate-api-key.php << 'EOF'
#!/usr/bin/env php
<?php
/**
 * Generate API key for distributed monitoring
 * Usage: php bin/generate-api-key.php [server_name]
 */

if ($argc < 2) {
    echo "Usage: php bin/generate-api-key.php <server_name>\n";
    echo "Example: php bin/generate-api-key.php client-a-server\n";
    exit(1);
}

$serverName = $argv[1];
$apiKey = bin2hex(random_bytes(32));

echo "Generated API key for server: {$serverName}\n";
echo "API Key: {$apiKey}\n";
echo "\n";
echo "Add this to your config/distributed_monitoring.yaml:\n";
echo "  {$serverName}:\n";
echo "    name: \"{$serverName}\"\n";
echo "    url: \"http://your-server-ip:8082\"\n";
echo "    api_key: \"{$apiKey}\"\n";
echo "    enabled: true\n";
echo "    location: \"Your-Location\"\n";
echo "    type: \"client\"\n";
EOF

chmod +x bin/generate-api-key.php
print_success "API key generation script created"

# Step 8: Create server registration script
print_status "Creating server registration script..."

cat > bin/register-server.php << 'EOF'
#!/usr/bin/env php
<?php
/**
 * Register a new server for distributed monitoring
 * Usage: php bin/register-server.php <server_id> <server_name> <server_url> <location> <type>
 */

require_once __DIR__ . '/../vendor/autoload.php';

use GrimReaper\Monitoring\DistributedMonitoringHub;

if ($argc < 6) {
    echo "Usage: php bin/register-server.php <server_id> <server_name> <server_url> <location> <type>\n";
    echo "Example: php bin/register-server.php client3 \"Client C Server\" \"http://client-c.example.com:8082\" \"EU-East\" \"client\"\n";
    exit(1);
}

$serverId = $argv[1];
$serverName = $argv[2];
$serverUrl = $argv[3];
$location = $argv[4];
$type = $argv[5];

// Generate API key
$apiKey = bin2hex(random_bytes(32));

$config = [
    'name' => $serverName,
    'url' => $serverUrl,
    'api_key' => $apiKey,
    'enabled' => true,
    'location' => $location,
    'type' => $type,
    'description' => "Automatically registered server"
];

try {
    $hub = new DistributedMonitoringHub();
    $success = $hub->addServer($serverId, $config);
    
    if ($success) {
        echo "✅ Server registered successfully!\n";
        echo "Server ID: {$serverId}\n";
        echo "Server Name: {$serverName}\n";
        echo "API Key: {$apiKey}\n";
        echo "\n";
        echo "Next steps:\n";
        echo "1. Install Grim Reaper on the target server\n";
        echo "2. Run: ./scripts/integrate-monitoring.sh on the target server\n";
        echo "3. Configure the API key on the target server\n";
        echo "4. Start the monitoring daemon on the target server\n";
    } else {
        echo "❌ Failed to register server\n";
        exit(1);
    }
} catch (Exception $e) {
    echo "❌ Error registering server: " . $e->getMessage() . "\n";
    exit(1);
}
EOF

chmod +x bin/register-server.php
print_success "Server registration script created"

# Step 9: Create monitoring dashboard
print_status "Creating distributed monitoring dashboard..."

cat > public/distributed-monitoring.php << 'EOF'
<?php
/**
 * Distributed Monitoring Dashboard
 * Access via: http://your-domain/distributed-monitoring.php
 */

require_once __DIR__ . '/../vendor/autoload.php';

use GrimReaper\Monitoring\DistributedMonitoringHub;

// Set content type for JSON responses
header('Content-Type: application/json');

// Get the requested action
$action = $_GET['action'] ?? 'dashboard';

try {
    $hub = new DistributedMonitoringHub();
    
    switch ($action) {
        case 'dashboard':
            $data = $hub->collectFromAllServers();
            echo json_encode(['success' => true, 'data' => $data]);
            break;

        case 'servers':
            $status = $hub->getServerStatus();
            echo json_encode(['success' => true, 'data' => $status]);
            break;

        case 'alerts':
            $alerts = $hub->getAlertsSummary();
            echo json_encode(['success' => true, 'data' => $alerts]);
            break;

        case 'performance':
            $performance = $hub->getPerformanceSummary();
            echo json_encode(['success' => true, 'data' => $performance]);
            break;

        case 'costs':
            $costs = $hub->getCostSummary();
            echo json_encode(['success' => true, 'data' => $costs]);
            break;

        case 'summary':
            $summary = $hub->getOverallSummary();
            echo json_encode(['success' => true, 'data' => $summary]);
            break;

        default:
            echo json_encode(['success' => false, 'error' => 'Invalid action']);
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
EOF

print_success "Distributed monitoring dashboard created"

# Step 10: Update main config.yaml
print_status "Updating main configuration..."
if [ -f "config.yaml" ]; then
    # Backup original config
    cp config.yaml config.yaml.backup

    # Add distributed monitoring configuration if not present
    if ! grep -q "distributed_monitoring:" config.yaml; then
        cat >> config.yaml << EOF

# Distributed Monitoring Configuration
distributed_monitoring:
  enabled: true
  config_file: "config/distributed_monitoring.yaml"
  polling_interval: 60
  dashboard_url: "/distributed-monitoring.php"
EOF
        print_success "Configuration updated"
    else
        print_warning "Distributed monitoring configuration already exists in config.yaml"
    fi
else
    print_warning "config.yaml not found, skipping configuration update"
fi

print_success "🎉 Grim Reaper Distributed Monitoring Setup Complete!"

echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Configure your servers in config/distributed_monitoring.yaml:"
echo "   - Update server URLs to point to your actual servers"
echo "   - Generate API keys for each server"
echo ""
echo "2. Generate API keys for your servers:"
echo "   php bin/generate-api-key.php server-name"
echo ""
echo "3. Register new servers:"
echo "   php bin/register-server.php server-id \"Server Name\" \"http://server-url:8082\" \"Location\" \"type\""
echo ""
echo "4. Start the distributed monitoring daemon:"
echo "   sudo systemctl start grim-distributed-monitoring"
echo ""
echo "5. Access the distributed monitoring dashboard:"
echo "   http://your-domain/distributed-monitoring.php"
echo ""
echo "6. Monitor the logs:"
echo "   tail -f logs/distributed_monitoring.log"
echo ""
echo "🌐 Your admin server can now monitor multiple CLI user installations across separate servers!" 