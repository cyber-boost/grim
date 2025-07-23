// Package grim provides a high-performance compression engine with multiple algorithms
//
// This package offers 8 different compression algorithms with benchmarking capabilities:
// - Gzip (standard)
// - Zlib
// - Snappy (fast)
// - Zstd (high compression)
// - Brotli (web optimized)
// - XZ (maximum compression)
// - Pgzip (parallel gzip)
// - Gozstd (optimized zstd)
//
// Example usage:
//
//	package main
//
//	import "github.com/grim/grim"
//
//	func main() {
//		engine := grim.NewCompressionEngine()
//		
//		// Compress data
//		data := []byte("Hello, World!")
//		result, err := engine.Compress(data, grim.ZstdCompression)
//		if err != nil {
//			panic(err)
//		}
//		
//		// Benchmark all algorithms
//		benchmarks := engine.BenchmarkAll(data)
//		for algo, result := range benchmarks {
//			fmt.Printf("%s: %.2f%% compression, %.2f MB/s\n", 
//				algo, result.CompressionRatio, result.CompressionSpeed)
//		}
//	}
package grim

import "github.com/grim/grim/internal/compression"

// Re-export types and constants for public API
type CompressionAlgorithm = compression.CompressionAlgorithm
type CompressionResult = compression.CompressionResult
type CompressionEngine = compression.CompressionEngine

// Compression algorithm constants
const (
	GzipCompression   = compression.GzipCompression
	ZlibCompression   = compression.ZlibCompression
	SnappyCompression = compression.SnappyCompression
	ZstdCompression   = compression.ZstdCompression
	BrotliCompression = compression.BrotliCompression
	XzCompression     = compression.XzCompression
	PgzipCompression  = compression.PgzipCompression
	GozstdCompression = compression.GozstdCompression
)

// NewCompressionEngine creates a new compression engine with all algorithms
func NewCompressionEngine() *CompressionEngine {
	return compression.NewCompressionEngine()
} 