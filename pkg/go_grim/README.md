# Grim Reaper 🗡️ Go Package

[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://grim.so/license)
[![Go Reference](https://pkg.go.dev/badge/github.com/cyber-boost/grim.svg)](https://pkg.go.dev/github.com/cyber-boost/grim)
[![Go Report Card](https://goreportcard.com/badge/github.com/cyber-boost/grim)](https://goreportcard.com/report/github.com/cyber-boost/grim)
[![Go Version](https://img.shields.io/badge/go-%3E%3D%201.21-00ADD8.svg)](https://go.dev/)

**When data death comes knocking, Grim ensures resurrection is just a command away.**

Enterprise-grade data protection platform with AI-powered backup decisions, military-grade encryption, multi-algorithm compression, content-based deduplication, real-time monitoring, and automated threat response.

## 🚀 Quick Install

```bash
# Install via Go
go install github.com/cyber-boost/grim/cmd/grim@latest

# Or add to go.mod
require github.com/cyber-boost/grim v1.0.0
```

## 🎯 Quick Start

```go
package main

import (
    "context"
    "log"
    
    "github.com/cyber-boost/grim"
)

func main() {
    // Initialize Grim Reaper
    g, err := grim.New(grim.Config{
        WorkDir: "/opt/reaper",
    })
    if err != nil {
        log.Fatal(err)
    }
    defer g.Close()
    
    // Quick backup
    err = g.Backup(context.Background(), "/important/data")
    if err != nil {
        log.Fatal(err)
    }
    
    // Start monitoring
    events, err := g.Monitor(context.Background(), "/var/log")
    if err != nil {
        log.Fatal(err)
    }
    
    // Health check
    health, err := g.HealthCheck(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    log.Printf("System Status: %s", health.Status)
}
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

## 🔵 Go-Specific Integration

### Advanced Go Examples

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"
    
    "github.com/cyber-boost/grim"
    "github.com/cyber-boost/grim/backup"
    "github.com/cyber-boost/grim/security"
    "github.com/cyber-boost/grim/ai"
)

// High-performance backup with Go-specific optimizations
func backupGoProject(ctx context.Context, projectPath string, g *grim.Client) (*backup.Result, error) {
    config := backup.Config{
        ExcludePatterns: []string{
            "vendor/", ".git/", "*.log",
            "coverage.out", "*.test", "bin/",
            "tmp/", ".vscode/", ".idea/",
        },
        GoSpecific: &backup.GoOptions{
            IncludeGoMod:        true,   // Include go.mod and go.sum
            AnalyzeDependencies: true,   // Analyze Go module dependencies
            CheckGoVersion:      true,   // Validate Go version compatibility
            BuildTests:          false,  // Don't include test binaries
            OptimizeBinaries:    true,   // Optimize compiled binaries
            StripDebugInfo:      false,  // Keep debug info for troubleshooting
        },
        Compression: backup.CompressionZSTD,
        Encryption:  true,
        Deduplication: true,
    }

    result, err := g.Backup(ctx, projectPath, config)
    if err != nil {
        return nil, fmt.Errorf("backup failed: %w", err)
    }

    fmt.Printf("✅ Go project backup completed:\n")
    fmt.Printf("   ID: %s\n", result.BackupID)
    fmt.Printf("   Original size: %s\n", formatBytes(result.OriginalSize))
    fmt.Printf("   Compressed size: %s\n", formatBytes(result.CompressedSize))
    fmt.Printf("   Compression ratio: %.2fx\n", result.CompressionRatio)
    fmt.Printf("   Files backed up: %d\n", result.FilesCount)
    fmt.Printf("   Go modules analyzed: %d\n", result.GoModulesCount)

    return result, nil
}

// Monitor Go application with specialized tracking
func monitorGoApp(ctx context.Context, appPath string, g *grim.Client) error {
    config := grim.MonitorConfig{
        WatchPatterns: []string{"*.go", "go.mod", "go.sum", "*.yaml", "*.json"},
        GoSpecific: &grim.GoMonitorOptions{
            TrackGoroutines:     true,  // Monitor goroutine count and leaks
            TrackMemoryUsage:    true,  // Monitor heap and garbage collection
            TrackCPUUsage:       true,  // Monitor CPU utilization
            TrackBuildProcess:   true,  // Monitor go build/test commands
            AlertOnPanics:       true,  // Alert on application panics
            LogPerformanceMetrics: true, // Log detailed performance data
            MonitorModuleChanges: true, // Watch for go.mod changes
            TrackTestResults:    true,  // Monitor test results
        },
        AlertThresholds: grim.AlertThresholds{
            GoroutineCount: 10000,    // Alert if goroutines > 10k
            MemoryUsage:    80,       // Alert at 80% memory usage
            CPUUsage:       90,       // Alert at 90% CPU usage
            ErrorRate:      5,        // Alert on 5+ errors per minute
        },
    }

    events, err := g.Monitor(ctx, appPath, config)
    if err != nil {
        return fmt.Errorf("monitoring failed: %w", err)
    }

    fmt.Printf("🔍 Monitoring started for Go app: %s\n", appPath)

    // Process monitoring events
    go func() {
        for event := range events {
            switch event.Type {
            case grim.EventFileChange:
                fmt.Printf("📝 File changed: %s\n", event.Path)
            case grim.EventGoroutineLeak:
                fmt.Printf("⚠️  Goroutine leak detected: %d goroutines\n", event.Count)
            case grim.EventMemoryAlert:
                fmt.Printf("🚨 Memory alert: %d%% usage\n", event.MemoryPercent)
            case grim.EventPanic:
                fmt.Printf("💥 Application panic: %s\n", event.Message)
            }
        }
    }()

    return nil
}

// Compress with Go-specific optimizations
func compressWithGoOptimizations(ctx context.Context, sourcePath, targetPath string, g *grim.Client) error {
    config := grim.CompressionConfig{
        Algorithm: grim.CompressionZSTD,
        Level:     9, // Maximum compression
        GoOptimizations: &grim.GoCompressionOptions{
            ValidateSyntax:    true,  // Check Go syntax before compression
            StripComments:     false, // Keep comments for documentation
            OptimizeBinaries:  true,  // Optimize compiled binaries
            AnalyzeImports:    true,  // Analyze import dependencies
            CompressModCache:  true,  // Compress module cache
            PreserveBuildInfo: true,  // Keep build information
        },
        PreserveStructure: true,
    }

    result, err := g.Compress(ctx, sourcePath, targetPath, config)
    if err != nil {
        return fmt.Errorf("compression failed: %w", err)
    }

    if len(result.SyntaxErrors) > 0 {
        fmt.Printf("⚠️  Syntax errors found in %d files:\n", len(result.SyntaxErrors))
        for _, err := range result.SyntaxErrors {
            fmt.Printf("   %s:%d - %s\n", err.File, err.Line, err.Message)
        }
    }

    fmt.Printf("✅ Go files compressed successfully\n")
    fmt.Printf("   Compression ratio: %.2fx\n", result.CompressionRatio)
    fmt.Printf("   Space saved: %s\n", formatBytes(result.SpaceSaved))

    return nil
}

// Health check with Go-specific diagnostics
func goHealthCheck(ctx context.Context, g *grim.Client) (*grim.HealthStatus, error) {
    config := grim.HealthCheckConfig{
        CheckGoVersion:      true,
        CheckGoModules:      true,
        CheckGoPath:         true,
        CheckBuildTools:     true,
        CheckDiskSpace:      true,
        CheckMemoryUsage:    true,
        ValidateGoEnv:       true,
        CheckVendorConsistency: true,
    }

    health, err := g.HealthCheck(ctx, config)
    if err != nil {
        return nil, fmt.Errorf("health check failed: %w", err)
    }

    fmt.Printf("🔵 Go Environment Health Check:\n")
    fmt.Printf("   Overall Status: %s\n", health.OverallStatus)
    fmt.Printf("   Go Version: %s\n", health.GoVersion)
    fmt.Printf("   GOOS/GOARCH: %s/%s\n", health.GOOS, health.GOARCH)
    fmt.Printf("   GOPATH: %s\n", health.GOPATH)
    fmt.Printf("   GOROOT: %s\n", health.GOROOT)
    fmt.Printf("   Memory Usage: %d%%\n", health.MemoryUsage)
    fmt.Printf("   Disk Space: %.1f GB free\n", health.DiskFreeGB)
    fmt.Printf("   Module Issues: %d\n", len(health.ModuleIssues))

    if len(health.ModuleIssues) > 0 {
        fmt.Printf("\n📦 Module Issues:\n")
        for _, issue := range health.ModuleIssues[:min(5, len(health.ModuleIssues))] {
            fmt.Printf("   • %s: %s\n", issue.Module, issue.Description)
        }
    }

    if len(health.Recommendations) > 0 {
        fmt.Printf("\n💡 Recommendations:\n")
        for _, rec := range health.Recommendations {
            fmt.Printf("   • %s\n", rec)
        }
    }

    return health, nil
}

// AI-powered project analysis
func analyzeProjectWithAI(ctx context.Context, projectPath string, g *grim.Client) error {
    config := ai.AnalysisConfig{
        AnalyzeCodeQuality:      true,
        DetectPatterns:          true,
        SuggestOptimizations:    true,
        AssessSecurity:          true,
        PredictMaintenanceNeeds: true,
        GoSpecific: &ai.GoAnalysisOptions{
            AnalyzeGoroutines:    true,
            CheckMemoryLeaks:     true,
            AnalyzePerformance:   true,
            ReviewErrorHandling:  true,
            CheckTestCoverage:    true,
            AnalyzeDependencies:  true,
        },
    }

    analysis, err := g.AIAnalyze(ctx, projectPath, config)
    if err != nil {
        return fmt.Errorf("AI analysis failed: %w", err)
    }

    fmt.Printf("🤖 AI Go Project Analysis:\n")
    fmt.Printf("   Code Quality Score: %d/100\n", analysis.QualityScore)
    fmt.Printf("   Security Score: %d/100\n", analysis.SecurityScore)
    fmt.Printf("   Performance Score: %d/100\n", analysis.PerformanceScore)
    fmt.Printf("   Test Coverage: %.1f%%\n", analysis.TestCoverage)
    fmt.Printf("   Backup Priority: %s\n", analysis.BackupPriority)
    fmt.Printf("   Technical Debt: %s\n", analysis.TechnicalDebtLevel)

    if len(analysis.GoPatterns) > 0 {
        fmt.Printf("\n🔍 Go-Specific Patterns Detected:\n")
        for _, pattern := range analysis.GoPatterns {
            fmt.Printf("   • %s: %s\n", pattern.Type, pattern.Description)
        }
    }

    if len(analysis.Optimizations) > 0 {
        fmt.Printf("\n⚡ Go Optimization Suggestions:\n")
        for _, opt := range analysis.Optimizations {
            fmt.Printf("   • %s: %s\n", opt.Category, opt.Suggestion)
        }
    }

    return nil
}

// Main function demonstrating Go-specific features
func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
    defer cancel()

    // Initialize Grim Reaper with Go-optimized settings
    g, err := grim.New(grim.Config{
        WorkDir:     "/opt/reaper",
        LogLevel:    grim.LogLevelInfo,
        GoOptimized: true,
        Performance: grim.PerformanceConfig{
            Workers:           runtime.NumCPU(),
            CompressionLevel:  9,
            MemoryLimit:      "2GB",
            EnableProfiling:  true,
        },
    })
    if err != nil {
        log.Fatalf("Failed to initialize Grim: %v", err)
    }
    defer g.Close()

    projectPath := "/opt/my-go-project"

    // Backup the Go project
    fmt.Println("🗡️ Starting Go project backup...")
    backupResult, err := backupGoProject(ctx, projectPath, g)
    if err != nil {
        log.Fatalf("Backup failed: %v", err)
    }

    // Start monitoring
    fmt.Println("\n🔍 Starting project monitoring...")
    err = monitorGoApp(ctx, projectPath, g)
    if err != nil {
        log.Fatalf("Monitoring failed: %v", err)
    }

    // Compress source code with optimizations
    fmt.Println("\n📦 Compressing source code...")
    err = compressWithGoOptimizations(ctx, 
        fmt.Sprintf("%s/src", projectPath),
        fmt.Sprintf("/opt/backups/%s_src.zst", backupResult.BackupID),
        g)
    if err != nil {
        log.Fatalf("Compression failed: %v", err)
    }

    // Check system health
    fmt.Println("\n🏥 Checking system health...")
    health, err := goHealthCheck(ctx, g)
    if err != nil {
        log.Fatalf("Health check failed: %v", err)
    }

    // AI-powered analysis
    if health.OverallStatus == "healthy" {
        fmt.Println("\n🤖 Running AI analysis...")
        err = analyzeProjectWithAI(ctx, projectPath, g)
        if err != nil {
            log.Printf("AI analysis failed: %v", err)
        }
    }

    fmt.Println("\n✅ All operations completed successfully!")
}

// Utility functions
func formatBytes(size int64) string {
    const unit = 1024
    if size < unit {
        return fmt.Sprintf("%d B", size)
    }
    
    div, exp := int64(unit), 0
    for n := size / unit; n >= unit; n /= unit {
        div *= unit
        exp++
    }
    
    return fmt.Sprintf("%.1f %cB", float64(size)/float64(div), "KMGTPE"[exp])
}

func min(a, b int) int {
    if a < b {
        return a
    }
    return b
}
```

### Goroutine-Safe Operations

```go
// Concurrent backup operations
func concurrentBackups(ctx context.Context, paths []string, g *grim.Client) error {
    var wg sync.WaitGroup
    results := make(chan *backup.Result, len(paths))
    errors := make(chan error, len(paths))

    for _, path := range paths {
        wg.Add(1)
        go func(p string) {
            defer wg.Done()
            
            result, err := g.Backup(ctx, p, backup.Config{
                Compression: backup.CompressionZSTD,
                Concurrent:  true,
            })
            
            if err != nil {
                errors <- fmt.Errorf("backup %s failed: %w", p, err)
                return
            }
            
            results <- result
        }(path)
    }

    go func() {
        wg.Wait()
        close(results)
        close(errors)
    }()

    // Collect results
    var allResults []*backup.Result
    for result := range results {
        allResults = append(allResults, result)
        fmt.Printf("✅ Backup completed: %s (%.2fx compression)\n", 
            result.BackupID, result.CompressionRatio)
    }

    // Check for errors
    for err := range errors {
        fmt.Printf("❌ Error: %v\n", err)
    }

    fmt.Printf("📊 Total backups completed: %d\n", len(allResults))
    return nil
}
```

### Testing Integration

```go
package main

import (
    "context"
    "testing"
    "time"
    
    "github.com/cyber-boost/grim"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestGrimBackup(t *testing.T) {
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    g, err := grim.New(grim.Config{
        WorkDir: t.TempDir(),
        Testing: true, // Enable testing mode
    })
    require.NoError(t, err)
    defer g.Close()

    // Create test project structure
    projectDir := setupTestProject(t)

    // Test backup functionality
    result, err := g.Backup(ctx, projectDir, backup.Config{
        GoSpecific: &backup.GoOptions{
            IncludeGoMod:        true,
            AnalyzeDependencies: true,
        },
    })

    require.NoError(t, err)
    assert.NotEmpty(t, result.BackupID)
    assert.Greater(t, result.FilesCount, 0)
    assert.Greater(t, result.CompressionRatio, 1.0)
}

func TestGrimHealthCheck(t *testing.T) {
    ctx := context.Background()

    g, err := grim.New(grim.Config{
        WorkDir: t.TempDir(),
        Testing: true,
    })
    require.NoError(t, err)
    defer g.Close()

    health, err := g.HealthCheck(ctx, grim.HealthCheckConfig{
        CheckGoVersion: true,
        CheckGoModules: true,
    })

    require.NoError(t, err)
    assert.Contains(t, []string{"healthy", "warning", "critical"}, health.Status)
    assert.NotEmpty(t, health.GoVersion)
}

func BenchmarkBackupPerformance(b *testing.B) {
    ctx := context.Background()
    g, err := grim.New(grim.Config{
        WorkDir: b.TempDir(),
        Testing: true,
    })
    require.NoError(b, err)
    defer g.Close()

    projectDir := setupLargeTestProject(b)

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, err := g.Backup(ctx, projectDir, backup.Config{
            Compression: backup.CompressionLZ4, // Fast compression for benchmarking
        })
        require.NoError(b, err)
    }
}

func setupTestProject(t *testing.T) string {
    // Implementation for creating test Go project
    // ...
    return "/tmp/test-project"
}

func setupLargeTestProject(b *testing.B) string {
    // Implementation for creating large test project
    // ...
    return "/tmp/large-test-project"
}
```

## 🔗 Links & Resources

- **Website**: [grim.so](https://grim.so)
- **GitHub**: [github.com/cyber-boost/grim](https://github.com/cyber-boost/grim)
- **Download**: [get.grim.so](https://get.grim.so)
- **pkg.go.dev**: [pkg.go.dev/github.com/cyber-boost/grim](https://pkg.go.dev/github.com/cyber-boost/grim)
- **Documentation**: [grim.so/docs](https://grim.so/docs)

## 📄 License

By using this software you agree to the official license available at https://grim.so/license

---

<div align="center">
<strong>🗡️ GRIM REAPER</strong><br>
<i>"When data death comes knocking, resurrection is just a command away"</i>
</div>