package grim_test

import (
	"fmt"
	"log"

	"github.com/grim/grim"
)

func ExampleNewCompressionEngine() {
	_ = grim.NewCompressionEngine()
	fmt.Printf("Engine created successfully\n")
	// Output: Engine created successfully
}

func ExampleCompressionEngine_Compress() {
	engine := grim.NewCompressionEngine()
	
	data := []byte("Hello, World!")
	result, err := engine.Compress(data, grim.ZstdCompression)
	if err != nil {
		log.Fatal(err)
	}
	
	fmt.Printf("Compressed %d bytes with %.1f%% ratio\n", 
		len(data), result.CompressionRatio)
	// Output: Compressed 13 bytes with 1.7% ratio
}

func ExampleCompressionEngine_BenchmarkAll() {
	engine := grim.NewCompressionEngine()
	
	data := []byte("This is a larger test dataset for benchmarking compression algorithms...")
	benchmarks := engine.BenchmarkAll(data)
	
	// Use a specific algorithm for consistent output
	if result, exists := benchmarks[grim.BrotliCompression]; exists && result.Error == nil {
		fmt.Printf("%s: %.1f%% compression ratio\n", 
			grim.BrotliCompression, result.CompressionRatio)
	}
	// Output: brotli: 0.8% compression ratio
} 