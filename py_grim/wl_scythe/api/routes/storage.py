"""
Storage management routes for Scythe API
"""

from flask import Blueprint, request, jsonify, g
from flask_limiter.util import get_remote_address
from ..middleware.auth import require_auth, require_permission
from ..middleware.rate_limit import rate_limit
from ..middleware.error_handler import *
from ..utils.database import DatabaseManager
from ..utils.logger import log_storage_operation
import json
import logging
from datetime import datetime
from typing import Dict, Any, List

logger = logging.getLogger(__name__)
storage_bp = Blueprint('storage', __name__)
db_manager = DatabaseManager()

# Storage Providers Endpoints
@storage_bp.route('/providers', methods=['GET'])
@require_auth
@rate_limit(100, 3600)  # 100 requests per hour
def get_storage_providers():
    """Get all storage providers"""
    try:
        providers = db_manager.get_storage_providers()
        
        # Parse config JSON for each provider
        for provider in providers:
            provider['config'] = json.loads(provider['config'])
        
        return jsonify({
            'providers': providers,
            'count': len(providers),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        log_request_error(e, 'get_storage_providers')
        return handle_database_error(e)

@storage_bp.route('/providers', methods=['POST'])
@require_auth
@require_permission('storage:write')
@rate_limit(20, 3600)  # 20 requests per hour
def create_storage_provider():
    """Create a new storage provider"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['name', 'type', 'config']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Validate provider type
        valid_types = ['local', 's3', 'gcs', 'azure']
        if data['type'] not in valid_types:
            return bad_request(f"Invalid provider type. Must be one of: {valid_types}")
        
        # Create provider
        provider_id = db_manager.create_storage_provider(
            name=data['name'],
            provider_type=data['type'],
            config=data['config']
        )
        
        # Get created provider
        providers = db_manager.execute_query(
            "SELECT * FROM storage_providers WHERE id = ?",
            (provider_id,)
        )
        
        if providers:
            provider = providers[0]
            provider['config'] = json.loads(provider['config'])
            
            log_storage_operation(
                logger, 'create_provider', g.user_id, 
                f"provider:{provider_id}", 0, data['type']
            )
            
            return jsonify({
                'message': 'Storage provider created successfully',
                'provider': provider,
                'timestamp': datetime.utcnow().isoformat()
            }), 201
        
        return internal_server_error("Failed to retrieve created provider")
        
    except Exception as e:
        log_request_error(e, 'create_storage_provider')
        return handle_database_error(e)

# Storage Allocations Endpoints
@storage_bp.route('/allocations', methods=['GET'])
@require_auth
@rate_limit(100, 3600)  # 100 requests per hour
def get_storage_allocations():
    """Get storage allocations"""
    try:
        user_id = request.args.get('user_id')
        allocations = db_manager.get_storage_allocations(user_id)
        
        # Get provider details for each allocation
        for allocation in allocations:
            providers = db_manager.execute_query(
                "SELECT name, type FROM storage_providers WHERE id = ?",
                (allocation['provider_id'],)
            )
            if providers:
                allocation['provider'] = providers[0]
        
        return jsonify({
            'allocations': allocations,
            'count': len(allocations),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        log_request_error(e, 'get_storage_allocations')
        return handle_database_error(e)

@storage_bp.route('/allocations', methods=['POST'])
@require_auth
@require_permission('storage:write')
@rate_limit(50, 3600)  # 50 requests per hour
def create_storage_allocation():
    """Create a new storage allocation"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['user_id', 'provider_id', 'allocated_size', 'path']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Validate provider exists
        providers = db_manager.execute_query(
            "SELECT id FROM storage_providers WHERE id = ? AND enabled = 1",
            (data['provider_id'],)
        )
        if not providers:
            return not_found("Storage provider not found or disabled")
        
        # Create allocation
        allocation_id = db_manager.create_storage_allocation(
            user_id=data['user_id'],
            provider_id=data['provider_id'],
            allocated_size=data['allocated_size'],
            path=data['path']
        )
        
        # Get created allocation
        allocations = db_manager.execute_query(
            "SELECT * FROM storage_allocations WHERE id = ?",
            (allocation_id,)
        )
        
        if allocations:
            allocation = allocations[0]
            
            log_storage_operation(
                logger, 'create_allocation', g.user_id,
                allocation['path'], allocation['allocated_size'], 
                f"provider:{allocation['provider_id']}"
            )
            
            return jsonify({
                'message': 'Storage allocation created successfully',
                'allocation': allocation,
                'timestamp': datetime.utcnow().isoformat()
            }), 201
        
        return internal_server_error("Failed to retrieve created allocation")
        
    except Exception as e:
        log_request_error(e, 'create_storage_allocation')
        return handle_database_error(e)

@storage_bp.route('/allocations/<int:allocation_id>', methods=['PUT'])
@require_auth
@require_permission('storage:write')
@rate_limit(50, 3600)  # 50 requests per hour
def update_storage_allocation(allocation_id):
    """Update storage allocation"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        # Check if allocation exists
        allocations = db_manager.execute_query(
            "SELECT * FROM storage_allocations WHERE id = ?",
            (allocation_id,)
        )
        if not allocations:
            return not_found("Storage allocation not found")
        
        allocation = allocations[0]
        
        # Update fields
        update_fields = []
        update_values = []
        
        if 'allocated_size' in data:
            update_fields.append('allocated_size = ?')
            update_values.append(data['allocated_size'])
        
        if 'path' in data:
            update_fields.append('path = ?')
            update_values.append(data['path'])
        
        if 'status' in data:
            update_fields.append('status = ?')
            update_values.append(data['status'])
        
        if not update_fields:
            return bad_request("No valid fields to update")
        
        update_fields.append('updated_at = CURRENT_TIMESTAMP')
        update_values.append(allocation_id)
        
        # Execute update
        query = f"UPDATE storage_allocations SET {', '.join(update_fields)} WHERE id = ?"
        db_manager.execute_query(query, tuple(update_values))
        
        # Get updated allocation
        updated_allocations = db_manager.execute_query(
            "SELECT * FROM storage_allocations WHERE id = ?",
            (allocation_id,)
        )
        
        if updated_allocations:
            log_storage_operation(
                logger, 'update_allocation', g.user_id,
                updated_allocations[0]['path'], updated_allocations[0]['allocated_size'],
                f"provider:{updated_allocations[0]['provider_id']}"
            )
            
            return jsonify({
                'message': 'Storage allocation updated successfully',
                'allocation': updated_allocations[0],
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        
        return internal_server_error("Failed to retrieve updated allocation")
        
    except Exception as e:
        log_request_error(e, 'update_storage_allocation')
        return handle_database_error(e)

# Storage Usage Endpoints
@storage_bp.route('/usage', methods=['GET'])
@require_auth
@rate_limit(100, 3600)  # 100 requests per hour
def get_storage_usage():
    """Get storage usage statistics"""
    try:
        user_id = request.args.get('user_id')
        allocation_id = request.args.get('allocation_id')
        
        if allocation_id:
            # Get usage for specific allocation
            usage = db_manager.execute_query(
                "SELECT * FROM storage_usage WHERE allocation_id = ? ORDER BY uploaded_at DESC",
                (allocation_id,)
            )
        elif user_id:
            # Get usage for user's allocations
            usage = db_manager.execute_query('''
                SELECT su.*, sa.user_id, sa.path as allocation_path
                FROM storage_usage su
                JOIN storage_allocations sa ON su.allocation_id = sa.id
                WHERE sa.user_id = ?
                ORDER BY su.uploaded_at DESC
            ''', (user_id,))
        else:
            # Get all usage
            usage = db_manager.execute_query('''
                SELECT su.*, sa.user_id, sa.path as allocation_path
                FROM storage_usage su
                JOIN storage_allocations sa ON su.allocation_id = sa.id
                ORDER BY su.uploaded_at DESC
            ''')
        
        # Calculate totals
        total_size = sum(item['file_size'] for item in usage)
        total_files = len(usage)
        
        return jsonify({
            'usage': usage,
            'statistics': {
                'total_files': total_files,
                'total_size': total_size,
                'total_size_mb': round(total_size / (1024 * 1024), 2),
                'total_size_gb': round(total_size / (1024 * 1024 * 1024), 2)
            },
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        log_request_error(e, 'get_storage_usage')
        return handle_database_error(e)

@storage_bp.route('/usage', methods=['POST'])
@require_auth
@require_permission('storage:write')
@rate_limit(100, 3600)  # 100 requests per hour
def update_storage_usage():
    """Update storage usage"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['allocation_id', 'file_path', 'file_size']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Check if allocation exists
        allocations = db_manager.execute_query(
            "SELECT * FROM storage_allocations WHERE id = ?",
            (data['allocation_id'],)
        )
        if not allocations:
            return not_found("Storage allocation not found")
        
        allocation = allocations[0]
        
        # Check if file size exceeds allocation
        current_usage = db_manager.execute_query(
            "SELECT COALESCE(SUM(file_size), 0) as used FROM storage_usage WHERE allocation_id = ?",
            (data['allocation_id'],)
        )
        current_used = current_usage[0]['used'] if current_usage else 0
        new_total = current_used + data['file_size']
        
        if new_total > allocation['allocated_size']:
            return conflict("File size would exceed allocation limit")
        
        # Update usage
        db_manager.update_storage_usage(
            allocation_id=data['allocation_id'],
            file_path=data['file_path'],
            file_size=data['file_size'],
            file_type=data.get('file_type')
        )
        
        log_storage_operation(
            logger, 'update_usage', g.user_id,
            data['file_path'], data['file_size'],
            f"allocation:{data['allocation_id']}"
        )
        
        return jsonify({
            'message': 'Storage usage updated successfully',
            'file_path': data['file_path'],
            'file_size': data['file_size'],
            'timestamp': datetime.utcnow().isoformat()
        }), 201
        
    except Exception as e:
        log_request_error(e, 'update_storage_usage')
        return handle_database_error(e)

# Storage Policies Endpoints
@storage_bp.route('/policies', methods=['GET'])
@require_auth
@rate_limit(50, 3600)  # 50 requests per hour
def get_storage_policies():
    """Get storage policies"""
    try:
        policies = db_manager.execute_query(
            "SELECT * FROM storage_policies ORDER BY name"
        )
        
        # Parse config JSON for each policy
        for policy in policies:
            policy['config'] = json.loads(policy['config'])
        
        return jsonify({
            'policies': policies,
            'count': len(policies),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        log_request_error(e, 'get_storage_policies')
        return handle_database_error(e)

@storage_bp.route('/policies', methods=['POST'])
@require_auth
@require_permission('storage:write')
@rate_limit(20, 3600)  # 20 requests per hour
def create_storage_policy():
    """Create a new storage policy"""
    try:
        data = request.get_json()
        
        if not data:
            return bad_request("Request body required")
        
        required_fields = ['name', 'policy_type', 'config']
        for field in required_fields:
            if field not in data:
                return bad_request(f"Missing required field: {field}")
        
        # Validate policy type
        valid_types = ['retention', 'file_type', 'size_limit', 'encryption', 'backup']
        if data['policy_type'] not in valid_types:
            return bad_request(f"Invalid policy type. Must be one of: {valid_types}")
        
        # Create policy
        query = '''
            INSERT INTO storage_policies (name, policy_type, config)
            VALUES (?, ?, ?)
        '''
        conn = db_manager.get_connection()
        cursor = conn.cursor()
        cursor.execute(query, (data['name'], data['policy_type'], json.dumps(data['config'])))
        policy_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        # Get created policy
        policies = db_manager.execute_query(
            "SELECT * FROM storage_policies WHERE id = ?",
            (policy_id,)
        )
        
        if policies:
            policy = policies[0]
            policy['config'] = json.loads(policy['config'])
            
            log_storage_operation(
                logger, 'create_policy', g.user_id,
                f"policy:{policy_id}", 0, data['policy_type']
            )
            
            return jsonify({
                'message': 'Storage policy created successfully',
                'policy': policy,
                'timestamp': datetime.utcnow().isoformat()
            }), 201
        
        return internal_server_error("Failed to retrieve created policy")
        
    except Exception as e:
        log_request_error(e, 'create_storage_policy')
        return handle_database_error(e) 