#!/bin/bash
# Grimm Report Module: Advanced status reporting and analytics

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="$GRIM_ROOT/db/grimm.db"
LOG_FILE="$GRIM_ROOT/logs/report.log"
CONFIG_FILE="$GRIM_ROOT/config/report.tsk"

# Module version
REPORT_VERSION="2.0.0"

# Default configuration
DEFAULT_CONFIG="
# Reporting Configuration
reports_enabled=true
auto_generation=true
report_retention=30
detailed_analytics=true
performance_metrics=true
trend_analysis=true
export_formats=text,json,csv
"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo "Grimm Report Module v$REPORT_VERSION"
    echo "Usage: report.sh [command] [options]"
    echo ""
    echo "Purpose: Advanced status reporting and analytics system providing"
    echo "         comprehensive insights into backup operations, performance"
    echo "         metrics, and system health."
    echo ""
    echo "Commands:"
    echo "  generate              - Generate comprehensive report (default)"
    echo "  summary               - Generate executive summary"
    echo "  analytics             - Generate detailed analytics"
    echo "  trends                - Generate trend analysis"
    echo "  performance           - Generate performance metrics"
    echo "  health                - Generate system health report"
    echo "  export                - Export report in various formats"
    echo "  schedule              - Schedule automated reports"
    echo "  config                - Show or update configuration"
    echo "  init                  - Initialize reporting system"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Options:"
    echo "  --verbose, -v         - Enable verbose output"
    echo "  --output=FORMAT       - Output format (text, json, csv, html)"
    echo "  --period=PERIOD       - Report period (daily, weekly, monthly)"
    echo "  --detailed, -d        - Include detailed breakdowns"
    echo ""
    echo "Examples:"
    echo "  ./report.sh                    # Generate comprehensive report"
    echo "  ./report.sh summary            # Generate executive summary"
    echo "  ./report.sh analytics --json   # JSON analytics report"
    echo "  ./report.sh trends --period=weekly  # Weekly trend analysis"
    echo "  ./report.sh export --output=csv     # Export as CSV"
    echo "  ./report.sh config              # Show configuration"
    echo ""
    echo "Features:"
    echo "  - Comprehensive backup status reporting"
    echo "  - Performance metrics and analytics"
    echo "  - Trend analysis and forecasting"
    echo "  - System health monitoring"
    echo "  - Multi-format export capabilities"
    echo "  - Automated report scheduling"
    echo "  - Executive summaries and detailed breakdowns"
}

# Initialize reporting system
init_report() {
    log "Initializing reporting system..."
    
    # Create configuration file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
        log "Created default configuration: $CONFIG_FILE"
    fi
    
    # Create database tables for reporting
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS report_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_type TEXT NOT NULL,
    report_data TEXT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    period TEXT DEFAULT 'daily',
    format TEXT DEFAULT 'text'
);

CREATE TABLE IF NOT EXISTS report_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_type TEXT NOT NULL,
    schedule_cron TEXT NOT NULL,
    output_format TEXT DEFAULT 'text',
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_report_history_type ON report_history(report_type);
CREATE INDEX IF NOT EXISTS idx_report_history_date ON report_history(generated_at);
CREATE INDEX IF NOT EXISTS idx_report_schedules_type ON report_schedules(report_type);
EOF
    
    log "Reporting system initialized"
    echo "${GREEN}✓ Reporting system initialized${RESET}"
}

# Generate comprehensive report
generate_comprehensive_report() {
    local verbose="${1:-false}"
    local output_format="${2:-text}"
    local period="${3:-daily}"
    
    log "Generating comprehensive report..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Generating comprehensive backup report...${RESET}"
    fi
    
    case "$output_format" in
        json)
            generate_json_report "$period"
            ;;
        csv)
            generate_csv_report "$period"
            ;;
        html)
            generate_html_report "$period"
            ;;
        *)
            generate_text_report "$period"
            ;;
    esac
    
    # Store report in history
    local report_data=$(generate_report_data "$period")
    sqlite3 "$DB_PATH" "INSERT INTO report_history (report_type, report_data, period, format) VALUES ('comprehensive', '$report_data', '$period', '$output_format');"
    
    log "Comprehensive report generated"
}

# Generate executive summary
generate_summary() {
    local verbose="${1:-false}"
    local output_format="${2:-text}"
    
    log "Generating executive summary..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Generating executive summary...${RESET}"
    fi
    
    echo "${CYAN}=== Executive Summary ===${RESET}"
    echo "Generated: $(date)"
    echo ""
    
    # Key metrics
    echo "${YELLOW}Key Metrics:${RESET}"
    local total_files=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files;")
    local total_size=$(sqlite3 "$DB_PATH" "SELECT ROUND(SUM(size_bytes) / 1024 / 1024 / 1024, 2) FROM files;")
    local backup_coverage=$(sqlite3 "$DB_PATH" "SELECT ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM files), 1) FROM files WHERE backup_freq IS NOT NULL;")
    
    echo "  Total Files: $total_files"
    echo "  Total Size: ${total_size}GB"
    echo "  Backup Coverage: ${backup_coverage}%"
    echo ""
    
    # Recent activity
    echo "${YELLOW}Recent Activity:${RESET}"
    sqlite3 "$DB_PATH" "SELECT COUNT(*) as recent_backups FROM files WHERE (strftime('%s','now') - mtime) < 86400;" | while read -r count; do
        echo "  Files modified in last 24h: $count"
    done
    
    log "Executive summary generated"
}

# Generate analytics report
generate_analytics() {
    local verbose="${1:-false}"
    local output_format="${2:-text}"
    
    log "Generating analytics report..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Generating detailed analytics...${RESET}"
    fi
    
    echo "${CYAN}=== Analytics Report ===${RESET}"
    echo "Generated: $(date)"
    echo ""
    
    # File distribution by type
    echo "${YELLOW}File Distribution by Type:${RESET}"
    sqlite3 "$DB_PATH" "SELECT type, COUNT(*) as count, ROUND(SUM(size_bytes) / 1024 / 1024, 2) as size_mb FROM files GROUP BY type ORDER BY count DESC LIMIT 10;"
    
    echo ""
    
    # Backup frequency distribution
    echo "${YELLOW}Backup Frequency Distribution:${RESET}"
    sqlite3 "$DB_PATH" "SELECT backup_freq, COUNT(*) as count FROM files WHERE backup_freq IS NOT NULL GROUP BY backup_freq ORDER BY count DESC;"
    
    echo ""
    
    # Change frequency analysis
    echo "${YELLOW}Change Frequency Analysis:${RESET}"
    sqlite3 "$DB_PATH" "SELECT 
        CASE 
            WHEN scan_count > 20 THEN 'Very High'
            WHEN scan_count > 10 THEN 'High'
            WHEN scan_count > 5 THEN 'Medium'
            ELSE 'Low'
        END as change_level,
        COUNT(*) as file_count
    FROM files 
    GROUP BY change_level 
    ORDER BY file_count DESC;"
    
    log "Analytics report generated"
}

# Generate trend analysis
generate_trends() {
    local verbose="${1:-false}"
    local period="${2:-weekly}"
    
    log "Generating trend analysis..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Generating trend analysis for $period period...${RESET}"
    fi
    
    echo "${CYAN}=== Trend Analysis ($period) ===${RESET}"
    echo "Generated: $(date)"
    echo ""
    
    # File growth trends
    echo "${YELLOW}File Growth Trends:${RESET}"
    sqlite3 "$DB_PATH" "SELECT 
        strftime('%Y-%m', mtime) as month,
        COUNT(*) as new_files,
        ROUND(SUM(size_bytes) / 1024 / 1024, 2) as size_mb
    FROM files 
    WHERE mtime > datetime('now', '-3 months')
    GROUP BY month 
    ORDER BY month;"
    
    echo ""
    
    # Change frequency trends
    echo "${YELLOW}Change Frequency Trends:${RESET}"
    sqlite3 "$DB_PATH" "SELECT 
        CASE 
            WHEN scan_count > 20 THEN 'Very High'
            WHEN scan_count > 10 THEN 'High'
            WHEN scan_count > 5 THEN 'Medium'
            ELSE 'Low'
        END as change_level,
        COUNT(*) as file_count,
        ROUND(AVG(scan_count), 1) as avg_scans
    FROM files 
    GROUP BY change_level 
    ORDER BY avg_scans DESC;"
    
    log "Trend analysis generated"
}

# Generate performance metrics
generate_performance() {
    local verbose="${1:-false}"
    
    log "Generating performance metrics..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Generating performance metrics...${RESET}"
    fi
    
    echo "${CYAN}=== Performance Metrics ===${RESET}"
    echo "Generated: $(date)"
    echo ""
    
    # Backup performance
    echo "${YELLOW}Backup Performance:${RESET}"
    local backup_success_rate=$(sqlite3 "$DB_PATH" "SELECT ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM files WHERE backup_freq IS NOT NULL), 1) FROM files WHERE backup_freq IS NOT NULL AND (strftime('%s','now') - mtime) < 86400*7;")
    echo "  Recent Backup Success Rate: ${backup_success_rate}%"
    
    # Storage efficiency
    echo "${YELLOW}Storage Efficiency:${RESET}"
    local avg_file_size=$(sqlite3 "$DB_PATH" "SELECT ROUND(AVG(size_bytes) / 1024 / 1024, 2) FROM files;")
    local large_files=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files WHERE size_bytes > 1000000000;")
    echo "  Average File Size: ${avg_file_size}MB"
    echo "  Large Files (>1GB): $large_files"
    
    log "Performance metrics generated"
}

# Generate system health report
generate_health() {
    local verbose="${1:-false}"
    
    log "Generating system health report..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Generating system health report...${RESET}"
    fi
    
    echo "${CYAN}=== System Health Report ===${RESET}"
    echo "Generated: $(date)"
    echo ""
    
    # Database health
    echo "${YELLOW}Database Health:${RESET}"
    local db_size=$(sqlite3 "$DB_PATH" "SELECT ROUND(page_count * page_size / 1024.0, 2) FROM pragma_page_count(), pragma_page_size();")
    echo "  Database Size: ${db_size}KB"
    
    # File system health
    echo "${YELLOW}File System Health:${RESET}"
    local orphaned_files=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files WHERE NOT EXISTS (SELECT 1 FROM files f2 WHERE f2.path = files.path AND f2.mtime > files.mtime);")
    echo "  Orphaned Files: $orphaned_files"
    
    # Backup health
    echo "${YELLOW}Backup Health:${RESET}"
    local missing_backups=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files WHERE backup_freq IS NULL;")
    echo "  Files Without Backup: $missing_backups"
    
    log "System health report generated"
}

# Export report in various formats
export_report() {
    local report_type="${1:-comprehensive}"
    local output_format="${2:-csv}"
    local period="${3:-daily}"
    
    log "Exporting $report_type report in $output_format format..."
    
    case "$output_format" in
        csv)
            generate_csv_export "$report_type" "$period"
            ;;
        json)
            generate_json_export "$report_type" "$period"
            ;;
        html)
            generate_html_export "$report_type" "$period"
            ;;
        *)
            echo "${YELLOW}Unsupported format: $output_format${RESET}"
            return 1
            ;;
    esac
    
    log "Report exported in $output_format format"
}

# Generate text report
generate_text_report() {
    local period="$1"
    
    echo "${CYAN}=== Comprehensive Backup Report ($period) ===${RESET}"
    echo "Generated: $(date)"
    echo ""
    
    # Backup frequency statistics
    echo "${YELLOW}Backup Frequency Statistics:${RESET}"
    for freq in hourly daily weekly monthly; do
        count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files WHERE backup_freq='$freq';")
        echo "  $freq: $count files scheduled for backup"
    done
    
    echo ""
    
    # Recent activity
    echo "${YELLOW}Recent Activity:${RESET}"
    tail -n 10 "$GRIM_ROOT/logs/backup.log" 2>/dev/null || echo "  No recent backup logs found"
    
    echo ""
    
    # Smart suggestions
    echo "${YELLOW}Smart Suggestions:${RESET}"
    tail -n 10 "$GRIM_ROOT/logs/smart_suggestions.log" 2>/dev/null || echo "  No smart suggestions found"
}

# Generate JSON report
generate_json_report() {
    local period="$1"
    
    echo '{"report": {'
    echo '  "type": "comprehensive",'
    echo '  "period": "'$period'",'
    echo '  "generated": "'$(date -Iseconds)'",'
    echo '  "backup_frequencies": '
    sqlite3 -json "$DB_PATH" "SELECT backup_freq, COUNT(*) as count FROM files WHERE backup_freq IS NOT NULL GROUP BY backup_freq ORDER BY count DESC;"
    echo ','
    echo '  "file_types": '
    sqlite3 -json "$DB_PATH" "SELECT type, COUNT(*) as count FROM files GROUP BY type ORDER BY count DESC LIMIT 10;"
    echo '}}'
}

# Generate CSV report
generate_csv_report() {
    local period="$1"
    
    echo "report_type,period,generated"
    echo "comprehensive,$period,$(date -Iseconds)"
    
    echo ""
    echo "backup_freq,file_count"
    sqlite3 -csv "$DB_PATH" "SELECT backup_freq, COUNT(*) FROM files WHERE backup_freq IS NOT NULL GROUP BY backup_freq ORDER BY COUNT(*) DESC;"
    
    echo ""
    echo "file_type,count"
    sqlite3 -csv "$DB_PATH" "SELECT type, COUNT(*) FROM files GROUP BY type ORDER BY COUNT(*) DESC LIMIT 10;"
}

# Generate HTML report
generate_html_report() {
    local period="$1"
    
    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Grimm Backup Report - $period</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #e8f4f8; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Grimm Backup Report</h1>
        <p>Period: $period | Generated: $(date)</p>
    </div>
    
    <div class="section">
        <h2>Backup Frequency Statistics</h2>
        <table>
            <tr><th>Frequency</th><th>File Count</th></tr>
EOF
    
    sqlite3 "$DB_PATH" "SELECT backup_freq, COUNT(*) FROM files WHERE backup_freq IS NOT NULL GROUP BY backup_freq ORDER BY COUNT(*) DESC;" | while IFS='|' read -r freq count; do
        echo "            <tr><td>$freq</td><td>$count</td></tr>"
    done
    
    cat << EOF
        </table>
    </div>
</body>
</html>
EOF
}

# Generate report data for storage
generate_report_data() {
    local period="$1"
    
    sqlite3 "$DB_PATH" << 'EOF'
SELECT json_group_object(
    'period', '$period',
    'generated', datetime('now'),
    'backup_frequencies', (
        SELECT json_group_object(backup_freq, COUNT(*))
        FROM files 
        WHERE backup_freq IS NOT NULL 
        GROUP BY backup_freq
    ),
    'file_types', (
        SELECT json_group_object(type, COUNT(*))
        FROM files 
        GROUP BY type
    )
) as report_data
FROM files
LIMIT 1;
EOF
}

# Show or update configuration
show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "${CYAN}Reporting Configuration:${RESET}"
        echo ""
        cat "$CONFIG_FILE"
    else
        echo "${YELLOW}Configuration file not found. Run 'init' to create it.${RESET}"
    fi
}

# Main function
main() {
    local command="${1:-generate}"
    local verbose=false
    local output_format="text"
    local period="daily"
    local detailed=false
    
    # Parse options
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose=true
                shift
                ;;
            --output=*)
                output_format="${1#*=}"
                shift
                ;;
            --period=*)
                period="${1#*=}"
                shift
                ;;
            --detailed|-d)
                detailed=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    case "$command" in
        help|-h|--help)
            show_help
            ;;
        init)
            init_report
            ;;
        generate)
            generate_comprehensive_report "$verbose" "$output_format" "$period"
            ;;
        summary)
            generate_summary "$verbose" "$output_format"
            ;;
        analytics)
            generate_analytics "$verbose" "$output_format"
            ;;
        trends)
            generate_trends "$verbose" "$period"
            ;;
        performance)
            generate_performance "$verbose"
            ;;
        health)
            generate_health "$verbose"
            ;;
        export)
            export_report "comprehensive" "$output_format" "$period"
            ;;
        schedule)
            echo "${YELLOW}Scheduling functionality coming soon...${RESET}"
            ;;
        config)
            show_config
            ;;
        *)
            generate_comprehensive_report "$verbose" "$output_format" "$period"
            ;;
    esac
}

main "$@" 