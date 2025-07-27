#!/bin/bash
"""
Installation script for TuskLang integration with Grim
Installs the official tusktsk package and Flask-TSK extension
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "requirements.txt" ]]; then
    print_error "This script must be run from the py_grim directory"
    exit 1
fi

print_status "Installing TuskLang integration for Grim..."

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.8"

if [[ $(echo "$PYTHON_VERSION >= $REQUIRED_VERSION" | bc -l) -eq 0 ]]; then
    print_error "Python $REQUIRED_VERSION or higher is required. Found: $PYTHON_VERSION"
    exit 1
fi

print_success "Python version check passed: $PYTHON_VERSION"

# Install tusktsk package
print_status "Installing tusktsk package..."
if pip3 install tusktsk>=2.0.3; then
    print_success "tusktsk package installed successfully"
else
    print_error "Failed to install tusktsk package"
    exit 1
fi

# Install Flask for Flask-TSK
print_status "Installing Flask for Flask-TSK..."
if pip3 install Flask>=2.0.0; then
    print_success "Flask installed successfully"
else
    print_warning "Failed to install Flask - Flask-TSK will not be available"
fi

# Install other dependencies
print_status "Installing additional dependencies..."
if pip3 install -r requirements.txt; then
    print_success "Dependencies installed successfully"
else
    print_warning "Some dependencies may not have installed correctly"
fi

# Test the Grim TuskLang integration
print_status "Testing Grim TuskLang integration..."
if python3 -c "from grim_core.tusktsk import get_tusk_integration; tusk = get_tusk_integration(); print('Grim integration test passed')"; then
    print_success "Grim TuskLang integration test passed"
else
    print_error "Grim TuskLang integration test failed"
    exit 1
fi

# Test Flask-TSK integration
print_status "Testing Flask-TSK integration..."
if python3 -c "from flask_tsk import FlaskTSK; print('Flask-TSK import test passed')"; then
    print_success "Flask-TSK integration test passed"
else
    print_warning "Flask-TSK integration test failed - Flask may not be installed"
fi

# Run comprehensive tests
print_status "Running comprehensive tests..."
if python3 test_tusktsk_integration.py; then
    print_success "All tests passed"
else
    print_warning "Some tests failed - check test_results.json for details"
fi

# Create a simple test script
cat > test_simple.py << 'EOF'
#!/usr/bin/env python3
"""
Simple test script for TuskLang integration
"""

from grim_core.tusktsk import get_tusk_integration

def main():
    print("🧪 Testing TuskLang Integration")
    print("=" * 40)
    
    # Get integration instance
    tusk = get_tusk_integration()
    
    # Check status
    status = tusk.get_tusk_status()
    print(f"TuskLang Available: {status.get('available', False)}")
    print(f"Version: {status.get('version', 'Unknown')}")
    print(f"Initialized: {status.get('initialized', False)}")
    print(f"Peanut Loaded: {status.get('peanut_loaded', False)}")
    
    # Test basic operations
    if status.get('available', False):
        print("\n✅ TuskLang integration is working!")
        
        # Test setting a value
        tusk.set_tusk_config('test', 'greeting', 'Hello from Grim!')
        
        # Test getting the value
        value = tusk.get_tusk_config('test', 'greeting')
        print(f"Test value: {value}")
        
        # Get database config
        db_config = tusk.get_database_config()
        print(f"Database type: {db_config.get('type', 'unknown')}")
        
    else:
        print("\n❌ TuskLang integration is not available")
        print("Make sure tusktsk package is installed: pip install tusktsk")

if __name__ == "__main__":
    main()
EOF

print_success "Created simple test script: test_simple.py"

# Create Flask-TSK test script
cat > test_flask_tsk.py << 'EOF'
#!/usr/bin/env python3
"""
Test script for Flask-TSK integration
"""

try:
    from flask import Flask
    from flask_tsk import FlaskTSK, get_tsk
    
    def test_flask_tsk():
        print("🧪 Testing Flask-TSK Integration")
        print("=" * 40)
        
        # Create Flask app
        app = Flask(__name__)
        app.config['SECRET_KEY'] = 'test-key'
        
        # Initialize Flask-TSK
        tsk = FlaskTSK(app)
        
        with app.app_context():
            # Get TSK instance
            tsk_instance = get_tsk()
            
            if tsk_instance:
                print("✅ Flask-TSK initialized successfully")
                
                # Test basic operations
                tsk_instance.set_config('test', 'flask_greeting', 'Hello from Flask-TSK!')
                value = tsk_instance.get_config('test', 'flask_greeting')
                print(f"Test value: {value}")
                
                # Check status
                status = tsk_instance.get_status()
                print(f"TuskLang Available: {status.get('available', False)}")
                print(f"Version: {status.get('version', 'Unknown')}")
                
                return True
            else:
                print("❌ Flask-TSK not initialized")
                return False
    
    if __name__ == "__main__":
        test_flask_tsk()
        
except ImportError as e:
    print("❌ Flask-TSK test skipped - Flask not available")
    print(f"Error: {e}")
except Exception as e:
    print(f"❌ Flask-TSK test failed: {e}")
EOF

print_success "Created Flask-TSK test script: test_flask_tsk.py"

# Make the test scripts executable
chmod +x test_simple.py
chmod +x test_flask_tsk.py

# Create installation summary
cat > INSTALLATION_SUMMARY.md << 'EOF'
# TuskLang Integration Installation Summary

## What was installed:

### Core Packages
- **tusktsk>=2.0.3** - Official TuskLang Python SDK
- **Flask>=2.0.0** - Web framework for Flask-TSK

### Grim Integration
- **grim_core.tusktsk** - TuskLang integration for Grim
- **grim_web.tusktsk_routes** - FastAPI routes for TuskLang
- **grim_web.app** - Updated FastAPI app with TuskLang integration

### Flask Extension
- **flask_tsk** - Flask extension for TuskLang integration
- **flask_tsk.blueprint** - REST API blueprint for Flask-TSK
- **flask_tsk.setup.py** - Package setup for Flask-TSK

## Test Scripts Created:
- `test_simple.py` - Basic TuskLang integration test
- `test_flask_tsk.py` - Flask-TSK integration test

## Usage Examples:

### Grim Integration
```python
from grim_core.tusktsk import get_tusk_integration

tsk = get_tusk_integration()
db_type = tsk.get_tusk_config('database', 'type', 'sqlite')
```

### Flask Integration
```python
from flask import Flask
from flask_tsk import FlaskTSK

app = Flask(__name__)
tsk = FlaskTSK(app)

@app.route('/')
def index():
    db_type = tsk.get_config('database', 'type', 'sqlite')
    return f'Database: {db_type}'
```

## API Endpoints:

### Grim FastAPI
- `GET /tusktsk/status` - TuskLang status
- `GET /tusktsk/config/{section}` - Get configuration
- `POST /tusktsk/function` - Execute function

### Flask-TSK
- `GET /tsk/status` - TuskLang status
- `GET /tsk/config/{section}` - Get configuration
- `POST /tsk/function` - Execute function

## Next Steps:
1. Run tests: `python3 test_simple.py`
2. Test Flask-TSK: `python3 test_flask_tsk.py`
3. Start Grim web server: `python3 grim_web/server.py --dev`
4. Test Flask-TSK example: `python3 flask_tsk/test_example.py`

## Documentation:
- `TUSKLANG_INTEGRATION.md` - Comprehensive integration guide
- `flask_tsk/README.md` - Flask-TSK documentation
EOF

print_success "Created installation summary: INSTALLATION_SUMMARY.md"

print_status "Installation completed!"
print_success "You can now use TuskLang integration in your Grim application"
print_status ""
print_status "Next steps:"
print_status "1. Run Grim tests: python3 test_simple.py"
print_status "2. Run Flask-TSK tests: python3 test_flask_tsk.py"
print_status "3. Start Grim web server: python3 grim_web/server.py --dev"
print_status "4. Test Flask-TSK example: python3 flask_tsk/test_example.py"
print_status "5. Check documentation: cat INSTALLATION_SUMMARY.md"
print_status ""
print_success "🎉 TuskLang integration and Flask-TSK are ready to use!" 