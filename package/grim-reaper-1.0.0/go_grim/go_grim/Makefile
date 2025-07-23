# Go Grim - Performance-Critical Components Makefile

# Variables
BINARY_DIR=bin
CMD_DIR=cmd
INTERNAL_DIR=internal
PKG_DIR=pkg
TEST_DIR=tests
BENCH_DIR=benchmarks

# Build flags
LDFLAGS=-ldflags "-X main.Version=$(shell git describe --tags --always --dirty) -X main.BuildTime=$(shell date -u '+%Y-%m-%d_%H:%M:%S')"
BUILD_FLAGS=-trimpath -ldflags="-s -w"

# Go commands
GO=go
GOBUILD=$(GO) build
GOTEST=$(GO) test
GOBENCH=$(GO) test -bench=.
GOVET=$(GO) vet
GOFMT=gofmt
GOLINT=golangci-lint

# Applications
APPS=deduplication compression scanner chunker transfer

.PHONY: all build clean test benchmark vet fmt lint setup help

# Default target
all: build

# Setup development environment
setup:
	@echo "Setting up Go Grim development environment..."
	$(GO) mod download
	$(GO) mod tidy
	@echo "Installing development tools..."
	$(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "Setup complete!"

# Build all applications
build: $(APPS)

# Build individual applications
$(APPS): %: $(BINARY_DIR)/%

$(BINARY_DIR)/%: $(CMD_DIR)/%/main.go
	@echo "Building $@..."
	@mkdir -p $(BINARY_DIR)
	$(GOBUILD) $(LDFLAGS) -o $@ ./$(CMD_DIR)/$*

# Build with optimizations for release
build-release: LDFLAGS += $(BUILD_FLAGS)
build-release: build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BINARY_DIR)
	$(GO) clean -cache -testcache

# Run all tests
test:
	@echo "Running tests..."
	$(GOTEST) -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run specific test
test-%:
	@echo "Running tests for $*..."
	$(GOTEST) -v ./$*

# Run benchmarks
benchmark:
	@echo "Running benchmarks..."
	$(GOBENCH) ./$(BENCH_DIR)/...

# Run specific benchmark
bench-%:
	@echo "Running benchmark for $*..."
	$(GOBENCH) ./$(BENCH_DIR)/$*_bench.go

# Run go vet
vet:
	@echo "Running go vet..."
	$(GOVET) ./...

# Format code
fmt:
	@echo "Formatting code..."
	$(GOFMT) -w -s .

# Run linter
lint:
	@echo "Running linter..."
	$(GOLINT) run ./...

# Install applications
install: build
	@echo "Installing applications..."
	cp $(BINARY_DIR)/* /usr/local/bin/

# Uninstall applications
uninstall:
	@echo "Uninstalling applications..."
	rm -f /usr/local/bin/grim-*

# Run performance tests
perf-test:
	@echo "Running performance tests..."
	$(GOTEST) -v -bench=. -benchmem ./$(TEST_DIR)/performance_test.go

# Generate documentation
docs:
	@echo "Generating documentation..."
	$(GO) doc -all ./pkg/grim

# Check for security vulnerabilities
security:
	@echo "Checking for security vulnerabilities..."
	$(GO) list -json -deps ./... | nancy sleuth

# Docker build
docker-build:
	@echo "Building Docker image..."
	docker build -t grim-system/go-grim:latest .

# Docker run
docker-run:
	@echo "Running Docker container..."
	docker run -it --rm grim-system/go-grim:latest

# Development workflow
dev: fmt vet lint test

# Pre-commit checks
pre-commit: fmt vet lint test

# CI/CD pipeline
ci: clean build test-coverage benchmark

# Release build
release: clean build-release test-coverage
	@echo "Creating release artifacts..."
	tar -czf grim-go-release-$(shell git describe --tags --always).tar.gz $(BINARY_DIR)/*

# Help
help:
	@echo "Available targets:"
	@echo "  setup          - Setup development environment"
	@echo "  build          - Build all applications"
	@echo "  build-release  - Build with optimizations"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Run all tests"
	@echo "  test-coverage  - Run tests with coverage"
	@echo "  benchmark      - Run all benchmarks"
	@echo "  vet            - Run go vet"
	@echo "  fmt            - Format code"
	@echo "  lint           - Run linter"
	@echo "  install        - Install applications"
	@echo "  uninstall      - Uninstall applications"
	@echo "  perf-test      - Run performance tests"
	@echo "  docs           - Generate documentation"
	@echo "  security       - Check for vulnerabilities"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-run     - Run Docker container"
	@echo "  dev            - Development workflow"
	@echo "  pre-commit     - Pre-commit checks"
	@echo "  ci             - CI/CD pipeline"
	@echo "  release        - Create release"
	@echo "  help           - Show this help"

# Individual application targets
deduplication: $(BINARY_DIR)/deduplication
compression: $(BINARY_DIR)/compression
scanner: $(BINARY_DIR)/scanner
chunker: $(BINARY_DIR)/chunker
transfer: $(BINARY_DIR)/transfer

# Test individual applications
test-deduplication: test-internal/deduplication
test-compression: test-internal/compression
test-scanner: test-internal/scanner
test-chunker: test-internal/chunking
test-transfer: test-internal/network

# Benchmark individual applications
bench-deduplication: bench-deduplication
bench-compression: bench-compression
bench-scanner: bench-scanner
bench-chunker: bench-chunking
bench-transfer: bench-transfer 