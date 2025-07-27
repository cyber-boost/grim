#!/bin/bash
# Grimm Blacksmith Module: System maintenance and optimization tools

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/blacksmith.log"
BLACKSMITH_ROOT="${BLACKSMITH_DIR:-$GRIM_ROOT/blacksmith}"
TOOLS_DIR="$BLACKSMITH_ROOT/tools"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Blacksmith Module"
    echo "Usage: blacksmith.sh <command> [options]"
    echo ""
    echo "Purpose: Provides system maintenance, optimization, and tool creation"
    echo "         capabilities for the Grimm system."
    echo ""
    echo "Commands:"
    echo "  optimize [target]            - Optimize system performance"
    echo "  maintain [task]              - Run maintenance tasks"
    echo "  forge <tool_name> <type>     - Create new maintenance tool"
    echo "  list-tools                   - List available tools"
    echo "  run-tool <name> [args]       - Run a specific tool"
    echo "  schedule <task> <cron>       - Schedule maintenance task"
    echo "  list-scheduled               - List scheduled tasks"
    echo "  backup-tools                 - Backup all tools"
    echo "  restore-tools <backup>       - Restore tools from backup"
    echo "  update-tools                 - Update all tools"
    echo "  stats                        - Show maintenance statistics"
    echo "  config                       - Show configuration"
    echo "  help, -h, --help             - Show this help message"
    echo ""
    echo "Optimization Targets:"
    echo "  system                       - System-level optimization"
    echo "  database                     - Database optimization"
    echo "  backup                       - Backup optimization"
    echo "  logs                         - Log optimization"
    echo "  all                          - All optimizations"
    echo ""
    echo "Maintenance Tasks:"
    echo "  cleanup                      - Clean up old files"
    echo "  defrag                       - Defragment databases"
    echo "  compress                     - Compress old backups"
    echo "  rotate-logs                  - Rotate log files"
    echo "  update-indexes               - Update database indexes"
    echo "  all                          - All maintenance tasks"
    echo ""
    echo "Tool Types:"
    echo "  script                       - Bash script"
    echo "  python                       - Python script"
    echo "  config                       - Configuration template"
    echo "  template                      - Generic template"
    echo ""
    echo "Examples:"
    echo "  ./blacksmith.sh optimize all"
    echo "  ./blacksmith.sh maintain cleanup"
    echo "  ./blacksmith.sh forge disk-cleaner script"
    echo "  ./blacksmith.sh schedule cleanup '0 2 * * 0'"
    echo "  ./blacksmith.sh help"
}

# Initialize database tables
init_db() {
    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS blacksmith_tools (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL,
    description TEXT,
    file_path TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_run DATETIME,
    run_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS maintenance_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    command TEXT NOT NULL,
    schedule TEXT,
    enabled INTEGER DEFAULT 1,
    last_run DATETIME,
    next_run DATETIME,
    run_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS optimization_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target TEXT NOT NULL,
    action TEXT NOT NULL,
    status TEXT NOT NULL,
    details TEXT,
    duration_seconds INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS blacksmith_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
}

# Load configuration
load_config() {
    local config_file="$GRIM_ROOT/config/blacksmith.conf"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" <<'EOF'
# Grimm Blacksmith Configuration

# Optimization Settings
OPTIMIZATION_ENABLED="true"
AUTO_OPTIMIZE="false"
OPTIMIZATION_INTERVAL="86400"  # 24 hours

# Maintenance Settings
MAINTENANCE_ENABLED="true"
AUTO_MAINTENANCE="true"
MAINTENANCE_WINDOW="02:00-04:00"

# Tool Settings
TOOLS_DIR="/opt/grim/blacksmith/tools"
BACKUP_TOOLS="true"
TOOL_BACKUP_RETENTION="30"

# Performance Thresholds
DISK_USAGE_THRESHOLD="85"
MEMORY_USAGE_THRESHOLD="80"
CPU_USAGE_THRESHOLD="75"

# Cleanup Settings
LOG_RETENTION_DAYS="30"
BACKUP_RETENTION_DAYS="90"
TEMP_FILE_RETENTION_HOURS="24"

# Database Settings
DB_VACUUM_THRESHOLD="1000"  # Operations before vacuum
DB_ANALYZE_INTERVAL="168"   # Hours between analyze
DB_OPTIMIZE_INTERVAL="720"  # Hours between optimize
EOF
        log "Created default config at $config_file"
    fi
    
    source "$config_file"
}

# System optimization
optimize_system() {
    local target="$1"
    
    case "$target" in
        system)
            optimize_system_performance
            ;;
        database)
            optimize_database
            ;;
        backup)
            optimize_backup_system
            ;;
        logs)
            optimize_logs
            ;;
        all)
            optimize_system_performance
            optimize_database
            optimize_backup_system
            optimize_logs
            ;;
        *)
            log_error "Unknown optimization target: $target"
            return 1
            ;;
    esac
}

# Optimize system performance
optimize_system_performance() {
    local start_time=$(date +%s)
    local status="success"
    local details=""
    
    log "Starting system performance optimization..."
    
    # Clear system caches
    if command -v sync >/dev/null 2>&1; then
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        details="$details Cleared system caches;"
    fi
    
    # Optimize file system
    if command -v fstrim >/dev/null 2>&1; then
        fstrim -v / 2>/dev/null || true
        details="$details Trimmed filesystem;"
    fi
    
    # Clean temporary files
    find /tmp -type f -atime +1 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +1 -delete 2>/dev/null || true
    details="$details Cleaned temporary files;"
    
    # Optimize swap
    if command -v swapon >/dev/null 2>&1; then
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null || true
        details="$details Optimized swap;"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Log optimization
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO optimization_history (target, action, status, details, duration_seconds)
VALUES ('system', 'performance_optimization', '$status', '$details', $duration);
EOF
    
    log "System performance optimization completed"
    echo -e "${GREEN}✅ System performance optimized${NC}"
}

# Optimize database
optimize_database() {
    local start_time=$(date +%s)
    local status="success"
    local details=""
    
    log "Starting database optimization..."
    
    # Check database size before optimization
    local size_before=$(stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
    
    # Vacuum database
    sqlite3 "$DB_PATH" "VACUUM;" 2>/dev/null || {
        status="failed"
        details="VACUUM failed"
    }
    
    # Analyze database
    sqlite3 "$DB_PATH" "ANALYZE;" 2>/dev/null || {
        status="failed"
        details="$details ANALYZE failed"
    }
    
    # Reindex database
    sqlite3 "$DB_PATH" "REINDEX;" 2>/dev/null || {
        status="failed"
        details="$details REINDEX failed"
    }
    
    # Check database size after optimization
    local size_after=$(stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
    local size_reduction=$((size_before - size_after))
    
    if [[ $size_reduction -gt 0 ]]; then
        details="$details Reduced database size by ${size_reduction} bytes;"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Log optimization
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO optimization_history (target, action, status, details, duration_seconds)
VALUES ('database', 'database_optimization', '$status', '$details', $duration);
EOF
    
    if [[ "$status" == "success" ]]; then
        log "Database optimization completed"
        echo -e "${GREEN}✅ Database optimized${NC}"
    else
        log_error "Database optimization failed"
        echo -e "${RED}❌ Database optimization failed${NC}"
        return 1
    fi
}

# Optimize backup system
optimize_backup_system() {
    local start_time=$(date +%s)
    local status="success"
    local details=""
    
    log "Starting backup system optimization..."
    
    # Compress old backups
    local compressed_count=0
    find "$GRIM_ROOT/backups" -name "*.tar.gz" -mtime +7 -exec gzip -t {} \; 2>/dev/null | while read -r file; do
        if [[ -f "$file" ]]; then
            gzip -9 "$file" 2>/dev/null && ((compressed_count++))
        fi
    done
    
    details="$details Compressed $compressed_count old backups;"
    
    # Remove very old backups
    local removed_count=$(find "$GRIM_ROOT/backups" -name "*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS:-90} | wc -l)
    find "$GRIM_ROOT/backups" -name "*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS:-90} -delete 2>/dev/null
    
    if [[ $removed_count -gt 0 ]]; then
        details="$details Removed $removed_count old backups;"
    fi
    
    # Optimize backup directory structure
    for freq in hourly daily weekly monthly; do
        if [[ -d "$GRIM_ROOT/backups/$freq" ]]; then
            # Keep only the most recent backups per frequency
            find "$GRIM_ROOT/backups/$freq" -name "*.tar.gz" | sort -r | tail -n +11 | xargs rm -f 2>/dev/null
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Log optimization
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO optimization_history (target, action, status, details, duration_seconds)
VALUES ('backup', 'backup_optimization', '$status', '$details', $duration);
EOF
    
    log "Backup system optimization completed"
    echo -e "${GREEN}✅ Backup system optimized${NC}"
}

# Optimize logs
optimize_logs() {
    local start_time=$(date +%s)
    local status="success"
    local details=""
    
    log "Starting log optimization..."
    
    # Rotate log files
    local rotated_count=0
    for log_file in "$GRIM_ROOT/logs"/*.log; do
        if [[ -f "$log_file" ]]; then
            local size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            if [[ $size -gt 10485760 ]]; then  # 10MB
                mv "$log_file" "${log_file}.$(date +%Y%m%d-%H%M%S)"
                touch "$log_file"
                ((rotated_count++))
            fi
        fi
    done
    
    details="$details Rotated $rotated_count log files;"
    
    # Compress old log files
    local compressed_count=0
    find "$GRIM_ROOT/logs" -name "*.log.*" -mtime +1 | while read -r file; do
        if [[ -f "$file" ]] && [[ ! "$file" =~ \.gz$ ]]; then
            gzip "$file" 2>/dev/null && ((compressed_count++))
        fi
    done
    
    details="$details Compressed $compressed_count old log files;"
    
    # Remove very old log files
    local removed_count=$(find "$GRIM_ROOT/logs" -name "*.log.*" -mtime +${LOG_RETENTION_DAYS:-30} | wc -l)
    find "$GRIM_ROOT/logs" -name "*.log.*" -mtime +${LOG_RETENTION_DAYS:-30} -delete 2>/dev/null
    
    if [[ $removed_count -gt 0 ]]; then
        details="$details Removed $removed_count old log files;"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Log optimization
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO optimization_history (target, action, status, details, duration_seconds)
VALUES ('logs', 'log_optimization', '$status', '$details', $duration);
EOF
    
    log "Log optimization completed"
    echo -e "${GREEN}✅ Logs optimized${NC}"
}

# Run maintenance tasks
run_maintenance() {
    local task="$1"
    
    case "$task" in
        cleanup)
            maintenance_cleanup
            ;;
        defrag)
            maintenance_defrag
            ;;
        compress)
            maintenance_compress
            ;;
        rotate-logs)
            maintenance_rotate_logs
            ;;
        update-indexes)
            maintenance_update_indexes
            ;;
        all)
            maintenance_cleanup
            maintenance_defrag
            maintenance_compress
            maintenance_rotate_logs
            maintenance_update_indexes
            ;;
        *)
            log_error "Unknown maintenance task: $task"
            return 1
            ;;
    esac
}

# Maintenance: Cleanup
maintenance_cleanup() {
    log "Running cleanup maintenance..."
    
    # Clean temporary files
    find /tmp -type f -atime +1 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +1 -delete 2>/dev/null || true
    
    # Clean Grimm temporary files
    find "$GRIM_ROOT" -name "*.tmp" -delete 2>/dev/null || true
    find "$GRIM_ROOT" -name "*.temp" -delete 2>/dev/null || true
    
    # Clean old cache files
    find "$GRIM_ROOT" -name "*.cache" -mtime +7 -delete 2>/dev/null || true
    
    log "Cleanup maintenance completed"
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Maintenance: Defragment
maintenance_defrag() {
    log "Running defragmentation maintenance..."
    
    # Database defragmentation
    sqlite3 "$DB_PATH" "VACUUM;" 2>/dev/null || true
    
    # File system defragmentation (if supported)
    if command -v e4defrag >/dev/null 2>&1; then
        e4defrag "$GRIM_ROOT" >/dev/null 2>&1 || true
    fi
    
    log "Defragmentation maintenance completed"
    echo -e "${GREEN}✅ Defragmentation completed${NC}"
}

# Maintenance: Compress
maintenance_compress() {
    log "Running compression maintenance..."
    
    # Compress old backups
    find "$GRIM_ROOT/backups" -name "*.tar" -mtime +1 -exec gzip {} \; 2>/dev/null || true
    
    # Compress old logs
    find "$GRIM_ROOT/logs" -name "*.log.*" -mtime +1 -exec gzip {} \; 2>/dev/null || true
    
    log "Compression maintenance completed"
    echo -e "${GREEN}✅ Compression completed${NC}"
}

# Maintenance: Rotate logs
maintenance_rotate_logs() {
    log "Running log rotation maintenance..."
    
    for log_file in "$GRIM_ROOT/logs"/*.log; do
        if [[ -f "$log_file" ]]; then
            local size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            if [[ $size -gt 5242880 ]]; then  # 5MB
                mv "$log_file" "${log_file}.$(date +%Y%m%d-%H%M%S)"
                touch "$log_file"
            fi
        fi
    done
    
    log "Log rotation maintenance completed"
    echo -e "${GREEN}✅ Log rotation completed${NC}"
}

# Maintenance: Update indexes
maintenance_update_indexes() {
    log "Running index update maintenance..."
    
    # Update database indexes
    sqlite3 "$DB_PATH" "REINDEX;" 2>/dev/null || true
    
    # Analyze database
    sqlite3 "$DB_PATH" "ANALYZE;" 2>/dev/null || true
    
    log "Index update maintenance completed"
    echo -e "${GREEN}✅ Index update completed${NC}"
}

# Create new tool
forge_tool() {
    local name="$1"
    local type="$2"
    
    if [[ -z "$name" || -z "$type" ]]; then
        log_error "Usage: forge <tool_name> <type>"
        return 1
    fi
    
    # Validate tool name
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Tool name must contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    # Validate type
    case "$type" in
        script|python|config|template)
            ;;
        *)
            log_error "Invalid tool type: $type. Valid types: script, python, config, template"
            return 1
            ;;
    esac
    
    local tool_path="$TOOLS_DIR/$name"
    
    # Create tool based on type
    case "$type" in
        script)
            create_bash_tool "$name" "$tool_path"
            ;;
        python)
            create_python_tool "$name" "$tool_path"
            ;;
        config)
            create_config_tool "$name" "$tool_path"
            ;;
        template)
            create_template_tool "$name" "$tool_path"
            ;;
    esac
    
    # Register tool in database
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO blacksmith_tools (name, type, description, file_path)
VALUES ('$name', '$type', 'Auto-generated $type tool', '$tool_path');
EOF
    
    log "Created tool: $name ($type)"
    echo "Tool '$name' created successfully at $tool_path"
}

# Create bash tool
create_bash_tool() {
    local name="$1"
    local path="$2"
    
    cat > "$path" <<EOF
#!/bin/bash
# Grimm Blacksmith Tool: $name
# Auto-generated by Blacksmith module

SCRIPT_PATH="\$(readlink -f "\$0")"
GRIM_ROOT="\$(cd "\$(dirname "\$SCRIPT_PATH")/../.." && pwd)"

# Colors
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m'

log() {
    echo -e "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"
}

show_help() {
    echo "Grimm Blacksmith Tool: $name"
    echo "Usage: \$0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Description:"
    echo "  Auto-generated tool for system maintenance"
}

main() {
    case "\${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log "Starting $name tool..."
            
            # TODO: Add your tool logic here
            
            log "$name tool completed"
            echo -e "\${GREEN}✅ $name completed successfully\${NC}"
            ;;
    esac
}

main "\$@"
EOF
    
    chmod +x "$path"
}

# Create Python tool
create_python_tool() {
    local name="$1"
    local path="$2"
    
    cat > "$path" <<EOF
#!/usr/bin/env python3
"""
Grimm Blacksmith Tool: $name
Auto-generated by Blacksmith module
"""

import os
import sys
import argparse
import logging
from datetime import datetime

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('$name')

def main():
    parser = argparse.ArgumentParser(description='Grimm Blacksmith Tool: $name')
    parser.add_argument('--help', '-h', action='store_true', help='Show help message')
    
    args = parser.parse_args()
    
    if args.help:
        parser.print_help()
        return
    
    logger.info("Starting $name tool...")
    
    # TODO: Add your tool logic here
    
    logger.info("$name tool completed")
    print("✅ $name completed successfully")

if __name__ == '__main__':
    main()
EOF
    
    chmod +x "$path"
}

# Create config tool
create_config_tool() {
    local name="$1"
    local path="$2"
    
    cat > "$path" <<EOF
# Grimm Blacksmith Config Tool: $name
# Auto-generated by Blacksmith module

# Configuration template for $name
# Copy this file to your config directory and customize as needed

[main]
enabled = true
interval = 3600
retention_days = 30

[settings]
# Add your configuration settings here
setting1 = "value1"
setting2 = "value2"

[thresholds]
# Add your thresholds here
threshold1 = 80
threshold2 = 90
EOF
}

# Create template tool
create_template_tool() {
    local name="$1"
    local path="$2"
    
    cat > "$path" <<EOF
# Grimm Blacksmith Template Tool: $name
# Auto-generated by Blacksmith module

# This is a template file for $name
# Customize this template according to your needs

TEMPLATE_NAME="$name"
TEMPLATE_VERSION="1.0.0"
TEMPLATE_DESCRIPTION="Auto-generated template tool"

# Template variables
VARIABLE1="default_value1"
VARIABLE2="default_value2"

# Template functions
function template_function1() {
    echo "Template function 1"
}

function template_function2() {
    echo "Template function 2"
}

# Main template logic
function main() {
    echo "Running template: \$TEMPLATE_NAME"
    template_function1
    template_function2
    echo "Template completed"
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\$0" ]]; then
    main "\$@"
fi
EOF
    
    chmod +x "$path"
}

# List available tools
list_tools() {
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT name, type, description, enabled, last_run, run_count
FROM blacksmith_tools
ORDER BY name;
EOF
}

# Run specific tool
run_tool() {
    local name="$1"
    shift
    
    if [[ -z "$name" ]]; then
        log_error "Usage: run-tool <name> [args...]"
        return 1
    fi
    
    local tool_info=$(sqlite3 "$DB_PATH" "SELECT file_path, type FROM blacksmith_tools WHERE name='$name' AND enabled=1 LIMIT 1;")
    
    if [[ -z "$tool_info" ]]; then
        log_error "Tool not found or disabled: $name"
        return 1
    fi
    
    local file_path=$(echo "$tool_info" | cut -d'|' -f1)
    local type=$(echo "$tool_info" | cut -d'|' -f2)
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Tool file not found: $file_path"
        return 1
    fi
    
    log "Running tool: $name"
    
    # Update last run time
    sqlite3 "$DB_PATH" "UPDATE blacksmith_tools SET last_run=CURRENT_TIMESTAMP, run_count=run_count+1 WHERE name='$name';"
    
    # Execute tool
    case "$type" in
        script|template)
            bash "$file_path" "$@"
            ;;
        python)
            python3 "$file_path" "$@"
            ;;
        config)
            cat "$file_path"
            ;;
        *)
            log_error "Unknown tool type: $type"
            return 1
            ;;
    esac
    
    log "Tool execution completed: $name"
}

# Schedule maintenance task
schedule_task() {
    local task="$1"
    local cron_schedule="$2"
    
    if [[ -z "$task" || -z "$cron_schedule" ]]; then
        log_error "Usage: schedule <task> <cron_schedule>"
        return 1
    fi
    
    # Validate cron schedule (basic validation)
    if ! echo "$cron_schedule" | grep -E '^(\*|[0-9]{1,2})(\/[0-9]{1,2})?(\s+(\*|[0-9]{1,2})(\/[0-9]{1,2})?){4}$' >/dev/null; then
        log_error "Invalid cron schedule: $cron_schedule"
        return 1
    fi
    
    # Calculate next run time
    local next_run=$(date -d "$(echo "$cron_schedule" | sed 's/^\([^ ]*\) \([^ ]*\) \([^ ]*\) \([^ ]*\) \([^ ]*\)$/\2 \1 \3 \4 \5/')" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    
    sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO maintenance_tasks (name, description, command, schedule, next_run)
VALUES ('$task', 'Scheduled maintenance task', 'grim blacksmith maintain $task', '$cron_schedule', '$next_run');
EOF
    
    log "Scheduled task: $task"
    echo "Task '$task' scheduled successfully"
}

# List scheduled tasks
list_scheduled() {
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT name, schedule, enabled, last_run, next_run, run_count, success_count, failure_count
FROM maintenance_tasks
ORDER BY name;
EOF
}

# Backup tools
backup_tools() {
    local backup_dir="$BLACKSMITH_ROOT/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/tools_backup_$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    log "Backing up tools to $backup_file"
    
    if tar -czf "$backup_file" -C "$BLACKSMITH_ROOT" tools/ 2>/dev/null; then
        log "Tools backup completed"
        echo "Tools backed up to $backup_file"
        
        # Clean old backups
        find "$backup_dir" -name "tools_backup_*.tar.gz" -mtime +${TOOL_BACKUP_RETENTION:-30} -delete 2>/dev/null
    else
        log_error "Tools backup failed"
        return 1
    fi
}

# Restore tools
restore_tools() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_error "Usage: restore-tools <backup_file>"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log "Restoring tools from $backup_file"
    
    # Backup current tools
    backup_tools
    
    # Restore from backup
    if tar -xzf "$backup_file" -C "$BLACKSMITH_ROOT" 2>/dev/null; then
        log "Tools restore completed"
        echo "Tools restored from $backup_file"
    else
        log_error "Tools restore failed"
        return 1
    fi
}

# Update tools
update_tools() {
    log "Updating all tools..."
    
    local updated_count=0
    
    # Get all enabled tools
    sqlite3 "$DB_PATH" "SELECT name, file_path FROM blacksmith_tools WHERE enabled=1;" | while IFS='|' read -r name file_path; do
        if [[ -f "$file_path" ]]; then
            # Check if tool has update logic
            if grep -q "update\|upgrade" "$file_path"; then
                log "Updating tool: $name"
                if bash "$file_path" --update 2>/dev/null; then
                    ((updated_count++))
                fi
            fi
        fi
    done
    
    log "Tools update completed: $updated_count tools updated"
    echo "Updated $updated_count tools"
}

# Show statistics
show_stats() {
    echo "=== Blacksmith Statistics ==="
    
    # Tool statistics
    local total_tools=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM blacksmith_tools;")
    local enabled_tools=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM blacksmith_tools WHERE enabled=1;")
    echo "Tools: $enabled_tools/$total_tools enabled"
    
    # Task statistics
    local total_tasks=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM maintenance_tasks;")
    local enabled_tasks=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM maintenance_tasks WHERE enabled=1;")
    echo "Tasks: $enabled_tasks/$total_tasks enabled"
    
    # Optimization statistics
    echo ""
    echo "Recent optimizations:"
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT target, action, status, timestamp
FROM optimization_history
ORDER BY timestamp DESC
LIMIT 10;
EOF
    
    # Tool usage statistics
    echo ""
    echo "Most used tools:"
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT name, run_count, last_run
FROM blacksmith_tools
WHERE run_count > 0
ORDER BY run_count DESC
LIMIT 5;
EOF
}

# Main execution
main() {
    mkdir -p "$(dirname "$LOG_FILE")" "$TOOLS_DIR"
    init_db
    load_config
    
    case "${1:-}" in
        optimize)
            optimize_system "$2"
            ;;
        maintain)
            run_maintenance "$2"
            ;;
        forge)
            forge_tool "$2" "$3"
            ;;
        list-tools)
            list_tools
            ;;
        run-tool)
            run_tool "$2" "${@:3}"
            ;;
        schedule)
            schedule_task "$2" "$3"
            ;;
        list-scheduled)
            list_scheduled
            ;;
        backup-tools)
            backup_tools
            ;;
        restore-tools)
            restore_tools "$2"
            ;;
        update-tools)
            update_tools
            ;;
        stats)
            show_stats
            ;;
        config)
            echo "Blacksmith configuration: $GRIM_ROOT/config/blacksmith.conf"
            cat "$GRIM_ROOT/config/blacksmith.conf"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 