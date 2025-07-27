# Grim Reaper 🗡️ Ruby Gem

[![Gem Version](https://badge.fury.io/rb/grim-reaper.svg)](https://rubygems.org/gems/grim-reaper)
[![Downloads](https://img.shields.io/gem/dt/grim-reaper)](https://rubygems.org/gems/grim-reaper)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://grim.so/license)

**When data death comes knocking, Grim ensures resurrection is just a command away.**

Enterprise-grade data protection platform with AI-powered backup decisions, military-grade encryption, multi-algorithm compression, content-based deduplication, real-time monitoring, and automated threat response.

## 🚀 What's New in v1.0.34

### 🆕 **Latest.tar.gz Auto-Download System**
- **Direct Install**: Now downloads complete Grim system from `get.grim.so/latest.tar.gz`
- **Smart Extraction**: Properly handles `graveyard/reaper/` structure with `--strip-components=2`
- **Auto-Environment**: Automatically sets `GRIM_ROOT`, `GRIM_LICENSE=FREE`, `GRIM_REAPER=FALSE`
- **Intelligent Paths**: Tries `/root/.grim`, `$HOME/.grim`, or local directory
- **Executable Scripts**: Automatically makes all scripts executable
- **Bashrc Integration**: Adds environment to `~/.bashrc` for persistence

### 🏗️ **Professional Tier System (July 2025)**
Complete overhaul of pricing structure with 6-tier system:

- **🆓 FREE** ($0) - 1GB storage, 15 commands, encrypted auto-backups
- **💼 BASIC** ($19) - 25GB cloud, 35 commands, removes encryption friction  
- **🚀 PRO** ($49) - 100GB storage, 60 commands, AI-powered decisions
- **⚔️ MASTER** ($99) - 1TB storage, 200+ commands, enterprise compliance
- **💀 REAPER** ($499) - Unlimited storage, custom development, 24/7 support
- **🏢 ENTERPRISE** (Custom) - Global deployment, source code access, strategic partnership

### 🔧 **Critical Infrastructure Fixes (July 26-27, 2025)**
- **SSL Certificate Crisis**: Fixed `up.grim.so` SSL mismatch (was `cyberboost.com`)
- **Port Configuration**: Corrected auto-update service from `4745` → `5001`
- **Auto-Update Daemon**: Restored background version checking for 5000+ installations
- **Nginx Proxy**: Fixed proxy configuration for proper request routing
- **Function Dependencies**: Resolved `log_update` function order bugs

### 🔐 **Enhanced Security Features**
- **OTP Authentication**: TOTP support with QR codes and backup codes
- **Environment Protection**: Smart environment variable detection and setup
- **Secure Downloads**: HTTPS-only downloads with SSL verification
- **Permission Management**: Automatic executable permissions for all scripts

## 🚀 Quick Install

```bash
gem install grim-reaper
```

## 🎯 Quick Start Commands

```bash
# Download and install complete Grim system
grim download-latest

# Setup complete environment (Python, Go, Shell, Scythe)
grim setup-complete

# Check installation status
grim check-installation

# Health check all modules
grim health
```

## 🔐 Enhanced OTP Authentication

Enhanced security with One-Time Password (TOTP) authentication:

```bash
# Setup OTP authentication
grim otp-setup

# Use OTP with commands
grim health --otp 123456
grim setup-complete --otp 789012

# Check OTP status
grim otp-status

# Verify OTP code
grim otp-verify 123456
```

## 🎯 Ruby Integration

```ruby
require 'grim_reaper'

# Initialize with auto-download
grim = GrimReaper.new

# Download latest if not installed
installer = GrimReaper::Installer.new
installer.download_latest_grim unless installer.find_grim_root

# Quick operations
grim.backup('/important/data')
grim.monitor('/var/log')
grim.security
```

## 📥 Installation Options

### Option 1: Ruby Gem (Recommended)
```bash
gem install grim-reaper
grim download-latest
```

### Option 2: Direct Download
```bash
curl -sSL get.grim.so | sudo bash
```

### Option 3: Manual Setup
```bash
gem install grim-reaper
grim setup-complete
```

## 🎯 Quick Start

```ruby
require 'grim_reaper'

# Initialize Grim Reaper
grim = GrimReaper::Core.new

# Quick backup
grim.backup('/important/data')

# Start monitoring
grim.monitor('/var/log')

# Health check
grim.health_check
```

## 📋 Complete Command Reference

All commands use the unified Grim Reaper command structure:

### 🤖 AI & Machine Learning

```bash
# AI Decision Engine
grim ai-decision init                    # Initialize AI decision engine
grim ai-decision analyze                 # Analyze files for intelligent backup decisions
grim ai-decision backup-priority         # Determine backup priorities using AI
grim ai-decision storage-optimize        # Optimize storage allocation with AI
grim ai-decision resource-manage         # Manage system resources intelligently
grim ai-decision validate                # Validate AI models and decisions
grim ai-decision report                  # Generate AI analysis report
grim ai-decision config                  # Configure AI parameters
grim ai-decision status                  # Check AI engine status

# AI Integration
grim ai init                             # Initialize AI integration framework
grim ai install                          # Install AI dependencies (TensorFlow/PyTorch)
grim ai train                            # Train AI models on your data
grim ai predict                          # Generate predictions from models
grim ai analyze                          # Analyze data patterns
grim ai optimize                         # Optimize AI performance
grim ai monitor                          # Monitor AI operations
grim ai validate                         # Validate model accuracy
grim ai report                           # Generate integration report
grim ai config                           # Configure AI integration
grim ai status                           # Check integration status

# AI Production Deployment
grim ai-deploy deploy                    # Deploy AI models to production
grim ai-deploy test                      # Run automated deployment tests
grim ai-deploy rollback                  # Rollback to previous version
grim ai-deploy monitor                   # Monitor deployed models
grim ai-deploy health                    # Check deployment health
grim ai-deploy backup                    # Backup current deployment
grim ai-deploy restore                   # Restore from backup
grim ai-deploy status                    # Check deployment status

# AI Training
grim ai-train analyze                    # Analyze training data
grim ai-train train                      # Train base models
grim ai-train predict                    # Generate predictions
grim ai-train cluster                    # Perform clustering analysis
grim ai-train extract                    # Extract features from data
grim ai-train validate                   # Validate model performance
grim ai-train report                     # Generate training report
grim ai-train neural                     # Train neural networks
grim ai-train ensemble                   # Train ensemble models
grim ai-train timeseries                 # Time series analysis
grim ai-train regression                 # Train regression models
grim ai-train classify                   # Train classification models
grim ai-train config                     # Configure training parameters
grim ai-train init                       # Initialize training environment

# AI Velocity Enhancement
grim ai-turbo turbo                      # Activate turbo mode for AI
grim ai-turbo optimize                   # Optimize AI performance
grim ai-turbo benchmark                  # Run performance benchmarks
grim ai-turbo validate                   # Validate optimizations
grim ai-turbo deploy                     # Deploy optimized models
grim ai-turbo monitor                    # Monitor performance gains
grim ai-turbo report                     # Generate performance report
```

### 💾 Backup & Recovery

```bash
# Core Backup Operations
grim backup create                       # Create intelligent backup
grim backup verify                       # Verify backup integrity
grim backup list                         # List all backups

# Core Backup Engine
grim backup-core create                  # Create core backup with progress
grim backup-core verify                  # Verify backup checksums
grim backup-core restore                 # Restore from backup
grim backup-core status                  # Check backup system status
grim backup-core init                    # Initialize backup system

# Automatic Backup Daemon
grim auto-backup start                   # Start automatic backup daemon
grim auto-backup stop                    # Stop backup daemon
grim auto-backup restart                 # Restart backup daemon
grim auto-backup status                  # Check daemon status
grim auto-backup health                  # Health check with diagnostics

# Restore Operations
grim restore recover                     # Restore from backup
grim restore list                        # List available restore points
grim restore verify                      # Verify restore integrity

# Deduplication
grim dedup dedup                         # Deduplicate files
grim dedup restore                       # Restore deduplicated files
grim dedup cleanup                       # Clean orphaned chunks
grim dedup stats                         # Show deduplication statistics
grim dedup verify                        # Verify dedup integrity
grim dedup benchmark                     # Run deduplication benchmarks
```

### 📊 System Monitoring & Health

```bash
# System Monitoring
grim monitor start                       # Start system monitoring
grim monitor stop                        # Stop monitoring
grim monitor status                      # Check monitor status
grim monitor show                        # Show current metrics
grim monitor report                      # Generate monitoring report

# Health Checking
grim health check                        # Complete health check
grim health fix                          # Auto-fix detected issues
grim health report                       # Generate health report
grim health monitor                      # Continuous health monitoring

# Enhanced Health Monitoring
grim health-check check                  # Enhanced health check
grim health-check services               # Check all services
grim health-check disk                   # Check disk health
grim health-check memory                 # Check memory status
grim health-check network                # Check network health
grim health-check fix                    # Auto-fix all issues
grim health-check report                 # Detailed health report
```

### 🔒 Security & Compliance

```bash
# Security Auditing
grim audit full                          # Complete security audit
grim audit permissions                   # Audit file permissions
grim audit compliance                    # Check compliance (CIS/STIG/NIST)
grim audit backups                       # Audit backup integrity
grim audit logs                          # Audit access logs
grim audit config                        # Audit configuration security
grim audit report                        # Generate audit report

# Security Operations
grim security scan                       # Run security scan
grim security audit                      # Deep security audit
grim security fix                        # Auto-fix vulnerabilities
grim security report                     # Generate security report
grim security monitor                    # Start security monitoring

# Security Testing
grim security-testing vulnerability      # Run vulnerability tests
grim security-testing penetration        # Run penetration tests
grim security-testing compliance         # Test compliance standards
grim security-testing report             # Generate test report

# File Encryption
grim encrypt encrypt                     # Encrypt files
grim encrypt decrypt                     # Decrypt files
grim encrypt key-gen                     # Generate encryption keys
grim encrypt verify                      # Verify encryption

# File Verification
grim verify integrity                    # Verify file integrity
grim verify checksum                     # Verify checksums
grim verify signature                    # Verify digital signatures
grim verify backup                       # Verify backup integrity

# Multi-Language Scanner
grim scanner scan                        # Multi-threaded file system scan
grim scanner info                        # Get file information and summary
grim scanner hash                        # Calculate file hashes (MD5/SHA256)
grim scanner py-scan                     # Python-based security scanning
grim scanner security                    # Security vulnerability scan
grim scanner malware                     # Malware detection scan
grim scanner vulnerability               # Deep vulnerability scan
grim scanner compliance                  # Compliance verification scan
grim scanner report                      # Generate scan report
```

### 🚀 Performance & Optimization

```bash
# High-Performance Compression
grim compression compress                # Compress with Go binary (8 algorithms)
grim compression decompress              # Decompress files
grim compression benchmark               # Run compression benchmarks
grim compression optimize                # Optimize compression
grim compression analyze                 # Analyze compression potential
grim compression list                    # List compressed files
grim compression cleanup                 # Clean temporary files

# System Optimization
grim blacksmith optimize                 # System-wide optimization
grim blacksmith maintain                 # Run maintenance tasks
grim blacksmith forge                    # Create new tools
grim blacksmith list-tools               # List available tools
grim blacksmith run-tool                 # Run specific tool
grim blacksmith schedule                 # Schedule maintenance
grim blacksmith list-scheduled           # List scheduled tasks
grim blacksmith backup-tools             # Backup custom tools
grim blacksmith restore-tools            # Restore tools
grim blacksmith update-tools             # Update all tools
grim blacksmith stats                    # Show forge statistics
grim blacksmith config                   # Configure forge

# Performance Testing
grim performance-test cpu                # Test CPU performance
grim performance-test memory             # Test memory performance
grim performance-test disk               # Test disk I/O
grim performance-test network            # Test network throughput
grim performance-test full               # Run all performance tests
grim performance-test report             # Generate performance report

# System Cleanup
grim cleanup all                         # Clean everything safely
grim cleanup backups                     # Clean old backups
grim cleanup temp                        # Clean temporary files
grim cleanup logs                        # Clean old logs
grim cleanup database                    # Clean database
grim cleanup duplicates                  # Remove duplicate files
grim cleanup report                      # Preview cleanup actions
```

### 🌐 Web Services & APIs

```bash
# Web Services
grim web start                           # Start FastAPI web server
grim web stop                            # Stop all web services
grim web restart                         # Restart web server
grim web gateway                         # Start API gateway with load balancing
grim web api                             # Start API application
grim web status                          # Show web services status

# Monitoring Dashboard
grim dashboard start                     # Start web dashboard
grim dashboard stop                      # Stop dashboard
grim dashboard restart                   # Restart dashboard
grim dashboard status                    # Check dashboard status
grim dashboard config                    # Configure dashboard
grim dashboard init                      # Initialize dashboard
grim dashboard setup                     # Run setup wizard
grim dashboard logs                      # View dashboard logs

# API Gateway
grim gateway start                       # Start API gateway
grim gateway stop                        # Stop gateway
grim gateway status                      # Gateway status
grim gateway config                      # Configure gateway
```

### ☁️ Cloud & Distributed Systems

```bash
# Cloud Platform Integration
grim cloud init                          # Initialize cloud platform
grim cloud aws                           # Deploy to AWS
grim cloud azure                         # Deploy to Azure
grim cloud gcp                           # Deploy to Google Cloud
grim cloud serverless                    # Deploy serverless functions
grim cloud comprehensive                 # Full cloud deployment

# Distributed Architecture
grim distributed init                    # Initialize distributed system
grim distributed deploy                  # Deploy microservices
grim distributed scale                   # Scale services
grim distributed balance                 # Configure load balancing
grim distributed monitor                 # Monitor distributed system

# Load Balancing
grim load-balancer start                 # Start load balancer
grim load-balancer stop                  # Stop load balancer
grim load-balancer status                # Check balancer status
grim load-balancer add-server            # Add backend server
grim load-balancer remove-server         # Remove backend server

# File Transfer (Multi-Protocol)
grim transfer upload                     # Upload files to destination
grim transfer download                   # Download files from source
grim transfer resume                     # Resume interrupted transfer
grim transfer verify                     # Verify transfer integrity
```

### 🧪 Testing & Quality Assurance

```bash
# Testing Framework
grim testing run                         # Run all tests
grim testing benchmark                   # Run benchmarks
grim testing ci                          # CI/CD test suite
grim testing report                      # Generate test report

# Quality Assurance
grim qa code-review                      # Automated code review
grim qa static-analysis                  # Static code analysis
grim qa security-scan                    # Security scanning
grim qa performance-test                 # Performance testing
grim qa integration-test                 # Integration testing
grim qa report                           # Generate QA report

# User Acceptance Testing
grim user-acceptance run                 # Run acceptance tests
grim user-acceptance generate            # Generate test scenarios
grim user-acceptance validate            # Validate user workflows
grim user-acceptance report              # Generate UAT report
```

### 🔧 System Maintenance & Operations

```bash
# Central Orchestrator (Scythe)
grim scythe harvest                      # Orchestrate all operations
grim scythe analyze                      # Analyze system state
grim scythe report                       # Generate master report
grim scythe monitor                      # Monitor all operations
grim scythe status                       # Show orchestrator status
grim scythe backup                       # Orchestrated backup operations

# Logging System
grim log init                            # Initialize logging system
grim log setup                           # Setup logger configuration
grim log event                           # Log structured event
grim log metric                          # Log performance metric
grim log rotate                          # Rotate log files
grim log cleanup                         # Clean up old log files
grim log status                          # Show logging system status
grim log tail                            # Tail log file

# Configuration Management
grim config load                         # Load configuration
grim config save                         # Save configuration
grim config get                          # Get configuration value
grim config set                          # Set configuration value
grim config validate                     # Validate configuration
```

## 💎 Ruby-Specific Integration

### Rails Integration

```ruby
# Gemfile
gem 'grim-reaper'

# config/initializers/grim.rb
Rails.application.config.grim = GrimReaper::Core.new(
  config_path: Rails.root.join('config/grim.yml'),
  backup_path: Rails.root.join('backups'),
  log_level: Rails.env.production? ? :info : :debug
)

# Automatic backup of Rails app
Rails.application.config.grim.auto_backup(Rails.root, schedule: :daily)

# Monitor Rails logs
Rails.application.config.grim.monitor(Rails.root.join('log'))
```

### Ruby Code Examples

```ruby
require 'grim_reaper'

# Initialize with custom configuration
grim = GrimReaper::Core.new(
  backup_path: '/opt/backups',
  compression: 'zstd',
  encryption: true
)

# Backup with Ruby-specific options
grim.backup('/var/www/ruby_app') do |backup|
  backup.exclude_patterns = %w[tmp/ log/ node_modules/]
  backup.include_gems = true
  backup.ruby_version_info = true
end

# Monitor Ruby application
grim.monitor('/var/www/ruby_app') do |monitor|
  monitor.watch_gemfile = true
  monitor.ruby_processes = true
  monitor.rails_logs = true if defined?(Rails)
end

# Compress Ruby source files
grim.compress('/app/source', algorithm: 'zstd') do |compress|
  compress.ruby_syntax_check = true
  compress.preserve_permissions = true
end

# Health check with Ruby-specific checks
health = grim.health_check do |check|
  check.ruby_version = true
  check.gem_dependencies = true
  check.bundler_status = true
  check.rails_environment = true if defined?(Rails)
end

puts "System Health: #{health.status}"
puts "Ruby Version: #{health.ruby_version}"
puts "Gems Status: #{health.gems_status}"
```

### Rake Tasks

```ruby
# lib/tasks/grim.rake
namespace :grim do
  desc "Backup Rails application"
  task backup: :environment do
    GrimReaper::Core.new.backup(Rails.root)
  end

  desc "Start monitoring Rails application"
  task monitor: :environment do
    GrimReaper::Core.new.monitor(Rails.root)
  end

  desc "Run health check"
  task health: :environment do
    health = GrimReaper::Core.new.health_check
    puts "Status: #{health.overall_status}"
  end

  desc "Optimize Rails application"
  task optimize: :environment do
    GrimReaper::Core.new.optimize(Rails.root)
  end
end
```

### RSpec Integration

```ruby
# spec/spec_helper.rb
require 'grim_reaper/rspec'

RSpec.configure do |config|
  config.include GrimReaper::RSpec::Helpers
  
  # Backup test database before each test
  config.before(:each) do
    grim_backup_test_data if example.metadata[:backup_data]
  end
  
  # Clean up test artifacts
  config.after(:suite) do
    grim_cleanup_test_artifacts
  end
end

# In your specs
RSpec.describe MyController, :backup_data do
  it "processes data safely" do
    # Your test code here
    # Test data will be automatically backed up
  end
end
```

## 🔗 Links & Resources

- **Website**: [grim.so](https://grim.so)
- **GitHub**: [github.com/cyber-boost/grim](https://github.com/cyber-boost/grim)
- **Download**: [get.grim.so](https://get.grim.so)
- **RubyGems**: [rubygems.org/gems/grim-reaper](https://rubygems.org/gems/grim-reaper)
- **Documentation**: [grim.so/docs](https://grim.so/docs)

## 📄 License

By using this software you agree to the official license available at https://grim.so/license

---

<div align="center">
<strong>🗡️ GRIM REAPER</strong><br>
<i>"When data death comes knocking, resurrection is just a command away"</i>
</div>