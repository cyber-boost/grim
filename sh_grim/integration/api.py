"""
Grimm Integration - API Management
Comprehensive external API integration and management
"""

import requests
import json
import time
import hashlib
import hmac
import base64
from typing import Dict, List, Optional, Any, Union
from urllib.parse import urlencode
import logging
from datetime import datetime, timedelta
import threading
from collections import defaultdict
import ssl
import certifi


class RateLimiter:
    """Rate limiting for API requests"""
    
    def __init__(self, max_requests: int = 100, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests = []
        self.lock = threading.Lock()
        
    def can_make_request(self) -> bool:
        """Check if a request can be made"""
        now = time.time()
        
        with self.lock:
            # Remove old requests outside the window
            self.requests = [req_time for req_time in self.requests 
                           if now - req_time < self.window_seconds]
            
            if len(self.requests) < self.max_requests:
                self.requests.append(now)
                return True
            return False
            
    def wait_if_needed(self):
        """Wait if rate limit is exceeded"""
        while not self.can_make_request():
            time.sleep(1)


class APIManager:
    """Comprehensive API integration manager"""
    
    def __init__(self, config: Optional[Dict] = None):
        self.config = config or {}
        self.session = requests.Session()
        self.rate_limiters = defaultdict(lambda: RateLimiter())
        self.logger = logging.getLogger('grimm.api')
        self._setup_session()
        
    def _setup_session(self):
        """Setup requests session with default configuration"""
        self.session.headers.update({
            'User-Agent': self.config.get('default_user_agent', 'Grimm-API/1.0'),
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        })
        
        # SSL configuration
        if self.config.get('enable_ssl_verification', True):
            self.session.verify = certifi.where()
        else:
            self.session.verify = False
            
        # Timeout configuration
        self.session.timeout = self.config.get('api_timeout', 30)
        
    def add_api_config(self, 
                      name: str,
                      base_url: str,
                      auth_type: str = 'none',
                      api_key: Optional[str] = None,
                      username: Optional[str] = None,
                      password: Optional[str] = None,
                      headers: Optional[Dict] = None,
                      rate_limit: Optional[int] = None,
                      rate_window: Optional[int] = None) -> bool:
        """Add API configuration"""
        try:
            config = {
                'base_url': base_url.rstrip('/'),
                'auth_type': auth_type,
                'api_key': api_key,
                'username': username,
                'password': password,
                'headers': headers or {},
                'rate_limit': rate_limit,
                'rate_window': rate_window
            }
            
            # Store configuration
            self.config[f'api_{name}'] = config
            
            # Setup rate limiter if specified
            if rate_limit and rate_window:
                self.rate_limiters[name] = RateLimiter(rate_limit, rate_window)
                
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to add API config {name}: {e}")
            return False
            
    def _get_auth_headers(self, api_config: Dict, endpoint: str = '') -> Dict:
        """Generate authentication headers"""
        headers = {}
        auth_type = api_config.get('auth_type', 'none')
        
        if auth_type == 'api_key':
            api_key = api_config.get('api_key')
            if api_key:
                headers['Authorization'] = f'Bearer {api_key}'
                headers['X-API-Key'] = api_key
                
        elif auth_type == 'basic':
            username = api_config.get('username')
            password = api_config.get('password')
            if username and password:
                import base64
                credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
                headers['Authorization'] = f'Basic {credentials}'
                
        elif auth_type == 'hmac':
            api_key = api_config.get('api_key')
            if api_key:
                timestamp = str(int(time.time()))
                message = f"{endpoint}{timestamp}"
                signature = hmac.new(
                    api_key.encode(),
                    message.encode(),
                    hashlib.sha256
                ).hexdigest()
                headers['X-Timestamp'] = timestamp
                headers['X-Signature'] = signature
                
        return headers
        
    def make_request(self,
                    api_name: str,
                    method: str,
                    endpoint: str,
                    data: Optional[Dict] = None,
                    params: Optional[Dict] = None,
                    headers: Optional[Dict] = None,
                    timeout: Optional[int] = None) -> Dict:
        """Make API request with rate limiting and error handling"""
        try:
            # Get API configuration
            api_config = self.config.get(f'api_{api_name}')
            if not api_config:
                raise ValueError(f"API configuration not found: {api_name}")
                
            # Rate limiting
            rate_limiter = self.rate_limiters.get(api_name)
            if rate_limiter:
                rate_limiter.wait_if_needed()
                
            # Build URL
            url = f"{api_config['base_url']}/{endpoint.lstrip('/')}"
            
            # Prepare headers
            request_headers = api_config.get('headers', {}).copy()
            request_headers.update(self._get_auth_headers(api_config, endpoint))
            if headers:
                request_headers.update(headers)
                
            # Prepare request data
            request_data = None
            if data:
                if method.upper() in ['GET', 'DELETE']:
                    params = params or {}
                    params.update(data)
                else:
                    request_data = json.dumps(data)
                    
            # Make request
            response = self.session.request(
                method=method.upper(),
                url=url,
                data=request_data,
                params=params,
                headers=request_headers,
                timeout=timeout or self.config.get('api_timeout', 30)
            )
            
            # Handle response
            result = {
                'success': response.status_code < 400,
                'status_code': response.status_code,
                'headers': dict(response.headers),
                'url': response.url
            }
            
            try:
                result['data'] = response.json()
            except:
                result['data'] = response.text
                
            # Log request
            if self.config.get('log_integration_events', True):
                self.logger.info(f"API {api_name} {method} {endpoint}: {response.status_code}")
                
            return result
            
        except requests.exceptions.Timeout:
            return {
                'success': False,
                'error': 'timeout',
                'message': 'Request timed out'
            }
        except requests.exceptions.ConnectionError:
            return {
                'success': False,
                'error': 'connection_error',
                'message': 'Connection failed'
            }
        except Exception as e:
            return {
                'success': False,
                'error': 'request_error',
                'message': str(e)
            }
            
    def get(self, api_name: str, endpoint: str, **kwargs) -> Dict:
        """Make GET request"""
        return self.make_request(api_name, 'GET', endpoint, **kwargs)
        
    def post(self, api_name: str, endpoint: str, data: Dict, **kwargs) -> Dict:
        """Make POST request"""
        return self.make_request(api_name, 'POST', endpoint, data=data, **kwargs)
        
    def put(self, api_name: str, endpoint: str, data: Dict, **kwargs) -> Dict:
        """Make PUT request"""
        return self.make_request(api_name, 'PUT', endpoint, data=data, **kwargs)
        
    def delete(self, api_name: str, endpoint: str, **kwargs) -> Dict:
        """Make DELETE request"""
        return self.make_request(api_name, 'DELETE', endpoint, **kwargs)
        
    def batch_request(self, 
                     api_name: str,
                     requests: List[Dict],
                     max_concurrent: int = 5) -> List[Dict]:
        """Make multiple requests in parallel"""
        import concurrent.futures
        
        results = []
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_concurrent) as executor:
            future_to_request = {}
            
            for req in requests:
                future = executor.submit(
                    self.make_request,
                    api_name,
                    req['method'],
                    req['endpoint'],
                    data=req.get('data'),
                    params=req.get('params'),
                    headers=req.get('headers')
                )
                future_to_request[future] = req
                
            for future in concurrent.futures.as_completed(future_to_request):
                results.append(future.result())
                
        return results
        
    def health_check(self, api_name: str) -> Dict:
        """Check API health"""
        try:
            api_config = self.config.get(f'api_{api_name}')
            if not api_config:
                return {'healthy': False, 'error': 'Configuration not found'}
                
            # Try to make a simple request
            result = self.get(api_name, 'health')
            if result['success']:
                return {'healthy': True, 'response_time': result.get('response_time')}
            else:
                return {'healthy': False, 'error': result.get('message')}
                
        except Exception as e:
            return {'healthy': False, 'error': str(e)}
            
    def get_rate_limit_status(self, api_name: str) -> Dict:
        """Get rate limit status for an API"""
        rate_limiter = self.rate_limiters.get(api_name)
        if not rate_limiter:
            return {'enabled': False}
            
        with rate_limiter.lock:
            now = time.time()
            recent_requests = [req_time for req_time in rate_limiter.requests 
                             if now - req_time < rate_limiter.window_seconds]
            
            return {
                'enabled': True,
                'max_requests': rate_limiter.max_requests,
                'window_seconds': rate_limiter.window_seconds,
                'current_requests': len(recent_requests),
                'remaining_requests': max(0, rate_limiter.max_requests - len(recent_requests)),
                'reset_time': now + rate_limiter.window_seconds if recent_requests else now
            }


def main():
    """CLI interface for API management"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grimm API Manager CLI')
    parser.add_argument('action', choices=['config', 'request', 'health', 'status'])
    parser.add_argument('--api-name', required=True, help='API name')
    parser.add_argument('--method', choices=['GET', 'POST', 'PUT', 'DELETE'], help='HTTP method')
    parser.add_argument('--endpoint', help='API endpoint')
    parser.add_argument('--data', help='Request data (JSON)')
    parser.add_argument('--base-url', help='Base URL for API')
    parser.add_argument('--api-key', help='API key')
    parser.add_argument('--auth-type', choices=['none', 'api_key', 'basic', 'hmac'], default='none')
    
    args = parser.parse_args()
    api_manager = APIManager()
    
    if args.action == 'config':
        if not args.base_url:
            print("Error: base-url required for configuration")
            return
            
        success = api_manager.add_api_config(
            name=args.api_name,
            base_url=args.base_url,
            auth_type=args.auth_type,
            api_key=args.api_key
        )
        print(f"API configuration: {'Success' if success else 'Failed'}")
        
    elif args.action == 'request':
        if not all([args.method, args.endpoint]):
            print("Error: method and endpoint required for request")
            return
            
        data = None
        if args.data:
            try:
                data = json.loads(args.data)
            except json.JSONDecodeError:
                print("Error: Invalid JSON data")
                return
                
        result = api_manager.make_request(
            api_name=args.api_name,
            method=args.method,
            endpoint=args.endpoint,
            data=data
        )
        print(json.dumps(result, indent=2))
        
    elif args.action == 'health':
        result = api_manager.health_check(args.api_name)
        print(json.dumps(result, indent=2))
        
    elif args.action == 'status':
        result = api_manager.get_rate_limit_status(args.api_name)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main() 