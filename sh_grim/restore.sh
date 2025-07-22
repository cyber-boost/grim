#!/bin/bash
# Grimm Restore Operations Module: Comprehensive backup restoration and recovery
# Advanced version with full Grim system integration and enhanced safety features

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TUSK_FILE="$GRIM_ROOT/config/grimm.tusk"
TUSK_PARSER="$GRIM_ROOT/bin/tusk_parser.sh"
LOG_FILE="$GRIM_ROOT/logs/restore.log"
BACKUP_ROOT="$GRIM_ROOT/backups"
GRAVEYARD_DIR="$GRIM_ROOT/graveyard"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Load Tusk config
source "$TUSK_PARSER" "$TUSK_FILE"

# Ensure directories exist
mkdir -p "$BACKUP_ROOT" "$GRAVEYARD_DIR" "$(dirname "$LOG_FILE")"

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

show_help() {
    echo -e "${CYAN}Grimm Restore Operations - Comprehensive Backup Restoration${NC}"
    echo "Usage: grim restore <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  restore <source> <target> [options]  - Restore backup to target location"
    echo "  list [type]                          - List available backups"
    echo "  info <backup>                        - Show backup information"
    echo "  verify <backup>                      - Verify backup integrity"
    echo "  extract <backup> <path>              - Extract specific files from backup"
    echo "  search <pattern>                     - Search for files in backups"
    echo "  schedule <backup> <cron>             - Schedule automatic restore"
    echo "  status                               - Show restore system status"
    echo "  help, -h, --help                     - Show this help message"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --force                              - Skip confirmation prompts"
    echo "  --dry-run                            - Show what would be restored"
    echo "  --overwrite                          - Overwrite existing files"
    echo "  --preserve-permissions               - Preserve original permissions"
    echo "  --exclude <pattern>                  - Exclude files matching pattern"
    echo "  --include <pattern>                  - Include only files matching pattern"
    echo ""
    echo -e "${YELLOW}Backup Types:${NC}"
    echo "  hourly, daily, weekly, monthly       - Standard backup frequencies"
    echo "  graveyard                            - Restore from graveyard"
    echo "  custom                               - Custom backup archives"
    echo ""
    echo -e "${YELLOW}Safety Features:${NC}"
    echo "  - Interactive confirmation prompts"
    echo "  - Backup integrity verification"
    echo "  - Comprehensive logging"
    echo "  - Integration with Grim notification system"
    echo "  - Automatic conflict resolution"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  grim restore /backups/daily/backup.tar.gz /target/dir"
    echo "  grim restore list daily"
    echo "  grim restore info backup.tar.gz"
    echo "  grim restore verify backup.tar.gz"
    echo "  grim restore extract backup.tar.gz /specific/file"
    echo "  grim restore search '*.conf'"
}

confirm_action() {
    local prompt="$1"
    local confirm_word="REAP"
    if [[ "$restore_without_conf" == "true" ]] || [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    echo -ne "${RED}$prompt Type '$confirm_word' to confirm: ${NC}"
    read input
    [[ "$input" == "$confirm_word" ]]
}

# Get backup information
get_backup_info() {
    local backup_path="$1"
    
    if [[ ! -f "$backup_path" ]]; then
        echo -e "${RED}❌ Backup file not found: $backup_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Backup Information ===${NC}"
    echo "File: $backup_path"
    echo "Size: $(du -sh "$backup_path" | cut -f1)"
    echo "Modified: $(stat -c %y "$backup_path")"
    echo "Permissions: $(stat -c %a "$backup_path")"
    
    # Check if it's a tar.gz file
    if [[ "$backup_path" == *.tar.gz ]]; then
        echo ""
        echo -e "${YELLOW}Archive Contents:${NC}"
        tar -tzf "$backup_path" | head -20 | while read -r line; do
            echo "  $line"
        done
        
        local total_files=$(tar -tzf "$backup_path" | wc -l)
        echo ""
        echo "Total files in archive: $total_files"
        
        if [[ $total_files -gt 20 ]]; then
            echo "(Showing first 20 files)"
        fi
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"
    
    if [[ ! -f "$backup_path" ]]; then
        echo -e "${RED}❌ Backup file not found: $backup_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Verifying Backup Integrity ===${NC}"
    echo "File: $backup_path"
    
    # Check if it's a tar.gz file
    if [[ "$backup_path" == *.tar.gz ]]; then
        echo "Testing archive integrity..."
        if tar -tzf "$backup_path" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Archive integrity verified${NC}"
            return 0
        else
            echo -e "${RED}❌ Archive is corrupted${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Unknown archive format${NC}"
        return 1
    fi
}

# List available backups
list_backups() {
    local backup_type="${1:-}"
    
    echo -e "${CYAN}=== Available Backups ===${NC}"
    
    if [[ -z "$backup_type" ]]; then
        # List all backup types
        for freq in hourly daily weekly monthly; do
            local backup_dir="$BACKUP_ROOT/$freq"
            if [[ -d "$backup_dir" ]]; then
                local count=$(find "$backup_dir" -name "*.tar.gz" 2>/dev/null | wc -l)
                if [[ $count -gt 0 ]]; then
                    echo -e "${YELLOW}$freq backups ($count):${NC}"
                    find "$backup_dir" -name "*.tar.gz" -printf "  %T@ %p\n" 2>/dev/null | sort -nr | head -5 | while read -r timestamp path; do
                        local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
                        local size=$(du -sh "$path" | cut -f1)
                        echo "    $date - $size - $(basename "$path")"
                    done
                    echo ""
                fi
            fi
        done
        
        # List graveyard contents
        if [[ -d "$GRAVEYARD_DIR" ]] && [[ -n "$(ls -A "$GRAVEYARD_DIR" 2>/dev/null)" ]]; then
            local graveyard_count=$(find "$GRAVEYARD_DIR" -type f -o -type d 2>/dev/null | grep -v "\.meta$" | wc -l)
            if [[ $graveyard_count -gt 0 ]]; then
                echo -e "${YELLOW}graveyard items ($graveyard_count):${NC}"
                find "$GRAVEYARD_DIR" -type f -o -type d 2>/dev/null | grep -v "\.meta$" | head -5 | while read -r path; do
                    local date=$(stat -c %y "$path" | cut -d' ' -f1,2)
                    local size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "Unknown")
                    echo "    $date - $size - $(basename "$path")"
                done
                echo ""
            fi
        fi
    else
        # List specific backup type
        local backup_dir="$BACKUP_ROOT/$backup_type"
        if [[ "$backup_type" == "graveyard" ]]; then
            backup_dir="$GRAVEYARD_DIR"
        fi
        
        if [[ ! -d "$backup_dir" ]]; then
            echo -e "${RED}❌ Backup directory not found: $backup_dir${NC}"
            return 1
        fi
        
        echo -e "${YELLOW}$backup_type backups:${NC}"
        find "$backup_dir" -name "*.tar.gz" -printf "%T@ %p\n" 2>/dev/null | sort -nr | while read -r timestamp path; do
            local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
            local size=$(du -sh "$path" | cut -f1)
            echo "  $date - $size - $(basename "$path")"
        done
    fi
}

# Search for files in backups
search_backups() {
    local pattern="$1"
    
    if [[ -z "$pattern" ]]; then
        echo -e "${RED}❌ Search pattern is required${NC}"
        echo "Usage: grim restore search <pattern>"
        return 1
    fi
    
    echo -e "${CYAN}=== Searching Backups ===${NC}"
    echo "Pattern: $pattern"
    echo ""
    
    local found_count=0
    
    # Search in all backup types
    for freq in hourly daily weekly monthly; do
        local backup_dir="$BACKUP_ROOT/$freq"
        if [[ -d "$backup_dir" ]]; then
            find "$backup_dir" -name "*.tar.gz" 2>/dev/null | while read -r backup_file; do
                local matches=$(tar -tzf "$backup_file" 2>/dev/null | grep -i "$pattern" | wc -l)
                if [[ $matches -gt 0 ]]; then
                    echo -e "${YELLOW}$(basename "$backup_file") ($matches matches):${NC}"
                    tar -tzf "$backup_file" 2>/dev/null | grep -i "$pattern" | head -10 | while read -r file; do
                        echo "  $file"
                    done
                    if [[ $matches -gt 10 ]]; then
                        echo "  ... and $((matches - 10)) more"
                    fi
                    echo ""
                    found_count=$((found_count + matches))
                fi
            done
        fi
    done
    
    if [[ $found_count -eq 0 ]]; then
        echo -e "${YELLOW}No files found matching pattern: $pattern${NC}"
    else
        echo -e "${GREEN}Total matches found: $found_count${NC}"
    fi
}

# Extract specific files from backup
extract_from_backup() {
    local backup_path="$1"
    local extract_path="$2"
    
    if [[ -z "$backup_path" ]] || [[ -z "$extract_path" ]]; then
        echo -e "${RED}❌ Usage: grim restore extract <backup> <path>${NC}"
        return 1
    fi
    
    if [[ ! -f "$backup_path" ]]; then
        echo -e "${RED}❌ Backup file not found: $backup_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== Extracting from Backup ===${NC}"
    echo "Backup: $backup_path"
    echo "Extract path: $extract_path"
    
    # Check if file exists in backup
    if ! tar -tzf "$backup_path" | grep -q "$extract_path"; then
        echo -e "${RED}❌ File not found in backup: $extract_path${NC}"
        echo "Available files:"
        tar -tzf "$backup_path" | head -20
        return 1
    fi
    
    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    local temp_file="$temp_dir/$(basename "$extract_path")"
    
    # Extract specific file
    if tar -xzf "$backup_path" -C "$temp_dir" "$extract_path" 2>/dev/null; then
        echo -e "${GREEN}✅ File extracted successfully${NC}"
        echo "Extracted to: $temp_file"
        echo "Use 'cp \"$temp_file\" <destination>' to copy to desired location"
    else
        echo -e "${RED}❌ Failed to extract file${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Main restore function
perform_restore() {
    local source="$1"
    local target="$2"
    shift 2 || true
    
    # Parse options
    local FORCE=false
    local DRY_RUN=false
    local OVERWRITE=false
    local PRESERVE_PERMISSIONS=false
    local EXCLUDE_PATTERNS=()
    local INCLUDE_PATTERNS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --overwrite)
                OVERWRITE=true
                shift
                ;;
            --preserve-permissions)
                PRESERVE_PERMISSIONS=true
                shift
                ;;
            --exclude)
                EXCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            --include)
                INCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    # Validate source
    if [[ -z "$source" ]]; then
        echo -e "${RED}❌ Source backup is required${NC}"
        return 1
    fi
    
    # Handle different source types
    local actual_source="$source"
    if [[ ! -f "$source" ]]; then
        # Check if it's a relative path in backups
        for freq in hourly daily weekly monthly; do
            local backup_dir="$BACKUP_ROOT/$freq"
            if [[ -f "$backup_dir/$source" ]]; then
                actual_source="$backup_dir/$source"
                break
            fi
        done
        
        # Check if it's in graveyard
        if [[ ! -f "$actual_source" ]] && [[ -f "$GRAVEYARD_DIR/$source" ]]; then
            actual_source="$GRAVEYARD_DIR/$source"
        fi
    fi
    
    if [[ ! -f "$actual_source" ]]; then
        echo -e "${RED}❌ Backup file not found: $source${NC}"
        echo "Available backups:"
        list_backups
        return 1
    fi
    
    # Validate target
    if [[ -z "$target" ]]; then
        echo -e "${RED}❌ Target directory is required${NC}"
        return 1
    fi
    
    # Check if target exists and handle conflicts
    if [[ -e "$target" ]] && [[ "$OVERWRITE" != "true" ]]; then
        echo -e "${YELLOW}⚠️  Target already exists: $target${NC}"
        if ! confirm_action "Overwrite existing target? "; then
            echo "Restore cancelled."
            return 1
        fi
    fi
    
    # Show restore information
    echo -e "${CYAN}=== Restore Information ===${NC}"
    echo "Source: $actual_source"
    echo "Target: $target"
    echo "Size: $(du -sh "$actual_source" | cut -f1)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}=== DRY RUN ===${NC}"
        echo "Would restore: $actual_source -> $target"
        return 0
    fi
    
    # Confirm restore
    if ! confirm_action "Are you sure you want to restore this backup? "; then
        echo "Restore cancelled."
        return 1
    fi
    
    # Create target directory
    mkdir -p "$target"
    
    # Build tar command
    local tar_cmd="tar -xzf \"$actual_source\" -C \"$target\""
    
    # Add include/exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        tar_cmd="$tar_cmd --exclude=\"$pattern\""
    done
    
    for pattern in "${INCLUDE_PATTERNS[@]}"; do
        tar_cmd="$tar_cmd --include=\"$pattern\""
    done
    
    # Execute restore
    echo "Executing restore..."
    if eval "$tar_cmd"; then
        log "SUCCESS: Restored $actual_source to $target"
        echo -e "${GREEN}✅ Restore completed successfully${NC}"
        
        # Send notification
        if [[ -f "$NOTIFY_MODULE" ]]; then
            "$NOTIFY_MODULE" send success "Backup Restored" "Restored $actual_source to $target" "{\"source\": \"$actual_source\", \"target\": \"$target\"}"
        fi
        
        return 0
    else
        log "ERROR: Failed to restore $actual_source to $target"
        echo -e "${RED}❌ Restore failed${NC}"
        return 1
    fi
}

# Show restore system status
show_status() {
    echo -e "${CYAN}=== Restore System Status ===${NC}"
    
    # Check backup directories
    local total_backups=0
    for freq in hourly daily weekly monthly; do
        local backup_dir="$BACKUP_ROOT/$freq"
        if [[ -d "$backup_dir" ]]; then
            local count=$(find "$backup_dir" -name "*.tar.gz" 2>/dev/null | wc -l)
            echo "$freq backups: $count"
            total_backups=$((total_backups + count))
        else
            echo "$freq backups: 0 (directory not found)"
        fi
    done
    
    echo ""
    echo "Total backups: $total_backups"
    echo "Backup root: $BACKUP_ROOT"
    echo "Graveyard: $GRAVEYARD_DIR"
    echo "Log file: $LOG_FILE"
    
    # Check disk space
    echo ""
    echo -e "${YELLOW}Disk Space:${NC}"
    df -h "$BACKUP_ROOT" | tail -1
}

# Main command handler
main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        restore)
            perform_restore "$@"
            ;;
        list)
            list_backups "$@"
            ;;
        info)
            get_backup_info "${1:-}"
            ;;
        verify)
            verify_backup "${1:-}"
            ;;
        extract)
            extract_from_backup "$@"
            ;;
        search)
            search_backups "${1:-}"
            ;;
        status)
            show_status
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

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 