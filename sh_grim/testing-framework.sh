#!/bin/bash
# Grimm Testing Framework Module: Comprehensive testing suite for Grim system
# Advanced testing framework with automated execution, reporting, and integration

SCRIPT_PATH="$(readlink -f "$0")"
GRIM_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TUSK_FILE="$GRIM_ROOT/config/grimm.tusk"
TUSK_PARSER="$GRIM_ROOT/bin/tusk_parser.sh"
LOG_FILE="$GRIM_ROOT/logs/testing.log"
TEST_ROOT="$GRIM_ROOT/tests"
REPORTS_DIR="$GRIM_ROOT/reports"
NOTIFY_MODULE="$GRIM_ROOT/sh_grim/notify.sh"

# Load Tusk config
source "$TUSK_PARSER" "$TUSK_FILE"

# Ensure directories exist
mkdir -p "$TEST_ROOT" "$REPORTS_DIR" "$(dirname "$LOG_FILE")"

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
    echo -e "${CYAN}Grimm Testing Framework - Comprehensive Testing Suite${NC}"
    echo "Usage: grim test <command> [options]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  run [test_suite] [options]        - Run test suite or all tests"
    echo "  create <test_name> [type]         - Create new test"
    echo "  list [category]                   - List available tests"
    echo "  info <test_name>                  - Show test information"
    echo "  validate <test_name>              - Validate test syntax"
    echo "  report [test_run]                 - Show test reports"
    echo "  coverage [test_suite]             - Show test coverage"
    echo "  benchmark [test_suite]            - Run performance benchmarks"
    echo "  ci [options]                      - Continuous integration mode"
    echo "  status                            - Show testing system status"
    echo "  help, -h, --help                  - Show this help message"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --verbose                         - Enable verbose output"
    echo "  --quiet                           - Suppress output"
    echo "  --parallel                        - Run tests in parallel"
    echo "  --timeout <seconds>               - Set test timeout"
    echo "  --retry <count>                   - Retry failed tests"
    echo "  --filter <pattern>                - Filter tests by pattern"
    echo "  --coverage                        - Generate coverage report"
    echo "  --report-format <format>          - Set report format (html,json,xml)"
    echo ""
    echo -e "${YELLOW}Test Types:${NC}"
    echo "  unit                              - Unit tests for individual components"
    echo "  integration                       - Integration tests for modules"
    echo "  system                            - System-wide functionality tests"
    echo "  performance                       - Performance and load tests"
    echo "  security                          - Security and vulnerability tests"
    echo "  regression                        - Regression tests"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "  - Automated test discovery"
    echo "  - Parallel test execution"
    echo "  - Comprehensive reporting"
    echo "  - Coverage analysis"
    echo "  - Performance benchmarking"
    echo "  - CI/CD integration"
    echo "  - Test result notifications"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  grim test run unit"
    echo "  grim test run all --parallel --coverage"
    echo "  grim test create my_test unit"
    echo "  grim test report latest"
    echo "  grim test benchmark performance"
    echo "  grim test ci --report-format html"
}

# Test result tracking
declare -A TEST_RESULTS
declare -A TEST_TIMES
declare -A TEST_COVERAGE

# Initialize test environment
init_test_env() {
    log "Initializing test environment"
    
    # Create test directories if they don't exist
    for test_type in unit integration system performance security regression; do
        mkdir -p "$TEST_ROOT/$test_type"
    done
    
    # Create test templates
    create_test_templates
    
    # Initialize test database
    init_test_db
}

# Create test templates
create_test_templates() {
    # Unit test template
    cat > "$TEST_ROOT/templates/unit_test.sh" << 'EOF'
#!/bin/bash
# Unit Test Template
# Test: {{TEST_NAME}}
# Description: {{TEST_DESCRIPTION}}

TEST_NAME="{{TEST_NAME}}"
TEST_DESCRIPTION="{{TEST_DESCRIPTION}}"
TEST_TIMEOUT="{{TEST_TIMEOUT:-30}}"

# Test setup
setup() {
    echo "Setting up test: $TEST_NAME"
    # Add setup code here
}

# Test teardown
teardown() {
    echo "Cleaning up test: $TEST_NAME"
    # Add cleanup code here
}

# Test execution
run_test() {
    echo "Running test: $TEST_NAME"
    
    # Add test logic here
    # Example:
    # result=$(some_function "test_input")
    # assert_equal "$result" "expected_output" "Test description"
    
    return 0
}

# Main test runner
main() {
    setup
    run_test
    local exit_code=$?
    teardown
    exit $exit_code
}

# Assertion functions
assert_equal() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$actual" == "$expected" ]]; then
        echo "✅ PASS: $message"
        return 0
    else
        echo "❌ FAIL: $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        return 1
    fi
}

assert_not_equal() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$actual" != "$expected" ]]; then
        echo "✅ PASS: $message"
        return 0
    else
        echo "❌ FAIL: $message"
        echo "  Expected: not $expected"
        echo "  Actual: $actual"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ -f "$file" ]]; then
        echo "✅ PASS: $message"
        return 0
    else
        echo "❌ FAIL: $message"
        echo "  File: $file"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    if [[ -d "$dir" ]]; then
        echo "✅ PASS: $message"
        return 0
    else
        echo "❌ FAIL: $message"
        echo "  Directory: $dir"
        return 1
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
EOF

    # Integration test template
    cat > "$TEST_ROOT/templates/integration_test.sh" << 'EOF'
#!/bin/bash
# Integration Test Template
# Test: {{TEST_NAME}}
# Description: {{TEST_DESCRIPTION}}

TEST_NAME="{{TEST_NAME}}"
TEST_DESCRIPTION="{{TEST_DESCRIPTION}}"
TEST_TIMEOUT="{{TEST_TIMEOUT:-60}}"

# Test setup
setup() {
    echo "Setting up integration test: $TEST_NAME"
    # Initialize test environment
    # Start required services
    # Set up test data
}

# Test teardown
teardown() {
    echo "Cleaning up integration test: $TEST_NAME"
    # Stop services
    # Clean up test data
    # Reset environment
}

# Test execution
run_test() {
    echo "Running integration test: $TEST_NAME"
    
    # Test module interactions
    # Test data flow between components
    # Test error handling and recovery
    
    return 0
}

# Main test runner
main() {
    setup
    run_test
    local exit_code=$?
    teardown
    exit $exit_code
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
EOF

    # Performance test template
    cat > "$TEST_ROOT/templates/performance_test.sh" << 'EOF'
#!/bin/bash
# Performance Test Template
# Test: {{TEST_NAME}}
# Description: {{TEST_DESCRIPTION}}

TEST_NAME="{{TEST_NAME}}"
TEST_DESCRIPTION="{{TEST_DESCRIPTION}}"
TEST_TIMEOUT="{{TEST_TIMEOUT:-300}}"
TEST_ITERATIONS="{{TEST_ITERATIONS:-100}}"

# Performance metrics
declare -a EXECUTION_TIMES
declare -a MEMORY_USAGE
declare -a CPU_USAGE

# Test setup
setup() {
    echo "Setting up performance test: $TEST_NAME"
    # Initialize performance monitoring
    # Set up test environment
}

# Test teardown
teardown() {
    echo "Cleaning up performance test: $TEST_NAME"
    # Generate performance report
    # Clean up resources
}

# Performance measurement
measure_performance() {
    local start_time=$(date +%s.%N)
    local start_memory=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # Execute test operation
    "$@"
    
    local end_time=$(date +%s.%N)
    local end_memory=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    local execution_time=$(echo "$end_time - $start_time" | bc)
    local memory_usage=$(echo "$end_memory - $start_memory" | bc)
    
    EXECUTION_TIMES+=("$execution_time")
    MEMORY_USAGE+=("$memory_usage")
}

# Test execution
run_test() {
    echo "Running performance test: $TEST_NAME"
    echo "Iterations: $TEST_ITERATIONS"
    
    for ((i=1; i<=TEST_ITERATIONS; i++)); do
        echo "Iteration $i/$TEST_ITERATIONS"
        measure_performance test_operation
    done
    
    # Calculate statistics
    calculate_performance_stats
}

# Calculate performance statistics
calculate_performance_stats() {
    local total_time=0
    local total_memory=0
    local count=${#EXECUTION_TIMES[@]}
    
    for time in "${EXECUTION_TIMES[@]}"; do
        total_time=$(echo "$total_time + $time" | bc)
    done
    
    for memory in "${MEMORY_USAGE[@]}"; do
        total_memory=$(echo "$total_memory + $memory" | bc)
    done
    
    local avg_time=$(echo "scale=4; $total_time / $count" | bc)
    local avg_memory=$(echo "scale=2; $total_memory / $count" | bc)
    
    echo "Performance Results:"
    echo "  Average execution time: ${avg_time}s"
    echo "  Average memory usage: ${avg_memory}%"
    echo "  Total iterations: $count"
}

# Main test runner
main() {
    setup
    run_test
    local exit_code=$?
    teardown
    exit $exit_code
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
EOF
}

# Initialize test database
init_test_db() {
    local db_file="$GRIM_ROOT/db/testing.db"
    
    sqlite3 "$db_file" << 'EOF'
CREATE TABLE IF NOT EXISTS test_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT UNIQUE NOT NULL,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    total_tests INTEGER DEFAULT 0,
    passed_tests INTEGER DEFAULT 0,
    failed_tests INTEGER DEFAULT 0,
    skipped_tests INTEGER DEFAULT 0,
    status TEXT DEFAULT 'running',
    duration REAL DEFAULT 0,
    environment TEXT,
    metadata TEXT
);

CREATE TABLE IF NOT EXISTS test_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    test_name TEXT NOT NULL,
    test_type TEXT NOT NULL,
    status TEXT NOT NULL,
    duration REAL DEFAULT 0,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    output TEXT,
    error_message TEXT,
    stack_trace TEXT,
    metadata TEXT,
    FOREIGN KEY (run_id) REFERENCES test_runs (run_id)
);

CREATE TABLE IF NOT EXISTS test_coverage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    test_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    lines_covered INTEGER DEFAULT 0,
    lines_total INTEGER DEFAULT 0,
    coverage_percentage REAL DEFAULT 0,
    FOREIGN KEY (run_id) REFERENCES test_runs (run_id)
);

CREATE INDEX IF NOT EXISTS idx_test_runs_run_id ON test_runs (run_id);
CREATE INDEX IF NOT EXISTS idx_test_results_run_id ON test_results (run_id);
CREATE INDEX IF NOT EXISTS idx_test_results_test_name ON test_results (test_name);
CREATE INDEX IF NOT EXISTS idx_test_coverage_run_id ON test_coverage (run_id);
EOF
}

# Create new test
create_test() {
    local test_name="$1"
    local test_type="${2:-unit}"
    
    if [[ -z "$test_name" ]]; then
        echo -e "${RED}❌ Test name is required${NC}"
        echo "Usage: grim test create <test_name> [type]"
        return 1
    fi
    
    # Validate test type
    local valid_types="unit integration system performance security regression"
    if [[ ! " $valid_types " =~ " $test_type " ]]; then
        echo -e "${RED}❌ Invalid test type: $test_type${NC}"
        echo "Valid types: $valid_types"
        return 1
    fi
    
    local test_file="$TEST_ROOT/$test_type/${test_name}.sh"
    
    if [[ -f "$test_file" ]]; then
        echo -e "${YELLOW}⚠️  Test already exists: $test_file${NC}"
        return 1
    fi
    
    # Get template
    local template_file="$TEST_ROOT/templates/${test_type}_test.sh"
    if [[ ! -f "$template_file" ]]; then
        echo -e "${RED}❌ Template not found: $template_file${NC}"
        return 1
    fi
    
    # Create test from template
    sed "s/{{TEST_NAME}}/$test_name/g; s/{{TEST_DESCRIPTION}}/Test for $test_name/g" "$template_file" > "$test_file"
    chmod +x "$test_file"
    
    echo -e "${GREEN}✅ Created test: $test_file${NC}"
    echo "Edit the test file to implement your test logic."
}

# List available tests
list_tests() {
    local category="${1:-}"
    
    echo -e "${CYAN}=== Available Tests ===${NC}"
    
    if [[ -z "$category" ]]; then
        # List all test categories
        for test_type in unit integration system performance security regression; do
            local test_dir="$TEST_ROOT/$test_type"
            if [[ -d "$test_dir" ]]; then
                local count=$(find "$test_dir" -name "*.sh" -type f 2>/dev/null | wc -l)
                if [[ $count -gt 0 ]]; then
                    echo -e "${YELLOW}$test_type tests ($count):${NC}"
                    find "$test_dir" -name "*.sh" -type f 2>/dev/null | while read -r test_file; do
                        echo "  $(basename "$test_file" .sh)"
                    done
                    echo ""
                fi
            fi
        done
    else
        # List specific category
        local test_dir="$TEST_ROOT/$category"
        if [[ ! -d "$test_dir" ]]; then
            echo -e "${RED}❌ Test category not found: $category${NC}"
            return 1
        fi
        
        echo -e "${YELLOW}$category tests:${NC}"
        find "$test_dir" -name "*.sh" -type f 2>/dev/null | while read -r test_file; do
            echo "  $(basename "$test_file" .sh)"
        done
    fi
}

# Run tests
run_tests() {
    local test_suite="${1:-all}"
    shift || true
    
    # Parse options
    local VERBOSE=false
    local QUIET=false
    local PARALLEL=false
    local TIMEOUT=30
    local RETRY=0
    local FILTER=""
    local COVERAGE=false
    local REPORT_FORMAT="text"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --retry)
                RETRY="$2"
                shift 2
                ;;
            --filter)
                FILTER="$2"
                shift 2
                ;;
            --coverage)
                COVERAGE=true
                shift
                ;;
            --report-format)
                REPORT_FORMAT="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done
    
    # Generate run ID
    local run_id="test_$(date +%Y%m%d_%H%M%S)_$$"
    local start_time=$(date +%s)
    
    echo -e "${CYAN}=== Running Tests ===${NC}"
    echo "Run ID: $run_id"
    echo "Test Suite: $test_suite"
    echo "Options: $(if [[ "$VERBOSE" == "true" ]]; then echo -n "verbose "; fi)$(if [[ "$PARALLEL" == "true" ]]; then echo -n "parallel "; fi)$(if [[ "$COVERAGE" == "true" ]]; then echo -n "coverage "; fi)"
    echo ""
    
    # Initialize test run in database
    init_test_run "$run_id"
    
    # Collect test files
    local test_files=()
    if [[ "$test_suite" == "all" ]]; then
        # Get all test files
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$TEST_ROOT" -name "*.sh" -type f -print0 2>/dev/null)
    else
        # Get tests from specific suite
        local test_dir="$TEST_ROOT/$test_suite"
        if [[ ! -d "$test_dir" ]]; then
            echo -e "${RED}❌ Test suite not found: $test_suite${NC}"
            return 1
        fi
        
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$test_dir" -name "*.sh" -type f -print0 2>/dev/null)
    fi
    
    # Apply filter if specified
    if [[ -n "$FILTER" ]]; then
        local filtered_files=()
        for file in "${test_files[@]}"; do
            if [[ "$(basename "$file")" =~ $FILTER ]]; then
                filtered_files+=("$file")
            fi
        done
        test_files=("${filtered_files[@]}")
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No tests found for suite: $test_suite${NC}"
        return 0
    fi
    
    echo "Found ${#test_files[@]} tests to run"
    echo ""
    
    # Run tests
    local total_tests=${#test_files[@]}
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0
    
    if [[ "$PARALLEL" == "true" ]]; then
        # Run tests in parallel
        run_tests_parallel "${test_files[@]}"
    else
        # Run tests sequentially
        for test_file in "${test_files[@]}"; do
            run_single_test "$test_file" "$run_id"
            local result=$?
            case $result in
                0) passed_tests=$((passed_tests + 1)) ;;
                1) failed_tests=$((failed_tests + 1)) ;;
                2) skipped_tests=$((skipped_tests + 1)) ;;
            esac
        done
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update test run in database
    update_test_run "$run_id" "$total_tests" "$passed_tests" "$failed_tests" "$skipped_tests" "$duration"
    
    # Generate report
    generate_test_report "$run_id" "$REPORT_FORMAT"
    
    # Show summary
    echo ""
    echo -e "${CYAN}=== Test Summary ===${NC}"
    echo "Run ID: $run_id"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Skipped: $skipped_tests"
    echo "Duration: ${duration}s"
    
    # Send notification
    if [[ -f "$NOTIFY_MODULE" ]]; then
        local status="success"
        if [[ $failed_tests -gt 0 ]]; then
            status="warning"
        fi
        "$NOTIFY_MODULE" send "$status" "Test Run Complete" "Tests: $passed_tests passed, $failed_tests failed" "{\"run_id\": \"$run_id\", \"passed\": \"$passed_tests\", \"failed\": \"$failed_tests\", \"duration\": \"${duration}s\"}"
    fi
    
    return $((failed_tests > 0 ? 1 : 0))
}

# Run single test
run_single_test() {
    local test_file="$1"
    local run_id="$2"
    
    local test_name=$(basename "$test_file" .sh)
    local test_type=$(basename "$(dirname "$test_file")")
    local test_start_time=$(date +%s)
    
    echo -e "${CYAN}Running: $test_name${NC}"
    
    # Record test start
    record_test_start "$run_id" "$test_name" "$test_type"
    
    # Run test with timeout
    local output
    local exit_code
    if output=$(timeout "$TIMEOUT" bash "$test_file" 2>&1); then
        exit_code=0
        status="passed"
        echo -e "${GREEN}✅ PASS: $test_name${NC}"
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            status="timeout"
            echo -e "${RED}⏰ TIMEOUT: $test_name${NC}"
        else
            status="failed"
            echo -e "${RED}❌ FAIL: $test_name${NC}"
        fi
    fi
    
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))
    
    # Record test result
    record_test_result "$run_id" "$test_name" "$test_type" "$status" "$test_duration" "$output"
    
    return $exit_code
}

# Run tests in parallel
run_tests_parallel() {
    local test_files=("$@")
    local max_jobs=4  # Limit parallel jobs
    
    echo "Running tests in parallel (max $max_jobs jobs)"
    
    # Use GNU parallel if available, otherwise use background jobs
    if command -v parallel >/dev/null 2>&1; then
        parallel -j "$max_jobs" run_single_test ::: "${test_files[@]}"
    else
        # Simple parallel execution with background jobs
        local job_count=0
        for test_file in "${test_files[@]}"; do
            if [[ $job_count -ge $max_jobs ]]; then
                wait -n
                job_count=$((job_count - 1))
            fi
            run_single_test "$test_file" &
            job_count=$((job_count + 1))
        done
        wait
    fi
}

# Database functions
init_test_run() {
    local run_id="$1"
    local db_file="$GRIM_ROOT/db/testing.db"
    
    sqlite3 "$db_file" "INSERT INTO test_runs (run_id, environment) VALUES ('$run_id', '$(uname -a)')"
}

update_test_run() {
    local run_id="$1"
    local total="$2"
    local passed="$3"
    local failed="$4"
    local skipped="$5"
    local duration="$6"
    local db_file="$GRIM_ROOT/db/testing.db"
    
    local status="completed"
    if [[ $failed -gt 0 ]]; then
        status="failed"
    fi
    
    sqlite3 "$db_file" "UPDATE test_runs SET total_tests=$total, passed_tests=$passed, failed_tests=$failed, skipped_tests=$skipped, duration=$duration, end_time=CURRENT_TIMESTAMP, status='$status' WHERE run_id='$run_id'"
}

record_test_start() {
    local run_id="$1"
    local test_name="$2"
    local test_type="$3"
    local db_file="$GRIM_ROOT/db/testing.db"
    
    sqlite3 "$db_file" "INSERT INTO test_results (run_id, test_name, test_type, status) VALUES ('$run_id', '$test_name', '$test_type', 'running')"
}

record_test_result() {
    local run_id="$1"
    local test_name="$2"
    local test_type="$3"
    local status="$4"
    local duration="$5"
    local output="$6"
    local db_file="$GRIM_ROOT/db/testing.db"
    
    sqlite3 "$db_file" "UPDATE test_results SET status='$status', duration=$duration, end_time=CURRENT_TIMESTAMP, output='$(echo "$output" | sqlite3_escape)' WHERE run_id='$run_id' AND test_name='$test_name'"
}

# Generate test report
generate_test_report() {
    local run_id="$1"
    local format="$2"
    local db_file="$GRIM_ROOT/db/testing.db"
    
    case "$format" in
        html)
            generate_html_report "$run_id"
            ;;
        json)
            generate_json_report "$run_id"
            ;;
        xml)
            generate_xml_report "$run_id"
            ;;
        *)
            generate_text_report "$run_id"
            ;;
    esac
}

# Generate text report
generate_text_report() {
    local run_id="$1"
    local db_file="$GRIM_ROOT/db/testing.db"
    local report_file="$REPORTS_DIR/${run_id}_report.txt"
    
    {
        echo "Grimm Test Report"
        echo "================="
        echo "Run ID: $run_id"
        echo "Generated: $(date)"
        echo ""
        
        # Get run summary
        local summary=$(sqlite3 "$db_file" "SELECT total_tests, passed_tests, failed_tests, skipped_tests, duration, status FROM test_runs WHERE run_id='$run_id'")
        IFS='|' read -r total passed failed skipped duration status <<< "$summary"
        
        echo "Summary:"
        echo "  Total Tests: $total"
        echo "  Passed: $passed"
        echo "  Failed: $failed"
        echo "  Skipped: $skipped"
        echo "  Duration: ${duration}s"
        echo "  Status: $status"
        echo ""
        
        # Get failed tests
        local failed_tests=$(sqlite3 "$db_file" "SELECT test_name, error_message FROM test_results WHERE run_id='$run_id' AND status='failed'")
        if [[ -n "$failed_tests" ]]; then
            echo "Failed Tests:"
            echo "$failed_tests" | while IFS='|' read -r test_name error_message; do
                echo "  $test_name: $error_message"
            done
            echo ""
        fi
        
        # Get all test results
        echo "Test Results:"
        sqlite3 "$db_file" "SELECT test_name, status, duration FROM test_results WHERE run_id='$run_id' ORDER BY test_name" | while IFS='|' read -r test_name status duration; do
            echo "  $test_name: $status (${duration}s)"
        done
    } > "$report_file"
    
    echo "Report generated: $report_file"
}

# Main command handler
main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        run)
            run_tests "$@"
            ;;
        create)
            create_test "$@"
            ;;
        list)
            list_tests "$@"
            ;;
        info)
            # TODO: Implement test info
            echo "Test info not yet implemented"
            ;;
        validate)
            # TODO: Implement test validation
            echo "Test validation not yet implemented"
            ;;
        report)
            # TODO: Implement report viewing
            echo "Report viewing not yet implemented"
            ;;
        coverage)
            # TODO: Implement coverage analysis
            echo "Coverage analysis not yet implemented"
            ;;
        benchmark)
            # TODO: Implement benchmarking
            echo "Benchmarking not yet implemented"
            ;;
        ci)
            # TODO: Implement CI mode
            echo "CI mode not yet implemented"
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

# Show testing system status
show_status() {
    echo -e "${CYAN}=== Testing System Status ===${NC}"
    
    # Check test directories
    local total_tests=0
    for test_type in unit integration system performance security regression; do
        local test_dir="$TEST_ROOT/$test_type"
        if [[ -d "$test_dir" ]]; then
            local count=$(find "$test_dir" -name "*.sh" -type f 2>/dev/null | wc -l)
            echo "$test_type tests: $count"
            total_tests=$((total_tests + count))
        else
            echo "$test_type tests: 0 (directory not found)"
        fi
    done
    
    echo ""
    echo "Total tests: $total_tests"
    echo "Test root: $TEST_ROOT"
    echo "Reports directory: $REPORTS_DIR"
    echo "Log file: $LOG_FILE"
    
    # Check recent test runs
    local db_file="$GRIM_ROOT/db/testing.db"
    if [[ -f "$db_file" ]]; then
        echo ""
        echo -e "${YELLOW}Recent Test Runs:${NC}"
        sqlite3 "$db_file" "SELECT run_id, status, passed_tests, failed_tests, duration FROM test_runs ORDER BY start_time DESC LIMIT 5" | while IFS='|' read -r run_id status passed failed duration; do
            echo "  $run_id: $status ($passed passed, $failed failed, ${duration}s)"
        done
    fi
}

# Only call main if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # Initialize test environment on first run
    if [[ ! -d "$TEST_ROOT/templates" ]]; then
        init_test_env
    fi
    
    main "$@"
fi 