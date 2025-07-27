"""
Webhook utilities for Scythe API
"""

import requests
import json
import hmac
import hashlib
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional
from concurrent.futures import ThreadPoolExecutor
import threading

logger = logging.getLogger(__name__)

class WebhookManager:
    """Manages webhook delivery and retries"""
    
    def __init__(self, db_manager):
        self.db_manager = db_manager
        self.executor = ThreadPoolExecutor(max_workers=10)
        self.session = requests.Session()
        self.session.timeout = 30
    
    def send_webhook(self, event_type: str, payload: Dict[str, Any], webhook_url: str, secret: str) -> bool:
        """Send webhook to a specific URL"""
        try:
            # Add timestamp and event type
            webhook_data = {
                'event': event_type,
                'timestamp': datetime.utcnow().isoformat(),
                'data': payload
            }
            
            # Create signature
            signature = self._create_signature(webhook_data, secret)
            
            # Prepare headers
            headers = {
                'Content-Type': 'application/json',
                'User-Agent': 'Scythe-API/1.0',
                'X-Scythe-Signature': signature,
                'X-Scythe-Event': event_type
            }
            
            # Send webhook
            response = self.session.post(
                webhook_url,
                json=webhook_data,
                headers=headers
            )
            
            if response.status_code in [200, 201, 202]:
                logger.info(f"Webhook sent successfully to {webhook_url} for event {event_type}")
                return True
            else:
                logger.warning(f"Webhook failed for {webhook_url}: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending webhook to {webhook_url}: {e}")
            return False
    
    def _create_signature(self, data: Dict[str, Any], secret: str) -> str:
        """Create HMAC signature for webhook data"""
        payload = json.dumps(data, separators=(',', ':'))
        signature = hmac.new(
            secret.encode('utf-8'),
            payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        return f"sha256={signature}"
    
    def send_event_webhooks(self, event_type: str, payload: Dict[str, Any]) -> None:
        """Send webhooks for a specific event type to all registered webhooks"""
        try:
            # Get webhooks for this event type
            webhooks = self.db_manager.execute_query(
                "SELECT * FROM webhooks WHERE enabled = 1 AND events LIKE ?",
                (f'%{event_type}%',)
            )
            
            if not webhooks:
                logger.debug(f"No webhooks registered for event {event_type}")
                return
            
            # Send webhooks asynchronously
            for webhook in webhooks:
                self.executor.submit(
                    self.send_webhook,
                    event_type,
                    payload,
                    webhook['url'],
                    webhook['secret']
                )
                
        except Exception as e:
            logger.error(f"Error sending event webhooks for {event_type}: {e}")
    
    def send_storage_webhook(self, operation: str, user_id: str, file_path: str, file_size: int, provider: str):
        """Send storage operation webhook"""
        payload = {
            'operation': operation,
            'user_id': user_id,
            'file_path': file_path,
            'file_size': file_size,
            'provider': provider
        }
        self.send_event_webhooks('storage.operation', payload)
    
    def send_license_webhook(self, operation: str, license_key: str, user_id: str, status: str):
        """Send license operation webhook"""
        payload = {
            'operation': operation,
            'license_key': license_key[:8] + '...',  # Mask full key
            'user_id': user_id,
            'status': status
        }
        self.send_event_webhooks('license.operation', payload)
    
    def send_payment_webhook(self, operation: str, user_id: str, amount: float, currency: str, status: str):
        """Send payment operation webhook"""
        payload = {
            'operation': operation,
            'user_id': user_id,
            'amount': amount,
            'currency': currency,
            'status': status
        }
        self.send_event_webhooks('payment.operation', payload)
    
    def send_vendor_webhook(self, operation: str, vendor_id: int, vendor_name: str, commission_rate: float):
        """Send vendor operation webhook"""
        payload = {
            'operation': operation,
            'vendor_id': vendor_id,
            'vendor_name': vendor_name,
            'commission_rate': commission_rate
        }
        self.send_event_webhooks('vendor.operation', payload)
    
    def send_product_webhook(self, operation: str, product_id: int, product_name: str, price: float):
        """Send product operation webhook"""
        payload = {
            'operation': operation,
            'product_id': product_id,
            'product_name': product_name,
            'price': price
        }
        self.send_event_webhooks('product.operation', payload)
    
    def send_error_webhook(self, error_type: str, error_message: str, context: str = None, user_id: str = None):
        """Send error notification webhook"""
        payload = {
            'error_type': error_type,
            'error_message': error_message,
            'context': context,
            'user_id': user_id
        }
        self.send_event_webhooks('system.error', payload)
    
    def register_webhook(self, url: str, events: List[str], secret: str) -> int:
        """Register a new webhook"""
        try:
            query = '''
                INSERT INTO webhooks (url, events, secret)
                VALUES (?, ?, ?)
            '''
            conn = self.db_manager.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, (url, ','.join(events), secret))
            webhook_id = cursor.lastrowid
            conn.commit()
            conn.close()
            
            logger.info(f"Webhook registered: {url} for events: {events}")
            return webhook_id
            
        except Exception as e:
            logger.error(f"Error registering webhook: {e}")
            raise
    
    def unregister_webhook(self, webhook_id: int) -> bool:
        """Unregister a webhook"""
        try:
            self.db_manager.execute_query(
                "DELETE FROM webhooks WHERE id = ?",
                (webhook_id,)
            )
            logger.info(f"Webhook unregistered: {webhook_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error unregistering webhook: {e}")
            return False
    
    def test_webhook(self, webhook_id: int) -> bool:
        """Test a webhook by sending a test event"""
        try:
            webhooks = self.db_manager.execute_query(
                "SELECT * FROM webhooks WHERE id = ?",
                (webhook_id,)
            )
            
            if not webhooks:
                return False
            
            webhook = webhooks[0]
            
            # Send test payload
            test_payload = {
                'test': True,
                'message': 'This is a test webhook from Scythe API',
                'webhook_id': webhook_id
            }
            
            return self.send_webhook(
                'test',
                test_payload,
                webhook['url'],
                webhook['secret']
            )
            
        except Exception as e:
            logger.error(f"Error testing webhook: {e}")
            return False
    
    def get_webhook_stats(self) -> Dict[str, Any]:
        """Get webhook statistics"""
        try:
            webhooks = self.db_manager.execute_query("SELECT * FROM webhooks")
            
            stats = {
                'total_webhooks': len(webhooks),
                'enabled_webhooks': len([w for w in webhooks if w['enabled']]),
                'events': {}
            }
            
            # Count events
            for webhook in webhooks:
                events = webhook['events'].split(',')
                for event in events:
                    event = event.strip()
                    stats['events'][event] = stats['events'].get(event, 0) + 1
            
            return stats
            
        except Exception as e:
            logger.error(f"Error getting webhook stats: {e}")
            return {}
    
    def cleanup(self):
        """Cleanup resources"""
        self.executor.shutdown(wait=True)
        self.session.close() 