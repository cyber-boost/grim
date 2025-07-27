#!/bin/bash

# Grim Docs - Advanced Documentation and User Guides
# Provides comprehensive documentation for the Grimm system with integration capabilities

# Source reaper.sh for utilities and colors
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GRIM_ROOT="${GRIM_ROOT:-$(dirname "$SCRIPT_DIR")}"
source "$GRIM_ROOT/reaper.sh" 2>/dev/null || source /opt/grim/reaper.sh 2>/dev/null

DOCS_VERSION="2.0.0"
DOCS_CONFIG="${GRIM_CONFIG_DIR}/docs.tsk"
DOCS_DIR="${GRIM_ROOT}/docs"
DOCS_TEMPLATES="${GRIM_ROOT}/docs/templates"
DOCS_OUTPUT="${GRIM_ROOT}/docs/output"

# Initialize documentation system
init_docs() {
    echo "${CYAN}Initializing documentation system...${RESET}"
    
    # Create documentation directories
    mkdir -p "$DOCS_DIR" "$DOCS_TEMPLATES" "$DOCS_OUTPUT"
    
    # Create documentation structure
    create_docs_structure
    
    # Generate initial documentation
    generate_all_docs
    
    echo "${GREEN}✓ Documentation system initialized${RESET}"
}

create_docs_structure() {
    # Create main documentation files
    cat > "$DOCS_DIR/README.md" <<'EOF'
# Grim Documentation

Welcome to the Grim system documentation. This comprehensive guide covers all aspects of the Grim backup and management system.

## Quick Start

1. [Installation Guide](installation.md)
2. [User Guide](user-guide.md)
3. [API Reference](api-reference.md)
4. [Configuration](configuration.md)
5. [Troubleshooting](troubleshooting.md)

## Modules

- [Monitor Module](modules/monitor.md) - Real-time filesystem monitoring
- [Health Module](modules/health.md) - System health checks
- [Compress Module](modules/compress.md) - Advanced compression
- [Scythe Module](modules/scythe.md) - License protection
- [Security Module](modules/security.md) - Security integration
- [Install Module](modules/install.md) - Installation management
- [Docs Module](modules/docs.md) - Documentation system

## Support

For support and questions, please refer to the [Troubleshooting](troubleshooting.md) guide or contact the development team.
EOF

    # Create module documentation directory
    mkdir -p "$DOCS_DIR/modules"
    
    # Create templates directory
    mkdir -p "$DOCS_TEMPLATES"
    
    # Create output directories
    mkdir -p "$DOCS_OUTPUT/html" "$DOCS_OUTPUT/pdf" "$DOCS_OUTPUT/man"
}

# Generate documentation for all modules
generate_all_docs() {
    echo "${CYAN}Generating documentation for all modules...${RESET}"
    
    # Generate module documentation
    generate_module_docs "monitor"
    generate_module_docs "health"
    generate_module_docs "compress"
    generate_module_docs "scythe"
    generate_module_docs "security"
    generate_module_docs "install"
    generate_module_docs "docs"
    
    # Generate main documentation
    generate_main_docs
    
    # Generate API documentation
    generate_api_docs
    
    # Generate configuration documentation
    generate_config_docs
    
    echo "${GREEN}✓ All documentation generated${RESET}"
}

# Generate documentation for a specific module
generate_module_docs() {
    local module_name="$1"
    local module_file="$GRIM_ROOT/modules/${module_name}.sh"
    local doc_file="$DOCS_DIR/modules/${module_name}.md"
    
    echo "  Generating documentation for $module_name..."
    
    if [[ ! -f "$module_file" ]]; then
        echo "${YELLOW}⚠ Module file not found: $module_file${RESET}"
        return 1
    fi
    
    # Extract module information
    local version=$(grep -E "^${module_name^^}_VERSION=" "$module_file" | cut -d'"' -f2 2>/dev/null || echo "1.0.0")
    local description=$(grep -E "^#.*${module_name^}" "$module_file" | head -1 | sed 's/^# //' 2>/dev/null || echo "Grim $module_name module")
    
    # Generate module documentation
    cat > "$doc_file" <<EOF
# $module_name Module

$description

## Version

$version

## Overview

$(extract_module_overview "$module_file")

## Commands

$(extract_module_commands "$module_file")

## Configuration

$(extract_module_config "$module_file")

## Examples

$(extract_module_examples "$module_file")

## Troubleshooting

$(extract_module_troubleshooting "$module_file")

## API Reference

$(extract_module_api "$module_file")
EOF
    
    echo "    ✓ Documentation generated: $doc_file"
}

# Extract module overview from source code
extract_module_overview() {
    local module_file="$1"
    
    # Extract comments between module header and first function
    local overview=$(sed -n '/^#/,/^[^#]/p' "$module_file" | head -20 | grep -E "^# " | sed 's/^# //' | head -5)
    
    if [[ -n "$overview" ]]; then
        echo "$overview"
    else
        echo "This module provides functionality for the Grim system."
    fi
}

# Extract module commands from source code
extract_module_commands() {
    local module_file="$1"
    
    # Extract command patterns from case statement
    local commands=$(grep -A 50 "case.*help" "$module_file" | grep -E "^\s*[a-zA-Z_][a-zA-Z0-9_]*\)" | sed 's/^\s*//' | sed 's/)$//' | head -10)
    
    if [[ -n "$commands" ]]; then
        echo "| Command | Description |"
        echo "|---------|-------------|"
        echo "$commands" | while read -r cmd; do
            case "$cmd" in
                init) echo "| \`$cmd\` | Initialize module |" ;;
                start) echo "| \`$cmd\` | Start module operation |" ;;
                stop) echo "| \`$cmd\` | Stop module operation |" ;;
                status) echo "| \`$cmd\` | Show module status |" ;;
                report) echo "| \`$cmd\` | Generate report |" ;;
                help) echo "| \`$cmd\` | Show help information |" ;;
                *) echo "| \`$cmd\` | Module command |" ;;
            esac
        done
    else
        echo "No specific commands documented."
    fi
}

# Extract module configuration from source code
extract_module_config() {
    local module_file="$1"
    
    # Extract configuration variables
    local config_vars=$(grep -E "^[A-Z_]+=" "$module_file" | head -10)
    
    if [[ -n "$config_vars" ]]; then
        echo "| Variable | Default | Description |"
        echo "|----------|---------|-------------|"
        echo "$config_vars" | while read -r var; do
            local name=$(echo "$var" | cut -d'=' -f1)
            local value=$(echo "$var" | cut -d'=' -f2- | sed 's/"//g')
            echo "| \`$name\` | \`$value\` | Configuration setting |"
        done
    else
        echo "No configuration variables documented."
    fi
}

# Extract module examples from source code
extract_module_examples() {
    local module_file="$1"
    
    # Look for example patterns in comments
    local examples=$(grep -A 5 -B 5 "Examples:" "$module_file" | grep -E "^# " | sed 's/^# //' | head -10)
    
    if [[ -n "$examples" ]]; then
        echo "\`\`\`bash"
        echo "$examples"
        echo "\`\`\`"
    else
        echo "See the module help for usage examples."
    fi
}

# Extract module troubleshooting from source code
extract_module_troubleshooting() {
    local module_file="$1"
    
    # Look for error handling patterns
    local errors=$(grep -E "Error:|ERROR:" "$module_file" | head -5)
    
    if [[ -n "$errors" ]]; then
        echo "### Common Issues"
        echo ""
        echo "$errors" | while read -r error; do
            echo "- **Issue**: $error"
            echo "  - **Solution**: Check configuration and permissions"
            echo ""
        done
    else
        echo "No specific troubleshooting information available."
    fi
}

# Extract module API from source code
extract_module_api() {
    local module_file="$1"
    
    # Extract function definitions
    local functions=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$module_file" | head -10)
    
    if [[ -n "$functions" ]]; then
        echo "### Functions"
        echo ""
        echo "$functions" | while read -r func; do
            local func_name=$(echo "$func" | sed 's/()//')
            echo "- \`$func_name()\` - Module function"
        done
    else
        echo "No API functions documented."
    fi
}

# Generate main documentation files
generate_main_docs() {
    echo "  Generating main documentation..."
    
    # Installation guide
    cat > "$DOCS_DIR/installation.md" <<'EOF'
# Installation Guide

## Prerequisites

- Linux operating system (Ubuntu 18.04+, CentOS 7+, or similar)
- Bash shell
- SQLite3
- curl
- wget
- jq
- openssl

## Quick Installation

```bash
# Download and run installation script
curl -sSL https://grim.so/install.sh | sudo bash

# Or using wget
wget -qO- https://grim.so/install.sh | sudo bash
```

## Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/grim-project/grim.git /opt/grim
cd /opt/grim
```

2. Run the installation script:
```bash
sudo ./install.sh
```

3. Initialize the system:
```bash
grim init
```

## Configuration

After installation, configure the system:

```bash
# Edit main configuration
nano /opt/grim/config/grim.tsk

# Initialize modules
grim monitor init
grim health init
grim security init
```

## Verification

Verify the installation:

```bash
# Check system status
grim status

# Test modules
grim monitor status
grim health check
```

## Next Steps

- Read the [User Guide](user-guide.md)
- Configure [Security](modules/security.md)
- Set up [Monitoring](modules/monitor.md)
EOF

    # User guide
    cat > "$DOCS_DIR/user-guide.md" <<'EOF'
# User Guide

## Getting Started

The Grim system provides comprehensive backup and management capabilities. This guide will help you get started.

## Basic Commands

### System Status
```bash
# Check overall system status
grim status

# Check specific module status
grim monitor status
grim health status
```

### Monitoring
```bash
# Start monitoring
grim monitor start

# View monitoring events
grim monitor events

# Stop monitoring
grim monitor stop
```

### Health Checks
```bash
# Run health check
grim health check

# Start continuous monitoring
grim health monitor

# View health report
grim health report
```

### Compression
```bash
# Compress files
grim compress file.txt

# Decompress archive
grim compress decompress archive.tar.gz

# List archive contents
grim compress list archive.tar.gz
```

## Advanced Usage

### Security
```bash
# Initialize security
grim security init

# Grant permissions
grim security permission grant user backup * read

# Check SSL certificates
grim security ssl check
```

### Installation Management
```bash
# Install component
grim install grim 1.0.0 /opt/grim

# Deploy to multiple hosts
grim deploy create prod-001 production "host1,host2" "grim,scythe" admin
grim deploy execute prod-001
```

## Configuration

### Main Configuration
Edit `/opt/grim/config/grim.tsk`:

```yaml
grim:
  version: "1.0.0"
  log_level: "info"
  backup_retention: 30
  auto_update: true

modules:
  monitor: true
  health: true
  compress: true
  scythe: true
  security: true
```

### Module Configuration
Each module has its own configuration file in `/opt/grim/config/`.

## Best Practices

1. **Regular Backups**: Set up automated backup schedules
2. **Monitoring**: Enable monitoring for critical systems
3. **Security**: Configure proper permissions and SSL certificates
4. **Updates**: Keep the system updated regularly
5. **Documentation**: Document your configuration and procedures

## Troubleshooting

See the [Troubleshooting Guide](troubleshooting.md) for common issues and solutions.
EOF

    # API reference
    cat > "$DOCS_DIR/api-reference.md" <<'EOF'
# API Reference

## Overview

The Grim system provides a comprehensive API for integration and automation.

## Core API

### System Information
```bash
grim status                    # Get system status
grim version                   # Get version information
grim info                      # Get detailed system information
```

### Module Management
```bash
grim <module> init             # Initialize module
grim <module> status           # Get module status
grim <module> help             # Get module help
```

## Module APIs

### Monitor Module
```bash
grim monitor start [dir]       # Start monitoring directory
grim monitor stop              # Stop monitoring
grim monitor events            # List recent events
grim monitor watch <dir>       # Watch specific directory
```

### Health Module
```bash
grim health check              # Run health check
grim health monitor            # Start continuous monitoring
grim health report [type]      # Generate health report
grim health alert              # Configure alerts
```

### Compress Module
```bash
grim compress <file>           # Compress file
grim compress decompress <archive>  # Decompress archive
grim compress list <archive>   # List archive contents
grim compress test <archive>   # Test archive integrity
```

### Scythe Module
```bash
grim scythe install <dir> <id> <name>  # Install protection
grim scythe start <id>         # Start monitoring
grim scythe check              # Check for violations
grim scythe report [type]      # Generate violation report
```

### Security Module
```bash
grim security init             # Initialize security
grim security permission grant <user> <type> <id> <perm>  # Grant permission
grim security encrypt <input> <output> <key>  # Encrypt file
grim security ssl install <domain> <cert> <key>  # Install SSL certificate
```

### Install Module
```bash
grim install <component> <version> <path>  # Install component
grim deploy create <id> <env> <hosts> <comps> <by>  # Create deployment
grim update check <component>  # Check for updates
grim requirements <component>  # Check system requirements
```

## Configuration API

### Configuration Files
- `/opt/grim/config/grim.tsk` - Main configuration
- `/opt/grim/config/monitor.tsk` - Monitor configuration
- `/opt/grim/config/health.tsk` - Health configuration
- `/opt/grim/config/scythe.tsk` - Scythe configuration
- `/opt/grim/config/security.tsk` - Security configuration

### Configuration Format
All configuration files use the `.tsk` format:

```yaml
section:
  key: value
  nested:
    key: value
```

## Database API

### Database Locations
- `/opt/grim/db/grim.db` - Main database
- `/opt/grim/db/monitor.db` - Monitor database
- `/opt/grim/db/health.db` - Health database
- `/opt/grim/db/scythe.db` - Scythe database
- `/opt/grim/db/security.db` - Security database

### Database Access
```bash
# Access main database
sqlite3 /opt/grim/db/grim.db

# Access module database
sqlite3 /opt/grim/db/<module>.db
```

## Integration Examples

### Shell Integration
```bash
# Source Grim utilities
source /opt/grim/reaper.sh

# Use Grim functions
log_action "INFO" "Custom action"
show_status "Custom status"
```

### Script Integration
```bash
#!/bin/bash
# Custom script using Grim

source /opt/grim/reaper.sh

# Check system health
grim health check

# Backup if healthy
if [[ $? -eq 0 ]]; then
    grim backup create
fi
```

### Cron Integration
```cron
# Daily health check
0 2 * * * /opt/grim/health.sh check

# Weekly backup
0 3 * * 0 /opt/grim/backup.sh create

# Monthly cleanup
0 4 1 * * /opt/grim/cleanup.sh
```
EOF

    # Configuration guide
    cat > "$DOCS_DIR/configuration.md" <<'EOF'
# Configuration Guide

## Overview

The Grim system uses `.tsk` configuration files for all settings. This guide explains the configuration format and options.

## Configuration Format

### Basic Structure
```yaml
section:
  key: value
  nested:
    key: value
    list:
      - item1
      - item2
```

### Comments
```yaml
# This is a comment
section:
  key: value  # Inline comment
```

## Main Configuration

### Grim Configuration (`/opt/grim/config/grim.tsk`)
```yaml
grim:
  version: "1.0.0"
  install_path: "/opt/grim"
  log_level: "info"
  backup_retention: 30
  auto_update: true

modules:
  monitor: true
  health: true
  compress: true
  scythe: true
  security: true
  install: true

paths:
  config_dir: "/opt/grim/config"
  data_dir: "/opt/grim/db"
  log_dir: "/opt/grim/logs"
  backup_dir: "/opt/grim/backups"
  cache_dir: "/opt/grim/cache"
  run_dir: "/opt/grim/run"
```

## Module Configurations

### Monitor Configuration (`/opt/grim/config/monitor.tsk`)
```yaml
monitor:
  version: "1.0.0"
  enabled: true
  check_interval: 60
  log_events: true
  max_events: 1000

directories:
  - path: "/var/www"
    recursive: true
    events:
      - create
      - modify
      - delete
  - path: "/etc"
    recursive: false
    events:
      - modify

notifications:
  email: true
  webhook: "https://api.example.com/webhook"
  slack: "https://hooks.slack.com/services/..."
```

### Health Configuration (`/opt/grim/config/health.tsk`)
```yaml
health:
  version: "1.0.0"
  enabled: true
  check_interval: 300
  alert_threshold: 80

checks:
  cpu:
    enabled: true
    threshold: 90
    interval: 60
  memory:
    enabled: true
    threshold: 85
    interval: 60
  disk:
    enabled: true
    threshold: 90
    interval: 300
  network:
    enabled: true
    threshold: 1000
    interval: 60

alerts:
  email: true
  slack: true
  webhook: "https://api.example.com/alerts"
```

### Scythe Configuration (`/opt/grim/config/scythe.tsk`)
```yaml
scythe:
  version: "2.0.0"
  enabled: true
  mother_db_url: "https://api.grim.so/scythe"
  check_interval: 3600
  stealth_mode: true

protection:
  default_license_file: ".license"
  check_files: true
  check_processes: true
  integrity_check: true

monitoring:
  silent: true
  background: true
  retry_attempts: 3
  timeout: 30

notifications:
  channels:
    - grim_command
    - email
    - web_dashboard
```

### Security Configuration (`/opt/grim/config/security.tsk`)
```yaml
security:
  version: "1.0.0"
  enabled: true
  monitoring_interval: 300
  alert_threshold: 5

access_control:
  enabled: true
  default_permission: "deny"
  wildcard_support: true

encryption:
  default_algorithm: "aes256"
  key_rotation_days: 365
  auto_backup: true

ssl:
  auto_renew: true
  renewal_threshold: 30
  certbot_path: "/usr/bin/certbot"

audit:
  enabled: true
  retention_days: 90
  log_failed_attempts: true
```

## Environment Variables

You can override configuration values using environment variables:

```bash
export GRIM_LOG_LEVEL="debug"
export GRIM_BACKUP_RETENTION="60"
export GRIM_AUTO_UPDATE="false"
```

## Configuration Validation

Validate your configuration:

```bash
# Validate main configuration
grim config validate

# Validate module configuration
grim monitor config validate
grim health config validate
```

## Configuration Backup

Backup your configuration:

```bash
# Backup all configurations
grim config backup

# Restore configuration
grim config restore /path/to/backup
```

## Best Practices

1. **Use Comments**: Document your configuration choices
2. **Test Changes**: Validate configuration before applying
3. **Backup Configs**: Keep backups of working configurations
4. **Environment Variables**: Use for sensitive information
5. **Modular Configs**: Keep module configurations separate
6. **Version Control**: Track configuration changes
EOF

    # Troubleshooting guide
    cat > "$DOCS_DIR/troubleshooting.md" <<'EOF'
# Troubleshooting Guide

## Common Issues

### Installation Issues

#### Permission Denied
**Problem**: `Permission denied` errors during installation
**Solution**:
```bash
# Check permissions
ls -la /opt/grim

# Fix permissions
sudo chown -R root:root /opt/grim
sudo chmod -R 755 /opt/grim
```

#### Missing Dependencies
**Problem**: Module fails to start due to missing packages
**Solution**:
```bash
# Install required packages
sudo apt-get update
sudo apt-get install sqlite3 curl wget jq openssl

# Or on CentOS/RHEL
sudo yum install sqlite curl wget jq openssl
```

### Module Issues

#### Monitor Module
**Problem**: Monitor not detecting file changes
**Solution**:
```bash
# Check if inotify is available
ls /proc/sys/fs/inotify/

# Install inotify-tools if needed
sudo apt-get install inotify-tools

# Check monitor status
grim monitor status
```

#### Health Module
**Problem**: Health checks failing
**Solution**:
```bash
# Check system resources
grim health check --verbose

# Check specific component
grim health check cpu
grim health check memory
grim health check disk
```

#### Scythe Module
**Problem**: License validation failing
**Solution**:
```bash
# Check license file
cat .license

# Validate license manually
grim scythe validate <license_key>

# Check network connectivity
curl -I https://api.grim.so/scythe
```

#### Security Module
**Problem**: Permission denied errors
**Solution**:
```bash
# Check user permissions
grim security permission check <user> <type> <id> <perm>

# Grant necessary permissions
grim security permission grant <user> <type> <id> <perm>

# Check security status
grim security status
```

### Database Issues

#### Database Locked
**Problem**: `database is locked` errors
**Solution**:
```bash
# Check for running processes
ps aux | grep grim

# Kill stuck processes
sudo pkill -f grim

# Check database integrity
sqlite3 /opt/grim/db/grim.db "PRAGMA integrity_check;"
```

#### Database Corrupted
**Problem**: Database corruption errors
**Solution**:
```bash
# Create backup
cp /opt/grim/db/grim.db /opt/grim/db/grim.db.backup

# Recreate database
grim init

# Restore from backup if needed
sqlite3 /opt/grim/db/grim.db < /opt/grim/db/grim.db.backup
```

### Network Issues

#### API Connectivity
**Problem**: Cannot connect to Grim API
**Solution**:
```bash
# Test connectivity
curl -I https://api.grim.so

# Check DNS resolution
nslookup api.grim.so

# Check firewall
sudo iptables -L
```

#### SSL Certificate Issues
**Problem**: SSL certificate errors
**Solution**:
```bash
# Check certificate
openssl s_client -connect api.grim.so:443

# Update certificates
sudo update-ca-certificates

# Check system time
date
```

### Performance Issues

#### High CPU Usage
**Problem**: Grim using too much CPU
**Solution**:
```bash
# Check which module is using CPU
top -p $(pgrep -f grim)

# Adjust monitoring intervals
# Edit /opt/grim/config/monitor.tsk
# Increase check_interval values
```

#### High Memory Usage
**Problem**: Grim using too much memory
**Solution**:
```bash
# Check memory usage
free -h

# Check for memory leaks
grim health check memory --verbose

# Restart modules
grim monitor restart
grim health restart
```

#### Slow Performance
**Problem**: Grim operations are slow
**Solution**:
```bash
# Check disk I/O
iostat -x 1

# Check disk space
df -h

# Optimize database
sqlite3 /opt/grim/db/grim.db "VACUUM;"
sqlite3 /opt/grim/db/grim.db "ANALYZE;"
```

## Debug Mode

Enable debug mode for detailed logging:

```bash
# Enable debug logging
export GRIM_LOG_LEVEL="debug"

# Run command with debug output
grim <module> <command> --debug

# Check debug logs
tail -f /opt/grim/logs/grim.log
```

## Log Analysis

### Common Log Patterns

#### Error Patterns
```bash
# Find errors
grep -i error /opt/grim/logs/*.log

# Find warnings
grep -i warning /opt/grim/logs/*.log

# Find failed operations
grep -i fail /opt/grim/logs/*.log
```

#### Performance Patterns
```bash
# Find slow operations
grep "slow\|timeout" /opt/grim/logs/*.log

# Find high resource usage
grep "cpu\|memory\|disk" /opt/grim/logs/*.log
```

## Getting Help

### Self-Service
1. Check this troubleshooting guide
2. Review the [User Guide](user-guide.md)
3. Check the [API Reference](api-reference.md)
4. Enable debug mode and check logs

### Support Channels
- GitHub Issues: https://github.com/grim-project/grim/issues
- Documentation: https://grim.so/docs
- Community Forum: https://community.grim.so

### Information to Provide
When seeking help, provide:
1. Grim version: `grim version`
2. System information: `grim info`
3. Error messages and logs
4. Steps to reproduce the issue
5. Configuration files (sanitized)
EOF
}

# Generate API documentation
generate_api_docs() {
    echo "  Generating API documentation..."
    
    # This would typically parse the actual code to generate API docs
    # For now, we'll create a basic structure
    cat > "$DOCS_DIR/api.md" <<'EOF'
# API Documentation

## REST API

### Base URL
```
https://api.grim.so/v1
```

### Authentication
All API requests require authentication using API keys:

```
Authorization: Bearer YOUR_API_KEY
```

### Endpoints

#### System Status
```
GET /status
```

#### Health Check
```
GET /health
```

#### Backup Management
```
GET /backups
POST /backups
GET /backups/{id}
DELETE /backups/{id}
```

#### Monitoring
```
GET /monitor/events
POST /monitor/start
POST /monitor/stop
```

## WebSocket API

### Connection
```
wss://api.grim.so/ws
```

### Events
- `backup.completed`
- `backup.failed`
- `monitor.event`
- `health.alert`
- `security.violation`

## SDK Libraries

### Python SDK
```python
from grim import GrimClient

client = GrimClient(api_key=os.getenv('GRIM_API_KEY', 'YOUR_API_KEY'))
status = client.get_status()
```

### JavaScript SDK
```javascript
const GrimClient = require('grim-sdk');

const client = new GrimClient('YOUR_API_KEY');
const status = await client.getStatus();
```

### Go SDK
```go
import "github.com/grim-project/grim-sdk-go"

client := grim.NewClient("YOUR_API_KEY")
status, err := client.GetStatus()
```
EOF
}

# Generate configuration documentation
generate_config_docs() {
    echo "  Generating configuration documentation..."
    
    # This would typically parse actual configuration files
    # For now, we'll create a basic structure
    cat > "$DOCS_DIR/config-reference.md" <<'EOF'
# Configuration Reference

## Configuration Files

### Main Configuration
- **File**: `/opt/grim/config/grim.tsk`
- **Purpose**: Main system configuration
- **Format**: TSK (Tusk Configuration)

### Module Configurations
- **Monitor**: `/opt/grim/config/monitor.tsk`
- **Health**: `/opt/grim/config/health.tsk`
- **Scythe**: `/opt/grim/config/scythe.tsk`
- **Security**: `/opt/grim/config/security.tsk`

## Configuration Format

### TSK Format
The TSK (Tusk) format is a simple, hierarchical configuration format:

```yaml
section:
  key: value
  nested:
    key: value
    list:
      - item1
      - item2
```

### Environment Variables
Configuration can be overridden using environment variables:

```bash
export GRIM_LOG_LEVEL="debug"
export GRIM_BACKUP_RETENTION="60"
```

## Configuration Validation

### Validate Configuration
```bash
grim config validate
```

### Check Configuration
```bash
grim config check
```

### Backup Configuration
```bash
grim config backup
```

### Restore Configuration
```bash
grim config restore /path/to/backup
```
EOF
}

# Build documentation in different formats
build_docs() {
    local format="${1:-html}"
    
    echo "${CYAN}Building documentation in $format format...${RESET}"
    
    case "$format" in
        html)
            build_html_docs
            ;;
        pdf)
            build_pdf_docs
            ;;
        man)
            build_man_docs
            ;;
        *)
            echo "${RED}Unknown format: $format${RESET}"
            return 1
            ;;
    esac
}

build_html_docs() {
    echo "  Building HTML documentation..."
    
    # Create HTML template
    cat > "$DOCS_TEMPLATES/html_template.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Grim Documentation</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        h2 { color: #666; margin-top: 30px; }
        code { background: #f4f4f4; padding: 2px 4px; border-radius: 3px; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Grim Documentation</h1>
    <div id="content">
        <!-- Content will be inserted here -->
    </div>
</body>
</html>
EOF
    
    # Convert markdown to HTML (simplified)
    for md_file in "$DOCS_DIR"/*.md; do
        if [[ -f "$md_file" ]]; then
            local basename=$(basename "$md_file" .md)
            local html_file="$DOCS_OUTPUT/html/${basename}.html"
            
            # Create HTML file with template
            sed 's|<!-- Content will be inserted here -->|CONTENT_PLACEHOLDER|' "$DOCS_TEMPLATES/html_template.html" > "$html_file.tmp"
            
            # Convert markdown to simple HTML
            {
                echo "<div class=\"content\">"
                sed -e 's/^# \(.*\)/<h1>\1<\/h1>/' \
                    -e 's/^## \(.*\)/<h2>\1<\/h2>/' \
                    -e 's/^### \(.*\)/<h3>\1<\/h3>/' \
                    -e 's/`\([^`]*\)`/<code>\1<\/code>/g' \
                    -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
                    -e 's/\*\([^*]*\)\*/<em>\1<\/em>/g' \
                    -e 's/^$/&<br>/' "$md_file"
                echo "</div>"
            } > "$html_file.content"
            
            # Replace placeholder with content
            sed '/CONTENT_PLACEHOLDER/r '"$html_file.content" "$html_file.tmp" | sed '/CONTENT_PLACEHOLDER/d' > "$html_file"
            
            # Clean up temporary files
            rm -f "$html_file.tmp" "$html_file.content"
            
            echo "    ✓ Generated: $html_file"
        fi
    done
    
    # Convert module documentation
    mkdir -p "$DOCS_OUTPUT/html/modules"
    for md_file in "$DOCS_DIR/modules"/*.md; do
        if [[ -f "$md_file" ]]; then
            local basename=$(basename "$md_file" .md)
            local html_file="$DOCS_OUTPUT/html/modules/${basename}.html"
            
            # Create HTML file with template
            sed 's|<!-- Content will be inserted here -->|CONTENT_PLACEHOLDER|' "$DOCS_TEMPLATES/html_template.html" > "$html_file.tmp"
            
            # Convert markdown to simple HTML
            {
                echo "<div class=\"content\">"
                sed -e 's/^# \(.*\)/<h1>\1<\/h1>/' \
                    -e 's/^## \(.*\)/<h2>\1<\/h2>/' \
                    -e 's/^### \(.*\)/<h3>\1<\/h3>/' \
                    -e 's/`\([^`]*\)`/<code>\1<\/code>/g' \
                    -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
                    -e 's/\*\([^*]*\)\*/<em>\1<\/em>/g' \
                    -e 's/^$/&<br>/' "$md_file"
                echo "</div>"
            } > "$html_file.content"
            
            # Replace placeholder with content
            sed '/CONTENT_PLACEHOLDER/r '"$html_file.content" "$html_file.tmp" | sed '/CONTENT_PLACEHOLDER/d' > "$html_file"
            
            # Clean up temporary files
            rm -f "$html_file.tmp" "$html_file.content"
            
            echo "    ✓ Generated: $html_file"
        fi
    done
    
    echo "${GREEN}✓ HTML documentation built${RESET}"
}

build_pdf_docs() {
    echo "  Building PDF documentation..."
    
    # Check if pandoc is available
    if ! command -v pandoc >/dev/null 2>&1; then
        echo "${YELLOW}⚠ pandoc not available, skipping PDF generation${RESET}"
        return 1
    fi
    
    # Convert markdown to PDF
    for md_file in "$DOCS_DIR"/*.md; do
        if [[ -f "$md_file" ]]; then
            local basename=$(basename "$md_file" .md)
            local pdf_file="$DOCS_OUTPUT/pdf/${basename}.pdf"
            
            pandoc "$md_file" -o "$pdf_file" --pdf-engine=xelatex
            
            echo "    ✓ Generated: $pdf_file"
        fi
    done
    
    echo "${GREEN}✓ PDF documentation built${RESET}"
}

build_man_docs() {
    echo "  Building man page documentation..."
    
    # Create man pages for each module
    for module in monitor health compress scythe security install; do
        local man_file="$DOCS_OUTPUT/man/grim-${module}.1"
        
        cat > "$man_file" <<EOF
.TH GRIM-$module 1 "$(date +%Y-%m-%d)" "Grim System" "User Commands"

.SH NAME
grim-$module \- Grim $module module

.SH SYNOPSIS
.B grim $module
[\fIcommand\fR] [\fIoptions\fR]

.SH DESCRIPTION
The grim-$module module provides $module functionality for the Grim system.

.SH COMMANDS
.TP
.B init
Initialize the $module module
.TP
.B status
Show $module status
.TP
.B help
Show help information

.SH EXAMPLES
.TP
Initialize the module:
.B grim $module init
.TP
Check status:
.B grim $module status

.SH FILES
.TP
.I /opt/grim/config/$module.tsk
Configuration file
.TP
.I /opt/grim/db/$module.db
Database file
.TP
.I /opt/grim/logs/$module.log
Log file

.SH SEE ALSO
.BR grim (1)
.br
Full documentation at: https://grim.so/docs/modules/$module.html

.SH AUTHOR
Grim Development Team
EOF
        
        echo "    ✓ Generated: $man_file"
    done
    
    echo "${GREEN}✓ Man page documentation built${RESET}"
}

# Serve documentation locally
serve_docs() {
    local port="${1:-8080}"
    
    echo "${CYAN}Serving documentation on port $port...${RESET}"
    
    # Check if Python is available
    if command -v python3 >/dev/null 2>&1; then
        cd "$DOCS_OUTPUT/html"
        python3 -m http.server "$port"
    elif command -v python >/dev/null 2>&1; then
        cd "$DOCS_OUTPUT/html"
        python -m SimpleHTTPServer "$port"
    else
        echo "${RED}Error: Python not available for serving documentation${RESET}"
        return 1
    fi
}

# Display help
help() {
    cat <<EOF
${GREEN}Grim Docs v$DOCS_VERSION - Documentation and User Guides${RESET}

Usage: $0 [command] [options]

Commands:
  init                                           Initialize documentation system
  generate [module]                              Generate documentation
  build [format]                                 Build documentation
  serve [port]                                   Serve documentation locally
  update                                         Update documentation
  
Formats:
  html                                          HTML documentation
  pdf                                           PDF documentation
  man                                           Man pages

Options:
  -h, --help                Show this help message
  -v, --verbose             Verbose output
  -d, --debug               Debug mode

Examples:
  $0 init
  $0 generate
  $0 build html
  $0 serve 8080
  
Documentation Features:
  - Comprehensive user guides
  - API reference documentation
  - Configuration guides
  - Troubleshooting guides
  - Multiple output formats
  - Local documentation server
  - Auto-generated module docs
EOF
}

# Main command handler
case "${1:-help}" in
    init)
        init_docs
        ;;
    generate)
        if [[ -n "${2:-}" ]]; then
            generate_module_docs "$2"
        else
            generate_all_docs
        fi
        ;;
    build)
        build_docs "${2:-}"
        ;;
    serve)
        serve_docs "${2:-}"
        ;;
    update)
        generate_all_docs
        build_docs html
        echo "${GREEN}✓ Documentation updated${RESET}"
        ;;
    help|-h|--help)
        help
        ;;
    *)
        echo "${RED}Unknown command: $1${RESET}"
        help
        exit 1
        ;;
esac 