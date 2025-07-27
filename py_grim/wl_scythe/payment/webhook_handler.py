"""
Webhook handler for Stripe payment events
"""

import stripe
import logging
from datetime import datetime
from typing import Dict, Any, Optional
import json

logger = logging.getLogger(__name__)

class StripeWebhookHandler:
    """Handles Stripe webhook events"""
    
    def __init__(self, stripe_secret_key: str, webhook_secret: str):
        self.stripe = stripe
        self.stripe.api_key = stripe_secret_key
        self.webhook_secret = webhook_secret
        self.db_manager = None
        self.billing_manager = None
        self.connect_manager = None
    
    def set_managers(self, db_manager, billing_manager, connect_manager):
        """Set managers for database and billing operations"""
        self.db_manager = db_manager
        self.billing_manager = billing_manager
        self.connect_manager = connect_manager
    
    def handle_webhook(self, payload: str, signature: str) -> Dict[str, Any]:
        """Handle incoming webhook"""
        try:
            # Verify webhook signature
            event = self.stripe.Webhook.construct_event(
                payload, signature, self.webhook_secret
            )
            
            logger.info(f"Received webhook event: {event.type}")
            
            # Handle different event types
            if event.type == 'invoice.payment_succeeded':
                return self.handle_invoice_payment_succeeded(event.data.object)
            elif event.type == 'invoice.payment_failed':
                return self.handle_invoice_payment_failed(event.data.object)
            elif event.type == 'customer.subscription.created':
                return self.handle_subscription_created(event.data.object)
            elif event.type == 'customer.subscription.updated':
                return self.handle_subscription_updated(event.data.object)
            elif event.type == 'customer.subscription.deleted':
                return self.handle_subscription_deleted(event.data.object)
            elif event.type == 'payment_intent.succeeded':
                return self.handle_payment_intent_succeeded(event.data.object)
            elif event.type == 'payment_intent.payment_failed':
                return self.handle_payment_intent_failed(event.data.object)
            elif event.type == 'transfer.created':
                return self.handle_transfer_created(event.data.object)
            elif event.type == 'transfer.failed':
                return self.handle_transfer_failed(event.data.object)
            elif event.type == 'payout.paid':
                return self.handle_payout_paid(event.data.object)
            elif event.type == 'payout.failed':
                return self.handle_payout_failed(event.data.object)
            else:
                logger.info(f"Unhandled event type: {event.type}")
                return {'status': 'ignored', 'event_type': event.type}
                
        except ValueError as e:
            logger.error(f"Invalid payload: {e}")
            raise
        except stripe.error.SignatureVerificationError as e:
            logger.error(f"Invalid signature: {e}")
            raise
        except Exception as e:
            logger.error(f"Error handling webhook: {e}")
            raise
    
    def handle_invoice_payment_succeeded(self, invoice: Dict[str, Any]) -> Dict[str, Any]:
        """Handle successful invoice payment"""
        try:
            customer_id = invoice.customer
            invoice_id = invoice.id
            amount = invoice.amount_paid / 100  # Convert from cents
            currency = invoice.currency
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            # Update invoice status in database
            self.db_manager.execute_query(
                "UPDATE invoices SET status = 'paid', paid_at = CURRENT_TIMESTAMP WHERE stripe_invoice_id = ?",
                (invoice_id,)
            )
            
            # Log payment
            logger.info(f"Invoice {invoice_id} paid successfully for user {user_id}")
            
            # Send webhook notification
            if hasattr(self, 'webhook_manager'):
                self.webhook_manager.send_payment_webhook(
                    'invoice_paid', user_id, amount, currency, 'success'
                )
            
            return {
                'status': 'success',
                'event_type': 'invoice.payment_succeeded',
                'user_id': user_id,
                'invoice_id': invoice_id,
                'amount': amount,
                'currency': currency
            }
            
        except Exception as e:
            logger.error(f"Error handling invoice payment succeeded: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_invoice_payment_failed(self, invoice: Dict[str, Any]) -> Dict[str, Any]:
        """Handle failed invoice payment"""
        try:
            customer_id = invoice.customer
            invoice_id = invoice.id
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            # Update invoice status in database
            self.db_manager.execute_query(
                "UPDATE invoices SET status = 'failed', updated_at = CURRENT_TIMESTAMP WHERE stripe_invoice_id = ?",
                (invoice_id,)
            )
            
            # Update subscription status if this is a subscription invoice
            if invoice.subscription:
                self.db_manager.execute_query(
                    "UPDATE subscriptions SET status = 'past_due', updated_at = CURRENT_TIMESTAMP WHERE stripe_subscription_id = ?",
                    (invoice.subscription,)
                )
            
            logger.warning(f"Invoice {invoice_id} payment failed for user {user_id}")
            
            # Send webhook notification
            if hasattr(self, 'webhook_manager'):
                self.webhook_manager.send_payment_webhook(
                    'invoice_failed', user_id, 0, invoice.currency, 'failed'
                )
            
            return {
                'status': 'success',
                'event_type': 'invoice.payment_failed',
                'user_id': user_id,
                'invoice_id': invoice_id
            }
            
        except Exception as e:
            logger.error(f"Error handling invoice payment failed: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_subscription_created(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription creation"""
        try:
            subscription_id = subscription.id
            customer_id = subscription.customer
            status = subscription.status
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            # Update subscription status in database
            self.db_manager.execute_query(
                "UPDATE subscriptions SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE stripe_subscription_id = ?",
                (status, subscription_id)
            )
            
            logger.info(f"Subscription {subscription_id} created for user {user_id}")
            
            return {
                'status': 'success',
                'event_type': 'customer.subscription.created',
                'user_id': user_id,
                'subscription_id': subscription_id,
                'status': status
            }
            
        except Exception as e:
            logger.error(f"Error handling subscription created: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_subscription_updated(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription updates"""
        try:
            subscription_id = subscription.id
            customer_id = subscription.customer
            status = subscription.status
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            # Update subscription status in database
            self.db_manager.execute_query(
                "UPDATE subscriptions SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE stripe_subscription_id = ?",
                (status, subscription_id)
            )
            
            logger.info(f"Subscription {subscription_id} updated for user {user_id} to status {status}")
            
            return {
                'status': 'success',
                'event_type': 'customer.subscription.updated',
                'user_id': user_id,
                'subscription_id': subscription_id,
                'status': status
            }
            
        except Exception as e:
            logger.error(f"Error handling subscription updated: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_subscription_deleted(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription deletion"""
        try:
            subscription_id = subscription.id
            customer_id = subscription.customer
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            # Update subscription status in database
            self.db_manager.execute_query(
                "UPDATE subscriptions SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE stripe_subscription_id = ?",
                (subscription_id,)
            )
            
            logger.info(f"Subscription {subscription_id} cancelled for user {user_id}")
            
            return {
                'status': 'success',
                'event_type': 'customer.subscription.deleted',
                'user_id': user_id,
                'subscription_id': subscription_id
            }
            
        except Exception as e:
            logger.error(f"Error handling subscription deleted: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_payment_intent_succeeded(self, payment_intent: Dict[str, Any]) -> Dict[str, Any]:
        """Handle successful payment intent"""
        try:
            payment_intent_id = payment_intent.id
            customer_id = payment_intent.customer
            amount = payment_intent.amount / 100  # Convert from cents
            currency = payment_intent.currency
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            # Check if this is a vendor payment
            if payment_intent.metadata and 'vendor_id' in payment_intent.metadata:
                vendor_id = int(payment_intent.metadata['vendor_id'])
                commission_rate = float(payment_intent.metadata.get('commission_rate', 0))
                
                # Create split payment
                if self.connect_manager:
                    self.connect_manager.create_split_payment(
                        payment_intent_id, vendor_id, commission_rate
                    )
            
            logger.info(f"Payment intent {payment_intent_id} succeeded for user {user_id}")
            
            return {
                'status': 'success',
                'event_type': 'payment_intent.succeeded',
                'user_id': user_id,
                'payment_intent_id': payment_intent_id,
                'amount': amount,
                'currency': currency
            }
            
        except Exception as e:
            logger.error(f"Error handling payment intent succeeded: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_payment_intent_failed(self, payment_intent: Dict[str, Any]) -> Dict[str, Any]:
        """Handle failed payment intent"""
        try:
            payment_intent_id = payment_intent.id
            customer_id = payment_intent.customer
            
            # Get user ID from customer
            customers = self.db_manager.execute_query(
                "SELECT user_id FROM stripe_customers WHERE stripe_customer_id = ?",
                (customer_id,)
            )
            
            if not customers:
                logger.warning(f"No customer found for Stripe customer ID: {customer_id}")
                return {'status': 'error', 'message': 'Customer not found'}
            
            user_id = customers[0]['user_id']
            
            logger.warning(f"Payment intent {payment_intent_id} failed for user {user_id}")
            
            return {
                'status': 'success',
                'event_type': 'payment_intent.payment_failed',
                'user_id': user_id,
                'payment_intent_id': payment_intent_id
            }
            
        except Exception as e:
            logger.error(f"Error handling payment intent failed: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_transfer_created(self, transfer: Dict[str, Any]) -> Dict[str, Any]:
        """Handle transfer creation"""
        try:
            transfer_id = transfer.id
            destination = transfer.destination
            amount = transfer.amount / 100  # Convert from cents
            currency = transfer.currency
            
            # Get vendor ID from destination account
            vendors = self.db_manager.execute_query(
                "SELECT id FROM vendors WHERE stripe_connect_account_id = ?",
                (destination,)
            )
            
            if not vendors:
                logger.warning(f"No vendor found for Connect account: {destination}")
                return {'status': 'error', 'message': 'Vendor not found'}
            
            vendor_id = vendors[0]['id']
            
            # Update transfer status in database
            self.db_manager.execute_query(
                "UPDATE vendor_transfers SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE stripe_transfer_id = ?",
                (transfer.status, transfer_id)
            )
            
            logger.info(f"Transfer {transfer_id} created for vendor {vendor_id}")
            
            return {
                'status': 'success',
                'event_type': 'transfer.created',
                'vendor_id': vendor_id,
                'transfer_id': transfer_id,
                'amount': amount,
                'currency': currency
            }
            
        except Exception as e:
            logger.error(f"Error handling transfer created: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_transfer_failed(self, transfer: Dict[str, Any]) -> Dict[str, Any]:
        """Handle transfer failure"""
        try:
            transfer_id = transfer.id
            destination = transfer.destination
            
            # Get vendor ID from destination account
            vendors = self.db_manager.execute_query(
                "SELECT id FROM vendors WHERE stripe_connect_account_id = ?",
                (destination,)
            )
            
            if not vendors:
                logger.warning(f"No vendor found for Connect account: {destination}")
                return {'status': 'error', 'message': 'Vendor not found'}
            
            vendor_id = vendors[0]['id']
            
            # Update transfer status in database
            self.db_manager.execute_query(
                "UPDATE vendor_transfers SET status = 'failed', updated_at = CURRENT_TIMESTAMP WHERE stripe_transfer_id = ?",
                (transfer_id,)
            )
            
            logger.warning(f"Transfer {transfer_id} failed for vendor {vendor_id}")
            
            return {
                'status': 'success',
                'event_type': 'transfer.failed',
                'vendor_id': vendor_id,
                'transfer_id': transfer_id
            }
            
        except Exception as e:
            logger.error(f"Error handling transfer failed: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_payout_paid(self, payout: Dict[str, Any]) -> Dict[str, Any]:
        """Handle successful payout"""
        try:
            payout_id = payout.id
            stripe_account = payout.stripe_account
            amount = payout.amount / 100  # Convert from cents
            currency = payout.currency
            
            # Get vendor ID from Connect account
            vendors = self.db_manager.execute_query(
                "SELECT id FROM vendors WHERE stripe_connect_account_id = ?",
                (stripe_account,)
            )
            
            if not vendors:
                logger.warning(f"No vendor found for Connect account: {stripe_account}")
                return {'status': 'error', 'message': 'Vendor not found'}
            
            vendor_id = vendors[0]['id']
            
            # Update payout status in database
            self.db_manager.execute_query(
                "UPDATE vendor_payouts SET status = 'paid', paid_at = CURRENT_TIMESTAMP WHERE stripe_payout_id = ?",
                (payout_id,)
            )
            
            logger.info(f"Payout {payout_id} paid for vendor {vendor_id}")
            
            return {
                'status': 'success',
                'event_type': 'payout.paid',
                'vendor_id': vendor_id,
                'payout_id': payout_id,
                'amount': amount,
                'currency': currency
            }
            
        except Exception as e:
            logger.error(f"Error handling payout paid: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def handle_payout_failed(self, payout: Dict[str, Any]) -> Dict[str, Any]:
        """Handle failed payout"""
        try:
            payout_id = payout.id
            stripe_account = payout.stripe_account
            
            # Get vendor ID from Connect account
            vendors = self.db_manager.execute_query(
                "SELECT id FROM vendors WHERE stripe_connect_account_id = ?",
                (stripe_account,)
            )
            
            if not vendors:
                logger.warning(f"No vendor found for Connect account: {stripe_account}")
                return {'status': 'error', 'message': 'Vendor not found'}
            
            vendor_id = vendors[0]['id']
            
            # Update payout status in database
            self.db_manager.execute_query(
                "UPDATE vendor_payouts SET status = 'failed', updated_at = CURRENT_TIMESTAMP WHERE stripe_payout_id = ?",
                (payout_id,)
            )
            
            logger.warning(f"Payout {payout_id} failed for vendor {vendor_id}")
            
            return {
                'status': 'success',
                'event_type': 'payout.failed',
                'vendor_id': vendor_id,
                'payout_id': payout_id
            }
            
        except Exception as e:
            logger.error(f"Error handling payout failed: {e}")
            return {'status': 'error', 'message': str(e)} 