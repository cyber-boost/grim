"""
CLI wrapper for tier management integration
"""

#!/bin/bash

import os
import sys
import json
import logging
from typing import Dict, Any, Optional, List
try:
    from .tier_manager import TierManager
except ImportError:
    from tier_manager import TierManager

logger = logging.getLogger(__name__)

class TierCLIWrapper:
    """CLI wrapper for tier management integration with grim_throne.sh"""
    
    def __init__(self, db_manager=None):
        self.tier_manager = TierManager(db_manager)
        self.config_file = os.path.expanduser("~/.scythe/tier_config.json")
        self.load_config()
    
    def load_config(self):
        """Load tier configuration"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.config = json.load(f)
            else:
                self.config = {
                    "default_tier": "FREE",
                    "enforce_limits": True,
                    "track_usage": True,
                    "show_warnings": True
                }
                self.save_config()
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            self.config = {"default_tier": "FREE", "enforce_limits": True}
    
    def save_config(self):
        """Save tier configuration"""
        try:
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving config: {e}")
    
    def get_user_tier(self, user_id: str) -> str:
        """Get user tier with proper fallback chain"""
        try:
            # 1. Try API first (with caching)
            api_tier = self.tier_manager.get_user_tier_from_api(user_id)
            if api_tier:
                return api_tier
            
            # 2. Try GRIMS_MOTHER PostgreSQL database
            grims_mother_tier = self.tier_manager.get_user_tier_from_grims_mother(user_id)
            if grims_mother_tier:
                return grims_mother_tier
            
            # 3. Fallback to local database
            if self.tier_manager.db_manager:
                users = self.tier_manager.db_manager.execute_query(
                    "SELECT tier FROM users WHERE user_id = ?",
                    (user_id,)
                )
                if users:
                    return users[0]['tier']
            
            # 4. Final fallback to config default
            return self.config.get("default_tier", "FREE")
            
        except Exception as e:
            logger.error(f"Error getting user tier: {e}")
            return "FREE"
    
    def check_command_access(self, command: str, user_id: str) -> Dict[str, Any]:
        """Check command access and return result"""
        try:
            user_tier = self.get_user_tier(user_id)
            allowed, message = self.tier_manager.check_command_access(command, user_tier)
            
            result = {
                "allowed": allowed,
                "message": message,
                "user_tier": user_tier,
                "command": command
            }
            
            # Track usage if enabled
            if self.config.get("track_usage", True) and allowed:
                self.tier_manager.track_usage(user_id, "commands_per_day")
                # Sync usage to API (background, don't block)
                try:
                    self.tier_manager.sync_usage_to_api(user_id, {
                        "command": command,
                        "timestamp": datetime.now().isoformat(),
                        "success": True
                    })
                except Exception as e:
                    logger.debug(f"Usage sync failed (non-critical): {e}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error checking command access: {e}")
            return {
                "allowed": False,
                "message": f"Error checking access: {str(e)}",
                "user_tier": "FREE",
                "command": command
            }
    
    def check_usage_limits(self, user_id: str, usage_type: str, current_usage: int) -> Dict[str, Any]:
        """Check usage limits and return result"""
        try:
            user_tier = self.get_user_tier(user_id)
            allowed, result = self.tier_manager.check_usage_limits(user_id, user_tier, usage_type, current_usage)
            
            result["user_tier"] = user_tier
            result["usage_type"] = usage_type
            
            return result
            
        except Exception as e:
            logger.error(f"Error checking usage limits: {e}")
            return {
                "allowed": False,
                "error": f"Error checking limits: {str(e)}",
                "user_tier": "FREE",
                "usage_type": usage_type
            }
    
    def generate_upgrade_message(self, current_tier: str, required_tier: str) -> str:
        """Generate upgrade message"""
        return self.tier_manager.generate_upgrade_message(current_tier, required_tier)
    
    def get_available_commands(self, user_id: str) -> List[str]:
        """Get available commands for user"""
        try:
            user_tier = self.get_user_tier(user_id)
            return self.tier_manager.get_available_commands(user_tier)
        except Exception as e:
            logger.error(f"Error getting available commands: {e}")
            return []
    
    def get_user_usage(self, user_id: str, usage_type: str = None) -> Dict[str, Any]:
        """Get user usage statistics"""
        try:
            return self.tier_manager.get_user_usage(user_id, usage_type)
        except Exception as e:
            logger.error(f"Error getting user usage: {e}")
            return {"error": f"Error getting usage: {str(e)}"}

def main():
    """Main CLI entry point"""
    if len(sys.argv) < 3:
        print("Usage: tier_check.py <command> <user_id> [usage_type] [current_usage]")
        sys.exit(1)
    
    command = sys.argv[1]
    user_id = sys.argv[2]
    
    wrapper = TierCLIWrapper()
    
    if command == "check_access":
        if len(sys.argv) < 4:
            print("Usage: tier_check.py check_access <user_id> <command>")
            sys.exit(1)
        
        cmd = sys.argv[3]
        result = wrapper.check_command_access(cmd, user_id)
        print(json.dumps(result))
        
    elif command == "check_limits":
        if len(sys.argv) < 6:
            print("Usage: tier_check.py check_limits <user_id> <usage_type> <current_usage>")
            sys.exit(1)
        
        usage_type = sys.argv[3]
        current_usage = int(sys.argv[4])
        result = wrapper.check_usage_limits(user_id, usage_type, current_usage)
        print(json.dumps(result))
        
    elif command == "get_commands":
        commands = wrapper.get_available_commands(user_id)
        print(json.dumps({"commands": commands}))
        
    elif command == "get_usage":
        usage_type = sys.argv[3] if len(sys.argv) > 3 else None
        result = wrapper.get_user_usage(user_id, usage_type)
        print(json.dumps(result))
        
    elif command == "upgrade_message":
        if len(sys.argv) < 5:
            print("Usage: tier_check.py upgrade_message <current_tier> <required_tier>")
            sys.exit(1)
        
        current_tier = sys.argv[3]
        required_tier = sys.argv[4]
        message = wrapper.generate_upgrade_message(current_tier, required_tier)
        print(json.dumps({"message": message}))
        
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main() 