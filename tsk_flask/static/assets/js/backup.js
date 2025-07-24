/**
 * Grim Backup Page - Backup Management & Scheduling
 * Handles all backup operations, restoration, and scheduling
 */

class GrimBackup {
    constructor() {
        this.executor = new GrimExecutor();
        this.backups = [];
        this.schedules = [];
        this.currentOperation = null;
        this.backupConfig = {
            retention: 30,
            compression: true,
            encryption: false,
            verify: true,
            incremental: true
        };
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadBackupConfig();
        this.loadBackups();
        this.loadSchedules();
        this.updateStats();
        this.startLiveUpdates();
        
        console.log('Grim Backup initialized');
    }

    setupEventListeners() {
        // Backup creation
        document.getElementById('create-backup-btn')?.addEventListener('click', () => this.createBackup());
        
        // Quick actions
        document.querySelectorAll('.backup-action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.getAttribute('data-action');
                this.performBackupAction(action);
            });
        });

        // Schedule management
        document.getElementById('add-schedule-btn')?.addEventListener('click', () => this.addSchedule());
        
        // Configuration controls
        document.querySelectorAll('.config-toggle').forEach(toggle => {
            toggle.addEventListener('change', (e) => this.updateConfig(e.target));
        });
    }

    /**
     * Create a new backup
     */
    async createBackup() {
        try {
            const backupName = document.getElementById('backup-name')?.value || `backup-${Date.now()}`;
            const backupPath = document.getElementById('backup-path')?.value || '/';
            
            this.updateBackupStatus('Creating backup...', 0);
            this.disableBackupControls();
            
            const command = `grim backup --name "${backupName}" --path "${backupPath}" --retention ${this.backupConfig.retention}`;
            this.currentOperation = await this.executor.executeCommand(command);
            
            this.monitorBackupProgress();
            
        } catch (error) {
            console.error('Backup creation failed:', error);
            this.updateBackupStatus('Backup failed: ' + error.message, 0);
            this.enableBackupControls();
        }
    }

    /**
     * Monitor backup progress
     */
    async monitorBackupProgress() {
        if (!this.currentOperation) return;
        
        const pollInterval = setInterval(async () => {
            try {
                const status = await this.executor.getCommandStatus(this.currentOperation.id);
                
                if (status.status === 'completed') {
                    clearInterval(pollInterval);
                    this.handleBackupComplete(status.result);
                } else if (status.status === 'failed') {
                    clearInterval(pollInterval);
                    this.handleBackupError(status.error);
                } else {
                    this.updateBackupProgress(status.progress || 0, status.current_file || 'Backing up...');
                }
                
            } catch (error) {
                console.error('Error monitoring backup:', error);
            }
        }, 1000);
    }

    /**
     * Handle backup completion
     */
    handleBackupComplete(result) {
        this.updateBackupStatus('Backup completed successfully!', 100);
        this.enableBackupControls();
        
        // Parse backup result
        this.parseBackupResult(result);
        this.loadBackups(); // Refresh backup list
        this.updateStats();
        
        // Add to activity feed
        this.addActivityItem('💾', 'Backup created successfully');
    }

    /**
     * Parse backup result
     */
    parseBackupResult(result) {
        try {
            // Parse backup information from result
            const backupInfo = {
                id: Date.now(),
                name: result.backup_name || `backup-${Date.now()}`,
                size: result.size || 'Unknown',
                created: new Date().toISOString(),
                status: 'completed',
                path: result.path || '/'
            };
            
            this.backups.unshift(backupInfo);
            
        } catch (error) {
            console.error('Error parsing backup result:', error);
        }
    }

    /**
     * Load existing backups
     */
    async loadBackups() {
        try {
            const command = 'grim backup-list --json';
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.parseBackupList(result.output);
                this.updateBackupDisplay();
            }
            
        } catch (error) {
            console.error('Error loading backups:', error);
        }
    }

    /**
     * Parse backup list from Grim output
     */
    parseBackupList(output) {
        try {
            // Parse JSON output or structured text
            const lines = output.split('\n');
            this.backups = [];
            
            lines.forEach(line => {
                if (line.trim()) {
                    const backup = this.parseBackupLine(line);
                    if (backup) {
                        this.backups.push(backup);
                    }
                }
            });
            
        } catch (error) {
            console.error('Error parsing backup list:', error);
        }
    }

    /**
     * Parse individual backup line
     */
    parseBackupLine(line) {
        // Example: "backup-1234567890 2024-01-15 10:30:00 1.2GB /home/user completed"
        const match = line.match(/(\S+)\s+(\S+\s+\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
        if (match) {
            return {
                id: match[1],
                created: match[2],
                size: match[3],
                path: match[4],
                status: match[5]
            };
        }
        return null;
    }

    /**
     * Update backup display
     */
    updateBackupDisplay() {
        const container = document.querySelector('.backup-list');
        if (!container) return;
        
        container.innerHTML = this.backups.map(backup => `
            <div class="backup-item" data-backup-id="${backup.id}">
                <div class="backup-info">
                    <div class="backup-name">${backup.name || backup.id}</div>
                    <div class="backup-details">
                        <span class="backup-date">${this.formatDate(backup.created)}</span>
                        <span class="backup-size">${backup.size}</span>
                        <span class="backup-path">${backup.path}</span>
                    </div>
                </div>
                <div class="backup-status ${backup.status}">${backup.status}</div>
                <div class="backup-actions">
                    <button class="btn btn-secondary" onclick="grimBackup.restoreBackup('${backup.id}')">
                        <span>🔄</span> Restore
                    </button>
                    <button class="btn btn-secondary" onclick="grimBackup.verifyBackup('${backup.id}')">
                        <span>✅</span> Verify
                    </button>
                    <button class="btn btn-danger" onclick="grimBackup.deleteBackup('${backup.id}')">
                        <span>🗑️</span> Delete
                    </button>
                </div>
            </div>
        `).join('');
    }

    /**
     * Restore a backup
     */
    async restoreBackup(backupId) {
        if (!confirm(`Are you sure you want to restore backup ${backupId}? This will overwrite current data.`)) {
            return;
        }
        
        try {
            this.updateBackupStatus('Restoring backup...', 0);
            this.disableBackupControls();
            
            const command = `grim restore --backup "${backupId}" --confirm`;
            this.currentOperation = await this.executor.executeCommand(command);
            
            this.monitorRestoreProgress();
            
        } catch (error) {
            console.error('Restore failed:', error);
            this.updateBackupStatus('Restore failed: ' + error.message, 0);
            this.enableBackupControls();
        }
    }

    /**
     * Monitor restore progress
     */
    async monitorRestoreProgress() {
        if (!this.currentOperation) return;
        
        const pollInterval = setInterval(async () => {
            try {
                const status = await this.executor.getCommandStatus(this.currentOperation.id);
                
                if (status.status === 'completed') {
                    clearInterval(pollInterval);
                    this.handleRestoreComplete();
                } else if (status.status === 'failed') {
                    clearInterval(pollInterval);
                    this.handleRestoreError(status.error);
                } else {
                    this.updateBackupProgress(status.progress || 0, status.current_file || 'Restoring...');
                }
                
            } catch (error) {
                console.error('Error monitoring restore:', error);
            }
        }, 1000);
    }

    /**
     * Handle restore completion
     */
    handleRestoreComplete() {
        this.updateBackupStatus('Restore completed successfully!', 100);
        this.enableBackupControls();
        
        this.addActivityItem('🔄', 'Backup restored successfully');
        
        setTimeout(() => {
            this.updateBackupStatus('Ready', 0);
        }, 3000);
    }

    /**
     * Verify a backup
     */
    async verifyBackup(backupId) {
        try {
            this.updateBackupStatus('Verifying backup...', 0);
            
            const command = `grim backup --verify "${backupId}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateBackupStatus('Backup verification completed!', 100);
                this.addActivityItem('✅', `Backup ${backupId} verified successfully`);
            } else {
                this.updateBackupStatus('Backup verification failed!', 0);
                this.addActivityItem('❌', `Backup ${backupId} verification failed`);
            }
            
        } catch (error) {
            console.error('Verification failed:', error);
            this.updateBackupStatus('Verification failed: ' + error.message, 0);
        }
    }

    /**
     * Delete a backup
     */
    async deleteBackup(backupId) {
        if (!confirm(`Are you sure you want to delete backup ${backupId}? This action cannot be undone.`)) {
            return;
        }
        
        try {
            this.updateBackupStatus('Deleting backup...', 0);
            
            const command = `grim backup --delete "${backupId}" --confirm`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.updateBackupStatus('Backup deleted successfully!', 100);
                this.loadBackups(); // Refresh list
                this.updateStats();
                this.addActivityItem('🗑️', `Backup ${backupId} deleted`);
            } else {
                this.updateBackupStatus('Backup deletion failed!', 0);
            }
            
        } catch (error) {
            console.error('Deletion failed:', error);
            this.updateBackupStatus('Deletion failed: ' + error.message, 0);
        }
    }

    /**
     * Load backup schedules
     */
    async loadSchedules() {
        try {
            const command = 'grim backup-schedule --list';
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.parseScheduleList(result.output);
                this.updateScheduleDisplay();
            }
            
        } catch (error) {
            console.error('Error loading schedules:', error);
        }
    }

    /**
     * Parse schedule list
     */
    parseScheduleList(output) {
        try {
            const lines = output.split('\n');
            this.schedules = [];
            
            lines.forEach(line => {
                if (line.trim()) {
                    const schedule = this.parseScheduleLine(line);
                    if (schedule) {
                        this.schedules.push(schedule);
                    }
                }
            });
            
        } catch (error) {
            console.error('Error parsing schedule list:', error);
        }
    }

    /**
     * Parse individual schedule line
     */
    parseScheduleLine(line) {
        // Example: "daily-backup daily 02:00 /home/user enabled"
        const match = line.match(/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
        if (match) {
            return {
                name: match[1],
                frequency: match[2],
                time: match[3],
                path: match[4],
                status: match[5]
            };
        }
        return null;
    }

    /**
     * Update schedule display
     */
    updateScheduleDisplay() {
        const container = document.querySelector('.schedule-list');
        if (!container) return;
        
        container.innerHTML = this.schedules.map(schedule => `
            <div class="schedule-item" data-schedule-name="${schedule.name}">
                <div class="schedule-info">
                    <div class="schedule-name">${schedule.name}</div>
                    <div class="schedule-details">
                        <span class="schedule-frequency">${schedule.frequency}</span>
                        <span class="schedule-time">${schedule.time}</span>
                        <span class="schedule-path">${schedule.path}</span>
                    </div>
                </div>
                <div class="schedule-status ${schedule.status}">${schedule.status}</div>
                <div class="schedule-actions">
                    <button class="btn btn-secondary" onclick="grimBackup.toggleSchedule('${schedule.name}')">
                        <span>${schedule.status === 'enabled' ? '⏸️' : '▶️'}</span>
                        ${schedule.status === 'enabled' ? 'Pause' : 'Enable'}
                    </button>
                    <button class="btn btn-danger" onclick="grimBackup.deleteSchedule('${schedule.name}')">
                        <span>🗑️</span> Delete
                    </button>
                </div>
            </div>
        `).join('');
    }

    /**
     * Add a new schedule
     */
    async addSchedule() {
        const name = document.getElementById('schedule-name')?.value;
        const frequency = document.getElementById('schedule-frequency')?.value;
        const time = document.getElementById('schedule-time')?.value;
        const path = document.getElementById('schedule-path')?.value;
        
        if (!name || !frequency || !time || !path) {
            alert('Please fill in all schedule fields');
            return;
        }
        
        try {
            const command = `grim backup-schedule --add --name "${name}" --frequency "${frequency}" --time "${time}" --path "${path}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.loadSchedules(); // Refresh list
                this.addActivityItem('📅', `Schedule "${name}" added successfully`);
                
                // Clear form
                document.getElementById('schedule-name').value = '';
                document.getElementById('schedule-frequency').value = '';
                document.getElementById('schedule-time').value = '';
                document.getElementById('schedule-path').value = '';
            }
            
        } catch (error) {
            console.error('Error adding schedule:', error);
            alert('Failed to add schedule: ' + error.message);
        }
    }

    /**
     * Toggle schedule status
     */
    async toggleSchedule(scheduleName) {
        try {
            const command = `grim backup-schedule --toggle "${scheduleName}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.loadSchedules(); // Refresh list
                this.addActivityItem('⚙️', `Schedule "${scheduleName}" toggled`);
            }
            
        } catch (error) {
            console.error('Error toggling schedule:', error);
        }
    }

    /**
     * Delete a schedule
     */
    async deleteSchedule(scheduleName) {
        if (!confirm(`Are you sure you want to delete schedule "${scheduleName}"?`)) {
            return;
        }
        
        try {
            const command = `grim backup-schedule --delete "${scheduleName}"`;
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.loadSchedules(); // Refresh list
                this.addActivityItem('🗑️', `Schedule "${scheduleName}" deleted`);
            }
            
        } catch (error) {
            console.error('Error deleting schedule:', error);
        }
    }

    /**
     * Perform specific backup actions
     */
    async performBackupAction(action) {
        const actions = {
            'full-backup': 'grim backup --full --all',
            'incremental-backup': 'grim backup --incremental',
            'verify-all': 'grim backup --verify-all',
            'cleanup-old': 'grim backup --cleanup --older-than 30',
            'export-backups': 'grim backup --export-list',
            'import-backups': 'grim backup --import',
            'backup-stats': 'grim backup --stats',
            'backup-health': 'grim backup --health-check'
        };

        const command = actions[action];
        if (!command) {
            console.error('Unknown action:', action);
            return;
        }

        try {
            this.updateBackupStatus(`Starting ${action}...`, 0);
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.handleActionComplete(action, result);
            }
            
        } catch (error) {
            console.error(`${action} failed:`, error);
            this.updateBackupStatus(`${action} failed: ${error.message}`, 0);
        }
    }

    /**
     * Handle action completion
     */
    handleActionComplete(action, result) {
        this.updateBackupStatus(`${action} completed successfully!`, 100);
        
        // Add to activity feed
        const actionNames = {
            'full-backup': 'Full System Backup',
            'incremental-backup': 'Incremental Backup',
            'verify-all': 'Verify All Backups',
            'cleanup-old': 'Cleanup Old Backups',
            'export-backups': 'Export Backup List',
            'import-backups': 'Import Backups',
            'backup-stats': 'Backup Statistics',
            'backup-health': 'Backup Health Check'
        };
        
        this.addActivityItem('⚡', `${actionNames[action]} completed`);
        
        // Refresh data if needed
        if (['full-backup', 'incremental-backup', 'cleanup-old'].includes(action)) {
            this.loadBackups();
            this.updateStats();
        }
    }

    /**
     * Update backup progress display
     */
    updateBackupProgress(percentage, currentFile) {
        const progressBar = document.getElementById('backup-progress');
        const percentageSpan = document.querySelector('.backup-percentage');
        const currentFileSpan = document.getElementById('backup-current-file');
        
        if (progressBar) progressBar.style.width = percentage + '%';
        if (percentageSpan) percentageSpan.textContent = percentage + '%';
        if (currentFileSpan) currentFileSpan.textContent = currentFile;
    }

    /**
     * Update backup status
     */
    updateBackupStatus(message, percentage) {
        this.updateBackupProgress(percentage, message);
    }

    /**
     * Disable backup controls during operation
     */
    disableBackupControls() {
        const createBtn = document.getElementById('create-backup-btn');
        if (createBtn) createBtn.disabled = true;
    }

    /**
     * Enable backup controls after operation
     */
    enableBackupControls() {
        const createBtn = document.getElementById('create-backup-btn');
        if (createBtn) createBtn.disabled = false;
    }

    /**
     * Update statistics
     */
    updateStats() {
        const totalBackups = this.backups.length;
        const totalSize = this.backups.reduce((sum, backup) => {
            const size = this.parseSize(backup.size);
            return sum + size;
        }, 0);
        
        const activeSchedules = this.schedules.filter(s => s.status === 'enabled').length;
        
        // Update stats cards
        this.updateStatCard('total-backups', totalBackups.toString());
        this.updateStatCard('total-size', this.formatSize(totalSize));
        this.updateStatCard('active-schedules', activeSchedules.toString());
        this.updateStatCard('last-backup', this.getLastBackupDate());
    }

    /**
     * Parse size string to bytes
     */
    parseSize(sizeStr) {
        const match = sizeStr.match(/(\d+(?:\.\d+)?)\s*(B|KB|MB|GB|TB)/i);
        if (!match) return 0;
        
        const value = parseFloat(match[1]);
        const unit = match[2].toUpperCase();
        
        const multipliers = { B: 1, KB: 1024, MB: 1024*1024, GB: 1024*1024*1024, TB: 1024*1024*1024*1024 };
        return value * multipliers[unit];
    }

    /**
     * Format bytes to human readable
     */
    formatSize(bytes) {
        const units = ['B', 'KB', 'MB', 'GB', 'TB'];
        let size = bytes;
        let unitIndex = 0;
        
        while (size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024;
            unitIndex++;
        }
        
        return `${size.toFixed(1)} ${units[unitIndex]}`;
    }

    /**
     * Get last backup date
     */
    getLastBackupDate() {
        if (this.backups.length === 0) return 'Never';
        
        const lastBackup = this.backups[0];
        return this.formatDate(lastBackup.created);
    }

    /**
     * Format date for display
     */
    formatDate(dateStr) {
        const date = new Date(dateStr);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
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
            <div class="activity-icon" style="background: #007bff;">${icon}</div>
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
     * Load backup configuration
     */
    loadBackupConfig() {
        const saved = localStorage.getItem('grim-backup-config');
        if (saved) {
            this.backupConfig = { ...this.backupConfig, ...JSON.parse(saved) };
        }
        
        this.updateConfigDisplay();
    }

    /**
     * Save backup configuration
     */
    saveBackupConfig() {
        localStorage.setItem('grim-backup-config', JSON.stringify(this.backupConfig));
    }

    /**
     * Update configuration display
     */
    updateConfigDisplay() {
        // Update toggles
        Object.keys(this.backupConfig).forEach(key => {
            const toggle = document.querySelector(`[data-config="${key}"]`);
            if (toggle) {
                toggle.checked = this.backupConfig[key];
            }
        });
    }

    /**
     * Update configuration
     */
    updateConfig(element) {
        const key = element.getAttribute('data-config');
        this.backupConfig[key] = element.checked;
        this.saveBackupConfig();
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

// Initialize backup functionality when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.grimBackup = new GrimBackup();
});

// Global functions for HTML onclick handlers
window.createBackup = () => window.grimBackup?.createBackup();
window.performBackupAction = (action) => window.grimBackup?.performBackupAction(action);
window.addSchedule = () => window.grimBackup?.addSchedule(); 