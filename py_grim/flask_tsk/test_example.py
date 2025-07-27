#!/usr/bin/env python3
"""
Example Flask application using Flask-TSK
Demonstrates basic usage and features
"""

from flask import Flask, render_template_string, jsonify, request
from flask_tsk import FlaskTSK, get_tsk, tsk_config, tsk_section, tsk_function
import os

# Create Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['DEBUG'] = True

# Initialize Flask-TSK
tsk = FlaskTSK(app)

# Sample TuskLang configuration for testing
SAMPLE_CONFIG = """
[database]
type = "postgresql"
host = "localhost"
port = 5432
name = "testdb"
username = "testuser"
password = os.environ.get('TEST_PASSWORD', 'test-password-change-in-production')

[security]
encryption_key = "test-encryption-key-123"
jwt_secret = "test-jwt-secret-456"

[ui]
theme = "dark"
component_cache = true
minify_assets = true

[utils]
format_date_fujsen = \"\"\"
def format_date(date_str):
    from datetime import datetime
    try:
        dt = datetime.strptime(date_str, '%Y-%m-%d')
        return dt.strftime('%B %d, %Y')
    except:
        return date_str
\"\"\"

[math]
add_fujsen = \"\"\"
lambda a, b: a + b
\"\"\"
"""

# Create sample config file
def create_sample_config():
    """Create a sample TuskLang configuration file"""
    config_path = 'sample_config.tsk'
    with open(config_path, 'w') as f:
        f.write(SAMPLE_CONFIG)
    return config_path

# Routes
@app.route('/')
def index():
    """Main page with TuskLang integration examples"""
    template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Flask-TSK Example</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
            .success { background-color: #d4edda; border-color: #c3e6cb; }
            .error { background-color: #f8d7da; border-color: #f5c6cb; }
            .info { background-color: #d1ecf1; border-color: #bee5eb; }
            code { background-color: #f8f9fa; padding: 2px 4px; border-radius: 3px; }
            pre { background-color: #f8f9fa; padding: 10px; border-radius: 5px; overflow-x: auto; }
        </style>
    </head>
    <body>
        <h1>Flask-TSK Example Application</h1>
        
        <div class="section info">
            <h2>TuskLang Status</h2>
            <p><strong>Available:</strong> {{ tsk_available }}</p>
            <p><strong>Version:</strong> {{ tsk_version }}</p>
            <p><strong>Initialized:</strong> {{ tsk.is_available() if tsk else False }}</p>
        </div>
        
        <div class="section">
            <h2>Configuration Examples</h2>
            <p><strong>Database Type:</strong> {{ tsk_config('database', 'type', 'sqlite') }}</p>
            <p><strong>Database Host:</strong> {{ tsk_config('database', 'host', 'localhost') }}</p>
            <p><strong>UI Theme:</strong> {{ tsk_config('ui', 'theme', 'light') }}</p>
        </div>
        
        <div class="section">
            <h2>Section Examples</h2>
            {% set db_config = tsk_section('database') %}
            {% if db_config %}
                <h3>Database Configuration:</h3>
                <ul>
                    <li>Type: {{ db_config.type }}</li>
                    <li>Host: {{ db_config.host }}</li>
                    <li>Port: {{ db_config.port }}</li>
                    <li>Name: {{ db_config.name }}</li>
                </ul>
            {% else %}
                <p>No database configuration found</p>
            {% endif %}
        </div>
        
        <div class="section">
            <h2>Function Examples</h2>
            <p><strong>Formatted Date:</strong> {{ tsk_function('utils', 'format_date', '2024-01-15') }}</p>
            <p><strong>Math Addition:</strong> {{ tsk_function('math', 'add_fujsen', 5, 3) }}</p>
        </div>
        
        <div class="section">
            <h2>API Endpoints</h2>
            <ul>
                <li><a href="/tsk/status">Status</a> - Get TuskLang status</li>
                <li><a href="/tsk/config/database">Database Config</a> - Get database configuration</li>
                <li><a href="/tsk/config/ui">UI Config</a> - Get UI configuration</li>
                <li><a href="/tsk/sections">Sections</a> - List all sections</li>
                <li><a href="/tsk/health">Health</a> - Health check</li>
            </ul>
        </div>
        
        <div class="section">
            <h2>Test Functions</h2>
            <form method="POST" action="/test-function">
                <label>Section: <input type="text" name="section" value="utils"></label><br>
                <label>Key: <input type="text" name="key" value="format_date"></label><br>
                <label>Args (comma-separated): <input type="text" name="args" value="2024-01-15"></label><br>
                <input type="submit" value="Execute Function">
            </form>
        </div>
        
        <div class="section">
            <h2>Set Configuration</h2>
            <form method="POST" action="/set-config">
                <label>Section: <input type="text" name="section" value="app"></label><br>
                <label>Key: <input type="text" name="key" value="debug"></label><br>
                <label>Value: <input type="text" name="value" value="true"></label><br>
                <input type="submit" value="Set Config">
            </form>
        </div>
    </body>
    </html>
    """
    return render_template_string(template)

@app.route('/api/status')
def api_status():
    """API endpoint to get TuskLang status"""
    tsk_instance = get_tsk()
    if tsk_instance:
        return jsonify({
            'success': True,
            'data': tsk_instance.get_status()
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Flask-TSK not initialized'
        })

@app.route('/api/config/<section>')
def api_config_section(section):
    """API endpoint to get configuration section"""
    tsk_instance = get_tsk()
    if tsk_instance:
        data = tsk_instance.get_section(section)
        return jsonify({
            'success': True,
            'data': {
                'section': section,
                'data': data
            }
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Flask-TSK not initialized'
        })

@app.route('/test-function', methods=['POST'])
def test_function():
    """Test function execution"""
    tsk_instance = get_tsk()
    if not tsk_instance:
        return jsonify({'error': 'Flask-TSK not initialized'})
    
    section = request.form.get('section', 'utils')
    key = request.form.get('key', 'format_date')
    args_str = request.form.get('args', '')
    
    # Parse args
    args = []
    if args_str:
        args = [arg.strip() for arg in args_str.split(',')]
    
    try:
        result = tsk_instance.execute_function(section, key, *args)
        return jsonify({
            'success': True,
            'result': result,
            'section': section,
            'key': key,
            'args': args
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/set-config', methods=['POST'])
def set_config():
    """Set configuration value"""
    tsk_instance = get_tsk()
    if not tsk_instance:
        return jsonify({'error': 'Flask-TSK not initialized'})
    
    section = request.form.get('section', 'app')
    key = request.form.get('key', 'debug')
    value = request.form.get('value', 'true')
    
    # Convert string values to appropriate types
    if value.lower() in ('true', 'false'):
        value = value.lower() == 'true'
    elif value.isdigit():
        value = int(value)
    elif value.replace('.', '').isdigit():
        value = float(value)
    
    try:
        success = tsk_instance.set_config(section, key, value)
        return jsonify({
            'success': success,
            'section': section,
            'key': key,
            'value': value
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/load-sample')
def load_sample_config():
    """Load sample configuration"""
    tsk_instance = get_tsk()
    if not tsk_instance:
        return jsonify({'error': 'Flask-TSK not initialized'})
    
    try:
        config_path = create_sample_config()
        success = tsk_instance.load_config(config_path)
        
        # Clean up
        if os.path.exists(config_path):
            os.remove(config_path)
        
        return jsonify({
            'success': success,
            'message': 'Sample configuration loaded' if success else 'Failed to load sample configuration'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

if __name__ == '__main__':
    print("Starting Flask-TSK Example Application...")
    print("Visit http://localhost:5000 to see the example")
    print("API endpoints available at /tsk/*")
    app.run(debug=True, host='0.0.0.0', port=5000) 