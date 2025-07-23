#!/bin/bash
# 🗡️ GRIM Post-Install Script
# Runs after npm install to set up the Grim system

set -e

echo "🗡️  Setting up Grim system..."

# Track installation start (graceful - don't fail if error tracker fails)
if [[ -f "scripts/error-tracker.sh" ]]; then
    chmod +x scripts/error-tracker.sh
    ./scripts/error-tracker.sh install npm true "NPM installation started" || true
fi

# Create necessary directories
sudo mkdir -p /opt/grim-reaper
sudo mkdir -p /etc/grim-reaper
sudo mkdir -p /var/log/grim
sudo mkdir -p /backups

# Set permissions
sudo chown -R root:root /opt/grim-reaper
sudo chown -R root:root /etc/grim-reaper
sudo chmod -R 755 /opt/grim-reaper
sudo chmod -R 644 /etc/grim-reaper

# Create log directory with proper permissions
sudo chown -R root:root /var/log/grim
sudo chmod -R 755 /var/log/grim

# Create backup directory
sudo chown -R root:root /backups
sudo chmod -R 755 /backups

# Copy configuration files if they exist
if [ -d "config" ]; then
    sudo cp -r config/* /etc/grim-reaper/ 2>/dev/null || true
fi

# Copy components to installation directory
if [ -d "sh_grim" ]; then
    sudo cp -r sh_grim /opt/grim-reaper/
fi

if [ -d "py_grim" ]; then
    sudo cp -r py_grim /opt/grim-reaper/
fi

if [ -d "go_grim" ]; then
    sudo cp -r go_grim /opt/grim-reaper/
fi

if [ -d "scythe" ]; then
    sudo cp -r scythe /opt/grim-reaper/
fi

if [ -d "ascii" ]; then
    sudo cp -r ascii /opt/grim-reaper/
fi

# Set executable permissions
sudo find /opt/grim-reaper -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
sudo find /opt/grim-reaper -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

# Ensure grim_throne.sh is executable
sudo chmod +x grim_throne.sh

# Create binary symlink if npm didn't create it
if [ ! -L "/usr/bin/grim" ] && [ ! -f "/usr/bin/grim" ]; then
    echo "🔗 Creating grim binary symlink..."
    sudo ln -sf "$(pwd)/grim_throne.sh" /usr/bin/grim
    echo "✅ Binary symlink created: /usr/bin/grim"
fi

echo "✅ Grim system setup complete!"
echo "📁 Installation directory: /opt/grim-reaper"
echo "📁 Configuration directory: /etc/grim-reaper"
echo "📁 Log directory: /var/log/grim"
echo "📁 Backup directory: /backups"
echo ""
echo "🔍 Checking dependencies..."
echo ""

# Run dependency check
if [[ -f "scripts/dependency-manager.sh" ]]; then
    chmod +x scripts/dependency-manager.sh
    ./scripts/dependency-manager.sh
    
    # Track successful installation
    if [[ -f "scripts/error-tracker.sh" ]]; then
        ./scripts/error-tracker.sh install npm true "NPM installation completed successfully"
    fi
else
    echo "⚠️  Dependency manager not found. Please ensure Python 3 and Go are installed."
    
    # Track installation failure
    if [[ -f "scripts/error-tracker.sh" ]]; then
        ./scripts/error-tracker.sh error installation_failed "Dependency manager script not found" "scripts/dependency-manager.sh missing" high
    fi
fi

echo ""
echo "🚀 You can now use: grim --help"
