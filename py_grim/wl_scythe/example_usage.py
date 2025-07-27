#!/usr/bin/env python3
"""
Example showing how SCYTHE_LICENSE_KEY environment variable is used
"""

import os
import sys
from license_manager import ScytheLicenseManager

def main():
    """Example of license validation using environment variable"""
    
    # 1. Get license key from environment variable
    license_key = os.getenv('SCYTHE_LICENSE_KEY')
    
    if not license_key:
        print("❌ SCYTHE_LICENSE_KEY environment variable not set")
        print("   Set it with: export SCYTHE_LICENSE_KEY='your-license-key'")
        sys.exit(1)
    
    if license_key == "your-license-key":
        print("❌ Please replace 'your-license-key' with an actual license key")
        print("   export SCYTHE_LICENSE_KEY='SCYTHE-ABC123DEF456-7890'")
        sys.exit(1)
    
    print(f"🔑 Using license key: {license_key}")
    
    # 2. Initialize license manager
    manager = ScytheLicenseManager()
    
    # 3. Validate the license
    print("🔍 Validating license...")
    result = manager.validate_license(license_key)
    
    # 4. Check validation result
    if result["valid"]:
        print("✅ License is valid!")
        print(f"   Product: {result['product_name']}")
        print(f"   Customer: {result['customer_email']}")
        print(f"   Expires: {result['expires_at']}")
        
        # 5. Now you can run your CLI tool
        print("\n🚀 License validated - running your CLI tool...")
        run_cli_tool()
        
    else:
        print(f"❌ License validation failed: {result['error']}")
        print("💡 Please check your license key or contact support")
        sys.exit(1)

def run_cli_tool():
    """Example CLI tool functionality"""
    print("   📊 Processing data...")
    print("   🔧 Optimizing performance...")
    print("   ✅ Task completed successfully!")
    print("\n🎉 Your CLI tool is working with valid license!")

if __name__ == "__main__":
    main() 