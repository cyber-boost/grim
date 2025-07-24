#!/bin/bash
# Grim Reaper Quick Installer

set -euo pipefail

INSTALL_DIR="/opt/reaper"

echo "=�  Installing Grim Reaper..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying files..."
cp -r ./* "$INSTALL_DIR/"

# Make scripts executable
find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;
find "$INSTALL_DIR" -name "*.py" -exec chmod +x {} \;

# Run full installation
echo "Running full installation..."
cd "$INSTALL_DIR"
./scripts/install.sh

echo " Installation complete!"
echo "Run 'grim health' to verify installation"
