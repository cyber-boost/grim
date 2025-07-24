/**
 * Grim Logs Management System
 * Real-time log viewing, filtering, and management with live API integration
 * Based on mother-db.js architecture for comprehensive functionality
 */

class GrimLogManager {
    constructor() {
        this.baseUrl = window.location.origin;
        this.currentSource = 'executor'; // Default to executor log which has most data
        this.logs = [];
        this.filteredLogs = [];
        this.liveMode = true;
        this.autoScroll = true;
        this.refreshInterval = null;
        this.liveInterval = null;
        this.sources = [];
        
        // Initialize system
        this.init();
    }

    async init() {
        console.log('🚀 Initializing Grim Log Manager...');
        this.setupEventListeners();
        await this.loadLogSources();
        await this.loadInitialData();
        this.startLiveUpdates();
        console.log('✅ Grim Log Manager initialized successfully');
    }

    setupEventListeners() {
        // Control buttons
        const refreshBtn = document.getElementById('refresh-logs');
        const clearBtn = document.getElementById('clear-logs');
        const downloadBtn = document.getElementById('download-logs');

        if (refreshBtn) refreshBtn.addEventListener('click', () => this.refreshLogs());
        if (clearBtn) clearBtn.addEventListener('click', () => this.clearLogs());
        if (downloadBtn) downloadBtn.addEventListener('click', () => this.downloadLogs());

        // Filter controls
        const levelFilter = document.getElementById('log-level-filter');
        const componentFilter = document.getElementById('component-filter');
        const timeFilter = document.getElementById('time-filter');
        const searchInput = document.getElementById('log-search');

        if (levelFilter) levelFilter.addEventListener('change', () => this.applyFilters());
        if (componentFilter) componentFilter.addEventListener('change', () => this.applyFilters());
        if (timeFilter) timeFilter.addEventListener('change', () => this.loadLogs());
        if (searchInput) {
            let searchTimeout;
            searchInput.addEventListener('input', (e) => {
                clearTimeout(searchTimeout);
                searchTimeout = setTimeout(() => this.applyFilters(), 300);
            });
        }

        // Live controls
        const autoScrollCheck = document.getElementById('auto-scroll');
        const liveModeCheck = document.getElementById('live-mode');

        if (autoScrollCheck) {
            autoScrollCheck.addEventListener('change', (e) => {
                this.autoScroll = e.target.checked;
            });
        }

        if (liveModeCheck) {
            liveModeCheck.addEventListener('change', (e) => {
                this.liveMode = e.target.checked;
                if (this.liveMode) {
                    this.startLiveUpdates();
                } else {
                    this.stopLiveUpdates();
                }
            });
        }

        // Source selector
        const sourceSelector = document.getElementById('log-source');
        if (sourceSelector) {
            sourceSelector.addEventListener('change', (e) => {
                this.currentSource = e.target.value;
                this.showNotification(`Switched to ${e.target.selectedOptions[0].text}`, 'info');
                this.loadLogs();
            });
        }
    }

    async loadLogSources() {
        try {
            const response = await this.fetchWithAuth('/api/logs/sources');
            const data = await response.json();
            
            if (data.success) {
                this.sources = data.sources;
                this.updateSourcesUI();
                this.showNotification('Log sources loaded successfully', 'success');
            } else {
                throw new Error(data.error);
            }
        } catch (error) {
            console.error('Error loading log sources:', error);
            this.showNotification('Failed to load log sources', 'error');
        }
    }

    async loadInitialData() {
        try {
            await Promise.all([
                this.loadLogStats(),
                this.loadLogs()
            ]);
        } catch (error) {
            console.error('Error loading initial data:', error);
            this.showNotification('Failed to load initial data', 'error');
        }
    }

    async loadLogStats() {
        try {
            const response = await this.fetchWithAuth('/api/logs/stats');
            const data = await response.json();
            
            if (data.success) {
                this.updateStatsDisplay(data.stats);
            } else {
                throw new Error(data.error);
            }
        } catch (error) {
            console.error('Error loading log stats:', error);
            this.showNotification('Failed to load log statistics', 'error');
        }
    }

    async loadLogs() {
        try {
            const params = new URLSearchParams({
                source: this.currentSource,
                level: this.getCurrentLevel(),
                limit: '200',
                time_range: this.getCurrentTimeRange(),
                search: this.getCurrentSearch()
            });

            const response = await this.fetchWithAuth(`/api/logs/entries?${params}`);
            const data = await response.json();
            
            if (data.success) {
                this.logs = data.entries;
                
                // If no logs found, generate sample data for demonstration
                if (this.logs.length === 0) {
                    this.logs = this.generateSampleLogs();
                    this.showNotification('No logs found, showing sample data', 'info');
                }
                
                this.applyFilters();
                this.updateLogDisplay();
                this.updateLogStats();
                
                // Show success notification only on manual refresh
                if (!this.refreshInterval) {
                    this.showNotification(`Loaded ${data.entries.length} log entries`, 'success');
                }
            } else {
                // If API fails, show helpful message about real logs
                this.logs = [];
                this.showNotification('API unavailable - Grim admin server may not be running properly.', 'error');
                this.applyFilters();
                this.updateLogDisplay();
                this.updateLogStats();
            }
        } catch (error) {
            console.error('Error loading logs:', error);
            this.logs = [];
            this.showNotification(`Failed to load logs: ${error.message}. Check if Grim admin server is running.`, 'error');
            this.applyFilters();
            this.updateLogDisplay();
            this.updateLogStats();
        }
    }

    async loadLiveLogs() {
        if (!this.liveMode) return;

        try {
            const params = new URLSearchParams({
                source: this.currentSource,
                lines: '20'
            });

            const response = await this.fetchWithAuth(`/api/logs/live?${params}`);
            const data = await response.json();
            
            if (data.success && data.entries.length > 0) {
                // Add new entries to live display
                this.addLiveEntries(data.entries);
            }
        } catch (error) {
            console.error('Error loading live logs:', error);
        }
    }

    updateStatsDisplay(stats) {
        // Update stat cards
        const elements = {
            'total-logs': stats.total_logs || 0,
            'error-count': stats.error_count || 0,
            'warning-count': stats.warning_count || 0,
            'info-count': stats.info_count || 0
        };

        Object.entries(elements).forEach(([id, value]) => {
            const element = document.getElementById(id);
            if (element) {
                element.textContent = value.toLocaleString();
            }
        });

        // Update source breakdown if available
        if (stats.sources) {
            this.updateSourceStats(stats.sources);
        }
    }

    updateSourceStats(sources) {
        // This could update a sources breakdown UI if implemented
        console.log('Source stats:', sources);
    }

    updateLogDisplay() {
        this.updateHistoryTable();
        this.updateLogStats();
    }

    updateHistoryTable() {
        const tbody = document.getElementById('history-tbody');
        if (!tbody) return;

        tbody.innerHTML = '';

        if (this.filteredLogs.length === 0) {
            const row = document.createElement('tr');
            row.innerHTML = '<td colspan="5" class="no-data">No log entries found</td>';
            tbody.appendChild(row);
            return;
        }

        this.filteredLogs.slice(0, 100).forEach(log => {
            const row = this.createLogRow(log);
            tbody.appendChild(row);
        });
    }

    createLogRow(log) {
        const row = document.createElement('tr');
        row.className = `log-row ${log.level.toLowerCase()}`;
        
        const timestamp = new Date(log.timestamp).toLocaleString();
        const levelBadge = this.createLevelBadge(log.level);
        
        row.innerHTML = `
            <td>${timestamp}</td>
            <td>${levelBadge}</td>
            <td class="component-cell">${log.component}</td>
            <td class="message-cell">${this.escapeHtml(log.message)}</td>
            <td>
                <button class="btn-small details-btn" data-log-id="${log.id}">
                    Details
                </button>
            </td>
        `;

        // Add click handler for details
        const detailsBtn = row.querySelector('.details-btn');
        detailsBtn.addEventListener('click', () => this.showLogDetails(log));

        return row;
    }

    createLevelBadge(level) {
        const levelClass = level.toLowerCase();
        return `<span class="level-badge ${levelClass}">${level}</span>`;
    }

    addLiveEntries(entries) {
        const logOutput = document.getElementById('log-output');
        if (!logOutput) return;

        entries.forEach(entry => {
            const logEntry = this.createLiveLogEntry(entry);
            logOutput.appendChild(logEntry);
        });

        // Auto-scroll if enabled
        if (this.autoScroll) {
            logOutput.scrollTop = logOutput.scrollHeight;
        }

        // Keep only last 200 entries for performance
        while (logOutput.children.length > 200) {
            logOutput.removeChild(logOutput.firstChild);
        }
    }

    createLiveLogEntry(log) {
        const entry = document.createElement('div');
        entry.className = 'log-entry new-entry';
        
        const timestamp = new Date(log.timestamp).toLocaleTimeString();
        
        entry.innerHTML = `
            <span class="log-timestamp">${timestamp}</span>
            <span class="log-level ${log.level.toLowerCase()}">${log.level}</span>
            <span class="log-component">${log.component}</span>
            <span class="log-message">${this.escapeHtml(log.message)}</span>
        `;
        
        // Remove the new-entry class after animation
        setTimeout(() => {
            entry.classList.remove('new-entry');
        }, 300);
        
        return entry;
    }

    applyFilters() {
        const level = this.getCurrentLevel();
        const component = this.getCurrentComponent();
        const search = this.getCurrentSearch().toLowerCase();

        this.filteredLogs = this.logs.filter(log => {
            // Level filter
            if (level !== 'all' && log.level.toLowerCase() !== level.toLowerCase()) {
                return false;
            }

            // Component filter
            if (component !== 'all' && log.component !== component) {
                return false;
            }

            // Search filter
            if (search && !log.message.toLowerCase().includes(search)) {
                return false;
            }

            return true;
        });

        this.updateHistoryTable();
        this.updateLogStats();
    }

    updateLogStats() {
        const total = this.filteredLogs.length;
        const errors = this.filteredLogs.filter(log => log.level === 'ERROR').length;
        const warnings = this.filteredLogs.filter(log => log.level === 'WARN' || log.level === 'WARNING').length;
        const info = this.filteredLogs.filter(log => log.level === 'INFO').length;

        // Update filtered stats display
        const totalElement = document.getElementById('filtered-total');
        const errorElement = document.getElementById('filtered-errors');
        const warningElement = document.getElementById('filtered-warnings');
        const infoElement = document.getElementById('filtered-info');

        if (totalElement) totalElement.textContent = total;
        if (errorElement) errorElement.textContent = errors;
        if (warningElement) warningElement.textContent = warnings;
        if (infoElement) infoElement.textContent = info;
    }

    async refreshLogs() {
        this.showNotification('Refreshing logs...', 'info');
        await this.loadLogs();
    }

    async clearLogs() {
        if (!confirm('Are you sure you want to clear the current log source? This action cannot be undone.')) {
            return;
        }

        try {
            const response = await this.fetchWithAuth('/api/logs/clear', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    source: this.currentSource
                })
            });

            const data = await response.json();
            
            if (data.success) {
                this.showNotification('Logs cleared successfully', 'success');
                
                // Clear displays
                this.logs = [];
                this.filteredLogs = [];
                this.updateLogDisplay();
                
                // Clear live display
                const logOutput = document.getElementById('log-output');
                if (logOutput) {
                    logOutput.innerHTML = '';
                }
            } else {
                throw new Error(data.error);
            }
        } catch (error) {
            console.error('Error clearing logs:', error);
            this.showNotification('Failed to clear logs', 'error');
        }
    }

    async downloadLogs() {
        try {
            const params = new URLSearchParams({
                source: this.currentSource,
                format: 'txt',
                time_range: this.getCurrentTimeRange()
            });

            const response = await this.fetchWithAuth(`/api/logs/export?${params}`);
            const data = await response.json();
            
            if (data.success) {
                // Create and download file
                const blob = new Blob([data.data], { type: 'text/plain' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = data.filename;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
                
                this.showNotification('Logs downloaded successfully', 'success');
            } else {
                throw new Error(data.error);
            }
        } catch (error) {
            console.error('Error downloading logs:', error);
            this.showNotification('Failed to download logs', 'error');
        }
    }

    showLogDetails(log) {
        // Create modal or detailed view
        const modal = document.createElement('div');
        modal.className = 'log-details-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Log Entry Details</h3>
                    <button class="modal-close">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="detail-row">
                        <strong>Timestamp:</strong> ${new Date(log.timestamp).toLocaleString()}
                    </div>
                    <div class="detail-row">
                        <strong>Level:</strong> ${this.createLevelBadge(log.level)}
                    </div>
                    <div class="detail-row">
                        <strong>Component:</strong> ${log.component}
                    </div>
                    <div class="detail-row">
                        <strong>Message:</strong> 
                        <div class="message-content">${this.escapeHtml(log.message)}</div>
                    </div>
                    ${log.raw ? `
                        <div class="detail-row">
                            <strong>Raw Log:</strong>
                            <pre class="raw-log">${this.escapeHtml(log.raw)}</pre>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;

        // Add to document
        document.body.appendChild(modal);

        // Add event listeners
        const closeBtn = modal.querySelector('.modal-close');
        closeBtn.addEventListener('click', () => {
            document.body.removeChild(modal);
        });

        // Click outside to close
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                document.body.removeChild(modal);
            }
        });
    }

    startLiveUpdates() {
        if (this.liveInterval) {
            clearInterval(this.liveInterval);
        }

        // Update stream status indicator
        this.updateStreamIndicator(true);

        this.liveInterval = setInterval(() => {
            this.loadLiveLogs();
        }, 2000); // Update every 2 seconds for better responsiveness

        // Also refresh full logs every 30 seconds
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }

        this.refreshInterval = setInterval(() => {
            this.loadLogs();
            this.loadLogStats();
        }, 30000);
    }

    stopLiveUpdates() {
        if (this.liveInterval) {
            clearInterval(this.liveInterval);
            this.liveInterval = null;
        }

        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
        
        // Update stream status indicator
        this.updateStreamIndicator(false);
    }

    updateStreamIndicator(isActive) {
        const indicator = document.getElementById('stream-indicator');
        const statusText = document.getElementById('stream-status-text');
        
        if (indicator && statusText) {
            if (isActive) {
                indicator.className = 'status-indicator active';
                statusText.textContent = 'Streaming';
                statusText.style.color = '#28a745';
            } else {
                indicator.className = 'status-indicator inactive';
                statusText.textContent = 'Paused';
                statusText.style.color = '#dc3545';
            }
        }
    }

    updateSourcesUI() {
        // Update component filter with actual components from logs
        const componentFilter = document.getElementById('component-filter');
        if (componentFilter && this.logs.length > 0) {
            const components = [...new Set(this.logs.map(log => log.component))];
            
            // Clear existing options (except "All Components")
            while (componentFilter.children.length > 1) {
                componentFilter.removeChild(componentFilter.lastChild);
            }

            // Add component options
            components.forEach(component => {
                const option = document.createElement('option');
                option.value = component;
                option.textContent = component;
                componentFilter.appendChild(option);
            });
        }

        // Update source selector to match current source
        const sourceSelector = document.getElementById('log-source');
        if (sourceSelector) {
            sourceSelector.value = this.currentSource;
        }

        // Update active sources count in status
        const activeSourcesElement = document.getElementById('active-sources');
        if (activeSourcesElement && this.sources.length > 0) {
            const activeSources = this.sources.filter(s => s.active).length;
            activeSourcesElement.textContent = `${activeSources}/${this.sources.length}`;
        }
    }

    // Utility methods
    getCurrentLevel() {
        const levelFilter = document.getElementById('log-level-filter');
        return levelFilter ? levelFilter.value : 'all';
    }

    getCurrentComponent() {
        const componentFilter = document.getElementById('component-filter');
        return componentFilter ? componentFilter.value : 'all';
    }

    getCurrentTimeRange() {
        const timeFilter = document.getElementById('time-filter');
        return timeFilter ? timeFilter.value : '24h';
    }

    getCurrentSearch() {
        const searchInput = document.getElementById('log-search');
        return searchInput ? searchInput.value : '';
    }

    async fetchWithAuth(url, options = {}) {
        const response = await fetch(url, {
            ...options,
            credentials: 'include',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                ...options.headers
            }
        });

        if (!response.ok) {
            if (response.status === 401) {
                window.location.href = '/login';
                return;
            }
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return response;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    generateSampleLogs() {
        const levels = ['ERROR', 'WARN', 'INFO', 'DEBUG'];
        const components = ['grim_executor', 'api', 'auth', 'backup', 'system', 'nginx', 'flask'];
        const messages = [
            'Grim Executor initialized successfully',
            'API request received from 192.168.1.100',
            'Authentication successful for user admin',
            'Backup process started',
            'System health check passed',
            'Database connection established',
            'Configuration loaded from peanu.tsk',
            'Terminal session started',
            'License validation successful',
            'Error tracking enabled',
            'Log rotation completed',
            'Memory usage: 75%',
            'Disk space check: OK',
            'Network connectivity verified',
            'SSL certificate valid',
            'Cache cleared successfully'
        ];

        const logs = [];
        const now = new Date();
        
        for (let i = 0; i < 25; i++) {
            const timestamp = new Date(now.getTime() - Math.random() * 7 * 24 * 60 * 60 * 1000);
            const level = levels[Math.floor(Math.random() * levels.length)];
            const component = components[Math.floor(Math.random() * components.length)];
            const message = messages[Math.floor(Math.random() * messages.length)];
            
            logs.push({
                id: `sample_${Date.now()}_${i}`,
                timestamp: timestamp.toISOString(),
                level: level,
                component: component,
                message: `[DEMO] ${message}`,
                raw: `${timestamp.toISOString()} [${level}] [${component}] [DEMO] ${message}`
            });
        }
        
        return logs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    }

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <span class="notification-message">${message}</span>
            <button class="notification-close">&times;</button>
        `;

        // Position it
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 10000;
            padding: 12px 16px;
            border-radius: 4px;
            color: white;
            background: ${type === 'error' ? '#dc3545' : type === 'success' ? '#28a745' : '#17a2b8'};
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
            transform: translateX(100%);
            transition: transform 0.3s ease;
        `;

        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.style.transform = 'translateX(0)';
        }, 10);

        // Add close handler
        const closeBtn = notification.querySelector('.notification-close');
        closeBtn.addEventListener('click', () => {
            this.removeNotification(notification);
        });

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (document.body.contains(notification)) {
                this.removeNotification(notification);
            }
        }, 5000);
    }

    removeNotification(notification) {
        notification.style.transform = 'translateX(100%)';
        setTimeout(() => {
            if (document.body.contains(notification)) {
                document.body.removeChild(notification);
            }
        }, 300);
    }
}

// Legacy function support for existing HTML onclick handlers
function refreshData() {
    if (window.grimLogManager) {
        window.grimLogManager.refreshLogs();
    }
}

function clearLogs() {
    if (window.grimLogManager) {
        window.grimLogManager.clearLogs();
    }
}

function downloadLogs() {
    if (window.grimLogManager) {
        window.grimLogManager.downloadLogs();
    }
}

// Additional legacy functions
function startAutoRefresh() {
    if (window.grimLogManager) {
        window.grimLogManager.startLiveUpdates();
    }
}

function stopAutoRefresh() {
    if (window.grimLogManager) {
        window.grimLogManager.stopLiveUpdates();
    }
}

function filterLogs() {
    if (window.grimLogManager) {
        window.grimLogManager.applyFilters();
    }
}

function exportLogs() {
    if (window.grimLogManager) {
        window.grimLogManager.downloadLogs();
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Only initialize if we're on the logs page
    if (document.getElementById('log-output') || document.getElementById('history-table')) {
        window.grimLogManager = new GrimLogManager();
        console.log('✅ Grim Log Manager loaded and ready');
    }
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GrimLogManager;
} 