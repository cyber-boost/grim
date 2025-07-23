# Grim Reaper PHP Package

[![Packagist](https://img.shields.io/packagist/v/grim-reaper/grim-reaper.svg)](https://packagist.org/packages/grim-reaper/grim-reaper)
[![Packagist Downloads](https://img.shields.io/packagist/dt/grim-reaper/grim-reaper.svg)](https://packagist.org/packages/grim-reaper/grim-reaper)
[![License](https://img.shields.io/packagist/l/grim-reaper/grim-reaper.svg)](https://packagist.org/packages/grim-reaper/grim-reaper)

**Enhanced PHP Package for Grim Reaper - Advanced backup, monitoring, and system management toolkit with comprehensive PHP development features.**

## 🚀 Features

### 🐘 PHP-Specific Commands (20+ New Commands)
- **`php-setup`** - Complete PHP environment setup and configuration
- **`php-analyze`** - Code quality analysis (PHPStan, Psalm, PHPMD)
- **`php-optimize`** - Performance optimization (OpCache, Composer autoloader)
- **`php-security`** - Security audits and vulnerability scanning
- **`php-test`** - PHPUnit test execution and management
- **`php-lint`** - Syntax and PSR-12 style checking
- **`php-deps`** - Dependency analysis and updates
- **`php-deploy`** - Production deployment with automatic backups
- **`php-monitor`** - Real-time PHP application monitoring
- **`php-backup`** - Application + database backup
- **`php-restore`** - Complete application restoration
- **`php-cache`** - OpCache and cache management
- **`php-logs`** - Error log management and analysis
- **`php-composer`** - Composer operations wrapper
- **`php-extensions`** - PHP extension management
- **`php-versions`** - Multiple PHP version management
- **`php-fpm`** - PHP-FPM service management
- **`php-nginx`** - Nginx + PHP configuration
- **`php-apache`** - Apache + PHP configuration
- **`php-docker`** - Docker PHP operations
- **`php-k8s`** - Kubernetes PHP operations

### 🔧 Core Grim Reaper Features (All Original Commands Work)
- **Backup System** - Full, incremental, differential backups
- **Monitoring** - System health, performance, file monitoring
- **Security** - Encryption, quarantine, vulnerability scanning
- **AI/ML** - Decision engine, recommendations, predictions
- **Emergency** - Emergency heal, isolate, restore
- **Build/Deploy** - Build management, deployment automation
- **Web Interface** - Admin web interface
- **Reporting** - All reports and analytics

### 🌍 Cross-Platform & Portable
- **Dynamic Path Detection** - No hardcoded paths, works anywhere
- **Multi-User Support** - Works for root and regular users
- **Cross-Platform** - Linux, macOS, Windows (WSL)
- **Portable Installation** - Any directory structure

## 📋 Requirements

- **PHP**: 8.1 or higher
- **Operating System**: Linux (Ubuntu/Debian, CentOS/RHEL), macOS, Windows (WSL)
- **PHP Extensions**: json, curl, openssl, zip, mbstring, xml, opcache
- **System Commands**: composer, git, curl, wget, tar, gzip
- **Optional**: Go (for compression features)

## 🛠️ Installation

### Via Composer (Recommended)

```bash
# Global installation
composer global require grim-reaper/grim-reaper

# Or project-specific installation
composer require grim-reaper/grim-reaper
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/cyber-boost/grim.git
cd grim/php_grim

# Install system dependencies
./install_php_dependencies.sh

# Install Composer dependencies
composer install
```

## 🚀 Quick Start

```bash
# Setup PHP environment
grim php-setup

# Analyze PHP code quality
grim php-analyze /path/to/your/app

# Deploy PHP application
grim php-deploy /path/to/your/app

# Monitor PHP application
grim php-monitor /path/to/your/app
```

## 📖 Usage

### PHP Development Commands

```bash
# Code Quality & Analysis
grim php-analyze /app          # Run PHPStan, Psalm, PHPMD
grim php-lint /app             # Syntax and PSR-12 checking
grim php-test /app             # Run PHPUnit tests
grim php-deps /app             # Analyze dependencies

# Performance & Optimization
grim php-optimize /app         # Optimize OpCache and Composer
grim php-cache clear           # Clear PHP caches
grim php-cache status          # Check OpCache status

# Security
grim php-security /app         # Security audit
grim php-logs analyze          # Analyze error logs

# Deployment
grim php-deploy /app           # Deploy with backup
grim php-backup /app           # Backup app + database
grim php-restore backup-name   # Restore from backup

# Monitoring
grim php-monitor /app          # Real-time monitoring
grim php-fpm status            # Check PHP-FPM status
grim php-nginx status          # Check Nginx status

# Container Operations
grim php-docker build          # Build Docker image
grim php-docker run            # Run Docker container
grim php-k8s deploy            # Deploy to Kubernetes
```

### Core Grim Reaper Commands (All Work)

```bash
# System Health
grim health                    # Check system health
grim status                    # Overall system status

# Backup Operations
grim backup /data             # Backup directory
grim backup-full /data        # Full backup
grim backup-incremental /data # Incremental backup

# Monitoring
grim monitor /path            # Monitor directory
grim monitor-start /path      # Start monitoring
grim monitor-status           # Check monitoring status

# Security
grim security-audit           # Security audit
grim security-encrypt /file   # Encrypt file
grim quarantine-isolate /file # Isolate suspicious file

# AI & Machine Learning
grim ai-analyze /path         # AI analysis
grim ai-recommend             # Get recommendations
grim smart-suggestions        # Smart suggestions

# Emergency Operations
grim emergency-heal           # Emergency system heal
grim emergency-restore backup # Emergency restore
```

## 🔧 PHP Integration

### Using in PHP Code

```php
<?php

use GrimReaper\GrimCLI;
use GrimReaper\Installer;

// Initialize Grim Reaper
$grim = new GrimCLI();

// Setup environment
$installer = new Installer();
$installer->setupEnvironment();

// Get installation status
$status = $installer->getStatus();
print_r($status);
```

### Composer Scripts

```json
{
    "scripts": {
        "grim-setup": "GrimReaper\\Installer::installDependencies",
        "grim-analyze": "grim php-analyze src/",
        "grim-test": "grim php-test .",
        "grim-deploy": "grim php-deploy ."
    }
}
```

## 🏗️ Automatic Dependency Management

The package automatically:

- **Detects and installs** missing PHP extensions
- **Downloads and configures** Composer
- **Installs development tools** (PHPUnit, PHPStan, PHPCS, PHPMD, Psalm)
- **Configures PHP settings** for optimal performance
- **Sets up environment** variables and directories
- **Manages system dependencies** (Ubuntu/Debian, CentOS/RHEL)

## 🔍 Troubleshooting

### Common Issues

```bash
# Check installation status
grim php-setup

# Verify PHP extensions
grim php-extensions

# Check PHP version
php -v

# Verify Composer
composer --version

# Check Grim Reaper installation
grim status
```

### Logs and Debugging

```bash
# View PHP error logs
grim php-logs show

# Analyze error patterns
grim php-logs analyze

# Clear logs
grim php-logs clear
```

## 🛠️ Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/cyber-boost/grim.git
cd grim/php_grim

# Install dependencies
composer install

# Run tests
composer test

# Build package
./phpgrim.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [https://grim.so](https://grim.so)
- **Issues**: [GitHub Issues](https://github.com/cyber-boost/grim/issues)
- **Discussions**: [GitHub Discussions](https://github.com/cyber-boost/grim/discussions)

## 📈 Changelog

### v1.0.2 (Current)
- ✨ **Enhanced PHP Features**: 20+ new PHP-specific commands
- 🌍 **Dynamic Path Detection**: No more hardcoded paths
- 🐘 **Comprehensive PHP Tools**: PHPStan, Psalm, PHPMD, PHPUnit
- 🔧 **Advanced Deployment**: Docker, Kubernetes, Nginx, Apache support
- 🛡️ **Security Features**: Vulnerability scanning, file permissions
- 📊 **Monitoring**: Real-time PHP application monitoring
- 🚀 **Performance**: OpCache optimization, Composer autoloader
- 🔄 **Portability**: Cross-platform, multi-user support

### v1.0.1
- 🐛 Bug fixes and improvements
- 📦 Packagist deployment

### v1.0.0
- 🎉 Initial release
- 📦 Basic PHP wrapper functionality
- 🔧 Core Grim Reaper integration

---

**Grim Reaper PHP Package** - The ultimate PHP development and deployment toolkit! 🗡️🐘 