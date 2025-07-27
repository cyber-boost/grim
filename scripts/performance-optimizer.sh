#!/bin/bash

# Grim Performance Optimizer
# Comprehensive performance optimization for Grim and Scythe systems

set -euo pipefail

# Configuration
# Determine GRIM_ROOT - try multiple possible locations
GRIM_ROOT="${GRIM_ROOT:-}"
if [[ -z "$GRIM_ROOT" ]]; then
    if [[ -d "/opt/reaper" ]]; then
        GRIM_ROOT="/opt/reaper"
    elif [[ -d "/root/.graveyard/reaper" ]]; then
        GRIM_ROOT="/root/.graveyard/reaper"
    elif [[ -d "$HOME/.graveyard/reaper" ]]; then
        GRIM_ROOT="$HOME/.graveyard/reaper"
    else
        GRIM_ROOT="/opt/reaper"  # fallback
    fi
fi

LOG_FILE="/var/log/grim/performance-optimizer.log"
CONFIG_FILE="$GRIM_ROOT/config/performance.conf"
BACKUP_DIR="/backups/performance"
ALERT_WEBHOOK="${PERFORMANCE_ALERT_WEBHOOK:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local severity=$1
    local message=$2
    
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"severity\":\"$severity\",\"message\":\"$message\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            --silent --show-error || true
    fi
    
    case $severity in
        "CRITICAL")
            echo -e "${RED}[CRITICAL]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
    esac
}

# Database Performance Optimization

optimize_database() {
    log "INFO" "Starting database performance optimization"
    
    # Analyze table statistics
    log "INFO" "Analyzing table statistics"
    psql -h grim-postgres -U grim_monitor -d grim -c "
        ANALYZE backups;
        ANALYZE backup_jobs;
        ANALYZE compression_stats;
        ANALYZE security_events;
        ANALYZE performance_metrics;
    " || log "WARNING" "Failed to analyze table statistics"
    
    # Update table statistics
    log "INFO" "Updating table statistics"
    psql -h grim-postgres -U grim_monitor -d grim -c "
        UPDATE pg_stat_statements SET calls = 0;
        SELECT pg_stat_statements_reset();
    " || log "WARNING" "Failed to reset statistics"
    
    # Optimize indexes
    log "INFO" "Optimizing database indexes"
    psql -h grim-postgres -U grim_monitor -d grim -c "
        REINDEX INDEX CONCURRENTLY idx_backups_created_at;
        REINDEX INDEX CONCURRENTLY idx_backups_status;
        REINDEX INDEX CONCURRENTLY idx_backup_jobs_backup_id;
        REINDEX INDEX CONCURRENTLY idx_security_events_created_at;
        REINDEX INDEX CONCURRENTLY idx_performance_metrics_timestamp;
    " || log "WARNING" "Failed to reindex some indexes"
    
    # Vacuum and analyze
    log "INFO" "Running VACUUM and ANALYZE"
    psql -h grim-postgres -U grim_monitor -d grim -c "
        VACUUM ANALYZE backups;
        VACUUM ANALYZE backup_jobs;
        VACUUM ANALYZE compression_stats;
        VACUUM ANALYZE security_events;
        VACUUM ANALYZE performance_metrics;
    " || log "WARNING" "Failed to vacuum some tables"
    
    # Check for slow queries
    log "INFO" "Identifying slow queries"
    local slow_queries=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT query, mean_time, calls 
        FROM pg_stat_statements 
        WHERE mean_time > 1000
        ORDER BY mean_time DESC 
        LIMIT 10;
    " 2>/dev/null)
    
    if [[ -n "$slow_queries" ]]; then
        log "WARNING" "Slow queries detected"
        echo "$slow_queries" >> "$LOG_FILE"
        send_alert "WARNING" "Slow database queries detected"
    fi
    
    # Optimize PostgreSQL configuration
    log "INFO" "Optimizing PostgreSQL configuration"
    local current_shared_buffers=$(psql -h grim-postgres -U grim_monitor -d grim -c "SHOW shared_buffers;" 2>/dev/null | tail -1)
    local current_effective_cache_size=$(psql -h grim-postgres -U grim_monitor -d grim -c "SHOW effective_cache_size;" 2>/dev/null | tail -1)
    
    log "INFO" "Current shared_buffers: $current_shared_buffers"
    log "INFO" "Current effective_cache_size: $current_effective_cache_size"
    
    # Recommend configuration changes
    local total_memory=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local recommended_shared_buffers=$((total_memory * 25 / 100))
    local recommended_effective_cache_size=$((total_memory * 75 / 100))
    
    log "INFO" "Recommended shared_buffers: ${recommended_shared_buffers}MB"
    log "INFO" "Recommended effective_cache_size: ${recommended_effective_cache_size}MB"
    
    log "INFO" "Database optimization completed"
}

# Cache Optimization

optimize_caching() {
    log "INFO" "Starting cache optimization"
    
    # Redis optimization
    log "INFO" "Optimizing Redis configuration"
    
    # Check Redis memory usage
    local redis_memory=$(redis-cli -h grim-redis -a "$REDIS_PASSWORD" info memory | grep used_memory_human | cut -d: -f2)
    local redis_memory_peak=$(redis-cli -h grim-redis -a "$REDIS_PASSWORD" info memory | grep used_memory_peak_human | cut -d: -f2)
    
    log "INFO" "Redis current memory: $redis_memory"
    log "INFO" "Redis peak memory: $redis_memory_peak"
    
    # Optimize Redis configuration
    redis-cli -h grim-redis -a "$REDIS_PASSWORD" config set maxmemory-policy allkeys-lru || log "WARNING" "Failed to set Redis memory policy"
    redis-cli -h grim-redis -a "$REDIS_PASSWORD" config set save "900 1 300 10 60 10000" || log "WARNING" "Failed to set Redis save configuration"
    
    # Clear expired keys
    log "INFO" "Clearing expired Redis keys"
    redis-cli -h grim-redis -a "$REDIS_PASSWORD" --eval /dev/stdin <<EOF
        local keys = redis.call('keys', '*')
        local expired = 0
        for i, key in ipairs(keys) do
            if redis.call('ttl', key) == -1 then
                redis.call('expire', key, 3600)
                expired = expired + 1
            end
        end
        return expired
EOF
    
    # Application-level cache optimization
    log "INFO" "Optimizing application cache"
    
    # Clear old cache files
    find /tmp -name "grim_cache_*" -mtime +1 -delete 2>/dev/null || true
    find /var/cache/grim -name "*.cache" -mtime +7 -delete 2>/dev/null || true
    
    # Optimize cache configuration
    cat > "$GRIM_ROOT/config/cache.conf" <<EOF
# Grim Cache Configuration
cache_enabled = true
cache_ttl = 3600
cache_max_size = 512MB
cache_compression = true
cache_persistence = true
cache_eviction_policy = lru
cache_statistics = true
EOF
    
    log "INFO" "Cache optimization completed"
}

# Storage Optimization

optimize_storage() {
    log "INFO" "Starting storage optimization"
    
    # Analyze storage usage
    log "INFO" "Analyzing storage usage"
    local backup_usage=$(df -h /backups | awk 'NR==2 {print $5}' | sed 's/%//')
    local data_usage=$(df -h /data | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log "INFO" "Backup storage usage: ${backup_usage}%"
    log "INFO" "Data storage usage: ${data_usage}%"
    
    # Clean up old backups
    if [[ $backup_usage -gt 80 ]]; then
        log "WARNING" "High backup storage usage detected"
        send_alert "WARNING" "Backup storage usage is ${backup_usage}%"
        
        # Remove old backup files
        log "INFO" "Cleaning up old backup files"
        find /backups -name "*.gz*" -mtime +30 -delete 2>/dev/null || true
        find /backups -name "*.sql*" -mtime +30 -delete 2>/dev/null || true
    fi
    
    # Optimize compression
    log "INFO" "Optimizing compression settings"
    
    # Update compression configuration
    cat > "$GRIM_ROOT/config/compression.conf" <<EOF
# Grim Compression Configuration
compression_level = 9
compression_algorithm = zstd
compression_threads = 4
compression_chunk_size = 64MB
compression_dictionary = true
compression_adaptive = true
EOF
    
    # Storage routing optimization
    log "INFO" "Optimizing storage routing"
    
    # Implement tiered storage
    cat > "$GRIM_ROOT/config/storage.conf" <<EOF
# Grim Storage Configuration
primary_storage = /data
backup_storage = /backups
archive_storage = /archive
temp_storage = /tmp

# Storage tiers
tier1 = ssd:/data
tier2 = hdd:/backups
tier3 = cloud:/archive

# Routing rules
hot_data = tier1
warm_data = tier2
cold_data = tier3
EOF
    
    log "INFO" "Storage optimization completed"
}

# API Performance Optimization

optimize_api() {
    log "INFO" "Starting API performance optimization"
    
    # Optimize API configuration
    cat > "$GRIM_ROOT/config/api.conf" <<EOF
# Grim API Configuration
api_workers = 4
api_max_connections = 1000
api_timeout = 30
api_rate_limit = 1000
api_compression = true
api_caching = true
api_monitoring = true

# Performance settings
api_keepalive = true
api_keepalive_timeout = 65
api_max_keepalive_requests = 100
api_send_timeout = 60
api_read_timeout = 60
EOF
    
    # Optimize Nginx configuration
    log "INFO" "Optimizing Nginx configuration"
    
    cat > /etc/nginx/conf.d/grim-optimized.conf <<EOF
# Grim Optimized Nginx Configuration
upstream grim_api {
    server grim-api:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

upstream scythe_api {
    server scythe-api:8081 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# Rate limiting
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;

# Caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=grim_cache:10m max_size=1g inactive=60m use_temp_path=off;

server {
    listen 80;
    server_name grim.so;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    
    # API endpoints
    location /api/v1/ {
        proxy_pass http://grim_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Caching
        proxy_cache grim_cache;
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location /scythe/ {
        proxy_pass http://scythe_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Rate limiting for license checks
        limit_req zone=login burst=5 nodelay;
    }
    
    # Static files
    location /static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        gzip_static on;
    }
    
    # Health checks
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Reload Nginx
    nginx -t && nginx -s reload || log "WARNING" "Failed to reload Nginx"
    
    log "INFO" "API optimization completed"
}

# User Interface Optimization

optimize_ui() {
    log "INFO" "Starting UI optimization"
    
    # Optimize frontend assets
    log "INFO" "Optimizing frontend assets"
    
    # Minify CSS and JavaScript
    if command -v uglifyjs >/dev/null 2>&1; then
        find "$GRIM_ROOT/web/static/js" -name "*.js" -exec uglifyjs {} -o {} \;
    fi
    
    if command -v cleancss >/dev/null 2>&1; then
        find "$GRIM_ROOT/web/static/css" -name "*.css" -exec cleancss {} -o {} \;
    fi
    
    # Optimize images
    if command -v convert >/dev/null 2>&1; then
        find "$GRIM_ROOT/web/static/images" -name "*.png" -exec convert {} -strip -quality 85 {} \;
        find "$GRIM_ROOT/web/static/images" -name "*.jpg" -exec convert {} -strip -quality 85 {} \;
    fi
    
    # Generate optimized configuration
    cat > "$GRIM_ROOT/config/ui.conf" <<EOF
# Grim UI Configuration
ui_theme = dark
ui_language = en
ui_timezone = UTC
ui_refresh_interval = 30
ui_auto_refresh = true
ui_animations = true
ui_compact_mode = false
ui_advanced_mode = false

# Performance settings
ui_lazy_loading = true
ui_virtual_scrolling = true
ui_debounce_search = 300
ui_cache_queries = true
ui_preload_data = true
EOF
    
    log "INFO" "UI optimization completed"
}

# Auto-scaling Implementation

implement_autoscaling() {
    log "INFO" "Implementing auto-scaling"
    
    # Create auto-scaling configuration
    cat > "$GRIM_ROOT/config/autoscaling.conf" <<EOF
# Grim Auto-scaling Configuration
autoscaling_enabled = true
autoscaling_min_instances = 2
autoscaling_max_instances = 10
autoscaling_target_cpu = 70
autoscaling_target_memory = 80
autoscaling_scale_up_cooldown = 300
autoscaling_scale_down_cooldown = 600

# Scaling metrics
scaling_metric_cpu = true
scaling_metric_memory = true
scaling_metric_queue_length = true
scaling_metric_response_time = true

# Scaling policies
scale_up_threshold = 80
scale_down_threshold = 30
scale_up_step = 1
scale_down_step = 1
EOF
    
    # Create auto-scaling script
    cat > "$GRIM_ROOT/scripts/autoscaler.sh" <<'EOF'
#!/bin/bash

# Grim Auto-scaler
# Monitors system metrics and scales services automatically

set -euo pipefail

CONFIG_FILE="$GRIM_ROOT/config/autoscaling.conf"
LOG_FILE="/var/log/grim/autoscaler.log"

# Load configuration
source "$CONFIG_FILE"

log() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

get_cpu_usage() {
    docker stats --no-stream --format "table {{.CPUPerc}}" grim-api | tail -1 | sed 's/%//'
}

get_memory_usage() {
    docker stats --no-stream --format "table {{.MemPerc}}" grim-api | tail -1 | sed 's/%//'
}

get_queue_length() {
    redis-cli -h grim-redis -a "$REDIS_PASSWORD" llen backup_queue 2>/dev/null || echo "0"
}

get_response_time() {
    curl -w "%{time_total}" -o /dev/null -s http://grim-api:8080/health 2>/dev/null || echo "0"
}

scale_up() {
    local current_instances=$(docker-compose -f docker-compose.prod.yml ps grim-api | grep -c "Up")
    local new_instances=$((current_instances + scale_up_step))
    
    if [[ $new_instances -le $autoscaling_max_instances ]]; then
        log "Scaling up from $current_instances to $new_instances instances"
        docker-compose -f docker-compose.prod.yml up -d --scale grim-api=$new_instances
        return 0
    fi
    return 1
}

scale_down() {
    local current_instances=$(docker-compose -f docker-compose.prod.yml ps grim-api | grep -c "Up")
    local new_instances=$((current_instances - scale_down_step))
    
    if [[ $new_instances -ge $autoscaling_min_instances ]]; then
        log "Scaling down from $current_instances to $new_instances instances"
        docker-compose -f docker-compose.prod.yml up -d --scale grim-api=$new_instances
        return 0
    fi
    return 1
}

# Main scaling logic
main() {
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    local queue_length=$(get_queue_length)
    local response_time=$(get_response_time)
    
    log "Current metrics - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Queue: $queue_length, Response: ${response_time}s"
    
    # Scale up conditions
    if [[ $cpu_usage -gt $scale_up_threshold ]] || [[ $memory_usage -gt $scale_up_threshold ]] || [[ $queue_length -gt 100 ]] || [[ $(echo "$response_time > 2" | bc -l) -eq 1 ]]; then
        scale_up
    fi
    
    # Scale down conditions
    if [[ $cpu_usage -lt $scale_down_threshold ]] && [[ $memory_usage -lt $scale_down_threshold ]] && [[ $queue_length -lt 10 ]] && [[ $(echo "$response_time < 0.5" | bc -l) -eq 1 ]]; then
        scale_down
    fi
}

# Run scaling check
main
EOF
    
    chmod +x "$GRIM_ROOT/scripts/autoscaler.sh"
    
    # Create systemd service for auto-scaling
    cat > /etc/systemd/system/grim-autoscaler.service <<EOF
[Unit]
Description=Grim Auto-scaler
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$GRIM_ROOT/scripts/autoscaler.sh
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    
    # Create timer for periodic execution
    cat > /etc/systemd/system/grim-autoscaler.timer <<EOF
[Unit]
Description=Run Grim Auto-scaler every 30 seconds
Requires=grim-autoscaler.service

[Timer]
OnBootSec=30
OnUnitActiveSec=30
Unit=grim-autoscaler.service

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start auto-scaling
    systemctl daemon-reload
    systemctl enable grim-autoscaler.timer
    systemctl start grim-autoscaler.timer
    
    log "INFO" "Auto-scaling implementation completed"
}

# Customer Success Programs

implement_customer_success() {
    log "INFO" "Implementing customer success programs"
    
    # Create customer onboarding program
    cat > "$GRIM_ROOT/config/customer-success.conf" <<EOF
# Grim Customer Success Configuration
onboarding_enabled = true
onboarding_duration_days = 14
onboarding_checkpoints = 5
onboarding_automation = true

# Success metrics
success_metric_backup_success_rate = 99.9
success_metric_compression_ratio = 70
success_metric_management_time = 2
success_metric_cost_savings = 60
success_metric_uptime = 99.9

# Engagement programs
engagement_email_series = true
engagement_webinars = true
engagement_community = true
engagement_support = true
EOF
    
    # Create customer success scripts
    cat > "$GRIM_ROOT/scripts/customer-success.sh" <<'EOF'
#!/bin/bash

# Grim Customer Success Manager
# Manages customer onboarding and success programs

set -euo pipefail

CONFIG_FILE="$GRIM_ROOT/config/customer-success.conf"
LOG_FILE="/var/log/grim/customer-success.log"

# Load configuration
source "$CONFIG_FILE"

log() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

check_customer_health() {
    local customer_id="$1"
    
    # Get customer metrics
    local backup_success_rate=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT 
            CASE 
                WHEN COUNT(*) = 0 THEN 100
                ELSE (COUNT(CASE WHEN status = 'completed' THEN 1 END) * 100.0 / COUNT(*))
            END as success_rate
        FROM backup_jobs 
        WHERE customer_id = '$customer_id' 
        AND created_at > NOW() - INTERVAL '30 days';
    " 2>/dev/null | tail -1 | xargs)
    
    local compression_ratio=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT AVG(compression_ratio) 
        FROM compression_stats 
        WHERE customer_id = '$customer_id' 
        AND created_at > NOW() - INTERVAL '30 days';
    " 2>/dev/null | tail -1 | xargs)
    
    local management_time=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT AVG(EXTRACT(EPOCH FROM (completed_at - started_at))/3600) 
        FROM backup_jobs 
        WHERE customer_id = '$customer_id' 
        AND status = 'completed' 
        AND created_at > NOW() - INTERVAL '30 days';
    " 2>/dev/null | tail -1 | xargs)
    
    # Calculate health score
    local health_score=0
    
    if [[ $(echo "$backup_success_rate >= $success_metric_backup_success_rate" | bc -l) -eq 1 ]]; then
        health_score=$((health_score + 25))
    fi
    
    if [[ $(echo "$compression_ratio >= $success_metric_compression_ratio" | bc -l) -eq 1 ]]; then
        health_score=$((health_score + 25))
    fi
    
    if [[ $(echo "$management_time <= $success_metric_management_time" | bc -l) -eq 1 ]]; then
        health_score=$((health_score + 25))
    fi
    
    # Check for recent issues
    local recent_issues=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT COUNT(*) 
        FROM security_events 
        WHERE customer_id = '$customer_id' 
        AND severity IN ('HIGH', 'CRITICAL') 
        AND created_at > NOW() - INTERVAL '7 days';
    " 2>/dev/null | tail -1 | xargs)
    
    if [[ $recent_issues -eq 0 ]]; then
        health_score=$((health_score + 25))
    fi
    
    echo "$health_score"
}

send_onboarding_email() {
    local customer_id="$1"
    local email="$2"
    local step="$3"
    
    case $step in
        1)
            subject="Welcome to Grim - Let's Get Started!"
            template="welcome"
            ;;
        2)
            subject="Grim Setup Complete - Next Steps"
            template="setup-complete"
            ;;
        3)
            subject="Your First Backup - How Did It Go?"
            template="first-backup"
            ;;
        4)
            subject="Advanced Features - Unlock Grim's Full Potential"
            template="advanced-features"
            ;;
        5)
            subject="You're All Set - Welcome to the Grim Family!"
            template="onboarding-complete"
            ;;
    esac
    
    # Send email (placeholder for email service integration)
    log "Sending onboarding email $step to $email"
}

main() {
    # Get customers in onboarding
    local onboarding_customers=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT customer_id, email, created_at, onboarding_step
        FROM customers 
        WHERE onboarding_complete = false 
        AND created_at > NOW() - INTERVAL '$onboarding_duration_days days';
    " 2>/dev/null)
    
    echo "$onboarding_customers" | while IFS='|' read -r customer_id email created_at step; do
        if [[ -n "$customer_id" ]]; then
            # Check if it's time for next onboarding step
            local days_since_created=$(( ( $(date +%s) - $(date -d "$created_at" +%s) ) / 86400 ))
            local expected_step=$(( (days_since_created / 3) + 1 ))
            
            if [[ $expected_step -gt $step ]] && [[ $expected_step -le $onboarding_checkpoints ]]; then
                send_onboarding_email "$customer_id" "$email" "$expected_step"
                
                # Update onboarding step
                psql -h grim-postgres -U grim_monitor -d grim -c "
                    UPDATE customers 
                    SET onboarding_step = $expected_step 
                    WHERE customer_id = '$customer_id';
                " 2>/dev/null
            fi
        fi
    done
    
    # Check customer health for all customers
    local all_customers=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT customer_id, email 
        FROM customers 
        WHERE onboarding_complete = true;
    " 2>/dev/null)
    
    echo "$all_customers" | while IFS='|' read -r customer_id email; do
        if [[ -n "$customer_id" ]]; then
            local health_score=$(check_customer_health "$customer_id")
            
            if [[ $health_score -lt 50 ]]; then
                log "Low health score ($health_score) for customer $customer_id"
                # Send health check email
            fi
        fi
    done
}

main
EOF
    
    chmod +x "$GRIM_ROOT/scripts/customer-success.sh"
    
    # Create systemd service for customer success
    cat > /etc/systemd/system/grim-customer-success.service <<EOF
[Unit]
Description=Grim Customer Success Manager
After=grim-postgres.service
Requires=grim-postgres.service

[Service]
Type=oneshot
ExecStart=$GRIM_ROOT/scripts/customer-success.sh
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    
    # Create timer for daily execution
    cat > /etc/systemd/system/grim-customer-success.timer <<EOF
[Unit]
Description=Run Grim Customer Success daily
Requires=grim-customer-success.service

[Timer]
OnBootSec=300
OnUnitActiveSec=86400
Unit=grim-customer-success.service

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start customer success
    systemctl daemon-reload
    systemctl enable grim-customer-success.timer
    systemctl start grim-customer-success.timer
    
    log "INFO" "Customer success programs implemented"
}

# Feedback and Survey System

implement_feedback_system() {
    log "INFO" "Implementing feedback and survey system"
    
    # Create feedback configuration
    cat > "$GRIM_ROOT/config/feedback.conf" <<EOF
# Grim Feedback Configuration
feedback_enabled = true
feedback_survey_interval_days = 30
feedback_automation = true
feedback_integration = true

# Survey types
survey_onboarding = true
survey_quarterly = true
survey_support = true
survey_feature_request = true

# Feedback channels
feedback_email = true
feedback_web = true
feedback_api = true
feedback_slack = true
EOF
    
    # Create feedback collection script
    cat > "$GRIM_ROOT/scripts/feedback-collector.sh" <<'EOF'
#!/bin/bash

# Grim Feedback Collector
# Collects and processes customer feedback

set -euo pipefail

CONFIG_FILE="$GRIM_ROOT/config/feedback.conf"
LOG_FILE="/var/log/grim/feedback.log"

# Load configuration
source "$CONFIG_FILE"

log() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

send_survey() {
    local customer_id="$1"
    local email="$2"
    local survey_type="$3"
    
    case $survey_type in
        "onboarding")
            subject="How was your Grim setup experience?"
            template="onboarding-survey"
            ;;
        "quarterly")
            subject="Quarterly Grim Feedback Survey"
            template="quarterly-survey"
            ;;
        "support")
            subject="How was your recent support experience?"
            template="support-survey"
            ;;
        "feature")
            subject="Help us improve Grim - Feature Request Survey"
            template="feature-survey"
            ;;
    esac
    
    # Send survey email (placeholder for email service integration)
    log "Sending $survey_type survey to $email"
}

collect_usage_metrics() {
    local customer_id="$1"
    
    # Collect usage metrics for feedback analysis
    local metrics=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT 
            COUNT(*) as total_backups,
            AVG(compression_ratio) as avg_compression,
            AVG(EXTRACT(EPOCH FROM (completed_at - started_at))/3600) as avg_duration,
            COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_backups
        FROM backup_jobs 
        WHERE customer_id = '$customer_id' 
        AND created_at > NOW() - INTERVAL '30 days';
    " 2>/dev/null)
    
    echo "$metrics"
}

analyze_sentiment() {
    local feedback_text="$1"
    
    # Simple sentiment analysis (placeholder for AI service integration)
    local positive_words=("great" "excellent" "amazing" "love" "perfect" "awesome")
    local negative_words=("bad" "terrible" "hate" "awful" "broken" "useless")
    
    local positive_count=0
    local negative_count=0
    
    for word in "${positive_words[@]}"; do
        if echo "$feedback_text" | grep -qi "$word"; then
            ((positive_count++))
        fi
    done
    
    for word in "${negative_words[@]}"; do
        if echo "$feedback_text" | grep -qi "$word"; then
            ((negative_count++))
        fi
    done
    
    if [[ $positive_count -gt $negative_count ]]; then
        echo "positive"
    elif [[ $negative_count -gt $positive_count ]]; then
        echo "negative"
    else
        echo "neutral"
    fi
}

main() {
    # Send onboarding surveys
    local onboarding_customers=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT customer_id, email, created_at
        FROM customers 
        WHERE onboarding_complete = true 
        AND onboarding_survey_sent = false
        AND created_at < NOW() - INTERVAL '7 days';
    " 2>/dev/null)
    
    echo "$onboarding_customers" | while IFS='|' read -r customer_id email created_at; do
        if [[ -n "$customer_id" ]]; then
            send_survey "$customer_id" "$email" "onboarding"
            
            # Mark survey as sent
            psql -h grim-postgres -U grim_monitor -d grim -c "
                UPDATE customers 
                SET onboarding_survey_sent = true 
                WHERE customer_id = '$customer_id';
            " 2>/dev/null
        fi
    done
    
    # Send quarterly surveys
    local quarterly_customers=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT customer_id, email
        FROM customers 
        WHERE last_quarterly_survey < NOW() - INTERVAL '90 days'
        OR last_quarterly_survey IS NULL;
    " 2>/dev/null)
    
    echo "$quarterly_customers" | while IFS='|' read -r customer_id email; do
        if [[ -n "$customer_id" ]]; then
            send_survey "$customer_id" "$email" "quarterly"
            
            # Update last survey date
            psql -h grim-postgres -U grim_monitor -d grim -c "
                UPDATE customers 
                SET last_quarterly_survey = NOW() 
                WHERE customer_id = '$customer_id';
            " 2>/dev/null
        fi
    done
    
    # Process existing feedback
    local feedback_entries=$(psql -h grim-postgres -U grim_monitor -d grim -c "
        SELECT feedback_id, customer_id, feedback_text, sentiment
        FROM customer_feedback 
        WHERE processed = false;
    " 2>/dev/null)
    
    echo "$feedback_entries" | while IFS='|' read -r feedback_id customer_id feedback_text sentiment; do
        if [[ -n "$feedback_id" ]]; then
            # Analyze sentiment if not already done
            if [[ -z "$sentiment" ]]; then
                sentiment=$(analyze_sentiment "$feedback_text")
                
                psql -h grim-postgres -U grim_monitor -d grim -c "
                    UPDATE customer_feedback 
                    SET sentiment = '$sentiment' 
                    WHERE feedback_id = $feedback_id;
                " 2>/dev/null
            fi
            
            # Mark as processed
            psql -h grim-postgres -U grim_monitor -d grim -c "
                UPDATE customer_feedback 
                SET processed = true, processed_at = NOW() 
                WHERE feedback_id = $feedback_id;
            " 2>/dev/null
            
            log "Processed feedback $feedback_id with sentiment: $sentiment"
        fi
    done
}

main
EOF
    
    chmod +x "$GRIM_ROOT/scripts/feedback-collector.sh"
    
    # Create systemd service for feedback collection
    cat > /etc/systemd/system/grim-feedback.service <<EOF
[Unit]
Description=Grim Feedback Collector
After=grim-postgres.service
Requires=grim-postgres.service

[Service]
Type=oneshot
ExecStart=$GRIM_ROOT/scripts/feedback-collector.sh
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    
    # Create timer for weekly execution
    cat > /etc/systemd/system/grim-feedback.timer <<EOF
[Unit]
Description=Run Grim Feedback Collector weekly
Requires=grim-feedback.service

[Timer]
OnBootSec=600
OnUnitActiveSec=604800
Unit=grim-feedback.service

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start feedback system
    systemctl daemon-reload
    systemctl enable grim-feedback.timer
    systemctl start grim-feedback.timer
    
    log "INFO" "Feedback and survey system implemented"
}

# Main optimization function

main() {
    local action="${1:-all}"
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "Performance optimizer started with action: $action"
    
    case $action in
        "database")
            optimize_database
            ;;
        "cache")
            optimize_caching
            ;;
        "storage")
            optimize_storage
            ;;
        "api")
            optimize_api
            ;;
        "ui")
            optimize_ui
            ;;
        "autoscaling")
            implement_autoscaling
            ;;
        "customer-success")
            implement_customer_success
            ;;
        "feedback")
            implement_feedback_system
            ;;
        "all")
            optimize_database
            optimize_caching
            optimize_storage
            optimize_api
            optimize_ui
            implement_autoscaling
            implement_customer_success
            implement_feedback_system
            ;;
        *)
            echo "Usage: $0 {database|cache|storage|api|ui|autoscaling|customer-success|feedback|all}"
            exit 1
            ;;
    esac
    
    log "INFO" "Performance optimization completed"
}

# Run main function with all arguments
main "$@" 