#!/bin/bash
# Grimm Security Testing Module
# Comprehensive security penetration testing and vulnerability scanning

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECURITY_DIR="$PROJECT_ROOT/tests/security"
SCAN_DIR="$SECURITY_DIR/security_scans"
REPORTS_DIR="$SECURITY_DIR/security_reports"

# Security thresholds
MAX_CRITICAL_VULNERABILITIES=0
MAX_HIGH_VULNERABILITIES=2
MAX_MEDIUM_VULNERABILITIES=5
MAX_LOW_VULNERABILITIES=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Security tracking
TOTAL_SCANS=0
PASSED_SCANS=0
FAILED_SCANS=0
CRITICAL_VULNS=0
HIGH_VULNS=0
MEDIUM_VULNS=0
LOW_VULNS=0
START_TIME=$(date +%s)

# Logging functions
log_info() {
    echo -e "${BLUE}[SECURITY]${NC} $1"
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

log_vulnerability() {
    echo -e "${MAGENTA}[VULNERABILITY]${NC} $1"
}

# Initialize security testing environment
init_security_testing() {
    log_info "Initializing Security Testing Environment..."
    
    mkdir -p "$SECURITY_DIR"
    mkdir -p "$SCAN_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$SECURITY_DIR/penetration_tests"
    mkdir -p "$SECURITY_DIR/vulnerability_scans"
    mkdir -p "$SECURITY_DIR/security_audits"
    
    # Set security environment variables
    export GRIMM_SECURITY_MODE=true
    export GRIMM_SECURITY_DIR="$SECURITY_DIR"
    
    log_success "Security testing environment initialized"
}

# File Permissions Security Test
test_file_permissions() {
    log_info "Running File Permissions Security Test"
    
    local test_name="file_permissions"
    local results_file="$SCAN_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    # Test file permission security
    local permission_tests=(
        "world_writable_files"
        "world_readable_files"
        "suid_files"
        "sgid_files"
        "sticky_bit"
    )
    
    for test in "${permission_tests[@]}"; do
        # Test file permissions
        case "$test" in
            "world_writable_files")
                # Find world writable files
                local world_writable=$(find "$PROJECT_ROOT" -perm -002 -type f 2>/dev/null | wc -l)
                if [ "$world_writable" -gt 0 ]; then
                    vulnerabilities+=("WORLD_WRITABLE:$world_writable world writable files found")
                fi
                ;;
            "world_readable_files")
                # Find world readable sensitive files
                local world_readable=$(find "$PROJECT_ROOT" -name "*.key" -o -name "*.pem" -o -name "*.conf" -perm -004 -type f 2>/dev/null | wc -l)
                if [ "$world_readable" -gt 0 ]; then
                    vulnerabilities+=("WORLD_READABLE:$world_readable sensitive world readable files found")
                fi
                ;;
            "suid_files")
                # Find SUID files
                local suid_files=$(find "$PROJECT_ROOT" -perm -4000 -type f 2>/dev/null | wc -l)
                if [ "$suid_files" -gt 0 ]; then
                    vulnerabilities+=("SUID_FILES:$suid_files SUID files found")
                fi
                ;;
            "sgid_files")
                # Find SGID files
                local sgid_files=$(find "$PROJECT_ROOT" -perm -2000 -type f 2>/dev/null | wc -l)
                if [ "$sgid_files" -gt 0 ]; then
                    vulnerabilities+=("SGID_FILES:$sgid_files SGID files found")
                fi
                ;;
            "sticky_bit")
                # Check sticky bit on directories
                local sticky_dirs=$(find "$PROJECT_ROOT" -perm -1000 -type d 2>/dev/null | wc -l)
                if [ "$sticky_dirs" -gt 0 ]; then
                    vulnerabilities+=("STICKY_BIT:$sticky_dirs directories with sticky bit found")
                fi
                ;;
        esac
    done
    
    # Generate results
    local vuln_count=${#vulnerabilities[@]}
    local status="PASSED"
    if [ $vuln_count -gt 0 ]; then
        status="FAILED"
        MEDIUM_VULNS=$((MEDIUM_VULNS + vuln_count))
    fi
    
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "vulnerabilities_found": $vuln_count,
  "status": "$status",
  "vulnerabilities": [
EOF
    
    for i in "${!vulnerabilities[@]}"; do
        cat >> "$results_file" <<EOF
    {
      "type": "FILE_PERMISSIONS",
      "description": "${vulnerabilities[$i]}",
      "severity": "MEDIUM"
    }$(if [ $i -lt $((${#vulnerabilities[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    # Update counters
    TOTAL_SCANS=$((TOTAL_SCANS + 1))
    if [ "$status" = "PASSED" ]; then
        PASSED_SCANS=$((PASSED_SCANS + 1))
        log_success "File permissions test passed"
    else
        FAILED_SCANS=$((FAILED_SCANS + 1))
        log_vulnerability "File permissions test failed: $vuln_count vulnerabilities found"
    fi
    
    echo "$results_file"
}

# Network Security Test
test_network_security() {
    log_info "Running Network Security Test"
    
    local test_name="network_security"
    local results_file="$SCAN_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    # Test network security
    local network_tests=(
        "open_ports"
        "unencrypted_communication"
        "weak_protocols"
        "dns_security"
    )
    
    for test in "${network_tests[@]}"; do
        case "$test" in
            "open_ports")
                # Check for unnecessary open ports
                local open_ports=$(netstat -tlnp 2>/dev/null | grep LISTEN | wc -l)
                if [ "$open_ports" -gt 5 ]; then
                    vulnerabilities+=("OPEN_PORTS:Too many open ports: $open_ports")
                fi
                ;;
            "unencrypted_communication")
                # Test for unencrypted communication
                if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                    if "$PROJECT_ROOT/reaper.sh" --network-test 2>&1 | grep -i "http\|ftp\|telnet" > /dev/null; then
                        vulnerabilities+=("UNENCRYPTED_COMM:Unencrypted communication detected")
                    fi
                fi
                ;;
            "weak_protocols")
                # Test for weak protocols
                if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                    if "$PROJECT_ROOT/reaper.sh" --protocol-test 2>&1 | grep -i "ssl2\|ssl3\|tls1.0" > /dev/null; then
                        vulnerabilities+=("WEAK_PROTOCOLS:Weak protocols detected")
                    fi
                fi
                ;;
            "dns_security")
                # Test DNS security
                if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                    if "$PROJECT_ROOT/reaper.sh" --dns-test 2>&1 | grep -i "dnssec\|dns-over-https" > /dev/null; then
                        log_success "DNS security test passed"
                    else
                        vulnerabilities+=("DNS_SECURITY:DNS security not configured")
                    fi
                fi
                ;;
        esac
    done
    
    # Generate results
    local vuln_count=${#vulnerabilities[@]}
    local status="PASSED"
    if [ $vuln_count -gt 0 ]; then
        status="FAILED"
        MEDIUM_VULNS=$((MEDIUM_VULNS + vuln_count))
    fi
    
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "vulnerabilities_found": $vuln_count,
  "status": "$status",
  "vulnerabilities": [
EOF
    
    for i in "${!vulnerabilities[@]}"; do
        cat >> "$results_file" <<EOF
    {
      "type": "NETWORK_SECURITY",
      "description": "${vulnerabilities[$i]}",
      "severity": "MEDIUM"
    }$(if [ $i -lt $((${#vulnerabilities[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    # Update counters
    TOTAL_SCANS=$((TOTAL_SCANS + 1))
    if [ "$status" = "PASSED" ]; then
        PASSED_SCANS=$((PASSED_SCANS + 1))
        log_success "Network security test passed"
    else
        FAILED_SCANS=$((FAILED_SCANS + 1))
        log_vulnerability "Network security test failed: $vuln_count vulnerabilities found"
    fi
    
    echo "$results_file"
}

# Encryption Validation Test
test_encryption_validation() {
    log_info "Running Encryption Validation Test"
    
    local test_name="encryption_validation"
    local results_file="$SCAN_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    # Test encryption security
    local encryption_tests=(
        "weak_encryption"
        "missing_encryption"
        "encryption_key_exposure"
        "encryption_algorithm"
    )
    
    for test in "${encryption_tests[@]}"; do
        # Test encryption security
        if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
            case "$test" in
                "weak_encryption")
                    # Test for weak encryption algorithms
                    if "$PROJECT_ROOT/reaper.sh" --encryption-test 2>&1 | grep -i "md5\|des\|rc4" > /dev/null; then
                        vulnerabilities+=("WEAK_ENCRYPTION:Weak encryption algorithm detected")
                    fi
                    ;;
                "missing_encryption")
                    # Test for missing encryption
                    if "$PROJECT_ROOT/reaper.sh" --encryption-test 2>&1 | grep -i "plaintext\|unencrypted" > /dev/null; then
                        vulnerabilities+=("MISSING_ENCRYPTION:Sensitive data not encrypted")
                    fi
                    ;;
                "encryption_key_exposure")
                    # Test for key exposure
                    if "$PROJECT_ROOT/reaper.sh" --encryption-test 2>&1 | grep -i "key.*exposed\|password.*plain" > /dev/null; then
                        vulnerabilities+=("KEY_EXPOSURE:Encryption key exposed")
                    fi
                    ;;
                "encryption_algorithm")
                    # Test encryption algorithm strength
                    if "$PROJECT_ROOT/reaper.sh" --encryption-test 2>&1 | grep -i "aes-128\|sha-1" > /dev/null; then
                        vulnerabilities+=("WEAK_ALGORITHM:Weak encryption algorithm used")
                    fi
                    ;;
            esac
        fi
    done
    
    # Generate results
    local vuln_count=${#vulnerabilities[@]}
    local status="PASSED"
    if [ $vuln_count -gt 0 ]; then
        status="FAILED"
        HIGH_VULNS=$((HIGH_VULNS + vuln_count))
    fi
    
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "vulnerabilities_found": $vuln_count,
  "status": "$status",
  "vulnerabilities": [
EOF
    
    for i in "${!vulnerabilities[@]}"; do
        cat >> "$results_file" <<EOF
    {
      "type": "ENCRYPTION",
      "description": "${vulnerabilities[$i]}",
      "severity": "HIGH"
    }$(if [ $i -lt $((${#vulnerabilities[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    # Update counters
    TOTAL_SCANS=$((TOTAL_SCANS + 1))
    if [ "$status" = "PASSED" ]; then
        PASSED_SCANS=$((PASSED_SCANS + 1))
        log_success "Encryption validation test passed"
    else
        FAILED_SCANS=$((FAILED_SCANS + 1))
        log_vulnerability "Encryption validation test failed: $vuln_count vulnerabilities found"
    fi
    
    echo "$results_file"
}

# Access Control Test
test_access_control() {
    log_info "Running Access Control Test"
    
    local test_name="access_control"
    local results_file="$SCAN_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    # Test access control
    local access_tests=(
        "direct_file_access"
        "parameter_manipulation"
        "url_manipulation"
    )
    
    for test in "${access_tests[@]}"; do
        # Test access control bypass attempts
        if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
            case "$test" in
                "direct_file_access")
                    # Test direct access to sensitive files
                    if "$PROJECT_ROOT/reaper.sh" --access-file "/etc/passwd" 2>&1 | grep -i "success\|accessed" > /dev/null; then
                        vulnerabilities+=("ACCESS_CONTROL_BYPASS:Direct file access bypass")
                    fi
                    ;;
                "parameter_manipulation")
                    # Test parameter manipulation
                    if "$PROJECT_ROOT/reaper.sh" --manipulate-param "user_id=1" 2>&1 | grep -i "success\|accessed" > /dev/null; then
                        vulnerabilities+=("ACCESS_CONTROL_BYPASS:Parameter manipulation bypass")
                    fi
                    ;;
                "url_manipulation")
                    # Test URL manipulation
                    if "$PROJECT_ROOT/reaper.sh" --manipulate-url "/admin/users" 2>&1 | grep -i "success\|accessed" > /dev/null; then
                        vulnerabilities+=("ACCESS_CONTROL_BYPASS:URL manipulation bypass")
                    fi
                    ;;
            esac
        fi
    done
    
    # Generate results
    local vuln_count=${#vulnerabilities[@]}
    local status="PASSED"
    if [ $vuln_count -gt 0 ]; then
        status="FAILED"
        CRITICAL_VULNS=$((CRITICAL_VULNS + vuln_count))
    fi
    
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "vulnerabilities_found": $vuln_count,
  "status": "$status",
  "vulnerabilities": [
EOF
    
    for i in "${!vulnerabilities[@]}"; do
        cat >> "$results_file" <<EOF
    {
      "type": "ACCESS_CONTROL",
      "description": "${vulnerabilities[$i]}",
      "severity": "CRITICAL"
    }$(if [ $i -lt $((${#vulnerabilities[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    # Update counters
    TOTAL_SCANS=$((TOTAL_SCANS + 1))
    if [ "$status" = "PASSED" ]; then
        PASSED_SCANS=$((PASSED_SCANS + 1))
        log_success "Access control test passed"
    else
        FAILED_SCANS=$((FAILED_SCANS + 1))
        log_vulnerability "Access control test failed: $vuln_count vulnerabilities found"
    fi
    
    echo "$results_file"
}

# Authentication Test
test_authentication() {
    log_info "Running Authentication Test"
    
    local test_name="authentication"
    local results_file="$SCAN_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    # Test authentication bypass attempts
    local auth_bypass_tests=(
        "null_credentials:"
        "empty_credentials:"
        "admin_admin:admin:admin"
        "default_credentials:admin:password"
        "weak_credentials:user:123456"
    )
    
    for test in "${auth_bypass_tests[@]}"; do
        IFS=':' read -r test_type username password <<< "$test"
        
        # Test authentication with various credentials
        if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
            # Set test credentials
            export GRIMM_TEST_USER="$username"
            export GRIMM_TEST_PASS="$password"
            
            # Attempt authentication
            if "$PROJECT_ROOT/reaper.sh" --auth-test 2>&1 | grep -i "authenticated\|success\|welcome" > /dev/null; then
                vulnerabilities+=("AUTH_BYPASS:Authentication bypass with $test_type credentials")
            fi
        fi
    done
    
    # Generate results
    local vuln_count=${#vulnerabilities[@]}
    local status="PASSED"
    if [ $vuln_count -gt 0 ]; then
        status="FAILED"
        CRITICAL_VULNS=$((CRITICAL_VULNS + vuln_count))
    fi
    
    cat > "$results_file" <<EOF
{
  "test_name": "$test_name",
  "timestamp": "$(date -Iseconds)",
  "vulnerabilities_found": $vuln_count,
  "status": "$status",
  "vulnerabilities": [
EOF
    
    for i in "${!vulnerabilities[@]}"; do
        cat >> "$results_file" <<EOF
    {
      "type": "AUTHENTICATION",
      "description": "${vulnerabilities[$i]}",
      "severity": "CRITICAL"
    }$(if [ $i -lt $((${#vulnerabilities[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    # Update counters
    TOTAL_SCANS=$((TOTAL_SCANS + 1))
    if [ "$status" = "PASSED" ]; then
        PASSED_SCANS=$((PASSED_SCANS + 1))
        log_success "Authentication test passed"
    else
        FAILED_SCANS=$((FAILED_SCANS + 1))
        log_vulnerability "Authentication test failed: $vuln_count vulnerabilities found"
    fi
    
    echo "$results_file"
}

# Vulnerability Scanning
run_vulnerability_scan() {
    log_info "Running Comprehensive Vulnerability Scan"
    
    local scan_name="vulnerability_scan"
    local results_file="$SCAN_DIR/${scan_name}_$(date +%Y%m%d_%H%M%S).json"
    local vulnerabilities=()
    
    # Run all security tests
    local security_tests=(
        "test_file_permissions"
        "test_network_security"
        "test_encryption_validation"
        "test_access_control"
        "test_authentication"
    )
    
    for test_func in "${security_tests[@]}"; do
        if declare -f "$test_func" > /dev/null; then
            local test_result=$($test_func)
            if [ -f "$test_result" ]; then
                local vuln_count=$(jq -r '.vulnerabilities_found' "$test_result" 2>/dev/null || echo "0")
                if [ "$vuln_count" -gt 0 ]; then
                    local vuln_details=$(jq -r '.vulnerabilities[] | "\(.type):\(.description)"' "$test_result" 2>/dev/null)
                    while IFS= read -r vuln; do
                        vulnerabilities+=("$vuln")
                    done <<< "$vuln_details"
                fi
            fi
        fi
    done
    
    # Generate comprehensive scan report
    local total_vulns=${#vulnerabilities[@]}
    local status="PASSED"
    if [ $total_vulns -gt 0 ]; then
        status="FAILED"
    fi
    
    cat > "$results_file" <<EOF
{
  "scan_name": "$scan_name",
  "timestamp": "$(date -Iseconds)",
  "total_vulnerabilities": $total_vulns,
  "critical_vulnerabilities": $CRITICAL_VULNS,
  "high_vulnerabilities": $HIGH_VULNS,
  "medium_vulnerabilities": $MEDIUM_VULNS,
  "low_vulnerabilities": $LOW_VULNS,
  "status": "$status",
  "vulnerabilities": [
EOF
    
    for i in "${!vulnerabilities[@]}"; do
        IFS=':' read -r vuln_type description <<< "${vulnerabilities[$i]}"
        cat >> "$results_file" <<EOF
    {
      "type": "$vuln_type",
      "description": "$description",
      "severity": "$(determine_severity "$vuln_type")"
    }$(if [ $i -lt $((${#vulnerabilities[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    log_success "Vulnerability scan completed: $results_file"
    echo "$results_file"
}

# Penetration Testing
run_penetration_tests() {
    log_info "Running Penetration Tests"
    
    local penetration_dir="$SECURITY_DIR/penetration_tests"
    local results_file="$SCAN_DIR/penetration_test_$(date +%Y%m%d_%H%M%S).json"
    
    # Penetration test scenarios
    local penetration_scenarios=(
        "sql_injection"
        "cross_site_scripting"
        "command_injection"
        "path_traversal"
        "privilege_escalation"
    )
    
    local penetration_results=()
    
    for scenario in "${penetration_scenarios[@]}"; do
        log_info "Running penetration test: $scenario"
        
        local scenario_start=$(date +%s.%N)
        local vulnerability_found=false
        
        # Run penetration test based on scenario
        case "$scenario" in
            "sql_injection")
                # Test SQL injection vulnerabilities
                local sql_payloads=("' OR '1'='1" "'; DROP TABLE users; --" "' UNION SELECT * FROM users --")
                for payload in "${sql_payloads[@]}"; do
                    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                        if "$PROJECT_ROOT/reaper.sh" --sql-test "$payload" 2>&1 | grep -i "sql\|injection\|error" > /dev/null; then
                            vulnerability_found=true
                            break
                        fi
                    fi
                done
                ;;
            "cross_site_scripting")
                # Test XSS vulnerabilities
                local xss_payloads=("<script>alert('XSS')</script>" "<img src=x onerror=alert('XSS')>" "javascript:alert('XSS')")
                for payload in "${xss_payloads[@]}"; do
                    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                        if "$PROJECT_ROOT/reaper.sh" --xss-test "$payload" 2>&1 | grep -i "script\|alert\|xss" > /dev/null; then
                            vulnerability_found=true
                            break
                        fi
                    fi
                done
                ;;
            "command_injection")
                # Test command injection vulnerabilities
                local cmd_payloads=("$(whoami)" "`id`" "; rm -rf /" "| cat /etc/passwd")
                for payload in "${cmd_payloads[@]}"; do
                    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                        if "$PROJECT_ROOT/reaper.sh" --cmd-test "$payload" 2>&1 | grep -i "uid\|gid\|root\|command" > /dev/null; then
                            vulnerability_found=true
                            break
                        fi
                    fi
                done
                ;;
            "path_traversal")
                # Test path traversal vulnerabilities
                local path_payloads=("../../../etc/passwd" "..\\..\\..\\windows\\system32\\config\\sam" "....//....//....//etc/passwd")
                for payload in "${path_payloads[@]}"; do
                    if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                        if "$PROJECT_ROOT/reaper.sh" --path-test "$payload" 2>&1 | grep -i "passwd\|system32\|traversal" > /dev/null; then
                            vulnerability_found=true
                            break
                        fi
                    fi
                done
                ;;
            "privilege_escalation")
                # Test privilege escalation vulnerabilities
                if [ -f "$PROJECT_ROOT/reaper.sh" ]; then
                    export GRIMM_TEST_ROLE="user"
                    if "$PROJECT_ROOT/reaper.sh" --admin-operation 2>&1 | grep -i "success\|completed" > /dev/null; then
                        vulnerability_found=true
                    fi
                fi
                ;;
        esac
        
        local scenario_end=$(date +%s.%N)
        local scenario_duration=$(echo "$scenario_end - $scenario_start" | bc -l)
        
        # Store penetration results
        penetration_results+=("$scenario:$vulnerability_found:$scenario_duration")
        
        if [ "$vulnerability_found" = true ]; then
            log_vulnerability "Penetration test $scenario: VULNERABILITY FOUND"
            CRITICAL_VULNS=$((CRITICAL_VULNS + 1))
        else
            log_success "Penetration test $scenario: No vulnerabilities found"
        fi
    done
    
    # Generate penetration test report
    cat > "$results_file" <<EOF
{
  "test_type": "penetration_test",
  "timestamp": "$(date -Iseconds)",
  "scenarios": [
EOF
    
    for i in "${!penetration_results[@]}"; do
        IFS=':' read -r name vulnerability_found duration <<< "${penetration_results[$i]}"
        
        cat >> "$results_file" <<EOF
    {
      "name": "$name",
      "vulnerability_found": $vulnerability_found,
      "duration_seconds": $duration,
      "status": "$(if [ "$vulnerability_found" = false ]; then echo "PASSED"; else echo "FAILED"; fi)"
    }$(if [ $i -lt $((${#penetration_results[@]} - 1)) ]; then echo ","; fi)
EOF
    done
    
    cat >> "$results_file" <<EOF
  ]
}
EOF
    
    log_success "Penetration test completed: $results_file"
    echo "$results_file"
}

# Determine vulnerability severity
determine_severity() {
    local vuln_type="$1"
    
    case "$vuln_type" in
        *"AUTHENTICATION"*|*"AUTHORIZATION"*|*"ACCESS_CONTROL"*)
            echo "CRITICAL"
            ;;
        *"ENCRYPTION"*|*"INJECTION"*)
            echo "HIGH"
            ;;
        *"PERMISSIONS"*|*"NETWORK"*)
            echo "MEDIUM"
            ;;
        *)
            echo "LOW"
            ;;
    esac
}

# Generate Security Report
generate_security_report() {
    log_info "Generating Comprehensive Security Report"
    
    local report_file="$REPORTS_DIR/security_report_$(date +%Y%m%d_%H%M%S).md"
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    # Collect all scan results
    local scan_files=($(find "$SCAN_DIR" -name "*.json" -type f))
    
    cat > "$report_file" <<EOF
# Grimm Security Testing Report

## Executive Summary
- **Scan Duration**: ${duration} seconds
- **Total Scans**: $TOTAL_SCANS
- **Passed Scans**: $PASSED_SCANS
- **Failed Scans**: $FAILED_SCANS
- **Success Rate**: $(if [ $TOTAL_SCANS -gt 0 ]; then echo "$((PASSED_SCANS * 100 / TOTAL_SCANS))%"; else echo "N/A"; fi)

## Vulnerability Summary
- **Critical Vulnerabilities**: $CRITICAL_VULNS
- **High Vulnerabilities**: $HIGH_VULNS
- **Medium Vulnerabilities**: $MEDIUM_VULNS
- **Low Vulnerabilities**: $LOW_VULNS
- **Total Vulnerabilities**: $((CRITICAL_VULNS + HIGH_VULNS + MEDIUM_VULNS + LOW_VULNS))

## Security Thresholds
- **Max Critical**: $MAX_CRITICAL_VULNERABILITIES
- **Max High**: $MAX_HIGH_VULNERABILITIES
- **Max Medium**: $MAX_MEDIUM_VULNERABILITIES
- **Max Low**: $MAX_LOW_VULNERABILITIES

## Scan Results Summary

### Individual Scans
EOF
    
    for scan_file in "${scan_files[@]}"; do
        if [ -f "$scan_file" ]; then
            local scan_name=$(basename "$scan_file" .json)
            local status=$(jq -r '.status // "UNKNOWN"' "$scan_file" 2>/dev/null || echo "UNKNOWN")
            local vuln_count=$(jq -r '.vulnerabilities_found // .total_vulnerabilities // "0"' "$scan_file" 2>/dev/null || echo "0")
            
            cat >> "$report_file" <<EOF
- **$scan_name**: $status (Vulnerabilities: $vuln_count)
EOF
        fi
    done
    
    cat >> "$report_file" <<EOF

## Detailed Results

EOF
    
    for scan_file in "${scan_files[@]}"; do
        if [ -f "$scan_file" ]; then
            local scan_name=$(basename "$scan_file" .json)
            cat >> "$report_file" <<EOF
### $scan_name
\`\`\`json
$(cat "$scan_file")
\`\`\`

EOF
        fi
    done
    
    cat >> "$report_file" <<EOF
## Security Recommendations

$(generate_security_recommendations)

## Next Steps

$(generate_security_next_steps)
EOF
    
    log_success "Security report generated: $report_file"
    echo "$report_file"
}

# Generate security recommendations
generate_security_recommendations() {
    local recommendations=""
    
    if [ $CRITICAL_VULNS -gt 0 ]; then
        recommendations+="- **CRITICAL**: Address $CRITICAL_VULNS critical vulnerabilities immediately\n"
    fi
    
    if [ $HIGH_VULNS -gt 0 ]; then
        recommendations+="- **HIGH**: Fix $HIGH_VULNS high severity vulnerabilities\n"
    fi
    
    if [ $MEDIUM_VULNS -gt 0 ]; then
        recommendations+="- **MEDIUM**: Review $MEDIUM_VULNS medium severity vulnerabilities\n"
    fi
    
    if [ $LOW_VULNS -gt 0 ]; then
        recommendations+="- **LOW**: Consider addressing $LOW_VULNS low severity vulnerabilities\n"
    fi
    
    recommendations+="- **Ongoing**: Implement continuous security monitoring\n"
    recommendations+="- **Regular**: Schedule periodic security assessments\n"
    
    echo -e "$recommendations"
}

# Generate security next steps
generate_security_next_steps() {
    local next_steps=""
    
    if [ $CRITICAL_VULNS -gt 0 ]; then
        next_steps+="1. **Immediate**: Fix all critical vulnerabilities\n"
    fi
    
    if [ $HIGH_VULNS -gt 0 ]; then
        next_steps+="2. **High Priority**: Address high severity vulnerabilities\n"
    fi
    
    next_steps+="3. **Short-term**: Implement security best practices\n"
    next_steps+="4. **Medium-term**: Establish security monitoring\n"
    next_steps+="5. **Long-term**: Develop security incident response plan\n"
    
    echo -e "$next_steps"
}

# Main security testing execution
main() {
    log_info "Starting Grimm Security Testing Module"
    log_info "Security Thresholds: Critical=$MAX_CRITICAL_VULNERABILITIES, High=$MAX_HIGH_VULNERABILITIES"
    
    # Initialize security testing
    init_security_testing
    
    # Run comprehensive vulnerability scan
    local scan_result=$(run_vulnerability_scan)
    
    # Run penetration tests
    local penetration_result=$(run_penetration_tests)
    
    # Generate comprehensive report
    local report_file=$(generate_security_report)
    
    # Display final results
    log_info "Security testing completed!"
    log_info "Total scans: $TOTAL_SCANS"
    log_info "Passed: $PASSED_SCANS"
    log_info "Failed: $FAILED_SCANS"
    log_info "Vulnerabilities: Critical=$CRITICAL_VULNS, High=$HIGH_VULNS, Medium=$MEDIUM_VULNS, Low=$LOW_VULNS"
    log_info "Report: $report_file"
    
    # Check against thresholds
    local overall_status="PASSED"
    if [ $CRITICAL_VULNS -gt $MAX_CRITICAL_VULNERABILITIES ] || [ $HIGH_VULNS -gt $MAX_HIGH_VULNERABILITIES ]; then
        overall_status="FAILED"
    fi
    
    if [ "$overall_status" = "PASSED" ]; then
        log_success "Security testing passed all thresholds!"
        return 0
    else
        log_error "Security testing failed thresholds!"
        return 1
    fi
}

# Run security testing if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-main}" in
        vulnerability)
            log_info "Running Vulnerability Testing"
            init_security_testing
            run_vulnerability_scan
            generate_security_report
            ;;
        penetration)
            log_info "Running Penetration Testing"
            init_security_testing
            run_penetration_tests
            generate_security_report
            ;;
        compliance)
            log_info "Running Compliance Testing"
            init_security_testing
            # Run compliance-focused tests
            test_file_permissions
            test_access_control
            test_encryption_validation
            generate_security_report
            ;;
        report)
            log_info "Generating Security Testing Report"
            generate_security_report
            ;;
        help|--help|-h)
            echo "Security Testing Commands:"
            echo "  vulnerability  - Run vulnerability assessment"
            echo "  penetration   - Run penetration tests"
            echo "  compliance    - Run compliance checks"
            echo "  report        - Generate security report"
            echo "  help          - Show this help"
            ;;
        main|"")
            main "$@"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use 'security_testing.sh help' for available commands"
            exit 1
            ;;
    esac
fi 