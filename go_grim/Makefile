.PHONY: build test clean benchmark install lint format help build-scanner build-transfer build-all-tools

# Build variables
BINARY_NAME=grim-compression
SCANNER_NAME=grim-scanner
TRANSFER_NAME=grim-transfer
BUILD_DIR=build
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
LDFLAGS=-ldflags "-X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME}"

# Go variables
GO=go
GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)

# Default target
all: build-all-tools

# Build all tools
build-all-tools: build build-scanner build-transfer
	@echo "All tools built successfully!"

# Build the compression tool
build:
	@echo "Building ${BINARY_NAME} for ${GOOS}/${GOARCH}..."
	@mkdir -p ${BUILD_DIR}
	${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME} ./cmd/compression

# Build the scanner tool
build-scanner:
	@echo "Building ${SCANNER_NAME} for ${GOOS}/${GOARCH}..."
	@mkdir -p ${BUILD_DIR}
	${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${SCANNER_NAME} ./cmd/scanner

# Build the transfer tool
build-transfer:
	@echo "Building ${TRANSFER_NAME} for ${GOOS}/${GOARCH}..."
	@mkdir -p ${BUILD_DIR}
	${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${TRANSFER_NAME} ./cmd/transfer

# Build for multiple platforms
build-all: clean
	@echo "Building for multiple platforms..."
	@mkdir -p ${BUILD_DIR}
	# Compression tool
	GOOS=linux GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-linux-amd64 ./cmd/compression
	GOOS=linux GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-linux-arm64 ./cmd/compression
	GOOS=darwin GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-darwin-amd64 ./cmd/compression
	GOOS=darwin GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-darwin-arm64 ./cmd/compression
	GOOS=windows GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-windows-amd64.exe ./cmd/compression
	# Scanner tool
	GOOS=linux GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${SCANNER_NAME}-linux-amd64 ./cmd/scanner
	GOOS=linux GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${SCANNER_NAME}-linux-arm64 ./cmd/scanner
	GOOS=darwin GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${SCANNER_NAME}-darwin-amd64 ./cmd/scanner
	GOOS=darwin GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${SCANNER_NAME}-darwin-arm64 ./cmd/scanner
	GOOS=windows GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${SCANNER_NAME}-windows-amd64.exe ./cmd/scanner
	# Transfer tool
	GOOS=linux GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${TRANSFER_NAME}-linux-amd64 ./cmd/transfer
	GOOS=linux GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${TRANSFER_NAME}-linux-arm64 ./cmd/transfer
	GOOS=darwin GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${TRANSFER_NAME}-darwin-amd64 ./cmd/transfer
	GOOS=darwin GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${TRANSFER_NAME}-darwin-arm64 ./cmd/transfer
	GOOS=windows GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${TRANSFER_NAME}-windows-amd64.exe ./cmd/transfer

# Run tests
test:
	@echo "Running tests..."
	${GO} test -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	${GO} test -v -coverprofile=coverage.out ./...
	${GO} tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run benchmarks
benchmark:
	@echo "Running benchmarks..."
	${GO} test -bench=. -benchmem ./...

# Run compression benchmarks
benchmark-compression: build
	@echo "Running compression benchmarks..."
	./${BUILD_DIR}/${BINARY_NAME} -benchmark -iterations 5 -json

# Run scanner benchmarks
benchmark-scanner: build-scanner
	@echo "Running scanner benchmarks..."
	./${BUILD_DIR}/${SCANNER_NAME} -path . -workers 8 -output scanner-benchmark.json

# Run transfer benchmarks
benchmark-transfer: build-transfer
	@echo "Running transfer benchmarks..."
	@echo "Note: Transfer benchmarks require network connectivity"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	${GO} mod download
	${GO} mod tidy

# Install all binaries
install: build-all-tools
	@echo "Installing all tools..."
	cp ${BUILD_DIR}/${BINARY_NAME} /usr/local/bin/
	cp ${BUILD_DIR}/${SCANNER_NAME} /usr/local/bin/
	cp ${BUILD_DIR}/${TRANSFER_NAME} /usr/local/bin/

# Run linter
lint:
	@echo "Running linter..."
	golangci-lint run

# Format code
format:
	@echo "Formatting code..."
	${GO} fmt ./...
	${GO} vet ./...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf ${BUILD_DIR}
	rm -f coverage.out coverage.html
	rm -f scanner-benchmark.json

# Run the compression tool
run: build
	@echo "Running ${BINARY_NAME}..."
	./${BUILD_DIR}/${BINARY_NAME}

# Run the scanner tool
run-scanner: build-scanner
	@echo "Running ${SCANNER_NAME}..."
	./${BUILD_DIR}/${SCANNER_NAME} -path . -verbose

# Run the transfer tool
run-transfer: build-transfer
	@echo "Running ${TRANSFER_NAME}..."
	@echo "Usage: ./${BUILD_DIR}/${TRANSFER_NAME} -source <source> -dest <destination>"

# Development mode with hot reload
dev:
	@echo "Starting development mode..."
	@if command -v air > /dev/null; then \
		air; \
	else \
		echo "Air not found. Install with: go install github.com/cosmtrek/air@latest"; \
		${GO} run ./cmd/compression; \
	fi

# Create release
release: clean build-all
	@echo "Creating release..."
	@mkdir -p release
	# Compression tool
	@cd ${BUILD_DIR} && tar -czf ../release/${BINARY_NAME}-${VERSION}-linux-amd64.tar.gz ${BINARY_NAME}-linux-amd64
	@cd ${BUILD_DIR} && tar -czf ../release/${BINARY_NAME}-${VERSION}-linux-arm64.tar.gz ${BINARY_NAME}-linux-arm64
	@cd ${BUILD_DIR} && tar -czf ../release/${BINARY_NAME}-${VERSION}-darwin-amd64.tar.gz ${BINARY_NAME}-darwin-amd64
	@cd ${BUILD_DIR} && tar -czf ../release/${BINARY_NAME}-${VERSION}-darwin-arm64.tar.gz ${BINARY_NAME}-darwin-arm64
	@cd ${BUILD_DIR} && zip ../release/${BINARY_NAME}-${VERSION}-windows-amd64.zip ${BINARY_NAME}-windows-amd64.exe
	# Scanner tool
	@cd ${BUILD_DIR} && tar -czf ../release/${SCANNER_NAME}-${VERSION}-linux-amd64.tar.gz ${SCANNER_NAME}-linux-amd64
	@cd ${BUILD_DIR} && tar -czf ../release/${SCANNER_NAME}-${VERSION}-linux-arm64.tar.gz ${SCANNER_NAME}-linux-arm64
	@cd ${BUILD_DIR} && tar -czf ../release/${SCANNER_NAME}-${VERSION}-darwin-amd64.tar.gz ${SCANNER_NAME}-darwin-amd64
	@cd ${BUILD_DIR} && tar -czf ../release/${SCANNER_NAME}-${VERSION}-darwin-arm64.tar.gz ${SCANNER_NAME}-darwin-arm64
	@cd ${BUILD_DIR} && zip ../release/${SCANNER_NAME}-${VERSION}-windows-amd64.zip ${SCANNER_NAME}-windows-amd64.exe
	# Transfer tool
	@cd ${BUILD_DIR} && tar -czf ../release/${TRANSFER_NAME}-${VERSION}-linux-amd64.tar.gz ${TRANSFER_NAME}-linux-amd64
	@cd ${BUILD_DIR} && tar -czf ../release/${TRANSFER_NAME}-${VERSION}-linux-arm64.tar.gz ${TRANSFER_NAME}-linux-arm64
	@cd ${BUILD_DIR} && tar -czf ../release/${TRANSFER_NAME}-${VERSION}-darwin-amd64.tar.gz ${TRANSFER_NAME}-darwin-amd64
	@cd ${BUILD_DIR} && tar -czf ../release/${TRANSFER_NAME}-${VERSION}-darwin-arm64.tar.gz ${TRANSFER_NAME}-darwin-arm64
	@cd ${BUILD_DIR} && zip ../release/${TRANSFER_NAME}-${VERSION}-windows-amd64.zip ${TRANSFER_NAME}-windows-amd64.exe
	@echo "Release packages created in release/ directory"

# Performance testing
perf-test: build build-scanner build-transfer
	@echo "Running performance tests..."
	@echo "=== Compression Tool ==="
	./${BUILD_DIR}/${BINARY_NAME} -benchmark -iterations 3
	@echo ""
	@echo "=== Scanner Tool ==="
	./${BUILD_DIR}/${SCANNER_NAME} -path . -workers 8 -output scanner-perf.json
	@echo ""
	@echo "=== Transfer Tool ==="
	@echo "Transfer tool requires network connectivity for testing"

# Security scan
security:
	@echo "Running security scan..."
	gosec ./...

# Generate documentation
docs:
	@echo "Generating documentation..."
	godoc -http=:6060 &
	@echo "Documentation available at http://localhost:6060"
	@echo "Press Ctrl+C to stop"

# Quick test of all tools
quick-test: build-all-tools
	@echo "Testing all tools..."
	@echo "=== Testing Compression ==="
	./${BUILD_DIR}/${BINARY_NAME} -help
	@echo "=== Testing Scanner ==="
	./${BUILD_DIR}/${SCANNER_NAME} -help
	@echo "=== Testing Transfer ==="
	./${BUILD_DIR}/${TRANSFER_NAME} -help
	@echo "All tools built and tested successfully!"

# Show help
help:
	@echo "Available targets:"
	@echo "  build              - Build compression tool"
	@echo "  build-scanner      - Build scanner tool"
	@echo "  build-transfer     - Build transfer tool"
	@echo "  build-all-tools    - Build all tools"
	@echo "  build-all          - Build for multiple platforms"
	@echo "  test               - Run tests"
	@echo "  test-coverage      - Run tests with coverage report"
	@echo "  benchmark          - Run Go benchmarks"
	@echo "  benchmark-compression - Run compression benchmarks"
	@echo "  benchmark-scanner  - Run scanner benchmarks"
	@echo "  benchmark-transfer - Run transfer benchmarks"
	@echo "  deps               - Install dependencies"
	@echo "  install            - Install all binaries"
	@echo "  lint               - Run linter"
	@echo "  format             - Format code"
	@echo "  clean              - Clean build artifacts"
	@echo "  run                - Run compression tool"
	@echo "  run-scanner        - Run scanner tool"
	@echo "  run-transfer       - Run transfer tool"
	@echo "  dev                - Development mode with hot reload"
	@echo "  release            - Create release packages"
	@echo "  perf-test          - Run performance tests"
	@echo "  security           - Run security scan"
	@echo "  docs               - Generate documentation"
	@echo "  quick-test         - Quick test of all tools"
	@echo "  help               - Show this help" 