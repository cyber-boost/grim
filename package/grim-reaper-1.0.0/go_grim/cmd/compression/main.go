package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/grim/go-grim/internal/compression"
	"github.com/sirupsen/logrus"
)

type BenchmarkResult struct {
	Timestamp    time.Time                                    `json:"timestamp"`
	DataSize     int64                                        `json:"data_size"`
	Results      map[compression.CompressionAlgorithm]*compression.CompressionResult `json:"results"`
	BestRatio    compression.CompressionAlgorithm             `json:"best_ratio"`
	FastestSpeed compression.CompressionAlgorithm             `json:"fastest_speed"`
	Duration     time.Duration                                `json:"duration"`
}

func main() {
	var (
		inputFile    = flag.String("input", "", "Input file to compress")
		outputFile   = flag.String("output", "", "Output file for compressed data")
		algorithm    = flag.String("algorithm", "", "Compression algorithm to use")
		benchmark    = flag.Bool("benchmark", false, "Run benchmark on all algorithms")
		decompress   = flag.Bool("decompress", false, "Decompress instead of compress")
		jsonOutput   = flag.Bool("json", false, "Output results in JSON format")
		verbose      = flag.Bool("verbose", false, "Enable verbose logging")
		iterations   = flag.Int("iterations", 1, "Number of benchmark iterations")
	)
	flag.Parse()

	if *verbose {
		logrus.SetLevel(logrus.DebugLevel)
	}

	engine := compression.NewCompressionEngine()

	// Handle benchmark mode
	if *benchmark {
		runBenchmark(engine, *inputFile, *iterations, *jsonOutput)
		return
	}

	// Handle single file compression/decompression
	if *inputFile == "" {
		log.Fatal("Input file is required")
	}

	if *algorithm == "" {
		log.Fatal("Algorithm is required")
	}

	algo := compression.CompressionAlgorithm(*algorithm)
	if *decompress {
		decompressFile(engine, *inputFile, *outputFile, algo, *jsonOutput)
	} else {
		compressFile(engine, *inputFile, *outputFile, algo, *jsonOutput)
	}
}

func runBenchmark(engine *compression.CompressionEngine, inputFile string, iterations int, jsonOutput bool) {
	var data []byte
	var err error

	if inputFile == "" {
		// Generate synthetic data for benchmarking
		data = generateTestData(10 * 1024 * 1024) // 10MB
	} else {
		data, err = os.ReadFile(inputFile)
		if err != nil {
			log.Fatalf("Failed to read input file: %v", err)
		}
	}

	fmt.Printf("Running compression benchmark on %d MB of data (%d iterations)...\n", 
		len(data)/(1024*1024), iterations)

	start := time.Now()
	var allResults []BenchmarkResult

	for i := 0; i < iterations; i++ {
		results := engine.BenchmarkAll(data)
		
		// Find best compression ratio
		var bestRatio compression.CompressionAlgorithm
		bestRatioValue := 1.0
		for algo, result := range results {
			if result.Error == nil && result.CompressionRatio < bestRatioValue {
				bestRatioValue = result.CompressionRatio
				bestRatio = algo
			}
		}

		// Find fastest compression speed
		var fastestSpeed compression.CompressionAlgorithm
		fastestSpeedValue := 0.0
		for algo, result := range results {
			if result.Error == nil && result.CompressionSpeed > fastestSpeedValue {
				fastestSpeedValue = result.CompressionSpeed
				fastestSpeed = algo
			}
		}

		benchmarkResult := BenchmarkResult{
			Timestamp:    time.Now(),
			DataSize:     int64(len(data)),
			Results:      results,
			BestRatio:    bestRatio,
			FastestSpeed: fastestSpeed,
			Duration:     time.Since(start),
		}
		allResults = append(allResults, benchmarkResult)
	}

	totalDuration := time.Since(start)

	if jsonOutput {
		outputJSON(allResults)
	} else {
		outputBenchmarkResults(allResults, totalDuration)
	}
}

func compressFile(engine *compression.CompressionEngine, inputFile, outputFile string, algorithm compression.CompressionAlgorithm, jsonOutput bool) {
	data, err := os.ReadFile(inputFile)
	if err != nil {
		log.Fatalf("Failed to read input file: %v", err)
	}

	result, err := engine.Compress(data, algorithm)
	if err != nil {
		log.Fatalf("Compression failed: %v", err)
	}

	if result.Error != nil {
		log.Fatalf("Compression error: %v", result.Error)
	}

	if outputFile == "" {
		outputFile = inputFile + "." + string(algorithm)
	}

	// We need to compress the data again to get the compressed bytes
	compressor, exists := engine.GetAlgorithm(algorithm)
	if !exists {
		log.Fatalf("Algorithm %s not found", algorithm)
	}
	compressedBytes, err := compressor.Compress(data)
	if err != nil {
		log.Fatalf("Compression failed: %v", err)
	}
	err = os.WriteFile(outputFile, compressedBytes, 0644)
	if err != nil {
		log.Fatalf("Failed to write output file: %v", err)
	}

	if jsonOutput {
		outputCompressionResult(result, jsonOutput)
	} else {
		fmt.Printf("Compression completed successfully!\n")
		fmt.Printf("Algorithm: %s\n", algorithm)
		fmt.Printf("Original size: %d bytes (%.2f MB)\n", result.OriginalSize, float64(result.OriginalSize)/(1024*1024))
		fmt.Printf("Compressed size: %d bytes (%.2f MB)\n", result.CompressedSize, float64(result.CompressedSize)/(1024*1024))
		fmt.Printf("Compression ratio: %.2f%%\n", result.CompressionRatio*100)
		fmt.Printf("Compression time: %v\n", result.CompressionTime)
		fmt.Printf("Compression speed: %.2f MB/s\n", result.CompressionSpeed)
		fmt.Printf("Output file: %s\n", outputFile)
	}
}

func decompressFile(engine *compression.CompressionEngine, inputFile, outputFile string, algorithm compression.CompressionAlgorithm, jsonOutput bool) {
	data, err := os.ReadFile(inputFile)
	if err != nil {
		log.Fatalf("Failed to read input file: %v", err)
	}

	result, err := engine.Decompress(data, algorithm)
	if err != nil {
		log.Fatalf("Decompression failed: %v", err)
	}

	if result.Error != nil {
		log.Fatalf("Decompression error: %v", result.Error)
	}

	if outputFile == "" {
		// Remove algorithm extension
		ext := "." + string(algorithm)
		if filepath.Ext(inputFile) == ext {
			outputFile = inputFile[:len(inputFile)-len(ext)]
		} else {
			outputFile = inputFile + ".decompressed"
		}
	}

	// We need to decompress the data again to get the decompressed bytes
	compressor, exists := engine.GetAlgorithm(algorithm)
	if !exists {
		log.Fatalf("Algorithm %s not found", algorithm)
	}
	decompressedBytes, err := compressor.Decompress(data)
	if err != nil {
		log.Fatalf("Decompression failed: %v", err)
	}
	err = os.WriteFile(outputFile, decompressedBytes, 0644)
	if err != nil {
		log.Fatalf("Failed to write output file: %v", err)
	}

	if jsonOutput {
		outputDecompressionResult(result, jsonOutput)
	} else {
		fmt.Printf("Decompression completed successfully!\n")
		fmt.Printf("Algorithm: %s\n", algorithm)
		fmt.Printf("Compressed size: %d bytes (%.2f MB)\n", result.CompressedSize, float64(result.CompressedSize)/(1024*1024))
		fmt.Printf("Decompressed size: %d bytes (%.2f MB)\n", result.OriginalSize, float64(result.OriginalSize)/(1024*1024))
		fmt.Printf("Compression ratio: %.2f%%\n", result.CompressionRatio*100)
		fmt.Printf("Decompression time: %v\n", result.DecompressionTime)
		fmt.Printf("Decompression speed: %.2f MB/s\n", result.DecompressionSpeed)
		fmt.Printf("Output file: %s\n", outputFile)
	}
}

func generateTestData(size int) []byte {
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i % 256)
	}
	return data
}

func outputJSON(data interface{}) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(data); err != nil {
		log.Fatalf("Failed to encode JSON: %v", err)
	}
}

func outputBenchmarkResults(results []BenchmarkResult, totalDuration time.Duration) {
	if len(results) == 0 {
		return
	}

	// Use the last result for display
	result := results[len(results)-1]

	fmt.Printf("\n=== COMPRESSION BENCHMARK RESULTS ===\n")
	fmt.Printf("Data size: %d bytes (%.2f MB)\n", result.DataSize, float64(result.DataSize)/(1024*1024))
	fmt.Printf("Iterations: %d\n", len(results))
	fmt.Printf("Total duration: %v\n", totalDuration)
	fmt.Printf("Average duration per iteration: %v\n", totalDuration/time.Duration(len(results)))

	fmt.Printf("\n--- ALGORITHM COMPARISON ---\n")
	fmt.Printf("%-12s %-12s %-12s %-12s %-12s %-12s\n", 
		"Algorithm", "Size (MB)", "Ratio (%)", "Comp (MB/s)", "Decomp (MB/s)", "Status")
	fmt.Printf("%-12s %-12s %-12s %-12s %-12s %-12s\n", 
		"-----------", "-----------", "-----------", "-----------", "-----------", "-----------")

	for algo, res := range result.Results {
		status := "OK"
		if res.Error != nil {
			status = "ERROR"
		}

		fmt.Printf("%-12s %-12.2f %-12.2f %-12.2f %-12.2f %-12s\n",
			algo,
			float64(res.CompressedSize)/(1024*1024),
			res.CompressionRatio*100,
			res.CompressionSpeed,
			res.DecompressionSpeed,
			status)
	}

	fmt.Printf("\n--- SUMMARY ---\n")
	fmt.Printf("Best compression ratio: %s (%.2f%%)\n", 
		result.BestRatio, result.Results[result.BestRatio].CompressionRatio*100)
	fmt.Printf("Fastest compression: %s (%.2f MB/s)\n", 
		result.FastestSpeed, result.Results[result.FastestSpeed].CompressionSpeed)
}

func outputCompressionResult(result *compression.CompressionResult, jsonOutput bool) {
	if jsonOutput {
		outputJSON(result)
	}
}

func outputDecompressionResult(result *compression.CompressionResult, jsonOutput bool) {
	if jsonOutput {
		outputJSON(result)
	}
} 