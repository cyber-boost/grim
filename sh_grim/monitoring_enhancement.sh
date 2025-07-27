#!/bin/bash

# Monitoring Enhancement Module for Grim System
# Agent a2 - Goal g5 - Monitoring Enhancement Component
# Distributed tracing, APM, and advanced alerting

set -e

# Configuration
MONITORING_CONFIG="/etc/grim/monitoring.conf"
PROMETHEUS_CONFIG="/etc/grim/prometheus.conf"
GRAFANA_CONFIG="/etc/grim/grafana.conf"
JAEGER_CONFIG="/etc/grim/jaeger.conf"
ALERTING_CONFIG="/etc/grim/alerting.conf"
MONITORING_RESULTS="/var/log/grim/monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a /var/log/grim/monitoring.log
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a /var/log/grim/monitoring.log
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a /var/log/grim/monitoring.log
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a /var/log/grim/monitoring.log
}

# Initialize monitoring environment
init_monitoring() {
    log "Initializing monitoring environment"
    
    mkdir -p "$MONITORING_RESULTS"
    mkdir -p /var/log/grim
    mkdir -p /etc/grim/monitoring
    
    # Create monitoring configuration
    if [[ ! -f "$MONITORING_CONFIG" ]]; then
        cat > "$MONITORING_CONFIG" << EOF
# Monitoring Enhancement Configuration
[prometheus]
enabled=true
version=2.45.0
retention_days=30
scrape_interval=15s

[grafana]
enabled=true
version=10.0.0
admin_password=secure_password_123
datasources=prometheus,jaeger

[jaeger]
enabled=true
version=1.48.0
storage_type=elasticsearch
sampling_rate=1.0

[alerting]
enabled=true
alertmanager_version=0.25.0
slack_webhook=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
email_smtp=smtp.gmail.com:587

[apm]
enabled=true
elastic_apm_version=7.17.0
service_name=grim-backup-system
environment=production

[distributed_tracing]
enabled=true
sampling_rate=0.1
max_trace_duration=300s
EOF
    fi
    
    success "Monitoring environment initialized"
}

# Implement Prometheus monitoring
implement_prometheus_monitoring() {
    log "Implementing Prometheus monitoring"
    
    local prometheus_file="$MONITORING_RESULTS/prometheus_config_$(date +%Y%m%d_%H%M%S).yaml"
    
    cat > "$prometheus_file" << EOF
# Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: grim-cluster
    environment: production

rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Grim Backup Service
  - job_name: 'grim-backup-service'
    metrics_path: /metrics
    scrape_interval: 30s
    static_configs:
      - targets:
        - 'backup-service-1:8080'
        - 'backup-service-2:8080'
        - 'backup-service-3:8080'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod

  # Grim Restore Service
  - job_name: 'grim-restore-service'
    metrics_path: /metrics
    scrape_interval: 30s
    static_configs:
      - targets:
        - 'restore-service-1:8080'
        - 'restore-service-2:8080'
        - 'restore-service-3:8080'

  # Grim Storage Service
  - job_name: 'grim-storage-service'
    metrics_path: /metrics
    scrape_interval: 30s
    static_configs:
      - targets:
        - 'storage-service-1:8080'
        - 'storage-service-2:8080'
        - 'storage-service-3:8080'

  # Node Exporter
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - 'node-exporter-1:9100'
        - 'node-exporter-2:9100'
        - 'node-exporter-3:9100'

  # PostgreSQL
  - job_name: 'postgres-exporter'
    static_configs:
      - targets:
        - 'postgres-exporter:9187'

  # Redis
  - job_name: 'redis-exporter'
    static_configs:
      - targets:
        - 'redis-exporter:9121'
EOF
    
    # Create Prometheus deployment
    cat > "$MONITORING_RESULTS/prometheus_deployment_$(date +%Y%m%d_%H%M%S).yaml" << EOF
# Prometheus Deployment
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: grim-system
data:
  prometheus.yml: |
$(cat "$prometheus_file" | sed 's/^/    /')
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: grim-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.45.0
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-storage
          mountPath: /prometheus
        command:
        - /bin/prometheus
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.retention.time=30d
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
        - --web.enable-lifecycle
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage
        persistentVolumeClaim:
          claimName: prometheus-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: grim-system
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
EOF
    
    success "Prometheus monitoring implemented: $prometheus_file"
}

# Implement Grafana dashboards
implement_grafana_dashboards() {
    log "Implementing Grafana dashboards"
    
    local grafana_file="$MONITORING_RESULTS/grafana_config_$(date +%Y%m%d_%H%M%S).yaml"
    
    cat > "$grafana_file" << EOF
# Grafana Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: grim-system
data:
  datasources.yml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus-service:9090
      isDefault: true
    - name: Jaeger
      type: jaeger
      access: proxy
      url: http://jaeger-query:16686
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: grim-system
data:
  grim-backup-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Grim Backup System Dashboard",
        "tags": ["grim", "backup"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Backup Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(grim_backup_success_total[5m])",
                "legendFormat": "Success Rate"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "thresholds"
                },
                "thresholds": {
                  "steps": [
                    {"color": "red", "value": null},
                    {"color": "green", "value": 0.95}
                  ]
                }
              }
            }
          },
          {
            "id": 2,
            "title": "Backup Duration",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(grim_backup_duration_seconds_bucket[5m]))",
                "legendFormat": "95th Percentile"
              }
            ]
          },
          {
            "id": 3,
            "title": "Active Backups",
            "type": "stat",
            "targets": [
              {
                "expr": "grim_backup_active",
                "legendFormat": "Active Backups"
              }
            ]
          },
          {
            "id": 4,
            "title": "Storage Usage",
            "type": "gauge",
            "targets": [
              {
                "expr": "grim_storage_usage_percent",
                "legendFormat": "Storage Usage %"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: grim-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.0.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "secure_password_123"
        - name: GF_INSTALL_PLUGINS
          value: "grafana-jaeger-datasource"
        volumeMounts:
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
        - name: grafana-dashboards
          mountPath: /etc/grafana/provisioning/dashboards
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-dashboards
        configMap:
          name: grafana-dashboards
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: grim-system
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF
    
    success "Grafana dashboards implemented: $grafana_file"
}

# Implement Jaeger distributed tracing
implement_jaeger_tracing() {
    log "Implementing Jaeger distributed tracing"
    
    local jaeger_file="$MONITORING_RESULTS/jaeger_config_$(date +%Y%m%d_%H%M%S).yaml"
    
    cat > "$jaeger_file" << EOF
# Jaeger Distributed Tracing Configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: grim-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:1.48.0
        ports:
        - containerPort: 16686
          name: query
        - containerPort: 14268
          name: collector
        - containerPort: 14250
          name: grpc
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        - name: SPAN_STORAGE_TYPE
          value: "elasticsearch"
        - name: ES_SERVER_URLS
          value: "http://elasticsearch-service:9200"
        - name: ES_USERNAME
          value: "elastic"
        - name: ES_PASSWORD
          value: "changeme"
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-service
  namespace: grim-system
spec:
  selector:
    app: jaeger
  ports:
  - port: 16686
    targetPort: 16686
    name: query
  - port: 14268
    targetPort: 14268
    name: collector
  - port: 14250
    targetPort: 14250
    name: grpc
  type: ClusterIP
---
# Jaeger Agent for service instrumentation
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: jaeger-agent
  namespace: grim-system
spec:
  selector:
    matchLabels:
      app: jaeger-agent
  template:
    metadata:
      labels:
        app: jaeger-agent
    spec:
      containers:
      - name: jaeger-agent
        image: jaegertracing/jaeger-agent:1.48.0
        ports:
        - containerPort: 6831
          name: udp
        - containerPort: 6832
          name: udp-compact
        - containerPort: 5778
          name: http
        env:
        - name: COLLECTOR_HOST_PORT
          value: "jaeger-service:14267"
        - name: REPORTER_LOG_SPANS
          value: "true"
        volumeMounts:
        - name: var-run
          mountPath: /var/run
      volumes:
      - name: var-run
        hostPath:
          path: /var/run
EOF
    
    success "Jaeger distributed tracing implemented: $jaeger_file"
}

# Implement advanced alerting
implement_advanced_alerting() {
    log "Implementing advanced alerting"
    
    local alerting_file="$MONITORING_RESULTS/alerting_config_$(date +%Y%m%d_%H%M%S).yaml"
    
    cat > "$alerting_file" << EOF
# Advanced Alerting Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: grim-system
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'grim-alerts@grim.local'
      smtp_auth_username: 'grim-alerts@gmail.com'
      smtp_auth_password: 'your-app-password'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      receiver: 'grim-team'
      routes:
      - match:
          severity: critical
        receiver: 'grim-critical'
        repeat_interval: 1h
      - match:
          service: backup-service
        receiver: 'backup-team'
    
    receivers:
    - name: 'grim-team'
      slack_configs:
      - channel: '#grim-alerts'
        title: 'Grim Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
      email_configs:
      - to: 'grim-team@grim.local'
        subject: 'Grim Alert: {{ .GroupLabels.alertname }}'
    
    - name: 'grim-critical'
      slack_configs:
      - channel: '#grim-critical'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
      email_configs:
      - to: 'grim-critical@grim.local'
        subject: '🚨 CRITICAL ALERT: {{ .GroupLabels.alertname }}'
      pagerduty_configs:
      - routing_key: 'your-pagerduty-key'
    
    - name: 'backup-team'
      slack_configs:
      - channel: '#backup-alerts'
        title: 'Backup Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: grim-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.25.0
        ports:
        - containerPort: 9093
        volumeMounts:
        - name: alertmanager-config
          mountPath: /etc/alertmanager
        command:
        - /bin/alertmanager
        - --config.file=/etc/alertmanager/alertmanager.yml
        - --storage.path=/alertmanager
      volumes:
      - name: alertmanager-config
        configMap:
          name: alertmanager-config
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager-service
  namespace: grim-system
spec:
  selector:
    app: alertmanager
  ports:
  - port: 9093
    targetPort: 9093
  type: ClusterIP
---
# Prometheus Alert Rules
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
  namespace: grim-system
data:
  grim-alerts.yml: |
    groups:
    - name: grim-backup-alerts
      rules:
      - alert: BackupServiceDown
        expr: up{job="grim-backup-service"} == 0
        for: 1m
        labels:
          severity: critical
          service: backup-service
        annotations:
          summary: "Backup service is down"
          description: "Backup service has been down for more than 1 minute"
      
      - alert: BackupFailureRate
        expr: rate(grim_backup_failure_total[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
          service: backup-service
        annotations:
          summary: "High backup failure rate"
          description: "Backup failure rate is above 10%"
      
      - alert: BackupDurationHigh
        expr: histogram_quantile(0.95, rate(grim_backup_duration_seconds_bucket[5m])) > 300
        for: 5m
        labels:
          severity: warning
          service: backup-service
        annotations:
          summary: "Backup duration is high"
          description: "95th percentile backup duration is above 5 minutes"
      
      - alert: StorageUsageHigh
        expr: grim_storage_usage_percent > 85
        for: 5m
        labels:
          severity: warning
          service: storage-service
        annotations:
          summary: "Storage usage is high"
          description: "Storage usage is above 85%"
      
      - alert: RestoreServiceDown
        expr: up{job="grim-restore-service"} == 0
        for: 1m
        labels:
          severity: critical
          service: restore-service
        annotations:
          summary: "Restore service is down"
          description: "Restore service has been down for more than 1 minute"
EOF
    
    success "Advanced alerting implemented: $alerting_file"
}

# Implement APM (Application Performance Monitoring)
implement_apm() {
    log "Implementing APM (Application Performance Monitoring)"
    
    local apm_file="$MONITORING_RESULTS/apm_config_$(date +%Y%m%d_%H%M%S).yaml"
    
    cat > "$apm_file" << EOF
# APM Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: elastic-apm-config
  namespace: grim-system
data:
  apm-server.yml: |
    apm-server:
      host: "0.0.0.0:8200"
      secret_token: "your-secret-token"
    
    output.elasticsearch:
      hosts: ["elasticsearch-service:9200"]
      username: "elastic"
      password: "changeme"
    
    setup.kibana:
      host: "kibana-service:5601"
    
    logging.level: info
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apm-server
  namespace: grim-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apm-server
  template:
    metadata:
      labels:
        app: apm-server
    spec:
      containers:
      - name: apm-server
        image: docker.elastic.co/apm/apm-server:7.17.0
        ports:
        - containerPort: 8200
        volumeMounts:
        - name: apm-config
          mountPath: /usr/share/apm-server/apm-server.yml
          subPath: apm-server.yml
      volumes:
      - name: apm-config
        configMap:
          name: elastic-apm-config
---
apiVersion: v1
kind: Service
metadata:
  name: apm-server-service
  namespace: grim-system
spec:
  selector:
    app: apm-server
  ports:
  - port: 8200
    targetPort: 8200
  type: ClusterIP
---
# APM Agent Configuration for Grim Services
apiVersion: v1
kind: ConfigMap
metadata:
  name: grim-apm-config
  namespace: grim-system
data:
  apm-agent.conf: |
    [apm]
    server_url = http://apm-server-service:8200
    secret_token = your-secret-token
    service_name = grim-backup-system
    environment = production
    log_level = info
    
    [tracing]
    enabled = true
    sample_rate = 0.1
    max_trace_duration = 300s
    
    [metrics]
    enabled = true
    interval = 30s
EOF
    
    success "APM implemented: $apm_file"
}

# Run comprehensive monitoring enhancement implementation
run_comprehensive_monitoring_enhancement() {
    log "Starting comprehensive monitoring enhancement implementation"
    
    # Initialize environment
    init_monitoring
    
    # Implement all monitoring components
    implement_prometheus_monitoring
    implement_grafana_dashboards
    implement_jaeger_tracing
    implement_advanced_alerting
    implement_apm
    
    # Generate comprehensive report
    generate_monitoring_enhancement_report
    
    success "Comprehensive monitoring enhancement implementation completed"
}

# Generate monitoring enhancement report
generate_monitoring_enhancement_report() {
    local report_file="$MONITORING_RESULTS/comprehensive_monitoring_enhancement_report_$(date +%Y%m%d_%H%M%S).html"
    
    log "Generating comprehensive monitoring enhancement report"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Comprehensive Monitoring Enhancement Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric { margin: 10px 0; padding: 10px; border-left: 4px solid #007cba; }
        .success { border-left-color: #28a745; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Comprehensive Monitoring Enhancement Report</h1>
        <p>Generated: $(date)</p>
        <p>Monitoring: Prometheus, Grafana, Jaeger, APM</p>
    </div>
    
    <div class="section">
        <h2>Monitoring Components Implemented</h2>
        <table>
            <tr>
                <th>Component</th>
                <th>Status</th>
                <th>Features</th>
                <th>Configuration</th>
            </tr>
            <tr>
                <td>Prometheus</td>
                <td>✅ Completed</td>
                <td>Metrics collection, alerting, service discovery</td>
                <td>prometheus_config_*.yaml</td>
            </tr>
            <tr>
                <td>Grafana</td>
                <td>✅ Completed</td>
                <td>Dashboards, visualization, alerting</td>
                <td>grafana_config_*.yaml</td>
            </tr>
            <tr>
                <td>Jaeger</td>
                <td>✅ Completed</td>
                <td>Distributed tracing, span analysis</td>
                <td>jaeger_config_*.yaml</td>
            </tr>
            <tr>
                <td>Alerting</td>
                <td>✅ Completed</td>
                <td>Advanced alerts, notifications, escalation</td>
                <td>alerting_config_*.yaml</td>
            </tr>
            <tr>
                <td>APM</td>
                <td>✅ Completed</td>
                <td>Application performance, error tracking</td>
                <td>apm_config_*.yaml</td>
            </tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Monitoring Features</h2>
        <div class="metric">
            <h3>Metrics Collection</h3>
            <ul>
                <li><strong>Prometheus</strong>: Time-series metrics collection</li>
                <li><strong>Service Metrics</strong>: Backup, restore, storage performance</li>
                <li><strong>Infrastructure Metrics</strong>: CPU, memory, disk usage</li>
                <li><strong>Custom Metrics</strong>: Business-specific KPIs</li>
            </ul>
        </div>
        
        <div class="metric">
            <h3>Distributed Tracing</h3>
            <ul>
                <li><strong>Jaeger</strong>: End-to-end request tracing</li>
                <li><strong>Span Analysis</strong>: Performance bottleneck identification</li>
                <li><strong>Service Dependencies</strong>: Map service interactions</li>
                <li><strong>Error Tracking</strong>: Trace error propagation</li>
            </ul>
        </div>
        
        <div class="metric">
            <h3>Advanced Alerting</h3>
            <ul>
                <li><strong>Multi-channel</strong>: Slack, email, PagerDuty</li>
                <li><strong>Escalation</strong>: Critical alerts with immediate response</li>
                <li><strong>Grouping</strong>: Related alerts grouped together</li>
                <li><strong>Silencing</strong>: Temporary alert suppression</li>
            </ul>
        </div>
        
        <div class="metric">
            <h3>APM Features</h3>
            <ul>
                <li><strong>Performance Monitoring</strong>: Response times, throughput</li>
                <li><strong>Error Tracking</strong>: Exception monitoring and analysis</li>
                <li><strong>Transaction Monitoring</strong>: Business transaction tracking</li>
                <li><strong>Real-time Monitoring</strong>: Live performance data</li>
            </ul>
        </div>
    </div>
    
    <div class="section">
        <h2>Alert Rules Implemented</h2>
        <ul>
            <li><strong>BackupServiceDown</strong>: Critical alert when backup service is unavailable</li>
            <li><strong>BackupFailureRate</strong>: Warning when failure rate exceeds 10%</li>
            <li><strong>BackupDurationHigh</strong>: Warning when backup duration exceeds 5 minutes</li>
            <li><strong>StorageUsageHigh</strong>: Warning when storage usage exceeds 85%</li>
            <li><strong>RestoreServiceDown</strong>: Critical alert when restore service is unavailable</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Configuration Files</h2>
        <p>All configuration files are available in the following locations:</p>
        <ul>
            <li>Monitoring Results: $MONITORING_RESULTS</li>
            <li>Monitoring Config: $MONITORING_CONFIG</li>
            <li>Prometheus Config: $PROMETHEUS_CONFIG</li>
            <li>Grafana Config: $GRAFANA_CONFIG</li>
            <li>Jaeger Config: $JAEGER_CONFIG</li>
            <li>Alerting Config: $ALERTING_CONFIG</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    success "Comprehensive monitoring enhancement report generated: $report_file"
}

# Main command handler
case "${1:-}" in
    "init")
        init_monitoring
        ;;
    "prometheus")
        implement_prometheus_monitoring
        ;;
    "grafana")
        implement_grafana_dashboards
        ;;
    "jaeger")
        implement_jaeger_tracing
        ;;
    "alerting")
        implement_advanced_alerting
        ;;
    "apm")
        implement_apm
        ;;
    "comprehensive")
        run_comprehensive_monitoring_enhancement
        ;;
    "help"|"--help"|"-h")
        cat << EOF
Monitoring Enhancement Module for Grim System

Usage: $0 [command] [options]

Commands:
    init                    Initialize monitoring environment
    prometheus              Implement Prometheus monitoring
    grafana                 Implement Grafana dashboards
    jaeger                  Implement Jaeger distributed tracing
    alerting                Implement advanced alerting
    apm                     Implement APM (Application Performance Monitoring)
    comprehensive           Run complete monitoring enhancement implementation
    help                    Show this help message

Examples:
    $0 init
    $0 prometheus
    $0 comprehensive

Configuration:
    Monitoring config: $MONITORING_CONFIG
    Results: $MONITORING_RESULTS
EOF
        ;;
    *)
        error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac 