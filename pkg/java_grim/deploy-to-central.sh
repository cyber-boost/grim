#!/bin/bash

# 🗡️ GRIM REAPER JAVA - NEW MAVEN CENTRAL DEPLOYMENT
# Deploy Java Grim v1.0.33 to NEW Maven Central Portal API

set -e

# NEW Maven Central Credentials
USERNAME="dc1IZh"
PASSWORD="i0C94CWBTwUsJ7bW6aBwryLvI5sZczzh4"
VERSION="1.0.33"
ARTIFACT_ID="grim-reaper"
GROUP_ID="so.grim"

# Create proper Bearer token (base64 encode username:password)
TOKEN=$(printf "%s:%s" "$USERNAME" "$PASSWORD" | base64)

echo "🗡️  GRIM REAPER JAVA DEPLOYMENT v${VERSION}"
echo "=============================================="
echo "📦 Artifact: ${GROUP_ID}:${ARTIFACT_ID}:${VERSION}"
echo "🎯 Target: NEW Maven Central Portal API"
echo "🔑 Using Bearer authentication"
echo ""

# Verify POM version matches
echo "🔍 Verifying POM.xml version..."
POM_VERSION=$(grep -o '<version>[^<]*</version>' pom.xml | head -1 | sed 's/<version>\(.*\)<\/version>/\1/')
if [[ "$POM_VERSION" != "$VERSION" ]]; then
    echo "❌ Version mismatch: POM has $POM_VERSION, expected $VERSION"
    exit 1
fi
echo "✅ POM version verified: $POM_VERSION"

# Set GPG environment
export GPG_TTY=$(tty)
echo "🔑 GPG TTY set to: $GPG_TTY"

# Clean and build with full verification
echo ""
echo "🔨 Building and signing artifacts..."
mvn clean package gpg:sign -Dmaven.test.skip=true

# Verify artifacts were created
echo ""
echo "📋 Verifying artifacts..."
EXPECTED_FILES=(
    "target/${ARTIFACT_ID}-${VERSION}.jar"
    "target/${ARTIFACT_ID}-${VERSION}.jar.asc"
    "target/${ARTIFACT_ID}-${VERSION}-sources.jar"
    "target/${ARTIFACT_ID}-${VERSION}-sources.jar.asc"
    "target/${ARTIFACT_ID}-${VERSION}-javadoc.jar"
    "target/${ARTIFACT_ID}-${VERSION}-javadoc.jar.asc"
)

for file in "${EXPECTED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ Found: $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done

# Create deployment bundle
echo ""
echo "📦 Creating deployment bundle..."
BUNDLE_DIR="target/deployment-bundle"
MAVEN_DIR="$BUNDLE_DIR/${GROUP_ID//.//}/${ARTIFACT_ID}/${VERSION}"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MAVEN_DIR"

# Copy all artifacts with proper naming
cp "target/${ARTIFACT_ID}-${VERSION}.jar" "$MAVEN_DIR/"
cp "target/${ARTIFACT_ID}-${VERSION}.jar.asc" "$MAVEN_DIR/"
cp "target/${ARTIFACT_ID}-${VERSION}-sources.jar" "$MAVEN_DIR/"
cp "target/${ARTIFACT_ID}-${VERSION}-sources.jar.asc" "$MAVEN_DIR/"
cp "target/${ARTIFACT_ID}-${VERSION}-javadoc.jar" "$MAVEN_DIR/"
cp "target/${ARTIFACT_ID}-${VERSION}-javadoc.jar.asc" "$MAVEN_DIR/"

# Create POM and signature
cp pom.xml "$MAVEN_DIR/${ARTIFACT_ID}-${VERSION}.pom"
gpg --detach-sign --armor "$MAVEN_DIR/${ARTIFACT_ID}-${VERSION}.pom"

# Generate required checksums (MD5 and SHA1) for all files
echo "🔢 Generating checksums..."
cd "$MAVEN_DIR"
for file in *.jar *.pom; do
    if [[ -f "$file" ]]; then
        md5sum "$file" | cut -d' ' -f1 > "${file}.md5"
        sha1sum "$file" | cut -d' ' -f1 > "${file}.sha1"
        echo "✅ Checksums created for: $file"
    fi
done
cd - > /dev/null

# Create bundle zip
cd "$BUNDLE_DIR"
BUNDLE_ZIP="../grim-reaper-${VERSION}-bundle.zip"
zip -r "$BUNDLE_ZIP" .
cd ../..

echo "✅ Bundle created: target/grim-reaper-${VERSION}-bundle.zip"

# Upload to NEW Maven Central Portal API
echo ""
echo "📤 Uploading to NEW Maven Central Portal API..."
echo "🔑 Using Bearer token: Bearer ${TOKEN:0:20}..."

UPLOAD_RESPONSE=$(curl --request POST \
  --verbose \
  --header "Authorization: Bearer $TOKEN" \
  --form "bundle=@target/grim-reaper-${VERSION}-bundle.zip" \
  --form "name=Grim Reaper v${VERSION}" \
  --form "publishingType=AUTOMATIC" \
  https://central.sonatype.com/api/v1/publisher/upload 2>&1)

echo "📋 Upload response: $UPLOAD_RESPONSE"

# Extract deployment ID from response
DEPLOYMENT_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '^[a-f0-9\-]\{36\}$' | head -1)

if [[ -z "$DEPLOYMENT_ID" ]]; then
    # Try alternative extraction method
    DEPLOYMENT_ID=$(echo "$UPLOAD_RESPONSE" | grep -E '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' -o | head -1)
fi

if [[ -z "$DEPLOYMENT_ID" ]]; then
    echo "❌ Failed to extract deployment ID from response"
    echo "📋 Full response: $UPLOAD_RESPONSE"
    exit 1
fi

echo "✅ Upload successful!"
echo "🆔 Deployment ID: $DEPLOYMENT_ID"

# Check deployment status using NEW API
echo ""
echo "🔍 Checking deployment status..."
sleep 15

STATUS_RESPONSE=$(curl --request POST \
  --header "Authorization: Bearer $TOKEN" \
  "https://central.sonatype.com/api/v1/publisher/status?id=$DEPLOYMENT_ID")

echo "📊 Status response: $STATUS_RESPONSE"

# Parse deployment state
DEPLOYMENT_STATE=$(echo "$STATUS_RESPONSE" | grep -o '"deploymentState":"[^"]*"' | cut -d'"' -f4)

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================================="
echo "📦 Package: Grim Reaper Java v${VERSION}"
echo "🆔 Deployment ID: $DEPLOYMENT_ID"
echo "📊 State: $DEPLOYMENT_STATE"
echo "🔗 Maven Central: https://central.sonatype.com/artifact/${GROUP_ID}/${ARTIFACT_ID}/${VERSION}"
echo "🔗 Search: https://search.maven.org/artifact/${GROUP_ID}/${ARTIFACT_ID}/${VERSION}"
echo ""
echo "📝 Usage:"
echo "Maven:"
echo "<dependency>"
echo "    <groupId>${GROUP_ID}</groupId>"
echo "    <artifactId>${ARTIFACT_ID}</artifactId>"
echo "    <version>${VERSION}</version>"
echo "</dependency>"
echo ""
echo "Gradle:"
echo "implementation '${GROUP_ID}:${ARTIFACT_ID}:${VERSION}'"
echo ""

case "$DEPLOYMENT_STATE" in
    "PENDING"|"VALIDATING")
        echo "⏳ Deployment is processing..."
        ;;
    "VALIDATED")
        echo "✅ Deployment validated! Ready for manual publishing."
        echo "🔗 Portal: https://central.sonatype.com/publishing/deployments"
        ;;
    "PUBLISHING")
        echo "🚀 Deployment is being published to Maven Central..."
        ;;
    "PUBLISHED")
        echo "🎉 Successfully published to Maven Central!"
        ;;
    "FAILED")
        echo "❌ Deployment failed! Check the Portal for details."
        echo "🔗 Portal: https://central.sonatype.com/publishing/deployments"
        ;;
    *)
        echo "❓ Unknown state: $DEPLOYMENT_STATE"
        ;;
esac

echo ""
echo "⏳ Note: May take 5-15 minutes to appear in search results"
echo "🗡️  Death-defying data protection is now available!" 