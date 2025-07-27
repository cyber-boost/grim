#!/bin/bash
# Grimm Deduplication Module: Advanced storage optimization through content-based deduplication

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/dedup.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/dedup.log"
CHUNK_STORE="$GRIM_ROOT/backups/.dedup_store"
TEMP_DIR="$GRIM_ROOT/tmp/dedup"

# Default settings
DEFAULT_CHUNK_SIZE=1048576  # 1MB chunks
DEFAULT_ALGORITHM="sha256"
DEFAULT_COMPRESSION="gzip"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$LOG_FILE"
}

# Initialize directories and database with migration support
init_system() {
    mkdir -p "$(dirname "$DB_PATH")"
    mkdir -p "$CHUNK_STORE"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Check if database exists and needs migration
    local needs_migration=false
    if [[ -f "$DB_PATH" ]]; then
        # Check if new columns exist
        local has_algorithm=$(sqlite3 "$DB_PATH" "PRAGMA table_info(chunks);" | grep -c "algorithm" || echo "0")
        local has_original_size=$(sqlite3 "$DB_PATH" "PRAGMA table_info(files);" | grep -c "original_size" || echo "0")
        
        if [[ $has_algorithm -eq 0 ]] || [[ $has_original_size -eq 0 ]]; then
            needs_migration=true
            log "Database migration required..."
        fi
    fi
    
    # Create or migrate database schema
    if [[ "$needs_migration" == "true" ]]; then
        # Backup existing database
        cp "$DB_PATH" "${DB_PATH}.backup.$(date +%s)" 2>/dev/null || true
        
        # Add new columns to existing tables
        sqlite3 "$DB_PATH" <<'EOF'
-- Add new columns to chunks table if they don't exist
ALTER TABLE chunks ADD COLUMN algorithm TEXT DEFAULT 'sha256';
ALTER TABLE chunks ADD COLUMN compression TEXT DEFAULT 'gzip';

-- Migrate files table (rename old table, create new one, copy data)
CREATE TABLE IF NOT EXISTS files_new (
    path TEXT PRIMARY KEY,
    original_size INTEGER,
    dedup_size INTEGER,
    chunk_count INTEGER,
    dedup_ratio REAL,
    algorithm TEXT,
    created INTEGER,
    checksum TEXT
);

-- Copy existing data if old files table exists
INSERT OR IGNORE INTO files_new (path, original_size, dedup_size, chunk_count, dedup_ratio, algorithm, created, checksum)
SELECT path, 
       COALESCE(size, 0) as original_size,
       COALESCE(size, 0) as dedup_size,
       COALESCE(chunk_count, 0),
       COALESCE(dedup_ratio, 0),
       'sha256' as algorithm,
       COALESCE(created, strftime('%s','now')),
       '' as checksum
FROM files;

-- Replace old table with new one
DROP TABLE IF EXISTS files;
ALTER TABLE files_new RENAME TO files;

-- Add new column to file_chunks table if it doesn't exist
ALTER TABLE file_chunks ADD COLUMN chunk_size INTEGER DEFAULT 0;

-- Create new tables if they don't exist
CREATE TABLE IF NOT EXISTS dedup_stats (
    date TEXT PRIMARY KEY,
    total_files INTEGER,
    total_original_size INTEGER,
    total_dedup_size INTEGER,
    space_saved INTEGER,
    dedup_ratio REAL
);

-- Recreate indexes
CREATE INDEX IF NOT EXISTS idx_chunk_refs ON chunks(ref_count);
CREATE INDEX IF NOT EXISTS idx_file_chunks ON file_chunks(chunk_hash);
CREATE INDEX IF NOT EXISTS idx_chunk_algorithm ON chunks(algorithm);
EOF
        
        log_success "Database migration completed"
    else
        # Create database schema for new installations
        sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS chunks (
    hash TEXT PRIMARY KEY,
    size INTEGER,
    ref_count INTEGER DEFAULT 1,
    first_seen INTEGER,
    last_seen INTEGER,
    algorithm TEXT DEFAULT 'sha256',
    compression TEXT DEFAULT 'gzip'
);

CREATE TABLE IF NOT EXISTS files (
    path TEXT PRIMARY KEY,
    original_size INTEGER,
    dedup_size INTEGER,
    chunk_count INTEGER,
    dedup_ratio REAL,
    algorithm TEXT,
    created INTEGER,
    checksum TEXT
);

CREATE TABLE IF NOT EXISTS file_chunks (
    file_path TEXT,
    chunk_index INTEGER,
    chunk_hash TEXT,
    chunk_size INTEGER,
    PRIMARY KEY (file_path, chunk_index),
    FOREIGN KEY (file_path) REFERENCES files(path),
    FOREIGN KEY (chunk_hash) REFERENCES chunks(hash)
);

CREATE TABLE IF NOT EXISTS dedup_stats (
    date TEXT PRIMARY KEY,
    total_files INTEGER,
    total_original_size INTEGER,
    total_dedup_size INTEGER,
    space_saved INTEGER,
    dedup_ratio REAL
);

CREATE INDEX IF NOT EXISTS idx_chunk_refs ON chunks(ref_count);
CREATE INDEX IF NOT EXISTS idx_file_chunks ON file_chunks(chunk_hash);
CREATE INDEX IF NOT EXISTS idx_chunk_algorithm ON chunks(algorithm);
EOF
    fi
}

# Calculate hash for chunk
calculate_chunk_hash() {
    local data="$1"
    local algorithm="${2:-sha256}"
    
    case "$algorithm" in
        sha256)
            echo -n "$data" | sha256sum | cut -d' ' -f1
            ;;
        sha1)
            echo -n "$data" | sha1sum | cut -d' ' -f1
            ;;
        md5)
            echo -n "$data" | md5sum | cut -d' ' -f1
            ;;
        *)
            echo -n "$data" | sha256sum | cut -d' ' -f1
            ;;
    esac
}

# Store unique chunk with compression
store_chunk() {
    local hash="$1"
    local data="$2"
    local compression="${3:-gzip}"
    
    # Create hierarchical directory structure
    local chunk_dir="$CHUNK_STORE/${hash:0:2}/${hash:2:2}"
    local chunk_path="$chunk_dir/$hash"
    
    mkdir -p "$chunk_dir"
    
    # Store and compress chunk
    case "$compression" in
        gzip)
            echo -n "$data" | gzip -9 > "$chunk_path.gz"
            ;;
        bzip2)
            echo -n "$data" | bzip2 -9 > "$chunk_path.bz2"
            ;;
        xz)
            echo -n "$data" | xz -9 > "$chunk_path.xz"
            ;;
        none)
            echo -n "$data" > "$chunk_path"
            ;;
        *)
            echo -n "$data" | gzip -9 > "$chunk_path.gz"
            ;;
    esac
}

# Retrieve chunk data
retrieve_chunk() {
    local hash="$1"
    local compression="${2:-gzip}"
    
    local chunk_dir="$CHUNK_STORE/${hash:0:2}/${hash:2:2}"
    local chunk_path="$chunk_dir/$hash"
    
    case "$compression" in
        gzip)
            if [[ -f "$chunk_path.gz" ]]; then
                gunzip -c "$chunk_path.gz"
                return 0
            fi
            ;;
        bzip2)
            if [[ -f "$chunk_path.bz2" ]]; then
                bunzip2 -c "$chunk_path.bz2"
                return 0
            fi
            ;;
        xz)
            if [[ -f "$chunk_path.xz" ]]; then
                unxz -c "$chunk_path.xz"
                return 0
            fi
            ;;
        none)
            if [[ -f "$chunk_path" ]]; then
                cat "$chunk_path"
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Enhanced file deduplication with configurable options
deduplicate_file() {
    local file="$1"
    local output_base="${2:-}"
    local chunk_size="${3:-$DEFAULT_CHUNK_SIZE}"
    local algorithm="${4:-$DEFAULT_ALGORITHM}"
    local compression="${5:-$DEFAULT_COMPRESSION}"
    
    # Validate input
    if [[ -z "$file" ]]; then
        log_error "No input file specified"
        echo "Usage: grim dedup dedup <file> [output_base] [chunk_size] [algorithm] [compression]"
        return 1
    fi
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Set output paths
    if [[ -z "$output_base" ]]; then
        output_base="$file"
    fi
    
    local manifest="${output_base}.dedup.manifest"
    local metadata="${output_base}.dedup.meta"
    
    init_system
    
    log "Starting deduplication: $file"
    echo -e "${CYAN}File: $file${NC}"
    echo -e "${CYAN}Chunk size: $(numfmt --to=iec-i --suffix=B $chunk_size)${NC}"
    echo -e "${CYAN}Algorithm: $algorithm${NC}"
    echo -e "${CYAN}Compression: $compression${NC}"
    
    local file_size=$(stat -c%s "$file")
    local total_chunks=0
    local unique_chunks=0
    local duplicate_chunks=0
    local bytes_saved=0
    local start_time=$(date +%s)
    
    # Create manifest and metadata files
    > "$manifest"
    
    # Calculate file checksum for integrity
    local file_checksum=$(${algorithm}sum "$file" | cut -d' ' -f1)
    
    # Process file in chunks using a more reliable method
    local offset=0
    while [[ $offset -lt $file_size ]]; do
        # Calculate remaining bytes
        local remaining=$((file_size - offset))
        local read_size=$chunk_size
        if [[ $remaining -lt $chunk_size ]]; then
            read_size=$remaining
        fi
        
        # Read chunk using head/tail for reliable byte reading
        local chunk_data
        if [[ $offset -eq 0 ]] && [[ $read_size -eq $file_size ]]; then
            # Read entire file if it's smaller than chunk size
            chunk_data=$(cat "$file")
        else
            # Read specific range
            chunk_data=$(head -c $((offset + read_size)) "$file" | tail -c $read_size)
        fi
        
        if [[ -n "$chunk_data" ]] || [[ $read_size -gt 0 ]]; then
            local actual_size=${#chunk_data}
            
            # Handle case where chunk_data might be empty but we expect data
            if [[ $actual_size -eq 0 ]] && [[ $read_size -gt 0 ]]; then
                # Try alternative reading method for edge cases
                chunk_data=$(dd if="$file" bs=1 skip=$offset count=$read_size 2>/dev/null | cat)
                actual_size=${#chunk_data}
            fi
            
            if [[ $actual_size -gt 0 ]]; then
                local hash=$(calculate_chunk_hash "$chunk_data" "$algorithm")
                
                # Check if chunk exists in database
                local existing=$(sqlite3 "$DB_PATH" "SELECT hash FROM chunks WHERE hash='$hash';")
                
                if [[ -z "$existing" ]]; then
                    # New unique chunk
                    store_chunk "$hash" "$chunk_data" "$compression"
                    sqlite3 "$DB_PATH" "INSERT INTO chunks (hash, size, algorithm, compression, first_seen, last_seen) VALUES ('$hash', $actual_size, '$algorithm', '$compression', strftime('%s','now'), strftime('%s','now'));"
                    ((unique_chunks++))
                    log "New chunk: $hash (size: $actual_size)"
                else
                    # Duplicate chunk found
                    sqlite3 "$DB_PATH" "UPDATE chunks SET ref_count = ref_count + 1, last_seen = strftime('%s','now') WHERE hash='$hash';"
                    ((duplicate_chunks++))
                    ((bytes_saved += actual_size))
                    log "Duplicate chunk: $hash (saved: $actual_size bytes)"
                fi
                
                # Add to manifest
                echo "$hash:$actual_size:$algorithm:$compression" >> "$manifest"
                
                ((total_chunks++))
                offset=$((offset + actual_size))
                
                # Show progress
                local progress=$((offset * 100 / file_size))
                echo -ne "\rProgress: ${progress}% (chunks: $total_chunks, unique: $unique_chunks, duplicates: $duplicate_chunks)"
            else
                # No more data to read
                break
            fi
        else
            break
        fi
    done
    
    echo  # New line after progress
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Calculate deduplication metrics
    local dedup_size=$((file_size - bytes_saved))
    local dedup_ratio=0
    if [[ $file_size -gt 0 ]]; then
        dedup_ratio=$(echo "scale=2; $bytes_saved * 100 / $file_size" | bc)
    fi
    
    # Store file metadata in database
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO files (path, original_size, dedup_size, chunk_count, dedup_ratio, algorithm, created, checksum) VALUES ('$file', $file_size, $dedup_size, $total_chunks, $dedup_ratio, '$algorithm', strftime('%s','now'), '$file_checksum');"
    
    # Store file-chunk mappings
    sqlite3 "$DB_PATH" "DELETE FROM file_chunks WHERE file_path='$file';"
    local chunk_index=0
    while IFS=: read -r hash size alg comp; do
        sqlite3 "$DB_PATH" "INSERT INTO file_chunks (file_path, chunk_index, chunk_hash, chunk_size) VALUES ('$file', $chunk_index, '$hash', $size);"
        ((chunk_index++))
    done < "$manifest"
    
    # Create metadata file
    cat > "$metadata" <<EOF
# Grim Deduplication Metadata
FILE_PATH="$file"
ORIGINAL_SIZE=$file_size
DEDUP_SIZE=$dedup_size
TOTAL_CHUNKS=$total_chunks
UNIQUE_CHUNKS=$unique_chunks
DUPLICATE_CHUNKS=$duplicate_chunks
BYTES_SAVED=$bytes_saved
DEDUP_RATIO=$dedup_ratio
ALGORITHM="$algorithm"
COMPRESSION="$compression"
CHUNK_SIZE=$chunk_size
FILE_CHECKSUM="$file_checksum"
CREATED="$(date -Iseconds)"
DURATION=$duration
EOF
    
    # Compress manifest
    gzip -9 "$manifest"
    
    # Display results
    echo -e "${GREEN}✓ Deduplication completed${NC}"
    echo -e "Original size: $(numfmt --to=iec-i --suffix=B $file_size)"
    echo -e "Dedup size: $(numfmt --to=iec-i --suffix=B $dedup_size)"
    echo -e "Space saved: $(numfmt --to=iec-i --suffix=B $bytes_saved) (${dedup_ratio}%)"
    echo -e "Total chunks: $total_chunks (unique: $unique_chunks, duplicates: $duplicate_chunks)"
    echo -e "Processing time: ${duration}s"
    echo -e "Manifest: ${manifest}.gz"
    echo -e "Metadata: $metadata"
    
    log_success "Deduplication completed: $file -> ${dedup_ratio}% space saved"
    
    return 0
}

# Enhanced restore with metadata support
restore_file() {
    local manifest="$1"
    local output="${2:-}"
    
    if [[ -z "$manifest" ]]; then
        log_error "No manifest file specified"
        echo "Usage: grim dedup restore <manifest> [output_file]"
        return 1
    fi
    
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest not found: $manifest"
        return 1
    fi
    
    # Determine output file
    if [[ -z "$output" ]]; then
        # Try to extract original filename from manifest name
        output="${manifest}"
        output="${output%.dedup.manifest.gz}"
        output="${output%.dedup.manifest}"
        if [[ "$output" == "$manifest" ]]; then
            output="${manifest}.restored"
        fi
    fi
    
    log "Restoring from manifest: $manifest"
    echo -e "${CYAN}Manifest: $manifest${NC}"
    echo -e "${CYAN}Output: $output${NC}"
    
    # Decompress manifest if needed
    local temp_manifest="$manifest"
    if [[ "$manifest" == *.gz ]]; then
        temp_manifest=$(mktemp)
        gunzip -c "$manifest" > "$temp_manifest"
    fi
    
    # Check if we have metadata
    local metadata_file="${manifest%.gz}"
    metadata_file="${metadata_file%.manifest}.meta"
    local expected_size=0
    local expected_checksum=""
    local expected_algorithm="sha256"
    
    if [[ -f "$metadata_file" ]]; then
        source "$metadata_file"
        expected_size=$ORIGINAL_SIZE
        expected_checksum=$FILE_CHECKSUM
        expected_algorithm=$ALGORITHM
        echo -e "${BLUE}Using metadata: original size $(numfmt --to=iec-i --suffix=B $expected_size)${NC}"
    fi
    
    # Restore chunks
    > "$output"
    local chunk_count=0
    local restored_size=0
    local start_time=$(date +%s)
    
    while IFS=: read -r hash size algorithm compression; do
        # Handle old format (hash:size) and new format (hash:size:algorithm:compression)
        if [[ -z "$algorithm" ]]; then
            algorithm="sha256"
        fi
        if [[ -z "$compression" ]]; then
            compression="gzip"
        fi
        
        # Retrieve chunk data
        local chunk_data=$(retrieve_chunk "$hash" "$compression")
        
        if [[ $? -ne 0 ]] || [[ -z "$chunk_data" ]]; then
            log_error "Missing or corrupted chunk: $hash"
            rm -f "$output"
            [[ "$temp_manifest" != "$manifest" ]] && rm -f "$temp_manifest"
            return 1
        fi
        
        # Verify chunk integrity
        local actual_hash=$(calculate_chunk_hash "$chunk_data" "$algorithm")
        if [[ "$actual_hash" != "$hash" ]]; then
            log_error "Chunk integrity verification failed: $hash"
            rm -f "$output"
            [[ "$temp_manifest" != "$manifest" ]] && rm -f "$temp_manifest"
            return 1
        fi
        
        # Append chunk to output
        echo -n "$chunk_data" >> "$output"
        
        ((chunk_count++))
        restored_size=$((restored_size + ${#chunk_data}))
        
        # Show progress
        if [[ $expected_size -gt 0 ]]; then
            local progress=$((restored_size * 100 / expected_size))
            echo -ne "\rProgress: ${progress}% (chunks: $chunk_count, size: $(numfmt --to=iec-i --suffix=B $restored_size))"
        else
            echo -ne "\rRestored chunks: $chunk_count (size: $(numfmt --to=iec-i --suffix=B $restored_size))"
        fi
    done < "$temp_manifest"
    
    echo  # New line
    [[ "$temp_manifest" != "$manifest" ]] && rm -f "$temp_manifest"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Verify restored file if we have expected checksum
    if [[ -n "$expected_checksum" ]]; then
        echo -e "${BLUE}Verifying restored file integrity...${NC}"
        local actual_checksum=$(${expected_algorithm}sum "$output" | cut -d' ' -f1)
        
        if [[ "$actual_checksum" == "$expected_checksum" ]]; then
            echo -e "${GREEN}✓ File integrity verified${NC}"
        else
            log_error "File integrity verification failed"
            echo -e "${RED}✗ Checksum mismatch${NC}"
            echo -e "Expected: $expected_checksum"
            echo -e "Actual: $actual_checksum"
            return 1
        fi
    fi
    
    # Display results
    echo -e "${GREEN}✓ Restore completed${NC}"
    echo -e "Chunks restored: $chunk_count"
    echo -e "File size: $(numfmt --to=iec-i --suffix=B $restored_size)"
    echo -e "Processing time: ${duration}s"
    
    log_success "Restore completed: $manifest -> $output"
    return 0
}

# Enhanced cleanup with detailed reporting
cleanup_chunks() {
    local dry_run="${1:-false}"
    
    init_system
    
    if [[ "$dry_run" == "true" ]]; then
        log "Starting cleanup analysis (dry run)..."
        echo -e "${YELLOW}DRY RUN MODE - No files will be deleted${NC}"
    else
        log "Starting chunk cleanup..."
    fi
    
    local total_chunks=0
    local unreferenced_chunks=0
    local cleaned_files=0
    local space_freed=0
    local start_time=$(date +%s)
    
    # Find unreferenced chunks
    echo -e "${BLUE}Analyzing chunk references...${NC}"
    
    # Get all chunks with zero references
    local unreferenced_list=$(mktemp)
    sqlite3 "$DB_PATH" "SELECT hash, size FROM chunks WHERE ref_count = 0;" > "$unreferenced_list"
    
    total_chunks=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM chunks;")
    unreferenced_chunks=$(wc -l < "$unreferenced_list")
    
    echo "Total chunks: $total_chunks"
    echo "Unreferenced chunks: $unreferenced_chunks"
    
    if [[ $unreferenced_chunks -eq 0 ]]; then
        echo -e "${GREEN}No unreferenced chunks found${NC}"
        rm -f "$unreferenced_list"
        return 0
    fi
    
    # Process unreferenced chunks
    while IFS='|' read -r hash size; do
        if [[ -n "$hash" ]]; then
            local chunk_dir="$CHUNK_STORE/${hash:0:2}/${hash:2:2}"
            local chunk_found=false
            
            # Check for chunk with different compression formats
            for ext in .gz .bz2 .xz ""; do
                local chunk_path="$chunk_dir/$hash$ext"
                if [[ -f "$chunk_path" ]]; then
                    chunk_found=true
                    if [[ "$dry_run" != "true" ]]; then
                        rm -f "$chunk_path"
                        log "Removed chunk: $hash$ext"
                    else
                        echo "Would remove: $chunk_path"
                    fi
                    ((cleaned_files++))
                    space_freed=$((space_freed + size))
                    break
                fi
            done
            
            if [[ "$chunk_found" == "true" && "$dry_run" != "true" ]]; then
                sqlite3 "$DB_PATH" "DELETE FROM chunks WHERE hash='$hash';"
            fi
        fi
    done < "$unreferenced_list"
    
    rm -f "$unreferenced_list"
    
    # Remove empty directories if not dry run
    if [[ "$dry_run" != "true" ]]; then
        find "$CHUNK_STORE" -type d -empty -delete 2>/dev/null || true
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update cleanup statistics
    if [[ "$dry_run" != "true" ]]; then
        sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO dedup_stats (date, total_files, total_original_size, total_dedup_size, space_saved, dedup_ratio) SELECT date('now'), COUNT(*), SUM(original_size), SUM(dedup_size), SUM(original_size - dedup_size), AVG(dedup_ratio) FROM files;"
    fi
    
    # Display results
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}✓ Cleanup analysis completed${NC}"
    else
        echo -e "${GREEN}✓ Cleanup completed${NC}"
    fi
    echo -e "Files processed: $cleaned_files"
    echo -e "Space freed: $(numfmt --to=iec-i --suffix=B $space_freed)"
    echo -e "Processing time: ${duration}s"
    
    if [[ "$dry_run" != "true" ]]; then
        log_success "Cleanup completed: $cleaned_files files removed, $(numfmt --to=iec-i --suffix=B $space_freed) freed"
    fi
    
    return 0
}

# Enhanced statistics with detailed breakdowns
show_stats() {
    init_system
    
    echo -e "\n${CYAN}=== Grim Deduplication Statistics ===${NC}"
    
    # Overall statistics
    local total_chunks=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM chunks;" 2>/dev/null || echo "0")
    local total_refs=$(sqlite3 "$DB_PATH" "SELECT SUM(ref_count) FROM chunks;" 2>/dev/null || echo "0")
    local unique_size=$(sqlite3 "$DB_PATH" "SELECT SUM(size) FROM chunks;" 2>/dev/null || echo "0")
    local total_files=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM files;" 2>/dev/null || echo "0")
    
    if [[ $total_refs -gt 0 && $total_chunks -gt 0 ]]; then
        local overall_dedup_ratio=$(echo "scale=2; ($total_refs - $total_chunks) * 100 / $total_refs" | bc 2>/dev/null || echo "0")
    else
        local overall_dedup_ratio="0"
    fi
    
    echo -e "\n${YELLOW}Overall Statistics:${NC}"
    echo "Total files processed: $total_files"
    echo "Total unique chunks: $total_chunks"
    echo "Total chunk references: $total_refs"
    echo "Overall deduplication ratio: ${overall_dedup_ratio}%"
    echo "Storage used by chunks: $(numfmt --to=iec-i --suffix=B $unique_size 2>/dev/null || echo "$unique_size bytes")"
    
    # File statistics
    if [[ $total_files -gt 0 ]]; then
        local total_original=$(sqlite3 "$DB_PATH" "SELECT SUM(original_size) FROM files;" 2>/dev/null || echo "0")
        local total_dedup=$(sqlite3 "$DB_PATH" "SELECT SUM(dedup_size) FROM files;" 2>/dev/null || echo "0")
        local space_saved=$((total_original - total_dedup))
        
        echo -e "\n${YELLOW}File Statistics:${NC}"
        echo "Total original size: $(numfmt --to=iec-i --suffix=B $total_original)"
        echo "Total deduplicated size: $(numfmt --to=iec-i --suffix=B $total_dedup)"
        echo "Space saved: $(numfmt --to=iec-i --suffix=B $space_saved)"
        
        if [[ $total_original -gt 0 ]]; then
            local file_dedup_ratio=$(echo "scale=2; $space_saved * 100 / $total_original" | bc)
            echo "File deduplication ratio: ${file_dedup_ratio}%"
        fi
    fi
    
    # Algorithm breakdown
    echo -e "\n${YELLOW}Algorithm Usage:${NC}"
    sqlite3 "$DB_PATH" -column -header "SELECT algorithm, COUNT(*) as chunks, printf('%.2f MB', SUM(size)/1024.0/1024.0) as total_size FROM chunks GROUP BY algorithm ORDER BY chunks DESC;" 2>/dev/null || echo "No algorithm data available"
    
    # Compression breakdown
    echo -e "\n${YELLOW}Compression Usage:${NC}"
    sqlite3 "$DB_PATH" -column -header "SELECT compression, COUNT(*) as chunks, printf('%.2f MB', SUM(size)/1024.0/1024.0) as total_size FROM chunks GROUP BY compression ORDER BY chunks DESC;" 2>/dev/null || echo "No compression data available"
    
    # Top duplicated chunks
    echo -e "\n${YELLOW}Most Duplicated Chunks:${NC}"
    sqlite3 "$DB_PATH" -column -header "SELECT substr(hash, 1, 16) as hash_prefix, ref_count, printf('%.2f KB', size/1024.0) as size, algorithm FROM chunks WHERE ref_count > 1 ORDER BY ref_count DESC LIMIT 10;" 2>/dev/null || echo "No duplicate chunks found"
    
    # Recent files
    echo -e "\n${YELLOW}Recently Processed Files:${NC}"
    sqlite3 "$DB_PATH" -column -header "SELECT substr(path, -50) as file_path, printf('%.2f MB', original_size/1024.0/1024.0) as orig_size, printf('%.1f%%', dedup_ratio) as saved, algorithm, datetime(created, 'unixepoch') as processed FROM files ORDER BY created DESC LIMIT 10;" 2>/dev/null || echo "No files processed yet"
    
    # Storage efficiency by date
    echo -e "\n${YELLOW}Historical Efficiency:${NC}"
    sqlite3 "$DB_PATH" -column -header "SELECT date, total_files, printf('%.2f GB', total_original_size/1024.0/1024.0/1024.0) as original, printf('%.2f GB', total_dedup_size/1024.0/1024.0/1024.0) as dedup, printf('%.1f%%', dedup_ratio) as efficiency FROM dedup_stats ORDER BY date DESC LIMIT 5;" 2>/dev/null || echo "No historical data available"
}

# Enhanced verification with comprehensive checks
verify_dedup() {
    local manifest="$1"
    local check_integrity="${2:-true}"
    
    if [[ -z "$manifest" ]]; then
        log_error "No manifest file specified"
        echo "Usage: grim dedup verify <manifest> [check_integrity]"
        return 1
    fi
    
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest not found: $manifest"
        return 1
    fi
    
    log "Starting deduplication verification: $manifest"
    echo -e "${CYAN}Verifying: $manifest${NC}"
    
    local verification_passed=true
    local start_time=$(date +%s)
    
    # Check manifest integrity
    echo -e "${BLUE}Checking manifest integrity...${NC}"
    
    local temp_manifest="$manifest"
    if [[ "$manifest" == *.gz ]]; then
        temp_manifest=$(mktemp)
        if ! gunzip -c "$manifest" > "$temp_manifest" 2>/dev/null; then
            echo -e "${RED}✗ Manifest decompression failed${NC}"
            verification_passed=false
            rm -f "$temp_manifest"
            return 1
        fi
        echo -e "${GREEN}✓ Manifest decompression OK${NC}"
    fi
    
    # Check metadata if available
    local metadata_file="${manifest%.gz}"
    metadata_file="${metadata_file%.manifest}.meta"
    
    if [[ -f "$metadata_file" ]]; then
        echo -e "${BLUE}Checking metadata...${NC}"
        if source "$metadata_file" 2>/dev/null; then
            echo -e "  Original size: $(numfmt --to=iec-i --suffix=B $ORIGINAL_SIZE)"
            echo -e "  Chunks: $TOTAL_CHUNKS (unique: $UNIQUE_CHUNKS, duplicates: $DUPLICATE_CHUNKS)"
            echo -e "  Algorithm: $ALGORITHM"
            echo -e "  Compression: $COMPRESSION"
            echo -e "  Created: $CREATED"
            echo -e "${GREEN}✓ Metadata OK${NC}"
        else
            echo -e "${YELLOW}⚠ Metadata file corrupted${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No metadata file found${NC}"
    fi
    
    # Verify chunk availability and integrity
    echo -e "${BLUE}Verifying chunk availability...${NC}"
    
    local total_chunks=0
    local missing_chunks=0
    local corrupted_chunks=0
    local verified_chunks=0
    
    while IFS=: read -r hash size algorithm compression; do
        # Handle old and new manifest formats
        if [[ -z "$algorithm" ]]; then
            algorithm="sha256"
        fi
        if [[ -z "$compression" ]]; then
            compression="gzip"
        fi
        
        ((total_chunks++))
        
        # Check if chunk exists
        local chunk_data=$(retrieve_chunk "$hash" "$compression" 2>/dev/null)
        
        if [[ $? -ne 0 ]] || [[ -z "$chunk_data" ]]; then
            echo -e "${RED}✗ Missing chunk: $hash${NC}"
            ((missing_chunks++))
            verification_passed=false
        else
            # Verify chunk integrity if requested
            if [[ "$check_integrity" == "true" ]]; then
                local actual_hash=$(calculate_chunk_hash "$chunk_data" "$algorithm")
                if [[ "$actual_hash" != "$hash" ]]; then
                    echo -e "${RED}✗ Corrupted chunk: $hash${NC}"
                    ((corrupted_chunks++))
                    verification_passed=false
                else
                    ((verified_chunks++))
                fi
            else
                ((verified_chunks++))
            fi
        fi
        
        # Show progress
        if [[ $((total_chunks % 100)) -eq 0 ]]; then
            echo -ne "\rChecked chunks: $total_chunks (verified: $verified_chunks, missing: $missing_chunks, corrupted: $corrupted_chunks)"
        fi
    done < "$temp_manifest"
    
    echo  # New line
    [[ "$temp_manifest" != "$manifest" ]] && rm -f "$temp_manifest"
    
    # Test restoration if integrity check passed
    if [[ "$verification_passed" == "true" && "$check_integrity" == "true" ]]; then
        echo -e "${BLUE}Testing file restoration...${NC}"
        
        local temp_output=$(mktemp)
        if restore_file "$manifest" "$temp_output" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Restoration test passed${NC}"
            rm -f "$temp_output"
        else
            echo -e "${RED}✗ Restoration test failed${NC}"
            verification_passed=false
            rm -f "$temp_output"
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Display final results
    echo -e "\n${YELLOW}Verification Summary:${NC}"
    echo "Total chunks: $total_chunks"
    echo "Verified chunks: $verified_chunks"
    echo "Missing chunks: $missing_chunks"
    echo "Corrupted chunks: $corrupted_chunks"
    echo "Processing time: ${duration}s"
    
    if [[ "$verification_passed" == "true" ]]; then
        echo -e "${GREEN}✓ Overall verification: PASSED${NC}"
        log_success "Verification passed for: $manifest"
        return 0
    else
        echo -e "${RED}✗ Overall verification: FAILED${NC}"
        log_error "Verification failed for: $manifest"
        return 1
    fi
}

# Benchmark deduplication performance
benchmark_dedup() {
    local test_size="${1:-10485760}"  # 10MB default
    local chunk_sizes="${2:-"65536 262144 1048576 4194304"}"  # 64K, 256K, 1M, 4M
    local algorithms="${3:-"sha256 sha1 md5"}"
    local compressions="${4:-"gzip bzip2 xz none"}"
    
    echo -e "${CYAN}=== Grim Deduplication Benchmark ===${NC}"
    echo -e "Test file size: $(numfmt --to=iec-i --suffix=B $test_size)"
    echo -e "Chunk sizes: $chunk_sizes"
    echo -e "Algorithms: $algorithms"
    echo -e "Compressions: $compressions"
    echo
    
    # Create test file with patterns for realistic deduplication
    local test_file=$(mktemp)
    local pattern_size=1024
    local pattern_data=$(head -c $pattern_size /dev/urandom | base64)
    
    echo -e "${BLUE}Creating test file with deduplication patterns...${NC}"
    local written=0
    while [[ $written -lt $test_size ]]; do
        # Mix of repeated patterns and unique data for realistic dedup ratios
        if [[ $((RANDOM % 3)) -eq 0 ]]; then
            # Repeated pattern (33% chance)
            echo -n "$pattern_data" >> "$test_file"
            written=$((written + ${#pattern_data}))
        else
            # Unique data (67% chance)
            head -c $pattern_size /dev/urandom >> "$test_file" 2>/dev/null
            written=$((written + pattern_size))
        fi
    done
    
    # Benchmark results
    echo -e "\n${YELLOW}Benchmark Results:${NC}"
    printf "%-10s %-12s %-8s %-10s %-12s %-10s %-8s %-10s\n" "Chunk" "Algorithm" "Compress" "Time(s)" "Dedup%" "Chunks" "Unique" "Speed"
    printf "%s\n" "$(printf '=%.0s' {1..88})"
    
    for chunk_size in $chunk_sizes; do
        for algorithm in $algorithms; do
            for compression in $compressions; do
                local start_time=$(date +%s.%N)
                
                # Run deduplication
                local bench_output=$(mktemp)
                if deduplicate_file "$test_file" "$bench_output" "$chunk_size" "$algorithm" "$compression" >/dev/null 2>&1; then
                    local end_time=$(date +%s.%N)
                    local duration=$(echo "$end_time - $start_time" | bc)
                    
                    # Get results from metadata
                    local metadata="${bench_output}.dedup.meta"
                    if [[ -f "$metadata" ]]; then
                        source "$metadata"
                        local speed=$(echo "scale=2; $ORIGINAL_SIZE / 1024 / 1024 / $duration" | bc)
                        
                        printf "%-10s %-12s %-8s %-10.2f %-12.1f %-10d %-8d %-10.1f\n" \
                            "$(numfmt --to=iec $chunk_size)" \
                            "$algorithm" \
                            "$compression" \
                            "$duration" \
                            "$DEDUP_RATIO" \
                            "$TOTAL_CHUNKS" \
                            "$UNIQUE_CHUNKS" \
                            "${speed}MB/s"
                    fi
                    
                    # Cleanup benchmark files
                    rm -f "$bench_output"* 2>/dev/null
                else
                    printf "%-10s %-12s %-8s %-10s %-12s %-10s %-8s %-10s\n" \
                        "$(numfmt --to=iec $chunk_size)" \
                        "$algorithm" \
                        "$compression" \
                        "FAILED" \
                        "-" \
                        "-" \
                        "-" \
                        "-"
                fi
            done
        done
    done
    
    # Cleanup
    rm -f "$test_file"
    
    echo -e "\n${GREEN}✓ Benchmark completed${NC}"
    log "Benchmark completed with test size: $(numfmt --to=iec-i --suffix=B $test_size)"
}

# Enhanced help with all options
show_help() {
    echo -e "${CYAN}Grim Deduplication Module v2.0${NC}"
    echo "Advanced storage optimization through content-based deduplication"
    echo "Reduces storage requirements by identifying and storing unique data chunks only once"
    echo ""
    echo -e "${YELLOW}Usage:${NC} grim dedup <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  dedup <file> [output] [chunk_size] [algorithm] [compression]"
    echo "                                   - Deduplicate file with advanced options"
    echo "  restore <manifest> [output]      - Restore file from deduplication manifest"
    echo "  cleanup [dry_run]                - Remove unreferenced chunks (dry_run=true for analysis)"
    echo "  stats                            - Show comprehensive deduplication statistics"
    echo "  verify <manifest> [check_integrity] - Verify deduplication integrity"
    echo "  benchmark [size] [chunks] [algs] [comps] - Run performance benchmarks"
    echo "  help                             - Show this help"
    echo ""
    echo -e "${YELLOW}Algorithms:${NC}"
    echo "  sha256      - SHA-256 (default, recommended)"
    echo "  sha1        - SHA-1 (faster, less secure)"
    echo "  md5         - MD5 (fastest, least secure)"
    echo ""
    echo -e "${YELLOW}Compression:${NC}"
    echo "  gzip        - Good compression, fast (default)"
    echo "  bzip2       - Better compression, slower"
    echo "  xz          - Best compression, slowest"
    echo "  none        - No compression"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  # Basic deduplication"
    echo "  grim dedup dedup backup.tar"
    echo ""
    echo "  # Advanced deduplication with custom settings"
    echo "  grim dedup dedup large_file.bin output 2097152 sha256 xz"
    echo ""
    echo "  # Restore deduplicated file"
    echo "  grim dedup restore backup.tar.dedup.manifest.gz"
    echo ""
    echo "  # Verify integrity"
    echo "  grim dedup verify backup.tar.dedup.manifest.gz true"
    echo ""
    echo "  # Clean up unused chunks (dry run first)"
    echo "  grim dedup cleanup true"
    echo "  grim dedup cleanup false"
    echo ""
    echo "  # Show statistics"
    echo "  grim dedup stats"
    echo ""
    echo "  # Run benchmarks"
    echo "  grim dedup benchmark 52428800"  # 50MB test
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Default chunk size: $(numfmt --to=iec-i --suffix=B $DEFAULT_CHUNK_SIZE)"
    echo "  Default algorithm: $DEFAULT_ALGORITHM"
    echo "  Default compression: $DEFAULT_COMPRESSION"
    echo "  Chunk storage: $CHUNK_STORE"
    echo "  Database: $DB_PATH"
    echo "  Temporary files: $TEMP_DIR"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "  • Content-based deduplication with configurable chunk sizes"
    echo "  • Multiple hash algorithms for different security/speed requirements"
    echo "  • Multiple compression algorithms for optimal storage efficiency"
    echo "  • Hierarchical chunk storage for filesystem performance"
    echo "  • Comprehensive integrity verification and restoration testing"
    echo "  • Detailed statistics and performance monitoring"
    echo "  • Benchmark tools for performance optimization"
    echo "  • Safe cleanup with dry-run capabilities"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT NOTES:${NC}"
    echo "  • Always verify deduplication before deleting original files"
    echo "  • Backup your chunk store and database regularly"
    echo "  • Use appropriate chunk sizes for your data type"
    echo "  • Monitor storage usage and run cleanup periodically"
    echo "  • Test restoration capabilities regularly"
}

# Main function with enhanced argument parsing
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
            cleanup_chunks "$@"
            ;;
        stats)
            show_stats
            ;;
        verify)
            verify_dedup "$@"
            ;;
        benchmark)
            benchmark_dedup "$@"
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