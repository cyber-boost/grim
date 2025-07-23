package common

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// LogLevel represents the logging level
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
	FATAL
)

// String returns the string representation of the log level
func (l LogLevel) String() string {
	switch l {
	case DEBUG:
		return "DEBUG"
	case INFO:
		return "INFO"
	case WARN:
		return "WARN"
	case ERROR:
		return "ERROR"
	case FATAL:
		return "FATAL"
	default:
		return "UNKNOWN"
	}
}

// ParseLogLevel parses a log level from string
func ParseLogLevel(level string) LogLevel {
	switch strings.ToUpper(level) {
	case "DEBUG":
		return DEBUG
	case "INFO":
		return INFO
	case "WARN", "WARNING":
		return WARN
	case "ERROR":
		return ERROR
	case "FATAL":
		return FATAL
	default:
		return INFO
	}
}

// Logger provides structured logging functionality
type Logger struct {
	level    LogLevel
	prefix   string
	output   io.Writer
	file     *os.File
	verbose  bool
}

// NewLogger creates a new logger instance
func NewLogger(verbose bool) *Logger {
	level := INFO
	if verbose {
		level = DEBUG
	}
	
	return &Logger{
		level:   level,
		prefix:  "",
		output:  os.Stdout,
		verbose: verbose,
	}
}

// NewFileLogger creates a new logger that writes to a file
func NewFileLogger(logPath string, level LogLevel, verbose bool) (*Logger, error) {
	// Ensure log directory exists
	logDir := filepath.Dir(logPath)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create log directory: %w", err)
	}
	
	// Open log file
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}
	
	return &Logger{
		level:   level,
		prefix:  "",
		output:  file,
		file:    file,
		verbose: verbose,
	}, nil
}

// SetLevel sets the logging level
func (l *Logger) SetLevel(level LogLevel) {
	l.level = level
}

// SetPrefix sets the logger prefix
func (l *Logger) SetPrefix(prefix string) {
	l.prefix = prefix
}

// Close closes the logger and any open files
func (l *Logger) Close() error {
	if l.file != nil {
		return l.file.Close()
	}
	return nil
}

// log writes a log message with the given level
func (l *Logger) log(level LogLevel, format string, args ...interface{}) {
	if level < l.level {
		return
	}
	
	// Get caller information
	_, file, line, ok := runtime.Caller(2)
	if !ok {
		file = "unknown"
		line = 0
	}
	
	// Extract filename from path
	filename := filepath.Base(file)
	
	// Format timestamp
	timestamp := time.Now().Format("2006-01-02 15:04:05.000")
	
	// Format message
	message := fmt.Sprintf(format, args...)
	
	// Build log entry
	var entry strings.Builder
	entry.WriteString(timestamp)
	entry.WriteString(" [")
	entry.WriteString(level.String())
	entry.WriteString("]")
	
	if l.prefix != "" {
		entry.WriteString(" [")
		entry.WriteString(l.prefix)
		entry.WriteString("]")
	}
	
	entry.WriteString(" ")
	entry.WriteString(filename)
	entry.WriteString(":")
	entry.WriteString(fmt.Sprintf("%d", line))
	entry.WriteString(" ")
	entry.WriteString(message)
	entry.WriteString("\n")
	
	// Write to output
	fmt.Fprint(l.output, entry.String())
}

// Debug logs a debug message
func (l *Logger) Debug(format string, args ...interface{}) {
	l.log(DEBUG, format, args...)
}

// Info logs an info message
func (l *Logger) Info(format string, args ...interface{}) {
	l.log(INFO, format, args...)
}

// Warn logs a warning message
func (l *Logger) Warn(format string, args ...interface{}) {
	l.log(WARN, format, args...)
}

// Error logs an error message
func (l *Logger) Error(format string, args ...interface{}) {
	l.log(ERROR, format, args...)
}

// Fatal logs a fatal message and exits
func (l *Logger) Fatal(format string, args ...interface{}) {
	l.log(FATAL, format, args...)
	os.Exit(1)
}

// WithFields creates a new logger with additional fields
func (l *Logger) WithFields(fields map[string]interface{}) *Logger {
	// For now, just return the same logger
	// In a more sophisticated implementation, this would add fields to the log context
	return l
}

// WithPrefix creates a new logger with a prefix
func (l *Logger) WithPrefix(prefix string) *Logger {
	newLogger := *l
	newLogger.prefix = prefix
	return &newLogger
}

// LogMetric logs a metric with tags
func (l *Logger) LogMetric(metricName string, value float64, tags map[string]string) {
	tagStr := ""
	if len(tags) > 0 {
		var tagPairs []string
		for k, v := range tags {
			tagPairs = append(tagPairs, fmt.Sprintf("%s=%s", k, v))
		}
		tagStr = " " + strings.Join(tagPairs, " ")
	}
	
	l.Info("METRIC %s=%.6f%s", metricName, value, tagStr)
}

// LogEvent logs an event with structured data
func (l *Logger) LogEvent(eventType string, data map[string]interface{}) {
	dataStr := ""
	if len(data) > 0 {
		var pairs []string
		for k, v := range data {
			pairs = append(pairs, fmt.Sprintf("%s=%v", k, v))
		}
		dataStr = " " + strings.Join(pairs, " ")
	}
	
	l.Info("EVENT %s%s", eventType, dataStr)
}

// LogPerformance logs performance metrics
func (l *Logger) LogPerformance(operation string, duration time.Duration, metadata map[string]interface{}) {
	metadataStr := ""
	if len(metadata) > 0 {
		var pairs []string
		for k, v := range metadata {
			pairs = append(pairs, fmt.Sprintf("%s=%v", k, v))
		}
		metadataStr = " " + strings.Join(pairs, " ")
	}
	
	l.Info("PERFORMANCE %s duration=%v%s", operation, duration, metadataStr)
}

// LogSecurity logs security events
func (l *Logger) LogSecurity(eventType string, details map[string]interface{}, severity string) {
	detailsStr := ""
	if len(details) > 0 {
		var pairs []string
		for k, v := range details {
			pairs = append(pairs, fmt.Sprintf("%s=%v", k, v))
		}
		detailsStr = " " + strings.Join(pairs, " ")
	}
	
	l.Info("SECURITY %s severity=%s%s", eventType, severity, detailsStr)
}

// LogAudit logs audit events
func (l *Logger) LogAudit(user, action, resource string, details map[string]interface{}, success bool) {
	detailsStr := ""
	if len(details) > 0 {
		var pairs []string
		for k, v := range details {
			pairs = append(pairs, fmt.Sprintf("%s=%v", k, v))
		}
		detailsStr = " " + strings.Join(pairs, " ")
	}
	
	status := "SUCCESS"
	if !success {
		status = "FAILED"
	}
	
	l.Info("AUDIT user=%s action=%s resource=%s status=%s%s", user, action, resource, status, detailsStr)
}

// IsVerbose returns true if verbose logging is enabled
func (l *Logger) IsVerbose() bool {
	return l.verbose
}

// GetLevel returns the current log level
func (l *Logger) GetLevel() LogLevel {
	return l.level
}

// Rotate rotates the log file (if using file logging)
func (l *Logger) Rotate() error {
	if l.file == nil {
		return nil
	}
	
	// Close current file
	if err := l.file.Close(); err != nil {
		return fmt.Errorf("failed to close log file: %w", err)
	}
	
	// Rename current file with timestamp
	timestamp := time.Now().Format("20060102-150405")
	oldPath := l.file.Name()
	newPath := oldPath + "." + timestamp
	
	if err := os.Rename(oldPath, newPath); err != nil {
		return fmt.Errorf("failed to rotate log file: %w", err)
	}
	
	// Open new file
	file, err := os.OpenFile(oldPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("failed to open new log file: %w", err)
	}
	
	l.file = file
	l.output = file
	
	return nil
}

// CleanupOldLogs removes old log files
func (l *Logger) CleanupOldLogs(logDir string, maxAge time.Duration) error {
	if l.file == nil {
		return nil
	}
	
	logPath := l.file.Name()
	logDir = filepath.Dir(logPath)
	
	entries, err := os.ReadDir(logDir)
	if err != nil {
		return fmt.Errorf("failed to read log directory: %w", err)
	}
	
	cutoff := time.Now().Add(-maxAge)
	cleaned := 0
	
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		
		// Check if it's a rotated log file
		if !strings.HasSuffix(entry.Name(), ".log") {
			continue
		}
		
		info, err := entry.Info()
		if err != nil {
			continue
		}
		
		if info.ModTime().Before(cutoff) {
			filePath := filepath.Join(logDir, entry.Name())
			if err := os.Remove(filePath); err != nil {
				l.Warn("Failed to remove old log file: %s", filePath)
			} else {
				cleaned++
			}
		}
	}
	
	if cleaned > 0 {
		l.Info("Cleaned up %d old log files", cleaned)
	}
	
	return nil
} 