.PHONY: build test clean benchmark install lint format help build-scanner build-transfer build-config build-all-tools

# Build variables
BINARY_NAME=grim-compression
SCANNER_NAME=grim-scanner
TRANSFER_NAME=grim-transfer
CONFIG_NAME=grim-config
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
build-all-tools: build build-scanner build-transfer build-config
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

# Build the config tool
build-config:
	@echo "Building ${CONFIG_NAME} for ${GOOS}/${GOARCH}..."
	@mkdir -p ${BUILD_DIR}
	${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${CONFIG_NAME} ./cmd/config

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
	# Config tool
	GOOS=linux GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${CONFIG_NAME}-linux-amd64 ./cmd/config
	GOOS=linux GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${CONFIG_NAME}-linux-arm64 ./cmd/config
	GOOS=darwin GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${CONFIG_NAME}-darwin-amd64 ./cmd/config
	GOOS=darwin GOARCH=arm64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${CONFIG_NAME}-darwin-arm64 ./cmd/config
	GOOS=windows GOARCH=amd64 ${GO} build ${LDFLAGS} -o ${BUILD_DIR}/${CONFIG_NAME}-windows-amd64.exe ./cmd/config

# Test all packages
test:
	@echo "Running tests..."
	${GO} test -v ./...

# Run benchmarks
benchmark:
	@echo "Running benchmarks..."
	${GO} test -bench=. -benchmem ./...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf ${BUILD_DIR}
	${GO} clean

# Install tools to GOPATH/bin
install: build-all-tools
	@echo "Installing tools..."
	${GO} install ./cmd/compression
	${GO} install ./cmd/scanner
	${GO} install ./cmd/transfer
	${GO} install ./cmd/config

# Lint code
lint:
	@echo "Running linter..."
	golangci-lint run

# Format code
format:
	@echo "Formatting code..."
	${GO} fmt ./...

# Development helpers
dev-setup:
	@echo "Setting up development environment..."
	${GO} mod download
	${GO} mod tidy

# Docker build
docker-build:
	@echo "Building Docker image..."
	docker build -t grim-tools .

# Help
help:
	@echo "Available targets:"
	@echo "  build              Build compression tool"
	@echo "  build-scanner      Build scanner tool"
	@echo "  build-transfer     Build transfer tool"
	@echo "  build-config       Build config tool"
	@echo "  build-all-tools    Build all tools"
	@echo "  build-all          Build for multiple platforms"
	@echo "  test               Run tests"
	@echo "  benchmark          Run benchmarks"
	@echo "  clean              Clean build artifacts"
	@echo "  install            Install tools to GOPATH/bin"
	@echo "  lint               Run linter"
	@echo "  format             Format code"
	@echo "  dev-setup          Set up development environment"
	@echo "  docker-build       Build Docker image"
	@echo "  help               Show this help"

# Quality checks
quality: format lint test
	@echo "Quality checks completed!"

# Release preparation
release: clean quality build-all
	@echo "Release artifacts prepared!"

# Quick development build
quick: build-all-tools
	@echo "Quick development build completed!"

# Continuous integration target
ci: dev-setup quality build-all
	@echo "CI pipeline completed!"

# File watching for development (requires entr)
watch:
	@echo "Watching for changes..."
	find . -name "*.go" | entr -r make quick

# Show version information
version:
	@echo "Version: ${VERSION}"
	@echo "Build Time: ${BUILD_TIME}"

# Create build directory
build-dir:
	@mkdir -p ${BUILD_DIR}

# Check Go environment
check-env:
	@echo "Go version: $(shell ${GO} version)"
	@echo "GOOS: ${GOOS}"
	@echo "GOARCH: ${GOARCH}"
	@echo "GOPATH: $(shell ${GO} env GOPATH)"
	@echo "GOROOT: $(shell ${GO} env GOROOT)"

# Dependencies check
check-deps:
	@echo "Checking dependencies..."
	${GO} mod verify
	${GO} mod download

# Security scan (requires gosec)
security-scan:
	@echo "Running security scan..."
	gosec ./...

# Generate documentation
docs:
	@echo "Generating documentation..."
	${GO} doc -all ./...

# Profile build
profile:
	@echo "Profiling build..."
	${GO} build -gcflags="-m" ./cmd/compression

# Cross-compile check
cross-compile-check:
	@echo "Checking cross-compilation..."
	GOOS=linux GOARCH=amd64 ${GO} build -o /dev/null ./cmd/compression
	GOOS=darwin GOARCH=amd64 ${GO} build -o /dev/null ./cmd/compression
	GOOS=windows GOARCH=amd64 ${GO} build -o /dev/null ./cmd/compression
	@echo "Cross-compilation check passed!"

# Vendor dependencies
vendor:
	@echo "Vendoring dependencies..."
	${GO} mod vendor

# Update dependencies
update-deps:
	@echo "Updating dependencies..."
	${GO} get -u ./...
	${GO} mod tidy

# Size analysis
size-analysis: build-all-tools
	@echo "Binary size analysis:"
	@ls -lh ${BUILD_DIR}/

# Coverage report
coverage:
	@echo "Generating coverage report..."
	${GO} test -coverprofile=coverage.out ./...
	${GO} tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html" 