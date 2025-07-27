#!/bin/bash

# Build script that maintains correct semantic versions for each package

set -e

BUILD_DIR="/opt/reaper/pkg"
cd "$BUILD_DIR"

echo "🔨 Building packages with correct versions..."

# Fix JavaScript version
echo "📦 Fixing JavaScript version..."
sed -i 's/"version": ".*"/"version": "1.0.22"/' js_grim/package.json

# Fix Rust version and dependencies
echo "🦀 Fixing Rust versions..."
cat > rs_grim/Cargo.toml << 'EOF'
[package]
name = "grim-reaper"
version = "1.0.0"
edition = "2021"
authors = ["Bernie Gengel and his beagle Buddy"]
description = "Real core integration with sh_grim, py_grim, and go_grim - The Ultimate Backup, Monitoring, and Security System"
license = "BBL"
repository = "https://github.com/cyber-boost/grim"
homepage = "https://grim.so"
keywords = ["backup", "monitoring", "security", "grim", "core-integration"]
categories = ["command-line-utilities", "filesystem", "system-administration"]

[dependencies]
# Essential dependencies for core integration
tokio = { version = "1.32", features = ["process", "fs", "rt-multi-thread"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
clap = { version = "4.4", features = ["derive"] }
anyhow = "1.0"
thiserror = "1.0"

# HTTP client for py_grim API integration
reqwest = { version = "0.11", features = ["json"] }

# File system utilities
walkdir = "2.3"

# Configuration and utilities
dirs = "5.0"
which = "4.4"

[dev-dependencies]
tokio-test = "0.4"
tempfile = "3.0"
assert_fs = "1.0"

[[bin]]
name = "grim"
path = "src/main.rs"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"

[profile.dev]
opt-level = 0
debug = true

# Workspace configuration (uncomment when crates are ready)
# [workspace]
# members = [
#     "crates/grim-core",
#     "crates/grim-cli",
#     "crates/grim-api",
# ] 
EOF

# Fix PHP version
echo "🐘 Fixing PHP version..."
sed -i 's/"version": ".*"/"version": "1.0.2"/' php_grim/composer.json

# Now run the build without version argument
echo "🚀 Running build..."
./build.sh

echo "✅ Build complete!"