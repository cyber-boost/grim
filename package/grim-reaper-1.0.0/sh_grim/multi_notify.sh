#!/bin/bash
# Grimm Multi-Channel Notification System: Enhanced notification with Mother DB integration

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/multi_notify.log"
CONFIG_FILE="$GRIM_ROOT/config/multi_notify.conf"
NOTIFY_QUEUE="$GRIM_ROOT/logs/.multi_notify_queue"
MOTHER_DB_CONFIG="$GRIM_ROOT/config/mother_db.conf"

# Colors for output
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

# Load Mother DB configuration
load_mother_db_config() {
    if [ -f "$MOTHER_DB_CONFIG" ]; then
        source "$MOTHER_DB_CONFIG"
    else
        # Create default Mother DB config
        cat > "$MOTHER_DB_CONFIG" <<'EOF'
# Mother DB Configuration
MOTHER_DB_ENABLED="false"
MOTHER_DB_HOST="localhost"
MOTHER_DB_PORT="8080"
MOTHER_DB_API_KEY=""
MOTHER_DB_SECRET=""
MOTHER_DB_SSL="false"
MOTHER_DB_TIMEOUT="30"
EOF
        log "Created default Mother DB config at $MOTHER_DB_CONFIG"
        return 1
    fi
}

# Load notification configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Create enhanced config
        cat > "$CONFIG_FILE" <<'EOF'
# Grimm Multi-Channel Notification Configuration

# Email Settings
EMAIL_ENABLED="false"
EMAIL_TO=""
EMAIL_FROM="grimm@localhost"
EMAIL_SUBJECT_PREFIX="[Grimm]"
EMAIL_SMTP_HOST="localhost"
EMAIL_SMTP_PORT="25"
EMAIL_SMTP_USER=""
EMAIL_SMTP_PASS=""
EMAIL_USE_TLS="false"

# Webhook Settings
WEBHOOK_ENABLED="false"
WEBHOOK_URL=""
WEBHOOK_SECRET=""
WEBHOOK_METHOD="POST"

# Slack Settings
SLACK_ENABLED="false"
SLACK_WEBHOOK_URL=""
SLACK_CHANNEL=""
SLACK_USERNAME="Grimm Reaper"
SLACK_ICON=":skull:"

# Discord Settings
DISCORD_ENABLED="false"
DISCORD_WEBHOOK_URL=""

# Telegram Settings
TELEGRAM_ENABLED="false"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Microsoft Teams Settings
TEAMS_ENABLED="false"
TEAMS_WEBHOOK_URL=""

# PagerDuty Settings
PAGERDUTY_ENABLED="false"
PAGERDUTY_API_KEY=""
PAGERDUTY_SERVICE_ID=""

# SMS Settings (via Twilio)
SMS_ENABLED="false"
SMS_TWILIO_ACCOUNT_SID=""
SMS_TWILIO_AUTH_TOKEN=""
SMS_TWILIO_FROM_NUMBER=""
SMS_TO_NUMBER=""

# System Notifications
SYSTEM_NOTIFY_ENABLED="false"

# Mother DB Integration
MOTHER_DB_NOTIFY_ENABLED="false"

# Notification Levels
NOTIFY_ON_ERROR="true"
NOTIFY_ON_WARNING="true"
NOTIFY_ON_SUCCESS="false"
NOTIFY_ON_BACKUP_COMPLETE="true"
NOTIFY_ON_SCAN_COMPLETE="false"
NOTIFY_ON_DISK_SPACE_LOW="true"
NOTIFY_ON_LICENSE_VIOLATION="true"

# Thresholds
DISK_SPACE_WARNING_PERCENT="90"
BACKUP_SIZE_WARNING_GB="50"
LICENSE_VIOLATION_THRESHOLD="3"

# Rate Limiting
RATE_LIMIT_ENABLED="true"
RATE_LIMIT_MAX_PER_HOUR="100"
RATE_LIMIT_MAX_PER_DAY="1000"
EOF
        log "Created enhanced config at $CONFIG_FILE"
        return 1
    fi
}

# Send notification to Mother DB
send_mother_db() {
    local event="$1"
    local message="$2"
    local data="$3"
    local priority="${4:-normal}"
    
    if [ "$MOTHER_DB_NOTIFY_ENABLED" != "true" ] || [ "$MOTHER_DB_ENABLED" != "true" ]; then
        return 1
    fi
    
    log "Sending to Mother DB: $event"
    
    # Create payload
    local payload=$(cat <<EOF
{
    "event": "$event",
    "message": "$message",
    "data": $data,
    "priority": "$priority",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "source": "grimm",
    "version": "2.0"
}
EOF
)
    
    # Calculate signature
    local signature=""
    if [ -n "$MOTHER_DB_SECRET" ]; then
        signature=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$MOTHER_DB_SECRET" | cut -d' ' -f2)
    fi
    
    # Send to Mother DB
    local protocol="http"
    if [ "$MOTHER_DB_SSL" = "true" ]; then
        protocol="https"
    fi
    
    local url="$protocol://$MOTHER_DB_HOST:$MOTHER_DB_PORT/api/v1/notifications"
    
    local headers="-H 'Content-Type: application/json'"
    if [ -n "$MOTHER_DB_API_KEY" ]; then
        headers="$headers -H 'X-API-Key: $MOTHER_DB_API_KEY'"
    fi
    if [ -n "$signature" ]; then
        headers="$headers -H 'X-Signature: sha256=$signature'"
    fi
    
    curl -s --connect-timeout "$MOTHER_DB_TIMEOUT" -X POST \
        $headers \
        -d "$payload" \
        "$url" || log_error "Mother DB notification failed"
}

# Send Telegram notification
send_telegram() {
    local message="$1"
    
    if [ "$TELEGRAM_ENABLED" != "true" ] || [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return 1
    fi
    
    log "Sending Telegram notification"
    
    local url="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
    local payload=$(cat <<EOF
{
    "chat_id": "$TELEGRAM_CHAT_ID",
    "text": "💀 Grimm Notification\n\n$message",
    "parse_mode": "HTML"
}
EOF
)
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "$url" || log_error "Telegram notification failed"
}

# Send Microsoft Teams notification
send_teams() {
    local title="$1"
    local message="$2"
    local color="${3:-#36a64f}"
    
    if [ "$TEAMS_ENABLED" != "true" ] || [ -z "$TEAMS_WEBHOOK_URL" ]; then
        return 1
    fi
    
    log "Sending Teams notification"
    
    local payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "$color",
    "summary": "Grimm: $title",
    "sections": [{
        "activityTitle": "Grimm Reaper",
        "activitySubtitle": "$(date '+%Y-%m-%d %H:%M:%S')",
        "text": "$message",
        "markdown": true
    }]
}
EOF
)
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "$TEAMS_WEBHOOK_URL" || log_error "Teams notification failed"
}

# Send PagerDuty alert
send_pagerduty() {
    local title="$1"
    local message="$2"
    local severity="${3:-warning}"
    
    if [ "$PAGERDUTY_ENABLED" != "true" ] || [ -z "$PAGERDUTY_API_KEY" ] || [ -z "$PAGERDUTY_SERVICE_ID" ]; then
        return 1
    fi
    
    log "Sending PagerDuty alert"
    
    local payload=$(cat <<EOF
{
    "routing_key": "$PAGERDUTY_API_KEY",
    "event_action": "trigger",
    "payload": {
        "summary": "Grimm: $title",
        "severity": "$severity",
        "source": "$(hostname)",
        "custom_details": "$message"
    }
}
EOF
)
    
    curl -s -X POST -H "Content-Type: application/json" \
        -H "Accept: application/vnd.pagerduty+json;version=2" \
        -d "$payload" "https://events.pagerduty.com/v2/enqueue" || log_error "PagerDuty alert failed"
}

# Send SMS via Twilio
send_sms() {
    local message="$1"
    
    if [ "$SMS_ENABLED" != "true" ] || [ -z "$SMS_TWILIO_ACCOUNT_SID" ] || [ -z "$SMS_TWILIO_AUTH_TOKEN" ] || [ -z "$SMS_TWILIO_FROM_NUMBER" ] || [ -z "$SMS_TO_NUMBER" ]; then
        return 1
    fi
    
    log "Sending SMS notification"
    
    local url="https://api.twilio.com/2010-04-01/Accounts/$SMS_TWILIO_ACCOUNT_SID/Messages.json"
    
    curl -s -X POST "$url" \
        -u "$SMS_TWILIO_ACCOUNT_SID:$SMS_TWILIO_AUTH_TOKEN" \
        -d "From=$SMS_TWILIO_FROM_NUMBER" \
        -d "To=$SMS_TO_NUMBER" \
        -d "Body=Grimm: $message" || log_error "SMS notification failed"
}

# Rate limiting check
check_rate_limit() {
    local level="$1"
    
    if [ "$RATE_LIMIT_ENABLED" != "true" ]; then
        return 0
    fi
    
    local rate_file="$GRIM_ROOT/logs/.rate_limit_$level"
    local current_time=$(date +%s)
    local hour_ago=$((current_time - 3600))
    local day_ago=$((current_time - 86400))
    
    # Clean old entries
    if [ -f "$rate_file" ]; then
        while IFS= read -r timestamp; do
            if [ "$timestamp" -gt "$hour_ago" ]; then
                echo "$timestamp" >> "${rate_file}.tmp"
            fi
        done < "$rate_file"
        mv "${rate_file}.tmp" "$rate_file" 2>/dev/null || rm -f "${rate_file}.tmp"
    fi
    
    # Check hourly limit
    local hourly_count=$(wc -l < "$rate_file" 2>/dev/null || echo "0")
    if [ "$hourly_count" -ge "${RATE_LIMIT_MAX_PER_HOUR:-100}" ]; then
        log "Rate limit exceeded for $level (hourly)"
        return 1
    fi
    
    # Add current timestamp
    echo "$current_time" >> "$rate_file"
    
    return 0
}

# Enhanced notification function
multi_notify() {
    local level="$1"
    local title="$2"
    local message="$3"
    local data="${4:-{}}"
    local priority="${5:-normal}"
    
    load_config || return 1
    load_mother_db_config || true
    
    # Check rate limiting
    if ! check_rate_limit "$level"; then
        log "Rate limit exceeded, skipping notification"
        return 0
    fi
    
    # Check if we should notify for this level
    case "$level" in
        error)
            [ "$NOTIFY_ON_ERROR" != "true" ] && return 0
            local color="#ff0000"
            local discord_color="15158332"
            local pagerduty_severity="critical"
            ;;
        warning)
            [ "$NOTIFY_ON_WARNING" != "true" ] && return 0
            local color="#ff9900"
            local discord_color="15105570"
            local pagerduty_severity="warning"
            ;;
        success)
            [ "$NOTIFY_ON_SUCCESS" != "true" ] && return 0
            local color="#36a64f"
            local discord_color="3066993"
            local pagerduty_severity="info"
            ;;
        *)
            local color="#0099ff"
            local discord_color="39423"
            local pagerduty_severity="info"
            ;;
    esac
    
    # Send to all enabled channels in parallel
    (
        # Legacy channels (from notify.sh)
        if [ -f "$GRIM_ROOT/sh_grim/notify.sh" ]; then
            "$GRIM_ROOT/sh_grim/notify.sh" send "$level" "$title" "$message" "$data" &
        fi
        
        # New channels
        send_mother_db "grimm.$level" "$message" "$data" "$priority" &
        send_telegram "$title: $message" &
        send_teams "$title" "$message" "$color" &
        send_pagerduty "$title" "$message" "$pagerduty_severity" &
        send_sms "$title: $message" &
        
        # Wait for all notifications to complete
        wait
    )
    
    # Log notification
    echo "$(date -Iseconds)|$level|$title|$message|$priority" >> "$NOTIFY_QUEUE"
    
    log "Multi-channel notification sent: $level - $title"
}

# License violation notification
notify_license_violation() {
    local violation_type="$1"
    local details="$2"
    local count="${3:-1}"
    
    if [ "$NOTIFY_ON_LICENSE_VIOLATION" != "true" ]; then
        return 0
    fi
    
    local threshold="${LICENSE_VIOLATION_THRESHOLD:-3}"
    local priority="normal"
    
    if [ "$count" -ge "$threshold" ]; then
        priority="high"
    fi
    
    multi_notify "error" "License Violation Detected" \
        "License violation: $violation_type (Count: $count)" \
        "{\"type\": \"$violation_type\", \"details\": \"$details\", \"count\": $count, \"threshold\": $threshold}" \
        "$priority"
}

# Test all notification channels
test_all_channels() {
    load_config || return 1
    load_mother_db_config || true
    
    echo "Testing all notification channels..."
    
    multi_notify "info" "Test Notification" \
        "This is a comprehensive test of all notification channels" \
        "{\"test\": true, \"timestamp\": \"$(date -Iseconds)\", \"channels\": \"all\"}" \
        "normal"
    
    echo "Test notifications sent. Check your configured channels."
}

# Show notification statistics
show_stats() {
    if [ ! -f "$NOTIFY_QUEUE" ]; then
        echo "No notification history found."
        return
    fi
    
    echo "=== Notification Statistics ==="
    echo "Total notifications: $(wc -l < "$NOTIFY_QUEUE")"
    echo ""
    echo "By level:"
    cut -d'|' -f2 "$NOTIFY_QUEUE" | sort | uniq -c | sort -nr
    echo ""
    echo "By priority:"
    cut -d'|' -f5 "$NOTIFY_QUEUE" | sort | uniq -c | sort -nr
    echo ""
    echo "Recent notifications:"
    tail -10 "$NOTIFY_QUEUE" | while IFS='|' read -r timestamp level title message priority; do
        printf "[%s] %-8s %-8s %s: %s\n" "$timestamp" "$level" "$priority" "$title" "$message"
    done
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Multi-Channel Notification System${NC}"
    echo "Enhanced notification system with Mother DB integration and multiple channels."
    echo "Supports email, webhooks, Slack, Discord, Telegram, Teams, PagerDuty, SMS, and Mother DB."
    echo ""
    echo "Usage: grim multi-notify <command> [options]"
    echo ""
    echo "Commands:"
    echo "  send <level> <title> <msg> [data] [priority] - Send notification to all channels"
    echo "  license-violation <type> <details> [count]   - Notify license violation"
    echo "  test                                           - Test all notification channels"
    echo "  stats                                          - Show notification statistics"
    echo "  config                                         - Display current configuration"
    echo "  mother-db-status                               - Check Mother DB connectivity"
    echo ""
    echo "Examples:"
    echo "  grim multi-notify send error 'Critical Error' 'System failure detected'"
    echo "  grim multi-notify license-violation 'unauthorized_access' 'User attempted unauthorized access' 5"
    echo "  grim multi-notify test                         # Test all channels"
    echo ""
    echo "Levels: error, warning, success, info"
    echo "Priorities: low, normal, high, critical"
    echo "Configuration: $CONFIG_FILE"
    echo "Mother DB Config: $MOTHER_DB_CONFIG"
}

# Check Mother DB connectivity
check_mother_db() {
    load_mother_db_config || return 1
    
    if [ "$MOTHER_DB_ENABLED" != "true" ]; then
        echo "Mother DB is disabled in configuration"
        return 1
    fi
    
    local protocol="http"
    if [ "$MOTHER_DB_SSL" = "true" ]; then
        protocol="https"
    fi
    
    local url="$protocol://$MOTHER_DB_HOST:$MOTHER_DB_PORT/api/v1/health"
    
    echo "Checking Mother DB connectivity..."
    echo "URL: $url"
    
    local response=$(curl -s --connect-timeout "$MOTHER_DB_TIMEOUT" "$url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "✅ Mother DB is reachable"
        echo "Response: $response"
        return 0
    else
        echo "❌ Mother DB is not reachable"
        return 1
    fi
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        send)
            local level="${1:-info}"
            local title="$2"
            local message="$3"
            local data="${4:-{}}"
            local priority="${5:-normal}"
            
            if [ -z "$title" ] || [ -z "$message" ]; then
                log_error "Usage: grim multi-notify send <level> <title> <message> [data] [priority]"
                exit 1
            fi
            
            multi_notify "$level" "$title" "$message" "$data" "$priority"
            ;;
        
        license-violation)
            local violation_type="$1"
            local details="$2"
            local count="${3:-1}"
            
            if [ -z "$violation_type" ] || [ -z "$details" ]; then
                log_error "Usage: grim multi-notify license-violation <type> <details> [count]"
                exit 1
            fi
            
            notify_license_violation "$violation_type" "$details" "$count"
            ;;
        
        test)
            test_all_channels
            ;;
        
        stats)
            show_stats
            ;;
        
        config)
            echo "Multi-notify configuration: $CONFIG_FILE"
            cat "$CONFIG_FILE"
            echo ""
            echo "Mother DB configuration: $MOTHER_DB_CONFIG"
            cat "$MOTHER_DB_CONFIG"
            ;;
        
        mother-db-status)
            check_mother_db
            ;;
        
        help|-h|--help)
            show_help
            ;;
        
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@" 