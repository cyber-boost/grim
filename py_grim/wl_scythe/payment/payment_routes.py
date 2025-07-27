"""
Payment API routes for Stripe integration
"""

from flask import Blueprint, request, jsonify, g
from ..api.middleware.auth import require_auth, require_permission
from ..api.middleware.rate_limit import rate_limit
from ..api.middleware.error_handler import *
from ..api.utils.database import DatabaseManager
from ..api.utils.logger import log_payment_operation
from .billing_manager import BillingManager
from .stripe_connect import StripeConnectManager
from .webhook_handler import StripeWebhookHandler
from .refund_manager import RefundManager
from .multi_currency import MultiCurrencyManager
import logging
from datetime import datetime

logger = logging.getLogger(__name__)
payment_bp = Blueprint('payment', __name__)

# Initialize managers
db_manager = DatabaseManager()
billing_manager = BillingManager(
    stripe_secret_key="sk_test_...",  # Set from environment
    stripe_connect_client_id="ca_..."  # Set from environment
)
connect_manager = StripeConnectManager(
    stripe_secret_key="sk_test_...",  # Set from environment
    connect_client_id="ca_..."  # Set from environment
)
webhook_handler = StripeWebhookHandler(
    stripe_secret_key="sk_test_...",  # Set from environment
    webhook_secret="whsec_..."  # Set from environment
)
refund_manager = RefundManager("sk_test_...")  # Set from environment
currency_manager = MultiCurrencyManager("sk_test_...")  # Set from environment

# Set database managers
billing_manager.set_db_manager(db_manager)
connect_manager.set_db_manager(db_manager)
webhook_handler.set_managers(db_manager, billing_manager, connect_manager)
refund_manager.set_db_manager(db_manager)

# Subscription endpoints
@payment_bp.route('/subscriptions', methods=['POST'])
@require_auth
@rate_limit(10, 3600)
def create_subscription():
    """Create a new subscription"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['tier', 'billing_cycle']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        subscription = billing_manager.create_subscription(
            user_id=g.user_id,
            tier=data['tier'],
            billing_cycle=data['billing_cycle'],
            payment_method_id=data.get('payment_method_id')
        )
        
        log_payment_operation(logger, 'create_subscription', g.user_id, subscription['amount'], subscription['currency'], 'success')
        
        return jsonify({
            'message': 'Subscription created successfully',
            'subscription': subscription,
            'timestamp': datetime.utcnow().isoformat()
        }), 201
        
    except Exception as e:
        log_request_error(e, 'create_subscription')
        return handle_payment_error(e)

@payment_bp.route('/subscriptions/<subscription_id>', methods=['DELETE'])
@require_auth
@rate_limit(5, 3600)
def cancel_subscription(subscription_id):
    """Cancel a subscription"""
    try:
        result = billing_manager.cancel_subscription(g.user_id, subscription_id)
        
        log_payment_operation(logger, 'cancel_subscription', g.user_id, 0, 'usd', 'success')
        
        return jsonify({
            'message': 'Subscription cancelled successfully',
            'result': result,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'cancel_subscription')
        return handle_payment_error(e)

@payment_bp.route('/subscriptions/status', methods=['GET'])
@require_auth
@rate_limit(50, 3600)
def get_subscription_status():
    """Get subscription status"""
    try:
        status = billing_manager.get_subscription_status(g.user_id)
        
        return jsonify({
            'status': status,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_subscription_status')
        return handle_payment_error(e)

# Vendor Connect endpoints
@payment_bp.route('/vendor/connect-account', methods=['POST'])
@require_auth
@require_permission('vendor:write')
@rate_limit(5, 3600)
def create_connect_account():
    """Create Stripe Connect account for vendor"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['vendor_id', 'email', 'name']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        account = connect_manager.create_connect_account(
            vendor_id=data['vendor_id'],
            vendor_email=data['email'],
            vendor_name=data['name']
        )
        
        return jsonify({
            'message': 'Connect account created successfully',
            'account': account,
            'timestamp': datetime.utcnow().isoformat()
        }), 201
        
    except Exception as e:
        log_request_error(e, 'create_connect_account')
        return handle_payment_error(e)

@payment_bp.route('/vendor/<int:vendor_id>/login-link', methods=['GET'])
@require_auth
@require_permission('vendor:read')
@rate_limit(20, 3600)
def get_vendor_login_link(vendor_id):
    """Get login link for vendor Connect dashboard"""
    try:
        login_url = connect_manager.create_connect_login_link(vendor_id)
        
        if not login_url:
            return not_found("Connect account not found")
        
        return jsonify({
            'login_url': login_url,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_vendor_login_link')
        return handle_payment_error(e)

@payment_bp.route('/vendor/<int:vendor_id>/payout', methods=['POST'])
@require_auth
@require_permission('vendor:write')
@rate_limit(10, 3600)
def process_vendor_payout(vendor_id):
    """Process payout to vendor"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        if 'amount' not in data:
            return bad_request("amount is required")
        
        payout = connect_manager.process_vendor_payout(
            vendor_id=vendor_id,
            amount=data['amount'],
            currency=data.get('currency', 'usd')
        )
        
        log_payment_operation(logger, 'vendor_payout', g.user_id, data['amount'], data.get('currency', 'usd'), 'success')
        
        return jsonify({
            'message': 'Payout processed successfully',
            'payout': payout,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'process_vendor_payout')
        return handle_payment_error(e)

# Refund endpoints
@payment_bp.route('/refunds', methods=['POST'])
@require_auth
@require_permission('payment:write')
@rate_limit(10, 3600)
def create_refund():
    """Create a refund"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        if 'payment_intent_id' not in data:
            return bad_request("payment_intent_id is required")
        
        refund = refund_manager.create_refund(
            payment_intent_id=data['payment_intent_id'],
            amount=data.get('amount'),
            reason=data.get('reason', 'requested_by_customer')
        )
        
        log_payment_operation(logger, 'create_refund', g.user_id, refund['amount'], refund['currency'], 'success')
        
        return jsonify({
            'message': 'Refund created successfully',
            'refund': refund,
            'timestamp': datetime.utcnow().isoformat()
        }), 201
        
    except Exception as e:
        log_request_error(e, 'create_refund')
        return handle_payment_error(e)

@payment_bp.route('/refunds/<refund_id>', methods=['GET'])
@require_auth
@require_permission('payment:read')
@rate_limit(50, 3600)
def get_refund(refund_id):
    """Get refund details"""
    try:
        refund = refund_manager.get_refund(refund_id)
        
        if not refund:
            return not_found("Refund not found")
        
        return jsonify({
            'refund': refund,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_refund')
        return handle_payment_error(e)

# Currency endpoints
@payment_bp.route('/currencies', methods=['GET'])
@require_auth
@rate_limit(100, 3600)
def get_supported_currencies():
    """Get supported currencies"""
    try:
        currencies = currency_manager.get_supported_currencies()
        
        return jsonify({
            'currencies': currencies,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_supported_currencies')
        return handle_payment_error(e)

@payment_bp.route('/currencies/convert', methods=['POST'])
@require_auth
@rate_limit(50, 3600)
def convert_currency():
    """Convert between currencies"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['amount', 'from_currency', 'to_currency']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        converted_amount = currency_manager.convert_currency(
            amount=data['amount'],
            from_currency=data['from_currency'],
            to_currency=data['to_currency']
        )
        
        return jsonify({
            'original_amount': data['amount'],
            'original_currency': data['from_currency'],
            'converted_amount': converted_amount,
            'target_currency': data['to_currency'],
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'convert_currency')
        return handle_payment_error(e)

# Webhook endpoint
@payment_bp.route('/webhook', methods=['POST'])
def handle_stripe_webhook():
    """Handle Stripe webhooks"""
    try:
        payload = request.get_data()
        signature = request.headers.get('Stripe-Signature')
        
        if not signature:
            return bad_request("Missing Stripe signature")
        
        result = webhook_handler.handle_webhook(payload, signature)
        
        return jsonify(result), 200
        
    except Exception as e:
        log_request_error(e, 'handle_stripe_webhook')
        return handle_webhook_error(e) 