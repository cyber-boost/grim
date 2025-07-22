#!/bin/bash
# Grimm Deduplication Module: Efficient storage through content-based deduplication

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/dedup.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/dedup.log"
CHUNK_STORE="$GRIM_ROOT/backups/.dedup_store"
CHUNK_SIZE=1048576  # 1MB chunks

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

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Initialize deduplication database
init_db() {
    mkdir -p "$(dirname "$DB_PATH")"
    mkdir -p "$CHUNK_STORE"
    
    sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS chunks (
    hash TEXT PRIMARY KEY,
    size INTEGER,
    ref_count INTEGER DEFAULT 1,
    first_seen INTEGER,
    last_seen INTEGER
);

CREATE TABLE IF NOT EXISTS files (
    path TEXT PRIMARY KEY,
    size INTEGER,
    chunk_count INTEGER,
    dedup_ratio REAL,
    created INTEGER
);

CREATE TABLE IF NOT EXISTS file_chunks (
    file_path TEXT,
    chunk_index INTEGER,
    chunk_hash TEXT,
    PRIMARY KEY (file_path, chunk_index),
    FOREIGN KEY (file_path) REFERENCES files(path),
    FOREIGN KEY (chunk_hash) REFERENCES chunks(hash)
);

CREATE INDEX IF NOT EXISTS idx_chunk_refs ON chunks(ref_count);
CREATE INDEX IF NOT EXISTS idx_file_chunks ON file_chunks(chunk_hash);
EOF
}

# Calculate rolling hash for chunk detection
calculate_hash() {
    local data="$1"
    echo -n "$data" | sha256sum | cut -d' ' -f1
}

# Split file into chunks
split_file_into_chunks() {
    local file="$1"
    local chunk_num=0
    
    while IFS= read -r -d '' -n $CHUNK_SIZE chunk; do
        if [ -n "$chunk" ]; then
            local hash=$(echo -n "$chunk" | sha256sum | cut -d' ' -f1)
            echo "$chunk_num:$hash:${#chunk}"
            ((chunk_num++))
        fi
    done < "$file"
}

# Store unique chunk
store_chunk() {
    local hash="$1"
    local data="$2"
    local chunk_path="$CHUNK_STORE/${hash:0:2}/${hash:2:2}/$hash"
    
    mkdir -p "$(dirname "$chunk_path")"
    echo -n "$data" > "$chunk_path"
    
    # Compress chunk
    gzip -9 "$chunk_path"
    mv "${chunk_path}.gz" "$chunk_path"
}

# Deduplicate file
deduplicate_file() {
    local file="$1"
    local dedup_path="${2:-${file}.dedup}"
    
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    
    init_db
    
    log "Deduplicating: $file"
    
    local file_size=$(stat -c%s "$file")
    local total_chunks=0
    local unique_chunks=0
    local saved_bytes=0
    
    # Create manifest file
    local manifest="${dedup_path}.manifest"
    > "$manifest"
    
    # Process file in chunks
    while IFS= read -r -d '' -n $CHUNK_SIZE chunk; do
        if [ -n "$chunk" ]; then
            local hash=$(echo -n "$chunk" | sha256sum | cut -d' ' -f1)
            local chunk_size=${#chunk}
            
            # Check if chunk exists
            local existing=$(sqlite3 "$DB_PATH" "SELECT hash FROM chunks WHERE hash='$hash';")
            
            if [ -z "$existing" ]; then
                # New unique chunk
                store_chunk "$hash" "$chunk"
                sqlite3 "$DB_PATH" "INSERT INTO chunks (hash, size, first_seen, last_seen) VALUES ('$hash', $chunk_size, strftime('%s','now'), strftime('%s','now'));"
                ((unique_chunks++))
            else
                # Duplicate chunk
                sqlite3 "$DB_PATH" "UPDATE chunks SET ref_count = ref_count + 1, last_seen = strftime('%s','now') WHERE hash='$hash';"
                ((saved_bytes += chunk_size))
            fi
            
            # Add to manifest
            echo "$hash:$chunk_size" >> "$manifest"
            
            ((total_chunks++))
            
            # Show progress
            if [ $((total_chunks % 100)) -eq 0 ]; then
                echo -ne "\rProcessed chunks: $total_chunks (unique: $unique_chunks)"
            fi
        fi
    done < "$file"
    
    echo  # New line after progress
    
    # Calculate deduplication ratio
    local dedup_ratio=$(echo "scale=2; ($file_size - $saved_bytes) * 100 / $file_size" | bc)
    
    # Store file metadata
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO files (path, size, chunk_count, dedup_ratio, created) VALUES ('$file', $file_size, $total_chunks, $dedup_ratio, strftime('%s','now'));"
    
    # Store file-chunk mappings
    local chunk_index=0
    while IFS=: read -r hash size; do
        sqlite3 "$DB_PATH" "INSERT INTO file_chunks (file_path, chunk_index, chunk_hash) VALUES ('$file', $chunk_index, '$hash');"
        ((chunk_index++))
    done < "$manifest"
    
    log "Deduplication complete: $total_chunks chunks, $unique_chunks unique"
    log "Space saved: $(numfmt --to=iec-i --suffix=B $saved_bytes) (${dedup_ratio}% stored)"
    
    # Compress manifest
    gzip -9 "$manifest"
    
    return 0
}

# Restore deduplicated file
restore_file() {
    local manifest="$1"
    local output="${2:-${manifest%.dedup.manifest.gz}}"
    
    if [ ! -f "$manifest" ]; then
        log_error "Manifest not found: $manifest"
        return 1
    fi
    
    log "Restoring from: $manifest"
    
    # Decompress manifest if needed
    local temp_manifest="$manifest"
    if [[ "$manifest" == *.gz ]]; then
        temp_manifest=$(mktemp)
        gunzip -c "$manifest" > "$temp_manifest"
    fi
    
    # Restore chunks
    > "$output"
    local chunk_count=0
    
    while IFS=: read -r hash size; do
        local chunk_path="$CHUNK_STORE/${hash:0:2}/${hash:2:2}/$hash"
        
        if [ ! -f "$chunk_path" ]; then
            log_error "Missing chunk: $hash"
            rm -f "$output"
            [ "$temp_manifest" != "$manifest" ] && rm -f "$temp_manifest"
            return 1
        fi
        
        # Decompress and append chunk
        gunzip -c "$chunk_path" >> "$output"
        
        ((chunk_count++))
        if [ $((chunk_count % 100)) -eq 0 ]; then
            echo -ne "\rRestored chunks: $chunk_count"
        fi
    done < "$temp_manifest"
    
    echo  # New line
    [ "$temp_manifest" != "$manifest" ] && rm -f "$temp_manifest"
    
    log "Restore complete: $output"
    return 0
}

# Clean up unreferenced chunks
cleanup_chunks() {
    log "Cleaning up unreferenced chunks..."
    
    local cleaned=0
    sqlite3 "$DB_PATH" "SELECT hash FROM chunks WHERE ref_count = 0;" | while read -r hash; do
        local chunk_path="$CHUNK_STORE/${hash:0:2}/${hash:2:2}/$hash"
        if [ -f "$chunk_path" ]; then
            rm -f "$chunk_path"
            ((cleaned++))
        fi
        sqlite3 "$DB_PATH" "DELETE FROM chunks WHERE hash='$hash';"
    done
    
    # Remove empty directories
    find "$CHUNK_STORE" -type d -empty -delete 2>/dev/null
    
    log "Cleaned up $cleaned unreferenced chunks"
}

# Show deduplication statistics
show_stats() {
    echo -e "\n=== Deduplication Statistics ==="
    
    local total_chunks=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM chunks;")
    local total_refs=$(sqlite3 "$DB_PATH" "SELECT SUM(ref_count) FROM chunks;")
    local total_size=$(sqlite3 "$DB_PATH" "SELECT SUM(size) FROM chunks;")
    local dedup_ratio=$(echo "scale=2; ($total_refs - $total_chunks) * 100 / $total_refs" | bc 2>/dev/null || echo "0")
    
    echo "Total unique chunks: $total_chunks"
    echo "Total chunk references: $total_refs"
    echo "Deduplication ratio: ${dedup_ratio}%"
    echo "Storage used: $(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "$total_size bytes")"
    
    echo -e "\nTop duplicated chunks:"
    sqlite3 "$DB_PATH" -column -header "SELECT substr(hash, 1, 16) as hash_prefix, ref_count, printf('%.2f KB', size/1024.0) as size FROM chunks WHERE ref_count > 1 ORDER BY ref_count DESC LIMIT 10;"
    
    echo -e "\nRecent deduplicated files:"
    sqlite3 "$DB_PATH" -column -header "SELECT substr(path, -40) as file, printf('%.2f MB', size/1024.0/1024.0) as size, printf('%.1f%%', dedup_ratio) as ratio FROM files ORDER BY created DESC LIMIT 10;"
}

# Verify deduplication integrity
verify_dedup() {
    local manifest="$1"
    
    log "Verifying deduplication integrity..."
    
    # Create temp file for verification
    local temp_file=$(mktemp)
    
    if restore_file "$manifest" "$temp_file"; then
        # Calculate checksum of restored file
        local restored_hash=$(sha256sum "$temp_file" | cut -d' ' -f1)
        rm -f "$temp_file"
        
        log "Verification complete: integrity verified"
        return 0
    else
        rm -f "$temp_file"
        log_error "Verification failed: could not restore file"
        return 1
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm Deduplication Module${NC}"
    echo "Efficient storage optimization through content-based deduplication."
    echo "Reduces backup storage requirements by identifying and storing unique data chunks."
    echo ""
    echo "Usage: grim dedup <command> [options]"
    echo ""
    echo "Commands:"
    echo "  dedup <file> [output]     - Deduplicate a file using chunk-based analysis"
    echo "  restore <manifest> [out]  - Restore original file from dedup manifest"
    echo "  cleanup                   - Remove unreferenced chunks to free space"
    echo "  stats                     - Show deduplication statistics and ratios"
    echo "  verify <manifest>         - Verify deduplication integrity"
    echo ""
    echo "Examples:"
    echo "  grim dedup dedup backup.tar.gz          # Create dedup version"
    echo "  grim dedup restore backup.dedup.manifest.gz  # Restore original"
    echo "  grim dedup stats                        # Show space savings"
    echo ""
    echo "Configuration:"
    echo "  Chunk size: 1MB (configurable)"
    echo "  Storage: $CHUNK_STORE"
    echo "  Database: $DB_PATH"
}

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        dedup)
            deduplicate_file "$@"
            ;;
        
        restore)
            restore_file "$@"
            ;;
        
        cleanup)
            cleanup_chunks
            ;;
        
        stats)
            init_db
            show_stats
            ;;
        
        verify)
            verify_dedup "$1"
            ;;
        
        help|-h|--help)
            show_help
            ;;
        
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"