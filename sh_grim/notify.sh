#!/bin/bash
# Grimm Notification Module: Email, webhook, and system notifications

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/notify.log"
CONFIG_FILE="$GRIM_ROOT/config/notify.conf"
NOTIFY_QUEUE="$GRIM_ROOT/logs/.notify_queue"

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

# Load notification configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Create default config
        cat > "$CONFIG_FILE" <<'EOF'
# Grimm Notification Configuration

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

# System Notifications (notify-send)
SYSTEM_NOTIFY_ENABLED="false"

# Notification Levels
NOTIFY_ON_ERROR="true"
NOTIFY_ON_WARNING="true"
NOTIFY_ON_SUCCESS="false"
NOTIFY_ON_BACKUP_COMPLETE="true"
NOTIFY_ON_SCAN_COMPLETE="false"
NOTIFY_ON_DISK_SPACE_LOW="true"

# Thresholds
DISK_SPACE_WARNING_PERCENT="90"
BACKUP_SIZE_WARNING_GB="50"
EOF
        log "Created default config at $CONFIG_FILE"
        return 1
    fi
}

# Send email notification
send_email() {
    local subject="$1"
    local body="$2"
    local priority="${3:-normal}"
    
    if [ "$EMAIL_ENABLED" != "true" ] || [ -z "$EMAIL_TO" ]; then
        return 1
    fi
    
    log "Sending email: $subject"
    
    # Create email with headers
    local email_content=$(cat <<EOF
From: $EMAIL_FROM
To: $EMAIL_TO
Subject: $EMAIL_SUBJECT_PREFIX $subject
X-Priority: $([ "$priority" = "high" ] && echo "1" || echo "3")
Content-Type: text/plain; charset=UTF-8

$body

---
Sent by Grimm Backup System
$(date)
EOF
)
    
    # Send via appropriate method
    if command -v sendmail &> /dev/null; then
        echo "$email_content" | sendmail -t
    elif command -v mail &> /dev/null; then
        echo "$body" | mail -s "$EMAIL_SUBJECT_PREFIX $subject" "$EMAIL_TO"
    elif [ -n "$EMAIL_SMTP_HOST" ]; then
        # Use Python for SMTP if available
        python3 - <<EOF
import smtplib
from email.mime.text import MIMEText

msg = MIMEText("""$body""")
msg['Subject'] = "$EMAIL_SUBJECT_PREFIX $subject"
msg['From'] = "$EMAIL_FROM"
msg['To'] = "$EMAIL_TO"

try:
    server = smtplib.SMTP('$EMAIL_SMTP_HOST', $EMAIL_SMTP_PORT)
    if "$EMAIL_USE_TLS" == "true":
        server.starttls()
    if "$EMAIL_SMTP_USER":
        server.login('$EMAIL_SMTP_USER', '$EMAIL_SMTP_PASS')
    server.send_message(msg)
    server.quit()
    print("Email sent successfully")
except Exception as e:
    print(f"Failed to send email: {e}")
    exit(1)
EOF
    else
        log_error "No email sending method available"
        return 1
    fi
}

# Send webhook notification
send_webhook() {
    local event="$1"
    local message="$2"
    local data="$3"
    
    if [ "$WEBHOOK_ENABLED" != "true" ] || [ -z "$WEBHOOK_URL" ]; then
        return 1
    fi
    
    log "Sending webhook: $event"
    
    # Create JSON payload
    local payload=$(cat <<EOF
{
    "event": "$event",
    "message": "$message",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "data": $data
}
EOF
)
    
    # Calculate signature if secret is set
    local headers=""
    if [ -n "$WEBHOOK_SECRET" ]; then
        local signature=$(echo -n "$payload" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | cut -d' ' -f2)
        headers="-H 'X-Grimm-Signature: sha256=$signature'"
    fi
    
    # Send webhook
    curl -s -X "$WEBHOOK_METHOD" \
        -H "Content-Type: application/json" \
        $headers \
        -d "$payload" \
        "$WEBHOOK_URL" || log_error "Webhook failed"
}

# Send Slack notification
send_slack() {
    local message="$1"
    local color="${2:-#36a64f}"  # green by default
    
    if [ "$SLACK_ENABLED" != "true" ] || [ -z "$SLACK_WEBHOOK_URL" ]; then
        return 1
    fi
    
    log "Sending Slack notification"
    
    local payload=$(cat <<EOF
{
    "channel": "${SLACK_CHANNEL}",
    "username": "${SLACK_USERNAME}",
    "icon_emoji": "${SLACK_ICON}",
    "attachments": [{
        "color": "$color",
        "title": "Grimm Notification",
        "text": "$message",
        "footer": "Grimm Backup System",
        "ts": $(date +%s)
    }]
}
EOF
)
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "$SLACK_WEBHOOK_URL" || log_error "Slack notification failed"
}

# Send Discord notification
send_discord() {
    local message="$1"
    local color="${2:-3066993}"  # green by default
    
    if [ "$DISCORD_ENABLED" != "true" ] || [ -z "$DISCORD_WEBHOOK_URL" ]; then
        return 1
    fi
    
    log "Sending Discord notification"
    
    local payload=$(cat <<EOF
{
    "username": "Grimm Reaper",
    "avatar_url": "https://example.com/grimm-avatar.png",
    "embeds": [{
        "title": "Grimm Notification",
        "description": "$message",
        "color": $color,
        "footer": {
            "text": "Grimm Backup System"
        },
        "timestamp": "$(date -Iseconds)"
    }]
}
EOF
)
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "$DISCORD_WEBHOOK_URL" || log_error "Discord notification failed"
}

# Send system notification
send_system_notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    if [ "$SYSTEM_NOTIFY_ENABLED" != "true" ]; then
        return 1
    fi
    
    if command -v notify-send &> /dev/null; then
        notify-send -u "$urgency" -i "dialog-information" "$title" "$message"
    elif [ "$(uname)" = "Darwin" ] && command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\""
    fi
}

# Send notification to all enabled channels
notify() {
    local level="$1"
    local title="$2"
    local message="$3"
    local data="${4:-{}}"
    
    load_config || return 1
    
    # Check if we should notify for this level
    case "$level" in
        error)
            [ "$NOTIFY_ON_ERROR" != "true" ] && return 0
            local color="#ff0000"
            local discord_color="15158332"
            ;;
        warning)
            [ "$NOTIFY_ON_WARNING" != "true" ] && return 0
            local color="#ff9900"
            local discord_color="15105570"
            ;;
        success)
            [ "$NOTIFY_ON_SUCCESS" != "true" ] && return 0
            local color="#36a64f"
            local discord_color="3066993"
            ;;
        *)
            local color="#0099ff"
            local discord_color="39423"
            ;;
    esac
    
    # Send to all enabled channels
    send_email "$title" "$message" "$level" &
    send_webhook "grimm.$level" "$message" "$data" &
    send_slack "$message" "$color" &
    send_discord "$message" "$discord_color" &
    send_system_notify "Grimm: $title" "$message" "$level" &
    
    # Wait for all notifications to complete
    wait
    
    # Log notification
    echo "$(date -Iseconds)|$level|$title|$message" >> "$NOTIFY_QUEUE"
}

# Check disk space and notify if low
check_disk_space() {
    local path="${1:-/}"
    local threshold="${DISK_SPACE_WARNING_PERCENT:-90}"
    
    local usage=$(df "$path" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$usage" -ge "$threshold" ]; then
        notify "warning" "Disk Space Low" "Disk usage at ${usage}% on $path" \
            "{\"path\": \"$path\", \"usage\": $usage, \"threshold\": $threshold}"
    fi
}

# Monitor backup completion
notify_backup_complete() {
    local backup_file="$1"
    local size_bytes="$2"
    local duration="$3"
    
    if [ "$NOTIFY_ON_BACKUP_COMPLETE" != "true" ]; then
        return 0
    fi
    
    local size_human=$(numfmt --to=iec-i --suffix=B $size_bytes 2>/dev/null || echo "$size_bytes bytes")
    
    notify "success" "Backup Complete" \
        "Backup completed successfully: $(basename "$backup_file") ($size_human in ${duration}s)" \
        "{\"file\": \"$backup_file\", \"size\": $size_bytes, \"duration\": $duration}"
}

# Test notification configuration
test_notifications() {
    load_config || return 1
    
    echo "Testing notification channels..."
    
    notify "info" "Test Notification" "This is a test notification from Grimm" \
        "{\"test\": true, \"timestamp\": \"$(date -Iseconds)\"}"
    
    echo "Test notifications sent. Check your configured channels."
}

# Show notification history
show_history() {
    if [ ! -f "$NOTIFY_QUEUE" ]; then
        echo "No notification history found."
        return
    fi
    
    echo "=== Recent Notifications ==="
    tail -20 "$NOTIFY_QUEUE" | while IFS='|' read -r timestamp level title message; do
        printf "[%s] %-8s %s: %s\n" "$timestamp" "$level" "$title" "$message"
    done
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Notification Module${NC}"
    echo "Multi-channel notification system supporting email, webhooks, Slack, Discord, and system notifications."
    echo "Provides comprehensive alerting for backup operations, errors, and system events."
    echo ""
    echo "Usage: grim notify <command> [options]"
    echo ""
    echo "Commands:"
    echo "  send <level> <title> <msg> [data] - Send notification to all channels"
    echo "  backup-complete <file> <size> <duration> - Notify backup completion"
    echo "  check-disk [path] [threshold]     - Check disk space and alert if low"
    echo "  test                              - Test all notification channels"
    echo "  history                           - Show recent notification history"
    echo "  config                            - Display current configuration"
    echo ""
    echo "Examples:"
    echo "  grim notify send error 'Backup Failed' 'Critical backup error occurred'"
    echo "  grim notify backup-complete backup.tar.gz 1073741824 300"
    echo "  grim notify test                           # Test all channels"
    echo ""
    echo "Levels: error, warning, success, info"
    echo "Configuration: $CONFIG_FILE"
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
            
            if [ -z "$title" ] || [ -z "$message" ]; then
                log_error "Usage: grim notify send <level> <title> <message> [data]"
                exit 1
            fi
            
            notify "$level" "$title" "$message" "$data"
            ;;
        
        backup-complete)
            notify_backup_complete "$@"
            ;;
        
        check-disk)
            check_disk_space "$@"
            ;;
        
        test)
            test_notifications
            ;;
        
        history)
            show_history
            ;;
        
        config)
            echo "Notification configuration: $CONFIG_FILE"
            cat "$CONFIG_FILE"
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