#!/bin/bash
# Grimm Delete Operations Module: Advanced safe deletion with graveyard support
# Enhanced version with comprehensive safety features and Grim system integration

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TUSK_FILE="$GRIM_ROOT/config/grimm.tusk"
TUSK_PARSER="$GRIM_ROOT/bin/tusk_parser.sh"
LOG_FILE="$GRIM_ROOT/logs/delete.log"
GRAVEYARD_DIR="$GRIM_ROOT/graveyard"
GRAVEYARD_RETENTION_DAYS="${graveyard_retention_days:-30}"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Load Tusk config
source "$TUSK_PARSER" "$TUSK_FILE"

# Ensure graveyard directory exists
mkdir -p "$GRAVEYARD_DIR"

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
    echo -e "${CYAN}Grimm Delete Operations - Safe Deletion with Graveyard Support${NC}"
    echo "Usage: grim delete <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  delete <path> [options]     - Safely delete file/directory to graveyard"
    echo "  list                        - List graveyard contents"
    echo "  restore <file> [path]       - Restore from graveyard"
    echo "  purge                       - Remove expired files from graveyard"
    echo "  status                      - Show graveyard status and statistics"
    echo "  help, -h, --help            - Show this help message"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --force                     - Skip confirmation prompts"
    echo "  --permanent                 - Delete permanently (no graveyard)"
    echo "  --retention <days>          - Set custom retention period"
    echo "  --dry-run                   - Show what would be deleted"
    echo ""
    echo -e "${YELLOW}Safety Features:${NC}"
    echo "  - Automatic graveyard backup before deletion"
    echo "  - Configurable retention periods"
    echo "  - Interactive confirmation prompts"
    echo "  - Comprehensive logging"
    echo "  - Integration with Grim notification system"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  grim delete /path/to/file"
    echo "  grim delete /path/to/directory --force"
    echo "  grim delete list"
    echo "  grim delete restore file.2024-01-15-14:30:00.txt"
    echo "  grim delete purge"
}

confirm_action() {
    local prompt="$1"
    local confirm_word="REAP"
    if [[ "$delete_without_conf" == "true" ]] || [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    echo -ne "${RED}$prompt Type '$confirm_word' to confirm: ${NC}"
    read input
    [[ "$input" == "$confirm_word" ]]
}

# Generate timestamp for graveyard files
get_timestamp() {
    date '+%Y-%m-%d-%H:%M:%S'
}

# Calculate file/directory size
get_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "Unknown"
    else
        du -sh "$path" 2>/dev/null | cut -f1 || echo "Unknown"
    fi
}

# Move file/directory to graveyard with enhanced metadata
move_to_graveyard() {
    local source="$1"
    local timestamp=$(get_timestamp)
    local basename=$(basename "$source")
    local extension=""
    local name_without_ext="$basename"
    
    # Validate source exists
    if [[ ! -e "$source" ]]; then
        log "ERROR: Source does not exist: $source"
        echo -e "${RED}❌ Source does not exist: $source${NC}"
        return 1
    fi
    
    # Handle files with extensions
    if [[ -f "$source" && "$basename" =~ \. ]]; then
        extension="${basename##*.}"
        name_without_ext="${basename%.*}"
    fi
    
    # Create graveyard filename with timestamp
    local graveyard_name
    if [[ -n "$extension" ]]; then
        graveyard_name="${name_without_ext}.${timestamp}.${extension}"
    else
        graveyard_name="${basename}.${timestamp}"
    fi
    
    local graveyard_path="$GRAVEYARD_DIR/$graveyard_name"
    
    # Create metadata file
    local metadata_file="${graveyard_path}.meta"
    {
        echo "original_path=$source"
        echo "deleted_at=$timestamp"
        echo "size=$(get_size "$source")"
        echo "type=$(if [[ -d "$source" ]]; then echo "directory"; else echo "file"; fi)"
        echo "user=$(whoami)"
        echo "hostname=$(hostname)"
        echo "retention_days=$GRAVEYARD_RETENTION_DAYS"
    } > "$metadata_file"
    
    # Move to graveyard
    if mv "$source" "$graveyard_path" 2>/dev/null; then
        log "SUCCESS: Moved to graveyard: $source -> $graveyard_path"
        echo -e "${GREEN}✅ Moved to graveyard: $source${NC}"
        echo "Graveyard path: $graveyard_path"
        
        # Send notification
        if [[ -f "$NOTIFY_MODULE" ]]; then
            "$NOTIFY_MODULE" send info "File Deleted" "Moved to graveyard: $source" "{\"source\": \"$source\", \"graveyard_path\": \"$graveyard_path\", \"size\": \"$(get_size "$source")\"}"
        fi
        
        return 0
    else
        log "ERROR: Failed to move to graveyard: $source"
        echo -e "${RED}❌ Failed to move to graveyard: $source${NC}"
        rm -f "$metadata_file"
        return 1
    fi
}

# List graveyard contents with enhanced information
list_graveyard() {
    if [[ ! -d "$GRAVEYARD_DIR" ]] || [[ -z "$(ls -A "$GRAVEYARD_DIR" 2>/dev/null)" ]]; then
        echo -e "${CYAN}Graveyard is empty.${NC}"
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    GRAVEYARD CONTENTS                        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Retention period: ${GRAVEYARD_RETENTION_DAYS} days                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - (GRAVEYARD_RETENTION_DAYS * 24 * 60 * 60)))
    local total_files=0
    local total_size=0
    local expired_count=0
    
    while IFS= read -r -d '' file; do
        # Skip metadata files
        if [[ "$file" == *.meta ]]; then
            continue
        fi
        
        local filename=$(basename "$file")
        local file_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
        local file_date=$(date -d "@$file_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
        local size=$(get_size "$file")
        local type=""
        
        # Determine if it's a file or directory
        if [[ -d "$file" ]]; then
            type=" [DIR]"
        else
            type=" [FILE]"
        fi
        
        # Check if file is expired
        local status=""
        if [[ $file_time -lt $cutoff_time ]]; then
            status=" [EXPIRED]"
            expired_count=$((expired_count + 1))
        fi
        
        total_files=$((total_files + 1))
        
        echo -e "${YELLOW}$filename$type$status${NC}"
        echo "  Date: $file_date"
        echo "  Size: $size"
        echo "  Path: $file"
        
        # Show metadata if available
        local metadata_file="${file}.meta"
        if [[ -f "$metadata_file" ]]; then
            local original_path=$(grep "^original_path=" "$metadata_file" | cut -d'=' -f2)
            echo "  Original: $original_path"
        fi
        echo ""
    done < <(find "$GRAVEYARD_DIR" -mindepth 1 -type f -o -type d -print0 2>/dev/null | sort -z)
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                        SUMMARY                               ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  Total files: $total_files${NC}"
    echo -e "${CYAN}║  Expired files: $expired_count${NC}"
    echo -e "${CYAN}║  Retention period: ${GRAVEYARD_RETENTION_DAYS} days${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Restore file/directory from graveyard with enhanced safety
restore_from_graveyard() {
    local graveyard_file="$1"
    local restore_path="$2"
    
    if [[ -z "$graveyard_file" ]]; then
        echo -e "${RED}❌ Usage: grim delete restore <graveyard_file> [restore_path]${NC}"
        echo "Available files:"
        list_graveyard
        exit 1
    fi
    
    # If graveyard_file doesn't have full path, assume it's in graveyard
    if [[ ! "$graveyard_file" =~ ^/ ]]; then
        graveyard_file="$GRAVEYARD_DIR/$graveyard_file"
    fi
    
    if [[ ! -e "$graveyard_file" ]]; then
        echo -e "${RED}❌ File/directory not found in graveyard: $graveyard_file${NC}"
        exit 1
    fi
    
    # Extract original filename (remove timestamp)
    local filename=$(basename "$graveyard_file")
    local original_name=""
    
    # Parse timestamp format: name.YYYY-MM-DD-HH:MM:SS.ext
    if [[ "$filename" =~ ^(.+)\.([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}:[0-9]{2}:[0-9]{2})(\.[^.]+)?$ ]]; then
        original_name="${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
    else
        original_name="$filename"
    fi
    
    # Determine restore path
    if [[ -z "$restore_path" ]]; then
        restore_path="./$original_name"
    fi
    
    # Check if restore path already exists
    if [[ -e "$restore_path" ]]; then
        echo -e "${YELLOW}⚠️  Restore path already exists: $restore_path${NC}"
        if ! confirm_action "Overwrite existing file/directory? "; then
            echo "Restore cancelled."
            exit 1
        fi
    fi
    
    # Restore file/directory
    if mv "$graveyard_file" "$restore_path"; then
        # Remove metadata file if it exists
        local metadata_file="${graveyard_file}.meta"
        if [[ -f "$metadata_file" ]]; then
            rm -f "$metadata_file"
        fi
        
        log "SUCCESS: Restored from graveyard: $graveyard_file -> $restore_path"
        echo -e "${GREEN}✅ Restored successfully${NC}"
        if [[ -d "$restore_path" ]]; then
            echo "Directory restored: $restore_path"
        else
            echo "File restored: $restore_path"
        fi
        
        # Send notification
        if [[ -f "$NOTIFY_MODULE" ]]; then
            "$NOTIFY_MODULE" send success "File Restored" "Restored from graveyard: $restore_path" "{\"restore_path\": \"$restore_path\", \"graveyard_file\": \"$graveyard_file\"}"
        fi
    else
        log "ERROR: Failed to restore from graveyard: $graveyard_file"
        echo -e "${RED}❌ Failed to restore file/directory.${NC}"
        exit 1
    fi
}

# Purge expired files from graveyard with enhanced reporting
purge_graveyard() {
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - (GRAVEYARD_RETENTION_DAYS * 24 * 60 * 60)))
    local expired_count=0
    local total_size=0
    local purged_size=0
    
    echo -e "${CYAN}=== Purging Expired Files ===${NC}"
    echo "Retention period: ${GRAVEYARD_RETENTION_DAYS} days"
    echo "Cutoff date: $(date -d "@$cutoff_time" '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    if ! confirm_action "Are you sure you want to purge expired files? "; then
        echo "Purge cancelled."
        return 1
    fi
    
    while IFS= read -r -d '' file; do
        # Skip metadata files
        if [[ "$file" == *.meta ]]; then
            continue
        fi
        
        local file_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
        if [[ $file_time -lt $cutoff_time ]]; then
            local size=$(stat -c %s "$file" 2>/dev/null || echo "0")
            purged_size=$((purged_size + size))
            
            if rm -rf "$file"; then
                # Remove metadata file if it exists
                local metadata_file="${file}.meta"
                if [[ -f "$metadata_file" ]]; then
                    rm -f "$metadata_file"
                fi
                
                log "PURGED: $file"
                echo -e "${GREEN}✅ Purged: $(basename "$file")${NC}"
                expired_count=$((expired_count + 1))
            else
                log "ERROR: Failed to purge file: $file"
                echo -e "${RED}❌ Failed to purge: $(basename "$file")${NC}"
            fi
        fi
    done < <(find "$GRAVEYARD_DIR" -mindepth 1 -type f -o -type d -print0 2>/dev/null)
    
    echo ""
    echo -e "${CYAN}=== Purge Summary ===${NC}"
    echo "Files purged: $expired_count"
    echo "Space freed: $(numfmt --to=iec $purged_size)"
    
    # Send notification
    if [[ -f "$NOTIFY_MODULE" ]] && [[ $expired_count -gt 0 ]]; then
        "$NOTIFY_MODULE" send warning "Graveyard Purged" "Purged $expired_count expired files" "{\"expired_count\": \"$expired_count\", \"space_freed\": \"$(numfmt --to=iec $purged_size)\"}"
    fi
}

# Show graveyard status and statistics
show_status() {
    echo -e "${CYAN}=== Graveyard Status ===${NC}"
    
    if [[ ! -d "$GRAVEYARD_DIR" ]]; then
        echo "Graveyard directory does not exist."
        return 1
    fi
    
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - (GRAVEYARD_RETENTION_DAYS * 24 * 60 * 60)))
    local total_files=0
    local total_size=0
    local expired_count=0
    local expired_size=0
    
    while IFS= read -r -d '' file; do
        # Skip metadata files
        if [[ "$file" == *.meta ]]; then
            continue
        fi
        
        local file_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
        local size=$(stat -c %s "$file" 2>/dev/null || echo "0")
        
        total_files=$((total_files + 1))
        total_size=$((total_size + size))
        
        if [[ $file_time -lt $cutoff_time ]]; then
            expired_count=$((expired_count + 1))
            expired_size=$((expired_size + size))
        fi
    done < <(find "$GRAVEYARD_DIR" -mindepth 1 -type f -o -type d -print0 2>/dev/null)
    
    echo "Total files: $total_files"
    echo "Total size: $(numfmt --to=iec $total_size)"
    echo "Expired files: $expired_count"
    echo "Expired size: $(numfmt --to=iec $expired_size)"
    echo "Retention period: ${GRAVEYARD_RETENTION_DAYS} days"
    echo "Cutoff date: $(date -d "@$cutoff_time" '+%Y-%m-%d %H:%M:%S')"
    
    if [[ $expired_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Run 'grim delete purge' to remove expired files${NC}"
    fi
}

# Main command handler
main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        delete)
            local target="$1"
            shift || true
            
            # Parse options
            local FORCE=false
            local PERMANENT=false
            local DRY_RUN=false
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --force)
                        FORCE=true
                        shift
                        ;;
                    --permanent)
                        PERMANENT=true
                        shift
                        ;;
                    --dry-run)
                        DRY_RUN=true
                        shift
                        ;;
                    --retention)
                        GRAVEYARD_RETENTION_DAYS="$2"
                        shift 2
                        ;;
                    *)
                        echo -e "${RED}❌ Unknown option: $1${NC}"
                        exit 1
                        ;;
                esac
            done
            
            if [[ -z "$target" ]]; then
                echo -e "${RED}❌ Target path is required${NC}"
                show_help
                exit 1
            fi
            
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "${CYAN}=== DRY RUN ===${NC}"
                echo "Would delete: $target"
                echo "Size: $(get_size "$target")"
                if [[ "$PERMANENT" == "true" ]]; then
                    echo "Mode: Permanent deletion"
                else
                    echo "Mode: Move to graveyard"
                fi
                return 0
            fi
            
            if [[ "$PERMANENT" == "true" ]]; then
                if confirm_action "Are you sure you want to PERMANENTLY delete $target? "; then
                    if rm -rf "$target"; then
                        log "PERMANENT DELETE: $target"
                        echo -e "${GREEN}✅ Permanently deleted: $target${NC}"
                    else
                        log "ERROR: Failed to delete: $target"
                        echo -e "${RED}❌ Failed to delete: $target${NC}"
                        return 1
                    fi
                else
                    echo "Deletion cancelled."
                    return 1
                fi
            else
                move_to_graveyard "$target"
            fi
            ;;
        list)
            list_graveyard
            ;;
        restore)
            restore_from_graveyard "$@"
            ;;
        purge)
            purge_graveyard
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