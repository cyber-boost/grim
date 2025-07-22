# TuskLang Integration Prompt for Future Agents

## Overview
This prompt provides comprehensive guidance for implementing and maintaining TuskLang syntax processing in the Grim Flask Admin Server. The system uses a custom TuskLang template renderer that processes `$extends` and `$content` blocks for template inheritance.

## Key Implementation Details

### 1. TuskLang Syntax Structure
Public pages use the following TuskLang syntax:
```
$extends "public/layout.html"

$content
    <!-- Page content here -->
$endcontent
```

### 2. Template Inheritance Flow
- `$extends` specifies the parent template (e.g., "public/layout.html")
- `$content` marks the beginning of content that will replace `$content` in the parent template
- `$endcontent` (optional) marks the end of content
- The renderer processes inheritance BEFORE other variable substitution

### 3. File Structure
```
tsk_flask/
├── grim/
│   ├── public/
│   │   ├── layout.html          # Parent template with $content placeholder
│   │   ├── landing.html         # Uses $extends and $content
│   │   └── architecture.html    # Uses $extends and $content
│   └── assets/
│       ├── css/                 # CSS files
│       ├── js/                  # JavaScript files
│       └── svg/                 # SVG assets
├── simple_tsk_renderer.py       # Custom TuskLang renderer
└── grim_admin_server.py         # Flask server with routes
```

### 4. Static File Serving Routes
The server has multiple static file routes that must be defined in the correct order:

```python
# More specific routes FIRST
@self.app.route('/assets/css/<path:filename>')
def assets_css_files(filename):
    css_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets', 'css')
    return send_from_directory(css_dir, filename)

@self.app.route('/assets/js/<path:filename>')
def assets_js_files(filename):
    js_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets', 'js')
    return send_from_directory(js_dir, filename)

# General assets route LAST
@self.app.route('/assets/<path:filename>')
def assets_files(filename):
    assets_dir = os.path.join(os.path.dirname(__file__), 'grim', 'assets')
    return send_from_directory(assets_dir, filename)
```

### 5. Authentication Bypass
The `herd_auth.py` file must include all asset route names in the `_before_request` handler:

```python
if request.endpoint and (
    request.endpoint.startswith('static') or
    request.endpoint.startswith('assets_files') or
    request.endpoint.startswith('assets_css_files') or  # Required for CSS
    request.endpoint.startswith('assets_js_files') or   # Required for JS
    # ... other public routes
):
    return  # Skip authentication
```

### 6. TuskLang Renderer Implementation
The `simple_tsk_renderer.py` contains the core logic:

#### Key Methods:
- `_process_tsk_extends()`: Handles `$extends` and `$content` blocks
- `render()`: Main rendering method that processes inheritance first
- Variable substitution: `$variable` and `$object.property` syntax
- Conditional processing: `$if condition ... $endif`

#### Processing Order:
1. TuskLang extends and content blocks FIRST
2. Jinja2 variable syntax (`{{ variable }}`)
3. TuskLang nested object access (`$object.property`)
4. TuskLang simple variable substitution (`$variable`)
5. Jinja2 conditionals and loops
6. TuskLang conditionals

### 7. Public Page Rendering
Public pages are rendered using `_render_public_page()`:

```python
def _render_public_page(self, template_path: str, context: Dict[str, Any] = None) -> str:
    # Load template from grim/public/ directory
    # Use simple TuskLang template rendering
    result = self.tsk_renderer(template_content, context)
    return result
```

## Common Issues and Solutions

### Issue 1: CSS/JS Files Getting 302 Redirects
**Problem**: Asset files redirect to login page
**Solution**: Add route names to `herd_auth.py` `_before_request` handler:
```python
request.endpoint.startswith('assets_css_files') or
request.endpoint.startswith('assets_js_files')
```

### Issue 2: Template Inheritance Not Working
**Problem**: `$extends` and `$content` not processed
**Solution**: Ensure `_process_tsk_extends()` is called FIRST in the render method

### Issue 3: Images Not Loading
**Problem**: SVG files not found
**Solution**: Check route order - specific routes must come before general routes

### Issue 4: Route Conflicts
**Problem**: More general routes catching specific requests
**Solution**: Define routes in order of specificity (most specific first)

## Testing Checklist

### 1. Template Inheritance
- [ ] `$extends "public/layout.html"` processes correctly
- [ ] `$content` block replaces `$content` in parent template
- [ ] Log shows: `INFO:simple_tsk_renderer:TuskLang extends template: public/layout.html`

### 2. Static File Serving
- [ ] CSS files: `curl http://localhost:8080/assets/css/landing.css`
- [ ] JS files: `curl http://localhost:8080/assets/js/landing.js`
- [ ] SVG files: `curl http://localhost:8080/assets/svg/grim-logo-primary.svg`
- [ ] Static files: `curl http://localhost:8080/static/svg/grim-logo-primary.svg`

### 3. Page Rendering
- [ ] Pages return 200 status codes
- [ ] TuskLang syntax is processed
- [ ] Images and assets load correctly
- [ ] No authentication redirects for public pages

## Creating New Public Pages

### Step 1: Create Template File
Create `tsk_flask/grim/public/your-page.html`:
```html
$extends "public/layout.html"

$content
    <!-- Your page content here -->
    <h1>Your Page Title</h1>
    <p>Your content goes here</p>
$endcontent
```

### Step 2: Add Route
Add to `grim_admin_server.py`:
```python
@self.app.route('/your-page')
def your_page():
    return self._render_public_page('your-page.html', {
        'page_title': 'Your Page Title',
        'page_description': 'Your page description'
    })
```

### Step 3: Test
- [ ] Page loads without authentication
- [ ] TuskLang syntax processes correctly
- [ ] Assets (CSS, JS, images) load properly
- [ ] Template inheritance works

## Maintenance Notes

### When Adding New Asset Types
1. Add specific route before general route
2. Update `herd_auth.py` to include new route name
3. Test with curl to ensure no redirects

### When Modifying Templates
1. Ensure `$extends` and `$content` syntax is correct
2. Check that parent template has `$content` placeholder
3. Verify template inheritance in logs

### When Adding New Public Routes
1. Add route name to `herd_auth.py` bypass list
2. Test authentication bypass
3. Verify static file serving works

## Performance Considerations

- TuskLang processing happens synchronously
- Template inheritance is recursive (parent templates can extend other templates)
- Static files are served directly without processing
- Authentication bypass is efficient for public assets

## Security Notes

- Public pages bypass authentication intentionally
- Static files are served from specific directories only
- No user input is processed in template rendering
- All routes are explicitly defined

## Debugging

### Enable Debug Logging
Add to `simple_tsk_renderer.py`:
```python
self.logger.setLevel(logging.DEBUG)
```

### Check Route Registration
```python
# In Flask app context
for rule in app.url_map.iter_rules():
    print(f"{rule.endpoint}: {rule.rule}")
```

### Test Template Processing
```python
# Test renderer directly
from simple_tsk_renderer import render_simple_tsk_template
result = render_simple_tsk_template(template_content, context)
print(result)
```

This prompt should provide future agents with all the information needed to maintain and extend the TuskLang integration in the Grim Flask Admin Server. 