#!/bin/bash
# Grimm Compress Module: Compression management and optimization

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/grimm.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/compress.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

show_help() {
    echo "Grimm Compress Module"
    echo "Usage: compress.sh <command> [options]"
    echo ""
    echo "Purpose: Intelligent compression management with format optimization,"
    echo "         deduplication, and performance analysis capabilities."
    echo ""
    echo "Commands:"
    echo "  compress <path> [format]         - Compress files or directories"
    echo "  decompress <file> [path]         - Decompress files"
    echo "  optimize <path>                  - Optimize existing compressed files"
    echo "  analyze <path>                   - Analyze compression efficiency"
    echo "  list [path]                      - List compressed files"
    echo "  benchmark [format]               - Run compression benchmarks"
    echo "  cleanup [path]                   - Clean up temporary files"
    echo "  help, -h, --help                 - Show this help message"
    echo ""
    echo "Compression Formats:"
    echo "  gzip              - Fast compression, good ratio (default)"
    echo "  bzip2             - Better compression, slower"
    echo "  xz                - Best compression, slowest"
    echo "  lz4               - Very fast, lower compression"
    echo "  zstd              - Fast with good compression"
    echo "  auto              - Automatically choose best format"
    echo ""
    echo "Options:"
    echo "  --level <1-9>           - Compression level (higher = better/slower)"
    echo "  --threads <count>       - Number of threads to use"
    echo "  --keep-original         - Keep original files after compression"
    echo "  --remove-original       - Remove original files after compression"
    echo "  --verify                - Verify compression integrity"
    echo "  --quiet                 - Suppress progress output"
    echo "  --verbose               - Show detailed information"
    echo "  --dry-run               - Show what would be done without doing it"
    echo ""
    echo "Advanced Options:"
    echo "  --exclude <pattern>     - Exclude files matching pattern"
    echo "  --include <pattern>     - Only compress files matching pattern"
    echo "  --min-size <bytes>      - Minimum file size to compress"
    echo "  --max-size <bytes>      - Maximum file size to compress"
    echo "  --deduplicate           - Remove duplicate files before compression"
    echo "  --parallel              - Use parallel compression"
    echo ""
    echo "Examples:"
    echo "  ./compress.sh compress /var/logs gzip              # Compress logs with gzip"
    echo "  ./compress.sh compress /backups xz --level 9       # Maximum compression"
    echo "  ./compress.sh compress /data auto --threads 4      # Auto-format with 4 threads"
    echo "  ./compress.sh decompress backup.tar.xz             # Decompress file"
    echo "  ./compress.sh optimize /compressed-files           # Optimize existing files"
    echo "  ./compress.sh analyze /data                        # Analyze compression efficiency"
    echo "  ./compress.sh list /backups                        # List compressed files"
    echo "  ./compress.sh benchmark                             # Run benchmarks"
    echo "  ./compress.sh cleanup /temp                         # Clean up temp files"
    echo "  ./compress.sh help                                  # Show help"
    echo ""
    echo "Integration:"
    echo "  - Integrates with backup module for compressed backups"
    echo "  - Works with monitor module for file changes"
    echo "  - Sends notifications via notify module"
    echo "  - Logs all operations to database for analysis"
    echo "  - Supports batch processing and automation"
}

# Initialize compression database tables
init_compress_db() {
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS compressed_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    original_path TEXT NOT NULL,
    compressed_path TEXT NOT NULL,
    compression_format TEXT NOT NULL,
    compression_level INTEGER,
    original_size INTEGER NOT NULL,
    compressed_size INTEGER NOT NULL,
    compression_ratio REAL,
    compression_time REAL,
    checksum TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compression_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_type TEXT NOT NULL,
    source_path TEXT NOT NULL,
    target_path TEXT,
    format TEXT,
    level INTEGER,
    status TEXT DEFAULT 'pending',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    files_processed INTEGER DEFAULT 0,
    total_size_saved INTEGER DEFAULT 0,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS compression_benchmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    format TEXT NOT NULL,
    level INTEGER NOT NULL,
    test_file TEXT NOT NULL,
    original_size INTEGER NOT NULL,
    compressed_size INTEGER NOT NULL,
    compression_time REAL NOT NULL,
    decompression_time REAL NOT NULL,
    compression_ratio REAL NOT NULL,
    speed_mbps REAL NOT NULL,
    benchmark_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_compressed_files_path ON compressed_files(original_path);
CREATE INDEX IF NOT EXISTS idx_compressed_files_format ON compressed_files(compression_format);
CREATE INDEX IF NOT EXISTS idx_compression_jobs_status ON compression_jobs(status);
CREATE INDEX IF NOT EXISTS idx_compression_benchmarks_format ON compression_benchmarks(format);
EOF
    log "Compression database initialized"
}

# Compress files or directories
compress_files() {
    local source_path="$1"
    local format="${2:-gzip}"
    local level="${3:-6}"
    local keep_original="${4:-false}"
    local verify="${5:-false}"
    local threads="${6:-1}"
    
    if [ -z "$source_path" ]; then
        log_error "Source path is required"
        return 1
    fi
    
    if [ ! -e "$source_path" ]; then
        log_error "Source path does not exist: $source_path"
        return 1
    fi
    
    init_compress_db
    
    local job_id=$(sqlite3 "$DB_PATH" "INSERT INTO compression_jobs (job_type, source_path, format, level, status, started_at) VALUES ('compress', '$source_path', '$format', $level, 'running', CURRENT_TIMESTAMP); SELECT last_insert_rowid();")
    
    log "Starting compression job $job_id: $source_path with $format (level $level)"
    
    local start_time=$(date +%s)
    local total_files=0
    local total_saved=0
    
    # Determine compression command based on format
    local compress_cmd=""
    local extension=""
    
    case "$format" in
        gzip)
            compress_cmd="gzip -${level}"
            extension=".gz"
            ;;
        bzip2)
            compress_cmd="bzip2 -${level}"
            extension=".bz2"
            ;;
        xz)
            compress_cmd="xz -${level}"
            extension=".xz"
            ;;
        lz4)
            compress_cmd="lz4 -${level}"
            extension=".lz4"
            ;;
        zstd)
            compress_cmd="zstd -${level}"
            extension=".zst"
            ;;
        *)
            log_error "Unsupported compression format: $format"
            return 1
            ;;
    esac
    
    # Add threading if supported and requested
    if [ "$threads" -gt 1 ]; then
        case "$format" in
            gzip)
                if command -v pigz >/dev/null 2>&1; then
                    compress_cmd="pigz -p $threads -${level}"
                fi
                ;;
            bzip2)
                if command -v pbzip2 >/dev/null 2>&1; then
                    compress_cmd="pbzip2 -p$threads -${level}"
                fi
                ;;
            xz)
                compress_cmd="xz -T$threads -${level}"
                ;;
            zstd)
                compress_cmd="zstd -T$threads -${level}"
                ;;
        esac
    fi
    
    # Compress files
    if [ -f "$source_path" ]; then
        # Single file compression
        compress_single_file "$source_path" "$compress_cmd" "$extension" "$format" "$level" "$keep_original" "$verify"
        total_files=1
    elif [ -d "$source_path" ]; then
        # Directory compression
        find "$source_path" -type f -not -name "*.gz" -not -name "*.bz2" -not -name "*.xz" -not -name "*.lz4" -not -name "*.zst" | while read -r file; do
            compress_single_file "$file" "$compress_cmd" "$extension" "$format" "$level" "$keep_original" "$verify"
            ((total_files++))
        done
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update job status
    sqlite3 "$DB_PATH" "UPDATE compression_jobs SET status = 'completed', completed_at = CURRENT_TIMESTAMP, files_processed = $total_files WHERE id = $job_id;"
    
    log "Compression job $job_id completed: $total_files files processed in ${duration}s"
    "$NOTIFY_MODULE" send success "Compression Complete" "Compressed $total_files files using $format" "{\"job_id\": $job_id, \"files\": $total_files, \"format\": \"$format\", \"duration\": $duration}"
    
    echo "Compression completed: $total_files files processed"
}

# Compress a single file
compress_single_file() {
    local file="$1"
    local compress_cmd="$2"
    local extension="$3"
    local format="$4"
    local level="$5"
    local keep_original="$6"
    local verify="$7"
    
    local original_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    local compressed_file="${file}${extension}"
    
    # Skip if already compressed
    if [[ "$file" =~ \.(gz|bz2|xz|lz4|zst)$ ]]; then
        log "Skipping already compressed file: $file"
        return 0
    fi
    
    # Skip if file is too small
    if [ "$original_size" -lt 1024 ]; then
        log "Skipping small file: $file (${original_size} bytes)"
        return 0
    fi
    
    local start_time=$(date +%s)
    
    # Compress the file
    if eval "$compress_cmd" "$file" 2>/dev/null; then
        local end_time=$(date +%s)
        local compress_time=$((end_time - start_time))
        local compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || echo 0)
        local ratio=0
        
        if [ "$original_size" -gt 0 ]; then
            ratio=$(echo "scale=2; (1 - $compressed_size / $original_size) * 100" | bc -l)
        fi
        
        # Verify compression if requested
        local verify_result=""
        if [ "$verify" = "true" ]; then
            case "$format" in
                gzip) verify_result=$(gzip -t "$compressed_file" 2>&1) ;;
                bzip2) verify_result=$(bzip2 -t "$compressed_file" 2>&1) ;;
                xz) verify_result=$(xz -t "$compressed_file" 2>&1) ;;
                lz4) verify_result=$(lz4 -t "$compressed_file" 2>&1) ;;
                zstd) verify_result=$(zstd -t "$compressed_file" 2>&1) ;;
            esac
        fi
        
        # Calculate checksum
        local checksum=$(sha256sum "$compressed_file" | cut -d' ' -f1)
        
        # Store in database
        sqlite3 "$DB_PATH" "INSERT INTO compressed_files (original_path, compressed_path, compression_format, compression_level, original_size, compressed_size, compression_ratio, compression_time, checksum) VALUES ('$file', '$compressed_file', '$format', $level, $original_size, $compressed_size, $ratio, $compress_time, '$checksum');"
        
        # Remove original if requested
        if [ "$keep_original" = "false" ]; then
            rm -f "$file"
        fi
        
        log "Compressed: $file -> $compressed_file (${ratio}% reduction, ${compress_time}s)"
        
        # Send notification for large files
        if [ "$original_size" -gt 104857600 ]; then  # 100MB
            "$NOTIFY_MODULE" send info "Large File Compressed" "Compressed large file: $file" "{\"file\": \"$file\", \"original_size\": $original_size, \"compressed_size\": $compressed_size, \"ratio\": $ratio}"
        fi
    else
        log_error "Failed to compress: $file"
        return 1
    fi
}

# Decompress files
decompress_files() {
    local compressed_file="$1"
    local target_path="${2:-}"
    
    if [ -z "$compressed_file" ]; then
        log_error "Compressed file path is required"
        return 1
    fi
    
    if [ ! -f "$compressed_file" ]; then
        log_error "Compressed file does not exist: $compressed_file"
        return 1
    fi
    
    # Determine decompression command based on file extension
    local decompress_cmd=""
    local original_name=""
    
    case "$compressed_file" in
        *.gz)
            decompress_cmd="gunzip"
            original_name="${compressed_file%.gz}"
            ;;
        *.bz2)
            decompress_cmd="bunzip2"
            original_name="${compressed_file%.bz2}"
            ;;
        *.xz)
            decompress_cmd="unxz"
            original_name="${compressed_file%.xz}"
            ;;
        *.lz4)
            decompress_cmd="lz4 -d"
            original_name="${compressed_file%.lz4}"
            ;;
        *.zst)
            decompress_cmd="zstd -d"
            original_name="${compressed_file%.zst}"
            ;;
        *)
            log_error "Unknown compression format: $compressed_file"
            return 1
            ;;
    esac
    
    # Set target path
    if [ -n "$target_path" ]; then
        original_name="$target_path"
    fi
    
    log "Decompressing: $compressed_file -> $original_name"
    
    # Decompress the file
    if eval "$decompress_cmd" "$compressed_file" 2>/dev/null; then
        log "Decompressed: $compressed_file -> $original_name"
        echo "Decompressed: $compressed_file -> $original_name"
        
        # Update database
        sqlite3 "$DB_PATH" "UPDATE compressed_files SET compressed_path = NULL WHERE compressed_path = '$compressed_file';"
        
        return 0
    else
        log_error "Failed to decompress: $compressed_file"
        return 1
    fi
}

# Optimize existing compressed files
optimize_compressed_files() {
    local path="$1"
    local format="${2:-auto}"
    
    if [ -z "$path" ]; then
        log_error "Path is required"
        return 1
    fi
    
    if [ ! -e "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    log "Optimizing compressed files in: $path"
    
    # Find compressed files
    find "$path" -type f \( -name "*.gz" -o -name "*.bz2" -o -name "*.xz" -o -name "*.lz4" -o -name "*.zst" \) | while read -r file; do
        optimize_single_file "$file" "$format"
    done
    
    echo "Optimization completed"
}

# Optimize a single compressed file
optimize_single_file() {
    local file="$1"
    local target_format="$2"
    
    # Get current format and size
    local current_format=""
    local current_size=$(stat -c%s "$file")
    
    case "$file" in
        *.gz) current_format="gzip" ;;
        *.bz2) current_format="bzip2" ;;
        *.xz) current_format="xz" ;;
        *.lz4) current_format="lz4" ;;
        *.zst) current_format="zstd" ;;
    esac
    
    # Decompress to temporary file
    local temp_file=$(mktemp)
    decompress_files "$file" "$temp_file"
    
    if [ $? -eq 0 ]; then
        # Recompress with optimal format
        local optimal_format="$current_format"
        if [ "$target_format" = "auto" ]; then
            optimal_format=$(determine_optimal_format "$temp_file")
        else
            optimal_format="$target_format"
        fi
        
        if [ "$optimal_format" != "$current_format" ]; then
            log "Recompressing $file with $optimal_format (was $current_format)"
            compress_files "$temp_file" "$optimal_format" 9 false true 1
            local new_size=$(stat -c%s "${temp_file}.${optimal_format}" 2>/dev/null || echo 0)
            local savings=$((current_size - new_size))
            
            if [ "$savings" -gt 0 ]; then
                log "Optimization saved ${savings} bytes (${current_size} -> ${new_size})"
            fi
        fi
        
        # Clean up
        rm -f "$temp_file"
    fi
}

# Determine optimal compression format for a file
determine_optimal_format() {
    local file="$1"
    local file_size=$(stat -c%s "$file")
    
    # Simple heuristic based on file size and type
    if [ "$file_size" -lt 1048576 ]; then  # < 1MB
        echo "gzip"  # Fast compression for small files
    elif [ "$file_size" -lt 104857600 ]; then  # < 100MB
        echo "zstd"  # Good balance for medium files
    else
        echo "xz"    # Best compression for large files
    fi
}

# Analyze compression efficiency
analyze_compression() {
    local path="$1"
    
    if [ -z "$path" ]; then
        log_error "Path is required"
        return 1
    fi
    
    if [ ! -e "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    echo "Compression Analysis: $path"
    echo "========================"
    
    # Get statistics from database
    sqlite3 "$DB_PATH" "SELECT 
        compression_format,
        COUNT(*) as file_count,
        SUM(original_size) as total_original,
        SUM(compressed_size) as total_compressed,
        AVG(compression_ratio) as avg_ratio,
        AVG(compression_time) as avg_time
    FROM compressed_files 
    WHERE original_path LIKE '$path%'
    GROUP BY compression_format
    ORDER BY avg_ratio DESC;" | while IFS='|' read -r format count original compressed ratio time; do
        if [ -n "$format" ]; then
            local saved=$((original - compressed))
            local saved_mb=$(echo "scale=1; $saved / 1048576" | bc -l)
            echo "$format: $count files, ${saved_mb}MB saved, ${ratio}% avg ratio, ${time}s avg time"
        fi
    done
    
    echo ""
    echo "Recent Compressions:"
    echo "==================="
    sqlite3 "$DB_PATH" "SELECT original_path, compression_format, compression_ratio, compression_time FROM compressed_files WHERE original_path LIKE '$path%' ORDER BY created_at DESC LIMIT 10;" | while IFS='|' read -r path format ratio time; do
        echo "$format: ${ratio}% ratio, ${time}s - $path"
    done
}

# List compressed files
list_compressed_files() {
    local path="${1:-}"
    
    local where_clause=""
    if [ -n "$path" ]; then
        where_clause="WHERE original_path LIKE '$path%'"
    fi
    
    echo "Compressed Files:"
    echo "================="
    
    sqlite3 "$DB_PATH" "SELECT original_path, compressed_path, compression_format, original_size, compressed_size, compression_ratio, created_at FROM compressed_files $where_clause ORDER BY created_at DESC;" | while IFS='|' read -r original compressed format orig_size comp_size ratio created; do
        local saved=$((orig_size - comp_size))
        local saved_mb=$(echo "scale=1; $saved / 1048576" | bc -l)
        local orig_mb=$(echo "scale=1; $orig_size / 1048576" | bc -l)
        echo "[$created] $format: ${ratio}% ratio (${orig_mb}MB -> ${saved_mb}MB saved) - $original"
    done
}

# Run compression benchmarks
run_benchmarks() {
    local test_format="${1:-}"
    
    echo "Compression Benchmarks"
    echo "====================="
    
    # Create test file if needed
    local test_file="/tmp/compress_benchmark.dat"
    if [ ! -f "$test_file" ] || [ $(stat -c%s "$test_file") -lt 10485760 ]; then  # 10MB
        echo "Creating test file..."
        dd if=/dev/urandom of="$test_file" bs=1M count=10 2>/dev/null
    fi
    
    local test_size=$(stat -c%s "$test_file")
    local formats=("gzip" "bzip2" "xz" "lz4" "zstd")
    
    if [ -n "$test_format" ]; then
        formats=("$test_format")
    fi
    
    for format in "${formats[@]}"; do
        if command -v "$format" >/dev/null 2>&1 || command -v "gzip" >/dev/null 2>&1; then
            benchmark_format "$format" "$test_file" "$test_size"
        fi
    done
    
    echo ""
    echo "Benchmark completed. Results stored in database."
}

# Benchmark a specific format
benchmark_format() {
    local format="$1"
    local test_file="$2"
    local test_size="$3"
    
    echo "Testing $format..."
    
    local compress_cmd=""
    local extension=""
    
    case "$format" in
        gzip)
            compress_cmd="gzip -9"
            extension=".gz"
            ;;
        bzip2)
            compress_cmd="bzip2 -9"
            extension=".bz2"
            ;;
        xz)
            compress_cmd="xz -9"
            extension=".xz"
            ;;
        lz4)
            compress_cmd="lz4 -9"
            extension=".lz4"
            ;;
        zstd)
            compress_cmd="zstd -9"
            extension=".zst"
            ;;
    esac
    
    if [ -n "$compress_cmd" ]; then
        local compressed_file="${test_file}${extension}"
        
        # Compression test
        local compress_start=$(date +%s.%N)
        eval "$compress_cmd" "$test_file" >/dev/null 2>&1
        local compress_end=$(date +%s.%N)
        local compress_time=$(echo "$compress_end - $compress_start" | bc -l)
        
        # Decompression test
        local decompress_start=$(date +%s.%N)
        case "$format" in
            gzip) gunzip "$compressed_file" >/dev/null 2>&1 ;;
            bzip2) bunzip2 "$compressed_file" >/dev/null 2>&1 ;;
            xz) unxz "$compressed_file" >/dev/null 2>&1 ;;
            lz4) lz4 -d "$compressed_file" >/dev/null 2>&1 ;;
            zstd) zstd -d "$compressed_file" >/dev/null 2>&1 ;;
        esac
        local decompress_end=$(date +%s.%N)
        local decompress_time=$(echo "$decompress_end - $decompress_start" | bc -l)
        
        # Calculate metrics
        local compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || echo 0)
        local ratio=$(echo "scale=2; (1 - $compressed_size / $test_size) * 100" | bc -l)
        local speed=$(echo "scale=2; $test_size / 1048576 / $compress_time" | bc -l)
        
        # Store in database
        sqlite3 "$DB_PATH" "INSERT INTO compression_benchmarks (format, level, test_file, original_size, compressed_size, compression_time, decompression_time, compression_ratio, speed_mbps) VALUES ('$format', 9, '$test_file', $test_size, $compressed_size, $compress_time, $decompress_time, $ratio, $speed);"
        
        echo "  $format: ${ratio}% ratio, ${speed} MB/s, ${compress_time}s compress, ${decompress_time}s decompress"
    fi
}

# Clean up temporary files
cleanup_temp_files() {
    local path="${1:-/tmp}"
    
    log "Cleaning up temporary compression files in: $path"
    
    # Remove temporary files
    find "$path" -name "*.tmp" -o -name "*.temp" -o -name "compress_*" | while read -r file; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log "Removed temporary file: $file"
        fi
    done
    
    echo "Cleanup completed"
}

# Main function
main() {
    case "${1:-}" in
        compress)
            compress_files "${2:-}" "${3:-gzip}" "${4:-6}" "${5:-false}" "${6:-false}" "${7:-1}"
            ;;
        decompress)
            decompress_files "${2:-}" "${3:-}"
            ;;
        optimize)
            optimize_compressed_files "${2:-}" "${3:-auto}"
            ;;
        analyze)
            analyze_compression "${2:-}"
            ;;
        list)
            list_compressed_files "${2:-}"
            ;;
        benchmark)
            run_benchmarks "${2:-}"
            ;;
        cleanup)
            cleanup_temp_files "${2:-/tmp}"
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

# Only call main if this script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 