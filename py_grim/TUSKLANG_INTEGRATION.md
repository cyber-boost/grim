# TuskLang Integration for Grim Web Application

## Overview

This document describes the integration of the official TuskLang Python SDK (`tusktsk`) with the Grim web application. The integration provides seamless access to TuskLang configuration, functions, and operators through both programmatic APIs and REST endpoints.

## Architecture

### Core Components

1. **GrimTuskIntegration** (`grim_core/tusktsk.py`)
   - Main integration layer between Grim and TuskLang
   - Uses the official `tusktsk` PyPI package
   - Handles configuration loading, parsing, and management
   - Provides fallback mechanisms when TuskLang is unavailable

2. **GrimTuskAPI** (`grim_core/tusktsk.py`)
   - API wrapper for TuskLang operations
   - Provides async interface for web operations
   - Handles error handling and response formatting

3. **TuskLang Routes** (`grim_web/tusktsk_routes.py`)
   - FastAPI router with REST endpoints
   - Comprehensive API for configuration management
   - Built-in validation and error handling

4. **Web Application** (`grim_web/app.py`)
   - Main FastAPI application with TuskLang integration
   - CORS middleware for cross-origin requests
   - Global exception handling

## Features

### Configuration Management
- Load configuration from `peanut.tsk` files
- Get/set configuration values by section and key
- Retrieve entire configuration sections
- Fallback to Grim configuration when TuskLang is unavailable

### Function Execution
- Execute TuskLang functions with arguments
- Support for both positional and keyword arguments
- Error handling and result validation

### Operator Support
- Execute TuskLang operators (@cache, @query, @metrics, etc.)
- Async operation support
- Context-aware execution

### Database Integration
- Retrieve database configuration from TuskLang
- Support for multiple database types (SQLite, PostgreSQL, MongoDB)
- Connection pooling and SSL configuration

### Security Features
- JWT secret management
- Encryption key handling
- App key configuration

### UI Configuration
- Theme management
- Asset optimization settings
- Responsive design configuration

## API Endpoints

### Status and Health
- `GET /tusktsk/status` - Get TuskLang integration status
- `GET /tusktsk/info` - Get detailed TuskLang package information
- `GET /tusktsk/health` - Health check for TuskLang integration

### Configuration Management
- `GET /tusktsk/config/{section}` - Get entire configuration section
- `GET /tusktsk/config/{section}/{key}` - Get specific configuration value
- `POST /tusktsk/config/{section}/{key}` - Set configuration value
- `GET /tusktsk/sections` - List all available sections

### Function and Operator Execution
- `POST /tusktsk/function` - Execute TuskLang function
- `POST /tusktsk/operator` - Execute TuskLang operator

### Specialized Configuration
- `GET /tusktsk/database` - Get database configuration
- `GET /tusktsk/security` - Get security configuration
- `GET /tusktsk/ui` - Get UI configuration

### File Operations
- `POST /tusktsk/save` - Save configuration to file
- `POST /tusktsk/load` - Load configuration from file

## Installation

### Quick Installation
```bash
cd py_grim
./install_tusktsk.sh
```

### Manual Installation
```bash
# Install the official tusktsk package
pip install tusktsk>=2.0.3

# Install other dependencies
pip install -r requirements.txt

# Test the integration
python test_simple.py
```

## Usage Examples

### Programmatic Usage

```python
from grim_core.tusktsk import get_tusk_integration, get_tusk_api

# Get integration instance
tusk = get_tusk_integration()

# Get configuration value
db_type = tusk.get_tusk_config('database', 'type', 'sqlite')

# Set configuration value
tusk.set_tusk_config('app', 'debug', True)

# Get entire section
db_config = tusk.get_tusk_section('database')

# Execute function
result = tusk.execute_tusk_function('utils', 'format_date', '2024-01-01')

# Get detailed information
info = tusk.get_tusk_info()
print(f"TuskLang version: {info['version']}")

# Async API usage
async def example():
    api = get_tusk_api()
    result = await api.get_config('database', 'host')
    return result
```

### REST API Usage

```bash
# Get TuskLang status
curl http://localhost:8000/tusktsk/status

# Get detailed TuskLang information
curl http://localhost:8000/tusktsk/info

# Get database configuration
curl http://localhost:8000/tusktsk/database

# Set configuration value
curl -X POST http://localhost:8000/tusktsk/config/app/debug \
  -H "Content-Type: application/json" \
  -d "true"

# Execute function
curl -X POST http://localhost:8000/tusktsk/function \
  -H "Content-Type: application/json" \
  -d '{
    "section": "utils",
    "key": "format_date",
    "args": ["2024-01-01"],
    "kwargs": {}
  }'
```

## Configuration

### TuskLang Package
The integration uses the official `tusktsk` package from PyPI:
- Package: `tusktsk>=2.0.3`
- Source: PyPI (https://pypi.org/project/tusktsk/)
- Features: Full TuskLang SDK with async support

### Peanut.tsk Loading
The integration attempts to load configuration from `peanut.tsk` files in the following order:
1. Current directory
2. Parent directories (up to 3 levels)
3. System-wide locations

### Fallback Configuration
When TuskLang is unavailable, the integration falls back to Grim's native configuration system.

## Error Handling

### Graceful Degradation
- TuskLang features are disabled when SDK is unavailable
- Fallback to Grim configuration system
- Clear error messages and logging

### API Error Responses
All API endpoints return consistent error responses:
```json
{
  "success": false,
  "data": {},
  "error": "Error description"
}
```

### Logging
- Comprehensive logging at all levels
- Error tracking and debugging information
- Performance metrics

## Testing

### Quick Test
```bash
python test_simple.py
```

### Comprehensive Testing
```bash
python test_tusktsk_integration.py
```

### Test Coverage
The integration includes comprehensive tests for:
- SDK availability and initialization
- Configuration operations
- Function and operator execution
- API endpoints
- Async operations
- Error handling

### Test Results
Test results are saved to `test_results.json` with detailed information about each test.

## Performance Considerations

### Caching
- TuskLang configuration is cached after initial load
- API responses are optimized for minimal latency
- Database connections are pooled

### Async Operations
- All API operations are async-compatible
- Non-blocking I/O for better performance
- Concurrent request handling

### Memory Management
- Efficient memory usage for large configurations
- Automatic cleanup of temporary resources
- Garbage collection optimization

## Security

### Input Validation
- All API inputs are validated using Pydantic models
- SQL injection prevention
- XSS protection

### Authentication
- JWT-based authentication support
- Secure key management
- Session handling

### Data Protection
- Encryption for sensitive configuration
- Secure file operations
- Audit logging

## Troubleshooting

### Common Issues

1. **tusktsk Package Not Found**
   ```bash
   pip install tusktsk>=2.0.3
   ```

2. **Configuration Loading Failed**
   - Check file permissions
   - Verify peanut.tsk syntax
   - Review error logs

3. **API Endpoints Not Responding**
   - Check server status
   - Verify CORS configuration
   - Review network connectivity

### Debug Mode
Enable debug logging by setting the log level to DEBUG in your configuration.

### Support
For issues and questions:
1. Check the test results
2. Review error logs
3. Verify configuration syntax
4. Test with minimal configuration

## Package Information

### Official Package Details
- **Name**: tusktsk
- **Version**: >=2.0.3
- **Source**: PyPI
- **Description**: Official TuskLang Python SDK
- **Features**: Configuration parsing, function execution, operator support, database adapters, async support

### Version Compatibility
- Python: 3.8+
- FastAPI: 0.104.1+
- Pydantic: 2.5.0+

## Future Enhancements

### Planned Features
- Real-time configuration updates
- WebSocket support for live updates
- Advanced caching strategies
- Performance monitoring
- Configuration validation schemas

### Integration Opportunities
- Database migration tools
- Configuration backup/restore
- Multi-environment support
- CI/CD integration

## Conclusion

The TuskLang integration provides a robust, feature-rich interface between the Grim web application and the official TuskLang Python SDK. With comprehensive error handling, performance optimization, and extensive testing, it ensures reliable operation in production environments.

The integration leverages the official `tusktsk` package from PyPI, ensuring compatibility and reliability with the latest TuskLang features and updates.

For more information, refer to:
- [TuskLang Documentation](https://tusklang.org)
- [tusktsk PyPI Package](https://pypi.org/project/tusktsk/)
- Grim project documentation 