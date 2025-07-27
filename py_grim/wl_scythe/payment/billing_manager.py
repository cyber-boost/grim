"""
BillingManager - Complete Stripe integration for subscription management
"""

import stripe
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
from decimal import Decimal
import json

logger = logging.getLogger(__name__)

class BillingManager:
    """Manages all billing operations with Stripe integration"""
    
    def __init__(self, stripe_secret_key: str, stripe_connect_client_id: str = None):
        self.stripe = stripe
        self.stripe.api_key = stripe_secret_key
        self.connect_client_id = stripe_connect_client_id
        self.db_manager = None  # Will be set externally
        
        # Tier pricing configuration
        self.tier_pricing = {
            'FREE': {
                'monthly': 0,
                'yearly': 0,
                'currency': 'usd',
                'stripe_price_id': None
            },
            'PRO': {
                'monthly': 2999,  # $29.99
                'yearly': 29990,  # $299.90 (2 months free)
                'currency': 'usd',
                'stripe_price_id': None
            },
            'MASTER': {
                'monthly': 9999,  # $99.99
                'yearly': 99990,  # $999.90 (2 months free)
                'currency': 'usd',
                'stripe_price_id': None
            },
            'REAPER': {
                'monthly': 19999,  # $199.99
                'yearly': 199990,  # $1999.90 (2 months free)
                'currency': 'usd',
                'stripe_price_id': None
            }
        }
        
        # Overage pricing
        self.overage_pricing = {
            'storage_gb': 0.10,  # $0.10 per GB
            'api_calls': 0.001,  # $0.001 per API call
            'alerts': 0.01,      # $0.01 per alert
            'currency': 'usd'
        }
    
    def set_db_manager(self, db_manager):
        """Set database manager for persistence"""
        self.db_manager = db_manager
    
    def create_stripe_customer(self, user_id: str, email: str, name: str = None) -> Dict[str, Any]:
        """Create a new Stripe customer"""
        try:
            customer_data = {
                'email': email,
                'metadata': {
                    'user_id': user_id,
                    'created_at': datetime.utcnow().isoformat()
                }
            }
            
            if name:
                customer_data['name'] = name
            
            customer = self.stripe.Customer.create(**customer_data)
            
            # Store customer info in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT OR REPLACE INTO stripe_customers (user_id, stripe_customer_id, email, created_at) VALUES (?, ?, ?, ?)",
                    (user_id, customer.id, email, datetime.utcnow().isoformat())
                )
            
            logger.info(f"Created Stripe customer {customer.id} for user {user_id}")
            return {
                'customer_id': customer.id,
                'user_id': user_id,
                'email': email,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating customer for user {user_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating customer for user {user_id}: {e}")
            raise
    
    def get_stripe_customer(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get Stripe customer by user ID"""
        try:
            if self.db_manager:
                customers = self.db_manager.execute_query(
                    "SELECT * FROM stripe_customers WHERE user_id = ?",
                    (user_id,)
                )
                
                if customers:
                    customer_data = customers[0]
                    # Fetch latest data from Stripe
                    stripe_customer = self.stripe.Customer.retrieve(customer_data['stripe_customer_id'])
                    return {
                        'customer_id': stripe_customer.id,
                        'user_id': user_id,
                        'email': stripe_customer.email,
                        'name': stripe_customer.name,
                        'created_at': customer_data['created_at'],
                        'stripe_data': stripe_customer
                    }
            
            return None
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting customer for user {user_id}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error getting customer for user {user_id}: {e}")
            return None
    
    def create_subscription(self, user_id: str, tier: str, billing_cycle: str = 'monthly', 
                          payment_method_id: str = None) -> Dict[str, Any]:
        """Create a subscription for a user"""
        try:
            # Validate tier and billing cycle
            if tier not in self.tier_pricing:
                raise ValueError(f"Invalid tier: {tier}")
            
            if billing_cycle not in ['monthly', 'yearly']:
                raise ValueError(f"Invalid billing cycle: {billing_cycle}")
            
            # Get or create customer
            customer = self.get_stripe_customer(user_id)
            if not customer:
                # Get user info from database
                users = self.db_manager.execute_query(
                    "SELECT email, name FROM users WHERE user_id = ?",
                    (user_id,)
                )
                if users:
                    user_data = users[0]
                    customer = self.create_stripe_customer(user_id, user_data['email'], user_data.get('name'))
                else:
                    raise ValueError(f"User {user_id} not found")
            
            # Get pricing for tier
            pricing = self.tier_pricing[tier]
            amount = pricing[billing_cycle]
            
            if amount == 0:
                # Free tier - create subscription record without Stripe
                subscription_data = {
                    'user_id': user_id,
                    'tier': tier,
                    'billing_cycle': billing_cycle,
                    'amount': 0,
                    'currency': pricing['currency'],
                    'status': 'active',
                    'stripe_subscription_id': None,
                    'created_at': datetime.utcnow().isoformat()
                }
                
                if self.db_manager:
                    subscription_id = self.db_manager.execute_query(
                        "INSERT INTO subscriptions (user_id, tier, billing_cycle, amount, currency, status, stripe_subscription_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        (user_id, tier, billing_cycle, amount, pricing['currency'], 'active', None, datetime.utcnow().isoformat())
                    )
                
                return subscription_data
            
            # Create Stripe subscription
            subscription_data = {
                'customer': customer['customer_id'],
                'items': [{
                    'price_data': {
                        'currency': pricing['currency'],
                        'unit_amount': amount,
                        'recurring': {
                            'interval': billing_cycle
                        },
                        'product_data': {
                            'name': f'Scythe {tier} Plan',
                            'description': f'{tier} tier subscription'
                        }
                    }
                }],
                'metadata': {
                    'user_id': user_id,
                    'tier': tier,
                    'billing_cycle': billing_cycle
                }
            }
            
            if payment_method_id:
                subscription_data['default_payment_method'] = payment_method_id
            
            subscription = self.stripe.Subscription.create(**subscription_data)
            
            # Store subscription in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT INTO subscriptions (user_id, tier, billing_cycle, amount, currency, status, stripe_subscription_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (user_id, tier, billing_cycle, amount, pricing['currency'], subscription.status, subscription.id, datetime.utcnow().isoformat())
                )
            
            logger.info(f"Created subscription {subscription.id} for user {user_id} tier {tier}")
            
            return {
                'subscription_id': subscription.id,
                'user_id': user_id,
                'tier': tier,
                'billing_cycle': billing_cycle,
                'amount': amount,
                'currency': pricing['currency'],
                'status': subscription.status,
                'created_at': datetime.utcnow().isoformat(),
                'stripe_data': subscription
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating subscription for user {user_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating subscription for user {user_id}: {e}")
            raise
    
    def cancel_subscription(self, user_id: str, subscription_id: str = None) -> Dict[str, Any]:
        """Cancel a subscription"""
        try:
            # Get subscription
            if subscription_id:
                stripe_subscription = self.stripe.Subscription.retrieve(subscription_id)
            else:
                # Get from database
                subscriptions = self.db_manager.execute_query(
                    "SELECT stripe_subscription_id FROM subscriptions WHERE user_id = ? AND status = 'active'",
                    (user_id,)
                )
                if not subscriptions:
                    raise ValueError(f"No active subscription found for user {user_id}")
                
                stripe_subscription = self.stripe.Subscription.retrieve(subscriptions[0]['stripe_subscription_id'])
            
            # Cancel at period end
            cancelled_subscription = self.stripe.Subscription.modify(
                stripe_subscription.id,
                cancel_at_period_end=True
            )
            
            # Update database
            if self.db_manager:
                self.db_manager.execute_query(
                    "UPDATE subscriptions SET status = 'cancelling' WHERE stripe_subscription_id = ?",
                    (stripe_subscription.id,)
                )
            
            logger.info(f"Cancelled subscription {stripe_subscription.id} for user {user_id}")
            
            return {
                'subscription_id': stripe_subscription.id,
                'user_id': user_id,
                'status': 'cancelling',
                'cancel_at': cancelled_subscription.cancel_at,
                'updated_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error cancelling subscription for user {user_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error cancelling subscription for user {user_id}: {e}")
            raise
    
    def calculate_overage(self, user_id: str, usage_data: Dict[str, Any]) -> Dict[str, Any]:
        """Calculate overage charges based on usage"""
        try:
            # Get user's tier limits
            subscriptions = self.db_manager.execute_query(
                "SELECT tier FROM subscriptions WHERE user_id = ? AND status = 'active'",
                (user_id,)
            )
            
            if not subscriptions:
                return {'overage_amount': 0, 'currency': 'usd', 'details': {}}
            
            tier = subscriptions[0]['tier']
            
            # Get tier limits from config
            from ..api.utils.config import Config
            tier_limits = Config.get_tier_limits()
            
            if tier not in tier_limits:
                return {'overage_amount': 0, 'currency': 'usd', 'details': {}}
            
            limits = tier_limits[tier]
            overage_details = {}
            total_overage = 0
            
            # Calculate storage overage
            if 'storage_gb' in usage_data:
                storage_used = usage_data['storage_gb']
                storage_limit = limits['storage_gb']
                if storage_used > storage_limit:
                    overage_gb = storage_used - storage_limit
                    overage_amount = overage_gb * self.overage_pricing['storage_gb']
                    overage_details['storage'] = {
                        'used_gb': storage_used,
                        'limit_gb': storage_limit,
                        'overage_gb': overage_gb,
                        'amount': overage_amount
                    }
                    total_overage += overage_amount
            
            # Calculate API calls overage
            if 'api_calls' in usage_data:
                api_calls_used = usage_data['api_calls']
                api_calls_limit = limits['api_calls_per_hour'] * 24 * 30  # Monthly limit
                if api_calls_used > api_calls_limit:
                    overage_calls = api_calls_used - api_calls_limit
                    overage_amount = overage_calls * self.overage_pricing['api_calls']
                    overage_details['api_calls'] = {
                        'used': api_calls_used,
                        'limit': api_calls_limit,
                        'overage': overage_calls,
                        'amount': overage_amount
                    }
                    total_overage += overage_amount
            
            # Calculate alerts overage
            if 'alerts' in usage_data:
                alerts_used = usage_data['alerts']
                alerts_limit = limits['alerts_per_day'] * 30  # Monthly limit
                if alerts_used > alerts_limit:
                    overage_alerts = alerts_used - alerts_limit
                    overage_amount = overage_alerts * self.overage_pricing['alerts']
                    overage_details['alerts'] = {
                        'used': alerts_used,
                        'limit': alerts_limit,
                        'overage': overage_alerts,
                        'amount': overage_amount
                    }
                    total_overage += overage_amount
            
            return {
                'overage_amount': round(total_overage, 2),
                'currency': self.overage_pricing['currency'],
                'details': overage_details,
                'user_id': user_id,
                'tier': tier
            }
            
        except Exception as e:
            logger.error(f"Error calculating overage for user {user_id}: {e}")
            return {'overage_amount': 0, 'currency': 'usd', 'details': {}}
    
    def create_overage_invoice(self, user_id: str, overage_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create an invoice for overage charges"""
        try:
            if overage_data['overage_amount'] <= 0:
                return {'invoice_id': None, 'amount': 0}
            
            # Get customer
            customer = self.get_stripe_customer(user_id)
            if not customer:
                raise ValueError(f"No Stripe customer found for user {user_id}")
            
            # Create invoice
            invoice = self.stripe.Invoice.create(
                customer=customer['customer_id'],
                description=f"Overage charges for {overage_data['tier']} tier",
                metadata={
                    'user_id': user_id,
                    'tier': overage_data['tier'],
                    'type': 'overage'
                }
            )
            
            # Add invoice items
            for category, details in overage_data['details'].items():
                self.stripe.InvoiceItem.create(
                    customer=customer['customer_id'],
                    invoice=invoice.id,
                    amount=int(details['amount'] * 100),  # Convert to cents
                    currency=overage_data['currency'],
                    description=f"{category.title()} overage charges"
                )
            
            # Finalize and send invoice
            invoice = self.stripe.Invoice.finalize_invoice(invoice.id)
            invoice = self.stripe.Invoice.send_invoice(invoice.id)
            
            # Store invoice in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT INTO invoices (user_id, stripe_invoice_id, amount, currency, status, type, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (user_id, invoice.id, overage_data['overage_amount'], overage_data['currency'], invoice.status, 'overage', datetime.utcnow().isoformat())
                )
            
            logger.info(f"Created overage invoice {invoice.id} for user {user_id}")
            
            return {
                'invoice_id': invoice.id,
                'amount': overage_data['overage_amount'],
                'currency': overage_data['currency'],
                'status': invoice.status,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating overage invoice for user {user_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating overage invoice for user {user_id}: {e}")
            raise
    
    def get_subscription_status(self, user_id: str) -> Dict[str, Any]:
        """Get current subscription status for a user"""
        try:
            subscriptions = self.db_manager.execute_query(
                "SELECT * FROM subscriptions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1",
                (user_id,)
            )
            
            if not subscriptions:
                return {
                    'user_id': user_id,
                    'has_subscription': False,
                    'tier': 'FREE',
                    'status': 'none'
                }
            
            subscription = subscriptions[0]
            
            # Get latest data from Stripe if applicable
            stripe_data = None
            if subscription['stripe_subscription_id']:
                try:
                    stripe_data = self.stripe.Subscription.retrieve(subscription['stripe_subscription_id'])
                except stripe.error.StripeError:
                    pass
            
            return {
                'user_id': user_id,
                'has_subscription': True,
                'tier': subscription['tier'],
                'billing_cycle': subscription['billing_cycle'],
                'amount': subscription['amount'],
                'currency': subscription['currency'],
                'status': subscription['status'],
                'created_at': subscription['created_at'],
                'stripe_data': stripe_data
            }
            
        except Exception as e:
            logger.error(f"Error getting subscription status for user {user_id}: {e}")
            return {
                'user_id': user_id,
                'has_subscription': False,
                'tier': 'FREE',
                'status': 'error'
            } 