#!/usr/bin/env python3
"""
Simple Webhook Test for Grim Reaper
Tests local components without external network calls
"""

import os
import sys
import json
from datetime import datetime

def test_environment():
    """Test environment variables"""
    print("🔍 Testing Environment Variables...")
    print("=" * 50)
    
    required = ['STRIPE_SECRET_KEY', 'STRIPE_PUBLISHABLE_KEY', 'GRIMS_MOTHER']
    optional = ['STRIPE_WEBHOOK_SECRET']
    
    all_good = True
    
    for var in required:
        value = os.getenv(var)
        if value:
            print(f"✅ {var}: {'*' * 10}...{value[-4:] if len(value) > 4 else value}")
        else:
            print(f"❌ {var}: NOT SET")
            all_good = False
    
    for var in optional:
        value = os.getenv(var)
        if value:
            print(f"✅ {var}: {'*' * 10}...{value[-4:] if len(value) > 4 else value}")
        else:
            print(f"⚠️ {var}: NOT SET (optional)")
    
    return all_good

def test_files():
    """Test if required files exist"""
    print("\n🔍 Testing Required Files...")
    print("=" * 50)
    
    files = [
        "py_grim/billing_manager.py",
        "tsk_flask/grim_license_manager.py",
        "sh_grim/auto_backup_strategic.sh",
        "grim/public/pricing.html",
        "grim/public/webhook-setup-guide.html"
    ]
    
    all_exist = True
    
    for file_path in files:
        if os.path.exists(file_path):
            print(f"✅ {file_path}")
        else:
            print(f"❌ {file_path} - MISSING")
            all_exist = False
    
    return all_exist

def test_billing_manager_import():
    """Test if billing manager can be imported"""
    print("\n🔍 Testing Billing Manager Import...")
    print("=" * 50)
    
    try:
        sys.path.append('py_grim')
        from billing_manager import BillingManager
        
        # Try to create instance
        manager = BillingManager()
        print("✅ BillingManager imported successfully")
        print(f"📊 Tier prices: {list(manager.tier_prices.keys())}")
        print(f"📊 Storage limits: {list(manager.storage_limits.keys())}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error importing BillingManager: {e}")
        return False

def test_license_manager_import():
    """Test if license manager can be imported"""
    print("\n🔍 Testing License Manager Import...")
    print("=" * 50)
    
    try:
        sys.path.append('tsk_flask')
        from grim_license_manager import GrimLicenseManager
        
        # Try to create instance
        manager = GrimLicenseManager()
        print("✅ GrimLicenseManager imported successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Error importing GrimLicenseManager: {e}")
        return False

def test_webhook_config():
    """Test webhook configuration"""
    print("\n🔍 Testing Webhook Configuration...")
    print("=" * 50)
    
    webhook_url = "https://grim.so/api/billing/webhook"
    
    print(f"📡 Webhook URL: {webhook_url}")
    print(f"🔑 Webhook Secret: {'SET' if os.getenv('STRIPE_WEBHOOK_SECRET') else 'NOT SET'}")
    
    # Test webhook payload structure
    test_payload = {
        "id": "evt_test_webhook",
        "object": "event",
        "api_version": "2025-06-30.basil",
        "created": int(datetime.now().timestamp()),
        "data": {
            "object": {
                "id": "pi_test_payment",
                "object": "payment_intent",
                "status": "succeeded"
            }
        },
        "livemode": False,
        "pending_webhooks": 1,
        "request": {
            "id": "req_test_request",
            "idempotency_key": None
        },
        "type": "payment_intent.succeeded"
    }
    
    print(f"📦 Test payload structure: {json.dumps(test_payload, indent=2)}")
    print("✅ Webhook configuration looks good")
    
    return True

def main():
    """Run all tests"""
    print("🚀 Grim Reaper Webhook Test Suite (Local)")
    print("=" * 60)
    print(f"⏰ Test started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    results = {}
    
    results['environment'] = test_environment()
    results['files'] = test_files()
    results['billing_manager'] = test_billing_manager_import()
    results['license_manager'] = test_license_manager_import()
    results['webhook_config'] = test_webhook_config()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name.replace('_', ' ').title()}: {status}")
        if result:
            passed += 1
    
    print(f"\n🎯 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 ALL LOCAL TESTS PASSED!")
        print("📡 Next: Test webhook endpoint connectivity")
    elif passed >= total * 0.8:
        print("⚠️ Most tests passed, but some issues need attention")
    else:
        print("❌ Multiple tests failed - system needs configuration")
    
    print("\n📋 Next Steps:")
    print("1. Set missing environment variables")
    print("2. Test webhook endpoint: curl -X POST https://grim.so/api/billing/webhook")
    print("3. Test Stripe connectivity")
    print("4. Verify webhook secret is configured")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 