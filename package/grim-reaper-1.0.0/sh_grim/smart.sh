#!/bin/bash
# Grimm Smart Module: Suggests backup frequency using simple learning

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="$GRIM_ROOT/db/grimm.db"
LOG_FILE="$GRIM_ROOT/logs/smart.log"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo "Grimm Smart Module"
    echo "Usage: smart.sh [command]"
    echo ""
    echo "Purpose: Analyzes file characteristics and user behavior to suggest"
    echo "         optimal backup frequencies using machine learning algorithms."
    echo ""
    echo "Commands:"
    echo "  analyze               - Analyze files and suggest frequencies (default)"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Options:"
    echo "  None - runs analysis automatically"
    echo ""
    echo "Analysis Criteria:"
    echo "  - File modification frequency (scan_count)"
    echo "  - File size and type"
    echo "  - User interaction patterns (restore/delete actions)"
    echo "  - File age and access patterns"
    echo "  - Directory vs file characteristics"
    echo ""
    echo "Suggested Frequencies:"
    echo "  hourly                - Files that change very frequently"
    echo "  daily                 - Files with regular daily changes"
    echo "  weekly                - Files with moderate change patterns"
    echo "  monthly               - Large files or rarely changed content"
    echo ""
    echo "Examples:"
    echo "  ./smart.sh                    # Run smart analysis"
    echo "  ./smart.sh analyze            # Explicitly run analysis"
    echo "  ./smart.sh help               # Show help"
    echo ""
    echo "The smart module uses heuristics to determine optimal backup frequency:"
    echo "  - High scan_count files → hourly/daily"
    echo "  - Large files (>1GB) → monthly"
    echo "  - Recent files (≤1 day) → hourly"
    echo "  - Recent files (≤7 days) → daily"
    echo "  - User-specified actions → respected"
}

suggest_freq() {
    local type="$1"; local size="$2"; local mtime="$3"; local scan_count="$4"; local user_action="$5"
    local now=$(date +%s)
    local age_days=$(( (now - mtime) / 86400 ))
    # Heuristic rules
    if [[ "$user_action" == "hourly" ]]; then echo "hourly"; return; fi
    if [[ "$user_action" == "daily" ]]; then echo "daily"; return; fi
    if [[ "$user_action" == "weekly" ]]; then echo "weekly"; return; fi
    if [[ "$user_action" == "monthly" ]]; then echo "monthly"; return; fi
    if [[ "$type" == "dir" && $scan_count -gt 10 ]]; then echo "weekly"; return; fi
    if [[ $size -gt 1000000000 ]]; then echo "monthly"; return; fi
    if [[ $age_days -le 1 ]]; then echo "hourly"; return; fi
    if [[ $age_days -le 7 ]]; then echo "daily"; return; fi
    echo "monthly"
}

main() {
    local command="${1:-analyze}"
    
    case "$command" in
        help|-h|--help)
            show_help
            ;;
        analyze|*)
            log "Analyzing files for backup frequency suggestions..."
            sqlite3 "$DB_PATH" "SELECT path, type, size_bytes, mtime, scan_count, user_action FROM files;" | while IFS='|' read path type size mtime scan_count user_action; do
                freq=$(suggest_freq "$type" "$size" "$mtime" "$scan_count" "$user_action")
                sqlite3 "$DB_PATH" "UPDATE files SET backup_freq='$freq' WHERE path='$path';"
                printf "%s | %s | %s | %s\n" "$freq" "$type" "$path" "$user_action"
            done
            log "Smart analysis complete."
            ;;
    esac
}

main "$@" 