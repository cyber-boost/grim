# Grim Reaper System - API Documentation

**Complete API Reference for All System Components**

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [py_grim Web APIs](#py_grim-web-apis)
4. [Scythe Orchestration APIs](#scythe-orchestration-apis)
5. [go_grim Compression APIs](#go_grim-compression-apis)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [Examples](#examples)

---

## Overview

The Grim Reaper system provides three main API interfaces:

- **py_grim Web APIs** - RESTful HTTP APIs for web integration
- **Scythe Orchestration APIs** - Command-line and programmatic orchestration
- **go_grim Compression APIs** - High-performance compression and optimization

### API Endpoints

| Component | Base URL | Protocol | Purpose |
|-----------|----------|----------|---------|
| py_grim | `http://localhost:8080/api/v1` | HTTP/REST | Web interface and integration |
| Scythe | `scythe://localhost:9090` | Custom TCP | Orchestration and management |
| go_grim | `grpc://localhost:50051` | gRPC | High-performance operations |

---

## Authentication

### API Keys

Most endpoints require authentication using API keys:

```bash
# Generate API key
curl -X POST http://localhost:8080/api/v1/auth/generate-key \
  -H "Content-Type: application/json" \
  -d '{"user": "admin", "permissions": ["read", "write"]}'
```

### Bearer Token

Include the API key in the Authorization header:

```bash
curl -X GET http://localhost:8080/api/v1/backups \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Session Authentication

For web interfaces, use session-based authentication:

```bash
# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'

# Use session cookie
curl -X GET http://localhost:8080/api/v1/backups \
  -H "Cookie: session=YOUR_SESSION_ID"
```

---

## py_grim Web APIs

### Base URL: `http://localhost:8080/api/v1`

### Backup APIs

#### List Backups

```http
GET /backups
```

**Parameters:**
- `type` (optional): Filter by backup type (`daily`, `weekly`, `monthly`)
- `limit` (optional): Number of results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "backups": [
    {
      "id": "backup_2024-01-15_120000",
      "type": "daily",
      "path": "/backups/daily/backup_2024-01-15_120000.tar.gz",
      "size": 1073741824,
      "created_at": "2024-01-15T12:00:00Z",
      "status": "completed",
      "checksum": "sha256:abc123..."
    }
  ],
  "total": 150,
  "limit": 50,
  "offset": 0
}
```

#### Create Backup

```http
POST /backups
```

**Request Body:**
```json
{
  "type": "daily",
  "paths": ["/var/www", "/home"],
  "encrypt": true,
  "compress": true,
  "retention_days": 30
}
```

**Response:**
```json
{
  "backup_id": "backup_2024-01-15_120000",
  "status": "started",
  "estimated_duration": 300,
  "progress_url": "/api/v1/backups/backup_2024-01-15_120000/progress"
}
```

#### Get Backup Progress

```http
GET /backups/{backup_id}/progress
```

**Response:**
```json
{
  "backup_id": "backup_2024-01-15_120000",
  "status": "in_progress",
  "progress": 65,
  "files_processed": 1250,
  "bytes_processed": 536870912,
  "estimated_completion": "2024-01-15T12:05:00Z"
}
```

#### Restore Backup

```http
POST /backups/{backup_id}/restore
```

**Request Body:**
```json
{
  "destination": "/restore/path",
  "extract_files": ["/path/to/specific/file"],
  "overwrite": false
}
```

### Monitoring APIs

#### Start Monitoring

```http
POST /monitoring
```

**Request Body:**
```json
{
  "path": "/var/www",
  "recursive": true,
  "exclude_patterns": ["*.tmp", "*.log"],
  "threshold": "100M",
  "check_interval": 60
}
```

#### Get Monitoring Status

```http
GET /monitoring/{path_id}
```

**Response:**
```json
{
  "path_id": "var_www",
  "path": "/var/www",
  "status": "active",
  "events_count": 1250,
  "last_check": "2024-01-15T12:00:00Z",
  "size": 1073741824,
  "files_count": 5000
}
```

#### Get Monitoring Events

```http
GET /monitoring/{path_id}/events
```

**Parameters:**
- `limit` (optional): Number of events (default: 100)
- `since` (optional): Events since timestamp
- `type` (optional): Event type (`created`, `modified`, `deleted`)

### Security APIs

#### License Status

```http
GET /security/license
```

**Response:**
```json
{
  "status": "valid",
  "project_id": "proj123",
  "license_key": "GRIM-XXXX-XXXX-XXXX",
  "expires_at": "2024-12-31T23:59:59Z",
  "violations": 0,
  "features": ["backup", "monitor", "security"]
}
```

#### Security Audit

```http
POST /security/audit
```

**Request Body:**
```json
{
  "paths": ["/var/www", "/etc"],
  "scan_type": "full",
  "include_vulnerabilities": true
}
```

### System APIs

#### Health Check

```http
GET /system/health
```

**Response:**
```json
{
  "status": "healthy",
  "components": {
    "backup": "healthy",
    "monitor": "healthy",
    "security": "healthy",
    "database": "healthy"
  },
  "uptime": 86400,
  "version": "1.0.0"
}
```

#### System Metrics

```http
GET /system/metrics
```

**Response:**
```json
{
  "cpu_usage": 25.5,
  "memory_usage": 2048,
  "disk_usage": 53687091200,
  "active_backups": 2,
  "monitored_paths": 5,
  "api_requests_per_minute": 150
}
```

---

## Scythe Orchestration APIs

### Command-Line Interface

Scythe provides a comprehensive command-line interface for system orchestration:

#### Backup Orchestration

```bash
# Create backup with orchestration
scythe backup create daily --paths /var/www,/home --encrypt

# Monitor backup progress
scythe backup status backup_2024-01-15_120000

# List all backups
scythe backup list --type daily --limit 10

# Restore backup
scythe backup restore backup_2024-01-15_120000 --destination /restore
```

#### Monitoring Orchestration

```bash
# Start monitoring with orchestration
scythe monitor start /var/www --recursive --exclude "*.tmp,*.log"

# Check monitoring status
scythe monitor status /var/www

# Get monitoring events
scythe monitor events /var/www --limit 50 --since "2024-01-15T00:00:00Z"

# Stop monitoring
scythe monitor stop /var/www
```

#### Security Orchestration

```bash
# Install license protection
scythe security install /app/project proj123 "My Project" --start

# Check license status
scythe security status

# Run security audit
scythe security audit --paths /var/www,/etc --full-scan

# Generate security report
scythe security report --format json --output security_report.json
```

#### System Orchestration

```bash
# System health check
scythe system health

# Get system metrics
scythe system metrics --format json

# Update system
scythe system update --force

# Restart services
scythe system restart --services backup,monitor
```

### Programmatic API

Scythe also provides a Python API for programmatic access:

```python
from scythe import ScytheOrchestrator

# Initialize orchestrator
scythe = ScytheOrchestrator()

# Create backup
backup_id = scythe.backup.create(
    type="daily",
    paths=["/var/www", "/home"],
    encrypt=True,
    compress=True
)

# Monitor progress
progress = scythe.backup.get_progress(backup_id)
print(f"Progress: {progress['progress']}%")

# Start monitoring
monitor_id = scythe.monitor.start(
    path="/var/www",
    recursive=True,
    exclude_patterns=["*.tmp", "*.log"]
)

# Get monitoring events
events = scythe.monitor.get_events(
    monitor_id,
    limit=100,
    since="2024-01-15T00:00:00Z"
)

# Check system health
health = scythe.system.health()
print(f"System status: {health['status']}")
```

### Configuration API

```python
# Get configuration
config = scythe.config.get()

# Update configuration
scythe.config.update({
    "backup": {
        "retention_days": 60,
        "compression_level": 9
    },
    "monitoring": {
        "check_interval": 30
    }
})

# Validate configuration
validation = scythe.config.validate()
```

---

## go_grim Compression APIs

### gRPC Interface

go_grim provides high-performance compression APIs via gRPC:

#### Compression Service

```protobuf
service CompressionService {
  rpc Compress(CompressRequest) returns (CompressResponse);
  rpc Decompress(DecompressRequest) returns (DecompressResponse);
  rpc Optimize(OptimizeRequest) returns (OptimizeResponse);
  rpc Benchmark(BenchmarkRequest) returns (BenchmarkResponse);
}
```

#### Compression Request

```protobuf
message CompressRequest {
  bytes data = 1;
  CompressionAlgorithm algorithm = 2;
  int32 level = 3;
  bool encrypt = 4;
  string encryption_key = 5;
}

enum CompressionAlgorithm {
  GZIP = 0;
  LZ4 = 1;
  ZSTD = 2;
  LZMA = 3;
}
```

#### Compression Response

```protobuf
message CompressResponse {
  bytes compressed_data = 1;
  int64 original_size = 2;
  int64 compressed_size = 3;
  float compression_ratio = 4;
  int64 processing_time_ms = 5;
  string checksum = 6;
}
```

### Go Client Example

```go
package main

import (
    "context"
    "log"
    "time"
    
    "google.golang.org/grpc"
    pb "github.com/grim-reaper/go_grim/proto"
)

func main() {
    // Connect to go_grim
    conn, err := grpc.Dial("localhost:50051", grpc.WithInsecure())
    if err != nil {
        log.Fatalf("Failed to connect: %v", err)
    }
    defer conn.Close()
    
    client := pb.NewCompressionServiceClient(conn)
    
    // Compress data
    ctx, cancel := context.WithTimeout(context.Background(), time.Second*30)
    defer cancel()
    
    data := []byte("This is test data to compress")
    req := &pb.CompressRequest{
        Data: data,
        Algorithm: pb.CompressionAlgorithm_ZSTD,
        Level: 6,
        Encrypt: false,
    }
    
    resp, err := client.Compress(ctx, req)
    if err != nil {
        log.Fatalf("Compression failed: %v", err)
    }
    
    log.Printf("Compression ratio: %.2f%%", resp.CompressionRatio*100)
    log.Printf("Processing time: %dms", resp.ProcessingTimeMs)
}
```

### Python Client Example

```python
import grpc
from grpc import ssl_channel_credentials
import grim_compression_pb2
import grim_compression_pb2_grpc

def compress_data(data, algorithm='ZSTD', level=6):
    # Create channel
    channel = grpc.secure_channel(
        'localhost:50051',
        ssl_channel_credentials()
    )
    
    # Create stub
    stub = grim_compression_pb2_grpc.CompressionServiceStub(channel)
    
    # Create request
    request = grim_compression_pb2.CompressRequest(
        data=data,
        algorithm=getattr(grim_compression_pb2, algorithm),
        level=level,
        encrypt=False
    )
    
    # Call service
    response = stub.Compress(request)
    
    return {
        'compressed_data': response.compressed_data,
        'compression_ratio': response.compression_ratio,
        'processing_time_ms': response.processing_time_ms
    }

# Usage
data = b"This is test data to compress"
result = compress_data(data, 'ZSTD', 6)
print(f"Compression ratio: {result['compression_ratio']:.2%}")
```

### Performance Benchmarks

```bash
# Run compression benchmark
go_grim benchmark --algorithm zstd --level 6 --iterations 1000

# Compare algorithms
go_grim benchmark --compare --data-size 1GB
```

**Benchmark Results:**
```
Algorithm | Level | Speed (MB/s) | Ratio | Memory (MB)
----------|-------|--------------|-------|------------
GZIP      | 6     | 45.2         | 2.8   | 8
LZ4       | 1     | 450.1        | 2.1   | 64
ZSTD      | 6     | 180.3        | 3.2   | 32
LZMA      | 6     | 12.8         | 4.1   | 128
```

---

## Error Handling

### HTTP Status Codes

| Code | Description | Example |
|------|-------------|---------|
| 200 | Success | Operation completed successfully |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid parameters or request format |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource already exists |
| 422 | Unprocessable Entity | Validation failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |

### Error Response Format

```json
{
  "error": {
    "code": "BACKUP_FAILED",
    "message": "Backup operation failed",
    "details": "Disk space insufficient",
    "timestamp": "2024-01-15T12:00:00Z",
    "request_id": "req_123456789"
  }
}
```

### Common Error Codes

| Code | Description | Resolution |
|------|-------------|------------|
| `BACKUP_FAILED` | Backup operation failed | Check disk space and permissions |
| `MONITORING_ERROR` | Monitoring operation failed | Verify path exists and is accessible |
| `LICENSE_INVALID` | License validation failed | Check license key and expiration |
| `AUTHENTICATION_FAILED` | Authentication failed | Verify API key or credentials |
| `RATE_LIMIT_EXCEEDED` | Rate limit exceeded | Wait and retry with exponential backoff |
| `VALIDATION_ERROR` | Request validation failed | Check request parameters |

---

## Rate Limiting

### Limits

- **API Requests**: 1000 requests per minute per API key
- **Backup Operations**: 10 concurrent backups per system
- **Monitoring Operations**: 50 concurrent monitoring sessions
- **Compression Operations**: 100 concurrent compression tasks

### Rate Limit Headers

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1642248000
```

### Handling Rate Limits

```python
import time
import requests

def make_request_with_retry(url, headers, max_retries=3):
    for attempt in range(max_retries):
        response = requests.get(url, headers=headers)
        
        if response.status_code == 429:
            reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
            wait_time = max(reset_time - time.time(), 1)
            time.sleep(wait_time)
            continue
            
        return response
    
    raise Exception("Max retries exceeded")
```

---

## Examples

### Complete Backup Workflow

```python
import requests
import time

class GrimReaperClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
    
    def create_backup(self, paths, backup_type='daily'):
        """Create a new backup"""
        response = requests.post(
            f'{self.base_url}/backups',
            headers=self.headers,
            json={
                'type': backup_type,
                'paths': paths,
                'encrypt': True,
                'compress': True
            }
        )
        response.raise_for_status()
        return response.json()
    
    def monitor_backup_progress(self, backup_id):
        """Monitor backup progress"""
        while True:
            response = requests.get(
                f'{self.base_url}/backups/{backup_id}/progress',
                headers=self.headers
            )
            response.raise_for_status()
            progress = response.json()
            
            print(f"Progress: {progress['progress']}%")
            
            if progress['status'] in ['completed', 'failed']:
                return progress
            
            time.sleep(5)
    
    def list_backups(self, backup_type=None):
        """List available backups"""
        params = {}
        if backup_type:
            params['type'] = backup_type
        
        response = requests.get(
            f'{self.base_url}/backups',
            headers=self.headers,
            params=params
        )
        response.raise_for_status()
        return response.json()

# Usage
client = GrimReaperClient('http://localhost:8080/api/v1', 'your-api-key')

# Create backup
backup = client.create_backup(['/var/www', '/home'], 'daily')
backup_id = backup['backup_id']

# Monitor progress
result = client.monitor_backup_progress(backup_id)
print(f"Backup completed: {result['status']}")

# List backups
backups = client.list_backups('daily')
print(f"Found {len(backups['backups'])} daily backups")
```

### Monitoring Integration

```python
def setup_monitoring(client, paths):
    """Set up monitoring for multiple paths"""
    monitors = []
    
    for path in paths:
        response = requests.post(
            f'{client.base_url}/monitoring',
            headers=client.headers,
            json={
                'path': path,
                'recursive': True,
                'exclude_patterns': ['*.tmp', '*.log', '.git/*'],
                'threshold': '100M',
                'check_interval': 60
            }
        )
        response.raise_for_status()
        monitors.append(response.json())
    
    return monitors

def get_monitoring_events(client, path_id, hours=24):
    """Get monitoring events for the last N hours"""
    import datetime
    
    since = datetime.datetime.now() - datetime.timedelta(hours=hours)
    
    response = requests.get(
        f'{client.base_url}/monitoring/{path_id}/events',
        headers=client.headers,
        params={
            'since': since.isoformat(),
            'limit': 1000
        }
    )
    response.raise_for_status()
    return response.json()

# Usage
paths = ['/var/www', '/home', '/etc']
monitors = setup_monitoring(client, paths)

# Check events
for monitor in monitors:
    events = get_monitoring_events(client, monitor['path_id'])
    print(f"Path {monitor['path']}: {len(events['events'])} events")
```

### Security Integration

```python
def check_security_status(client):
    """Check security and license status"""
    # Check license
    license_response = requests.get(
        f'{client.base_url}/security/license',
        headers=client.headers
    )
    license_response.raise_for_status()
    license = license_response.json()
    
    # Run security audit
    audit_response = requests.post(
        f'{client.base_url}/security/audit',
        headers=client.headers,
        json={
            'paths': ['/var/www', '/etc'],
            'scan_type': 'full',
            'include_vulnerabilities': True
        }
    )
    audit_response.raise_for_status()
    audit = audit_response.json()
    
    return {
        'license': license,
        'audit': audit
    }

# Usage
security = check_security_status(client)
print(f"License status: {security['license']['status']}")
print(f"Security audit: {security['audit']['status']}")
```

---

*This API documentation provides comprehensive coverage of all Grim Reaper system interfaces. For specific implementation details, refer to the individual component documentation.* 