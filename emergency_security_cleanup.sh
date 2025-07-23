#!/bin/bash
# 🚨 EMERGENCY SECURITY CLEANUP SCRIPT
# This script removes sensitive files from git history

echo "🚨 EMERGENCY SECURITY CLEANUP STARTING..."
echo "This will remove sensitive files from git history"

# Files to remove from git history
SENSITIVE_FILES=(
    ".api_key"
    ".install_id" 
    "mother_db"
    "config/credentials.tsk"
    "config/*.conf"
    "grim_venv"
    ".env"
    "*.key"
    "*.pem"
    "*.crt"
)

echo "Removing sensitive files from git history..."

# Remove files from git history
for file in "${SENSITIVE_FILES[@]}"; do
    echo "Removing $file from git history..."
    git filter-branch --force --index-filter \
        "git rm --cached --ignore-unmatch $file" \
        --prune-empty --tag-name-filter cat -- --all
done

# Clean up git
git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo "✅ Emergency cleanup complete!"
echo "⚠️  IMPORTANT: Force push to remote with: git push --force --all"
echo "⚠️  WARN ALL COLLABORATORS to re-clone the repository" 