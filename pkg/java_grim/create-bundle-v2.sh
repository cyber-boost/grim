#!/bin/bash

# Create Maven Central bundle - Version 2
set -e

echo "📦 Creating Maven Central bundle (v2)..."

# Clean and build
mvn clean package gpg:sign

# Create bundle directory
BUNDLE_DIR="target/bundle-v2"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Copy all artifacts directly to bundle root
echo "📦 Creating flat bundle structure..."
cp target/grim-reaper-*.jar "$BUNDLE_DIR/"
cp target/grim-reaper-*.jar.asc "$BUNDLE_DIR/"
cp pom.xml "$BUNDLE_DIR/"

# Create bundle
cd "$BUNDLE_DIR"
zip -r "../grim-reaper-bundle-v2.zip" .
cd ../..

echo "✅ Bundle created: target/grim-reaper-bundle-v2.zip"
echo "📁 Bundle contents:"
unzip -l target/grim-reaper-bundle-v2.zip 