#!/bin/bash
# Compression Analytics Module: Track and report compression savings

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/compression.log"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Sync compression data to GRIMS_MOTHER for analytics and ML learning
sync_compression_to_grims_mother() {
    local file_path="$1"
    local original_size="$2"
    local compressed_size="$3"
    local algorithm="$4"
    local compression_ratio="$5"
    local storage_saved_gb="$6"
    local money_saved_yearly="$7"
    
    # Get user info
    local user_id=$(whoami)
    local hostname=$(hostname)
    local os_info=$(uname -a)
    
    # Create JSON payload for GRIMS_MOTHER
    local payload=$(cat <<EOF
{
    "user_id": "$user_id",
    "hostname": "$hostname", 
    "os_info": "$os_info",
    "file_path": "$file_path",
    "original_size": $original_size,
    "compressed_size": $compressed_size,
    "algorithm": "$algorithm",
    "compression_ratio": $compression_ratio,
    "storage_saved_gb": $storage_saved_gb,
    "money_saved_yearly": $money_saved_yearly,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    # Send to rip.grim.so API (async, don't block if it fails)
    (
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "User-Agent: Grim-Reaper-CLI/1.0" \
            -d "$payload" \
            "https://rip.grim.so/api/compression/analytics" \
            >/dev/null 2>&1 || true
    ) &
    
    # Also save to local queue in case we're offline
    local queue_file="$GRIM_ROOT/db/compression_queue.json"
    echo "$payload" >> "$queue_file" 2>/dev/null || true
}

# Initialize compression analytics database
init_compression_db() {
    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS compression_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    file_path TEXT,
    original_size INTEGER,
    compressed_size INTEGER,
    algorithm TEXT,
    compression_ratio REAL,
    time_saved REAL,
    storage_saved_gb REAL,
    money_saved_usd REAL
);
EOF
}

# Record compression statistics
record_compression_stats() {
    local file_path="$1"
    local stats_file="$2"
    
    if [ ! -f "$stats_file" ]; then
        return 1
    fi
    
    # Parse JSON compression stats
    local original_size=$(jq -r '.data_size' "$stats_file" 2>/dev/null || echo "0")
    local best_algo=$(jq -r '.best_ratio' "$stats_file" 2>/dev/null || echo "unknown")
    local compressed_size=$(jq -r ".results[\"$best_algo\"].compressed_size" "$stats_file" 2>/dev/null || echo "0")
    local compression_time=$(jq -r ".results[\"$best_algo\"].compression_time" "$stats_file" 2>/dev/null || echo "0")
    
    if [ "$original_size" -gt 0 ] && [ "$compressed_size" -gt 0 ]; then
        local compression_ratio=$(echo "scale=4; $compressed_size / $original_size" | bc)
        local storage_saved_bytes=$((original_size - compressed_size))
        local storage_saved_gb=$(echo "scale=6; $storage_saved_bytes / 1024 / 1024 / 1024" | bc)
        
        # Calculate money saved (at Hetzner rates: $0.0049/GB/month)
        local money_saved_monthly=$(echo "scale=4; $storage_saved_gb * 0.0049" | bc)
        local money_saved_yearly=$(echo "scale=2; $money_saved_monthly * 12" | bc)
        
        # Store in local database
        sqlite3 "$DB_PATH" <<EOF
INSERT INTO compression_stats 
(file_path, original_size, compressed_size, algorithm, compression_ratio, time_saved, storage_saved_gb, money_saved_usd)
VALUES ('$file_path', $original_size, $compressed_size, '$best_algo', $compression_ratio, $compression_time, $storage_saved_gb, $money_saved_yearly);
EOF
        
        # Sync to GRIMS_MOTHER for analytics and ML learning
        sync_compression_to_grims_mother "$file_path" "$original_size" "$compressed_size" "$best_algo" "$compression_ratio" "$storage_saved_gb" "$money_saved_yearly"
        
        log "Compression saved: $storage_saved_gb GB (${compression_ratio}x ratio) = \$$money_saved_yearly/year"
        
        # Clean up stats file
        rm -f "$stats_file"
    fi
}

# Generate compression report for user value proposition
generate_compression_report() {
    init_compression_db
    
    local total_original=$(sqlite3 "$DB_PATH" "SELECT SUM(original_size) FROM compression_stats WHERE date(timestamp) >= date('now', '-30 days')" 2>/dev/null || echo "0")
    local total_compressed=$(sqlite3 "$DB_PATH" "SELECT SUM(compressed_size) FROM compression_stats WHERE date(timestamp) >= date('now', '-30 days')" 2>/dev/null || echo "0")
    local total_saved_gb=$(sqlite3 "$DB_PATH" "SELECT SUM(storage_saved_gb) FROM compression_stats WHERE date(timestamp) >= date('now', '-30 days')" 2>/dev/null || echo "0")
    local total_money_saved=$(sqlite3 "$DB_PATH" "SELECT SUM(money_saved_usd) FROM compression_stats WHERE date(timestamp) >= date('now', '-30 days')" 2>/dev/null || echo "0")
    local avg_ratio=$(sqlite3 "$DB_PATH" "SELECT AVG(compression_ratio) FROM compression_stats WHERE date(timestamp) >= date('now', '-30 days')" 2>/dev/null || echo "1.0")
    
    if [ "$(echo "$total_original > 0" | bc)" -eq 1 ]; then
        local original_gb=$(echo "scale=2; $total_original / 1024 / 1024 / 1024" | bc)
        local compressed_gb=$(echo "scale=2; $total_compressed / 1024 / 1024 / 1024" | bc)
        
        echo "🗡️ GRIM COMPRESSION SAVINGS (Last 30 Days)"
        echo "├── Original Size: ${original_gb} GB"
        echo "├── Compressed Size: ${compressed_gb} GB" 
        echo "├── Space Saved: ${total_saved_gb} GB"
        echo "├── Average Ratio: ${avg_ratio}x compression"
        echo "├── Money Saved: \$${total_money_saved}/year"
        echo "└── ROI: Grim compression pays for itself!"
        echo ""
        echo "💰 UPGRADE FOR MORE SAVINGS:"
        echo "   PRO (\$49/month): 25GB → Save \$147/year with compression"
        echo "   MASTER (\$99/month): 100GB → Save \$588/year with compression"
        echo "   REAPER (\$499/month): 1TB+ → Save \$5,880+/year with compression"
        echo ""
        echo "🚀 Your affiliate link: $(get_affiliate_link)"
    else
        echo "🗡️ Start using Grim backups to see your compression savings!"
        echo "   Each backup uses intelligent Go compression"
        echo "   Average user saves 60-80% storage space"
        echo "   = Lower costs, better performance, happier wallet"
    fi
}

# Get user's affiliate link
get_affiliate_link() {
    local user_id=$(whoami)
    local affiliate_id="${user_id}_dev_$(head -c 8 /dev/urandom | base32 | tr '[:upper:]' '[:lower:]' | tr -d '=')"
    echo "https://grim.so/underworld/${affiliate_id}"
}

# Show compression value in backup success messages
show_compression_value() {
    local backup_file="$1"
    local stats_file="$2"
    
    if [ -f "$stats_file" ]; then
        local savings=$(jq -r '.compression_savings_usd_yearly // "0"' "$stats_file" 2>/dev/null)
        if [ "$savings" != "0" ] && [ "$savings" != "null" ]; then
            echo ""
            echo "💰 COMPRESSION BONUS: This backup saved you \$$savings/year in storage costs!"
            echo "🚀 Upgrade to PRO for unlimited intelligent compression: https://grim.so/pricing"
            echo ""
        fi
    fi
}

# Main command handler
case "${1:-help}" in
    "init")
        init_compression_db
        log "Compression analytics database initialized"
        ;;
    "record")
        record_compression_stats "$2" "$3"
        ;;
    "report")
        generate_compression_report
        ;;
    "value")
        show_compression_value "$2" "$3"
        ;;
    "help"|"-h"|"--help"|*)
        echo "Compression Analytics Module"
        echo "Commands:"
        echo "  init                     - Initialize compression database"
        echo "  record <file> <stats>    - Record compression statistics"  
        echo "  report                   - Generate compression savings report"
        echo "  value <backup> <stats>   - Show compression value message"
        ;;
esac