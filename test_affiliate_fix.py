#!/usr/bin/env python3
"""
Test script to verify affiliate system fix
"""

import sqlite3
import os
import json
from datetime import datetime

def test_affiliate_database():
    """Test affiliate database and show current state"""
    db_path = "/opt/reaper/db/grim_affiliates.db"
    
    print("🔍 AFFILIATE DATABASE CURRENT STATE")
    print("=" * 50)
    
    if not os.path.exists(db_path):
        print("❌ Affiliate database does not exist!")
        return
    
    with sqlite3.connect(db_path) as conn:
        cursor = conn.cursor()
        
        # Show all affiliates
        print("\n📊 AFFILIATES:")
        cursor.execute("SELECT affiliate_id, total_referrals, total_earnings_usd, created_at FROM affiliates")
        affiliates = cursor.fetchall()
        
        if affiliates:
            for affiliate in affiliates:
                print(f"  • {affiliate[0]}: {affiliate[1]} referrals, ${affiliate[2]} earnings (created: {affiliate[3]})")
        else:
            print("  No affiliates found")
        
        # Show all referrals
        print("\n📈 RECENT REFERRALS:")
        cursor.execute("""
            SELECT affiliate_id, referred_email, plan_name, commission_amount_usd, status, created_at 
            FROM referrals 
            ORDER BY created_at DESC 
            LIMIT 10
        """)
        referrals = cursor.fetchall()
        
        if referrals:
            for referral in referrals:
                print(f"  • {referral[0]} -> {referral[1]} ({referral[2]}) = ${referral[3]} [{referral[4]}] {referral[5]}")
        else:
            print("  No referrals found")

def test_mother_db_licenses():
    """Test mother database license table for affiliate_id column"""
    print("\n🔍 MOTHER DATABASE LICENSE CHECK")
    print("=" * 50)
    
    grims_mother_url = os.environ.get('GRIMS_MOTHER')
    if not grims_mother_url:
        print("❌ GRIMS_MOTHER environment variable not set")
        return
    
    try:
        import psycopg2
        from psycopg2.extras import RealDictCursor
        
        with psycopg2.connect(grims_mother_url) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                # Check if affiliate_id column exists
                cursor.execute("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_name = 'licenses' AND column_name = 'affiliate_id'
                """)
                
                column_info = cursor.fetchone()
                if column_info:
                    print(f"✅ affiliate_id column exists: {column_info['data_type']}")
                else:
                    print("❌ affiliate_id column missing in licenses table")
                
                # Show recent licenses with affiliate data
                cursor.execute("""
                    SELECT customer_email, affiliate_id, original_plan, created_at 
                    FROM licenses 
                    WHERE affiliate_id IS NOT NULL AND affiliate_id != ''
                    ORDER BY created_at DESC 
                    LIMIT 5
                """)
                
                licenses = cursor.fetchall()
                print(f"\n📋 RECENT AFFILIATE LICENSES ({len(licenses)} found):")
                
                for license in licenses:
                    print(f"  • {license['customer_email']} via {license['affiliate_id']} ({license['original_plan']}) - {license['created_at']}")
                
    except Exception as e:
        print(f"❌ Error checking mother database: {e}")

def create_test_affiliate():
    """Create a test affiliate for manual testing"""
    print("\n🧪 CREATING TEST AFFILIATE")
    print("=" * 50)
    
    db_path = "/opt/reaper/db/grim_affiliates.db"
    test_affiliate_id = "12345test"
    
    with sqlite3.connect(db_path) as conn:
        cursor = conn.cursor()
        
        # Check if affiliate already exists
        cursor.execute("SELECT id FROM affiliates WHERE affiliate_id = ?", (test_affiliate_id,))
        existing = cursor.fetchone()
        
        if existing:
            print(f"✅ Test affiliate {test_affiliate_id} already exists")
        else:
            # Create test affiliate
            cursor.execute("""
                INSERT INTO affiliates (affiliate_id, affiliate_url, created_at, status)
                VALUES (?, ?, ?, ?)
            """, (
                test_affiliate_id,
                f"https://grim.so/underworld/{test_affiliate_id}",
                datetime.now().isoformat(),
                'active'
            ))
            conn.commit()
            print(f"✅ Created test affiliate: {test_affiliate_id}")

def show_test_instructions():
    """Show manual testing instructions"""
    print("\n🧪 MANUAL TESTING INSTRUCTIONS")
    print("=" * 50)
    print("""
1. Visit affiliate link:
   curl -c cookies.txt 'http://localhost:8080/underworld/12345test'
   
2. Check logs for session setting:
   grep "AFFILIATE VISIT" /path/to/your/flask/logs
   
3. Create checkout session (simulate user clicking buy):
   curl -b cookies.txt -X POST http://localhost:8080/api/create-checkout-session \\
     -H "Content-Type: application/json" \\
     -d '{"plan": "pro", "price": 49, "billing_period": "monthly"}'
   
4. Check logs for affiliate_id in metadata:
   grep "Stripe session metadata" /path/to/your/flask/logs
   
5. Simulate successful payment (replace SESSION_ID):
   curl -b cookies.txt 'http://localhost:8080/success?session_id=STRIPE_SESSION_ID'
   
6. Check database for new referral:
   python3 test_affiliate_fix.py
""")

def main():
    """Main test function"""
    print("🔧 GRIM AFFILIATE SYSTEM - REPAIR VERIFICATION")
    print("=" * 60)
    
    test_affiliate_database()
    test_mother_db_licenses()
    create_test_affiliate()
    show_test_instructions()
    
    print("\n✅ Test script completed!")
    print("💡 Check the logs when running manual tests to see debug output")

if __name__ == "__main__":
    main()