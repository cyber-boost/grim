# SH_GRIM - Bash Operations Engine

**The operational backbone of the Grim Reaper system** - 60+ bash modules providing comprehensive backup, monitoring, security, and system management capabilities.

## Quick Start

```bash
# Initialize environment
source ./init.sh

# Check system health
./health_fixed.sh check

# Run full backup
./backup.sh create daily

# Start monitoring
./monitor.sh start /important/data

# Check license compliance
./scythe.sh status
```

## Core Architecture

sh_grim modules are organized into functional categories, all designed to work together through the scythe orchestrator:

- **🎯 Core Operations** - Essential backup and restore functions
- **🔍 Monitoring & Scanning** - Real-time filesystem and system monitoring  
- **🛡️ Security & Compliance** - License protection and security auditing
- **🧠 AI & Intelligence** - ML-powered decision making and optimization
- **⚙️ System Management** - Maintenance, health checks, and automation
- **🔗 Integration** - APIs, webhooks, and service connectivity

---

## 📋 COMPLETE MODULE REFERENCE

### 🎯 **CORE OPERATIONS**

#### **backup.sh** - Intelligent Backup System
**Purpose:** Creates frequency-based backups with encryption and deduplication

```bash
# Basic usage
./backup.sh                              # Run all scheduled backups
./backup.sh create daily                 # Create daily backup
./backup.sh create hourly /var/www       # Backup specific path hourly
./backup.sh verify backup.tar.gz         # Verify backup integrity
./backup.sh list daily                   # List daily backups

# Advanced options
./backup.sh create daily --encrypt       # Encrypted backup
./backup.sh create weekly --dedup        # Deduplicated backup
./backup.sh create monthly --remote      # Upload to remote storage
```

**Features:** Progress tracking, SHA256 verification, graveyard recovery, compression, remote storage

#### **backup_core.sh** - Advanced Backup Engine
**Purpose:** Core backup functionality with enterprise features

```bash
./backup_core.sh full /data              # Full system backup
./backup_core.sh incremental /data       # Incremental backup
./backup_core.sh differential /data      # Differential backup
./backup_core.sh schedule                # Show backup schedule
./backup_core.sh optimize                # Optimize backup storage
```

**Features:** Multi-tier backup strategies, automated scheduling, storage optimization

#### **restore.sh** - File Recovery System
**Purpose:** Restores files from backups with integrity verification

```bash
./restore.sh list                        # List available backups
./restore.sh search "filename"           # Search for specific files
./restore.sh recover backup.tar.gz /dest # Restore entire backup
./restore.sh extract backup.tar.gz file  # Extract specific file
./restore.sh preview backup.tar.gz       # Preview backup contents
```

**Features:** Selective restoration, integrity checking, preview mode, search functionality

---

### 🔍 **MONITORING & SCANNING**

#### **scan.sh** - Filesystem Scanner
**Purpose:** Intelligent filesystem indexing with metadata tracking

```bash
./scan.sh                                # Default scan (common dirs)
./scan.sh full /var/www /home            # Full scan of specific dirs
./scan.sh quick /tmp 12                  # Quick scan (last 12 hours)
./scan.sh stats                          # Show scan statistics
./scan.sh clean                          # Clean non-existent entries
```

**Features:** Progress tracking, database storage, automatic exclusions, batch processing

#### **monitor.sh** - Real-time Monitoring
**Purpose:** Continuous filesystem monitoring with anomaly detection

```bash
./monitor.sh start /var/www              # Start monitoring directory
./monitor.sh start /home --recursive     # Monitor recursively
./monitor.sh status /var/www             # Check monitoring status
./monitor.sh events /var/www             # Show recent events
./monitor.sh stop /var/www               # Stop monitoring
./monitor.sh list                        # List all monitored paths

# Advanced monitoring
./monitor.sh start /etc --exclude '*.tmp'
./monitor.sh config /var/www --threshold 100M
```

**Features:** Real-time change detection, anomaly alerts, automatic quarantine, event logging

#### **lookouts.sh** - Security Surveillance
**Purpose:** Advanced security monitoring and threat detection

```bash
./lookouts.sh start                      # Start security monitoring
./lookouts.sh scan /suspicious/path      # Scan for threats
./lookouts.sh quarantine /bad/file       # Quarantine suspicious file
./lookouts.sh report                     # Generate security report
```

**Features:** Threat detection, behavioral analysis, automated response

---

### 🛡️ **SECURITY & COMPLIANCE**

#### **scythe.sh** - License Protection System  
**Purpose:** Silent license compliance monitoring and protection

```bash
# Installation and setup
./scythe.sh install /app/project proj123 "My Project" --start
./scythe.sh init                         # Initialize database

# Monitoring
./scythe.sh start proj123               # Start monitoring software
./scythe.sh stop                        # Stop all monitoring
./scythe.sh status                      # Show protection status
./scythe.sh check                       # Check for violations

# Reporting
./scythe.sh report summary              # Overview of protected software
./scythe.sh report violations proj123   # Show violations
./scythe.sh report communications       # Notification queue status

# License management
./scythe.sh validate LICENSE_KEY        # Validate license key
```

**Features:** Stealth monitoring, 9+ language support, violation tracking, mother DB sync

#### **security.sh** - Security Framework
**Purpose:** Comprehensive security auditing and access control

```bash
./security.sh audit                     # Run security audit
./security.sh permissions /path         # Check file permissions
./security.sh encrypt /file             # Encrypt file
./security.sh decrypt /file.enc         # Decrypt file
./security.sh scan-vulnerabilities      # Vulnerability scan
```

**Features:** SSL management, access control, audit logging, encryption

#### **quarantine.sh** - Threat Isolation
**Purpose:** Isolates and analyzes suspicious files

```bash
./quarantine.sh isolate /suspicious/file
./quarantine.sh analyze /quarantined/file
./quarantine.sh restore /quarantined/file
./quarantine.sh list                     # List quarantined files
```

**Features:** Safe isolation, malware analysis, restoration procedures

---

### 🧠 **AI & INTELLIGENCE**

#### **ai_decision_engine.sh** - ML Decision Making
**Purpose:** AI-powered backup prioritization and resource optimization

```bash
./ai_decision_engine.sh analyze /data    # Analyze data patterns
./ai_decision_engine.sh recommend        # Get AI recommendations
./ai_decision_engine.sh train            # Train ML models
./ai_decision_engine.sh predict /file    # Predict file importance
```

**Features:** TensorFlow/PyTorch integration, predictive analytics, automated decisions

#### **ai_integration.sh** - AI Framework
**Purpose:** Dual AI framework integration with GPU acceleration

```bash
./ai_integration.sh setup               # Setup AI environment
./ai_integration.sh benchmark           # Run AI benchmarks
./ai_integration.sh optimize           # Optimize AI performance
```

**Features:** TensorFlow 2.15.0 + PyTorch 2.1.0, GPU support, model management

#### **ai_train.sh** - ML Training Pipeline
**Purpose:** Machine learning model training and optimization

```bash
./ai_train.sh dataset /training/data    # Prepare training dataset
./ai_train.sh train model_name          # Train specific model
./ai_train.sh evaluate model_name       # Evaluate model performance
./ai_train.sh deploy model_name         # Deploy trained model
```

**Features:** Automated training pipelines, performance validation, model deployment

#### **smart_suggestions.sh** - Intelligent Recommendations
**Purpose:** AI-powered system optimization suggestions

```bash
./smart_suggestions.sh analyze          # Analyze system for improvements
./smart_suggestions.sh storage         # Storage optimization suggestions
./smart_suggestions.sh performance     # Performance improvement suggestions
```

**Features:** Pattern recognition, automated optimization, performance insights

---

### ⚙️ **SYSTEM MANAGEMENT**

#### **health.sh** / **health_fixed.sh** - Health Monitoring
**Purpose:** Comprehensive system health checking and diagnostics

```bash
./health_fixed.sh check                 # Full health check
./health_fixed.sh quick                 # Quick health check
./health_fixed.sh status                # Current status
./health_fixed.sh modules               # Check module status
```

**Features:** Resource monitoring, dependency checking, automated remediation

#### **blacksmith.sh** - System Maintenance
**Purpose:** System optimization and tool creation

```bash
./blacksmith.sh optimize all            # Optimize entire system
./blacksmith.sh maintain cleanup        # Run cleanup maintenance
./blacksmith.sh forge disk-cleaner script # Create new tool
./blacksmith.sh schedule cleanup '0 2 * * 0' # Schedule task
./blacksmith.sh list-tools              # List available tools
```

**Features:** Performance optimization, automated maintenance, tool creation

#### **healer.sh** - Self-Healing System
**Purpose:** Automated recovery and system remediation

```bash
./healer.sh diagnose                    # Diagnose system issues
./healer.sh heal                        # Attempt automatic healing
./healer.sh monitor                     # Start healing monitoring
./healer.sh report                      # Healing activity report
```

**Features:** Automatic issue detection, self-remediation, continuous monitoring

#### **cleanup.sh** - System Cleanup
**Purpose:** Automated cleanup and disk space management

```bash
./cleanup.sh all                        # Clean entire system
./cleanup.sh logs                       # Clean old log files
./cleanup.sh temp                       # Clean temporary files
./cleanup.sh backups 30                 # Clean backups older than 30 days
```

**Features:** Smart cleanup algorithms, age-based retention, space optimization

---

### 📊 **ANALYTICS & REPORTING**

#### **audit.sh** - Audit Logging
**Purpose:** Comprehensive system auditing and compliance tracking

```bash
./audit.sh start                        # Start audit logging
./audit.sh report                       # Generate audit report
./audit.sh compliance                   # Check compliance status
./audit.sh search "user:admin"          # Search audit logs
```

**Features:** Detailed audit trails, compliance reporting, log analysis

#### **report.sh** - Report Generation
**Purpose:** Automated report generation for all system components

```bash
./report.sh daily                       # Daily system report
./report.sh backup                      # Backup status report
./report.sh security                    # Security audit report
./report.sh performance                 # Performance analysis report
```

**Features:** Multi-format reports, automated scheduling, trend analysis

#### **performance.sh** - Performance Analytics
**Purpose:** System performance monitoring and optimization

```bash
./performance.sh benchmark              # Run performance benchmarks
./performance.sh monitor               # Real-time performance monitoring
./performance.sh analyze               # Analyze performance data
./performance.sh optimize              # Apply performance optimizations
```

**Features:** Real-time metrics, bottleneck identification, optimization recommendations

---

### 🔗 **INTEGRATION & CONNECTIVITY**

#### **notify.sh** - Notification System
**Purpose:** Multi-channel notification and alerting

```bash
./notify.sh send "System Alert" "Message"
./notify.sh setup email                 # Setup email notifications
./notify.sh setup slack                 # Setup Slack integration
./notify.sh test                        # Test notification system
```

**Features:** Email, SMS, Slack, Discord, webhook support, priority routing

#### **remote.sh** - Remote Operations
**Purpose:** Remote storage and synchronization

```bash
./remote.sh setup s3                    # Setup S3 storage
./remote.sh sync /local/path            # Sync to remote storage
./remote.sh download backup.tar.gz      # Download from remote
./remote.sh status                      # Remote storage status
```

**Features:** Multi-cloud support, encrypted transfer, bandwidth optimization

#### **schedule.sh** - Task Scheduling
**Purpose:** Advanced cron-based task scheduling

```bash
./schedule.sh add "0 2 * * *" "./backup.sh daily"
./schedule.sh list                      # List scheduled tasks
./schedule.sh enable task_id            # Enable scheduled task
./schedule.sh disable task_id           # Disable scheduled task
```

**Features:** Cron integration, dependency management, failure handling

---

### 🔧 **UTILITIES & TOOLS**

#### **compress.sh** - Compression Utilities
**Purpose:** Advanced file compression and archiving

```bash
./compress.sh /path/to/files            # Compress with best algorithm
./compress.sh /files --algorithm zstd   # Use specific algorithm
./compress.sh benchmark /files          # Test compression algorithms
```

**Features:** Multiple algorithms, adaptive selection, benchmark testing

#### **encrypt.sh** - Encryption Tools
**Purpose:** File and data encryption utilities

```bash
./encrypt.sh /sensitive/file            # Encrypt file
./encrypt.sh --decrypt /file.enc        # Decrypt file
./encrypt.sh --generate-key             # Generate encryption key
```

**Features:** AES-256 encryption, key management, secure deletion

#### **verify.sh** - Integrity Verification
**Purpose:** File integrity checking and verification

```bash
./verify.sh /important/file             # Verify file integrity
./verify.sh --create-hash /file         # Create integrity hash
./verify.sh --check-backup backup.tar.gz # Verify backup integrity
```

**Features:** Multiple hash algorithms, batch verification, corruption detection

#### **settings.sh** - Configuration Management
**Purpose:** System configuration and settings management

```bash
./settings.sh get backup.frequency      # Get configuration value
./settings.sh set backup.frequency daily # Set configuration
./settings.sh export                    # Export all settings
./settings.sh import config.json        # Import settings
```

**Features:** Centralized configuration, validation, backup/restore

---

## 🎛️ **SYSTEM INTEGRATION**

All sh_grim modules are designed to work together through:

1. **Shared Database** - SQLite database for coordination
2. **Event System** - Modules communicate through events
3. **Configuration** - Unified settings management
4. **Logging** - Centralized logging and audit trails
5. **Scythe Orchestration** - Central coordination through scythe.py

### Common Integration Patterns:

```bash
# Scan → Backup → Monitor → Report
./scan.sh full /important/data
./backup.sh create daily /important/data
./monitor.sh start /important/data
./report.sh backup

# Security → Quarantine → Notify → Audit
./security.sh scan-vulnerabilities
./quarantine.sh isolate /suspicious/file
./notify.sh send "Security Alert" "File quarantined"
./audit.sh report security
```

## 🚀 **ORCHESTRATION WITH SCYTHE**

The new scythe orchestrator coordinates all sh_grim modules:

```bash
# Scythe health check tests all modules
python3 ../scythe/scythe.py health

# Scythe backup operation coordinates multiple modules
python3 ../scythe/scythe.py backup /data --name coordinated_backup
```

**Scythe Integration Flow:**
1. **Health Check** - Validates all sh_grim modules
2. **Scan Phase** - Uses scan.sh for file discovery
3. **Backup Phase** - Coordinates backup.sh operations
4. **Compression** - Leverages go_grim for performance
5. **Storage** - Uses py_grim for metadata management
6. **Verification** - Validates backup integrity
7. **Notification** - Alerts on completion/errors

---

## 📚 **QUICK REFERENCE**

### Most Used Commands:
```bash
./health_fixed.sh check              # System health
./backup.sh create daily             # Daily backup
./scan.sh quick /path 24             # Quick scan
./monitor.sh start /path             # Start monitoring
./scythe.sh status                   # License compliance
./cleanup.sh all                     # System cleanup
./report.sh daily                    # Daily report
```

### Emergency Commands:
```bash
./healer.sh heal                     # Auto-fix issues
./quarantine.sh isolate /bad/file    # Isolate threats
./restore.sh recover backup.tar.gz   # Emergency restore
./security.sh encrypt /sensitive     # Quick encryption
```

### Maintenance Commands:
```bash
./blacksmith.sh optimize all         # System optimization
./performance.sh benchmark           # Performance check
./audit.sh compliance               # Compliance check
./verify.sh --check-backup *.tar.gz # Verify all backups
```

---

**sh_grim provides 60+ bash modules for comprehensive system management, all coordinated through the scythe orchestrator for seamless operation.**