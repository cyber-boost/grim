# 🐘 **FLASK-TSK INTEGRATION PROMPTS FOR AI AGENTS**

## **Herd Authentication Integration Prompt**

```
INTEGRATE HERD AUTHENTICATION INTO FLASK-TSK APPLICATION

You are integrating the Flask-TSK Herd authentication system into a Flask application. Herd provides comprehensive user authentication, registration, password management, two-factor authentication, magic links, session management, and security intelligence.

REQUIREMENTS:
1. Import and initialize Herd with Flask app
2. Set up authentication routes (login, logout, register, password reset)
3. Implement user session management
4. Add authentication decorators for protected routes
5. Configure security settings and logging
6. Integrate with TuskLang for user data storage
7. Set up audit logging and security monitoring

IMPLEMENTATION STEPS:
1. Import Herd: `from tsk_flask.herd import Herd, get_herd`
2. Initialize: `herd = Herd.get_instance()` or use `get_herd()`
3. Create authentication routes with proper error handling
4. Use `@herd.require_auth` decorator for protected routes
5. Implement user registration with email verification
6. Add password reset functionality with magic links
7. Set up two-factor authentication (optional)
8. Configure session management and security policies
9. Add audit logging for security events
10. Test all authentication flows

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify, session
from tsk_flask.herd import Herd, get_herd

app = Flask(__name__)
herd = get_herd()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    success = Herd.login(data['email'], data['password'])
    return jsonify({'success': success})

@app.route('/protected')
@herd.require_auth
def protected_route():
    user = Herd.user()
    return jsonify({'message': f'Hello {user["email"]}'})
```

CRITICAL CONSIDERATIONS:
- Always validate user input and sanitize data
- Implement proper error handling and user feedback
- Use secure session management
- Enable audit logging for security events
- Test authentication flows thoroughly
- Follow security best practices for password handling
- Implement rate limiting for login attempts
- Add CSRF protection for forms
- Use HTTPS in production
- Regular security audits and monitoring

The Herd system is OPTIONAL - only integrate if authentication is needed for your application.
```

## **Babar CMS Integration Prompt**

```
INTEGRATE BABAR CMS INTO FLASK-TSK APPLICATION

You are integrating Babar, the Content Management System elephant, into a Flask-TSK application. Babar provides hierarchical content organization, role-based access control, multi-language support, version control, workflow management, and SEO optimization.

REQUIREMENTS:
1. Import and initialize Babar CMS
2. Set up content creation and management routes
3. Implement content publishing workflow
4. Add content versioning and history
5. Set up role-based access control
6. Configure multi-language support
7. Implement SEO features and meta tags
8. Add content analytics and reporting
9. Integrate with TuskLang for content storage
10. Set up content templates and themes

IMPLEMENTATION STEPS:
1. Import Babar: `from tsk_flask.herd.elephants.babar import Babar, init_babar, get_babar`
2. Initialize: `babar = get_babar()`
3. Set current user for permissions: `babar.set_current_user(user_data)`
4. Create content management routes (CRUD operations)
5. Implement content publishing workflow (draft → review → publish)
6. Add content versioning and rollback functionality
7. Set up role-based permissions for content operations
8. Configure multi-language content support
9. Implement SEO features (meta tags, friendly URLs)
10. Add content analytics and reporting
11. Create content templates and theme integration
12. Test all content management flows

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.babar import get_babar

app = Flask(__name__)
babar = get_babar()

@app.route('/content', methods=['POST'])
def create_content():
    data = request.get_json()
    result = babar.create_story(data)
    return jsonify(result)

@app.route('/content/<content_id>', methods=['GET'])
def get_content(content_id):
    content = babar.get_story(content_id)
    return jsonify(content)

@app.route('/content/<content_id>/publish', methods=['POST'])
def publish_content(content_id):
    result = babar.publish(content_id)
    return jsonify(result)
```

CRITICAL CONSIDERATIONS:
- Always check user permissions before content operations
- Implement proper content validation and sanitization
- Use version control for content changes
- Set up content approval workflows
- Implement content caching for performance
- Add content backup and recovery
- Use SEO-friendly URLs and meta tags
- Implement content search functionality
- Add content analytics and reporting
- Test content workflows thoroughly
- Ensure proper error handling and user feedback
```

## **Dumbo HTTP Integration Prompt**

```
INTEGRATE DUMBO HTTP CLIENT INTO FLASK-TSK APPLICATION

You are integrating Dumbo, the HTTP client elephant, into a Flask-TSK application. Dumbo provides simple HTTP requests, automatic retries, response caching, parallel requests, cookie management, and network connectivity testing.

REQUIREMENTS:
1. Import and initialize Dumbo HTTP client
2. Set up HTTP request handling routes
3. Implement automatic retry logic
4. Add response caching functionality
5. Configure parallel request handling
6. Set up cookie and session management
7. Add network connectivity testing
8. Implement progress callbacks for downloads
9. Configure timeout and error handling
10. Add request/response logging

IMPLEMENTATION STEPS:
1. Import Dumbo: `from tsk_flask.herd.elephants.dumbo import Dumbo, init_dumbo, get_dumbo`
2. Initialize: `dumbo = get_dumbo()`
3. Create HTTP request routes (GET, POST, PUT, DELETE)
4. Implement automatic retry with exponential backoff
5. Add response caching for repeated requests
6. Set up parallel request handling with `fly_formation`
7. Configure cookie jar management
8. Add network connectivity testing with `ping`
9. Implement progress callbacks for large downloads
10. Set up timeout and error handling
11. Add request/response logging and monitoring
12. Test all HTTP operations

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.dumbo import get_dumbo

app = Flask(__name__)
dumbo = get_dumbo()

@app.route('/api/request', methods=['POST'])
def make_request():
    data = request.get_json()
    response = dumbo.get(data['url'])
    return jsonify({
        'status_code': response.status_code,
        'body': response.body,
        'elapsed_time': response.elapsed_time
    })

@app.route('/api/ping', methods=['POST'])
def ping_url():
    data = request.get_json()
    result = dumbo.ping(data['url'])
    return jsonify(result)

@app.route('/api/parallel', methods=['POST'])
def parallel_requests():
    data = request.get_json()
    results = dumbo.fly_formation(data['requests'])
    return jsonify(results)
```

CRITICAL CONSIDERATIONS:
- Always validate URLs before making requests
- Implement proper timeout handling
- Use HTTPS for sensitive data
- Add request rate limiting
- Implement proper error handling and retries
- Cache responses appropriately
- Monitor request performance and errors
- Handle large file downloads efficiently
- Add request logging for debugging
- Test network connectivity and error scenarios
- Implement security headers and validation
```

## **Elmer Theme Integration Prompt**

```
INTEGRATE ELMER THEME GENERATOR INTO FLASK-TSK APPLICATION

You are integrating Elmer, the theme analyzer elephant, into a Flask-TSK application. Elmer provides AI-powered theme generation, color harmony analysis, cultural themes, weather-based adaptation, accessibility support, and 3D color visualization.

REQUIREMENTS:
1. Import and initialize Elmer theme generator
2. Set up theme generation routes
3. Implement AI-powered theme creation
4. Add color harmony analysis
5. Configure cultural theme generation
6. Set up weather-based theme adaptation
7. Implement accessibility features
8. Add 3D color space visualization
9. Configure brand color extraction
10. Set up theme sharing and export

IMPLEMENTATION STEPS:
1. Import Elmer: `from tsk_flask.herd.elephants.elmer import Elmer, init_elmer, get_elmer`
2. Initialize: `elmer = get_elmer(claude_api_key="your-key")`
3. Create theme generation routes
4. Implement AI-powered theme creation with Claude
5. Add color harmony analysis and optimization
6. Set up cultural theme generation
7. Configure weather-based theme adaptation
8. Implement accessibility features (color blindness support)
9. Add 3D color space visualization
10. Set up brand color extraction from images
11. Configure theme sharing and export functionality
12. Test all theme generation features

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.elmer import get_elmer

app = Flask(__name__)
elmer = get_elmer(claude_api_key="your-claude-api-key")

@app.route('/theme/generate', methods=['POST'])
def generate_theme():
    data = request.get_json()
    theme = elmer.generate_claude_theme(data['prompt'], data.get('context'))
    return jsonify({
        'name': theme.name,
        'primary_colors': [patch.hex_color for patch in theme.primary_colors],
        'mood': theme.mood.value
    })

@app.route('/theme/cultural/<culture>', methods=['GET'])
def cultural_theme(culture):
    theme = elmer.create_cultural_theme(culture)
    return jsonify({
        'name': theme.name,
        'colors': [patch.hex_color for patch in theme.primary_colors]
    })

@app.route('/theme/extract', methods=['POST'])
def extract_brand_colors():
    data = request.get_json()
    result = elmer.extract_brand_colors(data['image_path'])
    return jsonify(result)
```

CRITICAL CONSIDERATIONS:
- Secure Claude API key storage and usage
- Implement proper image validation for color extraction
- Add accessibility features for color blindness
- Cache generated themes for performance
- Validate color combinations for contrast
- Implement theme versioning and history
- Add theme preview functionality
- Monitor API usage and costs
- Test theme generation with various inputs
- Implement proper error handling for API failures
- Add theme export in multiple formats
```

## **Happy Image Integration Prompt**

```
INTEGRATE HAPPY IMAGE PROCESSOR INTO FLASK-TSK APPLICATION

You are integrating Happy, the image processing elephant, into a Flask-TSK application. Happy provides emotional image filters, artistic transformations, conservation-aware processing, seasonal effects, and memory-based personalized filters.

REQUIREMENTS:
1. Import and initialize Happy image processor
2. Set up image upload and processing routes
3. Implement emotional filter application
4. Add artistic transformation features
5. Configure conservation-aware processing
6. Set up seasonal and weather effects
7. Implement memory-based personalization
8. Add batch processing capabilities
9. Configure output format options
10. Set up processing statistics and analytics

IMPLEMENTATION STEPS:
1. Import Happy: `from tsk_flask.herd.elephants.happy import Happy, init_happy, get_happy`
2. Initialize: `happy = get_happy()`
3. Create image upload and processing routes
4. Implement emotional filter application
5. Add artistic transformation features (painting, vintage, etc.)
6. Configure conservation-aware processing with donations
7. Set up seasonal and weather-based effects
8. Implement memory-based personalization for users
9. Add batch processing for multiple images
10. Configure output format options (JPEG, PNG, etc.)
11. Set up processing statistics and analytics
12. Test all image processing features

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.happy import get_happy

app = Flask(__name__)
happy = get_happy()

@app.route('/image/filter', methods=['POST'])
def apply_filter():
    data = request.get_json()
    result = happy.apply_filter(
        data['image_path'],
        data.get('filter_name', 'sunshine'),
        data.get('options', {})
    )
    return jsonify({
        'success': result.success,
        'output_path': result.output_path,
        'processing_time': result.processing_time
    })

@app.route('/image/emotional', methods=['POST'])
def emotional_filter():
    data = request.get_json()
    result = happy.apply_emotional_filter(
        data['image_path'],
        data.get('mood')
    )
    return jsonify({
        'success': result.success,
        'emotional_impact': result.emotional_impact
    })

@app.route('/image/stats', methods=['GET'])
def get_stats():
    stats = happy.get_stats()
    return jsonify(stats)
```

CRITICAL CONSIDERATIONS:
- Validate image files before processing
- Implement proper file size limits
- Add image format validation
- Use secure file upload handling
- Implement processing queue for large images
- Add progress tracking for long operations
- Cache processed images appropriately
- Monitor disk space usage
- Implement image backup and recovery
- Add processing error handling and retries
- Test with various image formats and sizes
- Implement proper cleanup of temporary files
```

## **Heffalump Search Integration Prompt**

```
INTEGRATE HEFFALUMP SEARCH ENGINE INTO FLASK-TSK APPLICATION

You are integrating Heffalump, the fuzzy search elephant, into a Flask-TSK application. Heffalump provides fuzzy search, typo correction, phonetic matching, N-gram similarity, autocomplete, and search analytics.

REQUIREMENTS:
1. Import and initialize Heffalump search engine
2. Set up search indexing routes
3. Implement fuzzy search functionality
4. Add typo correction and suggestions
5. Configure phonetic matching
6. Set up N-gram similarity search
7. Implement autocomplete functionality
8. Add search analytics and reporting
9. Configure Elasticsearch integration (optional)
10. Set up search result ranking

IMPLEMENTATION STEPS:
1. Import Heffalump: `from tsk_flask.herd.elephants.heffalump import Heffalump, init_heffalump, get_heffalump`
2. Initialize: `heffalump = get_heffalump()`
3. Create search indexing routes
4. Implement fuzzy search with Levenshtein distance
5. Add typo correction and "Did you mean?" suggestions
6. Configure phonetic matching (Soundex/Metaphone)
7. Set up N-gram similarity search
8. Implement autocomplete functionality
9. Add search analytics and reporting
10. Configure Elasticsearch integration (optional)
11. Set up search result ranking and relevance
12. Test all search functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.heffalump import get_heffalump

app = Flask(__name__)
heffalump = get_heffalump()

@app.route('/search', methods=['POST'])
def search():
    data = request.get_json()
    results = heffalump.hunt(data['query'], data.get('search_in', []))
    return jsonify({
        'query': data['query'],
        'results': [
            {
                'id': result.id,
                'content': result.content,
                'score': result.score,
                'confidence': result.confidence
            }
            for result in results
        ]
    })

@app.route('/search/suggestions', methods=['POST'])
def get_suggestions():
    data = request.get_json()
    suggestions = heffalump.track_suggestions(data['partial'])
    return jsonify({'suggestions': suggestions})

@app.route('/search/index', methods=['POST'])
def index_content():
    data = request.get_json()
    success = heffalump.index(data['id'], data['content'], data.get('metadata'))
    return jsonify({'success': success})
```

CRITICAL CONSIDERATIONS:
- Implement proper search result ranking
- Add search query validation and sanitization
- Configure appropriate search tolerance levels
- Implement search result caching
- Add search analytics and user behavior tracking
- Monitor search performance and optimize
- Implement search result pagination
- Add search filters and faceted search
- Test with various query types and edge cases
- Implement search result highlighting
- Add search suggestions and autocomplete
- Monitor search quality and relevance
```

## **Horton Job Integration Prompt**

```
INTEGRATE HORTON JOB PROCESSOR INTO FLASK-TSK APPLICATION

You are integrating Horton, the job queue elephant, into a Flask-TSK application. Horton provides background job processing, automatic retries, job prioritization, failed job handling, and distributed processing support.

REQUIREMENTS:
1. Import and initialize Horton job processor
2. Set up job dispatching routes
3. Implement job registration and handlers
4. Add job prioritization and queuing
5. Configure automatic retry logic
6. Set up failed job handling
7. Implement job status tracking
8. Add job statistics and monitoring
9. Configure distributed processing
10. Set up job cleanup and maintenance

IMPLEMENTATION STEPS:
1. Import Horton: `from tsk_flask.herd.elephants.horton import Horton, init_horton, get_horton`
2. Initialize: `horton = get_horton()`
3. Create job dispatching routes
4. Register job handlers for different job types
5. Implement job prioritization (high, normal, low)
6. Configure automatic retry with exponential backoff
7. Set up failed job handling and dead letter queue
8. Implement job status tracking and monitoring
9. Add job statistics and performance metrics
10. Configure distributed processing support
11. Set up job cleanup and maintenance tasks
12. Test all job processing functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.horton import get_horton

app = Flask(__name__)
horton = get_horton()

# Register job handlers
def email_job_handler(data):
    # Send email logic here
    pass

horton.register('send_email', email_job_handler)

@app.route('/jobs/dispatch', methods=['POST'])
def dispatch_job():
    data = request.get_json()
    job_id = horton.dispatch(
        data['name'],
        data.get('data', {}),
        data.get('queue', 'normal')
    )
    return jsonify({'job_id': job_id})

@app.route('/jobs/<job_id>/status', methods=['GET'])
def job_status(job_id):
    status = horton.status(job_id)
    return jsonify(status)

@app.route('/jobs/stats', methods=['GET'])
def job_stats():
    stats = horton.stats()
    return jsonify(stats)
```

CRITICAL CONSIDERATIONS:
- Implement proper job error handling and logging
- Configure appropriate retry policies
- Monitor job queue performance and health
- Implement job timeout handling
- Add job dependencies and workflows
- Set up job result storage and retrieval
- Implement job cancellation and cleanup
- Add job scheduling and delayed execution
- Monitor system resources during job processing
- Implement job priority management
- Test job processing under load
- Add job security and access control
```

## **Jumbo Upload Integration Prompt**

```
INTEGRATE JUMBO FILE UPLOAD INTO FLASK-TSK APPLICATION

You are integrating Jumbo, the file upload elephant, into a Flask-TSK application. Jumbo provides chunked file uploads, resume capability, file verification, progress tracking, and large file handling.

REQUIREMENTS:
1. Import and initialize Jumbo upload processor
2. Set up file upload routes
3. Implement chunked upload handling
4. Add upload resume functionality
5. Configure file verification and validation
6. Set up progress tracking
7. Implement upload statistics
8. Add file cleanup and management
9. Configure upload limits and security
10. Set up upload monitoring and logging

IMPLEMENTATION STEPS:
1. Import Jumbo: `from tsk_flask.herd.elephants.jumbo import Jumbo, init_jumbo, get_jumbo`
2. Initialize: `jumbo = get_jumbo()`
3. Create file upload routes
4. Implement chunked upload handling
5. Add upload resume functionality
6. Configure file verification and validation
7. Set up progress tracking and callbacks
8. Implement upload statistics and monitoring
9. Add file cleanup and management
10. Configure upload limits and security
11. Set up upload monitoring and logging
12. Test all upload functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.jumbo import get_jumbo

app = Flask(__name__)
jumbo = get_jumbo()

@app.route('/upload/start', methods=['POST'])
def start_upload():
    data = request.get_json()
    result = jumbo.start_upload(
        data['filename'],
        data['total_size'],
        data.get('metadata', {})
    )
    return jsonify(result)

@app.route('/upload/<upload_id>/chunk', methods=['POST'])
def upload_chunk(upload_id):
    data = request.get_json()
    result = jumbo.upload_chunk(
        upload_id,
        data['chunk_number'],
        data['chunk_data']
    )
    return jsonify(result)

@app.route('/upload/<upload_id>/status', methods=['GET'])
def upload_status(upload_id):
    status = jumbo.get_status(upload_id)
    return jsonify(status)
```

CRITICAL CONSIDERATIONS:
- Implement proper file validation and security
- Configure appropriate file size limits
- Add virus scanning for uploaded files
- Implement proper file type validation
- Set up secure file storage
- Add upload progress tracking
- Implement upload resume functionality
- Monitor disk space usage
- Add file cleanup and maintenance
- Implement upload rate limiting
- Test with various file types and sizes
- Add proper error handling and user feedback
```

## **Kaavan Monitor Integration Prompt**

```
INTEGRATE KAAVAN SYSTEM MONITOR INTO FLASK-TSK APPLICATION

You are integrating Kaavan, the system monitoring elephant, into a Flask-TSK application. Kaavan provides system health monitoring, automated backups, alert management, performance analysis, and system recovery.

REQUIREMENTS:
1. Import and initialize Kaavan monitor
2. Set up system monitoring routes
3. Implement health check functionality
4. Add automated backup systems
5. Configure alert management
6. Set up performance analysis
7. Implement system recovery
8. Add monitoring dashboards
9. Configure backup verification
10. Set up monitoring schedules

IMPLEMENTATION STEPS:
1. Import Kaavan: `from tsk_flask.herd.elephants.kaavan import Kaavan, init_kaavan, get_kaavan`
2. Initialize: `kaavan = get_kaavan()`
3. Create system monitoring routes
4. Implement health check functionality
5. Add automated backup systems
6. Configure alert management and notifications
7. Set up performance analysis and reporting
8. Implement system recovery procedures
9. Add monitoring dashboards and visualization
10. Configure backup verification and testing
11. Set up monitoring schedules and automation
12. Test all monitoring functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.kaavan import get_kaavan

app = Flask(__name__)
kaavan = get_kaavan()

@app.route('/monitor/health', methods=['GET'])
def system_health():
    health = kaavan.watch()
    return jsonify(health)

@app.route('/backup/create', methods=['POST'])
def create_backup():
    data = request.get_json()
    result = kaavan.backup(data.get('type', 'full'))
    return jsonify(result)

@app.route('/monitor/alerts', methods=['GET'])
def get_alerts():
    alerts = kaavan.get_alerts(active_only=True)
    return jsonify(alerts)

@app.route('/monitor/analyze', methods=['GET'])
def analyze_system():
    analysis = kaavan.analyze()
    return jsonify(analysis)
```

CRITICAL CONSIDERATIONS:
- Implement proper error handling and logging
- Configure appropriate monitoring thresholds
- Add backup verification and testing
- Set up alert escalation procedures
- Monitor system resources and performance
- Implement automated recovery procedures
- Add monitoring data retention policies
- Configure secure backup storage
- Test monitoring and backup procedures
- Implement monitoring dashboard access control
- Add monitoring data visualization
- Set up monitoring schedule automation
```

## **Koshik Audio Integration Prompt**

```
INTEGRATE KOSHIK AUDIO SYSTEM INTO FLASK-TSK APPLICATION

You are integrating Koshik, the audio and notification elephant, into a Flask-TSK application. Koshik provides text-to-speech, custom notification sounds, multi-language support, audio processing, and user preferences.

REQUIREMENTS:
1. Import and initialize Koshik audio system
2. Set up text-to-speech routes
3. Implement notification sound generation
4. Add multi-language audio support
5. Configure user audio preferences
6. Set up audio file management
7. Implement audio processing and effects
8. Add notification queuing
9. Configure audio playback
10. Set up audio analytics

IMPLEMENTATION STEPS:
1. Import Koshik: `from tsk_flask.herd.elephants.koshik import Koshik, init_koshik, get_koshik`
2. Initialize: `koshik = get_koshik()`
3. Create text-to-speech routes
4. Implement notification sound generation
5. Add multi-language audio support
6. Configure user audio preferences and settings
7. Set up audio file management and storage
8. Implement audio processing and effects
9. Add notification queuing and delivery
10. Configure audio playback and streaming
11. Set up audio analytics and usage tracking
12. Test all audio functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.koshik import get_koshik

app = Flask(__name__)
koshik = get_koshik()

@app.route('/audio/speak', methods=['POST'])
def speak_text():
    data = request.get_json()
    result = koshik.speak(data['message'], data.get('options', {}))
    return jsonify(result)

@app.route('/audio/notify', methods=['POST'])
def send_notification():
    data = request.get_json()
    notification_id = koshik.notify(
        data.get('sound_type', 'default'),
        data.get('options', {})
    )
    return jsonify({'notification_id': notification_id})

@app.route('/audio/preferences/<user_id>', methods=['GET'])
def get_preferences(user_id):
    preferences = koshik.get_user_preferences(int(user_id))
    return jsonify(preferences)
```

CRITICAL CONSIDERATIONS:
- Implement proper audio file validation
- Configure appropriate audio format support
- Add audio file size and quality limits
- Set up secure audio file storage
- Implement audio caching for performance
- Add audio playback controls and options
- Monitor audio processing performance
- Implement audio file cleanup
- Add audio accessibility features
- Test with various audio formats and languages
- Implement proper error handling for audio failures
- Add audio usage analytics and monitoring
```

## **Satao Security Integration Prompt**

```
INTEGRATE SATAO SECURITY SYSTEM INTO FLASK-TSK APPLICATION

You are integrating Satao, the security and protection elephant, into a Flask-TSK application. Satao provides threat detection, DDoS protection, security auditing, IP blocking, and real-time security monitoring.

REQUIREMENTS:
1. Import and initialize Satao security system
2. Set up security monitoring routes
3. Implement threat detection
4. Add DDoS protection
5. Configure IP blocking and whitelisting
6. Set up security auditing
7. Implement real-time monitoring
8. Add security alerts and notifications
9. Configure security policies
10. Set up security reporting

IMPLEMENTATION STEPS:
1. Import Satao: `from tsk_flask.herd.elephants.satao import Satao, init_satao`
2. Initialize: `satao = init_satao(app)`
3. Create security monitoring routes
4. Implement threat detection and analysis
5. Add DDoS protection and rate limiting
6. Configure IP blocking and whitelisting
7. Set up security auditing and logging
8. Implement real-time security monitoring
9. Add security alerts and notifications
10. Configure security policies and rules
11. Set up security reporting and analytics
12. Test all security functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.satao import init_satao

app = Flask(__name__)
satao = init_satao(app)

@app.route('/security/audit', methods=['GET'])
def security_audit():
    audit = satao.audit()
    return jsonify(audit)

@app.route('/security/threats', methods=['GET'])
def get_threats():
    threats = satao.get_threat_intelligence()
    return jsonify(threats)

@app.route('/security/block/<ip>', methods=['POST'])
def block_ip(ip):
    success = satao.block_attacker(ip, 'Manual block')
    return jsonify({'success': success})

@app.route('/security/status', methods=['GET'])
def security_status():
    status = satao.get_protection_status()
    return jsonify(status)
```

CRITICAL CONSIDERATIONS:
- Implement proper security logging and monitoring
- Configure appropriate security thresholds
- Add security alert escalation procedures
- Set up secure IP blocking and whitelisting
- Monitor security events and patterns
- Implement automated security responses
- Add security data retention policies
- Configure secure security reporting
- Test security monitoring and responses
- Implement security dashboard access control
- Add security data visualization
- Set up security schedule automation
```

## **Stampy Package Integration Prompt**

```
INTEGRATE STAMPY PACKAGE MANAGER INTO FLASK-TSK APPLICATION

You are integrating Stampy, the package management elephant, into a Flask-TSK application. Stampy provides app installation, dependency management, package catalog, configuration management, and app lifecycle management.

REQUIREMENTS:
1. Import and initialize Stampy package manager
2. Set up package installation routes
3. Implement app catalog management
4. Add dependency resolution
5. Configure package verification
6. Set up installation rollback
7. Implement configuration management
8. Add package analytics
9. Configure security scanning
10. Set up package updates

IMPLEMENTATION STEPS:
1. Import Stampy: `from tsk_flask.herd.elephants.stampy import Stampy, init_stampy`
2. Initialize: `stampy = init_stampy(app)`
3. Create package installation routes
4. Implement app catalog management
5. Add dependency resolution and management
6. Configure package verification and validation
7. Set up installation rollback and recovery
8. Implement configuration management
9. Add package analytics and usage tracking
10. Configure security scanning for packages
11. Set up package updates and maintenance
12. Test all package management functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.stampy import init_stampy

app = Flask(__name__)
stampy = init_stampy(app)

@app.route('/packages/catalog', methods=['GET'])
def get_catalog():
    catalog = stampy.catalog()
    return jsonify(catalog)

@app.route('/packages/install', methods=['POST'])
def install_package():
    data = request.get_json()
    success = stampy.install(data['app_name'], data.get('options', {}))
    return jsonify({'success': success})

@app.route('/packages/uninstall/<app_name>', methods=['POST'])
def uninstall_package(app_name):
    success = stampy.uninstall(app_name)
    return jsonify({'success': success})

@app.route('/packages/installed', methods=['GET'])
def get_installed():
    installed = stampy.scan_installed_apps()
    return jsonify(installed)
```

CRITICAL CONSIDERATIONS:
- Implement proper package validation and verification
- Configure secure package sources and repositories
- Add dependency conflict resolution
- Set up package installation rollback
- Monitor package installation performance
- Implement package security scanning
- Add package version management
- Configure package update automation
- Test package installation and removal
- Implement package configuration management
- Add package usage analytics
- Set up package backup and recovery
```

## **Tantor Database Integration Prompt**

```
INTEGRATE TANTOR DATABASE MANAGER INTO FLASK-TSK APPLICATION

You are integrating Tantor, the database management elephant, into a Flask-TSK application. Tantor provides database operations, migrations, optimization, backup management, and performance monitoring.

REQUIREMENTS:
1. Import and initialize Tantor database manager
2. Set up database operation routes
3. Implement database migrations
4. Add performance optimization
5. Configure backup management
6. Set up database monitoring
7. Implement query optimization
8. Add database analytics
9. Configure connection pooling
10. Set up database security

IMPLEMENTATION STEPS:
1. Import Tantor: `from tsk_flask.herd.elephants.tantor import Tantor, init_tantor, get_tantor`
2. Initialize: `tantor = get_tantor()`
3. Create database operation routes
4. Implement database migrations and schema management
5. Add performance optimization and tuning
6. Configure backup management and recovery
7. Set up database monitoring and health checks
8. Implement query optimization and analysis
9. Add database analytics and reporting
10. Configure connection pooling and management
11. Set up database security and access control
12. Test all database functionality

EXAMPLE USAGE:
```python
from flask import Flask, request, jsonify
from tsk_flask.herd.elephants.tantor import get_tantor

app = Flask(__name__)
tantor = get_tantor()

@app.route('/database/status', methods=['GET'])
def database_status():
    status = tantor.stats()
    return jsonify(status)

@app.route('/database/migrate', methods=['POST'])
def run_migration():
    data = request.get_json()
    result = tantor.run_migration(data['migration_file'])
    return jsonify(result)

@app.route('/database/optimize', methods=['POST'])
def optimize_database():
    result = tantor.optimize()
    return jsonify(result)

@app.route('/database/backup', methods=['POST'])
def create_backup():
    result = tantor.create_backup()
    return jsonify(result)
```

CRITICAL CONSIDERATIONS:
- Implement proper database connection management
- Configure appropriate database security
- Add database backup and recovery procedures
- Monitor database performance and health
- Implement query optimization and caching
- Add database migration versioning
- Configure database access control
- Test database operations thoroughly
- Implement database monitoring and alerting
- Add database analytics and reporting
- Set up database maintenance schedules
- Configure database scaling and replication
```

---

## **GENERAL INTEGRATION GUIDELINES**

### **For All Elephant Integrations:**

1. **Always check elephant availability** before using
2. **Implement proper error handling** and user feedback
3. **Add comprehensive logging** for debugging
4. **Test thoroughly** with various inputs and scenarios
5. **Monitor performance** and resource usage
6. **Implement security best practices** for each elephant
7. **Add proper documentation** for your integration
8. **Consider scalability** and performance implications
9. **Implement proper cleanup** and resource management
10. **Add monitoring and alerting** for elephant health

### **Integration Checklist:**

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

**Remember: Each elephant is designed to work independently or together. Choose the elephants that best fit your application's needs!** 🐘 