#!/bin/bash
# Grimm Healer Module: Auto-remediation and self-healing system

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/healer.log"
HEALER_ROOT="${HEALER_DIR:-$GRIM_ROOT/healer}"
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
    echo "Grimm Healer Module"
    echo "Usage: healer.sh <command> [options]"
    echo ""
    echo "Purpose: Provides automatic recovery and self-healing capabilities"
    echo "         for system failures, service outages, and performance issues."
    echo ""
    echo "Commands:"
    echo "  diagnose [service]           - Diagnose system health"
    echo "  heal [service] [issue]       - Attempt automatic healing"
    echo "  monitor                      - Start continuous monitoring"
    echo "  stop-monitor                 - Stop monitoring"
    echo "  add-playbook <name> <script> - Add recovery playbook"
    echo "  list-playbooks               - List available playbooks"
    echo "  test-playbook <name>         - Test a recovery playbook"
    echo "  history [service]            - Show healing history"
    echo "  stats                        - Show healing statistics"
    echo "  config                       - Show configuration"
    echo "  help, -h, --help             - Show this help message"
    echo ""
    echo "Services:"
    echo "  all                          - All services"
    echo "  grim                         - Grimm core services"
    echo "  database                     - Database services"
    echo "  backup                       - Backup services"
    echo "  notification                 - Notification services"
    echo "  scheduler                    - Scheduler services"
    echo "  mother-db                    - Mother DB service"
    echo "  system                       - System-level issues"
    echo ""
    echo "Examples:"
    echo "  ./healer.sh diagnose all"
    echo "  ./healer.sh heal grim service_down"
    echo "  ./healer.sh monitor"
    echo "  ./healer.sh add-playbook disk_full /path/to/script.sh"
    echo "  ./healer.sh help"
}

# Initialize database tables
init_db() {
    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS healing_playbooks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    script_path TEXT NOT NULL,
    service TEXT NOT NULL,
    issue_type TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS healing_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service TEXT NOT NULL,
    issue_type TEXT NOT NULL,
    playbook_name TEXT,
    status TEXT NOT NULL,
    details TEXT,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    duration_seconds INTEGER
);

CREATE TABLE IF NOT EXISTS system_health (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service TEXT NOT NULL,
    status TEXT NOT NULL,
    metrics TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS healing_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF
}

# Load configuration
load_config() {
    local config_file="$GRIM_ROOT/config/healer.conf"
    
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" <<'EOF'
# Grimm Healer Configuration

# Monitoring Settings
MONITORING_ENABLED="false"
MONITORING_INTERVAL="60"
MAX_RETRY_ATTEMPTS="3"
RETRY_DELAY="30"

# Service Health Checks
HEALTH_CHECK_TIMEOUT="30"
HEALTH_CHECK_RETRIES="2"

# Auto-Healing Settings
AUTO_HEAL_ENABLED="true"
AUTO_HEAL_DELAY="60"
LEARNING_ENABLED="true"

# Notification Settings
NOTIFY_ON_HEALING="true"
NOTIFY_ON_FAILURE="true"
NOTIFY_ON_SUCCESS="false"

# Recovery Playbooks
PLAYBOOKS_DIR="/opt/grim/healer/playbooks"
BACKUP_PLAYBOOKS="true"

# System Thresholds
DISK_USAGE_THRESHOLD="90"
MEMORY_USAGE_THRESHOLD="85"
CPU_USAGE_THRESHOLD="80"
EOF
        log "Created default config at $config_file"
    fi
    
    source "$config_file"
}

# Check service health
check_service_health() {
    local service="$1"
    
    case "$service" in
        grim)
            check_grim_health
            ;;
        database)
            check_database_health
            ;;
        backup)
            check_backup_health
            ;;
        notification)
            check_notification_health
            ;;
        scheduler)
            check_scheduler_health
            ;;
        mother-db)
            check_mother_db_health
            ;;
        system)
            check_system_health
            ;;
        all)
            check_grim_health
            check_database_health
            check_backup_health
            check_notification_health
            check_scheduler_health
            check_mother_db_health
            check_system_health
            ;;
        *)
            log_error "Unknown service: $service"
            return 1
            ;;
    esac
}

# Check Grimm core health
check_grim_health() {
    local issues=()
    
    # Check if reaper.sh is executable
    if [[ ! -x "$GRIM_ROOT/reaper.sh" ]]; then
        issues+=("reaper_not_executable")
    fi
    
    # Check if main modules exist
    for module in backup scan restore; do
        if [[ ! -f "$GRIM_ROOT/modules/$module.sh" ]]; then
            issues+=("module_missing_$module")
        fi
    done
    
    # Check systemd services
    for service in grimm-dashboard grimm-scanner grimm-backup grimm-scheduler grimm-mother-db; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            if ! systemctl is-active --quiet "$service" 2>/dev/null; then
                issues+=("service_down_$service")
            fi
        fi
    done
    
    # Store health status
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('grim', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "Grimm health issues detected: ${issues[*]}"
        return 1
    else
        log "Grimm health check passed"
        return 0
    fi
}

# Check database health
check_database_health() {
    local issues=()
    
    # Check if database is accessible
    if ! sqlite3 "$DB_PATH" "SELECT 1;" >/dev/null 2>&1; then
        issues+=("database_inaccessible")
    fi
    
    # Check database size
    local db_size=$(stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
    if [[ $db_size -gt 1073741824 ]]; then  # 1GB
        issues+=("database_large")
    fi
    
    # Check for corruption
    if ! sqlite3 "$DB_PATH" "PRAGMA integrity_check;" >/dev/null 2>&1; then
        issues+=("database_corrupted")
    fi
    
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('database', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "Database health issues detected: ${issues[*]}"
        return 1
    else
        log "Database health check passed"
        return 0
    fi
}

# Check backup health
check_backup_health() {
    local issues=()
    
    # Check backup directory
    if [[ ! -d "$GRIM_ROOT/backups" ]]; then
        issues+=("backup_dir_missing")
    else
        # Check disk space
        local usage=$(df "$GRIM_ROOT/backups" | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $usage -gt ${DISK_USAGE_THRESHOLD:-90} ]]; then
            issues+=("backup_disk_full")
        fi
        
        # Check recent backups
        local recent_backups=$(find "$GRIM_ROOT/backups" -name "*.tar.gz" -mtime -1 | wc -l)
        if [[ $recent_backups -eq 0 ]]; then
            issues+=("no_recent_backups")
        fi
    fi
    
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('backup', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "Backup health issues detected: ${issues[*]}"
        return 1
    else
        log "Backup health check passed"
        return 0
    fi
}

# Check notification health
check_notification_health() {
    local issues=()
    
    # Check if notification module exists
    if [[ ! -f "$GRIM_ROOT/sh_grim/notify.sh" ]] && [[ ! -f "$GRIM_ROOT/modules/multi_notify.sh" ]]; then
        issues+=("notification_modules_missing")
    fi
    
    # Test notification if configured
    if [[ -f "$GRIM_ROOT/config/notify.conf" ]] || [[ -f "$GRIM_ROOT/config/multi_notify.conf" ]]; then
        # This would be a more sophisticated test in production
        if [[ ! -d "$GRIM_ROOT/logs" ]]; then
            issues+=("notification_logs_missing")
        fi
    fi
    
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('notification', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "Notification health issues detected: ${issues[*]}"
        return 1
    else
        log "Notification health check passed"
        return 0
    fi
}

# Check scheduler health
check_scheduler_health() {
    local issues=()
    
    # Check if scheduler module exists
    if [[ ! -f "$GRIM_ROOT/modules/schedule.sh" ]]; then
        issues+=("scheduler_module_missing")
    fi
    
    # Check if cron jobs are installed
    if ! crontab -l 2>/dev/null | grep -q "grim\|grimm"; then
        issues+=("cron_jobs_missing")
    fi
    
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('scheduler', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "Scheduler health issues detected: ${issues[*]}"
        return 1
    else
        log "Scheduler health check passed"
        return 0
    fi
}

# Check Mother DB health
check_mother_db_health() {
    local issues=()
    
    # Check if Mother DB server exists
    if [[ ! -f "$GRIM_ROOT/bin/mother_db_server.py" ]]; then
        issues+=("mother_db_server_missing")
    fi
    
    # Check if Mother DB is running
    if ! systemctl is-active --quiet grimm-mother-db 2>/dev/null; then
        issues+=("mother_db_service_down")
    fi
    
    # Check if Mother DB is responding
    if command -v curl >/dev/null 2>&1; then
        if ! curl -s http://localhost:8080/api/v1/health >/dev/null 2>&1; then
            issues+=("mother_db_not_responding")
        fi
    fi
    
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('mother-db', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "Mother DB health issues detected: ${issues[*]}"
        return 1
    else
        log "Mother DB health check passed"
        return 0
    fi
}

# Check system health
check_system_health() {
    local issues=()
    
    # Check disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt ${DISK_USAGE_THRESHOLD:-90} ]]; then
        issues+=("disk_usage_high")
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt ${MEMORY_USAGE_THRESHOLD:-85} ]]; then
        issues+=("memory_usage_high")
    fi
    
    # Check CPU usage (simplified)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [[ $cpu_usage -gt ${CPU_USAGE_THRESHOLD:-80} ]]; then
        issues+=("cpu_usage_high")
    fi
    
    # Check load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_threshold=$((cpu_cores * 2))
    if (( $(echo "$load_avg > $load_threshold" | bc -l) )); then
        issues+=("load_average_high")
    fi
    
    local status="healthy"
    if [[ ${#issues[@]} -gt 0 ]]; then
        status="unhealthy"
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO system_health (service, status, metrics)
VALUES ('system', '$status', '$(printf '%s' "${issues[*]}" | jq -R -s -c 'split(" ")')');
EOF
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log "System health issues detected: ${issues[*]}"
        return 1
    else
        log "System health check passed"
        return 0
    fi
}

# Diagnose system health
diagnose() {
    local service="${1:-all}"
    
    log "Starting diagnosis for service: $service"
    
    if check_service_health "$service"; then
        echo -e "${GREEN}✅ $service is healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ $service has issues${NC}"
        return 1
    fi
}

# Attempt healing
heal() {
    local service="$1"
    local issue_type="$2"
    
    if [[ -z "$service" || -z "$issue_type" ]]; then
        log_error "Usage: heal <service> <issue_type>"
        return 1
    fi
    
    log "Attempting to heal $service for issue: $issue_type"
    
    # Find appropriate playbook
    local playbook=$(sqlite3 "$DB_PATH" "SELECT name, script_path FROM healing_playbooks WHERE service='$service' AND issue_type='$issue_type' AND enabled=1 LIMIT 1;")
    
    if [[ -z "$playbook" ]]; then
        log_error "No playbook found for $service/$issue_type"
        return 1
    fi
    
    local playbook_name=$(echo "$playbook" | cut -d'|' -f1)
    local script_path=$(echo "$playbook" | cut -d'|' -f2)
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Playbook script not found: $script_path"
        return 1
    fi
    
    # Execute healing playbook
    local start_time=$(date +%s)
    local status="failed"
    local details=""
    
    log "Executing playbook: $playbook_name"
    
    if bash "$script_path" "$service" "$issue_type" 2>&1; then
        status="success"
        details="Healing completed successfully"
        log "Healing successful for $service/$issue_type"
        "$NOTIFY_MODULE" send success "Auto-Healing Successful" "Successfully healed $service for $issue_type" "{\"service\": \"$service\", \"issue\": \"$issue_type\", \"playbook\": \"$playbook_name\"}" || true
    else
        details="Healing failed"
        log_error "Healing failed for $service/$issue_type"
        "$NOTIFY_MODULE" send error "Auto-Healing Failed" "Failed to heal $service for $issue_type" "{\"service\": \"$service\", \"issue\": \"$issue_type\", \"playbook\": \"$playbook_name\"}" || true
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Log healing attempt
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO healing_history (service, issue_type, playbook_name, status, details, end_time, duration_seconds)
VALUES ('$service', '$issue_type', '$playbook_name', '$status', '$details', datetime('now'), $duration);
EOF
    
    if [[ "$status" == "success" ]]; then
        echo -e "${GREEN}✅ Healing successful${NC}"
        return 0
    else
        echo -e "${RED}❌ Healing failed${NC}"
        return 1
    fi
}

# Add recovery playbook
add_playbook() {
    local name="$1"
    local script_path="$2"
    
    if [[ -z "$name" || -z "$script_path" ]]; then
        log_error "Usage: add-playbook <name> <script_path>"
        return 1
    fi
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    
    # Make script executable
    chmod +x "$script_path"
    
    # Extract service and issue type from script (simplified)
    local service="unknown"
    local issue_type="unknown"
    
    # Try to extract from script content
    if grep -q "service=" "$script_path"; then
        service=$(grep "service=" "$script_path" | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    if grep -q "issue=" "$script_path"; then
        issue_type=$(grep "issue=" "$script_path" | head -1 | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO healing_playbooks (name, script_path, service, issue_type, updated_at)
VALUES ('$name', '$script_path', '$service', '$issue_type', CURRENT_TIMESTAMP);
EOF
    
    log "Added playbook: $name"
    echo "Playbook '$name' added successfully"
}

# List playbooks
list_playbooks() {
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT name, service, issue_type, enabled, created_at
FROM healing_playbooks
ORDER BY name;
EOF
}

# Test playbook
test_playbook() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: test-playbook <name>"
        return 1
    fi
    
    local playbook=$(sqlite3 "$DB_PATH" "SELECT script_path, service, issue_type FROM healing_playbooks WHERE name='$name' LIMIT 1;")
    
    if [[ -z "$playbook" ]]; then
        log_error "Playbook not found: $name"
        return 1
    fi
    
    local script_path=$(echo "$playbook" | cut -d'|' -f1)
    local service=$(echo "$playbook" | cut -d'|' -f2)
    local issue_type=$(echo "$playbook" | cut -d'|' -f3)
    
    log "Testing playbook: $name"
    echo "Testing playbook '$name' for $service/$issue_type"
    
    if bash "$script_path" "$service" "$issue_type" --test 2>&1; then
        echo -e "${GREEN}✅ Playbook test successful${NC}"
        return 0
    else
        echo -e "${RED}❌ Playbook test failed${NC}"
        return 1
    fi
}

# Show healing history
show_history() {
    local service="$1"
    
    if [[ -n "$service" ]]; then
        sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT service, issue_type, playbook_name, status, start_time, duration_seconds
FROM healing_history
WHERE service='$service'
ORDER BY start_time DESC
LIMIT 20;
EOF
    else
        sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT service, issue_type, playbook_name, status, start_time, duration_seconds
FROM healing_history
ORDER BY start_time DESC
LIMIT 20;
EOF
    fi
}

# Show statistics
show_stats() {
    echo "=== Healing Statistics ==="
    
    # Total healing attempts
    local total=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM healing_history;")
    echo "Total healing attempts: $total"
    
    # Success rate
    local successful=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM healing_history WHERE status='success';")
    if [[ $total -gt 0 ]]; then
        local success_rate=$(echo "scale=1; $successful * 100 / $total" | bc)
        echo "Success rate: ${success_rate}%"
    fi
    
    # Most common issues
    echo ""
    echo "Most common issues:"
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT issue_type, COUNT(*) as count
FROM healing_history
GROUP BY issue_type
ORDER BY count DESC
LIMIT 5;
EOF
    
    # Recent activity
    echo ""
    echo "Recent healing activity:"
    sqlite3 "$DB_PATH" <<EOF
.mode column
.headers on
SELECT service, issue_type, status, start_time
FROM healing_history
ORDER BY start_time DESC
LIMIT 10;
EOF
}

# Start monitoring
start_monitoring() {
    log "Starting continuous monitoring..."
    
    # Create monitoring script
    cat > "$HEALER_ROOT/monitor.sh" <<EOF
#!/bin/bash
# Continuous monitoring script

GRIM_ROOT="$GRIM_ROOT"
HEALER_MODULE="$GRIM_ROOT/modules/healer.sh"
INTERVAL="${MONITORING_INTERVAL:-60}"

while true; do
    # Check all services
    if ! "\$HEALER_MODULE" diagnose all >/dev/null 2>&1; then
        # Issues detected, attempt healing
        "\$HEALER_MODULE" heal grim service_down || true
        "\$HEALER_MODULE" heal database database_inaccessible || true
        "\$HEALER_MODULE" heal backup backup_disk_full || true
        "\$HEALER_MODULE" heal system disk_usage_high || true
    fi
    
    sleep \$INTERVAL
done
EOF
    
    chmod +x "$HEALER_ROOT/monitor.sh"
    
    # Start monitoring in background
    nohup "$HEALER_ROOT/monitor.sh" > "$GRIM_ROOT/logs/healer_monitor.log" 2>&1 &
    echo $! > "$HEALER_ROOT/monitor.pid"
    
    log "Monitoring started (PID: $(cat "$HEALER_ROOT/monitor.pid"))"
    echo "Continuous monitoring started"
}

# Stop monitoring
stop_monitoring() {
    if [[ -f "$HEALER_ROOT/monitor.pid" ]]; then
        local pid=$(cat "$HEALER_ROOT/monitor.pid")
        if kill "$pid" 2>/dev/null; then
            log "Monitoring stopped (PID: $pid)"
            echo "Continuous monitoring stopped"
        else
            log "Failed to stop monitoring (PID: $pid)"
            echo "Failed to stop monitoring"
        fi
        rm -f "$HEALER_ROOT/monitor.pid"
    else
        echo "No monitoring process found"
    fi
}

# Main execution
main() {
    mkdir -p "$(dirname "$LOG_FILE")" "$HEALER_ROOT"
    init_db
    load_config
    
    case "${1:-}" in
        diagnose)
            diagnose "$2"
            ;;
        heal)
            heal "$2" "$3"
            ;;
        monitor)
            start_monitoring
            ;;
        stop-monitor)
            stop_monitoring
            ;;
        add-playbook)
            add_playbook "$2" "$3"
            ;;
        list-playbooks)
            list_playbooks
            ;;
        test-playbook)
            test_playbook "$2"
            ;;
        history)
            show_history "$2"
            ;;
        stats)
            show_stats
            ;;
        config)
            echo "Healer configuration: $GRIM_ROOT/config/healer.conf"
            cat "$GRIM_ROOT/config/healer.conf"
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