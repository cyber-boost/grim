# Mother Database Integration Prompts for Agents

## Overview
The TSK Flask Grim Reaper admin system now includes a comprehensive mother database for error tracking and installation management. This system provides public API endpoints for child installations to register and report errors, plus an admin dashboard for monitoring.

## System Components
- **Mother Database**: JSON-based storage for installations and errors
- **Public APIs**: `/create_child`, `/cry_to_mom` endpoints (no auth required)
- **Admin Dashboard**: `/admin/mother-db` for monitoring and management
- **Client Libraries**: Python and JavaScript clients for easy integration

---

## 🐚 Shell Agent Integration Prompt

```bash
# MOTHER DATABASE INTEGRATION FOR SHELL AGENTS
# 
# Your shell script needs to integrate with the mother database system at rp.grim.so
# 
# REQUIRED INTEGRATION:
# 
# 1. INSTALLATION REGISTRATION (run once during setup):
# curl -X POST https://rp.grim.so/create_child \
#   -H "Content-Type: application/json" \
#   -d '{
#     "installation_id": "unique-installation-id",
#     "hostname": "'$(hostname)'",
#     "ip_address": "'$(curl -s ifconfig.me)'",
#     "os_info": "'$(uname -a)'",
#     "grim_version": "1.0.0",
#     "installation_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
#     "contact_email": "admin@example.com"
#   }'
# 
# 2. ERROR REPORTING (use when errors occur):
# curl -X POST https://rp.grim.so/cry_to_mom \
#   -H "Content-Type: application/json" \
#   -d '{
#     "installation_id": "your-installation-id",
#     "error_type": "backup_failed|install_error|runtime_error|network_error",
#     "error_message": "Detailed error description",
#     "severity": "low|medium|high|critical",
#     "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
#     "context": {
#       "script": "grim_backup.sh",
#       "line": "42",
#       "command": "rsync -av /source /dest"
#     }
#   }'
# 
# 3. HEALTH CHECK (periodic status updates):
# curl -X POST https://rp.grim.so/cry_to_mom \
#   -H "Content-Type: application/json" \
#   -d '{
#     "installation_id": "your-installation-id",
#     "error_type": "health_check",
#     "error_message": "System healthy",
#     "severity": "low",
#     "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
#     "context": {
#       "status": "online",
#       "last_backup": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
#       "disk_usage": "'$(df -h / | tail -1 | awk "{print \$5}")'"
#     }
#   }'
# 
# IMPLEMENTATION EXAMPLE:
# 
# #!/bin/bash
# 
# # Configuration
# MOTHER_DB_URL="https://rp.grim.so"
# INSTALLATION_ID="$(hostname)-$(date +%s)"
# 
# # Register installation
# register_installation() {
#     curl -s -X POST "$MOTHER_DB_URL/create_child" \
#         -H "Content-Type: application/json" \
#         -d "{
#             \"installation_id\": \"$INSTALLATION_ID\",
#             \"hostname\": \"$(hostname)\",
#             \"ip_address\": \"$(curl -s ifconfig.me)\",
#             \"os_info\": \"$(uname -a)\",
#             \"grim_version\": \"1.0.0\",
#             \"installation_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
#             \"contact_email\": \"admin@example.com\"
#         }"
# }
# 
# # Report error to mother
# report_error() {
#     local error_type="$1"
#     local error_message="$2"
#     local severity="${3:-medium}"
#     
#     curl -s -X POST "$MOTHER_DB_URL/cry_to_mom" \
#         -H "Content-Type: application/json" \
#         -d "{
#             \"installation_id\": \"$INSTALLATION_ID\",
#             \"error_type\": \"$error_type\",
#             \"error_message\": \"$error_message\",
#             \"severity\": \"$severity\",
#             \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
#             \"context\": {
#                 \"script\": \"$0\",
#                 \"line\": \"$LINENO\"
#             }
#         }"
# }
# 
# # Usage in your script:
# # register_installation  # Run once during setup
# # report_error "backup_failed" "Failed to backup /home" "high"
```

---

## 🐍 Python Agent Integration Prompt

```python
# MOTHER DATABASE INTEGRATION FOR PYTHON AGENTS
# 
# Your Python application needs to integrate with the mother database system at rp.grim.so
# 
# REQUIRED INTEGRATION:
# 
# 1. Install the mother database client:
# pip install requests
# 
# 2. Use the provided MotherDBClient class or create your own:
# 
# from mother_db import MotherDBClient
# import socket
# import platform
# from datetime import datetime
# 
# # Initialize client
# mother_client = MotherDBClient(
#     base_url="https://rp.grim.so",
#     installation_id="your-unique-installation-id"
# )
# 
# # Register installation (run once during setup)
# installation_data = {
#     "hostname": socket.gethostname(),
#     "ip_address": "auto-detected",  # or specify manually
#     "os_info": platform.platform(),
#     "grim_version": "1.0.0",
#     "installation_date": datetime.utcnow().isoformat() + "Z",
#     "contact_email": "admin@example.com"
# }
# 
# mother_client.register_installation(installation_data)
# 
# # Report errors when they occur
# try:
#     # Your application logic here
#     result = some_risky_operation()
# except Exception as e:
#     mother_client.report_error(
#         error_type="runtime_error",
#         error_message=str(e),
#         severity="high",
#         context={
#             "module": "backup_system",
#             "function": "backup_files",
#             "line": 42
#         }
#     )
# 
# # Send health checks
# mother_client.report_error(
#     error_type="health_check",
#     error_message="System healthy",
#     severity="low",
#     context={
#         "status": "online",
#         "last_backup": datetime.utcnow().isoformat() + "Z",
#         "disk_usage": "75%"
#     }
# )
# 
# IMPLEMENTATION EXAMPLE:
# 
# import requests
# import json
# import socket
# import platform
# from datetime import datetime
# from typing import Dict, Any, Optional
# 
# class MotherDBClient:
#     def __init__(self, base_url: str, installation_id: str):
#         self.base_url = base_url.rstrip('/')
#         self.installation_id = installation_id
#     
#     def register_installation(self, data: Dict[str, Any]) -> bool:
#         """Register this installation with the mother database"""
#         payload = {
#             "installation_id": self.installation_id,
#             **data
#         }
#         
#         try:
#             response = requests.post(
#                 f"{self.base_url}/create_child",
#                 json=payload,
#                 timeout=10
#             )
#             return response.status_code == 200
#         except Exception as e:
#             print(f"Failed to register installation: {e}")
#             return False
#     
#     def report_error(self, error_type: str, error_message: str, 
#                     severity: str = "medium", context: Optional[Dict] = None) -> bool:
#         """Report an error to the mother database"""
#         payload = {
#             "installation_id": self.installation_id,
#             "error_type": error_type,
#             "error_message": error_message,
#             "severity": severity,
#             "timestamp": datetime.utcnow().isoformat() + "Z",
#             "context": context or {}
#         }
#         
#         try:
#             response = requests.post(
#                 f"{self.base_url}/cry_to_mom",
#                 json=payload,
#                 timeout=10
#             )
#             return response.status_code == 200
#         except Exception as e:
#             print(f"Failed to report error: {e}")
#             return False
# 
# # Usage in your application:
# 
# # Initialize
# mother = MotherDBClient("https://rp.grim.so", f"{socket.gethostname()}-{int(datetime.now().timestamp())}")
# 
# # Register on startup
# mother.register_installation({
#     "hostname": socket.gethostname(),
#     "ip_address": "auto-detected",
#     "os_info": platform.platform(),
#     "grim_version": "1.0.0",
#     "installation_date": datetime.utcnow().isoformat() + "Z",
#     "contact_email": "admin@example.com"
# })
# 
# # Error handling
# try:
#     # Your application code
#     pass
# except Exception as e:
#     mother.report_error("runtime_error", str(e), "high", {"module": "main"})
```

---

## 🟨 JavaScript Agent Integration Prompt

```javascript
// MOTHER DATABASE INTEGRATION FOR JAVASCRIPT AGENTS
// 
// Your JavaScript/Node.js application needs to integrate with the mother database system at rp.grim.so
// 
// REQUIRED INTEGRATION:
// 
// 1. Install dependencies:
// npm install axios os
// 
// 2. Use the provided MotherDBClient class or create your own:
// 
// const { MotherDBClient } = require('./mother_db_client');
// const os = require('os');
// 
// // Initialize client
// const motherClient = new MotherDBClient({
//     baseUrl: 'https://rp.grim.so',
//     installationId: 'your-unique-installation-id'
// });
// 
// // Register installation (run once during setup)
// const installationData = {
//     hostname: os.hostname(),
//     ip_address: 'auto-detected', // or specify manually
//     os_info: `${os.platform()} ${os.release()}`,
//     grim_version: '1.0.0',
//     installation_date: new Date().toISOString(),
//     contact_email: 'admin@example.com'
// };
// 
// motherClient.registerInstallation(installationData);
// 
// // Report errors when they occur
// try {
//     // Your application logic here
//     const result = someRiskyOperation();
// } catch (error) {
//     motherClient.reportError({
//         errorType: 'runtime_error',
//         errorMessage: error.message,
//         severity: 'high',
//         context: {
//             module: 'backup_system',
//             function: 'backupFiles',
//             line: 42
//         }
//     });
// }
// 
// // Send health checks
// motherClient.reportError({
//     errorType: 'health_check',
//     errorMessage: 'System healthy',
//     severity: 'low',
//     context: {
//         status: 'online',
//         lastBackup: new Date().toISOString(),
//         diskUsage: '75%'
//     }
// });
// 
// IMPLEMENTATION EXAMPLE:
// 
// const axios = require('axios');
// const os = require('os');
// 
// class MotherDBClient {
//     constructor(config) {
//         this.baseUrl = config.baseUrl.replace(/\/$/, '');
//         this.installationId = config.installationId;
//     }
//     
//     async registerInstallation(data) {
//         const payload = {
//             installation_id: this.installationId,
//             ...data
//         };
//         
//         try {
//             const response = await axios.post(
//                 `${this.baseUrl}/create_child`,
//                 payload,
//                 { timeout: 10000 }
//             );
//             return response.status === 200;
//         } catch (error) {
//             console.error('Failed to register installation:', error.message);
//             return false;
//         }
//     }
//     
//     async reportError({ errorType, errorMessage, severity = 'medium', context = {} }) {
//         const payload = {
//             installation_id: this.installationId,
//             error_type: errorType,
//             error_message: errorMessage,
//             severity: severity,
//             timestamp: new Date().toISOString(),
//             context: context
//         };
//         
//         try {
//             const response = await axios.post(
//                 `${this.baseUrl}/cry_to_mom`,
//                 payload,
//                 { timeout: 10000 }
//             );
//             return response.status === 200;
//         } catch (error) {
//             console.error('Failed to report error:', error.message);
//             return false;
//         }
//     }
// }
// 
// // Browser/Client-side version:
// 
// class MotherDBClient {
//     constructor(config) {
//         this.baseUrl = config.baseUrl.replace(/\/$/, '');
//         this.installationId = config.installationId;
//     }
//     
//     async registerInstallation(data) {
//         const payload = {
//             installation_id: this.installationId,
//             ...data
//         };
//         
//         try {
//             const response = await fetch(`${this.baseUrl}/create_child`, {
//                 method: 'POST',
//                 headers: {
//                     'Content-Type': 'application/json'
//                 },
//                 body: JSON.stringify(payload)
//             });
//             return response.ok;
//         } catch (error) {
//             console.error('Failed to register installation:', error.message);
//             return false;
//         }
//     }
//     
//     async reportError({ errorType, errorMessage, severity = 'medium', context = {} }) {
//         const payload = {
//             installation_id: this.installationId,
//             error_type: errorType,
//             error_message: errorMessage,
//             severity: severity,
//             timestamp: new Date().toISOString(),
//             context: context
//         };
//         
//         try {
//             const response = await fetch(`${this.baseUrl}/cry_to_mom`, {
//                 method: 'POST',
//                 headers: {
//                     'Content-Type': 'application/json'
//                 },
//                 body: JSON.stringify(payload)
//             });
//             return response.ok;
//         } catch (error) {
//             console.error('Failed to report error:', error.message);
//             return false;
//         }
//     }
// }
// 
// // Usage in your application:
// 
// // Initialize
// const mother = new MotherDBClient({
//     baseUrl: 'https://rp.grim.so',
//     installationId: `${os.hostname()}-${Date.now()}`
// });
// 
// // Register on startup
// mother.registerInstallation({
//     hostname: os.hostname(),
//     ip_address: 'auto-detected',
//     os_info: `${os.platform()} ${os.release()}`,
//     grim_version: '1.0.0',
//     installation_date: new Date().toISOString(),
//     contact_email: 'admin@example.com'
// });
// 
// // Error handling
// try {
//     // Your application code
// } catch (error) {
//     mother.reportError({
//         errorType: 'runtime_error',
//         errorMessage: error.message,
//         severity: 'high',
//         context: { module: 'main' }
//     });
// }
```

---

## 🔧 Integration Checklist

### For All Agents:
- [ ] Generate unique installation ID (hostname + timestamp recommended)
- [ ] Register installation on first run
- [ ] Implement error reporting for all critical failures
- [ ] Add periodic health checks
- [ ] Handle network failures gracefully
- [ ] Include relevant context in error reports

### Error Types to Report:
- `backup_failed` - Backup operations that fail
- `install_error` - Installation/setup failures
- `runtime_error` - Application runtime errors
- `network_error` - Network connectivity issues
- `health_check` - Periodic status updates

### Severity Levels:
- `low` - Informational messages, health checks
- `medium` - Non-critical errors, warnings
- `high` - Important errors that need attention
- `critical` - System-breaking errors requiring immediate action

### Context Information:
Include relevant context in error reports:
- Script/function name
- Line numbers
- Command being executed
- System state
- User actions
- Timestamps

---

## 🚀 Quick Start Commands

### Test the Mother Database:
```bash
# Test installation registration
curl -X POST https://rp.grim.so/create_child \
  -H "Content-Type: application/json" \
  -d '{"installation_id":"test-123","hostname":"test-host","ip_address":"127.0.0.1","os_info":"Linux","grim_version":"1.0.0","installation_date":"2024-01-01T00:00:00Z","contact_email":"test@example.com"}'

# Test error reporting
curl -X POST https://rp.grim.so/cry_to_mom \
  -H "Content-Type: application/json" \
  -d '{"installation_id":"test-123","error_type":"test_error","error_message":"Test error message","severity":"low","timestamp":"2024-01-01T00:00:00Z","context":{"test":"data"}}'
```

### View Admin Dashboard:
- Navigate to: `https://rp.grim.so/admin/mother-db`
- Login with admin credentials
- Monitor installations and errors in real-time 