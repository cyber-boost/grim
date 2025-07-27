"""
Usage tracking and enforcement system
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from .tier_manager import TierManager

logger = logging.getLogger(__name__)

class UsageTracker:
    """Real-time usage tracking and limit enforcement"""
    
    def __init__(self, tier_manager: TierManager):
        self.tier_manager = tier_manager
        self.real_time_cache = {}  # In-memory cache for real-time tracking
        
    def track_command_execution(self, user_id: str, command: str) -> Dict[str, Any]:
        """Track command execution and check limits"""
        try:
            # Check command access first
            user_tier = self._get_user_tier(user_id)
            allowed, message = self.tier_manager.check_command_access(command, user_tier)
            
            if not allowed:
                return {
                    "allowed": False,
                    "message": message,
                    "user_tier": user_tier,
                    "command": command
                }
            
            # Get current command usage
            current_usage = self._get_current_usage(user_id, "commands_per_day")
            
            # Check usage limits
            limit_allowed, limit_result = self.tier_manager.check_usage_limits(
                user_id, user_tier, "commands_per_day", current_usage
            )
            
            if not limit_allowed:
                return {
                    "allowed": False,
                    "message": limit_result.get("upgrade_message", "Usage limit exceeded"),
                    "user_tier": user_tier,
                    "command": command,
                    "usage_info": limit_result
                }
            
            # Track usage
            self._increment_usage(user_id, "commands_per_day")
            self.tier_manager.track_usage(user_id, "commands_per_day")
            
            return {
                "allowed": True,
                "message": "Command execution allowed",
                "user_tier": user_tier,
                "command": command,
                "usage_info": limit_result
            }
            
        except Exception as e:
            logger.error(f"Error tracking command execution: {e}")
            return {
                "allowed": False,
                "message": f"Error tracking execution: {str(e)}",
                "user_tier": "FREE",
                "command": command
            }
    
    def track_storage_usage(self, user_id: str, size_gb: float) -> Dict[str, Any]:
        """Track storage usage and check limits"""
        try:
            user_tier = self._get_user_tier(user_id)
            current_usage = self._get_current_usage(user_id, "storage_gb")
            new_total = current_usage + size_gb
            
            # Check usage limits
            allowed, result = self.tier_manager.check_usage_limits(
                user_id, user_tier, "storage_gb", int(new_total)
            )
            
            if not allowed:
                return {
                    "allowed": False,
                    "message": result.get("upgrade_message", "Storage limit exceeded"),
                    "user_tier": user_tier,
                    "current_usage": current_usage,
                    "requested_size": size_gb,
                    "usage_info": result
                }
            
            # Track usage
            self._increment_usage(user_id, "storage_gb", size_gb)
            self.tier_manager.track_usage(user_id, "storage_gb", int(size_gb))
            
            return {
                "allowed": True,
                "message": "Storage allocation allowed",
                "user_tier": user_tier,
                "current_usage": new_total,
                "usage_info": result
            }
            
        except Exception as e:
            logger.error(f"Error tracking storage usage: {e}")
            return {
                "allowed": False,
                "message": f"Error tracking storage: {str(e)}",
                "user_tier": "FREE",
                "current_usage": 0
            }
    
    def track_api_call(self, user_id: str) -> Dict[str, Any]:
        """Track API call and check hourly limits"""
        try:
            user_tier = self._get_user_tier(user_id)
            current_usage = self._get_current_usage(user_id, "api_calls_per_hour")
            
            # Check usage limits
            allowed, result = self.tier_manager.check_usage_limits(
                user_id, user_tier, "api_calls_per_hour", current_usage + 1
            )
            
            if not allowed:
                return {
                    "allowed": False,
                    "message": result.get("upgrade_message", "API call limit exceeded"),
                    "user_tier": user_tier,
                    "current_usage": current_usage,
                    "usage_info": result
                }
            
            # Track usage
            self._increment_usage(user_id, "api_calls_per_hour")
            
            return {
                "allowed": True,
                "message": "API call allowed",
                "user_tier": user_tier,
                "current_usage": current_usage + 1,
                "usage_info": result
            }
            
        except Exception as e:
            logger.error(f"Error tracking API call: {e}")
            return {
                "allowed": False,
                "message": f"Error tracking API call: {str(e)}",
                "user_tier": "FREE",
                "current_usage": 0
            }
    
    def track_alert(self, user_id: str) -> Dict[str, Any]:
        """Track alert creation and check daily limits"""
        try:
            user_tier = self._get_user_tier(user_id)
            current_usage = self._get_current_usage(user_id, "alerts_per_day")
            
            # Check usage limits
            allowed, result = self.tier_manager.check_usage_limits(
                user_id, user_tier, "alerts_per_day", current_usage + 1
            )
            
            if not allowed:
                return {
                    "allowed": False,
                    "message": result.get("upgrade_message", "Alert limit exceeded"),
                    "user_tier": user_tier,
                    "current_usage": current_usage,
                    "usage_info": result
                }
            
            # Track usage
            self._increment_usage(user_id, "alerts_per_day")
            self.tier_manager.track_usage(user_id, "alerts_per_day")
            
            return {
                "allowed": True,
                "message": "Alert creation allowed",
                "user_tier": user_tier,
                "current_usage": current_usage + 1,
                "usage_info": result
            }
            
        except Exception as e:
            logger.error(f"Error tracking alert: {e}")
            return {
                "allowed": False,
                "message": f"Error tracking alert: {str(e)}",
                "user_tier": "FREE",
                "current_usage": 0
            }
    
    def get_real_time_usage(self, user_id: str) -> Dict[str, Any]:
        """Get real-time usage statistics"""
        try:
            user_tier = self._get_user_tier(user_id)
            
            usage_stats = {}
            for usage_type in ["commands_per_day", "storage_gb", "api_calls_per_hour", "alerts_per_day"]:
                current_usage = self._get_current_usage(user_id, usage_type)
                allowed, result = self.tier_manager.check_usage_limits(
                    user_id, user_tier, usage_type, current_usage
                )
                
                usage_stats[usage_type] = {
                    "current_usage": current_usage,
                    "limit": result.get("limit", 0),
                    "remaining": result.get("remaining", 0),
                    "allowed": allowed
                }
            
            return {
                "user_id": user_id,
                "user_tier": user_tier,
                "usage_stats": usage_stats,
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting real-time usage: {e}")
            return {"error": f"Error getting usage: {str(e)}"}
    
    def generate_usage_warnings(self, user_id: str) -> List[str]:
        """Generate usage warnings for user"""
        try:
            warnings = []
            user_tier = self._get_user_tier(user_id)
            
            # Check each usage type
            for usage_type in ["commands_per_day", "storage_gb", "api_calls_per_hour", "alerts_per_day"]:
                current_usage = self._get_current_usage(user_id, usage_type)
                allowed, result = self.tier_manager.check_usage_limits(
                    user_id, user_tier, usage_type, current_usage
                )
                
                if not allowed:
                    warnings.append(f"{usage_type}: {result.get('upgrade_message', 'Limit exceeded')}")
                elif result.get("remaining", 0) < result.get("limit", 0) * 0.1:  # Less than 10% remaining
                    warnings.append(f"{usage_type}: Approaching limit ({result.get('remaining', 0)} remaining)")
            
            return warnings
            
        except Exception as e:
            logger.error(f"Error generating usage warnings: {e}")
            return [f"Error generating warnings: {str(e)}"]
    
    def _get_user_tier(self, user_id: str) -> str:
        """Get user tier from database or cache"""
        if self.tier_manager.db_manager:
            users = self.tier_manager.db_manager.execute_query(
                "SELECT tier FROM users WHERE user_id = ?",
                (user_id,)
            )
            if users:
                return users[0]['tier']
        return "FREE"
    
    def _get_current_usage(self, user_id: str, usage_type: str) -> int:
        """Get current usage from cache or database"""
        cache_key = f"{user_id}_{usage_type}_{datetime.now().date().isoformat()}"
        
        if cache_key in self.real_time_cache:
            return self.real_time_cache[cache_key]
        
        # Get from database
        if self.tier_manager.db_manager:
            usage_records = self.tier_manager.db_manager.execute_query(
                "SELECT amount FROM user_usage WHERE user_id = ? AND usage_type = ? AND date = ?",
                (user_id, usage_type, datetime.now().date().isoformat())
            )
            if usage_records:
                usage = usage_records[0]['amount']
                self.real_time_cache[cache_key] = usage
                return usage
        
        return 0
    
    def _increment_usage(self, user_id: str, usage_type: str, amount: float = 1):
        """Increment usage in cache"""
        cache_key = f"{user_id}_{usage_type}_{datetime.now().date().isoformat()}"
        
        if cache_key in self.real_time_cache:
            self.real_time_cache[cache_key] += amount
        else:
            self.real_time_cache[cache_key] = amount
    
    def clear_cache(self):
        """Clear real-time cache"""
        self.real_time_cache.clear()
        logger.info("Real-time usage cache cleared")
    
    def cleanup_old_cache(self):
        """Clean up old cache entries"""
        today = datetime.now().date().isoformat()
        old_keys = [key for key in self.real_time_cache.keys() if not key.endswith(today)]
        
        for key in old_keys:
            del self.real_time_cache[key]
        
        if old_keys:
            logger.info(f"Cleaned up {len(old_keys)} old cache entries") 