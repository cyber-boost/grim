# Grim Admin Dashboard - Page Creation Prompt

## Design System & Brand Guidelines

### Visual Identity
- **Primary Brand**: Grim Reaper - "The Reaper of Data Loss"
- **Personality**: Dark energy, professional with dark humor, enterprise-grade with personality
- **Color Palette**:
  - Primary: #8b4513 (Dark Brown), #654321 (Darker Brown)
  - Accent: #b8860b (Dark Goldenrod), #daa520 (Goldenrod)
  - Background: Linear gradients from #0a0a0a to #1a1a1a to #0d1117
  - Text: #e6e6e6 (Light), #ccc (Medium), #888-#999 (Muted)
  - Success: #28a745, Warning: #ffc107, Error: #dc3545

### Typography
- **Primary Font**: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif
- **Headers**: Arial Black for emphasis, Arial for regular headers
- **Code/Technical**: Monospace for technical elements
- **Weights**: 300 (light), 600 (semibold), 700 (bold), 900 (black)

### Layout Structure
```
Sidebar (280px fixed) + Main Content (margin-left: 280px)
├── Logo Section (Animated Data Scythe + "GRIM ADMIN PANEL")
├── Navigation Menu (12 items with icons and badges)
└── Main Content Area
    ├── Header (Page title + Action buttons + Status indicator)
    └── Content Sections
        ├── Stats Grid (4-column responsive cards)
        ├── System Status/Progress Bars
        ├── Main Content Area (tables, forms, charts)
        └── Activity/Quick Actions (2-column layout)
```

## Component Library

### 1. Stat Cards
```css
.stat-card {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(139, 69, 19, 0.2);
    border-radius: 12px;
    padding: 20px;
    transition: all 0.3s ease;
}
```

### 2. Buttons
- **Primary**: Linear gradient #8b4513 to #a0522d with hover lift effect
- **Secondary**: rgba(255,255,255,0.1) background with #444 border
- **Action Buttons**: Full width with left-aligned icons

### 3. Progress Bars
```css
.progress-bar {
    height: 6px;
    background: #333;
    border-radius: 3px;
    .progress-fill { background: linear-gradient(90deg, #8b4513, #b8860b); }
}
```

### 4. Activity Items
```css
.activity-item {
    display: flex;
    align-items: center;
    padding: 12px 0;
    border-bottom: 1px solid #333;
}
.activity-icon { 35px square, gradient background, centered emoji }
```

## Icon System
- **Reaper**: 💀 (Dashboard/Main)
- **Backup**: 💾 (Data Protection)
- **Scan**: 🔍 (File Discovery)
- **Hash**: 🔐 (Encryption)
- **Trash**: ♻️ (Deduplication)
- **Remote**: ☁️ (Cloud Storage)
- **Audit**: 🛡️ (Security)
- **Logs**: 📋 (Activity Tracking)
- **Settings**: ⚙️ (Configuration)
- **Scythe**: ⚔️ (License Protection)
- **Docs**: 📚 (Documentation)
- **Alerts**: 🔔 (Notifications)

## Page Creation Framework

### Page Template Structure
```html
<!-- Header Section -->
<header class="header">
    <h1 id="page-title">[PAGE NAME]</h1>
    <div class="header-actions">
        <!-- Page-specific action buttons -->
        <button class="btn btn-secondary"><!-- Icon --> Action</button>
        <button class="btn btn-primary"><!-- Icon --> Primary Action</button>
        <div class="status-indicator [online/warning/error]"></div>
        <span>Status Text</span>
    </div>
</header>

<!-- Main Content -->
<div class="dashboard-content">
    <!-- Stats Grid (Always include 4 relevant metrics) -->
    <div class="stats-grid">
        <div class="stat-card">
            <h3>[METRIC NAME]</h3>
            <div class="stat-value">[VALUE]</div>
            <div class="stat-label">[DESCRIPTION]</div>
        </div>
        <!-- Repeat 3 more times -->
    </div>

    <!-- Optional: System Status Bars -->
    <div class="system-status">
        <div class="status-item">
            <h4>[STATUS NAME]</h4>
            <div class="status-value">[VALUE]</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: [X]%"></div>
            </div>
        </div>
    </div>

    <!-- Main Page Content -->
    <div class="[page-specific-content]">
        <!-- Tables, forms, charts, etc. -->
    </div>

    <!-- Activity/Actions Section -->
    <div class="activity-section">
        <div class="activity-feed">
            <h3>[PAGE] Activity</h3>
            <!-- Activity items specific to this page -->
        </div>
        <div class="quick-actions">
            <h3>Quick Actions</h3>
            <!-- Action buttons specific to this page -->
        </div>
    </div>
</div>
```

## Content Guidelines for Each Page

### Backup Manager
- **Stats**: Total Backups, Success Rate, Next Backup, Storage Used
- **Content**: Backup schedule table, retention policies, backup history
- **Actions**: Create Backup, Schedule Management, Restore Point, View Logs

### File Scanner
- **Stats**: Files Scanned, Changes Detected, Scan Performance, Exclusions
- **Content**: Scan results table, exclusion patterns, file types analysis
- **Actions**: Full Scan, Quick Scan, Configure Exclusions, View Changes

### Encryption Hub
- **Stats**: Encrypted Files, Key Strength, Encryption Speed, Key Backups
- **Content**: Key management table, encryption settings, security audit
- **Actions**: Generate Key, Export Backup, Verify Integrity, Rotate Keys

### Deduplication Trash
- **Stats**: Space Saved, Chunks Stored, Deduplication Ratio, Garbage Collection
- **Content**: Chunk analysis, duplicate file reports, storage efficiency
- **Actions**: Run GC, View Statistics, Clean Orphans, Optimize Storage

### Remote Storage
- **Stats**: Sync Status, Bandwidth Usage, Remote Space, Last Sync
- **Content**: Remote endpoints table, sync logs, bandwidth charts
- **Actions**: Force Sync, Add Remote, Test Connection, Bandwidth Settings

### Security Audit
- **Stats**: Security Score, Vulnerabilities, Last Audit, Compliance Status
- **Content**: Security findings table, compliance reports, recommendations
- **Actions**: Run Audit, Fix Issues, Export Report, Schedule Audits

### System Logs
- **Stats**: Log Entries, Error Rate, Disk Usage, Retention Period
- **Content**: Live log viewer, log level filters, search functionality
- **Actions**: Clear Logs, Export Logs, Set Levels, Configure Rotation

### Settings
- **Stats**: Active Configs, Profiles, Override Count, Last Modified
- **Content**: Configuration forms, profile management, feature toggles
- **Actions**: Save Config, Create Profile, Reset Defaults, Export Settings

### Scythe License Manager
- **Stats**: Protected Software, License Status, Violations, Last Check
- **Content**: Software monitoring table, license details, violation reports
- **Actions**: Add Protection, License Scan, View Reports, Configure Alerts

### Documentation
- **Stats**: Docs Available, Last Updated, Help Requests, Community Links
- **Content**: Documentation browser, search, FAQ, tutorials
- **Actions**: Search Docs, Report Issue, Request Feature, Community Forum

### Notification Center
- **Stats**: Active Alerts, Notification Count, Channels, Response Time
- **Content**: Alert timeline, notification settings, channel configuration
- **Actions**: Mark Read, Configure Channels, Test Alerts, Set Preferences

## Animation & Interaction Patterns

### Hover Effects
- **Cards**: `transform: translateY(-5px)` + border color change
- **Buttons**: `transform: translateY(-2px)` + shadow increase
- **Nav Items**: `transform: translateX(5px)` + background change

### Loading States
- **Progress bars**: Animated width changes
- **Data updates**: Fade in/out transitions
- **Page transitions**: Slide/fade effects

### Status Indicators
- **Online**: Solid green circle
- **Warning**: Pulsing yellow circle
- **Error**: Blinking red circle
- **Loading**: Spinning animation

## Data Integration Patterns

### Real-time Updates
```javascript
// Auto-update stats every 30 seconds
setInterval(() => {
    updatePageStats();
    updateActivityFeed();
    updateNotificationBadges();
}, 30000);
```

### Page-specific Data Loading
```javascript
function loadPageContent(page) {
    // Fetch page-specific data
    // Update stats grid
    // Populate main content
    // Update activity feed
    // Configure quick actions
}
```

## Responsive Breakpoints
- **Desktop**: > 1200px (Full layout)
- **Tablet**: 768px - 1200px (Adjusted grid)
- **Mobile**: < 768px (Stacked layout, collapsible sidebar)

## Content Voice & Tone
- **Professional but edgy**: Technical accuracy with personality
- **Death/reaper themed**: "Reaping data loss", "Harvesting backups"
- **Action-oriented**: "Execute", "Deploy", "Terminate", "Harvest"
- **Confident**: "Data protected", "Threats eliminated", "System secured"

## Technical Implementation Notes
- Use CSS Grid for responsive layouts
- Implement backdrop-filter for glassmorphism effects
- Include smooth transitions (0.3s ease) for all interactions
- Maintain 12px border-radius for consistent rounded corners
- Use rgba() for transparency and layering effects
- Include proper accessibility with focus states and ARIA labels

## Example Page Request Format
"Create a [PAGE NAME] page for the Grim admin dashboard that includes:
- 4 relevant statistics cards showing [specific metrics]
- Main content area with [specific functionality]
- Activity feed showing [page-specific activities]
- Quick actions for [relevant operations]
- Follow the Grim design system with dark theme, reaper personality, and enterprise functionality
- Include hover effects, smooth animations, and responsive design
- Use the established color palette and typography
- Maintain the professional-but-edgy tone throughout"

---

This prompt ensures consistency across all pages while maintaining Grim's unique dark energy and professional functionality. Each new page should feel like a natural extension of the main dashboard while serving its specific purpose in the backup and system management ecosystem.