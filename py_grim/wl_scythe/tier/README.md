# Scythe Tier Management System

Comprehensive tier-based access control and usage limit enforcement system.

## Features

- **TierManager**: Core tier management with command access control
- **UsageTracker**: Real-time usage tracking and limit enforcement
- **CLI Wrapper**: Integration with grim_throne.sh command system
- **Command Mapping**: 200+ commands mapped across 4 tiers
- **Usage Limits**: Storage, API calls, alerts, and command limits
- **Real-time Enforcement**: Immediate limit checking and warnings
- **Upgrade Messages**: Automatic pricing information generation

## Quick Start

### Installation

```bash
cd scythe/tier
pip install -r requirements.txt
```

### Database Setup

The tier system requires additional database tables:

```sql
-- Users table with tier information
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT UNIQUE NOT NULL,
    tier TEXT DEFAULT 'FREE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User usage tracking
CREATE TABLE user_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    usage_type TEXT NOT NULL,
    amount INTEGER NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, usage_type, date)
);

-- Tier audit logs
CREATE TABLE tier_audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    action TEXT NOT NULL,
    command TEXT,
    usage_type TEXT,
    amount INTEGER,
    result TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Tier Structure

### FREE Tier (15 commands)
- Basic commands: help, version, status, config
- Basic reports: report, report-status, report-basic
- Basic audit: audit, audit-basic
- Basic cleanup: cleanup, cleanup-temp
- Basic compression: compress

### PRO Tier (35 total commands)
- Optimization: optimize, optimize-all
- Healing: heal, heal-basic
- Advanced compression: compress-advanced, decompress
- Detailed reports: report-detailed, report-performance
- Security audit: audit-security, audit-performance
- Advanced cleanup: cleanup-advanced, cleanup-orphaned
- Backup system: backup, backup-create, backup-list, backup-restore
- Monitoring: monitor, monitor-start, monitor-stop, monitor-status
- AI features: ai-analyze, ai-train, ai-predict (basic versions)
- Deployment: deploy, deploy-test, deploy-staging
- Build system: build, build-basic
- Testing: test, test-basic
- Validation: validate, validate-basic

### MASTER Tier (60 total commands)
- Advanced optimization: optimize-advanced, optimize-custom
- Advanced healing: heal-advanced, heal-custom
- Custom compression: compress-custom, decompress-advanced
- Custom reports: report-custom, report-analytics
- Custom audit: audit-custom, audit-compliance
- Custom cleanup: cleanup-custom
- Advanced backup: backup-advanced, backup-scheduled, backup-encrypted
- Advanced monitoring: monitor-advanced, monitor-custom, monitor-alerts
- Advanced AI: ai-analyze-advanced, ai-train-advanced, ai-predict-advanced
- Production deployment: deploy-production, deploy-advanced, deploy-custom
- Advanced build: build-advanced, build-custom
- Advanced testing: test-advanced, test-custom
- Advanced validation: validate-advanced, validate-custom
- Emergency features: emergency, emergency-stop, emergency-recovery

### REAPER Tier (200+ total commands)
- Enterprise features: All commands with -enterprise suffix
- Cluster features: All commands with -cluster suffix
- Admin features: All commands with admin- prefix
- Full system access: Complete command set

## Usage Limits

| Tier | Storage (GB) | API Calls/Hour | File Size (MB) | Alerts/Day | Commands/Day |
|------|--------------|----------------|----------------|------------|--------------|
| FREE | 1 | 100 | 10 | 5 | 50 |
| PRO | 10 | 500 | 100 | 25 | 200 |
| MASTER | 100 | 2000 | 500 | 100 | 1000 |
| REAPER | 1000 | 10000 | 2000 | 500 | 5000 |

## Overage Pricing

| Resource | FREE | PRO | MASTER | REAPER |
|----------|------|-----|--------|--------|
| Storage (per GB) | $0.10 | $0.08 | $0.05 | $0.02 |
| API Calls (per call) | $0.001 | $0.0008 | $0.0005 | $0.0002 |
| Alerts (per alert) | $0.01 | $0.008 | $0.005 | $0.002 |
| Commands (per command) | $0.05 | $0.04 | $0.025 | $0.01 |

## CLI Integration

### Basic Usage

```bash
# Check command access
./tier_check.sh check_access user123 optimize

# Check usage limits
./tier_check.sh check_limits user123 storage_gb 5

# Get available commands
./tier_check.sh get_commands user123

# Get user usage
./tier_check.sh get_usage user123

# Get upgrade message
./tier_check.sh upgrade_message FREE PRO
```

### Integration with grim_throne.sh

Add to your grim_throne.sh script:

```bash
# Check tier access before command execution
check_tier_access() {
    local user_id="$1"
    local command="$2"
    
    result=$(./tier_check.sh check_access "$user_id" "$command")
    allowed=$(echo "$result" | jq -r '.allowed')
    
    if [[ "$allowed" == "true" ]]; then
        return 0
    else
        message=$(echo "$result" | jq -r '.message')
        echo "Access denied: $message"
        return 1
    fi
}

# Usage in command execution
if check_tier_access "$USER_ID" "$COMMAND"; then
    # Execute command
    execute_command "$COMMAND"
else
    exit 1
fi
```

## Python API

### Basic Usage

```python
from scythe.tier.tier_manager import TierManager
from scythe.tier.usage_tracker import UsageTracker

# Initialize managers
tier_manager = TierManager(db_manager)
usage_tracker = UsageTracker(tier_manager)

# Check command access
allowed, message = tier_manager.check_command_access("optimize", "PRO")
print(f"Access: {allowed}, Message: {message}")

# Track command execution
result = usage_tracker.track_command_execution("user123", "optimize")
if result["allowed"]:
    print("Command executed successfully")
else:
    print(f"Command blocked: {result['message']}")

# Check usage limits
allowed, info = tier_manager.check_usage_limits("user123", "PRO", "storage_gb", 5)
print(f"Storage allowed: {allowed}")

# Get real-time usage
usage = usage_tracker.get_real_time_usage("user123")
print(f"Current usage: {usage}")
```

### Advanced Usage

```python
# Get available commands for tier
commands = tier_manager.get_available_commands("PRO")
print(f"Available commands: {commands}")

# Get user usage statistics
usage_stats = tier_manager.get_user_usage("user123", "storage_gb")
print(f"Usage stats: {usage_stats}")

# Generate upgrade message
message = tier_manager.generate_upgrade_message("FREE", "PRO")
print(f"Upgrade message: {message}")

# Get tier statistics
stats = tier_manager.get_tier_statistics()
print(f"Tier statistics: {stats}")

# Generate usage warnings
warnings = usage_tracker.generate_usage_warnings("user123")
for warning in warnings:
    print(f"Warning: {warning}")
```

## Configuration

### Tier Configuration File

Create `~/.scythe/tier_config.json`:

```json
{
  "default_tier": "FREE",
  "enforce_limits": true,
  "track_usage": true,
  "show_warnings": true,
  "cache_ttl": 3600,
  "warning_threshold": 0.1
}
```

### Environment Variables

```bash
export TIER_DEFAULT_TIER=FREE
export TIER_ENFORCE_LIMITS=true
export TIER_TRACK_USAGE=true
export TIER_LOG_LEVEL=INFO
```

## Monitoring and Logging

### Audit Logs

All tier operations are logged:

```sql
SELECT * FROM tier_audit_logs 
WHERE user_id = 'user123' 
ORDER BY created_at DESC;
```

### Usage Reports

Generate usage reports:

```python
# Get daily usage report
usage = tier_manager.get_user_usage("user123", start_date=datetime.now() - timedelta(days=7))

# Get tier statistics
stats = tier_manager.get_tier_statistics()

# Get real-time usage
realtime = usage_tracker.get_real_time_usage("user123")
```

## Security

- All tier checks are validated against database
- Usage tracking includes audit trails
- Real-time cache with TTL expiration
- Input validation and sanitization
- SQL injection prevention
- Rate limiting on tier checks

## Performance

- In-memory cache for real-time tracking
- Database indexing on user_id and date
- Efficient command mapping with enums
- Minimal database queries
- Async usage tracking where possible

## Testing

### Unit Tests

```python
# Test command access
def test_command_access():
    tier_manager = TierManager()
    allowed, message = tier_manager.check_command_access("optimize", "FREE")
    assert not allowed
    assert "Upgrade to PRO" in message

# Test usage limits
def test_usage_limits():
    tier_manager = TierManager()
    allowed, info = tier_manager.check_usage_limits("user123", "FREE", "storage_gb", 2)
    assert not allowed
    assert info["overage"] == 1
```

### Integration Tests

```bash
# Test CLI integration
./tier_check.sh check_access user123 help
./tier_check.sh check_limits user123 storage_gb 1
./tier_check.sh get_commands user123
```

## Deployment

### Production Checklist

1. Set up database tables
2. Configure tier limits
3. Set up monitoring and alerts
4. Configure logging
5. Test all tier transitions
6. Verify CLI integration
7. Set up usage tracking
8. Configure upgrade flows

### Monitoring

- Track tier upgrade/downgrade rates
- Monitor usage limit violations
- Alert on unusual usage patterns
- Track command access denials
- Monitor system performance

## Support

For tier system support:

1. Check tier configuration
2. Verify user tier assignments
3. Review usage statistics
4. Check audit logs
5. Test CLI integration
6. Contact development team 