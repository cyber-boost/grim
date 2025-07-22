package network

import (
	"crypto/md5"
	"crypto/tls"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type TransferManager struct {
	workers     int
	timeout     time.Duration
	username    string
	password    string
	client      *http.Client
	mu          sync.Mutex
}

type TransferResult struct {
	Source      string        `json:"source"`
	Destination string        `json:"destination"`
	Size        int64         `json:"size"`
	Transferred int64         `json:"transferred"`
	Duration    time.Duration `json:"duration"`
	Speed       float64       `json:"speed_mbps"`
	Success     bool          `json:"success"`
	Error       string        `json:"error,omitempty"`
	Resumed     bool          `json:"resumed"`
	Checksum    string        `json:"checksum,omitempty"`
}

func NewTransferManager(workers int, timeout time.Duration) *TransferManager {
	client := &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: false,
			},
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	return &TransferManager{
		workers: workers,
		timeout: timeout,
		client:  client,
	}
}

func (tm *TransferManager) SetCredentials(username, password string) {
	tm.mu.Lock()
	defer tm.mu.Unlock()
	tm.username = username
	tm.password = password
}

func (tm *TransferManager) Transfer(source, destination, protocol string, resume, verify, progress bool, results chan<- TransferResult, errors chan<- error) {
	defer close(results)
	defer close(errors)

	// Auto-detect protocol if not specified
	if protocol == "auto" {
		protocol = tm.detectProtocol(source)
	}

	// Create worker pool
	transferChan := make(chan TransferTask, 100)
	var wg sync.WaitGroup

	// Start workers
	for i := 0; i < tm.workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tm.worker(transferChan, resume, verify, progress, results, errors)
		}()
	}

	// Queue transfers
	go func() {
		defer close(transferChan)
		tm.queueTransfers(source, destination, protocol, transferChan, errors)
	}()

	wg.Wait()
}

type TransferTask struct {
	Source      string
	Destination string
	Protocol    string
}

func (tm *TransferManager) queueTransfers(source, destination, protocol string, transferChan chan<- TransferTask, errors chan<- error) {
	// Check if source is a directory
	info, err := os.Stat(source)
	if err != nil {
		errors <- fmt.Errorf("failed to stat source %s: %v", source, err)
		return
	}

	if info.IsDir() {
		// Queue all files in directory
		err := filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				errors <- fmt.Errorf("error accessing %s: %v", path, err)
				return nil
			}

			if !info.IsDir() {
				relPath, _ := filepath.Rel(source, path)
				destPath := filepath.Join(destination, relPath)
				
				// Create destination directory
				destDir := filepath.Dir(destPath)
				if err := os.MkdirAll(destDir, 0755); err != nil {
					errors <- fmt.Errorf("failed to create directory %s: %v", destDir, err)
					return nil
				}

				transferChan <- TransferTask{
					Source:      path,
					Destination: destPath,
					Protocol:    protocol,
				}
			}
			return nil
		})

		if err != nil {
			errors <- fmt.Errorf("error walking directory %s: %v", source, err)
		}
	} else {
		// Single file transfer
		transferChan <- TransferTask{
			Source:      source,
			Destination: destination,
			Protocol:    protocol,
		}
	}
}

func (tm *TransferManager) worker(transferChan <-chan TransferTask, resume, verify, progress bool, results chan<- TransferResult, errors chan<- error) {
	for task := range transferChan {
		result := tm.transferFile(task.Source, task.Destination, task.Protocol, resume, verify, progress)
		results <- result
	}
}

func (tm *TransferManager) transferFile(source, destination, protocol string, resume, verify, progress bool) TransferResult {
	startTime := time.Now()
	result := TransferResult{
		Source:      source,
		Destination: destination,
		Success:     false,
	}

	// Get file size
	var fileSize int64
	var err error

	switch protocol {
	case "http", "https":
		fileSize, err = tm.getRemoteFileSize(source)
	case "file":
		info, err := os.Stat(source)
		if err != nil {
			result.Error = fmt.Sprintf("failed to stat file: %v", err)
			return result
		}
		fileSize = info.Size()
	default:
		// Try as local file
		info, err := os.Stat(source)
		if err != nil {
			result.Error = fmt.Sprintf("failed to stat file: %v", err)
			return result
		}
		fileSize = info.Size()
	}

	if err != nil {
		result.Error = fmt.Sprintf("failed to get file size: %v", err)
		return result
	}

	result.Size = fileSize

	// Check for resume
	var offset int64
	if resume {
		if info, err := os.Stat(destination); err == nil {
			offset = info.Size()
			if offset > 0 && offset < fileSize {
				result.Resumed = true
			}
		}
	}

	// Perform transfer
	transferred, err := tm.performTransfer(source, destination, protocol, offset, fileSize, progress)
	if err != nil {
		result.Error = fmt.Sprintf("transfer failed: %v", err)
		return result
	}

	result.Transferred = transferred
	result.Duration = time.Since(startTime)
	result.Success = true

	// Calculate speed
	if result.Duration > 0 {
		result.Speed = float64(transferred) / result.Duration.Seconds() / (1024 * 1024) // MB/s
	}

	// Verify transfer if requested
	if verify && result.Success {
		if err := tm.verifyTransfer(source, destination, protocol); err != nil {
			result.Error = fmt.Sprintf("verification failed: %v", err)
			result.Success = false
		} else {
			// Calculate checksum
			if checksum, err := tm.calculateChecksum(destination); err == nil {
				result.Checksum = checksum
			}
		}
	}

	return result
}

func (tm *TransferManager) performTransfer(source, destination, protocol string, offset, fileSize int64, progress bool) (int64, error) {
	switch protocol {
	case "http", "https":
		return tm.transferHTTP(source, destination, offset, fileSize, progress)
	case "file":
		return tm.transferLocal(source, destination, offset, fileSize, progress)
	default:
		// Try as local file
		return tm.transferLocal(source, destination, offset, fileSize, progress)
	}
}

func (tm *TransferManager) transferHTTP(source, destination string, offset, fileSize int64, progress bool) (int64, error) {
	req, err := http.NewRequest("GET", source, nil)
	if err != nil {
		return 0, err
	}

	// Add range header for resume
	if offset > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", offset))
	}

	// Add authentication if provided
	tm.mu.Lock()
	if tm.username != "" {
		req.SetBasicAuth(tm.username, tm.password)
	}
	tm.mu.Unlock()

	resp, err := tm.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		return 0, fmt.Errorf("HTTP error: %s", resp.Status)
	}

	// Open destination file
	flag := os.O_CREATE | os.O_WRONLY
	if offset > 0 {
		flag |= os.O_APPEND
	} else {
		flag |= os.O_TRUNC
	}

	file, err := os.OpenFile(destination, flag, 0644)
	if err != nil {
		return 0, err
	}
	defer file.Close()

	// Transfer data
	buffer := make([]byte, 32*1024) // 32KB buffer
	var totalTransferred int64
	lastProgress := time.Now()

	for {
		n, err := resp.Body.Read(buffer)
		if n > 0 {
			written, writeErr := file.Write(buffer[:n])
			if writeErr != nil {
				return totalTransferred, writeErr
			}
			totalTransferred += int64(written)
		}

		// Show progress
		if progress && time.Since(lastProgress) > time.Second {
			percent := float64(totalTransferred+offset) / float64(fileSize) * 100
			fmt.Printf("\rProgress: %.1f%% (%d/%d bytes)", percent, totalTransferred+offset, fileSize)
			lastProgress = time.Now()
		}

		if err == io.EOF {
			break
		}
		if err != nil {
			return totalTransferred, err
		}
	}

	if progress {
		fmt.Println() // New line after progress
	}

	return totalTransferred, nil
}

func (tm *TransferManager) transferLocal(source, destination string, offset, fileSize int64, progress bool) (int64, error) {
	srcFile, err := os.Open(source)
	if err != nil {
		return 0, err
	}
	defer srcFile.Close()

	// Seek to offset if resuming
	if offset > 0 {
		if _, err := srcFile.Seek(offset, 0); err != nil {
			return 0, err
		}
	}

	// Open destination file
	flag := os.O_CREATE | os.O_WRONLY
	if offset > 0 {
		flag |= os.O_APPEND
	} else {
		flag |= os.O_TRUNC
	}

	dstFile, err := os.OpenFile(destination, flag, 0644)
	if err != nil {
		return 0, err
	}
	defer dstFile.Close()

	// Transfer data
	buffer := make([]byte, 32*1024) // 32KB buffer
	var totalTransferred int64
	lastProgress := time.Now()

	for {
		n, err := srcFile.Read(buffer)
		if n > 0 {
			written, writeErr := dstFile.Write(buffer[:n])
			if writeErr != nil {
				return totalTransferred, writeErr
			}
			totalTransferred += int64(written)
		}

		// Show progress
		if progress && time.Since(lastProgress) > time.Second {
			percent := float64(totalTransferred+offset) / float64(fileSize) * 100
			fmt.Printf("\rProgress: %.1f%% (%d/%d bytes)", percent, totalTransferred+offset, fileSize)
			lastProgress = time.Now()
		}

		if err == io.EOF {
			break
		}
		if err != nil {
			return totalTransferred, err
		}
	}

	if progress {
		fmt.Println() // New line after progress
	}

	return totalTransferred, nil
}

func (tm *TransferManager) getRemoteFileSize(url string) (int64, error) {
	req, err := http.NewRequest("HEAD", url, nil)
	if err != nil {
		return 0, err
	}

	tm.mu.Lock()
	if tm.username != "" {
		req.SetBasicAuth(tm.username, tm.password)
	}
	tm.mu.Unlock()

	resp, err := tm.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("HTTP error: %s", resp.Status)
	}

	return resp.ContentLength, nil
}

func (tm *TransferManager) verifyTransfer(source, destination, protocol string) error {
	// For now, just check file sizes match
	var sourceSize, destSize int64
	var err error

	switch protocol {
	case "http", "https":
		sourceSize, err = tm.getRemoteFileSize(source)
	case "file":
		info, err := os.Stat(source)
		if err != nil {
			return err
		}
		sourceSize = info.Size()
	default:
		info, err := os.Stat(source)
		if err != nil {
			return err
		}
		sourceSize = info.Size()
	}

	if err != nil {
		return err
	}

	destInfo, err := os.Stat(destination)
	if err != nil {
		return err
	}
	destSize = destInfo.Size()

	if sourceSize != destSize {
		return fmt.Errorf("size mismatch: source=%d, destination=%d", sourceSize, destSize)
	}

	return nil
}

func (tm *TransferManager) calculateChecksum(filepath string) (string, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := md5.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}

func (tm *TransferManager) detectProtocol(source string) string {
	if strings.HasPrefix(source, "http://") {
		return "http"
	}
	if strings.HasPrefix(source, "https://") {
		return "https"
	}
	if strings.HasPrefix(source, "ftp://") {
		return "ftp"
	}
	if strings.HasPrefix(source, "sftp://") {
		return "sftp"
	}
	return "file"
} 