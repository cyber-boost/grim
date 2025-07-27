package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/grim/go-grim/internal/scanner"
)

type ScanResult = scanner.ScanResult

type ScanSummary struct {
	TotalFiles     int64         `json:"total_files"`
	TotalDirs      int64         `json:"total_dirs"`
	TotalSize      int64         `json:"total_size"`
	ScanDuration   time.Duration `json:"scan_duration"`
	StartTime      time.Time     `json:"start_time"`
	EndTime        time.Time     `json:"end_time"`
	FileTypes      map[string]int `json:"file_types"`
	LargestFiles   []ScanResult  `json:"largest_files"`
	RecentFiles    []ScanResult  `json:"recent_files"`
}

func main() {
	var (
		rootPath     = flag.String("path", ".", "Root directory to scan")
		outputFile   = flag.String("output", "", "Output file for results (JSON)")
		includeHash  = flag.Bool("hash", false, "Calculate file hashes")
		workers      = flag.Int("workers", 8, "Number of worker goroutines")
		maxDepth     = flag.Int("depth", -1, "Maximum directory depth (-1 for unlimited)")
		fileTypes    = flag.String("types", "", "Comma-separated list of file extensions to include")
		minSize      = flag.Int64("min-size", 0, "Minimum file size in bytes")
		maxSize      = flag.Int64("max-size", -1, "Maximum file size in bytes")
		verbose      = flag.Bool("verbose", false, "Verbose output")
		summary      = flag.Bool("summary", true, "Generate scan summary")
	)
	flag.Parse()

	// Validate inputs
	if *workers < 1 {
		*workers = 1
	}

	// Parse file types filter
	var typeFilter []string
	if *fileTypes != "" {
		typeFilter = strings.Split(*fileTypes, ",")
		for i, t := range typeFilter {
			typeFilter[i] = strings.TrimSpace(t)
		}
	}

	// Create scanner
	scanner := scanner.NewFileScanner(*workers)

	// Start scanning
	startTime := time.Now()
	results := make(chan ScanResult, 1000)
	errors := make(chan error, 100)

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		scanner.ScanDirectory(*rootPath, *maxDepth, typeFilter, *minSize, *maxSize, *includeHash, results, errors)
	}()

	// Collect results
	var allResults []ScanResult
	var scanErrors []error

	go func() {
		for result := range results {
			allResults = append(allResults, result)
			if *verbose {
				fmt.Printf("Scanned: %s (%d bytes)\n", result.Path, result.Size)
			}
		}
	}()

	go func() {
		for err := range errors {
			scanErrors = append(scanErrors, err)
			if *verbose {
				fmt.Printf("Error: %v\n", err)
			}
		}
	}()

	wg.Wait()
	// Channels are already closed by ScanDirectory method

	endTime := time.Now()
	duration := endTime.Sub(startTime)

	// Generate summary
	var summaryData *ScanSummary
	if *summary {
		summaryData = generateSummary(allResults, startTime, endTime, duration)
	}

	// Prepare output
	output := map[string]interface{}{
		"scan_path":    *rootPath,
		"scan_time":    startTime,
		"duration":     duration.String(),
		"total_files":  len(allResults),
		"errors":       len(scanErrors),
		"results":      allResults,
		"scan_errors":  scanErrors,
	}

	if summaryData != nil {
		output["summary"] = summaryData
	}

	// Output results
	if *outputFile != "" {
		// Write to file
		file, err := os.Create(*outputFile)
		if err != nil {
			log.Fatalf("Failed to create output file: %v", err)
		}
		defer file.Close()

		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(output); err != nil {
			log.Fatalf("Failed to write output: %v", err)
		}

		fmt.Printf("Scan completed in %s\n", duration)
		fmt.Printf("Results written to: %s\n", *outputFile)
		fmt.Printf("Files scanned: %d\n", len(allResults))
		if len(scanErrors) > 0 {
			fmt.Printf("Errors: %d\n", len(scanErrors))
		}
	} else {
		// Write to stdout
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(output); err != nil {
			log.Fatalf("Failed to encode output: %v", err)
		}
	}
}

func generateSummary(results []ScanResult, startTime, endTime time.Time, duration time.Duration) *ScanSummary {
	summary := &ScanSummary{
		TotalFiles:   0,
		TotalDirs:    0,
		TotalSize:    0,
		ScanDuration: duration,
		StartTime:    startTime,
		EndTime:      endTime,
		FileTypes:    make(map[string]int),
		LargestFiles: make([]ScanResult, 0, 10),
		RecentFiles:  make([]ScanResult, 0, 10),
	}

	// Process results
	for _, result := range results {
		if result.IsDir {
			summary.TotalDirs++
		} else {
			summary.TotalFiles++
			summary.TotalSize += result.Size
			summary.FileTypes[result.FileType]++
		}
	}

	// Find largest files
	for _, result := range results {
		if !result.IsDir {
			if len(summary.LargestFiles) < 10 {
				summary.LargestFiles = append(summary.LargestFiles, result)
			} else {
				// Insert if larger than smallest in top 10
				for i, existing := range summary.LargestFiles {
					if result.Size > existing.Size {
						// Insert at position i
						summary.LargestFiles = append(summary.LargestFiles[:i+1], summary.LargestFiles[i:]...)
						summary.LargestFiles[i] = result
						if len(summary.LargestFiles) > 10 {
							summary.LargestFiles = summary.LargestFiles[:10]
						}
						break
					}
				}
			}
		}
	}

	// Find recent files
	for _, result := range results {
		if !result.IsDir {
			if len(summary.RecentFiles) < 10 {
				summary.RecentFiles = append(summary.RecentFiles, result)
			} else {
				// Insert if more recent than oldest in top 10
				for i, existing := range summary.RecentFiles {
					if result.ModTime.After(existing.ModTime) {
						// Insert at position i
						summary.RecentFiles = append(summary.RecentFiles[:i+1], summary.RecentFiles[i:]...)
						summary.RecentFiles[i] = result
						if len(summary.RecentFiles) > 10 {
							summary.RecentFiles = summary.RecentFiles[:10]
						}
						break
					}
				}
			}
		}
	}

	return summary
} 