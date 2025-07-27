# Scythe White-Label Licensing System

A simple, lightweight licensing system for CLI developers to integrate into their own projects.

## Overview

Scythe White-Label is a pure licensing solution that allows CLI developers to:
- Register their products
- Generate licenses for customers
- Validate licenses
- Handle payments via Stripe
- Receive webhook notifications

**This is NOT a full system like Grim - it's just licensing for your CLI tools.**

## Quick Start

### 1. Setup Database

```bash
# Run the database setup script
./scythe_db.sh
```

This creates a SQLite database with all required tables.

### 2. Register as a Vendor

```bash
# Register your CLI tool/company
python3 license_manager.py register --name "MyAwesomeCLI" --email "dev@myawesomecli.com"
```

You'll receive an API key for authentication.

### 3. Create a Product

```bash
# Create a product for your CLI tool
python3 license_manager.py create-product --vendor-id 1 --name "MyAwesomeCLI Pro"
```

### 4. Generate Licenses

```bash
# Generate a license for a customer
python3 license_manager.py generate --product-id 1 --email "customer@example.com"
```

### 5. Validate Licenses

```bash
# Validate a license key
python3 license_manager.py validate --license-key "SCYTHE-ABC123DEF456-7890"
```

## Integration in Your CLI Tool

### Python Integration

```python
from license_manager import ScytheLicenseManager

# Initialize the license manager
manager = ScytheLicenseManager()

# Check if license is valid
result = manager.validate_license("SCYTHE-ABC123DEF456-7890")
if result["valid"]:
    print("License is valid!")
    # Continue with your CLI functionality
else:
    print(f"License error: {result['error']}")
    # Show upgrade message or exit
```

### Bash Integration

```bash
#!/bin/bash

# Check license before running CLI command
LICENSE_KEY="SCYTHE-ABC123DEF456-7890"

# Validate license
result=$(python3 license_manager.py validate --license-key "$LICENSE_KEY")

# Parse JSON result (requires jq)
valid=$(echo "$result" | jq -r '.valid')

if [ "$valid" = "true" ]; then
    echo "License valid - running command..."
    # Your CLI logic here
else
    echo "License invalid - please upgrade"
    exit 1
fi
```

## Database Schema

The system uses a simple SQLite database with these main tables:

- **vendors** - CLI developers who use scythe
- **products** - CLI tools/apps that vendors sell
- **licenses** - License keys for customers
- **license_validations** - Audit trail of license checks
- **stripe_customers** - Payment integration
- **webhook_events** - Vendor notifications

## API Reference

### ScytheLicenseManager Class

#### `register_vendor(name, email, webhook_url=None)`
Register a new vendor (CLI developer).

#### `create_product(vendor_id, name, description=None, price=None, version="1.0.0")`
Create a new product for a vendor.

#### `generate_license(product_id, customer_email, customer_name=None, expires_in_days=365)`
Generate a license for a customer.

#### `validate_license(license_key, client_ip=None, user_agent=None)`
Validate a license key.

#### `list_licenses(vendor_id=None, product_id=None)`
List licenses with optional filtering.

#### `revoke_license(license_key)`
Revoke a license.

## CLI Commands

```bash
# Register as vendor
python3 license_manager.py register --name "YourCLI" --email "dev@yourcli.com"

# Create product
python3 license_manager.py create-product --vendor-id 1 --name "YourCLI Pro"

# Generate license
python3 license_manager.py generate --product-id 1 --email "customer@example.com"

# Validate license
python3 license_manager.py validate --license-key "SCYTHE-ABC123DEF456-7890"

# List licenses
python3 license_manager.py list --vendor-id 1

# Revoke license
python3 license_manager.py revoke --license-key "SCYTHE-ABC123DEF456-7890"
```

## Payment Integration

The system is designed to work with Stripe for payments. You can:

1. Use Stripe Checkout for one-time purchases
2. Use Stripe Subscriptions for recurring billing
3. Handle webhooks for payment events

## Webhooks

Configure webhook URLs to receive notifications for:
- License created
- License validated
- License expired
- Payment received
- Payment failed

## Security

- API keys are hashed using SHA-256
- License keys are cryptographically secure
- All license validations are logged
- Database is local to your system

## Example Use Cases

### Simple CLI Tool
```python
import sys
from license_manager import ScytheLicenseManager

def main():
    # Check license first
    manager = ScytheLicenseManager()
    result = manager.validate_license("YOUR-LICENSE-KEY")
    
    if not result["valid"]:
        print("❌ License invalid. Please purchase a license.")
        print("Visit: https://yourcli.com/purchase")
        sys.exit(1)
    
    # Your CLI logic here
    print("✅ License valid - running your tool...")

if __name__ == "__main__":
    main()
```

### Advanced CLI with Tiers
```python
def check_feature_access(license_key, feature):
    manager = ScytheLicenseManager()
    result = manager.validate_license(license_key)
    
    if not result["valid"]:
        return False
    
    # Check if feature is available for this license
    # You can extend the database to include feature flags
    return True
```

## Migration from Other Systems

If you're currently using a different licensing system, you can:

1. Export your existing licenses
2. Import them using the `generate_license` method
3. Update your CLI tool to use scythe validation

## Support

This is a white-label system - you're responsible for:
- Customer support
- License delivery
- Payment processing
- Webhook handling

The scythe system just handles the licensing logic.

## License

This white-label system is provided as-is for CLI developers to integrate into their own projects.