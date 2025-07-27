package common

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Config holds configuration for Grim components
type Config struct {
	// General settings
	Verbose     bool   `json:"verbose"`
	LogLevel    string `json:"log_level"`
	LogFile     string `json:"log_file"`
	ConfigFile  string `json:"config_file"`
	
	// Performance settings
	ChunkSize       int           `json:"chunk_size"`
	BufferSize      int           `json:"buffer_size"`
	MaxWorkers      int           `json:"max_workers"`
	Timeout         time.Duration `json:"timeout"`
	
	// Algorithm settings
	Algorithm       string `json:"algorithm"`
	CompressionType string `json:"compression_type"`
	
	// Storage settings
	DataDir         string `json:"data_dir"`
	TempDir         string `json:"temp_dir"`
	CacheDir        string `json:"cache_dir"`
	
	// Network settings
	Host            string `json:"host"`
	Port            int    `json:"port"`
	MaxConnections  int    `json:"max_connections"`
	
	// Security settings
	EnableTLS       bool   `json:"enable_tls"`
	CertFile        string `json:"cert_file"`
	KeyFile         string `json:"key_file"`
	
	// Metrics settings
	EnableMetrics   bool   `json:"enable_metrics"`
	MetricsPort     int    `json:"metrics_port"`
	
	// Database settings
	DatabaseURL     string `json:"database_url"`
	DatabaseType    string `json:"database_type"`
	
	// Backup settings
	BackupEnabled   bool   `json:"backup_enabled"`
	BackupInterval  string `json:"backup_interval"`
	BackupRetention int    `json:"backup_retention"`
}

// DefaultConfig returns a default configuration
func DefaultConfig() *Config {
	return &Config{
		Verbose:         false,
		LogLevel:        "info",
		LogFile:         "",
		ChunkSize:       8192,
		BufferSize:      65536,
		MaxWorkers:      4,
		Timeout:         30 * time.Second,
		Algorithm:       "sha256",
		CompressionType: "gzip",
		DataDir:         "./data",
		TempDir:         "./temp",
		CacheDir:        "./cache",
		Host:            "localhost",
		Port:            8080,
		MaxConnections:  100,
		EnableTLS:       false,
		EnableMetrics:   true,
		MetricsPort:     9090,
		DatabaseType:    "sqlite",
		DatabaseURL:     "./grim.db",
		BackupEnabled:   true,
		BackupInterval:  "24h",
		BackupRetention: 7,
	}
}

// LoadConfig loads configuration from file and environment variables
func LoadConfig(configPath string) (*Config, error) {
	config := DefaultConfig()
	
	// Load from file if specified
	if configPath != "" {
		if err := config.LoadFromFile(configPath); err != nil {
			return nil, fmt.Errorf("failed to load config file: %w", err)
		}
	}
	
	// Override with environment variables
	config.LoadFromEnv()
	
	// Validate configuration
	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}
	
	return config, nil
}

// LoadFromFile loads configuration from JSON file
func (c *Config) LoadFromFile(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	
	return json.Unmarshal(data, c)
}

// SaveToFile saves configuration to JSON file
func (c *Config) SaveToFile(path string) error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	
	return os.WriteFile(path, data, 0644)
}

// LoadFromEnv loads configuration from environment variables
func (c *Config) LoadFromEnv() {
	// General settings
	if val := os.Getenv("GRIM_VERBOSE"); val != "" {
		c.Verbose = parseBool(val)
	}
	if val := os.Getenv("GRIM_LOG_LEVEL"); val != "" {
		c.LogLevel = val
	}
	if val := os.Getenv("GRIM_LOG_FILE"); val != "" {
		c.LogFile = val
	}
	
	// Performance settings
	if val := os.Getenv("GRIM_CHUNK_SIZE"); val != "" {
		if size, err := strconv.Atoi(val); err == nil {
			c.ChunkSize = size
		}
	}
	if val := os.Getenv("GRIM_BUFFER_SIZE"); val != "" {
		if size, err := strconv.Atoi(val); err == nil {
			c.BufferSize = size
		}
	}
	if val := os.Getenv("GRIM_MAX_WORKERS"); val != "" {
		if workers, err := strconv.Atoi(val); err == nil {
			c.MaxWorkers = workers
		}
	}
	if val := os.Getenv("GRIM_TIMEOUT"); val != "" {
		if timeout, err := time.ParseDuration(val); err == nil {
			c.Timeout = timeout
		}
	}
	
	// Algorithm settings
	if val := os.Getenv("GRIM_ALGORITHM"); val != "" {
		c.Algorithm = val
	}
	if val := os.Getenv("GRIM_COMPRESSION_TYPE"); val != "" {
		c.CompressionType = val
	}
	
	// Storage settings
	if val := os.Getenv("GRIM_DATA_DIR"); val != "" {
		c.DataDir = val
	}
	if val := os.Getenv("GRIM_TEMP_DIR"); val != "" {
		c.TempDir = val
	}
	if val := os.Getenv("GRIM_CACHE_DIR"); val != "" {
		c.CacheDir = val
	}
	
	// Network settings
	if val := os.Getenv("GRIM_HOST"); val != "" {
		c.Host = val
	}
	if val := os.Getenv("GRIM_PORT"); val != "" {
		if port, err := strconv.Atoi(val); err == nil {
			c.Port = port
		}
	}
	if val := os.Getenv("GRIM_MAX_CONNECTIONS"); val != "" {
		if max, err := strconv.Atoi(val); err == nil {
			c.MaxConnections = max
		}
	}
	
	// Security settings
	if val := os.Getenv("GRIM_ENABLE_TLS"); val != "" {
		c.EnableTLS = parseBool(val)
	}
	if val := os.Getenv("GRIM_CERT_FILE"); val != "" {
		c.CertFile = val
	}
	if val := os.Getenv("GRIM_KEY_FILE"); val != "" {
		c.KeyFile = val
	}
	
	// Metrics settings
	if val := os.Getenv("GRIM_ENABLE_METRICS"); val != "" {
		c.EnableMetrics = parseBool(val)
	}
	if val := os.Getenv("GRIM_METRICS_PORT"); val != "" {
		if port, err := strconv.Atoi(val); err == nil {
			c.MetricsPort = port
		}
	}
	
	// Database settings
	if val := os.Getenv("GRIM_DATABASE_TYPE"); val != "" {
		c.DatabaseType = val
	}
	if val := os.Getenv("GRIM_DATABASE_URL"); val != "" {
		c.DatabaseURL = val
	}
	
	// Backup settings
	if val := os.Getenv("GRIM_BACKUP_ENABLED"); val != "" {
		c.BackupEnabled = parseBool(val)
	}
	if val := os.Getenv("GRIM_BACKUP_INTERVAL"); val != "" {
		c.BackupInterval = val
	}
	if val := os.Getenv("GRIM_BACKUP_RETENTION"); val != "" {
		if retention, err := strconv.Atoi(val); err == nil {
			c.BackupRetention = retention
		}
	}
}

// Validate validates the configuration
func (c *Config) Validate() error {
	// Validate chunk size
	if c.ChunkSize <= 0 {
		return fmt.Errorf("chunk size must be positive")
	}
	if c.ChunkSize > 1024*1024 {
		return fmt.Errorf("chunk size too large (max 1MB)")
	}
	
	// Validate buffer size
	if c.BufferSize <= 0 {
		return fmt.Errorf("buffer size must be positive")
	}
	
	// Validate max workers
	if c.MaxWorkers <= 0 {
		return fmt.Errorf("max workers must be positive")
	}
	if c.MaxWorkers > 1000 {
		return fmt.Errorf("max workers too high (max 1000)")
	}
	
	// Validate algorithm
	validAlgorithms := []string{"sha256", "sha1", "md5", "blake2b"}
	valid := false
	for _, alg := range validAlgorithms {
		if c.Algorithm == alg {
			valid = true
			break
		}
	}
	if !valid {
		return fmt.Errorf("invalid algorithm: %s (valid: %s)", c.Algorithm, strings.Join(validAlgorithms, ", "))
	}
	
	// Validate compression type
	validCompression := []string{"gzip", "lz4", "zstd", "none"}
	valid = false
	for _, comp := range validCompression {
		if c.CompressionType == comp {
			valid = true
			break
		}
	}
	if !valid {
		return fmt.Errorf("invalid compression type: %s (valid: %s)", c.CompressionType, strings.Join(validCompression, ", "))
	}
	
	// Validate port numbers
	if c.Port <= 0 || c.Port > 65535 {
		return fmt.Errorf("invalid port number: %d", c.Port)
	}
	if c.MetricsPort <= 0 || c.MetricsPort > 65535 {
		return fmt.Errorf("invalid metrics port number: %d", c.MetricsPort)
	}
	
	// Validate TLS settings
	if c.EnableTLS {
		if c.CertFile == "" {
			return fmt.Errorf("cert file required when TLS is enabled")
		}
		if c.KeyFile == "" {
			return fmt.Errorf("key file required when TLS is enabled")
		}
	}
	
	// Validate backup settings
	if c.BackupRetention <= 0 {
		return fmt.Errorf("backup retention must be positive")
	}
	
	return nil
}

// EnsureDirectories creates necessary directories
func (c *Config) EnsureDirectories() error {
	dirs := []string{c.DataDir, c.TempDir, c.CacheDir}
	
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}
	
	return nil
}

// GetDatabasePath returns the full database path
func (c *Config) GetDatabasePath() string {
	if c.DatabaseType == "sqlite" {
		return filepath.Join(c.DataDir, c.DatabaseURL)
	}
	return c.DatabaseURL
}

// GetLogPath returns the full log file path
func (c *Config) GetLogPath() string {
	if c.LogFile == "" {
		return ""
	}
	if filepath.IsAbs(c.LogFile) {
		return c.LogFile
	}
	return filepath.Join(c.DataDir, c.LogFile)
}

// parseBool parses a boolean string
func parseBool(s string) bool {
	s = strings.ToLower(strings.TrimSpace(s))
	return s == "true" || s == "1" || s == "yes" || s == "on"
} 