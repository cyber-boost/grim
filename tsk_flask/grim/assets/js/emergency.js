/**
 * Grim Emergency Page - Emergency Operations & System Recovery
 * Handles emergency operations, system recovery, and critical system management
 */

class GrimEmergency {
    constructor() {
        this.executor = new GrimExecutor();
        this.emergencyConfig = {
            autoHeal: true,
            healTimeout: 30,
            dataRepair: true,
            latestBackup: true,
            verifyBackup: true,
            restoreTimeout: 60,
            gracefulShutdown: 30,
            forceShutdown: true,
            saveState: true
        };
        this.currentOperation = null;
        this.systemStatus = 'safe';
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.loadEmergencyConfig();
        this.updateSystemStatus();
        this.updateStats();
        this.startLiveUpdates();
        
        console.log('Grim Emergency initialized');
    }

    setupEventListeners() {
        // Emergency action buttons
        document.querySelectorAll('.emergency-action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.getAttribute('data-action');
                this.performEmergencyAction(action);
            });
        });

        // Configuration controls
        document.querySelectorAll('.config-toggle').forEach(toggle => {
            toggle.addEventListener('change', (e) => this.updateConfig(e.target));
        });
    }

    /**
     * Perform emergency heal operation
     */
    async performEmergencyHeal() {
        if (!this.confirmEmergencyOperation('Emergency Heal', 'This will attempt to automatically repair critical system issues. Continue?')) {
            return;
        }
        
        try {
            this.updateEmergencyStatus('Starting emergency heal...', 0);
            this.showEmergencyProgress();
            this.disableEmergencyControls();
            
            const timeout = this.emergencyConfig.healTimeout;
            const dataRepair = this.emergencyConfig.dataRepair ? '--data-repair' : '';
            
            const command = `grim emergency-heal --timeout ${timeout} ${dataRepair} --auto`;
            this.currentOperation = await this.executor.executeCommand(command);
            
            this.monitorEmergencyOperation('heal');
            
        } catch (error) {
            console.error('Emergency heal failed:', error);
            this.updateEmergencyStatus('Emergency heal failed: ' + error.message, 0);
            this.enableEmergencyControls();
            this.hideEmergencyProgress();
        }
    }

    /**
     * Perform emergency restore operation
     */
    async performEmergencyRestore() {
        if (!this.confirmEmergencyOperation('Emergency Restore', 'This will restore the entire system from backup. This operation cannot be undone. Continue?')) {
            return;
        }
        
        try {
            this.updateEmergencyStatus('Starting emergency restore...', 0);
            this.showEmergencyProgress();
            this.disableEmergencyControls();
            
            const timeout = this.emergencyConfig.restoreTimeout;
            const verify = this.emergencyConfig.verifyBackup ? '--verify' : '';
            const latest = this.emergencyConfig.latestBackup ? '--latest' : '';
            
            const command = `grim emergency-restore --timeout ${timeout} ${verify} ${latest} --confirm`;
            this.currentOperation = await this.executor.executeCommand(command);
            
            this.monitorEmergencyOperation('restore');
            
        } catch (error) {
            console.error('Emergency restore failed:', error);
            this.updateEmergencyStatus('Emergency restore failed: ' + error.message, 0);
            this.enableEmergencyControls();
            this.hideEmergencyProgress();
        }
    }

    /**
     * Perform emergency shutdown operation
     */
    async performEmergencyShutdown() {
        if (!this.confirmEmergencyOperation('Emergency Shutdown', 'This will shut down the entire system immediately. This operation cannot be undone. Continue?')) {
            return;
        }
        
        try {
            this.updateEmergencyStatus('Starting emergency shutdown...', 0);
            this.showEmergencyProgress();
            this.disableEmergencyControls();
            
            const timeout = this.emergencyConfig.gracefulShutdown;
            const force = this.emergencyConfig.forceShutdown ? '--force' : '';
            const saveState = this.emergencyConfig.saveState ? '--save-state' : '';
            
            const command = `grim emergency-shutdown --timeout ${timeout} ${force} ${saveState} --confirm`;
            this.currentOperation = await this.executor.executeCommand(command);
            
            this.monitorEmergencyOperation('shutdown');
            
        } catch (error) {
            console.error('Emergency shutdown failed:', error);
            this.updateEmergencyStatus('Emergency shutdown failed: ' + error.message, 0);
            this.enableEmergencyControls();
            this.hideEmergencyProgress();
        }
    }

    /**
     * Monitor emergency operation progress
     */
    async monitorEmergencyOperation(operationType) {
        if (!this.currentOperation) return;
        
        const pollInterval = setInterval(async () => {
            try {
                const status = await this.executor.getCommandStatus(this.currentOperation.id);
                
                if (status.status === 'completed') {
                    clearInterval(pollInterval);
                    this.handleEmergencyOperationComplete(operationType, status.result);
                } else if (status.status === 'failed') {
                    clearInterval(pollInterval);
                    this.handleEmergencyOperationError(operationType, status.error);
                } else {
                    this.updateEmergencyProgress(status.progress || 0, status.current_operation || 'Processing...');
                }
                
            } catch (error) {
                console.error('Error monitoring emergency operation:', error);
            }
        }, 1000);
    }

    /**
     * Handle emergency operation completion
     */
    handleEmergencyOperationComplete(operationType, result) {
        this.updateEmergencyStatus(`${operationType} completed successfully!`, 100);
        this.enableEmergencyControls();
        this.hideEmergencyProgress();
        
        // Update system status
        this.updateSystemStatus();
        
        // Add to activity feed
        const operationNames = {
            'heal': 'Emergency Heal',
            'restore': 'Emergency Restore',
            'shutdown': 'Emergency Shutdown'
        };
        
        this.addActivityItem('✅', `${operationNames[operationType]} completed successfully`);
        
        // Add to emergency logs
        this.addEmergencyLog('success', `${operationNames[operationType]} completed successfully`);
        
        // Hide progress after delay
        setTimeout(() => {
            this.hideEmergencyProgress();
        }, 5000);
    }

    /**
     * Handle emergency operation error
     */
    handleEmergencyOperationError(operationType, error) {
        this.updateEmergencyStatus(`${operationType} failed: ${error}`, 0);
        this.enableEmergencyControls();
        this.hideEmergencyProgress();
        
        // Add to activity feed
        const operationNames = {
            'heal': 'Emergency Heal',
            'restore': 'Emergency Restore',
            'shutdown': 'Emergency Shutdown'
        };
        
        this.addActivityItem('❌', `${operationNames[operationType]} failed: ${error}`);
        
        // Add to emergency logs
        this.addEmergencyLog('error', `${operationNames[operationType]} failed: ${error}`);
    }

    /**
     * Perform specific emergency actions
     */
    async performEmergencyAction(action) {
        const actions = {
            'health-check': 'grim health --comprehensive --emergency',
            'backup-status': 'grim backup --status --emergency',
            'service-status': 'grim health --services --emergency',
            'emergency-test': 'grim emergency-heal --test --dry-run',
            'config-backup': 'grim config --backup --emergency',
            'emergency-report': 'grim emergency-heal --report --format html'
        };

        const command = actions[action];
        if (!command) {
            console.error('Unknown action:', action);
            return;
        }

        try {
            this.updateEmergencyStatus(`Starting ${action}...`, 0);
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.handleActionComplete(action, result);
            }
            
        } catch (error) {
            console.error(`${action} failed:`, error);
            this.updateEmergencyStatus(`${action} failed: ${error.message}`, 0);
        }
    }

    /**
     * Handle action completion
     */
    handleActionComplete(action, result) {
        this.updateEmergencyStatus(`${action} completed successfully!`, 100);
        
        // Add to activity feed
        const actionNames = {
            'health-check': 'System Health Check',
            'backup-status': 'Backup Status Check',
            'service-status': 'Service Status Check',
            'emergency-test': 'Emergency System Test',
            'config-backup': 'Configuration Backup',
            'emergency-report': 'Emergency Report Generated'
        };
        
        this.addActivityItem('📋', `${actionNames[action]} completed`);
        
        // Update stats if needed
        if (action === 'health-check') {
            this.updateSystemStatus();
            this.updateStats();
        }
    }

    /**
     * Update emergency progress display
     */
    updateEmergencyProgress(percentage, currentOperation) {
        const progressBar = document.getElementById('emergency-progress-fill');
        const percentageSpan = document.querySelector('.progress-percentage');
        const currentOperationSpan = document.getElementById('emergency-current-operation');
        
        if (progressBar) progressBar.style.width = percentage + '%';
        if (percentageSpan) percentageSpan.textContent = percentage + '%';
        if (currentOperationSpan) currentOperationSpan.textContent = currentOperation;
    }

    /**
     * Update emergency status
     */
    updateEmergencyStatus(message, percentage) {
        this.updateEmergencyProgress(percentage, message);
    }

    /**
     * Show emergency progress
     */
    showEmergencyProgress() {
        const progressElement = document.getElementById('emergency-progress');
        if (progressElement) {
            progressElement.style.display = 'block';
        }
    }

    /**
     * Hide emergency progress
     */
    hideEmergencyProgress() {
        const progressElement = document.getElementById('emergency-progress');
        if (progressElement) {
            progressElement.style.display = 'none';
        }
    }

    /**
     * Disable emergency controls during operation
     */
    disableEmergencyControls() {
        const buttons = document.querySelectorAll('.btn-emergency, .btn-extreme');
        buttons.forEach(btn => {
            btn.disabled = true;
        });
    }

    /**
     * Enable emergency controls after operation
     */
    enableEmergencyControls() {
        const buttons = document.querySelectorAll('.btn-emergency, .btn-extreme');
        buttons.forEach(btn => {
            btn.disabled = false;
        });
    }

    /**
     * Confirm emergency operation
     */
    confirmEmergencyOperation(title, message) {
        return confirm(`🚨 ${title}\n\n${message}\n\nThis is an emergency operation that may affect system stability.`);
    }

    /**
     * Update system status
     */
    async updateSystemStatus() {
        try {
            const command = 'grim health --quick --json';
            const result = await this.executor.executeCommand(command);
            
            if (result.status === 'completed') {
                this.parseSystemStatus(result.output);
                this.updateStatusDisplay();
            }
            
        } catch (error) {
            console.error('Error updating system status:', error);
            this.systemStatus = 'unknown';
        }
    }

    /**
     * Parse system status from output
     */
    parseSystemStatus(output) {
        try {
            // Parse health status from output
            if (output.includes('healthy') || output.includes('optimal')) {
                this.systemStatus = 'safe';
            } else if (output.includes('warning') || output.includes('degraded')) {
                this.systemStatus = 'warning';
            } else if (output.includes('critical') || output.includes('failed')) {
                this.systemStatus = 'critical';
            } else {
                this.systemStatus = 'unknown';
            }
        } catch (error) {
            console.error('Error parsing system status:', error);
            this.systemStatus = 'unknown';
        }
    }

    /**
     * Update status display
     */
    updateStatusDisplay() {
        const statusIndicator = document.querySelector('.status-indicator');
        const statusIcon = document.querySelector('.status-icon');
        const statusText = document.querySelector('.status-text h2');
        const statusDesc = document.querySelector('.status-text p');
        
        if (!statusIndicator) return;
        
        // Remove existing status classes
        statusIndicator.className = 'status-indicator';
        
        // Add new status class and update content
        switch (this.systemStatus) {
            case 'safe':
                statusIndicator.classList.add('safe');
                if (statusIcon) statusIcon.textContent = '🟢';
                if (statusText) statusText.textContent = 'System Status: SAFE';
                if (statusDesc) statusDesc.textContent = 'All systems operational - No emergency conditions detected';
                break;
            case 'warning':
                statusIndicator.classList.add('warning');
                if (statusIcon) statusIcon.textContent = '🟡';
                if (statusText) statusText.textContent = 'System Status: WARNING';
                if (statusDesc) statusDesc.textContent = 'Some systems degraded - Monitor closely';
                break;
            case 'critical':
                statusIndicator.classList.add('critical');
                if (statusIcon) statusIcon.textContent = '🔴';
                if (statusText) statusText.textContent = 'System Status: CRITICAL';
                if (statusDesc) statusDesc.textContent = 'Critical issues detected - Emergency action may be required';
                break;
            default:
                statusIndicator.classList.add('unknown');
                if (statusIcon) statusIcon.textContent = '❓';
                if (statusText) statusText.textContent = 'System Status: UNKNOWN';
                if (statusDesc) statusDesc.textContent = 'Unable to determine system status';
                break;
        }
    }

    /**
     * Update statistics
     */
    updateStats() {
        // Update stats based on system status
        const healthValue = this.systemStatus === 'safe' ? '98%' : 
                           this.systemStatus === 'warning' ? '75%' : 
                           this.systemStatus === 'critical' ? '45%' : 'Unknown';
        
        const alertsValue = this.systemStatus === 'critical' ? '3' : 
                           this.systemStatus === 'warning' ? '1' : '0';
        
        // Update stats cards
        this.updateStatCard('system-health', healthValue);
        this.updateStatCard('critical-alerts', alertsValue);
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
            <div class="activity-icon" style="background: #dc3545;">${icon}</div>
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
     * Add emergency log entry
     */
    addEmergencyLog(type, message) {
        const logsContainer = document.querySelector('.logs-container');
        if (!logsContainer) return;
        
        const timestamp = new Date().toLocaleString();
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${type}`;
        logEntry.innerHTML = `
            <div class="log-timestamp">${timestamp}</div>
            <div class="log-message">${message}</div>
        `;
        
        logsContainer.insertBefore(logEntry, logsContainer.firstChild);
        
        // Remove old entries if too many
        const entries = logsContainer.querySelectorAll('.log-entry');
        if (entries.length > 20) {
            entries[entries.length - 1].remove();
        }
    }

    /**
     * Load emergency configuration
     */
    loadEmergencyConfig() {
        const saved = localStorage.getItem('grim-emergency-config');
        if (saved) {
            this.emergencyConfig = { ...this.emergencyConfig, ...JSON.parse(saved) };
        }
        
        this.updateConfigDisplay();
    }

    /**
     * Save emergency configuration
     */
    saveEmergencyConfig() {
        localStorage.setItem('grim-emergency-config', JSON.stringify(this.emergencyConfig));
    }

    /**
     * Update configuration display
     */
    updateConfigDisplay() {
        // Update toggles
        Object.keys(this.emergencyConfig).forEach(key => {
            const toggle = document.querySelector(`[data-config="${key}"]`);
            if (toggle) {
                toggle.checked = this.emergencyConfig[key];
            }
        });
    }

    /**
     * Toggle configuration setting
     */
    toggleConfig(key) {
        this.emergencyConfig[key] = !this.emergencyConfig[key];
        this.saveEmergencyConfig();
        this.updateConfigDisplay();
    }

    /**
     * Update configuration
     */
    updateConfig(element) {
        const key = element.getAttribute('data-config');
        this.emergencyConfig[key] = element.checked;
        this.saveEmergencyConfig();
    }

    /**
     * Start live updates
     */
    startLiveUpdates() {
        // Update system status every 30 seconds
        setInterval(() => {
            this.updateSystemStatus();
            this.updateStats();
        }, 30000);
        
        // Auto-heal check every 5 minutes if enabled
        if (this.emergencyConfig.autoHeal) {
            setInterval(() => {
                this.checkAutoHeal();
            }, 300000); // 5 minutes
        }
    }

    /**
     * Check if auto-heal is needed
     */
    async checkAutoHeal() {
        if (this.systemStatus === 'critical') {
            console.log('Critical system status detected - auto-heal may be needed');
            this.addActivityItem('⚠️', 'Critical system status detected - monitoring for auto-heal');
        }
    }
}

// Initialize emergency functionality when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.grimEmergency = new GrimEmergency();
});

// Global functions for HTML onclick handlers
window.performEmergencyHeal = () => window.grimEmergency?.performEmergencyHeal();
window.performEmergencyRestore = () => window.grimEmergency?.performEmergencyRestore();
window.performEmergencyShutdown = () => window.grimEmergency?.performEmergencyShutdown();
window.performEmergencyAction = (action) => window.grimEmergency?.performEmergencyAction(action); 