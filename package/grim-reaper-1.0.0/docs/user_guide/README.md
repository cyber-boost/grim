# Grim Reaper System - Complete User Guide

**The Ultimate Backup, Monitoring, and Security System**

## Table of Contents

1. [Getting Started](#getting-started)
2. [System Overview](#system-overview)
3. [Installation](#installation)
4. [Basic Operations](#basic-operations)
5. [Advanced Features](#advanced-features)
6. [Configuration](#configuration)
7. [Troubleshooting](#troubleshooting)
8. [Quick Reference](#quick-reference)

---

## Getting Started

### What is Grim Reaper?

Grim Reaper is a comprehensive system management platform that combines:
- **Intelligent Backup & Recovery** - Multi-tier backup strategies with AI optimization
- **Real-time Monitoring** - Filesystem and system monitoring with anomaly detection
- **Security & Compliance** - License protection and security auditing
- **Orchestration** - Centralized control through the Scythe orchestrator

### System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   sh_grim       │    │   go_grim       │    │   py_grim       │
│   (Bash Engine) │    │   (Go Engine)   │    │   (Web API)     │
│                 │    │                 │    │                 │
│ • Backup ops    │    │ • Compression   │    │ • REST APIs     │
│ • Monitoring    │    │ • Performance   │    │ • Web interface │
│ • Security      │    │ • Optimization  │    │ • Integration   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │    Scythe       │
                    │ (Orchestrator)  │
                    │                 │
                    │ • Coordination  │
                    │ • Scheduling    │
                    │ • Management    │
                    └─────────────────┘
```

---

## Installation

### Prerequisites

- **Operating System**: Linux (Ubuntu 20.04+, CentOS 8+, or compatible)
- **Memory**: Minimum 2GB RAM, 4GB+ recommended
- **Storage**: 10GB+ available space
- **Network**: Internet access for updates and remote features

### Quick Installation

```bash
# Download and run the installer
curl -sSL https://grim-reaper.org/install.sh | sudo bash

# Or using wget
wget -qO- https://grim-reaper.org/install.sh | sudo bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/grim-reaper/system.git
cd system

# Install dependencies
sudo ./install_dependencies.sh

# Initialize the system
sudo ./init.sh

# Verify installation
./health_check.sh
```

### Post-Installation Setup

```bash
# Configure your first project
./scythe.sh install /your/project PROJECT_ID "Project Name" --start

# Set up monitoring
./monitor.sh start /important/data

# Create initial backup
./backup.sh create daily
```

---

## Basic Operations

### 1. Backup Operations

#### Creating Backups

```bash
# Daily backup (recommended)
./backup.sh create daily

# Hourly backup for critical data
./backup.sh create hourly /var/www

# Weekly backup with encryption
./backup.sh create weekly --encrypt

# Custom backup
./backup.sh create custom /path/to/data --frequency 6h
```

#### Managing Backups

```bash
# List available backups
./backup.sh list daily
./backup.sh list weekly

# Verify backup integrity
./backup.sh verify backup_2024-01-15.tar.gz

# Check backup statistics
./backup.sh stats
```

#### Restoring Data

```bash
# List restorable backups
./restore.sh list

# Restore entire backup
./restore.sh recover backup_2024-01-15.tar.gz /restore/path

# Extract specific files
./restore.sh extract backup_2024-01-15.tar.gz /path/to/file

# Search for files in backups
./restore.sh search "important_document.pdf"
```

### 2. Monitoring Operations

#### Starting Monitoring

```bash
# Monitor a directory
./monitor.sh start /var/www

# Monitor recursively
./monitor.sh start /home --recursive

# Monitor with exclusions
./monitor.sh start /etc --exclude '*.tmp,*.log'

# Monitor with custom thresholds
./monitor.sh start /data --threshold 100M
```

#### Managing Monitoring

```bash
# Check monitoring status
./monitor.sh status /var/www

# View recent events
./monitor.sh events /var/www

# List all monitored paths
./monitor.sh list

# Stop monitoring
./monitor.sh stop /var/www
```

### 3. Security Operations

#### License Protection

```bash
# Install protection for a project
./scythe.sh install /app/project proj123 "My Project" --start

# Check protection status
./scythe.sh status

# View violations
./scythe.sh report violations proj123

# Validate license key
./scythe.sh validate LICENSE_KEY
```

#### Security Auditing

```bash
# Run security audit
./security.sh audit

# Check file permissions
./security.sh permissions /path

# Scan for vulnerabilities
./security.sh scan-vulnerabilities

# Encrypt sensitive files
./security.sh encrypt /sensitive/file
```

---

## Advanced Features

### 1. AI-Powered Optimization

```bash
# Get AI recommendations
./ai_decision_engine.sh recommend

# Analyze data patterns
./ai_decision_engine.sh analyze /data

# Train ML models
./ai_decision_engine.sh train

# Predict file importance
./ai_decision_engine.sh predict /file
```

### 2. Advanced Backup Strategies

```bash
# Incremental backup
./backup_core.sh incremental /data

# Differential backup
./backup_core.sh differential /data

# Full system backup
./backup_core.sh full /data

# Optimize backup storage
./backup_core.sh optimize
```

### 3. Real-time Scanning

```bash
# Full filesystem scan
./scan.sh full /var/www /home

# Quick scan (recent changes)
./scan.sh quick /tmp 12

# View scan statistics
./scan.sh stats

# Clean scan database
./scan.sh clean
```

### 4. Threat Detection

```bash
# Start security monitoring
./lookouts.sh start

# Scan for threats
./lookouts.sh scan /suspicious/path

# Quarantine suspicious files
./quarantine.sh isolate /suspicious/file

# Generate security report
./lookouts.sh report
```

---

## Configuration

### System Configuration

The main configuration file is located at `/etc/grim-reaper/config.yaml`:

```yaml
# Backup Configuration
backup:
  default_frequency: daily
  retention_days: 30
  compression_level: 6
  encryption_enabled: true
  
# Monitoring Configuration
monitoring:
  check_interval: 60
  alert_threshold: 100M
  exclude_patterns:
    - "*.tmp"
    - "*.log"
    - ".git/*"
    
# Security Configuration
security:
  license_check_interval: 3600
  violation_threshold: 3
  auto_quarantine: true
  
# Performance Configuration
performance:
  max_concurrent_backups: 3
  memory_limit: 2G
  cpu_limit: 50%
```

### Environment Variables

```bash
# Set in your shell profile or systemd service
export GRIM_BACKUP_PATH="/backups"
export GRIM_LOG_LEVEL="INFO"
export GRIM_ENCRYPTION_KEY="your-secret-key"
export GRIM_REMOTE_STORAGE="s3://bucket/path"
```

### Service Configuration

```bash
# Enable systemd services
sudo systemctl enable grim-backup
sudo systemctl enable grim-monitor
sudo systemctl enable grim-security

# Start services
sudo systemctl start grim-backup
sudo systemctl start grim-monitor
sudo systemctl start grim-security

# Check service status
sudo systemctl status grim-*
```

---

## Troubleshooting

### Common Issues

#### 1. Backup Failures

**Problem**: Backup process fails with "Permission denied"

**Solution**:
```bash
# Check file permissions
ls -la /path/to/backup

# Fix permissions
sudo chown -R grim:grim /path/to/backup
sudo chmod -R 755 /path/to/backup

# Verify backup path exists
mkdir -p /path/to/backup
```

#### 2. Monitoring Not Working

**Problem**: Monitoring shows no events

**Solution**:
```bash
# Check monitoring status
./monitor.sh status /path

# Restart monitoring
./monitor.sh stop /path
./monitor.sh start /path

# Check logs
tail -f /var/log/grim/monitor.log
```

#### 3. License Violations

**Problem**: False license violation alerts

**Solution**:
```bash
# Check license status
./scythe.sh status

# Validate license key
./scythe.sh validate YOUR_LICENSE_KEY

# Reset violation counter
./scythe.sh reset-violations proj123
```

#### 4. Performance Issues

**Problem**: System running slowly

**Solution**:
```bash
# Check resource usage
./health_check.sh

# Optimize backup storage
./backup_core.sh optimize

# Adjust performance settings
./config.sh set performance.max_concurrent_backups 1
```

### Log Files

```bash
# Main system logs
tail -f /var/log/grim/system.log

# Backup logs
tail -f /var/log/grim/backup.log

# Monitoring logs
tail -f /var/log/grim/monitor.log

# Security logs
tail -f /var/log/grim/security.log
```

### Diagnostic Commands

```bash
# System health check
./health_check.sh

# Component status
./status.sh

# Performance metrics
./metrics.sh

# Configuration validation
./validate_config.sh
```

---

## Quick Reference

### Essential Commands

| Command | Description | Example |
|---------|-------------|---------|
| `./backup.sh create daily` | Create daily backup | `./backup.sh create daily` |
| `./restore.sh list` | List available backups | `./restore.sh list` |
| `./monitor.sh start /path` | Start monitoring | `./monitor.sh start /var/www` |
| `./scythe.sh status` | Check license status | `./scythe.sh status` |
| `./health_check.sh` | System health check | `./health_check.sh` |

### File Locations

| Component | Location | Purpose |
|-----------|----------|---------|
| Backups | `/backups/` | Backup storage |
| Logs | `/var/log/grim/` | System logs |
| Config | `/etc/grim-reaper/` | Configuration files |
| Cache | `/var/cache/grim/` | Temporary files |
| Database | `/var/lib/grim/` | System database |

### Emergency Procedures

#### System Recovery

```bash
# Emergency restore
./emergency_restore.sh

# Reset system
./reset_system.sh

# Rebuild database
./rebuild_db.sh
```

#### Data Recovery

```bash
# Mount backup
./mount_backup.sh backup.tar.gz /mnt/backup

# Extract specific files
./restore.sh extract backup.tar.gz /path/to/file

# Recover from graveyard
./graveyard_recovery.sh
```

---

## Support

### Getting Help

- **Documentation**: `/docs/` directory
- **Logs**: `/var/log/grim/`
- **Configuration**: `/etc/grim-reaper/`
- **Community**: https://community.grim-reaper.org

### Reporting Issues

```bash
# Generate diagnostic report
./diagnostic.sh

# Submit bug report
./report_bug.sh "Description of issue"
```

### Updates

```bash
# Check for updates
./update_check.sh

# Install updates
./update.sh

# Rollback update
./rollback.sh
```

---

*This user guide covers the essential operations for the Grim Reaper system. For advanced usage and API documentation, refer to the individual component README files.* 