#!/bin/bash
# Herald Alert System: Security alert management and notification

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
HERALD_DB="$GRIM_ROOT/db/herald.db"
HERALD_LOG="$GRIM_ROOT/logs/herald.log"
AUDIT_LOG="$GRIM_ROOT/logs/security_audit.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Alert configuration
ALERT_RETENTION_DAYS="${alert_retention_days:-30}"
ENABLE_EMAIL_ALERTS="${enable_email_alerts:-false}"
ENABLE_SMS_ALERTS="${enable_sms_alerts:-false}"
ENABLE_WEBHOOK_ALERTS="${enable_webhook_alerts:-false}"
ALERT_ESCALATION_TIME="${alert_escalation_time:-300}"

# Secure logging function
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HERALD_LOG"
}

# Security audit logging
audit_log() {
    local event_type="$1"
    local message="$2"
    local user="${SUDO_USER:-$USER}"
    local session_id="${SSH_SESSION_ID:-$(who am i | awk '{print $2}' | sed 's/[()]//g')}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUDIT] [$event_type] [$user] [$session_id] $message" >> "$AUDIT_LOG"
}

# Initialize Herald database
init_herald_db() {
    sqlite3 "$HERALD_DB" <<EOF
CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    message TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMP,
    resolved_at TIMESTAMP,
    status TEXT DEFAULT 'active',
    assigned_to TEXT,
    escalation_level INTEGER DEFAULT 0,
    notification_sent BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS alert_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_name TEXT NOT NULL,
    source_pattern TEXT,
    alert_type_pattern TEXT,
    severity_override TEXT,
    auto_acknowledge BOOLEAN DEFAULT FALSE,
    auto_resolve BOOLEAN DEFAULT FALSE,
    notification_channels TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notification_channels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_name TEXT NOT NULL,
    channel_type TEXT NOT NULL,
    config_data TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS alert_escalations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_id INTEGER,
    escalation_level INTEGER,
    escalated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    escalated_to TEXT,
    response TEXT,
    FOREIGN KEY (alert_id) REFERENCES alerts (id)
);

CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_source ON alerts(source);
CREATE INDEX IF NOT EXISTS idx_alerts_created ON alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_rules_name ON alert_rules(rule_name);
CREATE INDEX IF NOT EXISTS idx_channels_type ON notification_channels(channel_type);
EOF
    log "Herald database initialized"
    audit_log "DB_INIT" "Herald database initialized"
}

# Create alert
create_alert() {
    local source="$1"
    local alert_type="$2"
    local severity="$3"
    local message="$4"
    local details="${5:-}"
    
    # Apply alert rules
    local rule_result=$(apply_alert_rules "$source" "$alert_type" "$severity")
    if [[ -n "$rule_result" ]]; then
        severity=$(echo "$rule_result" | cut -d'|' -f1)
        local auto_acknowledge=$(echo "$rule_result" | cut -d'|' -f2)
        local auto_resolve=$(echo "$rule_result" | cut -d'|' -f3)
        local notification_channels=$(echo "$rule_result" | cut -d'|' -f4)
    fi
    
    # Insert alert
    local alert_id=$(sqlite3 "$HERALD_DB" <<EOF
INSERT INTO alerts (source, alert_type, severity, message, details)
VALUES ('$source', '$alert_type', '$severity', '$message', '$details');
SELECT last_insert_rowid();
EOF
)
    
    log "Alert created: ID $alert_id, Type: $alert_type, Severity: $severity"
    audit_log "ALERT_CREATED" "ID: $alert_id, Type: $alert_type, Severity: $severity, Source: $source"
    
    # Handle auto-actions
    if [[ "$auto_acknowledge" == "true" ]]; then
        acknowledge_alert "$alert_id" "auto"
    fi
    
    if [[ "$auto_resolve" == "true" ]]; then
        resolve_alert "$alert_id" "auto"
    fi
    
    # Send notifications
    if [[ -n "$notification_channels" ]]; then
        send_notifications "$alert_id" "$notification_channels"
    else
        send_notifications "$alert_id" "default"
    fi
    
    echo "$alert_id"
}

# Apply alert rules
apply_alert_rules() {
    local source="$1"
    local alert_type="$2"
    local severity="$3"
    
    sqlite3 "$HERALD_DB" "SELECT severity_override, auto_acknowledge, auto_resolve, notification_channels FROM alert_rules WHERE enabled = 1 AND (source_pattern IS NULL OR '$source' LIKE source_pattern) AND (alert_type_pattern IS NULL OR '$alert_type' LIKE alert_type_pattern) ORDER BY id DESC LIMIT 1" | while IFS='|' read -r severity_override auto_acknowledge auto_resolve notification_channels; do
        if [[ -n "$severity_override" ]]; then
            severity="$severity_override"
        fi
        echo "${severity}|${auto_acknowledge}|${auto_resolve}|${notification_channels}"
        break
    done
}

# Acknowledge alert
acknowledge_alert() {
    local alert_id="$1"
    local acknowledged_by="${2:-manual}"
    
    sqlite3 "$HERALD_DB" <<EOF
UPDATE alerts SET acknowledged_at = CURRENT_TIMESTAMP, status = 'acknowledged' WHERE id = $alert_id;
EOF
    
    log "Alert acknowledged: ID $alert_id by $acknowledged_by"
    audit_log "ALERT_ACKNOWLEDGED" "ID: $alert_id, By: $acknowledged_by"
}

# Resolve alert
resolve_alert() {
    local alert_id="$1"
    local resolved_by="${2:-manual}"
    
    sqlite3 "$HERALD_DB" <<EOF
UPDATE alerts SET resolved_at = CURRENT_TIMESTAMP, status = 'resolved' WHERE id = $alert_id;
EOF
    
    log "Alert resolved: ID $alert_id by $resolved_by"
    audit_log "ALERT_RESOLVED" "ID: $alert_id, By: $resolved_by"
}

# Escalate alert
escalate_alert() {
    local alert_id="$1"
    local escalation_level="$2"
    local escalated_to="$3"
    
    sqlite3 "$HERALD_DB" <<EOF
INSERT INTO alert_escalations (alert_id, escalation_level, escalated_to)
VALUES ($alert_id, $escalation_level, '$escalated_to');
UPDATE alerts SET escalation_level = $escalation_level WHERE id = $alert_id;
EOF
    
    log "Alert escalated: ID $alert_id to level $escalation_level ($escalated_to)"
    audit_log "ALERT_ESCALATED" "ID: $alert_id, Level: $escalation_level, To: $escalated_to"
}

# Send notifications
send_notifications() {
    local alert_id="$1"
    local channels="$2"
    
    # Get alert details
    local alert_info=$(sqlite3 "$HERALD_DB" "SELECT source, alert_type, severity, message FROM alerts WHERE id = $alert_id")
    local source=$(echo "$alert_info" | cut -d'|' -f1)
    local alert_type=$(echo "$alert_info" | cut -d'|' -f2)
    local severity=$(echo "$alert_info" | cut -d'|' -f3)
    local message=$(echo "$alert_info" | cut -d'|' -f4)
    
    # Send to each channel
    IFS=',' read -ra CHANNEL_ARRAY <<< "$channels"
    for channel in "${CHANNEL_ARRAY[@]}"; do
        case "$channel" in
            email)
                if [[ "$ENABLE_EMAIL_ALERTS" == "true" ]]; then
                    send_email_alert "$alert_id" "$source" "$alert_type" "$severity" "$message"
                fi
                ;;
            sms)
                if [[ "$ENABLE_SMS_ALERTS" == "true" ]]; then
                    send_sms_alert "$alert_id" "$source" "$alert_type" "$severity" "$message"
                fi
                ;;
            webhook)
                if [[ "$ENABLE_WEBHOOK_ALERTS" == "true" ]]; then
                    send_webhook_alert "$alert_id" "$source" "$alert_type" "$severity" "$message"
                fi
                ;;
            console)
                send_console_alert "$alert_id" "$source" "$alert_type" "$severity" "$message"
                ;;
        esac
    done
    
    # Mark notification as sent
    sqlite3 "$HERALD_DB" "UPDATE alerts SET notification_sent = 1 WHERE id = $alert_id"
}

# Send email alert
send_email_alert() {
    local alert_id="$1"
    local source="$2"
    local alert_type="$3"
    local severity="$4"
    local message="$5"
    
    local subject="[GRIM ALERT] $severity: $alert_type from $source"
    local body="Alert ID: $alert_id
Source: $source
Type: $alert_type
Severity: $severity
Message: $message
Time: $(date)
Host: $(hostname)"
    
    # Send email (placeholder)
    echo "$body" | mail -s "$subject" root 2>/dev/null || log "Failed to send email alert"
    
    log "Email alert sent: ID $alert_id"
    audit_log "EMAIL_ALERT_SENT" "ID: $alert_id, To: root"
}

# Send SMS alert
send_sms_alert() {
    local alert_id="$1"
    local source="$2"
    local alert_type="$3"
    local severity="$4"
    local message="$5"
    
    local sms_text="GRIM: $severity $alert_type - $message"
    
    # Send SMS (placeholder)
    log "SMS alert would be sent: $sms_text"
    audit_log "SMS_ALERT_SENT" "ID: $alert_id, Text: $sms_text"
}

# Send webhook alert
send_webhook_alert() {
    local alert_id="$1"
    local source="$2"
    local alert_type="$3"
    local severity="$4"
    local message="$5"
    
    local webhook_data="{\"alert_id\": $alert_id, \"source\": \"$source\", \"alert_type\": \"$alert_type\", \"severity\": \"$severity\", \"message\": \"$message\", \"timestamp\": \"$(date -Iseconds)\"}"
    
    # Send webhook (placeholder)
    curl -s -X POST -H "Content-Type: application/json" -d "$webhook_data" "http://localhost:8080/webhook" 2>/dev/null || log "Failed to send webhook alert"
    
    log "Webhook alert sent: ID $alert_id"
    audit_log "WEBHOOK_ALERT_SENT" "ID: $alert_id, Data: $webhook_data"
}

# Send console alert
send_console_alert() {
    local alert_id="$1"
    local source="$2"
    local alert_type="$3"
    local severity="$4"
    local message="$5"
    
    local color="$YELLOW"
    case "$severity" in
        high) color="$RED" ;;
        medium) color="$YELLOW" ;;
        low) color="$GREEN" ;;
    esac
    
    echo -e "${color}[ALERT $alert_id] $severity: $alert_type from $source${NC}"
    echo -e "  $message"
    
    log "Console alert displayed: ID $alert_id"
    audit_log "CONSOLE_ALERT_SENT" "ID: $alert_id, Severity: $severity"
}

# Get alert statistics
get_alert_stats() {
    echo -e "${CYAN}=== Alert Statistics ===${NC}"
    
    local total_alerts=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts")
    local active_alerts=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE status = 'active'")
    local acknowledged_alerts=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE status = 'acknowledged'")
    local resolved_alerts=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE status = 'resolved'")
    local high_severity=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE severity = 'high'")
    local medium_severity=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE severity = 'medium'")
    local low_severity=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE severity = 'low'")
    
    echo "Total alerts: $total_alerts"
    echo "Active alerts: $active_alerts"
    echo "Acknowledged alerts: $acknowledged_alerts"
    echo "Resolved alerts: $resolved_alerts"
    echo "High severity: $high_severity"
    echo "Medium severity: $medium_severity"
    echo "Low severity: $low_severity"
    
    echo ""
    echo -e "${YELLOW}Recent Alerts:${NC}"
    sqlite3 "$HERALD_DB" "SELECT id, source, alert_type, severity, status, created_at FROM alerts ORDER BY created_at DESC LIMIT 10" | while IFS='|' read -r id source alert_type severity status created_at; do
        echo "  [$id] $alert_type ($severity) from $source - $status - $created_at"
    done
}

# Clean up old alerts
cleanup_old_alerts() {
    local days="${1:-$ALERT_RETENTION_DAYS}"
    
    local deleted_count=$(sqlite3 "$HERALD_DB" "SELECT COUNT(*) FROM alerts WHERE created_at < datetime('now', '-$days days')")
    
    sqlite3 "$HERALD_DB" <<EOF
DELETE FROM alerts WHERE created_at < datetime('now', '-$days days');
DELETE FROM alert_escalations WHERE alert_id NOT IN (SELECT id FROM alerts);
EOF
    
    log "Cleaned up $deleted_count old alerts (older than $days days)"
    audit_log "ALERTS_CLEANUP" "Deleted: $deleted_count alerts, Retention: $days days"
}

# Show help
show_help() {
    echo -e "${CYAN}Herald Alert System${NC}"
    echo "Security alert management and notification system."
    echo ""
    echo "Usage: grim herald <command> [options]"
    echo ""
    echo "Commands:"
    echo "  alerts [status]                     - List alerts"
    echo "  acknowledge <alert_id>              - Acknowledge alert"
    echo "  resolve <alert_id>                  - Resolve alert"
    echo "  escalate <alert_id> <level> <to>    - Escalate alert"
    echo "  stats                               - Show alert statistics"
    echo "  rules [add|remove|list]             - Manage alert rules"
    echo "  channels [add|remove|list]          - Manage notification channels"
    echo "  cleanup [days]                      - Clean up old alerts"
    echo "  init                                - Initialize alert system"
    echo "  help                                - Show this help"
    echo ""
    echo "Examples:"
    echo "  grim herald alerts"
    echo "  grim herald acknowledge 123"
    echo "  grim herald escalate 123 2 admin"
    echo "  grim herald stats"
    echo ""
    echo "Configuration:"
    echo "  Alert retention: ${ALERT_RETENTION_DAYS} days"
    echo "  Email alerts: $ENABLE_EMAIL_ALERTS"
    echo "  SMS alerts: $ENABLE_SMS_ALERTS"
    echo "  Webhook alerts: $ENABLE_WEBHOOK_ALERTS"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        alerts)
            if [[ $# -eq 1 ]]; then
                sqlite3 "$HERALD_DB" "SELECT id, source, alert_type, severity, status, created_at FROM alerts WHERE status = '$1' ORDER BY created_at DESC"
            else
                sqlite3 "$HERALD_DB" "SELECT id, source, alert_type, severity, status, created_at FROM alerts ORDER BY created_at DESC LIMIT 20"
            fi
            ;;
        acknowledge)
            if [[ $# -lt 1 ]]; then
                echo "Usage: grim herald acknowledge <alert_id>"
                return 1
            fi
            acknowledge_alert "$1"
            ;;
        resolve)
            if [[ $# -lt 1 ]]; then
                echo "Usage: grim herald resolve <alert_id>"
                return 1
            fi
            resolve_alert "$1"
            ;;
        escalate)
            if [[ $# -lt 3 ]]; then
                echo "Usage: grim herald escalate <alert_id> <level> <to>"
                return 1
            fi
            escalate_alert "$1" "$2" "$3"
            ;;
        stats)
            get_alert_stats
            ;;
        rules)
            case "$1" in
                add)
                    echo "Adding alert rule..."
                    ;;
                remove)
                    echo "Removing alert rule..."
                    ;;
                list)
                    sqlite3 "$HERALD_DB" "SELECT rule_name, source_pattern, alert_type_pattern, severity_override, enabled FROM alert_rules ORDER BY rule_name"
                    ;;
                *)
                    echo "Usage: grim herald rules [add|remove|list]"
                    ;;
            esac
            ;;
        channels)
            case "$1" in
                add)
                    echo "Adding notification channel..."
                    ;;
                remove)
                    echo "Removing notification channel..."
                    ;;
                list)
                    sqlite3 "$HERALD_DB" "SELECT channel_name, channel_type, enabled FROM notification_channels ORDER BY channel_name"
                    ;;
                *)
                    echo "Usage: grim herald channels [add|remove|list]"
                    ;;
            esac
            ;;
        cleanup)
            cleanup_old_alerts "$1"
            ;;
        init)
            init_herald_db
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            return 1
            ;;
    esac
}

# Initialize on first run
init_herald_db

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 