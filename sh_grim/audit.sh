#!/bin/bash
# Grimm Security Audit Module: Comprehensive security auditing and compliance checking

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/audit.log"
AUDIT_REPORTS_DIR="$GRIM_ROOT/reports/audit"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"
CONFIG_FILE="$GRIM_ROOT/config/audit.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Audit severity levels
SEVERITY_CRITICAL=4
SEVERITY_HIGH=3
SEVERITY_MEDIUM=2
SEVERITY_LOW=1
SEVERITY_INFO=0

# Initialize audit results
declare -A AUDIT_RESULTS
declare -A AUDIT_COUNTS
AUDIT_COUNTS[CRITICAL]=0
AUDIT_COUNTS[HIGH]=0
AUDIT_COUNTS[MEDIUM]=0
AUDIT_COUNTS[LOW]=0
AUDIT_COUNTS[INFO]=0

# Safety limits to prevent infinite loops
MAX_FINDINGS_PER_CATEGORY=100
MAX_FILES_TO_SCAN=10000
SCAN_TIMEOUT=300  # 5 minutes

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Load audit configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Create default config
        cat > "$CONFIG_FILE" <<'EOF'
# Grimm Security Audit Configuration

# Audit Settings
AUDIT_ENABLED="true"
AUDIT_SCHEDULE="daily"
AUDIT_RETENTION_DAYS="30"

# Permission Audit Settings
PERMISSION_AUDIT_ENABLED="true"
WORLD_WRITABLE_CHECK="true"
INCORRECT_OWNERSHIP_CHECK="true"
SUID_SGID_CHECK="true"
STICKY_BIT_CHECK="true"

# Compliance Settings
CIS_BENCHMARK_CHECK="true"
STIG_CHECK="true"
NIST_CHECK="true"

# Backup Integrity Settings
BACKUP_INTEGRITY_CHECK="true"
CHECKSUM_VERIFICATION="true"
SIGNATURE_VERIFICATION="true"
BACKUP_AGE_CHECK_DAYS="30"

# Access Log Settings
ACCESS_LOG_ANALYSIS="true"
LOG_RETENTION_DAYS="90"
SUSPICIOUS_ACTIVITY_CHECK="true"
FAILED_LOGIN_THRESHOLD="5"

# Configuration Security Settings
CONFIG_SECURITY_CHECK="true"
CREDENTIAL_SCAN="true"
HARDCODED_SECRETS_CHECK="true"
EXPOSED_CONFIGS_CHECK="true"

# Report Settings
REPORT_FORMATS="text,json"
REPORT_DETAIL_LEVEL="detailed"
NOTIFY_ON_CRITICAL="true"
NOTIFY_ON_HIGH="true"

# Scan Paths
SCAN_PATHS="/opt/grim,/root/.grim,/var/log"
EXCLUDE_PATHS="/tmp,/proc,/sys,/dev"

# Compliance Standards
COMPLIANCE_STANDARDS="CIS,STIG,NIST"
EOF
        log "Created default audit config at $CONFIG_FILE"
    fi
}

# Add audit finding with safety checks
add_finding() {
    local severity="$1"
    local category="$2"
    local title="$3"
    local description="$4"
    local recommendation="$5"
    local evidence="$6"
    
    # Check if we've exceeded the maximum findings for this category
    local current_count=${AUDIT_COUNTS[$severity]}
    if [[ $current_count -ge $MAX_FINDINGS_PER_CATEGORY ]]; then
        if [[ $current_count -eq $MAX_FINDINGS_PER_CATEGORY ]]; then
            echo -e "${YELLOW}[WARNING]${NC} Maximum findings reached for $severity category ($MAX_FINDINGS_PER_CATEGORY). Additional findings will be suppressed."
        fi
        return
    fi
    
    local finding_id="$(date +%s)_${RANDOM}"
    local finding="{
        \"id\": \"$finding_id\",
        \"severity\": \"$severity\",
        \"category\": \"$category\",
        \"title\": \"$title\",
        \"description\": \"$description\",
        \"recommendation\": \"$recommendation\",
        \"evidence\": \"$evidence\",
        \"timestamp\": \"$(date -Iseconds)\"
    }"
    
    AUDIT_RESULTS["$finding_id"]="$finding"
    ((AUDIT_COUNTS[$severity]++))
    
    # Color-coded output
    case "$severity" in
        "CRITICAL")
            echo -e "${RED}[CRITICAL]${NC} $title"
            ;;
        "HIGH")
            echo -e "${YELLOW}[HIGH]${NC} $title"
            ;;
        "MEDIUM")
            echo -e "${BLUE}[MEDIUM]${NC} $title"
            ;;
        "LOW")
            echo -e "${CYAN}[LOW]${NC} $title"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $title"
            ;;
    esac
}

# Safe find function with limits
safe_find() {
    local path="$1"
    local conditions="$2"
    local max_results="${3:-$MAX_FILES_TO_SCAN}"
    
    if [[ ! -d "$path" ]]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    # Use timeout to prevent infinite loops
    timeout $SCAN_TIMEOUT find "$path" $conditions 2>/dev/null | head -n "$max_results"
}

# Permission auditing with safety improvements
audit_permissions() {
    local scan_path="${1:-$GRIM_ROOT}"
    log "Starting permission audit for: $scan_path"
    
    echo -e "\n${PURPLE}=== Permission Audit ===${NC}"
    
    # Check for world-writable files
    if [ "$WORLD_WRITABLE_CHECK" = "true" ]; then
        echo "Checking for world-writable files..."
        local count=0
        while IFS= read -r file && [[ $count -lt $MAX_FINDINGS_PER_CATEGORY ]]; do
            if [[ -n "$file" ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null)
                local owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
                add_finding "HIGH" "permissions" "World-writable file found" \
                    "File $file has world-write permissions" \
                    "Remove world-write permissions: chmod o-w '$file'" \
                    "File: $file, Permissions: $perms, Owner: $owner"
                ((count++))
            fi
        done < <(safe_find "$scan_path" "-type f -perm -002" 50)
    fi
    
    # Check for incorrect ownership (limited scan)
    if [ "$INCORRECT_OWNERSHIP_CHECK" = "true" ]; then
        echo "Checking file ownership..."
        local count=0
        while IFS= read -r file && [[ $count -lt $MAX_FINDINGS_PER_CATEGORY ]]; do
            if [[ -n "$file" ]]; then
                local owner=$(stat -c "%U" "$file" 2>/dev/null)
                local group=$(stat -c "%G" "$file" 2>/dev/null)
                
                # Check if owned by root but shouldn't be (limited to specific patterns)
                if [[ "$owner" = "root" ]] && [[ "$file" != *"/etc/"* ]] && [[ "$file" != *"/var/log/"* ]] && [[ "$file" != *"/usr/"* ]]; then
                    add_finding "MEDIUM" "permissions" "File owned by root" \
                        "File $file is owned by root but may not need to be" \
                        "Consider changing ownership to appropriate user: chown user:group '$file'" \
                        "File: $file, Owner: $owner:$group"
                    ((count++))
                fi
            fi
        done < <(safe_find "$scan_path" "-type f -user root" 100)
    fi
    
    # Check for sensitive files with wrong permissions
    echo "Checking sensitive file permissions..."
    local sensitive_patterns=("*.key" "*.pem" "*.p12" "*.pfx" "*.conf" "*.config" "*.ini" "*.env")
    for pattern in "${sensitive_patterns[@]}"; do
        while IFS= read -r file; do
            if [[ -n "$file" && -r "$file" ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null)
                if [[ "$perms" =~ ^[0-9][0-9][4-7]$ ]]; then
                    add_finding "CRITICAL" "permissions" "Sensitive file world-readable" \
                        "Sensitive file $file is world-readable" \
                        "Restrict permissions: chmod 600 '$file'" \
                        "File: $file, Permissions: $perms"
                fi
            fi
        done < <(safe_find "$scan_path" "-name '$pattern' -type f" 20)
    done
    
    # Check for SUID/SGID files
    if [ "$SUID_SGID_CHECK" = "true" ]; then
        echo "Checking for SUID/SGID files..."
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null)
                local owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
                add_finding "HIGH" "permissions" "SUID/SGID file found" \
                    "File $file has SUID or SGID bit set" \
                    "Review if SUID/SGID is necessary: ls -la '$file'" \
                    "File: $file, Permissions: $perms, Owner: $owner"
            fi
        done < <(safe_find "$scan_path" "-type f \\( -perm -4000 -o -perm -2000 \\)" 30)
    fi
}

# Compliance auditing
audit_compliance() {
    echo -e "\n${PURPLE}=== Compliance Audit ===${NC}"
    
    if [ "$CIS_BENCHMARK_CHECK" = "true" ]; then
        echo "Running CIS Benchmark checks..."
        
        # Check SSH configuration
        if [[ -f "/etc/ssh/sshd_config" ]]; then
            if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
                add_finding "HIGH" "compliance" "SSH root login enabled" \
                    "SSH allows root login which violates CIS benchmarks" \
                    "Set 'PermitRootLogin no' in /etc/ssh/sshd_config" \
                    "File: /etc/ssh/sshd_config"
            fi
            
            if ! grep -q "^Protocol 2" /etc/ssh/sshd_config 2>/dev/null; then
                add_finding "MEDIUM" "compliance" "SSH protocol version not specified" \
                    "SSH protocol version should be explicitly set to 2" \
                    "Add 'Protocol 2' to /etc/ssh/sshd_config" \
                    "File: /etc/ssh/sshd_config"
            fi
        fi
        
        # Check password policy
        if [[ -f "/etc/login.defs" ]]; then
            local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}')
            if [[ -z "$pass_max_days" || $pass_max_days -gt 90 ]]; then
                add_finding "MEDIUM" "compliance" "Password aging policy too lenient" \
                    "Password maximum age should be 90 days or less" \
                    "Set PASS_MAX_DAYS to 90 in /etc/login.defs" \
                    "Current value: $pass_max_days"
            fi
        fi
        
        # Check for default accounts
        local default_accounts=("games" "news" "gopher" "ftp")
        for account in "${default_accounts[@]}"; do
            if getent passwd "$account" >/dev/null 2>&1; then
                add_finding "LOW" "compliance" "Default account present" \
                    "Default system account '$account' is present" \
                    "Consider removing unused account: userdel '$account'" \
                    "Account: $account"
            fi
        done
    fi
    
    if [ "$STIG_CHECK" = "true" ]; then
        echo "Running STIG compliance checks..."
        
        # Check for unencrypted services
        local unencrypted_services=("telnet" "rsh" "rlogin")
        for service in "${unencrypted_services[@]}"; do
            if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
                add_finding "CRITICAL" "compliance" "Unencrypted service enabled" \
                    "Service '$service' provides unencrypted communication" \
                    "Disable service: systemctl disable '$service'" \
                    "Service: $service"
            fi
        done
        
        # Check file system permissions
        local critical_dirs=("/etc" "/bin" "/sbin" "/usr/bin" "/usr/sbin")
        for dir in "${critical_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                local perms=$(stat -c "%a" "$dir" 2>/dev/null)
                if [[ "$perms" =~ [2367]$ ]]; then
                    add_finding "HIGH" "compliance" "Critical directory world-writable" \
                        "Critical directory '$dir' has world-write permissions" \
                        "Remove world-write: chmod o-w '$dir'" \
                        "Directory: $dir, Permissions: $perms"
                fi
            fi
        done
    fi
    
    if [ "$NIST_CHECK" = "true" ]; then
        echo "Running NIST compliance checks..."
        
        # Check logging configuration
        if ! systemctl is-active rsyslog >/dev/null 2>&1 && ! systemctl is-active syslog-ng >/dev/null 2>&1; then
            add_finding "HIGH" "compliance" "System logging not active" \
                "No active system logging service found" \
                "Enable and start rsyslog or syslog-ng service" \
                "Services checked: rsyslog, syslog-ng"
        fi
        
        # Check for audit system
        if ! systemctl is-active auditd >/dev/null 2>&1; then
            add_finding "MEDIUM" "compliance" "Audit system not active" \
                "Audit daemon is not running" \
                "Install and enable auditd: apt-get install auditd && systemctl enable auditd" \
                "Service: auditd"
        fi
    fi
}

# Backup integrity auditing
audit_backup_integrity() {
    echo -e "\n${PURPLE}=== Backup Integrity Audit ===${NC}"
    
    if [ "$BACKUP_INTEGRITY_CHECK" = "true" ]; then
        echo "Checking backup integrity..."
        
        # Check GRIM backup directories
        local backup_dirs=("$GRIM_ROOT/backups" "$GRIM_ROOT/auto_backups")
        for backup_dir in "${backup_dirs[@]}"; do
            if [[ -d "$backup_dir" ]]; then
                echo "Scanning backup directory: $backup_dir"
                local backup_count=0
                local corrupted_count=0
                
                while IFS= read -r backup_file && [[ $backup_count -lt 50 ]]; do
                    if [[ -n "$backup_file" ]]; then
                        ((backup_count++))
                        
                        # Check if backup file is readable
                        if [[ ! -r "$backup_file" ]]; then
                            add_finding "HIGH" "backup" "Backup file not readable" \
                                "Backup file $backup_file cannot be read" \
                                "Check file permissions and integrity" \
                                "File: $backup_file"
                            ((corrupted_count++))
                            continue
                        fi
                        
                        # Check backup file age
                        local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$backup_file" 2>/dev/null || echo 0)) / 86400 ))
                        if [[ $file_age_days -gt ${BACKUP_AGE_CHECK_DAYS:-30} ]]; then
                            add_finding "LOW" "backup" "Old backup file" \
                                "Backup file $backup_file is $file_age_days days old" \
                                "Consider archiving or removing old backups" \
                                "File: $backup_file, Age: $file_age_days days"
                        fi
                        
                        # Quick integrity check for common formats
                        case "$backup_file" in
                            *.tar.gz|*.tgz)
                                if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
                                    add_finding "CRITICAL" "backup" "Corrupted TAR.GZ backup" \
                                        "Backup file $backup_file appears to be corrupted" \
                                        "Restore from alternate backup or recreate" \
                                        "File: $backup_file"
                                    ((corrupted_count++))
                                fi
                                ;;
                            *.tar)
                                if ! tar -tf "$backup_file" >/dev/null 2>&1; then
                                    add_finding "CRITICAL" "backup" "Corrupted TAR backup" \
                                        "Backup file $backup_file appears to be corrupted" \
                                        "Restore from alternate backup or recreate" \
                                        "File: $backup_file"
                                    ((corrupted_count++))
                                fi
                                ;;
                            *.zip)
                                if command -v unzip >/dev/null 2>&1; then
                                    if ! unzip -t "$backup_file" >/dev/null 2>&1; then
                                        add_finding "CRITICAL" "backup" "Corrupted ZIP backup" \
                                            "Backup file $backup_file appears to be corrupted" \
                                            "Restore from alternate backup or recreate" \
                                            "File: $backup_file"
                                        ((corrupted_count++))
                                    fi
                                fi
                                ;;
                        esac
                    fi
                done < <(find "$backup_dir" -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.tar.bz2" -o -name "*.tar.xz" \) 2>/dev/null)
                
                add_finding "INFO" "backup" "Backup directory scan complete" \
                    "Scanned $backup_count backup files in $backup_dir" \
                    "Regular backup integrity monitoring recommended" \
                    "Directory: $backup_dir, Files: $backup_count, Corrupted: $corrupted_count"
            else
                add_finding "MEDIUM" "backup" "Backup directory missing" \
                    "Expected backup directory $backup_dir does not exist" \
                    "Create backup directory and verify backup configuration" \
                    "Directory: $backup_dir"
            fi
        done
    fi
}

# Access log auditing
audit_access_logs() {
    echo -e "\n${PURPLE}=== Access Log Audit ===${NC}"
    
    if [ "$ACCESS_LOG_ANALYSIS" = "true" ]; then
        echo "Analyzing access logs..."
        
        # Check common log files
        local log_files=("/var/log/auth.log" "/var/log/secure" "/var/log/syslog" "$GRIM_ROOT/logs/access.log")
        
        for log_file in "${log_files[@]}"; do
            if [[ -f "$log_file" && -r "$log_file" ]]; then
                echo "Analyzing log: $log_file"
                
                # Check for failed login attempts
                local failed_logins=$(grep -c "Failed password\|authentication failure\|invalid user" "$log_file" 2>/dev/null || echo 0)
                if [[ $failed_logins -gt ${FAILED_LOGIN_THRESHOLD:-5} ]]; then
                    add_finding "HIGH" "security" "Excessive failed login attempts" \
                        "Found $failed_logins failed login attempts in $log_file" \
                        "Investigate source of failed logins and consider fail2ban" \
                        "Log: $log_file, Count: $failed_logins"
                fi
                
                # Check for privilege escalation attempts
                local sudo_failures=$(grep -c "sudo.*FAILED\|sudo.*incorrect password" "$log_file" 2>/dev/null || echo 0)
                if [[ $sudo_failures -gt 3 ]]; then
                    add_finding "MEDIUM" "security" "Sudo privilege escalation attempts" \
                        "Found $sudo_failures failed sudo attempts in $log_file" \
                        "Review sudo access and investigate failed attempts" \
                        "Log: $log_file, Count: $sudo_failures"
                fi
                
                # Check for suspicious commands
                local suspicious_commands=("rm -rf" "dd if=" "mkfs" "fdisk" "parted")
                for cmd in "${suspicious_commands[@]}"; do
                    local cmd_count=$(grep -c "$cmd" "$log_file" 2>/dev/null || echo 0)
                    if [[ $cmd_count -gt 0 ]]; then
                        add_finding "MEDIUM" "security" "Potentially dangerous command detected" \
                            "Found $cmd_count instances of '$cmd' in $log_file" \
                            "Review command usage and ensure it was authorized" \
                            "Log: $log_file, Command: $cmd, Count: $cmd_count"
                    fi
                done
            fi
        done
    fi
}

# Configuration security auditing
audit_config_security() {
    echo -e "\n${PURPLE}=== Configuration Security Audit ===${NC}"
    
    if [ "$CONFIG_SECURITY_CHECK" = "true" ]; then
        echo "Checking configuration security..."
        
        # Check for exposed configuration files
        local config_patterns=("*.conf" "*.config" "*.ini" "*.env" "*.yaml" "*.yml" "*.json")
        for pattern in "${config_patterns[@]}"; do
            while IFS= read -r config_file; do
                if [[ -n "$config_file" && -r "$config_file" ]]; then
                    local perms=$(stat -c "%a" "$config_file" 2>/dev/null)
                    if [[ "$perms" =~ ^[0-9][0-9][4-7]$ ]]; then
                        add_finding "HIGH" "config" "Configuration file world-readable" \
                            "Configuration file $config_file is world-readable" \
                            "Restrict permissions: chmod 600 '$config_file'" \
                            "File: $config_file, Permissions: $perms"
                    fi
                fi
            done < <(safe_find "$GRIM_ROOT" "-name '$pattern' -type f" 20)
        done
        
        # Check for hardcoded credentials
        if [ "$CREDENTIAL_SCAN" = "true" ]; then
            echo "Scanning for hardcoded credentials..."
            local credential_patterns=("password=" "passwd=" "pwd=" "secret=" "key=" "token=" "api_key=")
            for pattern in "${credential_patterns[@]}"; do
                while IFS= read -r file; do
                    if [[ -n "$file" && -r "$file" ]]; then
                        local matches=$(grep -c -i "$pattern" "$file" 2>/dev/null || echo 0)
                        if [[ $matches -gt 0 ]]; then
                            add_finding "CRITICAL" "config" "Potential hardcoded credentials" \
                                "File $file may contain hardcoded credentials" \
                                "Review file and remove any hardcoded credentials" \
                                "File: $file, Pattern: $pattern, Matches: $matches"
                        fi
                    fi
                done < <(safe_find "$GRIM_ROOT" "-type f \\( -name '*.conf' -o -name '*.config' -o -name '*.sh' -o -name '*.py' \\)" 30)
            done
        fi
    fi
}

# Generate audit report
generate_report() {
    local format="${1:-text}"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local report_file="$AUDIT_REPORTS_DIR/audit_report_${timestamp}.${format}"
    
    echo -e "\n${PURPLE}=== Generating Audit Report ===${NC}"
    echo "Report format: $format"
    echo "Report file: $report_file"
    
    case "$format" in
        "json")
            {
                echo "{"
                echo "  \"audit_timestamp\": \"$(date -Iseconds)\","
                echo "  \"grim_root\": \"$GRIM_ROOT\","
                echo "  \"summary\": {"
                echo "    \"critical\": ${AUDIT_COUNTS[CRITICAL]},"
                echo "    \"high\": ${AUDIT_COUNTS[HIGH]},"
                echo "    \"medium\": ${AUDIT_COUNTS[MEDIUM]},"
                echo "    \"low\": ${AUDIT_COUNTS[LOW]},"
                echo "    \"info\": ${AUDIT_COUNTS[INFO]}"
                echo "  },"
                echo "  \"findings\": ["
                local first=true
                for finding_id in "${!AUDIT_RESULTS[@]}"; do
                    if [ "$first" = true ]; then
                        first=false
                    else
                        echo ","
                    fi
                    echo "    ${AUDIT_RESULTS[$finding_id]}"
                done
                echo ""
                echo "  ]"
                echo "}"
            } > "$report_file"
            ;;
        "text"|*)
            {
                echo "GRIMM SECURITY AUDIT REPORT"
                echo "============================"
                echo "Timestamp: $(date)"
                echo "GRIM Root: $GRIM_ROOT"
                echo ""
                echo "SUMMARY"
                echo "-------"
                echo "Critical: ${AUDIT_COUNTS[CRITICAL]}"
                echo "High: ${AUDIT_COUNTS[HIGH]}"
                echo "Medium: ${AUDIT_COUNTS[MEDIUM]}"
                echo "Low: ${AUDIT_COUNTS[LOW]}"
                echo "Info: ${AUDIT_COUNTS[INFO]}"
                echo ""
                echo "FINDINGS"
                echo "--------"
                for finding_id in "${!AUDIT_RESULTS[@]}"; do
                    echo "${AUDIT_RESULTS[$finding_id]}" | python3 -m json.tool 2>/dev/null || echo "${AUDIT_RESULTS[$finding_id]}"
                    echo ""
                done
            } > "$report_file"
            ;;
    esac
    
    log "Audit report generated: $report_file"
    echo "Report saved to: $report_file"
}

# Send notifications for critical findings
send_notifications() {
    if [ "$NOTIFY_ON_CRITICAL" = "true" ] && [ ${AUDIT_COUNTS[CRITICAL]} -gt 0 ]; then
        local message="CRITICAL: Found ${AUDIT_COUNTS[CRITICAL]} critical security issues in GRIM audit"
        if [ -x "$NOTIFY_MODULE" ]; then
            "$NOTIFY_MODULE" send critical "Security Audit Alert" "$message" \
                "{\"critical\": ${AUDIT_COUNTS[CRITICAL]}, \"high\": ${AUDIT_COUNTS[HIGH]}, \"medium\": ${AUDIT_COUNTS[MEDIUM]}}"
        fi
    fi
    
    if [ "$NOTIFY_ON_HIGH" = "true" ] && [ ${AUDIT_COUNTS[HIGH]} -gt 0 ]; then
        local message="HIGH: Found ${AUDIT_COUNTS[HIGH]} high priority security issues in GRIM audit"
        if [ -x "$NOTIFY_MODULE" ]; then
            "$NOTIFY_MODULE" send warning "Security Audit Alert" "$message" \
                "{\"critical\": ${AUDIT_COUNTS[CRITICAL]}, \"high\": ${AUDIT_COUNTS[HIGH]}, \"medium\": ${AUDIT_COUNTS[MEDIUM]}}"
        fi
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Security Audit Module${NC}"
    echo "Usage: grim audit <command> [options]"
    echo ""
    echo "Commands:"
    echo "  full                    - Complete security audit"
    echo "  permissions [path]      - Check file permissions and ownership"
    echo "  compliance [standard]   - Run compliance checks (CIS, STIG, NIST)"
    echo "  backups [path]          - Verify backup integrity and checksums"
    echo "  logs [logfile]          - Analyze access logs for suspicious activity"
    echo "  config [path]           - Review configuration security"
    echo "  report [format]         - Generate security report (text|json)"
    echo "  help                    - Show this help"
    echo ""
    echo "Options:"
    echo "  --verbose               - Enable verbose output"
    echo "  --limit <number>        - Limit findings per category (default: $MAX_FINDINGS_PER_CATEGORY)"
    echo "  --timeout <seconds>     - Set scan timeout (default: $SCAN_TIMEOUT)"
    echo "  --format <type>         - Report format: text, json"
    echo ""
    echo "Examples:"
    echo "  grim audit full"
    echo "  grim audit permissions /opt/grim"
    echo "  grim audit compliance CIS"
    echo "  grim audit backups $GRIM_ROOT/backups"
    echo "  grim audit logs /var/log/auth.log"
    echo "  grim audit config $GRIM_ROOT/config"
    echo "  grim audit report json"
    echo ""
    echo "Configuration: $CONFIG_FILE"
}

# Main function
main() {
    local AUDIT_START_TIME=$(date +%s)
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --limit)
                MAX_FINDINGS_PER_CATEGORY="$2"
                shift 2
                ;;
            --timeout)
                SCAN_TIMEOUT="$2"
                shift 2
                ;;
            --format)
                REPORT_FORMAT="$2"
                shift 2
                ;;
            -*)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Load configuration
    load_config
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")" "$AUDIT_REPORTS_DIR"
    
    log "Security audit started with command: ${1:-help}"
    
    case "${1:-help}" in
        "full")
            echo -e "${PURPLE}💀 Grimm Security Audit - Full Scan 💀${NC}"
            echo "Scan limits: Max $MAX_FINDINGS_PER_CATEGORY findings per category, $SCAN_TIMEOUT second timeout"
            audit_permissions "${2:-$GRIM_ROOT}"
            audit_compliance
            audit_backup_integrity
            audit_access_logs
            audit_config_security
            generate_report "${REPORT_FORMAT:-text}"
            generate_report "json"
            send_notifications
            ;;
        "permissions")
            audit_permissions "${2:-$GRIM_ROOT}"
            ;;
        "compliance")
            audit_compliance
            ;;
        "backups")
            audit_backup_integrity
            ;;
        "logs")
            audit_access_logs
            ;;
        "config")
            audit_config_security
            ;;
        "report")
            generate_report "${2:-text}"
            ;;
        "help"|*)
            show_help
            ;;
    esac
    
    local AUDIT_END_TIME=$(date +%s)
    local AUDIT_DURATION=$((AUDIT_END_TIME - AUDIT_START_TIME))
    
    log "Security audit completed in ${AUDIT_DURATION} seconds"
    
    # Print summary
    echo -e "\n${PURPLE}=== Audit Summary ===${NC}"
    echo "Duration: ${AUDIT_DURATION} seconds"
    echo "Critical: ${AUDIT_COUNTS[CRITICAL]}"
    echo "High: ${AUDIT_COUNTS[HIGH]}"
    echo "Medium: ${AUDIT_COUNTS[MEDIUM]}"
    echo "Low: ${AUDIT_COUNTS[LOW]}"
    echo "Info: ${AUDIT_COUNTS[INFO]}"
    echo "Total: $((AUDIT_COUNTS[CRITICAL] + AUDIT_COUNTS[HIGH] + AUDIT_COUNTS[MEDIUM] + AUDIT_COUNTS[LOW] + AUDIT_COUNTS[INFO]))"
}

# Run main function
main "$@" 