"""
Grimm Integration - Webhook Management
Comprehensive webhook integration and management
"""

import requests
import json
import time
import hashlib
import hmac
import threading
from typing import Dict, List, Optional, Any, Callable
from datetime import datetime, timedelta
import logging
from urllib.parse import urlparse
import ssl
import certifi
from queue import Queue
import uuid


class WebhookEvent:
    """Webhook event data structure"""
    
    def __init__(self, 
                 event_type: str,
                 data: Dict,
                 source: str,
                 timestamp: Optional[datetime] = None,
                 event_id: Optional[str] = None):
        self.event_type = event_type
        self.data = data
        self.source = source
        self.timestamp = timestamp or datetime.utcnow()
        self.event_id = event_id or str(uuid.uuid4())
        
    def to_dict(self) -> Dict:
        """Convert to dictionary"""
        return {
            'event_id': self.event_id,
            'event_type': self.event_type,
            'data': self.data,
            'source': self.source,
            'timestamp': self.timestamp.isoformat()
        }
        
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict())


class WebhookManager:
    """Comprehensive webhook integration manager"""
    
    def __init__(self, config: Optional[Dict] = None):
        self.config = config or {}
        self.webhooks = {}
        self.event_handlers = {}
        self.logger = logging.getLogger('grimm.webhooks')
        self.session = requests.Session()
        self._setup_session()
        self.event_queue = Queue()
        self.processing_thread = None
        self.running = False
        
    def _setup_session(self):
        """Setup requests session"""
        self.session.headers.update({
            'User-Agent': self.config.get('default_user_agent', 'Grimm-Webhooks/1.0'),
            'Content-Type': 'application/json'
        })
        
        if self.config.get('enable_ssl_verification', True):
            self.session.verify = certifi.where()
        else:
            self.session.verify = False
            
        self.session.timeout = self.config.get('webhook_timeout', 30)
        
    def register_webhook(self,
                        name: str,
                        url: str,
                        events: List[str],
                        secret: Optional[str] = None,
                        headers: Optional[Dict] = None,
                        retry_attempts: Optional[int] = None,
                        retry_delay: Optional[int] = None,
                        timeout: Optional[int] = None) -> bool:
        """Register a webhook endpoint"""
        try:
            # Validate URL
            parsed_url = urlparse(url)
            if not parsed_url.scheme or not parsed_url.netloc:
                raise ValueError("Invalid webhook URL")
                
            webhook_config = {
                'url': url,
                'events': events,
                'secret': secret,
                'headers': headers or {},
                'retry_attempts': retry_attempts or self.config.get('webhook_retry_attempts', 3),
                'retry_delay': retry_delay or self.config.get('webhook_retry_delay', 5),
                'timeout': timeout or self.config.get('webhook_timeout', 30),
                'enabled': True,
                'created_at': datetime.utcnow(),
                'last_sent': None,
                'success_count': 0,
                'failure_count': 0
            }
            
            self.webhooks[name] = webhook_config
            
            # Start processing thread if not running
            if not self.running:
                self._start_processing()
                
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to register webhook {name}: {e}")
            return False
            
    def unregister_webhook(self, name: str) -> bool:
        """Unregister a webhook endpoint"""
        if name in self.webhooks:
            del self.webhooks[name]
            return True
        return False
        
    def register_event_handler(self, event_type: str, handler: Callable) -> bool:
        """Register an event handler"""
        try:
            if event_type not in self.event_handlers:
                self.event_handlers[event_type] = []
            self.event_handlers[event_type].append(handler)
            return True
        except Exception as e:
            self.logger.error(f"Failed to register event handler for {event_type}: {e}")
            return False
            
    def trigger_event(self, event_type: str, data: Dict, source: str = 'grimm') -> bool:
        """Trigger a webhook event"""
        try:
            event = WebhookEvent(event_type, data, source)
            
            # Add to processing queue
            self.event_queue.put(event)
            
            # Log event
            if self.config.get('log_integration_events', True):
                self.logger.info(f"Event triggered: {event_type} from {source}")
                
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to trigger event {event_type}: {e}")
            return False
            
    def _start_processing(self):
        """Start webhook processing thread"""
        if self.running:
            return
            
        self.running = True
        self.processing_thread = threading.Thread(target=self._process_events, daemon=True)
        self.processing_thread.start()
        
    def _process_events(self):
        """Process webhook events in background thread"""
        while self.running:
            try:
                # Get event from queue with timeout
                try:
                    event = self.event_queue.get(timeout=1)
                except:
                    continue
                    
                # Process event
                self._send_webhook_event(event)
                
            except Exception as e:
                self.logger.error(f"Error processing webhook events: {e}")
                
    def _send_webhook_event(self, event: WebhookEvent):
        """Send webhook event to registered endpoints"""
        event_data = event.to_dict()
        
        for name, webhook in self.webhooks.items():
            if not webhook['enabled']:
                continue
                
            # Check if webhook handles this event type
            if event.event_type not in webhook['events']:
                continue
                
            # Send webhook
            success = self._send_single_webhook(name, webhook, event_data)
            
            # Update statistics
            if success:
                webhook['success_count'] += 1
            else:
                webhook['failure_count'] += 1
            webhook['last_sent'] = datetime.utcnow()
            
    def _send_single_webhook(self, name: str, webhook: Dict, event_data: Dict) -> bool:
        """Send webhook to a single endpoint with retry logic"""
        headers = webhook['headers'].copy()
        
        # Add signature if secret is provided
        if webhook['secret']:
            signature = self._generate_signature(event_data, webhook['secret'])
            headers['X-Webhook-Signature'] = signature
            
        # Add event metadata
        headers['X-Event-Type'] = event_data['event_type']
        headers['X-Event-ID'] = event_data['event_id']
        headers['X-Source'] = event_data['source']
        
        for attempt in range(webhook['retry_attempts']):
            try:
                response = self.session.post(
                    webhook['url'],
                    json=event_data,
                    headers=headers,
                    timeout=webhook['timeout']
                )
                
                if response.status_code < 400:
                    self.logger.info(f"Webhook {name} sent successfully (attempt {attempt + 1})")
                    return True
                else:
                    self.logger.warning(f"Webhook {name} failed with status {response.status_code}")
                    
            except requests.exceptions.Timeout:
                self.logger.warning(f"Webhook {name} timeout (attempt {attempt + 1})")
            except requests.exceptions.ConnectionError:
                self.logger.warning(f"Webhook {name} connection error (attempt {attempt + 1})")
            except Exception as e:
                self.logger.error(f"Webhook {name} error: {e}")
                
            # Wait before retry
            if attempt < webhook['retry_attempts'] - 1:
                time.sleep(webhook['retry_delay'])
                
        return False
        
    def _generate_signature(self, data: Dict, secret: str) -> str:
        """Generate HMAC signature for webhook data"""
        payload = json.dumps(data, sort_keys=True)
        signature = hmac.new(
            secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()
        return f"sha256={signature}"
        
    def verify_signature(self, payload: str, signature: str, secret: str) -> bool:
        """Verify webhook signature"""
        try:
            expected_signature = self._generate_signature(json.loads(payload), secret)
            return hmac.compare_digest(signature, expected_signature)
        except:
            return False
            
    def get_webhook_status(self, name: str) -> Optional[Dict]:
        """Get webhook status and statistics"""
        if name not in self.webhooks:
            return None
            
        webhook = self.webhooks[name]
        return {
            'name': name,
            'url': webhook['url'],
            'enabled': webhook['enabled'],
            'events': webhook['events'],
            'created_at': webhook['created_at'].isoformat(),
            'last_sent': webhook['last_sent'].isoformat() if webhook['last_sent'] else None,
            'success_count': webhook['success_count'],
            'failure_count': webhook['failure_count'],
            'success_rate': (webhook['success_count'] / (webhook['success_count'] + webhook['failure_count']) * 100) 
                           if (webhook['success_count'] + webhook['failure_count']) > 0 else 0
        }
        
    def get_all_webhooks(self) -> List[Dict]:
        """Get all webhook configurations"""
        return [self.get_webhook_status(name) for name in self.webhooks.keys()]
        
    def enable_webhook(self, name: str) -> bool:
        """Enable a webhook"""
        if name in self.webhooks:
            self.webhooks[name]['enabled'] = True
            return True
        return False
        
    def disable_webhook(self, name: str) -> bool:
        """Disable a webhook"""
        if name in self.webhooks:
            self.webhooks[name]['enabled'] = False
            return True
        return False
        
    def test_webhook(self, name: str, test_data: Optional[Dict] = None) -> Dict:
        """Test a webhook endpoint"""
        if name not in self.webhooks:
            return {'success': False, 'error': 'Webhook not found'}
            
        webhook = self.webhooks[name]
        test_event = WebhookEvent(
            event_type='test',
            data=test_data or {'message': 'Test webhook from Grimm'},
            source='grimm-test'
        )
        
        success = self._send_single_webhook(name, webhook, test_event.to_dict())
        return {
            'success': success,
            'webhook_name': name,
            'url': webhook['url']
        }
        
    def cleanup_old_events(self, days: int = 30) -> int:
        """Clean up old webhook events (placeholder for future implementation)"""
        # This would clean up stored events if we implement event storage
        return 0


def main():
    """CLI interface for webhook management"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grimm Webhook Manager CLI')
    parser.add_argument('action', choices=['register', 'unregister', 'trigger', 'status', 'test'])
    parser.add_argument('--name', required=True, help='Webhook name')
    parser.add_argument('--url', help='Webhook URL')
    parser.add_argument('--events', nargs='+', help='Event types')
    parser.add_argument('--secret', help='Webhook secret')
    parser.add_argument('--event-type', help='Event type to trigger')
    parser.add_argument('--data', help='Event data (JSON)')
    parser.add_argument('--source', default='grimm-cli', help='Event source')
    
    args = parser.parse_args()
    webhook_manager = WebhookManager()
    
    if args.action == 'register':
        if not all([args.url, args.events]):
            print("Error: url and events required for registration")
            return
            
        success = webhook_manager.register_webhook(
            name=args.name,
            url=args.url,
            events=args.events,
            secret=args.secret
        )
        print(f"Webhook registration: {'Success' if success else 'Failed'}")
        
    elif args.action == 'unregister':
        success = webhook_manager.unregister_webhook(args.name)
        print(f"Webhook unregistration: {'Success' if success else 'Failed'}")
        
    elif args.action == 'trigger':
        if not all([args.event_type, args.data]):
            print("Error: event-type and data required for triggering")
            return
            
        try:
            data = json.loads(args.data)
        except json.JSONDecodeError:
            print("Error: Invalid JSON data")
            return
            
        success = webhook_manager.trigger_event(
            event_type=args.event_type,
            data=data,
            source=args.source
        )
        print(f"Event trigger: {'Success' if success else 'Failed'}")
        
    elif args.action == 'status':
        status = webhook_manager.get_webhook_status(args.name)
        if status:
            print(json.dumps(status, indent=2))
        else:
            print("Webhook not found")
            
    elif args.action == 'test':
        result = webhook_manager.test_webhook(args.name)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main() 