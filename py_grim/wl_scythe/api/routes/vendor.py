"""
Vendor management routes for Scythe API
"""

from flask import Blueprint, request, jsonify, g
from ..middleware.auth import require_auth, require_permission
from ..middleware.rate_limit import rate_limit
from ..middleware.error_handler import *
from ..utils.database import DatabaseManager
from ..utils.logger import log_payment_operation
import secrets
import hashlib
import json
import logging
from datetime import datetime
from typing import Dict, Any, List

logger = logging.getLogger(__name__)
vendor_bp = Blueprint('vendor', __name__)
db_manager = DatabaseManager()

def generate_api_key() -> str:
    """Generate a unique API key for vendor"""
    return f"sk_{secrets.token_hex(32)}"

def hash_api_key(api_key: str) -> str:
    """Hash API key for storage"""
    return hashlib.sha256(api_key.encode()).hexdigest()

@vendor_bp.route('/', methods=['GET'])
@require_auth
@require_permission('vendor:read')
@rate_limit(100, 3600)  # 100 requests per hour
def get_vendors():
    """Get all vendors"""
    try:
        vendors = db_manager.get_vendors()
        
        # Mask API keys for security
        for vendor in vendors:
            if vendor['api_key']:
                vendor['api_key'] = vendor['api_key'][:8] + '...'
        
        return jsonify({
            'vendors': vendors,
            'count': len(vendors),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        log_request_error(e, 'get_vendors')
        return handle_database_error(e)

@vendor_bp.route('/', methods=['POST'])
@require_auth
@require_permission('vendor:write')
@rate_limit(20, 3600)  # 20 requests per hour
def create_vendor():
    """Create a new vendor"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['name', 'email']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Validate email format (basic validation)
        if '@' not in data['email'] or '.' not in data['email']:
            return bad_request("Invalid email format")
        
        # Check if email already exists
        existing_vendors = db_manager.execute_query(
            "SELECT id FROM vendors WHERE email = ?",
            (data['email'],)
        )
        if existing_vendors:
            return conflict("Vendor with this email already exists")
        
        # Generate API key
        api_key = generate_api_key()
        api_key_hash = hash_api_key(api_key)
        
        # Create vendor
        vendor_id = db_manager.create_vendor(
            name=data['name'],
            email=data['email'],
            commission_rate=data.get('commission_rate', 0.0)
        )
        
        # Update vendor with API key
        db_manager.execute_query(
            "UPDATE vendors SET api_key = ? WHERE id = ?",
            (api_key_hash, vendor_id)
        )
        
        # Get created vendor
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        
        if vendors:
            vendor = vendors[0]
            
            # Return API key only in creation response
            vendor_response = dict(vendor)
            vendor_response['api_key'] = api_key  # Return the actual key
            
            log_payment_operation(
                logger, 'create_vendor', g.user_id,
                0.0, 'USD', 'success'
            )
            
            return jsonify({
                'message': 'Vendor created successfully',
                'vendor': vendor_response,
                'timestamp': datetime.utcnow().isoformat()
            }), 201
        
        return internal_server_error("Failed to retrieve created vendor")
        
    except Exception as e:
        log_request_error(e, 'create_vendor')
        return handle_database_error(e)

@vendor_bp.route('/<int:vendor_id>', methods=['GET'])
@require_auth
@require_permission('vendor:read')
@rate_limit(100, 3600)  # 100 requests per hour
def get_vendor(vendor_id):
    """Get vendor details"""
    try:
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        
        if not vendors:
            return not_found("Vendor not found")
        
        vendor = vendors[0]
        
        # Mask API key for security
        if vendor['api_key']:
            vendor['api_key'] = vendor['api_key'][:8] + '...'
        
        # Get vendor's products
        products = db_manager.get_products(vendor_id)
        
        return jsonify({
            'vendor': vendor,
            'products': products,
            'product_count': len(products),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_vendor')
        return handle_database_error(e)

@vendor_bp.route('/<int:vendor_id>', methods=['PUT'])
@require_auth
@require_permission('vendor:write')
@rate_limit(50, 3600)  # 50 requests per hour
def update_vendor(vendor_id):
    """Update vendor"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        # Check if vendor exists
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        if not vendors:
            return not_found("Vendor not found")
        
        vendor = vendors[0]
        
        # Update fields
        update_fields = []
        update_values = []
        
        if 'name' in data:
            update_fields.append('name = ?')
            update_values.append(data['name'])
        
        if 'email' in data:
            # Validate email format
            if '@' not in data['email'] or '.' not in data['email']:
                return bad_request("Invalid email format")
            
            # Check if email already exists for other vendors
            existing_vendors = db_manager.execute_query(
                "SELECT id FROM vendors WHERE email = ? AND id != ?",
                (data['email'], vendor_id)
            )
            if existing_vendors:
                return conflict("Vendor with this email already exists")
            
            update_fields.append('email = ?')
            update_values.append(data['email'])
        
        if 'commission_rate' in data:
            if not isinstance(data['commission_rate'], (int, float)) or data['commission_rate'] < 0:
                return bad_request("Commission rate must be a non-negative number")
            update_fields.append('commission_rate = ?')
            update_values.append(data['commission_rate'])
        
        if 'status' in data:
            valid_statuses = ['active', 'suspended', 'inactive']
            if data['status'] not in valid_statuses:
                return bad_request(f"Invalid status. Must be one of: {valid_statuses}")
            update_fields.append('status = ?')
            update_values.append(data['status'])
        
        if not update_fields:
            return bad_request("No valid fields to update")
        
        update_fields.append('updated_at = CURRENT_TIMESTAMP')
        update_values.append(vendor_id)
        
        # Execute update
        query = f"UPDATE vendors SET {', '.join(update_fields)} WHERE id = ?"
        db_manager.execute_query(query, tuple(update_values))
        
        # Get updated vendor
        updated_vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        
        if updated_vendors:
            updated_vendor = updated_vendors[0]
            
            # Mask API key for security
            if updated_vendor['api_key']:
                updated_vendor['api_key'] = updated_vendor['api_key'][:8] + '...'
            
            log_payment_operation(
                logger, 'update_vendor', g.user_id,
                0.0, 'USD', 'success'
            )
            
            return jsonify({
                'message': 'Vendor updated successfully',
                'vendor': updated_vendor,
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        return internal_server_error("Failed to retrieve updated vendor")
        
    except Exception as e:
        log_request_error(e, 'update_vendor')
        return handle_database_error(e)

@vendor_bp.route('/<int:vendor_id>', methods=['DELETE'])
@require_auth
@require_permission('vendor:write')
@rate_limit(10, 3600)  # 10 requests per hour
def delete_vendor(vendor_id):
    """Delete vendor"""
    try:
        # Check if vendor exists
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        if not vendors:
            return not_found("Vendor not found")
        
        vendor = vendors[0]
        
        # Check if vendor has active products
        products = db_manager.get_products(vendor_id)
        active_products = [p for p in products if p['status'] == 'active']
        
        if active_products:
            return conflict("Cannot delete vendor with active products")
        
        # Soft delete by setting status to inactive
        db_manager.execute_query(
            "UPDATE vendors SET status = 'inactive', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (vendor_id,)
        )
        
        log_payment_operation(
            logger, 'delete_vendor', g.user_id,
            0.0, 'USD', 'success'
        )
        
        return jsonify({
            'message': 'Vendor deleted successfully',
            'vendor_id': vendor_id,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'delete_vendor')
        return handle_database_error(e)

@vendor_bp.route('/<int:vendor_id>/regenerate-api-key', methods=['POST'])
@require_auth
@require_permission('vendor:write')
@rate_limit(5, 3600)  # 5 requests per hour
def regenerate_api_key(vendor_id):
    """Regenerate vendor API key"""
    try:
        # Check if vendor exists
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        if not vendors:
            return not_found("Vendor not found")
        
        vendor = vendors[0]
        
        # Generate new API key
        api_key = generate_api_key()
        api_key_hash = hash_api_key(api_key)
        
        # Update vendor with new API key
        db_manager.execute_query(
            "UPDATE vendors SET api_key = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (api_key_hash, vendor_id)
        )
        
        log_payment_operation(
            logger, 'regenerate_api_key', g.user_id,
            0.0, 'USD', 'success'
        )
        
        return jsonify({
            'message': 'API key regenerated successfully',
            'vendor_id': vendor_id,
            'api_key': api_key,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'regenerate_api_key')
        return handle_database_error(e)

@vendor_bp.route('/<int:vendor_id>/commission', methods=['GET'])
@require_auth
@require_permission('vendor:read')
@rate_limit(50, 3600)  # 50 requests per hour
def get_vendor_commission(vendor_id):
    """Get vendor commission information"""
    try:
        # Check if vendor exists
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        if not vendors:
            return not_found("Vendor not found")
        
        vendor = vendors[0]
        
        # Get vendor's products and calculate total value
        products = db_manager.get_products(vendor_id)
        total_product_value = sum(p['price'] for p in products if p['status'] == 'active')
        
        # Calculate commission
        commission_rate = vendor['commission_rate']
        total_commission = total_product_value * (commission_rate / 100)
        
        return jsonify({
            'vendor': {
                'id': vendor['id'],
                'name': vendor['name'],
                'commission_rate': commission_rate
            },
            'commission': {
                'rate_percentage': commission_rate,
                'total_product_value': total_product_value,
                'total_commission': total_commission,
                'active_products': len([p for p in products if p['status'] == 'active'])
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_vendor_commission')
        return handle_database_error(e)

@vendor_bp.route('/<int:vendor_id>/payout', methods=['POST'])
@require_auth
@require_permission('vendor:write')
@rate_limit(10, 3600)  # 10 requests per hour
def process_vendor_payout(vendor_id):
    """Process vendor payout"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        if 'amount' not in data:
            return bad_request("amount is required")
        
        amount = data['amount']
        if not isinstance(amount, (int, float)) or amount <= 0:
            return bad_request("Amount must be a positive number")
        
        # Check if vendor exists
        vendors = db_manager.execute_query(
            "SELECT * FROM vendors WHERE id = ?",
            (vendor_id,)
        )
        if not vendors:
            return not_found("Vendor not found")
        
        vendor = vendors[0]
        
        # Calculate commission for this payout
        commission_amount = amount * (vendor['commission_rate'] / 100)
        
        log_payment_operation(
            logger, 'vendor_payout', g.user_id,
            amount, 'USD', 'success'
        )
        
        return jsonify({
            'message': 'Payout processed successfully',
            'vendor_id': vendor_id,
            'payout': {
                'amount': amount,
                'commission_rate': vendor['commission_rate'],
                'commission_amount': commission_amount,
                'net_amount': amount - commission_amount
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'process_vendor_payout')
        return handle_payment_error(e) 