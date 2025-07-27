"""
License management routes for Scythe API
"""

from flask import Blueprint, request, jsonify, g
from ..middleware.auth import require_auth, require_permission
from ..middleware.rate_limit import rate_limit
from ..middleware.error_handler import *
from ..utils.database import DatabaseManager
from ..utils.logger import log_license_operation
import hashlib
import secrets
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)
license_bp = Blueprint('license', __name__)
db_manager = DatabaseManager()

def generate_license_key() -> str:
    """Generate a unique license key"""
    # Generate a random 32-character hex string
    random_part = secrets.token_hex(16)
    # Add timestamp for uniqueness
    timestamp = str(int(datetime.utcnow().timestamp()))[-8:]
    # Combine and hash
    combined = f"{random_part}{timestamp}"
    return hashlib.sha256(combined.encode()).hexdigest()[:32].upper()

def validate_license_format(license_key: str) -> bool:
    """Validate license key format"""
    if not license_key or len(license_key) != 32:
        return False
    # Check if it's a valid hex string
    try:
        int(license_key, 16)
        return True
    except ValueError:
        return False

@license_bp.route('/validate', methods=['POST'])
@require_auth
@rate_limit(50, 3600)  # 50 requests per hour
def validate_license():
    """Validate a license key"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        if 'license_key' not in data:
            return bad_request("license_key is required")
        
        license_key = data['license_key'].strip()
        
        # Validate format
        if not validate_license_format(license_key):
            return bad_request("Invalid license key format")
        
        # Get license from database
        license_data = db_manager.get_license_by_key(license_key)
        
        if not license_data:
            log_license_operation(logger, 'validate', license_key, g.user_id, 'invalid')
            return jsonify({
                'valid': False,
                'message': 'License key not found',
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        # Check if license is expired
        if license_data['expires_at']:
            expires_at = datetime.fromisoformat(license_data['expires_at'].replace('Z', '+00:00'))
            if datetime.utcnow() > expires_at:
                log_license_operation(logger, 'validate', license_key, g.user_id, 'expired')
                return jsonify({
                    'valid': False,
                    'message': 'License has expired',
                    'expires_at': license_data['expires_at'],
                    'timestamp': datetime.utcnow().isoformat()
                }), 200
        
        # Check if license is active
        if license_data['status'] != 'active':
            log_license_operation(logger, 'validate', license_key, g.user_id, 'inactive')
            return jsonify({
                'valid': False,
                'message': f'License is {license_data["status"]}',
                'status': license_data['status'],
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        # License is valid
        log_license_operation(logger, 'validate', license_key, g.user_id, 'valid')
        
        return jsonify({
            'valid': True,
            'license': {
                'user_id': license_data['user_id'],
                'product_id': license_data['product_id'],
                'tier': license_data['tier'],
                'status': license_data['status'],
                'created_at': license_data['created_at'],
                'expires_at': license_data['expires_at']
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'validate_license')
        return handle_license_error(e)

@license_bp.route('/license/generate', methods=['POST'])
@require_auth
@require_permission('license:write')
@rate_limit(20, 3600)  # 20 requests per hour
def generate_license():
    """Generate a new license"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['user_id', 'product_id', 'tier']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Validate tier
        valid_tiers = ['FREE', 'PRO', 'MASTER', 'REAPER']
        if data['tier'] not in valid_tiers:
            return bad_request(f"Invalid tier. Must be one of: {valid_tiers}")
        
        # Generate unique license key
        license_key = generate_license_key()
        
        # Check if key already exists (very unlikely, but check anyway)
        while db_manager.get_license_by_key(license_key):
            license_key = generate_license_key()
        
        # Set expiration date based on tier
        expires_at = None
        if data['tier'] == 'FREE':
            expires_at = (datetime.utcnow() + timedelta(days=30)).isoformat()
        elif data['tier'] == 'PRO':
            expires_at = (datetime.utcnow() + timedelta(days=365)).isoformat()
        elif data['tier'] == 'MASTER':
            expires_at = (datetime.utcnow() + timedelta(days=365*2)).isoformat()
        elif data['tier'] == 'REAPER':
            expires_at = (datetime.utcnow() + timedelta(days=365*5)).isoformat()
        
        # Create license
        license_id = db_manager.create_license(
            license_key=license_key,
            user_id=data['user_id'],
            product_id=data['product_id'],
            tier=data['tier'],
            expires_at=expires_at
        )
        
        # Get created license
        licenses = db_manager.execute_query(
            "SELECT * FROM licenses WHERE id = ?",
            (license_id,)
        )
        
        if licenses:
            license_data = licenses[0]
            
            log_license_operation(logger, 'generate', license_key, g.user_id, 'created')
            
            return jsonify({
                'message': 'License generated successfully',
                'license': {
                    'license_key': license_key,
                    'user_id': license_data['user_id'],
                    'product_id': license_data['product_id'],
                    'tier': license_data['tier'],
                    'status': license_data['status'],
                    'created_at': license_data['created_at'],
                    'expires_at': license_data['expires_at']
                },
                'timestamp': datetime.utcnow().isoformat()
            }), 201
        
        return internal_server_error("Failed to retrieve created license")
        
    except Exception as e:
        log_request_error(e, 'generate_license')
        return handle_license_error(e)

@license_bp.route('/license/<license_key>', methods=['GET'])
@require_auth
@require_permission('license:read')
@rate_limit(100, 3600)  # 100 requests per hour
def get_license(license_key):
    """Get license details"""
    try:
        # Validate format
        if not validate_license_format(license_key):
            return bad_request("Invalid license key format")
        
        # Get license from database
        license_data = db_manager.get_license_by_key(license_key)
        
        if not license_data:
            return not_found("License not found")
        
        return jsonify({
            'license': {
                'license_key': license_data['license_key'],
                'user_id': license_data['user_id'],
                'product_id': license_data['product_id'],
                'tier': license_data['tier'],
                'status': license_data['status'],
                'created_at': license_data['created_at'],
                'expires_at': license_data['expires_at'],
                'updated_at': license_data['updated_at']
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'get_license')
        return handle_license_error(e)

@license_bp.route('/license/<license_key>', methods=['PUT'])
@require_auth
@require_permission('license:write')
@rate_limit(20, 3600)  # 20 requests per hour
def update_license(license_key):
    """Update license"""
    try:
        # Validate format
        if not validate_license_format(license_key):
            return bad_request("Invalid license key format")
        
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        # Check if license exists
        license_data = db_manager.get_license_by_key(license_key)
        if not license_data:
            return not_found("License not found")
        
        # Update fields
        update_fields = []
        update_values = []
        
        if 'tier' in data:
            valid_tiers = ['FREE', 'PRO', 'MASTER', 'REAPER']
            if data['tier'] not in valid_tiers:
                return bad_request(f"Invalid tier. Must be one of: {valid_tiers}")
            update_fields.append('tier = ?')
            update_values.append(data['tier'])
        
        if 'status' in data:
            valid_statuses = ['active', 'suspended', 'cancelled']
            if data['status'] not in valid_statuses:
                return bad_request(f"Invalid status. Must be one of: {valid_statuses}")
            update_fields.append('status = ?')
            update_values.append(data['status'])
        
        if 'expires_at' in data:
            update_fields.append('expires_at = ?')
            update_values.append(data['expires_at'])
        
        if not update_fields:
            return bad_request("No valid fields to update")
        
        update_fields.append('updated_at = CURRENT_TIMESTAMP')
        update_values.append(license_key)
        
        # Execute update
        query = f"UPDATE licenses SET {', '.join(update_fields)} WHERE license_key = ?"
        db_manager.execute_query(query, tuple(update_values))
        
        # Get updated license
        updated_licenses = db_manager.execute_query(
            "SELECT * FROM licenses WHERE license_key = ?",
            (license_key,)
        )
        
        if updated_licenses:
            updated_license = updated_licenses[0]
            
            log_license_operation(logger, 'update', license_key, g.user_id, 'updated')
            
            return jsonify({
                'message': 'License updated successfully',
                'license': {
                    'license_key': updated_license['license_key'],
                    'user_id': updated_license['user_id'],
                    'product_id': updated_license['product_id'],
                    'tier': updated_license['tier'],
                    'status': updated_license['status'],
                    'created_at': updated_license['created_at'],
                    'expires_at': updated_license['expires_at'],
                    'updated_at': updated_license['updated_at']
                },
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        return internal_server_error("Failed to retrieve updated license")
        
    except Exception as e:
        log_request_error(e, 'update_license')
        return handle_license_error(e)

@license_bp.route('/license/<license_key>', methods=['DELETE'])
@require_auth
@require_permission('license:write')
@rate_limit(10, 3600)  # 10 requests per hour
def revoke_license(license_key):
    """Revoke a license"""
    try:
        # Validate format
        if not validate_license_format(license_key):
            return bad_request("Invalid license key format")
        
        # Check if license exists
        license_data = db_manager.get_license_by_key(license_key)
        if not license_data:
            return not_found("License not found")
        
        # Update status to cancelled
        db_manager.execute_query(
            "UPDATE licenses SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE license_key = ?",
            (license_key,)
        )
        
        log_license_operation(logger, 'revoke', license_key, g.user_id, 'cancelled')
        
        return jsonify({
            'message': 'License revoked successfully',
            'license_key': license_key,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'revoke_license')
        return handle_license_error(e)

@license_bp.route('/licenses', methods=['GET'])
@require_auth
@require_permission('license:read')
@rate_limit(50, 3600)  # 50 requests per hour
def list_licenses():
    """List all licenses with optional filtering"""
    try:
        user_id = request.args.get('user_id')
        product_id = request.args.get('product_id')
        tier = request.args.get('tier')
        status = request.args.get('status')
        
        # Build query with filters
        query = "SELECT * FROM licenses WHERE 1=1"
        params = []
        
        if user_id:
            query += " AND user_id = ?"
            params.append(user_id)
        
        if product_id:
            query += " AND product_id = ?"
            params.append(product_id)
        
        if tier:
            query += " AND tier = ?"
            params.append(tier)
        
        if status:
            query += " AND status = ?"
            params.append(status)
        
        query += " ORDER BY created_at DESC"
        
        licenses = db_manager.execute_query(query, tuple(params))
        
        return jsonify({
            'licenses': licenses,
            'count': len(licenses),
            'filters': {
                'user_id': user_id,
                'product_id': product_id,
                'tier': tier,
                'status': status
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        log_request_error(e, 'list_licenses')
        return handle_license_error(e) 