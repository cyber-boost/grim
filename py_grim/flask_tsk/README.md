# Flask-TSK

Flask extension for TuskLang integration. Provides seamless access to TuskLang configuration, functions, and operators in Flask applications.

## Features

- **Configuration Management**: Load and manage TuskLang configuration files
- **Function Execution**: Execute TuskLang functions with arguments
- **Template Integration**: Use TuskLang in Jinja2 templates
- **REST API**: Built-in API endpoints for TuskLang operations
- **Database Integration**: Retrieve database configuration from TuskLang
- **Security Features**: JWT and encryption key management
- **UI Configuration**: Theme and asset management

## Installation

```bash
pip install flask-tsk
```

Or install with database support:

```bash
pip install flask-tsk[databases]
```

## Quick Start

```python
from flask import Flask
from flask_tsk import FlaskTSK

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key'

# Initialize Flask-TSK
tsk = FlaskTSK(app)

@app.route('/')
def index():
    # Get configuration from TuskLang
    db_type = tsk.get_config('database', 'type', 'sqlite')
    return f'Database type: {db_type}'

@app.route('/execute')
def execute_function():
    # Execute a TuskLang function
    result = tsk.execute_function('utils', 'format_date', '2024-01-01')
    return f'Result: {result}'

if __name__ == '__main__':
    app.run(debug=True)
```

## Configuration

### Flask Configuration Options

```python
app.config.update({
    'TSK_CONFIG_PATH': '/path/to/config.tsk',  # Custom config path
    'TSK_AUTO_LOAD': True,                     # Auto-load peanut.tsk
    'TSK_ENABLE_BLUEPRINT': True,              # Enable API endpoints
    'TSK_ENABLE_CONTEXT': True,                # Enable template context
})
```

### TuskLang Configuration File (peanut.tsk)

```ini
[database]
type = "postgresql"
host = "localhost"
port = 5432
name = "myapp"
username = "user"
password = "pass"

[security]
encryption_key = "your-encryption-key"
jwt_secret = "your-jwt-secret"

[ui]
theme = "dark"
component_cache = true
minify_assets = true
```

## Usage

### In Flask Routes

```python
from flask_tsk import get_tsk

@app.route('/config/<section>')
def get_section(section):
    tsk = get_tsk()
    data = tsk.get_section(section)
    return jsonify(data)

@app.route('/set-config', methods=['POST'])
def set_config():
    tsk = get_tsk()
    success = tsk.set_config('app', 'debug', True)
    return jsonify({'success': success})
```

### In Jinja2 Templates

```html
<!-- Get configuration value -->
<p>Database: {{ tsk_config('database', 'type', 'sqlite') }}</p>

<!-- Get entire section -->
{% set db_config = tsk_section('database') %}
{% if db_config %}
    <p>Host: {{ db_config.host }}</p>
    <p>Port: {{ db_config.port }}</p>
{% endif %}

<!-- Execute function -->
<p>Formatted date: {{ tsk_function('utils', 'format_date', '2024-01-01') }}</p>

<!-- Check availability -->
{% if tsk_available %}
    <p>TuskLang is available (v{{ tsk_version }})</p>
{% else %}
    <p>TuskLang is not available</p>
{% endif %}
```

## API Endpoints

When enabled, Flask-TSK provides REST API endpoints:

### Status and Health
- `GET /tsk/status` - Get TuskLang integration status
- `GET /tsk/health` - Health check

### Configuration Management
- `GET /tsk/config/<section>` - Get configuration section
- `GET /tsk/config/<section>/<key>` - Get configuration value
- `POST /tsk/config/<section>/<key>` - Set configuration value
- `GET /tsk/sections` - List all sections

### Function Execution
- `POST /tsk/function` - Execute TuskLang function

### Specialized Configuration
- `GET /tsk/database` - Get database configuration
- `GET /tsk/security` - Get security configuration
- `GET /tsk/ui` - Get UI configuration

### File Operations
- `POST /tsk/save` - Save configuration to file
- `POST /tsk/load` - Load configuration from file

## API Examples

### Get Configuration

```bash
curl http://localhost:5000/tsk/config/database
```

### Set Configuration

```bash
curl -X POST http://localhost:5000/tsk/config/app/debug \
  -H "Content-Type: application/json" \
  -d "true"
```

### Execute Function

```bash
curl -X POST http://localhost:5000/tsk/function \
  -H "Content-Type: application/json" \
  -d '{
    "section": "utils",
    "key": "format_date",
    "args": ["2024-01-01"],
    "kwargs": {}
  }'
```

## Advanced Usage

### Custom Configuration Loading

```python
from flask_tsk import FlaskTSK

app = Flask(__name__)

# Initialize with custom config
tsk = FlaskTSK()
tsk.init_app(app)

# Load custom configuration file
tsk.load_config('/path/to/custom.tsk')
```

### Database Integration

```python
@app.route('/db-info')
def db_info():
    tsk = get_tsk()
    db_config = tsk.get_database_config()
    
    # Use with SQLAlchemy or other ORM
    from sqlalchemy import create_engine
    
    if db_config['type'] == 'postgresql':
        url = f"postgresql://{db_config['username']}:{db_config['password']}@{db_config['host']}:{db_config['port']}/{db_config['name']}"
        engine = create_engine(url)
        return jsonify({'status': 'connected'})
    
    return jsonify({'error': 'Unsupported database type'})
```

### Security Integration

```python
@app.route('/secure-data')
def secure_data():
    tsk = get_tsk()
    security_config = tsk.get_security_config()
    
    # Use encryption key
    encryption_key = security_config['encryption_key']
    
    # Use JWT secret
    jwt_secret = security_config['jwt_secret']
    
    return jsonify({'encrypted': True})
```

## Testing

### Unit Tests

```python
import pytest
from flask import Flask
from flask_tsk import FlaskTSK

@pytest.fixture
def app():
    app = Flask(__name__)
    app.config['TESTING'] = True
    app.config['SECRET_KEY'] = 'test-key'
    
    tsk = FlaskTSK(app)
    return app

@pytest.fixture
def client(app):
    return app.test_client()

def test_tsk_status(client):
    response = client.get('/tsk/status')
    assert response.status_code == 200
    data = response.get_json()
    assert 'available' in data['data']
```

### Integration Tests

```python
def test_tsk_config_operations(client):
    # Set configuration
    response = client.post('/tsk/config/test/key', json='value')
    assert response.status_code == 200
    
    # Get configuration
    response = client.get('/tsk/config/test/key')
    assert response.status_code == 200
    data = response.get_json()
    assert data['data']['value'] == 'value'
```

## Error Handling

Flask-TSK provides comprehensive error handling:

```python
@app.errorhandler(Exception)
def handle_tsk_error(error):
    if hasattr(error, 'tsk_error'):
        return jsonify({
            'error': 'TuskLang error',
            'message': str(error)
        }), 500
    return jsonify({
        'error': 'Internal server error',
        'message': str(error)
    }), 500
```

## Performance Considerations

- **Caching**: TuskLang configuration is cached after initial load
- **Lazy Loading**: Functions are compiled only when first executed
- **Connection Pooling**: Database connections are pooled when possible
- **Async Support**: Compatible with async Flask applications

## Security

- **Input Validation**: All API inputs are validated
- **Error Handling**: Sensitive information is not exposed in errors
- **Template Security**: Template helpers are safe for user input
- **Configuration Protection**: Sensitive config values are protected

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- **Documentation**: https://flask-tsk.readthedocs.io/
- **Issues**: https://github.com/grim-project/flask-tsk/issues
- **Discussions**: https://github.com/grim-project/flask-tsk/discussions

## Related Projects

- [TuskLang](https://tusklang.org) - The TuskLang language
- [tusktsk](https://pypi.org/project/tusktsk/) - Official TuskLang Python SDK
- [Grim](https://github.com/grim-project) - The Grim backup system 