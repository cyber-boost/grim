# 🗡️ Scythe Orchestrator

**The Grim Reaper's Command Center** - High-performance orchestrator that coordinates sh_grim, go_grim, and py_grim into a unified backup and system management platform.

## Architecture

Scythe acts as the central nervous system for the Grim Reaper ecosystem:

```
    🗡️ SCYTHE ORCHESTRATOR
           |
    ┌──────┼──────┐
    │      │      │
sh_grim go_grim py_grim
 (ops)  (speed) (web)
```

## Quick Start

```bash
# Check system health
python3 scythe/scythe.py health

# Execute backup
python3 scythe/scythe.py backup /path/to/data --name my_backup

# Get system status  
python3 scythe/scythe.py status
```

## Core Features

### 🏥 Health Monitoring
- Real-time health checks for all subsystems
- Performance monitoring and response time tracking
- Automatic failure detection and reporting

### 🎯 Coordinated Operations
- **Backup Operations**: Orchestrates scan → compress → store → verify
- **System Integration**: Seamless communication between bash, Go, and Python components
- **Error Handling**: Robust error recovery and operation rollback

### ⚡ High Performance
- Async/await architecture for maximum concurrency
- Intelligent resource management and load balancing
- Sub-second response times for coordination tasks

## System Coordination

### sh_grim (Bash Operations)
- File scanning and metadata collection
- System health checks and monitoring  
- Security and audit operations

### go_grim (Performance Engine)
- High-speed compression and deduplication
- Parallel file processing
- Resource-intensive operations

### py_grim (Web Services)
- REST API endpoints
- Web dashboard and monitoring
- Database and metadata management

## Configuration

Create `config.yaml` in the reaper root:

```yaml
logging:
  level: INFO
  file: scythe.log

systems:
  sh_grim:
    enabled: true
    health_check_script: health.sh
  go_grim:
    enabled: true
    binary: build/grim-compression
  py_grim:
    enabled: true
    module: grim_web.app

operations:
  timeout: 300
  max_concurrent: 5
  retry_attempts: 3
```

## API

### Health Checks
```python
health = await orchestrator.health_check_all()
# Returns health status for all systems
```

### Backup Operations
```python
result = await orchestrator.execute_backup('/data', 'backup_name')
# Coordinates full backup workflow
```

### System Status
```python
status = orchestrator.get_system_status()
# Returns comprehensive system information
```

## Development

### Prerequisites
- Python 3.8+
- go_grim compiled (run `make build` in go_grim/)
- sh_grim modules available
- py_grim modules importable

### Testing
```bash
# Test health checks
python3 scythe/scythe.py health

# Test backup with sample data
mkdir -p test_data
echo "test content" > test_data/test.txt
python3 scythe/scythe.py backup test_data --name test_backup
```

## Mission Status

**SCYTHE ORCHESTRATOR: OPERATIONAL** ✅

- ✅ Core orchestration engine built
- ✅ Health monitoring system active
- ✅ Backup coordination workflow implemented
- ✅ CLI interface ready
- ✅ Async architecture for maximum performance

**Ready to DOMINATE coordination tasks and CRUSH complexity!**