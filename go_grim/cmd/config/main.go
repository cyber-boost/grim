package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	// Default configuration file path
	DefaultConfigFile = "grim.conf"
	
	// Licensing URLs - CRITICAL: These must be the correct URLs
	DefaultLicenseURL     = "https://tusklang.org/license"
	DefaultLicenseAPIURL  = "https://tusklang.org/api/license"
	DefaultUpdateURL      = "https://tusklang.org/update"
	DefaultDownloadURL    = "https://tusklang.org/download"
	
	// Version information
	Version   = "1.0.0"
	BuildTime = "2025-01-27"
)

// Config represents the Grim configuration
type Config struct {
	// Licensing configuration
	LicenseURL     string `json:"license_url"`
	LicenseAPIURL  string `json:"license_api_url"`
	LicenseKey     string `json:"license_key"`
	LicenseEmail   string `json:"license_email"`
	LicenseExpiry  string `json:"license_expiry"`
	
	// Update configuration
	UpdateURL      string `json:"update_url"`
	DownloadURL    string `json:"download_url"`
	AutoUpdate     bool   `json:"auto_update"`
	
	// System configuration
	GrimRoot       string `json:"grim_root"`
	DataDir        string `json:"data_dir"`
	LogDir         string `json:"log_dir"`
	TempDir        string `json:"temp_dir"`
	
	// Feature configuration
	EnableLogging  bool   `json:"enable_logging"`
	LogLevel       string `json:"log_level"`
	MaxLogSize     int    `json:"max_log_size"`
	
	// Network configuration
	ProxyURL       string `json:"proxy_url"`
	Timeout        int    `json:"timeout"`
	Retries        int    `json:"retries"`
	
	// Security configuration
	EnableEncryption bool   `json:"enable_encryption"`
	EncryptionKey    string `json:"encryption_key"`
}

// DefaultConfig returns a default configuration with proper URLs
func DefaultConfig() *Config {
	grimRoot := os.Getenv("GRIM_ROOT")
	if grimRoot == "" {
		grimRoot = "/opt/grim"
	}
	
	return &Config{
		// Licensing URLs - MUST be correct
		LicenseURL:     DefaultLicenseURL,
		LicenseAPIURL:  DefaultLicenseAPIURL,
		LicenseKey:     "",
		LicenseEmail:   "",
		LicenseExpiry:  "",
		
		// Update URLs
		UpdateURL:      DefaultUpdateURL,
		DownloadURL:    DefaultDownloadURL,
		AutoUpdate:     true,
		
		// System paths
		GrimRoot:       grimRoot,
		DataDir:        filepath.Join(grimRoot, "data"),
		LogDir:         filepath.Join(grimRoot, "logs"),
		TempDir:        filepath.Join(grimRoot, "tmp"),
		
		// Feature defaults
		EnableLogging:  true,
		LogLevel:       "INFO",
		MaxLogSize:     100, // MB
		
		// Network defaults
		ProxyURL:       "",
		Timeout:        30, // seconds
		Retries:        3,
		
		// Security defaults
		EnableEncryption: true,
		EncryptionKey:    "",
	}
}

// LoadConfig loads configuration from file
func LoadConfig(path string) (*Config, error) {
	config := DefaultConfig()
	
	if path == "" {
		path = DefaultConfigFile
	}
	
	// Check if file exists
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return config, nil // Return default config if file doesn't exist
	}
	
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}
	
	if err := json.Unmarshal(data, config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}
	
	return config, nil
}

// SaveConfig saves configuration to file
func (c *Config) SaveConfig(path string) error {
	if path == "" {
		path = DefaultConfigFile
	}
	
	// Create directory if it doesn't exist
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}
	
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}
	
	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}
	
	return nil
}

// GetValue gets a configuration value by key
func (c *Config) GetValue(key string) (interface{}, error) {
	switch strings.ToLower(key) {
	case "license_url":
		return c.LicenseURL, nil
	case "license_api_url":
		return c.LicenseAPIURL, nil
	case "license_key":
		return c.LicenseKey, nil
	case "license_email":
		return c.LicenseEmail, nil
	case "license_expiry":
		return c.LicenseExpiry, nil
	case "update_url":
		return c.UpdateURL, nil
	case "download_url":
		return c.DownloadURL, nil
	case "auto_update":
		return c.AutoUpdate, nil
	case "grim_root":
		return c.GrimRoot, nil
	case "data_dir":
		return c.DataDir, nil
	case "log_dir":
		return c.LogDir, nil
	case "temp_dir":
		return c.TempDir, nil
	case "enable_logging":
		return c.EnableLogging, nil
	case "log_level":
		return c.LogLevel, nil
	case "max_log_size":
		return c.MaxLogSize, nil
	case "proxy_url":
		return c.ProxyURL, nil
	case "timeout":
		return c.Timeout, nil
	case "retries":
		return c.Retries, nil
	case "enable_encryption":
		return c.EnableEncryption, nil
	case "encryption_key":
		return c.EncryptionKey, nil
	default:
		return nil, fmt.Errorf("unknown configuration key: %s", key)
	}
}

// SetValue sets a configuration value by key
func (c *Config) SetValue(key string, value interface{}) error {
	switch strings.ToLower(key) {
	case "license_url":
		if v, ok := value.(string); ok {
			c.LicenseURL = v
		} else {
			return fmt.Errorf("license_url must be a string")
		}
	case "license_api_url":
		if v, ok := value.(string); ok {
			c.LicenseAPIURL = v
		} else {
			return fmt.Errorf("license_api_url must be a string")
		}
	case "license_key":
		if v, ok := value.(string); ok {
			c.LicenseKey = v
		} else {
			return fmt.Errorf("license_key must be a string")
		}
	case "license_email":
		if v, ok := value.(string); ok {
			c.LicenseEmail = v
		} else {
			return fmt.Errorf("license_email must be a string")
		}
	case "license_expiry":
		if v, ok := value.(string); ok {
			c.LicenseExpiry = v
		} else {
			return fmt.Errorf("license_expiry must be a string")
		}
	case "update_url":
		if v, ok := value.(string); ok {
			c.UpdateURL = v
		} else {
			return fmt.Errorf("update_url must be a string")
		}
	case "download_url":
		if v, ok := value.(string); ok {
			c.DownloadURL = v
		} else {
			return fmt.Errorf("download_url must be a string")
		}
	case "auto_update":
		if v, ok := value.(bool); ok {
			c.AutoUpdate = v
		} else if v, ok := value.(string); ok {
			c.AutoUpdate = strings.ToLower(v) == "true"
		} else {
			return fmt.Errorf("auto_update must be a boolean")
		}
	case "grim_root":
		if v, ok := value.(string); ok {
			c.GrimRoot = v
		} else {
			return fmt.Errorf("grim_root must be a string")
		}
	case "data_dir":
		if v, ok := value.(string); ok {
			c.DataDir = v
		} else {
			return fmt.Errorf("data_dir must be a string")
		}
	case "log_dir":
		if v, ok := value.(string); ok {
			c.LogDir = v
		} else {
			return fmt.Errorf("log_dir must be a string")
		}
	case "temp_dir":
		if v, ok := value.(string); ok {
			c.TempDir = v
		} else {
			return fmt.Errorf("temp_dir must be a string")
		}
	case "enable_logging":
		if v, ok := value.(bool); ok {
			c.EnableLogging = v
		} else if v, ok := value.(string); ok {
			c.EnableLogging = strings.ToLower(v) == "true"
		} else {
			return fmt.Errorf("enable_logging must be a boolean")
		}
	case "log_level":
		if v, ok := value.(string); ok {
			c.LogLevel = v
		} else {
			return fmt.Errorf("log_level must be a string")
		}
	case "max_log_size":
		if v, ok := value.(float64); ok {
			c.MaxLogSize = int(v)
		} else if v, ok := value.(int); ok {
			c.MaxLogSize = v
		} else {
			return fmt.Errorf("max_log_size must be a number")
		}
	case "proxy_url":
		if v, ok := value.(string); ok {
			c.ProxyURL = v
		} else {
			return fmt.Errorf("proxy_url must be a string")
		}
	case "timeout":
		if v, ok := value.(float64); ok {
			c.Timeout = int(v)
		} else if v, ok := value.(int); ok {
			c.Timeout = v
		} else {
			return fmt.Errorf("timeout must be a number")
		}
	case "retries":
		if v, ok := value.(float64); ok {
			c.Retries = int(v)
		} else if v, ok := value.(int); ok {
			c.Retries = v
		} else {
			return fmt.Errorf("retries must be a number")
		}
	case "enable_encryption":
		if v, ok := value.(bool); ok {
			c.EnableEncryption = v
		} else if v, ok := value.(string); ok {
			c.EnableEncryption = strings.ToLower(v) == "true"
		} else {
			return fmt.Errorf("enable_encryption must be a boolean")
		}
	case "encryption_key":
		if v, ok := value.(string); ok {
			c.EncryptionKey = v
		} else {
			return fmt.Errorf("encryption_key must be a string")
		}
	default:
		return fmt.Errorf("unknown configuration key: %s", key)
	}
	return nil
}

// Validate validates the configuration
func (c *Config) Validate() error {
	// Validate required URLs
	if c.LicenseURL == "" {
		return fmt.Errorf("license_url is required")
	}
	if c.LicenseAPIURL == "" {
		return fmt.Errorf("license_api_url is required")
	}
	if c.UpdateURL == "" {
		return fmt.Errorf("update_url is required")
	}
	if c.DownloadURL == "" {
		return fmt.Errorf("download_url is required")
	}
	
	// Validate paths
	if c.GrimRoot == "" {
		return fmt.Errorf("grim_root is required")
	}
	
	// Validate log level
	validLogLevels := []string{"DEBUG", "INFO", "WARN", "ERROR", "FATAL"}
	found := false
	for _, level := range validLogLevels {
		if strings.ToUpper(c.LogLevel) == level {
			found = true
			break
		}
	}
	if !found {
		return fmt.Errorf("invalid log_level: %s (valid: %s)", c.LogLevel, strings.Join(validLogLevels, ", "))
	}
	
	// Validate numeric values
	if c.MaxLogSize <= 0 {
		return fmt.Errorf("max_log_size must be positive")
	}
	if c.Timeout <= 0 {
		return fmt.Errorf("timeout must be positive")
	}
	if c.Retries < 0 {
		return fmt.Errorf("retries cannot be negative")
	}
	
	return nil
}

// PrintHelp prints help information
func PrintHelp() {
	fmt.Println("Grim Configuration Manager")
	fmt.Printf("Version: %s (Built: %s)\n\n", Version, BuildTime)
	fmt.Println("Usage: grim-config <command> [arguments]")
	fmt.Println("")
	fmt.Println("Commands:")
	fmt.Println("  get <key>           Get configuration value")
	fmt.Println("  set <key> <value>   Set configuration value")
	fmt.Println("  load [file]         Load configuration from file")
	fmt.Println("  save [file]         Save configuration to file")
	fmt.Println("  validate [file]     Validate configuration")
	fmt.Println("  help                Show this help")
	fmt.Println("")
	fmt.Println("Configuration Keys:")
	fmt.Println("  Licensing:")
	fmt.Println("    license_url       License server URL")
	fmt.Println("    license_api_url   License API URL")
	fmt.Println("    license_key       License key")
	fmt.Println("    license_email     License email")
	fmt.Println("    license_expiry    License expiry date")
	fmt.Println("")
	fmt.Println("  Updates:")
	fmt.Println("    update_url        Update server URL")
	fmt.Println("    download_url      Download server URL")
	fmt.Println("    auto_update       Enable auto-updates")
	fmt.Println("")
	fmt.Println("  System:")
	fmt.Println("    grim_root         Grim installation directory")
	fmt.Println("    data_dir          Data directory")
	fmt.Println("    log_dir           Log directory")
	fmt.Println("    temp_dir          Temporary directory")
	fmt.Println("")
	fmt.Println("  Logging:")
	fmt.Println("    enable_logging    Enable logging")
	fmt.Println("    log_level         Log level (DEBUG, INFO, WARN, ERROR, FATAL)")
	fmt.Println("    max_log_size      Maximum log file size (MB)")
	fmt.Println("")
	fmt.Println("  Network:")
	fmt.Println("    proxy_url         Proxy server URL")
	fmt.Println("    timeout           Network timeout (seconds)")
	fmt.Println("    retries           Number of retries")
	fmt.Println("")
	fmt.Println("  Security:")
	fmt.Println("    enable_encryption Enable encryption")
	fmt.Println("    encryption_key    Encryption key")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  grim-config get license_url")
	fmt.Println("  grim-config set license_key \"your-license-key\"")
	fmt.Println("  grim-config load /etc/grim/config.json")
	fmt.Println("  grim-config save grim.conf")
	fmt.Println("  grim-config validate")
}

func main() {
	if len(os.Args) < 2 {
		PrintHelp()
		os.Exit(1)
	}
	
	command := os.Args[1]
	
	switch command {
	case "get":
		if len(os.Args) < 3 {
			fmt.Fprintf(os.Stderr, "Error: get command requires a key\n")
			fmt.Fprintf(os.Stderr, "Usage: grim-config get <key>\n")
			os.Exit(1)
		}
		
		key := os.Args[2]
		configFile := DefaultConfigFile
		if len(os.Args) > 3 {
			configFile = os.Args[3]
		}
		
		config, err := LoadConfig(configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		
		value, err := config.GetValue(key)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("%v\n", value)
		
	case "set":
		if len(os.Args) < 4 {
			fmt.Fprintf(os.Stderr, "Error: set command requires key and value\n")
			fmt.Fprintf(os.Stderr, "Usage: grim-config set <key> <value> [file]\n")
			os.Exit(1)
		}
		
		key := os.Args[2]
		value := os.Args[3]
		configFile := DefaultConfigFile
		if len(os.Args) > 4 {
			configFile = os.Args[4]
		}
		
		config, err := LoadConfig(configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		
		if err := config.SetValue(key, value); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		
		if err := config.SaveConfig(configFile); err != nil {
			fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("Configuration updated: %s = %s\n", key, value)
		
	case "load":
		configFile := DefaultConfigFile
		if len(os.Args) > 2 {
			configFile = os.Args[2]
		}
		
		config, err := LoadConfig(configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("Configuration loaded from: %s\n", configFile)
		
		// Print current configuration
		data, _ := json.MarshalIndent(config, "", "  ")
		fmt.Println(string(data))
		
	case "save":
		configFile := DefaultConfigFile
		if len(os.Args) > 2 {
			configFile = os.Args[2]
		}
		
		config, err := LoadConfig("")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		
		if err := config.SaveConfig(configFile); err != nil {
			fmt.Fprintf(os.Stderr, "Error saving config: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("Configuration saved to: %s\n", configFile)
		
	case "validate":
		configFile := DefaultConfigFile
		if len(os.Args) > 2 {
			configFile = os.Args[2]
		}
		
		config, err := LoadConfig(configFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
		
		if err := config.Validate(); err != nil {
			fmt.Fprintf(os.Stderr, "Configuration validation failed: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Println("Configuration is valid")
		
	case "help", "--help", "-h":
		PrintHelp()
		
	default:
		fmt.Fprintf(os.Stderr, "Error: unknown command '%s'\n", command)
		fmt.Fprintf(os.Stderr, "Use 'grim-config help' for usage information\n")
		os.Exit(1)
	}
} 