# Scythe API - Storage Management & License Validation

A comprehensive RESTful API for storage management and license validation with full Stripe integration and tier-based access control.

## Features

- **Storage Management**: Provider management, allocations, usage monitoring, and policies
- **License System**: Validation, generation, and management with tier-based access
- **Vendor Management**: Complete vendor lifecycle with commission tracking
- **Product Management**: Product catalog with pricing and analytics
- **Authentication & Authorization**: JWT tokens and API keys with role-based permissions
- **Rate Limiting**: Tier-based rate limiting and usage enforcement
- **Webhooks**: Real-time notifications for all operations
- **Comprehensive Error Handling**: Standardized error responses and logging

## Quick Start

### Installation

```bash
cd scythe/api
pip install -r requirements.txt
```

### Configuration

Set environment variables:

```bash
export SCYTHE_SECRET_KEY="your-secret-key"
export SCYTHE_JWT_SECRET="your-jwt-secret"
export SCYTHE_DEBUG="True"
export SCYTHE_LOG_LEVEL="INFO"
```

### Running the API

```bash
python -m scythe.api.app
```

The API will be available at `http://localhost:5000`

## API Endpoints

### Authentication

All endpoints require authentication via:
- **Bearer Token**: `Authorization: Bearer <jwt_token>`
- **API Key**: `Authorization: ApiKey <api_key>`

### Storage Management

#### Storage Providers
- `GET /scythe/storage/providers` - List all storage providers
- `POST /scythe/storage/providers` - Create new storage provider

#### Storage Allocations
- `GET /scythe/storage/allocations` - List storage allocations
- `POST /scythe/storage/allocations` - Create storage allocation
- `PUT /scythe/storage/allocations/<id>` - Update storage allocation

#### Storage Usage
- `GET /scythe/storage/usage` - Get storage usage statistics
- `POST /scythe/storage/usage` - Update storage usage

#### Storage Policies
- `GET /scythe/storage/policies` - List storage policies
- `POST /scythe/storage/policies` - Create storage policy

### License Management

#### License Validation
- `POST /scythe/validate` - Validate license key

#### License Generation
- `POST /scythe/license/generate` - Generate new license
- `GET /scythe/license/<key>` - Get license details
- `PUT /scythe/license/<key>` - Update license
- `DELETE /scythe/license/<key>` - Revoke license
- `GET /scythe/licenses` - List all licenses

### Vendor Management

- `GET /scythe/vendor` - List all vendors
- `POST /scythe/vendor` - Create vendor
- `GET /scythe/vendor/<id>` - Get vendor details
- `PUT /scythe/vendor/<id>` - Update vendor
- `DELETE /scythe/vendor/<id>` - Delete vendor
- `POST /scythe/vendor/<id>/regenerate-api-key` - Regenerate API key
- `GET /scythe/vendor/<id>/commission` - Get commission info
- `POST /scythe/vendor/<id>/payout` - Process payout

### Product Management

- `GET /scythe/product` - List all products
- `POST /scythe/product` - Create product
- `GET /scythe/product/<id>` - Get product details
- `PUT /scythe/product/<id>` - Update product
- `DELETE /scythe/product/<id>` - Delete product
- `GET /scythe/product/<id>/pricing` - Get pricing info
- `GET /scythe/product/<id>/licenses` - Get product licenses
- `GET /scythe/product/<id>/analytics` - Get analytics

### System Endpoints

- `GET /scythe/health` - Health check
- `GET /scythe/docs` - API documentation

## Request Examples

### Create Storage Provider

```bash
curl -X POST http://localhost:5000/scythe/storage/providers \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Amazon S3",
    "type": "s3",
    "config": {
      "bucket": "my-bucket",
      "region": "us-east-1"
    }
  }'
```

### Validate License

```bash
curl -X POST http://localhost:5000/scythe/validate \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "license_key": "ABC123DEF456GHI789JKL012MNO345PQR678"
  }'
```

### Create Vendor

```bash
curl -X POST http://localhost:5000/scythe/vendor \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Example Vendor",
    "email": "vendor@example.com",
    "commission_rate": 15.0
  }'
```

## Response Format

All API responses follow a consistent format:

### Success Response
```json
{
  "message": "Operation successful",
  "data": { ... },
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Error Response
```json
{
  "error": {
    "type": "ValidationError",
    "message": "Invalid request data",
    "status_code": 400,
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

## Rate Limiting

Rate limits are applied based on user tier:

- **FREE**: 50 requests/hour
- **PRO**: 200 requests/hour
- **MASTER**: 500 requests/hour
- **REAPER**: 1000 requests/hour

## Webhooks

The API sends webhooks for various events:

- `storage.operation` - Storage operations
- `license.operation` - License operations
- `payment.operation` - Payment operations
- `vendor.operation` - Vendor operations
- `product.operation` - Product operations
- `system.error` - System errors

### Webhook Format
```json
{
  "event": "storage.operation",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "operation": "upload",
    "user_id": "user123",
    "file_path": "/path/to/file",
    "file_size": 1024,
    "provider": "s3"
  }
}
```

## Database Schema

The API uses SQLite with the following main tables:

- `storage_providers` - Storage provider configurations
- `storage_allocations` - User storage allocations
- `storage_usage` - File usage tracking
- `storage_policies` - Storage policies
- `licenses` - License keys and metadata
- `vendors` - Vendor information
- `products` - Product catalog
- `api_keys` - API key management
- `webhooks` - Webhook configurations

## Error Codes

- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `422` - Unprocessable Entity
- `429` - Too Many Requests
- `500` - Internal Server Error
- `503` - Service Unavailable

## Development

### Running Tests

```bash
python -m pytest tests/
```

### Code Style

The project follows PEP 8 style guidelines.

### Logging

Logs are written to both console and file (if configured). Log levels:
- `DEBUG` - Detailed debugging information
- `INFO` - General information
- `WARNING` - Warning messages
- `ERROR` - Error messages

## Security

- All API keys are hashed before storage
- JWT tokens have configurable expiration
- Rate limiting prevents abuse
- Input validation on all endpoints
- CORS configuration for cross-origin requests

## Deployment

### Production Considerations

1. Use a production WSGI server (Gunicorn, uWSGI)
2. Set up proper SSL/TLS certificates
3. Configure environment variables securely
4. Use a production database (PostgreSQL, MySQL)
5. Set up monitoring and alerting
6. Configure backup strategies

### Docker Deployment

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 5000

CMD ["python", "-m", "scythe.api.app"]
```

## Support

For API support and documentation, refer to the `/scythe/docs` endpoint or contact the development team. 