#!/usr/bin/env python3
"""
Test Script for TuskLang Integration with Grim
Tests all aspects of the integration including API endpoints
"""

import asyncio
import json
import sys
import time
from pathlib import Path
from typing import Dict, Any

# Add the project root to the path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from grim_core.tusktsk import get_tusk_integration, get_tusk_api, GrimTuskIntegration
from grim_web.tusktsk_routes import router
from fastapi.testclient import TestClient
from grim_web.app import app


class TuskLangIntegrationTester:
    """Comprehensive tester for TuskLang integration"""
    
    def __init__(self):
        self.tusk_integration = get_tusk_integration()
        self.tusk_api = get_tusk_api()
        self.client = TestClient(app)
        self.test_results = []
    
    def log_test(self, test_name: str, success: bool, details: str = ""):
        """Log test result"""
        result = {
            'test': test_name,
            'success': success,
            'details': details,
            'timestamp': time.time()
        }
        self.test_results.append(result)
        
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}")
        if details:
            print(f"   Details: {details}")
        print()
    
    def test_tusk_availability(self):
        """Test if TuskLang SDK is available"""
        try:
            status = self.tusk_integration.get_tusk_status()
            available = status.get('available', False)
            self.log_test(
                "TuskLang SDK Availability",
                available,
                f"Status: {status}"
            )
            return available
        except Exception as e:
            self.log_test(
                "TuskLang SDK Availability",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_tusk_initialization(self):
        """Test TuskLang initialization"""
        try:
            status = self.tusk_integration.get_tusk_status()
            initialized = status.get('initialized', False)
            self.log_test(
                "TuskLang Initialization",
                initialized,
                f"Initialized: {initialized}, Peanut loaded: {status.get('peanut_loaded', False)}"
            )
            return initialized
        except Exception as e:
            self.log_test(
                "TuskLang Initialization",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_config_operations(self):
        """Test configuration operations"""
        try:
            # Test setting a value
            success = self.tusk_integration.set_tusk_config('test', 'key', 'value')
            if not success:
                self.log_test("Config Set Operation", False, "Failed to set config value")
                return False
            
            # Test getting the value
            value = self.tusk_integration.get_tusk_config('test', 'key')
            success = value == 'value'
            self.log_test(
                "Config Get/Set Operations",
                success,
                f"Set: True, Get: {value}"
            )
            return success
        except Exception as e:
            self.log_test(
                "Config Get/Set Operations",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_section_operations(self):
        """Test section operations"""
        try:
            # Test setting a section
            test_section = {
                'key1': 'value1',
                'key2': 'value2',
                'key3': 123
            }
            
            for key, value in test_section.items():
                self.tusk_integration.set_tusk_config('test_section', key, value)
            
            # Test getting the section
            section = self.tusk_integration.get_tusk_section('test_section')
            success = section is not None and all(
                section.get(key) == value for key, value in test_section.items()
            )
            
            self.log_test(
                "Section Operations",
                success,
                f"Section data: {section}"
            )
            return success
        except Exception as e:
            self.log_test(
                "Section Operations",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_database_config(self):
        """Test database configuration retrieval"""
        try:
            db_config = self.tusk_integration.get_database_config()
            success = isinstance(db_config, dict) and 'type' in db_config
            self.log_test(
                "Database Config Retrieval",
                success,
                f"Config: {db_config}"
            )
            return success
        except Exception as e:
            self.log_test(
                "Database Config Retrieval",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_security_config(self):
        """Test security configuration retrieval"""
        try:
            security_config = self.tusk_integration.get_security_config()
            success = isinstance(security_config, dict)
            self.log_test(
                "Security Config Retrieval",
                success,
                f"Config keys: {list(security_config.keys()) if security_config else 'None'}"
            )
            return success
        except Exception as e:
            self.log_test(
                "Security Config Retrieval",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_ui_config(self):
        """Test UI configuration retrieval"""
        try:
            ui_config = self.tusk_integration.get_ui_config()
            success = isinstance(ui_config, dict)
            self.log_test(
                "UI Config Retrieval",
                success,
                f"Config: {ui_config}"
            )
            return success
        except Exception as e:
            self.log_test(
                "UI Config Retrieval",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_api_endpoints(self):
        """Test API endpoints"""
        try:
            # Test status endpoint
            response = self.client.get("/tusktsk/status")
            success = response.status_code == 200
            self.log_test(
                "API Status Endpoint",
                success,
                f"Status code: {response.status_code}"
            )
            
            # Test health endpoint
            response = self.client.get("/tusktsk/health")
            success = response.status_code == 200
            self.log_test(
                "API Health Endpoint",
                success,
                f"Status code: {response.status_code}"
            )
            
            # Test config endpoint
            response = self.client.get("/tusktsk/config/test")
            success = response.status_code == 200
            self.log_test(
                "API Config Endpoint",
                success,
                f"Status code: {response.status_code}"
            )
            
            return True
        except Exception as e:
            self.log_test(
                "API Endpoints",
                False,
                f"Error: {e}"
            )
            return False
    
    def test_async_operations(self):
        """Test async operations"""
        async def test_async():
            try:
                # Test async config get
                result = await self.tusk_api.get_config('test', 'key')
                success = isinstance(result, dict) and 'value' in result
                self.log_test(
                    "Async Config Get",
                    success,
                    f"Result: {result}"
                )
                
                # Test async config set
                result = await self.tusk_api.set_config('test', 'async_key', 'async_value')
                success = isinstance(result, dict) and result.get('success', False)
                self.log_test(
                    "Async Config Set",
                    success,
                    f"Result: {result}"
                )
                
                return True
            except Exception as e:
                self.log_test(
                    "Async Operations",
                    False,
                    f"Error: {e}"
                )
                return False
        
        return asyncio.run(test_async())
    
    def run_all_tests(self):
        """Run all tests"""
        print("🧪 Running TuskLang Integration Tests")
        print("=" * 50)
        
        tests = [
            ("TuskLang SDK Availability", self.test_tusk_availability),
            ("TuskLang Initialization", self.test_tusk_initialization),
            ("Config Operations", self.test_config_operations),
            ("Section Operations", self.test_section_operations),
            ("Database Config", self.test_database_config),
            ("Security Config", self.test_security_config),
            ("UI Config", self.test_ui_config),
            ("API Endpoints", self.test_api_endpoints),
            ("Async Operations", self.test_async_operations),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            try:
                if test_func():
                    passed += 1
            except Exception as e:
                self.log_test(test_name, False, f"Test failed with exception: {e}")
        
        print("=" * 50)
        print(f"📊 Test Results: {passed}/{total} tests passed")
        
        # Save results
        results_file = project_root / "test_results.json"
        with open(results_file, 'w') as f:
            json.dump({
                'summary': {
                    'passed': passed,
                    'total': total,
                    'timestamp': time.time()
                },
                'results': self.test_results
            }, f, indent=2)
        
        print(f"📄 Results saved to: {results_file}")
        
        return passed == total


def main():
    """Main test runner"""
    tester = TuskLangIntegrationTester()
    success = tester.run_all_tests()
    
    if success:
        print("🎉 All tests passed! TuskLang integration is working correctly.")
        sys.exit(0)
    else:
        print("⚠️  Some tests failed. Check the results above for details.")
        sys.exit(1)


if __name__ == "__main__":
    main() 