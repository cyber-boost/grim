#!/usr/bin/env python3
"""
Grim Performance Optimizer

Comprehensive performance optimization and benchmarking system for the Grim framework.
Provides automated performance tuning, bottleneck detection, and optimization recommendations.
"""

import json
import time
import psutil
import os
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable, Tuple
from pathlib import Path
from dataclasses import dataclass, asdict
from collections import defaultdict, deque
import statistics
import subprocess
import sys
import logging

# Simple logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')

@dataclass
class BenchmarkResult:
    """Benchmark result container"""
    name: str
    operation: str
    duration: float
    throughput: float
    memory_usage: int
    cpu_usage: float
    timestamp: float
    parameters: Dict[str, Any]
    success: bool
    error_message: Optional[str] = None

@dataclass
class PerformanceProfile:
    """Performance profile container"""
    name: str
    description: str
    benchmarks: List[BenchmarkResult]
    average_duration: float
    average_throughput: float
    average_memory: int
    average_cpu: float
    total_operations: int
    success_rate: float
    timestamp: float

@dataclass
class OptimizationRecommendation:
    """Optimization recommendation container"""
    id: str
    category: str
    title: str
    description: str
    impact: str  # 'low', 'medium', 'high', 'critical'
    effort: str  # 'low', 'medium', 'high'
    current_value: Any
    recommended_value: Any
    expected_improvement: float
    implementation_steps: List[str]
    timestamp: float

class GrimOptimizer:
    """Main performance optimizer"""
    
    def __init__(self):
        self.logger = logging.getLogger("grim_optimizer")
        
        # Performance tracking
        self.benchmark_results: List[BenchmarkResult] = []
        self.performance_profiles: Dict[str, PerformanceProfile] = {}
        self.optimization_recommendations: List[OptimizationRecommendation] = []
        
        # Optimization state
        self.optimization_running = False
        self.optimization_thread = None
        
        # Performance thresholds
        self.thresholds = {
            'response_time': 100.0,  # ms
            'throughput': 1000.0,    # ops/sec
            'memory_usage': 512 * 1024 * 1024,  # 512MB
            'cpu_usage': 50.0,       # percentage
            'disk_io': 100 * 1024 * 1024,  # 100MB/s
            'network_io': 50 * 1024 * 1024  # 50MB/s
        }
        
        # Initialize data directory
        self.data_dir = Path(os.getenv('GRIM_ROOT', '.')) / 'data' / 'optimizer'
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        # Load existing data
        self._load_data()

    def _load_data(self):
        """Load existing benchmark data and recommendations"""
        try:
            # Load benchmark results
            benchmark_file = self.data_dir / 'benchmarks.json'
            if benchmark_file.exists():
                with open(benchmark_file, 'r') as f:
                    data = json.load(f)
                    self.benchmark_results = [BenchmarkResult(**item) for item in data]
            
            # Load recommendations
            rec_file = self.data_dir / 'recommendations.json'
            if rec_file.exists():
                with open(rec_file, 'r') as f:
                    data = json.load(f)
                    self.optimization_recommendations = [OptimizationRecommendation(**item) for item in data]
                    
        except Exception as e:
            self.logger.warning(f"Failed to load existing data: {e}")

    def _save_data(self):
        """Save benchmark data and recommendations"""
        try:
            # Save benchmark results
            benchmark_file = self.data_dir / 'benchmarks.json'
            with open(benchmark_file, 'w') as f:
                json.dump([asdict(r) for r in self.benchmark_results], f, indent=2)
            
            # Save recommendations
            rec_file = self.data_dir / 'recommendations.json'
            with open(rec_file, 'w') as f:
                json.dump([asdict(r) for r in self.optimization_recommendations], f, indent=2)
                
        except Exception as e:
            self.logger.error(f"Failed to save data: {e}")

    def run_performance_analysis(self) -> Dict[str, Any]:
        """Run comprehensive performance analysis"""
        self.logger.info("Starting performance analysis...")
        
        analysis_results = {
            'timestamp': time.time(),
            'system_info': self._get_system_info(),
            'performance_metrics': self._collect_performance_metrics(),
            'disk_analysis': self._analyze_disk_performance(),
            'memory_analysis': self._analyze_memory_usage(),
            'cpu_analysis': self._analyze_cpu_performance(),
            'network_analysis': self._analyze_network_performance(),
            'recommendations_generated': 0
        }
        
        # Generate recommendations based on analysis
        recommendations = self._generate_recommendations(analysis_results)
        self.optimization_recommendations.extend(recommendations)
        analysis_results['recommendations_generated'] = len(recommendations)
        
        # Save data
        self._save_data()
        
        self.logger.info(f"Analysis complete. Generated {len(recommendations)} recommendations.")
        return analysis_results

    def _get_system_info(self) -> Dict[str, Any]:
        """Get basic system information"""
        try:
            return {
                'platform': os.name,
                'cpu_count': psutil.cpu_count(),
                'cpu_count_physical': psutil.cpu_count(logical=False),
                'memory_total': psutil.virtual_memory().total,
                'disk_usage': dict(psutil.disk_usage('/')),
                'boot_time': psutil.boot_time(),
                'python_version': sys.version
            }
        except Exception as e:
            self.logger.error(f"Error getting system info: {e}")
            return {}

    def _collect_performance_metrics(self) -> Dict[str, Any]:
        """Collect current performance metrics"""
        try:
            # Collect metrics over a short period
            metrics = []
            for _ in range(5):
                cpu_percent = psutil.cpu_percent(interval=1)
                memory = psutil.virtual_memory()
                disk_io = psutil.disk_io_counters()
                network_io = psutil.net_io_counters()
                
                metrics.append({
                    'cpu_percent': cpu_percent,
                    'memory_percent': memory.percent,
                    'memory_used': memory.used,
                    'memory_available': memory.available,
                    'disk_read_bytes': disk_io.read_bytes if disk_io else 0,
                    'disk_write_bytes': disk_io.write_bytes if disk_io else 0,
                    'network_sent': network_io.bytes_sent if network_io else 0,
                    'network_recv': network_io.bytes_recv if network_io else 0,
                    'timestamp': time.time()
                })
            
            # Calculate averages
            avg_metrics = {}
            for key in metrics[0].keys():
                if key != 'timestamp':
                    avg_metrics[f'avg_{key}'] = sum(m[key] for m in metrics) / len(metrics)
            
            avg_metrics['sample_count'] = len(metrics)
            avg_metrics['collection_duration'] = metrics[-1]['timestamp'] - metrics[0]['timestamp']
            
            return avg_metrics
            
        except Exception as e:
            self.logger.error(f"Error collecting performance metrics: {e}")
            return {}

    def _analyze_disk_performance(self) -> Dict[str, Any]:
        """Analyze disk performance"""
        try:
            disk_usage = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()
            
            analysis = {
                'total_space': disk_usage.total,
                'used_space': disk_usage.used,
                'free_space': disk_usage.free,
                'usage_percent': (disk_usage.used / disk_usage.total) * 100,
                'read_count': disk_io.read_count if disk_io else 0,
                'write_count': disk_io.write_count if disk_io else 0,
                'read_bytes': disk_io.read_bytes if disk_io else 0,
                'write_bytes': disk_io.write_bytes if disk_io else 0,
            }
            
            # Check for issues
            if analysis['usage_percent'] > 90:
                analysis['status'] = 'critical'
                analysis['issue'] = 'Disk usage is critically high'
            elif analysis['usage_percent'] > 80:
                analysis['status'] = 'warning'
                analysis['issue'] = 'Disk usage is high'
            else:
                analysis['status'] = 'good'
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analyzing disk performance: {e}")
            return {'status': 'error', 'error': str(e)}

    def _analyze_memory_usage(self) -> Dict[str, Any]:
        """Analyze memory usage"""
        try:
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            analysis = {
                'total_memory': memory.total,
                'available_memory': memory.available,
                'used_memory': memory.used,
                'memory_percent': memory.percent,
                'swap_total': swap.total,
                'swap_used': swap.used,
                'swap_percent': swap.percent,
            }
            
            # Check for issues
            if memory.percent > 90:
                analysis['status'] = 'critical'
                analysis['issue'] = 'Memory usage is critically high'
            elif memory.percent > 80:
                analysis['status'] = 'warning'
                analysis['issue'] = 'Memory usage is high'
            else:
                analysis['status'] = 'good'
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analyzing memory usage: {e}")
            return {'status': 'error', 'error': str(e)}

    def _analyze_cpu_performance(self) -> Dict[str, Any]:
        """Analyze CPU performance"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            cpu_freq = psutil.cpu_freq()
            load_avg = os.getloadavg() if hasattr(os, 'getloadavg') else (0, 0, 0)
            
            analysis = {
                'cpu_percent': cpu_percent,
                'cpu_count': cpu_count,
                'cpu_freq_current': cpu_freq.current if cpu_freq else 0,
                'cpu_freq_max': cpu_freq.max if cpu_freq else 0,
                'load_avg_1min': load_avg[0],
                'load_avg_5min': load_avg[1],
                'load_avg_15min': load_avg[2],
            }
            
            # Check for issues
            if cpu_percent > 90:
                analysis['status'] = 'critical'
                analysis['issue'] = 'CPU usage is critically high'
            elif cpu_percent > 80:
                analysis['status'] = 'warning'
                analysis['issue'] = 'CPU usage is high'
            else:
                analysis['status'] = 'good'
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analyzing CPU performance: {e}")
            return {'status': 'error', 'error': str(e)}

    def _analyze_network_performance(self) -> Dict[str, Any]:
        """Analyze network performance"""
        try:
            network_io = psutil.net_io_counters()
            
            if not network_io:
                return {'status': 'unavailable', 'message': 'Network statistics not available'}
            
            analysis = {
                'bytes_sent': network_io.bytes_sent,
                'bytes_recv': network_io.bytes_recv,
                'packets_sent': network_io.packets_sent,
                'packets_recv': network_io.packets_recv,
                'errin': network_io.errin,
                'errout': network_io.errout,
                'dropin': network_io.dropin,
                'dropout': network_io.dropout,
            }
            
            # Check for issues
            error_rate = (network_io.errin + network_io.errout) / max(network_io.packets_sent + network_io.packets_recv, 1)
            if error_rate > 0.01:  # 1% error rate
                analysis['status'] = 'warning'
                analysis['issue'] = f'High network error rate: {error_rate:.2%}'
            else:
                analysis['status'] = 'good'
            
            return analysis
            
        except Exception as e:
            self.logger.error(f"Error analyzing network performance: {e}")
            return {'status': 'error', 'error': str(e)}

    def _generate_recommendations(self, analysis_results: Dict[str, Any]) -> List[OptimizationRecommendation]:
        """Generate optimization recommendations based on analysis"""
        recommendations = []
        timestamp = time.time()
        
        # Memory recommendations
        memory_analysis = analysis_results.get('memory_analysis', {})
        if memory_analysis.get('memory_percent', 0) > 80:
            recommendations.append(OptimizationRecommendation(
                id=f"mem_opt_{int(timestamp)}",
                category="memory",
                title="High Memory Usage Detected",
                description="System memory usage is high. Consider adding more RAM or optimizing memory-intensive processes.",
                impact="high",
                effort="medium",
                current_value=f"{memory_analysis.get('memory_percent', 0):.1f}%",
                recommended_value="< 80%",
                expected_improvement=15.0,
                implementation_steps=[
                    "Identify memory-intensive processes using 'top' or 'htop'",
                    "Optimize or restart high-memory processes",
                    "Consider adding more system RAM",
                    "Implement memory caching strategies"
                ],
                timestamp=timestamp
            ))
        
        # Disk recommendations
        disk_analysis = analysis_results.get('disk_analysis', {})
        if disk_analysis.get('usage_percent', 0) > 80:
            recommendations.append(OptimizationRecommendation(
                id=f"disk_opt_{int(timestamp)}",
                category="storage",
                title="High Disk Usage Detected",
                description="Disk usage is high. Clean up unnecessary files or add more storage.",
                impact="high",
                effort="low",
                current_value=f"{disk_analysis.get('usage_percent', 0):.1f}%",
                recommended_value="< 80%",
                expected_improvement=20.0,
                implementation_steps=[
                    "Run 'grim cleanup' to remove temporary files",
                    "Identify large files using 'du -h --max-depth=1'",
                    "Archive or delete old backup files",
                    "Consider adding more storage capacity"
                ],
                timestamp=timestamp
            ))
        
        # CPU recommendations
        cpu_analysis = analysis_results.get('cpu_analysis', {})
        if cpu_analysis.get('cpu_percent', 0) > 80:
            recommendations.append(OptimizationRecommendation(
                id=f"cpu_opt_{int(timestamp)}",
                category="performance",
                title="High CPU Usage Detected",
                description="CPU usage is high. Optimize processes or upgrade hardware.",
                impact="high",
                effort="medium",
                current_value=f"{cpu_analysis.get('cpu_percent', 0):.1f}%",
                recommended_value="< 80%",
                expected_improvement=25.0,
                implementation_steps=[
                    "Identify CPU-intensive processes",
                    "Optimize or limit resource-heavy applications",
                    "Consider process scheduling improvements",
                    "Evaluate hardware upgrade options"
                ],
                timestamp=timestamp
            ))
        
        # General system recommendations
        system_info = analysis_results.get('system_info', {})
        if system_info.get('memory_total', 0) < 4 * 1024 * 1024 * 1024:  # Less than 4GB
            recommendations.append(OptimizationRecommendation(
                id=f"sys_mem_{int(timestamp)}",
                category="hardware",
                title="Low System Memory",
                description="System has less than 4GB RAM. Consider upgrading for better performance.",
                impact="medium",
                effort="high",
                current_value=f"{system_info.get('memory_total', 0) / (1024**3):.1f}GB",
                recommended_value=">= 8GB",
                expected_improvement=30.0,
                implementation_steps=[
                    "Evaluate current memory usage patterns",
                    "Plan memory upgrade",
                    "Install additional RAM modules",
                    "Verify system performance improvements"
                ],
                timestamp=timestamp
            ))
        
        return recommendations

    def get_recommendations(self) -> List[OptimizationRecommendation]:
        """Get all optimization recommendations"""
        return self.optimization_recommendations

    def implement_recommendation(self, recommendation_id: str) -> bool:
        """Implement a specific recommendation"""
        recommendation = None
        for rec in self.optimization_recommendations:
            if rec.id == recommendation_id:
                recommendation = rec
                break
        
        if not recommendation:
            self.logger.error(f"Recommendation not found: {recommendation_id}")
            return False
        
        self.logger.info(f"Implementing recommendation: {recommendation.title}")
        
        # Simulate implementation (in real implementation, this would execute actual optimizations)
        try:
            if recommendation.category == "memory":
                return self._implement_memory_optimization(recommendation)
            elif recommendation.category == "storage":
                return self._implement_storage_optimization(recommendation)
            elif recommendation.category == "performance":
                return self._implement_performance_optimization(recommendation)
            elif recommendation.category == "hardware":
                self.logger.info("Hardware recommendations require manual intervention")
                return True
            else:
                self.logger.warning(f"Unknown recommendation category: {recommendation.category}")
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to implement recommendation {recommendation_id}: {e}")
            return False

    def _implement_memory_optimization(self, recommendation: OptimizationRecommendation) -> bool:
        """Implement memory optimization"""
        try:
            # Clear system caches
            os.system("sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true")
            
            # Log the action
            self.logger.info("Cleared system caches to free memory")
            return True
            
        except Exception as e:
            self.logger.error(f"Memory optimization failed: {e}")
            return False

    def _implement_storage_optimization(self, recommendation: OptimizationRecommendation) -> bool:
        """Implement storage optimization"""
        try:
            grim_root = os.getenv('GRIM_ROOT', '.')
            
            # Clean temporary files
            temp_dirs = [
                os.path.join(grim_root, 'temp'),
                os.path.join(grim_root, 'tmp'),
                os.path.join(grim_root, 'cache'),
                '/tmp'
            ]
            
            cleaned_size = 0
            for temp_dir in temp_dirs:
                if os.path.exists(temp_dir):
                    for root, dirs, files in os.walk(temp_dir):
                        for file in files:
                            file_path = os.path.join(root, file)
                            try:
                                file_size = os.path.getsize(file_path)
                                # Only remove files older than 1 day
                                if os.path.getmtime(file_path) < time.time() - 86400:
                                    os.remove(file_path)
                                    cleaned_size += file_size
                            except:
                                continue
            
            self.logger.info(f"Cleaned {cleaned_size / (1024*1024):.2f}MB of temporary files")
            return True
            
        except Exception as e:
            self.logger.error(f"Storage optimization failed: {e}")
            return False

    def _implement_performance_optimization(self, recommendation: OptimizationRecommendation) -> bool:
        """Implement performance optimization"""
        try:
            # Adjust system swappiness (if possible)
            try:
                with open('/proc/sys/vm/swappiness', 'w') as f:
                    f.write('10')  # Reduce swappiness for better performance
                self.logger.info("Adjusted system swappiness for better performance")
            except:
                pass  # May not have permission
            
            return True
            
        except Exception as e:
            self.logger.error(f"Performance optimization failed: {e}")
            return False

    def get_performance_summary(self) -> Dict[str, Any]:
        """Get performance summary"""
        implemented_count = 0
        for rec in self.optimization_recommendations:
            if hasattr(rec, 'implemented') and rec.implemented:
                implemented_count += 1
        
        return {
            "total_benchmarks": len(self.benchmark_results),
            "total_recommendations": len(self.optimization_recommendations),
            "implemented_recommendations": implemented_count,
            "pending_recommendations": len(self.optimization_recommendations) - implemented_count,
            "last_analysis": max([r.timestamp for r in self.benchmark_results]) if self.benchmark_results else 0,
            "categories": list(set(r.category for r in self.optimization_recommendations)),
            "high_impact_recommendations": len([r for r in self.optimization_recommendations if r.impact == 'high'])
        }

def main():
    """Main entry point"""
    import sys
    
    if len(sys.argv) < 2:
        show_help()
        return
    
    command = sys.argv[1].lower()
    args = sys.argv[2:] if len(sys.argv) > 2 else []
    
    # Create optimizer
    try:
        optimizer = GrimOptimizer()
    except Exception as e:
        print(f"Error initializing optimizer: {e}")
        return
    
    if command == "analyze":
        # Run performance analysis
        try:
            results = optimizer.run_performance_analysis()
            print(json.dumps(results, indent=2))
        except Exception as e:
            print(f"Analysis failed: {e}")
    
    elif command == "implement":
        # Implement recommendation or all optimizations
        if args:
            # Implement specific recommendation by ID
            success = optimizer.implement_recommendation(args[0])
            print(f"Implementation {'successful' if success else 'failed'}")
        else:
            # Implement all recommendations
            try:
                results = optimizer.run_performance_analysis()
                recommendations = optimizer.get_recommendations()
                implemented = 0
                for rec in recommendations:
                    if optimizer.implement_recommendation(rec.id):
                        implemented += 1
                print(f"Implemented {implemented} of {len(recommendations)} recommendations")
            except Exception as e:
                print(f"Implementation failed: {e}")
    
    elif command == "list":
        # List recommendations
        try:
            recommendations = optimizer.get_recommendations()
            if not recommendations:
                print("No recommendations available. Run 'grim optimizer analyze' first.")
                return
                
            for i, rec in enumerate(recommendations, 1):
                print(f"{i}. [{rec.impact.upper()}] {rec.title}")
                print(f"   Category: {rec.category}")
                print(f"   Effort: {rec.effort}")
                print(f"   Expected improvement: {rec.expected_improvement}%")
                print(f"   ID: {rec.id}")
                print(f"   Description: {rec.description}")
                print()
        except Exception as e:
            print(f"Error listing recommendations: {e}")
    
    elif command == "summary":
        # Show summary
        try:
            summary = optimizer.get_performance_summary()
            print("=== GRIM OPTIMIZER PERFORMANCE SUMMARY ===")
            print(f"Total benchmarks run: {summary['total_benchmarks']}")
            print(f"Total recommendations: {summary['total_recommendations']}")
            print(f"Implemented recommendations: {summary['implemented_recommendations']}")
            print(f"Pending recommendations: {summary['pending_recommendations']}")
            if summary['last_analysis']:
                last_analysis = datetime.fromtimestamp(summary['last_analysis'])
                print(f"Last analysis: {last_analysis.strftime('%Y-%m-%d %H:%M:%S')}")
            else:
                print("Last analysis: Never")
        except Exception as e:
            print(f"Error generating summary: {e}")
    
    elif command == "help":
        show_help()
    
    else:
        print(f"Unknown command: {command}")
        show_help()

def show_help():
    """Show help information"""
    print("GRIM OPTIMIZER - Performance Analysis and Optimization System")
    print()
    print("USAGE:")
    print("  grim optimizer <command> [options]")
    print()
    print("COMMANDS:")
    print("  analyze     - Run comprehensive system performance analysis")
    print("  implement   - Implement optimization recommendations")
    print("              - implement [ID]  : Implement specific recommendation")
    print("              - implement       : Implement all recommendations")
    print("  list        - List all optimization recommendations")
    print("  summary     - Show performance summary and statistics")
    print("  help        - Show this help message")
    print()
    print("EXAMPLES:")
    print("  grim optimizer analyze                    # Run full performance analysis")
    print("  grim optimizer list                       # Show all recommendations")
    print("  grim optimizer implement opt_001          # Implement specific recommendation")
    print("  grim optimizer implement                  # Implement all recommendations")
    print("  grim optimizer summary                    # Show performance summary")
    print()
    print("The optimizer analyzes system performance, identifies bottlenecks,")
    print("and provides actionable recommendations for improvement.")

if __name__ == "__main__":
    main() 