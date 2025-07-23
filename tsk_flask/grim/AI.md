# 🤖 AI Agent Guide: Using Flask-TSK

## Overview

Flask-TSK is a revolutionary Flask extension that integrates TuskLang database operations, provides a comprehensive theme system, and offers scalable authentication. This guide explains how AI agents should interact with and extend Flask-TSK.

## 🚀 Quick Start for AI Agents

### 1. **Understanding the Repository Structure**

```
flask-tsk-repo/
├── tsk_flask/                    # Main Flask-TSK package
│   ├── __init__.py              # Flask extension initialization
│   ├── themes.py                # Theme management system
│   ├── theme_components.py      # Pre-built UI components
│   ├── theme_config.py          # Theme configuration
│   ├── theme_showcase.py        # Demo application
│   ├── herd/                    # Authentication system (optional)
│   │   ├── __init__.py          # Main Herd class
│   │   ├── services/            # Authentication services
│   │   └── events/              # Event system
│   ├── components/              # UI components
│   │   ├── navigation.py        # Navigation components
│   │   ├── forms.py             # Form components
│   │   └── ui.py                # UI utilities
│   ├── templates/               # Jinja2 templates
│   │   ├── base.html            # Base template
│   │   └── index.html           # Example template
│   └── themes/                  # CSS/JS theme files
│       ├── css/                 # Theme stylesheets
│       └── js/                  # Theme JavaScript
├── setup.py                     # Package configuration
├── requirements.txt             # Dependencies
├── .gitignore                   # Git ignore rules
├── README.md                    # Documentation
├── AI.md                        # This file
└── examples/                    # Example applications
```

### 2. **Core Principles for AI Agents**

#### **Always Use TuskLang Integration**
- Every component should connect to TuskLang database
- Use `tsk.get_config()` for configuration
- Use `tsk.execute_function()` for business logic
- Leverage TuskLang's caching and performance features

#### **Theme-First Development**
- All UI components should work with the theme system
- Use pre-built components from `theme_components.py`
- Support all 13 available themes
- Make components responsive and accessible

#### **Performance Optimization**
- Use the Turbo template engine for 10x faster rendering
- Implement intelligent caching with TuskLang
- Optimize database queries
- Use async operations where appropriate

## 🎨 Working with Themes

### **Theme System Architecture**

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

### **Creating Theme-Aware Components**

```python
from tsk_flask.theme_components import theme_components

# Render pre-built components
header = theme_components.render_header_modern(nav_data, user_data)
footer = theme_components.render_footer_modern(stats_data, activity_data)
widget = theme_components.render_dashboard_widget(widget_data)
```

### **Theme Configuration**

```python
from tsk_flask.theme_config import theme_config

# Get theme configuration
config = theme_config.get_theme_config('modern')

# Set custom theme properties
theme_config.set_theme_config('modern', {
    'primary_color': '#ff6b6b',
    'font_family': 'Roboto, sans-serif',
    'border_radius': '12px'
})

# Generate CSS variables
css_vars = theme_config.generate_css_variables('modern')
```

## 🗄️ TuskLang Database Integration

### **Configuration Management**

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

### **Function Execution**

```python
# Execute TuskLang functions
result = tsk.execute_function('utils', 'format_date', '2024-01-01')
user_count = tsk.execute_function('database', 'count_users', [])

# With arguments
formatted_text = tsk.execute_function('text', 'format', ['Hello World', 'uppercase'])
```

### **Template Integration**

```html
<!-- In Jinja2 templates -->
<p>Database: {{ tsk_config('database', 'type', 'sqlite') }}</p>
<p>Formatted Date: {{ tsk_function('utils', 'format_date', '2024-01-01') }}</p>
<p>User Count: {{ tsk_function('database', 'count_users', []) }}</p>
```

## 🔐 Authentication with Herd (Optional)

### **Basic Authentication**

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

### **User Registration**

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

### **Password Management**

```python
# Request password reset
Herd.request_password_reset('user@example.com')

# Reset password
Herd.reset_password('reset_token', 'new_password')

# Update password
Herd.update_password('current_password', 'new_password')
```

### **Magic Links**

```python
# Generate magic link
link_result = Herd.generate_magic_link(user_id, {
    'purpose': 'login',
    'redirect': '/dashboard/',
    'valid_days': 1
})

# Send magic link via email
Herd.send_magic_link(user_id, {
    'purpose': 'login',
    'subject': 'Your Magic Login Link'
})

# Login with magic link
Herd.login_with_magic_link('magic_token')
```

## 🎯 Best Practices for AI Agents

### **1. Component Development**

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

### **2. Database Integration**

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

### **3. Theme Integration**

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

### **4. Performance Optimization**

```python
# Use Turbo template engine for performance
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

## 🔧 Configuration Guidelines

### **TuskLang Configuration File (peanu.tsk)**

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

### **Flask Configuration**

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

## 📊 Performance Monitoring

### **Performance Metrics**

```python
from tsk_flask.performance_engine import get_performance_stats

# Get performance statistics
stats = get_performance_stats()

print(f"Cache hit rate: {stats['cache_hit_rate']:.1f}%")
print(f"Renders per second: {stats['renders_per_second']:.0f}")
print(f"Average render time: {stats['avg_render_time']:.2f}ms")
```

### **Theme Performance**

```python
# Benchmark theme rendering
from tsk_flask.performance_benchmark import PerformanceBenchmark

benchmark = PerformanceBenchmark()
results = benchmark.run_comprehensive_benchmark()

print(f"Modern theme: {results['modern']['avg_time']:.2f}ms")
print(f"Dark theme: {results['dark']['avg_time']:.2f}ms")
```

## 🧪 Testing Guidelines

### **Unit Testing**

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
    
    # Test component rendering
    header = theme_manager.render_header('modern')
    assert 'header-modern' in header
```

### **Integration Testing**

```python
def test_herd_authentication(app):
    """Test Herd authentication"""
    from tsk_flask.herd import Herd
    
    # Test user creation
    user_data = {
        'email': 'test@example.com',
        'password': 'test_password',
        'first_name': 'Test',
        'last_name': 'User'
    }
    
    result = Herd.create_user(user_data)
    assert result['success'] == True
    
    # Test login
    success = Herd.login('test@example.com', 'test_password')
    assert success == True
    
    # Test user retrieval
    user = Herd.user()
    assert user['email'] == 'test@example.com'
```

## 🚀 Deployment Guidelines

### **Production Setup**

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

### **Environment Variables**

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

## 📚 Learning Resources

### **Key Files to Study**

1. **`tsk_flask/__init__.py`** - Main Flask extension
2. **`tsk_flask/themes.py`** - Theme management system
3. **`tsk_flask/theme_components.py`** - Pre-built components
4. **`tsk_flask/herd/__init__.py`** - Authentication system
5. **`tsk_flask/performance_engine.py`** - Performance optimization

### **Example Applications**

1. **`tsk_flask/theme_showcase.py`** - Theme demonstration
2. **`tsk_flask/test_example.py`** - Basic usage example
3. **`examples/`** - Additional example applications

### **Documentation**

1. **`README.md`** - Main documentation
2. **`THEME_SYSTEM_SUMMARY.md`** - Theme system overview
3. **`INTEGRATION_GUIDE.md`** - Integration guide
4. **`PERFORMANCE_REVOLUTION.md`** - Performance features

## 🎯 Success Metrics

### **For AI Agents Working with Flask-TSK**

1. **Theme Integration**: All components work with all 13 themes
2. **TuskLang Usage**: Every feature uses TuskLang database integration
3. **Performance**: Components render in <5ms with Turbo engine
4. **Responsiveness**: All components work on mobile and desktop
5. **Accessibility**: Components meet WCAG guidelines
6. **Security**: Authentication follows security best practices
7. **Documentation**: All code is well-documented with examples

### **Quality Checklist**

- [ ] Components work with all themes
- [ ] TuskLang database integration implemented
- [ ] Performance optimized with Turbo engine
- [ ] Responsive design implemented
- [ ] Accessibility features included
- [ ] Security measures implemented
- [ ] Comprehensive testing added
- [ ] Documentation updated
- [ ] Example usage provided

## 🔮 Future Development

### **Planned Features**

1. **Machine Learning Integration**: AI-powered theme optimization
2. **Real-time Collaboration**: Live theme editing
3. **Advanced Analytics**: User behavior tracking
4. **Cloud Integration**: Multi-cloud deployment support
5. **Microservices**: Service-oriented architecture

### **Contribution Guidelines**

1. **Follow TuskLang Integration**: Always use TuskLang for data operations
2. **Theme-First Development**: Make all components theme-aware
3. **Performance Focus**: Optimize for speed and efficiency
4. **Security First**: Implement security best practices
5. **Documentation**: Provide clear documentation and examples

---

**Flask-TSK** - Making AI agents more powerful with TuskLang integration, beautiful themes, and scalable authentication! 🚀🐘 