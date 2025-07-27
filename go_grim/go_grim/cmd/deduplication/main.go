package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/grim-system/go-grim/internal/deduplication"
	"github.com/grim-system/go-grim/internal/common"
)

func main() {
	var (
		inputPath    = flag.String("input", "", "Input file or directory path")
		outputPath   = flag.String("output", "", "Output directory for deduplicated files")
		chunkSize    = flag.Int("chunk-size", 8192, "Chunk size in bytes")
		algorithm    = flag.String("algorithm", "sha256", "Hashing algorithm (sha256, sha1, md5)")
		verbose      = flag.Bool("verbose", false, "Enable verbose logging")
		benchmark    = flag.Bool("benchmark", false, "Run performance benchmark")
		help         = flag.Bool("help", false, "Show help message")
	)
	flag.Parse()

	if *help {
		printHelp()
		return
	}

	if *inputPath == "" {
		log.Fatal("Input path is required")
	}

	if *outputPath == "" {
		*outputPath = filepath.Join(filepath.Dir(*inputPath), "deduplicated")
	}

	// Initialize configuration
	config := &common.Config{
		ChunkSize: *chunkSize,
		Algorithm: *algorithm,
		Verbose:   *verbose,
	}

	// Initialize logger
	logger := common.NewLogger(*verbose)

	// Create deduplication engine
	engine := deduplication.NewEngine(config, logger)

	// Process input
	startTime := time.Now()
	
	if *benchmark {
		runBenchmark(engine, *inputPath, *outputPath)
	} else {
		runDeduplication(engine, *inputPath, *outputPath)
	}

	duration := time.Since(startTime)
	logger.Info("Processing completed", "duration", duration)
}

func runDeduplication(engine *deduplication.Engine, inputPath, outputPath string) {
	logger := engine.Logger()

	logger.Info("Starting deduplication", "input", inputPath, "output", outputPath)

	// Check if input exists
	if _, err := os.Stat(inputPath); os.IsNotExist(err) {
		logger.Error("Input path does not exist", "path", inputPath)
		os.Exit(1)
	}

	// Create output directory
	if err := os.MkdirAll(outputPath, 0755); err != nil {
		logger.Error("Failed to create output directory", "error", err)
		os.Exit(1)
	}

	// Process input
	result, err := engine.ProcessPath(inputPath, outputPath)
	if err != nil {
		logger.Error("Deduplication failed", "error", err)
		os.Exit(1)
	}

	// Print results
	fmt.Printf("\nDeduplication Results:\n")
	fmt.Printf("  Original size: %d bytes (%.2f MB)\n", result.OriginalSize, float64(result.OriginalSize)/(1024*1024))
	fmt.Printf("  Deduplicated size: %d bytes (%.2f MB)\n", result.DeduplicatedSize, float64(result.DeduplicatedSize)/(1024*1024))
	fmt.Printf("  Space saved: %.2f%%\n", result.Savings)
	fmt.Printf("  Chunks processed: %d\n", len(result.Chunks))
	fmt.Printf("  Unique chunks: %d\n", result.UniqueChunks)
	fmt.Printf("  Duplicate chunks: %d\n", result.DuplicateChunks)
}

func runBenchmark(engine *deduplication.Engine, inputPath, outputPath string) {
	logger := engine.Logger()

	logger.Info("Starting benchmark", "input", inputPath)

	// Run multiple iterations for accurate benchmarking
	iterations := 5
	var totalDuration time.Duration
	var totalSize int64

	for i := 0; i < iterations; i++ {
		logger.Info("Benchmark iteration", "iteration", i+1)

		startTime := time.Now()
		result, err := engine.ProcessPath(inputPath, outputPath)
		duration := time.Since(startTime)

		if err != nil {
			logger.Error("Benchmark iteration failed", "iteration", i+1, "error", err)
			continue
		}

		totalDuration += duration
		totalSize = result.OriginalSize

		logger.Info("Benchmark iteration completed",
			"iteration", i+1,
			"duration", duration,
			"throughput_mbps", float64(result.OriginalSize)/(1024*1024)/duration.Seconds())
	}

	avgDuration := totalDuration / time.Duration(iterations)
	avgThroughput := float64(totalSize) / (1024 * 1024) / avgDuration.Seconds()

	fmt.Printf("\nBenchmark Results (averaged over %d iterations):\n", iterations)
	fmt.Printf("  Average duration: %v\n", avgDuration)
	fmt.Printf("  Average throughput: %.2f MB/s\n", avgThroughput)
	fmt.Printf("  Total data processed: %d bytes (%.2f MB)\n", totalSize, float64(totalSize)/(1024*1024))
}

func printHelp() {
	fmt.Println("Grim Deduplication Engine")
	fmt.Println()
	fmt.Println("Usage: deduplication [options]")
	fmt.Println()
	fmt.Println("Options:")
	fmt.Println("  -input string")
	fmt.Println("        Input file or directory path (required)")
	fmt.Println("  -output string")
	fmt.Println("        Output directory for deduplicated files")
	fmt.Println("  -chunk-size int")
	fmt.Println("        Chunk size in bytes (default 8192)")
	fmt.Println("  -algorithm string")
	fmt.Println("        Hashing algorithm: sha256, sha1, md5 (default sha256)")
	fmt.Println("  -verbose")
	fmt.Println("        Enable verbose logging")
	fmt.Println("  -benchmark")
	fmt.Println("        Run performance benchmark")
	fmt.Println("  -help")
	fmt.Println("        Show this help message")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  deduplication -input /path/to/files -output /path/to/dedup")
	fmt.Println("  deduplication -input large_file.dat -chunk-size 16384 -verbose")
	fmt.Println("  deduplication -input /data -benchmark -algorithm sha1")
} 