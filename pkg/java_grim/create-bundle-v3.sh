#!/bin/bash

# Create Maven Central bundle - Version 3 (with POM at root)
set -e

echo "📦 Creating Maven Central bundle (v3)..."

# Clean and build
mvn clean package gpg:sign

# Create bundle directory
BUNDLE_DIR="target/bundle-v3"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Copy all artifacts to bundle root
echo "📦 Creating bundle with POM at root..."
cp target/grim-reaper-*.jar "$BUNDLE_DIR/"
cp target/grim-reaper-*.jar.asc "$BUNDLE_DIR/"

# Create a root-level POM file (parent project)
echo '<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>so.grim</groupId>
  <artifactId>grim-reaper-parent</artifactId>
  <version>1.0.29</version>
  <packaging>pom</packaging>
  <name>Grim Reaper Parent</name>
  <description>Parent project for Grim Reaper</description>
</project>' > "$BUNDLE_DIR/pom.xml"

# Also copy the actual project POM with a different name
cp pom.xml "$BUNDLE_DIR/grim-reaper-1.0.29.pom"

# Create bundle
cd "$BUNDLE_DIR"
zip -r "../grim-reaper-bundle-v3.zip" .
cd ../..

echo "✅ Bundle created: target/grim-reaper-bundle-v3.zip"
echo "📁 Bundle contents:"
unzip -l target/grim-reaper-bundle-v3.zip 