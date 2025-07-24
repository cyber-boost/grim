/**
 * Grim Admin Interface - Main Controller
 * Handles all admin page functionality and Grim command integration
 */

class GrimAdmin {
    constructor() {
        this.executor = new GrimExecutor();
        this.currentPage = this.getCurrentPage();
        this.activeCommands = new Map();
        this.commandHistory = [];
        
        this.init();
    }

    /**
     * Initialize admin interface
     */
    init() {
        this.setupEventListeners();
        this.loadPageSpecificFunctionality();
        this.startStatusUpdates();
        
        console.log(`Grim Admin initialized for page: ${this.currentPage}`);
    }

    /**
     * Get current admin page
     */
    getCurrentPage() {
        const path = window.location.pathname;
        if (path.includes('/admin/')) {
            return path.split('/admin/')[1] || 'dashboard';
        }
        return 'dashboard';
    }

    /**
     * Setup global event listeners
     */
    setupEventListeners() {
        // Command execution buttons
        document.addEventListener('click', (e) => {
            if (e.target.matches('[data-grim-command]')) {
                e.preventDefault();
                this.executeGrimCommand(e.target.dataset.grimCommand, e.target.dataset.grimArgs);
            }
            
            if (e.target.matches('[data-grim-action]')) {
                e.preventDefault();
                this.handleGrimAction(e.target.dataset.grimAction, e.target.dataset);
            }
        });

        // Real-time updates
        setInterval(() => {
            this.updateActiveCommands();
        }, 2000);
    }

    /**
     * Load page-specific functionality
     */
    loadPageSpecificFunctionality() {
        switch (this.currentPage) {
            case 'scan':
                this.initScanPage();
                break;
            case 'backup':
                this.initBackupPage();
                break;
            case 'audit':
                this.initAuditPage();
                break;
            case 'logs':
                this.initLogsPage();
                break;
            case 'license':
                this.initLicensePage();
                break;
            case 'settings':
                this.initSettingsPage();
                break;
            case 'scythe':
                this.initScythePage();
                break;
            case 'reaper':
                this.initReaperPage();
                break;
            case 'users':
                this.initUsersPage();
                break;
            default:
                this.initDashboard();
        }
    }

    /**
     * Execute Grim command with UI feedback
     */
    async executeGrimCommand(commandType, args = {}) {
        try {
            // Show loading state
            this.showCommandLoading(commandType);
            
            // Execute command
            const commandId = await this.executor.executeCommand(commandType, args);
            
            // Track active command
            this.activeCommands.set(commandId, {
                type: commandType,
                args: args,
                startTime: Date.now(),
                status: 'running'
            });
            
            // Set up completion callback
            this.executor.onCommandComplete(commandId, (result) => {
                this.handleCommandComplete(commandId, result);
            });
            
            return commandId;
        } catch (error) {
            console.error('Command execution failed:', error);
            this.showCommandError(commandType, error.message);
        }
    }

    /**
     * Handle command completion
     */
    handleCommandComplete(commandId, result) {
        const command = this.activeCommands.get(commandId);
        if (command) {
            command.status = result.success ? 'completed' : 'failed';
            command.result = result;
            command.endTime = Date.now();
            
            // Update UI
            this.updateCommandStatus(commandId, result);
            
            // Add to history
            this.commandHistory.unshift({
                id: commandId,
                ...command,
                timestamp: new Date()
            });
            
            // Keep history manageable
            if (this.commandHistory.length > 100) {
                this.commandHistory = this.commandHistory.slice(0, 100);
            }
        }
    }

    /**
     * Show command loading state
     */
    showCommandLoading(commandType) {
        const loadingEl = document.getElementById('command-loading');
        if (loadingEl) {
            loadingEl.style.display = 'block';
            loadingEl.innerHTML = `
                <div class="loading-spinner"></div>
                <span>Executing: ${commandType}</span>
            `;
        }
    }

    /**
     * Show command error
     */
    showCommandError(commandType, error) {
        const errorEl = document.getElementById('command-error');
        if (errorEl) {
            errorEl.style.display = 'block';
            errorEl.innerHTML = `
                <div class="error-icon">❌</div>
                <span>Error executing ${commandType}: ${error}</span>
            `;
            
            setTimeout(() => {
                errorEl.style.display = 'none';
            }, 5000);
        }
    }

    /**
     * Update command status in UI
     */
    updateCommandStatus(commandId, result) {
        const statusEl = document.getElementById(`command-status-${commandId}`);
        if (statusEl) {
            const statusClass = result.success ? 'success' : 'error';
            statusEl.className = `command-status ${statusClass}`;
            statusEl.innerHTML = `
                <span class="status-icon">${result.success ? '✅' : '❌'}</span>
                <span class="status-text">${result.success ? 'Completed' : 'Failed'}</span>
                <span class="execution-time">${result.execution_time.toFixed(2)}s</span>
            `;
        }
    }

    /**
     * Update active commands display
     */
    async updateActiveCommands() {
        const activeCommands = this.executor.getActiveCommands();
        const activeEl = document.getElementById('active-commands');
        
        if (activeEl && activeCommands.length > 0) {
            activeEl.innerHTML = activeCommands.map(cmd => `
                <div class="active-command">
                    <span class="command-type">${cmd.type}</span>
                    <span class="command-status running">Running...</span>
                    <span class="command-time">${((Date.now() - cmd.startTime) / 1000).toFixed(1)}s</span>
                </div>
            `).join('');
        } else if (activeEl) {
            activeEl.innerHTML = '<div class="no-active">No active commands</div>';
        }
    }

    /**
     * Start status updates
     */
    startStatusUpdates() {
        // Update system status every 30 seconds
        setInterval(async () => {
            try {
                const status = await this.executor.getExecutorStatus();
                this.updateSystemStatus(status);
            } catch (error) {
                console.error('Status update failed:', error);
            }
        }, 30000);
    }

    /**
     * Update system status display
     */
    updateSystemStatus(status) {
        const statusEl = document.getElementById('system-status');
        if (statusEl) {
            statusEl.innerHTML = `
                <div class="status-item">
                    <span class="status-label">Executor:</span>
                    <span class="status-value ${status.executor_running ? 'online' : 'offline'}">
                        ${status.executor_running ? '🟢 Online' : '🔴 Offline'}
                    </span>
                </div>
                <div class="status-item">
                    <span class="status-label">Active Commands:</span>
                    <span class="status-value">${status.active_commands}</span>
                </div>
                <div class="status-item">
                    <span class="status-label">Total Executed:</span>
                    <span class="status-value">${status.total_commands}</span>
                </div>
            `;
        }
    }

    /**
     * Handle Grim actions (non-command operations)
     */
    handleGrimAction(action, data) {
        switch (action) {
            case 'refresh':
                this.refreshCurrentPage();
                break;
            case 'export':
                this.exportData(data);
                break;
            case 'import':
                this.importData(data);
                break;
            case 'clear':
                this.clearData(data);
                break;
            default:
                console.warn('Unknown action:', action);
        }
    }

    /**
     * Refresh current page data
     */
    refreshCurrentPage() {
        this.loadPageSpecificFunctionality();
    }

    /**
     * Export data
     */
    exportData(data) {
        const exportType = data.exportType || 'json';
        const exportData = data.exportData || this.commandHistory;
        
        const blob = new Blob([JSON.stringify(exportData, null, 2)], {
            type: 'application/json'
        });
        
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `grim-export-${Date.now()}.${exportType}`;
        a.click();
        URL.revokeObjectURL(url);
    }

    /**
     * Import data
     */
    importData(data) {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.json';
        input.onchange = (e) => {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = (e) => {
                    try {
                        const importedData = JSON.parse(e.target.result);
                        this.handleImportedData(importedData);
                    } catch (error) {
                        console.error('Import failed:', error);
                        this.showNotification('Import failed: Invalid file format', 'error');
                    }
                };
                reader.readAsText(file);
            }
        };
        input.click();
    }

    /**
     * Handle imported data
     */
    handleImportedData(data) {
        // Handle different types of imported data
        if (data.commandHistory) {
            this.commandHistory = data.commandHistory;
            this.showNotification('Command history imported successfully', 'success');
        } else if (data.config) {
            this.updateConfig(data.config);
            this.showNotification('Configuration imported successfully', 'success');
        }
    }

    /**
     * Clear data
     */
    clearData(data) {
        const clearType = data.clearType || 'history';
        
        if (confirm(`Are you sure you want to clear ${clearType}?`)) {
            switch (clearType) {
                case 'history':
                    this.commandHistory = [];
                    break;
                case 'logs':
                    this.executeGrimCommand('logs', { action: 'clear' });
                    break;
                case 'temp':
                    this.executeGrimCommand('cleanup', { temp: true });
                    break;
            }
            this.showNotification(`${clearType} cleared successfully`, 'success');
        }
    }

    /**
     * Show notification
     */
    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <span class="notification-icon">${type === 'success' ? '✅' : type === 'error' ? '❌' : 'ℹ️'}</span>
            <span class="notification-message">${message}</span>
            <button class="notification-close" onclick="this.parentElement.remove()">×</button>
        `;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 5000);
    }

    // Page-specific initialization methods
    initDashboard() {
        // Dashboard specific functionality
        this.loadDashboardStats();
    }

    initScanPage() {
        // Scan page functionality
        this.setupScanControls();
    }

    initBackupPage() {
        // Backup page functionality
        this.setupBackupControls();
    }

    initAuditPage() {
        // Audit page functionality
        this.setupAuditControls();
    }

    initLogsPage() {
        // Logs page functionality
        this.setupLogsControls();
    }

    initLicensePage() {
        // License page functionality
        this.setupLicenseControls();
    }

    initSettingsPage() {
        // Settings page functionality
        this.setupSettingsControls();
    }

    initScythePage() {
        // Scythe page functionality
        this.setupScytheControls();
    }

    initReaperPage() {
        // Reaper page functionality
        this.setupReaperControls();
    }

    initUsersPage() {
        // Users page functionality
        this.setupUsersControls();
    }

    // Page-specific setup methods (to be implemented)
    loadDashboardStats() {
        // Load dashboard statistics
    }

    setupScanControls() {
        // Setup scan page controls
    }

    setupBackupControls() {
        // Setup backup page controls
    }

    setupAuditControls() {
        // Setup audit page controls
    }

    setupLogsControls() {
        // Setup logs page controls
    }

    setupLicenseControls() {
        // Setup license page controls
    }

    setupSettingsControls() {
        // Setup settings page controls
    }

    setupScytheControls() {
        // Setup scythe page controls
    }

    setupReaperControls() {
        // Setup reaper page controls
    }

    setupUsersControls() {
        // Setup users page controls
    }
}

// Initialize Grim Admin when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.grimAdmin = new GrimAdmin();
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GrimAdmin;
} 