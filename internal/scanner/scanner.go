package scanner

import (
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type FileScanner struct {
	workers int
}

type ScanResult struct {
	Path        string    `json:"path"`
	Size        int64     `json:"size"`
	ModTime     time.Time `json:"mod_time"`
	IsDir       bool      `json:"is_dir"`
	FileType    string    `json:"file_type"`
	MD5Hash     string    `json:"md5_hash,omitempty"`
	SHA256Hash  string    `json:"sha256_hash,omitempty"`
	Permissions string    `json:"permissions"`
	ScanTime    time.Time `json:"scan_time"`
}

func NewFileScanner(workers int) *FileScanner {
	return &FileScanner{
		workers: workers,
	}
}

func (fs *FileScanner) ScanDirectory(rootPath string, maxDepth int, typeFilter []string, minSize, maxSize int64, includeHash bool, results chan<- ScanResult, errors chan<- error) {
	defer close(results)
	defer close(errors)

	// Create worker pool
	fileChan := make(chan string, 1000)
	var wg sync.WaitGroup

	// Start workers
	for i := 0; i < fs.workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			fs.worker(fileChan, results, errors, typeFilter, minSize, maxSize, includeHash)
		}()
	}

	// Walk directory
	go func() {
		defer close(fileChan)
		err := filepath.Walk(rootPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				errors <- fmt.Errorf("error accessing %s: %v", path, err)
				return nil
			}

			// Check depth
			if maxDepth >= 0 {
				relPath, _ := filepath.Rel(rootPath, path)
				depth := strings.Count(relPath, string(os.PathSeparator))
				if depth > maxDepth {
					if info.IsDir() {
						return filepath.SkipDir
					}
					return nil
				}
			}

			// Send to workers
			fileChan <- path
			return nil
		})

		if err != nil {
			errors <- fmt.Errorf("error walking directory: %v", err)
		}
	}()

	wg.Wait()
}

func (fs *FileScanner) worker(fileChan <-chan string, results chan<- ScanResult, errors chan<- error, typeFilter []string, minSize, maxSize int64, includeHash bool) {
	for path := range fileChan {
		result, err := fs.scanFile(path, typeFilter, minSize, maxSize, includeHash)
		if err != nil {
			errors <- err
			continue
		}

		if result != nil {
			results <- *result
		}
	}
}

func (fs *FileScanner) scanFile(path string, typeFilter []string, minSize, maxSize int64, includeHash bool) (*ScanResult, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, fmt.Errorf("failed to stat %s: %v", path, err)
	}

	// Check size filters
	if !info.IsDir() {
		if minSize > 0 && info.Size() < minSize {
			return nil, nil
		}
		if maxSize > 0 && info.Size() > maxSize {
			return nil, nil
		}
	}

	// Get file type
	fileType := fs.detectFileType(path, info)

	// Check type filter
	if len(typeFilter) > 0 && !info.IsDir() {
		found := false
		for _, t := range typeFilter {
			if strings.HasSuffix(strings.ToLower(fileType), strings.ToLower(t)) {
				found = true
				break
			}
		}
		if !found {
			return nil, nil
		}
	}

	result := &ScanResult{
		Path:        path,
		Size:        info.Size(),
		ModTime:     info.ModTime(),
		IsDir:       info.IsDir(),
		FileType:    fileType,
		Permissions: info.Mode().String(),
		ScanTime:    time.Now(),
	}

	// Calculate hashes if requested and it's a file
	if includeHash && !info.IsDir() {
		md5Hash, sha256Hash, err := fs.calculateHashes(path)
		if err != nil {
			return nil, fmt.Errorf("failed to calculate hashes for %s: %v", path, err)
		}
		result.MD5Hash = md5Hash
		result.SHA256Hash = sha256Hash
	}

	return result, nil
}

func (fs *FileScanner) detectFileType(path string, info os.FileInfo) string {
	if info.IsDir() {
		return "directory"
	}

	ext := strings.ToLower(filepath.Ext(path))
	if ext == "" {
		return "unknown"
	}

	// Remove the dot
	ext = ext[1:]

	// Common file type mappings
	fileTypes := map[string]string{
		// Text files
		"txt":  "text/plain",
		"md":   "text/markdown",
		"json": "application/json",
		"xml":  "application/xml",
		"yaml": "application/yaml",
		"yml":  "application/yaml",
		"csv":  "text/csv",
		"html": "text/html",
		"htm":  "text/html",
		"css":  "text/css",
		"js":   "application/javascript",
		"ts":   "application/typescript",
		"py":   "text/x-python",
		"go":   "text/x-go",
		"rs":   "text/x-rust",
		"java": "text/x-java",
		"cpp":  "text/x-c++src",
		"c":    "text/x-csrc",
		"h":    "text/x-chdr",
		"hpp":  "text/x-c++hdr",
		"php":  "text/x-php",
		"rb":   "text/x-ruby",
		"sh":   "text/x-shellscript",
		"sql":  "text/x-sql",
		"conf": "text/plain",
		"cfg":  "text/plain",
		"ini":  "text/plain",
		"log":  "text/plain",

		// Image files
		"jpg":  "image/jpeg",
		"jpeg": "image/jpeg",
		"png":  "image/png",
		"gif":  "image/gif",
		"bmp":  "image/bmp",
		"svg":  "image/svg+xml",
		"ico":  "image/x-icon",
		"tiff": "image/tiff",
		"webp": "image/webp",

		// Audio files
		"mp3":  "audio/mpeg",
		"wav":  "audio/wav",
		"flac": "audio/flac",
		"aac":  "audio/aac",
		"ogg":  "audio/ogg",
		"wma":  "audio/x-ms-wma",

		// Video files
		"mp4":  "video/mp4",
		"avi":  "video/x-msvideo",
		"mkv":  "video/x-matroska",
		"mov":  "video/quicktime",
		"wmv":  "video/x-ms-wmv",
		"flv":  "video/x-flv",
		"webm": "video/webm",

		// Archive files
		"zip": "application/zip",
		"tar": "application/x-tar",
		"gz":  "application/gzip",
		"bz2": "application/x-bzip2",
		"7z":  "application/x-7z-compressed",
		"rar": "application/x-rar-compressed",
		"xz":  "application/x-xz",

		// Document files
		"pdf":  "application/pdf",
		"doc":  "application/msword",
		"docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
		"xls":  "application/vnd.ms-excel",
		"xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		"ppt":  "application/vnd.ms-powerpoint",
		"pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
		"odt":  "application/vnd.oasis.opendocument.text",
		"ods":  "application/vnd.oasis.opendocument.spreadsheet",
		"odp":  "application/vnd.oasis.opendocument.presentation",

		// Binary files
		"exe":   "application/x-executable",
		"dll":   "application/x-msdownload",
		"so":    "application/x-sharedlib",
		"dylib": "application/x-mach-binary",
		"bin":   "application/octet-stream",
		"dat":   "application/octet-stream",
	}

	if mimeType, exists := fileTypes[ext]; exists {
		return mimeType
	}

	return fmt.Sprintf("application/x-%s", ext)
}

func (fs *FileScanner) calculateHashes(path string) (string, string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", "", err
	}
	defer file.Close()

	md5Hash := md5.New()
	sha256Hash := sha256.New()

	// Read file in chunks to avoid memory issues
	buffer := make([]byte, 32*1024) // 32KB chunks
	for {
		n, err := file.Read(buffer)
		if n > 0 {
			md5Hash.Write(buffer[:n])
			sha256Hash.Write(buffer[:n])
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", "", err
		}
	}

	md5Sum := hex.EncodeToString(md5Hash.Sum(nil))
	sha256Sum := hex.EncodeToString(sha256Hash.Sum(nil))

	return md5Sum, sha256Sum, nil
}

// Utility functions for external use
func (fs *FileScanner) GetFileInfo(path string) (*ScanResult, error) {
	return fs.scanFile(path, nil, 0, -1, false)
}

func (fs *FileScanner) GetFileHash(path string) (string, string, error) {
	return fs.calculateHashes(path)
}

func (fs *FileScanner) DetectFileType(path string) string {
	info, err := os.Stat(path)
	if err != nil {
		return "unknown"
	}
	return fs.detectFileType(path, info)
}
