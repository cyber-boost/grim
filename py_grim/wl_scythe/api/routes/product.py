"""
Product management routes for Scythe API
"""

from flask import Blueprint, request, jsonify, g
from ..middleware.auth import require_auth, require_permission
from ..middleware.rate_limit import rate_limit
from ..middleware.error_handler import *
from ..utils.database import DatabaseManager
from ..utils.logger import log_payment_operation
import json
import logging
from datetime import datetime
from typing import Dict, Any, List

logger = logging.getLogger(__name__)
product_bp = Blueprint('product', __name__)
db_manager = DatabaseManager()

@product_bp.route('/', methods=['GET'])
@require_auth
@require_permission('product:read')
@rate_limit(100, 3600)  # 100 requests per hour
def get_products():
    """Get all products"""
    try:
        vendor_id = request.args.get('vendor_id')
        products = db_manager.get_products(vendor_id)
        
        # Parse tier_limits JSON for each product
        for product in products:
            product['tier_limits'] = json.loads(product['tier_limits'])
        
        return jsonify({
            'products': products,
            'count': len(products),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        log_request_error(e, 'get_products')
        return handle_database_error(e)

@product_bp.route('/', methods=['POST'])
@require_auth
@require_permission('product:write')
@rate_limit(20, 3600)  # 20 requests per hour
def create_product():
    """Create a new product"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['name', 'vendor_id', 'description', 'price', 'tier_limits']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Validate vendor exists
        vendors = db_manager.execute_query(
            "SELECT id FROM vendors WHERE id = ? AND status = 'active'",
            (data['vendor_id'],)
        )
        if not vendors:
            return not_found("Vendor not found or inactive")
        
        # Validate price
        if not isinstance(data['price'], (int, float)) or data['price'] <= 0:
            return bad_request("Price must be a positive number")
        
        # Validate tier_limits structure
        if not isinstance(data['tier_limits'], dict):
            return bad_request("tier_limits must be an object")
        
        required_tiers = ['FREE', 'PRO', 'MASTER', 'REAPER']
        for tier in required_tiers:
            if tier not in data['tier_limits']:
                return bad_request(f"Missing tier limits for {tier}")
        
        # Create product
        product_id = db_manager.create_product(
            name=data['name'],
            vendor_id=data['vendor_id'],
            description=data['description'],
            price=data['price'],
            tier_limits=data['tier_limits']
        )
        
        # Get created product
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        
        if products:
            product = products[0]
            product['tier_limits'] = json.loads(product['tier_limits'])
            
            log_payment_operation(
                logger, 'create_product', g.user_id,
                product['price'], 'USD', 'success'
            )
            
            return jsonify({
                'message': 'Product created successfully',
                'product': product,
                'timestamp': datetime.utcnow().isoformat()
            }), 201
        
        return internal_server_error("Failed to retrieve created product")
        
    except Exception as e:
        log_request_error(e, 'create_product')
        return handle_database_error(e)

@product_bp.route('/<int:product_id>', methods=['GET'])
@require_auth
@require_permission('product:read')
@rate_limit(100, 3600)  # 100 requests per hour
def get_product(product_id):
    """Get product details"""
    try:
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        
        if not products:
            return not_found("Product not found")
        
        product = products[0]
        product['tier_limits'] = json.loads(product['tier_limits'])
        
        # Get vendor information
        vendors = db_manager.execute_query(
            "SELECT id, name, email FROM vendors WHERE id = ?",
            (product['vendor_id'],)
        )
        
        vendor_info = vendors[0] if vendors else None
        
        return jsonify({
            'product': product,
            'vendor': vendor_info,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_product')
        return handle_database_error(e)

@product_bp.route('/<int:product_id>', methods=['PUT'])
@require_auth
@require_permission('product:write')
@rate_limit(50, 3600)  # 50 requests per hour
def update_product(product_id):
    """Update product"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        # Check if product exists
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        if not products:
            return not_found("Product not found")
        
        product = products[0]
        
        # Update fields
        update_fields = []
        update_values = []
        
        if 'name' in data:
            update_fields.append('name = ?')
            update_values.append(data['name'])
        
        if 'description' in data:
            update_fields.append('description = ?')
            update_values.append(data['description'])
        
        if 'price' in data:
            if not isinstance(data['price'], (int, float)) or data['price'] <= 0:
                return bad_request("Price must be a positive number")
            update_fields.append('price = ?')
            update_values.append(data['price'])
        
        if 'tier_limits' in data:
            if not isinstance(data['tier_limits'], dict):
                return bad_request("tier_limits must be an object")
            
            required_tiers = ['FREE', 'PRO', 'MASTER', 'REAPER']
            for tier in required_tiers:
                if tier not in data['tier_limits']:
                    return bad_request(f"Missing tier limits for {tier}")
            
            update_fields.append('tier_limits = ?')
            update_values.append(json.dumps(data['tier_limits']))
        
        if 'status' in data:
            valid_statuses = ['active', 'inactive', 'draft']
            if data['status'] not in valid_statuses:
                return bad_request(f"Invalid status. Must be one of: {valid_statuses}")
            update_fields.append('status = ?')
            update_values.append(data['status'])
        
        if not update_fields:
            return bad_request("No valid fields to update")
        
        update_fields.append('updated_at = CURRENT_TIMESTAMP')
        update_values.append(product_id)
        
        # Execute update
        query = f"UPDATE products SET {', '.join(update_fields)} WHERE id = ?"
        db_manager.execute_query(query, tuple(update_values))
        
        # Get updated product
        updated_products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        
        if updated_products:
            updated_product = updated_products[0]
            updated_product['tier_limits'] = json.loads(updated_product['tier_limits'])
            
            log_payment_operation(
                logger, 'update_product', g.user_id,
                updated_product['price'], 'USD', 'success'
            )
            
            return jsonify({
                'message': 'Product updated successfully',
                'product': updated_product,
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        return internal_server_error("Failed to retrieve updated product")
        
    except Exception as e:
        log_request_error(e, 'update_product')
        return handle_database_error(e)

@product_bp.route('/<int:product_id>', methods=['DELETE'])
@require_auth
@require_permission('product:write')
@rate_limit(10, 3600)  # 10 requests per hour
def delete_product(product_id):
    """Delete product"""
    try:
        # Check if product exists
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        if not products:
            return not_found("Product not found")
        
        product = products[0]
        
        # Check if product has active licenses
        licenses = db_manager.execute_query(
            "SELECT COUNT(*) as count FROM licenses WHERE product_id = ? AND status = 'active'",
            (product_id,)
        )
        
        if licenses and licenses[0]['count'] > 0:
            return conflict("Cannot delete product with active licenses")
        
        # Soft delete by setting status to inactive
        db_manager.execute_query(
            "UPDATE products SET status = 'inactive', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (product_id,)
        )
        
        log_payment_operation(
            logger, 'delete_product', g.user_id,
            0.0, 'USD', 'success'
        )
        
        return jsonify({
            'message': 'Product deleted successfully',
            'product_id': product_id,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'delete_product')
        return handle_database_error(e)

@product_bp.route('/<int:product_id>/pricing', methods=['GET'])
@require_auth
@require_permission('product:read')
@rate_limit(100, 3600)  # 100 requests per hour
def get_product_pricing(product_id):
    """Get product pricing information"""
    try:
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        
        if not products:
            return not_found("Product not found")
        
        product = products[0]
        product['tier_limits'] = json.loads(product['tier_limits'])
        
        # Get vendor information
        vendors = db_manager.execute_query(
            "SELECT id, name, commission_rate FROM vendors WHERE id = ?",
            (product['vendor_id'],)
        )
        
        vendor = vendors[0] if vendors else None
        
        # Calculate commission
        commission_amount = 0
        if vendor:
            commission_amount = product['price'] * (vendor['commission_rate'] / 100)
        
        return jsonify({
            'product': {
                'id': product['id'],
                'name': product['name'],
                'price': product['price'],
                'tier_limits': product['tier_limits']
            },
            'vendor': vendor,
            'pricing': {
                'base_price': product['price'],
                'commission_rate': vendor['commission_rate'] if vendor else 0,
                'commission_amount': commission_amount,
                'net_amount': product['price'] - commission_amount
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_product_pricing')
        return handle_database_error(e)

@product_bp.route('/<int:product_id>/licenses', methods=['GET'])
@require_auth
@require_permission('product:read')
@rate_limit(50, 3600)  # 50 requests per hour
def get_product_licenses(product_id):
    """Get licenses for a product"""
    try:
        # Check if product exists
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        if not products:
            return not_found("Product not found")
        
        # Get licenses for this product
        licenses = db_manager.execute_query(
            "SELECT * FROM licenses WHERE product_id = ? ORDER BY created_at DESC",
            (product_id,)
        )
        
        # Group licenses by status
        license_stats = {
            'total': len(licenses),
            'active': len([l for l in licenses if l['status'] == 'active']),
            'suspended': len([l for l in licenses if l['status'] == 'suspended']),
            'cancelled': len([l for l in licenses if l['status'] == 'cancelled']),
            'expired': 0
        }
        
        # Count expired licenses
        current_time = datetime.utcnow()
        for license_data in licenses:
            if license_data['expires_at']:
                expires_at = datetime.fromisoformat(license_data['expires_at'].replace('Z', '+00:00'))
                if current_time > expires_at and license_data['status'] == 'active':
                    license_stats['expired'] += 1
        
        return jsonify({
            'product_id': product_id,
            'licenses': licenses,
            'statistics': license_stats,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_product_licenses')
        return handle_database_error(e)

@product_bp.route('/<int:product_id>/analytics', methods=['GET'])
@require_auth
@require_permission('product:read')
@rate_limit(50, 3600)  # 50 requests per hour
def get_product_analytics(product_id):
    """Get product analytics"""
    try:
        # Check if product exists
        products = db_manager.execute_query(
            "SELECT * FROM products WHERE id = ?",
            (product_id,)
        )
        if not products:
            return not_found("Product not found")
        
        product = products[0]
        
        # Get license statistics
        licenses = db_manager.execute_query(
            "SELECT * FROM licenses WHERE product_id = ?",
            (product_id,)
        )
        
        # Calculate analytics
        total_licenses = len(licenses)
        active_licenses = len([l for l in licenses if l['status'] == 'active'])
        total_revenue = total_licenses * product['price']
        
        # Tier distribution
        tier_distribution = {}
        for license_data in licenses:
            tier = license_data['tier']
            tier_distribution[tier] = tier_distribution.get(tier, 0) + 1
        
        # Monthly growth (simplified)
        current_month = datetime.utcnow().month
        current_year = datetime.utcnow().year
        monthly_licenses = len([
            l for l in licenses 
            if datetime.fromisoformat(l['created_at'].replace('Z', '+00:00')).month == current_month
            and datetime.fromisoformat(l['created_at'].replace('Z', '+00:00')).year == current_year
        ])
        
        return jsonify({
            'product_id': product_id,
            'analytics': {
                'total_licenses': total_licenses,
                'active_licenses': active_licenses,
                'total_revenue': total_revenue,
                'monthly_licenses': monthly_licenses,
                'tier_distribution': tier_distribution,
                'conversion_rate': (active_licenses / total_licenses * 100) if total_licenses > 0 else 0
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_product_analytics')
        return handle_database_error(e) 