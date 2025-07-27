"""
Stripe Connect integration for vendor payments and commission tracking
"""

import stripe
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from decimal import Decimal

logger = logging.getLogger(__name__)

class StripeConnectManager:
    """Manages Stripe Connect for vendor payments and commission tracking"""
    
    def __init__(self, stripe_secret_key: str, connect_client_id: str):
        self.stripe = stripe
        self.stripe.api_key = stripe_secret_key
        self.connect_client_id = connect_client_id
        self.db_manager = None
    
    def set_db_manager(self, db_manager):
        """Set database manager for persistence"""
        self.db_manager = db_manager
    
    def create_connect_account(self, vendor_id: int, vendor_email: str, vendor_name: str) -> Dict[str, Any]:
        """Create a Stripe Connect account for a vendor"""
        try:
            # Create Connect account
            account = self.stripe.Account.create(
                type='express',
                country='US',  # Default country
                email=vendor_email,
                business_type='individual',
                capabilities={
                    'card_payments': {'requested': True},
                    'transfers': {'requested': True},
                },
                business_profile={
                    'name': vendor_name,
                    'url': 'https://scythe.com',
                    'mcc': '5734',  # Computer Software Stores
                },
                metadata={
                    'vendor_id': str(vendor_id),
                    'created_at': datetime.utcnow().isoformat()
                }
            )
            
            # Store Connect account info in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "UPDATE vendors SET stripe_connect_account_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                    (account.id, vendor_id)
                )
            
            logger.info(f"Created Stripe Connect account {account.id} for vendor {vendor_id}")
            
            return {
                'account_id': account.id,
                'vendor_id': vendor_id,
                'status': account.status,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating Connect account for vendor {vendor_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating Connect account for vendor {vendor_id}: {e}")
            raise
    
    def get_connect_account(self, vendor_id: int) -> Optional[Dict[str, Any]]:
        """Get Stripe Connect account for a vendor"""
        try:
            vendors = self.db_manager.execute_query(
                "SELECT stripe_connect_account_id FROM vendors WHERE id = ?",
                (vendor_id,)
            )
            
            if not vendors or not vendors[0]['stripe_connect_account_id']:
                return None
            
            account_id = vendors[0]['stripe_connect_account_id']
            account = self.stripe.Account.retrieve(account_id)
            
            return {
                'account_id': account.id,
                'vendor_id': vendor_id,
                'status': account.status,
                'charges_enabled': account.charges_enabled,
                'payouts_enabled': account.payouts_enabled,
                'details_submitted': account.details_submitted,
                'stripe_data': account
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting Connect account for vendor {vendor_id}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error getting Connect account for vendor {vendor_id}: {e}")
            return None
    
    def create_connect_login_link(self, vendor_id: int) -> Optional[str]:
        """Create a login link for vendor to access their Connect dashboard"""
        try:
            account = self.get_connect_account(vendor_id)
            if not account:
                return None
            
            login_link = self.stripe.Account.create_login_link(account['account_id'])
            return login_link.url
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating login link for vendor {vendor_id}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error creating login link for vendor {vendor_id}: {e}")
            return None
    
    def calculate_commission(self, amount: float, commission_rate: float) -> Dict[str, float]:
        """Calculate commission for a transaction"""
        commission_amount = amount * (commission_rate / 100)
        platform_amount = amount - commission_amount
        
        return {
            'total_amount': amount,
            'commission_amount': round(commission_amount, 2),
            'platform_amount': round(platform_amount, 2),
            'commission_rate': commission_rate
        }
    
    def create_split_payment(self, payment_intent_id: str, vendor_id: int, 
                           commission_rate: float) -> Dict[str, Any]:
        """Create a split payment between platform and vendor"""
        try:
            # Get payment intent
            payment_intent = self.stripe.PaymentIntent.retrieve(payment_intent_id)
            
            if payment_intent.status != 'succeeded':
                raise ValueError(f"Payment intent {payment_intent_id} not succeeded")
            
            # Get vendor's Connect account
            account = self.get_connect_account(vendor_id)
            if not account:
                raise ValueError(f"No Connect account found for vendor {vendor_id}")
            
            if not account['charges_enabled']:
                raise ValueError(f"Connect account {account['account_id']} not enabled for charges")
            
            # Calculate commission
            amount = payment_intent.amount / 100  # Convert from cents
            commission_calc = self.calculate_commission(amount, commission_rate)
            
            # Create transfer to vendor
            transfer = self.stripe.Transfer.create(
                amount=int(commission_calc['commission_amount'] * 100),  # Convert to cents
                currency=payment_intent.currency,
                destination=account['account_id'],
                source_transaction=payment_intent.latest_charge,
                description=f"Commission payment for vendor {vendor_id}",
                metadata={
                    'vendor_id': str(vendor_id),
                    'payment_intent_id': payment_intent_id,
                    'commission_rate': str(commission_rate),
                    'platform_amount': str(commission_calc['platform_amount'])
                }
            )
            
            # Store transfer in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT INTO vendor_transfers (vendor_id, stripe_transfer_id, payment_intent_id, amount, currency, commission_rate, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (vendor_id, transfer.id, payment_intent_id, commission_calc['commission_amount'], payment_intent.currency, commission_rate, transfer.status, datetime.utcnow().isoformat())
                )
            
            logger.info(f"Created transfer {transfer.id} for vendor {vendor_id}")
            
            return {
                'transfer_id': transfer.id,
                'vendor_id': vendor_id,
                'payment_intent_id': payment_intent_id,
                'amount': commission_calc['commission_amount'],
                'currency': payment_intent.currency,
                'commission_rate': commission_rate,
                'platform_amount': commission_calc['platform_amount'],
                'status': transfer.status,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating split payment for vendor {vendor_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating split payment for vendor {vendor_id}: {e}")
            raise
    
    def process_vendor_payout(self, vendor_id: int, amount: float, currency: str = 'usd') -> Dict[str, Any]:
        """Process a payout to a vendor"""
        try:
            # Get vendor's Connect account
            account = self.get_connect_account(vendor_id)
            if not account:
                raise ValueError(f"No Connect account found for vendor {vendor_id}")
            
            if not account['payouts_enabled']:
                raise ValueError(f"Connect account {account['account_id']} not enabled for payouts")
            
            # Create payout
            payout = self.stripe.Payout.create(
                amount=int(amount * 100),  # Convert to cents
                currency=currency,
                stripe_account=account['account_id'],
                description=f"Payout for vendor {vendor_id}",
                metadata={
                    'vendor_id': str(vendor_id),
                    'payout_type': 'manual'
                }
            )
            
            # Store payout in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT INTO vendor_payouts (vendor_id, stripe_payout_id, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                    (vendor_id, payout.id, amount, currency, payout.status, datetime.utcnow().isoformat())
                )
            
            logger.info(f"Created payout {payout.id} for vendor {vendor_id}")
            
            return {
                'payout_id': payout.id,
                'vendor_id': vendor_id,
                'amount': amount,
                'currency': currency,
                'status': payout.status,
                'arrival_date': datetime.fromtimestamp(payout.arrival_date).isoformat() if payout.arrival_date else None,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error processing payout for vendor {vendor_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error processing payout for vendor {vendor_id}: {e}")
            raise
    
    def get_vendor_balance(self, vendor_id: int) -> Dict[str, Any]:
        """Get vendor's current balance"""
        try:
            account = self.get_connect_account(vendor_id)
            if not account:
                return {'available': 0, 'pending': 0, 'currency': 'usd'}
            
            balance = self.stripe.Balance.retrieve(stripe_account=account['account_id'])
            
            # Find USD balance
            usd_balance = None
            for balance_obj in balance.available + balance.pending:
                if balance_obj.currency == 'usd':
                    usd_balance = balance_obj
                    break
            
            if not usd_balance:
                return {'available': 0, 'pending': 0, 'currency': 'usd'}
            
            return {
                'available': usd_balance.amount / 100,  # Convert from cents
                'pending': usd_balance.amount / 100,
                'currency': usd_balance.currency
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting balance for vendor {vendor_id}: {e}")
            return {'available': 0, 'pending': 0, 'currency': 'usd'}
        except Exception as e:
            logger.error(f"Error getting balance for vendor {vendor_id}: {e}")
            return {'available': 0, 'pending': 0, 'currency': 'usd'}
    
    def get_vendor_transfers(self, vendor_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Get transfer history for a vendor"""
        try:
            account = self.get_connect_account(vendor_id)
            if not account:
                return []
            
            transfers = self.stripe.Transfer.list(
                destination=account['account_id'],
                limit=limit
            )
            
            transfer_list = []
            for transfer in transfers.data:
                transfer_list.append({
                    'transfer_id': transfer.id,
                    'amount': transfer.amount / 100,  # Convert from cents
                    'currency': transfer.currency,
                    'status': transfer.status,
                    'created': datetime.fromtimestamp(transfer.created).isoformat(),
                    'description': transfer.description,
                    'metadata': transfer.metadata
                })
            
            return transfer_list
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting transfers for vendor {vendor_id}: {e}")
            return []
        except Exception as e:
            logger.error(f"Error getting transfers for vendor {vendor_id}: {e}")
            return []
    
    def get_vendor_payouts(self, vendor_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Get payout history for a vendor"""
        try:
            account = self.get_connect_account(vendor_id)
            if not account:
                return []
            
            payouts = self.stripe.Payout.list(
                stripe_account=account['account_id'],
                limit=limit
            )
            
            payout_list = []
            for payout in payouts.data:
                payout_list.append({
                    'payout_id': payout.id,
                    'amount': payout.amount / 100,  # Convert from cents
                    'currency': payout.currency,
                    'status': payout.status,
                    'created': datetime.fromtimestamp(payout.created).isoformat(),
                    'arrival_date': datetime.fromtimestamp(payout.arrival_date).isoformat() if payout.arrival_date else None,
                    'description': payout.description
                })
            
            return payout_list
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting payouts for vendor {vendor_id}: {e}")
            return []
        except Exception as e:
            logger.error(f"Error getting payouts for vendor {vendor_id}: {e}")
            return []
    
    def refund_transfer(self, transfer_id: str, vendor_id: int, amount: float = None) -> Dict[str, Any]:
        """Refund a transfer to a vendor"""
        try:
            # Get transfer
            transfer = self.stripe.Transfer.retrieve(transfer_id)
            
            if transfer.destination != self.get_connect_account(vendor_id)['account_id']:
                raise ValueError(f"Transfer {transfer_id} does not belong to vendor {vendor_id}")
            
            # Create refund
            refund_amount = int(amount * 100) if amount else transfer.amount
            refund = self.stripe.Refund.create(
                charge=transfer.source_transaction,
                amount=refund_amount,
                metadata={
                    'vendor_id': str(vendor_id),
                    'transfer_id': transfer_id,
                    'refund_type': 'transfer_refund'
                }
            )
            
            # Update transfer status in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "UPDATE vendor_transfers SET status = 'refunded', updated_at = CURRENT_TIMESTAMP WHERE stripe_transfer_id = ?",
                    (transfer_id,)
                )
            
            logger.info(f"Refunded transfer {transfer_id} for vendor {vendor_id}")
            
            return {
                'refund_id': refund.id,
                'transfer_id': transfer_id,
                'vendor_id': vendor_id,
                'amount': refund.amount / 100,  # Convert from cents
                'currency': refund.currency,
                'status': refund.status,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error refunding transfer {transfer_id}: {e}")
            raise
        except Exception as e:
            logger.error(f"Error refunding transfer {transfer_id}: {e}")
            raise 