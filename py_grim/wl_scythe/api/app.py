"""
Scythe API - Main Application
Comprehensive RESTful APIs for storage management and license validation
"""

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from functools import wraps
import jwt
import datetime
import logging
import os
import json
from typing import Dict, Any, Optional

# Import API modules
from .routes.storage import storage_bp
from .routes.license import license_bp
from .routes.vendor import vendor_bp
from .routes.product import product_bp
from .middleware.auth import auth_middleware
from .middleware.rate_limit import rate_limit_middleware
from .middleware.error_handler import error_handler_middleware
from .utils.config import Config
from .utils.database import DatabaseManager
from .utils.logger import setup_logger

# Initialize Flask app
app = Flask(__name__)
app.config.from_object(Config)

# Enable CORS
CORS(app, resources={r"/scythe/*": {"origins": "*"}})

# Setup logging
logger = setup_logger()

# Initialize rate limiter
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# Initialize database
db_manager = DatabaseManager()

# Register blueprints
app.register_blueprint(storage_bp, url_prefix='/scythe/storage')
app.register_blueprint(license_bp, url_prefix='/scythe')
app.register_blueprint(vendor_bp, url_prefix='/scythe/vendor')
app.register_blueprint(product_bp, url_prefix='/scythe/product')

# Register middleware
app.before_request(auth_middleware)
app.before_request(rate_limit_middleware)
app.register_error_handler(Exception, error_handler_middleware)

@app.route('/scythe/health', methods=['GET'])
@limiter.limit("100 per minute")
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }), 200

@app.route('/scythe/docs', methods=['GET'])
@limiter.limit("50 per minute")
def api_documentation():
    """API documentation endpoint"""
    docs = {
        "api_name": "Scythe Storage & License Management API",
        "version": "1.0.0",
        "endpoints": {
            "storage": {
                "providers": {
                    "GET /scythe/storage/providers": "List all storage providers",
                    "POST /scythe/storage/providers": "Create new storage provider"
                },
                "allocations": {
                    "GET /scythe/storage/allocations": "List storage allocations",
                    "POST /scythe/storage/allocations": "Create storage allocation",
                    "PUT /scythe/storage/allocations/<id>": "Update storage allocation"
                },
                "usage": {
                    "GET /scythe/storage/usage": "Get storage usage statistics",
                    "POST /scythe/storage/usage": "Update storage usage"
                },
                "policies": {
                    "GET /scythe/storage/policies": "List storage policies",
                    "POST /scythe/storage/policies": "Create storage policy"
                }
            },
            "license": {
                "validation": {
                    "POST /scythe/validate": "Validate license"
                },
                "generation": {
                    "POST /scythe/license/generate": "Generate new license"
                }
            },
            "vendor": {
                "GET /scythe/vendor": "List vendors",
                "POST /scythe/vendor": "Create vendor",
                "GET /scythe/vendor/<id>": "Get vendor details",
                "PUT /scythe/vendor/<id>": "Update vendor",
                "DELETE /scythe/vendor/<id>": "Delete vendor"
            },
            "product": {
                "GET /scythe/product": "List products",
                "POST /scythe/product": "Create product",
                "GET /scythe/product/<id>": "Get product details",
                "PUT /scythe/product/<id>": "Update product",
                "DELETE /scythe/product/<id>": "Delete product"
            }
        },
        "authentication": "Bearer token required for all endpoints",
        "rate_limits": "Varies by endpoint, see individual endpoint documentation"
    }
    return jsonify(docs), 200

if __name__ == '__main__':
    app.run(debug=Config.DEBUG, host='0.0.0.0', port=5000) 