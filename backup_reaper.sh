#!/bin/bash

# Grimm Reaper Backup Script
# Backup /opt/reaper/ to /root/ excluding large dependency directories
# Created: $(date)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SOURCE_DIR="/opt/reaper"
TARGET_BASE="/root"
BACKUP_NAME="reaper_backup_$(date +%Y%m%d_%H%M%S)"
TARGET_DIR="$TARGET_BASE/$BACKUP_NAME"

# Create backup directory
log "Creating backup directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Define exclusion patterns
EXCLUDE_PATTERNS=(
    # Dependency directories (main targets)
    "vendor/"
    "node_modules/"
    "venv/"
    "grim_venv/"
    ".venv/"
    
    # Build artifacts and caches
    "dist/"
    "build/"
    "builds/"
    ".cache/"
    "cache/"
    "temp/"
    ".tmp/"
    
    # Version control
    ".git/"
    ".svn/"
    
    # Logs and temporary files
    "*.log"
    "*.tmp"
    "*.cache"
    "*.swp"
    "*.swo"
    "*~"
    
    # Python cache files
    "__pycache__/"
    "*.pyc"
    "*.pyo"
    "*.pyd"
    ".pytest_cache/"
    
    # IDE files
    ".vscode/"
    ".idea/"
    "*.code-workspace"
    
    # OS specific files
    ".DS_Store"
    "Thumbs.db"
    
    # Large data files that can be regenerated
    "*.db-journal"
    "*.sqlite-shm"
    "*.sqlite-wal"
)

# Build rsync exclude arguments
RSYNC_EXCLUDES=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    RSYNC_EXCLUDES+=(--exclude="$pattern")
done

# Show what we're excluding
log "Backup configuration:"
echo "  Source: $SOURCE_DIR"
echo "  Target: $TARGET_DIR"
echo "  Excluding directories/patterns:"
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    echo "    - $pattern"
done

# Calculate excluded directory sizes
log "Calculating space savings from exclusions..."
EXCLUDED_SIZE=0
while IFS= read -r -d '' dir; do
    if [[ -d "$dir" ]]; then
        size=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo 0)
        EXCLUDED_SIZE=$((EXCLUDED_SIZE + size))
        echo "  Excluding: $dir ($(du -sh "$dir" 2>/dev/null | cut -f1))"
    fi
done < <(find "$SOURCE_DIR" \( -name "vendor" -o -name "node_modules" -o -name "venv" -o -name "grim_venv" -o -name ".venv" \) -type d -print0 2>/dev/null)

if [[ $EXCLUDED_SIZE -gt 0 ]]; then
    EXCLUDED_SIZE_MB=$((EXCLUDED_SIZE / 1024 / 1024))
    success "Will save approximately ${EXCLUDED_SIZE_MB}MB by excluding dependency directories"
fi

# Get source directory size before backup
log "Calculating source directory size..."
SOURCE_SIZE=$(du -sb "$SOURCE_DIR" 2>/dev/null | cut -f1)
SOURCE_SIZE_MB=$((SOURCE_SIZE / 1024 / 1024))
log "Total source size: ${SOURCE_SIZE_MB}MB"

# Perform the backup using rsync
log "Starting backup with rsync..."
echo "This may take a few minutes depending on the size of your project..."

if rsync -av --progress --stats "${RSYNC_EXCLUDES[@]}" "$SOURCE_DIR/" "$TARGET_DIR/"; then
    success "Backup completed successfully!"
else
    error "Backup failed!"
    exit 1
fi

# Calculate actual backup size
BACKUP_SIZE=$(du -sb "$TARGET_DIR" 2>/dev/null | cut -f1)
BACKUP_SIZE_MB=$((BACKUP_SIZE / 1024 / 1024))

# Show summary
log "Backup Summary:"
echo "  Source directory: $SOURCE_DIR (${SOURCE_SIZE_MB}MB)"
echo "  Backup location: $TARGET_DIR (${BACKUP_SIZE_MB}MB)"
echo "  Space saved: $((SOURCE_SIZE_MB - BACKUP_SIZE_MB))MB"
echo "  Backup efficiency: $(( (SOURCE_SIZE_MB - BACKUP_SIZE_MB) * 100 / SOURCE_SIZE_MB ))% size reduction"

# Create backup info file
cat > "$TARGET_DIR/BACKUP_INFO.txt" << EOF
Grimm Reaper Backup Information
===============================

Backup Date: $(date)
Source: $SOURCE_DIR
Target: $TARGET_DIR
Original Size: ${SOURCE_SIZE_MB}MB
Backup Size: ${BACKUP_SIZE_MB}MB
Space Saved: $((SOURCE_SIZE_MB - BACKUP_SIZE_MB))MB

Excluded Patterns:
$(printf '  - %s\n' "${EXCLUDE_PATTERNS[@]}")

Restore Command:
  rsync -av "$TARGET_DIR/" "$SOURCE_DIR/"

Note: Dependencies can be restored using:
  - npm install (for Node.js projects)
  - composer install (for PHP projects)  
  - pip install -r requirements.txt (for Python projects)
  - python -m venv venv && source venv/bin/activate (for Python virtual environments)
EOF

success "Backup information saved to: $TARGET_DIR/BACKUP_INFO.txt"

# Create symlink to latest backup
LATEST_LINK="$TARGET_BASE/reaper_backup_latest"
if [[ -L "$LATEST_LINK" ]]; then
    rm "$LATEST_LINK"
fi
ln -s "$TARGET_DIR" "$LATEST_LINK"
success "Created symlink: $LATEST_LINK -> $TARGET_DIR"

# Final verification
log "Verifying backup integrity..."
if [[ -d "$TARGET_DIR" ]] && [[ $(find "$TARGET_DIR" -type f | wc -l) -gt 0 ]]; then
    success "Backup verification passed - files successfully copied"
    success "Backup completed: $TARGET_DIR"
    success "Quick access via: $LATEST_LINK"
else
    error "Backup verification failed - no files found in target directory"
    exit 1
fi

log "Backup operation completed successfully!" 