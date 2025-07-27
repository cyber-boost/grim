#!/usr/bin/env python3
"""
Grim Billing Manager
Integrated with unified license system and GRIMS_MOTHER database
Handles Stripe payments and subscription management
"""

import os
import sys
import stripe
import psycopg2
import sqlite3
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
import logging
import json

logger = logging.getLogger(__name__)

class BillingManager:
    """Manages billing and subscriptions with unified license system integration"""
    
    def __init__(self):
        # Stripe configuration
        self.stripe_secret_key = os.getenv('STRIPE_SECRET_KEY')
        self.stripe_publishable_key = os.getenv('STRIPE_PUBLISHABLE_KEY')
        
        if self.stripe_secret_key:
            stripe.api_key = self.stripe_secret_key
        
        # GRIMS_MOTHER database configuration
        self.grims_mother_url = os.getenv('GRIMS_MOTHER')
        
        # Local cache for performance
        self.local_db_path = os.path.expanduser("~/.graveyard/grim_billing.db")
        self._init_local_database()
        
        # Tier pricing configuration
        self.tier_prices = {
            'PRO': {
                'monthly': 'price_pro_monthly',
                'annual': 'price_pro_annual',
                'amount': 2999,  # $29.99
                'currency': 'usd'
            },
            'MASTER': {
                'monthly': 'price_master_monthly', 
                'annual': 'price_master_annual',
                'amount': 9999,  # $99.99
                'currency': 'usd'
            },
            'REAPER': {
                'monthly': 'price_reaper_monthly',
                'annual': 'price_reaper_annual', 
                'amount': 29999,  # $299.99
                'currency': 'usd'
            }
        }
        
        # Storage limits per tier
        self.storage_limits = {
            'FREE': 5,      # 5 GB
            'PRO': 100,     # 100 GB
            'MASTER': 500,  # 500 GB
            'REAPER': 2000  # 2 TB
        }
    
    def _init_local_database(self):
        """Initialize local SQLite database for billing cache"""
        os.makedirs(os.path.dirname(self.local_db_path), exist_ok=True)
        
        with sqlite3.connect(self.local_db_path) as conn:
            cursor = conn.cursor()
            
            # Billing cache
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS grim_billing_cache (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    license_key TEXT NOT NULL,
                    stripe_customer_id TEXT,
                    stripe_subscription_id TEXT,
                    tier TEXT NOT NULL,
                    billing_cycle TEXT DEFAULT 'monthly',
                    status TEXT DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Payment history
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS grim_payment_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    license_key TEXT NOT NULL,
                    stripe_payment_intent_id TEXT,
                    amount INTEGER NOT NULL,
                    currency TEXT DEFAULT 'usd',
                    status TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.commit()
    
    def _get_grims_mother_connection(self):
        """Get connection to GRIMS_MOTHER database"""
        if not self.grims_mother_url:
            raise ValueError("GRIMS_MOTHER environment variable not set")
        
        return psycopg2.connect(self.grims_mother_url)
    
    def get_all_plans(self) -> Dict[str, Any]:
        """Get all available subscription plans"""
        return {
            'plans': [
                {
                    'id': 'FREE',
                    'name': 'Free',
                    'price': 0,
                    'currency': 'usd',
                    'billing_cycle': 'none',
                    'storage_gb': self.storage_limits['FREE'],
                    'features': [
                        'Basic auto-backup',
                        '5 GB storage',
                        'Email support'
                    ]
                },
                {
                    'id': 'PRO',
                    'name': 'Pro',
                    'price': 29.99,
                    'currency': 'usd',
                    'billing_cycle': 'monthly',
                    'storage_gb': self.storage_limits['PRO'],
                    'features': [
                        'Advanced auto-backup',
                        '100 GB storage',
                        'Priority support',
                        'Smart file selection',
                        'Tier-based backup locations'
                    ]
                },
                {
                    'id': 'MASTER',
                    'name': 'Master',
                    'price': 99.99,
                    'currency': 'usd',
                    'billing_cycle': 'monthly',
                    'storage_gb': self.storage_limits['MASTER'],
                    'features': [
                        'Everything in Pro',
                        '500 GB storage',
                        '24/7 support',
                        'Advanced encryption',
                        'Custom backup schedules'
                    ]
                },
                {
                    'id': 'REAPER',
                    'name': 'Reaper',
                    'price': 299.99,
                    'currency': 'usd',
                    'billing_cycle': 'monthly',
                    'storage_gb': self.storage_limits['REAPER'],
                    'features': [
                        'Everything in Master',
                        '2 TB storage',
                        'Dedicated support',
                        'Enterprise features',
                        'Custom integrations'
                    ]
                }
            ]
        }
    
    def get_user_billing_info(self, user_id: str) -> Dict[str, Any]:
        """Get user's billing information"""
        try:
            # Try GRIMS_MOTHER first
            with self._get_grims_mother_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT license_key, tier, stripe_customer_id, stripe_subscription_id
                    FROM grim_licenses 
                    WHERE user_id = %s AND is_active = TRUE
                """, (user_id,))
                
                row = cursor.fetchone()
                if row:
                    license_key, tier, stripe_customer_id, stripe_subscription_id = row
                    
                    # Get Stripe subscription details if available
                    subscription_info = {}
                    if stripe_subscription_id and self.stripe_secret_key:
                        try:
                            subscription = stripe.Subscription.retrieve(stripe_subscription_id)
                            subscription_info = {
                                'status': subscription.status,
                                'current_period_start': subscription.current_period_start,
                                'current_period_end': subscription.current_period_end,
                                'cancel_at_period_end': subscription.cancel_at_period_end
                            }
                        except stripe.error.StripeError as e:
                            logger.warning(f"Failed to retrieve Stripe subscription: {e}")
                    
                    return {
                        'user_id': user_id,
                        'license_key': license_key,
                        'tier': tier,
                        'stripe_customer_id': stripe_customer_id,
                        'stripe_subscription_id': stripe_subscription_id,
                        'subscription_info': subscription_info,
                        'storage_limit_gb': self.storage_limits.get(tier, 5),
                        'source': 'grims_mother'
                    }
            
            # Fallback to local cache
            with sqlite3.connect(self.local_db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT license_key, tier, stripe_customer_id, stripe_subscription_id, status
                    FROM grim_billing_cache 
                    WHERE user_id = ?
                """, (user_id,))
                
                row = cursor.fetchone()
                if row:
                    license_key, tier, stripe_customer_id, stripe_subscription_id, status = row
                    return {
                        'user_id': user_id,
                        'license_key': license_key,
                        'tier': tier,
                        'stripe_customer_id': stripe_customer_id,
                        'stripe_subscription_id': stripe_subscription_id,
                        'status': status,
                        'storage_limit_gb': self.storage_limits.get(tier, 5),
                        'source': 'local_cache'
                    }
            
            return {'error': 'User not found'}
            
        except Exception as e:
            logger.error(f"Error getting user billing info: {e}")
            return {'error': str(e)}
    
    def create_payment_intent(self, user_id: str, plan_name: str, billing_cycle: str = 'monthly', 
                            billing_details: Dict = None) -> Dict[str, Any]:
        """Create Stripe payment intent for subscription"""
        try:
            if not self.stripe_secret_key:
                return {'success': False, 'error': 'Stripe not configured'}
            
            # Get user info
            user_info = self.get_user_billing_info(user_id)
            if 'error' in user_info:
                return {'success': False, 'error': user_info['error']}
            
            # Validate plan
            if plan_name not in self.tier_prices:
                return {'success': False, 'error': 'Invalid plan'}
            
            plan_config = self.tier_prices[plan_name]
            price_id = plan_config.get(billing_cycle, plan_config['monthly'])
            
            # Create or get Stripe customer
            stripe_customer_id = user_info.get('stripe_customer_id')
            if not stripe_customer_id:
                customer = stripe.Customer.create(
                    email=billing_details.get('email') if billing_details else None,
                    name=billing_details.get('name') if billing_details else None
                )
                stripe_customer_id = customer.id
                
                # Update user info
                self._update_user_stripe_customer(user_id, stripe_customer_id)
            
            # Create payment intent
            payment_intent = stripe.PaymentIntent.create(
                amount=plan_config['amount'],
                currency=plan_config['currency'],
                customer=stripe_customer_id,
                metadata={
                    'user_id': user_id,
                    'plan': plan_name,
                    'billing_cycle': billing_cycle
                }
            )
            
            return {
                'success': True,
                'client_secret': payment_intent.client_secret,
                'payment_intent_id': payment_intent.id,
                'amount': plan_config['amount'],
                'currency': plan_config['currency']
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating payment intent: {e}")
            return {'success': False, 'error': str(e)}
        except Exception as e:
            logger.error(f"Error creating payment intent: {e}")
            return {'success': False, 'error': str(e)}
    
    def create_subscription(self, user_id: str, plan_name: str, billing_cycle: str = 'monthly',
                          payment_method_id: str = None) -> Dict[str, Any]:
        """Create Stripe subscription and update unified license system"""
        try:
            if not self.stripe_secret_key:
                return {'success': False, 'error': 'Stripe not configured'}
            
            # Get user info
            user_info = self.get_user_billing_info(user_id)
            if 'error' in user_info:
                return {'success': False, 'error': user_info['error']}
            
            # Validate plan
            if plan_name not in self.tier_prices:
                return {'success': False, 'error': 'Invalid plan'}
            
            plan_config = self.tier_prices[plan_name]
            price_id = plan_config.get(billing_cycle, plan_config['monthly'])
            
            # Get or create Stripe customer
            stripe_customer_id = user_info.get('stripe_customer_id')
            if not stripe_customer_id:
                customer = stripe.Customer.create()
                stripe_customer_id = customer.id
                self._update_user_stripe_customer(user_id, stripe_customer_id)
            
            # Create subscription
            subscription_data = {
                'customer': stripe_customer_id,
                'items': [{'price': price_id}],
                'expand': ['latest_invoice.payment_intent']
            }
            
            if payment_method_id:
                subscription_data['default_payment_method'] = payment_method_id
            
            subscription = stripe.Subscription.create(**subscription_data)
            
            # Update unified license system
            license_key = user_info.get('license_key')
            if license_key:
                self._upgrade_license_tier(license_key, plan_name, stripe_customer_id, subscription.id)
            
            # Update local cache
            self._update_billing_cache(user_id, license_key, plan_name, stripe_customer_id, subscription.id)
            
            return {
                'success': True,
                'subscription_id': subscription.id,
                'client_secret': subscription.latest_invoice.payment_intent.client_secret,
                'tier': plan_name
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating subscription: {e}")
            return {'success': False, 'error': str(e)}
        except Exception as e:
            logger.error(f"Error creating subscription: {e}")
            return {'success': False, 'error': str(e)}
    
    def handle_webhook(self, payload: str, sig_header: str) -> Dict[str, Any]:
        """Handle Stripe webhooks and update unified license system"""
        try:
            if not self.stripe_secret_key:
                return {'status': 'error', 'message': 'Stripe not configured'}
            
            # Verify webhook signature
            webhook_secret = os.getenv('STRIPE_WEBHOOK_SECRET')
            if webhook_secret:
                try:
                    event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
                except ValueError as e:
                    return {'status': 'error', 'message': 'Invalid payload'}
                except stripe.error.SignatureVerificationError as e:
                    return {'status': 'error', 'message': 'Invalid signature'}
            else:
                # Parse without signature verification (development)
                event = json.loads(payload)
            
            # Handle different event types
            event_type = event['type']
            
            if event_type == 'invoice.payment_succeeded':
                return self._handle_payment_success(event['data']['object'])
            elif event_type == 'invoice.payment_failed':
                return self._handle_payment_failure(event['data']['object'])
            elif event_type == 'customer.subscription.deleted':
                return self._handle_subscription_cancelled(event['data']['object'])
            elif event_type == 'customer.subscription.updated':
                return self._handle_subscription_updated(event['data']['object'])
            else:
                return {'status': 'success', 'message': f'Unhandled event type: {event_type}'}
                
        except Exception as e:
            logger.error(f"Error handling webhook: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def _handle_payment_success(self, invoice: Dict) -> Dict[str, Any]:
        """Handle successful payment"""
        try:
            subscription_id = invoice.get('subscription')
            if subscription_id:
                subscription = stripe.Subscription.retrieve(subscription_id)
                customer_id = subscription.customer
                
                # Update subscription status in unified system
                self._update_subscription_status(subscription_id, 'active')
                
                logger.info(f"Payment succeeded for subscription {subscription_id}")
                return {'status': 'success', 'message': 'Payment processed'}
            
            return {'status': 'success', 'message': 'Payment processed'}
            
        except Exception as e:
            logger.error(f"Error handling payment success: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def _handle_payment_failure(self, invoice: Dict) -> Dict[str, Any]:
        """Handle failed payment"""
        try:
            subscription_id = invoice.get('subscription')
            if subscription_id:
                # Update subscription status
                self._update_subscription_status(subscription_id, 'past_due')
                
                logger.warning(f"Payment failed for subscription {subscription_id}")
                return {'status': 'success', 'message': 'Payment failure handled'}
            
            return {'status': 'success', 'message': 'Payment failure handled'}
            
        except Exception as e:
            logger.error(f"Error handling payment failure: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def _handle_subscription_cancelled(self, subscription: Dict) -> Dict[str, Any]:
        """Handle subscription cancellation"""
        try:
            subscription_id = subscription.get('id')
            if subscription_id:
                # Downgrade to FREE tier
                self._downgrade_to_free_tier(subscription_id)
                
                logger.info(f"Subscription {subscription_id} cancelled, downgraded to FREE")
                return {'status': 'success', 'message': 'Subscription cancelled'}
            
            return {'status': 'success', 'message': 'Subscription cancelled'}
            
        except Exception as e:
            logger.error(f"Error handling subscription cancellation: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def _handle_subscription_updated(self, subscription: Dict) -> Dict[str, Any]:
        """Handle subscription updates"""
        try:
            subscription_id = subscription.get('id')
            if subscription_id:
                # Update subscription status
                status = subscription.get('status', 'active')
                self._update_subscription_status(subscription_id, status)
                
                logger.info(f"Subscription {subscription_id} updated to {status}")
                return {'status': 'success', 'message': 'Subscription updated'}
            
            return {'status': 'success', 'message': 'Subscription updated'}
            
        except Exception as e:
            logger.error(f"Error handling subscription update: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def _upgrade_license_tier(self, license_key: str, new_tier: str, stripe_customer_id: str, subscription_id: str):
        """Upgrade license tier in unified system"""
        try:
            # Update GRIMS_MOTHER
            with self._get_grims_mother_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE grim_licenses 
                    SET tier = %s, stripe_customer_id = %s, stripe_subscription_id = %s
                    WHERE license_key = %s
                """, (new_tier, stripe_customer_id, subscription_id, license_key))
                conn.commit()
            
            # Update local cache
            with sqlite3.connect(self.local_db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT OR REPLACE INTO grim_billing_cache 
                    (user_id, license_key, tier, stripe_customer_id, stripe_subscription_id, status)
                    VALUES (?, ?, ?, ?, ?, 'active')
                """, (license_key, license_key, new_tier, stripe_customer_id, subscription_id))
                conn.commit()
            
            logger.info(f"License {license_key} upgraded to {new_tier}")
            
        except Exception as e:
            logger.error(f"Error upgrading license tier: {e}")
    
    def _downgrade_to_free_tier(self, subscription_id: str):
        """Downgrade subscription to FREE tier"""
        try:
            # Find license by subscription ID
            with self._get_grims_mother_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE grim_licenses 
                    SET tier = 'FREE', stripe_subscription_id = NULL
                    WHERE stripe_subscription_id = %s
                """, (subscription_id,))
                conn.commit()
            
            # Update local cache
            with sqlite3.connect(self.local_db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE grim_billing_cache 
                    SET tier = 'FREE', status = 'cancelled'
                    WHERE stripe_subscription_id = ?
                """, (subscription_id,))
                conn.commit()
            
            logger.info(f"Subscription {subscription_id} downgraded to FREE")
            
        except Exception as e:
            logger.error(f"Error downgrading subscription: {e}")
    
    def _update_subscription_status(self, subscription_id: str, status: str):
        """Update subscription status in cache"""
        try:
            with sqlite3.connect(self.local_db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE grim_billing_cache 
                    SET status = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE stripe_subscription_id = ?
                """, (status, subscription_id))
                conn.commit()
        except Exception as e:
            logger.error(f"Error updating subscription status: {e}")
    
    def _update_user_stripe_customer(self, user_id: str, stripe_customer_id: str):
        """Update user's Stripe customer ID"""
        try:
            with self._get_grims_mother_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE grim_licenses 
                    SET stripe_customer_id = %s
                    WHERE user_id = %s
                """, (stripe_customer_id, user_id))
                conn.commit()
        except Exception as e:
            logger.error(f"Error updating user Stripe customer ID: {e}")
    
    def _update_billing_cache(self, user_id: str, license_key: str, tier: str, 
                            stripe_customer_id: str, subscription_id: str):
        """Update billing cache"""
        try:
            with sqlite3.connect(self.local_db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT OR REPLACE INTO grim_billing_cache 
                    (user_id, license_key, tier, stripe_customer_id, stripe_subscription_id, status)
                    VALUES (?, ?, ?, ?, ?, 'active')
                """, (user_id, license_key, tier, stripe_customer_id, subscription_id))
                conn.commit()
        except Exception as e:
            logger.error(f"Error updating billing cache: {e}")
    
    @property
    def config(self):
        """Configuration object for external access"""
        return type('Config', (), {
            'stripe_publishable_key': self.stripe_publishable_key,
            'stripe_secret_key': self.stripe_secret_key
        })()

def get_billing_manager():
    """Get billing manager instance"""
    return BillingManager()

if __name__ == "__main__":
    # CLI interface for testing
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim Billing Manager")
    parser.add_argument("command", choices=["plans", "user-info", "create-intent", "create-subscription"])
    parser.add_argument("--user-id", help="User ID")
    parser.add_argument("--plan", help="Plan name")
    parser.add_argument("--billing-cycle", default="monthly", help="Billing cycle")
    
    args = parser.parse_args()
    
    try:
        manager = BillingManager()
        
        if args.command == "plans":
            plans = manager.get_all_plans()
            print(json.dumps(plans, indent=2))
        
        elif args.command == "user-info":
            if not args.user_id:
                print("❌ User ID required")
                sys.exit(1)
            
            info = manager.get_user_billing_info(args.user_id)
            print(json.dumps(info, indent=2))
        
        elif args.command == "create-intent":
            if not all([args.user_id, args.plan]):
                print("❌ User ID and plan required")
                sys.exit(1)
            
            result = manager.create_payment_intent(args.user_id, args.plan, args.billing_cycle)
            print(json.dumps(result, indent=2))
        
        elif args.command == "create-subscription":
            if not all([args.user_id, args.plan]):
                print("❌ User ID and plan required")
                sys.exit(1)
            
            result = manager.create_subscription(args.user_id, args.plan, args.billing_cycle)
            print(json.dumps(result, indent=2))
    
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1) 