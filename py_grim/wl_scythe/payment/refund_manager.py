"""
Refund and chargeback handling manager
"""

import stripe
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from decimal import Decimal

logger = logging.getLogger(__name__)

class RefundManager:
    """Manages refunds and chargeback handling"""
    
    def __init__(self, stripe_secret_key: str):
        self.stripe = stripe
        self.stripe.api_key = stripe_secret_key
        self.db_manager = None
    
    def set_db_manager(self, db_manager):
        """Set database manager for persistence"""
        self.db_manager = db_manager
    
    def create_refund(self, payment_intent_id: str, amount: float = None, 
                     reason: str = 'requested_by_customer') -> Dict[str, Any]:
        """Create a refund for a payment"""
        try:
            # Get payment intent
            payment_intent = self.stripe.PaymentIntent.retrieve(payment_intent_id)
            
            if payment_intent.status != 'succeeded':
                raise ValueError(f"Payment intent {payment_intent_id} not succeeded")
            
            # Get customer info
            customer_id = payment_intent.customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            user_id = customers[0]['user_id'] if customers else None
            
            # Create refund
            refund_data = {
                'payment_intent': payment_intent_id,
                'reason': reason,
                'metadata': {
                    'user_id': user_id,
                    'refund_type': 'manual',
                    'created_at': datetime.utcnow().isoformat()
                }
            }
            
            if amount:
                refund_data['amount'] = int(amount * 100)  # Convert to cents
            
            refund = self.stripe.Refund.create(**refund_data)
            
            # Store refund in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT INTO refunds (user_id, stripe_refund_id, payment_intent_id, amount, currency, reason, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (user_id, refund.id, payment_intent_id, refund.amount / 100, refund.currency, reason, refund.status, datetime.utcnow().isoformat())
                )
            
            logger.info(f"Created refund {refund.id} for payment {payment_intent_id}")
            
            return {
                'refund_id': refund.id,
                'payment_intent_id': payment_intent_id,
                'user_id': user_id,
                'amount': refund.amount / 100,  # Convert from cents
                'currency': refund.currency,
                'reason': refund.reason,
                'status': refund.status,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error creating refund: {e}")
            raise
        except Exception as e:
            logger.error(f"Error creating refund: {e}")
            raise
    
    def get_refund(self, refund_id: str) -> Optional[Dict[str, Any]]:
        """Get refund details"""
        try:
            refund = self.stripe.Refund.retrieve(refund_id)
            
            return {
                'refund_id': refund.id,
                'payment_intent_id': refund.payment_intent,
                'amount': refund.amount / 100,  # Convert from cents
                'currency': refund.currency,
                'reason': refund.reason,
                'status': refund.status,
                'created': datetime.fromtimestamp(refund.created).isoformat(),
                'stripe_data': refund
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting refund {refund_id}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error getting refund {refund_id}: {e}")
            return None
    
    def list_refunds(self, user_id: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        """List refunds with optional filtering"""
        try:
            refunds = self.stripe.Refund.list(limit=limit)
            
            refund_list = []
            for refund in refunds.data:
                # Get user ID from payment intent
                payment_intent = self.stripe.PaymentIntent.retrieve(refund.payment_intent)
                customers = self.db_manager.execute_query(
                    "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                    (payment_intent.customer,)
                )
                
                refund_user_id = customers[0]['user_id'] if customers else None
                
                # Filter by user if specified
                if user_id and refund_user_id != user_id:
                    continue
                
                refund_list.append({
                    'refund_id': refund.id,
                    'user_id': refund_user_id,
                    'payment_intent_id': refund.payment_intent,
                    'amount': refund.amount / 100,  # Convert from cents
                    'currency': refund.currency,
                    'reason': refund.reason,
                    'status': refund.status,
                    'created': datetime.fromtimestamp(refund.created).isoformat()
                })
            
            return refund_list
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error listing refunds: {e}")
            return []
        except Exception as e:
            logger.error(f"Error listing refunds: {e}")
            return []
    
    def handle_chargeback(self, chargeback_id: str) -> Dict[str, Any]:
        """Handle a chargeback/dispute"""
        try:
            # Get dispute
            dispute = self.stripe.Dispute.retrieve(chargeback_id)
            
            # Get payment intent
            payment_intent = self.stripe.PaymentIntent.retrieve(dispute.payment_intent)
            
            # Get customer info
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (payment_intent.customer,)
            )
            
            user_id = customers[0]['user_id'] if customers else None
            
            # Store chargeback in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "INSERT INTO chargebacks (user_id, stripe_dispute_id, payment_intent_id, amount, currency, reason, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (user_id, dispute.id, dispute.payment_intent, dispute.amount / 100, dispute.currency, dispute.reason, dispute.status, datetime.utcnow().isoformat())
                )
            
            logger.warning(f"Chargeback {chargeback_id} received for payment {dispute.payment_intent}")
            
            return {
                'chargeback_id': dispute.id,
                'user_id': user_id,
                'payment_intent_id': dispute.payment_intent,
                'amount': dispute.amount / 100,  # Convert from cents
                'currency': dispute.currency,
                'reason': dispute.reason,
                'status': dispute.status,
                'created_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error handling chargeback: {e}")
            raise
        except Exception as e:
            logger.error(f"Error handling chargeback: {e}")
            raise
    
    def respond_to_chargeback(self, chargeback_id: str, evidence: Dict[str, Any]) -> Dict[str, Any]:
        """Respond to a chargeback with evidence"""
        try:
            # Update dispute with evidence
            dispute = self.stripe.Dispute.modify(
                chargeback_id,
                evidence=evidence
            )
            
            # Update chargeback status in database
            if self.db_manager:
                self.db_manager.execute_query(
                    "UPDATE chargebacks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE stripe_dispute_id = ?",
                    (dispute.status, chargeback_id)
                )
            
            logger.info(f"Responded to chargeback {chargeback_id} with evidence")
            
            return {
                'chargeback_id': dispute.id,
                'status': dispute.status,
                'updated_at': datetime.utcnow().isoformat()
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error responding to chargeback: {e}")
            raise
        except Exception as e:
            logger.error(f"Error responding to chargeback: {e}")
            raise
    
    def get_chargeback(self, chargeback_id: str) -> Optional[Dict[str, Any]]:
        """Get chargeback details"""
        try:
            dispute = self.stripe.Dispute.retrieve(chargeback_id)
            
            return {
                'chargeback_id': dispute.id,
                'payment_intent_id': dispute.payment_intent,
                'amount': dispute.amount / 100,  # Convert from cents
                'currency': dispute.currency,
                'reason': dispute.reason,
                'status': dispute.status,
                'created': datetime.fromtimestamp(dispute.created).isoformat(),
                'evidence': dispute.evidence,
                'stripe_data': dispute
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error getting chargeback {chargeback_id}: {e}")
            return None
        except Exception as e:
            logger.error(f"Error getting chargeback {chargeback_id}: {e}")
            return None
    
    def list_chargebacks(self, user_id: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        """List chargebacks with optional filtering"""
        try:
            disputes = self.stripe.Dispute.list(limit=limit)
            
            chargeback_list = []
            for dispute in disputes.data:
                # Get user ID from payment intent
                payment_intent = self.stripe.PaymentIntent.retrieve(dispute.payment_intent)
                customers = self.db_manager.execute_query(
                    "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                    (payment_intent.customer,)
                )
                
                chargeback_user_id = customers[0]['user_id'] if customers else None
                
                # Filter by user if specified
                if user_id and chargeback_user_id != user_id:
                    continue
                
                chargeback_list.append({
                    'chargeback_id': dispute.id,
                    'user_id': chargeback_user_id,
                    'payment_intent_id': dispute.payment_intent,
                    'amount': dispute.amount / 100,  # Convert from cents
                    'currency': dispute.currency,
                    'reason': dispute.reason,
                    'status': dispute.status,
                    'created': datetime.fromtimestamp(dispute.created).isoformat()
                })
            
            return chargeback_list
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error listing chargebacks: {e}")
            return []
        except Exception as e:
            logger.error(f"Error listing chargebacks: {e}")
            return []
    
    def calculate_refund_amount(self, payment_intent_id: str, 
                              refund_type: str = 'full') -> Dict[str, Any]:
        """Calculate refund amount based on type"""
        try:
            payment_intent = self.stripe.PaymentIntent.retrieve(payment_intent_id)
            
            total_amount = payment_intent.amount / 100  # Convert from cents
            currency = payment_intent.currency
            
            # Get existing refunds
            refunds = self.stripe.Refund.list(payment_intent=payment_intent_id)
            refunded_amount = sum(refund.amount for refund in refunds.data if refund.status == 'succeeded')
            refunded_amount = refunded_amount / 100  # Convert from cents
            
            available_amount = total_amount - refunded_amount
            
            if refund_type == 'full':
                refund_amount = available_amount
            elif refund_type == 'partial':
                # This would be set by the caller
                refund_amount = available_amount
            else:
                raise ValueError(f"Invalid refund type: {refund_type}")
            
            return {
                'total_amount': total_amount,
                'refunded_amount': refunded_amount,
                'available_amount': available_amount,
                'refund_amount': refund_amount,
                'currency': currency
            }
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error calculating refund amount: {e}")
            raise
        except Exception as e:
            logger.error(f"Error calculating refund amount: {e}")
            raise
    
    def get_refund_statistics(self, user_id: str = None, 
                            start_date: datetime = None, 
                            end_date: datetime = None) -> Dict[str, Any]:
        """Get refund statistics"""
        try:
            refunds = self.list_refunds(user_id, limit=1000)
            
            if start_date:
                refunds = [r for r in refunds if datetime.fromisoformat(r['created']) >= start_date]
            if end_date:
                refunds = [r for r in refunds if datetime.fromisoformat(r['created']) <= end_date]
            
            total_refunds = len(refunds)
            total_amount = sum(r['amount'] for r in refunds)
            successful_refunds = len([r for r in refunds if r['status'] == 'succeeded'])
            failed_refunds = len([r for r in refunds if r['status'] == 'failed'])
            
            # Group by reason
            reasons = {}
            for refund in refunds:
                reason = refund['reason']
                if reason not in reasons:
                    reasons[reason] = {'count': 0, 'amount': 0}
                reasons[reason]['count'] += 1
                reasons[reason]['amount'] += refund['amount']
            
            return {
                'total_refunds': total_refunds,
                'total_amount': total_amount,
                'successful_refunds': successful_refunds,
                'failed_refunds': failed_refunds,
                'success_rate': (successful_refunds / total_refunds * 100) if total_refunds > 0 else 0,
                'reasons': reasons,
                'period': {
                    'start_date': start_date.isoformat() if start_date else None,
                    'end_date': end_date.isoformat() if end_date else None
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting refund statistics: {e}")
            return {
                'total_refunds': 0,
                'total_amount': 0,
                'successful_refunds': 0,
                'failed_refunds': 0,
                'success_rate': 0,
                'reasons': {},
                'period': {
                    'start_date': start_date.isoformat() if start_date else None,
                    'end_date': end_date.isoformat() if end_date else None
                }
            } 