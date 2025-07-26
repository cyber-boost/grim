# GRIM REAPER DUAL LICENSING SYSTEMS - IMPLEMENTATION PLAN

## OVERVIEW

This document outlines TWO SEPARATE licensing systems:

1. **GRIM'S INTERNAL SYSTEM** - Monetizing Grim Reaper itself with tiered access
2. **SCYTHE LICENSE SYSTEM** - A white-label licensing platform users can deploy for their own software

Both systems leverage the GRIMS_MOTHER database but serve different purposes and customer bases.

---

## SYSTEM ARCHITECTURE - TWO DISTINCT PLATFORMS

### 🏢 GRIM'S INTERNAL SYSTEM (grim.so)
**Purpose**: Monetize the Grim Reaper platform itself
**Target**: DevOps teams, enterprises, system administrators
**Database**: PostgreSQL (GRIMS_MOTHER) with `grim_*` tables
**Revenue Model**: SaaS subscriptions for Grim Reaper access

### ⚔️ SCYTHE LICENSE SYSTEM (white-label)
**Purpose**: License management platform that users can deploy for their own software
**Target**: Software vendors, SaaS companies, independent developers  
**Database**: Local SQLite (`scythe.db`) for CLI users, separate from GRIMS_MOTHER
**Revenue Model**: License to use the licensing platform + transaction fees

**KEY DISTINCTION**: 
- **Grim Internal**: Uses PostgreSQL GRIMS_MOTHER database (cloud/enterprise)
- **Scythe License**: Uses local SQLite `scythe.db` (user-deployed instances)

---

## 1. DATABASE SCHEMA (GRIMS_MOTHER Integration)

### 🏢 GRIM'S INTERNAL SYSTEM TABLES

Core Tables for Grim Reaper Monetization

```sql
-- Users and Authentication
CREATE TABLE grim_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    api_key VARCHAR(128) UNIQUE,
    tier VARCHAR(20) DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    trial_end_date DATE,
    stripe_customer_id VARCHAR(100)
);

-- Subscription Management
CREATE TABLE grim_subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    tier VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'active', -- active, cancelled, past_due, trialing
    stripe_subscription_id VARCHAR(100),
    current_period_start DATE,
    current_period_end DATE,
    cancel_at_period_end BOOLEAN DEFAULT 0,
    trial_end DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES grim_users(id)
);

-- Command Access Control
CREATE TABLE grim_command_tiers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    command_name VARCHAR(100) NOT NULL,
    required_tier VARCHAR(20) NOT NULL,
    category VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Usage Tracking
CREATE TABLE grim_usage_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    resource_type VARCHAR(50) NOT NULL, -- storage, alerts, api_calls, file_size
    usage_amount BIGINT DEFAULT 0,
    billing_period DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES grim_users(id)
);

-- Command Usage Log
CREATE TABLE grim_command_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    command VARCHAR(100) NOT NULL,
    arguments TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    allowed BOOLEAN NOT NULL,
    user_tier VARCHAR(20),
    execution_time_ms INTEGER,
    ip_address VARCHAR(45),
    FOREIGN KEY (user_id) REFERENCES grim_users(id)
);

-- Billing and Overages
CREATE TABLE grim_billing_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    billing_period DATE NOT NULL,
    base_amount DECIMAL(10,2) DEFAULT 0,
    storage_overage DECIMAL(10,2) DEFAULT 0,
    alert_overage DECIMAL(10,2) DEFAULT 0,
    api_overage DECIMAL(10,2) DEFAULT 0,
    file_overage DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    stripe_invoice_id VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES grim_users(id)
);

-- Storage Allocation
CREATE TABLE grim_storage_allocation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    allocated_gb DECIMAL(10,3) NOT NULL,
    used_gb DECIMAL(10,3) DEFAULT 0,
    provider VARCHAR(50), -- hetzner, backblaze, aws
    bucket_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES grim_users(id)
);
```

### Indexes for Performance

```sql
CREATE INDEX idx_grim_users_email ON grim_users(email);
CREATE INDEX idx_grim_users_api_key ON grim_users(api_key);
CREATE INDEX idx_grim_users_tier ON grim_users(tier);
CREATE INDEX idx_grim_subscriptions_user_id ON grim_subscriptions(user_id);
CREATE INDEX idx_grim_command_usage_user_id ON grim_command_usage(user_id);
CREATE INDEX idx_grim_command_usage_timestamp ON grim_command_usage(timestamp);
CREATE INDEX idx_grim_usage_tracking_user_period ON grim_usage_tracking(user_id, billing_period);
```

### ⚔️ SCYTHE LICENSE SYSTEM TABLES

White-label licensing platform that users can deploy for their own software products.

```sql
-- Scythe License Vendors (Users of the Scythe platform)
CREATE TABLE scythe_vendors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    company_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    api_key VARCHAR(128) UNIQUE,
    scythe_plan VARCHAR(20) DEFAULT 'starter', -- starter, professional, enterprise
    domain VARCHAR(255), -- their custom domain for license server
    webhook_url VARCHAR(500), -- callback for license events
    stripe_account_id VARCHAR(100), -- their Stripe Connect account
    commission_rate DECIMAL(5,4) DEFAULT 0.05, -- 5% platform fee
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    monthly_license_limit INTEGER DEFAULT 100
);

-- Software Products managed by vendors
CREATE TABLE scythe_products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_key VARCHAR(100) UNIQUE NOT NULL, -- unique identifier for API calls
    public_key TEXT, -- RSA public key for license verification
    private_key TEXT, -- RSA private key for license generation
    license_template TEXT, -- JSON template for license structure
    webhook_secret VARCHAR(128), -- secret for webhook validation
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    FOREIGN KEY (vendor_id) REFERENCES scythe_vendors(id)
);

-- License Plans (tiers) for each product
CREATE TABLE scythe_license_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    plan_key VARCHAR(50) NOT NULL, -- for API identification
    features JSON, -- JSON object of features/limits
    max_installations INTEGER DEFAULT 1,
    duration_days INTEGER, -- NULL for lifetime
    price_cents INTEGER, -- price in cents
    stripe_price_id VARCHAR(100), -- Stripe price ID
    is_active BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES scythe_products(id)
);

-- End Customer Licenses
CREATE TABLE scythe_licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    plan_id INTEGER NOT NULL,
    license_key VARCHAR(255) UNIQUE NOT NULL,
    customer_email VARCHAR(255),
    customer_name VARCHAR(255),
    installation_id VARCHAR(128), -- unique per installation
    hardware_fingerprint VARCHAR(255), -- for hardware locking
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    last_validated TIMESTAMP,
    validation_count INTEGER DEFAULT 0,
    max_validations INTEGER, -- NULL for unlimited
    status VARCHAR(20) DEFAULT 'active', -- active, suspended, expired, revoked
    metadata JSON, -- custom data for the license
    stripe_payment_intent_id VARCHAR(100),
    FOREIGN KEY (product_id) REFERENCES scythe_products(id),
    FOREIGN KEY (plan_id) REFERENCES scythe_license_plans(id)
);

-- License Validation Logs
CREATE TABLE scythe_license_validations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_id INTEGER NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    hardware_fingerprint VARCHAR(255),
    validation_result VARCHAR(20), -- valid, expired, invalid, suspended
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    additional_data JSON,
    FOREIGN KEY (license_id) REFERENCES scythe_licenses(id)
);

-- Revenue Tracking
CREATE TABLE scythe_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    license_id INTEGER,
    transaction_type VARCHAR(50), -- license_sale, commission, payout
    amount_cents INTEGER NOT NULL,
    platform_fee_cents INTEGER DEFAULT 0,
    vendor_payout_cents INTEGER NOT NULL,
    stripe_payment_id VARCHAR(100),
    currency VARCHAR(3) DEFAULT 'USD',
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'completed',
    FOREIGN KEY (vendor_id) REFERENCES scythe_vendors(id),
    FOREIGN KEY (license_id) REFERENCES scythe_licenses(id)
);

-- Scythe System Usage (for billing vendors)
CREATE TABLE scythe_usage_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    resource_type VARCHAR(50), -- api_calls, licenses_generated, validations
    usage_amount INTEGER DEFAULT 0,
    billing_period DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES scythe_vendors(id)
);
```

### Scythe System Indexes

```sql
CREATE INDEX idx_scythe_vendors_email ON scythe_vendors(email);
CREATE INDEX idx_scythe_vendors_api_key ON scythe_vendors(api_key);
CREATE INDEX idx_scythe_products_vendor_id ON scythe_products(vendor_id);
CREATE INDEX idx_scythe_products_product_key ON scythe_products(product_key);
CREATE INDEX idx_scythe_licenses_product_id ON scythe_licenses(product_id);
CREATE INDEX idx_scythe_licenses_license_key ON scythe_licenses(license_key);
CREATE INDEX idx_scythe_licenses_status ON scythe_licenses(status);
CREATE INDEX idx_scythe_validations_license_id ON scythe_license_validations(license_id);
CREATE INDEX idx_scythe_validations_timestamp ON scythe_license_validations(timestamp);
CREATE INDEX idx_scythe_transactions_vendor_id ON scythe_transactions(vendor_id);
```

---

## 2. TIER COMMAND MAPPING

### Pre-populate Command Tier Table

```sql
-- FREE TIER COMMANDS (15 total)
INSERT INTO grim_command_tiers (command_name, required_tier, category, description) VALUES
('help', 'free', 'basic', 'Show available commands and usage'),
('status', 'free', 'basic', 'Show system status'),
('health', 'free', 'basic', 'Basic health check'),
('init', 'free', 'basic', 'Initialize grim system'),
('version', 'free', 'basic', 'Show version information'),
('backup', 'free', 'backup', 'Create basic backup (no encryption)'),
('restore', 'free', 'backup', 'Restore from backup (basic verification)'),
('scan', 'free', 'backup', 'Scan files and directories (limited depth)'),
('monitor-status', 'free', 'monitoring', 'View monitoring status (read-only)'),
('list', 'free', 'basic', 'List backups and basic info'),
('config-get', 'free', 'config', 'View configuration settings'),
('compress', 'free', 'performance', 'Basic compression (gzip only)'),
('cleanup-temp', 'free', 'maintenance', 'Clean temporary files only'),
('verify', 'free', 'security', 'Basic file verification (checksums only)'),
('report-daily', 'free', 'reporting', 'Generate basic daily report');

-- PRO TIER COMMANDS (20 additional)
INSERT INTO grim_command_tiers (command_name, required_tier, category, description) VALUES
('backup-create', 'pro', 'backup', 'Advanced backup with options'),
('backup-verify', 'pro', 'backup', 'Verify backup integrity'),
('backup-list', 'pro', 'backup', 'List all backups with details'),
('auto-backup', 'pro', 'backup', 'Intelligent auto-backup system'),
('encrypt', 'pro', 'security', 'File encryption/decryption'),
('dedup', 'pro', 'performance', 'Deduplication for storage efficiency'),
('monitor-start', 'pro', 'monitoring', 'Start active monitoring'),
('monitor-stop', 'pro', 'monitoring', 'Stop monitoring processes'),
('monitor-events', 'pro', 'monitoring', 'View monitoring events'),
('security-scan', 'pro', 'security', 'Basic security scanning'),
('quarantine-isolate', 'pro', 'security', 'Isolate suspicious files'),
('compress-benchmark', 'pro', 'performance', 'Compression performance testing'),
('optimize-storage', 'pro', 'performance', 'Basic storage optimization'),
('cleanup-logs', 'pro', 'maintenance', 'Log file cleanup and rotation'),
('notify', 'pro', 'monitoring', 'Send notifications/alerts'),
('lookouts-start', 'pro', 'monitoring', 'Start system lookouts'),
('credentials', 'pro', 'security', 'Basic credential management'),
('restore-verify', 'pro', 'backup', 'Restore with full verification'),
('backup-schedule', 'pro', 'backup', 'Schedule automated backups'),
('security-encrypt', 'pro', 'security', 'Security-focused encryption');

-- MASTER TIER COMMANDS (25 additional)
INSERT INTO grim_command_tiers (command_name, required_tier, category, description) VALUES
('ai-analyze', 'master', 'ai', 'AI-powered file analysis'),
('ai-optimize', 'master', 'ai', 'AI optimization recommendations'),
('ai-predict', 'master', 'ai', 'Predictive analytics for issues'),
('ai-recommend', 'master', 'ai', 'Smart suggestions engine'),
('security-audit', 'master', 'security', 'Comprehensive security audit'),
('audit-full', 'master', 'security', 'Complete security audit'),
('audit-start', 'master', 'security', 'Start compliance auditing'),
('compliance-check', 'master', 'security', 'Regulatory compliance verification'),
('distributed-arch', 'master', 'enterprise', 'Distributed architecture management'),
('load-balancing', 'master', 'enterprise', 'Load balancer configuration'),
('dashboard', 'master', 'web', 'Advanced monitoring dashboard'),
('web', 'master', 'web', 'Web-based dashboard'),
('performance-testing', 'master', 'testing', 'Comprehensive performance tests'),
('quality-assurance', 'master', 'testing', 'QA framework and testing'),
('user-acceptance', 'master', 'testing', 'User acceptance testing'),
('testing-framework', 'master', 'testing', 'Advanced testing capabilities'),
('optimize-all', 'master', 'performance', 'System-wide optimization'),
('heal-diagnose', 'master', 'maintenance', 'System healing and diagnosis'),
('security-testing', 'master', 'security', 'Security vulnerability testing'),
('quarantine-analyze', 'master', 'security', 'Analyze quarantined files'),
('service-discovery', 'master', 'enterprise', 'Service discovery and registration'),
('remote', 'master', 'enterprise', 'Remote operations management'),
('smart-suggestions', 'master', 'ai', 'Intelligent automation suggestions'),
('predictive-analytics', 'master', 'ai', 'Advanced pattern recognition'),
('nlp-interface', 'master', 'ai', 'Natural language processing');

-- REAPER TIER COMMANDS (All remaining commands)
-- Note: REAPER tier gets access to ALL commands, including future ones
INSERT INTO grim_command_tiers (command_name, required_tier, category, description) VALUES
('ai-train', 'reaper', 'ai-production', 'Train custom AI models'),
('ai-production-deploy', 'reaper', 'ai-production', 'Deploy AI to production'),
('cloud-native-platform', 'reaper', 'cloud', 'Full cloud integration'),
('serverless-functions', 'reaper', 'cloud', 'Serverless deployment'),
('white-label-config', 'reaper', 'enterprise', 'White-label customization'),
('custom-branding', 'reaper', 'enterprise', 'Custom UI/branding options'),
('multi-tenant-mgmt', 'reaper', 'enterprise', 'Multi-tenant administration'),
('enterprise-sso', 'reaper', 'enterprise', 'Single sign-on integration'),
('custom-development', 'reaper', 'enterprise', 'On-demand custom features');
```

---

## 3. TIER LIMITS CONFIGURATION

### Usage Limits Table

```sql
CREATE TABLE grim_tier_limits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tier VARCHAR(20) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    limit_value BIGINT NOT NULL,
    unit VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert tier limits
INSERT INTO grim_tier_limits (tier, resource_type, limit_value, unit) VALUES
-- FREE TIER
('free', 'storage', 1, 'GB'),
('free', 'alerts', 10, 'per_month'),
('free', 'max_file_size', 100, 'MB'),
('free', 'backup_frequency', 1440, 'minutes'), -- daily
('free', 'monitor_targets', 1, 'count'),

-- PRO TIER  
('pro', 'storage', 25, 'GB'),
('pro', 'alerts', 100, 'per_month'),
('pro', 'max_file_size', 1, 'GB'),
('pro', 'backup_frequency', 60, 'minutes'), -- hourly
('pro', 'monitor_targets', 5, 'count'),

-- MASTER TIER
('master', 'storage', 100, 'GB'),
('master', 'alerts', 500, 'per_month'),
('master', 'api_calls', 10000, 'per_month'),
('master', 'max_file_size', 10, 'GB'),
('master', 'backup_frequency', 15, 'minutes'),
('master', 'monitor_targets', 25, 'count'),

-- REAPER TIER
('reaper', 'storage', 1000, 'GB'),
('reaper', 'alerts', 5000, 'per_month'),
('reaper', 'api_calls', 100000, 'per_month'),
('reaper', 'max_file_size', 100, 'GB'),
('reaper', 'backup_frequency', 1, 'minutes'), -- real-time
('reaper', 'monitor_targets', 100, 'count');
```

---

## 4. ACCESS CONTROL IMPLEMENTATION PLAN

### Phase 1: Database Integration

```python
# /opt/reaper/py_grim/tier_manager.py
import sqlite3
import os
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, List

class TierManager:
    def __init__(self):
        self.db_path = os.environ.get('GRIMS_MOTHER')
        if not self.db_path:
            raise ValueError("GRIMS_MOTHER environment variable not set")
    
    def get_db_connection(self):
        """Get connection to GRIMS_MOTHER database"""
        return sqlite3.connect(self.db_path)
    
    def check_command_access(self, user_id: int, command: str) -> tuple[bool, str]:
        """Check if user has access to command"""
        with self.get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user tier
            cursor.execute("SELECT tier FROM grim_users WHERE id = ?", (user_id,))
            user_result = cursor.fetchone()
            if not user_result:
                return False, "User not found"
            
            user_tier = user_result[0]
            
            # Get command requirements
            cursor.execute("""
                SELECT required_tier, description 
                FROM grim_command_tiers 
                WHERE command_name = ?
            """, (command,))
            
            command_result = cursor.fetchone()
            if not command_result:
                # Command not in tier system - allow for now
                return True, ""
            
            required_tier, description = command_result
            
            # Check tier hierarchy
            tier_hierarchy = ['free', 'pro', 'master', 'reaper']
            user_tier_level = tier_hierarchy.index(user_tier) if user_tier in tier_hierarchy else -1
            required_tier_level = tier_hierarchy.index(required_tier) if required_tier in tier_hierarchy else 0
            
            access_granted = user_tier_level >= required_tier_level
            
            # Log the access attempt
            cursor.execute("""
                INSERT INTO grim_command_usage 
                (user_id, command, allowed, user_tier, timestamp)
                VALUES (?, ?, ?, ?, ?)
            """, (user_id, command, access_granted, user_tier, datetime.now()))
            
            conn.commit()
            
            if not access_granted:
                upgrade_message = self._get_upgrade_message(user_tier, required_tier)
                return False, upgrade_message
            
            return True, ""
    
    def _get_upgrade_message(self, current_tier: str, required_tier: str) -> str:
        """Generate upgrade message for tier restrictions"""
        tier_prices = {
            'pro': '$20/month',
            'master': '$49/month', 
            'reaper': '$99/month'
        }
        
        price = tier_prices.get(required_tier, '')
        return f"""
❌ This command requires {required_tier.upper()} tier or higher
💰 Your current tier: {current_tier.upper()}
🚀 Upgrade to {required_tier.upper()} ({price}) at: https://grim.so/upgrade
📊 See all features: https://grim.so/pricing
        """.strip()
    
    def check_usage_limits(self, user_id: int, resource_type: str, usage_amount: int = 1) -> tuple[bool, str]:
        """Check if user is within usage limits"""
        with self.get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user tier
            cursor.execute("SELECT tier FROM grim_users WHERE id = ?", (user_id,))
            user_result = cursor.fetchone()
            if not user_result:
                return False, "User not found"
            
            user_tier = user_result[0]
            
            # Get tier limits
            cursor.execute("""
                SELECT limit_value, unit 
                FROM grim_tier_limits 
                WHERE tier = ? AND resource_type = ?
            """, (user_tier, resource_type))
            
            limit_result = cursor.fetchone()
            if not limit_result:
                return True, ""  # No limit defined
            
            limit_value, unit = limit_result
            
            # Get current usage for this billing period
            current_period = datetime.now().replace(day=1).date()
            cursor.execute("""
                SELECT COALESCE(SUM(usage_amount), 0)
                FROM grim_usage_tracking 
                WHERE user_id = ? AND resource_type = ? AND billing_period = ?
            """, (user_id, resource_type, current_period))
            
            current_usage = cursor.fetchone()[0]
            
            if current_usage + usage_amount > limit_value:
                overage_cost = self._calculate_overage_cost(resource_type, 
                                                          current_usage + usage_amount - limit_value)
                return False, f"""
⚠️  Usage limit exceeded for {resource_type}
📊 Current usage: {current_usage}/{limit_value} {unit}
💰 Overage cost: ${overage_cost:.2f}
🚀 Upgrade your tier to increase limits: https://grim.so/upgrade
                """.strip()
            
            # Update usage
            cursor.execute("""
                INSERT OR REPLACE INTO grim_usage_tracking 
                (user_id, resource_type, usage_amount, billing_period)
                VALUES (?, ?, COALESCE((
                    SELECT usage_amount FROM grim_usage_tracking 
                    WHERE user_id = ? AND resource_type = ? AND billing_period = ?
                ), 0) + ?, ?)
            """, (user_id, resource_type, user_id, resource_type, current_period, usage_amount, current_period))
            
            conn.commit()
            return True, ""
    
    def _calculate_overage_cost(self, resource_type: str, overage_amount: int) -> float:
        """Calculate overage costs"""
        overage_rates = {
            'storage': 0.05,  # $0.05/GB/month
            'alerts': 0.10,   # $0.10 per alert
            'api_calls': 0.001  # $0.001 per API call
        }
        return overage_rates.get(resource_type, 0) * overage_amount
```

### Phase 2: CLI Integration Wrapper

```bash
# /opt/reaper/throne/tier_check.sh
#!/bin/bash

# Tier checking wrapper for grim commands
check_tier_access() {
    local user_id="$1"
    local command="$2"
    
    # Call Python tier manager
    local check_result=$(python3 -c "
import sys
sys.path.append('/opt/reaper/py_grim')
from tier_manager import TierManager

tm = TierManager()
allowed, message = tm.check_command_access($user_id, '$command')
if allowed:
    print('ALLOWED')
else:
    print('DENIED')
    print(message)
")
    
    if [[ "$check_result" == "ALLOWED"* ]]; then
        return 0
    else
        echo "$check_result" | tail -n +2  # Skip "DENIED" line
        return 1
    fi
}

# Check usage limits
check_usage_limits() {
    local user_id="$1"
    local resource_type="$2"
    local usage_amount="${3:-1}"
    
    local check_result=$(python3 -c "
import sys
sys.path.append('/opt/reaper/py_grim')
from tier_manager import TierManager

tm = TierManager()
allowed, message = tm.check_usage_limits($user_id, '$resource_type', $usage_amount)
if allowed:
    print('ALLOWED')
else:
    print('DENIED')
    print(message)
")
    
    if [[ "$check_result" == "ALLOWED"* ]]; then
        return 0
    else
        echo "$check_result" | tail -n +2
        return 1
    fi
}

# Get user ID from API key
get_user_id_from_api_key() {
    local api_key="$1"
    
    python3 -c "
import sqlite3
import os

db_path = os.environ.get('GRIMS_MOTHER')
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute('SELECT id FROM grim_users WHERE api_key = ?', ('$api_key',))
result = cursor.fetchone()
conn.close()

if result:
    print(result[0])
else:
    print('0')
"
}
```

---

## 5. AUTHENTICATION SYSTEM PLAN

### API Key Authentication

```python
# /opt/reaper/py_grim/auth_manager.py
import secrets
import hashlib
import sqlite3
from datetime import datetime, timedelta

class AuthManager:
    def __init__(self):
        self.db_path = os.environ.get('GRIMS_MOTHER')
    
    def register_user(self, email: str, password: str, username: str = None) -> dict:
        """Register new user with FREE tier"""
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        api_key = secrets.token_urlsafe(32)
        
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            try:
                cursor.execute("""
                    INSERT INTO grim_users (email, username, password_hash, api_key, tier)
                    VALUES (?, ?, ?, ?, 'free')
                """, (email, username, password_hash, api_key))
                
                user_id = cursor.lastrowid
                
                # Create initial subscription record
                cursor.execute("""
                    INSERT INTO grim_subscriptions (user_id, tier, status)
                    VALUES (?, 'free', 'active')
                """, (user_id,))
                
                # Allocate free tier storage
                cursor.execute("""
                    INSERT INTO grim_storage_allocation (user_id, allocated_gb, provider)
                    VALUES (?, 1.0, 'local')
                """, (user_id,))
                
                conn.commit()
                
                return {
                    'success': True,
                    'user_id': user_id,
                    'api_key': api_key,
                    'tier': 'free'
                }
                
            except sqlite3.IntegrityError:
                return {'success': False, 'error': 'Email already exists'}
    
    def authenticate_api_key(self, api_key: str) -> dict:
        """Authenticate user by API key"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id, email, tier, is_active
                FROM grim_users 
                WHERE api_key = ?
            """, (api_key,))
            
            result = cursor.fetchone()
            if result and result[3]:  # is_active
                # Update last login
                cursor.execute("""
                    UPDATE grim_users 
                    SET last_login = ? 
                    WHERE id = ?
                """, (datetime.now(), result[0]))
                conn.commit()
                
                return {
                    'success': True,
                    'user_id': result[0],
                    'email': result[1],
                    'tier': result[2]
                }
            
            return {'success': False, 'error': 'Invalid API key'}
```

---

## 6. STRIPE INTEGRATION PLAN

### Subscription Management

```python
# /opt/reaper/py_grim/billing_manager.py
import stripe
import sqlite3
from datetime import datetime, timedelta

class BillingManager:
    def __init__(self):
        stripe.api_key = os.environ.get('STRIPE_SECRET_KEY')
        self.db_path = os.environ.get('GRIMS_MOTHER')
        
        self.tier_prices = {
            'pro': 'price_pro_monthly',      # Stripe price ID
            'master': 'price_master_monthly',
            'reaper': 'price_reaper_monthly'
        }
    
    def create_subscription(self, user_id: int, tier: str, payment_method_id: str) -> dict:
        """Create new subscription"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Get user info
                cursor.execute("SELECT email, stripe_customer_id FROM grim_users WHERE id = ?", (user_id,))
                user_info = cursor.fetchone()
                if not user_info:
                    return {'success': False, 'error': 'User not found'}
                
                email, stripe_customer_id = user_info
                
                # Create or update Stripe customer
                if not stripe_customer_id:
                    customer = stripe.Customer.create(
                        email=email,
                        payment_method=payment_method_id,
                        invoice_settings={'default_payment_method': payment_method_id}
                    )
                    stripe_customer_id = customer.id
                    
                    cursor.execute("""
                        UPDATE grim_users 
                        SET stripe_customer_id = ? 
                        WHERE id = ?
                    """, (stripe_customer_id, user_id))
                
                # Create subscription
                subscription = stripe.Subscription.create(
                    customer=stripe_customer_id,
                    items=[{'price': self.tier_prices[tier]}],
                    expand=['latest_invoice.payment_intent']
                )
                
                # Update database
                cursor.execute("""
                    UPDATE grim_users SET tier = ? WHERE id = ?
                """, (tier, user_id))
                
                cursor.execute("""
                    INSERT INTO grim_subscriptions 
                    (user_id, tier, status, stripe_subscription_id, current_period_start, current_period_end)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    user_id, tier, subscription.status, subscription.id,
                    datetime.fromtimestamp(subscription.current_period_start),
                    datetime.fromtimestamp(subscription.current_period_end)
                ))
                
                # Update storage allocation
                storage_limits = {'pro': 25, 'master': 100, 'reaper': 1000}
                cursor.execute("""
                    UPDATE grim_storage_allocation 
                    SET allocated_gb = ? 
                    WHERE user_id = ?
                """, (storage_limits[tier], user_id))
                
                conn.commit()
                
                return {
                    'success': True,
                    'subscription_id': subscription.id,
                    'client_secret': subscription.latest_invoice.payment_intent.client_secret
                }
                
        except stripe.error.StripeError as e:
            return {'success': False, 'error': str(e)}
    
    def handle_webhook(self, event_type: str, event_data: dict):
        """Handle Stripe webhooks"""
        if event_type == 'invoice.payment_succeeded':
            self._handle_payment_success(event_data)
        elif event_type == 'invoice.payment_failed':
            self._handle_payment_failure(event_data)
        elif event_type == 'customer.subscription.deleted':
            self._handle_subscription_cancelled(event_data)
```

---

## 7. UPGRADE FLOW DESIGN

### Web Interface Plan

```python
# /opt/reaper/py_grim/upgrade_flows.py
from flask import Flask, render_template, request, jsonify, session
from tier_manager import TierManager
from billing_manager import BillingManager

app = Flask(__name__)

@app.route('/pricing')
def pricing_page():
    """Show tier comparison page"""
    tiers = {
        'free': {'price': 0, 'storage': '1GB', 'alerts': 10, 'commands': 15},
        'pro': {'price': 20, 'storage': '25GB', 'alerts': 100, 'commands': 35},
        'master': {'price': 49, 'storage': '100GB', 'alerts': 500, 'commands': 60},
        'reaper': {'price': 99, 'storage': '1TB', 'alerts': 5000, 'commands': '200+'}
    }
    return render_template('pricing.html', tiers=tiers)

@app.route('/upgrade/<tier>')
def upgrade_flow(tier):
    """Start upgrade flow for specific tier"""
    if 'user_id' not in session:
        return redirect('/login')
    
    user_id = session['user_id']
    tm = TierManager()
    
    # Get current usage to show value
    usage_stats = tm.get_usage_stats(user_id)
    
    return render_template('upgrade.html', 
                         target_tier=tier, 
                         usage_stats=usage_stats)

@app.route('/api/create-subscription', methods=['POST'])
def create_subscription_api():
    """API endpoint to create subscription"""
    data = request.json
    user_id = session.get('user_id')
    
    if not user_id:
        return jsonify({'error': 'Not authenticated'}), 401
    
    bm = BillingManager()
    result = bm.create_subscription(
        user_id=user_id,
        tier=data['tier'],
        payment_method_id=data['payment_method_id']
    )
    
    return jsonify(result)

@app.route('/usage-dashboard')
def usage_dashboard():
    """Show user's current usage vs limits"""
    if 'user_id' not in session:
        return redirect('/login')
    
    user_id = session['user_id']
    tm = TierManager()
    
    usage_data = tm.get_detailed_usage(user_id)
    upgrade_recommendations = tm.get_upgrade_recommendations(user_id)
    
    return render_template('dashboard.html', 
                         usage=usage_data,
                         recommendations=upgrade_recommendations)
```

---

## 8. IMPLEMENTATION PHASES

### Phase 1 (Month 1): Database & Core Infrastructure
1. Create all database tables in GRIMS_MOTHER
2. Implement TierManager and AuthManager classes
3. Create CLI wrapper for tier checking
4. Basic user registration and API key system

### Phase 2 (Month 2): Command Integration
1. Populate command tier mappings
2. Integrate tier checking into grim_throne.sh
3. Implement usage tracking for storage and alerts
4. Create upgrade prompts and error messages

### Phase 3 (Month 3): Billing & Subscriptions
1. Stripe integration for payments
2. Subscription management system
3. Webhook handling for payment events
4. Overage billing calculation

### Phase 4 (Month 4): Web Interface & UX
1. Pricing and upgrade pages
2. Usage dashboard
3. Account management interface
4. Customer onboarding flow

---

## 9. TESTING STRATEGY

### Tier Access Testing
```bash
# Test script for tier access
#!/bin/bash

echo "Testing tier access control..."

# Test FREE tier user
export GRIM_USER_ID=1
./grim_throne.sh help        # Should work
./grim_throne.sh ai-analyze  # Should fail with upgrade prompt

# Test PRO tier user  
export GRIM_USER_ID=2
./grim_throne.sh ai-analyze  # Should fail with upgrade prompt
./grim_throne.sh auto-backup # Should work

# Test MASTER tier user
export GRIM_USER_ID=3
./grim_throne.sh ai-analyze  # Should work
./grim_throne.sh ai-train    # Should fail with upgrade prompt

# Test usage limits
./grim_throne.sh backup      # Should track storage usage
./grim_throne.sh backup      # May hit storage limit and show overage
```

---

## 10. MONITORING & ANALYTICS

### Key Metrics to Track
- Command usage by tier
- Upgrade conversion rates
- Usage limit hit rates
- Customer churn by tier
- Revenue per customer
- Support ticket volume by tier

### Database Queries for Analytics
```sql
-- Conversion rates by tier
SELECT 
    COUNT(*) as upgrades,
    AVG(JULIANDAY(upgraded_at) - JULIANDAY(created_at)) as avg_days_to_upgrade
FROM grim_users 
WHERE tier != 'free';

-- Most used commands by tier
SELECT 
    u.tier,
    cu.command,
    COUNT(*) as usage_count
FROM grim_command_usage cu
JOIN grim_users u ON cu.user_id = u.id
WHERE cu.allowed = 1
GROUP BY u.tier, cu.command
ORDER BY usage_count DESC;

-- Usage limit hits (conversion opportunities)
SELECT 
    u.tier,
    ut.resource_type,
    COUNT(*) as limit_hits
FROM grim_usage_tracking ut
JOIN grim_users u ON ut.user_id = u.id
JOIN grim_tier_limits tl ON u.tier = tl.tier AND ut.resource_type = tl.resource_type
WHERE ut.usage_amount >= tl.limit_value
GROUP BY u.tier, ut.resource_type;
```

---

## SUMMARY - TWO DISTINCT MONETIZATION SYSTEMS

### 🏢 GRIM'S INTERNAL TIER SYSTEM
- **Purpose**: Monetize Grim Reaper platform access
- **Database**: PostgreSQL GRIMS_MOTHER with `grim_*` tables
- **Implementation**: Modify grim_throne.sh to check user tiers before command execution
- **Revenue**: $20-$99/month subscriptions for different command access levels
- **Users**: DevOps teams subscribing to use Grim Reaper

### ⚔️ SCYTHE LICENSE PLATFORM  
- **Purpose**: White-label licensing system users can deploy for their own software
- **Database**: Local SQLite `scythe.db` per deployment
- **Implementation**: Complete licensing-as-a-service platform with APIs, SDKs, payment processing
- **Revenue**: Platform license fees + 5% transaction fees on license sales
- **Users**: Software vendors who want to license their own applications

### 🔄 INTEGRATION POINTS
Both systems can work together:
- Grim users at MASTER/REAPER tiers get access to deploy Scythe License Systems
- Scythe becomes a premium feature that drives tier upgrades
- Cross-selling opportunities between the two platforms

This dual approach maximizes revenue streams:
1. **Direct Revenue**: From Grim Reaper subscriptions
2. **Platform Revenue**: From vendors using Scythe licensing
3. **Transaction Revenue**: From license sales processed through Scythe

This comprehensive plan provides roadmaps for both systems while leveraging shared infrastructure and user bases for maximum profitability.