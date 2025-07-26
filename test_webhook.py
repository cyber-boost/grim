#!/usr/bin/env python3
"""
Webhook Test Script for Grim Reaper
Tests webhook endpoint and billing manager functionality
"""

import os
import sys
import json
import requests
import time
from datetime import datetime
import subprocess

def test_webhook_endpoint():
    """Test the webhook endpoint directly"""
    print("🔍 Testing Webhook Endpoint...")
    print("=" * 50)
    
    webhook_url = "https://grim.so/api/billing/webhook"
    
    # Test payload
    test_payload = {
        "test": "webhook_health_check",
        "timestamp": datetime.utcnow().isoformat(),
        "source": "grim_webhook_test"
    }
    
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "GrimWebhookTest/1.0"
    }
    
    try:
        print(f"📡 Testing endpoint: {webhook_url}")
        print(f"📦 Payload: {json.dumps(test_payload, indent=2)}")
        
        response = requests.post(
            webhook_url,
            json=test_payload,
            headers=headers,
            timeout=30
        )
        
        print(f"✅ Status Code: {response.status_code}")
        print(f"📄 Response Headers: {dict(response.headers)}")
        print(f"📝 Response Body: {response.text[:500]}...")
        
        if response.status_code == 200:
            print("🎉 Webhook endpoint is responding!")
            return True
        else:
            print(f"⚠️ Webhook endpoint returned status {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection Error: Cannot reach webhook endpoint")
        return False
    except requests.exceptions.Timeout:
        print("⏰ Timeout: Webhook endpoint took too long to respond")
        return False
    except Exception as e:
        print(f"❌ Error testing webhook: {e}")
        return False

def test_billing_manager():
    """Test the billing manager functionality"""
    print("\n🔍 Testing Billing Manager...")
    print("=" * 50)
    
    try:
        # Test if billing manager exists
        if not os.path.exists("py_grim/billing_manager.py"):
            print("❌ Billing manager not found: py_grim/billing_manager.py")
            return False
        
        # Test billing manager plans
        result = subprocess.run(
            ["python3", "py_grim/billing_manager.py", "plans"],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        print(f"📊 Billing Manager Plans Test:")
        print(f"Exit Code: {result.returncode}")
        print(f"Output: {result.stdout}")
        
        if result.stderr:
            print(f"Errors: {result.stderr}")
        
        if result.returncode == 0:
            print("✅ Billing manager is working!")
            return True
        else:
            print("⚠️ Billing manager has issues")
            return False
            
    except subprocess.TimeoutExpired:
        print("⏰ Timeout: Billing manager test took too long")
        return False
    except Exception as e:
        print(f"❌ Error testing billing manager: {e}")
        return False

def test_environment_variables():
    """Test environment variable configuration"""
    print("\n🔍 Testing Environment Variables...")
    print("=" * 50)
    
    required_vars = [
        'STRIPE_SECRET_KEY',
        'STRIPE_PUBLISHABLE_KEY',
        'GRIMS_MOTHER'
    ]
    
    optional_vars = [
        'STRIPE_WEBHOOK_SECRET'
    ]
    
    all_good = True
    
    print("📋 Required Variables:")
    for var in required_vars:
        value = os.getenv(var)
        if value:
            print(f"✅ {var}: {'*' * 10}...{value[-4:] if len(value) > 4 else value}")
        else:
            print(f"❌ {var}: NOT SET")
            all_good = False
    
    print("\n📋 Optional Variables:")
    for var in optional_vars:
        value = os.getenv(var)
        if value:
            print(f"✅ {var}: {'*' * 10}...{value[-4:] if len(value) > 4 else value}")
        else:
            print(f"⚠️ {var}: NOT SET (optional for development)")
    
    return all_good

def test_license_system():
    """Test the license system"""
    print("\n🔍 Testing License System...")
    print("=" * 50)
    
    try:
        # Test license manager
        if os.path.exists("tsk_flask/grim_license_manager.py"):
            result = subprocess.run(
                ["python3", "tsk_flask/grim_license_manager.py", "--help"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            print(f"📊 License Manager Test:")
            print(f"Exit Code: {result.returncode}")
            print(f"Output: {result.stdout[:200]}...")
            
            if result.returncode == 0:
                print("✅ License manager is working!")
                return True
            else:
                print("⚠️ License manager has issues")
                return False
        else:
            print("❌ License manager not found: tsk_flask/grim_license_manager.py")
            return False
            
    except subprocess.TimeoutExpired:
        print("⏰ Timeout: License manager test took too long")
        return False
    except Exception as e:
        print(f"❌ Error testing license manager: {e}")
        return False

def test_auto_backup_system():
    """Test the auto-backup system"""
    print("\n🔍 Testing Auto-Backup System...")
    print("=" * 50)
    
    try:
        # Test auto-backup script
        if os.path.exists("sh_grim/auto_backup_strategic.sh"):
            result = subprocess.run(
                ["bash", "sh_grim/auto_backup_strategic.sh", "help"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            print(f"📊 Auto-Backup Test:")
            print(f"Exit Code: {result.returncode}")
            print(f"Output: {result.stdout[:200]}...")
            
            if result.returncode == 0:
                print("✅ Auto-backup system is working!")
                return True
            else:
                print("⚠️ Auto-backup system has issues")
                return False
        else:
            print("❌ Auto-backup script not found: sh_grim/auto_backup_strategic.sh")
            return False
            
    except subprocess.TimeoutExpired:
        print("⏰ Timeout: Auto-backup test took too long")
        return False
    except Exception as e:
        print(f"❌ Error testing auto-backup: {e}")
        return False

def test_stripe_connectivity():
    """Test Stripe API connectivity"""
    print("\n🔍 Testing Stripe Connectivity...")
    print("=" * 50)
    
    try:
        import stripe
        
        # Check if Stripe key is set
        stripe_key = os.getenv('STRIPE_SECRET_KEY')
        if not stripe_key:
            print("❌ STRIPE_SECRET_KEY not set")
            return False
        
        # Test Stripe API call
        stripe.api_key = stripe_key
        
        # Try to get account info
        account = stripe.Account.retrieve()
        print(f"✅ Stripe connected! Account: {account.id}")
        print(f"📊 Account Type: {account.type}")
        print(f"🌍 Country: {account.country}")
        
        return True
        
    except stripe.error.AuthenticationError:
        print("❌ Stripe authentication failed - check your API key")
        return False
    except stripe.error.APIConnectionError:
        print("❌ Stripe API connection error - check network connectivity")
        return False
    except Exception as e:
        print(f"❌ Stripe test error: {e}")
        return False

def main():
    """Run all webhook tests"""
    print("🚀 Grim Reaper Webhook Test Suite")
    print("=" * 60)
    print(f"⏰ Test started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    results = {}
    
    # Run all tests
    results['environment'] = test_environment_variables()
    results['stripe'] = test_stripe_connectivity()
    results['billing_manager'] = test_billing_manager()
    results['license_system'] = test_license_system()
    results['auto_backup'] = test_auto_backup_system()
    results['webhook_endpoint'] = test_webhook_endpoint()
    
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
        print("🎉 ALL TESTS PASSED! System is ready for production!")
    elif passed >= total * 0.8:
        print("⚠️ Most tests passed, but some issues need attention")
    else:
        print("❌ Multiple tests failed - system needs configuration")
    
    print("\n📋 Recommendations:")
    if not results['environment']:
        print("- Set required environment variables (STRIPE_SECRET_KEY, GRIMS_MOTHER)")
    if not results['stripe']:
        print("- Check Stripe API key configuration")
    if not results['webhook_endpoint']:
        print("- Verify webhook endpoint is accessible and responding")
    if not results['billing_manager']:
        print("- Check billing manager installation and dependencies")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1) 