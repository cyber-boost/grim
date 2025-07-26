#!/bin/bash
# Add auto-backup feature to existing Grim Reaper installation
# Quick script to enable automatic file protection

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GRIM_INSTALL_DIR="${GRIM_INSTALL_DIR:-/opt/reaper}"
GRIM_GRAVEYARD="${GRIM_GRAVEYARD:-$HOME/.graveyard}"

echo -e "${BLUE}=== Grim Auto-Backup Installer ===${NC}"

# Check if Grim is installed
if [[ ! -d "$GRIM_INSTALL_DIR" ]]; then
    echo -e "${RED}Error: Grim Reaper not found at $GRIM_INSTALL_DIR${NC}"
    echo "Please install Grim Reaper first: curl -sSL get.grim.so | bash"
    exit 1
fi

# Check if auto-backup is already running
if systemctl is-active --quiet grim-auto-backup 2>/dev/null; then
    echo -e "${GREEN}✅ Auto-backup is already running!${NC}"
    echo ""
    echo "Commands:"
    echo "  systemctl status grim-auto-backup  - Check status"
    echo "  systemctl stop grim-auto-backup    - Stop auto-backup"
    echo "  systemctl restart grim-auto-backup - Restart auto-backup"
    echo "  grim restore list auto             - List auto-backups"
    exit 0
fi

echo -e "${YELLOW}Installing auto-backup system...${NC}"

# Run the auto-backup installer if it exists
if [[ -f "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup.sh" ]]; then
    echo "Using existing auto-backup installer..."
    sudo "$GRIM_INSTALL_DIR/sh_grim/install_auto_backup.sh"
else
    echo "Setting up auto-backup manually..."
    
    # Install dependencies
    echo "Installing dependencies..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y inotify-tools
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y inotify-tools
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y inotify-tools
    else
        echo -e "${YELLOW}Warning: Could not install inotify-tools automatically${NC}"
        echo "Please install inotify-tools manually for your distribution"
    fi
    
    # Create directories
    echo "Creating backup directories..."
    sudo mkdir -p "$GRIM_GRAVEYARD/auto_backups"
    
    # Create configuration
    echo "Creating configuration..."
    sudo tee "$GRIM_INSTALL_DIR/sh_grim/auto_backup.conf" > /dev/null << EOF
# Grim Auto Backup Configuration
GRAVEYARD_DIR="$GRIM_GRAVEYARD"
MONITOR_DIR="$GRIM_INSTALL_DIR"
BACKUP_INTERVAL=300
MAX_BACKUPS=50
MIN_FILE_SIZE=1024
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache" ".git/*" "node_modules/*" "venv/*" "*.pyc" "__pycache__/*")
INCLUDE_PATTERNS=("*.py" "*.sh" "*.go" "*.js" "*.php" "*.ts" "*.tsk" "*.pnt" "*.md" "*.txt" "*.json" "*.yaml" "*.yml")
COMPRESSION_ALGORITHM="zstd"
EOF
    
    # Create systemd service
    echo "Creating systemd service..."
    sudo tee /etc/systemd/system/grim-auto-backup.service > /dev/null << EOF
[Unit]
Description=Grim Automatic Backup System
Documentation=https://grim.so/docs
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$GRIM_INSTALL_DIR
Environment=GRAVEYARD_DIR=$GRIM_GRAVEYARD
Environment=MONITOR_DIR=$GRIM_INSTALL_DIR
Environment=BACKUP_INTERVAL=300
Environment=MAX_BACKUPS=50
Environment=COMPRESSION_ALGORITHM=zstd
ExecStart=$GRIM_INSTALL_DIR/sh_grim/auto_backup.sh start
ExecStop=$GRIM_INSTALL_DIR/sh_grim/auto_backup.sh stop
ExecReload=$GRIM_INSTALL_DIR/sh_grim/auto_backup.sh restart
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=grim-auto-backup

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$GRIM_GRAVEYARD $GRIM_INSTALL_DIR /var/log /var/run

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    echo "Starting auto-backup service..."
    sudo systemctl daemon-reload
    sudo systemctl enable grim-auto-backup.service
    sudo systemctl start grim-auto-backup.service
fi

# Verify service is running
sleep 2
if systemctl is-active --quiet grim-auto-backup; then
    echo ""
    echo -e "${GREEN}✅ Auto-backup successfully installed and running!${NC}"
    echo ""
    echo -e "${YELLOW}What's happening now:${NC}"
    echo "  • Monitoring: $GRIM_INSTALL_DIR"
    echo "  • Backing up to: $GRIM_GRAVEYARD/auto_backups"
    echo "  • Backup interval: 5 minutes"
    echo "  • Compression: zstd (or gzip for smaller files)"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  systemctl status grim-auto-backup  - Check service status"
    echo "  grim restore list                  - List all backups (including auto)"
    echo "  grim restore list auto             - List only auto-backups"
    echo "  journalctl -u grim-auto-backup -f  - Watch live logs"
    echo ""
    echo -e "${GREEN}Your files are now protected! 🛡️${NC}"
else
    echo -e "${RED}Error: Auto-backup service failed to start${NC}"
    echo "Check logs with: journalctl -u grim-auto-backup -n 50"
    exit 1
fi