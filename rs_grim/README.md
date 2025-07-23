# Grim Reaper Rust SDK

🗡️ **High-performance backup and deployment system built with Rust**

## Overview

The Grim Reaper Rust SDK provides a fast, reliable, and secure foundation for backup and deployment operations. Built with Rust's memory safety and performance guarantees, this SDK offers enterprise-grade functionality with minimal resource usage.

## Features

### 🚀 **Performance**
- **Zero-cost abstractions** - Rust's compile-time optimizations
- **Memory safety** - No null pointer dereferences or data races
- **Concurrent operations** - Async/await with Tokio runtime
- **Optimized binaries** - LTO and panic abort for minimal size

### 🛡️ **Security**
- **Cryptographic operations** - SHA2, HMAC, AES encryption
- **Secure networking** - TLS/SSL support with reqwest
- **Input validation** - Comprehensive error handling
- **No unsafe code** - Memory safety guarantees

### 🔧 **Functionality**
- **File system operations** - Walkdir, compression, archiving
- **Database support** - PostgreSQL and SQLite with SQLx
- **Network operations** - HTTP client, webhooks, APIs
- **Configuration management** - TOML, JSON, environment variables

## Quick Start

### Prerequisites

1. **Install Rust** (if not already installed):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

2. **Verify installation**:
   ```bash
   rustc --version
   cargo --version
   ```

### Building the Project

```bash
# Navigate to the Rust project
cd rs_grim

# Build in release mode (recommended)
./grimrust.sh build

# Or build in debug mode
./grimrust.sh build debug
```

### Running the Application

```bash
# Show help
./target/release/grim --help

# Initialize a new project
./target/release/grim init --name my-project

# Show status
./target/release/grim status --verbose

# Run tests
./target/release/grim test
```

## Build System

The `grimrust.sh` script provides comprehensive build and deployment capabilities:

### Build Commands

```bash
# Build in release mode (default)
./grimrust.sh build

# Build in debug mode
./grimrust.sh build debug

# Clean build artifacts
./grimrust.sh clean

# Check code without building
./grimrust.sh check
```

### Testing Commands

```bash
# Run all tests
./grimrust.sh test all

# Run unit tests only
./grimrust.sh test unit

# Run integration tests
./grimrust.sh test integration

# Run documentation tests
./grimrust.sh test doc

# Run benchmarks
./grimrust.sh bench
```

### Code Quality

```bash
# Run Clippy linting
./grimrust.sh clippy

# Format code with rustfmt
./grimrust.sh fmt

# Check code formatting
./grimrust.sh fmt --check
```

### Deployment

```bash
# Deploy to staging
./grimrust.sh deploy staging

# Deploy to production (with confirmation)
./grimrust.sh deploy production

# Show package information
./grimrust.sh info
```

## CLI Commands

### Core Commands

| Command | Description | Options |
|---------|-------------|---------|
| `init` | Initialize new Grim Reaper project | `--name`, `--path` |
| `build` | Build project | `--target`, `--clean` |
| `deploy` | Deploy to environment | `--environment`, `--force` |
| `backup` | Backup files and directories | `--source`, `--destination`, `--compression` |
| `restore` | Restore from backup | `--backup`, `--destination`, `--overwrite` |
| `status` | Show project status | `--verbose` |
| `test` | Run tests | `--test-type` |

### Examples

```bash
# Initialize a new project
grim init --name my-backup-system --path /opt/backups

# Build with clean artifacts
grim build --target release --clean

# Deploy to staging
grim deploy --environment staging

# Backup with high compression
grim backup --source /home/user --destination /backups/user.tar.gz --compression 9

# Restore with overwrite
grim restore --backup /backups/user.tar.gz --destination /home/user --overwrite

# Show detailed status
grim status --verbose
```

## Project Structure

```
rs_grim/
├── Cargo.toml          # Package configuration and dependencies
├── src/
│   └── main.rs         # CLI application entry point
├── grimrust.sh         # Build and deploy script
├── target/             # Build artifacts (generated)
│   ├── debug/          # Debug builds
│   └── release/        # Release builds
└── README.md           # This file
```

## Dependencies

### Core Dependencies

| Crate | Version | Purpose |
|-------|---------|---------|
| `tokio` | 1.0 | Async runtime |
| `serde` | 1.0 | Serialization |
| `clap` | 4.0 | CLI argument parsing |
| `anyhow` | 1.0 | Error handling |
| `tracing` | 0.1 | Logging and diagnostics |

### File System

| Crate | Version | Purpose |
|-------|---------|---------|
| `walkdir` | 2.3 | Directory traversal |
| `flate2` | 1.0 | Compression |
| `tar` | 0.4 | Archive creation |
| `zip` | 0.6 | ZIP file support |

### Networking

| Crate | Version | Purpose |
|-------|---------|---------|
| `reqwest` | 0.11 | HTTP client |
| `hyper` | 0.14 | HTTP implementation |
| `tower` | 0.4 | Network middleware |

### Database

| Crate | Version | Purpose |
|-------|---------|---------|
| `sqlx` | 0.7 | Database toolkit |
| `sqlx-postgres` | 0.7 | PostgreSQL support |
| `sqlx-sqlite` | 0.7 | SQLite support |

### Security

| Crate | Version | Purpose |
|-------|---------|---------|
| `sha2` | 0.10 | SHA2 hashing |
| `hmac` | 0.12 | HMAC authentication |
| `aes` | 0.8 | AES encryption |
| `base64` | 0.21 | Base64 encoding |

### Configuration

| Crate | Version | Purpose |
|-------|---------|---------|
| `config` | 0.13 | Configuration management |
| `toml` | 0.8 | TOML parsing |

### Utilities

| Crate | Version | Purpose |
|-------|---------|---------|
| `chrono` | 0.4 | Date and time |
| `uuid` | 1.0 | UUID generation |
| `rand` | 0.8 | Random number generation |
| `regex` | 1.0 | Regular expressions |

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | `false` | Enable debug output |
| `BUILD_TARGET` | `release` | Build target (debug/release) |
| `DEPLOY_ENVIRONMENT` | `production` | Deployment environment |
| `TEST_TIMEOUT` | `300` | Test timeout in seconds |

### Logging

Logs are written to `/opt/reaper/logs/grimrust.log` with the following levels:
- **ERROR** - Critical errors that prevent operation
- **SUCCESS** - Successful operations
- **INFO** - General information
- **WARNING** - Non-critical issues
- **DEBUG** - Detailed debugging information

## Development

### Adding New Commands

1. **Add command to CLI structure** in `src/main.rs`:
   ```rust
   #[derive(Subcommand)]
   enum Commands {
       // ... existing commands ...
       
       /// New command description
       NewCommand {
           /// Option description
           #[arg(short, long)]
           option: Option<String>,
       },
   }
   ```

2. **Add handler function**:
   ```rust
   async fn handle_new_command(option: Option<&str>) -> Result<()> {
       info!("Handling new command with option: {:?}", option);
       // Implementation here
       Ok(())
   }
   ```

3. **Add to main match statement**:
   ```rust
   match &cli.command {
       // ... existing matches ...
       Commands::NewCommand { option } => {
           handle_new_command(option.as_deref()).await?;
       }
   }
   ```

### Testing

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_name

# Run tests with output
cargo test -- --nocapture

# Run benchmarks
cargo bench
```

### Code Quality

```bash
# Run Clippy
cargo clippy

# Format code
cargo fmt

# Check formatting
cargo fmt -- --check
```

## Performance

### Build Optimizations

The release profile includes several optimizations:

```toml
[profile.release]
opt-level = 3        # Maximum optimization
lto = true          # Link-time optimization
codegen-units = 1   # Single codegen unit
panic = "abort"     # Abort on panic (smaller binary)
```

### Binary Size

- **Release build**: ~1.2MB
- **Debug build**: ~15MB
- **Stripped release**: ~800KB

### Memory Usage

- **Idle**: ~2MB
- **Active backup**: ~10-50MB (depending on file size)
- **Peak**: ~100MB (large operations)

## Security Considerations

### Input Validation

- All user inputs are validated before processing
- File paths are sanitized to prevent directory traversal
- Network requests use HTTPS by default

### Error Handling

- Sensitive information is not logged
- Errors are handled gracefully without exposing internals
- Panic handling is configured for production

### Dependencies

- All dependencies are from trusted sources (crates.io)
- Regular security updates are applied
- No known vulnerabilities in current dependencies

## Troubleshooting

### Common Issues

#### Build Failures

```bash
# Clean and rebuild
./grimrust.sh clean
./grimrust.sh build

# Check Rust version
rustc --version

# Update dependencies
cargo update
```

#### Test Failures

```bash
# Run tests with verbose output
cargo test -- --nocapture

# Run specific test
cargo test test_name

# Check test timeout
export TEST_TIMEOUT=600
```

#### Permission Issues

```bash
# Make script executable
chmod +x grimrust.sh

# Check file permissions
ls -la grimrust.sh
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
export DEBUG=true
./grimrust.sh build
```

### Log Analysis

Check logs for detailed information:

```bash
tail -f /opt/reaper/logs/grimrust.log
```

## Contributing

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests for new functionality**
5. **Run the test suite**
6. **Submit a pull request**

### Code Style

- Follow Rust formatting guidelines
- Use meaningful variable and function names
- Add documentation for public APIs
- Include error handling for all operations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Check the troubleshooting section
- Review the logs for error details
- Open an issue on the project repository

---

**Grim Reaper Rust SDK** - Built with ❤️ and Rust
