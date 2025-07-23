# Grim Reaper - The Ultimate Backup, Monitoring, and Security System

[![PyPI version](https://badge.fury.io/py/grim-reaper.svg)](https://badge.fury.io/py/grim-reaper)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive system management platform that combines Python, Go, and Bash components for enterprise-grade backup, monitoring, and security operations.

## 🚀 Quick Start

### Option 1: Automated Installation (Recommended)

```bash
# Download and run the installation script
curl -sSL https://raw.githubusercontent.com/cyber-boost/grim/main/install_dependencies.sh | bash
```

### Option 2: Manual Installation

#### 1. Install Python Package
```bash
pip install grim-reaper==1.0.4
```

#### 2. Install System Dependencies
**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y rsync tar gzip bzip2 xz-utils openssl curl wget ssh-client scp findutils build-essential git
```

**CentOS/RHEL:**
```bash
sudo yum update -y
sudo yum install -y rsync tar gzip bzip2 xz openssl curl wget openssh-clients findutils gcc gcc-c++ make git
```

#### 3. Install Go Runtime
```bash
# Download and install Go
curl -LO https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

#### 4. Setup Grim Directory
```bash
sudo mkdir -p /opt/reaper
sudo chown $USER:$USER /opt/reaper
```

#### 5. Build Go Binaries
```bash
cd /opt/reaper/go_grim
go mod download
make build
```

## 📋 System Requirements

### Required System Tools
- `rsync` - File synchronization
- `tar` - Archive creation
- `gzip`, `bzip2`, `xz` - Compression utilities
- `openssl` - Encryption and certificates
- `curl`, `wget` - File downloads
- `ssh`, `scp` - Remote operations
- `find`, `du`, `df` - System utilities

### Required Runtime
- **Python 3.8+** - Core application logic
- **Go 1.21+** - High-performance components
- **Bash 4.0+** - System orchestration

### Optional Dependencies
- **PostgreSQL** - Database backend
- **Redis** - Caching and sessions
- **MongoDB** - Document storage

## 🔧 Dependency Management

### How PyPI Handles Dependencies

The Grim Reaper package uses a **hybrid dependency management** approach:

#### ✅ What PyPI Manages
- Python package dependencies (via `install_requires`)
- Python console scripts (via `entry_points`)
- Package data files (bash scripts, configs)

#### ❌ What Requires Manual Installation
- System-level packages (apt, yum, etc.)
- Go runtime and binaries
- External system tools

### Dependency Checking

The package includes built-in dependency checking:

```bash
# Check all dependencies
grim check-deps

# This will verify:
# - System tools (rsync, tar, gzip, etc.)
# - Go runtime
# - Go binaries
# - Python package integrity
```

## 🏗️ Architecture

```
Grim Reaper System
├── Python Package (PyPI)
│   ├── grim_gateway.py    # Main entry point
│   ├── grim_web/          # Web interface
│   ├── grim_core/         # Core functionality
│   └── grim_monitor/      # Monitoring
├── Go Components
│   ├── grim-compression   # High-performance compression
│   └── grim-encryption    # Encryption utilities
└── Bash Scripts
    ├── grim_throne.sh     # Main orchestrator
    ├── backup.sh          # Backup operations
    ├── monitor.sh         # System monitoring
    └── security.sh        # Security operations
```

## 📦 Package Contents

### Python Package (`grim-reaper`)
- **Entry Points**: `grim`, `grim-backup`, `grim-monitor`, `grim-scan`, `grim-health`, `scythe`
- **Data Files**: Bash scripts, configuration files, ASCII art
- **Dependencies**: FastAPI, TuskLang SDK, PyYAML, aiohttp, bcrypt, etc.

### Go Components (`go_grim/`)
- **Binary**: `grim-compression` - High-performance compression engine
- **Dependencies**: Managed via `go.mod`
- **Build**: Requires Go 1.21+ and Make

### Bash Scripts (`sh_grim/`)
- **Orchestrator**: `grim_throne.sh` - Main command router
- **Operations**: Backup, monitoring, security, AI integration
- **Dependencies**: System utilities (rsync, tar, openssl, etc.)

## 🚀 Usage

### Basic Commands
```bash
# Show help
grim help

# Check system health
grim health

# Start backup
grim backup /path/to/backup

# Monitor system
grim monitor

# Security scan
grim scan /path/to/scan

# Check dependencies
grim check-deps
```

### Advanced Usage
```bash
# Orchestrated backup with all systems
grim backup --source /home --dest /backups --compress --encrypt

# Real-time monitoring
grim monitor --interval 30 --metrics

# Security audit
grim scan --vulnerabilities --compliance
```

## 🔍 Troubleshooting

### Common Issues

#### 1. "grim_throne.sh not found"
```bash
# Ensure Grim directory exists
sudo mkdir -p /opt/reaper
sudo chown $USER:$USER /opt/reaper

# Reinstall package
pip install --force-reinstall grim-reaper
```

#### 2. "Go binary not found"
```bash
# Build Go components
cd /opt/reaper/go_grim
make build
```

#### 3. "System tool not found"
```bash
# Install missing system tools
sudo apt install rsync tar gzip bzip2 xz-utils openssl curl wget
```

#### 4. "Permission denied"
```bash
# Fix permissions
sudo chown -R $USER:$USER /opt/reaper
chmod +x /opt/reaper/grim_throne.sh
```

### Dependency Verification
```bash
# Comprehensive dependency check
grim check-deps

# Manual verification
which rsync tar gzip go grim-compression
ls -la /opt/reaper/grim_throne.sh
```

## 📚 Documentation

- **API Documentation**: https://grim.so/docs
- **Installation Guide**: https://grim.so/install
- **Configuration**: https://grim.so/config
- **Troubleshooting**: https://grim.so/troubleshoot

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: https://github.com/cyber-boost/grim/issues
- **Discussions**: https://github.com/cyber-boost/grim/discussions
- **Email**: support@grim.so

---

**Grim Reaper** - The Ultimate Backup, Monitoring, and Security System
