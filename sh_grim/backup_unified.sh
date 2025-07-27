#!/bin/bash
# Grim Unified Backup System
# Consolidates all backup functionality into a single, clean interface
# Replaces: backup.sh, backup_core.sh, auto_backup.sh, cloud_backup.sh

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Main backup command router
main() {
    local category="$1"
    shift
    
    case "$category" in
        # Basic backup operations
        "create")
            backup_create "$@"
            ;;
        "verify")
            backup_verify "$@"
            ;;
        "list")
            backup_list "$@"
            ;;
        "restore")
            backup_restore "$@"
            ;;
        "clean")
            backup_clean "$@"
            ;;
        
        # Auto-backup daemon operations
        "auto")
            auto_backup_commands "$@"
            ;;
        
        # Cloud backup operations
        "cloud")
            cloud_backup_commands "$@"
            ;;
        
        # Core/enterprise operations
        "core")
            core_backup_commands "$@"
            ;;
        
        # Development version control
        "dev")
            dev_commands "$@"
            ;;
        
        # Help and status
        "status")
            backup_status "$@"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        
        *)
            echo -e "${RED}Unknown backup command: $category${NC}"
            echo "Use 'grim backup help' for available commands"
            return 1
            ;;
    esac
}

# =============================================================================
# BASIC BACKUP OPERATIONS
# =============================================================================

backup_create() {
    echo "Executing: grim backup create $*"
    bash "$GRIM_ROOT/sh_grim/backup.sh" create "$@"
}

backup_verify() {
    echo "Executing: grim backup verify $*"
    bash "$GRIM_ROOT/sh_grim/backup.sh" verify "$@"
}

backup_list() {
    echo "Executing: grim backup list $*"
    bash "$GRIM_ROOT/sh_grim/backup.sh" list "$@"
}

backup_restore() {
    local subcommand="$1"
    shift
    
    case "$subcommand" in
        "auto"|"list-auto"|"restore-auto")
            echo "Executing: grim restore $subcommand $*"
            bash "$GRIM_ROOT/sh_grim/restore.sh" "$subcommand" "$@"
            ;;
        *)
            echo "Executing: grim restore $subcommand $*"
            bash "$GRIM_ROOT/sh_grim/restore.sh" restore "$subcommand" "$@"
            ;;
    esac
}

backup_clean() {
    echo "Executing: grim backup clean $*"
    bash "$GRIM_ROOT/sh_grim/backup.sh" clean "$@"
}

backup_status() {
    echo -e "${CYAN}=== Grim Unified Backup Status ===${NC}"
    echo ""
    
    # Basic backup status
    echo -e "${BLUE}📦 Basic Backups:${NC}"
    bash "$GRIM_ROOT/sh_grim/backup.sh" list 2>/dev/null || echo "  No basic backups found"
    echo ""
    
    # Auto-backup status
    echo -e "${BLUE}🤖 Auto-Backup Daemon:${NC}"
    bash "$GRIM_ROOT/sh_grim/auto_backup.sh" health 2>/dev/null || echo "  Daemon not running"
    echo ""
    
    # Cloud backup status
    echo -e "${BLUE}☁️  Cloud Backup:${NC}"
    bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" status 2>/dev/null || echo "  Cloud backup not configured"
    echo ""
}

# =============================================================================
# AUTO-BACKUP OPERATIONS
# =============================================================================

auto_backup_commands() {
    local command="$1"
    shift
    
    case "$command" in
        "start")
            echo "Executing: grim backup auto start $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" start "$@"
            ;;
        "stop")
            echo "Executing: grim backup auto stop $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" stop "$@"
            ;;
        "restart")
            echo "Executing: grim backup auto restart $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" restart "$@"
            ;;
        "status")
            echo "Executing: grim backup auto status $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" status "$@"
            ;;
        "health")
            echo "Executing: grim backup auto health $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" health "$@"
            ;;
        "decrypt")
            echo "Executing: grim backup auto decrypt $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" decrypt "$@"
            ;;
        "list-encrypted")
            echo "Executing: grim backup auto list-encrypted $*"
            bash "$GRIM_ROOT/sh_grim/auto_backup.sh" list-encrypted "$@"
            ;;
        "py"|"python")
            auto_backup_python_commands "$@"
            ;;
        "help"|"--help"|"-h")
            echo "Auto Backup Commands:"
            echo "  grim backup auto start                     - Start auto backup daemon (Bash)"
            echo "  grim backup auto stop                      - Stop auto backup daemon (Bash)"
            echo "  grim backup auto restart                   - Restart auto backup daemon (Bash)"
            echo "  grim backup auto status                    - Show current status and configuration (Bash)"
            echo "  grim backup auto health                    - Check daemon health status (Bash)"
            echo "  grim backup auto decrypt <file> [output]   - Decrypt encrypted backup (FREE license)"
            echo "  grim backup auto list-encrypted            - List encrypted backups"
            echo "  grim backup auto py <command>              - Python auto backup daemon"
            echo "  grim backup auto python <command>          - Python auto backup daemon (alias)"
            echo "  grim backup auto help                      - Show this help"
            ;;
        *)
            echo "Unknown auto-backup command: $command"
            echo "Use 'grim backup auto help' for available commands"
            return 1
            ;;
    esac
}

# Python Auto-Backup Commands
auto_backup_python_commands() {
    local command="$1"
    shift
    
    case "$command" in
        "start")
            echo "Executing: grim backup auto py start $*"
            python3 "$GRIM_ROOT/py_grim/auto_backup.py" start "$@"
            ;;
        "stop")
            echo "Executing: grim backup auto py stop $*"
            python3 "$GRIM_ROOT/py_grim/auto_backup.py" stop "$@"
            ;;
        "restart")
            echo "Executing: grim backup auto py restart $*"
            python3 "$GRIM_ROOT/py_grim/auto_backup.py" restart "$@"
            ;;
        "status")
            echo "Executing: grim backup auto py status $*"
            python3 "$GRIM_ROOT/py_grim/auto_backup.py" status "$@"
            ;;
        "health")
            echo "Executing: grim backup auto py health $*"
            python3 "$GRIM_ROOT/py_grim/auto_backup.py" health "$@"
            ;;
        "configure")
            echo "Executing: grim backup auto py configure $*"
            python3 "$GRIM_ROOT/py_grim/auto_backup.py" configure "$@"
            ;;
        "help"|"--help"|"-h")
            echo "Python Auto Backup Commands:"
            echo "  grim backup auto py start      - Start Python auto backup daemon"
            echo "  grim backup auto py stop       - Stop Python auto backup daemon"
            echo "  grim backup auto py restart    - Restart Python auto backup daemon"
            echo "  grim backup auto py status     - Show Python auto backup status"
            echo "  grim backup auto py health     - Check Python daemon health"
            echo "  grim backup auto py configure  - Configure Python auto backup"
            echo "  grim backup auto py help       - Show this help"
            ;;
        *)
            echo "Unknown Python auto-backup command: $command"
            echo "Use 'grim backup auto py help' for available commands"
            return 1
            ;;
    esac
}

# =============================================================================
# CLOUD BACKUP OPERATIONS
# =============================================================================

cloud_backup_commands() {
    local command="$1"
    shift
    
    case "$command" in
        "setup")
            echo "Executing: grim backup cloud setup $*"
            bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" setup "$@"
            ;;
        "upload")
            echo "Executing: grim backup cloud upload $*"
            bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" upload "$@"
            ;;
        "download")
            echo "Executing: grim backup cloud download $*"
            bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" download "$@"
            ;;
        "list")
            echo "Executing: grim backup cloud list $*"
            bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" list "$@"
            ;;
        "status")
            echo "Executing: grim backup cloud status $*"
            bash "$GRIM_ROOT/sh_grim/cloud_backup.sh" status "$@"
            ;;
        "help"|"--help"|"-h")
            echo "Cloud Backup Commands:"
            echo "  grim backup cloud setup                    - Setup cloud authentication"
            echo "  grim backup cloud upload <file> [provider] - Upload file to cloud storage"
            echo "  grim backup cloud download <key> [dest]    - Download file from cloud"
            echo "  grim backup cloud list                     - List cloud files"
            echo "  grim backup cloud status                   - Show cloud backup status"
            echo "  grim backup cloud help                     - Show this help"
            ;;
        *)
            echo "Unknown cloud-backup command: $command"
            echo "Use 'grim backup cloud help' for available commands"
            return 1
            ;;
    esac
}

# =============================================================================
# CORE/ENTERPRISE OPERATIONS
# =============================================================================

core_backup_commands() {
    local command="$1"
    shift
    
    case "$command" in
        "create")
            echo "Executing: grim backup core create $*"
            bash "$GRIM_ROOT/sh_grim/backup_core.sh" create "$@"
            ;;
        "verify")
            echo "Executing: grim backup core verify $*"
            bash "$GRIM_ROOT/sh_grim/backup_core.sh" verify "$@"
            ;;
        "restore")
            echo "Executing: grim backup core restore $*"
            bash "$GRIM_ROOT/sh_grim/backup_core.sh" restore "$@"
            ;;
        "status")
            echo "Executing: grim backup core status $*"
            bash "$GRIM_ROOT/sh_grim/backup_core.sh" status "$@"
            ;;
        "init")
            echo "Executing: grim backup core init $*"
            bash "$GRIM_ROOT/sh_grim/backup_core.sh" init "$@"
            ;;
        "help"|"--help"|"-h")
            echo "Core Backup Commands:"
            echo "  grim backup core create   - Core backup engine with progress tracking"
            echo "  grim backup core verify   - Core verification engine with retries"
            echo "  grim backup core restore  - Core restoration engine with safety checks"
            echo "  grim backup core status   - Core status and health monitoring"
            echo "  grim backup core init     - Initialize core configuration"
            echo "  grim backup core help     - Show this help"
            ;;
        *)
            echo "Unknown backup-core command: $command"
            echo "Use 'grim backup core help' for available commands"
            return 1
            ;;
    esac
}

# =============================================================================
# DEVELOPMENT VERSION CONTROL OPERATIONS
# =============================================================================

dev_commands() {
    echo "Executing: grim dev $*"
    bash "$GRIM_ROOT/sh_grim/fckgit.sh" "$@"
}

# =============================================================================
# HELP SYSTEM
# =============================================================================

show_help() {
    echo -e "${CYAN}Grim Unified Backup System${NC}"
    echo ""
    echo -e "${YELLOW}BASIC OPERATIONS:${NC}"
    echo "  grim backup create <source> [frequency]     - Create backup with intelligent scheduling"
    echo "  grim backup verify [file]                   - Verify backup integrity"
    echo "  grim backup list                            - List available backups"
    echo "  grim backup restore <backup> [destination]  - Restore from backup"
    echo "  grim backup clean [age]                     - Clean old backups"
    echo "  grim backup status                          - Show comprehensive backup status"
    echo ""
    echo -e "${YELLOW}AUTO-BACKUP DAEMON:${NC}"
    echo "  grim backup auto start                      - Start automatic backup daemon"
    echo "  grim backup auto stop                       - Stop automatic backup daemon"
    echo "  grim backup auto status                     - Show daemon status"
    echo "  grim backup auto decrypt <file>             - Decrypt encrypted backup"
    echo ""
    echo -e "${YELLOW}CLOUD STORAGE:${NC}"
    echo "  grim backup cloud setup                     - Configure cloud authentication"
    echo "  grim backup cloud upload <file>             - Upload to cloud storage"
    echo "  grim backup cloud download <key>            - Download from cloud"
    echo "  grim backup cloud list                      - List cloud files"
    echo ""
    echo -e "${YELLOW}ENTERPRISE/CORE:${NC}"
    echo "  grim backup core create <source> <dest>     - Enterprise-grade backup"
    echo "  grim backup core verify <backup>            - Advanced verification"
    echo "  grim backup core restore <backup> <dest>    - Advanced restoration"
    echo ""
    echo -e "${YELLOW}DEVELOPMENT VERSION CONTROL:${NC}"
    echo "  grim backup dev init                        - Initialize .g repository (lightweight git alternative)"
    echo "  grim backup dev track <files>               - Track files with compression"
    echo "  grim backup dev commit \"message\"            - Commit changes with backup integration"
    echo "  grim backup dev git <command>               - Safe git operations with auto-backup"
    echo ""
    echo -e "${YELLOW}SHORT ALIASES:${NC}"
    echo "  grim bu                                     - Short alias for 'grim backup'"
    echo "  grim bu create, grim bu auto start, etc.   - All commands work with 'bu'"
    echo ""
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "  grim backup create /home/user daily         - Daily backup of home directory"
    echo "  grim backup auto start                      - Start automatic monitoring"
    echo "  grim backup cloud upload myfile.tar.gz     - Upload to cloud storage"
    echo "  grim backup status                          - Check everything at once"
    echo ""
    echo "Use 'grim backup <category> help' for detailed help on each category"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main "$@" 