# Grim Reaper PHP Package

🗡️ Advanced backup, monitoring, and system management toolkit for PHP applications.

[![Packagist Version](https://img.shields.io/packagist/v/grim-reaper/grim-reaper.svg)](https://packagist.org/packages/grim-reaper/grim-reaper)
[![Packagist Downloads](https://img.shields.io/packagist/dt/grim-reaper/grim-reaper.svg)](https://packagist.org/packages/grim-reaper/grim-reaper)

## Overview

Grim Reaper is a comprehensive system management toolkit that provides advanced backup, monitoring, security, and optimization capabilities. This PHP package provides a complete wrapper around the Grim Reaper system, making it easy to integrate into PHP applications and deploy via Composer.

## Features

- **Advanced Backup System**: Full, incremental, and differential backups with compression
- **Real-time Monitoring**: File system monitoring with intelligent change detection
- **Security Tools**: Encryption, vulnerability scanning, and quarantine systems
- **AI-Powered Analysis**: Machine learning-based decision making and optimization
- **Performance Optimization**: System tuning and resource management
- **Emergency Recovery**: Rapid disaster recovery and system restoration
- **Web Interface**: Modern web-based management dashboard

## Requirements

- PHP 8.1 or higher
- Linux operating system (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Required PHP extensions: `json`, `curl`, `openssl`, `zip`
- System commands: `rsync`, `tar`, `gzip`, `curl`, `wget`
- Go programming language (automatically installed)

## Installation

### Via Composer (Recommended)

```bash
# Install globally
composer global require grim-reaper/grim-reaper

# Or install in your project
composer require grim-reaper/grim-reaper
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/cyber-boost/grim.git
cd grim

# Install dependencies
./install_php_dependencies.sh

# Install Composer dependencies
composer install
```

## Quick Start

```bash
# Check if Grim Reaper is properly installed
grim check-deps

# Run initial setup
grim setup

# Check system health
grim health

# Start monitoring a directory
grim monitor /path/to/monitor

# Create a backup
grim backup /path/to/backup

# View system status
grim status
```

## Usage

### Basic Commands

```bash
# System health and status
grim health              # Check all systems health
grim status              # Overall system status
grim doctor              # Diagnose installation issues

# Backup operations
grim backup /data        # Create backup of directory
grim backup-list         # List available backups
grim backup-verify       # Verify backup integrity
grim restore backup-name # Restore from backup

# Monitoring
grim monitor /path       # Start monitoring directory
grim monitor-status      # Check monitoring status
grim monitor-events      # View monitoring events

# Security
grim security-audit      # Run security audit
grim security-encrypt    # Encrypt files
grim security-scan       # Scan for vulnerabilities

# System optimization
grim optimize-all        # Optimize all systems
grim optimize-storage    # Optimize storage usage
grim optimize-performance # Optimize performance
```

### Advanced Commands

```bash
# AI and machine learning
grim ai-analyze /path    # Analyze with AI
grim ai-recommend        # Get AI recommendations
grim ai-train model      # Train AI models

# Emergency operations
grim emergency-heal      # Emergency system healing
grim emergency-isolate   # Isolate suspicious files
grim emergency-restore   # Emergency restore

# Reporting and analytics
grim report-daily        # Daily system report
grim report-backup       # Backup report
grim report-security     # Security report
grim report-performance  # Performance report
```

## Configuration

The PHP package automatically creates a configuration file at `config/grim.json`:

```json
{
    "version": "1.0.0",
    "grim_root": "/path/to/grim/reaper",
    "backup_path": "/path/to/grim/reaper/backups",
    "log_path": "/path/to/grim/reaper/logs",
    "temp_path": "/path/to/grim/reaper/temp"
}
```

## PHP Integration

### Using in PHP Applications

```php
<?php

use GrimReaper\GrimCLI;

// Create CLI instance
$grim = new GrimCLI();

// Run commands programmatically
$exitCode = $grim->run(['grim', 'health']);
$exitCode = $grim->run(['grim', 'backup', '/data']);
$exitCode = $grim->run(['grim', 'monitor', '/path']);
```

### Composer Scripts

Add these scripts to your `composer.json`:

```json
{
    "scripts": {
        "grim:health": "grim health",
        "grim:backup": "grim backup",
        "grim:monitor": "grim monitor",
        "grim:setup": "grim setup",
        "grim:check-deps": "grim check-deps"
    }
}
```

Then run:

```bash
composer run grim:health
composer run grim:backup /data
```

## Automatic Dependency Management

The PHP package automatically handles all dependencies:

- **System Dependencies**: rsync, tar, gzip, curl, wget, etc.
- **PHP Extensions**: json, curl, openssl, zip
- **Go Language**: Automatic installation and PATH configuration
- **Composer**: Package dependency resolution

### Dependency Installation

Dependencies are automatically installed during:

1. **Composer Installation**: Post-install hooks run automatically
2. **First Use**: `grim setup` automatically checks and installs missing deps
3. **Manual Commands**: `grim install-deps` for explicit installation

## Troubleshooting

### Common Issues

1. **"Grim command not found"**
   ```bash
   # Run setup to create symlinks
   grim setup
   
   # Or manually create symlink
   sudo ln -sf /path/to/grim-reaper/bin/grim /usr/local/bin/grim
   ```

2. **"PHP extension not loaded"**
   ```bash
   # Install missing extensions
   sudo apt install php-json php-curl php-openssl php-zip
   ```

3. **"Go not found"**
   ```bash
   # Install Go manually
   ./install_php_dependencies.sh
   ```

4. **"Permission denied"**
   ```bash
   # Fix permissions
   sudo chown -R $USER:$USER /path/to/grim-reaper
   chmod +x /path/to/grim-reaper/bin/grim
   ```

### Getting Help

```bash
# Show help
grim help

# Check dependencies
grim check-deps

# Diagnose issues
grim doctor

# View logs
tail -f /path/to/grim-reaper/logs/grim.log
```

## Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/cyber-boost/grim.git
cd grim

# Install development dependencies
composer install

# Run tests
composer test

# Run static analysis
composer stan
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Documentation**: https://grim.so/docs
- **Issues**: https://github.com/cyber-boost/grim/issues
- **Discussions**: https://github.com/cyber-boost/grim/discussions
- **Email**: support@grim.so

## Changelog

### v1.0.0
- Initial PHP package release
- Complete CLI wrapper implementation
- Automatic dependency installation
- Composer integration
- Packagist deployment ready

---

**Grim Reaper** - Advanced system management for the modern era.
