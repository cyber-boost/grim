package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/grim/go-grim/internal/network"
)

type TransferResult = network.TransferResult

type TransferSummary struct {
	TotalFiles       int              `json:"total_files"`
	Successful       int              `json:"successful"`
	Failed           int              `json:"failed"`
	TotalSize        int64            `json:"total_size"`
	TotalTransferred int64            `json:"total_transferred"`
	TotalDuration    time.Duration    `json:"total_duration"`
	AverageSpeed     float64          `json:"average_speed_mbps"`
	Results          []TransferResult `json:"results"`
}

func main() {
	var (
		source      = flag.String("source", "", "Source file or directory")
		destination = flag.String("dest", "", "Destination path")
		workers     = flag.Int("workers", 4, "Number of concurrent transfers")
		resume      = flag.Bool("resume", true, "Resume interrupted transfers")
		verify      = flag.Bool("verify", true, "Verify transfer integrity")
		timeout     = flag.Duration("timeout", 30*time.Minute, "Transfer timeout")
		progress    = flag.Bool("progress", true, "Show progress")
		output      = flag.String("output", "", "Output file for results (JSON)")
		protocol    = flag.String("protocol", "auto", "Transfer protocol (http, https, ftp, sftp, auto)")
		username    = flag.String("username", "", "Username for authentication")
		password    = flag.String("password", "", "Password for authentication")
		verbose     = flag.Bool("verbose", false, "Verbose output")
	)
	flag.Parse()

	if *source == "" || *destination == "" {
		log.Fatal("Source and destination are required")
	}

	// Create transfer manager
	manager := network.NewTransferManager(*workers, *timeout)

	// Configure authentication if provided
	if *username != "" {
		manager.SetCredentials(*username, *password)
	}

	// Start transfer
	startTime := time.Now()
	results := make(chan TransferResult, 100)
	errors := make(chan error, 100)

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		manager.Transfer(*source, *destination, *protocol, *resume, *verify, *progress, results, errors)
	}()

	// Collect results
	var allResults []TransferResult
	var transferErrors []error

	go func() {
		for result := range results {
			allResults = append(allResults, result)
			if *verbose {
				if result.Success {
					fmt.Printf("✓ Transferred: %s -> %s (%d bytes, %.2f MB/s)\n",
						result.Source, result.Destination, result.Transferred, result.Speed)
				} else {
					fmt.Printf("✗ Failed: %s -> %s (%s)\n",
						result.Source, result.Destination, result.Error)
				}
			}
		}
	}()

	go func() {
		for err := range errors {
			transferErrors = append(transferErrors, err)
			if *verbose {
				fmt.Printf("Error: %v\n", err)
			}
		}
	}()

	wg.Wait()
	close(results)
	close(errors)

	endTime := time.Now()
	duration := endTime.Sub(startTime)

	// Generate summary
	summary := generateSummary(allResults, startTime, endTime, duration)

	// Prepare output
	outputData := map[string]interface{}{
		"source":          *source,
		"destination":     *destination,
		"protocol":        *protocol,
		"start_time":      startTime,
		"end_time":        endTime,
		"duration":        duration.String(),
		"total_files":     len(allResults),
		"errors":          len(transferErrors),
		"results":         allResults,
		"transfer_errors": transferErrors,
		"summary":         summary,
	}

	// Output results
	if *output != "" {
		// Write to file
		file, err := os.Create(*output)
		if err != nil {
			log.Fatalf("Failed to create output file: %v", err)
		}
		defer file.Close()

		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(outputData); err != nil {
			log.Fatalf("Failed to write output: %v", err)
		}

		fmt.Printf("Transfer completed in %s\n", duration)
		fmt.Printf("Results written to: %s\n", *output)
		fmt.Printf("Files transferred: %d/%d\n", summary.Successful, summary.TotalFiles)
		fmt.Printf("Average speed: %.2f MB/s\n", summary.AverageSpeed)
		if len(transferErrors) > 0 {
			fmt.Printf("Errors: %d\n", len(transferErrors))
		}
	} else {
		// Write to stdout
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(outputData); err != nil {
			log.Fatalf("Failed to encode output: %v", err)
		}
	}
}

func generateSummary(results []TransferResult, startTime, endTime time.Time, duration time.Duration) *TransferSummary {
	summary := &TransferSummary{
		TotalFiles:       len(results),
		Successful:       0,
		Failed:           0,
		TotalSize:        0,
		TotalTransferred: 0,
		TotalDuration:    duration,
		Results:          results,
	}

	var totalSpeed float64
	successfulCount := 0

	for _, result := range results {
		if result.Success {
			summary.Successful++
			summary.TotalSize += result.Size
			summary.TotalTransferred += result.Transferred
			totalSpeed += result.Speed
			successfulCount++
		} else {
			summary.Failed++
		}
	}

	if successfulCount > 0 {
		summary.AverageSpeed = totalSpeed / float64(successfulCount)
	}

	return summary
}
