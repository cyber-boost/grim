# Grim Reaper 🗡️ JavaScript/Node.js Package

[![npm](https://img.shields.io/npm/v/grim-reaper)](https://www.npmjs.com/package/grim-reaper)
[![Downloads](https://img.shields.io/npm/dm/grim-reaper)](https://www.npmjs.com/package/grim-reaper)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://grim.so/license)

**When data death comes knocking, Grim ensures resurrection is just a command away.**

Enterprise-grade data protection platform with AI-powered backup decisions, military-grade encryption, multi-algorithm compression, content-based deduplication, real-time monitoring, and automated threat response.

## 🚀 Quick Install

```bash
npm install -g grim-reaper
```

## 🎯 Quick Start

```javascript
const GrimReaper = require('grim-reaper');

// Initialize Grim Reaper
const grim = new GrimReaper();

// Quick backup
await grim.backup('/important/data');

// Start monitoring
await grim.monitor('/var/log');

// Health check
const health = await grim.healthCheck();
console.log(`System Status: ${health.status}`);
```

## 📋 Complete Command Reference

All commands use the unified Grim Reaper command structure:

### 🤖 AI & Machine Learning

```bash
# AI Decision Engine
grim ai-decision init                    # Initialize AI decision engine
grim ai-decision analyze                 # Analyze files for intelligent backup decisions
grim ai-decision backup-priority         # Determine backup priorities using AI
grim ai-decision storage-optimize        # Optimize storage allocation with AI
grim ai-decision resource-manage         # Manage system resources intelligently
grim ai-decision validate                # Validate AI models and decisions
grim ai-decision report                  # Generate AI analysis report
grim ai-decision config                  # Configure AI parameters
grim ai-decision status                  # Check AI engine status

# AI Integration
grim ai init                             # Initialize AI integration framework
grim ai install                          # Install AI dependencies (TensorFlow/PyTorch)
grim ai train                            # Train AI models on your data
grim ai predict                          # Generate predictions from models
grim ai analyze                          # Analyze data patterns
grim ai optimize                         # Optimize AI performance
grim ai monitor                          # Monitor AI operations
grim ai validate                         # Validate model accuracy
grim ai report                           # Generate integration report
grim ai config                           # Configure AI integration
grim ai status                           # Check integration status

# AI Production Deployment
grim ai-deploy deploy                    # Deploy AI models to production
grim ai-deploy test                      # Run automated deployment tests
grim ai-deploy rollback                  # Rollback to previous version
grim ai-deploy monitor                   # Monitor deployed models
grim ai-deploy health                    # Check deployment health
grim ai-deploy backup                    # Backup current deployment
grim ai-deploy restore                   # Restore from backup
grim ai-deploy status                    # Check deployment status

# AI Training
grim ai-train analyze                    # Analyze training data
grim ai-train train                      # Train base models
grim ai-train predict                    # Generate predictions
grim ai-train cluster                    # Perform clustering analysis
grim ai-train extract                    # Extract features from data
grim ai-train validate                   # Validate model performance
grim ai-train report                     # Generate training report
grim ai-train neural                     # Train neural networks
grim ai-train ensemble                   # Train ensemble models
grim ai-train timeseries                 # Time series analysis
grim ai-train regression                 # Train regression models
grim ai-train classify                   # Train classification models
grim ai-train config                     # Configure training parameters
grim ai-train init                       # Initialize training environment

# AI Velocity Enhancement
grim ai-turbo turbo                      # Activate turbo mode for AI
grim ai-turbo optimize                   # Optimize AI performance
grim ai-turbo benchmark                  # Run performance benchmarks
grim ai-turbo validate                   # Validate optimizations
grim ai-turbo deploy                     # Deploy optimized models
grim ai-turbo monitor                    # Monitor performance gains
grim ai-turbo report                     # Generate performance report
```

### 💾 Backup & Recovery

```bash
# Core Backup Operations
grim backup create                       # Create intelligent backup
grim backup verify                       # Verify backup integrity
grim backup list                         # List all backups

# Core Backup Engine
grim backup-core create                  # Create core backup with progress
grim backup-core verify                  # Verify backup checksums
grim backup-core restore                 # Restore from backup
grim backup-core status                  # Check backup system status
grim backup-core init                    # Initialize backup system

# Automatic Backup Daemon
grim auto-backup start                   # Start automatic backup daemon
grim auto-backup stop                    # Stop backup daemon
grim auto-backup restart                 # Restart backup daemon
grim auto-backup status                  # Check daemon status
grim auto-backup health                  # Health check with diagnostics

# Restore Operations
grim restore recover                     # Restore from backup
grim restore list                        # List available restore points
grim restore verify                      # Verify restore integrity

# Deduplication
grim dedup dedup                         # Deduplicate files
grim dedup restore                       # Restore deduplicated files
grim dedup cleanup                       # Clean orphaned chunks
grim dedup stats                         # Show deduplication statistics
grim dedup verify                        # Verify dedup integrity
grim dedup benchmark                     # Run deduplication benchmarks
```

### 📊 System Monitoring & Health

```bash
# System Monitoring
grim monitor start                       # Start system monitoring
grim monitor stop                        # Stop monitoring
grim monitor status                      # Check monitor status
grim monitor show                        # Show current metrics
grim monitor report                      # Generate monitoring report

# Health Checking
grim health check                        # Complete health check
grim health fix                          # Auto-fix detected issues
grim health report                       # Generate health report
grim health monitor                      # Continuous health monitoring

# Enhanced Health Monitoring
grim health-check check                  # Enhanced health check
grim health-check services               # Check all services
grim health-check disk                   # Check disk health
grim health-check memory                 # Check memory status
grim health-check network                # Check network health
grim health-check fix                    # Auto-fix all issues
grim health-check report                 # Detailed health report
```

### 🔒 Security & Compliance

```bash
# Security Auditing
grim audit full                          # Complete security audit
grim audit permissions                   # Audit file permissions
grim audit compliance                    # Check compliance (CIS/STIG/NIST)
grim audit backups                       # Audit backup integrity
grim audit logs                          # Audit access logs
grim audit config                        # Audit configuration security
grim audit report                        # Generate audit report

# Security Operations
grim security scan                       # Run security scan
grim security audit                      # Deep security audit
grim security fix                        # Auto-fix vulnerabilities
grim security report                     # Generate security report
grim security monitor                    # Start security monitoring

# Security Testing
grim security-testing vulnerability      # Run vulnerability tests
grim security-testing penetration        # Run penetration tests
grim security-testing compliance         # Test compliance standards
grim security-testing report             # Generate test report

# File Encryption
grim encrypt encrypt                     # Encrypt files
grim encrypt decrypt                     # Decrypt files
grim encrypt key-gen                     # Generate encryption keys
grim encrypt verify                      # Verify encryption

# File Verification
grim verify integrity                    # Verify file integrity
grim verify checksum                     # Verify checksums
grim verify signature                    # Verify digital signatures
grim verify backup                       # Verify backup integrity

# Multi-Language Scanner
grim scanner scan                        # Multi-threaded file system scan
grim scanner info                        # Get file information and summary
grim scanner hash                        # Calculate file hashes (MD5/SHA256)
grim scanner py-scan                     # Python-based security scanning
grim scanner security                    # Security vulnerability scan
grim scanner malware                     # Malware detection scan
grim scanner vulnerability               # Deep vulnerability scan
grim scanner compliance                  # Compliance verification scan
grim scanner report                      # Generate scan report
```

### 🚀 Performance & Optimization

```bash
# High-Performance Compression
grim compression compress                # Compress with Go binary (8 algorithms)
grim compression decompress              # Decompress files
grim compression benchmark               # Run compression benchmarks
grim compression optimize                # Optimize compression
grim compression analyze                 # Analyze compression potential
grim compression list                    # List compressed files
grim compression cleanup                 # Clean temporary files

# System Optimization
grim blacksmith optimize                 # System-wide optimization
grim blacksmith maintain                 # Run maintenance tasks
grim blacksmith forge                    # Create new tools
grim blacksmith list-tools               # List available tools
grim blacksmith run-tool                 # Run specific tool
grim blacksmith schedule                 # Schedule maintenance
grim blacksmith list-scheduled           # List scheduled tasks
grim blacksmith backup-tools             # Backup custom tools
grim blacksmith restore-tools            # Restore tools
grim blacksmith update-tools             # Update all tools
grim blacksmith stats                    # Show forge statistics
grim blacksmith config                   # Configure forge

# Performance Testing
grim performance-test cpu                # Test CPU performance
grim performance-test memory             # Test memory performance
grim performance-test disk               # Test disk I/O
grim performance-test network            # Test network throughput
grim performance-test full               # Run all performance tests
grim performance-test report             # Generate performance report

# System Cleanup
grim cleanup all                         # Clean everything safely
grim cleanup backups                     # Clean old backups
grim cleanup temp                        # Clean temporary files
grim cleanup logs                        # Clean old logs
grim cleanup database                    # Clean database
grim cleanup duplicates                  # Remove duplicate files
grim cleanup report                      # Preview cleanup actions
```

### 🌐 Web Services & APIs

```bash
# Web Services
grim web start                           # Start FastAPI web server
grim web stop                            # Stop all web services
grim web restart                         # Restart web server
grim web gateway                         # Start API gateway with load balancing
grim web api                             # Start API application
grim web status                          # Show web services status

# Monitoring Dashboard
grim dashboard start                     # Start web dashboard
grim dashboard stop                      # Stop dashboard
grim dashboard restart                   # Restart dashboard
grim dashboard status                    # Check dashboard status
grim dashboard config                    # Configure dashboard
grim dashboard init                      # Initialize dashboard
grim dashboard setup                     # Run setup wizard
grim dashboard logs                      # View dashboard logs

# API Gateway
grim gateway start                       # Start API gateway
grim gateway stop                        # Stop gateway
grim gateway status                      # Gateway status
grim gateway config                      # Configure gateway
```

### ☁️ Cloud & Distributed Systems

```bash
# Cloud Platform Integration
grim cloud init                          # Initialize cloud platform
grim cloud aws                           # Deploy to AWS
grim cloud azure                         # Deploy to Azure
grim cloud gcp                           # Deploy to Google Cloud
grim cloud serverless                    # Deploy serverless functions
grim cloud comprehensive                 # Full cloud deployment

# Distributed Architecture
grim distributed init                    # Initialize distributed system
grim distributed deploy                  # Deploy microservices
grim distributed scale                   # Scale services
grim distributed balance                 # Configure load balancing
grim distributed monitor                 # Monitor distributed system

# Load Balancing
grim load-balancer start                 # Start load balancer
grim load-balancer stop                  # Stop load balancer
grim load-balancer status                # Check balancer status
grim load-balancer add-server            # Add backend server
grim load-balancer remove-server         # Remove backend server

# File Transfer (Multi-Protocol)
grim transfer upload                     # Upload files to destination
grim transfer download                   # Download files from source
grim transfer resume                     # Resume interrupted transfer
grim transfer verify                     # Verify transfer integrity
```

### 🧪 Testing & Quality Assurance

```bash
# Testing Framework
grim testing run                         # Run all tests
grim testing benchmark                   # Run benchmarks
grim testing ci                          # CI/CD test suite
grim testing report                      # Generate test report

# Quality Assurance
grim qa code-review                      # Automated code review
grim qa static-analysis                  # Static code analysis
grim qa security-scan                    # Security scanning
grim qa performance-test                 # Performance testing
grim qa integration-test                 # Integration testing
grim qa report                           # Generate QA report

# User Acceptance Testing
grim user-acceptance run                 # Run acceptance tests
grim user-acceptance generate            # Generate test scenarios
grim user-acceptance validate            # Validate user workflows
grim user-acceptance report              # Generate UAT report
```

### 🔧 System Maintenance & Operations

```bash
# Central Orchestrator (Scythe)
grim scythe harvest                      # Orchestrate all operations
grim scythe analyze                      # Analyze system state
grim scythe report                       # Generate master report
grim scythe monitor                      # Monitor all operations
grim scythe status                       # Show orchestrator status
grim scythe backup                       # Orchestrated backup operations

# Logging System
grim log init                            # Initialize logging system
grim log setup                           # Setup logger configuration
grim log event                           # Log structured event
grim log metric                          # Log performance metric
grim log rotate                          # Rotate log files
grim log cleanup                         # Clean up old log files
grim log status                          # Show logging system status
grim log tail                            # Tail log file

# Configuration Management
grim config load                         # Load configuration
grim config save                         # Save configuration
grim config get                          # Get configuration value
grim config set                          # Set configuration value
grim config validate                     # Validate configuration
```

## 🟨 JavaScript/Node.js-Specific Integration

### Express.js Integration

```javascript
const express = require('express');
const GrimReaper = require('grim-reaper');

const app = express();
const grim = new GrimReaper();

// Middleware for automatic backup
app.use(async (req, res, next) => {
  // Auto-backup critical operations
  if (req.method === 'POST' && req.path.includes('/data')) {
    await grim.backup('./user_data', { 
      background: true,
      compression: 'lz4' // Fast compression for real-time operations
    });
  }
  next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    const health = await grim.healthCheck();
    res.json({
      status: health.status,
      details: health.details,
      timestamp: health.timestamp
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Backup endpoint
app.post('/backup', async (req, res) => {
  try {
    const { path, options } = req.body;
    const result = await grim.backup(path, options);
    
    res.json({
      success: true,
      backupId: result.backupId,
      size: result.compressedSize,
      ratio: result.compressionRatio
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start monitoring endpoint
app.post('/monitor', async (req, res) => {
  try {
    const { path, config } = req.body;
    await grim.monitor(path, config);
    res.json({ status: 'monitoring_started', path });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000, () => {
  console.log('🗡️ Express server with Grim Reaper running on port 3000');
});
```

### Koa.js Integration

```javascript
const Koa = require('koa');
const Router = require('@koa/router');
const GrimReaper = require('grim-reaper');

const app = new Koa();
const router = new Router();
const grim = new GrimReaper({
  backupPath: '/opt/backups',
  compression: 'zstd',
  encryption: true
});

// Error handling middleware
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (err) {
    // Log error and create emergency backup
    console.error('Error occurred:', err);
    await grim.emergency.backup('./critical_data');
    
    ctx.status = err.status || 500;
    ctx.body = { error: err.message };
  }
});

// Backup middleware
router.post('/api/backup', async (ctx) => {
  const { path, options = {} } = ctx.request.body;
  
  const backupOptions = {
    ...options,
    exclude: ['node_modules/', '.git/', 'logs/'],
    nodeSpecific: {
      includePackageJson: true,
      analyzeDependencies: true,
      optimizeForNode: true
    }
  };
  
  const result = await grim.backup(path, backupOptions);
  
  ctx.body = {
    success: true,
    backup: {
      id: result.backupId,
      originalSize: result.originalSize,
      compressedSize: result.compressedSize,
      ratio: result.compressionRatio,
      nodeModulesHandling: result.nodeModulesOptimization
    }
  };
});

// Real-time monitoring
router.post('/api/monitor/start', async (ctx) => {
  const { path, config } = ctx.request.body;
  
  const monitorConfig = {
    ...config,
    nodeSpecific: {
      watchPackageJson: true,
      trackNodeProcesses: true,
      monitorMemoryLeaks: true,
      alertOnCrashes: true
    }
  };
  
  await grim.monitor(path, monitorConfig);
  ctx.body = { status: 'monitoring_active', path };
});

app.use(router.routes());
app.listen(3000);
```

### Next.js Integration

```javascript
// pages/api/grim/[...params].js
import GrimReaper from 'grim-reaper';

const grim = new GrimReaper();

export default async function handler(req, res) {
  const { params } = req.query;
  const [action, ...args] = params;

  try {
    switch (action) {
      case 'backup':
        const backupResult = await grim.backup(req.body.path, {
          nextjs: {
            includeStaticFiles: true,
            optimizeBuild: true,
            excludePaths: ['.next/', 'node_modules/']
          }
        });
        res.status(200).json(backupResult);
        break;

      case 'health':
        const health = await grim.healthCheck({
          checkNextJsConfig: true,
          validateBuildOutput: true,
          checkStaticAssets: true
        });
        res.status(200).json(health);
        break;

      case 'monitor':
        await grim.monitor('./pages', {
          watchPatterns: ['*.js', '*.jsx', '*.ts', '*.tsx'],
          nextjsSpecific: {
            watchApiRoutes: true,
            monitorBuildProcess: true,
            trackPerformance: true
          }
        });
        res.status(200).json({ status: 'monitoring_started' });
        break;

      default:
        res.status(404).json({ error: 'Action not found' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

// pages/_app.js - Auto-backup on build
import { useEffect } from 'react';
import GrimReaper from 'grim-reaper';

function MyApp({ Component, pageProps }) {
  useEffect(() => {
    // Auto-backup during development
    if (process.env.NODE_ENV === 'development') {
      const grim = new GrimReaper();
      
      // Backup on page changes
      const handleRouteChange = async () => {
        await grim.backup('./pages', { 
          background: true,
          nextjs: { devMode: true }
        });
      };
      
      router.events.on('routeChangeComplete', handleRouteChange);
      return () => router.events.off('routeChangeComplete', handleRouteChange);
    }
  }, []);

  return <Component {...pageProps} />;
}

export default MyApp;
```

### React Integration

```javascript
import React, { useState, useEffect } from 'react';
import GrimReaper from 'grim-reaper';

// Custom hook for Grim Reaper integration
function useGrimReaper(config = {}) {
  const [grim] = useState(() => new GrimReaper(config));
  const [health, setHealth] = useState(null);
  const [isMonitoring, setIsMonitoring] = useState(false);

  useEffect(() => {
    // Initialize and check health
    const checkHealth = async () => {
      const healthStatus = await grim.healthCheck();
      setHealth(healthStatus);
    };

    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Check every 30 seconds

    return () => clearInterval(interval);
  }, [grim]);

  const backup = async (path, options = {}) => {
    return await grim.backup(path, {
      ...options,
      react: {
        includeBuildFiles: true,
        excludeDevFiles: process.env.NODE_ENV === 'production',
        optimizeAssets: true
      }
    });
  };

  const startMonitoring = async (path, config = {}) => {
    await grim.monitor(path, {
      ...config,
      react: {
        watchComponents: true,
        trackStateChanges: true,
        monitorPerformance: true
      }
    });
    setIsMonitoring(true);
  };

  const stopMonitoring = async () => {
    await grim.stopMonitoring();
    setIsMonitoring(false);
  };

  return {
    grim,
    health,
    isMonitoring,
    backup,
    startMonitoring,
    stopMonitoring
  };
}

// Component with Grim Reaper integration
function DataProtectionDashboard() {
  const { health, isMonitoring, backup, startMonitoring, stopMonitoring } = useGrimReaper();
  const [backupStatus, setBackupStatus] = useState(null);

  const handleBackup = async () => {
    try {
      setBackupStatus('backing_up');
      const result = await backup('./src', {
        compression: 'zstd',
        includeNodeModules: false
      });
      
      setBackupStatus('completed');
      console.log('Backup completed:', result);
    } catch (error) {
      setBackupStatus('error');
      console.error('Backup failed:', error);
    }
  };

  return (
    <div className="grim-dashboard">
      <h2>🗡️ Data Protection Dashboard</h2>
      
      {/* Health Status */}
      <div className="health-section">
        <h3>System Health</h3>
        {health && (
          <div className={`health-status ${health.status}`}>
            <span>Status: {health.status}</span>
            <span>Memory: {health.memoryUsage}%</span>
            <span>Disk: {health.diskUsage}%</span>
          </div>
        )}
      </div>

      {/* Backup Controls */}
      <div className="backup-section">
        <h3>Backup Operations</h3>
        <button 
          onClick={handleBackup}
          disabled={backupStatus === 'backing_up'}
        >
          {backupStatus === 'backing_up' ? 'Backing up...' : 'Create Backup'}
        </button>
        {backupStatus === 'completed' && (
          <div className="success">✅ Backup completed successfully</div>
        )}
      </div>

      {/* Monitoring Controls */}
      <div className="monitoring-section">
        <h3>Real-time Monitoring</h3>
        <button 
          onClick={isMonitoring ? stopMonitoring : () => startMonitoring('./src')}
        >
          {isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'}
        </button>
        <div className={`monitor-status ${isMonitoring ? 'active' : 'inactive'}`}>
          {isMonitoring ? '🟢 Monitoring Active' : '🔴 Monitoring Inactive'}
        </div>
      </div>
    </div>
  );
}

export default DataProtectionDashboard;
```

### Electron Integration

```javascript
// main.js (Main Process)
const { app, BrowserWindow, ipcMain } = require('electron');
const GrimReaper = require('grim-reaper');

const grim = new GrimReaper({
  backupPath: app.getPath('userData') + '/backups',
  encryption: true
});

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('index.html');

  // Auto-backup on app close
  mainWindow.on('close', async (event) => {
    event.preventDefault();
    
    try {
      await grim.backup(app.getPath('userData'), {
        electron: {
          includeUserData: true,
          backupPreferences: true,
          optimizeForElectron: true
        }
      });
      
      mainWindow.destroy();
    } catch (error) {
      console.error('Backup failed on close:', error);
      mainWindow.destroy(); // Close anyway
    }
  });
}

// IPC handlers for renderer process
ipcMain.handle('grim-backup', async (event, path, options) => {
  return await grim.backup(path, options);
});

ipcMain.handle('grim-health', async () => {
  return await grim.healthCheck();
});

ipcMain.handle('grim-monitor', async (event, path, config) => {
  return await grim.monitor(path, config);
});

app.whenReady().then(createWindow);

// renderer.js (Renderer Process)
const { ipcRenderer } = require('electron');

class ElectronGrimInterface {
  async backup(path, options = {}) {
    return await ipcRenderer.invoke('grim-backup', path, options);
  }

  async healthCheck() {
    return await ipcRenderer.invoke('grim-health');
  }

  async startMonitoring(path, config = {}) {
    return await ipcRenderer.invoke('grim-monitor', path, config);
  }
}

const grimInterface = new ElectronGrimInterface();

// Auto-backup timer
setInterval(async () => {
  try {
    await grimInterface.backup('./user_documents', {
      background: true,
      compression: 'lz4' // Fast compression for frequent backups
    });
  } catch (error) {
    console.error('Auto-backup failed:', error);
  }
}, 300000); // Every 5 minutes
```

### Node.js CLI Integration

```javascript
#!/usr/bin/env node

const { Command } = require('commander');
const GrimReaper = require('grim-reaper');
const chalk = require('chalk');
const ora = require('ora');

const program = new Command();
const grim = new GrimReaper();

program
  .name('my-cli')
  .description('CLI with Grim Reaper integration')
  .version('1.0.0');

program
  .command('backup <path>')
  .description('Backup a directory with Grim Reaper')
  .option('-c, --compression <algorithm>', 'Compression algorithm', 'zstd')
  .option('-e, --encrypt', 'Enable encryption')
  .option('--node-optimize', 'Optimize for Node.js projects')
  .action(async (path, options) => {
    const spinner = ora('Creating backup...').start();
    
    try {
      const backupOptions = {
        compression: options.compression,
        encryption: options.encrypt,
        nodeSpecific: options.nodeOptimize ? {
          excludeNodeModules: true,
          includePackageJson: true,
          optimizeDependencies: true
        } : undefined
      };

      const result = await grim.backup(path, backupOptions);
      
      spinner.succeed(chalk.green('Backup completed successfully!'));
      
      console.log(chalk.blue('Backup Details:'));
      console.log(`  ID: ${result.backupId}`);
      console.log(`  Original Size: ${(result.originalSize / 1024 / 1024).toFixed(2)} MB`);
      console.log(`  Compressed Size: ${(result.compressedSize / 1024 / 1024).toFixed(2)} MB`);
      console.log(`  Compression Ratio: ${result.compressionRatio.toFixed(2)}x`);
      console.log(`  Files: ${result.filesCount}`);
      
    } catch (error) {
      spinner.fail(chalk.red('Backup failed!'));
      console.error(chalk.red(error.message));
      process.exit(1);
    }
  });

program
  .command('monitor <path>')
  .description('Start monitoring a directory')
  .option('--node-watch', 'Watch Node.js specific files')
  .action(async (path, options) => {
    const spinner = ora('Starting monitoring...').start();
    
    try {
      const monitorConfig = options.nodeWatch ? {
        watchPatterns: ['*.js', '*.json', '*.ts'],
        nodeSpecific: {
          watchPackageJson: true,
          trackProcesses: true,
          alertOnErrors: true
        }
      } : {};

      await grim.monitor(path, monitorConfig);
      
      spinner.succeed(chalk.green(`Monitoring started for: ${path}`));
      console.log(chalk.yellow('Press Ctrl+C to stop monitoring...'));
      
      // Keep process alive
      process.on('SIGINT', async () => {
        console.log(chalk.yellow('\nStopping monitoring...'));
        await grim.stopMonitoring();
        console.log(chalk.green('Monitoring stopped.'));
        process.exit(0);
      });
      
    } catch (error) {
      spinner.fail(chalk.red('Failed to start monitoring!'));
      console.error(chalk.red(error.message));
      process.exit(1);
    }
  });

program
  .command('health')
  .description('Check system health')
  .action(async () => {
    const spinner = ora('Checking system health...').start();
    
    try {
      const health = await grim.healthCheck({
        checkNodeVersion: true,
        checkNpmPackages: true,
        checkDiskSpace: true,
        checkMemory: true
      });
      
      spinner.stop();
      
      const statusColor = health.status === 'healthy' ? 'green' : 
                         health.status === 'warning' ? 'yellow' : 'red';
      
      console.log(chalk[statusColor](`🗡️ System Status: ${health.status.toUpperCase()}`));
      console.log(chalk.blue('Health Details:'));
      console.log(`  Node.js Version: ${health.nodeVersion || 'N/A'}`);
      console.log(`  Memory Usage: ${health.memoryUsage}%`);
      console.log(`  Disk Usage: ${health.diskUsage}%`);
      console.log(`  Last Backup: ${health.lastBackup || 'Never'}`);
      
      if (health.issues && health.issues.length > 0) {
        console.log(chalk.yellow('\n⚠️ Issues Found:'));
        health.issues.forEach(issue => {
          console.log(chalk.yellow(`  • ${issue}`));
        });
      }
      
      if (health.recommendations && health.recommendations.length > 0) {
        console.log(chalk.blue('\n💡 Recommendations:'));
        health.recommendations.forEach(rec => {
          console.log(chalk.blue(`  • ${rec}`));
        });
      }
      
    } catch (error) {
      spinner.fail(chalk.red('Health check failed!'));
      console.error(chalk.red(error.message));
      process.exit(1);
    }
  });

program.parse();
```

### Jest Testing Integration

```javascript
// tests/grim.test.js
const GrimReaper = require('grim-reaper');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

describe('Grim Reaper Integration', () => {
  let grim;
  let tempDir;

  beforeAll(async () => {
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'grim-test-'));
    grim = new GrimReaper({
      backupPath: tempDir,
      encryption: false, // Disable for testing
      testing: true
    });
  });

  afterAll(async () => {
    await fs.rmdir(tempDir, { recursive: true });
  });

  describe('Backup Operations', () => {
    test('should backup a Node.js project', async () => {
      // Create test project structure
      const projectDir = path.join(tempDir, 'test-project');
      await fs.mkdir(projectDir, { recursive: true });
      await fs.writeFile(path.join(projectDir, 'package.json'), JSON.stringify({
        name: 'test-project',
        version: '1.0.0',
        dependencies: { express: '^4.18.0' }
      }));
      await fs.writeFile(path.join(projectDir, 'index.js'), 'console.log("Hello World");');

      const result = await grim.backup(projectDir, {
        nodeSpecific: {
          analyzePackageJson: true,
          excludeNodeModules: true
        }
      });

      expect(result.success).toBe(true);
      expect(result.backupId).toBeDefined();
      expect(result.filesCount).toBeGreaterThan(0);
      expect(result.compressionRatio).toBeGreaterThan(1);
    }, 30000);

    test('should handle backup errors gracefully', async () => {
      await expect(grim.backup('/nonexistent/path')).rejects.toThrow();
    });
  });

  describe('Health Monitoring', () => {
    test('should perform health check', async () => {
      const health = await grim.healthCheck();

      expect(health).toHaveProperty('status');
      expect(['healthy', 'warning', 'critical']).toContain(health.status);
      expect(health).toHaveProperty('timestamp');
      expect(health).toHaveProperty('details');
    });

    test('should include Node.js specific health checks', async () => {
      const health = await grim.healthCheck({
        checkNodeVersion: true,
        checkNpmPackages: true
      });

      expect(health.nodeVersion).toBeDefined();
      expect(health.packageStatus).toBeDefined();
    });
  });

  describe('File Monitoring', () => {
    test('should start and stop monitoring', async () => {
      const monitorDir = path.join(tempDir, 'monitor-test');
      await fs.mkdir(monitorDir, { recursive: true });

      // Start monitoring
      const monitorPromise = grim.monitor(monitorDir, {
        nodeSpecific: {
          watchPatterns: ['*.js', '*.json']
        }
      });

      // Create a file to trigger monitoring
      await fs.writeFile(path.join(monitorDir, 'test.js'), 'console.log("test");');

      // Stop monitoring
      await grim.stopMonitoring();

      expect(monitorPromise).resolves.not.toThrow();
    });
  });
});

// Performance benchmarks
describe('Performance Benchmarks', () => {
  test('backup performance benchmark', async () => {
    const grim = new GrimReaper({ testing: true });
    const testDir = path.join(os.tmpdir(), 'perf-test');
    
    // Create test files
    await fs.mkdir(testDir, { recursive: true });
    for (let i = 0; i < 100; i++) {
      await fs.writeFile(
        path.join(testDir, `file${i}.js`),
        `// Test file ${i}\nconsole.log('File ${i}');\n`.repeat(100)
      );
    }

    const startTime = Date.now();
    const result = await grim.backup(testDir);
    const endTime = Date.now();

    const backupTime = endTime - startTime;

    expect(result.success).toBe(true);
    expect(backupTime).toBeLessThan(10000); // Should complete within 10 seconds
    expect(result.compressionRatio).toBeGreaterThan(2); // Should achieve good compression

    // Cleanup
    await fs.rmdir(testDir, { recursive: true });
  }, 15000);
});
```

### JavaScript Code Examples

```javascript
const GrimReaper = require('grim-reaper');
const path = require('path');
const fs = require('fs').promises;

// Initialize with custom configuration
const grim = new GrimReaper({
  backupPath: '/opt/backups',
  compressionAlgorithm: 'zstd',
  encryptionEnabled: true,
  aiAnalysis: true,
  maxConcurrentOperations: 4
});

// Advanced backup with JavaScript-specific options
async function backupJavaScriptProject(projectPath) {
  try {
    const result = await grim.backup(projectPath, {
      excludePatterns: [
        'node_modules/', '.git/', '.svn/', '.hg/',
        'dist/', 'build/', '.next/', '.nuxt/',
        'coverage/', '.nyc_output/', '.jest/',
        '*.log', 'logs/', 'tmp/', 'temp/',
        '.DS_Store', 'Thumbs.db'
      ],
      nodeSpecific: {
        analyzePackageJson: true,       // Analyze package.json dependencies
        includeLockFiles: true,         // Include package-lock.json/yarn.lock
        optimizeNodeModules: true,      // Special handling for node_modules
        analyzeWebpackConfig: true,     // Analyze webpack configuration
        includeEnvFiles: false,         // Exclude .env files (security)
        checkSyntax: true              // Validate JavaScript syntax
      },
      compression: 'zstd',              // High compression for source code
      encryption: true
    });

    console.log('✅ JavaScript project backup completed:');
    console.log(`   ID: ${result.backupId}`);
    console.log(`   Original size: ${(result.originalSizeMB).toFixed(1)} MB`);
    console.log(`   Compressed size: ${(result.compressedSizeMB).toFixed(1)} MB`);
    console.log(`   Compression ratio: ${result.compressionRatio.toFixed(2)}x`);
    console.log(`   Files backed up: ${result.filesCount}`);
    console.log(`   Dependencies analyzed: ${result.dependencyCount || 0}`);

    return result;
  } catch (error) {
    console.error('❌ Backup failed:', error.message);
    throw error;
  }
}

// Monitor JavaScript application with specialized tracking
async function monitorJavaScriptApp(appPath) {
  try {
    const monitorConfig = {
      watchPatterns: ['*.js', '*.jsx', '*.ts', '*.tsx', '*.json', '*.mjs'],
      nodeSpecific: {
        trackNodeProcesses: true,       // Monitor Node.js processes
        trackMemoryLeaks: true,         // Detect memory leaks
        trackAsyncOperations: true,     // Monitor async operations
        trackEventLoopLag: true,        // Monitor event loop performance
        alertOnCrashes: true,           // Alert on application crashes
        logPerformanceMetrics: true,    // Log performance data
        watchPackageJson: true,         // Watch for dependency changes
        monitorBuildProcess: true       // Monitor build/compilation
      },
      alertThresholds: {
        memoryUsage: 85,               // Alert at 85% memory usage
        eventLoopLag: 100,             // Alert on 100ms+ event loop lag
        errorRate: 5                   // Alert on 5+ errors per minute
      }
    };

    await grim.monitor(appPath, monitorConfig);
    console.log(`🔍 Monitoring started for JavaScript app: ${appPath}`);

    // Set up event listeners for monitoring events
    grim.on('fileChange', (event) => {
      console.log(`📝 File changed: ${event.path}`);
    });

    grim.on('processAlert', (alert) => {
      console.log(`⚠️  Process alert: ${alert.message}`);
    });

    grim.on('performanceIssue', (issue) => {
      console.log(`🐌 Performance issue: ${issue.description}`);
    });

  } catch (error) {
    console.error('❌ Monitoring failed:', error.message);
    throw error;
  }
}

// Compress with JavaScript syntax validation and optimization
async function compressWithOptimization(sourcePath, targetPath) {
  try {
    const result = await grim.compress(sourcePath, targetPath, {
      algorithm: 'zstd',
      level: 9,                        // Maximum compression
      jsOptimizations: {
        validateSyntax: true,          // Check JavaScript syntax
        minify: false,                 // Don't minify (preserve readability)
        removeComments: false,         // Keep comments for documentation
        optimizeWhitespace: true,      // Optimize whitespace
        analyzeDependencies: true,     // Analyze import/require statements
        detectDeadCode: true          // Identify potentially unused code
      },
      preserveStructure: true          // Maintain file/folder structure
    });

    if (result.syntaxErrors && result.syntaxErrors.length > 0) {
      console.log(`⚠️  Syntax errors found in ${result.syntaxErrors.length} files:`);
      result.syntaxErrors.forEach(error => {
        console.log(`   ${error.file}:${error.line} - ${error.message}`);
      });
    }

    if (result.deadCodeDetected && result.deadCodeDetected.length > 0) {
      console.log(`🗑️  Potential dead code detected in ${result.deadCodeDetected.length} files`);
    }

    console.log('✅ JavaScript files compressed and optimized successfully');
    console.log(`   Compression ratio: ${result.compressionRatio.toFixed(2)}x`);
    console.log(`   Space saved: ${(result.spaceSavedMB).toFixed(1)} MB`);

    return result;
  } catch (error) {
    console.error('❌ Compression failed:', error.message);
    throw error;
  }
}

// Health check with JavaScript-specific diagnostics
async function javascriptHealthCheck() {
  try {
    const health = await grim.healthCheck({
      checkNodeVersion: true,
      checkNpmRegistry: true,
      checkPackageVulnerabilities: true,
      checkDiskSpace: true,
      checkMemoryUsage: true,
      validateProjectStructure: true,
      checkBuildTools: true
    });

    console.log('🟨 JavaScript Environment Health Check:');
    console.log(`   Overall Status: ${health.overallStatus}`);
    console.log(`   Node.js Version: ${health.nodeVersion}`);
    console.log(`   NPM Version: ${health.npmVersion}`);
    console.log(`   Package Vulnerabilities: ${health.vulnerabilityCount || 0}`);
    console.log(`   Memory Usage: ${health.memoryUsage}%`);
    console.log(`   Disk Space: ${health.diskFreeGB.toFixed(1)} GB free`);
    console.log(`   Project Structure: ${health.projectStructureValid ? 'Valid' : 'Issues detected'}`);

    if (health.vulnerabilities && health.vulnerabilities.length > 0) {
      console.log('\n🔒 Security Vulnerabilities:');
      health.vulnerabilities.slice(0, 5).forEach(vuln => {
        console.log(`   • ${vuln.package}: ${vuln.severity} - ${vuln.title}`);
      });
      if (health.vulnerabilities.length > 5) {
        console.log(`   ... and ${health.vulnerabilities.length - 5} more`);
      }
    }

    if (health.recommendations && health.recommendations.length > 0) {
      console.log('\n💡 Recommendations:');
      health.recommendations.forEach(rec => {
        console.log(`   • ${rec}`);
      });
    }

    return health;
  } catch (error) {
    console.error('❌ Health check failed:', error.message);
    throw error;
  }
}

// AI-powered project analysis
async function analyzeProjectWithAI(projectPath) {
  try {
    const analysis = await grim.aiAnalyze(projectPath, {
      analyzeCodeQuality: true,
      detectPatterns: true,
      suggestOptimizations: true,
      assessSecurity: true,
      predictMaintenanceNeeds: true
    });

    console.log('🤖 AI Project Analysis:');
    console.log(`   Code Quality Score: ${analysis.qualityScore}/100`);
    console.log(`   Security Score: ${analysis.securityScore}/100`);
    console.log(`   Maintainability Score: ${analysis.maintainabilityScore}/100`);
    console.log(`   Backup Priority: ${analysis.backupPriority}`);
    console.log(`   Technical Debt: ${analysis.technicalDebtLevel}`);

    if (analysis.patterns && analysis.patterns.length > 0) {
      console.log('\n🔍 Detected Patterns:');
      analysis.patterns.forEach(pattern => {
        console.log(`   • ${pattern.type}: ${pattern.description}`);
      });
    }

    if (analysis.optimizations && analysis.optimizations.length > 0) {
      console.log('\n⚡ Optimization Suggestions:');
      analysis.optimizations.forEach(opt => {
        console.log(`   • ${opt.category}: ${opt.suggestion}`);
      });
    }

    return analysis;
  } catch (error) {
    console.error('❌ AI analysis failed:', error.message);
    throw error;
  }
}

// Main example demonstrating JavaScript-specific features
async function main() {
  try {
    const projectPath = './my-javascript-project';

    // Backup the JavaScript project
    console.log('🗡️ Starting JavaScript project backup...');
    const backupResult = await backupJavaScriptProject(projectPath);

    // Start monitoring
    console.log('\n🔍 Starting project monitoring...');
    await monitorJavaScriptApp(projectPath);

    // Compress source code with optimizations
    console.log('\n📦 Compressing source code...');
    await compressWithOptimization(
      path.join(projectPath, 'src'),
      `/opt/backups/${backupResult.backupId}_src.zst`
    );

    // Check system health
    console.log('\n🏥 Checking system health...');
    const health = await javascriptHealthCheck();

    // AI-powered analysis
    if (health.overallStatus === 'healthy') {
      console.log('\n🤖 Running AI analysis...');
      const analysis = await analyzeProjectWithAI(projectPath);
      
      if (analysis.qualityScore < 70) {
        console.log('\n⚠️  Consider addressing code quality issues before next backup');
      }
    }

    console.log('\n✅ All operations completed successfully!');

  } catch (error) {
    console.error('\n❌ Operation failed:', error.message);
    process.exit(1);
  }
}

// Error handling for unhandled promises
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Emergency backup on critical errors
  grim.emergency.backup('./critical_data').catch(console.error);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  try {
    await grim.stopMonitoring();
    await grim.emergency.backup('./important_data');
    console.log('✅ Graceful shutdown completed');
  } catch (error) {
    console.error('❌ Shutdown error:', error.message);
  }
  process.exit(0);
});

// Export for use as module
module.exports = {
  GrimReaper,
  backupJavaScriptProject,
  monitorJavaScriptApp,
  compressWithOptimization,
  javascriptHealthCheck,
  analyzeProjectWithAI
};

// Run main function if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}
```

## 🔗 Links & Resources

- **Website**: [grim.so](https://grim.so)
- **GitHub**: [github.com/cyber-boost/grim](https://github.com/cyber-boost/grim)
- **Download**: [get.grim.so](https://get.grim.so)
- **NPM**: [npmjs.com/package/grim-reaper](https://www.npmjs.com/package/grim-reaper)
- **Documentation**: [grim.so/docs](https://grim.so/docs)

## 📄 License

By using this software you agree to the official license available at https://grim.so/license

---

<div align="center">
<strong>🗡️ GRIM REAPER</strong><br>
<i>"When data death comes knocking, resurrection is just a command away"</i>
</div>