package compression

import (
	"bytes"
	"compress/gzip"
	"compress/zlib"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/DataDog/zstd"
	"github.com/andybalholm/brotli"
	"github.com/golang/snappy"
	"github.com/klauspost/pgzip"
	"github.com/ulikunitz/xz"
	"github.com/valyala/gozstd"
)

// CompressionAlgorithm represents different compression methods
type CompressionAlgorithm string

const (
	GzipCompression   CompressionAlgorithm = "gzip"
	ZlibCompression   CompressionAlgorithm = "zlib"
	SnappyCompression CompressionAlgorithm = "snappy"
	ZstdCompression   CompressionAlgorithm = "zstd"
	BrotliCompression CompressionAlgorithm = "brotli"
	XzCompression     CompressionAlgorithm = "xz"
	PgzipCompression  CompressionAlgorithm = "pgzip"
	GozstdCompression CompressionAlgorithm = "gozstd"
)

// CompressionResult contains compression metrics
type CompressionResult struct {
	Algorithm          CompressionAlgorithm
	OriginalSize       int64
	CompressedSize     int64
	CompressionRatio   float64
	CompressionTime    time.Duration
	DecompressionTime  time.Duration
	CompressionSpeed   float64 // MB/s
	DecompressionSpeed float64 // MB/s
	Error              error
}

// CompressionEngine provides high-performance compression capabilities
type CompressionEngine struct {
	algorithms map[CompressionAlgorithm]Compressor
	pool       sync.Pool
}

// Compressor interface for different compression algorithms
type Compressor interface {
	Compress(data []byte) ([]byte, error)
	Decompress(data []byte) ([]byte, error)
	Name() string
}

// NewCompressionEngine creates a new compression engine with all algorithms
func NewCompressionEngine() *CompressionEngine {
	engine := &CompressionEngine{
		algorithms: make(map[CompressionAlgorithm]Compressor),
		pool: sync.Pool{
			New: func() interface{} {
				return new(bytes.Buffer)
			},
		},
	}

	// Register all compression algorithms
	engine.algorithms[GzipCompression] = &GzipCompressor{}
	engine.algorithms[ZlibCompression] = &ZlibCompressor{}
	engine.algorithms[SnappyCompression] = &SnappyCompressor{}
	engine.algorithms[ZstdCompression] = &ZstdCompressor{}
	engine.algorithms[BrotliCompression] = &BrotliCompressor{}
	engine.algorithms[XzCompression] = &XzCompressor{}
	engine.algorithms[PgzipCompression] = &PgzipCompressor{}
	engine.algorithms[GozstdCompression] = &GozstdCompressor{}

	return engine
}

// Compress compresses data using the specified algorithm
func (e *CompressionEngine) Compress(data []byte, algorithm CompressionAlgorithm) (*CompressionResult, error) {
	compressor, exists := e.algorithms[algorithm]
	if !exists {
		return nil, fmt.Errorf("unsupported compression algorithm: %s", algorithm)
	}

	start := time.Now()
	compressed, err := compressor.Compress(data)
	compressionTime := time.Since(start)

	if err != nil {
		return &CompressionResult{
			Algorithm: algorithm,
			Error:     err,
		}, nil
	}

	originalSize := int64(len(data))
	compressedSize := int64(len(compressed))
	compressionRatio := float64(compressedSize) / float64(originalSize)
	compressionSpeed := float64(originalSize) / 1024 / 1024 / compressionTime.Seconds()

	return &CompressionResult{
		Algorithm:        algorithm,
		OriginalSize:     originalSize,
		CompressedSize:   compressedSize,
		CompressionRatio: compressionRatio,
		CompressionTime:  compressionTime,
		CompressionSpeed: compressionSpeed,
	}, nil
}

// Decompress decompresses data using the specified algorithm
func (e *CompressionEngine) Decompress(data []byte, algorithm CompressionAlgorithm) (*CompressionResult, error) {
	compressor, exists := e.algorithms[algorithm]
	if !exists {
		return nil, fmt.Errorf("unsupported compression algorithm: %s", algorithm)
	}

	start := time.Now()
	decompressed, err := compressor.Decompress(data)
	decompressionTime := time.Since(start)

	if err != nil {
		return &CompressionResult{
			Algorithm: algorithm,
			Error:     err,
		}, nil
	}

	originalSize := int64(len(decompressed))
	compressedSize := int64(len(data))
	compressionRatio := float64(compressedSize) / float64(originalSize)
	decompressionSpeed := float64(originalSize) / 1024 / 1024 / decompressionTime.Seconds()

	return &CompressionResult{
		Algorithm:          algorithm,
		OriginalSize:       originalSize,
		CompressedSize:     compressedSize,
		CompressionRatio:   compressionRatio,
		DecompressionTime:  decompressionTime,
		DecompressionSpeed: decompressionSpeed,
	}, nil
}

// BenchmarkAll runs compression benchmarks on all algorithms
func (e *CompressionEngine) BenchmarkAll(data []byte) map[CompressionAlgorithm]*CompressionResult {
	results := make(map[CompressionAlgorithm]*CompressionResult)

	for algorithm := range e.algorithms {
		// Compress
		compResult, err := e.Compress(data, algorithm)
		if err != nil {
			compResult = &CompressionResult{
				Algorithm: algorithm,
				Error:     err,
			}
		}

		// Decompress if compression succeeded
		if compResult.Error == nil {
			// Compress again to get data for decompression test
			compressed, err := e.algorithms[algorithm].Compress(data)
			if err != nil {
				compResult.Error = err
			} else {
				decompResult, err := e.Decompress(compressed, algorithm)
				if err != nil {
					compResult.Error = err
				} else {
					compResult.DecompressionTime = decompResult.DecompressionTime
					compResult.DecompressionSpeed = decompResult.DecompressionSpeed
				}
			}
		}

		results[algorithm] = compResult
	}

	return results
}

// GetBestAlgorithm returns the algorithm with the best compression ratio
func (e *CompressionEngine) GetBestAlgorithm(data []byte) (CompressionAlgorithm, *CompressionResult, error) {
	results := e.BenchmarkAll(data)

	var bestAlgorithm CompressionAlgorithm
	var bestResult *CompressionResult
	bestRatio := 1.0

	for algorithm, result := range results {
		if result.Error != nil {
			continue
		}
		if result.CompressionRatio < bestRatio {
			bestRatio = result.CompressionRatio
			bestAlgorithm = algorithm
			bestResult = result
		}
	}

	if bestResult == nil {
		return "", nil, fmt.Errorf("no working compression algorithm found")
	}

	return bestAlgorithm, bestResult, nil
}

// GetFastestAlgorithm returns the algorithm with the fastest compression speed
func (e *CompressionEngine) GetFastestAlgorithm(data []byte) (CompressionAlgorithm, *CompressionResult, error) {
	results := e.BenchmarkAll(data)

	var fastestAlgorithm CompressionAlgorithm
	var fastestResult *CompressionResult
	fastestSpeed := 0.0

	for algorithm, result := range results {
		if result.Error != nil {
			continue
		}
		if result.CompressionSpeed > fastestSpeed {
			fastestSpeed = result.CompressionSpeed
			fastestAlgorithm = algorithm
			fastestResult = result
		}
	}

	if fastestResult == nil {
		return "", nil, fmt.Errorf("no working compression algorithm found")
	}

	return fastestAlgorithm, fastestResult, nil
}

// Compressor implementations

type GzipCompressor struct{}

func (g *GzipCompressor) Compress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	writer := gzip.NewWriter(&buf)
	if _, err := writer.Write(data); err != nil {
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (g *GzipCompressor) Decompress(data []byte) ([]byte, error) {
	reader, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	return io.ReadAll(reader)
}

func (g *GzipCompressor) Name() string { return "gzip" }

type ZlibCompressor struct{}

func (z *ZlibCompressor) Compress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	writer := zlib.NewWriter(&buf)
	if _, err := writer.Write(data); err != nil {
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (z *ZlibCompressor) Decompress(data []byte) ([]byte, error) {
	reader, err := zlib.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	return io.ReadAll(reader)
}

func (z *ZlibCompressor) Name() string { return "zlib" }

type SnappyCompressor struct{}

func (s *SnappyCompressor) Compress(data []byte) ([]byte, error) {
	return snappy.Encode(nil, data), nil
}

func (s *SnappyCompressor) Decompress(data []byte) ([]byte, error) {
	return snappy.Decode(nil, data)
}

func (s *SnappyCompressor) Name() string { return "snappy" }

type ZstdCompressor struct{}

func (z *ZstdCompressor) Compress(data []byte) ([]byte, error) {
	return zstd.Compress(nil, data)
}

func (z *ZstdCompressor) Decompress(data []byte) ([]byte, error) {
	return zstd.Decompress(nil, data)
}

func (z *ZstdCompressor) Name() string { return "zstd" }

type BrotliCompressor struct{}

func (b *BrotliCompressor) Compress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	writer := brotli.NewWriter(&buf)
	if _, err := writer.Write(data); err != nil {
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (b *BrotliCompressor) Decompress(data []byte) ([]byte, error) {
	reader := brotli.NewReader(bytes.NewReader(data))
	return io.ReadAll(reader)
}

func (b *BrotliCompressor) Name() string { return "brotli" }

type XzCompressor struct{}

func (x *XzCompressor) Compress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	writer, err := xz.NewWriter(&buf)
	if err != nil {
		return nil, err
	}
	if _, err := writer.Write(data); err != nil {
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (x *XzCompressor) Decompress(data []byte) ([]byte, error) {
	reader, err := xz.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	return io.ReadAll(reader)
}

func (x *XzCompressor) Name() string { return "xz" }

type PgzipCompressor struct{}

func (p *PgzipCompressor) Compress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	writer, err := pgzip.NewWriterLevel(&buf, pgzip.BestCompression)
	if err != nil {
		return nil, err
	}
	if _, err := writer.Write(data); err != nil {
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (p *PgzipCompressor) Decompress(data []byte) ([]byte, error) {
	reader, err := pgzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	return io.ReadAll(reader)
}

func (p *PgzipCompressor) Name() string { return "pgzip" }

type GozstdCompressor struct{}

func (g *GozstdCompressor) Compress(data []byte) ([]byte, error) {
	compressed := gozstd.Compress(nil, data)
	return compressed, nil
}

func (g *GozstdCompressor) Decompress(data []byte) ([]byte, error) {
	decompressed, err := gozstd.Decompress(nil, data)
	return decompressed, err
}

func (g *GozstdCompressor) Name() string { return "gozstd" }

// GetAlgorithm returns a specific algorithm by name
func (e *CompressionEngine) GetAlgorithm(algorithm CompressionAlgorithm) (Compressor, bool) {
	compressor, exists := e.algorithms[algorithm]
	return compressor, exists
}
