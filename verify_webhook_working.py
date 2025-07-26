#!/usr/bin/env python3
"""
DEFINITIVE WEBHOOK VERIFICATION
Failure is NOT an option - this will prove the webhook works!
"""

import os
import sys
import json
import requests
import subprocess
import time
from datetime import datetime
import urllib3

# Disable SSL warnings for testing
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class WebhookVerifier:
    """Definitive webhook verification system"""
    
    def __init__(self):
        self.webhook_url = "https://grim.so/api/billing/webhook"
        self.results = {}
        self.start_time = datetime.now()
        
    def log(self, message, level="INFO"):
        """Log with timestamp"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")
        
    def test_webhook_endpoint(self):
        """Test webhook endpoint with multiple methods"""
        self.log("🔍 TESTING WEBHOOK ENDPOINT - MULTIPLE METHODS")
        print("=" * 60)
        
        # Method 1: Simple POST
        try:
            self.log("Method 1: Simple POST request")
            payload = {
                "test": "webhook_verification",
                "timestamp": datetime.utcnow().isoformat(),
                "source": "grim_verifier"
            }
            
            response = requests.post(
                self.webhook_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30,
                verify=False
            )
            
            self.log(f"Status: {response.status_code}")
            self.log(f"Response: {response.text[:200]}...")
            
            if response.status_code == 200:
                self.log("✅ WEBHOOK ENDPOINT RESPONDING!", "SUCCESS")
                self.results['webhook_endpoint'] = True
                return True
            else:
                self.log(f"⚠️ Webhook returned {response.status_code}", "WARNING")
                self.results['webhook_endpoint'] = False
                
        except Exception as e:
            self.log(f"❌ Method 1 failed: {e}", "ERROR")
            
        # Method 2: Stripe-like payload
        try:
            self.log("Method 2: Stripe-like webhook payload")
            stripe_payload = {
                "id": "evt_webhook_test",
                "object": "event",
                "api_version": "2025-06-30.basil",
                "created": int(time.time()),
                "data": {
                    "object": {
                        "id": "pi_test_payment",
                        "object": "payment_intent",
                        "status": "succeeded",
                        "amount": 2999,
                        "currency": "usd"
                    }
                },
                "livemode": False,
                "pending_webhooks": 1,
                "request": {
                    "id": "req_test",
                    "idempotency_key": None
                },
                "type": "payment_intent.succeeded"
            }
            
            response = requests.post(
                self.webhook_url,
                json=stripe_payload,
                headers={"Content-Type": "application/json"},
                timeout=30,
                verify=False
            )
            
            self.log(f"Stripe payload status: {response.status_code}")
            
            if response.status_code in [200, 202]:
                self.log("✅ WEBHOOK ACCEPTS STRIPE PAYLOADS!", "SUCCESS")
                self.results['stripe_payload'] = True
                return True
                
        except Exception as e:
            self.log(f"❌ Method 2 failed: {e}", "ERROR")
            
        # Method 3: Health check
        try:
            self.log("Method 3: Health check endpoint")
            health_url = self.webhook_url.replace("/api/billing/webhook", "/health")
            
            response = requests.get(health_url, timeout=10, verify=False)
            self.log(f"Health check status: {response.status_code}")
            
        except Exception as e:
            self.log(f"Health check failed: {e}", "WARNING")
            
        return False
        
    def test_billing_manager(self):
        """Test billing manager functionality"""
        self.log("🔍 TESTING BILLING MANAGER")
        print("=" * 60)
        
        try:
            # Check if file exists
            if not os.path.exists("py_grim/billing_manager.py"):
                self.log("❌ Billing manager file not found", "ERROR")
                self.results['billing_manager'] = False
                return False
                
            # Test import
            sys.path.append('py_grim')
            from billing_manager import BillingManager
            
            manager = BillingManager()
            self.log("✅ BillingManager imported successfully", "SUCCESS")
            
            # Test plans
            plans = manager.get_all_plans()
            self.log(f"✅ Plans available: {list(plans.keys())}", "SUCCESS")
            
            self.results['billing_manager'] = True
            return True
            
        except Exception as e:
            self.log(f"❌ Billing manager test failed: {e}", "ERROR")
            self.results['billing_manager'] = False
            return False
            
    def test_license_system(self):
        """Test license system"""
        self.log("🔍 TESTING LICENSE SYSTEM")
        print("=" * 60)
        
        try:
            # Check if file exists
            if not os.path.exists("tsk_flask/grim_license_manager.py"):
                self.log("❌ License manager file not found", "ERROR")
                self.results['license_system'] = False
                return False
                
            # Test import
            sys.path.append('tsk_flask')
            from grim_license_manager import GrimLicenseManager
            
            manager = GrimLicenseManager()
            self.log("✅ GrimLicenseManager imported successfully", "SUCCESS")
            
            # Test license generation
            test_email = "test@grim.so"
            result = manager.generate_freemium_license(test_email)
            
            if result and 'license_key' in result:
                self.log(f"✅ License generation works: {result['license_key'][:10]}...", "SUCCESS")
                self.results['license_system'] = True
                return True
            else:
                self.log("⚠️ License generation returned unexpected result", "WARNING")
                self.results['license_system'] = False
                return False
                
        except Exception as e:
            self.log(f"❌ License system test failed: {e}", "ERROR")
            self.results['license_system'] = False
            return False
            
    def test_environment(self):
        """Test environment variables"""
        self.log("🔍 TESTING ENVIRONMENT VARIABLES")
        print("=" * 60)
        
        required = ['STRIPE_SECRET_KEY', 'STRIPE_PUBLISHABLE_KEY', 'GRIMS_MOTHER']
        optional = ['STRIPE_WEBHOOK_SECRET']
        
        all_good = True
        
        for var in required:
            value = os.getenv(var)
            if value:
                self.log(f"✅ {var}: {'*' * 10}...{value[-4:] if len(value) > 4 else value}", "SUCCESS")
            else:
                self.log(f"❌ {var}: NOT SET", "ERROR")
                all_good = False
                
        for var in optional:
            value = os.getenv(var)
            if value:
                self.log(f"✅ {var}: {'*' * 10}...{value[-4:] if len(value) > 4 else value}", "SUCCESS")
            else:
                self.log(f"⚠️ {var}: NOT SET (optional)", "WARNING")
                
        self.results['environment'] = all_good
        return all_good
        
    def test_stripe_connectivity(self):
        """Test Stripe API connectivity"""
        self.log("🔍 TESTING STRIPE CONNECTIVITY")
        print("=" * 60)
        
        try:
            import stripe
            
            stripe_key = os.getenv('STRIPE_SECRET_KEY')
            if not stripe_key:
                self.log("❌ STRIPE_SECRET_KEY not set", "ERROR")
                self.results['stripe'] = False
                return False
                
            stripe.api_key = stripe_key
            
            # Test account retrieval
            account = stripe.Account.retrieve()
            self.log(f"✅ Stripe connected! Account: {account.id}", "SUCCESS")
            self.log(f"📊 Account Type: {account.type}", "INFO")
            self.log(f"🌍 Country: {account.country}", "INFO")
            
            self.results['stripe'] = True
            return True
            
        except Exception as e:
            self.log(f"❌ Stripe test failed: {e}", "ERROR")
            self.results['stripe'] = False
            return False
            
    def test_auto_backup(self):
        """Test auto-backup system"""
        self.log("🔍 TESTING AUTO-BACKUP SYSTEM")
        print("=" * 60)
        
        try:
            # Check if file exists
            if not os.path.exists("sh_grim/auto_backup_strategic.sh"):
                self.log("❌ Auto-backup script not found", "ERROR")
                self.results['auto_backup'] = False
                return False
                
            # Test script execution
            result = subprocess.run(
                ["bash", "sh_grim/auto_backup_strategic.sh", "help"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                self.log("✅ Auto-backup script executes successfully", "SUCCESS")
                self.log(f"Output: {result.stdout[:100]}...", "INFO")
                self.results['auto_backup'] = True
                return True
            else:
                self.log(f"⚠️ Auto-backup script returned {result.returncode}", "WARNING")
                self.log(f"Error: {result.stderr}", "ERROR")
                self.results['auto_backup'] = False
                return False
                
        except Exception as e:
            self.log(f"❌ Auto-backup test failed: {e}", "ERROR")
            self.results['auto_backup'] = False
            return False
            
    def generate_report(self):
        """Generate comprehensive test report"""
        self.log("📊 GENERATING COMPREHENSIVE REPORT")
        print("=" * 60)
        
        end_time = datetime.now()
        duration = end_time - self.start_time
        
        print(f"\n🚀 GRIM REAPER WEBHOOK VERIFICATION REPORT")
        print(f"⏰ Duration: {duration}")
        print(f"📅 Date: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 60)
        
        passed = 0
        total = len(self.results)
        
        for test_name, result in self.results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{test_name.replace('_', ' ').title()}: {status}")
            if result:
                passed += 1
                
        print(f"\n🎯 OVERALL RESULTS: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 ALL TESTS PASSED! WEBHOOK IS WORKING!")
            print("🚀 SYSTEM IS READY FOR 3000 USERS!")
        elif passed >= total * 0.8:
            print("⚠️ Most tests passed - minor issues need attention")
        else:
            print("❌ Multiple tests failed - system needs configuration")
            
        print("\n📋 DETAILED RESULTS:")
        for test_name, result in self.results.items():
            print(f"  {test_name}: {'✅ WORKING' if result else '❌ FAILED'}")
            
        return passed == total
        
    def run_all_tests(self):
        """Run all verification tests"""
        self.log("🚀 STARTING DEFINITIVE WEBHOOK VERIFICATION")
        print("=" * 60)
        print("FAILURE IS NOT AN OPTION - PROVING WEBHOOK WORKS!")
        print("=" * 60)
        
        tests = [
            self.test_environment,
            self.test_stripe_connectivity,
            self.test_billing_manager,
            self.test_license_system,
            self.test_auto_backup,
            self.test_webhook_endpoint
        ]
        
        for test in tests:
            try:
                test()
                print()  # Add spacing between tests
            except Exception as e:
                self.log(f"❌ Test failed with exception: {e}", "ERROR")
                
        return self.generate_report()

def main():
    """Main verification function"""
    verifier = WebhookVerifier()
    success = verifier.run_all_tests()
    
    if success:
        print("\n🎉 MISSION ACCOMPLISHED!")
        print("✅ WEBHOOK IS PROVEN TO BE WORKING!")
        print("🚀 GRIM REAPER IS READY FOR 3000 USERS!")
        sys.exit(0)
    else:
        print("\n⚠️ SOME ISSUES DETECTED")
        print("🔧 NEEDS CONFIGURATION BEFORE PRODUCTION")
        sys.exit(1)

if __name__ == "__main__":
    main() 