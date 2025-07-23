# 🐘 **FLASK-TSK COMPLETE INTEGRATION GUIDE**

## **Overview**
Flask-TSK is a revolutionary Flask extension that integrates TuskLang database operations, provides a comprehensive theme system, scalable authentication, and 13 specialized elephant systems. This guide covers complete integration for AI agents.

## **🚀 Quick Start**

### **1. Basic Flask-TSK Setup**

```python
from flask import Flask
from tsk_flask import FlaskTSK, render_tsk_template, get_tsk_config

# Initialize Flask app
app = Flask(__name__)

# Initialize Flask-TSK with simple renderer
flask_tsk = FlaskTSK(app)

# Your routes here
@app.route('/')
def home():
    return render_tsk_template("""
    <h1>Welcome to Flask-TSK</h1>
    <p>Database: $database_type</p>
    <p>Version: $tsk_version</p>
    """, {
        'database_type': get_tsk_config('database', 'type', 'sqlite'),
        'tsk_version': '2.0.5-simple'
    })
```

### **2. TuskLang Template Syntax**

```html
<!-- Use $extends for template inheritance -->
$extends "public/layout.html"

$content
    <h1>$page_title</h1>
    <p>$page_description</p>
    
    <!-- Nested object access -->
    <p>User: $user.name ($user.email)</p>
    
    <!-- Conditionals -->
    $if user.is_admin
        <div class="admin-panel">Admin controls</div>
    $endif
    
    <!-- Loops -->
    $for item in items
        <div class="item">$item.name</div>
    $endfor
$endcontent
```

## **🔧 Core Components**

### **1. Simple TSK Renderer**
- **File**: `simple_tsk_renderer.py`
- **Purpose**: Processes TuskLang syntax (`$variable`, `$extends`, `$content`)
- **Features**: Template inheritance, variable substitution, conditionals

### **2. Performance Engine**
- **File**: `performance_engine.py`
- **Purpose**: Turbo template rendering for 10x faster performance
- **Features**: Caching, optimization, async rendering

### **3. Mother Database**
- **File**: `mother_db.py`
- **Purpose**: Central error tracking and installation management
- **Features**: Installation registration, error reporting, admin dashboard

### **4. Herd Authentication**
- **File**: `herd_auth.py`
- **Purpose**: User authentication and session management
- **Features**: Login/logout, registration, password reset, magic links

## **🐘 Elephant System Integration**

### **Available Elephants:**
1. **Herd** - Authentication system
2. **Babar** - Content Management System
3. **Dumbo** - HTTP client
4. **Elmer** - Theme generator
5. **Happy** - Image processor
6. **Heffalump** - Search engine
7. **Horton** - Job processor
8. **Jumbo** - File upload
9. **Kaavan** - System monitor
10. **Koshik** - Audio system
11. **Satao** - Security system
12. **Stampy** - Package manager
13. **Tantor** - Database manager

### **Integration Example:**

```python
from tsk_flask.herd.elephants.babar import get_babar
from tsk_flask.herd.elephants.dumbo import get_dumbo
from tsk_flask.herd.elephants.elmer import get_elmer

# Initialize elephants
babar = get_babar()
dumbo = get_dumbo()
elmer = get_elmer(claude_api_key="your-key")

@app.route('/content/create', methods=['POST'])
def create_content():
    data = request.get_json()
    result = babar.create_story(data)
    return jsonify(result)

@app.route('/api/request', methods=['POST'])
def make_request():
    data = request.get_json()
    response = dumbo.get(data['url'])
    return jsonify(response)

@app.route('/theme/generate', methods=['POST'])
def generate_theme():
    data = request.get_json()
    theme = elmer.generate_claude_theme(data['prompt'])
    return jsonify(theme)
```

## **📊 Mother Database Integration**

### **Installation Registration:**
```python
from mother_db import MotherDBClient

# Initialize client
mother_client = MotherDBClient(
    base_url="https://rp.grim.so",
    installation_id="your-unique-id"
)

# Register installation
mother_client.register_installation({
    "hostname": socket.gethostname(),
    "ip_address": "auto-detected",
    "os_info": platform.platform(),
    "grim_version": "1.0.0",
    "installation_date": datetime.utcnow().isoformat() + "Z",
    "contact_email": "admin@example.com"
})
```

### **Error Reporting:**
```python
# Report errors to mother database
mother_client.report_error(
    error_type="runtime_error",
    error_message="Failed to backup files",
    severity="high",
    context={
        "script": "backup.sh",
        "line": "42",
        "command": "rsync -av /source /dest"
    }
)
```

### **Health Checks:**
```python
# Send periodic health checks
mother_client.report_error(
    error_type="health_check",
    error_message="System healthy",
    severity="low",
    context={
        "status": "online",
        "last_backup": datetime.utcnow().isoformat() + "Z",
        "disk_usage": "75%"
    }
)
```

## **🎨 Theme System Integration**

### **Theme Management:**
```python
from tsk_flask.themes import theme_manager, get_theme_manager

# Get theme manager
manager = get_theme_manager()

# Render theme components
header = manager.render_header('modern')
footer = manager.render_footer('modern')
navigation = manager.render_navigation('modern')

# Switch themes
manager.set_theme('dark')

# Get available themes
themes = manager.get_available_themes()
```

### **Creating Theme-Aware Components:**
```python
from tsk_flask.theme_components import theme_components

# Render pre-built components
header = theme_components.render_header_modern(nav_data, user_data)
footer = theme_components.render_footer_modern(stats_data, activity_data)
widget = theme_components.render_dashboard_widget(widget_data)
```

## **🔐 Authentication with Herd**

### **Basic Authentication:**
```python
from tsk_flask.herd import Herd, get_herd

# User login
success = Herd.login('user@example.com', 'password', remember=True)

# Check authentication
if Herd.check():
    user = Herd.user()
    user_id = Herd.id()

# User logout
Herd.logout()
```

### **User Registration:**
```python
# Create new user
user_data = {
    'email': 'newuser@example.com',
    'password': 'secure_password',
    'first_name': 'John',
    'last_name': 'Doe'
}
result = Herd.create_user(user_data)

# Activate account
activation = Herd.activate('activation_token')
```

### **Magic Links:**
```python
# Generate magic link
link_result = Herd.generate_magic_link(user_id, {
    'purpose': 'login',
    'redirect': '/dashboard/',
    'valid_days': 1
})

# Login with magic link
Herd.login_with_magic_link('magic_token')
```

## **🗄️ TuskLang Database Integration**

### **Configuration Management:**
```python
from tsk_flask import get_tsk

tsk = get_tsk()

# Get configuration
db_type = tsk.get_config('database', 'type', 'sqlite')
debug_mode = tsk.get_config('app', 'debug', False)

# Set configuration
tsk.set_config('app', 'debug', True)

# Get entire section
db_config = tsk.get_section('database')
```

### **Function Execution:**
```python
# Execute TuskLang functions
result = tsk.execute_function('utils', 'format_date', '2024-01-01')
user_count = tsk.execute_function('database', 'count_users', [])

# With arguments
formatted_text = tsk.execute_function('text', 'format', ['Hello World', 'uppercase'])
```

## **🚀 Performance Optimization**

### **Turbo Template Engine:**
```python
from tsk_flask.performance_engine import render_turbo_template

def render_complex_dashboard(data):
    """Render complex dashboard with Turbo engine"""
    
    template = """
    <div class="dashboard">
        {% for widget in widgets %}
            <div class="widget widget-{{ widget.type }}">
                <h3>{{ widget.title }}</h3>
                <div class="widget-content">{{ widget.content }}</div>
            </div>
        {% endfor %}
    </div>
    """
    
    return render_turbo_template(template, {'widgets': data['widgets']})
```

### **Performance Monitoring:**
```python
from tsk_flask.performance_engine import get_performance_stats

# Get performance statistics
stats = get_performance_stats()

print(f"Cache hit rate: {stats['cache_hit_rate']:.1f}%")
print(f"Renders per second: {stats['renders_per_second']:.0f}")
print(f"Average render time: {stats['avg_render_time']:.2f}ms")
```

## **🔧 Configuration Guidelines**

### **TuskLang Configuration File (peanu.tsk):**
```ini
[app]
name = "My Flask-TSK App"
debug = false
secret_key = "your-secret-key"

[database]
type = "postgresql"
host = "localhost"
port = 5432
name = "myapp"
username = "user"
password = "pass"

[herd]
enabled = true
session_lifetime = 7200
max_login_attempts = 5
lockout_duration = 900

[themes]
default_theme = "modern"
auto_load = true
cache_duration = 300

[ui]
component_cache = true
minify_assets = true
responsive_breakpoints = "sm:640px,md:768px,lg:1024px,xl:1280px"
```

### **Flask Configuration:**
```python
app.config.update({
    'TSK_CONFIG_PATH': '/path/to/peanu.tsk',
    'TSK_AUTO_LOAD': True,
    'TSK_ENABLE_BLUEPRINT': True,
    'TSK_ENABLE_CONTEXT': True,
    'HERD_ENABLED': True,
    'THEME_DEFAULT': 'modern',
    'THEME_AUTO_LOAD': True
})
```

## **🧪 Testing Guidelines**

### **Unit Testing:**
```python
import pytest
from flask import Flask
from tsk_flask import FlaskTSK

@pytest.fixture
def app():
    app = Flask(__name__)
    app.config['TESTING'] = True
    app.config['SECRET_KEY'] = 'test-key'
    
    tsk = FlaskTSK(app)
    return app

def test_tsk_integration(app):
    """Test TuskLang integration"""
    with app.test_client() as client:
        response = client.get('/tsk/status')
        assert response.status_code == 200
        data = response.get_json()
        assert 'available' in data['data']

def test_theme_system(app):
    """Test theme system"""
    from tsk_flask.themes import theme_manager
    
    # Test theme switching
    assert theme_manager.set_theme('modern')
    assert theme_manager.get_current_theme() == 'modern'
```

## **🚀 Deployment Guidelines**

### **Production Setup:**
```python
# Production configuration
app.config.update({
    'TSK_AUTO_LOAD': True,
    'TSK_ENABLE_BLUEPRINT': True,
    'HERD_ENABLED': True,
    'THEME_DEFAULT': 'modern',
    'THEME_AUTO_LOAD': True,
    'PERFORMANCE_MODE': True,
    'CACHE_ENABLED': True
})
```

### **Environment Variables:**
```bash
# Required environment variables
export TSK_CONFIG_PATH="/path/to/peanu.tsk"
export FLASK_ENV="production"
export SECRET_KEY="your-production-secret-key"

# Optional environment variables
export HERD_SESSION_LIFETIME="7200"
export THEME_DEFAULT="modern"
export PERFORMANCE_MODE="true"
```

## **🎯 Best Practices for AI Agents**

### **1. Component Development:**
```python
# Always make components theme-aware
def create_user_card(user_data, theme_name='modern'):
    """Create a user card component that works with all themes"""
    
    # Get theme-specific styling
    theme_config = theme_config.get_theme_config(theme_name)
    
    # Use pre-built components
    card = theme_components.render_card_component({
        'title': user_data['name'],
        'content': user_data['bio'],
        'actions': [
            {'text': 'View Profile', 'url': f'/user/{user_data["id"]}'},
            {'text': 'Send Message', 'url': f'/message/{user_data["id"]}'}
        ]
    })
    
    return card
```

### **2. Database Integration:**
```python
# Always use TuskLang for database operations
def get_user_dashboard_data(user_id):
    """Get user dashboard data with TuskLang integration"""
    
    tsk = get_tsk()
    
    # Get user data
    user = tsk.execute_function('users', 'get_by_id', [user_id])
    
    # Get user statistics
    stats = tsk.execute_function('analytics', 'get_user_stats', [user_id])
    
    # Get recent activity
    activity = tsk.execute_function('activity', 'get_recent', [user_id, 10])
    
    return {
        'user': user,
        'stats': stats,
        'activity': activity
    }
```

### **3. Theme Integration:**
```python
# Make all pages theme-aware
def render_dashboard_page(user_id, theme_name=None):
    """Render dashboard page with theme support"""
    
    # Get data
    data = get_user_dashboard_data(user_id)
    
    # Get theme manager
    manager = get_theme_manager()
    
    # Render with theme
    return manager.render_layout(
        theme_name=theme_name,
        content=render_dashboard_content(data),
        page_title="Dashboard",
        meta_description="User dashboard"
    )
```

## **🔍 Integration Checklist**

### **For All Elephant Integrations:**
- [ ] Elephant imported and initialized correctly
- [ ] Routes created with proper error handling
- [ ] Input validation and sanitization implemented
- [ ] Security measures in place
- [ ] Performance monitoring configured
- [ ] Comprehensive testing completed
- [ ] Documentation updated
- [ ] Error handling and logging implemented
- [ ] User feedback and notifications added
- [ ] Resource cleanup and management configured

### **Quality Standards:**
- [ ] Components work with all themes
- [ ] TuskLang database integration implemented
- [ ] Performance optimized with Turbo engine
- [ ] Responsive design implemented
- [ ] Accessibility features included
- [ ] Security measures implemented
- [ ] Comprehensive testing added
- [ ] Documentation updated
- [ ] Example usage provided

## **📚 Learning Resources**

### **Key Files to Study:**
1. **`tsk_flask/__init__.py`** - Main Flask extension
2. **`tsk_flask/simple_tsk_renderer.py`** - TuskLang template processing
3. **`tsk_flask/performance_engine.py`** - Performance optimization
4. **`tsk_flask/mother_db.py`** - Mother database system
5. **`tsk_flask/herd_auth.py`** - Authentication system

### **Documentation:**
1. **`grim/flask.md`** - Elephant integration prompts
2. **`grim/AI.md`** - AI agent guide
3. **`TUSKLANG_INTEGRATION_PROMPT.md`** - TuskLang integration details
4. **`agent_integration_prompts.md`** - Mother database integration

## **🎯 Success Metrics**

### **For AI Agents Working with Flask-TSK:**
1. **Theme Integration**: All components work with all 13 themes
2. **TuskLang Usage**: Every feature uses TuskLang database integration
3. **Performance**: Components render in <5ms with Turbo engine
4. **Responsiveness**: All components work on mobile and desktop
5. **Accessibility**: Components meet WCAG guidelines
6. **Security**: Authentication follows security best practices
7. **Documentation**: All code is well-documented with examples

---

**Flask-TSK** - Making AI agents more powerful with TuskLang integration, beautiful themes, scalable authentication, and 13 specialized elephant systems! 🚀🐘 