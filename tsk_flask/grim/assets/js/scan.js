/**
 * Grim Scan Page - File System Scanner & Change Detection
 * Handles all scanning operations and file system analysis
 */

class GrimScan {
    constructor() {
        this.executor = new GrimExecutor();
        this.currentScan = null;
        this.scanResults = {
            newFiles: [],
            modifiedFiles: [],
            deletedFiles: [],
            largeFiles: [],
            duplicates: []
        };
        this.scanConfig = {
            paths: ['/home/user', '/etc'],
            exclusions: ['*.tmp', '*.cache', '/proc/*', '*.log'],
            schedule: 'daily',
            deepScan: 'weekly'
        };
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadScanConfig();
        this.updateStats();
        this.startLiveUpdates();
        
        console.log('Grim Scan initialized');
    }

    setupEventListeners() {
        // Scan control buttons
        document.getElementById('scan-btn')?.addEventListener('click', () => this.startFullScan());
        
        // Quick actions
        document.querySelectorAll('.action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.getAttribute('data-action');
                this.performScanAction(action);
            });
        });

        // Configuration controls
        document.querySelectorAll('.toggle-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.togglePath(e.currentTarget));
        });

        // Exclusion management
        document.querySelector('.add-exclusion button')?.addEventListener('click', () => this.addExclusion());
    }

    /**
     * Start a full system scan
     */
    async startFullScan() {
        try {
            this.updateScanStatus('Starting full scan...', 0);
            this.disableScanControls();
            
            const command = 'grim scan --full --verbose';
            this.currentScan = await this.executor.executeCommand(command);
            
            this.monitorScanProgress();
            
        } catch (error) {
            console.error('Scan failed:', error);
            this.updateScanStatus('Scan failed: ' + error.message, 0);
            this.enableScanControls();
        }
    }

    /**
     * Start a quick scan
     */
    async startQuickScan() {
        try {
            this.updateScanStatus('Starting quick scan...', 0);
            this.disableScanControls();
            
            const command = 'grim scan --quick';
            this.currentScan = await this.executor.executeCommand(command);
            
            this.monitorScanProgress();
            
        } catch (error) {
            console.error('Quick scan failed:', error);
            this.updateScanStatus('Quick scan failed: ' + error.message, 0);
            this.enableScanControls();
        }
    }

    /**
     * Monitor scan progress
     */
    async monitorScanProgress() {
        if (!this.currentScan) return;
        
        const pollInterval = setInterval(async () => {
            try {
                const status = await this.executor.getCommandStatus(this.currentScan.id);
                
                if (status.status === 'completed') {
                    clearInterval(pollInterval);
                    this.handleScanComplete(status.result);
                } else if (status.status === 'failed') {
                    clearInterval(pollInterval);
                    this.handleScanError(status.error);
                } else {
                    this.updateScanProgress(status.progress || 0, status.current_file || 'Scanning...');
                }
                
            } catch (error) {
                console.error('Error monitoring scan:', error);
            }
        }, 1000);
    }

    /**
     * Handle scan completion
     */
    handleScanComplete(result) {
        this.updateScanStatus('Scan completed successfully!', 100);
        this.enableScanControls();
        
        // Parse scan results
        this.parseScanResults(result);
        this.updateResultsDisplay();
        this.updateStats();
        
        // Add to activity feed
        this.addActivityItem('🔍', `Full system scan completed: ${this.scanResults.newFiles.length + this.scanResults.modifiedFiles.length} changes detected`);
    }

    /**
     * Parse scan results from Grim output
     */
    parseScanResults(result) {
        // Reset results
        this.scanResults = {
            newFiles: [],
            modifiedFiles: [],
            deletedFiles: [],
            largeFiles: [],
            duplicates: []
        };

        // Parse the result output (assuming JSON or structured output)
        try {
            const lines = result.output.split('\n');
            
            lines.forEach(line => {
                if (line.includes('NEW:')) {
                    this.scanResults.newFiles.push(this.parseFileInfo(line));
                } else if (line.includes('MODIFIED:')) {
                    this.scanResults.modifiedFiles.push(this.parseFileInfo(line));
                } else if (line.includes('DELETED:')) {
                    this.scanResults.deletedFiles.push(this.parseFileInfo(line));
                } else if (line.includes('LARGE:')) {
                    this.scanResults.largeFiles.push(this.parseFileInfo(line));
                }
            });
        } catch (error) {
            console.error('Error parsing scan results:', error);
        }
    }

    /**
     * Parse file information from scan output
     */
    parseFileInfo(line) {
        // Example: "NEW: /path/to/file.txt (1.2 MB)"
        const match = line.match(/(?:NEW|MODIFIED|DELETED|LARGE):\s+(.+?)\s+\((.+?)\)/);
        if (match) {
            return {
                path: match[1],
                size: match[2],
                icon: this.getFileIcon(match[1])
            };
        }
        return { path: line, size: 'Unknown', icon: '📄' };
    }

    /**
     * Get appropriate icon for file type
     */
    getFileIcon(path) {
        const ext = path.split('.').pop()?.toLowerCase();
        const icons = {
            'pdf': '📄', 'doc': '📝', 'docx': '📝',
            'jpg': '🖼️', 'jpeg': '🖼️', 'png': '🖼️', 'gif': '🖼️',
            'mp4': '🎬', 'avi': '🎬', 'mov': '🎬',
            'mp3': '🎵', 'wav': '🎵', 'flac': '🎵',
            'zip': '📦', 'tar': '📦', 'gz': '📦',
            'py': '🐍', 'js': '📜', 'php': '🐘', 'html': '🌐',
            'sql': '🗄️', 'db': '🗄️', 'sqlite': '🗄️',
            'log': '📋', 'txt': '📄', 'conf': '⚙️'
        };
        return icons[ext] || '📄';
    }

    /**
     * Update scan progress display
     */
    updateScanProgress(percentage, currentFile) {
        const progressBar = document.getElementById('scan-progress');
        const percentageSpan = document.querySelector('.scan-percentage');
        const currentFileSpan = document.getElementById('current-file');
        
        if (progressBar) progressBar.style.width = percentage + '%';
        if (percentageSpan) percentageSpan.textContent = percentage + '%';
        if (currentFileSpan) currentFileSpan.textContent = currentFile;
    }

    /**
     * Update scan status
     */
    updateScanStatus(message, percentage) {
        this.updateScanProgress(percentage, message);
    }

    /**
     * Disable scan controls during operation
     */
    disableScanControls() {
        const scanBtn = document.getElementById('scan-btn');
        const pauseBtn = document.getElementById('pause-btn');
        
        if (scanBtn) scanBtn.disabled = true;
        if (pauseBtn) pauseBtn.disabled = false;
    }

    /**
     * Enable scan controls after operation
     */
    enableScanControls() {
        const scanBtn = document.getElementById('scan-btn');
        const pauseBtn = document.getElementById('pause-btn');
        
        if (scanBtn) scanBtn.disabled = false;
        if (pauseBtn) pauseBtn.disabled = true;
    }

    /**
     * Perform specific scan actions
     */
    async performScanAction(action) {
        const actions = {
            'deep-scan': 'grim scan --deep --verbose',
            'smart-scan': 'grim scan-changes --smart',
            'duplicate-finder': 'grim dedup --find',
            'size-analyzer': 'grim scan --size-analysis',
            'integrity-check': 'grim hash --verify',
            'permission-scan': 'grim scan --permissions',
            'export-results': 'grim scan --export-json',
            'cleanup-temp': 'grim cleanup --temp-files'
        };

        const command = actions[action];
        if (!command) {
            console.error('Unknown action:', action);
            return;
        }

        try {
            this.updateScanStatus(`Starting ${action}...`, 0);
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.handleActionComplete(action, result);
            }
            
        } catch (error) {
            console.error(`${action} failed:`, error);
            this.updateScanStatus(`${action} failed: ${error.message}`, 0);
        }
    }

    /**
     * Handle action completion
     */
    handleActionComplete(action, result) {
        this.updateScanStatus(`${action} completed successfully!`, 100);
        
        // Add to activity feed
        const actionNames = {
            'deep-scan': 'Deep Filesystem Scan',
            'smart-scan': 'Smart Change Detection',
            'duplicate-finder': 'Find Duplicate Files',
            'size-analyzer': 'Disk Space Analyzer',
            'integrity-check': 'File Integrity Check',
            'permission-scan': 'Permission Scanner',
            'export-results': 'Export Scan Results',
            'cleanup-temp': 'Cleanup Temp Files'
        };
        
        this.addActivityItem('⚡', `${actionNames[action]} completed`);
        
        // Update results if applicable
        if (action === 'duplicate-finder') {
            this.parseDuplicateResults(result);
        }
    }

    /**
     * Update results display
     */
    updateResultsDisplay() {
        // Update new files
        this.updateCategoryDisplay('new-files', this.scanResults.newFiles);
        
        // Update modified files
        this.updateCategoryDisplay('modified-files', this.scanResults.modifiedFiles);
        
        // Update deleted files
        this.updateCategoryDisplay('deleted-files', this.scanResults.deletedFiles);
        
        // Update large files
        this.updateCategoryDisplay('large-files', this.scanResults.largeFiles);
    }

    /**
     * Update category display
     */
    updateCategoryDisplay(category, files) {
        const container = document.querySelector(`[data-category="${category}"]`);
        if (!container) return;
        
        const countElement = container.querySelector('.category-count');
        const detailsContainer = container.querySelector('.category-details');
        
        if (countElement) countElement.textContent = files.length;
        
        if (detailsContainer) {
            detailsContainer.innerHTML = files.map(file => `
                <div class="detail-item">
                    <span class="file-icon">${file.icon}</span>
                    <span class="file-path">${file.path}</span>
                    <span class="file-size">${file.size}</span>
                    <button class="action-btn-mini">${this.getActionButton(category)}</button>
                </div>
            `).join('');
        }
    }

    /**
     * Get appropriate action button for category
     */
    getActionButton(category) {
        const actions = {
            'new-files': 'Include',
            'modified-files': 'Backup',
            'deleted-files': 'Restore',
            'large-files': 'Compress'
        };
        return actions[category] || 'Action';
    }

    /**
     * Update statistics
     */
    updateStats() {
        const totalChanges = this.scanResults.newFiles.length + 
                           this.scanResults.modifiedFiles.length + 
                           this.scanResults.deletedFiles.length;
        
        // Update stats cards
        this.updateStatCard('files-scanned', '2.4M');
        this.updateStatCard('changes-detected', totalChanges.toString());
        this.updateStatCard('scan-performance', '1.2k/s');
        this.updateStatCard('exclusions-active', this.scanConfig.exclusions.length.toString());
    }

    /**
     * Update individual stat card
     */
    updateStatCard(statId, value) {
        const statElement = document.querySelector(`[data-stat="${statId}"] .stat-value`);
        if (statElement) {
            statElement.textContent = value;
        }
    }

    /**
     * Add activity item to timeline
     */
    addActivityItem(icon, title) {
        const activityFeed = document.querySelector('.activity-feed');
        if (!activityFeed) return;
        
        const activityItem = document.createElement('div');
        activityItem.className = 'activity-item';
        activityItem.innerHTML = `
            <div class="activity-icon" style="background: #28a745;">${icon}</div>
            <div class="activity-content">
                <div class="activity-title">${title}</div>
                <div class="activity-time">Just now</div>
            </div>
        `;
        
        activityFeed.insertBefore(activityItem, activityFeed.firstChild);
        
        // Remove old items if too many
        const items = activityFeed.querySelectorAll('.activity-item');
        if (items.length > 10) {
            items[items.length - 1].remove();
        }
    }

    /**
     * Load scan configuration
     */
    loadScanConfig() {
        // Load from localStorage or default config
        const saved = localStorage.getItem('grim-scan-config');
        if (saved) {
            this.scanConfig = { ...this.scanConfig, ...JSON.parse(saved) };
        }
        
        this.updateConfigDisplay();
    }

    /**
     * Save scan configuration
     */
    saveScanConfig() {
        localStorage.setItem('grim-scan-config', JSON.stringify(this.scanConfig));
    }

    /**
     * Update configuration display
     */
    updateConfigDisplay() {
        // Update paths
        this.updatePathDisplay();
        
        // Update exclusions
        this.updateExclusionDisplay();
        
        // Update schedule settings
        this.updateScheduleDisplay();
    }

    /**
     * Update path display
     */
    updatePathDisplay() {
        const pathItems = document.querySelectorAll('.path-item');
        pathItems.forEach(item => {
            const pathName = item.querySelector('.path-name').textContent;
            const toggleBtn = item.querySelector('.toggle-btn');
            
            if (this.scanConfig.paths.includes(pathName)) {
                toggleBtn.classList.add('active');
                toggleBtn.textContent = '✓';
            } else {
                toggleBtn.classList.remove('active');
                toggleBtn.textContent = '○';
            }
        });
    }

    /**
     * Update exclusion display
     */
    updateExclusionDisplay() {
        const exclusionList = document.querySelector('.exclusion-list');
        if (!exclusionList) return;
        
        exclusionList.innerHTML = '';
        this.scanConfig.exclusions.forEach(pattern => {
            const item = document.createElement('div');
            item.className = 'exclusion-item';
            item.innerHTML = `
                <span class="exclusion-pattern">${pattern}</span>
                <button class="remove-btn" onclick="removeExclusion('${pattern}')">×</button>
            `;
            exclusionList.appendChild(item);
        });
    }

    /**
     * Update schedule display
     */
    updateScheduleDisplay() {
        // Update schedule settings display
        const scheduleSelect = document.querySelector('.schedule-select');
        if (scheduleSelect) {
            scheduleSelect.value = this.scanConfig.schedule;
        }
    }

    /**
     * Toggle scan path
     */
    togglePath(button) {
        const pathItem = button.closest('.path-item');
        const pathName = pathItem.querySelector('.path-name').textContent;
        
        if (button.classList.contains('active')) {
            button.classList.remove('active');
            button.textContent = '○';
            this.scanConfig.paths = this.scanConfig.paths.filter(p => p !== pathName);
        } else {
            button.classList.add('active');
            button.textContent = '✓';
            this.scanConfig.paths.push(pathName);
        }
        
        this.saveScanConfig();
    }

    /**
     * Add exclusion pattern
     */
    addExclusion() {
        const input = document.querySelector('.exclusion-input');
        const pattern = input.value.trim();
        
        if (pattern && !this.scanConfig.exclusions.includes(pattern)) {
            this.scanConfig.exclusions.push(pattern);
            this.updateExclusionDisplay();
            this.saveScanConfig();
            input.value = '';
        }
    }

    /**
     * Remove exclusion pattern
     */
    removeExclusion(pattern) {
        this.scanConfig.exclusions = this.scanConfig.exclusions.filter(p => p !== pattern);
        this.updateExclusionDisplay();
        this.saveScanConfig();
    }

    /**
     * Toggle switch element
     */
    toggleSwitch(element) {
        element.classList.toggle('active');
        this.saveScanConfig();
    }

    /**
     * Pause current scan
     */
    pauseScan() {
        if (this.currentScan) {
            this.updateScanStatus('Scan paused', this.currentProgress || 0);
            this.enableScanControls();
            // In a real implementation, we'd send a pause command to the backend
        }
    }

    /**
     * Start live updates
     */
    startLiveUpdates() {
        // Update stats every 30 seconds
        setInterval(() => {
            this.updateStats();
        }, 30000);
    }
}

// Initialize scan functionality when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.grimScan = new GrimScan();
});

// Global functions for HTML onclick handlers
window.startFullScan = () => window.grimScan?.startFullScan();
window.startQuickScan = () => window.grimScan?.startQuickScan();
window.pauseScan = () => window.grimScan?.pauseScan();
window.performScanAction = (action) => window.grimScan?.performScanAction(action);
window.togglePath = (button) => window.grimScan?.togglePath(button);
window.toggleSwitch = (element) => window.grimScan?.toggleSwitch(element);
window.removeExclusion = (pattern) => window.grimScan?.removeExclusion(pattern);