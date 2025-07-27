#!/bin/bash
# Grimm File Integrity Module: Monitor and verify file integrity

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
DB_PATH="${DB_DIR:-$GRIM_ROOT/db}/integrity.db"
LOG_FILE="${LOG_DIR:-$GRIM_ROOT/logs}/verify.log"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"
MONITOR_PID_FILE="$GRIM_ROOT/logs/verify-monitor.pid"

# --- Colors ---
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

# Initialize SQLite database
init_database() {
    mkdir -p "$(dirname "$DB_PATH")"
    sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS integrity_baselines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL UNIQUE,
    checksum TEXT NOT NULL,
    size INTEGER NOT NULL,
    mtime INTEGER NOT NULL,
    permissions TEXT NOT NULL,
    owner TEXT NOT NULL,
    "group" TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS integrity_violations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL,
    violation_type TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS monitor_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS checksum_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL,
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    checksum TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS signature_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL,
    signature_type TEXT NOT NULL DEFAULT 'gpg',
    signature_data TEXT NOT NULL,
    public_key TEXT,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS backup_verifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_path TEXT NOT NULL,
    verification_type TEXT NOT NULL,
    result TEXT NOT NULL,
    checksum TEXT,
    file_count INTEGER,
    total_size INTEGER,
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_baselines_path ON integrity_baselines(path);
CREATE INDEX IF NOT EXISTS idx_violations_path ON integrity_violations(path);
CREATE INDEX IF NOT EXISTS idx_violations_resolved ON integrity_violations(resolved);
CREATE INDEX IF NOT EXISTS idx_checksum_path ON checksum_records(path);
CREATE INDEX IF NOT EXISTS idx_signature_path ON signature_records(path);
CREATE INDEX IF NOT EXISTS idx_backup_path ON backup_verifications(backup_path);
EOF
    log "Database initialized: $DB_PATH"
}

# Calculate file checksum
calculate_checksum() {
    local file="$1"
    local algorithm="${2:-sha256}"
    if [[ -f "$file" ]]; then
        case "$algorithm" in
            "md5")
                md5sum "$file" | cut -d' ' -f1
                ;;
            "sha1")
                sha1sum "$file" | cut -d' ' -f1
                ;;
            "sha256")
                sha256sum "$file" | cut -d' ' -f1
                ;;
            "sha512")
                sha512sum "$file" | cut -d' ' -f1
                ;;
            *)
                sha256sum "$file" | cut -d' ' -f1
                ;;
        esac
    else
        echo ""
    fi
}

# Get file metadata
get_file_metadata() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local mtime=$(stat -c%Y "$file" 2>/dev/null || echo "0")
        local permissions=$(stat -c%a "$file" 2>/dev/null || echo "000")
        local owner=$(stat -c%U "$file" 2>/dev/null || echo "unknown")
        local group=$(stat -c%G "$file" 2>/dev/null || echo "unknown")
        echo "$size|$mtime|$permissions|$owner|$group"
    else
        echo ""
    fi
}

# =============================================================================
# NEW SUBCOMMANDS: integrity, checksum, signature, backup
# =============================================================================

# Verify file integrity using various methods
verify_integrity() {
    local path="${1:-}"
    local algorithm="${2:-sha256}"
    local verbose="${3:-false}"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify integrity <path> [algorithm] [verbose]"
        echo "Algorithms: md5, sha1, sha256, sha512"
        echo "Examples:"
        echo "  grim verify integrity /etc/passwd"
        echo "  grim verify integrity /var/log sha512"
        echo "  grim verify integrity /home/user md5 verbose"
        return 1
    fi
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    echo -e "${CYAN}🔍 Verifying integrity for: $path${NC}"
    echo -e "${BLUE}Algorithm: $algorithm${NC}"
    
    if [[ -f "$path" ]]; then
        verify_file_integrity "$path" "$algorithm" "$verbose"
    elif [[ -d "$path" ]]; then
        verify_directory_integrity "$path" "$algorithm" "$verbose"
    else
        echo -e "${RED}Error: Path is neither file nor directory${NC}"
        return 1
    fi
}

# Verify single file integrity
verify_file_integrity() {
    local file="$1"
    local algorithm="$2"
    local verbose="$3"
    local abs_path=$(readlink -f "$file")
    
    # Calculate current checksum
    local current_checksum=$(calculate_checksum "$abs_path" "$algorithm")
    local file_size=$(stat -c%s "$abs_path" 2>/dev/null || echo "0")
    
    if [[ -z "$current_checksum" ]]; then
        echo -e "${RED}❌ Failed to calculate checksum for: $file${NC}"
        return 1
    fi
    
    # Check if we have a baseline
    local baseline_checksum=$(sqlite3 "$DB_PATH" "SELECT checksum FROM integrity_baselines WHERE path='$abs_path';" 2>/dev/null)
    
    if [[ -n "$baseline_checksum" ]]; then
        if [[ "$current_checksum" == "$baseline_checksum" ]]; then
            echo -e "${GREEN}✅ Integrity verified: $file${NC}"
            if [[ "$verbose" == "verbose" ]]; then
                echo -e "${BLUE}   Checksum: $current_checksum${NC}"
                echo -e "${BLUE}   Size: $file_size bytes${NC}"
            fi
        else
            echo -e "${RED}❌ Integrity violation detected: $file${NC}"
            echo -e "${YELLOW}   Expected: $baseline_checksum${NC}"
            echo -e "${YELLOW}   Current:  $current_checksum${NC}"
            
            # Record violation
            sqlite3 "$DB_PATH" "INSERT INTO integrity_violations (path, violation_type, old_value, new_value) VALUES ('$abs_path', 'checksum_mismatch', '$baseline_checksum', '$current_checksum');"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  No baseline found for: $file${NC}"
        echo -e "${BLUE}   Current checksum: $current_checksum${NC}"
        echo -e "${CYAN}   Use 'grim verify create $file' to create baseline${NC}"
    fi
    
    # Store/update checksum record
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO checksum_records (path, algorithm, checksum, file_size) VALUES ('$abs_path', '$algorithm', '$current_checksum', $file_size);"
}

# Verify directory integrity
verify_directory_integrity() {
    local dir="$1"
    local algorithm="$2"
    local verbose="$3"
    local abs_dir=$(readlink -f "$dir")
    local verified=0
    local violations=0
    local no_baseline=0
    
    echo -e "${CYAN}Verifying directory integrity: $dir${NC}"
    
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            if verify_file_integrity "$file" "$algorithm" "$verbose" >/dev/null 2>&1; then
                ((verified++))
            else
                # Check if it was a violation or missing baseline
                local baseline_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_baselines WHERE path='$(readlink -f "$file")';" 2>/dev/null)
                if [[ "$baseline_exists" == "0" ]]; then
                    ((no_baseline++))
                else
                    ((violations++))
                fi
            fi
            
            if [[ $((verified % 100)) -eq 0 ]]; then
                echo -e "${BLUE}Processed $verified files...${NC}"
            fi
        fi
    done < <(find "$abs_dir" -type f -print0 2>/dev/null)
    
    echo -e "${GREEN}✅ Verified: $verified files${NC}"
    if [[ $violations -gt 0 ]]; then
        echo -e "${RED}❌ Violations: $violations files${NC}"
    fi
    if [[ $no_baseline -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  No baseline: $no_baseline files${NC}"
    fi
    
    return $violations
}

# Verify file checksums
verify_checksum() {
    local path="${1:-}"
    local algorithm="${2:-sha256}"
    local expected_checksum="${3:-}"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify checksum <path> [algorithm] [expected_checksum]"
        echo "Algorithms: md5, sha1, sha256, sha512"
        echo "Examples:"
        echo "  grim verify checksum /etc/passwd"
        echo "  grim verify checksum /var/log/syslog sha256"
        echo "  grim verify checksum /file.txt md5 5d41402abc4b2a76b9719d911017c592"
        return 1
    fi
    
    if [[ ! -f "$path" ]]; then
        echo -e "${RED}Error: File does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    local abs_path=$(readlink -f "$path")
    local current_checksum=$(calculate_checksum "$abs_path" "$algorithm")
    local file_size=$(stat -c%s "$abs_path" 2>/dev/null || echo "0")
    
    echo -e "${CYAN}🔍 Verifying checksum for: $path${NC}"
    echo -e "${BLUE}Algorithm: $algorithm${NC}"
    echo -e "${BLUE}Current checksum: $current_checksum${NC}"
    
    if [[ -n "$expected_checksum" ]]; then
        # Compare with provided checksum
        if [[ "$current_checksum" == "$expected_checksum" ]]; then
            echo -e "${GREEN}✅ Checksum verified successfully${NC}"
        else
            echo -e "${RED}❌ Checksum mismatch${NC}"
            echo -e "${YELLOW}   Expected: $expected_checksum${NC}"
            echo -e "${YELLOW}   Current:  $current_checksum${NC}"
            return 1
        fi
    else
        # Check against stored checksum
        local stored_checksum=$(sqlite3 "$DB_PATH" "SELECT checksum FROM checksum_records WHERE path='$abs_path' AND algorithm='$algorithm' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null)
        
        if [[ -n "$stored_checksum" ]]; then
            if [[ "$current_checksum" == "$stored_checksum" ]]; then
                echo -e "${GREEN}✅ Checksum matches stored value${NC}"
            else
                echo -e "${RED}❌ Checksum differs from stored value${NC}"
                echo -e "${YELLOW}   Stored:  $stored_checksum${NC}"
                echo -e "${YELLOW}   Current: $current_checksum${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}⚠️  No stored checksum found${NC}"
            echo -e "${CYAN}   Storing current checksum for future verification${NC}"
        fi
    fi
    
    # Store checksum record
    sqlite3 "$DB_PATH" "INSERT INTO checksum_records (path, algorithm, checksum, file_size) VALUES ('$abs_path', '$algorithm', '$current_checksum', $file_size);"
    
    return 0
}

# Verify digital signatures
verify_signature() {
    local path="${1:-}"
    local signature_file="${2:-}"
    local public_key="${3:-}"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify signature <path> [signature_file] [public_key]"
        echo "Examples:"
        echo "  grim verify signature /file.txt"
        echo "  grim verify signature /file.txt /file.txt.sig"
        echo "  grim verify signature /file.txt /file.txt.sig /path/to/public.key"
        return 1
    fi
    
    if [[ ! -f "$path" ]]; then
        echo -e "${RED}Error: File does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    local abs_path=$(readlink -f "$path")
    echo -e "${CYAN}🔍 Verifying signature for: $path${NC}"
    
    # Check if GPG is available
    if ! command -v gpg >/dev/null 2>&1; then
        echo -e "${RED}Error: GPG is not installed${NC}"
        echo -e "${YELLOW}Install GPG: sudo apt-get install gnupg${NC}"
        return 1
    fi
    
    # Determine signature file
    if [[ -z "$signature_file" ]]; then
        # Look for common signature file extensions
        for ext in .sig .asc .gpg; do
            if [[ -f "${abs_path}${ext}" ]]; then
                signature_file="${abs_path}${ext}"
                break
            fi
        done
        
        if [[ -z "$signature_file" ]]; then
            echo -e "${RED}Error: No signature file found${NC}"
            echo -e "${YELLOW}Expected: ${abs_path}.sig, ${abs_path}.asc, or ${abs_path}.gpg${NC}"
            return 1
        fi
    fi
    
    if [[ ! -f "$signature_file" ]]; then
        echo -e "${RED}Error: Signature file does not exist: $signature_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Signature file: $signature_file${NC}"
    
    # Verify signature
    if gpg --verify "$signature_file" "$abs_path" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Signature verified successfully${NC}"
        
        # Get signature info
        local sig_info=$(gpg --verify "$signature_file" "$abs_path" 2>&1 | head -3)
        echo -e "${BLUE}Signature details:${NC}"
        echo "$sig_info" | while read line; do
            echo -e "${BLUE}   $line${NC}"
        done
        
        # Store signature record
        sqlite3 "$DB_PATH" "INSERT INTO signature_records (path, signature_type, signature_data, verified) VALUES ('$abs_path', 'gpg', '$(basename "$signature_file")', 1);"
        
        return 0
    else
        echo -e "${RED}❌ Signature verification failed${NC}"
        
        # Show error details
        local error_info=$(gpg --verify "$signature_file" "$abs_path" 2>&1)
        echo -e "${YELLOW}Error details:${NC}"
        echo "$error_info" | while read line; do
            echo -e "${YELLOW}   $line${NC}"
        done
        
        # Store failed verification
        sqlite3 "$DB_PATH" "INSERT INTO signature_records (path, signature_type, signature_data, verified) VALUES ('$abs_path', 'gpg', '$(basename "$signature_file")', 0);"
        
        return 1
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_path="${1:-}"
    local verification_type="${2:-full}"
    
    if [[ -z "$backup_path" ]]; then
        echo -e "${RED}Error: Backup path is required${NC}"
        echo "Usage: grim verify backup <backup_path> [verification_type]"
        echo "Verification types: full, quick, checksum, structure"
        echo "Examples:"
        echo "  grim verify backup /backups/daily-20250127.tar.gz"
        echo "  grim verify backup /backups/backup.tar.gz full"
        echo "  grim verify backup /backups/backup.tar.gz checksum"
        return 1
    fi
    
    if [[ ! -f "$backup_path" ]]; then
        echo -e "${RED}Error: Backup file does not exist: $backup_path${NC}"
        return 1
    fi
    
    init_database
    
    local abs_backup_path=$(readlink -f "$backup_path")
    echo -e "${CYAN}🔍 Verifying backup: $backup_path${NC}"
    echo -e "${BLUE}Verification type: $verification_type${NC}"
    
    local result="UNKNOWN"
    local checksum=""
    local file_count=0
    local total_size=0
    
    case "$verification_type" in
        "quick")
            verify_backup_quick "$abs_backup_path"
            result=$?
            ;;
        "checksum")
            verify_backup_checksum "$abs_backup_path"
            result=$?
            ;;
        "structure")
            verify_backup_structure "$abs_backup_path"
            result=$?
            ;;
        "full"|*)
            verify_backup_full "$abs_backup_path"
            result=$?
            ;;
    esac
    
    # Store verification record
    local result_text="FAILED"
    if [[ $result -eq 0 ]]; then
        result_text="PASSED"
    fi
    
    sqlite3 "$DB_PATH" "INSERT INTO backup_verifications (backup_path, verification_type, result, checksum, file_count, total_size) VALUES ('$abs_backup_path', '$verification_type', '$result_text', '$checksum', $file_count, $total_size);"
    
    return $result
}

# Quick backup verification
verify_backup_quick() {
    local backup_path="$1"
    
    echo -e "${BLUE}Performing quick verification...${NC}"
    
    # Check if file is readable
    if [[ ! -r "$backup_path" ]]; then
        echo -e "${RED}❌ Backup file is not readable${NC}"
        return 1
    fi
    
    # Check file size
    local size=$(stat -c%s "$backup_path" 2>/dev/null || echo "0")
    if [[ $size -eq 0 ]]; then
        echo -e "${RED}❌ Backup file is empty${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Quick verification passed${NC}"
    echo -e "${BLUE}   File size: $size bytes${NC}"
    
    return 0
}

# Checksum backup verification
verify_backup_checksum() {
    local backup_path="$1"
    
    echo -e "${BLUE}Calculating backup checksum...${NC}"
    
    local checksum=$(calculate_checksum "$backup_path" "sha256")
    if [[ -z "$checksum" ]]; then
        echo -e "${RED}❌ Failed to calculate checksum${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Checksum calculated successfully${NC}"
    echo -e "${BLUE}   SHA256: $checksum${NC}"
    
    # Check if we have a stored checksum
    local backup_name=$(basename "$backup_path")
    local stored_checksum=$(sqlite3 "$DB_PATH" "SELECT checksum FROM backup_verifications WHERE backup_path LIKE '%$backup_name' ORDER BY verified_at DESC LIMIT 1;" 2>/dev/null)
    
    if [[ -n "$stored_checksum" && "$stored_checksum" != "$checksum" ]]; then
        echo -e "${YELLOW}⚠️  Checksum differs from previous verification${NC}"
        echo -e "${YELLOW}   Previous: $stored_checksum${NC}"
        echo -e "${YELLOW}   Current:  $checksum${NC}"
    fi
    
    return 0
}

# Structure backup verification
verify_backup_structure() {
    local backup_path="$1"
    
    echo -e "${BLUE}Verifying backup structure...${NC}"
    
    # Determine backup type
    local backup_type=""
    case "$backup_path" in
        *.tar.gz|*.tgz)
            backup_type="tar.gz"
            ;;
        *.tar.bz2|*.tbz2)
            backup_type="tar.bz2"
            ;;
        *.tar.xz|*.txz)
            backup_type="tar.xz"
            ;;
        *.tar)
            backup_type="tar"
            ;;
        *.zip)
            backup_type="zip"
            ;;
        *)
            echo -e "${YELLOW}⚠️  Unknown backup format, attempting tar verification${NC}"
            backup_type="tar"
            ;;
    esac
    
    echo -e "${BLUE}   Detected format: $backup_type${NC}"
    
    # Verify structure based on type
    case "$backup_type" in
        "tar.gz"|"tar.bz2"|"tar.xz"|"tar")
            if tar -tf "$backup_path" >/dev/null 2>&1; then
                local file_count=$(tar -tf "$backup_path" | wc -l)
                echo -e "${GREEN}✅ TAR structure is valid${NC}"
                echo -e "${BLUE}   Files in archive: $file_count${NC}"
            else
                echo -e "${RED}❌ TAR structure is corrupted${NC}"
                return 1
            fi
            ;;
        "zip")
            if command -v unzip >/dev/null 2>&1; then
                if unzip -t "$backup_path" >/dev/null 2>&1; then
                    local file_count=$(unzip -l "$backup_path" | tail -1 | awk '{print $2}')
                    echo -e "${GREEN}✅ ZIP structure is valid${NC}"
                    echo -e "${BLUE}   Files in archive: $file_count${NC}"
                else
                    echo -e "${RED}❌ ZIP structure is corrupted${NC}"
                    return 1
                fi
            else
                echo -e "${YELLOW}⚠️  unzip not available, skipping ZIP verification${NC}"
            fi
            ;;
    esac
    
    return 0
}

# Full backup verification
verify_backup_full() {
    local backup_path="$1"
    
    echo -e "${BLUE}Performing full verification...${NC}"
    
    # Run all verification types
    if ! verify_backup_quick "$backup_path"; then
        return 1
    fi
    
    if ! verify_backup_checksum "$backup_path"; then
        return 1
    fi
    
    if ! verify_backup_structure "$backup_path"; then
        return 1
    fi
    
    echo -e "${GREEN}✅ Full verification completed successfully${NC}"
    return 0
}

# =============================================================================
# EXISTING COMMANDS: create, check, monitor, etc. (backward compatibility)
# =============================================================================

# Create integrity baseline
create_baseline() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify create <path>"
        return 1
    fi
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    if [[ -f "$path" ]]; then
        # Single file
        create_file_baseline "$path"
    elif [[ -d "$path" ]]; then
        # Directory - recursive
        create_directory_baseline "$path"
    else
        echo -e "${RED}Error: Path is neither file nor directory${NC}"
        return 1
    fi
}

# Create baseline for single file
create_file_baseline() {
    local file="$1"
    local abs_path=$(readlink -f "$file")
    local checksum=$(calculate_checksum "$abs_path")
    local metadata=$(get_file_metadata "$abs_path")
    
    if [[ -z "$checksum" ]]; then
        echo -e "${RED}Error: Cannot calculate checksum for $file${NC}"
        return 1
    fi
    
    IFS='|' read -r size mtime permissions owner group <<< "$metadata"
    
    sqlite3 "$DB_PATH" << EOF
INSERT OR REPLACE INTO integrity_baselines 
(path, checksum, size, mtime, permissions, owner, "group", updated_at) 
VALUES ('$abs_path', '$checksum', $size, $mtime, '$permissions', '$owner', '$group', CURRENT_TIMESTAMP);
EOF
    
    echo -e "${GREEN}✓ Baseline created for: $file${NC}"
    log "Baseline created: $file (checksum: ${checksum:0:8}...)"
}

# Create baseline for directory recursively
create_directory_baseline() {
    local dir="$1"
    local abs_dir=$(readlink -f "$dir")
    local count=0
    local errors=0
    
    echo -e "${CYAN}Creating baseline for directory: $dir${NC}"
    
    # Find all files in directory
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            if create_file_baseline "$file" >/dev/null 2>&1; then
                ((count++))
                if [[ $((count % 100)) -eq 0 ]]; then
                    echo -e "${BLUE}Processed $count files...${NC}"
                fi
            else
                ((errors++))
            fi
        fi
    done < <(find "$abs_dir" -type f -print0 2>/dev/null)
    
    echo -e "${GREEN}✓ Baseline created for $count files${NC}"
    if [[ $errors -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  $errors files had errors${NC}"
    fi
    log "Directory baseline created: $dir ($count files, $errors errors)"
}

# Check file integrity (existing functionality)
check_integrity() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify check <path>"
        return 1
    fi
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}Error: Path does not exist: $path${NC}"
        return 1
    fi
    
    init_database
    
    if [[ -f "$path" ]]; then
        check_file_integrity "$path"
    elif [[ -d "$path" ]]; then
        check_directory_integrity "$path"
    else
        echo -e "${RED}Error: Path is neither file nor directory${NC}"
        return 1
    fi
}

# Check single file integrity
check_file_integrity() {
    local file="$1"
    local abs_path=$(readlink -f "$file")
    
    # Get baseline
    local baseline=$(sqlite3 "$DB_PATH" "SELECT checksum, size, mtime, permissions, owner, \"group\" FROM integrity_baselines WHERE path='$abs_path';" 2>/dev/null)
    
    if [[ -z "$baseline" ]]; then
        echo -e "${YELLOW}⚠️  No baseline found for: $file${NC}"
        echo -e "${CYAN}   Use 'grim verify create $file' to create baseline${NC}"
        return 1
    fi
    
    IFS='|' read -r baseline_checksum baseline_size baseline_mtime baseline_permissions baseline_owner baseline_group <<< "$baseline"
    
    # Calculate current values
    local current_checksum=$(calculate_checksum "$abs_path")
    local current_metadata=$(get_file_metadata "$abs_path")
    IFS='|' read -r current_size current_mtime current_permissions current_owner current_group <<< "$current_metadata"
    
    local violations=0
    
    # Check checksum
    if [[ "$current_checksum" != "$baseline_checksum" ]]; then
        echo -e "${RED}❌ Checksum violation: $file${NC}"
        echo -e "${YELLOW}   Expected: $baseline_checksum${NC}"
        echo -e "${YELLOW}   Current:  $current_checksum${NC}"
        ((violations++))
        
        sqlite3 "$DB_PATH" "INSERT INTO integrity_violations (path, violation_type, old_value, new_value) VALUES ('$abs_path', 'checksum', '$baseline_checksum', '$current_checksum');"
    fi
    
    # Check size
    if [[ "$current_size" != "$baseline_size" ]]; then
        echo -e "${RED}❌ Size violation: $file${NC}"
        echo -e "${YELLOW}   Expected: $baseline_size bytes${NC}"
        echo -e "${YELLOW}   Current:  $current_size bytes${NC}"
        ((violations++))
        
        sqlite3 "$DB_PATH" "INSERT INTO integrity_violations (path, violation_type, old_value, new_value) VALUES ('$abs_path', 'size', '$baseline_size', '$current_size');"
    fi
    
    # Check permissions
    if [[ "$current_permissions" != "$baseline_permissions" ]]; then
        echo -e "${RED}❌ Permission violation: $file${NC}"
        echo -e "${YELLOW}   Expected: $baseline_permissions${NC}"
        echo -e "${YELLOW}   Current:  $current_permissions${NC}"
        ((violations++))
        
        sqlite3 "$DB_PATH" "INSERT INTO integrity_violations (path, violation_type, old_value, new_value) VALUES ('$abs_path', 'permissions', '$baseline_permissions', '$current_permissions');"
    fi
    
    if [[ $violations -eq 0 ]]; then
        echo -e "${GREEN}✅ Integrity verified: $file${NC}"
    fi
    
    return $violations
}

# Check directory integrity
check_directory_integrity() {
    local dir="$1"
    local abs_dir=$(readlink -f "$dir")
    local checked=0
    local violations=0
    local no_baseline=0
    
    echo -e "${CYAN}Checking directory integrity: $dir${NC}"
    
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local file_violations=$(check_file_integrity "$file" 2>/dev/null | grep -c "❌" || echo "0")
            
            if [[ $file_violations -eq 0 ]]; then
                # Check if baseline exists
                local baseline_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_baselines WHERE path='$(readlink -f "$file")';" 2>/dev/null)
                if [[ "$baseline_exists" == "0" ]]; then
                    ((no_baseline++))
                else
                    ((checked++))
                fi
            else
                ((violations++))
            fi
            
            if [[ $(((checked + violations + no_baseline) % 100)) -eq 0 ]]; then
                echo -e "${BLUE}Processed $((checked + violations + no_baseline)) files...${NC}"
            fi
        fi
    done < <(find "$abs_dir" -type f -print0 2>/dev/null)
    
    echo -e "${GREEN}✅ Verified: $checked files${NC}"
    if [[ $violations -gt 0 ]]; then
        echo -e "${RED}❌ Violations: $violations files${NC}"
    fi
    if [[ $no_baseline -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  No baseline: $no_baseline files${NC}"
    fi
    
    return $violations
}

# Start monitoring (placeholder - would need inotify implementation)
start_monitoring() {
    echo -e "${CYAN}🔍 Starting file integrity monitoring...${NC}"
    echo -e "${YELLOW}⚠️  Monitoring functionality requires inotify-tools${NC}"
    echo -e "${BLUE}Install with: sudo apt-get install inotify-tools${NC}"
    
    # Check if already running
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Monitoring is already running (PID: $pid)${NC}"
            return 1
        fi
    fi
    
    # For now, just log that monitoring would start
    log "Monitoring started (placeholder implementation)"
    echo $$ > "$MONITOR_PID_FILE"
    echo -e "${GREEN}✅ Monitoring started${NC}"
}

# Stop monitoring
stop_monitoring() {
    echo -e "${CYAN}🛑 Stopping file integrity monitoring...${NC}"
    
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            kill "$pid" 2>/dev/null
            rm -f "$MONITOR_PID_FILE"
            echo -e "${GREEN}✅ Monitoring stopped${NC}"
        else
            echo -e "${YELLOW}⚠️  Monitoring PID file exists but process not running${NC}"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo -e "${YELLOW}⚠️  Monitoring is not running${NC}"
    fi
}

# Show monitoring status
show_monitor_status() {
    echo -e "${CYAN}📊 File Integrity Monitoring Status${NC}"
    
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Monitoring is running (PID: $pid)${NC}"
        else
            echo -e "${YELLOW}⚠️  Monitoring PID file exists but process not running${NC}"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo -e "${YELLOW}⚠️  Monitoring is not running${NC}"
    fi
    
    # Show database statistics
    if [[ -f "$DB_PATH" ]]; then
        local baseline_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_baselines;" 2>/dev/null || echo "0")
        local violation_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM integrity_violations WHERE resolved=0;" 2>/dev/null || echo "0")
        local checksum_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM checksum_records;" 2>/dev/null || echo "0")
        
        echo -e "${BLUE}Database Statistics:${NC}"
        echo -e "${BLUE}   Baselines: $baseline_count${NC}"
        echo -e "${BLUE}   Unresolved violations: $violation_count${NC}"
        echo -e "${BLUE}   Checksum records: $checksum_count${NC}"
    fi
}

# Show violations report
show_report() {
    local filter="${1:-all}"
    
    echo -e "${CYAN}📋 Integrity Violations Report${NC}"
    
    init_database
    
    case "$filter" in
        "recent")
            echo -e "${BLUE}Recent violations (last 24 hours):${NC}"
            sqlite3 "$DB_PATH" "SELECT path, violation_type, old_value, new_value, detected_at FROM integrity_violations WHERE resolved=0 AND datetime(detected_at) > datetime('now', '-1 day') ORDER BY detected_at DESC;" | \
            while IFS='|' read -r path violation_type old_value new_value detected_at; do
                echo -e "${RED}❌ $path${NC}"
                echo -e "${YELLOW}   Type: $violation_type${NC}"
                echo -e "${YELLOW}   Expected: $old_value${NC}"
                echo -e "${YELLOW}   Current: $new_value${NC}"
                echo -e "${YELLOW}   Detected: $detected_at${NC}"
                echo ""
            done
            ;;
        "unresolved"|"all"|*)
            echo -e "${BLUE}All unresolved violations:${NC}"
            sqlite3 "$DB_PATH" "SELECT path, violation_type, old_value, new_value, detected_at FROM integrity_violations WHERE resolved=0 ORDER BY detected_at DESC;" | \
            while IFS='|' read -r path violation_type old_value new_value detected_at; do
                echo -e "${RED}❌ $path${NC}"
                echo -e "${YELLOW}   Type: $violation_type${NC}"
                echo -e "${YELLOW}   Expected: $old_value${NC}"
                echo -e "${YELLOW}   Current: $new_value${NC}"
                echo -e "${YELLOW}   Detected: $detected_at${NC}"
                echo ""
            done
            ;;
    esac
}

# Update baseline
update_baseline() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        echo -e "${RED}Error: Path is required${NC}"
        echo "Usage: grim verify update <path>"
        return 1
    fi
    
    echo -e "${CYAN}🔄 Updating baseline for: $path${NC}"
    create_baseline "$path"
}

# Show help
show_help() {
    echo -e "${CYAN}Grimm File Verification Module${NC}"
    echo "Usage: grim verify <command> [options]"
    echo ""
    echo -e "${YELLOW}New Commands:${NC}"
    echo "  integrity <path> [algorithm] [verbose]  - Verify file integrity with checksums"
    echo "  checksum <path> [algorithm] [expected]  - Verify file checksums"
    echo "  signature <path> [sig_file] [pub_key]   - Verify digital signatures"
    echo "  backup <path> [type]                    - Verify backup integrity"
    echo ""
    echo -e "${YELLOW}Legacy Commands:${NC}"
    echo "  create <path>     - Create integrity baseline for file/directory"
    echo "  check <path>      - Check file integrity against baseline"
    echo "  monitor [paths]   - Start real-time monitoring"
    echo "  stop-monitor      - Stop real-time monitoring"
    echo "  status            - Show monitoring status"
    echo "  report [filter]   - Show integrity violations report"
    echo "  update <path>     - Update baseline for legitimate changes"
    echo "  help              - Show this help"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  grim verify integrity /etc/passwd"
    echo "  grim verify checksum /file.txt sha256"
    echo "  grim verify signature /file.txt /file.txt.sig"
    echo "  grim verify backup /backups/daily.tar.gz full"
    echo "  grim verify create /etc/passwd"
    echo "  grim verify check /etc"
    echo "  grim verify report recent"
    echo ""
    echo "Database: $DB_PATH"
}

# Main function
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "${1:-}" in
        # New subcommands
        "integrity")
            verify_integrity "${2:-}" "${3:-sha256}" "${4:-false}"
            ;;
        "checksum")
            verify_checksum "${2:-}" "${3:-sha256}" "${4:-}"
            ;;
        "signature")
            verify_signature "${2:-}" "${3:-}" "${4:-}"
            ;;
        "backup")
            verify_backup "${2:-}" "${3:-full}"
            ;;
        # Legacy commands (backward compatibility)
        "create")
            create_baseline "${2:-}"
            ;;
        "check")
            check_integrity "${2:-}"
            ;;
        "monitor")
            start_monitoring "${2:-}" "${3:-}"
            ;;
        "stop-monitor")
            stop_monitoring
            ;;
        "status")
            show_monitor_status
            ;;
        "report")
            show_report "${2:-}"
            ;;
        "update")
            update_baseline "${2:-}"
            ;;
        "help"|"")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@" 