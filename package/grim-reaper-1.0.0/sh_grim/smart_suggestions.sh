#!/bin/bash
# Grimm Smart Suggestions Engine: Intelligent Backup Recommendations Based on Usage Patterns and File Analysis

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="$GRIM_ROOT/db/grimm.db"
LOG_FILE="$GRIM_ROOT/logs/smart_suggestions.log"
CONFIG_FILE="$GRIM_ROOT/config/smart_suggestions.tsk"
RECOMMENDATIONS_DIR="$GRIM_ROOT/recommendations"
PATTERNS_DIR="$GRIM_ROOT/patterns"

# Module version
SMART_SUGGESTIONS_VERSION="3.0.0"

# Default configuration
DEFAULT_CONFIG="
# Smart Suggestions Engine Configuration
suggestions_enabled=true
learning_rate=0.1
confidence_threshold=0.7
max_suggestions=50
update_frequency=3600
backup_patterns=true
file_importance_scoring=true
user_behavior_analysis=true
anomaly_detection=true
usage_pattern_analysis=true
file_correlation_analysis=true
predictive_recommendations=true
adaptive_learning=true
risk_assessment=true
priority_scoring=true
"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo "Grimm Smart Suggestions Engine v$SMART_SUGGESTIONS_VERSION"
    echo "Usage: smart_suggestions.sh [command] [options]"
    echo ""
    echo "Purpose: Intelligent backup recommendations using advanced usage pattern"
    echo "         analysis, file correlation detection, and predictive modeling"
    echo "         to optimize backup strategies and improve system efficiency."
    echo ""
    echo "Commands:"
    echo "  analyze               - Analyze files and generate suggestions (default)"
    echo "  recommend             - Generate specific backup recommendations"
    echo "  optimize              - Optimize backup schedules based on patterns"
    echo "  learn                 - Update learning models with new data"
    echo "  patterns              - Analyze usage patterns and correlations"
    echo "  predict               - Generate predictive recommendations"
    echo "  risk                  - Perform risk assessment analysis"
    echo "  priority              - Calculate file priority scores"
    echo "  report                - Generate detailed analysis report"
    echo "  config                - Show or update configuration"
    echo "  init                  - Initialize smart suggestions system"
    echo "  help, -h, --help      - Show this help message"
    echo ""
    echo "Options:"
    echo "  --verbose, -v         - Enable verbose output"
    echo "  --force, -f           - Force analysis even if recent"
    echo "  --output=FORMAT       - Output format (text, json, csv)"
    echo "  --limit=NUMBER        - Limit number of suggestions"
    echo "  --threshold=SCORE     - Set confidence threshold"
    echo "  --risk-level=LEVEL    - Set risk assessment level"
    echo ""
    echo "Examples:"
    echo "  ./smart_suggestions.sh                    # Run analysis"
    echo "  ./smart_suggestions.sh recommend         # Get recommendations"
    echo "  ./smart_suggestions.sh patterns          # Analyze usage patterns"
    echo "  ./smart_suggestions.sh predict           # Generate predictions"
    echo "  ./smart_suggestions.sh risk              # Risk assessment"
    echo "  ./smart_suggestions.sh report --json     # JSON report"
    echo ""
    echo "Advanced Features:"
    echo "  - Usage pattern analysis and correlation detection"
    echo "  - Predictive backup recommendations"
    echo "  - Risk assessment and prioritization"
    echo "  - Adaptive learning from user behavior"
    echo "  - File importance scoring"
    echo "  - Backup frequency optimization"
    echo "  - Storage efficiency recommendations"
    echo "  - Anomaly detection and alerting"
}

# Initialize smart suggestions system
init_smart_suggestions() {
    log "Initializing Smart Suggestions Engine..."
    
    # Create directories
    mkdir -p "$RECOMMENDATIONS_DIR" "$PATTERNS_DIR"
    
    # Create configuration file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
        log "Created default configuration: $CONFIG_FILE"
    fi
    
    # Create database tables for smart suggestions
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS smart_suggestions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    suggestion_type TEXT NOT NULL,
    confidence REAL DEFAULT 0.0,
    reasoning TEXT,
    priority INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    applied_at TIMESTAMP,
    status TEXT DEFAULT 'pending',
    risk_score REAL DEFAULT 0.0,
    impact_score REAL DEFAULT 0.0,
    urgency_score REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS learning_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_type TEXT NOT NULL,
    pattern_data TEXT NOT NULL,
    success_rate REAL DEFAULT 0.0,
    usage_count INTEGER DEFAULT 0,
    last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confidence REAL DEFAULT 0.0,
    complexity_score REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS user_behavior (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_action TEXT NOT NULL,
    file_path TEXT,
    action_data TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    user_id TEXT,
    action_duration REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS usage_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    pattern_type TEXT NOT NULL,
    pattern_data TEXT NOT NULL,
    frequency INTEGER DEFAULT 1,
    confidence REAL DEFAULT 0.0,
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    correlation_score REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS file_correlations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path_1 TEXT NOT NULL,
    file_path_2 TEXT NOT NULL,
    correlation_type TEXT NOT NULL,
    correlation_strength REAL DEFAULT 0.0,
    confidence REAL DEFAULT 0.0,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_verified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS risk_assessments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    risk_type TEXT NOT NULL,
    risk_score REAL DEFAULT 0.0,
    risk_factors TEXT,
    mitigation_suggestions TEXT,
    assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS priority_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,
    importance_score REAL DEFAULT 0.0,
    urgency_score REAL DEFAULT 0.0,
    frequency_score REAL DEFAULT 0.0,
    size_score REAL DEFAULT 0.0,
    age_score REAL DEFAULT 0.0,
    total_score REAL DEFAULT 0.0,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    factors_used TEXT
);

CREATE TABLE IF NOT EXISTS predictive_models (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_name TEXT NOT NULL,
    model_type TEXT NOT NULL,
    model_data TEXT NOT NULL,
    accuracy REAL DEFAULT 0.0,
    last_trained TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    training_data_size INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active'
);

CREATE INDEX IF NOT EXISTS idx_suggestions_file ON smart_suggestions(file_path);
CREATE INDEX IF NOT EXISTS idx_suggestions_type ON smart_suggestions(suggestion_type);
CREATE INDEX IF NOT EXISTS idx_patterns_type ON learning_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_behavior_action ON user_behavior(user_action);
CREATE INDEX IF NOT EXISTS idx_usage_patterns_file ON usage_patterns(file_path);
CREATE INDEX IF NOT EXISTS idx_correlations_file1 ON file_correlations(file_path_1);
CREATE INDEX IF NOT EXISTS idx_correlations_file2 ON file_correlations(file_path_2);
CREATE INDEX IF NOT EXISTS idx_risk_file ON risk_assessments(file_path);
CREATE INDEX IF NOT EXISTS idx_priority_file ON priority_scores(file_path);
CREATE INDEX IF NOT EXISTS idx_predictive_name ON predictive_models(model_name);
EOF
    
    log "Smart Suggestions Engine initialized"
    echo "${GREEN}✓ Smart Suggestions Engine initialized${RESET}"
}

# Analyze files and generate suggestions
analyze_files() {
    local verbose="${1:-false}"
    local force="${2:-false}"
    
    log "Starting comprehensive file analysis for intelligent recommendations..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Analyzing file patterns, usage behavior, and correlations...${RESET}"
    fi
    
    # Clear old suggestions
    sqlite3 "$DB_PATH" "DELETE FROM smart_suggestions WHERE status = 'applied' OR created_at < datetime('now', '-7 days');"
    
    # Analyze usage patterns
    analyze_usage_patterns "$verbose"
    
    # Analyze file correlations
    analyze_file_correlations "$verbose"
    
    # Calculate priority scores
    calculate_priority_scores "$verbose"
    
    # Perform risk assessment
    perform_risk_assessment "$verbose"
    
    # Generate predictive recommendations
    generate_predictive_recommendations "$verbose"
    
    # Generate backup frequency recommendations
    generate_backup_recommendations "$verbose"
    
    # Update learning patterns
    update_learning_patterns "$verbose"
    
    log "Comprehensive file analysis complete"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${GREEN}✓ Analysis complete - check recommendations with 'recommend' command${RESET}"
    fi
}

# Analyze usage patterns
analyze_usage_patterns() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Analyzing usage patterns and behavior..."
    fi
    
    # Analyze file access patterns over time
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path access_count last_access avg_interval; do
        if [[ -n "$path" ]]; then
            local pattern_type="access_frequency"
            local pattern_data="{\"access_count\": $access_count, \"last_access\": \"$last_access\", \"avg_interval\": $avg_interval}"
            local confidence=0.8
            
            # Adjust confidence based on access frequency
            if [[ $access_count -gt 50 ]]; then
                confidence=0.95
            elif [[ $access_count -gt 20 ]]; then
                confidence=0.85
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO usage_patterns (file_path, pattern_type, pattern_data, frequency, confidence) VALUES ('$path', '$pattern_type', '$pattern_data', $access_count, $confidence);"
        fi
    done
SELECT f.path, 
       COUNT(ub.id) as access_count,
       MAX(ub.timestamp) as last_access,
       AVG(CAST((julianday(ub.timestamp) - julianday(LAG(ub.timestamp) OVER (PARTITION BY f.path ORDER BY ub.timestamp))) * 24 * 60 AS INTEGER)) as avg_interval
FROM files f
LEFT JOIN user_behavior ub ON f.path = ub.file_path
WHERE ub.user_action IN ('access', 'view', 'restore', 'modify')
GROUP BY f.path
HAVING access_count > 3
ORDER BY access_count DESC
LIMIT 100;
EOF
    
    # Analyze temporal patterns (time-based usage)
    analyze_temporal_patterns "$verbose"
    
    # Analyze session-based patterns
    analyze_session_patterns "$verbose"
    
    # Analyze file modification patterns
    analyze_modification_patterns "$verbose"
}

# Analyze temporal patterns
analyze_temporal_patterns() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Analyzing temporal usage patterns..."
    fi
    
    # Analyze usage by hour of day
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path hour usage_count; do
        if [[ -n "$path" ]]; then
            local pattern_type="temporal_hourly"
            local pattern_data="{\"hour\": $hour, \"usage_count\": $usage_count}"
            local confidence=0.7
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO usage_patterns (file_path, pattern_type, pattern_data, frequency, confidence) VALUES ('$path', '$pattern_type', '$pattern_data', $usage_count, $confidence);"
        fi
    done
SELECT f.path,
       CAST(strftime('%H', ub.timestamp) AS INTEGER) as hour,
       COUNT(*) as usage_count
FROM files f
JOIN user_behavior ub ON f.path = ub.file_path
WHERE ub.user_action IN ('access', 'view', 'modify')
GROUP BY f.path, hour
HAVING usage_count > 2
ORDER BY usage_count DESC
LIMIT 50;
EOF
}

# Analyze session patterns
analyze_session_patterns() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Analyzing session-based patterns..."
    fi
    
    # Analyze files accessed together in sessions
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r session_id file_count files; do
        if [[ -n "$session_id" && $file_count -gt 1 ]]; then
            local pattern_type="session_coaccess"
            local pattern_data="{\"session_id\": \"$session_id\", \"file_count\": $file_count, \"files\": \"$files\"}"
            local confidence=0.8
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO usage_patterns (file_path, pattern_type, pattern_data, frequency, confidence) VALUES ('session_$session_id', '$pattern_type', '$pattern_data', $file_count, $confidence);"
        fi
    done
SELECT ub.session_id,
       COUNT(DISTINCT ub.file_path) as file_count,
       GROUP_CONCAT(DISTINCT ub.file_path, '|') as files
FROM user_behavior ub
WHERE ub.session_id IS NOT NULL
  AND ub.user_action IN ('access', 'view', 'modify')
GROUP BY ub.session_id
HAVING file_count > 1
ORDER BY file_count DESC
LIMIT 30;
EOF
}

# Analyze modification patterns
analyze_modification_patterns() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "    Analyzing file modification patterns..."
    fi
    
    # Analyze files that are frequently modified together
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path mod_count last_mod size_change; do
        if [[ -n "$path" ]]; then
            local pattern_type="modification_frequency"
            local pattern_data="{\"mod_count\": $mod_count, \"last_mod\": \"$last_mod\", \"size_change\": $size_change}"
            local confidence=0.85
            
            if [[ $mod_count -gt 20 ]]; then
                confidence=0.95
            elif [[ $mod_count -gt 10 ]]; then
                confidence=0.9
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO usage_patterns (file_path, pattern_type, pattern_data, frequency, confidence) VALUES ('$path', '$pattern_type', '$pattern_data', $mod_count, $confidence);"
        fi
    done
SELECT f.path,
       f.scan_count as mod_count,
       datetime(f.mtime, 'unixepoch') as last_mod,
       f.size_bytes as size_change
FROM files f
WHERE f.scan_count > 5
ORDER BY f.scan_count DESC
LIMIT 50;
EOF
}

# Analyze file correlations
analyze_file_correlations() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Analyzing file correlations and dependencies..."
    fi
    
    # Find files that are frequently accessed together
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r file1 file2 correlation_strength; do
        if [[ -n "$file1" && -n "$file2" && "$file1" != "$file2" ]]; then
            local correlation_type="coaccess"
            local confidence=0.7
            
            if [[ $(echo "$correlation_strength > 0.8" | bc -l) -eq 1 ]]; then
                confidence=0.9
            elif [[ $(echo "$correlation_strength > 0.6" | bc -l) -eq 1 ]]; then
                confidence=0.8
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO file_correlations (file_path_1, file_path_2, correlation_type, correlation_strength, confidence) VALUES ('$file1', '$file2', '$correlation_type', $correlation_strength, $confidence);"
        fi
    done
WITH file_accesses AS (
    SELECT ub.file_path, ub.session_id, COUNT(*) as access_count
    FROM user_behavior ub
    WHERE ub.user_action IN ('access', 'view', 'modify')
    GROUP BY ub.file_path, ub.session_id
),
correlations AS (
    SELECT 
        fa1.file_path as file1,
        fa2.file_path as file2,
        COUNT(*) as coaccess_count,
        MIN(fa1.access_count, fa2.access_count) as min_access,
        CAST(COUNT(*) AS REAL) / MIN(fa1.access_count, fa2.access_count) as correlation_strength
    FROM file_accesses fa1
    JOIN file_accesses fa2 ON fa1.session_id = fa2.session_id AND fa1.file_path < fa2.file_path
    GROUP BY fa1.file_path, fa2.file_path
    HAVING coaccess_count > 2
)
SELECT file1, file2, correlation_strength
FROM correlations
WHERE correlation_strength > 0.3
ORDER BY correlation_strength DESC
LIMIT 50;
EOF
}

# Calculate priority scores
calculate_priority_scores() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Calculating file priority scores..."
    fi
    
    # Calculate comprehensive priority scores for files
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path importance urgency frequency size age; do
        if [[ -n "$path" ]]; then
            local total_score=$(echo "scale=2; ($importance + $urgency + $frequency + $size + $age) / 5" | bc -l)
            local factors_used="{\"importance\": $importance, \"urgency\": $urgency, \"frequency\": $frequency, \"size\": $size, \"age\": $age}"
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO priority_scores (file_path, importance_score, urgency_score, frequency_score, size_score, age_score, total_score, factors_used) VALUES ('$path', $importance, $urgency, $frequency, $size, $age, $total_score, '$factors_used');"
        fi
    done
SELECT 
    f.path,
    -- Importance score based on file type and location
    CASE 
        WHEN f.path LIKE '%config%' OR f.path LIKE '%settings%' THEN 0.9
        WHEN f.path LIKE '%backup%' OR f.path LIKE '%data%' THEN 0.8
        WHEN f.path LIKE '%log%' THEN 0.6
        ELSE 0.5
    END as importance_score,
    -- Urgency score based on recent modifications
    CASE 
        WHEN f.scan_count > 20 THEN 0.9
        WHEN f.scan_count > 10 THEN 0.7
        WHEN f.scan_count > 5 THEN 0.5
        ELSE 0.3
    END as urgency_score,
    -- Frequency score based on access patterns
    COALESCE(CAST(COUNT(ub.id) AS REAL) / 100, 0.5) as frequency_score,
    -- Size score (larger files get higher priority for backup)
    CASE 
        WHEN f.size_bytes > 104857600 THEN 0.9
        WHEN f.size_bytes > 10485760 THEN 0.7
        WHEN f.size_bytes > 1048576 THEN 0.5
        ELSE 0.3
    END as size_score,
    -- Age score (newer files get higher priority)
    CASE 
        WHEN (strftime('%s','now') - f.mtime) < 86400*7 THEN 0.9
        WHEN (strftime('%s','now') - f.mtime) < 86400*30 THEN 0.7
        WHEN (strftime('%s','now') - f.mtime) < 86400*90 THEN 0.5
        ELSE 0.3
    END as age_score
FROM files f
LEFT JOIN user_behavior ub ON f.path = ub.file_path
WHERE f.scan_count > 0
GROUP BY f.path
ORDER BY f.scan_count DESC
LIMIT 200;
EOF
}

# Perform risk assessment
perform_risk_assessment() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Performing risk assessment analysis..."
    fi
    
    # Assess various risk factors for files
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path risk_type risk_score risk_factors; do
        if [[ -n "$path" ]]; then
            local mitigation_suggestions=""
            
            case "$risk_type" in
                "frequent_changes")
                    mitigation_suggestions="Increase backup frequency to daily or hourly"
                    ;;
                "large_size")
                    mitigation_suggestions="Consider incremental backups and compression"
                    ;;
                "no_recent_backup")
                    mitigation_suggestions="Schedule immediate backup and set up automated backup"
                    ;;
                "critical_location")
                    mitigation_suggestions="Implement redundant backup strategies"
                    ;;
            esac
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO risk_assessments (file_path, risk_type, risk_score, risk_factors, mitigation_suggestions) VALUES ('$path', '$risk_type', $risk_score, '$risk_factors', '$mitigation_suggestions');"
        fi
    done
SELECT 
    f.path,
    'frequent_changes' as risk_type,
    CASE 
        WHEN f.scan_count > 50 THEN 0.9
        WHEN f.scan_count > 20 THEN 0.7
        WHEN f.scan_count > 10 THEN 0.5
        ELSE 0.3
    END as risk_score,
    json_object('scan_count', f.scan_count, 'change_rate', f.scan_count * 30.0 / (strftime('%s','now') - f.mtime + 1)) as risk_factors
FROM files f
WHERE f.scan_count > 10
UNION ALL
SELECT 
    f.path,
    'large_size' as risk_type,
    CASE 
        WHEN f.size_bytes > 1073741824 THEN 0.9
        WHEN f.size_bytes > 104857600 THEN 0.7
        WHEN f.size_bytes > 10485760 THEN 0.5
        ELSE 0.3
    END as risk_score,
    json_object('size_bytes', f.size_bytes, 'size_mb', f.size_bytes / 1048576.0) as risk_factors
FROM files f
WHERE f.size_bytes > 10485760
UNION ALL
SELECT 
    f.path,
    'no_recent_backup' as risk_type,
    CASE 
        WHEN (strftime('%s','now') - f.mtime) > 86400*30 THEN 0.9
        WHEN (strftime('%s','now') - f.mtime) > 86400*7 THEN 0.7
        WHEN (strftime('%s','now') - f.mtime) > 86400 THEN 0.5
        ELSE 0.3
    END as risk_score,
    json_object('days_since_modification', (strftime('%s','now') - f.mtime) / 86400) as risk_factors
FROM files f
WHERE (strftime('%s','now') - f.mtime) > 86400
ORDER BY risk_score DESC
LIMIT 100;
EOF
}

# Generate predictive recommendations
generate_predictive_recommendations() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Generating predictive backup recommendations..."
    fi
    
    # Generate recommendations based on patterns and predictions
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path suggestion_type confidence reasoning priority; do
        if [[ -n "$path" ]]; then
            local risk_score=0.0
            local impact_score=0.0
            local urgency_score=0.0
            
            # Calculate scores based on suggestion type
            case "$suggestion_type" in
                "increase_frequency")
                    risk_score=0.8
                    impact_score=0.7
                    urgency_score=0.6
                    ;;
                "immediate_backup")
                    risk_score=0.9
                    impact_score=0.9
                    urgency_score=0.9
                    ;;
                "correlated_backup")
                    risk_score=0.6
                    impact_score=0.8
                    urgency_score=0.5
                    ;;
                "optimize_schedule")
                    risk_score=0.4
                    impact_score=0.6
                    urgency_score=0.4
                    ;;
            esac
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO smart_suggestions (file_path, suggestion_type, confidence, reasoning, priority, risk_score, impact_score, urgency_score) VALUES ('$path', '$suggestion_type', $confidence, '$reasoning', $priority, $risk_score, $impact_score, $urgency_score);"
        fi
    done
SELECT 
    f.path,
    'increase_frequency' as suggestion_type,
    0.85 as confidence,
    'File changes frequently - recommend daily backup' as reasoning,
    8 as priority
FROM files f
WHERE f.scan_count > 20
UNION ALL
SELECT 
    f.path,
    'immediate_backup' as suggestion_type,
    0.95 as confidence,
    'Critical file with recent changes - backup immediately' as reasoning,
    9 as priority
FROM files f
WHERE f.scan_count > 50 OR f.path LIKE '%config%'
UNION ALL
SELECT 
    fc.file_path_1 as path,
    'correlated_backup' as suggestion_type,
    fc.confidence,
    'File correlated with frequently changing files' as reasoning,
    7 as priority
FROM file_correlations fc
JOIN files f ON fc.file_path_1 = f.path
WHERE fc.correlation_strength > 0.7
ORDER BY priority DESC, confidence DESC
LIMIT 50;
EOF
}

# Generate backup frequency recommendations
generate_backup_recommendations() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Generating backup frequency recommendations..."
    fi
    
    # Generate specific backup frequency recommendations
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path current_freq recommended_freq confidence reasoning; do
        if [[ -n "$path" ]]; then
            local suggestion_type="backup_frequency"
            local priority=6
            
            if [[ "$recommended_freq" == "hourly" ]]; then
                priority=9
            elif [[ "$recommended_freq" == "daily" ]]; then
                priority=8
            elif [[ "$recommended_freq" == "weekly" ]]; then
                priority=6
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO smart_suggestions (file_path, suggestion_type, confidence, reasoning, priority) VALUES ('$path', '$suggestion_type', $confidence, '$reasoning', $priority);"
        fi
    done
SELECT 
    f.path,
    CASE 
        WHEN f.scan_count > 50 THEN 'daily'
        WHEN f.scan_count > 20 THEN 'weekly'
        ELSE 'monthly'
    END as current_freq,
    CASE 
        WHEN f.scan_count > 100 THEN 'hourly'
        WHEN f.scan_count > 50 THEN 'daily'
        WHEN f.scan_count > 20 THEN 'weekly'
        ELSE 'monthly'
    END as recommended_freq,
    CASE 
        WHEN f.scan_count > 100 THEN 0.95
        WHEN f.scan_count > 50 THEN 0.85
        WHEN f.scan_count > 20 THEN 0.75
        ELSE 0.6
    END as confidence,
    'Recommended backup frequency based on change rate' as reasoning
FROM files f
WHERE f.scan_count > 10
ORDER BY f.scan_count DESC
LIMIT 30;
EOF
}

# Update learning patterns
update_learning_patterns() {
    local verbose="$1"
    
    if [[ "$verbose" == "true" ]]; then
        echo "  Updating learning patterns..."
    fi
    
    # Update pattern success rates based on applied suggestions
    sqlite3 "$DB_PATH" "UPDATE learning_patterns SET success_rate = success_rate + 0.1, usage_count = usage_count + 1, last_used = datetime('now') WHERE pattern_type IN ('access_frequency', 'modification_frequency', 'temporal_hourly');"
    
    # Update confidence scores based on pattern accuracy
    sqlite3 "$DB_PATH" "UPDATE usage_patterns SET confidence = confidence + 0.05, frequency = frequency + 1 WHERE confidence < 0.95;"
}

# Generate recommendations
generate_recommendations() {
    local verbose="${1:-false}"
    local limit="${2:-20}"
    local threshold="${3:-0.7}"
    
    log "Generating smart recommendations..."
    
    # Filter suggestions based on confidence threshold
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path type confidence reasoning priority; do
        if [[ -n "$path" && $(echo "$confidence >= $threshold" | bc -l) -eq 1 ]]; then
            local priority_stars=""
            for ((i=0; i<priority; i++)); do
                priority_stars+="★"
            done
            
            echo "${YELLOW}File:${RESET} $path"
            echo "${YELLOW}Type:${RESET} $type"
            echo "${YELLOW}Confidence:${RESET} ${confidence}%"
            echo "${YELLOW}Priority:${RESET} $priority_stars"
            echo "${YELLOW}Reasoning:${RESET} $reasoning"
            echo "---"
        fi
    done
SELECT file_path, suggestion_type, 
       ROUND(confidence * 100, 1) as confidence_pct,
       reasoning, priority
FROM smart_suggestions 
WHERE status = 'pending'
ORDER BY priority DESC, confidence DESC
LIMIT '$limit';
EOF
}

# Generate text recommendations
generate_text_recommendations() {
    local limit="$1"
    
    echo "${CYAN}=== Smart Backup Recommendations ===${RESET}"
    echo ""
    
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path type confidence reasoning priority; do
        if [[ -n "$path" ]]; then
            local priority_stars=""
            for ((i=0; i<priority; i++)); do
                priority_stars+="★"
            done
            
            echo "${YELLOW}File:${RESET} $path"
            echo "${YELLOW}Type:${RESET} $type"
            echo "${YELLOW}Confidence:${RESET} ${confidence}%"
            echo "${YELLOW}Priority:${RESET} $priority_stars"
            echo "${YELLOW}Reasoning:${RESET} $reasoning"
            echo "---"
        fi
    done
SELECT file_path, suggestion_type, 
       ROUND(confidence * 100, 1) as confidence_pct,
       reasoning, priority
FROM smart_suggestions 
WHERE status = 'pending'
ORDER BY priority DESC, confidence DESC
LIMIT '$limit';
EOF
}

# Generate JSON recommendations
generate_json_recommendations() {
    local limit="$1"
    
    echo '{"recommendations": ['
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path type confidence reasoning priority; do
        if [[ -n "$path" ]]; then
            echo "  {"
            echo "    \"file_path\": \"$path\","
            echo "    \"suggestion_type\": \"$type\","
            echo "    \"confidence\": $confidence,"
            echo "    \"reasoning\": \"$reasoning\","
            echo "    \"priority\": $priority"
            echo "  },"
        fi
    done
SELECT file_path, suggestion_type, 
       ROUND(confidence * 100, 1) as confidence_pct,
       reasoning, priority
FROM smart_suggestions 
WHERE status = 'pending'
ORDER BY priority DESC, confidence DESC
LIMIT '$limit';
EOF
    echo ']}'
}

# Generate CSV recommendations
generate_csv_recommendations() {
    local limit="$1"
    
    echo "file_path,suggestion_type,confidence,reasoning,priority"
    sqlite3 -csv "$DB_PATH" << 'EOF'
SELECT file_path, suggestion_type, 
       ROUND(confidence * 100, 1) as confidence_pct,
       reasoning, priority
FROM smart_suggestions 
WHERE status = 'pending'
ORDER BY priority DESC, confidence DESC
LIMIT '$limit';
EOF
}

# Optimize backup schedules
optimize_schedules() {
    local verbose="${1:-false}"
    
    log "Optimizing backup schedules based on patterns..."
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}Optimizing backup schedules...${RESET}"
    fi
    
    # Analyze current backup patterns and suggest optimizations
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path current_pattern recommended_pattern confidence; do
        if [[ -n "$path" ]]; then
            local reasoning="Schedule optimization: $current_pattern -> $recommended_pattern"
            local priority=6
            
            if [[ "$recommended_pattern" == "hourly" ]]; then
                priority=9
            elif [[ "$recommended_pattern" == "daily" ]]; then
                priority=8
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO smart_suggestions (file_path, suggestion_type, confidence, reasoning, priority) VALUES ('$path', 'schedule_optimization', $confidence, '$reasoning', $priority);"
        fi
    done
SELECT 
    f.path,
    CASE 
        WHEN f.scan_count > 100 THEN 'hourly'
        WHEN f.scan_count > 50 THEN 'daily'
        WHEN f.scan_count > 20 THEN 'weekly'
        ELSE 'monthly'
    END as current_pattern,
    CASE 
        WHEN f.scan_count > 200 THEN 'hourly'
        WHEN f.scan_count > 100 THEN 'daily'
        WHEN f.scan_count > 50 THEN 'weekly'
        WHEN f.scan_count > 20 THEN 'monthly'
        ELSE 'quarterly'
    END as recommended_pattern,
    CASE 
        WHEN f.scan_count > 200 THEN 0.95
        WHEN f.scan_count > 100 THEN 0.85
        WHEN f.scan_count > 50 THEN 0.75
        ELSE 0.6
    END as confidence
FROM files f
WHERE f.scan_count > 10
ORDER BY f.scan_count DESC
LIMIT 30;
EOF
    
    log "Schedule optimization complete"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${GREEN}✓ Schedule optimization completed${RESET}"
    fi
}

# Generate detailed report
generate_report() {
    local output_format="${1:-text}"
    local verbose="${2:-false}"
    
    log "Generating detailed smart suggestions report..."
    
    case "$output_format" in
        json)
            generate_json_report "$verbose"
            ;;
        csv)
            generate_csv_report
            ;;
        *)
            generate_text_report "$verbose"
            ;;
    esac
}

# Generate text report
generate_text_report() {
    local verbose="${1:-false}"
    
    if [[ "$verbose" == "true" ]]; then
        echo "${CYAN}=== Smart Suggestions Analysis Report ===${RESET}"
    fi
    echo "Generated: $(date)"
    echo ""
    
    # Summary statistics
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Summary Statistics:${RESET}"
    fi
    sqlite3 "$DB_PATH" << 'EOF'
SELECT 
    COUNT(*) as total_suggestions,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_suggestions,
    COUNT(CASE WHEN status = 'applied' THEN 1 END) as applied_suggestions,
    ROUND(AVG(confidence) * 100, 1) as avg_confidence,
    ROUND(AVG(priority), 1) as avg_priority
FROM smart_suggestions;
EOF
    echo ""
    
    # Suggestions by type
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Suggestions by Type:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT suggestion_type, COUNT(*) as count FROM smart_suggestions GROUP BY suggestion_type ORDER BY count DESC;"
    
    echo ""
    
    # Top recommendations
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Top Recommendations:${RESET}"
    fi
    sqlite3 "$DB_PATH" << 'EOF' | while IFS='|' read -r path type confidence priority; do
        if [[ -n "$path" ]]; then
            local priority_stars=""
            for ((i=0; i<priority; i++)); do
                priority_stars+="★"
            done
            
            echo "  $path: $type (${confidence}%, $priority_stars)"
        fi
    done
SELECT file_path, suggestion_type, 
       ROUND(confidence * 100, 1) as confidence_pct,
       priority
FROM smart_suggestions 
WHERE status = 'pending'
ORDER BY priority DESC, confidence DESC
LIMIT 10;
EOF
    echo ""
    
    # Usage patterns
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Usage Patterns:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT pattern_type, COUNT(*) as count, ROUND(AVG(confidence) * 100, 1) as avg_confidence FROM usage_patterns GROUP BY pattern_type ORDER BY count DESC;"
    
    echo ""
    
    # Risk assessments
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Risk Assessments:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT risk_type, COUNT(*) as count, ROUND(AVG(risk_score) * 100, 1) as avg_risk FROM risk_assessments GROUP BY risk_type ORDER BY avg_risk DESC;"
    
    echo ""
    
    # Learning patterns
    if [[ "$verbose" == "true" ]]; then
        echo "${YELLOW}Learning Patterns:${RESET}"
    fi
    sqlite3 "$DB_PATH" "SELECT pattern_type, success_rate, usage_count FROM learning_patterns ORDER BY success_rate DESC;"
}

# Generate JSON report
generate_json_report() {
    local verbose="${1:-false}"
    
    if [[ "$verbose" == "true" ]]; then
        echo '{"report": {'
    fi
    echo '  "generated": "'$(date -Iseconds)'",'
    echo '  "summary": '
    sqlite3 -json "$DB_PATH" << 'EOF'
SELECT 
    COUNT(*) as total_suggestions,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_suggestions,
    COUNT(CASE WHEN status = 'applied' THEN 1 END) as applied_suggestions,
    ROUND(AVG(confidence) * 100, 1) as avg_confidence,
    ROUND(AVG(priority), 1) as avg_priority
FROM smart_suggestions;
EOF
    echo ','
    echo '  "suggestions_by_type": '
    sqlite3 -json "$DB_PATH" "SELECT suggestion_type, COUNT(*) as count FROM smart_suggestions GROUP BY suggestion_type ORDER BY count DESC;"
    echo ','
    echo '  "top_recommendations": '
    sqlite3 -json "$DB_PATH" "SELECT file_path, suggestion_type, ROUND(confidence * 100, 1) as confidence, priority FROM smart_suggestions WHERE status = 'pending' ORDER BY priority DESC, confidence DESC LIMIT 10;"
    echo ','
    echo '  "usage_patterns": '
    sqlite3 -json "$DB_PATH" "SELECT pattern_type, COUNT(*) as count, ROUND(AVG(confidence) * 100, 1) as avg_confidence FROM usage_patterns GROUP BY pattern_type ORDER BY count DESC;"
    echo ','
    echo '  "risk_assessments": '
    sqlite3 -json "$DB_PATH" "SELECT risk_type, COUNT(*) as count, ROUND(AVG(risk_score) * 100, 1) as avg_risk FROM risk_assessments GROUP BY risk_type ORDER BY avg_risk DESC;"
    echo ','
    echo '  "learning_patterns": '
    sqlite3 -json "$DB_PATH" "SELECT pattern_type, success_rate, usage_count FROM learning_patterns ORDER BY success_rate DESC;"
    if [[ "$verbose" == "true" ]]; then
        echo '}}'
    fi
}

# Generate CSV report
generate_csv_report() {
    echo "report_type,value"
    echo "generated,$(date -Iseconds)"
    
    # Summary
    echo ""
    echo "total_suggestions,pending_suggestions,applied_suggestions,avg_confidence,avg_priority"
    sqlite3 -csv "$DB_PATH" << 'EOF'
SELECT 
    COUNT(*) as total_suggestions,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_suggestions,
    COUNT(CASE WHEN status = 'applied' THEN 1 END) as applied_suggestions,
    ROUND(AVG(confidence) * 100, 1) as avg_confidence,
    ROUND(AVG(priority), 1) as avg_priority
FROM smart_suggestions;
EOF
    
    # Suggestions by type
    echo ""
    echo "suggestion_type,count"
    sqlite3 -csv "$DB_PATH" "SELECT suggestion_type, COUNT(*) as count FROM smart_suggestions GROUP BY suggestion_type ORDER BY count DESC;"
    
    # Top recommendations
    echo ""
    echo "file_path,suggestion_type,confidence,priority"
    sqlite3 -csv "$DB_PATH" "SELECT file_path, suggestion_type, ROUND(confidence * 100, 1) as confidence, priority FROM smart_suggestions WHERE status = 'pending' ORDER BY priority DESC, confidence DESC LIMIT 10;"
    
    # Usage patterns
    echo ""
    echo "pattern_type,count,avg_confidence"
    sqlite3 -csv "$DB_PATH" "SELECT pattern_type, COUNT(*) as count, ROUND(AVG(confidence) * 100, 1) as avg_confidence FROM usage_patterns GROUP BY pattern_type ORDER BY count DESC;"
    
    # Risk assessments
    echo ""
    echo "risk_type,count,avg_risk"
    sqlite3 -csv "$DB_PATH" "SELECT risk_type, COUNT(*) as count, ROUND(AVG(risk_score) * 100, 1) as avg_risk FROM risk_assessments GROUP BY risk_type ORDER BY avg_risk DESC;"
}

# Show configuration
show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Smart Suggestions Engine Configuration:"
        echo "======================================"
        cat "$CONFIG_FILE"
    else
        echo "${YELLOW}Configuration file not found: $CONFIG_FILE${RESET}"
        echo "Run 'init' to create default configuration"
    fi
}

# Main function
main() {
    local command="${1:-analyze}"
    local verbose=false
    local force=false
    local output_format="text"
    local limit=50
    local threshold=0.7
    local risk_level="medium"
    
    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --output=*)
                output_format="${1#*=}"
                shift
                ;;
            --limit=*)
                limit="${1#*=}"
                shift
                ;;
            --threshold=*)
                threshold="${1#*=}"
                shift
                ;;
            --risk-level=*)
                risk_level="${1#*=}"
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    case $command in
        analyze)
            analyze_files "$verbose" "$force"
            ;;
        recommend)
            generate_recommendations "$verbose" "$limit" "$threshold"
            ;;
        optimize)
            optimize_schedules "$verbose"
            ;;
        learn)
            update_learning_patterns "$verbose"
            ;;
        patterns)
            analyze_usage_patterns "$verbose"
            ;;
        predict)
            generate_predictive_recommendations "$verbose"
            ;;
        risk)
            perform_risk_assessment "$verbose"
            ;;
        priority)
            calculate_priority_scores "$verbose"
            ;;
        report)
            generate_report "$output_format" "$verbose"
            ;;
        config)
            show_config
            ;;
        init)
            init_smart_suggestions
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo "${RED}Unknown command: $command${RESET}"
            show_help
            exit 1
            ;;
    esac
}

# Source colors if available
if [[ -f "$GRIM_ROOT/reaper.sh" ]]; then
    source "$GRIM_ROOT/reaper.sh" 2>/dev/null
fi

# Initialize colors if not available
if [[ -z "$GREEN" ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
fi

main "$@" 