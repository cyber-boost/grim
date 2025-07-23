#!/bin/bash
# Grim Reaper Unified Command Router
# Routes all grim commands to appropriate modules

set -euo pipefail

GRIM_ROOT="/opt/reaper"
cd "$GRIM_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Show help if no arguments
if [[ $# -eq 0 ]]; then
    echo -e "${CYAN}🗡️  Grim Reaper Unified Command Interface${NC}"
    echo ""
    echo "Usage: grim <command> [options]"
    echo ""
    echo "Core Commands:"
    echo "  health                   Check all systems health"
    echo "  status                   Overall system status"
    echo "  backup <path>            Orchestrated backup"
    echo "  restore <backup>         Coordinated restore"
    echo "  scan <path>              Unified file scanning"
    echo "  monitor <path>           Start monitoring"
    echo "  web                      Start web interface"
    echo ""
    echo "Command Categories:"
    echo "  backup-*                 Backup operations"
    echo "  monitor-*                Monitoring commands"
    echo "  security-*               Security operations"
    echo "  ai-*                     AI/ML commands"
    echo "  optimize-*               System optimization"
    echo "  config-*                 Configuration management"
    echo "  emergency-*              Emergency commands"
    echo ""
    echo "Examples:"
    echo "  grim health              # Check system health"
    echo "  grim backup /data        # Backup directory"
    echo "  grim monitor-start /path # Start monitoring"
    echo "  grim security-audit      # Security audit"
    echo ""
    echo "For full command list: grim help-all"
    exit 0
fi

COMMAND="$1"
shift || true

case "$COMMAND" in
    # Core Operations
    health)
        python3 scythe/scythe.py health
        ;;
    status)
        python3 scythe/scythe.py status
        ;;
    backup)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim backup <path> [--name <name>]"
        fi
        python3 scythe/scythe.py backup "$@"
        ;;
    restore)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim restore <backup>"
        fi
        ./sh_grim/restore.sh recover "$@"
        ;;
    scan)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim scan <path>"
        fi
        ./sh_grim/scan.sh full "$@"
        ;;
    monitor)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim monitor <path>"
        fi
        ./sh_grim/monitor.sh start "$@"
        ;;
    web)
        source /opt/grim_venv/bin/activate 2>/dev/null || true
        python3 py_grim/grim_web/app.py
        ;;
    
    # Backup Operations
    backup-create)
        if [[ $# -lt 2 ]]; then
            error "Usage: grim backup-create <type> <path>"
        fi
        ./sh_grim/backup.sh create "$@"
        ;;
    backup-list)
        ./sh_grim/backup.sh list "$@"
        ;;
    backup-verify)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim backup-verify <backup>"
        fi
        ./sh_grim/backup.sh verify "$@"
        ;;
    backup-schedule)
        if [[ $# -lt 2 ]]; then
            error "Usage: grim backup-schedule <frequency> <path>"
        fi
        ./sh_grim/schedule.sh add "0 2 * * *" "./backup.sh create $1 $2"
        ;;
    backup-full)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim backup-full <path>"
        fi
        ./sh_grim/backup_core.sh full "$@"
        ;;
    backup-incremental)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim backup-incremental <path>"
        fi
        ./sh_grim/backup_core.sh incremental "$@"
        ;;
    backup-differential)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim backup-differential <path>"
        fi
        ./sh_grim/backup_core.sh differential "$@"
        ;;
    
    # Monitoring Commands
    monitor-start)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim monitor-start <path>"
        fi
        ./sh_grim/monitor.sh start "$@"
        ;;
    monitor-stop)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim monitor-stop <path>"
        fi
        ./sh_grim/monitor.sh stop "$@"
        ;;
    monitor-status)
        ./sh_grim/monitor.sh status "$@"
        ;;
    monitor-events)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim monitor-events <path>"
        fi
        ./sh_grim/monitor.sh events "$@"
        ;;
    monitor-performance)
        ./sh_grim/performance.sh monitor
        ;;
    lookouts-start)
        ./sh_grim/lookouts.sh start
        ;;
    lookouts-scan)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim lookouts-scan <path>"
        fi
        ./sh_grim/lookouts.sh scan "$@"
        ;;
    
    # Security Commands
    security-audit)
        ./sh_grim/security.sh audit
        ;;
    security-encrypt)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim security-encrypt <file>"
        fi
        ./sh_grim/security.sh encrypt "$@"
        ;;
    security-decrypt)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim security-decrypt <file>"
        fi
        ./sh_grim/security.sh decrypt "$@"
        ;;
    security-scan)
        ./sh_grim/security.sh scan-vulnerabilities
        ;;
    quarantine-isolate)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim quarantine-isolate <file>"
        fi
        ./sh_grim/quarantine.sh isolate "$@"
        ;;
    quarantine-analyze)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim quarantine-analyze <file>"
        fi
        ./sh_grim/quarantine.sh analyze "$@"
        ;;
    quarantine-restore)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim quarantine-restore <file>"
        fi
        ./sh_grim/quarantine.sh restore "$@"
        ;;
    quarantine-list)
        ./sh_grim/quarantine.sh list
        ;;
    
    # License Protection
    license-install)
        if [[ $# -lt 3 ]]; then
            error "Usage: grim license-install <path> <id> <name>"
        fi
        ./sh_grim/scythe.sh install "$@"
        ;;
    license-start)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim license-start <id>"
        fi
        ./sh_grim/scythe.sh start "$@"
        ;;
    license-stop)
        ./sh_grim/scythe.sh stop
        ;;
    license-status)
        ./sh_grim/scythe.sh status
        ;;
    license-check)
        ./sh_grim/scythe.sh check
        ;;
    license-report)
        ./sh_grim/scythe.sh report summary
        ;;
    
    # AI & Machine Learning
    ai-analyze)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim ai-analyze <path>"
        fi
        ./sh_grim/ai_decision_engine.sh analyze "$@"
        ;;
    ai-recommend)
        ./sh_grim/ai_decision_engine.sh recommend
        ;;
    ai-train)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim ai-train <model>"
        fi
        ./sh_grim/ai_train.sh train "$@"
        ;;
    ai-predict)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim ai-predict <file>"
        fi
        ./sh_grim/ai_decision_engine.sh predict "$@"
        ;;
    ai-setup)
        ./sh_grim/ai_integration.sh setup
        ;;
    ai-optimize)
        ./sh_grim/ai_integration.sh optimize
        ;;
    smart-suggestions)
        ./sh_grim/smart_suggestions.sh analyze
        ;;
    
    # System Maintenance
    optimize-all)
        ./sh_grim/blacksmith.sh optimize all
        ;;
    optimize-storage)
        ./sh_grim/smart_suggestions.sh storage
        ;;
    optimize-performance)
        ./sh_grim/smart_suggestions.sh performance
        ;;
    heal)
        ./sh_grim/healer.sh heal
        ;;
    heal-diagnose)
        ./sh_grim/healer.sh diagnose
        ;;
    heal-monitor)
        ./sh_grim/healer.sh monitor
        ;;
    cleanup-all)
        ./sh_grim/cleanup.sh all
        ;;
    cleanup-logs)
        ./sh_grim/cleanup.sh logs
        ;;
    cleanup-temp)
        ./sh_grim/cleanup.sh temp
        ;;
    cleanup-backups)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim cleanup-backups <days>"
        fi
        ./sh_grim/cleanup.sh backups "$@"
        ;;
    
    # Compression Operations
    compress)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim compress <file> [--algorithm <algo>]"
        fi
        if [[ -f "go_grim/build/grim-compression" ]]; then
            ./go_grim/build/grim-compression -input "$@"
        else
            ./sh_grim/compress.sh "$@"
        fi
        ;;
    compress-benchmark)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim compress-benchmark <path>"
        fi
        ./sh_grim/compress.sh benchmark "$@"
        ;;
    decompress)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim decompress <file>"
        fi
        ./sh_grim/compress.sh --decompress "$@"
        ;;
    
    # Reporting & Analytics
    report-daily)
        ./sh_grim/report.sh daily
        ;;
    report-backup)
        ./sh_grim/report.sh backup
        ;;
    report-security)
        ./sh_grim/report.sh security
        ;;
    report-performance)
        ./sh_grim/report.sh performance
        ;;
    report-compliance)
        ./sh_grim/audit.sh compliance
        ;;
    audit-start)
        ./sh_grim/audit.sh start
        ;;
    audit-report)
        ./sh_grim/audit.sh report
        ;;
    audit-search)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim audit-search <query>"
        fi
        ./sh_grim/audit.sh search "$@"
        ;;
    
    # Configuration Management
    config-get)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim config-get <key>"
        fi
        ./sh_grim/settings.sh get "$@"
        ;;
    config-set)
        if [[ $# -lt 2 ]]; then
            error "Usage: grim config-set <key> <value>"
        fi
        ./sh_grim/settings.sh set "$@"
        ;;
    config-export)
        ./sh_grim/settings.sh export
        ;;
    config-import)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim config-import <file>"
        fi
        ./sh_grim/settings.sh import "$@"
        ;;
    
    # Emergency Commands
    emergency-heal)
        ./sh_grim/healer.sh heal
        ;;
    emergency-isolate)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim emergency-isolate <file>"
        fi
        ./sh_grim/quarantine.sh isolate "$@"
        ;;
    emergency-restore)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim emergency-restore <backup>"
        fi
        ./sh_grim/restore.sh recover "$@"
        ;;
    emergency-encrypt)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim emergency-encrypt <path>"
        fi
        ./sh_grim/security.sh encrypt "$@"
        ;;
    
    # Build & Deployment
    build)
        ./admin/build.sh build
        ;;
    build-list)
        ./admin/build.sh list
        ;;
    deploy)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim deploy <build>"
        fi
        ./admin/deploy.sh deploy "$@"
        ;;
    deploy-latest)
        ./admin/deploy.sh deploy latest
        ;;
    deploy-rollback)
        if [[ $# -eq 0 ]]; then
            error "Usage: grim deploy-rollback <backup>"
        fi
        ./admin/deploy.sh rollback "$@"
        ;;
    deploy-status)
        ./admin/deploy.sh status
        ;;
    
    # Help
    help-all)
        cat "$GRIM_ROOT/commands.txt"
        ;;
    
    *)
        error "Unknown command: $COMMAND\nRun 'grim' for help or 'grim help-all' for full command list"
        ;;
esac
