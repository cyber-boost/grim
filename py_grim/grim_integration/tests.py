#!/usr/bin/env python3
"""
Grim Integration Testing Framework

Comprehensive end-to-end testing for Python and Go components integration.
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import unittest
from unittest.mock import patch, MagicMock

# Add the project root to the path
sys.path.insert(0, str(Path(__file__).parent.parent))

from grim_core.config import Config
from grim_core.database import DatabaseManager
from grim_core.logger import Logger
from grim_backup import BackupManager

@dataclass
class TestResult:
    """Test result container"""
    name: str
    status: str  # 'PASS', 'FAIL', 'SKIP'
    duration: float
    error: Optional[str] = None
    details: Optional[Dict] = None

class IntegrationTestSuite:
    """Comprehensive integration testing suite"""
    
    def __init__(self, config_path: Optional[str] = None):
        self.config = Config(config_path) if config_path else Config()
        self.logger = Logger("integration_tests")
        self.results: List[TestResult] = []
        self.test_data_dir = Path(tempfile.mkdtemp(prefix="grim_test_"))
        self.go_compression_bin = Path("/opt/grim/go_grim/build/grim-compression")
        
        # Ensure test data directory exists
        self.test_data_dir.mkdir(parents=True, exist_ok=True)
        
        self.logger.info(f"Integration test suite initialized with test data dir: {self.test_data_dir}")
    
    def setup_test_environment(self) -> bool:
        """Setup test environment and dependencies"""
        try:
            # Create test database
            self.db_manager = DatabaseManager(self.config)
            self.db_manager.initialize_database()
            
            # Create test backup manager
            self.backup_manager = BackupManager(self.config)
            
            # Check if Go compression binary exists
            if not self.go_compression_bin.exists():
                self.logger.warning(f"Go compression binary not found at {self.go_compression_bin}")
                self.logger.info("Skipping Go compression tests")
                return False
            
            # Generate test data
            self._generate_test_data()
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to setup test environment: {e}")
            return False
    
    def _generate_test_data(self):
        """Generate various test data files"""
        # Text file
        text_data = "This is a test file for integration testing.\n" * 1000
        (self.test_data_dir / "test.txt").write_text(text_data)
        
        # JSON file
        json_data = {
            "test": True,
            "data": list(range(1000)),
            "nested": {"key": "value", "array": [1, 2, 3, 4, 5]}
        }
        (self.test_data_dir / "test.json").write_text(json.dumps(json_data, indent=2))
        
        # Binary file
        binary_data = bytes([i % 256 for i in range(1024 * 1024)])  # 1MB
        (self.test_data_dir / "test.bin").write_bytes(binary_data)
        
        # Log file
        log_data = "\n".join([f"Log entry {i}: Test message" for i in range(1000)])
        (self.test_data_dir / "test.log").write_text(log_data)
        
        self.logger.info(f"Generated test data in {self.test_data_dir}")
    
    def run_all_tests(self) -> Dict[str, List[TestResult]]:
        """Run all integration tests"""
        self.logger.info("Starting comprehensive integration test suite")
        
        test_categories = {
            "core": self._run_core_tests(),
            "database": self._run_database_tests(),
            "backup": self._run_backup_tests(),
            "compression": self._run_compression_tests(),
            "web": self._run_web_tests(),
            "performance": self._run_performance_tests(),
            "integration": self._run_integration_tests()
        }
        
        # Generate summary
        self._generate_test_summary(test_categories)
        
        return test_categories
    
    def _run_core_tests(self) -> List[TestResult]:
        """Test core Python components"""
        results = []
        
        # Test configuration loading
        start_time = time.time()
        try:
            config = Config()
            assert config is not None
            assert hasattr(config, 'database_url')
            results.append(TestResult(
                name="Config Loading",
                status="PASS",
                duration=time.time() - start_time
            ))
        except Exception as e:
            results.append(TestResult(
                name="Config Loading",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        # Test logger initialization
        start_time = time.time()
        try:
            logger = Logger("test_logger")
            logger.info("Test log message")
            results.append(TestResult(
                name="Logger Initialization",
                status="PASS",
                duration=time.time() - start_time
            ))
        except Exception as e:
            results.append(TestResult(
                name="Logger Initialization",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _run_database_tests(self) -> List[TestResult]:
        """Test database operations"""
        results = []
        
        # Test database connection
        start_time = time.time()
        try:
            db = DatabaseManager(self.config)
            db.initialize_database()
            
            # Test basic operations
            with db.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                assert result[0] == 1
            
            results.append(TestResult(
                name="Database Connection",
                status="PASS",
                duration=time.time() - start_time
            ))
        except Exception as e:
            results.append(TestResult(
                name="Database Connection",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        # Test backup table operations
        start_time = time.time()
        try:
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO backups (filename, size, checksum, created_at)
                    VALUES (?, ?, ?, ?)
                """, ("test_backup.tar.gz", 1024, "test_checksum", time.time()))
                conn.commit()
                
                cursor.execute("SELECT COUNT(*) FROM backups WHERE filename = ?", ("test_backup.tar.gz",))
                count = cursor.fetchone()[0]
                assert count == 1
            
            results.append(TestResult(
                name="Database Operations",
                status="PASS",
                duration=time.time() - start_time
            ))
        except Exception as e:
            results.append(TestResult(
                name="Database Operations",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _run_backup_tests(self) -> List[TestResult]:
        """Test backup system integration"""
        results = []
        
        # Test backup creation
        start_time = time.time()
        try:
            test_file = self.test_data_dir / "test.txt"
            backup_path = self.backup_manager.create_backup([str(test_file)])
            
            assert backup_path.exists()
            assert backup_path.stat().st_size > 0
            
            results.append(TestResult(
                name="Backup Creation",
                status="PASS",
                duration=time.time() - start_time,
                details={"backup_size": backup_path.stat().st_size}
            ))
        except Exception as e:
            results.append(TestResult(
                name="Backup Creation",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        # Test backup restoration
        start_time = time.time()
        try:
            if 'backup_path' in locals():
                restore_dir = self.test_data_dir / "restored"
                restore_dir.mkdir(exist_ok=True)
                
                self.backup_manager.restore_backup(backup_path, str(restore_dir))
                
                restored_file = restore_dir / "test.txt"
                assert restored_file.exists()
                assert restored_file.read_text() == (self.test_data_dir / "test.txt").read_text()
                
                results.append(TestResult(
                    name="Backup Restoration",
                    status="PASS",
                    duration=time.time() - start_time
                ))
        except Exception as e:
            results.append(TestResult(
                name="Backup Restoration",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _run_compression_tests(self) -> List[TestResult]:
        """Test Go compression engine integration"""
        results = []
        
        if not self.go_compression_bin.exists():
            results.append(TestResult(
                name="Go Compression Engine",
                status="SKIP",
                duration=0.0,
                error="Go compression binary not found"
            ))
            return results
        
        # Test compression algorithms
        algorithms = ["gzip", "zstd", "snappy", "brotli"]
        test_file = self.test_data_dir / "test.txt"
        
        for algorithm in algorithms:
            start_time = time.time()
            try:
                # Compress
                compressed_file = test_file.with_suffix(f".{algorithm}")
                result = subprocess.run([
                    str(self.go_compression_bin),
                    "-input", str(test_file),
                    "-algorithm", algorithm,
                    "-output", str(compressed_file),
                    "-json"
                ], capture_output=True, text=True, check=True)
                
                # Parse JSON result
                compression_result = json.loads(result.stdout)
                
                # Decompress
                decompressed_file = compressed_file.with_suffix(".decompressed")
                subprocess.run([
                    str(self.go_compression_bin),
                    "-input", str(compressed_file),
                    "-algorithm", algorithm,
                    "-decompress",
                    "-output", str(decompressed_file),
                    "-json"
                ], capture_output=True, text=True, check=True)
                
                # Verify integrity
                original_content = test_file.read_bytes()
                decompressed_content = decompressed_file.read_bytes()
                assert original_content == decompressed_content
                
                results.append(TestResult(
                    name=f"Compression {algorithm.upper()}",
                    status="PASS",
                    duration=time.time() - start_time,
                    details={
                        "compression_ratio": compression_result.get("compression_ratio", 0),
                        "compression_speed": compression_result.get("compression_speed", 0)
                    }
                ))
                
            except Exception as e:
                results.append(TestResult(
                    name=f"Compression {algorithm.upper()}",
                    status="FAIL",
                    duration=time.time() - start_time,
                    error=str(e)
                ))
        
        # Test benchmarking
        start_time = time.time()
        try:
            result = subprocess.run([
                str(self.go_compression_bin),
                "-benchmark",
                "-iterations", "2",
                "-json"
            ], capture_output=True, text=True, check=True)
            
            benchmark_results = json.loads(result.stdout)
            assert len(benchmark_results) > 0
            
            results.append(TestResult(
                name="Compression Benchmarking",
                status="PASS",
                duration=time.time() - start_time,
                details={"benchmark_count": len(benchmark_results)}
            ))
            
        except Exception as e:
            results.append(TestResult(
                name="Compression Benchmarking",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _run_web_tests(self) -> List[TestResult]:
        """Test web framework integration"""
        results = []
        
        # Test FastAPI app initialization
        start_time = time.time()
        try:
            from grim_web.app import app
            assert app is not None
            
            # Test health check endpoint
            from fastapi.testclient import TestClient
            client = TestClient(app)
            
            response = client.get("/health")
            assert response.status_code == 200
            assert response.json()["status"] == "healthy"
            
            results.append(TestResult(
                name="Web Framework Health Check",
                status="PASS",
                duration=time.time() - start_time
            ))
            
        except Exception as e:
            results.append(TestResult(
                name="Web Framework Health Check",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        # Test API endpoints
        start_time = time.time()
        try:
            from fastapi.testclient import TestClient
            from grim_web.app import app
            
            client = TestClient(app)
            
            # Test metrics endpoint
            response = client.get("/metrics")
            assert response.status_code == 200
            
            # Test API info endpoint
            response = client.get("/api/v1/info")
            assert response.status_code == 200
            
            results.append(TestResult(
                name="Web API Endpoints",
                status="PASS",
                duration=time.time() - start_time
            ))
            
        except Exception as e:
            results.append(TestResult(
                name="Web API Endpoints",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _run_performance_tests(self) -> List[TestResult]:
        """Test performance characteristics"""
        results = []
        
        # Test database performance
        start_time = time.time()
        try:
            with self.db_manager.get_connection() as conn:
                cursor = conn.cursor()
                
                # Insert performance test
                start_insert = time.time()
                for i in range(100):
                    cursor.execute("""
                        INSERT INTO backups (filename, size, checksum, created_at)
                        VALUES (?, ?, ?, ?)
                    """, (f"perf_test_{i}.tar.gz", i * 1024, f"checksum_{i}", time.time()))
                
                conn.commit()
                insert_time = time.time() - start_insert
                
                # Query performance test
                start_query = time.time()
                cursor.execute("SELECT COUNT(*) FROM backups WHERE filename LIKE 'perf_test_%'")
                count = cursor.fetchone()[0]
                query_time = time.time() - start_query
                
                assert count == 100
                
                results.append(TestResult(
                    name="Database Performance",
                    status="PASS",
                    duration=time.time() - start_time,
                    details={
                        "insert_time": insert_time,
                        "query_time": query_time,
                        "records_inserted": 100
                    }
                ))
                
        except Exception as e:
            results.append(TestResult(
                name="Database Performance",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        # Test backup performance
        start_time = time.time()
        try:
            large_file = self.test_data_dir / "large_test.bin"
            # Create a larger test file
            large_file.write_bytes(bytes([i % 256 for i in range(10 * 1024 * 1024)]))  # 10MB
            
            backup_start = time.time()
            backup_path = self.backup_manager.create_backup([str(large_file)])
            backup_time = time.time() - backup_start
            
            assert backup_path.exists()
            
            results.append(TestResult(
                name="Backup Performance",
                status="PASS",
                duration=time.time() - start_time,
                details={
                    "backup_time": backup_time,
                    "file_size_mb": large_file.stat().st_size / (1024 * 1024),
                    "backup_size_mb": backup_path.stat().st_size / (1024 * 1024)
                }
            ))
            
        except Exception as e:
            results.append(TestResult(
                name="Backup Performance",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _run_integration_tests(self) -> List[TestResult]:
        """Test end-to-end integration scenarios"""
        results = []
        
        # Test complete backup workflow with compression
        start_time = time.time()
        try:
            # Create test files
            test_files = [
                self.test_data_dir / "integration_test1.txt",
                self.test_data_dir / "integration_test2.json",
                self.test_data_dir / "integration_test3.bin"
            ]
            
            for i, test_file in enumerate(test_files):
                test_file.write_text(f"Integration test data {i + 1}")
            
            # Create backup
            backup_path = self.backup_manager.create_backup([str(f) for f in test_files])
            assert backup_path.exists()
            
            # Compress backup using Go engine
            if self.go_compression_bin.exists():
                compressed_backup = backup_path.with_suffix(".zstd")
                subprocess.run([
                    str(self.go_compression_bin),
                    "-input", str(backup_path),
                    "-algorithm", "zstd",
                    "-output", str(compressed_backup)
                ], check=True)
                
                assert compressed_backup.exists()
                
                # Verify compression ratio
                original_size = backup_path.stat().st_size
                compressed_size = compressed_backup.stat().st_size
                compression_ratio = compressed_size / original_size
                
                results.append(TestResult(
                    name="End-to-End Backup Workflow",
                    status="PASS",
                    duration=time.time() - start_time,
                    details={
                        "original_size_mb": original_size / (1024 * 1024),
                        "compressed_size_mb": compressed_size / (1024 * 1024),
                        "compression_ratio": compression_ratio
                    }
                ))
            else:
                results.append(TestResult(
                    name="End-to-End Backup Workflow",
                    status="SKIP",
                    duration=time.time() - start_time,
                    error="Go compression binary not available"
                ))
                
        except Exception as e:
            results.append(TestResult(
                name="End-to-End Backup Workflow",
                status="FAIL",
                duration=time.time() - start_time,
                error=str(e)
            ))
        
        return results
    
    def _generate_test_summary(self, test_categories: Dict[str, List[TestResult]]):
        """Generate comprehensive test summary"""
        total_tests = 0
        passed_tests = 0
        failed_tests = 0
        skipped_tests = 0
        total_duration = 0.0
        
        print("\n" + "="*80)
        print("GRIM INTEGRATION TEST SUMMARY")
        print("="*80)
        
        for category, results in test_categories.items():
            print(f"\n{category.upper()} TESTS:")
            print("-" * 40)
            
            category_passed = 0
            category_failed = 0
            category_skipped = 0
            category_duration = 0.0
            
            for result in results:
                total_tests += 1
                category_duration += result.duration
                total_duration += result.duration
                
                status_icon = {
                    "PASS": "✅",
                    "FAIL": "❌",
                    "SKIP": "⏭️"
                }.get(result.status, "❓")
                
                print(f"  {status_icon} {result.name:<30} {result.duration:.3f}s")
                
                if result.status == "PASS":
                    passed_tests += 1
                    category_passed += 1
                elif result.status == "FAIL":
                    failed_tests += 1
                    category_failed += 1
                    if result.error:
                        print(f"      Error: {result.error}")
                elif result.status == "SKIP":
                    skipped_tests += 1
                    category_skipped += 1
                
                if result.details:
                    for key, value in result.details.items():
                        print(f"      {key}: {value}")
            
            print(f"  Category: {category_passed} passed, {category_failed} failed, {category_skipped} skipped ({category_duration:.3f}s)")
        
        print("\n" + "="*80)
        print("OVERALL SUMMARY:")
        print(f"  Total Tests: {total_tests}")
        print(f"  Passed: {passed_tests} ✅")
        print(f"  Failed: {failed_tests} ❌")
        print(f"  Skipped: {skipped_tests} ⏭️")
        print(f"  Success Rate: {(passed_tests/total_tests*100):.1f}%" if total_tests > 0 else "  Success Rate: 0%")
        print(f"  Total Duration: {total_duration:.3f}s")
        print("="*80)
        
        # Save detailed results to file
        summary_file = Path("integration_test_results.json")
        summary_data = {
            "timestamp": time.time(),
            "summary": {
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "failed_tests": failed_tests,
                "skipped_tests": skipped_tests,
                "success_rate": (passed_tests/total_tests*100) if total_tests > 0 else 0,
                "total_duration": total_duration
            },
            "categories": {
                category: [
                    {
                        "name": result.name,
                        "status": result.status,
                        "duration": result.duration,
                        "error": result.error,
                        "details": result.details
                    }
                    for result in results
                ]
                for category, results in test_categories.items()
            }
        }
        
        summary_file.write_text(json.dumps(summary_data, indent=2))
        print(f"\nDetailed results saved to: {summary_file}")
    
    def cleanup(self):
        """Cleanup test environment"""
        try:
            import shutil
            shutil.rmtree(self.test_data_dir, ignore_errors=True)
            self.logger.info("Test environment cleaned up")
        except Exception as e:
            self.logger.error(f"Failed to cleanup test environment: {e}")

def main():
    """Main entry point for integration tests"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grim Integration Test Suite")
    parser.add_argument("--config", help="Path to configuration file")
    parser.add_argument("--category", choices=["core", "database", "backup", "compression", "web", "performance", "integration", "all"], 
                       default="all", help="Test category to run")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose output")
    
    args = parser.parse_args()
    
    # Setup logging
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)
    
    # Initialize test suite
    test_suite = IntegrationTestSuite(args.config)
    
    try:
        # Setup environment
        if not test_suite.setup_test_environment():
            print("❌ Failed to setup test environment")
            sys.exit(1)
        
        # Run tests
        if args.category == "all":
            results = test_suite.run_all_tests()
        else:
            # Run specific category
            method_name = f"_run_{args.category}_tests"
            if hasattr(test_suite, method_name):
                method = getattr(test_suite, method_name)
                category_results = method()
                results = {args.category: category_results}
                test_suite._generate_test_summary(results)
            else:
                print(f"❌ Unknown test category: {args.category}")
                sys.exit(1)
        
        # Check for failures
        total_failures = sum(
            sum(1 for result in category_results if result.status == "FAIL")
            for category_results in results.values()
        )
        
        if total_failures > 0:
            print(f"\n❌ Integration tests failed with {total_failures} failures")
            sys.exit(1)
        else:
            print("\n✅ All integration tests passed!")
            
    except KeyboardInterrupt:
        print("\n⚠️  Integration tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Integration tests failed with error: {e}")
        sys.exit(1)
    finally:
        test_suite.cleanup()

if __name__ == "__main__":
    main() 