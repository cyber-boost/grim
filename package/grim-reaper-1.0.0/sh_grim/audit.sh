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

# Add audit finding
add_finding() {
    local severity="$1"
    local category="$2"
    local title="$3"
    local description="$4"
    local recommendation="$5"
    local evidence="$6"
    
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

# Permission auditing
audit_permissions() {
    local scan_path="${1:-$GRIM_ROOT}"
    log "Starting permission audit for: $scan_path"
    
    echo -e "\n${PURPLE}=== Permission Audit ===${NC}"
    
    # Check for world-writable files
    if [ "$WORLD_WRITABLE_CHECK" = "true" ]; then
        echo "Checking for world-writable files..."
        find "$scan_path" -type f -perm -002 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file" 2>/dev/null)
            local owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
            add_finding "HIGH" "permissions" "World-writable file found" \
                "File $file has world-write permissions" \
                "Remove world-write permissions: chmod o-w '$file'" \
                "File: $file, Permissions: $perms, Owner: $owner"
        done
    fi
    
    # Check for incorrect ownership
    if [ "$INCORRECT_OWNERSHIP_CHECK" = "true" ]; then
        echo "Checking file ownership..."
        find "$scan_path" -type f 2>/dev/null | while read -r file; do
            local owner=$(stat -c "%U" "$file" 2>/dev/null)
            local group=$(stat -c "%G" "$file" 2>/dev/null)
            
            # Check if owned by root but shouldn't be
            if [ "$owner" = "root" ] && [[ "$file" != *"/etc/"* ]] && [[ "$file" != *"/var/log/"* ]]; then
                add_finding "MEDIUM" "permissions" "File owned by root" \
                    "File $file is owned by root but may not need to be" \
                    "Consider changing ownership to appropriate user: chown user:group '$file'" \
                    "File: $file, Owner: $owner:$group"
            fi
            
            # Check for world-readable sensitive files
            if [ -r "$file" ] && [[ "$file" =~ \.(key|pem|p12|pfx|conf|config|ini|env)$ ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null)
                if [[ "$perms" =~ ^[0-9][0-9][4-7]$ ]]; then
                    add_finding "CRITICAL" "permissions" "Sensitive file world-readable" \
                        "Sensitive file $file is world-readable" \
                        "Restrict permissions: chmod 600 '$file'" \
                        "File: $file, Permissions: $perms"
                fi
            fi
        done
    fi
    
    # Check for SUID/SGID files
    if [ "$SUID_SGID_CHECK" = "true" ]; then
        echo "Checking for SUID/SGID files..."
        find "$scan_path" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while read -r file; do
            local perms=$(stat -c "%a" "$file" 2>/dev/null)
            local owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
            add_finding "HIGH" "permissions" "SUID/SGID file found" \
                "File $file has SUID or SGID bit set" \
                "Review if SUID/SGID is necessary: chmod u-s,g-s '$file'" \
                "File: $file, Permissions: $perms, Owner: $owner"
        done
    fi
    
    # Check directory permissions
    echo "Checking directory permissions..."
    find "$scan_path" -type d 2>/dev/null | while read -r dir; do
        local perms=$(stat -c "%a" "$dir" 2>/dev/null)
        local owner=$(stat -c "%U:%G" "$dir" 2>/dev/null)
        
        # Check for world-writable directories
        if [[ "$perms" =~ ^[0-9][0-9][2-7]$ ]]; then
            add_finding "HIGH" "permissions" "World-writable directory" \
                "Directory $dir is world-writable" \
                "Restrict directory permissions: chmod 755 '$dir'" \
                "Directory: $dir, Permissions: $perms, Owner: $owner"
        fi
    done
}

# Security compliance checks
audit_compliance() {
    log "Starting compliance audit"
    
    echo -e "\n${PURPLE}=== Compliance Audit ===${NC}"
    
    # CIS Benchmark checks
    if [ "$CIS_BENCHMARK_CHECK" = "true" ]; then
        echo "Running CIS Benchmark checks..."
        
        # Check password policy
        if command -v passwd &> /dev/null; then
            local min_len=$(grep "^PASS_MIN_LEN" /etc/login.defs 2>/dev/null | awk '{print $2}')
            if [ -z "$min_len" ] || [ "$min_len" -lt 8 ]; then
                add_finding "MEDIUM" "compliance" "Weak password policy" \
                    "Minimum password length is less than 8 characters" \
                    "Set PASS_MIN_LEN=8 in /etc/login.defs" \
                    "Current minimum length: ${min_len:-not set}"
            fi
        fi
        
        # Check account lockout
        local lockout_enabled=$(grep -c "pam_tally2" /etc/pam.d/common-auth 2>/dev/null || echo 0)
        if [ "$lockout_enabled" -eq 0 ]; then
            add_finding "MEDIUM" "compliance" "No account lockout policy" \
                "No account lockout policy configured" \
                "Configure pam_tally2 in /etc/pam.d/common-auth" \
                "Account lockout not configured"
        fi
        
        # Check for unnecessary services
        local unnecessary_services=("telnet" "rsh" "rlogin" "rexec" "tftp")
        for service in "${unnecessary_services[@]}"; do
            if systemctl is-enabled "$service" &>/dev/null; then
                add_finding "HIGH" "compliance" "Unnecessary service enabled" \
                    "Service $service is enabled and should be disabled" \
                    "Disable service: systemctl disable $service" \
                    "Service: $service"
            fi
        done
    fi
    
    # STIG checks
    if [ "$STIG_CHECK" = "true" ]; then
        echo "Running STIG checks..."
        
        # Check for default accounts
        local default_accounts=("root" "admin" "guest" "test")
        for account in "${default_accounts[@]}"; do
            if id "$account" &>/dev/null; then
                add_finding "MEDIUM" "compliance" "Default account exists" \
                    "Default account $account exists on system" \
                    "Remove or secure default account: userdel $account" \
                    "Account: $account"
            fi
        done
        
        # Check file permissions on critical files
        local critical_files=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow")
        for file in "${critical_files[@]}"; do
            if [ -f "$file" ]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null)
                case "$file" in
                    "/etc/passwd")
                        if [ "$perms" != "644" ]; then
                            add_finding "CRITICAL" "compliance" "Incorrect /etc/passwd permissions" \
                                "/etc/passwd has incorrect permissions" \
                                "Set correct permissions: chmod 644 /etc/passwd" \
                                "Current permissions: $perms, Expected: 644"
                        fi
                        ;;
                    "/etc/shadow")
                        if [ "$perms" != "640" ]; then
                            add_finding "CRITICAL" "compliance" "Incorrect /etc/shadow permissions" \
                                "/etc/shadow has incorrect permissions" \
                                "Set correct permissions: chmod 640 /etc/shadow" \
                                "Current permissions: $perms, Expected: 640"
                        fi
                        ;;
                esac
            fi
        done
    fi
    
    # NIST checks
    if [ "$NIST_CHECK" = "true" ]; then
        echo "Running NIST checks..."
        
        # Check for encryption at rest
        local encrypted_partitions=$(lsblk -f 2>/dev/null | grep -c "crypt" || echo 0)
        if [ "$encrypted_partitions" -eq 0 ]; then
            add_finding "MEDIUM" "compliance" "No disk encryption detected" \
                "No encrypted partitions found on system" \
                "Consider implementing full disk encryption" \
                "Encrypted partitions: $encrypted_partitions"
        fi
        
        # Check for secure protocols
        local ssh_config="/etc/ssh/sshd_config"
        if [ -f "$ssh_config" ]; then
            local protocol_version=$(grep "^Protocol" "$ssh_config" 2>/dev/null | awk '{print $2}')
            if [ "$protocol_version" != "2" ]; then
                add_finding "CRITICAL" "compliance" "SSH Protocol 1 enabled" \
                    "SSH Protocol 1 is enabled and insecure" \
                    "Set Protocol 2 in $ssh_config" \
                    "Current protocol: $protocol_version"
            fi
        fi
    fi
}

# Backup integrity verification
audit_backup_integrity() {
    log "Starting backup integrity audit"
    
    echo -e "\n${PURPLE}=== Backup Integrity Audit ===${NC}"
    
    local backup_dir="$GRIM_ROOT/backups"
    if [ ! -d "$backup_dir" ]; then
        add_finding "INFO" "backup_integrity" "No backup directory found" \
            "Backup directory $backup_dir does not exist" \
            "Create backup directory or configure backup paths" \
            "Backup directory: $backup_dir"
        return
    fi
    
    echo "Checking backup integrity..."
    
    # Find all backup files
    find "$backup_dir" -type f \( -name "*.tar.gz" -o -name "*.enc" -o -name "*.dedup" \) 2>/dev/null | while read -r backup_file; do
        local filename=$(basename "$backup_file")
        local backup_age=$(( ($(date +%s) - $(stat -c %Y "$backup_file" 2>/dev/null)) / 86400 ))
        
        # Check backup age
        if [ "$backup_age" -gt "${BACKUP_AGE_CHECK_DAYS:-30}" ]; then
            add_finding "MEDIUM" "backup_integrity" "Old backup file" \
                "Backup file $filename is $backup_age days old" \
                "Consider creating fresh backup or archiving old backups" \
                "File: $filename, Age: $backup_age days"
        fi
        
        # Verify checksums if available
        if [ "$CHECKSUM_VERIFICATION" = "true" ]; then
            local checksum_file="${backup_file}.sha256"
            if [ -f "$checksum_file" ]; then
                if ! sha256sum -c "$checksum_file" >/dev/null 2>&1; then
                    add_finding "CRITICAL" "backup_integrity" "Backup checksum verification failed" \
                        "Backup file $filename failed checksum verification" \
                        "Backup may be corrupted - restore from another source" \
                        "File: $filename, Checksum file: $checksum_file"
                else
                    add_finding "INFO" "backup_integrity" "Backup checksum verified" \
                        "Backup file $filename passed checksum verification" \
                        "No action required" \
                        "File: $filename"
                fi
            else
                add_finding "MEDIUM" "backup_integrity" "No checksum file" \
                    "Backup file $filename has no checksum file" \
                    "Create checksum: sha256sum '$backup_file' > '${backup_file}.sha256'" \
                    "File: $filename"
            fi
        fi
        
        # Check file size (suspiciously small backups)
        local file_size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
        if [ "$file_size" -lt 1024 ]; then  # Less than 1KB
            add_finding "HIGH" "backup_integrity" "Suspiciously small backup" \
                "Backup file $filename is very small ($file_size bytes)" \
                "Verify backup creation process and content" \
                "File: $filename, Size: $file_size bytes"
        fi
    done
    
    # Check backup directory permissions
    local backup_dir_perms=$(stat -c "%a" "$backup_dir" 2>/dev/null)
    if [[ "$backup_dir_perms" =~ ^[0-9][0-9][2-7]$ ]]; then
        add_finding "HIGH" "backup_integrity" "Backup directory world-writable" \
            "Backup directory is world-writable" \
            "Restrict permissions: chmod 755 '$backup_dir'" \
            "Directory: $backup_dir, Permissions: $backup_dir_perms"
    fi
}

# Access log analysis
audit_access_logs() {
    log "Starting access log analysis"
    
    echo -e "\n${PURPLE}=== Access Log Analysis ===${NC}"
    
    if [ "$ACCESS_LOG_ANALYSIS" != "true" ]; then
        return
    fi
    
    echo "Analyzing access logs..."
    
    # Check for failed login attempts
    local failed_logins=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
    if [ "$failed_logins" -gt "${FAILED_LOGIN_THRESHOLD:-5}" ]; then
        add_finding "HIGH" "access_logs" "Multiple failed login attempts" \
            "Found $failed_logins failed login attempts in auth.log" \
            "Investigate potential brute force attack" \
            "Failed logins: $failed_logins, Threshold: ${FAILED_LOGIN_THRESHOLD:-5}"
    fi
    
    # Check for suspicious SSH activity
    local ssh_failures=$(grep -c "sshd.*Failed" /var/log/auth.log 2>/dev/null || echo 0)
    if [ "$ssh_failures" -gt 10 ]; then
        add_finding "CRITICAL" "access_logs" "High SSH failure rate" \
            "Found $ssh_failures SSH failures in auth.log" \
            "Consider implementing fail2ban or similar protection" \
            "SSH failures: $ssh_failures"
    fi
    
    # Check for unusual access patterns
    local recent_access=$(find /var/log -name "*.log" -mtime -1 2>/dev/null | wc -l)
    if [ "$recent_access" -eq 0 ]; then
        add_finding "MEDIUM" "access_logs" "No recent log activity" \
            "No log files modified in the last 24 hours" \
            "Verify logging is working correctly" \
            "Recent log files: $recent_access"
    fi
    
    # Check for log rotation issues
    local large_logs=$(find /var/log -name "*.log" -size +100M 2>/dev/null | wc -l)
    if [ "$large_logs" -gt 0 ]; then
        add_finding "MEDIUM" "access_logs" "Large log files detected" \
            "Found $large_logs log files larger than 100MB" \
            "Configure log rotation to prevent disk space issues" \
            "Large log files: $large_logs"
    fi
}

# Configuration security review
audit_config_security() {
    log "Starting configuration security audit"
    
    echo -e "\n${PURPLE}=== Configuration Security Audit ===${NC}"
    
    if [ "$CONFIG_SECURITY_CHECK" != "true" ]; then
        return
    fi
    
    echo "Checking configuration security..."
    
    # Scan for hardcoded credentials
    if [ "$CREDENTIAL_SCAN" = "true" ]; then
        echo "Scanning for hardcoded credentials..."
        
        # Common credential patterns
        local credential_patterns=(
            "password.*=.*['\"][^'\"]*['\"]"
            "passwd.*=.*['\"][^'\"]*['\"]"
            "secret.*=.*['\"][^'\"]*['\"]"
            "key.*=.*['\"][^'\"]*['\"]"
            "token.*=.*['\"][^'\"]*['\"]"
            "api_key.*=.*['\"][^'\"]*['\"]"
        )
        
        for pattern in "${credential_patterns[@]}"; do
            find "$GRIM_ROOT" -type f \( -name "*.sh" -o -name "*.conf" -o -name "*.config" -o -name "*.ini" \) 2>/dev/null | while read -r file; do
                if grep -q "$pattern" "$file" 2>/dev/null; then
                    local line=$(grep "$pattern" "$file" 2>/dev/null | head -1)
                    add_finding "HIGH" "config_security" "Hardcoded credential found" \
                        "Hardcoded credential found in $file" \
                        "Move credentials to secure configuration or environment variables" \
                        "File: $file, Pattern: $pattern, Line: $line"
                fi
            done
        done
    fi
    
    # Check for exposed configuration files
    if [ "$EXPOSED_CONFIGS_CHECK" = "true" ]; then
        echo "Checking for exposed configuration files..."
        
        local config_files=("$GRIM_ROOT/config/"*.conf "$GRIM_ROOT/config/"*.config)
        for config_file in "${config_files[@]}"; do
            if [ -f "$config_file" ]; then
                local perms=$(stat -c "%a" "$config_file" 2>/dev/null)
                if [[ "$perms" =~ ^[0-9][0-9][4-7]$ ]]; then
                    add_finding "HIGH" "config_security" "Exposed configuration file" \
                        "Configuration file $config_file is world-readable" \
                        "Restrict permissions: chmod 600 '$config_file'" \
                        "File: $config_file, Permissions: $perms"
                fi
            fi
        done
    fi
    
    # Check for insecure file permissions in config directory
    local config_dir="$GRIM_ROOT/config"
    if [ -d "$config_dir" ]; then
        local config_dir_perms=$(stat -c "%a" "$config_dir" 2>/dev/null)
        if [[ "$config_dir_perms" =~ ^[0-9][0-9][2-7]$ ]]; then
            add_finding "HIGH" "config_security" "Config directory world-writable" \
                "Configuration directory is world-writable" \
                "Restrict permissions: chmod 755 '$config_dir'" \
                "Directory: $config_dir, Permissions: $config_dir_perms"
        fi
    fi
    
    # Check for backup of sensitive files
    local sensitive_files=("$GRIM_ROOT/config/"*.key "$GRIM_ROOT/config/"*.pem "$GRIM_ROOT/config/"*.p12)
    for sensitive_file in "${sensitive_files[@]}"; do
        if [ -f "$sensitive_file" ]; then
            local backup_exists=false
            for backup_dir in "$GRIM_ROOT/backups"/*; do
                if [ -d "$backup_dir" ] && find "$backup_dir" -name "$(basename "$sensitive_file")" -type f | grep -q .; then
                    backup_exists=true
                    break
                fi
            done
            
            if [ "$backup_exists" = false ]; then
                add_finding "MEDIUM" "config_security" "Sensitive file not backed up" \
                    "Sensitive file $sensitive_file is not backed up" \
                    "Include sensitive files in backup strategy" \
                    "File: $sensitive_file"
            fi
        fi
    done
}

# Generate security report
generate_report() {
    local format="${1:-text}"
    local report_file="$AUDIT_REPORTS_DIR/audit_report_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$AUDIT_REPORTS_DIR"
    
    if [ "$format" = "json" ]; then
        generate_json_report "$report_file.json"
    else
        generate_text_report "$report_file.txt"
    fi
    
    log "Security report generated: $report_file.$format"
    echo "Security report generated: $report_file.$format"
}

# Generate text report
generate_text_report() {
    local report_file="$1"
    
    {
        echo "Grimm Security Audit Report"
        echo "=========================="
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "Audit Duration: $(($(date +%s) - AUDIT_START_TIME)) seconds"
        echo ""
        
        echo "Summary"
        echo "-------"
        echo "Critical Findings: ${AUDIT_COUNTS[CRITICAL]}"
        echo "High Findings: ${AUDIT_COUNTS[HIGH]}"
        echo "Medium Findings: ${AUDIT_COUNTS[MEDIUM]}"
        echo "Low Findings: ${AUDIT_COUNTS[LOW]}"
        echo "Info Findings: ${AUDIT_COUNTS[INFO]}"
        echo ""
        
        echo "Detailed Findings"
        echo "================="
        echo ""
        
        # Group findings by severity
        for severity in "CRITICAL" "HIGH" "MEDIUM" "LOW" "INFO"; do
            local count=0
            for finding_id in "${!AUDIT_RESULTS[@]}"; do
                local finding="${AUDIT_RESULTS[$finding_id]}"
                local finding_severity=$(echo "$finding" | jq -r '.severity' 2>/dev/null || echo "UNKNOWN")
                if [ "$finding_severity" = "$severity" ]; then
                    ((count++))
                    if [ $count -eq 1 ]; then
                        echo "$severity Findings"
                        echo "$(echo "$severity" | tr '[:upper:]' '[:lower:]' | sed 's/./=/g')"
                        echo ""
                    fi
                    
                    local title=$(echo "$finding" | jq -r '.title' 2>/dev/null)
                    local description=$(echo "$finding" | jq -r '.description' 2>/dev/null)
                    local recommendation=$(echo "$finding" | jq -r '.recommendation' 2>/dev/null)
                    local evidence=$(echo "$finding" | jq -r '.evidence' 2>/dev/null)
                    
                    echo "Title: $title"
                    echo "Description: $description"
                    echo "Recommendation: $recommendation"
                    echo "Evidence: $evidence"
                    echo ""
                fi
            done
        done
        
        echo "Recommendations"
        echo "==============="
        echo ""
        
        if [ "${AUDIT_COUNTS[CRITICAL]}" -gt 0 ]; then
            echo "CRITICAL: Address all critical findings immediately as they pose significant security risks."
        fi
        
        if [ "${AUDIT_COUNTS[HIGH]}" -gt 0 ]; then
            echo "HIGH: Address high-priority findings within 24-48 hours."
        fi
        
        if [ "${AUDIT_COUNTS[MEDIUM]}" -gt 0 ]; then
            echo "MEDIUM: Address medium-priority findings within 1 week."
        fi
        
        if [ "${AUDIT_COUNTS[LOW]}" -gt 0 ]; then
            echo "LOW: Address low-priority findings as time permits."
        fi
        
        echo ""
        echo "Next Steps"
        echo "=========="
        echo "1. Review all findings and prioritize based on severity"
        echo "2. Implement recommended fixes"
        echo "3. Re-run audit after implementing changes"
        echo "4. Schedule regular security audits"
        
    } > "$report_file"
}

# Generate JSON report
generate_json_report() {
    local report_file="$1"
    
    {
        echo "{"
        echo "  \"audit_report\": {"
        echo "    \"metadata\": {"
        echo "      \"generated\": \"$(date -Iseconds)\","
        echo "      \"hostname\": \"$(hostname)\","
        echo "      \"audit_duration_seconds\": $(($(date +%s) - AUDIT_START_TIME)),"
        echo "      \"grim_version\": \"$(cat "$GRIM_ROOT/VERSION" 2>/dev/null || echo "unknown")\""
        echo "    },"
        echo "    \"summary\": {"
        echo "      \"critical\": ${AUDIT_COUNTS[CRITICAL]},"
        echo "      \"high\": ${AUDIT_COUNTS[HIGH]},"
        echo "      \"medium\": ${AUDIT_COUNTS[MEDIUM]},"
        echo "      \"low\": ${AUDIT_COUNTS[LOW]},"
        echo "      \"info\": ${AUDIT_COUNTS[INFO]}"
        echo "    },"
        echo "    \"findings\": ["
        
        local first=true
        for finding_id in "${!AUDIT_RESULTS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            echo -n "      ${AUDIT_RESULTS[$finding_id]}"
        done
        
        echo ""
        echo "    ]"
        echo "  }"
        echo "}"
    } > "$report_file"
}

# Send notifications for critical findings
send_notifications() {
    if [ "${AUDIT_COUNTS[CRITICAL]}" -gt 0 ] && [ "$NOTIFY_ON_CRITICAL" = "true" ]; then
        "$NOTIFY_MODULE" send critical "Security Audit: Critical Findings" \
            "Found ${AUDIT_COUNTS[CRITICAL]} critical security issues" \
            "{\"critical\": ${AUDIT_COUNTS[CRITICAL]}, \"high\": ${AUDIT_COUNTS[HIGH]}, \"medium\": ${AUDIT_COUNTS[MEDIUM]}}"
    elif [ "${AUDIT_COUNTS[HIGH]}" -gt 0 ] && [ "$NOTIFY_ON_HIGH" = "true" ]; then
        "$NOTIFY_MODULE" send warning "Security Audit: High Priority Findings" \
            "Found ${AUDIT_COUNTS[HIGH]} high priority security issues" \
            "{\"critical\": ${AUDIT_COUNTS[CRITICAL]}, \"high\": ${AUDIT_COUNTS[HIGH]}, \"medium\": ${AUDIT_COUNTS[MEDIUM]}}"
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Security Audit Module${NC}"
    echo "Usage: ./audit.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  full                    - Complete security audit"
    echo "  permissions [path]      - Check file permissions"
    echo "  compliance             - Run compliance checks"
    echo "  backups                - Verify backup integrity"
    echo "  logs                   - Analyze access logs"
    echo "  config                 - Review configuration security"
    echo "  report [format]        - Generate security report (text|json)"
    echo "  help                   - Show this help"
    echo ""
    echo "Examples:"
    echo "  ./audit.sh full"
    echo "  ./audit.sh permissions /opt/grim"
    echo "  ./audit.sh report json"
    echo ""
    echo "Configuration: $CONFIG_FILE"
}

# Main function
main() {
    local AUDIT_START_TIME=$(date +%s)
    
    # Load configuration
    load_config
    
    # Create necessary directories
    mkdir -p "$(dirname "$LOG_FILE")" "$AUDIT_REPORTS_DIR"
    
    log "Security audit started"
    
    case "${1:-help}" in
        "full")
            echo -e "${PURPLE}💀 Grimm Security Audit - Full Scan 💀${NC}"
            audit_permissions
            audit_compliance
            audit_backup_integrity
            audit_access_logs
            audit_config_security
            generate_report "text"
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
    
    log "Security audit completed"
    
    # Print summary
    echo -e "\n${PURPLE}=== Audit Summary ===${NC}"
    echo "Critical: ${AUDIT_COUNTS[CRITICAL]}"
    echo "High: ${AUDIT_COUNTS[HIGH]}"
    echo "Medium: ${AUDIT_COUNTS[MEDIUM]}"
    echo "Low: ${AUDIT_COUNTS[LOW]}"
    echo "Info: ${AUDIT_COUNTS[INFO]}"
}

# Run main function
main "$@" 