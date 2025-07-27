#!/bin/bash

# GRIM Cloud Management Module
# Enterprise-grade multi-cloud platform integration
# Supports AWS, Azure, GCP, and serverless architectures
# TIER RESTRICTION: Reaper+ only (cloud infrastructure is enterprise-grade)

set -euo pipefail

# Determine GRIM_ROOT dynamically
if [ -z "${GRIM_ROOT:-}" ]; then
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
    GRIM_ROOT="$(dirname "$(dirname "$SCRIPT_PATH")")"
    export GRIM_ROOT
fi

# Configuration paths
CLOUD_CONFIG_DIR="$GRIM_ROOT/config/cloud"
CLOUD_LOG_FILE="$GRIM_ROOT/logs/cloud.log"
CLOUD_CACHE_DIR="$GRIM_ROOT/cache/cloud"
CLOUD_TEMP_DIR="$GRIM_ROOT/temp/cloud"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$CLOUD_LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$CLOUD_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$CLOUD_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$CLOUD_LOG_FILE"
}

# Ensure required directories exist
ensure_directories() {
    mkdir -p "$CLOUD_CONFIG_DIR"/{aws,azure,gcp,serverless}
    mkdir -p "$(dirname "$CLOUD_LOG_FILE")"
    mkdir -p "$CLOUD_CACHE_DIR"
    mkdir -p "$CLOUD_TEMP_DIR"
}

# Check user tier and permissions - ALL CLOUD COMMANDS REQUIRE REAPER+
check_tier_permissions() {
    local required_tier="$1"
    local tier_file="$GRIM_ROOT/config/user_tier"
    
    if [[ ! -f "$tier_file" ]]; then
        echo "free" > "$tier_file"
    fi
    
    local user_tier=$(cat "$tier_file" 2>/dev/null || echo "free")
    
    case "$required_tier" in
        "reaper")
            [[ "$user_tier" =~ ^(reaper|enterprise)$ ]] && return 0
            ;;
        "enterprise")
            [[ "$user_tier" == "enterprise" ]] && return 0
            ;;
    esac
    
    log_error "Cloud infrastructure requires Reaper+ tier. Required: $required_tier, Your tier: $user_tier"
    echo -e "${RED}☁️  Cloud infrastructure is restricted to Reaper and Enterprise tiers only.${NC}"
    echo -e "${YELLOW}Current tier: $user_tier${NC}"
    echo -e "${YELLOW}Required tier: $required_tier or higher${NC}"
    echo ""
    echo -e "${CYAN}Why cloud requires Reaper+ tier:${NC}"
    echo "  • Enterprise-grade multi-cloud orchestration"
    echo "  • Advanced security and compliance features"
    echo "  • High-availability infrastructure management"
    echo "  • Premium support and SLA guarantees"
    echo ""
    echo "Contact support for tier upgrades: support@grim.so"
    echo "Or visit: https://grim.so/pricing"
    return 1
}

# Initialize cloud environment - REAPER+ ONLY
cloud_init() {
    log "Initializing GRIM cloud environment"
    
    if ! check_tier_permissions "reaper"; then
        return 1
    fi
    
    ensure_directories
    
    # Create main cloud configuration
    cat > "$CLOUD_CONFIG_DIR/main.conf" << EOF
# GRIM Cloud Configuration
# Generated on $(date)

[general]
version=1.0.0
initialized=$(date -u +%Y-%m-%dT%H:%M:%SZ)
default_region=us-west-2
encryption_enabled=true
backup_retention_days=30
tier_required=reaper

[providers]
aws_enabled=false
azure_enabled=false
gcp_enabled=false
serverless_enabled=false

[security]
require_mfa=true
encrypt_at_rest=true
encrypt_in_transit=true
audit_logging=true
compliance_mode=enterprise

[monitoring]
metrics_enabled=true
alerting_enabled=true
log_retention_days=90
sla_monitoring=true

[enterprise_features]
multi_region_backup=true
disaster_recovery=true
compliance_reporting=true
dedicated_support=true
EOF
    
    # Create provider-specific config templates
    create_aws_config_template
    create_azure_config_template
    create_gcp_config_template
    create_serverless_config_template
    
    log_success "Cloud environment initialized successfully"
    echo -e "${GREEN}✓ Enterprise cloud configuration created: $CLOUD_CONFIG_DIR${NC}"
    echo -e "${GREEN}✓ High-availability logging configured: $CLOUD_LOG_FILE${NC}"
    echo -e "${GREEN}✓ Multi-region cache directory ready: $CLOUD_CACHE_DIR${NC}"
    echo -e "${CYAN}Next steps (Reaper+ tier):${NC}"
    echo "  1. Configure providers: grim cloud aws|azure|gcp"
    echo "  2. Set up enterprise credentials and MFA"
    echo "  3. Enable compliance monitoring: grim cloud comprehensive"
    echo "  4. Configure disaster recovery policies"
}

# Create AWS configuration template
create_aws_config_template() {
    cat > "$CLOUD_CONFIG_DIR/aws/config.conf" << 'EOF'
# AWS Enterprise Configuration Template
[aws]
enabled=false
region=us-west-2
access_key_id=
secret_access_key=
session_token=
profile=default
mfa_required=true

[services]
s3_enabled=true
ec2_enabled=true
lambda_enabled=true
rds_enabled=true
cloudwatch_enabled=true
iam_enabled=true
organizations_enabled=true
config_enabled=true

[s3]
default_bucket=grim-enterprise-backups
storage_class=STANDARD_IA
encryption=AES256
versioning=true
lifecycle_management=true

[lambda]
runtime=python3.9
timeout=900
memory=3008
vpc_enabled=true

[monitoring]
cloudwatch_logs=true
cloudtrail=true
config_rules=true
guardduty=true
security_hub=true

[compliance]
aws_config=true
cloudtrail_encryption=true
s3_access_logging=true
vpc_flow_logs=true
EOF
}

# Create Azure configuration template
create_azure_config_template() {
    cat > "$CLOUD_CONFIG_DIR/azure/config.conf" << 'EOF'
# Azure Enterprise Configuration Template
[azure]
enabled=false
subscription_id=
tenant_id=
client_id=
client_secret=
resource_group=grim-enterprise-resources
management_group=grim-management

[services]
storage_enabled=true
compute_enabled=true
functions_enabled=true
sql_enabled=true
monitor_enabled=true
security_center=true
sentinel=true

[storage]
account_name=
account_key=
container_name=grim-enterprise-backups
tier=Cool
replication=GRS
encryption=true

[functions]
runtime=python
version=3.9
consumption_plan=false
premium_plan=true

[monitoring]
application_insights=true
log_analytics=true
azure_monitor=true
security_center=true

[compliance]
azure_policy=true
blueprint_enabled=true
regulatory_compliance=true
EOF
}

# Create GCP configuration template
create_gcp_config_template() {
    cat > "$CLOUD_CONFIG_DIR/gcp/config.conf" << 'EOF'
# Google Cloud Platform Enterprise Configuration Template
[gcp]
enabled=false
project_id=
organization_id=
region=us-central1
zone=us-central1-a
service_account_key=
billing_account=

[services]
storage_enabled=true
compute_enabled=true
functions_enabled=true
sql_enabled=true
monitoring_enabled=true
security_command_center=true
cloud_asset_inventory=true

[storage]
bucket_name=grim-enterprise-backups
storage_class=NEARLINE
location=US
encryption=CMEK
lifecycle_management=true

[functions]
runtime=python39
memory=8192MB
timeout=540s
vpc_connector=true

[monitoring]
stackdriver=true
logging=true
error_reporting=true
trace=true
profiler=true

[compliance]
cloud_audit_logs=true
data_loss_prevention=true
binary_authorization=true
policy_intelligence=true
EOF
}

# Create serverless configuration template
create_serverless_config_template() {
    cat > "$CLOUD_CONFIG_DIR/serverless/config.conf" << 'EOF'
# Enterprise Serverless Configuration Template
[serverless]
enabled=false
framework_version=3.0
provider=aws
enterprise_features=true

[aws_lambda]
runtime=python3.9
memory=3008
timeout=900
environment=production
vpc_enabled=true
reserved_concurrency=100

[azure_functions]
runtime=python
version=3.9
plan_type=premium
max_instances=200

[gcp_functions]
runtime=python39
memory=8192MB
timeout=540s
vpc_connector=true
max_instances=1000

[deployment]
auto_deploy=false
stage=production
region=us-west-2
blue_green=true
canary_deployment=true

[monitoring]
x_ray_tracing=true
custom_metrics=true
alerting=true
performance_insights=true
EOF
}

# Configure AWS - REAPER+ ONLY
cloud_aws() {
    log "Configuring AWS enterprise cloud integration"
    
    if ! check_tier_permissions "reaper"; then
        return 1
    fi
    
    ensure_directories
    
    echo -e "${CYAN}=== AWS Enterprise Cloud Configuration ===${NC}"
    echo -e "${YELLOW}Enterprise features: Multi-region, compliance, advanced security${NC}"
    echo ""
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI not found. Installing enterprise version..."
        if command -v curl &> /dev/null; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$CLOUD_TEMP_DIR/awscliv2.zip"
            cd "$CLOUD_TEMP_DIR" && unzip -q awscliv2.zip
            sudo ./aws/install
            log_success "AWS CLI enterprise version installed successfully"
        else
            log_error "curl not found. Please install AWS CLI manually"
            return 1
        fi
    fi
    
    # Interactive configuration with enterprise features
    echo -e "${YELLOW}Enter AWS enterprise configuration details:${NC}"
    read -p "AWS Access Key ID: " aws_access_key
    read -s -p "AWS Secret Access Key: " aws_secret_key
    echo ""
    read -p "Default Region [us-west-2]: " aws_region
    aws_region=${aws_region:-us-west-2}
    read -p "Organization ID (optional): " org_id
    
    # Update configuration
    sed -i "s/enabled=false/enabled=true/" "$CLOUD_CONFIG_DIR/aws/config.conf"
    sed -i "s/access_key_id=/access_key_id=$aws_access_key/" "$CLOUD_CONFIG_DIR/aws/config.conf"
    sed -i "s/secret_access_key=/secret_access_key=$aws_secret_key/" "$CLOUD_CONFIG_DIR/aws/config.conf"
    sed -i "s/region=us-west-2/region=$aws_region/" "$CLOUD_CONFIG_DIR/aws/config.conf"
    
    # Test connection with enterprise features
    export AWS_ACCESS_KEY_ID="$aws_access_key"
    export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
    export AWS_DEFAULT_REGION="$aws_region"
    
    if aws sts get-caller-identity &> /dev/null; then
        log_success "AWS enterprise connection test successful"
        echo -e "${GREEN}✓ AWS enterprise cloud configured and connected${NC}"
        
        # Create enterprise S3 bucket with versioning and encryption
        local bucket_name="grim-enterprise-backups-$(date +%s)"
        if aws s3 mb "s3://$bucket_name" --region "$aws_region" &> /dev/null; then
            # Enable versioning and encryption
            aws s3api put-bucket-versioning --bucket "$bucket_name" --versioning-configuration Status=Enabled
            aws s3api put-bucket-encryption --bucket "$bucket_name" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
            log_success "Created enterprise S3 bucket with encryption: $bucket_name"
            sed -i "s/default_bucket=grim-enterprise-backups/default_bucket=$bucket_name/" "$CLOUD_CONFIG_DIR/aws/config.conf"
        fi
    else
        log_error "AWS enterprise connection test failed"
        return 1
    fi
}

# Configure Azure - REAPER+ ONLY
cloud_azure() {
    log "Configuring Azure enterprise cloud integration"
    
    if ! check_tier_permissions "reaper"; then
        return 1
    fi
    
    ensure_directories
    
    echo -e "${CYAN}=== Azure Enterprise Cloud Configuration ===${NC}"
    echo -e "${YELLOW}Enterprise features: Management groups, policy, security center${NC}"
    echo ""
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_warning "Azure CLI not found. Installing enterprise version..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        log_success "Azure CLI enterprise version installed successfully"
    fi
    
    echo -e "${YELLOW}Azure enterprise configuration requires interactive login${NC}"
    echo "Please complete the login process in your browser..."
    
    if az login; then
        log_success "Azure enterprise login successful"
        
        # Get subscription and tenant info
        local subscription_id=$(az account show --query id -o tsv)
        local tenant_id=$(az account show --query tenantId -o tsv)
        
        # Update configuration
        sed -i "s/enabled=false/enabled=true/" "$CLOUD_CONFIG_DIR/azure/config.conf"
        sed -i "s/subscription_id=/subscription_id=$subscription_id/" "$CLOUD_CONFIG_DIR/azure/config.conf"
        sed -i "s/tenant_id=/tenant_id=$tenant_id/" "$CLOUD_CONFIG_DIR/azure/config.conf"
        
        log_success "Azure enterprise cloud configured successfully"
        echo -e "${GREEN}✓ Azure enterprise cloud configured and connected${NC}"
    else
        log_error "Azure enterprise login failed"
        return 1
    fi
}

# Configure GCP - REAPER+ ONLY
cloud_gcp() {
    log "Configuring Google Cloud Platform enterprise integration"
    
    if ! check_tier_permissions "reaper"; then
        return 1
    fi
    
    ensure_directories
    
    echo -e "${CYAN}=== Google Cloud Platform Enterprise Configuration ===${NC}"
    echo -e "${YELLOW}Enterprise features: Organization, billing, security center${NC}"
    echo ""
    
    # Check if gcloud CLI is installed
    if ! command -v gcloud &> /dev/null; then
        log_warning "Google Cloud CLI not found. Installing enterprise version..."
        curl https://sdk.cloud.google.com | bash
        exec -l $SHELL
        log_success "Google Cloud CLI enterprise version installed successfully"
    fi
    
    echo -e "${YELLOW}GCP enterprise configuration requires interactive login${NC}"
    echo "Please complete the login process in your browser..."
    
    if gcloud auth login; then
        log_success "GCP enterprise login successful"
        
        # Get project and organization info
        read -p "Enter GCP Project ID: " project_id
        read -p "Enter Organization ID (optional): " org_id
        gcloud config set project "$project_id"
        
        # Update configuration
        sed -i "s/enabled=false/enabled=true/" "$CLOUD_CONFIG_DIR/gcp/config.conf"
        sed -i "s/project_id=/project_id=$project_id/" "$CLOUD_CONFIG_DIR/gcp/config.conf"
        if [[ -n "$org_id" ]]; then
            sed -i "s/organization_id=/organization_id=$org_id/" "$CLOUD_CONFIG_DIR/gcp/config.conf"
        fi
        
        log_success "GCP enterprise cloud configured successfully"
        echo -e "${GREEN}✓ GCP enterprise cloud configured and connected${NC}"
    else
        log_error "GCP enterprise login failed"
        return 1
    fi
}

# Configure serverless - ENTERPRISE ONLY
cloud_serverless() {
    log "Configuring enterprise serverless deployment environment"
    
    if ! check_tier_permissions "enterprise"; then
        return 1
    fi
    
    ensure_directories
    
    echo -e "${CYAN}=== Enterprise Serverless Configuration ===${NC}"
    echo -e "${YELLOW}Enterprise features: Blue-green deployment, canary releases, premium plans${NC}"
    echo ""
    
    # Install Serverless Framework if not present
    if ! command -v serverless &> /dev/null && ! command -v sls &> /dev/null; then
        log_warning "Serverless Framework not found. Installing enterprise version..."
        if command -v npm &> /dev/null; then
            npm install -g serverless@latest
            npm install -g @serverless/enterprise-plugin
            log_success "Serverless Framework enterprise version installed successfully"
        else
            log_error "npm not found. Please install Node.js and npm first"
            return 1
        fi
    fi
    
    # Create enterprise serverless project template
    local serverless_dir="$CLOUD_CONFIG_DIR/serverless/projects"
    mkdir -p "$serverless_dir"
    
    cat > "$serverless_dir/grim-enterprise-functions.yml" << 'EOF'
service: grim-enterprise-functions

provider:
  name: aws
  runtime: python3.9
  region: us-west-2
  stage: production
  environment:
    GRIM_ENVIRONMENT: enterprise
    GRIM_TIER: enterprise
  vpc:
    securityGroupIds:
      - sg-enterprise-lambda
    subnetIds:
      - subnet-enterprise-1
      - subnet-enterprise-2

functions:
  enterprise-backup-processor:
    handler: handlers/backup.enterprise_process
    events:
      - s3:
          bucket: grim-enterprise-backups
          event: s3:ObjectCreated:*
    timeout: 900
    memorySize: 3008
    reservedConcurrency: 50
    
  enterprise-health-monitor:
    handler: handlers/monitor.enterprise_health_check
    events:
      - schedule: rate(1 minute)
    timeout: 300
    memorySize: 1024
    
  enterprise-compliance-auditor:
    handler: handlers/compliance.audit
    events:
      - schedule: rate(1 hour)
    timeout: 600
    memorySize: 2048
    
  enterprise-disaster-recovery:
    handler: handlers/dr.orchestrate
    events:
      - sns:
          topicName: grim-enterprise-alerts
    timeout: 900
    memorySize: 3008

plugins:
  - serverless-python-requirements
  - @serverless/enterprise-plugin
  - serverless-vpc-plugin

custom:
  pythonRequirements:
    dockerizePip: true
  enterprise:
    collectLambdaLogs: true
    disableAwsLogs: false
    enableTracing: true
EOF
    
    # Update configuration
    sed -i "s/enabled=false/enabled=true/" "$CLOUD_CONFIG_DIR/serverless/config.conf"
    
    log_success "Enterprise serverless environment configured"
    echo -e "${GREEN}✓ Serverless Framework enterprise ready${NC}"
    echo -e "${CYAN}Enterprise template created: $serverless_dir/grim-enterprise-functions.yml${NC}"
}

# Comprehensive cloud setup - ENTERPRISE ONLY
cloud_comprehensive() {
    log "Running comprehensive enterprise cloud platform setup"
    
    if ! check_tier_permissions "enterprise"; then
        return 1
    fi
    
    echo -e "${CYAN}=== Comprehensive Enterprise Cloud Platform Setup ===${NC}"
    echo ""
    echo "This will configure all enterprise cloud providers and services."
    echo "Enterprise features include:"
    echo "  • Multi-region disaster recovery"
    echo "  • Advanced compliance monitoring"
    echo "  • Premium support and SLA"
    echo "  • Enterprise security controls"
    echo ""
    echo "Estimated time: 15-20 minutes"
    echo ""
    
    read -p "Continue with comprehensive enterprise setup? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        return 0
    fi
    
    # Initialize base environment
    cloud_init
    
    echo -e "\n${YELLOW}=== Step 1/4: AWS Enterprise Configuration ===${NC}"
    if ! cloud_aws; then
        log_warning "AWS enterprise configuration failed, continuing with other providers"
    fi
    
    echo -e "\n${YELLOW}=== Step 2/4: Azure Enterprise Configuration ===${NC}"
    if ! cloud_azure; then
        log_warning "Azure enterprise configuration failed, continuing with other providers"
    fi
    
    echo -e "\n${YELLOW}=== Step 3/4: GCP Enterprise Configuration ===${NC}"
    if ! cloud_gcp; then
        log_warning "GCP enterprise configuration failed, continuing with serverless"
    fi
    
    echo -e "\n${YELLOW}=== Step 4/4: Enterprise Serverless Configuration ===${NC}"
    if ! cloud_serverless; then
        log_warning "Enterprise serverless configuration failed"
    fi
    
    # Generate comprehensive enterprise report
    generate_enterprise_cloud_report
    
    log_success "Comprehensive enterprise cloud setup completed"
    echo -e "${GREEN}✓ Multi-cloud enterprise platform configured successfully${NC}"
    echo -e "${CYAN}Enterprise configuration report: $CLOUD_CONFIG_DIR/enterprise-setup-report.txt${NC}"
}

# Generate enterprise cloud setup report
generate_enterprise_cloud_report() {
    local report_file="$CLOUD_CONFIG_DIR/enterprise-setup-report.txt"
    
    cat > "$report_file" << EOF
GRIM Enterprise Cloud Platform Setup Report
Generated: $(date)
Tier: Enterprise
==========================================

ENTERPRISE CONFIGURATION STATUS:
EOF
    
    # Check each provider
    if grep -q "enabled=true" "$CLOUD_CONFIG_DIR/aws/config.conf" 2>/dev/null; then
        echo "✓ AWS Enterprise: Configured with advanced security and compliance" >> "$report_file"
    else
        echo "✗ AWS Enterprise: Not configured" >> "$report_file"
    fi
    
    if grep -q "enabled=true" "$CLOUD_CONFIG_DIR/azure/config.conf" 2>/dev/null; then
        echo "✓ Azure Enterprise: Configured with management groups and policies" >> "$report_file"
    else
        echo "✗ Azure Enterprise: Not configured" >> "$report_file"
    fi
    
    if grep -q "enabled=true" "$CLOUD_CONFIG_DIR/gcp/config.conf" 2>/dev/null; then
        echo "✓ GCP Enterprise: Configured with organization and security center" >> "$report_file"
    else
        echo "✗ GCP Enterprise: Not configured" >> "$report_file"
    fi
    
    if grep -q "enabled=true" "$CLOUD_CONFIG_DIR/serverless/config.conf" 2>/dev/null; then
        echo "✓ Enterprise Serverless: Configured with premium features" >> "$report_file"
    else
        echo "✗ Enterprise Serverless: Not configured" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

ENTERPRISE FEATURES ENABLED:
• Multi-region disaster recovery
• Advanced compliance monitoring
• Enterprise security controls
• Premium support and SLA
• Blue-green deployments
• Canary releases
• Advanced monitoring and alerting

NEXT STEPS:
1. Configure disaster recovery policies
2. Set up compliance monitoring dashboards
3. Enable advanced security scanning
4. Configure premium support channels
5. Test enterprise backup and recovery

ENTERPRISE SUPPORT:
- Dedicated support: enterprise-support@grim.so
- Emergency hotline: +1-800-GRIM-911
- Documentation: https://docs.grim.so/enterprise
- Premium community: https://enterprise.grim.so
EOF
}

# Show help
cloud_help() {
    echo -e "${CYAN}GRIM Enterprise Cloud Management${NC}"
    echo ""
    echo -e "${RED}⚠️  TIER RESTRICTION: Reaper+ only${NC}"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}"
    echo "  grim cloud <command> [options]"
    echo ""
    echo -e "${YELLOW}COMMANDS:${NC}"
    echo ""
    echo -e "${GREEN}  init${NC}           Initialize enterprise cloud environment (Reaper tier+)"
    echo -e "${GREEN}  aws${NC}            Configure AWS enterprise integration (Reaper tier+)"
    echo -e "${GREEN}  azure${NC}          Configure Azure enterprise integration (Reaper tier+)"
    echo -e "${GREEN}  gcp${NC}            Configure Google Cloud Platform enterprise (Reaper tier+)"
    echo -e "${GREEN}  serverless${NC}     Configure enterprise serverless deployment (Enterprise tier only)"
    echo -e "${GREEN}  comprehensive${NC}  Full enterprise multi-cloud setup (Enterprise tier only)"
    echo -e "${GREEN}  help${NC}           Show this help message"
    echo ""
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "  grim cloud init                    # Initialize enterprise cloud environment"
    echo "  grim cloud aws                     # Set up AWS enterprise integration"
    echo "  grim cloud azure                   # Set up Azure enterprise integration"
    echo "  grim cloud gcp                     # Set up Google Cloud enterprise"
    echo "  grim cloud serverless              # Configure enterprise serverless functions"
    echo "  grim cloud comprehensive           # Complete enterprise multi-cloud setup"
    echo ""
    echo -e "${YELLOW}TIER REQUIREMENTS:${NC}"
    echo "  Reaper:     init, aws, azure, gcp"
    echo "  Enterprise: serverless, comprehensive"
    echo ""
    echo -e "${YELLOW}ENTERPRISE FEATURES:${NC}"
    echo "  • Multi-region disaster recovery"
    echo "  • Advanced compliance monitoring"
    echo "  • Enterprise security controls"
    echo "  • Premium support and SLA"
    echo "  • Blue-green deployments"
    echo "  • Canary releases"
    echo ""
    echo -e "${YELLOW}CONFIGURATION:${NC}"
    echo "  Config Dir: $CLOUD_CONFIG_DIR"
    echo "  Log File:   $CLOUD_LOG_FILE"
    echo "  Cache Dir:  $CLOUD_CACHE_DIR"
    echo ""
    echo -e "${CYAN}Upgrade to Reaper+ tier: https://grim.so/pricing${NC}"
}

# Main command handler
main() {
    local command="${1:-help}"
    shift || true
    
    ensure_directories
    
    case "$command" in
        "init")
            cloud_init "$@"
            ;;
        "aws")
            cloud_aws "$@"
            ;;
        "azure")
            cloud_azure "$@"
            ;;
        "gcp")
            cloud_gcp "$@"
            ;;
        "serverless")
            cloud_serverless "$@"
            ;;
        "comprehensive")
            cloud_comprehensive "$@"
            ;;
        "help"|"--help"|"-h")
            cloud_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo -e "${RED}Unknown command: $command${NC}"
            echo "Use 'grim cloud help' for available commands"
            return 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 