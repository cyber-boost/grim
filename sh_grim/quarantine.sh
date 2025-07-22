#!/bin/bash
# Grimm Quarantine Module: Isolate suspicious or corrupted files

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/quarantine.log"
QUARANTINE_DIR="${QUARANTINE_DIR:-$GRIM_ROOT/quarantine}"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Quarantine Module"
    echo "Usage: quarantine.sh <command> [options]"
    echo ""
    echo "Purpose: Securely isolate suspicious, corrupted, or unauthorized files,"
    echo "         with full audit trail and restoration capabilities."
    echo ""
    echo "Commands:"
    echo "  isolate <file> [reason]         - Quarantine a file"
    echo "  release <file>                  - Restore a quarantined file"
    echo "  list [status]                   - List quarantined files"
    echo "  status <file>                   - Show quarantine status"
    echo "  purge [days]                    - Permanently delete old quarantined files"
    echo "  audit [file]                    - Show audit trail for a file"
    echo "  help, -h, --help                - Show this help message"
    echo ""
    echo "Options:"
    echo "  --reason <text>                 - Reason for quarantine"
    echo "  --user <username>               - User performing the action"
    echo "  --force                         - Force quarantine even if in use"
    echo "  --dry-run                       - Show what would be done"
    echo "  --quiet                         - Suppress normal output"
    echo "  --verbose                       - Show detailed information"
    echo ""
    echo "Examples:"
    echo "  ./quarantine.sh isolate /tmp/suspicious.sh 'Malware detected'"
    echo "  ./quarantine.sh release /quarantine/suspicious.sh"
    echo "  ./quarantine.sh list active"
    echo "  ./quarantine.sh status /quarantine/suspicious.sh"
    echo "  ./quarantine.sh purge 30"
    echo "  ./quarantine.sh audit /quarantine/suspicious.sh"
    echo "  ./quarantine.sh help"
    echo ""
    echo "Integration:"
    echo "  - Integrates with monitor, health, and backup modules"
    echo "  - Sends notifications via notify module"
    echo "  - Maintains full audit trail in database"
    echo "  - Supports automated and manual quarantine actions"
}

# Initialize quarantine database tables
init_quarantine_db() {
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS quarantined_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    original_path TEXT NOT NULL,
    quarantine_path TEXT NOT NULL,
    reason TEXT,
    user TEXT,
    status TEXT DEFAULT 'active',
    quarantined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_at TIMESTAMP,
    purged_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS quarantine_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id INTEGER,
    action TEXT NOT NULL,
    user TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT,
    FOREIGN KEY (file_id) REFERENCES quarantined_files(id)
);

CREATE INDEX IF NOT EXISTS idx_quarantined_files_status ON quarantined_files(status);
CREATE INDEX IF NOT EXISTS idx_quarantined_files_path ON quarantined_files(original_path);
CREATE INDEX IF NOT EXISTS idx_quarantine_audit_file_id ON quarantine_audit(file_id);
EOF
    log "Quarantine database initialized"
}

# Main function
main() {
    case "${1:-}" in
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 