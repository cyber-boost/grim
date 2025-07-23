#!/bin/bash

# Grim Security - Advanced Security Integration and Hooks
# Provides comprehensive security features for the Grimm system

# Source reaper.sh for utilities and colors
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GRIM_ROOT="${GRIM_ROOT:-$(dirname "$SCRIPT_DIR")}"
source "$GRIM_ROOT/reaper.sh" 2>/dev/null || source /opt/grim/reaper.sh 2>/dev/null

SECURITY_VERSION="1.0.0"
SECURITY_CONFIG="${GRIM_CONFIG_DIR}/security.tsk"
SECURITY_DB="${GRIM_DB_DIR}/security.db"
SECURITY_LOG="${GRIM_LOG_DIR}/security.log"
SECURITY_PID="${GRIM_RUN_DIR}/security.pid"
SECURITY_KEYS="${GRIM_CONFIG_DIR}/keys"
SECURITY_CERTS="${GRIM_CONFIG_DIR}/certs"

# Initialize security database
init_security_db() {
    sqlite3 "$SECURITY_DB" <<EOF
CREATE TABLE IF NOT EXISTS access_control (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    resource_type TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    user_id TEXT,
    permission TEXT NOT NULL,
    granted_by TEXT,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    active BOOLEAN DEFAULT TRUE,
    UNIQUE(resource_type, resource_id, user_id, permission)
);

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    details TEXT,
    ip_address TEXT,
    user_agent TEXT,
    success BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS security_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    source TEXT NOT NULL,
    details TEXT,
    ip_address TEXT,
    user_agent TEXT,
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS encryption_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT UNIQUE NOT NULL,
    key_type TEXT NOT NULL,
    key_data TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS ssl_certificates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL,
    cert_file TEXT NOT NULL,
    key_file TEXT NOT NULL,
    expires_at TIMESTAMP,
    auto_renew BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_access_control_resource ON access_control(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_access_control_user ON access_control(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity);
CREATE INDEX IF NOT EXISTS idx_encryption_keys_id ON encryption_keys(key_id);
CREATE INDEX IF NOT EXISTS idx_ssl_certificates_domain ON ssl_certificates(domain);
EOF
}

# Access control functions
check_permission() {
    local user_id="$1"
    local resource_type="$2"
    local resource_id="$3"
    local permission="$4"
    
    # Check if user has explicit permission
    local has_permission=$(sqlite3 "$SECURITY_DB" "
        SELECT COUNT(*) FROM access_control 
        WHERE user_id = '$user_id' 
        AND resource_type = '$resource_type' 
        AND resource_id = '$resource_id' 
        AND permission = '$permission' 
        AND active = 1 
        AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
    ")
    
    if [[ "$has_permission" -gt 0 ]]; then
        return 0
    fi
    
    # Check for wildcard permissions
    local wildcard_permission=$(sqlite3 "$SECURITY_DB" "
        SELECT COUNT(*) FROM access_control 
        WHERE user_id = '$user_id' 
        AND resource_type = '$resource_type' 
        AND resource_id = '*' 
        AND permission = '$permission' 
        AND active = 1 
        AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
    ")
    
    if [[ "$wildcard_permission" -gt 0 ]]; then
        return 0
    fi
    
    return 1
}

grant_permission() {
    local user_id="$1"
    local resource_type="$2"
    local resource_id="$3"
    local permission="$4"
    local granted_by="$5"
    local expires_days="${6:-}"
    
    local expires_clause=""
    if [[ -n "$expires_days" ]]; then
        expires_clause=", expires_at = datetime('now', '+$expires_days days')"
    fi
    
    sqlite3 "$SECURITY_DB" <<EOF
INSERT OR REPLACE INTO access_control (user_id, resource_type, resource_id, permission, granted_by$expires_clause)
VALUES ('$user_id', '$resource_type', '$resource_id', '$permission', '$granted_by'$expires_clause);
EOF
    
    log_security_event "permission_granted" "low" "security" "Permission granted: $permission on $resource_type:$resource_id to $user_id"
}

revoke_permission() {
    local user_id="$1"
    local resource_type="$2"
    local resource_id="$3"
    local permission="$4"
    
    sqlite3 "$SECURITY_DB" "UPDATE access_control SET active = 0 WHERE user_id = '$user_id' AND resource_type = '$resource_type' AND resource_id = '$resource_id' AND permission = '$permission'"
    
    log_security_event "permission_revoked" "medium" "security" "Permission revoked: $permission on $resource_type:$resource_id from $user_id"
}

# Audit logging
log_audit_event() {
    local user_id="$1"
    local action="$2"
    local resource_type="$3"
    local resource_id="$4"
    local details="$5"
    local success="${6:-true}"
    
    local ip_address=$(get_client_ip)
    local user_agent=$(get_user_agent)
    
    sqlite3 "$SECURITY_DB" <<EOF
INSERT INTO audit_log (user_id, action, resource_type, resource_id, details, ip_address, user_agent, success)
VALUES ('$user_id', '$action', '$resource_type', '$resource_id', '$details', '$ip_address', '$user_agent', '$success');
EOF
}

# Security event logging
log_security_event() {
    local event_type="$1"
    local severity="$2"
    local source="$3"
    local details="$4"
    
    local ip_address=$(get_client_ip)
    local user_agent=$(get_user_agent)
    
    sqlite3 "$SECURITY_DB" <<EOF
INSERT INTO security_events (event_type, severity, source, details, ip_address, user_agent)
VALUES ('$event_type', '$severity', '$source', '$details', '$ip_address', '$user_agent');
EOF
    
    # Log to security log file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $severity: $event_type - $details" >> "$SECURITY_LOG"
    
    # Trigger alerts for high severity events
    if [[ "$severity" == "high" ]] || [[ "$severity" == "critical" ]]; then
        trigger_security_alert "$event_type" "$severity" "$details"
    fi
}

# Get client information
get_client_ip() {
    # Try to get real IP from various headers
    local ip="${HTTP_X_FORWARDED_FOR:-${HTTP_X_REAL_IP:-${REMOTE_ADDR:-unknown}}}"
    echo "$ip" | cut -d',' -f1 | tr -d ' '
}

get_user_agent() {
    echo "${HTTP_USER_AGENT:-unknown}" | tr -d "'"
}

# Security alert system
trigger_security_alert() {
    local event_type="$1"
    local severity="$2"
    local details="$3"
    
    # Send to notification system
    if [[ -f "$GRIM_ROOT/sh_grim/notify.sh" ]]; then
        "$GRIM_ROOT/sh_grim/notify.sh" send security "$severity" "$event_type" "$details"
    fi
    
    # Send to Grim command interface
    echo "${RED}🚨 SECURITY ALERT: $severity - $event_type${RESET}"
    echo "   Details: $details"
    echo "   Time: $(date)"
    echo
}

# Encryption key management
generate_encryption_key() {
    local key_id="$1"
    local key_type="${2:-aes256}"
    local expires_days="${3:-365}"
    
    # Generate random key
    local key_data=$(openssl rand -hex 32)
    
    sqlite3 "$SECURITY_DB" <<EOF
INSERT OR REPLACE INTO encryption_keys (key_id, key_type, key_data, expires_at)
VALUES ('$key_id', '$key_type', '$key_data', datetime('now', '+$expires_days days'));
EOF
    
    echo "${GREEN}✓ Encryption key generated: $key_id${RESET}"
}

get_encryption_key() {
    local key_id="$1"
    
    local key_data=$(sqlite3 "$SECURITY_DB" "SELECT key_data FROM encryption_keys WHERE key_id = '$key_id' AND active = 1 AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)")
    
    if [[ -n "$key_data" ]]; then
        echo "$key_data"
        return 0
    else
        return 1
    fi
}

# File encryption/decryption
encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key_id="$3"
    
    local key_data=$(get_encryption_key "$key_id")
    if [[ $? -ne 0 ]]; then
        echo "${RED}Error: Invalid or expired encryption key: $key_id${RESET}"
        return 1
    fi
    
    # Encrypt file using AES-256
    openssl enc -aes-256-cbc -salt -in "$input_file" -out "$output_file" -k "$key_data" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ File encrypted: $input_file -> $output_file${RESET}"
        log_audit_event "system" "file_encrypted" "file" "$input_file" "Encrypted with key: $key_id"
    else
        echo "${RED}Error: Failed to encrypt file${RESET}"
        return 1
    fi
}

decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local key_id="$3"
    
    local key_data=$(get_encryption_key "$key_id")
    if [[ $? -ne 0 ]]; then
        echo "${RED}Error: Invalid or expired encryption key: $key_id${RESET}"
        return 1
    fi
    
    # Decrypt file using AES-256
    openssl enc -aes-256-cbc -d -in "$input_file" -out "$output_file" -k "$key_data" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ File decrypted: $input_file -> $output_file${RESET}"
        log_audit_event "system" "file_decrypted" "file" "$input_file" "Decrypted with key: $key_id"
    else
        echo "${RED}Error: Failed to decrypt file${RESET}"
        return 1
    fi
}

# SSL certificate management
install_ssl_certificate() {
    local domain="$1"
    local cert_file="$2"
    local key_file="$3"
    local auto_renew="${4:-true}"
    
    # Validate certificate
    if [[ ! -f "$cert_file" ]] || [[ ! -f "$key_file" ]]; then
        echo "${RED}Error: Certificate or key file not found${RESET}"
        return 1
    fi
    
    # Get certificate expiration
    local expires_at=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d'=' -f2)
    if [[ -z "$expires_at" ]]; then
        echo "${RED}Error: Invalid certificate file${RESET}"
        return 1
    fi
    
    # Convert to SQLite format
    local sqlite_expires=$(date -d "$expires_at" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    
    sqlite3 "$SECURITY_DB" <<EOF
INSERT OR REPLACE INTO ssl_certificates (domain, cert_file, key_file, expires_at, auto_renew)
VALUES ('$domain', '$cert_file', '$key_file', '$sqlite_expires', '$auto_renew');
EOF
    
    echo "${GREEN}✓ SSL certificate installed for $domain${RESET}"
    echo "  Expires: $expires_at"
    echo "  Auto-renew: $auto_renew"
}

check_ssl_certificates() {
    local expired_certs=$(sqlite3 "$SECURITY_DB" "
        SELECT domain, expires_at FROM ssl_certificates 
        WHERE expires_at < datetime('now', '+30 days') 
        AND auto_renew = 1
    ")
    
    if [[ -n "$expired_certs" ]]; then
        echo "${YELLOW}⚠ SSL certificates expiring soon:${RESET}"
        echo "$expired_certs" | while IFS='|' read -r domain expires_at; do
            echo "  $domain expires: $expires_at"
        done
        
        # Trigger renewal process
        renew_ssl_certificates
    else
        echo "${GREEN}✓ All SSL certificates are valid${RESET}"
    fi
}

renew_ssl_certificates() {
    local expiring_certs=$(sqlite3 "$SECURITY_DB" "
        SELECT domain, cert_file, key_file FROM ssl_certificates 
        WHERE expires_at < datetime('now', '+30 days') 
        AND auto_renew = 1
    ")
    
    if [[ -n "$expiring_certs" ]]; then
        echo "${CYAN}Renewing SSL certificates...${RESET}"
        
        echo "$expiring_certs" | while IFS='|' read -r domain cert_file key_file; do
            echo "Renewing certificate for $domain..."
            
            # Use Let's Encrypt if certbot is available
            if command -v certbot >/dev/null 2>&1; then
                certbot renew --cert-name "$domain" --quiet
                if [[ $? -eq 0 ]]; then
                    echo "${GREEN}✓ Certificate renewed for $domain${RESET}"
                    log_audit_event "system" "ssl_renewed" "ssl" "$domain" "Certificate auto-renewed"
                else
                    echo "${RED}✗ Failed to renew certificate for $domain${RESET}"
                    log_security_event "ssl_renewal_failed" "high" "security" "Failed to renew SSL certificate for $domain"
                fi
            else
                echo "${YELLOW}⚠ certbot not available, manual renewal required for $domain${RESET}"
                log_security_event "ssl_manual_renewal" "medium" "security" "Manual SSL renewal required for $domain"
            fi
        done
    fi
}

# Security monitoring
start_security_monitoring() {
    if [[ -f "$SECURITY_PID" ]]; then
        local pid=$(cat "$SECURITY_PID" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            echo "${YELLOW}⚠ Security monitoring already running (PID: $pid)${RESET}"
            return 0
        fi
    fi
    
    # Start monitoring in background
    (
        while true; do
            # Check for security events
            check_security_events
            
            # Check SSL certificates
            check_ssl_certificates
            
            # Check for suspicious activity
            check_suspicious_activity
            
            # Sleep for 5 minutes
            sleep 300
        done
    ) &
    
    echo $! > "$SECURITY_PID"
    echo "${GREEN}✓ Security monitoring started${RESET}"
}

stop_security_monitoring() {
    if [[ -f "$SECURITY_PID" ]]; then
        local pid=$(cat "$SECURITY_PID" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$SECURITY_PID"
            echo "${GREEN}✓ Security monitoring stopped${RESET}"
        else
            echo "${YELLOW}⚠ Security monitoring not running${RESET}"
        fi
    else
        echo "${YELLOW}⚠ No security monitoring PID file found${RESET}"
    fi
}

check_security_events() {
    local recent_events=$(sqlite3 "$SECURITY_DB" "
        SELECT event_type, severity, details, created_at 
        FROM security_events 
        WHERE created_at > datetime('now', '-1 hour') 
        AND resolved = 0
        ORDER BY created_at DESC
    ")
    
    if [[ -n "$recent_events" ]]; then
        echo "${YELLOW}=== Recent Security Events ===${RESET}"
        echo "$recent_events" | while IFS='|' read -r event_type severity details created_at; do
            echo "[$created_at] $severity: $event_type - $details"
        done
    fi
}

check_suspicious_activity() {
    # Check for multiple failed login attempts
    local failed_logins=$(sqlite3 "$SECURITY_DB" "
        SELECT user_id, COUNT(*) as attempts 
        FROM audit_log 
        WHERE action = 'login_failed' 
        AND created_at > datetime('now', '-1 hour')
        GROUP BY user_id 
        HAVING attempts > 5
    ")
    
    if [[ -n "$failed_logins" ]]; then
        echo "$failed_logins" | while IFS='|' read -r user_id attempts; do
            log_security_event "brute_force_attempt" "high" "security" "Multiple failed login attempts for user: $user_id ($attempts attempts)"
        done
    fi
    
    # Check for unusual access patterns
    local unusual_access=$(sqlite3 "$SECURITY_DB" "
        SELECT user_id, COUNT(*) as accesses 
        FROM audit_log 
        WHERE created_at > datetime('now', '-1 hour')
        GROUP BY user_id 
        HAVING accesses > 100
    ")
    
    if [[ -n "$unusual_access" ]]; then
        echo "$unusual_access" | while IFS='|' read -r user_id accesses; do
            log_security_event "unusual_activity" "medium" "security" "Unusual access pattern for user: $user_id ($accesses accesses in 1 hour)"
        done
    fi
}

# Security report generation
generate_security_report() {
    local report_type="${1:-summary}"
    local days="${2:-7}"
    
    case "$report_type" in
        summary)
            echo "${GREEN}=== Security Summary (Last $days days) ===${RESET}"
            
            local total_events=$(sqlite3 "$SECURITY_DB" "
                SELECT COUNT(*) FROM security_events 
                WHERE created_at > datetime('now', '-$days days')
            ")
            
            local high_events=$(sqlite3 "$SECURITY_DB" "
                SELECT COUNT(*) FROM security_events 
                WHERE created_at > datetime('now', '-$days days') 
                AND severity IN ('high', 'critical')
            ")
            
            local total_audits=$(sqlite3 "$SECURITY_DB" "
                SELECT COUNT(*) FROM audit_log 
                WHERE created_at > datetime('now', '-$days days')
            ")
            
            echo "Total Security Events: $total_events"
            echo "High/Critical Events: $high_events"
            echo "Total Audit Entries: $total_audits"
            ;;
            
        events)
            echo "${RED}=== Security Events (Last $days days) ===${RESET}"
            sqlite3 "$SECURITY_DB" "
                SELECT event_type, severity, details, created_at 
                FROM security_events 
                WHERE created_at > datetime('now', '-$days days')
                ORDER BY created_at DESC
                LIMIT 50
            "
            ;;
            
        audit)
            echo "${BLUE}=== Audit Log (Last $days days) ===${RESET}"
            sqlite3 "$SECURITY_DB" "
                SELECT user_id, action, resource_type, resource_id, success, created_at 
                FROM audit_log 
                WHERE created_at > datetime('now', '-$days days')
                ORDER BY created_at DESC
                LIMIT 50
            "
            ;;
            
        permissions)
            echo "${CYAN}=== Active Permissions ===${RESET}"
            sqlite3 "$SECURITY_DB" "
                SELECT user_id, resource_type, resource_id, permission, granted_at, expires_at 
                FROM access_control 
                WHERE active = 1 
                ORDER BY granted_at DESC
            "
            ;;
            
        ssl)
            echo "${MAGENTA}=== SSL Certificates ===${RESET}"
            sqlite3 "$SECURITY_DB" "
                SELECT domain, expires_at, auto_renew, created_at 
                FROM ssl_certificates 
                ORDER BY expires_at ASC
            "
            ;;
            
        *)
            echo "${RED}Unknown report type: $report_type${RESET}"
            echo "Available types: summary, events, audit, permissions, ssl"
            ;;
    esac
}

# Security hooks for other modules
security_hook_pre_action() {
    local user_id="$1"
    local action="$2"
    local resource_type="$3"
    local resource_id="$4"
    
    # Check permissions
    if ! check_permission "$user_id" "$resource_type" "$resource_id" "$action"; then
        log_security_event "permission_denied" "medium" "security" "Permission denied: $user_id tried to $action on $resource_type:$resource_id"
        return 1
    fi
    
    # Log the action
    log_audit_event "$user_id" "$action" "$resource_type" "$resource_id" "Pre-action hook"
    return 0
}

security_hook_post_action() {
    local user_id="$1"
    local action="$2"
    local resource_type="$3"
    local resource_id="$4"
    local success="$5"
    
    # Log the result
    log_audit_event "$user_id" "$action" "$resource_type" "$resource_id" "Post-action hook" "$success"
}

# Display help
help() {
    cat <<EOF
${GREEN}Grim Security v$SECURITY_VERSION - Advanced Security Integration${RESET}

Usage: $0 [command] [options]

Commands:
  init                                           Initialize security database
  monitor start|stop                             Start/stop security monitoring
  permission grant <user> <type> <id> <perm>    Grant permission to user
  permission revoke <user> <type> <id> <perm>   Revoke permission from user
  permission check <user> <type> <id> <perm>    Check user permission
  encrypt <input> <output> <key_id>             Encrypt file
  decrypt <input> <output> <key_id>             Decrypt file
  key generate <key_id> [type] [days]           Generate encryption key
  ssl install <domain> <cert> <key> [renew]     Install SSL certificate
  ssl check                                      Check SSL certificate status
  ssl renew                                      Renew expiring certificates
  report [type] [days]                          Generate security report
  hook pre <user> <action> <type> <id>          Pre-action security hook
  hook post <user> <action> <type> <id> [success] Post-action security hook
  
Report Types:
  summary        - Security overview
  events         - Security events
  audit          - Audit log entries
  permissions    - Active permissions
  ssl            - SSL certificates

Options:
  -h, --help                Show this help message
  -v, --verbose             Verbose output
  -d, --debug               Debug mode

Examples:
  $0 init
  $0 monitor start
  $0 permission grant admin backup * read
  $0 encrypt sensitive.txt sensitive.enc backup_key
  $0 ssl install example.com cert.pem key.pem
  $0 report events 30
  
Security Features:
  - Access control with fine-grained permissions
  - Comprehensive audit logging
  - Security event monitoring and alerting
  - File encryption/decryption with key management
  - SSL certificate management with auto-renewal
  - Suspicious activity detection
  - Integration hooks for other modules
EOF
}

# Main command handler
case "${1:-help}" in
    init)
        init_security_db
        echo "${GREEN}✓ Security database initialized${RESET}"
        ;;
    monitor)
        case "${2:-}" in
            start)
                start_security_monitoring
                ;;
            stop)
                stop_security_monitoring
                ;;
            *)
                echo "${RED}Usage: $0 monitor start|stop${RESET}"
                exit 1
                ;;
        esac
        ;;
    permission)
        case "${2:-}" in
            grant)
                shift 2
                grant_permission "$@"
                ;;
            revoke)
                shift 2
                revoke_permission "$@"
                ;;
            check)
                shift 2
                if check_permission "$@"; then
                    echo "${GREEN}✓ Permission granted${RESET}"
                else
                    echo "${RED}✗ Permission denied${RESET}"
                fi
                ;;
            *)
                echo "${RED}Usage: $0 permission grant|revoke|check${RESET}"
                exit 1
                ;;
        esac
        ;;
    encrypt)
        shift
        encrypt_file "$@"
        ;;
    decrypt)
        shift
        decrypt_file "$@"
        ;;
    key)
        case "${2:-}" in
            generate)
                shift 2
                generate_encryption_key "$@"
                ;;
            *)
                echo "${RED}Usage: $0 key generate <key_id> [type] [days]${RESET}"
                exit 1
                ;;
        esac
        ;;
    ssl)
        case "${2:-}" in
            install)
                shift 2
                install_ssl_certificate "$@"
                ;;
            check)
                check_ssl_certificates
                ;;
            renew)
                renew_ssl_certificates
                ;;
            *)
                echo "${RED}Usage: $0 ssl install|check|renew${RESET}"
                exit 1
                ;;
        esac
        ;;
    report)
        shift
        generate_security_report "$@"
        ;;
    hook)
        case "${2:-}" in
            pre)
                shift 2
                security_hook_pre_action "$@"
                ;;
            post)
                shift 2
                security_hook_post_action "$@"
                ;;
            *)
                echo "${RED}Usage: $0 hook pre|post${RESET}"
                exit 1
                ;;
        esac
        ;;
    help|-h|--help)
        help
        ;;
    *)
        echo "${RED}Unknown command: $1${RESET}"
        help
        exit 1
        ;;
esac 