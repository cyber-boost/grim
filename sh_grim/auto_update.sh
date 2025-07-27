#!/bin/bash
# 🔄 GRIM AUTO-UPDATE CLIENT
# Randomly pings up.grim.so for version updates

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRIM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$HOME/.graveyard/.rip"
UPDATE_LOG="$HOME/.graveyard/auto_update.log"
LOCK_FILE="/tmp/grim_auto_update.lock"
VERSION_ENDPOINT="https://up.grim.so/version-check"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# INITIALIZATION  
# ============================================================================
check_and_migrate_scythe() {
    # Check if .scythe directory structure exists, create if not
    local scythe_dir="$HOME/.graveyard/.rip/.scythe"
    
    if [[ ! -d "$scythe_dir" ]]; then
        log_update "🗡️ .scythe directory not found, initializing..."
        
        # Use the universal setup script if available
        local setup_script="$GRIM_ROOT/scripts/setup_scythe_dirs.sh"
        
        if [[ -f "$setup_script" ]]; then
            "$setup_script" setup "$GRIM_ROOT" auto >> "$UPDATE_LOG" 2>&1 || true
            log_update "✅ .scythe directory initialized"
        else
            # Basic fallback 
            mkdir -p "$scythe_dir"/{config,db,logs,run,integrations}
            mkdir -p "$scythe_dir/logs"/{orchestration,components,integrations,security}
            mkdir -p "$scythe_dir/integrations"/{discovered,configs,scripts}
            log_update "✅ Basic .scythe directory created"
        fi
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
log_update() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$UPDATE_LOG"
}

# Initialize .scythe structure if needed (run once on startup)
check_and_migrate_scythe

get_current_version() {
    # Try to get version from latest build manifest
    if [[ -f "$GRIM_ROOT/builds/latest/manifest.tsk" ]]; then
        grep "version:" "$GRIM_ROOT/builds/latest/manifest.tsk" | sed 's/.*version: *"*\([^"]*\)"*.*/\1/' 2>/dev/null || echo "unknown"
    elif [[ -f "$HOME/.graveyard/version.txt" ]]; then
        cat "$HOME/.graveyard/version.txt" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

is_auto_update_enabled() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 0  # Enabled by default
    fi
    
    # Check if auto_update is disabled
    if grep -q "enabled=false" "$CONFIG_FILE" 2>/dev/null; then
        return 1  # Disabled
    else
        return 0  # Enabled
    fi
}

get_random_interval() {
    # Random interval between 45-90 minutes (2700-5400 seconds)
    local min_seconds=2700
    local max_seconds=5400
    local range=$((max_seconds - min_seconds))
    local random_offset=$((RANDOM % range))
    echo $((min_seconds + random_offset))
}

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_update "Auto-update already running (PID: $lock_pid)"
            exit 0
        else
            # Stale lock, remove it
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# ============================================================================
# VERSION CHECK & UPDATE
# ============================================================================
check_for_updates() {
    local current_version=$(get_current_version)
    
    log_update "Checking for updates (current: $current_version)"
    
    # Prepare request data
    local request_data=$(cat << EOF
{
    "current_version": "$current_version",
    "client_info": {
        "hostname": "$(hostname 2>/dev/null || echo 'unknown')",
        "os": "$(uname -s 2>/dev/null || echo 'unknown')",
        "arch": "$(uname -m 2>/dev/null || echo 'unknown')",
        "grimster": true
    }
}
EOF
)
    
    # Make request to up.grim.so with fallback
    local response
    if ! response=$(curl -s -m 30 -X POST "$VERSION_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "User-Agent: GrimReaper-AutoUpdate/1.0" \
        -d "$request_data" 2>/dev/null); then
        
        # Fallback to localhost if HTTPS fails
        log_update "⚠️ HTTPS endpoint failed, trying localhost fallback..."
        local fallback_endpoint="http://localhost:5001/version-check"
        
        if ! response=$(curl -s -m 30 -X POST "$fallback_endpoint" \
            -H "Content-Type: application/json" \
            -H "User-Agent: GrimReaper-AutoUpdate/1.0" \
            -d "$request_data" 2>/dev/null); then
            log_update "❌ Failed to contact version service - both HTTPS and localhost failed"
            return 1
        fi
        
        log_update "✅ Fallback to localhost successful"
    fi
    
    # Parse response
    local update_available=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print('true' if data.get('update_available', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")
    
    local latest_version=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('latest_version', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
    
    local critical_update=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print('true' if data.get('critical_update', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")
    
    local message=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('message', 'Update check completed'))
except:
    print('Update check completed')
" 2>/dev/null || echo "Update check completed")
    
    log_update "Response: $message (latest: $latest_version)"
    
    if [[ "$update_available" == "true" ]]; then
        if [[ "$critical_update" == "true" ]]; then
            log_update "💀 CRITICAL UPDATE AVAILABLE: $latest_version"
            perform_update "$latest_version" "critical"
        else
            log_update "🗡️ Update available: $latest_version (non-critical)"
            # For non-critical updates, just log and notify
            notify_user_of_update "$latest_version" "normal"
        fi
    else
        log_update "✅ Grim is up to date ($current_version)"
    fi
}

notify_user_of_update() {
    local version="$1"
    local priority="$2"
    
    # Create notification file
    local notification_file="$HOME/.graveyard/update_notification.txt"
    cat > "$notification_file" << EOF
💀 GRIM UPDATE AVAILABLE 💀

New version: $version
Priority: $priority

To update manually, run:
  curl -fsSL https://get.grim.so | sudo bash

Or: grim update

To disable auto-update notifications:
  Edit $CONFIG_FILE and set enabled=false

Death is patient, but updates are recommended.
EOF
    
    # Try to show notification if desktop environment available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Grim Reaper Update" "Version $version available. Run 'grim update' to upgrade." 2>/dev/null || true
    fi
    
    log_update "📢 User notified of available update: $version"
}

migrate_scythe_directories() {
    log_update "🗡️ Migrating .scythe directory structure..."
    
    # Use the universal setup script if available
    local setup_script="$GRIM_ROOT/scripts/setup_scythe_dirs.sh"
    
    if [[ -f "$setup_script" ]]; then
        log_update "Running .scythe directory migration..."
        if "$setup_script" migrate "$GRIM_ROOT" >> "$UPDATE_LOG" 2>&1; then
            log_update "✅ .scythe directory migration completed"
        else
            log_update "⚠️ .scythe directory migration had issues but continuing"
        fi
    else
        log_update "⚠️ Setup script not found, running basic migration..."
        
        # Basic fallback migration
        local scythe_dir="$GRIM_ROOT/.graveyard/.rip/.scythe"
        
        if [[ ! -d "$scythe_dir" ]]; then
            log_update "Creating .scythe directory structure..."
            mkdir -p "$scythe_dir"/{config,db,logs,run,integrations}
            mkdir -p "$scythe_dir/logs"/{orchestration,components,integrations,security}
            mkdir -p "$scythe_dir/integrations"/{discovered,configs,scripts}
            
            log_update "✅ Basic .scythe directory structure created"
        else
            log_update "✅ .scythe directory already exists"
        fi
    fi
}

perform_update() {
    local version="$1"
    local priority="$2"
    
    log_update "🔄 Initiating auto-update to $version (priority: $priority)"
    
    # Only auto-update critical updates to prevent disruption
    if [[ "$priority" == "critical" ]]; then
        log_update "⚠️ Performing critical auto-update..."
        
        # Run the installer
        if curl -fsSL https://get.grim.so | bash >> "$UPDATE_LOG" 2>&1; then
            log_update "✅ Critical update completed successfully"
            
            # Run migration for .scythe directory structure
            migrate_scythe_directories
            
            # Update version file
            echo "$version" > "$HOME/.graveyard/version.txt"
            
            # Notify user of completed update
            if command -v notify-send >/dev/null 2>&1; then
                notify-send "Grim Reaper Updated" "Critical update to $version completed automatically." 2>/dev/null || true
            fi
        else
            log_update "❌ Critical update failed - manual intervention required"
        fi
    else
        # Non-critical updates just notify
        notify_user_of_update "$version" "$priority"
    fi
}

# ============================================================================
# DAEMON MODE
# ============================================================================
run_daemon() {
    log_update "🗡️ Grim auto-update daemon starting"
    
    while true; do
        if is_auto_update_enabled; then
            check_for_updates
        else
            log_update "Auto-update disabled by user configuration"
        fi
        
        # Get random sleep interval
        local sleep_time=$(get_random_interval)
        log_update "💤 Sleeping for $((sleep_time / 60)) minutes until next check"
        
        sleep "$sleep_time"
    done
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================
main() {
    local command="${1:-daemon}"
    
    case "$command" in
        daemon)
            acquire_lock
            mkdir -p "$(dirname "$UPDATE_LOG")"
            run_daemon
            ;;
        check)
            log_update "Manual update check requested"
            check_for_updates
            ;;
        status)
            if [[ -f "$UPDATE_LOG" ]]; then
                echo "📋 Recent auto-update activity:"
                tail -10 "$UPDATE_LOG"
            else
                echo "No auto-update activity logged yet"
            fi
            ;;
        enable)
            if [[ -f "$CONFIG_FILE" ]]; then
                sed -i 's/enabled=false/enabled=true/' "$CONFIG_FILE"
            fi
            echo "✅ Auto-updates enabled"
            log_update "Auto-updates enabled by user"
            ;;
        disable)
            if [[ -f "$CONFIG_FILE" ]]; then
                sed -i 's/enabled=true/enabled=false/' "$CONFIG_FILE"
            else
                mkdir -p "$(dirname "$CONFIG_FILE")"
                echo "[auto_update]" >> "$CONFIG_FILE"
                echo "enabled=false" >> "$CONFIG_FILE"
            fi
            echo "❌ Auto-updates disabled"
            log_update "Auto-updates disabled by user"
            ;;
        *)
            echo "Usage: $0 {daemon|check|status|enable|disable}"
            echo ""
            echo "Commands:"
            echo "  daemon  - Run continuous auto-update daemon (default)"
            echo "  check   - Check for updates once"
            echo "  status  - Show recent auto-update activity"
            echo "  enable  - Enable auto-updates"
            echo "  disable - Disable auto-updates"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"