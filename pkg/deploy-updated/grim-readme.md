# 🗡️ Grim Reaper Unified Build & Deploy System

## Overview

This unified system replaces the separate `build.sh` and `deploy.sh` scripts with a single `grim.sh` script and a `grim-config.json` configuration file. It provides better version management, deployment ordering, and OTP support for 2FA-enabled registries.

**Current Version**: 1.0.29 (as of January 15, 2025)

## Features

- **Single unified script** for both building and deploying
- **JSON-based configuration** with version history tracking
- **Manual version override** capability
- **OTP support** for npm and RubyGems 2FA
- **Customizable deployment order** (npm → ruby → python → rust → others)
- **Skip functionality** for individual packages
- **Dry-run mode** for testing
- **Comprehensive logging** and reporting

## Quick Start

```bash
# Make the script executable
chmod +x grim.sh

# Build all packages
./grim.sh build

# Deploy all packages
./grim.sh deploy

# Build and deploy all packages
./grim.sh all

# Build and deploy with specific version
./grim.sh all -v 2024.12.20

# Deploy with OTP tokens
./grim.sh deploy --otp-npm 123456 --otp-ruby 789012

# Skip specific languages
./grim.sh all --skip-java --skip-csharp

# Dry run to see what would happen
./grim.sh deploy --dry-run
```

## Configuration

The `grim-config.json` file controls:

### Version Management
```json
"version": {
  "current": "2024.12.19",
  "override": null,  // Set this to force a specific version
  "history": [...]   // Automatically maintained
}
```

### Package Settings
Each package can be:
- Enabled/disabled
- Have custom version file patterns
- Define registry information

### Deployment Order
The deployment order is defined in:
```json
"deployment": {
  "order": ["js_grim", "rb_grim", "py_grim", "rs_grim", ...]
}
```

## Commands

### `grim.sh build`
Builds all enabled packages with the configured version.

### `grim.sh deploy`
Deploys all built packages to their respective registries.

### `grim.sh all`
Builds and then deploys all packages, updating version history.

## Options

| Option | Description |
|--------|-------------|
| `-v, --version VERSION` | Override the version from config |
| `--dry-run` | Show what would be done without doing it |
| `-m, --message MESSAGE` | Add deployment notes to version history |
| `--otp-npm TOKEN` | NPM OTP token for 2FA |
| `--otp-ruby TOKEN` | RubyGems OTP token for 2FA |
| `--skip-LANG` | Skip specific language (npm, python, ruby, rust, php, go, csharp, java) |

## Version Management

### How Version Numbers Work
The system uses the **highest version number** from all package files as the unified version:

- **JavaScript**: `js_grim/package.json` → `"version": "1.0.29"`
- **Python**: `py_grim/setup.py` → `version="1.0.9"`
- **Ruby**: RubyGems registry → `1.0.5` (published version)
- **Rust**: `rs_grim/Cargo.toml` → `version = "1.0.3"`
- **PHP**: `php_grim/composer.json` → No version field (uses latest from other packages)
- **Go**: `go_grim/version.go` → `Version = "1.0.2"`
- **C#**: `cs_grim/GrimReaper.csproj` → `<PackageVersion>1.0.4</PackageVersion>`
- **Java**: `java_grim/pom.xml` → `<version>1.0.2</version>`

**Current Unified Version**: 1.0.29 (from JavaScript package)

### Automatic Version
By default, the script uses the version from `grim-config.json`:
```bash
./grim.sh all  # Uses version from config
```

### Manual Version Override
You can override the version in three ways:

1. **Command line** (highest priority):
   ```bash
   ./grim.sh all -v 1.0.30
   ```

2. **Config override** (permanent override):
   ```json
   "version": {
     "override": "1.0.30"  // This version will always be used
   }
   ```

3. **Update config version**:
   ```bash
   # Edit grim-config.json and change "current" version
   ```

## Deployment Order

Packages are deployed in this order (as requested):
1. **npm** (with OTP if provided)
2. **RubyGems** (with OTP if provided)  
3. **PyPI**
4. **crates.io**
5. Everything else (PHP, Go, C#, Java)

## Credentials Setup

Before deploying, ensure you have credentials set up:

```bash
# NPM
npm login

# PyPI
# Create ~/.pypirc or set TWINE_USERNAME/TWINE_PASSWORD

# RubyGems  
gem signin

# Crates.io
cargo login

# NuGet
export NUGET_API_KEY="your-key"
```

## Logs and Reports

All operations are logged to:
- Build logs: `/opt/reaper/pkg/logs/grim-TIMESTAMP.log`
- Summary reports: `/opt/reaper/pkg/logs/ACTION-summary-TIMESTAMP.txt`

## Version History

The system automatically tracks version history in the config file:
```json
"history": [
  {
    "version": "2024.12.19",
    "date": "2024-12-19T10:00:00Z", 
    "notes": "Initial unified build/deploy system"
  }
]
```

## Troubleshooting

### Missing Dependencies
```bash
# Install jq (required)
sudo apt-get install jq
```

### Package Not Found
Ensure your package directories exist at:
```
/opt/reaper/pkg/js_grim/
/opt/reaper/pkg/py_grim/
/opt/reaper/pkg/rb_grim/
# etc...
```

### Deployment Fails
1. Check credentials are set up
2. Use `--dry-run` to test first
3. Check logs in `/opt/reaper/pkg/logs/`
4. For 2FA registries, use `--otp-npm` or `--otp-ruby`

### Version Already Published
The script will warn but continue if a version is already published.

## Migration from Old Scripts

1. Replace `build.sh` and `deploy.sh` with `grim.sh`
2. Create `grim-config.json` in the same directory
3. Update any automation to use the new commands:
   - `./build.sh` → `./grim.sh build`
   - `./deploy.sh` → `./grim.sh deploy`
   - Both → `./grim.sh all`