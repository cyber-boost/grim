#!/bin/bash

# Create Maven Central bundle - Final Version
set -e

echo "📦 Creating Maven Central bundle (Final)..."

# Clean and build
mvn clean package gpg:sign

# Create bundle directory with proper Maven structure
BUNDLE_DIR="target/bundle-final"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Create the Maven repository structure
REPO_DIR="$BUNDLE_DIR/so/grim/grim-reaper/1.0.29"
mkdir -p "$REPO_DIR"

# Copy all artifacts to proper Maven directory structure
echo "📦 Creating proper Maven repository structure..."
cp target/grim-reaper-*.jar "$REPO_DIR/"
cp target/grim-reaper-*.jar.asc "$REPO_DIR/"
cp pom.xml "$REPO_DIR/"

# Generate checksums for all files
echo "🔍 Generating checksums..."
cd "$REPO_DIR"
for file in *; do
    if [[ -f "$file" ]]; then
        md5sum "$file" > "$file.md5"
        sha1sum "$file" > "$file.sha1"
    fi
done
cd ../../../../..

# Create bundle
cd "$BUNDLE_DIR"
zip -r "../grim-reaper-bundle-final.zip" .
cd ../../..

echo "✅ Bundle created: target/grim-reaper-bundle-final.zip"
echo "📁 Bundle contents:"
unzip -l target/grim-reaper-bundle-final.zip 