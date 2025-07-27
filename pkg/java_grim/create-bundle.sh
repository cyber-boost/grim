#!/bin/bash

# Create Maven Central bundle
set -e

echo "📦 Creating Maven Central bundle..."

# Clean and build
mvn clean package gpg:sign

# Create bundle directory
BUNDLE_DIR="target/bundle"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Create the Maven repository structure
REPO_DIR="$BUNDLE_DIR/so/grim/grim-reaper/1.0.29"
mkdir -p "$REPO_DIR"

# Copy all artifacts
cp target/grim-reaper-*.jar "$REPO_DIR/"
cp target/grim-reaper-*.jar.asc "$REPO_DIR/"
cp pom.xml "$REPO_DIR/"

# Create bundle
cd "$BUNDLE_DIR"
zip -r "../grim-reaper-bundle.zip" .
cd ../..

echo "✅ Bundle created: target/grim-reaper-bundle.zip"
echo "📁 Bundle contents:"
unzip -l target/grim-reaper-bundle.zip 