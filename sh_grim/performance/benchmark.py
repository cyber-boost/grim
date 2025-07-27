#!/usr/bin/env python3
"""
Grimm Performance Benchmarking Module
Comprehensive performance analysis and benchmarking for backup operations
"""

import os
import sys
import time
import psutil
import threading
import multiprocessing
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
import json
import logging
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed
import statistics

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class PerformanceMetrics:
    """Performance metrics data structure"""
    operation: str
    duration: float
    cpu_usage: float
    memory_usage: float
    io_read_bytes: int
    io_write_bytes: int
    throughput_mbps: float
    timestamp: datetime
    metadata: Dict[str, Any]

@dataclass
class BenchmarkResult:
    """Benchmark result data structure"""
    test_name: str
    iterations: int
    total_duration: float
    avg_duration: float
    min_duration: float
    max_duration: float
    std_deviation: float
    cpu_usage_avg: float
    memory_usage_avg: float
    throughput_avg: float
    results: List[PerformanceMetrics]
    timestamp: datetime

class PerformanceBenchmark:
    """Main performance benchmarking class"""
    
    def __init__(self, output_dir: str = "benchmarks"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Performance tracking
        self.metrics: List[PerformanceMetrics] = []
        self.benchmarks: List[BenchmarkResult] = []
        
        # System information
        self.system_info = self._get_system_info()
        
        logger.info("Performance benchmark initialized")
    
    def _get_system_info(self) -> Dict[str, Any]:
        """Get system information for benchmarking context"""
        return {
            "cpu_count": multiprocessing.cpu_count(),
            "cpu_freq": psutil.cpu_freq()._asdict() if psutil.cpu_freq() else {},
            "memory_total": psutil.virtual_memory().total,
            "disk_usage": psutil.disk_usage('/')._asdict(),
            "platform": sys.platform,
            "python_version": sys.version,
            "timestamp": datetime.now().isoformat()
        }
    
    def benchmark_backup_operation(self, source_path: str, iterations: int = 5) -> BenchmarkResult:
        """Benchmark backup operation performance"""
        logger.info(f"Benchmarking backup operation: {source_path}")
        
        results = []
        
        for i in range(iterations):
            logger.info(f"Iteration {i+1}/{iterations}")
            
            # Start monitoring
            start_time = time.time()
            start_cpu = psutil.cpu_percent(interval=0.1)
            start_memory = psutil.virtual_memory().used
            start_io = psutil.disk_io_counters()
            
            # Perform backup operation (simulated)
            self._simulate_backup_operation(source_path)
            
            # End monitoring
            end_time = time.time()
            end_cpu = psutil.cpu_percent(interval=0.1)
            end_memory = psutil.virtual_memory().used
            end_io = psutil.disk_io_counters()
            
            # Calculate metrics
            duration = end_time - start_time
            cpu_usage = (start_cpu + end_cpu) / 2
            memory_usage = end_memory - start_memory
            io_read = end_io.read_bytes - start_io.read_bytes if start_io and end_io else 0
            io_write = end_io.write_bytes - start_io.write_bytes if start_io and end_io else 0
            
            # Calculate throughput (MB/s)
            total_size = self._get_directory_size(source_path)
            throughput = (total_size / 1024 / 1024) / duration if duration > 0 else 0
            
            metrics = PerformanceMetrics(
                operation="backup",
                duration=duration,
                cpu_usage=cpu_usage,
                memory_usage=memory_usage,
                io_read_bytes=io_read,
                io_write_bytes=io_write,
                throughput_mbps=throughput,
                timestamp=datetime.now(),
                metadata={
                    "source_path": source_path,
                    "iteration": i + 1,
                    "total_size_bytes": total_size
                }
            )
            
            results.append(metrics)
        
        # Calculate statistics
        durations = [r.duration for r in results]
        cpu_usages = [r.cpu_usage for r in results]
        memory_usages = [r.memory_usage for r in results]
        throughputs = [r.throughput_mbps for r in results]
        
        benchmark_result = BenchmarkResult(
            test_name=f"backup_{Path(source_path).name}",
            iterations=iterations,
            total_duration=sum(durations),
            avg_duration=statistics.mean(durations),
            min_duration=min(durations),
            max_duration=max(durations),
            std_deviation=statistics.stdev(durations) if len(durations) > 1 else 0,
            cpu_usage_avg=statistics.mean(cpu_usages),
            memory_usage_avg=statistics.mean(memory_usages),
            throughput_avg=statistics.mean(throughputs),
            results=results,
            timestamp=datetime.now()
        )
        
        self.benchmarks.append(benchmark_result)
        return benchmark_result
    
    def benchmark_parallel_operations(self, operations: List[str], max_workers: int = None) -> BenchmarkResult:
        """Benchmark parallel operations performance"""
        logger.info(f"Benchmarking parallel operations with {len(operations)} operations")
        
        if max_workers is None:
            max_workers = min(len(operations), multiprocessing.cpu_count())
        
        start_time = time.time()
        start_cpu = psutil.cpu_percent(interval=0.1)
        start_memory = psutil.virtual_memory().used
        start_io = psutil.disk_io_counters()
        
        results = []
        
        # Execute operations in parallel
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_op = {
                executor.submit(self._simulate_operation, op): op 
                for op in operations
            }
            
            for future in as_completed(future_to_op):
                operation = future_to_op[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Operation {operation} failed: {e}")
        
        end_time = time.time()
        end_cpu = psutil.cpu_percent(interval=0.1)
        end_memory = psutil.virtual_memory().used
        end_io = psutil.disk_io_counters()
        
        # Calculate overall metrics
        duration = end_time - start_time
        cpu_usage = (start_cpu + end_cpu) / 2
        memory_usage = end_memory - start_memory
        io_read = end_io.read_bytes - start_io.read_bytes if start_io and end_io else 0
        io_write = end_io.write_bytes - start_io.write_bytes if start_io and end_io else 0
        
        overall_metrics = PerformanceMetrics(
            operation="parallel_operations",
            duration=duration,
            cpu_usage=cpu_usage,
            memory_usage=memory_usage,
            io_read_bytes=io_read,
            io_write_bytes=io_write,
            throughput_mbps=0,  # Not applicable for parallel operations
            timestamp=datetime.now(),
            metadata={
                "operations_count": len(operations),
                "max_workers": max_workers,
                "individual_results": len(results)
            }
        )
        
        benchmark_result = BenchmarkResult(
            test_name="parallel_operations",
            iterations=1,
            total_duration=duration,
            avg_duration=duration,
            min_duration=duration,
            max_duration=duration,
            std_deviation=0,
            cpu_usage_avg=cpu_usage,
            memory_usage_avg=memory_usage,
            throughput_avg=0,
            results=[overall_metrics],
            timestamp=datetime.now()
        )
        
        self.benchmarks.append(benchmark_result)
        return benchmark_result
    
    def benchmark_memory_usage(self, operation_func, *args, **kwargs) -> BenchmarkResult:
        """Benchmark memory usage for a specific operation"""
        logger.info("Benchmarking memory usage")
        
        results = []
        iterations = 5
        
        for i in range(iterations):
            # Force garbage collection
            import gc
            gc.collect()
            
            # Get initial memory state
            start_memory = psutil.virtual_memory().used
            start_time = time.time()
            
            # Execute operation
            operation_func(*args, **kwargs)
            
            # Get final memory state
            end_memory = psutil.virtual_memory().used
            end_time = time.time()
            
            # Calculate metrics
            duration = end_time - start_time
            memory_usage = end_memory - start_memory
            
            metrics = PerformanceMetrics(
                operation="memory_usage",
                duration=duration,
                cpu_usage=0,  # Not measured for memory benchmark
                memory_usage=memory_usage,
                io_read_bytes=0,
                io_write_bytes=0,
                throughput_mbps=0,
                timestamp=datetime.now(),
                metadata={
                    "iteration": i + 1,
                    "operation_name": operation_func.__name__
                }
            )
            
            results.append(metrics)
        
        # Calculate statistics
        durations = [r.duration for r in results]
        memory_usages = [r.memory_usage for r in results]
        
        benchmark_result = BenchmarkResult(
            test_name=f"memory_{operation_func.__name__}",
            iterations=iterations,
            total_duration=sum(durations),
            avg_duration=statistics.mean(durations),
            min_duration=min(durations),
            max_duration=max(durations),
            std_deviation=statistics.stdev(durations) if len(durations) > 1 else 0,
            cpu_usage_avg=0,
            memory_usage_avg=statistics.mean(memory_usages),
            throughput_avg=0,
            results=results,
            timestamp=datetime.now()
        )
        
        self.benchmarks.append(benchmark_result)
        return benchmark_result
    
    def benchmark_io_performance(self, file_path: str, operation: str = "read", size_mb: int = 100) -> BenchmarkResult:
        """Benchmark I/O performance"""
        logger.info(f"Benchmarking I/O performance: {operation} {size_mb}MB")
        
        results = []
        iterations = 5
        
        for i in range(iterations):
            start_time = time.time()
            start_io = psutil.disk_io_counters()
            
            if operation == "read":
                self._simulate_file_read(file_path, size_mb)
            elif operation == "write":
                self._simulate_file_write(file_path, size_mb)
            else:
                raise ValueError(f"Unsupported operation: {operation}")
            
            end_time = time.time()
            end_io = psutil.disk_io_counters()
            
            # Calculate metrics
            duration = end_time - start_time
            io_bytes = end_io.read_bytes - start_io.read_bytes if start_io and end_io else 0
            throughput = (size_mb * 1024 * 1024) / duration if duration > 0 else 0
            
            metrics = PerformanceMetrics(
                operation=f"io_{operation}",
                duration=duration,
                cpu_usage=0,
                memory_usage=0,
                io_read_bytes=io_bytes if operation == "read" else 0,
                io_write_bytes=io_bytes if operation == "write" else 0,
                throughput_mbps=throughput / (1024 * 1024),
                timestamp=datetime.now(),
                metadata={
                    "file_path": file_path,
                    "size_mb": size_mb,
                    "iteration": i + 1
                }
            )
            
            results.append(metrics)
        
        # Calculate statistics
        durations = [r.duration for r in results]
        throughputs = [r.throughput_mbps for r in results]
        
        benchmark_result = BenchmarkResult(
            test_name=f"io_{operation}_{size_mb}mb",
            iterations=iterations,
            total_duration=sum(durations),
            avg_duration=statistics.mean(durations),
            min_duration=min(durations),
            max_duration=max(durations),
            std_deviation=statistics.stdev(durations) if len(durations) > 1 else 0,
            cpu_usage_avg=0,
            memory_usage_avg=0,
            throughput_avg=statistics.mean(throughputs),
            results=results,
            timestamp=datetime.now()
        )
        
        self.benchmarks.append(benchmark_result)
        return benchmark_result
    
    def _simulate_backup_operation(self, source_path: str):
        """Simulate a backup operation for benchmarking"""
        # Simulate file scanning
        time.sleep(0.1)
        
        # Simulate file copying
        time.sleep(0.2)
        
        # Simulate compression
        time.sleep(0.1)
        
        # Simulate encryption
        time.sleep(0.1)
    
    def _simulate_operation(self, operation: str):
        """Simulate a generic operation for benchmarking"""
        time.sleep(0.1)  # Simulate work
        return f"Completed: {operation}"
    
    def _simulate_file_read(self, file_path: str, size_mb: int):
        """Simulate file read operation"""
        # Create test file if it doesn't exist
        test_file = Path(file_path)
        if not test_file.exists():
            test_file.parent.mkdir(parents=True, exist_ok=True)
            with open(test_file, 'wb') as f:
                f.write(b'0' * (size_mb * 1024 * 1024))
        
        # Simulate read operation
        with open(test_file, 'rb') as f:
            f.read()
    
    def _simulate_file_write(self, file_path: str, size_mb: int):
        """Simulate file write operation"""
        test_file = Path(file_path)
        test_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(test_file, 'wb') as f:
            f.write(b'0' * (size_mb * 1024 * 1024))
    
    def _get_directory_size(self, path: str) -> int:
        """Get directory size in bytes"""
        total_size = 0
        try:
            for dirpath, dirnames, filenames in os.walk(path):
                for filename in filenames:
                    filepath = os.path.join(dirpath, filename)
                    if os.path.exists(filepath):
                        total_size += os.path.getsize(filepath)
        except Exception as e:
            logger.warning(f"Could not calculate directory size for {path}: {e}")
            total_size = 1024 * 1024  # Default 1MB for simulation
        
        return total_size
    
    def generate_report(self, output_file: str = None) -> str:
        """Generate comprehensive performance report"""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = self.output_dir / f"performance_report_{timestamp}.json"
        
        report = {
            "system_info": self.system_info,
            "benchmarks": [asdict(benchmark) for benchmark in self.benchmarks],
            "summary": self._generate_summary(),
            "timestamp": datetime.now().isoformat()
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Performance report generated: {output_file}")
        return str(output_file)
    
    def _generate_summary(self) -> Dict[str, Any]:
        """Generate summary statistics"""
        if not self.benchmarks:
            return {}
        
        all_durations = []
        all_throughputs = []
        all_cpu_usage = []
        all_memory_usage = []
        
        for benchmark in self.benchmarks:
            all_durations.append(benchmark.avg_duration)
            all_throughputs.append(benchmark.throughput_avg)
            all_cpu_usage.append(benchmark.cpu_usage_avg)
            all_memory_usage.append(benchmark.memory_usage_avg)
        
        return {
            "total_benchmarks": len(self.benchmarks),
            "avg_duration": statistics.mean(all_durations),
            "avg_throughput": statistics.mean(all_throughputs),
            "avg_cpu_usage": statistics.mean(all_cpu_usage),
            "avg_memory_usage": statistics.mean(all_memory_usage),
            "best_performing_test": min(self.benchmarks, key=lambda x: x.avg_duration).test_name,
            "worst_performing_test": max(self.benchmarks, key=lambda x: x.avg_duration).test_name
        }

def main():
    """Main entry point for performance benchmarking"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grimm Performance Benchmarking")
    parser.add_argument("--source-path", required=True, help="Source path for backup benchmarking")
    parser.add_argument("--iterations", type=int, default=5, help="Number of iterations")
    parser.add_argument("--output-dir", default="benchmarks", help="Output directory for reports")
    
    args = parser.parse_args()
    
    # Initialize benchmarker
    benchmarker = PerformanceBenchmark(args.output_dir)
    
    # Run benchmarks
    print("Running performance benchmarks...")
    
    # Backup operation benchmark
    backup_result = benchmarker.benchmark_backup_operation(args.source_path, args.iterations)
    print(f"Backup benchmark completed: {backup_result.avg_duration:.2f}s average")
    
    # Parallel operations benchmark
    operations = [f"op_{i}" for i in range(10)]
    parallel_result = benchmarker.benchmark_parallel_operations(operations)
    print(f"Parallel operations benchmark completed: {parallel_result.total_duration:.2f}s total")
    
    # I/O performance benchmark
    io_result = benchmarker.benchmark_io_performance("/tmp/test_io", "write", 50)
    print(f"I/O benchmark completed: {io_result.throughput_avg:.2f} MB/s average")
    
    # Generate report
    report_file = benchmarker.generate_report()
    print(f"Performance report generated: {report_file}")

if __name__ == "__main__":
    main() 