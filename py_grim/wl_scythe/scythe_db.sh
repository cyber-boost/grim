#!/bin/bash
# Scythe Database Setup Script
# Creates SQLite database for white-label licensing system
# CLI developers integrate this into their own projects

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$SCRIPT_DIR/database"
DB_FILE="$DB_DIR/scythe.db"
SQL_DIR="$SCRIPT_DIR/sql"

echo -e "${CYAN}🔧 Scythe Licensing Database Setup${NC}"
echo "Setting up SQLite database for white-label licensing..."

# Create directories
mkdir -p "$DB_DIR"
mkdir -p "$SQL_DIR"

# Create licensing-focused schema
cat > "$SQL_DIR/01_licensing_schema.sql" << 'EOF'
-- Scythe Licensing Database Schema
-- White-label version for CLI developers

-- Vendors (CLI developers who use scythe)
CREATE TABLE IF NOT EXISTS vendors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    api_key_hash TEXT,
    webhook_url TEXT,
    webhook_secret TEXT,
    commission_rate DECIMAL(5,2) DEFAULT 15.0,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products (CLI tools/apps that vendors sell)
CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    version TEXT DEFAULT '1.0.0',
    price DECIMAL(10,2),
    currency TEXT DEFAULT 'USD',
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(id)
);

-- Licenses
CREATE TABLE IF NOT EXISTS licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_key TEXT UNIQUE NOT NULL,
    product_id INTEGER NOT NULL,
    customer_email TEXT NOT NULL,
    customer_name TEXT,
    status TEXT DEFAULT 'active',
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- License validations (audit trail)
CREATE TABLE IF NOT EXISTS license_validations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_id INTEGER NOT NULL,
    validation_result TEXT NOT NULL,
    client_ip TEXT,
    user_agent TEXT,
    validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (license_id) REFERENCES licenses(id)
);

-- Stripe customers (for payment integration)
CREATE TABLE IF NOT EXISTS stripe_customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_email TEXT UNIQUE NOT NULL,
    stripe_customer_id TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions (if vendor offers subscription-based licensing)
CREATE TABLE IF NOT EXISTS subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_id INTEGER NOT NULL,
    stripe_subscription_id TEXT UNIQUE,
    status TEXT DEFAULT 'active',
    current_period_start TIMESTAMP,
    current_period_end TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (license_id) REFERENCES licenses(id)
);

-- Vendor payouts
CREATE TABLE IF NOT EXISTS vendor_payouts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    stripe_payout_id TEXT UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(id)
);

-- API keys for vendor authentication
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    key_hash TEXT NOT NULL,
    permissions TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(id)
);

-- Webhook events (for vendor notifications)
CREATE TABLE IF NOT EXISTS webhook_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    event_data TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    attempts INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(id)
);
EOF

# Create indexes
cat > "$SQL_DIR/02_indexes.sql" << 'EOF'
-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vendors_email ON vendors(email);
CREATE INDEX IF NOT EXISTS idx_products_vendor ON products(vendor_id);
CREATE INDEX IF NOT EXISTS idx_licenses_key ON licenses(license_key);
CREATE INDEX IF NOT EXISTS idx_licenses_product ON licenses(product_id);
CREATE INDEX IF NOT EXISTS idx_licenses_customer ON licenses(customer_email);
CREATE INDEX IF NOT EXISTS idx_license_validations_license ON license_validations(license_id);
CREATE INDEX IF NOT EXISTS idx_stripe_customers_email ON stripe_customers(customer_email);
CREATE INDEX IF NOT EXISTS idx_subscriptions_license ON subscriptions(license_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payouts_vendor ON vendor_payouts(vendor_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_vendor ON api_keys(vendor_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_vendor ON webhook_events(vendor_id);
EOF

# Create default data
cat > "$SQL_DIR/03_default_data.sql" << 'EOF'
-- Default webhook endpoints (vendors can customize)
INSERT OR IGNORE INTO webhook_events (vendor_id, event_type, event_data, status) VALUES
(1, 'license.created', '{"message": "License created successfully"}', 'sent'),
(1, 'license.validated', '{"message": "License validated"}', 'sent'),
(1, 'license.expired', '{"message": "License expired"}', 'sent');
EOF

# Create database
echo -e "${BLUE}Creating SQLite database...${NC}"
sqlite3 "$DB_FILE" < "$SQL_DIR/01_licensing_schema.sql"
sqlite3 "$DB_FILE" < "$SQL_DIR/02_indexes.sql"
sqlite3 "$DB_FILE" < "$SQL_DIR/03_default_data.sql"

# Set permissions
chmod 644 "$DB_FILE"

echo -e "${GREEN}✅ Licensing database created successfully!${NC}"
echo -e "${CYAN}Database location: $DB_FILE${NC}"
echo -e "${CYAN}SQL files location: $SQL_DIR${NC}"

# Show database info
echo ""
echo -e "${YELLOW}Database Information:${NC}"
sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table';" | while read table; do
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;")
    echo -e "  ${BLUE}$table${NC}: $count records"
done

echo ""
echo -e "${GREEN}🎉 Scythe licensing database setup complete!${NC}"
echo -e "${CYAN}This is a pure licensing system for CLI developers.${NC}"
echo -e "${YELLOW}Vendors can:${NC}"
echo "  • Register their products"
echo "  • Generate licenses for customers"
echo "  • Validate licenses"
echo "  • Receive payments via Stripe"
echo "  • Get webhook notifications" 