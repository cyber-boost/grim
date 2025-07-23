#!/bin/bash
# Grimm Performance Module: Performance optimization and monitoring
# Advanced performance analysis, optimization, and real-time monitoring

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TUSK_FILE="$GRIM_ROOT/config/grimm.tusk"
TUSK_PARSER="$GRIM_ROOT/bin/tusk_parser.sh"
LOG_FILE="$GRIM_ROOT/logs/performance.log"
METRICS_DIR="$GRIM_ROOT/metrics"
REPORTS_DIR="$GRIM_ROOT/reports"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Load Tusk config
source "$TUSK_PARSER" "$TUSK_FILE"

# Ensure directories exist
mkdir -p "$METRICS_DIR" "$REPORTS_DIR" "$(dirname "$LOG_FILE")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo -e "${CYAN}Grimm Performance Module - Optimization and Monitoring${NC}"
    echo "Usage: grim performance <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  monitor [duration] [options]      - Real-time performance monitoring"
    echo "  analyze [target] [options]        - Performance analysis and profiling"
    echo "  optimize [target] [options]       - Performance optimization"
    echo "  benchmark [test] [options]        - Run performance benchmarks"
    echo "  report [type] [options]           - Generate performance reports"
    echo "  alert [action] [options]          - Configure performance alerts"
    echo "  status                            - Show performance system status"
    echo "  help, -h, --help                  - Show this help message"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --interval <seconds>              - Monitoring interval"
    echo "  --threshold <value>               - Alert threshold"
    echo "  --output <format>                 - Output format (text,json,html)"
    echo "  --verbose                         - Enable verbose output"
    echo "  --quiet                           - Suppress output"
    echo "  --save                            - Save metrics to file"
    echo ""
    echo -e "${YELLOW}Monitoring Targets:${NC}"
    echo "  system                            - System-wide metrics"
    echo "  cpu                               - CPU performance"
    echo "  memory                            - Memory usage and performance"
    echo "  disk                              - Disk I/O and performance"
    echo "  network                           - Network performance"
    echo "  process                           - Process-specific metrics"
    echo "  grim                              - Grim system performance"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "  - Real-time performance monitoring"
    echo "  - Automated performance analysis"
    echo "  - Optimization recommendations"
    echo "  - Performance benchmarking"
    echo "  - Alert system for performance issues"
    echo "  - Historical performance tracking"
    echo "  - Resource usage optimization"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  grim performance monitor system --interval 5"
    echo "  grim performance analyze cpu --verbose"
    echo "  grim performance optimize memory"
    echo "  grim performance benchmark disk"
    echo "  grim performance report system --output html"
    echo "  grim performance alert set --threshold 80"
}

# Get system metrics
get_system_metrics() {
    local metrics_file="$METRICS_DIR/system_$(date +%Y%m%d_%H%M%S).json"
    
    # CPU metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_cores=$(nproc)
    
    # Memory metrics
    local mem_info=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_available=$(free -m | awk 'NR==2{print $7}')
    
    # Disk metrics
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
    local disk_io=$(iostat -x 1 1 | awk 'NR==4{print $2, $3, $4, $5}')
    
    # Network metrics
    local network_rx=$(cat /proc/net/dev | grep eth0 | awk '{print $2}')
    local network_tx=$(cat /proc/net/dev | grep eth0 | awk '{print $10}')
    
    # Process metrics
    local process_count=$(ps aux | wc -l)
    local grim_processes=$(ps aux | grep grim | wc -l)
    
    # Create JSON metrics
    cat > "$metrics_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "system": {
        "hostname": "$(hostname)",
        "uptime": "$(uptime -p)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)"
    },
    "cpu": {
        "usage_percent": $cpu_usage,
        "load_average": $cpu_load,
        "cores": $cpu_cores
    },
    "memory": {
        "usage_percent": $mem_info,
        "total_mb": $mem_total,
        "used_mb": $mem_used,
        "available_mb": $mem_available
    },
    "disk": {
        "usage_percent": $disk_usage,
        "io_stats": "$disk_io"
    },
    "network": {
        "bytes_rx": $network_rx,
        "bytes_tx": $network_tx
    },
    "processes": {
        "total": $process_count,
        "grim_processes": $grim_processes
    }
}
EOF
    
    echo "$metrics_file"
}

# Real-time monitoring
monitor_performance() {
    local duration="${1:-60}"
    local target="${2:-system}"
    shift 2 || true
    
    # Parse options
    local INTERVAL=5
    local VERBOSE=false
    local QUIET=false
    local SAVE=false
    local OUTPUT_FORMAT="text"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interval)
                INTERVAL="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --save)
                SAVE=true
                shift
                ;;
            --output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    echo -e "${CYAN}=== Performance Monitoring ===${NC}"
    echo "Target: $target"
    echo "Duration: ${duration}s"
    echo "Interval: ${INTERVAL}s"
    echo "Output: $OUTPUT_FORMAT"
    echo ""
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local iteration=0
    
    # Create monitoring session
    local session_id="monitor_$(date +%Y%m%d_%H%M%S)_$$"
    local session_file="$METRICS_DIR/${session_id}.json"
    
    echo "[" > "$session_file"
    
    while [[ $(date +%s) -lt $end_time ]]; do
        iteration=$((iteration + 1))
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # Get metrics based on target
        case "$target" in
            system)
                local metrics_file=$(get_system_metrics)
                ;;
            cpu)
                local metrics_file=$(get_cpu_metrics)
                ;;
            memory)
                local metrics_file=$(get_memory_metrics)
                ;;
            disk)
                local metrics_file=$(get_disk_metrics)
                ;;
            network)
                local metrics_file=$(get_network_metrics)
                ;;
            grim)
                local metrics_file=$(get_grim_metrics)
                ;;
            *)
                echo -e "${RED}❌ Unknown monitoring target: $target${NC}"
                return 1
                ;;
        esac
        
        # Display metrics
        if [[ "$QUIET" != "true" ]]; then
            display_metrics "$metrics_file" "$OUTPUT_FORMAT" "$iteration" "$elapsed"
        fi
        
        # Save to session file
        if [[ "$SAVE" == "true" ]]; then
            if [[ $iteration -gt 1 ]]; then
                echo "," >> "$session_file"
            fi
            cat "$metrics_file" >> "$session_file"
        fi
        
        # Clean up individual metrics file
        rm -f "$metrics_file"
        
        # Check for alerts
        check_performance_alerts "$metrics_file"
        
        # Wait for next interval
        if [[ $(date +%s) -lt $end_time ]]; then
            sleep "$INTERVAL"
        fi
    done
    
    echo "]" >> "$session_file"
    
    echo ""
    echo -e "${GREEN}✅ Monitoring completed${NC}"
    echo "Session: $session_id"
    echo "Iterations: $iteration"
    echo "Duration: ${duration}s"
    
    if [[ "$SAVE" == "true" ]]; then
        echo "Data saved: $session_file"
    fi
}

# Display metrics in various formats
display_metrics() {
    local metrics_file="$1"
    local format="$2"
    local iteration="$3"
    local elapsed="$4"
    
    case "$format" in
        json)
            cat "$metrics_file"
            ;;
        text)
            display_text_metrics "$metrics_file" "$iteration" "$elapsed"
            ;;
        html)
            display_html_metrics "$metrics_file" "$iteration" "$elapsed"
            ;;
        *)
            display_text_metrics "$metrics_file" "$iteration" "$elapsed"
            ;;
    esac
}

# Display metrics in text format
display_text_metrics() {
    local metrics_file="$1"
    local iteration="$2"
    local elapsed="$3"
    
    echo -e "${CYAN}[$iteration] Elapsed: ${elapsed}s${NC}"
    
    # Parse JSON and display key metrics
    local cpu_usage=$(jq -r '.cpu.usage_percent' "$metrics_file" 2>/dev/null || echo "N/A")
    local mem_usage=$(jq -r '.memory.usage_percent' "$metrics_file" 2>/dev/null || echo "N/A")
    local disk_usage=$(jq -r '.disk.usage_percent' "$metrics_file" 2>/dev/null || echo "N/A")
    
    echo "  CPU: ${cpu_usage}% | Memory: ${mem_usage}% | Disk: ${disk_usage}%"
}

# Performance analysis
analyze_performance() {
    local target="${1:-system}"
    shift || true
    
    # Parse options
    local VERBOSE=false
    local OUTPUT_FORMAT="text"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    echo -e "${CYAN}=== Performance Analysis ===${NC}"
    echo "Target: $target"
    echo ""
    
    case "$target" in
        system)
            analyze_system_performance
            ;;
        cpu)
            analyze_cpu_performance
            ;;
        memory)
            analyze_memory_performance
            ;;
        disk)
            analyze_disk_performance
            ;;
        network)
            analyze_network_performance
            ;;
        grim)
            analyze_grim_performance
            ;;
        *)
            echo -e "${RED}❌ Unknown analysis target: $target${NC}"
            return 1
            ;;
    esac
}

# Analyze system performance
analyze_system_performance() {
    echo -e "${YELLOW}System Performance Analysis${NC}"
    echo "================================"
    
    # CPU analysis
    echo ""
    echo -e "${CYAN}CPU Analysis:${NC}"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_cores=$(nproc)
    
    echo "  Current CPU Usage: ${cpu_usage}%"
    echo "  Load Average: $cpu_load"
    echo "  CPU Cores: $cpu_cores"
    
    # CPU recommendations
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        echo -e "  ${RED}⚠️  High CPU usage detected${NC}"
        echo "    - Consider optimizing CPU-intensive processes"
        echo "    - Check for runaway processes"
        echo "    - Consider scaling up CPU resources"
    elif (( $(echo "$cpu_usage > 60" | bc -l) )); then
        echo -e "  ${YELLOW}⚠️  Moderate CPU usage${NC}"
        echo "    - Monitor for performance degradation"
        echo "    - Consider process optimization"
    else
        echo -e "  ${GREEN}✅ CPU usage is healthy${NC}"
    fi
    
    # Memory analysis
    echo ""
    echo -e "${CYAN}Memory Analysis:${NC}"
    local mem_info=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_available=$(free -m | awk 'NR==2{print $7}')
    
    echo "  Memory Usage: ${mem_info}%"
    echo "  Total Memory: ${mem_total}MB"
    echo "  Used Memory: ${mem_used}MB"
    echo "  Available Memory: ${mem_available}MB"
    
    # Memory recommendations
    if (( $(echo "$mem_info > 90" | bc -l) )); then
        echo -e "  ${RED}⚠️  Critical memory usage${NC}"
        echo "    - Immediate action required"
        echo "    - Check for memory leaks"
        echo "    - Consider adding more RAM"
    elif (( $(echo "$mem_info > 80" | bc -l) )); then
        echo -e "  ${YELLOW}⚠️  High memory usage${NC}"
        echo "    - Monitor memory usage closely"
        echo "    - Consider optimizing memory usage"
    else
        echo -e "  ${GREEN}✅ Memory usage is healthy${NC}"
    fi
    
    # Disk analysis
    echo ""
    echo -e "${CYAN}Disk Analysis:${NC}"
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
    
    echo "  Disk Usage: ${disk_usage}%"
    
    # Disk recommendations
    if [[ $disk_usage -gt 90 ]]; then
        echo -e "  ${RED}⚠️  Critical disk usage${NC}"
        echo "    - Immediate cleanup required"
        echo "    - Check for large files"
        echo "    - Consider expanding storage"
    elif [[ $disk_usage -gt 80 ]]; then
        echo -e "  ${YELLOW}⚠️  High disk usage${NC}"
        echo "    - Monitor disk space closely"
        echo "    - Consider cleanup procedures"
    else
        echo -e "  ${GREEN}✅ Disk usage is healthy${NC}"
    fi
    
    # Process analysis
    echo ""
    echo -e "${CYAN}Process Analysis:${NC}"
    local process_count=$(ps aux | wc -l)
    local grim_processes=$(ps aux | grep grim | wc -l)
    
    echo "  Total Processes: $process_count"
    echo "  Grim Processes: $grim_processes"
    
    # Top processes by CPU
    echo ""
    echo -e "${YELLOW}Top CPU Processes:${NC}"
    ps aux --sort=-%cpu | head -6 | awk 'NR>1{print "  " $3 "% - " $11}'
    
    # Top processes by memory
    echo ""
    echo -e "${YELLOW}Top Memory Processes:${NC}"
    ps aux --sort=-%mem | head -6 | awk 'NR>1{print "  " $4 "% - " $11}'
}

# Performance optimization
optimize_performance() {
    local target="${1:-system}"
    shift || true
    
    echo -e "${CYAN}=== Performance Optimization ===${NC}"
    echo "Target: $target"
    echo ""
    
    case "$target" in
        system)
            optimize_system_performance
            ;;
        cpu)
            optimize_cpu_performance
            ;;
        memory)
            optimize_memory_performance
            ;;
        disk)
            optimize_disk_performance
            ;;
        network)
            optimize_network_performance
            ;;
        grim)
            optimize_grim_performance
            ;;
        *)
            echo -e "${RED}❌ Unknown optimization target: $target${NC}"
            return 1
            ;;
    esac
}

# Optimize system performance
optimize_system_performance() {
    echo -e "${YELLOW}System Performance Optimization${NC}"
    echo "====================================="
    
    # Check for optimization opportunities
    local optimizations=()
    
    # CPU optimization
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > 70" | bc -l) )); then
        optimizations+=("cpu")
    fi
    
    # Memory optimization
    local mem_info=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    if (( $(echo "$mem_info > 80" | bc -l) )); then
        optimizations+=("memory")
    fi
    
    # Disk optimization
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
    if [[ $disk_usage -gt 80 ]]; then
        optimizations+=("disk")
    fi
    
    if [[ ${#optimizations[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ System performance is optimal${NC}"
        return 0
    fi
    
    echo "Optimization opportunities detected:"
    for opt in "${optimizations[@]}"; do
        echo "  - $opt"
    done
    echo ""
    
    # Apply optimizations
    for opt in "${optimizations[@]}"; do
        case "$opt" in
            cpu)
                optimize_cpu_performance
                ;;
            memory)
                optimize_memory_performance
                ;;
            disk)
                optimize_disk_performance
                ;;
        esac
    done
}

# Optimize CPU performance
optimize_cpu_performance() {
    echo -e "${CYAN}CPU Optimization:${NC}"
    
    # Find high CPU processes
    local high_cpu_processes=$(ps aux --sort=-%cpu | awk 'NR>1 && $3>10{print $2 " " $3 " " $11}')
    
    if [[ -n "$high_cpu_processes" ]]; then
        echo "High CPU processes detected:"
        echo "$high_cpu_processes" | while read -r pid cpu name; do
            echo "  PID $pid: ${cpu}% - $name"
        done
        echo ""
        echo "Recommendations:"
        echo "  - Review high CPU processes"
        echo "  - Consider process optimization"
        echo "  - Check for infinite loops"
    else
        echo -e "  ${GREEN}✅ No high CPU processes detected${NC}"
    fi
}

# Optimize memory performance
optimize_memory_performance() {
    echo -e "${CYAN}Memory Optimization:${NC}"
    
    # Check for memory leaks
    local high_mem_processes=$(ps aux --sort=-%mem | awk 'NR>1 && $4>10{print $2 " " $4 " " $11}')
    
    if [[ -n "$high_mem_processes" ]]; then
        echo "High memory processes detected:"
        echo "$high_mem_processes" | while read -r pid mem name; do
            echo "  PID $pid: ${mem}% - $name"
        done
        echo ""
        echo "Recommendations:"
        echo "  - Review high memory processes"
        echo "  - Check for memory leaks"
        echo "  - Consider process restart"
    else
        echo -e "  ${GREEN}✅ No high memory processes detected${NC}"
    fi
    
    # Clear page cache if needed
    local mem_info=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    if (( $(echo "$mem_info > 90" | bc -l) )); then
        echo ""
        echo -e "${YELLOW}⚠️  Critical memory usage - clearing page cache${NC}"
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "  Requires root privileges"
    fi
}

# Optimize disk performance
optimize_disk_performance() {
    echo -e "${CYAN}Disk Optimization:${NC}"
    
    # Find large files
    echo "Large files (>100MB):"
    find / -type f -size +100M 2>/dev/null | head -10 | while read -r file; do
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "  $size - $file"
    done
    echo ""
    
    # Check for old log files
    echo "Old log files (>30 days):"
    find /var/log -type f -mtime +30 2>/dev/null | head -10 | while read -r file; do
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "  $size - $file"
    done
    echo ""
    
    echo "Recommendations:"
    echo "  - Remove unnecessary large files"
    echo "  - Rotate old log files"
    echo "  - Consider disk cleanup"
}

# Performance benchmarking
benchmark_performance() {
    local test="${1:-system}"
    shift || true
    
    echo -e "${CYAN}=== Performance Benchmarking ===${NC}"
    echo "Test: $test"
    echo ""
    
    case "$test" in
        system)
            benchmark_system_performance
            ;;
        cpu)
            benchmark_cpu_performance
            ;;
        memory)
            benchmark_memory_performance
            ;;
        disk)
            benchmark_disk_performance
            ;;
        network)
            benchmark_network_performance
            ;;
        grim)
            benchmark_grim_performance
            ;;
        *)
            echo -e "${RED}❌ Unknown benchmark test: $test${NC}"
            return 1
            ;;
    esac
}

# Benchmark system performance
benchmark_system_performance() {
    echo -e "${YELLOW}System Performance Benchmark${NC}"
    echo "================================"
    
    # CPU benchmark
    echo ""
    echo -e "${CYAN}CPU Benchmark:${NC}"
    local start_time=$(date +%s.%N)
    
    # Simple CPU test
    for i in {1..1000000}; do
        echo "scale=10; sqrt($i)" | bc -l >/dev/null 2>&1
    done
    
    local end_time=$(date +%s.%N)
    local cpu_time=$(echo "$end_time - $start_time" | bc)
    echo "  CPU calculation time: ${cpu_time}s"
    
    # Memory benchmark
    echo ""
    echo -e "${CYAN}Memory Benchmark:${NC}"
    start_time=$(date +%s.%N)
    
    # Memory allocation test
    local test_size=1000000
    local test_array=()
    for ((i=0; i<test_size; i++)); do
        test_array[$i]=$i
    done
    
    end_time=$(date +%s.%N)
    local mem_time=$(echo "$end_time - $start_time" | bc)
    echo "  Memory allocation time: ${mem_time}s"
    
    # Disk benchmark
    echo ""
    echo -e "${CYAN}Disk Benchmark:${NC}"
    local test_file="/tmp/grim_benchmark_$$"
    start_time=$(date +%s.%N)
    
    # Write test
    dd if=/dev/zero of="$test_file" bs=1M count=100 2>/dev/null
    
    end_time=$(date +%s.%N)
    local write_time=$(echo "$end_time - $start_time" | bc)
    echo "  Disk write time: ${write_time}s"
    
    # Read test
    start_time=$(date +%s.%N)
    dd if="$test_file" of=/dev/null bs=1M 2>/dev/null
    
    end_time=$(date +%s.%N)
    local read_time=$(echo "$end_time - $start_time" | bc)
    echo "  Disk read time: ${read_time}s"
    
    # Cleanup
    rm -f "$test_file"
    
    # Summary
    echo ""
    echo -e "${YELLOW}Benchmark Summary:${NC}"
    echo "  CPU: ${cpu_time}s"
    echo "  Memory: ${mem_time}s"
    echo "  Disk Write: ${write_time}s"
    echo "  Disk Read: ${read_time}s"
}

# Check performance alerts
check_performance_alerts() {
    local metrics_file="$1"
    
    # CPU alert
    local cpu_usage=$(jq -r '.cpu.usage_percent' "$metrics_file" 2>/dev/null || echo "0")
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        send_performance_alert "CPU" "Critical CPU usage: ${cpu_usage}%"
    elif (( $(echo "$cpu_usage > 80" | bc -l) )); then
        send_performance_alert "CPU" "High CPU usage: ${cpu_usage}%"
    fi
    
    # Memory alert
    local mem_usage=$(jq -r '.memory.usage_percent' "$metrics_file" 2>/dev/null || echo "0")
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        send_performance_alert "Memory" "Critical memory usage: ${mem_usage}%"
    elif (( $(echo "$mem_usage > 80" | bc -l) )); then
        send_performance_alert "Memory" "High memory usage: ${mem_usage}%"
    fi
    
    # Disk alert
    local disk_usage=$(jq -r '.disk.usage_percent' "$metrics_file" 2>/dev/null || echo "0")
    if [[ $disk_usage -gt 90 ]]; then
        send_performance_alert "Disk" "Critical disk usage: ${disk_usage}%"
    elif [[ $disk_usage -gt 80 ]]; then
        send_performance_alert "Disk" "High disk usage: ${disk_usage}%"
    fi
}

# Send performance alert
send_performance_alert() {
    local component="$1"
    local message="$2"
    
    log "PERFORMANCE ALERT: $component - $message"
    
    if [[ -f "$NOTIFY_MODULE" ]]; then
        "$NOTIFY_MODULE" send warning "Performance Alert" "$message" "{\"component\": \"$component\", \"message\": \"$message\"}"
    fi
}

# Show performance system status
show_status() {
    echo -e "${CYAN}=== Performance System Status ===${NC}"
    
    # Check metrics directory
    local metrics_count=$(find "$METRICS_DIR" -name "*.json" 2>/dev/null | wc -l)
    echo "Metrics files: $metrics_count"
    
    # Check recent metrics
    if [[ $metrics_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Recent Metrics:${NC}"
        find "$METRICS_DIR" -name "*.json" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -5 | while read -r timestamp file; do
            local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
            local size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo "  $date - $size - $(basename "$file")"
        done
    fi
    
    # Check system resources
    echo ""
    echo -e "${YELLOW}Current System Status:${NC}"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_info=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
    
    echo "  CPU Usage: ${cpu_usage}%"
    echo "  Memory Usage: ${mem_info}%"
    echo "  Disk Usage: ${disk_usage}%"
    
    # Performance recommendations
    echo ""
    echo -e "${YELLOW}Performance Recommendations:${NC}"
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        echo "  - Consider CPU optimization"
    fi
    if (( $(echo "$mem_info > 80" | bc -l) )); then
        echo "  - Consider memory optimization"
    fi
    if [[ $disk_usage -gt 80 ]]; then
        echo "  - Consider disk cleanup"
    fi
}

# Main command handler
main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        monitor)
            monitor_performance "$@"
            ;;
        analyze)
            analyze_performance "$@"
            ;;
        optimize)
            optimize_performance "$@"
            ;;
        benchmark)
            benchmark_performance "$@"
            ;;
        report)
            # TODO: Implement report generation
            echo "Report generation not yet implemented"
            ;;
        alert)
            # TODO: Implement alert configuration
            echo "Alert configuration not yet implemented"
            ;;
        status)
            show_status
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi 