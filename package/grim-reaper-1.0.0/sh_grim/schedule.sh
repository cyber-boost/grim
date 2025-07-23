#!/bin/bash
# Grimm Schedule Module: Cron-like scheduling and automation

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/schedule.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Schedule Module"
    echo "Usage: schedule.sh <command> [options]"
    echo ""
    echo "Purpose: Cron-like scheduling and automation for Grimm tasks,"
    echo "         with intelligent job management and monitoring."
    echo ""
    echo "Commands:"
    echo "  add <name> <schedule> <command>  - Add a scheduled job"
    echo "  remove <name>                    - Remove a scheduled job"
    echo "  list                             - List all scheduled jobs"
    echo "  run <name>                       - Run a scheduled job immediately"
    echo "  enable <name>                    - Enable a scheduled job"
    echo "  disable <name>                   - Disable a scheduled job"
    echo "  history [name]                   - Show job run history"
    echo "  help, -h, --help                 - Show this help message"
    echo ""
    echo "Schedule format: standard cron (e.g. '0 2 * * *')"
    echo "Examples:"
    echo "  ./schedule.sh add daily_backup '0 2 * * *' './reaper.sh backup daily'"
    echo "  ./schedule.sh list"
    echo "  ./schedule.sh run daily_backup"
    echo "  ./schedule.sh remove daily_backup"
    echo "  ./schedule.sh help"
}

# Initialize schedule database tables
init_schedule_db() {
    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS schedule_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    schedule TEXT NOT NULL,
    command TEXT NOT NULL,
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS schedule_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER,
    run_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT,
    output TEXT,
    FOREIGN KEY (job_id) REFERENCES schedule_jobs(id)
);
CREATE INDEX IF NOT EXISTS idx_schedule_jobs_name ON schedule_jobs(name);
CREATE INDEX IF NOT EXISTS idx_schedule_history_job_id ON schedule_history(job_id);
EOF
    log "Schedule database initialized"
}

# Add a scheduled job
add_job() {
    local name="$1"
    local schedule="$2"
    shift 2
    local command="$*"
    if [ -z "$name" ] || [ -z "$schedule" ] || [ -z "$command" ]; then
        log_error "Missing arguments for add"
        show_help
        return 1
    fi
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO schedule_jobs (name, schedule, command, enabled) VALUES ('$name', '$schedule', '$command', 1);" 2>/dev/null
    log "Added job: $name ($schedule) -> $command"
    "$NOTIFY_MODULE" send info "Job Added" "Scheduled job added: $name" "{\"name\": \"$name\", \"schedule\": \"$schedule\", \"command\": \"$command\"}"
}

# Remove a scheduled job
remove_job() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Missing job name for remove"
        show_help
        return 1
    fi
    sqlite3 "$DB_PATH" "DELETE FROM schedule_jobs WHERE name='$name';" 2>/dev/null
    log "Removed job: $name"
    "$NOTIFY_MODULE" send info "Job Removed" "Scheduled job removed: $name" "{\"name\": \"$name\"}"
}

# List all scheduled jobs
list_jobs() {
    echo -e "\n${CYAN}=== Scheduled Jobs ===${NC}"
    sqlite3 "$DB_PATH" "SELECT name, schedule, command, enabled, created_at FROM schedule_jobs;" 2>/dev/null | while IFS='|' read -r name schedule command enabled created; do
        local status="DISABLED"
        [ "$enabled" = "1" ] && status="ENABLED"
        echo "- $name: $schedule ($status) -> $command [created: $created]"
    done
    echo ""
}

# Run a scheduled job immediately
run_job() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Missing job name for run"
        show_help
        return 1
    fi
    local job_info=$(sqlite3 "$DB_PATH" "SELECT id, command FROM schedule_jobs WHERE name='$name' AND enabled=1;" 2>/dev/null)
    if [ -z "$job_info" ]; then
        log_error "Job not found or disabled: $name"
        return 1
    fi
    local job_id=$(echo "$job_info" | cut -d'|' -f1)
    local command=$(echo "$job_info" | cut -d'|' -f2-)
    log "Running job: $name -> $command"
    local output
    output=$(eval "$command" 2>&1)
    local status=$?
    sqlite3 "$DB_PATH" "INSERT INTO schedule_history (job_id, status, output) VALUES ($job_id, '$status', '$(echo "$output" | sed "s/'/''/g")');" 2>/dev/null
    if [ $status -eq 0 ]; then
        log "Job $name completed successfully"
        "$NOTIFY_MODULE" send success "Job Success" "Job $name completed successfully" "{\"name\": \"$name\", \"output\": \"$(echo "$output" | head -c 1000)\"}"
    else
        log_error "Job $name failed"
        "$NOTIFY_MODULE" send error "Job Failed" "Job $name failed" "{\"name\": \"$name\", \"output\": \"$(echo "$output" | head -c 1000)\"}"
    fi
}

# Enable a scheduled job
enable_job() {
    local name="$1"
    sqlite3 "$DB_PATH" "UPDATE schedule_jobs SET enabled=1 WHERE name='$name';" 2>/dev/null
    log "Enabled job: $name"
}

# Disable a scheduled job
disable_job() {
    local name="$1"
    sqlite3 "$DB_PATH" "UPDATE schedule_jobs SET enabled=0 WHERE name='$name';" 2>/dev/null
    log "Disabled job: $name"
}

# Show job run history
show_history() {
    local name="$1"
    local job_id=""
    if [ -n "$name" ]; then
        job_id=$(sqlite3 "$DB_PATH" "SELECT id FROM schedule_jobs WHERE name='$name';" 2>/dev/null)
    fi
    echo -e "\n${CYAN}=== Job Run History ===${NC}"
    if [ -n "$job_id" ]; then
        sqlite3 "$DB_PATH" "SELECT run_time, status, output FROM schedule_history WHERE job_id=$job_id ORDER BY run_time DESC LIMIT 10;" 2>/dev/null | while IFS='|' read -r run_time status output; do
            echo "[$run_time] Status: $status"
            echo "Output: $output"
            echo "---"
        done
    else
        sqlite3 "$DB_PATH" "SELECT run_time, status, output FROM schedule_history ORDER BY run_time DESC LIMIT 10;" 2>/dev/null | while IFS='|' read -r run_time status output; do
            echo "[$run_time] Status: $status"
            echo "Output: $output"
            echo "---"
        done
    fi
    echo ""
}

# Main command handler
main() {
    init_schedule_db
    case "${1:-}" in
        add)
            add_job "$2" "$3" "${@:4}"
            ;;
        remove)
            remove_job "$2"
            ;;
        list)
            list_jobs
            ;;
        run)
            run_job "$2"
            ;;
        enable)
            enable_job "$2"
            ;;
        disable)
            disable_job "$2"
            ;;
        history)
            show_history "$2"
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