# Claude's Java Maven Central Deployment Guide

## Overview
This document explains how to deploy the Grim Reaper Java package to Maven Central using the **NEW Maven Central Portal API** with Bearer authentication.

## Prerequisites
- GPG key for signing artifacts
- NEW Maven Central Portal account credentials
- Proper pom.xml configuration

## Step-by-Step Deployment Process

### 1. Maven Settings Configuration
File: `/root/.m2/settings.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>central</id>
      <username>dc1IZh</username>
      <password>i0C94CWBTwUsJ7bW6aBwryLvI5sZczzh4</password>
    </server>
  </servers>
  <profiles>
    <profile>
      <id>ossrh</id>
      <properties>
        <ossrh.namespace.id>0051298b-de08-4dbd-8866-29d82ca6e97f</ossrh.namespace.id>
      </properties>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>ossrh</activeProfile>
  </activeProfiles>
</settings>
```

### 2. NEW Bearer Authentication
The NEW Maven Central Portal API uses Bearer authentication:

```bash
# Create Bearer token (base64 encode username:password)
TOKEN=$(printf "dc1IZh:i0C94CWBTwUsJ7bW6aBwryLvI5sZczzh4" | base64)
echo "Authorization: Bearer $TOKEN"
```

### 3. POM.xml Configuration (Key Parts)

```xml
<!-- Use the NEW Central Publishing Maven Plugin -->
<plugin>
    <groupId>org.sonatype.central</groupId>
    <artifactId>central-publishing-maven-plugin</artifactId>
    <version>0.4.0</version>
    <extensions>true</extensions>
    <configuration>
        <publishingServerId>central</publishingServerId>
        <tokenAuth>false</tokenAuth>
        <autoPublish>true</autoPublish>
    </configuration>
</plugin>

<!-- Disable the old deploy plugin -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-deploy-plugin</artifactId>
    <version>3.1.1</version>
    <configuration>
        <skip>true</skip>
    </configuration>
</plugin>

<!-- GPG signing (required) -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-gpg-plugin</artifactId>
    <version>3.1.0</version>
    <executions>
        <execution>
            <id>sign-artifacts</id>
            <phase>verify</phase>
            <goals>
                <goal>sign</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

### 4. GPG Setup
```bash
# Check existing GPG keys
gpg --list-secret-keys

# If needed, generate new key
gpg --gen-key

# Set GPG TTY for Maven
export GPG_TTY=$(tty)
```

### 5. Deployment Commands

```bash
# Navigate to java package directory
cd /opt/reaper/pkg/java_grim

# Use our custom deployment script with NEW API
./deploy-to-central.sh

# OR manually deploy
mvn clean deploy -Dmaven.test.skip=true
```

### 6. NEW API Upload Example

```bash
# Create Bearer token
TOKEN=$(printf "dc1IZh:i0C94CWBTwUsJ7bW6aBwryLvI5sZczzh4" | base64)

# Upload bundle using NEW API
curl --request POST \
  --header "Authorization: Bearer $TOKEN" \
  --form "bundle=@target/grim-reaper-1.0.33-bundle.zip" \
  --form "name=Grim Reaper v1.0.33" \
  --form "publishingType=AUTOMATIC" \
  https://central.sonatype.com/api/v1/publisher/upload

# Check status (returns deployment state)
curl --request POST \
  --header "Authorization: Bearer $TOKEN" \
  "https://central.sonatype.com/api/v1/publisher/status?id=DEPLOYMENT_ID"
```

### 7. Deployment States
- **PENDING**: Uploaded and waiting for processing
- **VALIDATING**: Being processed by validation service
- **VALIDATED**: Passed validation, waiting for manual publish (if USER_MANAGED)
- **PUBLISHING**: Being uploaded to Maven Central
- **PUBLISHED**: Successfully available on Maven Central
- **FAILED**: Encountered an error

## Package Information

**Maven Coordinates:**
- **GroupId:** `so.grim`
- **ArtifactId:** `grim-reaper`
- **Version:** `1.0.33`

**Maven Central URLs:**
- **Portal:** https://central.sonatype.com/artifact/so.grim/grim-reaper/1.0.33
- **Search:** https://search.maven.org/artifact/so.grim/grim-reaper/1.0.33
- **Repository:** https://repo1.maven.apache.org/maven2/so/grim/grim-reaper/1.0.33/

## Usage for Java Developers

**Maven dependency:**
```xml
<dependency>
    <groupId>so.grim</groupId>
    <artifactId>grim-reaper</artifactId>
    <version>1.0.33</version>
</dependency>
```

**Gradle dependency:**
```gradle
implementation 'so.grim:grim-reaper:1.0.33'
```

## Important Notes

### ✅ DO Use (NEW System):
- `central-publishing-maven-plugin` v0.4.0+
- Bearer authentication with base64 encoded credentials
- NEW Portal API: https://central.sonatype.com/api/v1/publisher/upload
- Server ID: `central` in settings.xml

### ❌ DON'T Use (Legacy System):
- `maven-deploy-plugin` with OSSRH URLs
- `https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/`
- UserToken authentication (deprecated)
- Old Nexus Repository Manager

## Troubleshooting

### Common Issues:
1. **401 Authentication Failed:** Check Bearer token is properly base64 encoded
2. **Bundle Upload Failed:** Ensure all required artifacts are signed
3. **GPG Signing Failed:** Set `GPG_TTY` environment variable
4. **Missing Server Config:** Ensure `central` server in settings.xml

### Verification:
```bash
# Check if package is available (may take a few minutes)
curl -I https://repo1.maven.apache.org/maven2/so/grim/grim-reaper/1.0.33/grim-reaper-1.0.33.jar
```

## Latest.tar.gz Integration

The Java package v1.0.33 is fully compatible with the latest.tar.gz distribution system:

- ✅ Automatic path discovery for Grim installations
- ✅ Integration with post-install recovery tools
- ✅ Emergency healing and fallback mechanisms
- ✅ Real core integration with sh_grim, py_grim, and go_grim modules

---

*This guide was updated by Claude on 2025-01-22 to document the NEW Maven Central Portal API deployment process with Bearer authentication.*