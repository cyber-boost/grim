#!/bin/bash

# Grim Reaper Monitoring Integration Script
# This script integrates the PHP monitoring systems with the existing Grim infrastructure

set -e

echo "🔗 Integrating Grim Reaper Monitoring Systems..."

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

print_status "Starting monitoring integration..."

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
mkdir -p public
print_success "Directories created"

# Step 3: Set proper permissions
print_status "Setting permissions..."
chmod +x bin/monitoring-daemon.php
chmod 755 logs
chmod 755 data
print_success "Permissions set"

# Step 4: Test PHP installation
print_status "Testing PHP installation..."
if php -r "echo 'PHP version: ' . PHP_VERSION . PHP_EOL;" 2>/dev/null; then
    print_success "PHP is working correctly"
else
    print_error "PHP is not working correctly"
    exit 1
fi

# Step 5: Test monitoring systems
print_status "Testing monitoring systems..."
if php -r "
require_once 'vendor/autoload.php';
use GrimReaper\Monitoring\StorageAnalyticsDashboard;
\$dashboard = new StorageAnalyticsDashboard();
echo 'Monitoring systems loaded successfully' . PHP_EOL;
" 2>/dev/null; then
    print_success "Monitoring systems are working"
else
    print_error "Failed to load monitoring systems"
    exit 1
fi

# Step 6: Create systemd service (if running on Linux with systemd)
if command -v systemctl &> /dev/null; then
    print_status "Creating systemd service for monitoring daemon..."
    
    cat > /etc/systemd/system/grim-monitoring.service << EOF
[Unit]
Description=Grim Reaper Monitoring Daemon
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/php $(pwd)/bin/monitoring-daemon.php
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable grim-monitoring.service
    print_success "Systemd service created and enabled"
    print_status "To start the service: sudo systemctl start grim-monitoring"
    print_status "To check status: sudo systemctl status grim-monitoring"
fi

# Step 7: Update config.yaml to include monitoring settings
print_status "Updating configuration..."
if [ -f "config.yaml" ]; then
    # Backup original config
    cp config.yaml config.yaml.backup
    
    # Add monitoring configuration if not present
    if ! grep -q "monitoring:" config.yaml; then
        cat >> config.yaml << EOF

# PHP Monitoring & Analytics Configuration
monitoring:
  php:
    enabled: true
    web_port: 8082
    daemon_enabled: true
    log_level: INFO
    alert_channels:
      email: true
      slack: true
      webhook: true
      sms: false
EOF
        print_success "Configuration updated"
    else
        print_warning "Monitoring configuration already exists in config.yaml"
    fi
else
    print_warning "config.yaml not found, skipping configuration update"
fi

# Step 8: Create web server configuration
print_status "Creating web server configuration..."

# Apache configuration
if command -v apache2 &> /dev/null; then
    cat > /etc/apache2/sites-available/grim-monitoring.conf << EOF
<VirtualHost *:8082>
    ServerName grim-monitoring.local
    DocumentRoot $(pwd)/public
    
    <Directory $(pwd)/public>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/grim-monitoring-error.log
    CustomLog \${APACHE_LOG_DIR}/grim-monitoring-access.log combined
</VirtualHost>
EOF

    a2ensite grim-monitoring.conf
    systemctl reload apache2
    print_success "Apache configuration created"
fi

# Nginx configuration
if command -v nginx &> /dev/null; then
    cat > /etc/nginx/sites-available/grim-monitoring << EOF
server {
    listen 8082;
    server_name grim-monitoring.local;
    root $(pwd)/public;
    index monitoring.php;
    
    location / {
        try_files \$uri \$uri/ /monitoring.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/grim-monitoring /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    print_success "Nginx configuration created"
fi

# Step 9: Test web access
print_status "Testing web access..."
if curl -s http://localhost:8082/monitoring.php?action=health > /dev/null; then
    print_success "Web monitoring interface is accessible"
else
    print_warning "Web monitoring interface may not be accessible yet"
fi

# Step 10: Create integration with existing Grim CLI
print_status "Integrating with existing Grim CLI..."

# Add monitoring commands to grim CLI
if [ -f "grim_reaper.go" ]; then
    print_status "Adding monitoring commands to Grim CLI..."
    # This would require modifying the Go code to add monitoring endpoints
    print_warning "Manual integration with grim_reaper.go required"
fi

print_success "🎉 Grim Reaper Monitoring Integration Complete!"

echo ""
echo "📋 Next Steps:"
echo "1. Start the monitoring daemon:"
echo "   sudo systemctl start grim-monitoring"
echo ""
echo "2. Access the web interface:"
echo "   http://localhost:8082/monitoring.php"
echo ""
echo "3. Test the monitoring systems:"
echo "   php tests/MonitoringAnalyticsTest.php"
echo ""
echo "4. Check monitoring logs:"
echo "   tail -f logs/monitoring.log"
echo ""
echo "5. Configure alerting channels in config.yaml"
echo ""
echo "🔗 The PHP monitoring systems are now integrated with your Grim Reaper infrastructure!" 