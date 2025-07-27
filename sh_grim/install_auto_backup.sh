#!/bin/bash

# Grim Auto Backup Installation Script
# Installs and configures the automatic backup system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/grim-auto-backup.service"
SYSTEMD_DIR="/etc/systemd/system"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Grim Auto Backup Installation ===${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"

if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y inotify-tools build-essential
elif command -v yum >/dev/null 2>&1; then
    yum install -y inotify-tools gcc make
else
    echo -e "${RED}Unsupported package manager. Please install inotify-tools manually.${NC}"
    exit 1
fi

# Build Go compression engine
echo -e "${YELLOW}Building Go compression engine...${NC}"
cd "$SCRIPT_DIR/../go_grim"
if [[ -f Makefile ]]; then
    make build
    echo -e "${GREEN}Go compression engine built successfully${NC}"
else
    echo -e "${RED}Makefile not found in go_grim directory${NC}"
    exit 1
fi

# Create graveyard directory
echo -e "${YELLOW}Creating graveyard directory...${NC}"
mkdir -p /root/.graveyard/auto_backups
chmod 755 /root/.graveyard

# Install systemd service
echo -e "${YELLOW}Installing systemd service...${NC}"
cp "$SERVICE_FILE" "$SYSTEMD_DIR/"
systemctl daemon-reload
systemctl enable grim-auto-backup.service

# Create configuration file
echo -e "${YELLOW}Creating configuration...${NC}"
cat > "$SCRIPT_DIR/auto_backup.conf" << 'EOF'
# Grim Auto Backup Configuration
GRAVEYARD_DIR="/root/.graveyard"
MONITOR_DIR="/opt/reaper"
BACKUP_INTERVAL=300
MAX_BACKUPS=50
MIN_FILE_SIZE=1024
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache" ".git/*" "node_modules/*" "venv/*" "*.pyc" "__pycache__/*")
INCLUDE_PATTERNS=("*.py" "*.sh" "*.go" "*.js" "*.php" "*.ts" "*.tsk" "*.pnt" "*.md" "*.txt" "*.json" "*.yaml" "*.yml")
COMPRESSION_ALGORITHM="zstd"
EOF

# Set permissions
chmod 644 "$SCRIPT_DIR/auto_backup.conf"

# Start the service
echo -e "${YELLOW}Starting auto backup service...${NC}"
systemctl start grim-auto-backup.service

# Check status
echo -e "${YELLOW}Checking service status...${NC}"
if systemctl is-active --quiet grim-auto-backup.service; then
    echo -e "${GREEN}✓ Auto backup service is running${NC}"
else
    echo -e "${RED}✗ Auto backup service failed to start${NC}"
    systemctl status grim-auto-backup.service
    exit 1
fi

# Show configuration
echo -e "${BLUE}=== Installation Complete ===${NC}"
echo -e "${GREEN}Auto backup system installed and running!${NC}"
echo ""
echo "Configuration:"
echo "  Monitor Directory: /opt/reaper"
echo "  Graveyard Directory: /root/.graveyard"
echo "  Backup Interval: 5 minutes"
echo "  Compression: zstd"
echo "  Max Backups: 50 per file"
echo ""
echo "Commands:"
echo "  systemctl start grim-auto-backup.service   - Start service"
echo "  systemctl stop grim-auto-backup.service    - Stop service"
echo "  systemctl restart grim-auto-backup.service - Restart service"
echo "  systemctl status grim-auto-backup.service  - Check status"
echo "  journalctl -u grim-auto-backup.service     - View logs"
echo ""
echo "Manual commands:"
echo "  $SCRIPT_DIR/auto_backup.sh status  - Show detailed status"
echo "  $SCRIPT_DIR/auto_backup.sh health  - Health check"
echo ""
echo -e "${YELLOW}The system will automatically:${NC}"
echo "  • Monitor file changes in /opt/reaper"
echo "  • Create compressed backups of modified files"
echo "  • Detect 'hot' files (frequently modified)"
echo "  • Clean up old backups automatically"
echo "  • Start on system boot"
echo ""
echo -e "${GREEN}Installation complete! Your files are now protected.${NC}" 