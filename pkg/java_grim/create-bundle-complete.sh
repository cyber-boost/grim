#!/bin/bash

# Create Maven Central bundle - Complete Version
set -e

echo "📦 Creating Maven Central bundle (Complete)..."

# Clean and build
mvn clean package gpg:sign

# Create bundle directory with proper Maven structure
BUNDLE_DIR="target/bundle-complete"
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

# Create POM files for each directory level
echo "📝 Creating POM files for all directory levels..."

# Root level POM
echo '<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>so.grim</groupId>
  <artifactId>grim-reaper-parent</artifactId>
  <version>1.0.29</version>
  <packaging>pom</packaging>
</project>' > "$BUNDLE_DIR/pom.xml"

# so/ level POM
echo '<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>so.grim</groupId>
  <artifactId>grim-reaper-parent</artifactId>
  <version>1.0.29</version>
  <packaging>pom</packaging>
</project>' > "$BUNDLE_DIR/so/pom.xml"

# so/grim/ level POM
echo '<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>so.grim</groupId>
  <artifactId>grim-reaper-parent</artifactId>
  <version>1.0.29</version>
  <packaging>pom</packaging>
</project>' > "$BUNDLE_DIR/so/grim/pom.xml"

# so/grim/grim-reaper/ level POM
echo '<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>so.grim</groupId>
  <artifactId>grim-reaper-parent</artifactId>
  <version>1.0.29</version>
  <packaging>pom</packaging>
</project>' > "$BUNDLE_DIR/so/grim/grim-reaper/pom.xml"

# Generate checksums for all files
echo "🔍 Generating checksums..."
find "$BUNDLE_DIR" -type f -name "*.jar" -o -name "*.asc" -o -name "*.xml" | while read file; do
    md5sum "$file" > "$file.md5"
    sha1sum "$file" > "$file.sha1"
done

# Create bundle
cd "$BUNDLE_DIR"
zip -r "../grim-reaper-bundle-complete.zip" .
cd ../../..

echo "✅ Bundle created: target/grim-reaper-bundle-complete.zip"
echo "📁 Bundle contents:"
unzip -l target/grim-reaper-bundle-complete.zip 