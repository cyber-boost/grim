# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Overview

The Grim Reaper System is a comprehensive data protection, backup, monitoring, and security platform built with multiple language components:

1. **sh_grim/** - Bash operations engine with 60+ modules for system operations
2. **go_grim/** - High-performance Go compression and file tools  
3. **py_grim/** - Python web services with FastAPI and AI integration
4. **scythe/** - Central orchestrator coordinating all components
5. **tsk_flask/** - Flask-based admin web interface using Flask-TSK framework
6. **rb_grim/** - Ruby implementation with gem packaging
7. **php_grim/** - PHP components with Composer integration

## Essential Development Commands

### System Build and Deploy
```bash
# Master installation (installs all dependencies)
sudo ./master-install.sh

# Build complete release
./admin/build.sh build

# Deploy latest build
sudo ./admin/deploy.sh

# Full system installation
sudo ./install.sh
```

### Go Components (go_grim/)
```bash
# Build all tools (compression, scanner, transfer)
cd go_grim && make build-all-tools

# Run tests with coverage
cd go_grim && make test-coverage

# Format and lint code
cd go_grim && make format && make lint

# Run compression benchmarks
cd go_grim && make benchmark-compression

# Security scanning
cd go_grim && make security

# Quick test all tools
cd go_grim && make quick-test

# Development mode with hot reload
cd go_grim && make dev
```

### Python Components (py_grim/)
```bash
# Install dependencies
cd py_grim && pip install -r requirements.txt

# Run FastAPI server (development)
cd py_grim/grim_web && python server.py --dev

# Run tests
cd py_grim && pytest

# TuskLang integration testing
cd py_grim && python test_tusktsk_integration.py

# Auto-backup service
cd py_grim && python auto_backup.py --config ../config/auto_backup.yaml
```

### Ruby Components (rb_grim/)
```bash
# Install dependencies
cd rb_grim && bundle install

# Build gem
cd rb_grim && gem build grim-reaper.gemspec

# Install gem locally
cd rb_grim && gem install ./grim-reaper-*.gem

# Run tests
cd rb_grim && bundle exec rspec

# Linting
cd rb_grim && bundle exec rubocop
```

### PHP Components (php_grim/)
```bash
# Install dependencies
cd php_grim && composer install

# Run tests
cd php_grim && composer test

# Generate coverage report
cd php_grim && composer test-coverage

# Static analysis
cd php_grim && composer stan

# Install Grim dependencies
cd php_grim && composer grim-install-deps
```

### Flask-TSK Admin Server (tsk_flask/)
**IMPORTANT: This component uses Flask-TSK framework with strict patterns**
```bash
# Install Flask-TSK dependencies
cd tsk_flask && pip install -r requirements.txt

# Run admin server
cd tsk_flask && python grim_admin_server.py

# Production server with SSL
cd tsk_flask && python grim_admin_server.py --ssl --port 4746
```

### Testing Commands
```bash
# Run master test suite
python test_data/master_test_runner.py

# Run comprehensive testing framework
./sh_grim/testing-framework.sh run

# Run specific test categories
./sh_grim/testing-framework.sh run unit
./sh_grim/testing-framework.sh run integration
./sh_grim/testing-framework.sh run performance

# Performance benchmarks
./sh_grim/testing-framework.sh benchmark

# CI mode with HTML report
./sh_grim/testing-framework.sh ci --report-format html

# System health checks
./sh_grim/health_fixed.sh check
```

## Architecture Overview

### Multi-Language Integration
- **Bash (sh_grim)**: 60+ system operation modules (backup, monitor, security, etc.)
- **Go (go_grim)**: High-performance compression, scanning, and transfer tools
- **Python (py_grim)**: FastAPI web services, AI/ML integration, database operations
- **Ruby (rb_grim)**: Ruby gem wrapper providing unified access to all modules
- **PHP (php_grim)**: PHP SDK with Composer package for web integration
- **Python (tsk_flask)**: Flask-TSK admin interface with Herd authentication
- **Scythe Orchestrator**: Async Python coordinator for all components

### Key Integration Points
- **Database**: Shared SQLite database (`db/grimm.db`) for coordination
- **Configuration**: YAML-based config (`config.yaml`) and component-specific configs
- **Logging**: Centralized logging in `logs/` directory with structured JSON
- **Build System**: Automated builds with manifests in `builds/` directory
- **Command Routing**: Unified CLI (`grim`) routes to language-specific throne scripts

### Critical File Locations
- **Config**: `config.yaml` (main), `config/` (component-specific)
- **Database**: `db/grimm.db`
- **Logs**: `logs/` (all components log here)
- **Backups**: `backups/` (daily, hourly, weekly, monthly)
- **Test Data**: `test_data/` (extensive test suites)
- **Build Artifacts**: `builds/` (versioned releases)

## Flask-TSK Development Rules

**CRITICAL: The tsk_flask component follows strict Flask-TSK patterns from Cursor rules:**

### Authentication
- Use `from tsk_flask.herd import Herd, get_herd` 
- Use `@herd.require_auth` for protected routes
- Never use flask_login or custom session management

### Database Operations
- Use `from tsk_flask.herd.elephants.tantor import get_tantor`
- Never use direct sqlite3, psycopg2, or SQLAlchemy

### HTTP Requests
- Use `from tsk_flask.herd.elephants.dumbo import get_dumbo`
- Never use requests or urllib directly

### File Uploads
- Use `from tsk_flask.herd.elephants.jumbo import get_jumbo`
- Never use request.files directly

### Background Jobs  
- Use `from tsk_flask.herd.elephants.horton import get_horton`
- Never use celery, threading, or multiprocessing

### Security
- Use `from tsk_flask.herd.elephants.satao import init_satao`
- Never implement custom rate limiting or IP blocking

### Template Engine
- Never use jinja2 - always use Flask-TSK rendering methods
- Never use render_template() - use Flask-TSK patterns

## Development Workflows

### Working with Bash Modules (sh_grim/)
- Each module is standalone with specific functionality
- Integration through shared database and logging
- Common modules: `backup.sh`, `scan.sh`, `monitor.sh`, `scythe.sh`
- Use `./sh_grim/init.sh` to initialize environment

### Working with Go Tools (go_grim/)  
- Three main tools: compression, scanner, transfer
- All built with comprehensive Makefile
- JSON output for integration with other components
- Benchmarking and performance testing built-in
- Cross-platform builds available via `make build-all`

### Working with Python Services (py_grim/)
- FastAPI-based with async support
- Core modules: `grim_core`, `grim_web`, `grim_gateway`, `grim_monitor`
- AI/ML integration through TuskLang Python SDK (tusktsk>=2.0.3)
- Database operations coordinated through shared SQLite
- Auto-backup system with intelligent compression and hot file detection

### Working with Ruby Components (rb_grim/)
- Gem-based distribution (grim-reaper gem)
- Provides Ruby interface to all Grim components
- Located in `bin/` for executables and `lib/grim_reaper/` for modules
- Version management through gemspec

### Working with PHP Components (php_grim/)
- Composer-based package management
- PSR-4 autoloading standard
- CLI tools in `bin/` directory
- Web integration capabilities through SDK

### Scythe Orchestration
- Central coordination point in `scythe/core/orchestrator.py`
- Status tracking in `scythe/status.json`
- Coordinates operations across all language components
- Use `python scythe/scythe.py` for orchestrated operations

## Testing and Quality Assurance

### Test Framework
- Master test runner: `python test_data/master_test_runner.py`
- Comprehensive test framework: `./sh_grim/testing-framework.sh`
- Test suites: integration, performance, smoke, user acceptance
- Test data in `test_data/` with 400+ test files
- Language-specific testing: Go (make test), Python (pytest), Ruby (rspec), PHP (composer test)

### Build Verification
- Automated builds with manifest generation (`manifest.tsk`)
- Checksums and signatures for all builds (`.md5`, `.sha256`)
- Build reports track all components and dependencies
- Latest builds accessible via nginx configuration

### Log Analysis
- Structured JSON logging across all components
- Centralized in `logs/` directory
- Key logs: `backup.log`, `scythe.log`, `master_test_runner.log`
- Real-time monitoring and analysis capabilities

## Security and Compliance

### License Protection
- Handled by `scythe.sh` module with monitoring
- Software compliance tracking and reporting
- Automated license verification

### Encryption and Security
- Built-in encryption for backups and sensitive data
- Security auditing through `security.sh` module
- Vulnerability scanning and threat detection
- Access control and file permission management

## Common Operational Tasks

### System Health and Monitoring
```bash
# Complete system health check
./sh_grim/health_fixed.sh check

# Real-time monitoring
./sh_grim/monitor.sh start /path/to/watch

# System status via orchestrator
python scythe/scythe.py status
```

### Backup Operations
```bash
# Orchestrated backup
python scythe/scythe.py backup /path/to/data --name backup_name

# Direct backup module
./sh_grim/backup.sh create daily

# Restore operations
./sh_grim/restore.sh recover backup.tar.gz /restore/path

# Install auto-backup service
./sh_grim/install_auto_backup.sh
```

### Performance and Optimization
```bash
# System optimization
./sh_grim/blacksmith.sh optimize all

# Compression benchmarking
cd go_grim && make benchmark-compression

# Performance testing
./sh_grim/performance_testing.sh
```

### Web Services Management
```bash
# Start all web services
./sh_grim/web-manager.sh start all

# Individual services
./sh_grim/web-manager.sh start api     # FastAPI
./sh_grim/web-manager.sh start admin   # Flask-TSK admin
./sh_grim/web-manager.sh start monitor # Monitoring UI

# Service status
./sh_grim/web-manager.sh status
```

## Integration Notes

### Multi-Component Coordination
1. **Always run health checks** before major operations
2. **Use scythe orchestrator** for coordinated cross-component operations  
3. **Monitor logs** in `logs/` directory for troubleshooting
4. **Follow Flask-TSK patterns** strictly in tsk_flask component
5. **Verify builds** using provided checksums and manifests
6. **Test comprehensively** using the extensive test framework

### Performance Considerations
- Go components handle high-performance operations (compression, scanning)
- Python components handle complex logic and web interfaces
- Bash components handle system integration and orchestration
- Ruby and PHP provide additional language-specific interfaces
- All components coordinate through shared database and file system

### Package Distribution
- **NPM**: `npm install grim-reaper` (Node.js package)
- **PyPI**: Available through pip installation
- **RubyGems**: `gem install grim-reaper`
- **Packagist**: `composer require grim/reaper` (PHP)
- **Go Modules**: `go get github.com/grim/grim`

The system is architected for enterprise-grade data protection with military-level security, comprehensive monitoring, and zero-tolerance for data loss.