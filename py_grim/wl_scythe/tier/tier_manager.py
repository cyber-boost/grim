"""
Tier Manager for access control and usage limits
"""

import logging
import json
import os
import time
import requests
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
from enum import Enum

logger = logging.getLogger(__name__)

class Tier(Enum):
    FREE = "FREE"
    PRO = "PRO"
    MASTER = "MASTER"
    REAPER = "REAPER"

class TierManager:
    """Manages tier-based access control and usage limits"""
    
    def __init__(self, db_manager=None):
        self.db_manager = db_manager
        
        # API configuration with local caching
        self.api_base_url = os.getenv('GRIM_API_BASE_URL', 'https://rip.grim.so/grim')
        self.grims_mother_url = os.getenv('GRIMS_MOTHER')  # PostgreSQL connection
        self.cache_dir = os.path.expanduser("~/.scythe/cache")
        self.cache_duration = 300  # 5 minutes cache
        self.api_timeout = 10  # 10 seconds timeout
        
        # Ensure cache directory exists
        os.makedirs(self.cache_dir, exist_ok=True)
        
        # Command tier mapping - clean and organized
        self.command_tiers = {
            # FREE tier commands (15)
            'help': Tier.FREE, 'version': Tier.FREE, 'status': Tier.FREE,
            'config': Tier.FREE, 'config-show': Tier.FREE, 'config-set': Tier.FREE,
            'config-reset': Tier.FREE, 'report': Tier.FREE, 'report-status': Tier.FREE,
            'report-basic': Tier.FREE, 'audit': Tier.FREE, 'audit-basic': Tier.FREE,
            'cleanup': Tier.FREE, 'cleanup-temp': Tier.FREE, 'compress': Tier.FREE,
            
            # PRO tier commands (35 total)
            'optimize': Tier.PRO, 'optimize-all': Tier.PRO, 'heal': Tier.PRO,
            'heal-basic': Tier.PRO, 'compress-advanced': Tier.PRO, 'decompress': Tier.PRO,
            'report-detailed': Tier.PRO, 'report-performance': Tier.PRO,
            'audit-security': Tier.PRO, 'audit-performance': Tier.PRO,
            'cleanup-advanced': Tier.PRO, 'cleanup-orphaned': Tier.PRO,
            'backup': Tier.PRO, 'backup-create': Tier.PRO, 'backup-list': Tier.PRO,
            'backup-restore': Tier.PRO, 'monitor': Tier.PRO, 'monitor-start': Tier.PRO,
            'monitor-stop': Tier.PRO, 'monitor-status': Tier.PRO,
            'ai-analyze': Tier.PRO, 'ai-analyze-basic': Tier.PRO,
            'ai-train': Tier.PRO, 'ai-train-basic': Tier.PRO,
            'ai-predict': Tier.PRO, 'ai-predict-basic': Tier.PRO,
            'deploy': Tier.PRO, 'deploy-test': Tier.PRO, 'deploy-staging': Tier.PRO,
            'build': Tier.PRO, 'build-basic': Tier.PRO, 'test': Tier.PRO,
            'test-basic': Tier.PRO, 'validate': Tier.PRO, 'validate-basic': Tier.PRO,
            
            # MASTER tier commands (60 total)
            'optimize-advanced': Tier.MASTER, 'optimize-custom': Tier.MASTER,
            'heal-advanced': Tier.MASTER, 'heal-custom': Tier.MASTER,
            'compress-custom': Tier.MASTER, 'decompress-advanced': Tier.MASTER,
            'report-custom': Tier.MASTER, 'report-analytics': Tier.MASTER,
            'audit-custom': Tier.MASTER, 'audit-compliance': Tier.MASTER,
            'cleanup-custom': Tier.MASTER, 'backup-advanced': Tier.MASTER,
            'backup-scheduled': Tier.MASTER, 'backup-encrypted': Tier.MASTER,
            'monitor-advanced': Tier.MASTER, 'monitor-custom': Tier.MASTER,
            'monitor-alerts': Tier.MASTER, 'ai-analyze-advanced': Tier.MASTER,
            'ai-analyze-custom': Tier.MASTER, 'ai-train-advanced': Tier.MASTER,
            'ai-train-custom': Tier.MASTER, 'ai-predict-advanced': Tier.MASTER,
            'ai-predict-custom': Tier.MASTER, 'deploy-production': Tier.MASTER,
            'deploy-advanced': Tier.MASTER, 'deploy-custom': Tier.MASTER,
            'build-advanced': Tier.MASTER, 'build-custom': Tier.MASTER,
            'test-advanced': Tier.MASTER, 'test-custom': Tier.MASTER,
            'validate-advanced': Tier.MASTER, 'validate-custom': Tier.MASTER,
            'emergency': Tier.MASTER, 'emergency-stop': Tier.MASTER,
            'emergency-recovery': Tier.MASTER, 'emergency-backup': Tier.MASTER,
            'emergency-restore': Tier.MASTER,
            
            # REAPER tier commands (200+ total) - using patterns for efficiency
            'optimize-enterprise': Tier.REAPER, 'optimize-cluster': Tier.REAPER,
            'heal-enterprise': Tier.REAPER, 'heal-cluster': Tier.REAPER,
            'compress-enterprise': Tier.REAPER, 'compress-cluster': Tier.REAPER,
            'decompress-enterprise': Tier.REAPER, 'decompress-cluster': Tier.REAPER,
            'report-enterprise': Tier.REAPER, 'report-cluster': Tier.REAPER,
            'audit-enterprise': Tier.REAPER, 'audit-cluster': Tier.REAPER,
            'cleanup-enterprise': Tier.REAPER, 'cleanup-cluster': Tier.REAPER,
            'backup-enterprise': Tier.REAPER, 'backup-cluster': Tier.REAPER,
            'monitor-enterprise': Tier.REAPER, 'monitor-cluster': Tier.REAPER,
            'ai-analyze-enterprise': Tier.REAPER, 'ai-analyze-cluster': Tier.REAPER,
            'ai-train-enterprise': Tier.REAPER, 'ai-train-cluster': Tier.REAPER,
            'ai-predict-enterprise': Tier.REAPER, 'ai-predict-cluster': Tier.REAPER,
            'deploy-enterprise': Tier.REAPER, 'deploy-cluster': Tier.REAPER,
            'build-enterprise': Tier.REAPER, 'build-cluster': Tier.REAPER,
            'test-enterprise': Tier.REAPER, 'test-cluster': Tier.REAPER,
            'validate-enterprise': Tier.REAPER, 'validate-cluster': Tier.REAPER,
            'emergency-enterprise': Tier.REAPER, 'emergency-cluster': Tier.REAPER,
            'admin': Tier.REAPER, 'admin-users': Tier.REAPER, 'admin-system': Tier.REAPER,
            'admin-security': Tier.REAPER, 'admin-audit': Tier.REAPER,
            'admin-backup': Tier.REAPER, 'admin-restore': Tier.REAPER,
            'admin-monitor': Tier.REAPER, 'admin-ai': Tier.REAPER,
            'admin-deploy': Tier.REAPER, 'admin-build': Tier.REAPER,
            'admin-test': Tier.REAPER, 'admin-validate': Tier.REAPER,
            'admin-emergency': Tier.REAPER, 'admin-config': Tier.REAPER,
            'admin-report': Tier.REAPER, 'admin-cleanup': Tier.REAPER,
            'admin-compress': Tier.REAPER, 'admin-heal': Tier.REAPER,
            'admin-optimize': Tier.REAPER
        }
        
        # Usage limits configuration
        
        # Local cache for API responses
        self._cache = {}
        self.usage_limits = {
            Tier.FREE: {
                'storage_gb': 1,
                'api_calls_per_hour': 100,
                'file_size_mb': 10,
                'alerts_per_day': 5,
                'commands_per_day': 50
            },
            Tier.PRO: {
                'storage_gb': 10,
                'api_calls_per_hour': 500,
                'file_size_mb': 100,
                'alerts_per_day': 25,
                'commands_per_day': 200
            },
            Tier.MASTER: {
                'storage_gb': 100,
                'api_calls_per_hour': 2000,
                'file_size_mb': 500,
                'alerts_per_day': 100,
                'commands_per_day': 1000
            },
            Tier.REAPER: {
                'storage_gb': 1000,
                'api_calls_per_hour': 10000,
                'file_size_mb': 2000,
                'alerts_per_day': 500,
                'commands_per_day': 5000
            }
        }
        
        # Tier hierarchy for validation
        self.tier_hierarchy = {
            Tier.FREE: 1,
            Tier.PRO: 2,
            Tier.MASTER: 3,
            Tier.REAPER: 4
        }
    
    def check_command_access(self, command: str, user_tier: str) -> Tuple[bool, str]:
        """Check if user can access a command based on their tier"""
        try:
            # Get command tier requirement
            required_tier = self.command_tiers.get(command)
            if not required_tier:
                return False, f"Unknown command: {command}"
            
            # Get user tier enum
            try:
                user_tier_enum = Tier(user_tier.upper())
            except ValueError:
                return False, f"Invalid user tier: {user_tier}"
            
            # Check tier hierarchy
            if self.tier_hierarchy[user_tier_enum] >= self.tier_hierarchy[required_tier]:
                logger.info(f"Command access granted: {command} for tier {user_tier}")
                return True, "Access granted"
            else:
                upgrade_message = self.generate_upgrade_message(user_tier, required_tier.value)
                logger.warning(f"Command access denied: {command} for tier {user_tier}")
                return False, upgrade_message
                
        except Exception as e:
            logger.error(f"Error checking command access: {e}")
            return False, f"Error checking access: {str(e)}"
    
    def check_usage_limits(self, user_id: str, user_tier: str, 
                          usage_type: str, current_usage: int) -> Tuple[bool, Dict[str, Any]]:
        """Check if user has exceeded usage limits"""
        try:
            # Get user tier enum
            try:
                user_tier_enum = Tier(user_tier.upper())
            except ValueError:
                return False, {"error": f"Invalid user tier: {user_tier}"}
            
            # Get limits for user tier
            limits = self.usage_limits.get(user_tier_enum, {})
            limit_key = f"{usage_type}_per_day" if "per_day" in usage_type else usage_type
            
            if limit_key not in limits:
                return False, {"error": f"Unknown usage type: {usage_type}"}
            
            limit = limits[limit_key]
            
            # Check if usage exceeds limit
            if current_usage >= limit:
                overage = current_usage - limit
                overage_cost = self.calculate_overage_cost(user_tier_enum, usage_type, overage)
                
                result = {
                    "allowed": False,
                    "current_usage": current_usage,
                    "limit": limit,
                    "overage": overage,
                    "overage_cost": overage_cost,
                    "upgrade_message": self.generate_upgrade_message(user_tier, "PRO")
                }
                
                logger.warning(f"Usage limit exceeded: {usage_type} for user {user_id}")
                return False, result
            else:
                result = {
                    "allowed": True,
                    "current_usage": current_usage,
                    "limit": limit,
                    "remaining": limit - current_usage
                }
                
                logger.info(f"Usage within limits: {usage_type} for user {user_id}")
                return True, result
                
        except Exception as e:
            logger.error(f"Error checking usage limits: {e}")
            return False, {"error": f"Error checking limits: {str(e)}"}
    
    def generate_upgrade_message(self, current_tier: str, required_tier: str) -> str:
        """Generate upgrade message with pricing information"""
        pricing = {
            "PRO": {"monthly": 29.99, "yearly": 299.90},
            "MASTER": {"monthly": 99.99, "yearly": 999.90},
            "REAPER": {"monthly": 199.99, "yearly": 1999.90}
        }
        
        if required_tier in pricing:
            price = pricing[required_tier]
            return f"Upgrade to {required_tier} tier required. Pricing: ${price['monthly']}/month or ${price['yearly']}/year"
        else:
            return f"Upgrade to {required_tier} tier required"
    
    def calculate_overage_cost(self, tier: Tier, usage_type: str, overage: int) -> float:
        """Calculate overage cost based on tier and usage type"""
        overage_rates = {
            "storage_gb": {"FREE": 0.10, "PRO": 0.08, "MASTER": 0.05, "REAPER": 0.02},
            "api_calls_per_hour": {"FREE": 0.001, "PRO": 0.0008, "MASTER": 0.0005, "REAPER": 0.0002},
            "alerts_per_day": {"FREE": 0.01, "PRO": 0.008, "MASTER": 0.005, "REAPER": 0.002},
            "commands_per_day": {"FREE": 0.05, "PRO": 0.04, "MASTER": 0.025, "REAPER": 0.01}
        }
        
        rate = overage_rates.get(usage_type, {}).get(tier.value, 0.01)
        return round(overage * rate, 2)
    
    def track_usage(self, user_id: str, usage_type: str, amount: int = 1) -> bool:
        """Track user usage in database"""
        try:
            if not self.db_manager:
                logger.warning("No database manager available for usage tracking")
                return False
            
            # Insert or update usage record
            self.db_manager.execute_query(
                """INSERT INTO user_usage (user_id, usage_type, amount, date) 
                   VALUES (?, ?, ?, ?) 
                   ON CONFLICT(user_id, usage_type, date) 
                   DO UPDATE SET amount = amount + ?""",
                (user_id, usage_type, amount, datetime.now().date().isoformat(), amount)
            )
            
            logger.info(f"Usage tracked: {usage_type} for user {user_id}, amount: {amount}")
            return True
            
        except Exception as e:
            logger.error(f"Error tracking usage: {e}")
            return False
    
    def get_user_usage(self, user_id: str, usage_type: str = None, 
                      start_date: datetime = None, end_date: datetime = None) -> Dict[str, Any]:
        """Get user usage statistics"""
        try:
            if not self.db_manager:
                return {"error": "No database manager available"}
            
            query = "SELECT * FROM user_usage WHERE user_id = ?"
            params = [user_id]
            
            if usage_type:
                query += " AND usage_type = ?"
                params.append(usage_type)
            
            if start_date:
                query += " AND date >= ?"
                params.append(start_date.date().isoformat())
            
            if end_date:
                query += " AND date <= ?"
                params.append(end_date.date().isoformat())
            
            usage_records = self.db_manager.execute_query(query, tuple(params))
            
            # Calculate totals
            total_usage = {}
            for record in usage_records:
                usage_type = record['usage_type']
                if usage_type not in total_usage:
                    total_usage[usage_type] = 0
                total_usage[usage_type] += record['amount']
            
            return {
                "user_id": user_id,
                "usage_records": usage_records,
                "total_usage": total_usage,
                "period": {
                    "start_date": start_date.isoformat() if start_date else None,
                    "end_date": end_date.isoformat() if end_date else None
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting user usage: {e}")
            return {"error": f"Error getting usage: {str(e)}"}
    
    def validate_tier_hierarchy(self, from_tier: str, to_tier: str) -> bool:
        """Validate tier upgrade/downgrade hierarchy"""
        try:
            from_tier_enum = Tier(from_tier.upper())
            to_tier_enum = Tier(to_tier.upper())
            
            # Ensure proper hierarchy (can only upgrade or stay same)
            return self.tier_hierarchy[to_tier_enum] >= self.tier_hierarchy[from_tier_enum]
            
        except ValueError:
            return False
    
    def get_available_commands(self, user_tier: str) -> List[str]:
        """Get list of commands available to user tier"""
        try:
            user_tier_enum = Tier(user_tier.upper())
            available_commands = []
            
            for command, required_tier in self.command_tiers.items():
                if self.tier_hierarchy[user_tier_enum] >= self.tier_hierarchy[required_tier]:
                    available_commands.append(command)
            
            return sorted(available_commands)
            
        except ValueError:
            return []
    
    def get_tier_statistics(self) -> Dict[str, Any]:
        """Get tier usage statistics"""
        try:
            if not self.db_manager:
                return {"error": "No database manager available"}
            
            # Get command usage by tier
            command_stats = {}
            for tier in Tier:
                command_stats[tier.value] = {
                    "total_commands": len([cmd for cmd, t in self.command_tiers.items() if t == tier]),
                    "commands": [cmd for cmd, t in self.command_tiers.items() if t == tier]
                }
            
            # Get usage limits by tier
            limit_stats = {}
            for tier, limits in self.usage_limits.items():
                limit_stats[tier.value] = limits
            
            return {
                "command_statistics": command_stats,
                "usage_limits": limit_stats,
                "tier_hierarchy": {tier.value: level for tier, level in self.tier_hierarchy.items()}
            }
            
        except Exception as e:
            logger.error(f"Error getting tier statistics: {e}")
            return {"error": f"Error getting statistics: {str(e)}"}
    
    # =============================================================================
    # API INTEGRATION WITH LOCAL CACHING
    # =============================================================================
    
    def _get_cache_key(self, endpoint: str, params: Dict[str, Any] = None) -> str:
        """Generate cache key for API endpoint"""
        key = endpoint
        if params:
            key += "_" + json.dumps(params, sort_keys=True)
        return key
    
    def _get_cache_file(self, cache_key: str) -> str:
        """Get cache file path for key"""
        return os.path.join(self.cache_dir, f"{cache_key}.json")
    
    def _is_cache_valid(self, cache_file: str) -> bool:
        """Check if cache file is still valid"""
        if not os.path.exists(cache_file):
            return False
        
        # Check if cache is expired
        file_time = os.path.getmtime(cache_file)
        current_time = time.time()
        return (current_time - file_time) < self.cache_duration
    
    def _load_from_cache(self, cache_file: str) -> Optional[Dict[str, Any]]:
        """Load data from cache file"""
        try:
            if self._is_cache_valid(cache_file):
                with open(cache_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Error loading cache: {e}")
        return None
    
    def _save_to_cache(self, cache_file: str, data: Dict[str, Any]) -> bool:
        """Save data to cache file"""
        try:
            with open(cache_file, 'w') as f:
                json.dump(data, f)
            return True
        except Exception as e:
            logger.warning(f"Error saving cache: {e}")
            return False
    
    def _api_request(self, endpoint: str, params: Dict[str, Any] = None, 
                    method: str = "GET", data: Dict[str, Any] = None) -> Optional[Dict[str, Any]]:
        """Make API request with caching"""
        cache_key = self._get_cache_key(endpoint, params)
        cache_file = self._get_cache_file(cache_key)
        
        # Try to load from cache first
        cached_data = self._load_from_cache(cache_file)
        if cached_data:
            logger.debug(f"Using cached data for {endpoint}")
            return cached_data
        
        # Make API request if no valid cache
        try:
            url = f"{self.api_base_url}/{endpoint}"
            headers = {"Content-Type": "application/json"}
            
            if method.upper() == "GET":
                response = requests.get(url, params=params, headers=headers, timeout=self.api_timeout)
            else:
                response = requests.post(url, json=data, headers=headers, timeout=self.api_timeout)
            
            if response.status_code == 200:
                result = response.json()
                # Cache successful response
                self._save_to_cache(cache_file, result)
                logger.debug(f"API request successful for {endpoint}")
                return result
            else:
                logger.warning(f"API request failed for {endpoint}: {response.status_code}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.warning(f"API request error for {endpoint}: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error in API request for {endpoint}: {e}")
            return None
    
    def get_user_tier_from_api(self, user_id: str) -> Optional[str]:
        """Get user tier from API with caching"""
        result = self._api_request("tier/status", {"user_id": user_id})
        if result and "tier" in result:
            return result["tier"]
        return None
    
    def get_user_tier_from_grims_mother(self, user_id: str) -> Optional[str]:
        """Get user tier from GRIMS_MOTHER PostgreSQL database"""
        if not self.grims_mother_url:
            return None
            
        try:
            import psycopg2
            with psycopg2.connect(self.grims_mother_url) as conn:
                cursor = conn.cursor()
                
                # Try to find by license_key (user_id format: grim_<user_id>)
                cursor.execute("""
                    SELECT tier FROM licenses 
                    WHERE license_key = %s AND status = 'active'
                    ORDER BY created_at DESC LIMIT 1
                """, (user_id,))
                
                row = cursor.fetchone()
                if row:
                    return row[0].upper()  # Ensure uppercase for consistency
                
                # Also try by installation_id pattern
                cursor.execute("""
                    SELECT tier FROM licenses 
                    WHERE installation_id LIKE %s AND status = 'active'
                    ORDER BY created_at DESC LIMIT 1
                """, (f"%{user_id}%",))
                
                row = cursor.fetchone()
                if row:
                    return row[0].upper()  # Ensure uppercase for consistency
                    
                return None
                
        except Exception as e:
            logger.warning(f"Failed to get tier from GRIMS_MOTHER: {e}")
            return None
    
    def check_tier_upgrade_eligibility(self, user_id: str, target_tier: str) -> Dict[str, Any]:
        """Check if user can upgrade to target tier via API"""
        result = self._api_request("tier/upgrade", {"user_id": user_id, "target_tier": target_tier})
        if result:
            return result
        return {"eligible": False, "error": "API unavailable"}
    
    def sync_usage_to_api(self, user_id: str, usage_data: Dict[str, Any]) -> bool:
        """Sync usage data to API (no caching for writes)"""
        try:
            url = f"{self.api_base_url}/usage/sync"
            headers = {"Content-Type": "application/json"}
            
            response = requests.post(url, json={
                "user_id": user_id,
                "usage_data": usage_data,
                "timestamp": datetime.now().isoformat()
            }, headers=headers, timeout=self.api_timeout)
            
            return response.status_code == 200
            
        except Exception as e:
            logger.warning(f"Failed to sync usage to API: {e}")
            return False 