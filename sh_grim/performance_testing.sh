#!/bin/bash
# Grimm Performance Testing Module
# Comprehensive performance benchmarking suite and load testing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PERFORMANCE_DIR="$PROJECT_ROOT/tests/performance"
BENCHMARK_DIR="$PERFORMANCE_DIR/benchmarks"
LOAD_DIR="$PERFORMANCE_DIR/load_tests"
RESULTS_DIR="$PERFORMANCE_DIR/results"

# Performance thresholds
MAX_RESPONSE_TIME_MS=1000
MAX_MEMORY_USAGE_MB=512
MAX_CPU_USAGE_PERCENT=80
MIN_THROUGHPUT_RPS=100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Performance tracking
TOTAL_BENCHMARKS=0
PASSED_BENCHMARKS=0
FAILED_BENCHMARKS=0
START_TIME=$(date +%s)

# Logging functions
log_info() {
    echo -e "${BLUE}[PERFORMANCE]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_performance() {
    echo -e "${CYAN}[BENCHMARK]${NC} $1"
}

# Initialize performance testing environment
init_performance_testing() {
    log_info "Initializing Performance Testing Environment..."
    
    mkdir -p "$PERFORMANCE_DIR"
    mkdir -p "$BENCHMARK_DIR"
    mkdir -p "$LOAD_DIR"
    mkdir -p "$RESULTS_DIR"
    
    # Set performance environment variables
    export GRIMM_PERFORMANCE_MODE=true
    export GRIMM_PERFORMANCE_DIR="$PERFORMANCE_DIR"
    
    log_success "Performance testing environment initialized"
}

# Backup Performance Benchmark
benchmark_backup_performance() {
    log_performance "Running Backup Performance Benchmark"
    
    local test_name="backup_performance"
    local results_file="$RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    
    # Create test data
    local test_data_dir="/tmp/performance_backup_data"
    mkdir -p "$test_data_dir"
    
    # Generate test files of various sizes
    for i in {1..10}; do
        dd if=/dev/urandom of="$test_data_dir/file_${i}.dat" bs=1M count=$((i * 10)) 2>/dev/null
    done
    
    # Measure backup performance
    local start_time=$(date +%s.%N)
    local start_memory=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local start_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Run backup operation
    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
        timeout 300 "$PROJECT_ROOT/reaper.sh" backup "$test_data_dir" > /dev/null 2>&1
    fi
    
    local end_time=$(date +%s.%N)
    local end_memory=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local end_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Calculate metrics
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local memory_delta=$(echo "$end_memory - $start_memory" | bc -l)
    local cpu_delta=$(echo "$end_cpu - $start_cpu" | bc -l)
    local throughput=$(echo "scale=2; $(du -sb "$test_data_dir" | cut -f1) / $duration" | bc -l)
    
    # Generate results
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "duration_seconds": $duration,
  "memory_usage_mb": $memory_delta,
  "cpu_usage_percent": $cpu_delta,
  "throughput_bytes_per_second": $throughput,
  "data_size_bytes": $(du -sb "$test_data_dir" | cut -f1),
  "status": "$(if (( $(echo "$duration < 60" | bc -l) )); then echo "PASSED"; else echo "FAILED"; fi)"
}
EOF
    
    # Cleanup
    rm -rf "$test_data_dir"
    
    # Update counters
    TOTAL_BENCHMARKS=$((TOTAL_BENCHMARKS + 1))
    if (( $(echo "$duration < 60" | bc -l) )); then
        PASSED_BENCHMARKS=$((PASSED_BENCHMARKS + 1))
        log_success "Backup benchmark passed: ${duration}s"
    else
        FAILED_BENCHMARKS=$((FAILED_BENCHMARKS + 1))
        log_error "Backup benchmark failed: ${duration}s (threshold: 60s)"
    fi
    
    echo "$results_file"
}

# Restore Performance Benchmark
benchmark_restore_performance() {
    log_performance "Running Restore Performance Benchmark"
    
    local test_name="restore_performance"
    local results_file="$RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    
    # Create test backup
    local test_backup_dir="/tmp/performance_restore_backup"
    local test_restore_dir="/tmp/performance_restore_target"
    mkdir -p "$test_backup_dir" "$test_restore_dir"
    
    # Generate test backup data
    for i in {1..5}; do
        dd if=/dev/urandom of="$test_backup_dir/backup_${i}.dat" bs=1M count=$((i * 20)) 2>/dev/null
    done
    
    # Measure restore performance
    local start_time=$(date +%s.%N)
    local start_memory=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # Run restore operation
    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
        timeout 300 "$PROJECT_ROOT/reaper.sh" restore "$test_backup_dir" "$test_restore_dir" > /dev/null 2>&1
    fi
    
    local end_time=$(date +%s.%N)
    local end_memory=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # Calculate metrics
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local memory_delta=$(echo "$end_memory - $start_memory" | bc -l)
    local throughput=$(echo "scale=2; $(du -sb "$test_backup_dir" | cut -f1) / $duration" | bc -l)
    
    # Generate results
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "duration_seconds": $duration,
  "memory_usage_mb": $memory_delta,
  "throughput_bytes_per_second": $throughput,
  "data_size_bytes": $(du -sb "$test_backup_dir" | cut -f1),
  "status": "$(if (( $(echo "$duration < 120" | bc -l) )); then echo "PASSED"; else echo "FAILED"; fi)"
}
EOF
    
    # Cleanup
    rm -rf "$test_backup_dir" "$test_restore_dir"
    
    # Update counters
    TOTAL_BENCHMARKS=$((TOTAL_BENCHMARKS + 1))
    if (( $(echo "$duration < 120" | bc -l) )); then
        PASSED_BENCHMARKS=$((PASSED_BENCHMARKS + 1))
        log_success "Restore benchmark passed: ${duration}s"
    else
        FAILED_BENCHMARKS=$((FAILED_BENCHMARKS + 1))
        log_error "Restore benchmark failed: ${duration}s (threshold: 120s)"
    fi
    
    echo "$results_file"
}

# System Resource Benchmark
benchmark_system_resources() {
    log_performance "Running System Resource Benchmark"
    
    local test_name="system_resources"
    local results_file="$RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    
    # Measure system resources
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    local load_average=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # Check if resources are within acceptable limits
    local cpu_status="PASSED"
    local memory_status="PASSED"
    local disk_status="PASSED"
    local load_status="PASSED"
    
    if (( $(echo "$cpu_usage > $MAX_CPU_USAGE_PERCENT" | bc -l) )); then
        cpu_status="FAILED"
    fi
    
    if (( $(echo "$memory_usage > $MAX_MEMORY_USAGE_MB" | bc -l) )); then
        memory_status="FAILED"
    fi
    
    if [ "$disk_usage" -gt 90 ]; then
        disk_status="FAILED"
    fi
    
    if (( $(echo "$load_average > 2.0" | bc -l) )); then
        load_status="FAILED"
    fi
    
    # Generate results
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "cpu_usage_percent": $cpu_usage,
  "memory_usage_percent": $memory_usage,
  "disk_usage_percent": $disk_usage,
  "load_average": $load_average,
  "cpu_status": "$cpu_status",
  "memory_status": "$memory_status",
  "disk_status": "$disk_status",
  "load_status": "$load_status",
  "overall_status": "$(if [ "$cpu_status" = "PASSED" ] && [ "$memory_status" = "PASSED" ] && [ "$disk_status" = "PASSED" ] && [ "$load_status" = "PASSED" ]; then echo "PASSED"; else echo "FAILED"; fi)"
}
EOF
    
    # Update counters
    TOTAL_BENCHMARKS=$((TOTAL_BENCHMARKS + 1))
    if [ "$cpu_status" = "PASSED" ] && [ "$memory_status" = "PASSED" ] && [ "$disk_status" = "PASSED" ] && [ "$load_status" = "PASSED" ]; then
        PASSED_BENCHMARKS=$((PASSED_BENCHMARKS + 1))
        log_success "System resource benchmark passed"
    else
        FAILED_BENCHMARKS=$((FAILED_BENCHMARKS + 1))
        log_error "System resource benchmark failed"
    fi
    
    echo "$results_file"
}

# Load Testing Framework
run_load_tests() {
    log_performance "Running Load Tests"
    
    local load_test_dir="$LOAD_DIR"
    local results_file="$RESULTS_DIR/load_test_$(date +%Y%m%d_%H%M%S).json"
    
    # Load test scenarios
    local scenarios=(
        "concurrent_backups:10:60"
        "concurrent_restores:5:120"
        "mixed_operations:15:180"
        "high_frequency_backups:20:300"
    )
    
    local load_results=()
    
    for scenario in "${scenarios[@]}"; do
        IFS=':' read -r test_name concurrency duration <<< "$scenario"
        log_performance "Running load test: $test_name (concurrency: $concurrency, duration: ${duration}s)"
        
        local scenario_start=$(date +%s.%N)
        local scenario_results=()
        
        # Run concurrent operations
        for i in $(seq 1 "$concurrency"); do
            (
                local operation_start=$(date +%s.%N)
                
                # Simulate backup operation
                if [ "$test_name" = "concurrent_backups" ] || [ "$test_name" = "high_frequency_backups" ]; then
                    local test_dir="/tmp/load_test_${i}"
                    mkdir -p "$test_dir"
                    dd if=/dev/urandom of="$test_dir/data_${i}.dat" bs=1M count=10 2>/dev/null
                    
                    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                        "$PROJECT_ROOT/reaper.sh" backup "$test_dir" > /dev/null 2>&1
                    fi
                    
                    rm -rf "$test_dir"
                fi
                
                local operation_end=$(date +%s.%N)
                local operation_duration=$(echo "$operation_end - $operation_start" | bc -l)
                echo "$operation_duration" >> "$load_test_dir/${test_name}_${i}.tmp"
            ) &
        done
        
        # Wait for all operations to complete
        wait
        
        local scenario_end=$(date +%s.%N)
        local scenario_duration=$(echo "$scenario_end - $scenario_start" | bc -l)
        
        # Calculate scenario metrics
        local total_operations=0
        local total_duration=0
        local min_duration=999999
        local max_duration=0
        
        for i in $(seq 1 "$concurrency"); do
            if [ -f "$load_test_dir/${test_name}_${i}.tmp" ]; then
                local op_duration=$(cat "$load_test_dir/${test_name}_${i}.tmp")
                total_operations=$((total_operations + 1))
                total_duration=$(echo "$total_duration + $op_duration" | bc -l)
                
                if (( $(echo "$op_duration < $min_duration" | bc -l) )); then
                    min_duration=$op_duration
                fi
                if (( $(echo "$op_duration > $max_duration" | bc -l) )); then
                    max_duration=$op_duration
                fi
            fi
        done
        
        local avg_duration=$(echo "scale=3; $total_duration / $total_operations" | bc -l)
        local throughput=$(echo "scale=2; $total_operations / $scenario_duration" | bc -l)
        
        # Store scenario results
        scenario_results+=("$test_name:$concurrency:$avg_duration:$throughput:$min_duration:$max_duration")
        
        # Cleanup temporary files
        rm -f "$load_test_dir"/*.tmp
        
        log_performance "$test_name: avg=${avg_duration}s, throughput=${throughput} ops/s"
    done
    
    # Generate load test report
    cat > "$results_file" <<EOF
{
  "test_type": "load_test",
  "timestamp": "$(date -Iseconds)",
  "scenarios": [
EOF
    
    for i in "${!scenario_results[@]}"; do
        IFS=':' read -r name concurrency avg_duration throughput min_duration max_duration <<< "${scenario_results[$i]}"
        
        cat >> "$results_file" <<EOF
    {
      "name": "$name",
      "concurrency": $concurrency,
      "avg_duration_seconds": $avg_duration,
      "throughput_ops_per_second": $throughput,
      "min_duration_seconds": $min_duration,
      "max_duration_seconds": $max_duration,
      "status": "$(if (( $(echo "$avg_duration < 30" | bc -l) )); then echo "PASSED"; else echo "FAILED"; fi)"
    }$(if [ $i -lt $((${#scenario_results[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    log_success "Load test completed: $results_file"
    echo "$results_file"
}

# Stress Testing Framework
run_stress_tests() {
    log_performance "Running Stress Tests"
    
    local stress_test_dir="$LOAD_DIR/stress_tests"
    local results_file="$RESULTS_DIR/stress_test_$(date +%Y%m%d_%H%M%S).json"
    
    # Stress test scenarios
    local scenarios=(
        "memory_stress:512MB:60"
        "cpu_stress:80%:120"
        "disk_stress:1GB:180"
        "network_stress:100Mbps:300"
    )
    
    local stress_results=()
    
    for scenario in "${scenarios[@]}"; do
        IFS=':' read -r test_name limit duration <<< "$scenario"
        log_performance "Running stress test: $test_name (limit: $limit, duration: ${duration}s)"
        
        local scenario_start=$(date +%s.%N)
        local initial_memory=$(free -m | awk 'NR==2{print $3}')
        local initial_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        
        # Apply stress based on scenario
        case "$test_name" in
            "memory_stress")
                # Generate memory pressure
                stress-ng --vm 2 --vm-bytes "$limit" --timeout "$duration" > /dev/null 2>&1 &
                stress_pid=$!
                ;;
            "cpu_stress")
                # Generate CPU pressure
                stress-ng --cpu 4 --timeout "$duration" > /dev/null 2>&1 &
                stress_pid=$!
                ;;
            "disk_stress")
                # Generate disk I/O pressure
                stress-ng --io 2 --hdd 1 --timeout "$duration" > /dev/null 2>&1 &
                stress_pid=$!
                ;;
            "network_stress")
                # Generate network pressure
                stress-ng --net 2 --timeout "$duration" > /dev/null 2>&1 &
                stress_pid=$!
                ;;
        esac
        
        # Run backup operation under stress
        local test_dir="/tmp/stress_test_${test_name}"
        mkdir -p "$test_dir"
        dd if=/dev/urandom of="$test_dir/stress_data.dat" bs=1M count=100 2>/dev/null
        
        local operation_start=$(date +%s.%N)
        
        if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
            timeout "$duration" "$PROJECT_ROOT/reaper.sh" backup "$test_dir" > /dev/null 2>&1
        fi
        
        local operation_end=$(date +%s.%N)
        local operation_duration=$(echo "$operation_end - $operation_start" | bc -l)
        
        # Stop stress
        if [ -n "${stress_pid:-}" ]; then
            kill "$stress_pid" 2>/dev/null || true
        fi
        
        local final_memory=$(free -m | awk 'NR==2{print $3}')
        local final_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        
        local memory_delta=$((final_memory - initial_memory))
        local cpu_delta=$(echo "$final_cpu - $initial_cpu" | bc -l)
        
        # Store stress results
        stress_results+=("$test_name:$limit:$operation_duration:$memory_delta:$cpu_delta")
        
        # Cleanup
        rm -rf "$test_dir"
        
        log_performance "$test_name: duration=${operation_duration}s, memory_delta=${memory_delta}MB, cpu_delta=${cpu_delta}%"
    done
    
    # Generate stress test report
    cat > "$results_file" <<EOF
{
  "test_type": "stress_test",
  "timestamp": "$(date -Iseconds)",
  "scenarios": [
EOF
    
    for i in "${!stress_results[@]}"; do
        IFS=':' read -r name limit duration memory_delta cpu_delta <<< "${stress_results[$i]}"
        
        cat >> "$results_file" <<EOF
    {
      "name": "$name",
      "stress_limit": "$limit",
      "operation_duration_seconds": $duration,
      "memory_delta_mb": $memory_delta,
      "cpu_delta_percent": $cpu_delta,
      "status": "$(if (( $(echo "$duration < 300" | bc -l) )); then echo "PASSED"; else echo "FAILED"; fi)"
    }$(if [ $i -lt $((${#stress_results[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    log_success "Stress test completed: $results_file"
    echo "$results_file"
}

# Generate Performance Report
generate_performance_report() {
    log_performance "Generating Comprehensive Performance Report"
    
    local report_file="$RESULTS_DIR/performance_report_$(date +%Y%m%d_%H%M%S).md"
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    # Collect all result files
    local result_files=($(find "$RESULTS_DIR" -name "*.json" -type f))
    
    cat > "$report_file" <<EOF
# Grimm Performance Testing Report

## Executive Summary
- **Test Duration**: ${duration} seconds
- **Total Benchmarks**: $TOTAL_BENCHMARKS
- **Passed Benchmarks**: $PASSED_BENCHMARKS
- **Failed Benchmarks**: $FAILED_BENCHMARKS
- **Success Rate**: $(if [ $TOTAL_BENCHMARKS -gt 0 ]; then echo "$((PASSED_BENCHMARKS * 100 / TOTAL_BENCHMARKS))%"; else echo "N/A"; fi)

## Performance Thresholds
- **Max Response Time**: ${MAX_RESPONSE_TIME_MS}ms
- **Max Memory Usage**: ${MAX_MEMORY_USAGE_MB}MB
- **Max CPU Usage**: ${MAX_CPU_USAGE_PERCENT}%
- **Min Throughput**: ${MIN_THROUGHPUT_RPS} RPS

## Test Results Summary

### Individual Benchmarks
EOF
    
    for result_file in "${result_files[@]}"; do
        if [ -f "$result_file" ]; then
            local test_name=$(basename "$result_file" .json)
            local status=$(jq -r '.status // "UNKNOWN"' "$result_file" 2>/dev/null || echo "UNKNOWN")
            local duration=$(jq -r '.duration_seconds // "N/A"' "$result_file" 2>/dev/null || echo "N/A")
            
            cat >> "$report_file" <<EOF
- **$test_name**: $status (Duration: ${duration}s)
EOF
        fi
    done
    
    cat >> "$report_file" <<EOF

## Detailed Results

EOF
    
    for result_file in "${result_files[@]}"; do
        if [ -f "$result_file" ]; then
            local test_name=$(basename "$result_file" .json)
            cat >> "$report_file" <<EOF
### $test_name
\`\`\`json
$(cat "$result_file")
\`\`\`

EOF
        fi
    done
    
    cat >> "$report_file" <<EOF
## Recommendations

$(generate_performance_recommendations)

## Next Steps

$(generate_performance_next_steps)
EOF
    
    log_success "Performance report generated: $report_file"
    echo "$report_file"
}

# Generate performance recommendations
generate_performance_recommendations() {
    local recommendations=""
    
    if [ $FAILED_BENCHMARKS -gt 0 ]; then
        recommendations+="- **Critical**: Address $FAILED_BENCHMARKS failed benchmarks\n"
    fi
    
    if [ $PASSED_BENCHMARKS -lt $TOTAL_BENCHMARKS ]; then
        recommendations+="- **High Priority**: Optimize performance for failing benchmarks\n"
    fi
    
    recommendations+="- **Ongoing**: Monitor performance metrics in production\n"
    recommendations+="- **Regular**: Run performance tests regularly\n"
    
    echo -e "$recommendations"
}

# Generate performance next steps
generate_performance_next_steps() {
    local next_steps=""
    
    if [ $FAILED_BENCHMARKS -gt 0 ]; then
        next_steps+="1. **Immediate**: Investigate and fix performance bottlenecks\n"
    fi
    
    next_steps+="2. **Short-term**: Implement performance monitoring\n"
    next_steps+="3. **Medium-term**: Optimize critical paths\n"
    next_steps+="4. **Long-term**: Establish performance baselines\n"
    
    echo -e "$next_steps"
}

# Main performance testing execution
main() {
    log_performance "Starting Grimm Performance Testing Module"
    log_performance "Performance Thresholds: Response=${MAX_RESPONSE_TIME_MS}ms, Memory=${MAX_MEMORY_USAGE_MB}MB, CPU=${MAX_CPU_USAGE_PERCENT}%"
    
    # Initialize performance testing
    init_performance_testing
    
    # Run individual benchmarks
    local benchmark_results=()
    benchmark_results+=("$(benchmark_backup_performance)")
    benchmark_results+=("$(benchmark_restore_performance)")
    benchmark_results+=("$(benchmark_system_resources)")
    
    # Run comprehensive tests
    benchmark_results+=("$(run_load_tests)")
    benchmark_results+=("$(run_stress_tests)")
    
    # Generate comprehensive report
    local report_file=$(generate_performance_report)
    
    # Display final results
    log_performance "Performance testing completed!"
    log_performance "Total benchmarks: $TOTAL_BENCHMARKS"
    log_performance "Passed: $PASSED_BENCHMARKS"
    log_performance "Failed: $FAILED_BENCHMARKS"
    log_performance "Report: $report_file"
    
    if [ $FAILED_BENCHMARKS -eq 0 ]; then
        log_success "All performance benchmarks passed!"
        return 0
    else
        log_error "$FAILED_BENCHMARKS benchmarks failed!"
        return 1
    fi
}

# Run performance testing if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 