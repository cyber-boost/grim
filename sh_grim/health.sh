#!/bin/bash
# Grimm Health Module: System health checks and diagnostics

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/health.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Health Module"
    echo "Usage: health.sh <command> [options]"
    echo ""
    echo "Purpose: System health checks, diagnostics, and automated"
    echo "         monitoring with alerting and remediation capabilities."
    echo ""
    echo "Commands:"
    echo "  check                 - Run all health checks"
    echo "  disk                  - Check disk space and usage"
    echo "  memory                - Check memory usage"
    echo "  cpu                   - Check CPU usage and load"
    echo "  network               - Check network connectivity"
    echo "  services              - Check critical services"
    echo "  database              - Check database health"
    echo "  modules               - Check module status"
    echo "  report                - Generate health report"
    echo "  history               - Show health check history"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Options:"
    echo "  --critical            - Only show critical issues"
    echo "  --fix                 - Attempt to fix issues found"
    echo "  --notify              - Send notifications for issues"
    echo "  --quiet               - Suppress output, only return exit code"
    echo ""
    echo "Examples:"
    echo "  ./health.sh check                    # Run all health checks"
    echo "  ./health.sh disk --critical          # Check disk space (critical only)"
    echo "  ./health.sh memory --fix             # Check memory and fix issues"
    echo "  ./health.sh report                   # Generate detailed report"
    echo "  ./health.sh history 10               # Show last 10 health checks"
    echo "  ./health.sh help                     # Show help"
}

# Initialize health database tables
init_health_db() {
    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS health_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    check_type TEXT NOT NULL,
    status TEXT NOT NULL,
    message TEXT,
    details TEXT,
    severity TEXT DEFAULT 'info',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS health_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT,
    threshold_warning REAL,
    threshold_critical REAL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_health_checks_timestamp ON health_checks(timestamp);
CREATE INDEX IF NOT EXISTS idx_health_checks_type ON health_checks(check_type);
CREATE INDEX IF NOT EXISTS idx_health_checks_status ON health_checks(status);
CREATE INDEX IF NOT EXISTS idx_health_metrics_timestamp ON health_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_health_metrics_name ON health_metrics(metric_name);
EOF
    log "Health database initialized"
}

# Record health check result
record_health_check() {
    local check_type="$1"
    local status="$2"
    local message="$3"
    local details="${4:-}"
    local severity="${5:-info}"
    
    sqlite3 "$DB_PATH" "INSERT INTO health_checks (check_type, status, message, details, severity) VALUES ('$check_type', '$status', '$message', '$details', '$severity');" 2>/dev/null
    
    log "Health check: $check_type - $status - $message"
}

# Record metric
record_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local unit="${3:-}"
    local threshold_warning="${4:-}"
    local threshold_critical="${5:-}"
    
    sqlite3 "$DB_PATH" "INSERT INTO health_metrics (metric_name, metric_value, unit, threshold_warning, threshold_critical) VALUES ('$metric_name', $metric_value, '$unit', $threshold_warning, $threshold_critical);" 2>/dev/null
}

# Check disk space
check_disk() {
    local critical_only="${1:-false}"
    local fix_issues="${2:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== Disk Health Check ===${NC}"
    
    # Check root filesystem
    local root_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local root_available=$(df / | tail -1 | awk '{print $4}')
    local root_total=$(df / | tail -1 | awk '{print $2}')
    
    record_metric "disk_root_usage" "$root_usage" "percent" "80" "90"
    record_metric "disk_root_available" "$root_available" "blocks" "" ""
    record_metric "disk_root_total" "$root_total" "blocks" "" ""
    
    if [ "$root_usage" -ge 90 ]; then
        echo -e "${RED}❌ Root filesystem: ${root_usage}% used (CRITICAL)${NC}"
        record_health_check "disk" "critical" "Root filesystem ${root_usage}% full" "Available: $(numfmt --to=iec $((root_available * 1024)))" "critical"
        issues_found=$((issues_found + 1))
        
        if [ "$fix_issues" = "true" ]; then
            cleanup_disk_space
        fi
    elif [ "$root_usage" -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Root filesystem: ${root_usage}% used (WARNING)${NC}"
        record_health_check "disk" "warning" "Root filesystem ${root_usage}% full" "Available: $(numfmt --to=iec $((root_available * 1024)))" "warning"
        issues_found=$((issues_found + 1))
    else
        echo -e "${GREEN}✅ Root filesystem: ${root_usage}% used${NC}"
        record_health_check "disk" "ok" "Root filesystem healthy" "Usage: ${root_usage}%" "info"
    fi
    
    # Check backup volume if configured
    if [ -n "${volume_path:-}" ] && [ -d "$volume_path" ]; then
        local backup_usage=$(df "$volume_path" | tail -1 | awk '{print $5}' | sed 's/%//')
        local backup_available=$(df "$volume_path" | tail -1 | awk '{print $4}')
        
        record_metric "disk_backup_usage" "$backup_usage" "percent" "85" "95"
        record_metric "disk_backup_available" "$backup_available" "blocks" "" ""
        
        if [ "$backup_usage" -ge 95 ]; then
            echo -e "${RED}❌ Backup volume: ${backup_usage}% used (CRITICAL)${NC}"
            record_health_check "disk_backup" "critical" "Backup volume ${backup_usage}% full" "Available: $(numfmt --to=iec $((backup_available * 1024)))" "critical"
            issues_found=$((issues_found + 1))
        elif [ "$backup_usage" -ge 85 ]; then
            echo -e "${YELLOW}⚠️  Backup volume: ${backup_usage}% used (WARNING)${NC}"
            record_health_check "disk_backup" "warning" "Backup volume ${backup_usage}% full" "Available: $(numfmt --to=iec $((backup_available * 1024)))" "warning"
            issues_found=$((issues_found + 1))
        else
            echo -e "${GREEN}✅ Backup volume: ${backup_usage}% used${NC}"
            record_health_check "disk_backup" "ok" "Backup volume healthy" "Usage: ${backup_usage}%" "info"
        fi
    fi
    
    # Check inode usage
    local inode_usage=$(df -i / | tail -1 | awk '{print $5}' | sed 's/%//')
    record_metric "disk_inode_usage" "$inode_usage" "percent" "80" "90"
    
    if [ "$inode_usage" -ge 90 ]; then
        echo -e "${RED}❌ Inode usage: ${inode_usage}% (CRITICAL)${NC}"
        record_health_check "disk_inodes" "critical" "Inode usage ${inode_usage}%" "High inode usage detected" "critical"
        issues_found=$((issues_found + 1))
    elif [ "$inode_usage" -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Inode usage: ${inode_usage}% (WARNING)${NC}"
        record_health_check "disk_inodes" "warning" "Inode usage ${inode_usage}%" "High inode usage detected" "warning"
        issues_found=$((issues_found + 1))
    else
        echo -e "${GREEN}✅ Inode usage: ${inode_usage}%${NC}"
        record_health_check "disk_inodes" "ok" "Inode usage healthy" "Usage: ${inode_usage}%" "info"
    fi
    
    return $issues_found
}

# Clean up disk space
cleanup_disk_space() {
    echo -e "${YELLOW}Attempting disk space cleanup...${NC}"
    
    # Clean up old log files
    find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null
    find /var/log -name "*.gz" -mtime +30 -delete 2>/dev/null
    
    # Clean up package cache
    if command -v apt-get >/dev/null 2>&1; then
        apt-get clean 2>/dev/null
    elif command -v yum >/dev/null 2>&1; then
        yum clean all 2>/dev/null
    fi
    
    # Clean up temporary files
    find /tmp -type f -mtime +1 -delete 2>/dev/null
    find /var/tmp -type f -mtime +7 -delete 2>/dev/null
    
    # Clean up Grimm logs if too large
    if [ -d "$GRIM_ROOT/logs" ]; then
        find "$GRIM_ROOT/logs" -name "*.log.*" -mtime +7 -delete 2>/dev/null
    fi
    
    log "Disk space cleanup completed"
}

# Check memory usage
check_memory() {
    local critical_only="${1:-false}"
    local fix_issues="${2:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== Memory Health Check ===${NC}"
    
    # Get memory info
    local total_mem=$(free -m | awk 'NR==2{print $2}')
    local used_mem=$(free -m | awk 'NR==2{print $3}')
    local free_mem=$(free -m | awk 'NR==2{print $4}')
    local mem_usage=$((used_mem * 100 / total_mem))
    
    record_metric "memory_total" "$total_mem" "MB" "" ""
    record_metric "memory_used" "$used_mem" "MB" "" ""
    record_metric "memory_free" "$free_mem" "MB" "" ""
    record_metric "memory_usage" "$mem_usage" "percent" "80" "90"
    
    if [ "$mem_usage" -ge 90 ]; then
        echo -e "${RED}❌ Memory usage: ${mem_usage}% (CRITICAL)${NC}"
        record_health_check "memory" "critical" "Memory usage ${mem_usage}%" "Free: ${free_mem}MB" "critical"
        issues_found=$((issues_found + 1))
        
        if [ "$fix_issues" = "true" ]; then
            cleanup_memory
        fi
    elif [ "$mem_usage" -ge 80 ]; then
        echo -e "${YELLOW}⚠️  Memory usage: ${mem_usage}% (WARNING)${NC}"
        record_health_check "memory" "warning" "Memory usage ${mem_usage}%" "Free: ${free_mem}MB" "warning"
        issues_found=$((issues_found + 1))
    else
        echo -e "${GREEN}✅ Memory usage: ${mem_usage}%${NC}"
        record_health_check "memory" "ok" "Memory usage healthy" "Usage: ${mem_usage}%, Free: ${free_mem}MB" "info"
    fi
    
    # Check swap usage
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    if [ "$swap_total" -gt 0 ]; then
        local swap_used=$(free -m | awk 'NR==3{print $3}')
        local swap_usage=$((swap_used * 100 / swap_total))
        
        record_metric "swap_usage" "$swap_usage" "percent" "50" "80"
        
        if [ "$swap_usage" -ge 80 ]; then
            echo -e "${RED}❌ Swap usage: ${swap_usage}% (CRITICAL)${NC}"
            record_health_check "swap" "critical" "Swap usage ${swap_usage}%" "High swap usage detected" "critical"
            issues_found=$((issues_found + 1))
        elif [ "$swap_usage" -ge 50 ]; then
            echo -e "${YELLOW}⚠️  Swap usage: ${swap_usage}% (WARNING)${NC}"
            record_health_check "swap" "warning" "Swap usage ${swap_usage}%" "High swap usage detected" "warning"
            issues_found=$((issues_found + 1))
        else
            echo -e "${GREEN}✅ Swap usage: ${swap_usage}%${NC}"
            record_health_check "swap" "ok" "Swap usage healthy" "Usage: ${swap_usage}%" "info"
        fi
    fi
    
    return $issues_found
}

# Clean up memory
cleanup_memory() {
    echo -e "${YELLOW}Attempting memory cleanup...${NC}"
    
    # Clear page cache
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    # Clear swap if possible
    swapoff -a && swapon -a 2>/dev/null || true
    
    log "Memory cleanup completed"
}

# Check CPU usage
check_cpu() {
    local critical_only="${1:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== CPU Health Check ===${NC}"
    
    # Get CPU load averages
    local load_1=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_5=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | sed 's/,//')
    local load_15=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $3}')
    
    # Get CPU cores
    local cpu_cores=$(nproc)
    
    # Calculate load percentages
    local load_1_pct=$(echo "scale=1; $load_1 * 100 / $cpu_cores" | bc 2>/dev/null || echo "0")
    local load_5_pct=$(echo "scale=1; $load_5 * 100 / $cpu_cores" | bc 2>/dev/null || echo "0")
    local load_15_pct=$(echo "scale=1; $load_15 * 100 / $cpu_cores" | bc 2>/dev/null || echo "0")
    
    record_metric "cpu_load_1" "$load_1" "load" "0.7" "1.0"
    record_metric "cpu_load_5" "$load_5" "load" "0.5" "0.8"
    record_metric "cpu_load_15" "$load_15" "load" "0.3" "0.6"
    record_metric "cpu_cores" "$cpu_cores" "cores" "" ""
    
    if (( $(echo "$load_1 > 1.0" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${RED}❌ CPU load (1m): ${load_1} (CRITICAL)${NC}"
        record_health_check "cpu" "critical" "High CPU load: ${load_1}" "1-minute load average" "critical"
        issues_found=$((issues_found + 1))
    elif (( $(echo "$load_1 > 0.7" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${YELLOW}⚠️  CPU load (1m): ${load_1} (WARNING)${NC}"
        record_health_check "cpu" "warning" "High CPU load: ${load_1}" "1-minute load average" "warning"
        issues_found=$((issues_found + 1))
    else
        echo -e "${GREEN}✅ CPU load (1m): ${load_1}${NC}"
        record_health_check "cpu" "ok" "CPU load healthy" "1m: ${load_1}, 5m: ${load_5}, 15m: ${load_15}" "info"
    fi
    
    echo "CPU cores: $cpu_cores"
    echo "Load averages: 1m=${load_1}, 5m=${load_5}, 15m=${load_15}"
    
    return $issues_found
}

# Check network connectivity
check_network() {
    local critical_only="${1:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== Network Health Check ===${NC}"
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Internet connectivity: OK${NC}"
        record_health_check "network_internet" "ok" "Internet connectivity working" "Ping to 8.8.8.8 successful" "info"
    else
        echo -e "${RED}❌ Internet connectivity: FAILED${NC}"
        record_health_check "network_internet" "critical" "Internet connectivity failed" "Cannot ping 8.8.8.8" "critical"
        issues_found=$((issues_found + 1))
    fi
    
    # Check DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS resolution: OK${NC}"
        record_health_check "network_dns" "ok" "DNS resolution working" "nslookup google.com successful" "info"
    else
        echo -e "${RED}❌ DNS resolution: FAILED${NC}"
        record_health_check "network_dns" "critical" "DNS resolution failed" "Cannot resolve google.com" "critical"
        issues_found=$((issues_found + 1))
    fi
    
    # Check local network interfaces
    local interfaces=$(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | tr -d ' ')
    for interface in $interfaces; do
        if [ "$interface" != "lo" ]; then
            if ip link show "$interface" | grep -q "UP"; then
                echo -e "${GREEN}✅ Interface $interface: UP${NC}"
                record_health_check "network_interface" "ok" "Interface $interface is up" "Network interface operational" "info"
            else
                echo -e "${YELLOW}⚠️  Interface $interface: DOWN${NC}"
                record_health_check "network_interface" "warning" "Interface $interface is down" "Network interface not operational" "warning"
                issues_found=$((issues_found + 1))
            fi
        fi
    done
    
    return $issues_found
}

# Check critical services
check_services() {
    local critical_only="${1:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== Service Health Check ===${NC}"
    
    # Check SSH service
    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        echo -e "${GREEN}✅ SSH service: Running${NC}"
        record_health_check "service_ssh" "ok" "SSH service running" "SSH daemon operational" "info"
    else
        echo -e "${RED}❌ SSH service: Not running${NC}"
        record_health_check "service_ssh" "critical" "SSH service not running" "SSH daemon not operational" "critical"
        issues_found=$((issues_found + 1))
    fi
    
    # Check database service (if applicable)
    if command -v sqlite3 >/dev/null 2>&1; then
        if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" "SELECT 1;" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Database: Accessible${NC}"
            record_health_check "service_database" "ok" "Database accessible" "SQLite database operational" "info"
        else
            echo -e "${RED}❌ Database: Not accessible${NC}"
            record_health_check "service_database" "critical" "Database not accessible" "Cannot access SQLite database" "critical"
            issues_found=$((issues_found + 1))
        fi
    fi
    
    # Check cron service
    if systemctl is-active --quiet cron || systemctl is-active --quiet crond; then
        echo -e "${GREEN}✅ Cron service: Running${NC}"
        record_health_check "service_cron" "ok" "Cron service running" "Cron daemon operational" "info"
    else
        echo -e "${YELLOW}⚠️  Cron service: Not running${NC}"
        record_health_check "service_cron" "warning" "Cron service not running" "Cron daemon not operational" "warning"
        issues_found=$((issues_found + 1))
    fi
    
    return $issues_found
}

# Check database health
check_database() {
    local critical_only="${1:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== Database Health Check ===${NC}"
    
    if [ ! -f "$DB_PATH" ]; then
        echo -e "${RED}❌ Database file: Not found${NC}"
        record_health_check "database" "critical" "Database file not found" "Database file missing: $DB_PATH" "critical"
        return 1
    fi
    
    # Check database integrity
    if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        echo -e "${GREEN}✅ Database integrity: OK${NC}"
        record_health_check "database_integrity" "ok" "Database integrity check passed" "SQLite integrity check successful" "info"
    else
        echo -e "${RED}❌ Database integrity: FAILED${NC}"
        record_health_check "database_integrity" "critical" "Database integrity check failed" "SQLite integrity check failed" "critical"
        issues_found=$((issues_found + 1))
    fi
    
    # Check database size
    local db_size=$(stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
    local db_size_mb=$((db_size / 1024 / 1024))
    
    record_metric "database_size" "$db_size_mb" "MB" "100" "500"
    
    if [ "$db_size_mb" -gt 500 ]; then
        echo -e "${RED}❌ Database size: ${db_size_mb}MB (CRITICAL)${NC}"
        record_health_check "database_size" "critical" "Database size ${db_size_mb}MB" "Database is very large" "critical"
        issues_found=$((issues_found + 1))
    elif [ "$db_size_mb" -gt 100 ]; then
        echo -e "${YELLOW}⚠️  Database size: ${db_size_mb}MB (WARNING)${NC}"
        record_health_check "database_size" "warning" "Database size ${db_size_mb}MB" "Database is large" "warning"
        issues_found=$((issues_found + 1))
    else
        echo -e "${GREEN}✅ Database size: ${db_size_mb}MB${NC}"
        record_health_check "database_size" "ok" "Database size healthy" "Size: ${db_size_mb}MB" "info"
    fi
    
    return $issues_found
}

# Check module status
check_modules() {
    local critical_only="${1:-false}"
    local issues_found=0
    
    echo -e "\n${CYAN}=== Module Health Check ===${NC}"
    
    # Check if sh_grim directory exists
    if [ ! -d "$GRIM_ROOT/sh_grim" ]; then
        echo -e "${RED}❌ sh_grim directory: Not found${NC}"
        record_health_check "sh_grim_directory" "critical" "sh_grim directory not found" "sh_grim directory missing" "critical"
        return 1
    fi
    
    # Count all available modules
    local total_modules=$(find "$GRIM_ROOT/sh_grim" -name "*.sh" -type f | wc -l)
    local executable_modules=$(find "$GRIM_ROOT/sh_grim" -name "*.sh" -type f -executable | wc -l)
    
    echo -e "${GREEN}✅ Total sh_grim modules: $total_modules${NC}"
    echo -e "${GREEN}✅ Executable modules: $executable_modules${NC}"
    
    # Check core modules
    local core_modules=("backup.sh" "restore.sh" "scan.sh" "delete.sh" "notify.sh")
    for module in "${core_modules[@]}"; do
        if [ -f "$GRIM_ROOT/sh_grim/$module" ] && [ -x "$GRIM_ROOT/sh_grim/$module" ]; then
            echo -e "${GREEN}✅ Core module $module: OK${NC}"
            record_health_check "module_$module" "ok" "Core module $module accessible" "Module file exists and executable" "info"
        else
            echo -e "${RED}❌ Core module $module: Missing or not executable${NC}"
            record_health_check "module_$module" "critical" "Core module $module missing" "Module file missing or not executable" "critical"
            issues_found=$((issues_found + 1))
        fi
    done
    
    # Check additional important modules
    local important_modules=("monitor.sh" "health.sh" "schedule.sh" "compress.sh" "quarantine.sh" "security.sh" "ai_decision_engine.sh")
    for module in "${important_modules[@]}"; do
        if [ -f "$GRIM_ROOT/sh_grim/$module" ] && [ -x "$GRIM_ROOT/sh_grim/$module" ]; then
            echo -e "${GREEN}✅ Important module $module: OK${NC}"
            record_health_check "module_$module" "ok" "Important module $module accessible" "Module file exists and executable" "info"
        else
            echo -e "${YELLOW}⚠️  Important module $module: Missing or not executable${NC}"
            record_health_check "module_$module" "warning" "Important module $module missing" "Module file missing or not executable" "warning"
            issues_found=$((issues_found + 1))
        fi
    done
    
    return $issues_found
}

# Run all health checks
run_all_checks() {
    local critical_only="${1:-false}"
    local fix_issues="${2:-false}"
    local notify_issues="${3:-false}"
    local total_issues=0
    
    echo -e "${CYAN}=== Grimm Health Check ===${NC}"
    echo "Started at: $(date)"
    echo ""
    
    init_health_db
    
    # Run all checks
    check_disk "$critical_only" "$fix_issues"
    total_issues=$((total_issues + $?))
    
    check_memory "$critical_only" "$fix_issues"
    total_issues=$((total_issues + $?))
    
    check_cpu "$critical_only"
    total_issues=$((total_issues + $?))
    
    check_network "$critical_only"
    total_issues=$((total_issues + $?))
    
    check_services "$critical_only"
    total_issues=$((total_issues + $?))
    
    check_database "$critical_only"
    total_issues=$((total_issues + $?))
    
    check_modules "$critical_only"
    total_issues=$((total_issues + $?))
    
    echo ""
    echo -e "${CYAN}=== Health Check Summary ===${NC}"
    if [ "$total_issues" -eq 0 ]; then
        echo -e "${GREEN}✅ All systems healthy!${NC}"
        record_health_check "overall" "ok" "All health checks passed" "No issues found" "info"
    else
        echo -e "${RED}❌ Found $total_issues issue(s)${NC}"
        record_health_check "overall" "warning" "Found $total_issues issue(s)" "Health check completed with issues" "warning"
        
        if [ "$notify_issues" = "true" ]; then
            "$NOTIFY_MODULE" send warning "Health Check Issues" "Found $total_issues issue(s) during health check" "{\"total_issues\": $total_issues, \"timestamp\": \"$(date)\"}"
        fi
    fi
    
    echo "Completed at: $(date)"
    return $total_issues
}

# Generate health report
generate_report() {
    echo -e "\n${CYAN}=== Grimm Health Report ===${NC}"
    echo "Generated at: $(date)"
    echo ""
    
    # System information
    echo -e "${YELLOW}System Information:${NC}"
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    # Recent health checks
    echo -e "${YELLOW}Recent Health Checks:${NC}"
    sqlite3 "$DB_PATH" "SELECT check_type, status, message, timestamp FROM health_checks WHERE timestamp > datetime('now', '-24 hours') ORDER BY timestamp DESC LIMIT 10;" 2>/dev/null | while IFS='|' read -r check_type status message timestamp; do
        local status_icon=""
        case "$status" in
            "ok") status_icon="✅" ;;
            "warning") status_icon="⚠️" ;;
            "critical") status_icon="❌" ;;
            *) status_icon="ℹ️" ;;
        esac
        echo "[$timestamp] $status_icon $check_type: $message"
    done
    echo ""
    
    # Current metrics
    echo -e "${YELLOW}Current Metrics:${NC}"
    sqlite3 "$DB_PATH" "SELECT metric_name, metric_value, unit, timestamp FROM health_metrics WHERE timestamp > datetime('now', '-1 hour') ORDER BY timestamp DESC LIMIT 10;" 2>/dev/null | while IFS='|' read -r metric_name metric_value unit timestamp; do
        echo "$metric_name: $metric_value $unit ($timestamp)"
    done
    echo ""
}

# Show health check history
show_history() {
    local count="${1:-10}"
    
    echo -e "\n${CYAN}=== Health Check History ===${NC}"
    
    sqlite3 "$DB_PATH" "SELECT check_type, status, message, timestamp FROM health_checks ORDER BY timestamp DESC LIMIT $count;" 2>/dev/null | while IFS='|' read -r check_type status message timestamp; do
        local status_icon=""
        case "$status" in
            "ok") status_icon="✅" ;;
            "warning") status_icon="⚠️" ;;
            "critical") status_icon="❌" ;;
            *) status_icon="ℹ️" ;;
        esac
        echo "[$timestamp] $status_icon $check_type: $message"
    done
    
    echo ""
}

# Main command handler
main() {
    case "${1:-}" in
        check)
            run_all_checks "${2:-false}" "${3:-false}" "${4:-false}"
            ;;
        disk)
            check_disk "${2:-false}" "${3:-false}"
            ;;
        memory)
            check_memory "${2:-false}" "${3:-false}"
            ;;
        cpu)
            check_cpu "${2:-false}"
            ;;
        network)
            check_network "${2:-false}"
            ;;
        services)
            check_services "${2:-false}"
            ;;
        database)
            check_database "${2:-false}"
            ;;
        modules)
            check_modules "${2:-false}"
            ;;
        report)
            generate_report
            ;;
        history)
            show_history "${2:-10}"
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 