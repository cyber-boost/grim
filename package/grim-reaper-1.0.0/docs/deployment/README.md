# Grim Reaper System - Deployment Guide

**Complete Production Deployment Guide**

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)
8. [Security Hardening](#security-hardening)
9. [Backup & Recovery](#backup--recovery)
10. [Scaling](#scaling)

---

## System Requirements

### Minimum Requirements

- **Operating System**: Ubuntu 20.04 LTS, CentOS 8+, or RHEL 8+
- **CPU**: 2 cores (4+ recommended)
- **Memory**: 4GB RAM (8GB+ recommended)
- **Storage**: 50GB available space (100GB+ recommended)
- **Network**: 100Mbps connection (1Gbps+ recommended)

### Recommended Requirements

- **Operating System**: Ubuntu 22.04 LTS or RHEL 9
- **CPU**: 4+ cores with AES-NI support
- **Memory**: 16GB RAM
- **Storage**: 500GB+ SSD with RAID 1
- **Network**: 1Gbps+ connection with redundant links

### Software Dependencies

```bash
# Required packages
- Python 3.8+
- Go 1.19+
- Node.js 16+
- PostgreSQL 13+
- Redis 6+
- Docker 20.10+
- systemd
- rsync
- tar
- gzip
- openssl
```

### Network Requirements

- **Ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8080 (API), 9090 (Scythe), 50051 (gRPC)
- **Firewall**: Configured to allow required ports
- **DNS**: Proper hostname resolution
- **SSL/TLS**: Valid certificates for HTTPS endpoints

---

## Pre-Deployment Checklist

### Environment Preparation

- [ ] Server hardware meets minimum requirements
- [ ] Operating system is up to date
- [ ] Network connectivity is verified
- [ ] DNS resolution is working
- [ ] Firewall rules are configured
- [ ] SSL certificates are obtained
- [ ] Database server is prepared
- [ ] Backup storage is configured
- [ ] Monitoring tools are ready

### Security Preparation

- [ ] SSH key-based authentication is configured
- [ ] Firewall is properly configured
- [ ] SSL certificates are valid
- [ ] User accounts are created with proper permissions
- [ ] Security policies are defined
- [ ] Backup encryption keys are generated

### Documentation Preparation

- [ ] Network topology is documented
- [ ] IP addresses are assigned
- [ ] Hostnames are configured
- [ ] Service accounts are created
- [ ] Passwords and keys are securely stored
- [ ] Emergency procedures are documented

---

## Installation

### Automated Installation

```bash
# Download the installer
curl -sSL https://grim-reaper.org/install.sh -o install.sh

# Verify installer checksum
echo "INSTALLER_CHECKSUM" | sha256sum -c install.sh

# Run installer
sudo bash install.sh --production --auto-config
```

### Manual Installation

#### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3 python3-pip python3-venv \
    golang-go nodejs npm postgresql redis-server \
    docker.io docker-compose rsync tar gzip openssl \
    nginx certbot python3-certbot-nginx

# Create system user
sudo useradd -r -s /bin/false grim
sudo usermod -aG docker grim
```

#### Step 2: Download and Extract

```bash
# Create installation directory
sudo mkdir -p /opt/grim-reaper
cd /opt/grim-reaper

# Download system
wget https://grim-reaper.org/releases/latest/grim-reaper.tar.gz
tar -xzf grim-reaper.tar.gz

# Set permissions
sudo chown -R grim:grim /opt/grim-reaper
sudo chmod -R 755 /opt/grim-reaper
```

#### Step 3: Install Components

```bash
# Install sh_grim
cd sh_grim
sudo ./install.sh --production

# Install go_grim
cd ../go_grim
sudo ./build.sh
sudo ./install.sh

# Install py_grim
cd ../py_grim
sudo pip3 install -r requirements.txt
sudo python3 setup.py install

# Install scythe
cd ../scythe
sudo python3 setup.py install
```

#### Step 4: Database Setup

```bash
# Create database
sudo -u postgres createdb grim_reaper
sudo -u postgres createuser grim

# Set database password
sudo -u postgres psql -c "ALTER USER grim WITH PASSWORD 'SECURE_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE grim_reaper TO grim;"

# Initialize database schema
cd /opt/grim-reaper/py_grim
python3 manage.py migrate
python3 manage.py createsuperuser
```

#### Step 5: Service Configuration

```bash
# Copy systemd service files
sudo cp /opt/grim-reaper/systemd/*.service /etc/systemd/system/

# Enable services
sudo systemctl enable grim-backup
sudo systemctl enable grim-monitor
sudo systemctl enable grim-security
sudo systemctl enable grim-web
sudo systemctl enable grim-scythe

# Start services
sudo systemctl start grim-backup
sudo systemctl start grim-monitor
sudo systemctl start grim-security
sudo systemctl start grim-web
sudo systemctl start grim-scythe
```

---

## Configuration

### Main Configuration File

Create `/etc/grim-reaper/config.yaml`:

```yaml
# System Configuration
system:
  name: "grim-reaper-production"
  environment: "production"
  debug: false
  log_level: "INFO"
  
# Database Configuration
database:
  host: "localhost"
  port: 5432
  name: "grim_reaper"
  user: "grim"
  password: "SECURE_PASSWORD"
  ssl_mode: "require"
  
# Redis Configuration
redis:
  host: "localhost"
  port: 6379
  password: "SECURE_REDIS_PASSWORD"
  db: 0
  
# Backup Configuration
backup:
  storage_path: "/backups"
  retention_days: 90
  compression_level: 6
  encryption_enabled: true
  encryption_key: "SECURE_ENCRYPTION_KEY"
  max_concurrent_backups: 5
  remote_storage:
    enabled: true
    type: "s3"
    bucket: "grim-reaper-backups"
    region: "us-east-1"
    access_key: "AWS_ACCESS_KEY"
    secret_key: "AWS_SECRET_KEY"
    
# Monitoring Configuration
monitoring:
  check_interval: 60
  alert_threshold: 100M
  exclude_patterns:
    - "*.tmp"
    - "*.log"
    - ".git/*"
    - "node_modules/*"
  notification:
    email:
      enabled: true
      smtp_host: "smtp.gmail.com"
      smtp_port: 587
      username: "alerts@company.com"
      password: "EMAIL_PASSWORD"
      recipients: ["admin@company.com"]
    slack:
      enabled: true
      webhook_url: "https://hooks.slack.com/services/XXX/YYY/ZZZ"
      
# Security Configuration
security:
  license_check_interval: 3600
  violation_threshold: 3
  auto_quarantine: true
  ssl:
    enabled: true
    cert_path: "/etc/ssl/certs/grim-reaper.crt"
    key_path: "/etc/ssl/private/grim-reaper.key"
    
# Web Configuration
web:
  host: "0.0.0.0"
  port: 8080
  ssl_enabled: true
  cors_origins: ["https://grim-reaper.company.com"]
  session_secret: "SECURE_SESSION_SECRET"
  
# Scythe Configuration
scythe:
  host: "0.0.0.0"
  port: 9090
  max_workers: 10
  timeout: 300
  
# Performance Configuration
performance:
  max_memory: "8G"
  max_cpu_percent: 80
  connection_pool_size: 20
  cache_size: "2G"
```

### Environment Variables

Create `/etc/grim-reaper/environment`:

```bash
# Database
GRIM_DB_HOST=localhost
GRIM_DB_PORT=5432
GRIM_DB_NAME=grim_reaper
GRIM_DB_USER=grim
GRIM_DB_PASSWORD=SECURE_PASSWORD

# Redis
GRIM_REDIS_HOST=localhost
GRIM_REDIS_PORT=6379
GRIM_REDIS_PASSWORD=SECURE_REDIS_PASSWORD

# Security
GRIM_ENCRYPTION_KEY=SECURE_ENCRYPTION_KEY
GRIM_SESSION_SECRET=SECURE_SESSION_SECRET
GRIM_LICENSE_KEY=GRIM-XXXX-XXXX-XXXX

# AWS (if using S3)
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
AWS_DEFAULT_REGION=us-east-1

# Email
GRIM_SMTP_HOST=smtp.gmail.com
GRIM_SMTP_PORT=587
GRIM_SMTP_USERNAME=alerts@company.com
GRIM_SMTP_PASSWORD=EMAIL_PASSWORD
```

### Nginx Configuration

Create `/etc/nginx/sites-available/grim-reaper`:

```nginx
server {
    listen 80;
    server_name grim-reaper.company.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name grim-reaper.company.com;
    
    ssl_certificate /etc/ssl/certs/grim-reaper.crt;
    ssl_certificate_key /etc/ssl/private/grim-reaper.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    
    # API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
        proxy_connect_timeout 75;
    }
    
    # Web interface
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static files
    location /static/ {
        alias /opt/grim-reaper/py_grim/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/grim-reaper /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Verification

### Health Checks

```bash
# System health check
curl -k https://grim-reaper.company.com/api/v1/system/health

# Component health checks
sudo systemctl status grim-*
sudo journalctl -u grim-backup -f
sudo journalctl -u grim-monitor -f
sudo journalctl -u grim-security -f
sudo journalctl -u grim-web -f
sudo journalctl -u grim-scythe -f
```

### Functionality Tests

```bash
# Test backup creation
curl -X POST https://grim-reaper.company.com/api/v1/backups \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type": "test", "paths": ["/tmp"], "encrypt": false}'

# Test monitoring
curl -X POST https://grim-reaper.company.com/api/v1/monitoring \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"path": "/tmp", "recursive": false}'

# Test security
curl -X GET https://grim-reaper.company.com/api/v1/security/license \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Performance Tests

```bash
# Load test the API
ab -n 1000 -c 10 https://grim-reaper.company.com/api/v1/system/health

# Test backup performance
time curl -X POST https://grim-reaper.company.com/api/v1/backups \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type": "performance", "paths": ["/var/log"], "encrypt": true}'

# Test compression performance
go_grim benchmark --algorithm zstd --level 6 --iterations 100
```

### Security Tests

```bash
# SSL/TLS test
openssl s_client -connect grim-reaper.company.com:443 -servername grim-reaper.company.com

# Security scan
nmap -sV -sC grim-reaper.company.com

# Vulnerability scan
sudo lynis audit system
```

---

## Monitoring & Maintenance

### System Monitoring

#### Prometheus Configuration

Create `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'grim-reaper'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/api/v1/system/metrics'
    scheme: 'https'
    tls_config:
      insecure_skip_verify: true
```

#### Grafana Dashboard

Import the Grim Reaper dashboard:

```json
{
  "dashboard": {
    "title": "Grim Reaper System",
    "panels": [
      {
        "title": "System Health",
        "type": "stat",
        "targets": [
          {
            "expr": "grim_system_health",
            "legendFormat": "Health Status"
          }
        ]
      },
      {
        "title": "Backup Operations",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(grim_backup_operations_total[5m])",
            "legendFormat": "Backups/sec"
          }
        ]
      },
      {
        "title": "Monitoring Events",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(grim_monitoring_events_total[5m])",
            "legendFormat": "Events/sec"
          }
        ]
      }
    ]
  }
}
```

### Log Management

#### Log Rotation

Create `/etc/logrotate.d/grim-reaper`:

```
/var/log/grim/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 grim grim
    postrotate
        systemctl reload grim-web
    endscript
}
```

#### Log Monitoring

```bash
# Monitor logs in real-time
tail -f /var/log/grim/*.log | grep -E "(ERROR|WARN|CRITICAL)"

# Search for specific errors
grep -r "ERROR" /var/log/grim/

# Analyze log patterns
cat /var/log/grim/system.log | awk '{print $4}' | sort | uniq -c | sort -nr
```

### Backup Verification

```bash
# Daily backup verification
#!/bin/bash
# /opt/grim-reaper/scripts/verify_backups.sh

BACKUP_PATH="/backups"
RETENTION_DAYS=90

# Check backup integrity
find $BACKUP_PATH -name "*.tar.gz" -mtime -1 -exec sh -c '
    echo "Verifying $1"
    tar -tzf "$1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ $1 is valid"
    else
        echo "✗ $1 is corrupted"
        exit 1
    fi
' sh {} \;

# Check retention policy
find $BACKUP_PATH -name "*.tar.gz" -mtime +$RETENTION_DAYS -exec rm {} \;

# Send verification report
echo "Backup verification completed at $(date)" | mail -s "Grim Reaper Backup Verification" admin@company.com
```

### Performance Monitoring

```bash
# System resource monitoring
#!/bin/bash
# /opt/grim-reaper/scripts/monitor_performance.sh

# CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

# Memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.2f", $3/$2 * 100.0)}')

# Disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)

# Database connections
DB_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;")

# Log performance metrics
echo "$(date),$CPU_USAGE,$MEMORY_USAGE,$DISK_USAGE,$DB_CONNECTIONS" >> /var/log/grim/performance.log

# Alert if thresholds exceeded
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "High CPU usage: ${CPU_USAGE}%" | mail -s "Grim Reaper Alert" admin@company.com
fi
```

---

## Troubleshooting

### Common Issues

#### 1. Service Won't Start

```bash
# Check service status
sudo systemctl status grim-web

# Check logs
sudo journalctl -u grim-web -n 50

# Check configuration
sudo grim-web --config-test

# Check dependencies
sudo lsof -i :8080
sudo netstat -tlnp | grep 8080
```

#### 2. Database Connection Issues

```bash
# Test database connection
sudo -u grim psql -h localhost -U grim -d grim_reaper -c "SELECT 1;"

# Check PostgreSQL status
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log

# Reset database connection
sudo systemctl restart postgresql
sudo systemctl restart grim-web
```

#### 3. Backup Failures

```bash
# Check disk space
df -h /backups

# Check permissions
ls -la /backups

# Test backup manually
sudo -u grim /opt/grim-reaper/sh_grim/backup.sh create test /tmp

# Check backup logs
tail -f /var/log/grim/backup.log
```

#### 4. Monitoring Issues

```bash
# Check monitoring status
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://grim-reaper.company.com/api/v1/monitoring

# Restart monitoring
sudo systemctl restart grim-monitor

# Check file permissions
sudo -u grim ls -la /var/www

# Test monitoring manually
sudo -u grim /opt/grim-reaper/sh_grim/monitor.sh start /tmp
```

### Diagnostic Commands

```bash
# System diagnostics
/opt/grim-reaper/scripts/diagnostic.sh

# Network diagnostics
ping grim-reaper.company.com
traceroute grim-reaper.company.com
nslookup grim-reaper.company.com

# Performance diagnostics
top -p $(pgrep grim)
iostat -x 1 5
iotop -p $(pgrep grim)

# Security diagnostics
sudo lynis audit system
sudo rkhunter --check
sudo chkrootkit
```

### Emergency Procedures

#### System Recovery

```bash
# Emergency shutdown
sudo systemctl stop grim-*

# Emergency restart
sudo systemctl start grim-backup grim-monitor grim-security

# Database recovery
sudo -u postgres pg_restore -d grim_reaper /backups/database_backup.sql

# Configuration recovery
sudo cp /backups/config_backup.yaml /etc/grim-reaper/config.yaml
sudo systemctl restart grim-*
```

#### Data Recovery

```bash
# Mount backup
sudo mount /backups/backup_2024-01-15.tar.gz /mnt/backup

# Extract specific files
tar -xzf /backups/backup_2024-01-15.tar.gz /path/to/file

# Restore from graveyard
/opt/grim-reaper/sh_grim/graveyard_recovery.sh
```

---

## Security Hardening

### System Hardening

```bash
# Update system regularly
sudo apt update && sudo apt upgrade -y

# Install security updates
sudo unattended-upgrades

# Configure firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 9090/tcp

# Disable unnecessary services
sudo systemctl disable telnet
sudo systemctl disable rsh
sudo systemctl disable rlogin
```

### Application Security

```bash
# Set secure file permissions
sudo chmod 600 /etc/grim-reaper/config.yaml
sudo chmod 600 /etc/grim-reaper/environment
sudo chown grim:grim /etc/grim-reaper/config.yaml
sudo chown grim:grim /etc/grim-reaper/environment

# Configure SSL/TLS
sudo certbot --nginx -d grim-reaper.company.com

# Enable security headers
sudo a2enmod headers
sudo systemctl reload apache2
```

### Database Security

```bash
# Secure PostgreSQL
sudo -u postgres psql -c "ALTER USER grim PASSWORD 'NEW_SECURE_PASSWORD';"
sudo -u postgres psql -c "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;"
sudo -u postgres psql -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO grim;"

# Configure PostgreSQL security
sudo nano /etc/postgresql/*/main/postgresql.conf
# Add: ssl = on
# Add: ssl_cert_file = '/etc/ssl/certs/postgresql.crt'
# Add: ssl_key_file = '/etc/ssl/private/postgresql.key'

sudo systemctl restart postgresql
```

### Network Security

```bash
# Configure fail2ban
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Add Grim Reaper jail
sudo nano /etc/fail2ban/jail.local
# Add:
# [grim-reaper]
# enabled = true
# port = http,https
# filter = grim-reaper
# logpath = /var/log/grim/security.log
# maxretry = 3
# bantime = 3600

sudo systemctl restart fail2ban
```

---

## Backup & Recovery

### System Backup Strategy

```bash
#!/bin/bash
# /opt/grim-reaper/scripts/system_backup.sh

BACKUP_DIR="/backups/system"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup configuration
tar -czf $BACKUP_DIR/config_$DATE.tar.gz \
  /etc/grim-reaper \
  /etc/nginx/sites-available/grim-reaper \
  /etc/systemd/system/grim-*.service

# Backup database
sudo -u postgres pg_dump grim_reaper > $BACKUP_DIR/database_$DATE.sql

# Backup logs
tar -czf $BACKUP_DIR/logs_$DATE.tar.gz /var/log/grim

# Backup application
tar -czf $BACKUP_DIR/application_$DATE.tar.gz /opt/grim-reaper

# Encrypt backups
gpg --encrypt --recipient admin@company.com $BACKUP_DIR/*_$DATE.*

# Upload to remote storage
aws s3 cp $BACKUP_DIR s3://grim-reaper-system-backups/ --recursive

# Clean up old backups (keep 30 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
```

### Disaster Recovery Plan

#### Recovery Procedures

1. **System Recovery**
   ```bash
   # Restore from backup
   sudo systemctl stop grim-*
   sudo tar -xzf /backups/system/config_$DATE.tar.gz -C /
   sudo -u postgres psql grim_reaper < /backups/system/database_$DATE.sql
   sudo systemctl start grim-*
   ```

2. **Data Recovery**
   ```bash
   # Restore from backup
   /opt/grim-reaper/sh_grim/restore.sh recover backup_$DATE.tar.gz /restore
   ```

3. **Configuration Recovery**
   ```bash
   # Restore configuration
   sudo cp /backups/system/config_$DATE.tar.gz /tmp/
   cd /tmp && tar -xzf config_$DATE.tar.gz
   sudo cp -r etc/grim-reaper/* /etc/grim-reaper/
   sudo systemctl restart grim-*
   ```

#### Recovery Testing

```bash
# Test recovery procedures monthly
#!/bin/bash
# /opt/grim-reaper/scripts/test_recovery.sh

# Create test environment
sudo docker run -d --name grim-test -p 8081:8080 grim-reaper:test

# Test backup restoration
curl -X POST http://localhost:8081/api/v1/backups/test/restore \
  -H "Authorization: Bearer TEST_KEY" \
  -d '{"destination": "/tmp/test"}'

# Verify functionality
curl http://localhost:8081/api/v1/system/health

# Clean up
sudo docker stop grim-test
sudo docker rm grim-test
```

---

## Scaling

### Horizontal Scaling

#### Load Balancer Configuration

```nginx
# /etc/nginx/sites-available/grim-reaper-cluster

upstream grim_backend {
    least_conn;
    server grim-reaper-1.company.com:8080 max_fails=3 fail_timeout=30s;
    server grim-reaper-2.company.com:8080 max_fails=3 fail_timeout=30s;
    server grim-reaper-3.company.com:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name grim-reaper.company.com;
    
    location /api/ {
        proxy_pass http://grim_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Database Scaling

```bash
# Configure read replicas
sudo -u postgres psql -c "
CREATE PUBLICATION grim_reaper_pub FOR ALL TABLES;
"

# On replica servers
sudo -u postgres psql -c "
CREATE SUBSCRIPTION grim_reaper_sub 
CONNECTION 'host=grim-reaper-1.company.com port=5432 dbname=grim_reaper user=grim password=SECURE_PASSWORD'
PUBLICATION grim_reaper_pub;
"
```

### Vertical Scaling

#### Resource Optimization

```yaml
# /etc/grim-reaper/config.yaml
performance:
  max_memory: "16G"
  max_cpu_percent: 90
  connection_pool_size: 50
  cache_size: "8G"
  worker_processes: 8
  thread_pool_size: 32
```

#### Monitoring Scaling

```bash
# Increase monitoring capacity
monitoring:
  max_concurrent_monitors: 100
  event_buffer_size: 10000
  check_interval: 30
  batch_size: 1000
```

### Auto-Scaling

#### Kubernetes Deployment

```yaml
# grim-reaper-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grim-reaper
spec:
  replicas: 3
  selector:
    matchLabels:
      app: grim-reaper
  template:
    metadata:
      labels:
        app: grim-reaper
    spec:
      containers:
      - name: grim-reaper
        image: grim-reaper:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
        env:
        - name: GRIM_DB_HOST
          value: "grim-reaper-db"
---
apiVersion: v1
kind: Service
metadata:
  name: grim-reaper-service
spec:
  selector:
    app: grim-reaper
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

#### Auto-scaling Configuration

```yaml
# grim-reaper-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: grim-reaper-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: grim-reaper
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

*This deployment guide provides comprehensive instructions for deploying the Grim Reaper system in production environments. For additional support, refer to the troubleshooting section or contact the development team.* 