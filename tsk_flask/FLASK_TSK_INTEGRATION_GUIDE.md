# Flask-TSK Integration Guide

## Overview
Flask-TSK is a high-performance Flask extension that integrates TuskLang template processing using a simple TSK renderer and turbo performance engine. This guide teaches you how to use Flask-TSK effectively in your applications.

## 🚀 Quick Start

### 1. Basic Setup

```python
from flask import Flask
from tsk_flask import FlaskTSK, render_tsk_template

# Create Flask app
app = Flask(__name__)

# Initialize Flask-TSK
flask_tsk = FlaskTSK(app)

# Your routes here
@app.route('/')
def home():
    return render_tsk_template('home.tsk', {'title': 'Welcome'})
```

### 2. Template Structure

Create `.tsk` templates in your `templates/` directory:

```html
<!-- templates/home.tsk -->
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
</head>
<body>
    <h1>Welcome to $title</h1>
    
    $if user:
        <p>Hello, $user.name!</p>
        <p>Your role: $user.role</p>
    $else:
        <p>Please <a href="/login">login</a></p>
    
    $for item in items:
        <div class="item">
            <h3>$item.title</h3>
            <p>$item.description</p>
        </div>
</body>
</html>
```

## 📚 Core Concepts

### TuskLang Syntax in Templates

Flask-TSK uses TuskLang syntax with `$variable` interpolation:

```html
<!-- Variable interpolation -->
<h1>$page_title</h1>
<p>User: $user.name</p>

<!-- Conditional statements -->
$if user.is_admin:
    <div class="admin-panel">Admin Controls</div>
$else:
    <div class="user-panel">User Controls</div>

<!-- Loops -->
$for post in posts:
    <article>
        <h2>$post.title</h2>
        <p>$post.content</p>
    </article>

<!-- Nested objects -->
<p>Email: $user.contact.email</p>
<p>Phone: $user.contact.phone</p>
```

### Context Injection

Flask-TSK automatically injects useful context into all templates:

```python
# Available in all templates:
# - tsk_renderer: The TSK renderer instance
# - tsk_available: Boolean indicating TSK availability
# - tsk_version: Version string
# - turbo_engine: Performance engine instance
```

## 🔧 Advanced Usage

### 1. Custom Template Rendering

```python
from tsk_flask import render_tsk_template

@app.route('/dynamic')
def dynamic_content():
    template_content = """
    <h1>$title</h1>
    $for item in items:
        <li>$item</li>
    """
    
    context = {
        'title': 'Dynamic Content',
        'items': ['Item 1', 'Item 2', 'Item 3']
    }
    
    return render_tsk_template(template_content, context)
```

### 2. Template Filters

Flask-TSK provides custom template filters:

```python
# In your template
<p>Rendered: {{ template_content | tsk_render(context) }}</p>
<p>Value: {{ 'user.name' | tsk_value(context) }}</p>
```

### 3. Performance Optimization

```python
# Enable turbo performance engine
flask_tsk = FlaskTSK(app)

# The turbo engine automatically:
# - Compiles templates to bytecode
# - Caches compiled templates
# - Optimizes rendering performance
# - Provides memory-efficient processing
```

### 4. Error Handling

```python
@app.route('/safe-render')
def safe_render():
    try:
        return render_tsk_template('complex.tsk', complex_context)
    except Exception as e:
        # Fallback to static content
        return f"<h1>Error: {e}</h1>"
```

## 🎯 Real-World Examples

### 1. Admin Dashboard

```python
@app.route('/admin/dashboard')
@login_required
def admin_dashboard():
    stats = {
        'total_users': 1250,
        'active_users': 890,
        'total_errors': 45,
        'error_rate': '3.6%'
    }
    
    return render_tsk_template('admin/dashboard.tsk', {
        'stats': stats,
        'user': get_current_user()
    })
```

```html
<!-- templates/admin/dashboard.tsk -->
<div class="dashboard">
    <h1>Admin Dashboard</h1>
    <p>Welcome back, $user.name!</p>
    
    <div class="stats-grid">
        <div class="stat-card">
            <h3>Total Users</h3>
            <p class="stat-value">$stats.total_users</p>
        </div>
        
        <div class="stat-card">
            <h3>Active Users</h3>
            <p class="stat-value">$stats.active_users</p>
        </div>
        
        <div class="stat-card">
            <h3>Total Errors</h3>
            <p class="stat-value">$stats.total_errors</p>
        </div>
        
        <div class="stat-card">
            <h3>Error Rate</h3>
            <p class="stat-value">$stats.error_rate</p>
        </div>
    </div>
</div>
```

### 2. Data Tables

```python
@app.route('/users')
def users_list():
    users = [
        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'role': 'admin'},
        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com', 'role': 'user'},
        {'id': 3, 'name': 'Bob Johnson', 'email': 'bob@example.com', 'role': 'user'}
    ]
    
    return render_tsk_template('users/list.tsk', {'users': users})
```

```html
<!-- templates/users/list.tsk -->
<table class="users-table">
    <thead>
        <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Role</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        $for user in users:
            <tr>
                <td>$user.id</td>
                <td>$user.name</td>
                <td>$user.email</td>
                <td>
                    $if user.role == 'admin':
                        <span class="badge admin">Admin</span>
                    $else:
                        <span class="badge user">User</span>
                </td>
                <td>
                    <a href="/users/$user.id/edit">Edit</a>
                    <a href="/users/$user.id/delete">Delete</a>
                </td>
            </tr>
    </tbody>
</table>
```

### 3. Form Handling

```python
@app.route('/contact', methods=['GET', 'POST'])
def contact():
    if request.method == 'POST':
        # Process form data
        name = request.form.get('name')
        email = request.form.get('email')
        message = request.form.get('message')
        
        # Send email, save to database, etc.
        
        return render_tsk_template('contact/success.tsk', {
            'name': name,
            'message': 'Thank you for your message!'
        })
    
    return render_tsk_template('contact/form.tsk')
```

```html
<!-- templates/contact/form.tsk -->
<form method="POST" action="/contact">
    <div class="form-group">
        <label for="name">Name:</label>
        <input type="text" id="name" name="name" required>
    </div>
    
    <div class="form-group">
        <label for="email">Email:</label>
        <input type="email" id="email" name="email" required>
    </div>
    
    <div class="form-group">
        <label for="message">Message:</label>
        <textarea id="message" name="message" required></textarea>
    </div>
    
    <button type="submit">Send Message</button>
</form>
```

## 🔍 Debugging and Troubleshooting

### 1. Enable Debug Mode

```python
app.config['DEBUG'] = True
app.config['TEMPLATES_AUTO_RELOAD'] = True
```

### 2. Check TSK Availability

```python
from tsk_flask import TSK_RENDERER_AVAILABLE

if TSK_RENDERER_AVAILABLE:
    print("TSK renderer is available")
else:
    print("TSK renderer is not available")
```

### 3. Common Issues

**Template not found:**
```python
# Make sure template file exists
template_path = os.path.join(app.template_folder, 'template.tsk')
if not os.path.exists(template_path):
    print(f"Template not found: {template_path}")
```

**Variable not defined:**
```html
<!-- Use safe navigation -->
$if user and user.name:
    <p>Hello, $user.name!</p>
$else:
    <p>Hello, Guest!</p>
```

**Performance issues:**
```python
# Enable turbo engine
flask_tsk = FlaskTSK(app)

# Check if turbo engine is available
if flask_tsk.turbo_engine:
    print("Turbo engine is active")
```

## 🚀 Best Practices

### 1. Template Organization

```
templates/
├── base.tsk              # Base template
├── components/
│   ├── header.tsk        # Reusable components
│   ├── footer.tsk
│   └── sidebar.tsk
├── pages/
│   ├── home.tsk
│   ├── about.tsk
│   └── contact.tsk
└── admin/
    ├── dashboard.tsk
    └── users.tsk
```

### 2. Context Management

```python
def get_base_context():
    """Get common context for all templates"""
    return {
        'app_name': 'My App',
        'version': '1.0.0',
        'current_year': datetime.now().year
    }

@app.route('/')
def home():
    context = get_base_context()
    context.update({
        'title': 'Home',
        'user': get_current_user()
    })
    return render_tsk_template('pages/home.tsk', context)
```

### 3. Error Handling

```python
@app.errorhandler(404)
def not_found(error):
    return render_tsk_template('errors/404.tsk', {
        'error': error,
        'message': 'Page not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return render_tsk_template('errors/500.tsk', {
        'error': error,
        'message': 'Internal server error'
    }), 500
```

### 4. Security

```python
# Sanitize user input
from markupsafe import escape

@app.route('/user/<username>')
def user_profile(username):
    safe_username = escape(username)
    return render_tsk_template('user/profile.tsk', {
        'username': safe_username
    })
```

## 📊 Performance Monitoring

### 1. Template Rendering Stats

```python
from tsk_flask import get_tsk_config

config = get_tsk_config()
print(f"Renderer: {config['renderer']}")
print(f"Performance Engine: {config['performance_engine']}")
print(f"Version: {config['version']}")
```

### 2. Memory Usage

```python
import psutil
import os

def get_memory_usage():
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024  # MB

print(f"Memory usage: {get_memory_usage():.2f} MB")
```

## 🔧 Configuration

### 1. Flask Configuration

```python
app.config.update({
    'SECRET_KEY': 'your-secret-key',
    'DEBUG': False,  # Disable in production
    'TEMPLATES_AUTO_RELOAD': False,  # Disable for performance
    'SEND_FILE_MAX_AGE_DEFAULT': 3600  # Cache static files
})
```

### 2. TSK Configuration

```python
# TSK renderer configuration
tsk_config = {
    'cache_enabled': True,
    'cache_size': 1000,
    'debug_mode': False,
    'performance_mode': True
}
```

## 🎯 Integration with Mother Database

Flask-TSK integrates seamlessly with the mother database system:

```python
from mother_db import MotherDBClient

# Initialize mother database client
mother_client = MotherDBClient('https://rp.grim.so', 'your-installation-id')

@app.route('/api/status')
def api_status():
    try:
        # Report health check to mother database
        mother_client.report_error(
            error_type='health_check',
            error_message='API endpoint accessed',
            severity='low',
            context={'endpoint': '/api/status'}
        )
        
        return jsonify({'status': 'healthy'})
    except Exception as e:
        # Report error to mother database
        mother_client.report_error(
            error_type='api_error',
            error_message=str(e),
            severity='high',
            context={'endpoint': '/api/status'}
        )
        
        return jsonify({'error': str(e)}), 500
```

## 📚 Additional Resources

- [TuskLang Documentation](https://tusklang.org/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Mother Database Integration Guide](./agent_integration_prompts.md)

---

This guide covers the essential aspects of Flask-TSK integration. The system provides high-performance template rendering with TuskLang syntax, automatic optimization, and seamless integration with the mother database for error tracking and monitoring. 

## Overview
Flask-TSK is a high-performance Flask extension that integrates TuskLang template processing using a simple TSK renderer and turbo performance engine. This guide teaches you how to use Flask-TSK effectively in your applications.

## 🚀 Quick Start

### 1. Basic Setup

```python
from flask import Flask
from tsk_flask import FlaskTSK, render_tsk_template

# Create Flask app
app = Flask(__name__)

# Initialize Flask-TSK
flask_tsk = FlaskTSK(app)

# Your routes here
@app.route('/')
def home():
    return render_tsk_template('home.tsk', {'title': 'Welcome'})
```

### 2. Template Structure

Create `.tsk` templates in your `templates/` directory:

```html
<!-- templates/home.tsk -->
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
</head>
<body>
    <h1>Welcome to $title</h1>
    
    $if user:
        <p>Hello, $user.name!</p>
        <p>Your role: $user.role</p>
    $else:
        <p>Please <a href="/login">login</a></p>
    
    $for item in items:
        <div class="item">
            <h3>$item.title</h3>
            <p>$item.description</p>
        </div>
</body>
</html>
```

## 📚 Core Concepts

### TuskLang Syntax in Templates

Flask-TSK uses TuskLang syntax with `$variable` interpolation:

```html
<!-- Variable interpolation -->
<h1>$page_title</h1>
<p>User: $user.name</p>

<!-- Conditional statements -->
$if user.is_admin:
    <div class="admin-panel">Admin Controls</div>
$else:
    <div class="user-panel">User Controls</div>

<!-- Loops -->
$for post in posts:
    <article>
        <h2>$post.title</h2>
        <p>$post.content</p>
    </article>

<!-- Nested objects -->
<p>Email: $user.contact.email</p>
<p>Phone: $user.contact.phone</p>
```

### Context Injection

Flask-TSK automatically injects useful context into all templates:

```python
# Available in all templates:
# - tsk_renderer: The TSK renderer instance
# - tsk_available: Boolean indicating TSK availability
# - tsk_version: Version string
# - turbo_engine: Performance engine instance
```

## 🔧 Advanced Usage

### 1. Custom Template Rendering

```python
from tsk_flask import render_tsk_template

@app.route('/dynamic')
def dynamic_content():
    template_content = """
    <h1>$title</h1>
    $for item in items:
        <li>$item</li>
    """
    
    context = {
        'title': 'Dynamic Content',
        'items': ['Item 1', 'Item 2', 'Item 3']
    }
    
    return render_tsk_template(template_content, context)
```

### 2. Template Filters

Flask-TSK provides custom template filters:

```python
# In your template
<p>Rendered: {{ template_content | tsk_render(context) }}</p>
<p>Value: {{ 'user.name' | tsk_value(context) }}</p>
```

### 3. Performance Optimization

```python
# Enable turbo performance engine
flask_tsk = FlaskTSK(app)

# The turbo engine automatically:
# - Compiles templates to bytecode
# - Caches compiled templates
# - Optimizes rendering performance
# - Provides memory-efficient processing
```

### 4. Error Handling

```python
@app.route('/safe-render')
def safe_render():
    try:
        return render_tsk_template('complex.tsk', complex_context)
    except Exception as e:
        # Fallback to static content
        return f"<h1>Error: {e}</h1>"
```

## 🎯 Real-World Examples

### 1. Admin Dashboard

```python
@app.route('/admin/dashboard')
@login_required
def admin_dashboard():
    stats = {
        'total_users': 1250,
        'active_users': 890,
        'total_errors': 45,
        'error_rate': '3.6%'
    }
    
    return render_tsk_template('admin/dashboard.tsk', {
        'stats': stats,
        'user': get_current_user()
    })
```

```html
<!-- templates/admin/dashboard.tsk -->
<div class="dashboard">
    <h1>Admin Dashboard</h1>
    <p>Welcome back, $user.name!</p>
    
    <div class="stats-grid">
        <div class="stat-card">
            <h3>Total Users</h3>
            <p class="stat-value">$stats.total_users</p>
        </div>
        
        <div class="stat-card">
            <h3>Active Users</h3>
            <p class="stat-value">$stats.active_users</p>
        </div>
        
        <div class="stat-card">
            <h3>Total Errors</h3>
            <p class="stat-value">$stats.total_errors</p>
        </div>
        
        <div class="stat-card">
            <h3>Error Rate</h3>
            <p class="stat-value">$stats.error_rate</p>
        </div>
    </div>
</div>
```

### 2. Data Tables

```python
@app.route('/users')
def users_list():
    users = [
        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'role': 'admin'},
        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com', 'role': 'user'},
        {'id': 3, 'name': 'Bob Johnson', 'email': 'bob@example.com', 'role': 'user'}
    ]
    
    return render_tsk_template('users/list.tsk', {'users': users})
```

```html
<!-- templates/users/list.tsk -->
<table class="users-table">
    <thead>
        <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Role</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        $for user in users:
            <tr>
                <td>$user.id</td>
                <td>$user.name</td>
                <td>$user.email</td>
                <td>
                    $if user.role == 'admin':
                        <span class="badge admin">Admin</span>
                    $else:
                        <span class="badge user">User</span>
                </td>
                <td>
                    <a href="/users/$user.id/edit">Edit</a>
                    <a href="/users/$user.id/delete">Delete</a>
                </td>
            </tr>
    </tbody>
</table>
```

### 3. Form Handling

```python
@app.route('/contact', methods=['GET', 'POST'])
def contact():
    if request.method == 'POST':
        # Process form data
        name = request.form.get('name')
        email = request.form.get('email')
        message = request.form.get('message')
        
        # Send email, save to database, etc.
        
        return render_tsk_template('contact/success.tsk', {
            'name': name,
            'message': 'Thank you for your message!'
        })
    
    return render_tsk_template('contact/form.tsk')
```

```html
<!-- templates/contact/form.tsk -->
<form method="POST" action="/contact">
    <div class="form-group">
        <label for="name">Name:</label>
        <input type="text" id="name" name="name" required>
    </div>
    
    <div class="form-group">
        <label for="email">Email:</label>
        <input type="email" id="email" name="email" required>
    </div>
    
    <div class="form-group">
        <label for="message">Message:</label>
        <textarea id="message" name="message" required></textarea>
    </div>
    
    <button type="submit">Send Message</button>
</form>
```

## 🔍 Debugging and Troubleshooting

### 1. Enable Debug Mode

```python
app.config['DEBUG'] = True
app.config['TEMPLATES_AUTO_RELOAD'] = True
```

### 2. Check TSK Availability

```python
from tsk_flask import TSK_RENDERER_AVAILABLE

if TSK_RENDERER_AVAILABLE:
    print("TSK renderer is available")
else:
    print("TSK renderer is not available")
```

### 3. Common Issues

**Template not found:**
```python
# Make sure template file exists
template_path = os.path.join(app.template_folder, 'template.tsk')
if not os.path.exists(template_path):
    print(f"Template not found: {template_path}")
```

**Variable not defined:**
```html
<!-- Use safe navigation -->
$if user and user.name:
    <p>Hello, $user.name!</p>
$else:
    <p>Hello, Guest!</p>
```

**Performance issues:**
```python
# Enable turbo engine
flask_tsk = FlaskTSK(app)

# Check if turbo engine is available
if flask_tsk.turbo_engine:
    print("Turbo engine is active")
```

## 🚀 Best Practices

### 1. Template Organization

```
templates/
├── base.tsk              # Base template
├── components/
│   ├── header.tsk        # Reusable components
│   ├── footer.tsk
│   └── sidebar.tsk
├── pages/
│   ├── home.tsk
│   ├── about.tsk
│   └── contact.tsk
└── admin/
    ├── dashboard.tsk
    └── users.tsk
```

### 2. Context Management

```python
def get_base_context():
    """Get common context for all templates"""
    return {
        'app_name': 'My App',
        'version': '1.0.0',
        'current_year': datetime.now().year
    }

@app.route('/')
def home():
    context = get_base_context()
    context.update({
        'title': 'Home',
        'user': get_current_user()
    })
    return render_tsk_template('pages/home.tsk', context)
```

### 3. Error Handling

```python
@app.errorhandler(404)
def not_found(error):
    return render_tsk_template('errors/404.tsk', {
        'error': error,
        'message': 'Page not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return render_tsk_template('errors/500.tsk', {
        'error': error,
        'message': 'Internal server error'
    }), 500
```

### 4. Security

```python
# Sanitize user input
from markupsafe import escape

@app.route('/user/<username>')
def user_profile(username):
    safe_username = escape(username)
    return render_tsk_template('user/profile.tsk', {
        'username': safe_username
    })
```

## 📊 Performance Monitoring

### 1. Template Rendering Stats

```python
from tsk_flask import get_tsk_config

config = get_tsk_config()
print(f"Renderer: {config['renderer']}")
print(f"Performance Engine: {config['performance_engine']}")
print(f"Version: {config['version']}")
```

### 2. Memory Usage

```python
import psutil
import os

def get_memory_usage():
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024  # MB

print(f"Memory usage: {get_memory_usage():.2f} MB")
```

## 🔧 Configuration

### 1. Flask Configuration

```python
app.config.update({
    'SECRET_KEY': 'your-secret-key',
    'DEBUG': False,  # Disable in production
    'TEMPLATES_AUTO_RELOAD': False,  # Disable for performance
    'SEND_FILE_MAX_AGE_DEFAULT': 3600  # Cache static files
})
```

### 2. TSK Configuration

```python
# TSK renderer configuration
tsk_config = {
    'cache_enabled': True,
    'cache_size': 1000,
    'debug_mode': False,
    'performance_mode': True
}
```

## 🎯 Integration with Mother Database

Flask-TSK integrates seamlessly with the mother database system:

```python
from mother_db import MotherDBClient

# Initialize mother database client
mother_client = MotherDBClient('https://rp.grim.so', 'your-installation-id')

@app.route('/api/status')
def api_status():
    try:
        # Report health check to mother database
        mother_client.report_error(
            error_type='health_check',
            error_message='API endpoint accessed',
            severity='low',
            context={'endpoint': '/api/status'}
        )
        
        return jsonify({'status': 'healthy'})
    except Exception as e:
        # Report error to mother database
        mother_client.report_error(
            error_type='api_error',
            error_message=str(e),
            severity='high',
            context={'endpoint': '/api/status'}
        )
        
        return jsonify({'error': str(e)}), 500
```

## 📚 Additional Resources

- [TuskLang Documentation](https://tusklang.org/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Mother Database Integration Guide](./agent_integration_prompts.md)

---

This guide covers the essential aspects of Flask-TSK integration. The system provides high-performance template rendering with TuskLang syntax, automatic optimization, and seamless integration with the mother database for error tracking and monitoring. 

## Overview
Flask-TSK is a high-performance Flask extension that integrates TuskLang template processing using a simple TSK renderer and turbo performance engine. This guide teaches you how to use Flask-TSK effectively in your applications.

## 🚀 Quick Start

### 1. Basic Setup

```python
from flask import Flask
from tsk_flask import FlaskTSK, render_tsk_template

# Create Flask app
app = Flask(__name__)

# Initialize Flask-TSK
flask_tsk = FlaskTSK(app)

# Your routes here
@app.route('/')
def home():
    return render_tsk_template('home.tsk', {'title': 'Welcome'})
```

### 2. Template Structure

Create `.tsk` templates in your `templates/` directory:

```html
<!-- templates/home.tsk -->
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
</head>
<body>
    <h1>Welcome to $title</h1>
    
    $if user:
        <p>Hello, $user.name!</p>
        <p>Your role: $user.role</p>
    $else:
        <p>Please <a href="/login">login</a></p>
    
    $for item in items:
        <div class="item">
            <h3>$item.title</h3>
            <p>$item.description</p>
        </div>
</body>
</html>
```

## 📚 Core Concepts

### TuskLang Syntax in Templates

Flask-TSK uses TuskLang syntax with `$variable` interpolation:

```html
<!-- Variable interpolation -->
<h1>$page_title</h1>
<p>User: $user.name</p>

<!-- Conditional statements -->
$if user.is_admin:
    <div class="admin-panel">Admin Controls</div>
$else:
    <div class="user-panel">User Controls</div>

<!-- Loops -->
$for post in posts:
    <article>
        <h2>$post.title</h2>
        <p>$post.content</p>
    </article>

<!-- Nested objects -->
<p>Email: $user.contact.email</p>
<p>Phone: $user.contact.phone</p>
```

### Context Injection

Flask-TSK automatically injects useful context into all templates:

```python
# Available in all templates:
# - tsk_renderer: The TSK renderer instance
# - tsk_available: Boolean indicating TSK availability
# - tsk_version: Version string
# - turbo_engine: Performance engine instance
```

## 🔧 Advanced Usage

### 1. Custom Template Rendering

```python
from tsk_flask import render_tsk_template

@app.route('/dynamic')
def dynamic_content():
    template_content = """
    <h1>$title</h1>
    $for item in items:
        <li>$item</li>
    """
    
    context = {
        'title': 'Dynamic Content',
        'items': ['Item 1', 'Item 2', 'Item 3']
    }
    
    return render_tsk_template(template_content, context)
```

### 2. Template Filters

Flask-TSK provides custom template filters:

```python
# In your template
<p>Rendered: {{ template_content | tsk_render(context) }}</p>
<p>Value: {{ 'user.name' | tsk_value(context) }}</p>
```

### 3. Performance Optimization

```python
# Enable turbo performance engine
flask_tsk = FlaskTSK(app)

# The turbo engine automatically:
# - Compiles templates to bytecode
# - Caches compiled templates
# - Optimizes rendering performance
# - Provides memory-efficient processing
```

### 4. Error Handling

```python
@app.route('/safe-render')
def safe_render():
    try:
        return render_tsk_template('complex.tsk', complex_context)
    except Exception as e:
        # Fallback to static content
        return f"<h1>Error: {e}</h1>"
```

## 🎯 Real-World Examples

### 1. Admin Dashboard

```python
@app.route('/admin/dashboard')
@login_required
def admin_dashboard():
    stats = {
        'total_users': 1250,
        'active_users': 890,
        'total_errors': 45,
        'error_rate': '3.6%'
    }
    
    return render_tsk_template('admin/dashboard.tsk', {
        'stats': stats,
        'user': get_current_user()
    })
```

```html
<!-- templates/admin/dashboard.tsk -->
<div class="dashboard">
    <h1>Admin Dashboard</h1>
    <p>Welcome back, $user.name!</p>
    
    <div class="stats-grid">
        <div class="stat-card">
            <h3>Total Users</h3>
            <p class="stat-value">$stats.total_users</p>
        </div>
        
        <div class="stat-card">
            <h3>Active Users</h3>
            <p class="stat-value">$stats.active_users</p>
        </div>
        
        <div class="stat-card">
            <h3>Total Errors</h3>
            <p class="stat-value">$stats.total_errors</p>
        </div>
        
        <div class="stat-card">
            <h3>Error Rate</h3>
            <p class="stat-value">$stats.error_rate</p>
        </div>
    </div>
</div>
```

### 2. Data Tables

```python
@app.route('/users')
def users_list():
    users = [
        {'id': 1, 'name': 'John Doe', 'email': 'john@example.com', 'role': 'admin'},
        {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com', 'role': 'user'},
        {'id': 3, 'name': 'Bob Johnson', 'email': 'bob@example.com', 'role': 'user'}
    ]
    
    return render_tsk_template('users/list.tsk', {'users': users})
```

```html
<!-- templates/users/list.tsk -->
<table class="users-table">
    <thead>
        <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Role</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        $for user in users:
            <tr>
                <td>$user.id</td>
                <td>$user.name</td>
                <td>$user.email</td>
                <td>
                    $if user.role == 'admin':
                        <span class="badge admin">Admin</span>
                    $else:
                        <span class="badge user">User</span>
                </td>
                <td>
                    <a href="/users/$user.id/edit">Edit</a>
                    <a href="/users/$user.id/delete">Delete</a>
                </td>
            </tr>
    </tbody>
</table>
```

### 3. Form Handling

```python
@app.route('/contact', methods=['GET', 'POST'])
def contact():
    if request.method == 'POST':
        # Process form data
        name = request.form.get('name')
        email = request.form.get('email')
        message = request.form.get('message')
        
        # Send email, save to database, etc.
        
        return render_tsk_template('contact/success.tsk', {
            'name': name,
            'message': 'Thank you for your message!'
        })
    
    return render_tsk_template('contact/form.tsk')
```

```html
<!-- templates/contact/form.tsk -->
<form method="POST" action="/contact">
    <div class="form-group">
        <label for="name">Name:</label>
        <input type="text" id="name" name="name" required>
    </div>
    
    <div class="form-group">
        <label for="email">Email:</label>
        <input type="email" id="email" name="email" required>
    </div>
    
    <div class="form-group">
        <label for="message">Message:</label>
        <textarea id="message" name="message" required></textarea>
    </div>
    
    <button type="submit">Send Message</button>
</form>
```

## 🔍 Debugging and Troubleshooting

### 1. Enable Debug Mode

```python
app.config['DEBUG'] = True
app.config['TEMPLATES_AUTO_RELOAD'] = True
```

### 2. Check TSK Availability

```python
from tsk_flask import TSK_RENDERER_AVAILABLE

if TSK_RENDERER_AVAILABLE:
    print("TSK renderer is available")
else:
    print("TSK renderer is not available")
```

### 3. Common Issues

**Template not found:**
```python
# Make sure template file exists
template_path = os.path.join(app.template_folder, 'template.tsk')
if not os.path.exists(template_path):
    print(f"Template not found: {template_path}")
```

**Variable not defined:**
```html
<!-- Use safe navigation -->
$if user and user.name:
    <p>Hello, $user.name!</p>
$else:
    <p>Hello, Guest!</p>
```

**Performance issues:**
```python
# Enable turbo engine
flask_tsk = FlaskTSK(app)

# Check if turbo engine is available
if flask_tsk.turbo_engine:
    print("Turbo engine is active")
```

## 🚀 Best Practices

### 1. Template Organization

```
templates/
├── base.tsk              # Base template
├── components/
│   ├── header.tsk        # Reusable components
│   ├── footer.tsk
│   └── sidebar.tsk
├── pages/
│   ├── home.tsk
│   ├── about.tsk
│   └── contact.tsk
└── admin/
    ├── dashboard.tsk
    └── users.tsk
```

### 2. Context Management

```python
def get_base_context():
    """Get common context for all templates"""
    return {
        'app_name': 'My App',
        'version': '1.0.0',
        'current_year': datetime.now().year
    }

@app.route('/')
def home():
    context = get_base_context()
    context.update({
        'title': 'Home',
        'user': get_current_user()
    })
    return render_tsk_template('pages/home.tsk', context)
```

### 3. Error Handling

```python
@app.errorhandler(404)
def not_found(error):
    return render_tsk_template('errors/404.tsk', {
        'error': error,
        'message': 'Page not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return render_tsk_template('errors/500.tsk', {
        'error': error,
        'message': 'Internal server error'
    }), 500
```

### 4. Security

```python
# Sanitize user input
from markupsafe import escape

@app.route('/user/<username>')
def user_profile(username):
    safe_username = escape(username)
    return render_tsk_template('user/profile.tsk', {
        'username': safe_username
    })
```

## 📊 Performance Monitoring

### 1. Template Rendering Stats

```python
from tsk_flask import get_tsk_config

config = get_tsk_config()
print(f"Renderer: {config['renderer']}")
print(f"Performance Engine: {config['performance_engine']}")
print(f"Version: {config['version']}")
```

### 2. Memory Usage

```python
import psutil
import os

def get_memory_usage():
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / 1024 / 1024  # MB

print(f"Memory usage: {get_memory_usage():.2f} MB")
```

## 🔧 Configuration

### 1. Flask Configuration

```python
app.config.update({
    'SECRET_KEY': 'your-secret-key',
    'DEBUG': False,  # Disable in production
    'TEMPLATES_AUTO_RELOAD': False,  # Disable for performance
    'SEND_FILE_MAX_AGE_DEFAULT': 3600  # Cache static files
})
```

### 2. TSK Configuration

```python
# TSK renderer configuration
tsk_config = {
    'cache_enabled': True,
    'cache_size': 1000,
    'debug_mode': False,
    'performance_mode': True
}
```

## 🎯 Integration with Mother Database

Flask-TSK integrates seamlessly with the mother database system:

```python
from mother_db import MotherDBClient

# Initialize mother database client
mother_client = MotherDBClient('https://rp.grim.so', 'your-installation-id')

@app.route('/api/status')
def api_status():
    try:
        # Report health check to mother database
        mother_client.report_error(
            error_type='health_check',
            error_message='API endpoint accessed',
            severity='low',
            context={'endpoint': '/api/status'}
        )
        
        return jsonify({'status': 'healthy'})
    except Exception as e:
        # Report error to mother database
        mother_client.report_error(
            error_type='api_error',
            error_message=str(e),
            severity='high',
            context={'endpoint': '/api/status'}
        )
        
        return jsonify({'error': str(e)}), 500
```

## 📚 Additional Resources

- [TuskLang Documentation](https://tusklang.org/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Mother Database Integration Guide](./agent_integration_prompts.md)

---

This guide covers the essential aspects of Flask-TSK integration. The system provides high-performance template rendering with TuskLang syntax, automatic optimization, and seamless integration with the mother database for error tracking and monitoring. 