#!/bin/bash
# Grim Development Version Control System (fckgit.sh)
# A lightweight alternative to git for tracking file changes
# Uses .g folders and compressed storage for efficient change tracking

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
G_DIR=".g"
OBJECTS_DIR="$G_DIR/objects"
COMMITS_DIR="$G_DIR/commits"
REFS_DIR="$G_DIR/refs"
INDEX_FILE="$G_DIR/index"
CONFIG_FILE="$G_DIR/config"

# Main command router
main() {
    local command="$1"
    shift
    
    case "$command" in
        "init")
            fckgit_init "$@"
            ;;
        "track"|"add")
            fckgit_track "$@"
            ;;
        "commit")
            fckgit_commit "$@"
            ;;
        "history"|"log")
            fckgit_history "$@"
            ;;
        "diff")
            fckgit_diff "$@"
            ;;
        "restore"|"checkout")
            fckgit_restore "$@"
            ;;
        "status")
            fckgit_status "$@"
            ;;
        "config")
            fckgit_config "$@"
            ;;
        "cleanup")
            fckgit_cleanup "$@"
            ;;
        "git")
            safe_git_commands "$@"
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown dev command: $command${NC}"
            echo "Use 'grim dev help' for available commands"
            return 1
            ;;
    esac
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

fckgit_init() {
    local force="$1"
    
    if [[ -d "$G_DIR" ]] && [[ "$force" != "--force" ]]; then
        echo -e "${YELLOW}Repository already exists. Use --force to reinitialize${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Initializing Grim development repository...${NC}"
    
    # Create directory structure
    mkdir -p "$OBJECTS_DIR" "$COMMITS_DIR" "$REFS_DIR"
    
    # Initialize configuration
    cat > "$CONFIG_FILE" << EOF
# Grim Development Repository Configuration
version=1.0
compression=gzip
auto_backup=true
created=$(date -Iseconds)
path=$(pwd)
EOF
    
    # Initialize index
    echo "# Grim Development Index" > "$INDEX_FILE"
    echo "# Format: hash|path|timestamp|size" >> "$INDEX_FILE"
    
    # Initialize HEAD
    echo "main" > "$REFS_DIR/HEAD"
    
    # Create initial commit marker
    touch "$COMMITS_DIR/.init"
    
    echo -e "${GREEN}✓ Initialized empty Grim repository in $(pwd)/$G_DIR${NC}"
    echo -e "${BLUE}Use 'grim dev track <file>' to start tracking files${NC}"
    
    # Auto-integrate with backup system if configured
    if [[ -f "$GRIM_ROOT/sh_grim/auto_backup.sh" ]]; then
        echo -e "${PURPLE}Integrating with auto-backup system...${NC}"
        add_to_auto_backup
    fi
}

fckgit_track() {
    check_repository || return 1
    
    if [[ $# -eq 0 ]]; then
        echo -e "${RED}Error: No files specified${NC}"
        echo "Usage: grim dev track <file1> [file2] ..."
        return 1
    fi
    
    local tracked_count=0
    
    for file in "$@"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}Warning: File not found: $file${NC}"
            continue
        fi
        
        # Calculate file hash and metadata
        local file_hash=$(sha256sum "$file" | cut -d' ' -f1)
        local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local file_time=$(stat -c%Y "$file" 2>/dev/null || echo "0")
        local timestamp=$(date -Iseconds)
        
        # Create compressed copy in objects
        local object_path="$OBJECTS_DIR/${file_hash:0:2}/${file_hash:2}"
        mkdir -p "$(dirname "$object_path")"
        
        if [[ ! -f "$object_path" ]]; then
            gzip -c "$file" > "$object_path"
            echo -e "${GREEN}✓ Stored object: $file_hash${NC}"
        fi
        
        # Update index
        local relative_path=$(realpath --relative-to="$(pwd)" "$file")
        local index_entry="$file_hash|$relative_path|$timestamp|$file_size"
        
        # Remove existing entry for this file
        if [[ -f "$INDEX_FILE" ]]; then
            grep -v "|$relative_path|" "$INDEX_FILE" > "$INDEX_FILE.tmp" 2>/dev/null || touch "$INDEX_FILE.tmp"
            mv "$INDEX_FILE.tmp" "$INDEX_FILE"
        fi
        
        # Add new entry
        echo "$index_entry" >> "$INDEX_FILE"
        
        echo -e "${BLUE}Tracking: $relative_path${NC}"
        ((tracked_count++))
    done
    
    echo -e "${GREEN}Successfully tracked $tracked_count file(s)${NC}"
}

fckgit_commit() {
    check_repository || return 1
    
    local message="$1"
    if [[ -z "$message" ]]; then
        echo -e "${RED}Error: Commit message required${NC}"
        echo "Usage: grim dev commit \"Your commit message\""
        return 1
    fi
    
    # Check if there are tracked files
    if [[ ! -s "$INDEX_FILE" ]] || [[ $(grep -v "^#" "$INDEX_FILE" | wc -l) -eq 0 ]]; then
        echo -e "${YELLOW}Nothing to commit (no tracked files)${NC}"
        return 1
    fi
    
    # Generate commit hash
    local commit_hash=$(echo "$message$(date -Iseconds)$(cat "$INDEX_FILE")" | sha256sum | cut -d' ' -f1)
    local commit_short="${commit_hash:0:8}"
    
    # Create commit object
    local commit_file="$COMMITS_DIR/$commit_hash"
    cat > "$commit_file" << EOF
commit $commit_hash
message $message
timestamp $(date -Iseconds)
author $(whoami)@$(hostname)
parent $(cat "$REFS_DIR/HEAD" 2>/dev/null || echo "none")

# Files in this commit:
$(grep -v "^#" "$INDEX_FILE")
EOF
    
    # Update HEAD
    echo "$commit_hash" > "$REFS_DIR/HEAD"
    
    # Create human-readable log entry
    echo "[$commit_short] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$G_DIR/history.log"
    
    echo -e "${GREEN}✓ Committed changes: $commit_short${NC}"
    echo -e "${BLUE}Message: $message${NC}"
    
    # Auto-backup integration
    if grep -q "auto_backup=true" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${PURPLE}Triggering auto-backup...${NC}"
        trigger_auto_backup "$commit_hash"
    fi
}

fckgit_history() {
    check_repository || return 1
    
    local limit="${1:-10}"
    
    echo -e "${CYAN}=== Grim Development History ===${NC}"
    echo ""
    
    if [[ -f "$G_DIR/history.log" ]]; then
        tail -n "$limit" "$G_DIR/history.log" | tac
    else
        echo -e "${YELLOW}No commits found${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}Use 'grim dev history <number>' to show more commits${NC}"
}

fckgit_diff() {
    check_repository || return 1
    
    local file="$1"
    local commit1="$2"
    local commit2="$3"
    
    if [[ -z "$file" ]]; then
        echo -e "${RED}Error: File path required${NC}"
        echo "Usage: grim dev diff <file> [commit1] [commit2]"
        return 1
    fi
    
    # Show diff between working directory and last commit if no commits specified
    if [[ -z "$commit1" ]]; then
        show_working_diff "$file"
        return $?
    fi
    
    echo -e "${CYAN}Diff functionality coming in next version${NC}"
    echo -e "${BLUE}Current version shows file status changes${NC}"
}

fckgit_restore() {
    check_repository || return 1
    
    local file="$1"
    local commit="$2"
    
    if [[ -z "$file" ]]; then
        echo -e "${RED}Error: File path required${NC}"
        echo "Usage: grim dev restore <file> [commit_hash]"
        return 1
    fi
    
    # Use HEAD commit if none specified
    if [[ -z "$commit" ]]; then
        commit=$(cat "$REFS_DIR/HEAD" 2>/dev/null)
    fi
    
    if [[ -z "$commit" ]] || [[ ! -f "$COMMITS_DIR/$commit" ]]; then
        echo -e "${RED}Error: Invalid commit: $commit${NC}"
        return 1
    fi
    
    # Find file in commit
    local file_hash=$(grep "|$file|" "$COMMITS_DIR/$commit" | cut -d'|' -f1)
    
    if [[ -z "$file_hash" ]]; then
        echo -e "${RED}Error: File not found in commit: $file${NC}"
        return 1
    fi
    
    # Restore from objects
    local object_path="$OBJECTS_DIR/${file_hash:0:2}/${file_hash:2}"
    
    if [[ ! -f "$object_path" ]]; then
        echo -e "${RED}Error: Object not found: $file_hash${NC}"
        return 1
    fi
    
    # Create backup of current file
    if [[ -f "$file" ]]; then
        cp "$file" "$file.backup.$(date +%s)"
        echo -e "${YELLOW}Created backup: $file.backup.$(date +%s)${NC}"
    fi
    
    # Restore file
    gunzip -c "$object_path" > "$file"
    
    echo -e "${GREEN}✓ Restored: $file from commit ${commit:0:8}${NC}"
}

fckgit_status() {
    check_repository || return 1
    
    echo -e "${CYAN}=== Grim Development Status ===${NC}"
    echo ""
    
    # Show current branch/commit
    local current_commit=$(cat "$REFS_DIR/HEAD" 2>/dev/null)
    if [[ -n "$current_commit" ]] && [[ "$current_commit" != "main" ]]; then
        echo -e "${BLUE}HEAD: ${current_commit:0:8}${NC}"
    else
        echo -e "${BLUE}Branch: main${NC}"
    fi
    
    echo ""
    
    # Show tracked files status
    if [[ -f "$INDEX_FILE" ]]; then
        local tracked_count=$(grep -v "^#" "$INDEX_FILE" | wc -l)
        echo -e "${GREEN}Tracked files: $tracked_count${NC}"
        
        echo ""
        echo -e "${YELLOW}Recently tracked:${NC}"
        grep -v "^#" "$INDEX_FILE" | tail -5 | while IFS='|' read -r hash path timestamp size; do
            local status_color="$GREEN"
            if [[ -f "$path" ]]; then
                local current_hash=$(sha256sum "$path" | cut -d' ' -f1)
                if [[ "$current_hash" != "$hash" ]]; then
                    status_color="$YELLOW"
                    echo -e "  ${status_color}M $path${NC} (modified)"
                else
                    echo -e "  ${status_color}✓ $path${NC}"
                fi
            else
                status_color="$RED"
                echo -e "  ${status_color}D $path${NC} (deleted)"
            fi
        done
    else
        echo -e "${YELLOW}No tracked files${NC}"
    fi
    
    echo ""
    
    # Show repository stats
    if [[ -d "$OBJECTS_DIR" ]]; then
        local object_count=$(find "$OBJECTS_DIR" -type f | wc -l)
        local repo_size=$(du -sh "$G_DIR" 2>/dev/null | cut -f1)
        echo -e "${BLUE}Repository size: $repo_size ($object_count objects)${NC}"
    fi
}

fckgit_config() {
    check_repository || return 1
    
    local key="$1"
    local value="$2"
    
    if [[ -z "$key" ]]; then
        echo -e "${CYAN}=== Grim Development Configuration ===${NC}"
        cat "$CONFIG_FILE"
        return 0
    fi
    
    if [[ -z "$value" ]]; then
        # Get value
        grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2-
    else
        # Set value
        if grep -q "^$key=" "$CONFIG_FILE"; then
            sed -i "s/^$key=.*/$key=$value/" "$CONFIG_FILE"
        else
            echo "$key=$value" >> "$CONFIG_FILE"
        fi
        echo -e "${GREEN}Set $key = $value${NC}"
    fi
}

fckgit_cleanup() {
    check_repository || return 1
    
    echo -e "${CYAN}Cleaning up repository...${NC}"
    
    # Remove orphaned objects
    local removed_count=0
    
    # Find all hashes referenced in commits
    local referenced_hashes=$(mktemp)
    find "$COMMITS_DIR" -type f -exec grep -h "^[a-f0-9]" {} \; | cut -d'|' -f1 | sort -u > "$referenced_hashes"
    
    # Find unreferenced objects
    find "$OBJECTS_DIR" -type f | while read -r object_file; do
        local hash=$(basename "$(dirname "$object_file")")$(basename "$object_file")
        if ! grep -q "^$hash$" "$referenced_hashes"; then
            rm -f "$object_file"
            ((removed_count++))
        fi
    done
    
    rm -f "$referenced_hashes"
    
    # Clean empty directories
    find "$OBJECTS_DIR" -type d -empty -delete 2>/dev/null
    
    echo -e "${GREEN}✓ Cleanup complete (removed $removed_count orphaned objects)${NC}"
}

# =============================================================================
# SAFE GIT OPERATIONS
# =============================================================================

safe_git_commands() {
    local git_command="$1"
    shift
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}Not in a git repository${NC}"
        echo -e "${BLUE}Use 'git init' to initialize a git repository first${NC}"
        return 1
    fi
    
    case "$git_command" in
        "commit")
            safe_git_commit "$@"
            ;;
        "push")
            safe_git_push "$@"
            ;;
        "pull")
            safe_git_pull "$@"
            ;;
        "reset")
            safe_git_reset "$@"
            ;;
        "rebase")
            safe_git_rebase "$@"
            ;;
        "merge")
            safe_git_merge "$@"
            ;;
        "checkout")
            safe_git_checkout "$@"
            ;;
        "clean")
            safe_git_clean "$@"
            ;;
        "stash")
            safe_git_stash "$@"
            ;;
        "help"|"--help"|"-h")
            show_git_help
            ;;
        *)
            # For safe commands, just pass through
            if is_safe_git_command "$git_command"; then
                echo -e "${BLUE}Executing safe git command: git $git_command $*${NC}"
                git "$git_command" "$@"
            else
                echo -e "${YELLOW}Unknown git command: $git_command${NC}"
                echo -e "${BLUE}Creating safety backup before executing...${NC}"
                create_safety_backup "git-$git_command"
                git "$git_command" "$@"
            fi
            ;;
    esac
}

safe_git_commit() {
    echo -e "${CYAN}=== Safe Git Commit ===${NC}"
    
    # Initialize .g repo if it doesn't exist
    if [[ ! -d "$G_DIR" ]]; then
        echo -e "${YELLOW}No .g repository found. Initializing...${NC}"
        fckgit_init
    fi
    
    # Auto-track modified files
    echo -e "${BLUE}Auto-tracking modified files...${NC}"
    local modified_files=($(git diff --name-only HEAD 2>/dev/null))
    local staged_files=($(git diff --cached --name-only 2>/dev/null))
    local untracked_files=($(git ls-files --others --exclude-standard 2>/dev/null))
    
    # Combine all files and track them
    local all_files=("${modified_files[@]}" "${staged_files[@]}" "${untracked_files[@]}")
    if [[ ${#all_files[@]} -gt 0 ]]; then
        fckgit_track "${all_files[@]}" 2>/dev/null || true
    fi
    
    # Create fckgit commit
    local commit_msg="Git commit: $*"
    echo -e "${PURPLE}Creating .g backup commit...${NC}"
    fckgit_commit "$commit_msg"
    
    # Proceed with git commit
    echo -e "${GREEN}Proceeding with git commit...${NC}"
    git commit "$@"
    
    echo -e "${GREEN}✓ Safe commit complete (backed up to .g)${NC}"
}

safe_git_push() {
    echo -e "${CYAN}=== Safe Git Push ===${NC}"
    
    # Create safety backup
    create_safety_backup "pre-push"
    
    # Show what will be pushed
    echo -e "${BLUE}Commits to be pushed:${NC}"
    git log --oneline @{u}..HEAD 2>/dev/null || echo "No upstream configured"
    
    # Confirm push
    if [[ "$1" != "--force" ]] && [[ "$1" != "-f" ]]; then
        echo -e "${YELLOW}Proceed with push? [y/N]${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Push cancelled${NC}"
            return 0
        fi
    fi
    
    # Execute push
    echo -e "${GREEN}Pushing to remote...${NC}"
    git push "$@"
    
    echo -e "${GREEN}✓ Safe push complete${NC}"
}

safe_git_pull() {
    echo -e "${CYAN}=== Safe Git Pull ===${NC}"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
        echo -e "${BLUE}Creating safety backup...${NC}"
        create_safety_backup "pre-pull-uncommitted"
    fi
    
    # Create pre-pull backup
    create_safety_backup "pre-pull"
    
    # Show incoming changes
    echo -e "${BLUE}Fetching changes...${NC}"
    git fetch 2>/dev/null || true
    
    local behind_count=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    if [[ "$behind_count" -gt 0 ]]; then
        echo -e "${BLUE}Incoming commits: $behind_count${NC}"
        git log --oneline HEAD..@{u} 2>/dev/null | head -5
    else
        echo -e "${GREEN}Already up to date${NC}"
        return 0
    fi
    
    # Execute pull
    echo -e "${GREEN}Pulling changes...${NC}"
    git pull "$@"
    
    echo -e "${GREEN}✓ Safe pull complete${NC}"
}

safe_git_reset() {
    echo -e "${CYAN}=== Safe Git Reset ===${NC}"
    echo -e "${RED}⚠️  WARNING: This is a potentially destructive operation${NC}"
    
    # Create comprehensive backup
    create_safety_backup "pre-reset"
    
    # Show what will be reset
    echo -e "${BLUE}Current status:${NC}"
    git status --short
    
    echo -e "${YELLOW}Proceed with reset? [y/N]${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Reset cancelled${NC}"
        return 0
    fi
    
    # Execute reset
    echo -e "${GREEN}Executing reset...${NC}"
    git reset "$@"
    
    echo -e "${GREEN}✓ Safe reset complete (backup available in .g)${NC}"
}

safe_git_rebase() {
    echo -e "${CYAN}=== Safe Git Rebase ===${NC}"
    echo -e "${RED}⚠️  WARNING: This rewrites git history${NC}"
    
    # Create comprehensive backup
    create_safety_backup "pre-rebase"
    
    # Show current branch state
    echo -e "${BLUE}Current branch: $(git branch --show-current)${NC}"
    echo -e "${BLUE}Recent commits:${NC}"
    git log --oneline -5
    
    echo -e "${YELLOW}Proceed with rebase? [y/N]${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Rebase cancelled${NC}"
        return 0
    fi
    
    # Execute rebase
    echo -e "${GREEN}Executing rebase...${NC}"
    git rebase "$@"
    
    echo -e "${GREEN}✓ Safe rebase complete${NC}"
}

safe_git_merge() {
    echo -e "${CYAN}=== Safe Git Merge ===${NC}"
    
    # Create safety backup
    create_safety_backup "pre-merge"
    
    # Show merge preview
    local merge_branch="$1"
    if [[ -n "$merge_branch" ]]; then
        echo -e "${BLUE}Merging branch: $merge_branch${NC}"
        echo -e "${BLUE}Commits to be merged:${NC}"
        git log --oneline HEAD.."$merge_branch" 2>/dev/null | head -5
    fi
    
    # Execute merge
    echo -e "${GREEN}Executing merge...${NC}"
    git merge "$@"
    
    echo -e "${GREEN}✓ Safe merge complete${NC}"
}

safe_git_checkout() {
    echo -e "${CYAN}=== Safe Git Checkout ===${NC}"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
        echo -e "${BLUE}Creating safety backup...${NC}"
        create_safety_backup "pre-checkout-uncommitted"
    fi
    
    # Create safety backup for potential branch switch
    if [[ "$1" != "--" ]]; then
        create_safety_backup "pre-checkout"
    fi
    
    # Execute checkout
    echo -e "${GREEN}Executing checkout...${NC}"
    git checkout "$@"
    
    echo -e "${GREEN}✓ Safe checkout complete${NC}"
}

safe_git_clean() {
    echo -e "${CYAN}=== Safe Git Clean ===${NC}"
    echo -e "${RED}⚠️  WARNING: This permanently deletes untracked files${NC}"
    
    # Show what will be cleaned
    echo -e "${BLUE}Files to be removed:${NC}"
    git clean -n "$@"
    
    # Create backup of untracked files
    echo -e "${PURPLE}Backing up untracked files...${NC}"
    create_untracked_backup
    
    echo -e "${YELLOW}Proceed with clean? [y/N]${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Clean cancelled${NC}"
        return 0
    fi
    
    # Execute clean
    echo -e "${GREEN}Executing clean...${NC}"
    git clean "$@"
    
    echo -e "${GREEN}✓ Safe clean complete${NC}"
}

safe_git_stash() {
    echo -e "${CYAN}=== Safe Git Stash ===${NC}"
    
    # Create safety backup before stashing
    create_safety_backup "pre-stash"
    
    # Execute stash
    echo -e "${GREEN}Executing stash...${NC}"
    git stash "$@"
    
    echo -e "${GREEN}✓ Safe stash complete${NC}"
}

# =============================================================================
# SAFE GIT HELPER FUNCTIONS
# =============================================================================

create_safety_backup() {
    local backup_name="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    echo -e "${PURPLE}Creating safety backup: $backup_name-$timestamp${NC}"
    
    # Initialize .g repo if needed
    if [[ ! -d "$G_DIR" ]]; then
        fckgit_init >/dev/null 2>&1
    fi
    
    # Track all current files
    local all_files=($(find . -type f -not -path "./.git/*" -not -path "./.g/*" 2>/dev/null))
    if [[ ${#all_files[@]} -gt 0 ]]; then
        fckgit_track "${all_files[@]}" >/dev/null 2>&1
        fckgit_commit "Safety backup: $backup_name-$timestamp" >/dev/null 2>&1
    fi
    
    # Also create a traditional backup directory
    local backup_dir="$GRIM_ROOT/backups/dev-safety/$timestamp-$backup_name"
    mkdir -p "$backup_dir"
    
    # Copy important files
    cp -r .git "$backup_dir/" 2>/dev/null || true
    if [[ -d "$G_DIR" ]]; then
        cp -r "$G_DIR" "$backup_dir/" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Safety backup created${NC}"
}

create_untracked_backup() {
    local untracked_files=($(git ls-files --others --exclude-standard))
    
    if [[ ${#untracked_files[@]} -eq 0 ]]; then
        echo -e "${BLUE}No untracked files to backup${NC}"
        return 0
    fi
    
    local backup_dir="$GRIM_ROOT/backups/untracked/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    for file in "${untracked_files[@]}"; do
        local dest_dir="$backup_dir/$(dirname "$file")"
        mkdir -p "$dest_dir"
        cp "$file" "$dest_dir/" 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Untracked files backed up to: $backup_dir${NC}"
}

is_safe_git_command() {
    local command="$1"
    local safe_commands=("status" "log" "show" "diff" "branch" "remote" "config" "help" "version")
    
    for safe_cmd in "${safe_commands[@]}"; do
        if [[ "$command" == "$safe_cmd" ]]; then
            return 0
        fi
    done
    
    return 1
}

show_git_help() {
    echo -e "${CYAN}Grim Safe Git Operations${NC}"
    echo ""
    echo -e "${YELLOW}SAFE OPERATIONS (with auto-backup):${NC}"
    echo "  grim dev git commit [options]       - Commit with .g backup integration"
    echo "  grim dev git push [options]         - Push with confirmation and backup"
    echo "  grim dev git pull [options]         - Pull with pre-operation backup"
    echo "  grim dev git reset [options]        - Reset with comprehensive backup"
    echo "  grim dev git rebase [options]       - Rebase with history backup"
    echo "  grim dev git merge [branch]         - Merge with safety backup"
    echo "  grim dev git checkout [options]     - Checkout with uncommitted backup"
    echo "  grim dev git clean [options]        - Clean with untracked file backup"
    echo "  grim dev git stash [options]        - Stash with safety backup"
    echo ""
    echo -e "${YELLOW}PASS-THROUGH (safe commands):${NC}"
    echo "  grim dev git status                 - Show repository status"
    echo "  grim dev git log                    - Show commit history"
    echo "  grim dev git diff                   - Show differences"
    echo "  grim dev git branch                 - List/manage branches"
    echo ""
    echo -e "${YELLOW}FEATURES:${NC}"
    echo "  • Automatic .g repository integration"
    echo "  • Safety backups before destructive operations"
    echo "  • Confirmation prompts for dangerous commands"
    echo "  • Backup of untracked files before cleaning"
    echo "  • Traditional backup directory creation"
    echo ""
    echo -e "${BLUE}All backups are stored in both .g repository and $GRIM_ROOT/backups/${NC}"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

check_repository() {
    if [[ ! -d "$G_DIR" ]]; then
        echo -e "${RED}Not a Grim repository. Use 'grim dev init' to initialize.${NC}"
        return 1
    fi
    return 0
}

show_working_diff() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}File not found: $file${NC}"
        return 1
    fi
    
    # Get last tracked version
    local file_hash=$(grep "|$file|" "$INDEX_FILE" | tail -1 | cut -d'|' -f1)
    
    if [[ -z "$file_hash" ]]; then
        echo -e "${YELLOW}File not tracked: $file${NC}"
        return 1
    fi
    
    # Get current hash
    local current_hash=$(sha256sum "$file" | cut -d' ' -f1)
    
    if [[ "$file_hash" == "$current_hash" ]]; then
        echo -e "${GREEN}No changes in: $file${NC}"
    else
        echo -e "${YELLOW}File modified: $file${NC}"
        echo -e "${BLUE}Tracked:  $file_hash${NC}"
        echo -e "${BLUE}Current:  $current_hash${NC}"
    fi
}

add_to_auto_backup() {
    # Integration with Grim auto-backup system
    local auto_backup_config="$GRIM_ROOT/config/auto_backup.conf"
    
    if [[ -f "$auto_backup_config" ]]; then
        if ! grep -q "$(pwd)/$G_DIR" "$auto_backup_config"; then
            echo "$(pwd)/$G_DIR" >> "$auto_backup_config"
            echo -e "${GREEN}✓ Added to auto-backup monitoring${NC}"
        fi
    fi
}

trigger_auto_backup() {
    local commit_hash="$1"
    
    # Trigger backup after commit
    if [[ -x "$GRIM_ROOT/sh_grim/auto_backup.sh" ]]; then
        "$GRIM_ROOT/sh_grim/auto_backup.sh" trigger-dev-commit "$commit_hash" "$(pwd)" &
    fi
}

show_help() {
    echo -e "${CYAN}Grim Development Version Control System${NC}"
    echo ""
    echo -e "${YELLOW}REPOSITORY MANAGEMENT:${NC}"
    echo "  grim dev init                           - Initialize new development repository"
    echo "  grim dev status                         - Show repository status and file changes"
    echo "  grim dev config [key] [value]           - Get/set configuration options"
    echo "  grim dev cleanup                        - Clean up orphaned objects"
    echo ""
    echo -e "${YELLOW}FILE TRACKING:${NC}"
    echo "  grim dev track <file1> [file2...]       - Start tracking files (creates compressed copies)"
    echo "  grim dev commit \"message\"               - Commit tracked changes with message"
    echo "  grim dev history [count]                - Show commit history (default: last 10)"
    echo ""
    echo -e "${YELLOW}CHANGE MANAGEMENT:${NC}"
    echo "  grim dev diff <file> [commit1] [commit2] - Show differences between versions"
    echo "  grim dev restore <file> [commit]        - Restore file from commit (default: HEAD)"
    echo ""
    echo -e "${YELLOW}SAFE GIT OPERATIONS:${NC}"
    echo "  grim dev git commit [options]           - Safe git commit with .g backup integration"
    echo "  grim dev git push [options]             - Safe git push with confirmation"
    echo "  grim dev git pull [options]             - Safe git pull with pre-operation backup"
    echo "  grim dev git reset [options]            - Safe git reset with comprehensive backup"
    echo "  grim dev git rebase [options]           - Safe git rebase with history backup"
    echo "  grim dev git merge [branch]             - Safe git merge with safety backup"
    echo "  grim dev git help                       - Show detailed git operation help"
    echo ""
    echo -e "${YELLOW}FEATURES:${NC}"
    echo "  • Compressed storage using gzip"
    echo "  • Integration with Grim auto-backup system"
    echo "  • SHA256-based content addressing"
    echo "  • Lightweight alternative to git"
    echo "  • Automatic backup triggering on commits"
    echo ""
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "  grim dev init                           - Start tracking this directory"
    echo "  grim dev track *.sh *.conf              - Track shell scripts and config files"
    echo "  grim dev commit \"Initial backup\"        - Save current state"
    echo "  grim dev history                        - See what you've done"
    echo "  grim dev restore backup.sh abc123       - Restore file from specific commit"
    echo ""
    echo -e "${BLUE}The .g directory stores all version data with compressed file copies${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main "$@" 