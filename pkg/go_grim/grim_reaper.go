// Package grim provides real core integration with sh_grim, py_grim, and go_grim
// No mock files - directly calls actual core modules and binaries
//
// Copyright (c) 2025 Bernie Gengel and CyberBoost LLC
// Licensed under the MIT License
// See LICENSE file for full terms
package grim

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// GrimReaper provides integration with Grim Reaper core components
type GrimReaper struct {
	GrimRoot string
	APIBase  string
}

// BackupOptions represents backup configuration
type BackupOptions struct {
	Name        string
	Compress    string
	Incremental bool
}

// CompressionOptions represents compression configuration
type CompressionOptions struct {
	Algorithm string
	Level     int
	Output    string
}

// MonitoringOptions represents monitoring configuration
type MonitoringOptions struct {
	Interval int
	Events   string
}

// ScanOptions represents scanning configuration
type ScanOptions struct {
	Recursive bool
	Types     string
	Output    string
}

// SecurityScanOptions represents security scan configuration
type SecurityScanOptions struct {
	Deep   bool
	Report string
}

// NewGrimReaper creates a new GrimReaper instance with portable path discovery
func NewGrimReaper(grimRoot ...string) (*GrimReaper, error) {
	var root string
	var err error

	if len(grimRoot) > 0 && grimRoot[0] != "" {
		root = grimRoot[0]
	} else {
		root, err = findGrimRoot()
		if err != nil {
			return nil, err
		}
	}

	return &GrimReaper{
		GrimRoot: root,
		APIBase:  "http://localhost:8000",
	}, nil
}

// findGrimRoot searches for Grim Reaper installation directory
func findGrimRoot() (string, error) {
	// Check environment variable first
	if envPath := os.Getenv("GRIM_ROOT"); envPath != "" {
		if isGrimInstallation(envPath) {
			return envPath, nil
		}
	}

	// Search up directory tree
	currentDir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for i := 0; i < 10; i++ {
		if isGrimInstallation(currentDir) {
			return currentDir, nil
		}

		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			break
		}
		currentDir = parentDir
	}

	// Try common installation paths
	possiblePaths := []string{
		filepath.Join(os.Getenv("HOME"), "reaper"),
		filepath.Join(os.Getenv("HOME"), ".reaper"),
		"/root/reaper",
		"/root/.reaper",
		"/usr/local/reaper",
		"/usr/local/share/reaper",
		"/usr/share/reaper",
		"/opt/reaper",
		"/usr/local/lib/grim-reaper",
		"/usr/lib/grim-reaper",
	}

	for _, path := range possiblePaths {
		if isGrimInstallation(path) {
			return path, nil
		}
	}

	// Auto-download if not in CI/build environment
	if os.Getenv("CI") == "" && os.Getenv("GO_ENV") != "build" {
		fmt.Println("🔍 Grim Reaper not found locally")
		fmt.Println("📥 Auto-downloading from get.grim.so...")
		
		downloadPath, err := downloadLatest()
		if err != nil {
			fmt.Printf("❌ Auto-download failed: %v\n", err)
			fmt.Println("💡 Please install manually: curl -fsSL https://get.grim.so | sudo bash")
			return "", fmt.Errorf("grim installation not found and auto-download failed: %v", err)
		}
		
		return downloadPath, nil
	}

	return "", fmt.Errorf("grim installation not found")
}

// downloadLatest downloads latest.tar.gz from get.grim.so and extracts with proper graveyard/reaper/ handling
func downloadLatest() (string, error) {
	fmt.Println("📥 Downloading from https://get.grim.so/latest.tar.gz...")
	
	// Determine GRIM_ROOT with permission checks
	grimRoot, err := determineGrimRoot()
	if err != nil {
		return "", err
	}
	
	tempFile := filepath.Join(os.TempDir(), "grim-latest.tar.gz")
	
	// Download latest.tar.gz
	client := &http.Client{Timeout: 60 * time.Second}
	req, err := http.NewRequest("GET", "https://get.grim.so/latest.tar.gz", nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Grim-Reaper-Go/1.0.35")
	
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("download failed with status: %d", resp.StatusCode)
	}
	
	// Create temp file
	out, err := os.Create(tempFile)
	if err != nil {
		return "", err
	}
	defer out.Close()
	
	// Copy data
	size, err := io.Copy(out, resp.Body)
	if err != nil {
		return "", err
	}
	
	fmt.Printf("✅ Download complete (%s)\n", formatBytes(size))
	
	// Create GRIM_ROOT directory
	if err := os.MkdirAll(grimRoot, 0755); err != nil {
		return "", err
	}
	
	// Extract with --strip-components=2 to handle graveyard/reaper/ prefix
	fmt.Println("📦 Extracting with graveyard/reaper/ structure handling...")
	
	file, err := os.Open(tempFile)
	if err != nil {
		return "", err
	}
	defer file.Close()
	
	gzr, err := gzip.NewReader(file)
	if err != nil {
		return "", err
	}
	defer gzr.Close()
	
	tr := tar.NewReader(gzr)
	
	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", err
		}
		
		// Strip 2 components from path (remove graveyard/reaper/)
		pathParts := strings.Split(header.Name, "/")
		if len(pathParts) <= 2 {
			continue // Skip if not enough path components
		}
		
		// Reconstruct path without first 2 components
		newPath := filepath.Join(pathParts[2:]...)
		if newPath == "" {
			continue
		}
		
		target := filepath.Join(grimRoot, newPath)
		
		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0755); err != nil {
				return "", err
			}
		case tar.TypeReg:
			// Ensure directory exists
			if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
				return "", err
			}
			
			// Create file
			f, err := os.OpenFile(target, os.O_CREATE|os.O_RDWR, os.FileMode(header.Mode))
			if err != nil {
				return "", err
			}
			
			if _, err := io.Copy(f, tr); err != nil {
				f.Close()
				return "", err
			}
			f.Close()
		}
	}
	
	// Clean up temp file
	os.Remove(tempFile)
	
	// Setup environment variables
	setupEnvironmentVariables(grimRoot)
	
	// Make scripts executable
	makeScriptsExecutable(grimRoot)
	
	fmt.Printf("✅ Extraction complete to: %s\n", grimRoot)
	return grimRoot, nil
}

// determineGrimRoot determines optimal GRIM_ROOT with permission checking
func determineGrimRoot() (string, error) {
	// Check GRIM_REAPER mode
	if os.Getenv("GRIM_REAPER") == "TRUE" {
		if existing := os.Getenv("GRIM_ROOT"); existing != "" {
			if info, err := os.Stat(existing); err == nil && info.IsDir() {
				return existing, nil
			}
		}
	}
	
	// Try permission hierarchy
	home := os.Getenv("HOME")
	if home == "" {
		home = "/root"
	}
	
	candidates := []string{
		filepath.Join(home, ".grim"),
		"/root/.grim", 
		filepath.Join(".", ".grim"),
	}
	
	for _, path := range candidates {
		dir := filepath.Dir(path)
		if isWritable(dir) {
			return path, nil
		}
	}
	
	return "", fmt.Errorf("no writable directory found. Please chmod +x install.sh or run with proper permissions")
}

// setupEnvironmentVariables sets up environment variables with persistence
func setupEnvironmentVariables(grimRoot string) {
	fmt.Println("🌍 Setting up environment variables...")
	
	// Set for current process
	os.Setenv("GRIM_ROOT", grimRoot)
	os.Setenv("GRIM_LICENSE", "FREE")
	os.Setenv("GRIM_REAPER", "FALSE")
	
	// Read version from manifest.tsk if available
	manifestPath := filepath.Join(grimRoot, "manifest.tsk")
	if data, err := os.ReadFile(manifestPath); err == nil {
		content := string(data)
		if strings.Contains(content, "version") {
			lines := strings.Split(content, "\n")
			for _, line := range lines {
				if strings.Contains(line, "version") && strings.Contains(line, ":") {
					parts := strings.Split(line, ":")
					if len(parts) >= 2 {
						version := strings.Trim(strings.Trim(parts[1], " "), "\"")
						os.Setenv("GRIM_VERSION", version)
						fmt.Printf("📋 Set GRIM_VERSION=%s from manifest\n", version)
						break
					}
				}
			}
		}
	}
	
	fmt.Println("✅ Environment variables configured")
}

// makeScriptsExecutable makes all Grim scripts executable
func makeScriptsExecutable(grimRoot string) {
	fmt.Println("🔧 Making scripts executable...")
	
	scriptPatterns := []string{
		"reaper.sh", "install.sh", "throne/*.sh", "sh_grim/*.sh",
		"scripts/*.sh", "bin/*", ".rip/*", "py_grim/**/*.py", "go_grim/build/*",
	}
	
	for _, pattern := range scriptPatterns {
		fullPattern := filepath.Join(grimRoot, pattern)
		
		if strings.Contains(pattern, "*") {
			// Handle glob patterns
			matches, _ := filepath.Glob(fullPattern)
			for _, match := range matches {
				if info, err := os.Stat(match); err == nil && !info.IsDir() {
					os.Chmod(match, 0755)
				}
			}
		} else {
			// Handle specific files
			if info, err := os.Stat(fullPattern); err == nil && !info.IsDir() {
				os.Chmod(fullPattern, 0755)
			}
		}
	}
	
	fmt.Println("✅ Scripts made executable")
}

// isWritable checks if directory is writable
func isWritable(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	
	if !info.IsDir() {
		return false
	}
	
	// Test write permissions
	testFile := filepath.Join(path, fmt.Sprintf(".grim-test-%d", time.Now().UnixNano()))
	if err := os.WriteFile(testFile, []byte("test"), 0644); err != nil {
		return false
	}
	os.Remove(testFile)
	return true
}

// formatBytes formats bytes for display
func formatBytes(bytes int64) string {
	units := []string{"B", "KB", "MB", "GB"}
	size := float64(bytes)
	unitIndex := 0
	
	for size >= 1024 && unitIndex < len(units)-1 {
		size /= 1024
		unitIndex++
	}
	
	return fmt.Sprintf("%.2f %s", size, units[unitIndex])
}

// isGrimInstallation checks if path contains a valid Grim installation
func isGrimInstallation(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}

	// Check for key Grim files
	keyFiles := []string{
		"throne/grim_throne.sh",
		"sh_grim/backup.sh",
		"py_grim/grim_web/server.py",
		"go_grim/build/grim-compression",
		"reaper.sh",
		"install.sh",
	}

	for _, keyFile := range keyFiles {
		if _, err := os.Stat(filepath.Join(path, keyFile)); err == nil {
			return true
		}
	}

	return false
}

// executeShModule executes sh_grim module with proper error handling
func (g *GrimReaper) executeShModule(module string, args ...string) (string, error) {
	modulePath := filepath.Join(g.GrimRoot, "sh_grim", module+".sh")
	
	if _, err := os.Stat(modulePath); os.IsNotExist(err) {
		return "", fmt.Errorf("module not found: %s", module)
	}

	cmd := exec.Command(modulePath, args...)
	cmd.Dir = g.GrimRoot
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("module %s failed: %v - %s", module, err, string(output))
	}

	return string(output), nil
}

// executeGoBinary executes go_grim binary with proper error handling
func (g *GrimReaper) executeGoBinary(binary string, args ...string) (string, error) {
	binaryPath := filepath.Join(g.GrimRoot, "go_grim", "build", binary)
	
	if _, err := os.Stat(binaryPath); os.IsNotExist(err) {
		return "", fmt.Errorf("go binary not found: %s", binary)
	}

	cmd := exec.Command(binaryPath, args...)
	cmd.Dir = g.GrimRoot
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("go binary %s failed: %v - %s", binary, err, string(output))
	}

	return string(output), nil
}

// callPyAPI calls py_grim FastAPI service
func (g *GrimReaper) callPyAPI(endpoint string) (map[string]interface{}, error) {
	url := g.APIBase + endpoint
	
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("API call failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API call failed with status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read API response: %v", err)
	}

	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse API response: %v", err)
	}

	return result, nil
}

// ============================================================================
// BACKUP OPERATIONS (via sh_grim)
// ============================================================================

// Backup creates backup using sh_grim/backup.sh
func (g *GrimReaper) Backup(source string, opts *BackupOptions) (string, error) {
	args := []string{source}
	
	if opts != nil {
		if opts.Name != "" {
			args = append(args, "--name", opts.Name)
		}
		if opts.Compress != "" {
			args = append(args, "--compress", opts.Compress)
		}
		if opts.Incremental {
			args = append(args, "--incremental")
		}
	}

	return g.executeShModule("backup", args...)
}

// Restore restores from backup using sh_grim/restore.sh
func (g *GrimReaper) Restore(backup, destination string, overwrite bool) (string, error) {
	args := []string{backup, destination}
	
	if overwrite {
		args = append(args, "--overwrite")
	}

	return g.executeShModule("restore", args...)
}

// ListBackups lists available backups
func (g *GrimReaper) ListBackups() (string, error) {
	return g.executeShModule("backup", "--list")
}

// ============================================================================
// COMPRESSION OPERATIONS (via go_grim)
// ============================================================================

// Compress compresses file using go_grim compression engine
func (g *GrimReaper) Compress(filePath string, opts *CompressionOptions) (string, error) {
	args := []string{}
	
	if opts != nil {
		if opts.Algorithm != "" {
			args = append(args, "-a", opts.Algorithm)
		}
		if opts.Level > 0 {
			args = append(args, "-l", fmt.Sprintf("%d", opts.Level))
		}
		if opts.Output != "" {
			args = append(args, "-o", opts.Output)
		}
	}
	
	args = append(args, filePath)

	return g.executeGoBinary("grim-compression", args...)
}

// Decompress decompresses file using go_grim
func (g *GrimReaper) Decompress(filePath, output string) (string, error) {
	args := []string{"-d"}
	
	if output != "" {
		args = append(args, "-o", output)
	}
	args = append(args, filePath)

	return g.executeGoBinary("grim-compression", args...)
}

// BenchmarkCompression gets compression benchmarks
func (g *GrimReaper) BenchmarkCompression(filePath string) (string, error) {
	return g.executeGoBinary("grim-compression", "-benchmark", filePath)
}

// ============================================================================
// MONITORING OPERATIONS (via sh_grim)
// ============================================================================

// StartMonitoring starts monitoring using sh_grim/monitor.sh
func (g *GrimReaper) StartMonitoring(path string, opts *MonitoringOptions) (string, error) {
	args := []string{"start", path}
	
	if opts != nil {
		if opts.Interval > 0 {
			args = append(args, "--interval", fmt.Sprintf("%d", opts.Interval))
		}
		if opts.Events != "" {
			args = append(args, "--events", opts.Events)
		}
	}

	return g.executeShModule("monitor", args...)
}

// StopMonitoring stops monitoring
func (g *GrimReaper) StopMonitoring() (string, error) {
	return g.executeShModule("monitor", "stop")
}

// GetMonitoringStatus gets monitoring status
func (g *GrimReaper) GetMonitoringStatus() (string, error) {
	return g.executeShModule("monitor", "status")
}

// ============================================================================
// SCANNING OPERATIONS (via sh_grim)
// ============================================================================

// Scan scans directory using sh_grim/scan.sh
func (g *GrimReaper) Scan(path string, opts *ScanOptions) (string, error) {
	args := []string{path}
	
	if opts != nil {
		if opts.Recursive {
			args = append(args, "--recursive")
		}
		if opts.Types != "" {
			args = append(args, "--types", opts.Types)
		}
		if opts.Output != "" {
			args = append(args, "--output", opts.Output)
		}
	}

	return g.executeShModule("scan", args...)
}

// SecurityScan performs security scan using sh_grim/security.sh
func (g *GrimReaper) SecurityScan(path string, opts *SecurityScanOptions) (string, error) {
	args := []string{path}
	
	if opts != nil {
		if opts.Deep {
			args = append(args, "--deep")
		}
		if opts.Report != "" {
			args = append(args, "--report", opts.Report)
		}
	}

	return g.executeShModule("security", args...)
}

// ============================================================================
// SYSTEM OPERATIONS (via sh_grim)
// ============================================================================

// HealthCheck performs system health check using sh_grim/health.sh
func (g *GrimReaper) HealthCheck() (string, error) {
	return g.executeShModule("health", "check")
}

// GetStatus gets system status
func (g *GrimReaper) GetStatus() (string, error) {
	return g.executeShModule("health", "status")
}

// Optimize optimizes system using sh_grim/blacksmith.sh
func (g *GrimReaper) Optimize(target string) (string, error) {
	if target == "" {
		target = "all"
	}
	return g.executeShModule("blacksmith", "optimize", target)
}

// Heal performs self-healing using sh_grim/healer.sh
func (g *GrimReaper) Heal() (string, error) {
	return g.executeShModule("healer", "heal")
}

// ============================================================================
// API INTEGRATION (via py_grim FastAPI)
// ============================================================================

// GetAPIStatus gets system status via API
func (g *GrimReaper) GetAPIStatus() (map[string]interface{}, error) {
	return g.callPyAPI("/api/status")
}

// GetBackupInfo gets backup information via API
func (g *GrimReaper) GetBackupInfo() (map[string]interface{}, error) {
	return g.callPyAPI("/api/backups")
}

// GetMonitoringData gets monitoring data via API
func (g *GrimReaper) GetMonitoringData() (map[string]interface{}, error) {
	return g.callPyAPI("/api/monitoring")
}

// ============================================================================
// UTILITY METHODS
// ============================================================================

// ExecuteCommand executes raw grim command via throne script
func (g *GrimReaper) ExecuteCommand(command string, args ...string) (string, error) {
	thronePath := filepath.Join(g.GrimRoot, "throne", "grim_throne.sh")
	
	if _, err := os.Stat(thronePath); os.IsNotExist(err) {
		return "", fmt.Errorf("throne script not found: %s", thronePath)
	}

	cmdArgs := append([]string{command}, args...)
	cmd := exec.Command(thronePath, cmdArgs...)
	cmd.Dir = g.GrimRoot
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("command %s failed: %v - %s", command, err, string(output))
	}

	return string(output), nil
}

// GetVersion gets Grim version and build info
func (g *GrimReaper) GetVersion() (string, error) {
	manifestPath := filepath.Join(g.GrimRoot, "builds", "latest", "manifest.tsk")
	
	if _, err := os.Stat(manifestPath); err == nil {
		content, err := os.ReadFile(manifestPath)
		if err == nil {
			return string(content), nil
		}
	}

	return g.ExecuteCommand("version")
}

// CheckServices checks if Grim services are running
func (g *GrimReaper) CheckServices() map[string]bool {
	services := map[string]bool{
		"api":        false,
		"monitoring": false,
		"admin":      false,
	}

	// Check FastAPI service
	if cmd := exec.Command("pgrep", "-f", "grim_web"); cmd.Run() == nil {
		services["api"] = true
	}

	// Check monitoring service
	if cmd := exec.Command("pgrep", "-f", "monitor.sh"); cmd.Run() == nil {
		services["monitoring"] = true
	}

	// Check admin server
	if cmd := exec.Command("pgrep", "-f", "grim_admin_server.py"); cmd.Run() == nil {
		services["admin"] = true
	}

	return services
}

// SetAPIBase sets the API base URL
func (g *GrimReaper) SetAPIBase(apiBase string) {
	g.APIBase = strings.TrimSuffix(apiBase, "/")
}

// GetGrimRoot returns the Grim root directory
func (g *GrimReaper) GetGrimRoot() string {
	return g.GrimRoot
}

// GetAPIBase returns the API base URL
func (g *GrimReaper) GetAPIBase() string {
	return g.APIBase
}

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

// InstallGrimReaper installs Grim Reaper if not already installed
func InstallGrimReaper() (string, error) {
	// First check if already installed
	if root, err := findGrimRoot(); err == nil {
		return root, nil
	}
	
	// Not installed - download and install it
	downloadPath, err := downloadLatest()
	if err != nil {
		return "", fmt.Errorf("installation not found and auto-download failed: %v", err)
	}
	return downloadPath, nil
}

// NewGrimReaperWithInstall creates a new GrimReaper instance, installing if needed
func NewGrimReaperWithInstall(grimRoot ...string) (*GrimReaper, error) {
	var root string
	var err error

	if len(grimRoot) > 0 && grimRoot[0] != "" {
		root = grimRoot[0]
	} else {
		root, err = findGrimRoot() // This now includes auto-installation
		if err != nil {
			return nil, err
		}
	}

	return &GrimReaper{
		GrimRoot: root,
		APIBase:  "http://localhost:8000",
	}, nil
}

// QuickBackup performs a backup with automatic installation if needed
func QuickBackup(source string) (string, error) {
	grim, err := NewGrimReaperWithInstall()
	if err != nil {
		return "", err
	}
	return grim.Backup(source, nil)
}

// QuickRestore performs a restore with automatic installation if needed
func QuickRestore(backup, destination string) (string, error) {
	grim, err := NewGrimReaperWithInstall()
	if err != nil {
		return "", err
	}
	return grim.Restore(backup, destination, false)
}

// QuickCompress compresses a file with automatic installation if needed
func QuickCompress(filePath string) (string, error) {
	grim, err := NewGrimReaperWithInstall()
	if err != nil {
		return "", err
	}
	return grim.Compress(filePath, nil)
}

// QuickHealthCheck performs a health check with automatic installation if needed
func QuickHealthCheck() (string, error) {
	grim, err := NewGrimReaperWithInstall()
	if err != nil {
		return "", err
	}
	return grim.HealthCheck()
}

// QuickScan performs a scan with automatic installation if needed
func QuickScan(path string) (string, error) {
	grim, err := NewGrimReaperWithInstall()
	if err != nil {
		return "", err
	}
	return grim.Scan(path, nil)
}